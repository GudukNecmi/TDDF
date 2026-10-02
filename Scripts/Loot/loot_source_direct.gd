class_name LootSourceDirect
extends LootSource
## The shared rules of a source that drops physical loot straight out of the
## pouch - whether it pays at all, how often, and how many - so the Charm and
## Health sources hold only what is their own.
##
## [b]Which encounter pays is data.[/b] [member site_kinds] names the run map
## point kinds this source pays for, read off the [LootContext] exactly as
## [member RunMapUpgradeReward.site_kinds] is; nothing on the screen ever asks.
## Every roll is taken from the bundle's own generator ([member LootContext.rng]).

## How the dropped loot looks.
@export var look: LootRewardLook
## The point kinds this source pays for. Empty pays for every fight the Loot
## Screen is opened for.
@export var site_kinds: Array[StringName] = []
## The chance that this source drops anything at all, 0..1.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## How many pieces it drops when it does.
@export_range(0, 16) var count_min: int = 1
@export_range(0, 16) var count_max: int = 1

@export_group("Wording")
## Under a piece once it has been taken.
@export var taken_text: String = "ALINDI"


func contribute(bundle: LootBundle, context: LootContext) -> void:
	if bundle == null or context == null or not pays_for(context.site_kind):
		return
	var rng := context.rng if context.rng != null else RandomNumberGenerator.new()
	if rng.randf() >= chance:
		return
	for _piece: int in roll_count(rng):
		var entry := _make_reward(rng, context)
		if entry == null:
			continue
		if entry.look == null:
			entry.look = look
		entry.resolved_text = taken_text
		bundle.add(entry)


## Whether a fight from a point of [param kind] is paid by this source.
func pays_for(kind: StringName) -> bool:
	return site_kinds.is_empty() or site_kinds.has(kind)


## How many pieces one drop is.
func roll_count(rng: RandomNumberGenerator) -> int:
	var low := mini(count_min, count_max)
	var high := maxi(count_min, count_max)
	return rng.randi_range(low, high)


## Override: one piece of loot, or null for nothing.
func _make_reward(_rng: RandomNumberGenerator, _context: LootContext) -> LootReward:
	return null
