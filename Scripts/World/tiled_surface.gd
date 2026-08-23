@tool
class_name TiledSurface
extends Polygon2D
## A rectangle of repeating texture: the arena's floorboards, and the boards that
## run along its walls.
##
## It is a [Polygon2D] rather than a [Sprite2D] because the texture has to be
## turned *inside* the rectangle rather than with it. A sprite can only be rotated
## as a whole, so laying boards along a wall that runs down the screen would mean
## rotating the node and then undoing that rotation in its position and its size;
## a polygon maps the texture through its own transform, so the shape stays a
## plain axis-aligned strip and only the grain turns.
##
## Everything about how the texture sits is an inspector field, and nothing about
## it is decided here:
##
##   * [member surface_size] is the area covered, in world pixels, measured from
##     the node's own position - so moving the node moves the surface and nothing
##     has to agree with it in code
##   * [member tile_size] is how much of the world one tile of the texture covers.
##     This is the main dial: larger is bigger boards, fewer repeats
##   * [member tile_stretch] stretches that tile along the texture's own axes, so
##     a wall can run long boards down its length without also making them thick
##   * [member texture_angle] turns the grain within the rectangle
##   * [member Polygon2D.color] tints what is drawn, which is how the walls are
##     kept darker than the floor they meet
##
## The stretch and the angle are applied in that order, so [member tile_stretch]
## always means "along the boards" and "across the boards" however the surface is
## turned - a wall laid down the screen and one laid across it can share the same
## numbers.

## The area covered, in world pixels, with the node's position at its top-left
## corner. This is the whole of what decides the shape.
@export var surface_size := Vector2(1600.0, 900.0):
	set(value):
		surface_size = value
		_apply()

@export_group("Texture")
## How many world pixels one full tile of the texture covers. The main size dial:
## raise it for bigger, coarser boards and fewer repeats across the surface.
@export var tile_size: float = 700.0:
	set(value):
		tile_size = value
		_apply()
## Stretches one tile along the texture's own axes. X runs along the boards, Y
## across them, whatever [member texture_angle] is - so 3 on X gives boards three
## times as long without making them any thicker.
@export var tile_stretch := Vector2.ONE:
	set(value):
		tile_stretch = value
		_apply()
## Turns the grain inside the rectangle, in degrees. 90 lays the boards down the
## screen instead of across it, which is what the left and right walls want.
@export_range(-180.0, 180.0, 1.0) var texture_angle: float = 0.0:
	set(value):
		texture_angle = value
		_apply()


## The texture last measured for. [member Polygon2D.texture] is the base class's
## own field and cannot be intercepted when it is set, so swapping the artwork in
## the inspector is noticed rather than announced - see [method _process].
var _measured: Texture2D


func _ready() -> void:
	_apply()
	# The watch below is only ever worth running with an inspector attached; in a
	# running game the texture is whatever the scene was saved with.
	set_process(Engine.is_editor_hint())


## Editor only. Dropping a different texture on the node has to re-measure the
## tiling, and there is no signal for it.
func _process(_delta: float) -> void:
	if texture == _measured:
		return
	_measured = texture
	_apply()


## Rebuilds the rectangle and the texture transform from the fields above. Cheap
## enough to run on every change, which is what keeps the editor honest about what
## the game will look like.
func _apply() -> void:
	polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(surface_size.x, 0.0),
		surface_size,
		Vector2(0.0, surface_size.y),
	])

	# Without this the texture is clamped and one tile is all that is ever drawn.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_rotation = deg_to_rad(texture_angle)

	if texture == null:
		return

	# Polygon2D's scale is "how many times the texture fits", which is the
	# reciprocal of how much ground a tile covers - so this is where the friendly
	# number above is turned into the one the node actually wants.
	var tex := Vector2(texture.get_size())
	var span_x := maxf(tile_size * tile_stretch.x, 0.001)
	var span_y := maxf(tile_size * tile_stretch.y, 0.001)
	texture_scale = Vector2(tex.x / span_x, tex.y / span_y)
