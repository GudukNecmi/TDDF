class_name HeldItemFlip
extends Node
## Mirrors a held item's artwork so it never hangs upside down once the aim
## crosses vertical.
##
## Held-item art is drawn pointing along +X and the item itself is rotated to the
## aim, so the moment the aim passes straight up or straight down the rotation
## alone leaves the artwork inverted. Mirroring the art node on Y rights it
## again - on a node already rotated past 90 degrees that reads as a horizontal
## flip.
##
## This writes nothing but `scale.y` on the nodes it is given. [member
## Node2D.rotation] is left exactly as the aiming code set it, so the item still
## turns through a full 360 and its muzzle, its reach and its aim are all
## untouched - and an AnimationPlayer or a [SoftFollow] driving the same art is
## never fought.
##
## The art nodes must sit at zero rotation *relative to the aiming node*, with
## the aiming node carrying the turn. That is what makes the mirror land on the
## aim axis rather than on some angle of its own. Put the art under a plain
## [Node2D] and point this at that node when the sprite itself needs a fixed
## rotation to line its drawing up with +X.
##
## Every held item shares this - the shotgun and the collector's hand today, and
## any future weapon by adding the node and listing its art.

## Node whose [member Node2D.global_rotation] *is* the aim. Defaults to this
## component's parent, which is the item itself.
@export var aim_path: NodePath = ^".."
## Art pivots mirrored on Y. Their own scale magnitude is preserved, so this
## works just as well on a node that is already scaled.
@export var art_paths: Array[NodePath] = []
## How far past straight up or down the aim must lean before the art mirrors.
## Purely a dead zone against flicker: at exactly vertical the aim's X component
## is zero and the tiniest wobble would otherwise flip the art every frame.
@export var deadzone: float = 0.06

## -1 while the item is aimed left, +1 while it is aimed right.
var facing: float = 1.0

@onready var _aim: Node2D = get_node_or_null(aim_path) as Node2D

var _art_nodes: Array[Node2D] = []
var _base_scale_y: Array[float] = []


func _ready() -> void:
	for path: NodePath in art_paths:
		var node := get_node_or_null(path) as Node2D
		if node == null:
			continue
		_art_nodes.append(node)
		_base_scale_y.append(absf(node.scale.y))


func _physics_process(_delta: float) -> void:
	if _aim == null:
		return

	# The aim's own X component, read straight off its rotation, so this needs no
	# opinion about where the item is pointing or who decided that.
	var aim_x := cos(_aim.global_rotation)
	if aim_x > deadzone:
		facing = 1.0
	elif aim_x < -deadzone:
		facing = -1.0

	for i in _art_nodes.size():
		_art_nodes[i].scale.y = _base_scale_y[i] * facing
