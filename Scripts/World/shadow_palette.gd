class_name ShadowPalette
extends Node
## What colour shadows are in this place. One node per map, sitting in the map's
## own scene, holding the numbers every [PropShadow] in it should use.
##
## Shadows belong to the map, not to the things casting them: the player and the
## enemies are the same scenes wherever they are standing, so a desert's
## dark-orange shadow cannot be authored into them, and it must not be baked into
## a global either because the next map will want a cold blue one. This node is
## the seam - the desert's colour lives in the desert's scene, and moving to
## another map is another palette with other numbers in it.
##
## It reaches shadows two ways, and needs both. Anything already in the tree is
## swept on ready; anything that arrives later - every enemy the run spawns -
## asks for the palette itself as it enters. Neither has to know the order the
## other happened in.

## Group this joins, so a shadow can find it without a path across the scene.
const GROUP := &"shadow_palette"

## Colour every shadow on this map takes. The desert's is a dark orange picked
## off the concept art; another map sets another colour here and changes nothing
## else anywhere.
@export var shadow_color := Color(0.45, 0.19, 0.10):
	set(value):
		shadow_color = value
		_push()
## How dark the shadows are on this map.
@export_range(0.0, 1.0) var shadow_opacity: float = 0.4:
	set(value):
		shadow_opacity = value
		_push()
## Multiplier on every shadow's authored size, for a map whose light sits higher
## or lower. Individual shadows can opt out with
## [member PropShadow.palette_scales_size].
@export var size_scale: float = 1.0:
	set(value):
		size_scale = maxf(value, 0.0)
		_push()


func _ready() -> void:
	add_to_group(GROUP)
	_push()


## The palette a shadow should read, found by group. Null means this map has none
## and every shadow keeps whatever colour it was authored with.
static func get_active(from_node: Node) -> ShadowPalette:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as ShadowPalette


## Hands this palette's numbers to one shadow. Called by a shadow asking on ready
## and by the sweep below; the shadow itself decides whether to take them.
func apply_to(shadow: PropShadow) -> void:
	if shadow == null:
		return
	shadow.set_palette(shadow_color, shadow_opacity, size_scale)


## Repaints every shadow currently in the world. Runs on ready and on every
## inspector change, so tuning the map's shadow colour is immediate rather than
## something that only shows on the next scene load.
func _push() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(PropShadow.GROUP):
		apply_to(node as PropShadow)
