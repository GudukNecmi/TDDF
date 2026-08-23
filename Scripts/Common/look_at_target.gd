class_name LookAtTarget
extends Node2D
## Turns this node so that its art's resting direction points at [member target].
##
## Used as a pivot: put the sprite underneath and this node at the point the
## sprite should rotate around. Because it only writes `rotation` on *itself*,
## a child sprite is still free to run its own animation and offset.

enum Mode {
	## Full 360 degree tracking. Right for a held weapon.
	FREE,
	## Side-view: picks the side the target is on and only tilts a little.
	## Right for a head, which must never spin or end up upside down.
	LEAN,
}

@export var mode: Mode = Mode.FREE
## Whether the pivot points directly away from [member target] rather than at it.
##
## Off for anything that is looking at something, which is every pivot as it is
## authored. It is switched on at runtime by an enemy that has given up and is
## running - see [EnemyEscape] - so a retreat is the same tracking read backwards
## and its head and body face the way they are going without a second aiming mode
## having to exist. It works in both modes for the same reason: only the vector is
## reversed, and everything downstream of that is untouched.
@export var look_away: bool = false
## Direction this pivot's art faces when its rotation is zero, in degrees.
## Only used by [constant Mode.FREE]; in lean mode zero rotation is the art's
## own resting pose.
@export var rest_angle_degrees: float = 90.0
## How quickly the turn catches up. Higher snaps harder; 0 snaps instantly.
@export var turn_speed: float = 18.0

@export_group("Lean")
## Hard limit on the tilt in lean mode, applied either way from level.
@export var max_lean_degrees: float = 25.0
## Optional Node2D mirrored horizontally so the art faces the target's side.
## Its origin must sit on the character's centre line, or mirroring shifts it.
@export var flip_node_path: NodePath

## Assigned at runtime by the character that owns this pivot.
var target: Node2D
## -1 when the target is to the left, +1 when it is to the right.
var facing: float = 1.0

@onready var _flip_node: Node2D = get_node_or_null(flip_node_path) as Node2D

var _flip_base_scale_x: float = 1.0


func _ready() -> void:
	if _flip_node != null:
		_flip_base_scale_x = absf(_flip_node.scale.x)


## Takes the flip node's width as it is now to be the pose it mirrors about.
##
## [b]For art that is rescaled after this pivot has already measured it.[/b] The
## mirror writes `scale.x` every frame from the width read once on ready, so a
## sprite resized later - a mini boss whose head comes out of a [MiniBossWardrobe]
## drawn at a different size, see [MiniBossAppearance] - would be snapped back to
## its original width on the next frame while keeping its new height. Nothing that
## leaves the artwork at the size the scene authored it needs to call this.
func refresh_flip_base() -> void:
	if _flip_node != null:
		_flip_base_scale_x = absf(_flip_node.scale.x)


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var to_target := target.global_position - global_position
	if to_target.is_zero_approx():
		return
	if look_away:
		to_target = -to_target

	if mode == Mode.FREE:
		_track_freely(to_target, delta)
	else:
		_lean_towards(to_target, delta)


func _track_freely(to_target: Vector2, delta: float) -> void:
	var desired := to_target.angle() - deg_to_rad(rest_angle_degrees)
	if turn_speed <= 0.0:
		global_rotation = desired
	else:
		global_rotation = lerp_angle(global_rotation, desired, 1.0 - exp(-turn_speed * delta))


## Side-view heads never spin. The node mirrors to whichever side the target is
## on, then tilts by a clamped amount. Measuring the tilt from the facing
## direction rather than from +X is what keeps it on the short way round.
func _lean_towards(to_target: Vector2, delta: float) -> void:
	if not is_zero_approx(to_target.x):
		facing = signf(to_target.x)

	var lean := atan2(to_target.y, absf(to_target.x))
	var limit := deg_to_rad(max_lean_degrees)
	var desired := clampf(lean, -limit, limit) * facing

	if turn_speed <= 0.0:
		rotation = desired
	else:
		rotation = lerp_angle(rotation, desired, 1.0 - exp(-turn_speed * delta))

	if _flip_node != null:
		_flip_node.scale.x = _flip_base_scale_x * facing
