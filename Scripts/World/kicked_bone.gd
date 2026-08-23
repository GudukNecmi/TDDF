class_name KickedBone
extends Node2D
## A bone somebody's boot caught: it skitters off across the sand, turning over
## as it goes, and then lies there for the rest of the round.
##
## Purely cosmetic and deliberately physics-free. It has no body, no area and no
## collision of any kind, so a bone flying across the arena can never shove the
## player, block a pellet or be chased by an enemy. What it does is move itself
## along a direction, bleed off speed, and stop.
##
## The hop is the only part with a trick in it. The bone's *position* stays flat
## on the ground the whole time - that is where its shadow is, and where it will
## land - and the artwork is lifted above it on its own node instead. So the
## shadow stays put under the bone and the bone rises off it, which is what makes
## a flat top-down kick read as something leaving the ground rather than as a
## sprite sliding.
##
## Every number is an inspector value, so a heavier boot or a longer skitter is a
## setting on whatever spawns it rather than an edit here - see [BoneProp].

## Emitted as the bone comes to rest.
signal landed

## Artwork lifted for the hop and spun. Everything visual should hang off it.
@export var art_path: NodePath = ^"Art"
## Shadow left on the ground underneath, which does not rise with the artwork.
@export var shadow_path: NodePath = ^"Shadow"

@export_group("Flight")
## How fast the bone leaves the boot, in pixels per second.
@export var launch_speed := Vector2(210.0, 330.0)
## How quickly it bleeds that off. Higher stops it sooner.
@export var drag: float = 3.4
## Speed below which it is called down, in pixels per second.
@export var stop_speed: float = 18.0
## Longest a flight is allowed to last, in seconds, so nothing can be left
## drifting forever if the numbers above are tuned into a state that never
## settles.
@export var max_flight_time: float = 1.6
## Spread either side of the kick direction, in degrees. A boot does not send a
## bone perfectly straight.
@export var direction_spread_degrees: float = 22.0

@export_group("Hop")
## How high the artwork rises off the ground at the top of its arc, in pixels.
@export var hop_height: float = 26.0
## Turns the bone makes per second while it is in the air.
@export var spin_turns_per_second := Vector2(1.1, 2.4)
## How much the artwork grows at the top of the hop, as a fraction, so a bone
## coming towards the camera reads as coming up rather than only forwards.
@export var hop_scale: float = 0.18

@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _shadow: PropShadow = get_node_or_null(shadow_path) as PropShadow

var _velocity: Vector2 = Vector2.ZERO
var _flight_time: float = 0.0
var _flight_length: float = 1.0
var _spin: float = 0.0
var _art_rest: Vector2 = Vector2.ZERO
var _art_scale: Vector2 = Vector2.ONE
var _shadow_scale: Vector2 = Vector2.ONE
var _flying: bool = false


func _ready() -> void:
	if _art != null:
		_art_rest = _art.position
		_art_scale = _art.scale
	if _shadow != null:
		_shadow_scale = _shadow.scale
	set_physics_process(_flying)


## Kicks the bone off from [param from] in [param direction], which need not be
## normalised. [param power] scales the launch speed, so a player sprinting over
## a bone sends it further than one jogging.
##
## Called before the bone is added to the tree as well as after: the launch is
## remembered and applied on ready either way, so a spawner can set it up in one
## breath.
func launch(from: Vector2, direction: Vector2, power: float = 1.0) -> void:
	global_position = from
	# Physics interpolation is on project-wide; without this the bone is smeared
	# in from wherever its container's last frame put it.
	if is_inside_tree():
		reset_physics_interpolation()

	var heading := direction
	if heading.is_zero_approx():
		heading = Vector2.RIGHT.rotated(randf() * TAU)
	heading = heading.normalized().rotated(
		deg_to_rad(randf_range(-direction_spread_degrees, direction_spread_degrees)))

	var speed := randf_range(launch_speed.x, launch_speed.y) * maxf(power, 0.0)
	_velocity = heading * speed
	_spin = randf_range(spin_turns_per_second.x, spin_turns_per_second.y) \
		* (1.0 if randf() < 0.5 else -1.0)

	# How long the flight will last at this speed under this drag, so the hop can
	# be a single arc across the whole of it rather than a second timing to keep
	# in step with the movement.
	_flight_length = clampf(
		log(maxf(speed, stop_speed + 1.0) / maxf(stop_speed, 0.01)) / maxf(drag, 0.01),
		0.08, maxf(max_flight_time, 0.08))
	_flight_time = 0.0
	_flying = true
	set_physics_process(true)


func is_flying() -> bool:
	return _flying


func _physics_process(delta: float) -> void:
	if not _flying:
		return

	_flight_time += delta
	position += _velocity * delta
	_velocity *= exp(-maxf(drag, 0.0) * delta)

	var progress := clampf(_flight_time / _flight_length, 0.0, 1.0)
	_lift(sin(progress * PI))

	if _art != null:
		_art.rotation += _spin * TAU * delta * (1.0 - progress)

	if _velocity.length() <= stop_speed or _flight_time >= max_flight_time:
		_land()


## One value drives the height, the size and how faint the shadow is, so they
## can never drift apart part way through the arc: the further off the ground the
## bone is, the smaller and softer the mark it leaves under itself.
func _lift(amount: float) -> void:
	if _art != null:
		_art.position = _art_rest + Vector2(0.0, -hop_height * amount)
		_art.scale = _art_scale * (1.0 + hop_scale * amount)
	if _shadow != null:
		_shadow.scale = _shadow_scale * (1.0 - 0.45 * amount)
		_shadow.self_modulate.a = _shadow.shadow_opacity * (1.0 - 0.5 * amount)


func _land() -> void:
	_flying = false
	_velocity = Vector2.ZERO
	_lift(0.0)
	# It is scenery from here on: no movement to run, and nothing left that has to
	# be ticked for the rest of the round.
	set_physics_process(false)
	landed.emit()
