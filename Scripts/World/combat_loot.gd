class_name CombatLoot
extends RefCounted
## The blood, brass and paperwork one just-finished fight has handed over, held
## here for exactly as long as [HorseCartScreen] is open to let the player claim
## it and nowhere else - see [method WorldMapCombatBridge.get_combat_loot], which
## is the one place this is ever asked for.
##
## [b]It is not a second inventory.[/b] What one stack here actually is -
## identity, a display name, an icon, a category, how many, and the ceiling one
## stack can hold - is exactly [RunItemStack], the same class [RunInventory]'s
## own row is built out of, so a loot stack transfers into the Horse Inventory as
## itself rather than being translated into a second shape first. This class only
## ever holds a loose list of them: there is no slot count, no capacity and no
## ceiling of its own, because loot still waiting to be claimed is never made to
## compete with itself for room the way the Horse Inventory's own row does.
##
## [b]Nothing here decides what a fight is worth.[/b] Every add method below is
## a thin wrapper the same shape [method RunInventory.add_ammo] and its own
## siblings already are - it works out one category's identity and stack ceiling
## and leaves what to put in it, and how much, to whoever calls it. This pass
## adds none of that: what a fight actually drops is deliberately left for the
## loot-generation work still to come, and every one of these methods is here
## only so that work has a clean, ready seam to call into.

## One stack per kind of loot, in the order it was added. Never slot-limited -
## see the class doc - so a heavy fight can hand over as many kinds of loot as
## it actually produced without any of them crowding another out.
var stacks: Array[RunItemStack] = []


func is_empty() -> bool:
	return stacks.is_empty()


## Every stack currently held, in order. A copy, so [HorseCartScreen] reading
## this cannot reach in and edit a stack directly - the same guarantee
## [method RunInventory.get_slots] already makes for the Horse Inventory's own
## row.
func get_stacks() -> Array[RunItemStack]:
	return stacks.duplicate()


## The one place anything ever enters this loot. Tops up a stack already
## carrying [param item_id] before it opens a new one - the same stacking
## [method RunInventory.add_item] uses - so loot of the same kind piles onto
## itself instead of spreading across a row of ones and twos. Returns how much
## of [param amount] actually found a stack, which is always all of it: there is
## no ceiling here beyond one stack's own [param max_count].
func add(
	item_id: StringName,
	display_name: String,
	amount: int,
	max_count: int = 1,
	category: StringName = &"",
	icon: Texture2D = null,
	payload: Variant = null
) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var remaining := amount
	for stack: RunItemStack in stacks:
		if remaining <= 0:
			break
		if stack.item_id != item_id:
			continue
		var room := stack.get_free_room()
		if room <= 0:
			continue
		var taken := mini(room, remaining)
		stack.count += taken
		remaining -= taken

	while remaining > 0:
		var stack := RunItemStack.new()
		stack.item_id = item_id
		stack.display_name = display_name
		stack.icon = icon
		stack.category = category
		stack.max_count = maxi(max_count, 1)
		stack.payload = payload
		var taken := mini(stack.max_count, remaining)
		stack.count = taken
		stacks.append(stack)
		remaining -= taken

	return amount - remaining


## Gems - the first of the four loot categories a combat can hand over. Left
## for a later pass to actually call with a real identity and a real amount;
## see the class doc.
func add_gem(
	item_id: StringName, display_name: String, amount: int = 1,
	max_count: int = 99, icon: Texture2D = null, payload: Variant = null
) -> int:
	return add(item_id, display_name, amount, max_count, &"gem", icon, payload)


## Hearts, one non-stacking stack apiece - the same shape
## [method RunInventory.add_heart] already gives them once they are claimed,
## so a Heart never reads differently depending on which side of the transfer
## it is standing on.
func add_heart(amount: int = 1) -> int:
	var added := 0
	for _i in maxi(amount, 0):
		if add(&"heart", "Heart", 1, 1, &"heart") <= 0:
			break
		added += 1
	return added


## Ammunition for [param ammo_type]. [param max_count] is asked of the caller
## rather than worked out here, so this class never has to duplicate
## [method RunInventory.get_ammo_max_stack]'s own formula.
func add_ammo(ammo_type: AmmoType, amount: int, max_count: int) -> int:
	if ammo_type == null:
		return 0
	return add(ammo_type.id, ammo_type.get_plural_name(), amount, max_count, &"ammo",
		ammo_type.icon, ammo_type)


## What a boss's body hands over - a lead on the next contract, the same shape
## a beaten boss already hands over directly through [SurrenderKnowledge].
## Non-stacking: two pieces of information are two stacks, never one counted
## twice.
func add_boss_info(item_id: StringName, display_name: String, payload: Variant = null) -> int:
	return add(item_id, display_name, 1, 1, &"boss_info", null, payload)


## Takes up to [param amount] off the stack at [param index], freeing it once
## it is empty - the loot twin of [method RunInventory.remove_item], indexed
## rather than keyed on an id because this row has no slots of its own to look
## one up in. Returns how much was actually taken, which is at most what the
## stack was still holding: never more than it had, and the stack itself is
## simply left smaller when only part of it goes.
func remove_from_stack(index: int, amount: int) -> int:
	if index < 0 or index >= stacks.size():
		return 0
	var stack := stacks[index]
	var taken := clampi(amount, 0, stack.count)
	if taken <= 0:
		return 0
	stack.count -= taken
	if stack.count <= 0:
		stacks.remove_at(index)
	return taken
