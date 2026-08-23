class_name KnifeSlash
extends Node
## Procedural knife motion: spring-driven secondary motion plus a fast, messy
## thrust at a point on the target.
##
## It drives two things and nothing else:
##   * the blade's `rotation` - idle sway and the swing arc
##   * the carrier node's `position` - trailing lag, sway, pull-back and thrust
## The blade's own [SoftFollow] keeps writing its `position` on top of the
## carrier, so the two layers stack instead of fighting.
##
## The aim target is read from the parent [LookAtTarget] pivot, so nothing else
## has to wire it up.
##
## [b]Three nested things turn, and they turn about different points.[/b] The
## pivot swings the whole arrangement round the enemy so the blade is always on
## the player's side of them; the carrier is pushed about by the spring here; and
## the blade turns about its [i]own[/i] centre, because the sprite's `offset` puts
## that centre on its origin. That last part is what makes the knife read as a
## blade turning in the air rather than as something being swung round on a
## string, and it is why how far out from the enemy the knife sits is the blade's
## own resting `position` - one number, in the scene, tunable without touching any
## of the motion here.

## Emitted as a swing is committed to - the attack itself, on the frame the blade
## starts being drawn back.
signal swing_started
## Emitted as the blade stops being drawn back and starts travelling at the target,
## which is [constant Phase.WINDUP] handing over to [constant Phase.STRIKE].
##
## [b]This is the swoosh, and it is deliberately not the swing.[/b] The two are
## [member windup_time] apart: a sound on the swing would arrive while the knife is
## still going backwards, and a sound on the hit would arrive after the blade had
## already been through. Anything hung off this lands with the movement it is
## describing, whatever the wind-up is retuned to.
signal strike_started

enum Phase { IDLE, WINDUP, STRIKE, RECOVER }

## Blade sprite this drives the rotation of.
@export var knife_path: NodePath = ^"../KnifeHand/Knife"
## Carrier node this drives the position of. Sits between pivot and blade.
@export var hand_path: NodePath = ^"../KnifeHand"
## Direction the blade points, in its own local space, at zero rotation.
@export var blade_angle_degrees: float = -149.3
## Offset from the target's origin to the point actually swiped at - the
## target's centre rather than its feet.
@export var target_centre_offset := Vector2(0, -18)

@export_group("Idle")
## Amplitude of the constant idle sway. Keep it small.
@export var idle_sway_degrees: float = 3.0
@export var idle_sway_speed: float = 1.6
## How loosely the blade follows its idle angle. Lower = more inertia.
@export var rotation_inertia: float = 12.0

@export_group("Secondary motion")
## How far behind the enemy the knife hangs, in seconds of its travel.
@export var lag_seconds: float = 0.05
## Amplitude of the constant positional drift, in pixels.
@export var sway_position_px: float = 1.5
## Spring pulling the knife to where it should be. Higher = tighter.
@export var spring_stiffness: float = 200.0
## Resistance in that spring. Low enough to overshoot and settle.
@export var spring_damping: float = 16.0
## Hard cap on how far the knife may stray. It can never detach. Sized to sit
## clear of the thrust so it stays a safety net rather than a limiter.
@export var max_offset: float = 36.0

@export_group("Slash")
@export var windup_degrees: float = 55.0
@export var overshoot_degrees: float = 45.0
@export var windup_time: float = 0.07
@export var strike_time: float = 0.09
@export var recover_time: float = 0.18
## How far the wind-up, overshoot and aim are randomised per swing.
@export var messiness_degrees: float = 14.0
## Distance the knife is drawn back before the swing.
@export var pull_back_px: float = 11.0
## Distance the knife is driven towards the target during the swing.
@export var thrust_px: float = 26.0
## Spring used while swinging - stiff, so the thrust is aggressive.
@export var slash_stiffness: float = 1100.0
## Resistance during the swing. Tuned to overshoot the thrust by about a fifth
## rather than flying past it.
@export var slash_damping: float = 30.0

@onready var _knife: Node2D = get_node_or_null(knife_path) as Node2D
@onready var _hand: Node2D = get_node_or_null(hand_path) as Node2D
@onready var _pivot: LookAtTarget = get_parent() as LookAtTarget

var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
var _time: float = 0.0
var _from: float = 0.0
var _strike_angle: float = 0.0
var _side: float = 1.0
var _windup: float = 0.0
var _overshoot: float = 0.0

var _offset: Vector2 = Vector2.ZERO
var _spring_velocity: Vector2 = Vector2.ZERO
var _slash_direction: Vector2 = Vector2.RIGHT
var _pivot_velocity: Vector2 = Vector2.ZERO
var _previous_pivot_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if _pivot != null:
		_previous_pivot_position = _pivot.global_position


func is_slashing() -> bool:
	return _phase != Phase.IDLE


## Commits a swipe at wherever the target is right now. Safe to call again
## mid-swing; the new swing simply takes over from the current pose.
func slash() -> void:
	if _knife == null:
		return

	_strike_angle = _compute_strike_angle()
	_slash_direction = _compute_local_aim_direction()
	# A different side, reach and aim every time, so no two swings match.
	_side = 1.0 if randf() < 0.5 else -1.0
	_windup = deg_to_rad(windup_degrees + randf_range(-messiness_degrees, messiness_degrees))
	_overshoot = deg_to_rad(overshoot_degrees + randf_range(-messiness_degrees, messiness_degrees))
	_strike_angle += deg_to_rad(randf_range(-messiness_degrees, messiness_degrees) * 0.5)

	_from = _knife.rotation
	_elapsed = 0.0
	_phase = Phase.WINDUP
	swing_started.emit()


func _physics_process(delta: float) -> void:
	if _knife == null:
		return

	_time += delta
	_elapsed += delta
	_measure_pivot_velocity(delta)

	# Every phase picks where the knife is pulled towards and how hard.
	var spring_target := _idle_offset()
	var stiffness := spring_stiffness
	var damping := spring_damping

	match _phase:
		Phase.WINDUP:
			var t := _phase_progress(windup_time)
			# Snapped straight onto the curve: the swing must stay crisp.
			_knife.rotation = lerp_angle(_from, _strike_angle - _windup * _side, _ease_out(t, 3.0))
			spring_target = -_slash_direction * pull_back_px
			stiffness = slash_stiffness
			damping = slash_damping
			if t >= 1.0:
				_advance(Phase.STRIKE)
				strike_started.emit()
		Phase.STRIKE:
			var t := _phase_progress(strike_time)
			_knife.rotation = lerp_angle(_from, _strike_angle + _overshoot * _side, _ease_out(t, 2.0))
			spring_target = _slash_direction * thrust_px
			stiffness = slash_stiffness
			damping = slash_damping
			if t >= 1.0:
				_advance(Phase.RECOVER)
		Phase.RECOVER:
			var t := _phase_progress(recover_time)
			_knife.rotation = lerp_angle(_from, _idle_angle(), smoothstep(0.0, 1.0, t))
			if t >= 1.0:
				_phase = Phase.IDLE
		_:
			# Eased rather than assigned, so the blade carries a little inertia
			# and never sits perfectly still.
			_knife.rotation = lerp_angle(
				_knife.rotation, _idle_angle(), 1.0 - exp(-rotation_inertia * delta)
			)

	_integrate_spring(spring_target, stiffness, damping, delta)


## A damped spring, so direction changes overshoot and settle instead of
## snapping. This is what makes the knife feel heavy and loose.
func _integrate_spring(target: Vector2, stiffness: float, damping: float, delta: float) -> void:
	if _hand == null:
		return

	_spring_velocity += (target - _offset) * stiffness * delta
	_spring_velocity *= exp(-damping * delta)
	_offset += _spring_velocity * delta
	_offset = _offset.limit_length(max_offset)
	_hand.position = _offset


func _measure_pivot_velocity(delta: float) -> void:
	if _pivot == null or delta <= 0.0:
		return
	_pivot_velocity = (_pivot.global_position - _previous_pivot_position) / delta
	_previous_pivot_position = _pivot.global_position


## Where the knife wants to hang when nothing is happening: trailing behind the
## enemy's travel, with a slow drift on top so it is never perfectly still.
func _idle_offset() -> Vector2:
	var trail := Vector2.ZERO
	if _pivot != null:
		trail = _pivot.global_transform.basis_xform_inv(-_pivot_velocity * lag_seconds)

	var sway := Vector2(
		sin(_time * idle_sway_speed * TAU * 0.53 + 0.7),
		sin(_time * idle_sway_speed * TAU * 0.31 + 2.1)
	)
	return trail + sway * sway_position_px


func _advance(next: Phase) -> void:
	_from = _knife.rotation
	_elapsed = 0.0
	_phase = next


func _phase_progress(duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_elapsed / duration, 0.0, 1.0)


func _ease_out(t: float, power: float) -> float:
	return 1.0 - pow(1.0 - t, power)


## Two detuned sines, so the drift never repeats on an obvious beat.
func _idle_angle() -> float:
	var sway := sin(_time * idle_sway_speed * TAU) * 0.65
	sway += sin(_time * idle_sway_speed * TAU * 0.37 + 1.3) * 0.35
	return deg_to_rad(idle_sway_degrees) * sway


func _aim_point() -> Vector2:
	return _pivot.target.global_position + target_centre_offset


## Local rotation that would put the blade on the target's centre.
func _compute_strike_angle() -> float:
	if _pivot == null or _pivot.target == null:
		return 0.0

	var to_target := _aim_point() - _knife.global_position
	if to_target.is_zero_approx():
		return 0.0

	return wrapf(
		to_target.angle() - _pivot.global_rotation - deg_to_rad(blade_angle_degrees), -PI, PI
	)


## Direction of the target in the pivot's local space, which is the space the
## carrier's position lives in.
func _compute_local_aim_direction() -> Vector2:
	if _pivot == null or _pivot.target == null or _hand == null:
		return Vector2.RIGHT

	var to_target := _aim_point() - _hand.global_position
	if to_target.is_zero_approx():
		return Vector2.RIGHT

	return _pivot.global_transform.basis_xform_inv(to_target.normalized()).normalized()
