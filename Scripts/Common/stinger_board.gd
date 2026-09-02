class_name StingerBoard
extends SoundBank
## The reusable one-shot cinematic-cue mechanism: Bandit Encounter, Boss
## Discovery, Victory/Win, Decision Start, Decision Result, Fight Start,
## Extraction - every short cue the presentation layer wants to play at an
## exact instant, through one set of pooled voices.
##
## [b]It is [SoundBank], not a second player.[/b] Every voice, the bus, the
## level and the pitch spread are exactly [SoundBank]'s own - this only adds
## what a bank of single sounds does not have: a name that means "one of
## several", picked at random and, where it matters, never the same one
## twice in a row.
##
## [b]The picking is [VariantPicker], not a fresh [method randi] roll.[/b]
## [member repeat_penalty] of 0 on a set - the default - is what makes "the
## same Win sound must never play twice consecutively" and "do not play the
## same fight track twice consecutively" true by construction rather than by
## a caller remembering the last one itself; a set authored with a softer
## penalty (or just one entry) works exactly as well and needs nothing
## special from a caller either way.
##
## One instance, shared by every destination - placed on [RunHUD] beside
## [TravelLetterbox], the same "one reusable presentation piece, not one per
## destination" rule that controller already keeps. World Map bandit
## contact, a bounty camp, a boss's discovery, a kill-cam's win beat and the
## decision screen all ask this same board for their cue by name.

## Name -> [code]Array[AudioStream][/code]. A set with one entry behaves like
## an ordinary named sound; a set with several is where the variety and the
## no-repeat guarantee actually show up.
@export var variant_sets: Dictionary = {}
## Name -> how strongly that set refuses to repeat its last pick, as
## [member VariantPicker.repeat_penalty]: 0 forbids an immediate repeat
## outright, 1 allows it freely. A name with nothing here uses
## [member default_repeat_penalty].
@export var repeat_penalties: Dictionary = {}
## The penalty a set uses when [member repeat_penalties] says nothing about
## it. 0 - the default - is what every cue in this project is asked to be:
## never the same pick twice running.
@export_range(0.0, 1.0) var default_repeat_penalty: float = 0.0

## Group this joins, so any system - [WorldMapCombatBridge], [KillCam] -
## can reach the one board in the world without a [NodePath] across a scene
## it does not own, the same convention [TravelLetterbox] already uses for
## itself.
const GROUP := &"stinger_board"

## Name -> [VariantPicker], built lazily the first time a set is actually
## asked for, so a board authored with sets nobody has played yet costs
## nothing beyond the dictionary itself.
var _pickers: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


## The one stinger board in the world, or null when it has none - which every
## caller reads as "there is no cue to play, so the moment simply plays out
## silent the way it always did before this existed".
static func get_active(from_node: Node) -> StingerBoard:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as StingerBoard


## Plays one randomly-picked stream from [param set_name]'s own array through
## the ordinary pooled voices - see [method SoundBank.play_stream]. A name
## with nothing registered, or an empty array, plays nothing and returns
## null, exactly as an unknown name already does on [method SoundBank.play].
func play_variant(set_name: StringName, volume_db_offset: float = 0.0) -> AudioStreamPlayer:
	var stream := _pick(set_name)
	return play_stream(stream, volume_db_offset)


## Whether [param set_name] has anything registered to pick from.
func has_variant_set(set_name: StringName) -> bool:
	var set := variant_sets.get(set_name) as Array
	return set != null and not set.is_empty()


func _pick(set_name: StringName) -> AudioStream:
	var set := variant_sets.get(set_name) as Array
	if set == null or set.is_empty():
		return null
	if set.size() == 1:
		return set[0] as AudioStream

	var picker := _picker_for(set_name, set.size())
	var index := picker.pick()
	if index < 0 or index >= set.size():
		return null
	return set[index] as AudioStream


func _picker_for(set_name: StringName, variant_count: int) -> VariantPicker:
	var picker := _pickers.get(set_name) as VariantPicker
	if picker == null:
		var penalty: float = repeat_penalties.get(set_name, default_repeat_penalty)
		# Bias left at VariantPicker's own default: the "never twice running"
		# guarantee this board exists for comes entirely from the repeat
		# penalty, not from how hard an under-used variant is pulled back.
		picker = VariantPicker.new(variant_count, 1.6, penalty)
		_pickers[set_name] = picker
	else:
		picker.resize(variant_count)
	return picker
