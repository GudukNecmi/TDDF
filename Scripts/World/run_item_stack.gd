class_name RunItemStack
extends RefCounted
## One occupied slot in the [RunInventory]: what it is, how many of it are
## piled here, and how many ever could be.
##
## [b]It is run state, not authored content[/b] - a [RefCounted] rather than a
## [Resource], the same reasoning [AmmoReserve] is built on: a slot's count
## belongs to this run and nothing else, and should never be saveable to or
## shared through a file on disk.
##
## [member item_id] is the whole of what "the same item" means - see rule 14
## of the run inventory phase. Two stacks only ever merge when their ids match,
## so two different weapons, two different upgrades, or two different bounty
## posters can never pile onto one slot by accident, however similar their
## names read.
##
## [member payload] is optional and is never read by [RunInventory] itself. It
## is the seam a later system reaches an item's real identity through without
## this class needing to know what an [AmmoType], a [WeaponDefinition] or a
## [Bounty] is - see [method RunInventory.add_ammo] and its siblings, which are
## the only things that ever fill it in.

## The identity key stacks are matched on. Never shown to the player.
var item_id: StringName = &""
## What the slot prints.
var display_name: String = ""
## Picture for the slot. Left null, the UI falls back to a short label.
var icon: Texture2D
## Free-form grouping label - "ammo", "weapon", "heart", "bounty_poster",
## "treasure_map", "loot" - read only by presentation. Nothing in
## [RunInventory] ever branches behaviour on it.
var category: StringName = &""
## How many are piled here right now.
var count: int = 0
## The most this one slot can ever hold. 1 for a non-stackable item; for
## ammunition, [code]weapon_base_ammo_capacity * 4[/code] - see
## [method RunInventory.get_ammo_max_stack].
var max_count: int = 1
## The resource this item actually is, for a later system to read without
## [RunInventory] knowing what it is. Null for anything that has none.
var payload: Variant = null


## How much more this slot could take before [method add_ammo] et al. would
## have to open a second one.
func get_free_room() -> int:
	return maxi(max_count - count, 0)


func is_full() -> bool:
	return count >= max_count


## What the slot prints: the count against the ceiling for anything stackable,
## the bare name for anything that is not - a lone bounty poster or weapon
## does not want to read "1 / 1".
func describe() -> String:
	if max_count > 1:
		return "%s  %d / %d" % [display_name, count, max_count]
	return display_name
