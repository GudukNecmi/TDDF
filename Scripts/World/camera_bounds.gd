class_name CameraBounds
extends Node2D
## How far the camera may roam on this map.
##
## The limits used to be authored on the player's own camera, which meant the
## size of the arena lived inside the *player* - so a second map could not be a
## different size without editing a scene that has nothing to do with which map
## is being played. This node moves that fact to where it belongs: the map states
## its own extent, and the player is carried into it unchanged.
##
## It is the same arrangement [Teleporter] already uses when it hands the camera
## a destination's bounds on arrival, so nothing new is being introduced - the
## map is simply the first place the camera is told about, before anybody has
## teleported anywhere.
##
## A rectangle smaller than the screen is grown around its own centre first, for
## the same reason the teleporter grows one: a limit box the camera cannot fit
## inside pins it to the middle and shows empty world as bars down the edges.

## The playable rectangle, in this node's own local space.
@export var region := Rect2(-4000.0, -2500.0, 8000.0, 5000.0)
## Whether the limits are pushed as the map loads. Off leaves whatever the
## camera was authored with, for a map that wants to set them some other way.
@export var apply_on_ready: bool = true


func _ready() -> void:
	if apply_on_ready:
		apply()


## The rectangle in world space.
func get_world_region() -> Rect2:
	return Rect2(global_position + region.position, region.size)


## Hands the region to whichever camera is active. Safe to call at any time - a
## map that grows partway through a run can call it again.
func apply() -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	var box := _at_least_view_sized(get_world_region(), camera)
	camera.limit_left = int(box.position.x)
	camera.limit_top = int(box.position.y)
	camera.limit_right = int(box.end.x)
	camera.limit_bottom = int(box.end.y)
	camera.reset_smoothing()


func _at_least_view_sized(area: Rect2, camera: Camera2D) -> Rect2:
	var view := camera.get_viewport_rect().size / camera.zoom
	if area.size.x >= view.x and area.size.y >= view.y:
		return area

	var size := Vector2(maxf(area.size.x, view.x), maxf(area.size.y, view.y))
	return Rect2(area.get_center() - size * 0.5, size)
