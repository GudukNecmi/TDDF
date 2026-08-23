class_name PropShadow
extends Sprite2D
## The soft patch of ground under something. A separate node rather than part of
## anybody's artwork, so what colour a shadow is stays a property of the *map*
## and not of the character or prop standing on it.
##
## That separation is the whole point of the class. The player and the enemies
## are the same scenes on every map, so a desert's dark-orange shadow cannot live
## in them; and the shadow cannot be a global either, because the next map will
## want a different one. What each shadow does is ask - on ready - whether the
## world it has been placed in has a [ShadowPalette], and take its colour from
## there if it has. A map sets its shadows by putting one node in its own scene.
## A scene opened with no palette anywhere falls back to the colour authored
## here, so nothing depends on the palette existing.
##
## The texture is a soft radial disc generated on the spot rather than shipped as
## art, in the same way [BloodField] makes its specks, so there is no shadow PNG
## to keep in step with anything and the edge softness is an inspector value.

## Group every shadow joins, so a palette can find them all without being wired
## to any of them - including the ones on enemies that do not exist yet when the
## map loads.
const GROUP := &"prop_shadow"

## Colour of the shadow, used when the map has no [ShadowPalette] or when
## [member use_map_palette] is off. Multiplied over whatever it is drawn on.
@export var shadow_color := Color(0.45, 0.19, 0.10):
	set(value):
		shadow_color = value
		_apply()
## How dark the shadow is. Separate from the colour so a map can dial the whole
## set up or down without repicking a colour.
@export_range(0.0, 1.0) var shadow_opacity: float = 0.4:
	set(value):
		shadow_opacity = value
		_apply()
## Size of the patch in world pixels - width by height. Wider than it is tall
## reads as a shadow on the ground rather than a ball under the feet.
@export var shadow_scale := Vector2(30.0, 12.0):
	set(value):
		shadow_scale = value
		_apply()
## Where the patch sits relative to the node's origin. The origin of a character
## is at their feet, so this is usually a pixel or two down.
@export var shadow_offset := Vector2(0.0, -1.0):
	set(value):
		shadow_offset = value
		_apply()

@export_group("Map palette")
## Whether this shadow takes its colour from the map's [ShadowPalette]. Off pins
## it to the colour above, for anything that should look the same on every map.
@export var use_map_palette: bool = true
## Whether the palette is also allowed to scale the patch. Lets a brighter map
## with a higher sun shrink every shadow at once.
@export var palette_scales_size: bool = true

@export_group("Look")
## How hard the shadow's edge is. 0 is a soft smudge, 1 is a hard ellipse.
@export_range(0.0, 1.0) var edge_hardness: float = 0.35:
	set(value):
		edge_hardness = value
		if is_node_ready():
			texture = _build_texture()
			_apply()
## Resolution of the generated disc. Small is fine - it is blurred by definition.
@export var texture_size: int = 64

var _palette_scale: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)
	centered = true
	if texture == null:
		texture = _build_texture()

	if use_map_palette:
		var palette := ShadowPalette.get_active(self)
		if palette != null:
			palette.apply_to(self)

	_apply()


## Called by a [ShadowPalette] - either because this shadow asked on ready, or
## because the palette swept the group. Nothing else should call it; the
## inspector values are what a shadow is without a map to tell it otherwise.
func set_palette(colour: Color, opacity: float, size_scale: float) -> void:
	if not use_map_palette:
		return
	shadow_color = colour
	shadow_opacity = opacity
	_palette_scale = size_scale if palette_scales_size else 1.0
	_apply()


## [member Sprite2D.self_modulate] rather than `modulate`, so a parent tinting a
## whole character - a death fade - still reaches the shadow and multiplies with
## its colour instead of being overwritten by it.
func _apply() -> void:
	if not is_node_ready():
		return

	self_modulate = Color(
		shadow_color.r, shadow_color.g, shadow_color.b, shadow_opacity)
	position = shadow_offset

	var span := maxi(texture_size, 1)
	scale = shadow_scale * _palette_scale / float(span)


## A soft-edged white disc. The per-node colour tints it and the independent
## X/Y scale squashes it into an ellipse, so one texture covers every shadow in
## the game.
func _build_texture() -> Texture2D:
	var gradient := Gradient.new()
	var edge := clampf(edge_hardness, 0.0, 0.99)
	gradient.offsets = PackedFloat32Array([0.0, edge, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])

	var built := GradientTexture2D.new()
	built.gradient = gradient
	built.width = maxi(texture_size, 1)
	built.height = maxi(texture_size, 1)
	built.fill = GradientTexture2D.FILL_RADIAL
	built.fill_from = Vector2(0.5, 0.5)
	built.fill_to = Vector2(1.0, 0.5)
	return built
