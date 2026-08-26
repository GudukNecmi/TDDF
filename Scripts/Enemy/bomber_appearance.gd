class_name BomberAppearance
extends Node
## Dresses one bomber as it spawns, and puts the broken lamp on it when its head
## comes off.
##
## [b]It is [Enemy1Appearance] with the sets tied together.[/b] Same idea, same
## shared [VariantPicker] weighting - what the last bomber wore makes the next one
## less likely to wear it, so a crowd spreads itself across the colourways instead
## of clumping - and the same rule that only [member Sprite2D.texture] is ever
## written. The difference is that a bomber's body and head are not interchangeable
## with each other, so they are picked as one [BomberOutfit] rather than as two
## independent rolls.
##
## [b]The broken lamp is not a second death.[/b] The head comes off through the
## enemy's own [EnemyHeadPop], exactly as an Enemy1's does; this listens for that
## and swaps the picture on the way past. So a bomber killed before it lit itself
## dies an ordinary Enemy1 death whose only visible difference is its own artwork -
## which is precisely what the brief asks for - and a bomber killed after it lit
## itself loses its head the same way, on the same beat, through the same code.

## The colourways one is picked from. Empty leaves the bomber wearing whatever its
## scene shipped with.
@export var outfits: Array[BomberOutfit] = []

@export_group("Targets")
@export var head_path: NodePath = ^"../HeadAim/Head"
@export var body_path: NodePath = ^"../Visual/Body"
## The lamp's light, put out when the head is smashed. Optional.
@export var lamp_path: NodePath = ^"../HeadAim/Head/Lamp"
## The head separation watched for the swap. Left unresolved the bomber still
## dresses itself; its lamp simply survives its head coming off.
@export var head_pop_path: NodePath = ^"../HeadPop"

@export_group("Selection")
## How sharply an under-used outfit is favoured. See [member VariantPicker.bias].
@export var selection_bias: float = 1.6
## What the outfit used last is weighted by. See
## [member VariantPicker.repeat_penalty].
@export_range(0.0, 1.0) var repeat_penalty: float = 0.3

# Shared by every bomber in the process, for the same reason Enemy1's pickers are:
# a tally kept per enemy would be a tally of one and could not balance anything.
static var _outfit_picker := VariantPicker.new()

var _outfit: BomberOutfit
var _smashed: bool = false


func _ready() -> void:
	_dress()

	var pop := get_node_or_null(head_pop_path) as EnemyHeadPop
	if pop != null:
		pop.piece_separated.connect(_on_piece_separated)


## The colourway this bomber is wearing. Null when nothing was authored.
func get_outfit() -> BomberOutfit:
	return _outfit


## Puts the broken lamp on and switches the light off. Public and guarded, so a
## test - or anything else that smashes a lamp later - can do it without a death,
## and a second call cannot re-break a head that is already broken.
func smash_lamp() -> void:
	if _smashed:
		return
	_smashed = true

	var head := get_node_or_null(head_path) as Sprite2D
	if head != null and _outfit != null and _outfit.broken_head != null:
		head.texture = _outfit.broken_head

	var lamp := get_node_or_null(lamp_path) as Node2D
	if lamp != null:
		lamp.visible = false


## Only the head's own separation smashes the lamp. A knife or any other piece
## coming off the same body leaves it alone, which is why the carrier is asked
## which piece it is carrying rather than the first separation being assumed to be
## the head.
func _on_piece_separated(piece: DeathDebris) -> void:
	if piece == null:
		return
	var head := get_node_or_null(head_path) as Node2D
	if head != null and head.get_parent() == piece:
		smash_lamp()


## Re-applied per bomber rather than once, so retuning the weighting in the
## inspector takes effect on the next spawn instead of on the next restart.
func _dress() -> void:
	if outfits.is_empty():
		return

	_outfit_picker.bias = selection_bias
	_outfit_picker.repeat_penalty = repeat_penalty
	_outfit_picker.resize(outfits.size())

	var index := _outfit_picker.pick()
	if index < 0 or outfits[index] == null:
		return
	_outfit = outfits[index]

	_wear(body_path, _outfit.body)
	_wear(head_path, _outfit.head)


func _wear(path: NodePath, texture: Texture2D) -> void:
	if texture == null:
		return
	var sprite := get_node_or_null(path) as Sprite2D
	if sprite != null:
		sprite.texture = texture
