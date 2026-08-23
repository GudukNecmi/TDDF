@tool
class_name PropArt
extends Sprite2D
## One piece of scenery, drawn from a set of interchangeable pictures.
##
## A desert wants five kinds of cactus and three kinds of bush without five
## cactus scenes and three bush scenes. This is that: drop the pictures into
## [member textures] in the inspector and the prop becomes however many props
## there are entries, picked between at random when it is placed.
##
## Where the prop stands is worked out here rather than hand-tuned per picture:
## the node's origin is placed on the middle of the bottom edge of the *opaque*
## part of the texture, so a prop stands on its own base whatever the padding
## around the drawing is, and swaying it is a rotation about that base rather
## than about the middle of a canvas.
##
## [b]How big it is, is the picture's own business.[/b] By default a prop is drawn
## at exactly the size it was painted - one texture pixel to one world pixel - so
## the desert is laid out at the proportions the artwork was authored with and a
## cactus drawn taller than another simply is taller. Nothing here resizes it, the
## scatter is not asked to roll a size for it, and there is no multiplier anywhere
## between the PNG and the screen. See [member size_mode].
##
## The alternative is kept as a mode rather than deleted, because normalising a
## set of drawings to one height is genuinely what some sets of art want - a kind
## of plant drawn at whatever size fitted on the canvas. It is simply not what
## this desert's props want, so it is off.
##
## Adding a sixth cactus is therefore dropping a PNG into the array. There is no
## threshold, offset or name here that a new entry would have to be added to.

## How the picture's size is decided.
enum SizeMode {
	## Drawn at the size it was painted: one texture pixel to one world pixel,
	## with no scaling of any kind applied to it. The default, and what a set of
	## drawings already at the right relative sizes wants.
	AUTHORED_PIXELS,
	## Every picture scaled so its opaque part is [member reference_height] tall,
	## which turns a set of drawings at unrelated sizes into one consistent kind
	## of plant.
	REFERENCE_HEIGHT,
}

## Pictures this prop can be drawn as. One is chosen at random on ready.
@export var textures: Array[Texture2D] = []:
	set(value):
		textures = value
		_apply()
## Whether the artwork is drawn at its own size or normalised to a common height.
@export var size_mode: SizeMode = SizeMode.AUTHORED_PIXELS:
	set(value):
		size_mode = value
		_apply()
## Height the opaque part of whichever picture is chosen is scaled to, in pixels
## at this node's own scale of 1. Only read under
## [constant SizeMode.REFERENCE_HEIGHT]; ignored entirely by the default mode,
## where the picture's own dimensions are the size.
@export var reference_height: float = 80.0:
	set(value):
		reference_height = maxf(value, 1.0)
		_apply()
## Chance the artwork is mirrored left-to-right, which doubles the apparent
## variety for free. The mirroring is about the node's origin, so the prop still
## stands on the same spot.
@export_range(0.0, 1.0) var mirror_chance: float = 0.5

## Index shown in the editor and used at runtime when [member randomise] is off.
## -1 picks at random.
@export var texture_index: int = -1:
	set(value):
		texture_index = value
		_apply()
## Whether a fresh picture is picked when the prop enters the running game. Off
## keeps whatever [member texture_index] says, for a prop placed by hand that
## should stay the one that was placed.
@export var randomise: bool = true

var _mirrored: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint() and randomise:
		texture_index = -1
		_mirrored = randf() < mirror_chance
	_apply()


## The size of the artwork as drawn, in world pixels. What a shadow or a
## collision shape should be measured against when one wants to fit the plant
## rather than be authored to it.
func get_content_size() -> Vector2:
	if texture == null:
		return Vector2.ZERO
	return SpriteBounds.used_rect(texture).size * absf(scale.y)


## Picks the picture, stands it on its base and sizes it. Cheap enough to run on
## every inspector change, which is what keeps the editor honest about what the
## game will show.
func _apply() -> void:
	if textures.is_empty():
		return

	var index := texture_index
	if index < 0 or index >= textures.size():
		# Deterministic with an inspector attached, so opening or nudging the scene
		# never rolls a different picture and saves it into the file. The random
		# pick is a *runtime* thing, made once in [method _ready].
		index = 0 if Engine.is_editor_hint() else randi() % textures.size()
	var chosen := textures[index]
	if chosen == null:
		return

	texture = chosen
	centered = false

	var rect := SpriteBounds.used_rect(chosen)
	if rect.size.y <= 0.0:
		return

	# The origin lands on the middle of the bottom edge of the drawing: offset is
	# in texture pixels and is applied before scale, so this is the same number
	# whatever size the prop ends up.
	offset = -Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)

	# 1.0 under the default mode, so the only thing ever written to `scale` is the
	# mirror. The prop is drawn at the dimensions of its PNG and nothing multiplies
	# them.
	var factor := 1.0
	if size_mode == SizeMode.REFERENCE_HEIGHT:
		factor = reference_height / rect.size.y
	scale = Vector2(-factor if _mirrored else factor, factor)
