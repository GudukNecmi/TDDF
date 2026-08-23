class_name ParallaxDrift
extends Node2D
## Slides a layer of scenery against the camera, so it reads as nearer to or
## further from the viewer than the ground the player walks on.
##
## This is deliberately not [ParallaxBackground] and [ParallaxLayer]. Those are
## built on a [CanvasLayer], which puts them in their own drawing order outside
## the world - they can only ever be behind everything or in front of everything,
## and they measure their scroll from the world origin, so a layer belonging to an
## area sitting a few thousand pixels away starts life thousands of pixels out of
## place. This is a plain [Node2D], so the layer z-orders against the rest of the
## scene like any other art, and the drift is measured from [member anchor_path] -
## a node inside the same area - so an area can be moved anywhere in the world
## without its parallax needing to be re-tuned.
##
## The whole of it is one line of arithmetic per frame. [member scroll_scale] is
## the same number [ParallaxLayer] calls motion scale: 1 is locked to the ground,
## above 1 sweeps past faster than the ground (nearer the viewer - overhead
## pipework, a gantry, a canopy), below 1 lags behind it (further away - a
## skyline). Only this node's own [member Node2D.position] is written, so the art
## underneath keeps whatever transform it was authored with.

## How fast this layer sweeps compared to the ground. 1 is locked to it.
@export var scroll_scale := Vector2(1.12, 1.12)
## Node the drift is measured from - the middle of the area this layer belongs
## to. At the anchor the layer sits exactly where it was authored, which is what
## makes the editor view and the game view agree.
@export var anchor_path: NodePath = ^".."
## Turns the drift off without unpicking the node, for checking the layer's true
## placement against the ground.
@export var enabled: bool = true

@onready var _anchor: Node2D = get_node_or_null(anchor_path) as Node2D

var _rest: Vector2
var _camera: CameraController


func _ready() -> void:
	_rest = position
	# The layer is repositioned outright every frame from the camera, so blending
	# it from where it was a physics tick ago would only ever smear it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	if not enabled or _anchor == null:
		position = _rest
		return

	var camera := _get_camera()
	if camera == null:
		position = _rest
		return

	# Moving the layer *against* the camera is what makes it cross the screen
	# faster than the world does: the screen position of a fixed object already
	# changes one-for-one with the camera, so the extra has to be added on top of
	# that, in the opposite direction.
	var from_anchor := camera.global_position - _anchor.global_position
	position = _rest - from_anchor * (scroll_scale - Vector2.ONE)


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
