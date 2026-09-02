class_name RunInventory
extends Node
## The player's one run inventory: a fixed row of slots that everything the
## run carries - ammunition, weapons, bounty posters, treasure maps, loot - is
## counted through, Darkest-Dungeon style. See the run inventory phase's own
## design notes for the full rationale; this doc covers only how the class
## itself works.
##
## [b]There is exactly one of these, and it lives on the horse.[/b] It is a
## child of [Player], the same place [WorldMapHorse] already lives and for the
## identical reason: [Player] is only ever rebuilt by
## [method SceneTree.reload_current_scene], which happens at true run
## boundaries (riding home, the next round) and never while the player is
## walking Base to World Map to a location and back. A sibling of the horse
## therefore survives exactly the things rule 22 of the phase asks it to -
## World Map movement, region changes, location transitions, a future Combat
## scene - for free, and resets to empty at exactly the moments a brand-new
## run should start with nothing carried over. Base preparation happens before
## the player ever presses B to depart, in this same persistent scene, so
## stocking up at the trader is simply calling [method add_ammo] et al. before
## the world is ever rebuilt - there is no separate "run start" moment this
## class has to detect.
##
## [b]One core method, six thin wrappers.[/b] [method add_item] is the whole
## of the stacking rule: it tops up whatever compatible stacks already exist
## before it ever opens a new slot, and it opens as many new slots as remain
## free and no more - see its own doc for the worked example rule 3 of the
## phase describes. [method add_ammo], [method add_weapon],
## [method add_heart], [method add_bounty_poster], [method add_treasure_map]
## and [method add_loot] each work out one category's identity, display name
## and stack ceiling and hand the rest to it, which is what keeps every
## category's stacking behaviour identical and keeps this file from ever
## duplicating a weapon's or an ammo type's own numbers - see
## [method get_ammo_max_stack], which reads a weapon's authored base capacity
## live rather than copying it in.
##
## [b]Overflow never disappears.[/b] [method add_item] returns how much of
## what was offered actually found room; a caller - a pickup, a purchase - is
## the one that decides what happens to the remainder, and every caller this
## phase ships leaves it exactly where it was: on the ground, or in the
## player's blood rather than spent. See [WorldMapItemPickup].

## Emitted on any change to the slots - a count moved, a slot filled, a slot
## emptied. A UI should redraw on this rather than polling, per rule 35 of the
## phase.
signal inventory_changed
## Emitted whenever the capacity itself moves.
signal slots_changed(max_slots: int)
## Emitted once an add actually lands, with how much of it did.
signal item_added(item_id: StringName, amount: int)
## Emitted once a remove actually lands.
signal item_removed(item_id: StringName, amount: int)
## Emitted once per rejected add - some or all of what was offered found no
## room. Never emitted more than once per call, so a caller driving an
## "INVENTORY FULL" notice from this can never spam it within one press - see
## rule 30 of the phase.
signal pickup_rejected(item_id: StringName)

## Group this joins, so anything can find the one run inventory without a
## [NodePath] across the scene - the same convention [WorldMapHorse] uses.
const GROUP := &"run_inventory"

@export_group("Capacity")
## Slots the player starts a run with.
@export var base_slot_count: int = 6
## The most a Base upgrade could ever raise capacity to.
@export var max_slot_count: int = 10
## How much one capacity upgrade adds - see [method add_slot_upgrade]. Not
## wired to a purchase screen this phase; this is the seam rule 32 asks this
## phase to expose and prove, not to sell.
@export var slot_upgrade_amount: int = 1

## One entry per slot, sized to [method get_max_slots]. A `null` entry is an
## empty slot.
var _slots: Array[RunItemStack] = []
## Everything a capacity upgrade has added on top of [member base_slot_count] -
## the same "authored base plus a bonus" shape [AmmoReserve] already uses for
## ammunition capacity.
var _slot_bonus: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	_resize_slots()
	# Deferred for the same reason [PlayerLoadout] defers its own mount lookup:
	# the mount is this node's sibling and may not have run its own [_ready]
	# yet, so asking for it now would find nothing.
	_seed_starting_weapon.call_deferred()


## The inventory the rest of the game should talk to. Null means there is no
## run in progress, which every caller reads as "there is nothing to add to or
## show".
static func get_active(from_node: Node) -> RunInventory:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RunInventory


# --- Capacity ------------------------------------------------------------

func get_max_slots() -> int:
	return clampi(base_slot_count + _slot_bonus, 0, maxi(max_slot_count, base_slot_count))


func get_slot_bonus() -> int:
	return _slot_bonus


## Raises capacity by one upgrade's worth, clamped to [member max_slot_count].
## Returns whether it actually moved - a run already at the ceiling reports
## false and changes nothing.
func add_slot_upgrade() -> bool:
	return set_slot_bonus(_slot_bonus + maxi(slot_upgrade_amount, 0))


## Sets the capacity bonus outright, clamped so [method get_max_slots] can
## never leave [member base_slot_count] or exceed [member max_slot_count]. The
## seam a future Base upgrade purchase writes through, and the dev/test hook
## rule 32 of the phase asks this phase to prove with a value of 7.
func set_slot_bonus(bonus: int) -> bool:
	var clamped := clampi(bonus, 0, maxi(max_slot_count - base_slot_count, 0))
	if clamped == _slot_bonus:
		return false
	_slot_bonus = clamped
	_resize_slots()
	slots_changed.emit(get_max_slots())
	inventory_changed.emit()
	return true


## Grows or shrinks [member _slots] to match [method get_max_slots]. Shrinking
## never discards an occupied slot - see the inline note - so a capacity that
## comes back down cannot make an item vanish out from under the player.
func _resize_slots() -> void:
	var wanted := get_max_slots()
	if _slots.size() == wanted:
		return

	if wanted > _slots.size():
		while _slots.size() < wanted:
			_slots.append(null)
		return

	# Trims only the empty slots off the end. An occupied slot past the new
	# ceiling is left standing rather than emptied by force - the row simply
	# reads one slot fuller than the ceiling until the player empties it by
	# hand, which is the same "never silently discard" rule the phase asks of
	# every other overflow case.
	var trimmed: Array[RunItemStack] = []
	for i in _slots.size():
		if i < wanted or _slots[i] != null:
			trimmed.append(_slots[i])
	_slots = trimmed


# --- Reading the row -------------------------------------------------------

## Every slot, `null` where one is empty, sized to [method get_max_slots]. A
## copy, so a UI iterating this cannot reach in and edit a stack directly.
func get_slots() -> Array[RunItemStack]:
	return _slots.duplicate()


func get_slot(index: int) -> RunItemStack:
	return _slots[index] if index >= 0 and index < _slots.size() else null


func get_used_slots() -> int:
	var used := 0
	for stack: RunItemStack in _slots:
		if stack != null:
			used += 1
	return used


func get_remaining_slots() -> int:
	return maxi(_slots.size() - get_used_slots(), 0)


## The first empty slot's index, or -1 when the row is full.
func get_free_slot_index() -> int:
	for i in _slots.size():
		if _slots[i] == null:
			return i
	return -1


## Every stack currently holding [param item_id], in slot order. There may be
## more than one - a full 264 stack of Revolver ammo beside a second, partial
## one.
func find_stacks(item_id: StringName) -> Array[RunItemStack]:
	var found: Array[RunItemStack] = []
	if item_id == &"":
		return found
	for stack: RunItemStack in _slots:
		if stack != null and stack.item_id == item_id:
			found.append(stack)
	return found


## The first stack of [param item_id] that still has room, or null when every
## stack of it is full - which is when [method add_item] has to open a new
## slot instead.
func find_open_stack(item_id: StringName) -> RunItemStack:
	for stack: RunItemStack in find_stacks(item_id):
		if not stack.is_full():
			return stack
	return null


## How many more units of an item shaped like [param item_id]/[param max_count]
## could be taken in right now, without actually taking any of them in - the
## existing stacks' free room, plus every empty slot's own ceiling. What a
## shop asks before it prices a purchase - see [method TraderMenu.get_purchasable_rounds] -
## so it can charge for exactly what would fit rather than committing the add
## first and hoping the price matches.
func get_room_for_item(item_id: StringName, max_count: int = 1) -> int:
	var room := 0
	for stack: RunItemStack in find_stacks(item_id):
		room += stack.get_free_room()

	var empty_slots := 0
	for stack: RunItemStack in _slots:
		if stack == null:
			empty_slots += 1
	room += empty_slots * maxi(max_count, 1)
	return room


## Whether at least one unit of [param item_id] could be taken in right now -
## an existing stack has room, or a slot is free. What a shop asks before it
## charges the player - see [method TraderMenu.can_buy], which is the whole of
## rule 31's "reject the purchase before charging" - and what a pickup asks
## before it commits to taking anything off the ground.
func can_add_item(item_id: StringName) -> bool:
	if find_open_stack(item_id) != null:
		return true
	return get_free_slot_index() >= 0


# --- Adding --------------------------------------------------------------

## The one place anything ever enters the inventory.
##
## Fills every compatible stack it can find room in first, in slot order, and
## only once every existing stack of [param item_id] is full does it open a
## new one - and it opens as many new slots as it needs and has, never more.
## This is rule 3 and rule 13 of the phase, worked exactly as their own
## examples do: 250/264 receiving 30 tops the first stack to 264 and opens a
## second holding 16; with no second slot free, only the 14 that fit are
## taken and the rest is reported missing through the return value, for
## whoever called this to leave lying on the ground rather than destroy.
##
## Returns how much of [param amount] was actually taken in. [signal
## pickup_rejected] fires once, whether nothing fit at all or only part of it
## did - never per unit, so a caller flashing "INVENTORY FULL" from it cannot
## spam the message within a single press.
func add_item(
	item_id: StringName,
	item_display_name: String,
	amount: int,
	max_count: int = 1,
	category: StringName = &"",
	icon: Texture2D = null,
	payload: Variant = null
) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var remaining := amount
	var added := 0

	for stack: RunItemStack in find_stacks(item_id):
		if remaining <= 0:
			break
		var room := stack.get_free_room()
		if room <= 0:
			continue
		var taken := mini(room, remaining)
		stack.count += taken
		remaining -= taken
		added += taken

	while remaining > 0:
		var index := get_free_slot_index()
		if index < 0:
			break
		var stack := RunItemStack.new()
		stack.item_id = item_id
		stack.display_name = item_display_name
		stack.icon = icon
		stack.category = category
		stack.max_count = maxi(max_count, 1)
		stack.payload = payload
		var taken := mini(stack.max_count, remaining)
		stack.count = taken
		_slots[index] = stack
		remaining -= taken
		added += taken

	if added > 0:
		item_added.emit(item_id, added)
		inventory_changed.emit()
	if added < amount:
		pickup_rejected.emit(item_id)
	return added


## The most one slot of [param ammo_type] can ever hold: its authored base
## capacity, read live off the [AmmoType] itself, times four - rule 3 and rule
## 5 of the phase, in one place so nothing else has to reimplement the
## formula. Never the weapon's *upgraded* capacity - [member AmmoType.max_ammo]
## is the base a Base ammo-capacity upgrade adds on top of through
## [AmmoReserve], and this phase's stacks are deliberately sized off the base
## alone, so a capacity upgrade changes what fits in the loaded weapon and
## never what fits in one inventory stack.
func get_ammo_max_stack(ammo_type: AmmoType) -> int:
	return 0 if ammo_type == null else maxi(ammo_type.max_ammo, 0) * 4


## Adds reserve ammunition for [param ammo_type]. Identity and stack ceiling
## both come off the resource itself - see [method get_ammo_max_stack] - so a
## weapon's balance changing changes what fits here with nothing rewritten.
func add_ammo(ammo_type: AmmoType, amount: int) -> int:
	if ammo_type == null:
		return 0
	return add_item(
		ammo_type.id, ammo_type.get_plural_name(), amount,
		get_ammo_max_stack(ammo_type), &"ammo", ammo_type.icon, ammo_type)


## Adds one carried weapon. Never stacks - two of the same weapon id simply
## cannot both be added, since the second call finds its one slot already
## full and reports nothing taken.
func add_weapon(weapon: WeaponDefinition) -> bool:
	if weapon == null:
		return false
	return add_item(weapon.weapon_id, weapon.display_name, 1, 1, &"weapon", weapon.icon, weapon) > 0


## Adds [param amount] Hearts, one slot apiece - see rule 7 of the phase, which
## asks for exactly this and nothing cleverer: the project has no separate
## heart item resource to key stacking off, so each Heart is its own
## non-stacking unit exactly the way a bounty poster or a weapon is. Returns
## how many actually found room.
func add_heart(amount: int = 1) -> int:
	var added := 0
	for _i in maxi(amount, 0):
		if add_item(&"heart", "Heart", 1, 1, &"heart") <= 0:
			break
		added += 1
	return added


## Adds one bounty poster. Keyed on the bounty's own id, so two different
## contracts can never collide and the same contract can never be added twice
## - the second call finds its one slot already full. [param bounty] is kept
## as the stack's payload, which is what lets [signal Bounty.bounty_changed]
## and the Bounties panel read the real contract rather than a name copied out
## of it once - see rule 9 of the phase.
func add_bounty_poster(bounty: Bounty) -> bool:
	if bounty == null or bounty.bounty_id == &"":
		return false
	var who := "WANTED" if bounty.target == null else bounty.target.display_name
	return add_item(bounty.bounty_id, who, 1, 1, &"bounty_poster", null, bounty) > 0


## Adds one treasure map. [param map_item_id] is the identity two copies of
## the same map would share; two different maps use two different ids.
func add_treasure_map(map_item_id: StringName, item_display_name: String, icon: Texture2D = null) -> bool:
	return add_item(map_item_id, item_display_name, 1, 1, &"treasure_map", icon) > 0


## Adds loot or a weapon upgrade found during the run. Non-stackable by
## default, per rule 11 of the phase ("1 item = 1 slot"); a future loot item
## that is deliberately stackable can pass its own [param max_count].
func add_loot(
	item_id: StringName, item_display_name: String, amount: int = 1,
	max_count: int = 1, icon: Texture2D = null, payload: Variant = null
) -> int:
	return add_item(item_id, item_display_name, amount, max_count, &"loot", icon, payload)


# --- Removing --------------------------------------------------------------

## Empties one slot outright and hands back what was in it, or null if it was
## already empty. What discarding (rule 33 of the phase) uses - see
## [WorldMapItemPickup], which is what a discard drops the returned stack
## into.
func remove_slot(index: int) -> RunItemStack:
	if index < 0 or index >= _slots.size() or _slots[index] == null:
		return null
	var removed := _slots[index]
	_slots[index] = null
	item_removed.emit(removed.item_id, removed.count)
	inventory_changed.emit()
	return removed


## Removes up to [param amount] of [param item_id], spending across however
## many stacks hold it and freeing any it empties. For a later system
## consuming an item - a Heart used, a treasure map read - rather than a
## player discarding one; nothing in this phase calls it on its own. Returns
## how many were actually removed.
func remove_item(item_id: StringName, amount: int) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var remaining := amount
	var removed := 0
	for i in _slots.size():
		if remaining <= 0:
			break
		var stack := _slots[i]
		if stack == null or stack.item_id != item_id:
			continue
		var taken := mini(stack.count, remaining)
		stack.count -= taken
		remaining -= taken
		removed += taken
		if stack.count <= 0:
			_slots[i] = null

	if removed > 0:
		item_removed.emit(item_id, removed)
		inventory_changed.emit()
	return removed


# --- Starting inventory ----------------------------------------------------

## Represents whatever weapon the player is already carrying as a slot item -
## see rule 16 of the phase, "preserve the existing active weapon/loadout
## rules". [WeaponMount] alone still decides what is actually in the player's
## hands; this only ever mirrors that choice into the row, and never the other
## way round.
func _seed_starting_weapon() -> void:
	var mount := WeaponMount.get_active(self)
	if mount == null:
		return
	var definition := mount.get_definition()
	if definition != null:
		add_weapon(definition)


# --- Debugging ---------------------------------------------------------

## One line per occupied slot, for a developer readout or a print during a
## test.
func get_debug_text() -> String:
	var lines := PackedStringArray([
		"INVENTORY  %d / %d" % [get_used_slots(), get_max_slots()],
	])
	for i in _slots.size():
		var stack := _slots[i]
		if stack != null:
			lines.append("  [%d] %s (%s)" % [i, stack.describe(), stack.category])
	return "\n".join(lines)
