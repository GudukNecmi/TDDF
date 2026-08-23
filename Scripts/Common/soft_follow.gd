class_name SoftFollow
extends Node2D
## Subtle secondary motion for a sprite: it trails a few pixels behind the node
## it is parented to, then eases back to rest. Purely cosmetic.
##
## It only ever writes [member Node2D.position], so an AnimationPlayer is free
## to drive `rotation` on the same node without the two fighting each other.

## How far back in time the sprite lags, in seconds. Keep this small.
@export var lag: float = 0.035
## How quickly the trailing offset catches up to its target.
@export var response: float = 22.0
## Hard cap on the offset, so the sprite can never visibly detach.
@export var max_offset: float = 6.0
## Scales the trail per axis, applied after the cap. It exists because the two
## axes do not read the same on a character seen from above: a head sliding
## sideways off the shoulders is noticed immediately, while the same amount of
## give up and down still reads as weight. Pulling X down and leaving Y alone is
## how a head is pinned to its body without the motion being switched off.
##
## [constant Vector2.ONE] is the plain trail in both directions, which is what
## every sprite using this had before the field existed.
@export var offset_scale := Vector2.ONE

var _rest_position: Vector2
var _offset: Vector2 = Vector2.ZERO
var _previous_parent_position: Vector2


func _ready() -> void:
	_rest_position = position
	var parent := get_parent() as Node2D
	if parent != null:
		_previous_parent_position = parent.global_position


func _physics_process(delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null or delta <= 0.0:
		return

	var velocity := (parent.global_position - _previous_parent_position) / delta
	_previous_parent_position = parent.global_position

	# Trail towards where the parent was `lag` seconds ago, in the parent's own space.
	var target := parent.global_transform.basis_xform_inv(-velocity * lag)
	_offset = _offset.lerp(target.limit_length(max_offset), 1.0 - exp(-response * delta))

	position = _rest_position + _offset * offset_scale
