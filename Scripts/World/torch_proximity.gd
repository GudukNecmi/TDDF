class_name TorchProximity
extends Node
## Brings a group of torches up as the player comes near and lets them die back
## down as they leave.
##
## It owns nothing about how a torch burns. Every torch keeps its own flicker,
## its own noise seed and its own embers; this only writes
## [method Torch.set_lit_amount], one multiplier, so a ring of torches coming up
## together still guttering out of step with each other.
##
## The lit amount is a smooth band rather than a switch: fully lit at
## [member lit_distance] and closer, fully out at [member unlit_distance] and
## beyond, eased between the two. Because the two distances are separate there is
## a wide zone where the torches are part lit, which is what makes them read as
## catching and dying rather than snapping on and off - and it means no
## hysteresis is needed to stop them flickering at the boundary.

## Container whose [Torch] children are driven. Every torch found underneath it,
## at any depth, is picked up, so adding one to the scene is enough.
@export var torches_path: NodePath = ^"../Torches"
## Node the distance is measured from. Defaults to this component's parent, which
## is normally the thing the torches are arranged around.
@export var origin_path: NodePath = ^".."
## Group the approaching body is found by, so nothing has to be wired to the
## player.
@export var target_group: StringName = &"player"

@export_group("Range")
## At or inside this distance the torches are at full flame.
@export var lit_distance: float = 260.0
## At or beyond this distance they are out. Must be larger than
## [member lit_distance]; the gap between the two is the fade.
@export var unlit_distance: float = 520.0
## How quickly the torches follow a change in distance, in units per second. Low
## enough that walking past does not strobe them, high enough to feel responsive.
@export var response: float = 2.4

## 0 while the player is away, 1 while they are standing here.
var _amount: float = 0.0

@onready var _origin: Node2D = get_node_or_null(origin_path) as Node2D

var _torches: Array[Torch] = []


func _ready() -> void:
	var container := get_node_or_null(torches_path)
	if container != null:
		for node: Node in container.find_children("*", "Torch", true, false):
			var torch := node as Torch
			if torch != null:
				_torches.append(torch)

	# Settled at the true value on the first frame rather than eased into from
	# zero, so a base that starts with the player already standing in the pit does
	# not open on a ring of torches visibly catching alight.
	_amount = _goal()
	_apply()


func _process(delta: float) -> void:
	_amount = lerpf(_amount, _goal(), 1.0 - exp(-response * delta))
	_apply()


## How lit the torches should be right now, before the easing.
func _goal() -> float:
	var target := _find_target()
	if target == null or _origin == null:
		return 0.0

	var distance := _origin.global_position.distance_to(target.global_position)
	var near := minf(lit_distance, unlit_distance)
	var far := maxf(unlit_distance, near + 0.001)
	return 1.0 - smoothstep(near, far, distance)


func _apply() -> void:
	for torch: Torch in _torches:
		torch.set_lit_amount(_amount)


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D
