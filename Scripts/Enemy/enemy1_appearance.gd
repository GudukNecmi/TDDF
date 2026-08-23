class_name Enemy1Appearance
extends Node
## Dresses one Enemy1 as it spawns: a face, a body and a knife picked out of the
## sets below, so a crowd of them is visibly a crowd of individuals rather than
## one sprite repeated.
##
## Every variant is an inspector list of textures, so adding a face is dropping a
## PNG into the array and nothing else. The legs are deliberately not in here -
## every Enemy1 shares the same pair, so they stay plain sprites in the scene.
##
## Selection is not uniform random. The three [VariantPicker]s are [code]static[/code],
## so they are shared by every enemy in the process and outlive the run: what the
## last enemy wore is what makes the next one less likely to wear it. Over a long
## session that pulls the population towards every variant appearing about
## equally often, while keeping the order unpredictable enough that no repeating
## pattern is visible. See [VariantPicker] for the weighting itself.
##
## Only [member Sprite2D.texture] is written, once, before the first frame. The
## enemy's aim pivots, hitboxes, knife swing and idle are all untouched - which
## is why the variants are interchangeable in the first place: they are drawn on
## one shared canvas layout, so swapping a texture cannot move anything.

## Faces one is picked from.
@export var head_textures: Array[Texture2D] = []
## Bodies one is picked from.
@export var body_textures: Array[Texture2D] = []
## Knives one is picked from.
@export var knife_textures: Array[Texture2D] = []

@export_group("Targets")
@export var head_path: NodePath = ^"../HeadAim/Head"
@export var body_path: NodePath = ^"../Visual/Body"
@export var knife_path: NodePath = ^"../KnifeAim/KnifeHand/Knife"

@export_group("Selection")
## How sharply an under-used variant is favoured. See [member VariantPicker.bias].
@export var selection_bias: float = 1.6
## What the variant used last is weighted by. See
## [member VariantPicker.repeat_penalty].
@export_range(0.0, 1.0) var repeat_penalty: float = 0.3

# Shared by every Enemy1 in the process. That sharing is the whole point - a
# tally kept per enemy would be a tally of one and could not balance anything.
static var _head_picker := VariantPicker.new()
static var _body_picker := VariantPicker.new()
static var _knife_picker := VariantPicker.new()


func _ready() -> void:
	_dress(head_path, head_textures, _head_picker)
	_dress(body_path, body_textures, _body_picker)
	_dress(knife_path, knife_textures, _knife_picker)


## Leaves the sprite's own texture in place when the set is empty, so an enemy
## with nothing configured still looks like whatever the scene shipped with.
func _dress(path: NodePath, textures: Array[Texture2D], picker: VariantPicker) -> void:
	if textures.is_empty():
		return

	var sprite := get_node_or_null(path) as Sprite2D
	if sprite == null:
		return

	# Re-applied per enemy rather than once, so retuning the numbers in the
	# inspector takes effect on the next spawn without a restart.
	picker.bias = selection_bias
	picker.repeat_penalty = repeat_penalty
	picker.resize(textures.size())

	var index := picker.pick()
	if index >= 0 and textures[index] != null:
		sprite.texture = textures[index]
