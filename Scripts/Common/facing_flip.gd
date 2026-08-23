class_name FacingFlip
extends Node
## Mirrors side-view sprites horizontally so a character visually faces the way
## it is aiming.
##
## It writes only `scale.x` on the nodes it is given, so it never fights a
## squash animation on a parent, a [SoftFollow] driving `position`, or an
## AnimationPlayer driving `rotation`.

enum Source {
	## Face the mouse cursor.
	MOUSE,
	## Face another node in the scene.
	TARGET_NODE,
}

@export var source: Source = Source.MOUSE
## Only used when [member source] is [constant Source.TARGET_NODE].
@export var target_path: NodePath
## Node the direction is measured from. Defaults to this component's parent.
@export var origin_path: NodePath = ^".."
## Sprites or pivots to mirror. Each one's origin must sit on the character's
## centre line, otherwise mirroring shifts it sideways instead of in place.
@export var flip_paths: Array[NodePath] = []
## How far off centre the aim must be before the facing flips. Stops the
## character flickering when the cursor sits right on top of it.
@export var deadzone: float = 4.0

## -1 when aiming left, +1 when aiming right.
var facing: float = 1.0

@onready var _origin: Node2D = get_node_or_null(origin_path) as Node2D
@onready var _target: Node2D = get_node_or_null(target_path) as Node2D

var _flip_nodes: Array[Node2D] = []
var _base_scale_x: Array[float] = []


func _ready() -> void:
	for path: NodePath in flip_paths:
		var node := get_node_or_null(path) as Node2D
		if node == null:
			continue
		_flip_nodes.append(node)
		_base_scale_x.append(absf(node.scale.x))


func _physics_process(_delta: float) -> void:
	if _origin == null:
		return

	var dx := _get_aim_point().x - _origin.global_position.x
	if absf(dx) > deadzone:
		facing = signf(dx)

	for i in _flip_nodes.size():
		_flip_nodes[i].scale.x = _base_scale_x[i] * facing


func _get_aim_point() -> Vector2:
	if source == Source.TARGET_NODE and _target != null:
		return _target.global_position
	return _origin.get_global_mouse_position()
