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
##
## Only read when [member fence_path] names nothing that can be measured - see
## there. A map whose own walls state its extent leaves this alone.
@export var region := Rect2(-4000.0, -2500.0, 8000.0, 5000.0)
## The body whose collision shapes fence this map in, when it has one - the
## [code]Bounds[/code] wall box the player cannot walk out of.
##
## [b]The walls are how big the map is, and nothing else is.[/b] The playable area
## is adjusted by moving and scaling those walls in the editor, so a rectangle
## typed in beside them is a second copy of a number that has already been stated -
## and one that goes quietly wrong the moment the walls move. Pointed at the fence,
## this measures the inner faces of it, and the camera is exactly as large as the
## ground the player can actually reach, on a map of any size, without this node
## being touched again.
##
## It is also what a shell scene several maps inherit wants: the shell states
## [i]that[/i] the camera is bounded by the walls, and each map that inherits it
## states where its own walls are - so a region added later is framed correctly
## with nothing added to it.
##
## Empty - the default - falls back to [member region], which is what the base and
## the arena, whose extents are authored rather than fenced, keep doing.
@export var fence_path: NodePath
## Whether the limits are pushed as the map loads. Off leaves whatever the
## camera was authored with, for a map that wants to set them some other way.
@export var apply_on_ready: bool = true


func _ready() -> void:
	if apply_on_ready:
		apply()


## The rectangle in world space - measured off the fence when there is one to
## measure, and the authored [member region] otherwise.
func get_world_region() -> Rect2:
	var fenced := _measure_fence()
	if fenced.has_area():
		return fenced
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


## The inside of the fence named by [member fence_path], in world space, or an
## empty rectangle when there is no fence to measure - which the caller above
## reads as "this map has no walls to speak for it" and falls back on.
##
## The walls are taken together rather than one at a time: their outer edges are
## the box the map is drawn inside, and stepping that box in by the thickness of
## the thinnest of them lands on the faces the player's own collision already
## stops against. A fence built of thicker or thinner walls than these needs no
## change here - the thickness is measured, never assumed.
func _measure_fence() -> Rect2:
	var fence := get_node_or_null(fence_path) as Node2D
	if fence == null:
		return Rect2()

	var outside := Rect2()
	var thickness: float = 0.0
	var found: bool = false

	for child: Node in fence.get_children():
		var wall := child as CollisionShape2D
		if wall == null or wall.disabled:
			continue
		var shape := wall.shape as RectangleShape2D
		if shape == null:
			continue

		var size := (shape.size * wall.global_scale).abs()
		var box := Rect2(wall.global_position - size * 0.5, size)
		outside = box if not found else outside.merge(box)
		var thinnest := minf(size.x, size.y)
		thickness = thinnest if not found else minf(thickness, thinnest)
		found = true

	if not found:
		return Rect2()
	return outside.grow(-thickness)


func _at_least_view_sized(area: Rect2, camera: Camera2D) -> Rect2:
	var view := camera.get_viewport_rect().size / camera.zoom
	if area.size.x >= view.x and area.size.y >= view.y:
		return area

	var size := Vector2(maxf(area.size.x, view.x), maxf(area.size.y, view.y))
	return Rect2(area.get_center() - size * 0.5, size)
