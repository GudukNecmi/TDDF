class_name Cigarette
extends Node2D
## The cigarette clenched in the character's mouth, and the thread of smoke off
## its tip.
##
## This node *is* the mouth: it sits at the point where the cigarette touches the
## head and the artwork hangs off it, so it is parented under the head sprite and
## inherits the head's every move - the aim lean, the [SoftFollow] trail, the
## facing flip and the breathing squash - without knowing about any of them. All
## this script adds on top is a little play in the joint, which is what stops the
## cigarette reading as painted on.
##
## The play comes from three sources, all of them tiny: a constant detuned wobble
## so it is never perfectly still, a lean thrown by changes in the character's
## velocity - starting, stopping and turning - and a kick whenever the weapon
## fires. They are summed, so walking while shooting jostles it more than either
## alone. Only [member Node2D.rotation] and [member Node2D.position] on this node
## are written, and both settle back to zero, so the mouth end can never drift.
##
## The smoke is a plain [CPUParticles2D] left at [member CanvasItem.top_level],
## so it draws in world space at world scale however small the head's sprite is
## scaled - this node only carries it to the tip each frame. Its own emission
## settings decide how the smoke looks; nothing here writes to them.

## Character whose movement jostles the cigarette. Its `velocity` is read, never
## written.
@export var body_path: NodePath = ^"../../.."
## Weapon whose `fired` signal kicks the cigarette, when there is no
## [WeaponMount] in the world to ask. Optional - unresolved, the cigarette simply
## reacts to movement alone. Only a fallback for a test scene, exactly as
## [member PlayerLoadout.weapon_path] is.
@export var weapon_path: NodePath = ^"../../../../Shotgun"
## Smoke emitter carried to the burning tip. Optional.
@export var smoke_path: NodePath = ^"Smoke"
## Marker at the burning tip the smoke is emitted from. Falls back to this node's
## own position when there is none.
@export var tip_path: NodePath = ^"Cigar/Tip"

@export_group("Idle wobble")
## Constant sway either way, in degrees. Keep it under a degree or two - this is
## the cigarette settling in the mouth, not being waved about.
@export var idle_sway_degrees: float = 0.9
## Sway cycles per second. The two axes are detuned off this so the wobble never
## repeats on an obvious beat.
@export var idle_sway_speed: float = 0.7
## Constant positional drift, in screen pixels.
@export var idle_drift: float = 0.5

@export_group("Movement")
## How far a change in the character's velocity leans the cigarette, in degrees
## per pixel per second of change.
@export var lean_per_velocity_change: float = 0.05
## Ceiling on that lean, in degrees, so a hard direction change can only ever
## nudge it.
@export var max_lean_degrees: float = 7.0
## How far the same change shifts it, in screen pixels per pixel per second.
@export var shift_per_velocity_change: float = 0.03
## Ceiling on that shift, in screen pixels.
@export var max_shift: float = 2.4
## How quickly the lean and shift settle back to nothing.
@export var recovery: float = 9.0

@export_group("Recoil")
## Rotation the cigarette is snapped by when the weapon fires, in degrees. Signed
## randomly per shot so repeat fire does not pump it one way.
@export var fire_kick_degrees: float = 5.0
## Displacement it is snapped by when the weapon fires, in screen pixels.
@export var fire_kick_shift: float = 1.6

@onready var _body: Node = get_node_or_null(body_path)
@onready var _smoke: CPUParticles2D = get_node_or_null(smoke_path) as CPUParticles2D
@onready var _tip: Node2D = get_node_or_null(tip_path) as Node2D

var _rest_position: Vector2
var _time: float = 0.0
var _lean: float = 0.0
var _shift: Vector2 = Vector2.ZERO
var _previous_velocity: Vector2 = Vector2.ZERO
var _local_per_pixel: float = 1.0


func _ready() -> void:
	_rest_position = position
	_measure_scale()
	_bind_weapon()


## Finds whatever the player is carrying and listens for its shot.
##
## Asked of the [WeaponMount] rather than reached by path, because the weapon is
## built from the player's choice rather than authored into the world - and built
## possibly after this node was ready, which is why the mount is also listened to
## for the next one. Nothing here knows which weapon it is: any weapon that
## announces `fired` kicks the cigarette.
func _bind_weapon() -> void:
	var mount := WeaponMount.get_active(self)
	if mount == null:
		_listen_for_shots(get_node_or_null(weapon_path))
		return

	if not mount.weapon_built.is_connected(_listen_for_shots):
		mount.weapon_built.connect(_listen_for_shots)
	_listen_for_shots(mount.get_weapon())


func _listen_for_shots(weapon: Node) -> void:
	if weapon == null or not weapon.has_signal(&"fired"):
		return
	if not weapon.is_connected(&"fired", _on_weapon_fired):
		weapon.connect(&"fired", _on_weapon_fired)


## The cigarette hangs off a sprite drawn at a fraction of its texture's size, so
## one unit of this node's local space is a small fraction of a screen pixel.
## Measuring that fraction once lets every distance above be written in screen
## pixels, which is the only unit any of them are meaningful in.
##
## Read before a [FacingFlip] has had a frame to mirror anything, and taken as a
## magnitude regardless, so a mirrored character cannot invert it.
func _measure_scale() -> void:
	var drawn := absf(global_scale.x)
	_local_per_pixel = 1.0 / drawn if drawn > 0.0001 else 1.0


func _physics_process(delta: float) -> void:
	_time += delta
	_absorb_movement(delta)

	# Summed rather than blended: the wobble is always there and the kick rides on
	# top of it, so a shot fired while sprinting jostles the cigarette more than
	# either would alone.
	rotation = deg_to_rad(_lean) + _idle_rotation()
	position = _rest_position + _shift + _idle_drift()

	_carry_smoke()


## Kicked by *changes* in the character's velocity rather than by the velocity
## itself, so the cigarette is thrown when they start, stop and turn and hangs
## still while they cross the arena at a steady walk.
func _absorb_movement(delta: float) -> void:
	if delta <= 0.0:
		return

	var velocity := Vector2.ZERO
	if _body != null and "velocity" in _body:
		velocity = _body.get(&"velocity") as Vector2

	var change := velocity - _previous_velocity
	_previous_velocity = velocity

	_lean = clampf(
		_lean - change.x * lean_per_velocity_change, -max_lean_degrees, max_lean_degrees)
	_shift = (_shift - change * shift_per_velocity_change * _local_per_pixel) \
		.limit_length(max_shift * _local_per_pixel)

	var settle := 1.0 - exp(-recovery * delta)
	_lean = lerpf(_lean, 0.0, settle)
	_shift = _shift.lerp(Vector2.ZERO, settle)


## Two detuned sines, so the wobble never lands on a repeating beat.
func _idle_rotation() -> float:
	var sway := sin(_time * idle_sway_speed * TAU) * 0.7
	sway += sin(_time * idle_sway_speed * TAU * 0.41 + 1.9) * 0.3
	return deg_to_rad(idle_sway_degrees) * sway


func _idle_drift() -> Vector2:
	return Vector2(
		sin(_time * idle_sway_speed * TAU * 0.63 + 0.4),
		sin(_time * idle_sway_speed * TAU * 0.37 + 2.3)
	) * idle_drift * _local_per_pixel


## The emitter is [member CanvasItem.top_level], so it keeps world scale and
## world rotation however the head is scaled, leant or mirrored - it only has to
## be put in the right place. Smoke already in the air is left where it is, which
## is what makes it trail behind a moving character instead of being dragged
## along with them.
func _carry_smoke() -> void:
	if _smoke == null:
		return
	_smoke.global_position = _tip.global_position if _tip != null else global_position


## Signed at random so repeat fire jostles the cigarette about rather than
## walking it steadily to one side.
func _on_weapon_fired() -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	_lean = clampf(_lean + fire_kick_degrees * side, -max_lean_degrees, max_lean_degrees)
	var kick := Vector2(-fire_kick_shift, -fire_kick_shift * 0.4) * _local_per_pixel
	_shift = (_shift + kick).limit_length(max_shift * _local_per_pixel)
