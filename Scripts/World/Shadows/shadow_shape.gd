class_name ShadowShape
extends Node2D
## The node one contributor's projected silhouette is actually drawn on: a fan of
## triangles handed straight to the canvas, textured with the source's own artwork.
##
## [b]It exists because rebuilding a mesh is expensive and appending to a canvas is
## not.[/b] Every point of a shadow is projected afresh whenever the thing casting
## it moves, so the geometry underneath a walking figure is new every frame. Handing
## that to an [ArrayMesh] means destroying and recreating a rendering-server surface
## each time - measured at around fifty microseconds a part in a full scene, which a
## crowd cannot afford. A canvas item's triangle array is the engine's own path for
## geometry that changes every frame: the points are simply the next drawing
## command, and there is no resource to churn.
##
## [b]It holds no logic of its own.[/b] It does not know what it is drawing, where
## the sun is or what a shadow even is - [ShadowGroup] projects the points and hands
## them over. That is deliberate: the projection has one home, and this is a
## surface to put the answer on.
##
## The points are in the group's own space, so the container this hangs under
## carries the object's ground position and this node stays at the origin.

## Empty bone and weight arrays, so the texture can be reached in the call that
## takes them. Held as constants rather than built at every draw.
static var _no_bones := PackedInt32Array()
static var _no_weights := PackedFloat32Array()

var _indices := PackedInt32Array()
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _texture: Texture2D


func _init() -> void:
	y_sort_enabled = false


## Takes the geometry for this frame and asks to be redrawn with it.
##
## The arrays are taken as they are, not copied: the group keeps and refills the
## same buffers, so nothing is allocated per frame on either side.
func set_shape(indices: PackedInt32Array, points: PackedVector2Array,
		colors: PackedColorArray, uvs: PackedVector2Array, texture: Texture2D) -> void:
	_indices = indices
	_points = points
	_colors = colors
	_uvs = uvs
	_texture = texture
	queue_redraw()


## Drops the geometry, for a part that has stopped contributing.
func clear_shape() -> void:
	_points = PackedVector2Array()
	_indices = PackedInt32Array()
	queue_redraw()


## The projected points, in group space. For a test or a debug readout - this is
## where a shadow's silhouette actually is.
func get_points() -> PackedVector2Array:
	return _points


## How high up the object each of those points was drawn, carried in the red
## channel - see [ShadowGroup.apply].
func get_colors() -> PackedColorArray:
	return _colors


## The artwork the silhouette is cut from - the source sprite's own texture.
func get_texture() -> Texture2D:
	return _texture


## Whether there is anything here to draw.
func has_shape() -> bool:
	return _texture != null and _points.size() >= 3 and not _indices.is_empty()


func _draw() -> void:
	if not has_shape():
		return
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), _indices, _points, _colors, _uvs,
		_no_bones, _no_weights, _texture.get_rid())
