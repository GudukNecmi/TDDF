class_name CombatLootGenerator
extends RefCounted
## Turns one bandit fight's authoritative battle size into what it hands over -
## see [CombatLootDirector], the only thing that ever calls this, and
## [CombatLootTable], where every chance and every quantity below actually
## comes from.
##
## [b]This file decides nothing about balance.[/b] It is the four rolls Part A
## of the loot pass asks for, worked exactly as [CombatLootTable]'s own points
## and steps say to, and nothing here would need to change for any of them to
## be retuned - that is the whole point of the table being a resource. A fifth
## loot type is a fifth roll added here and a fifth section on the table
## beside it, never a branch woven into the four that already exist.
##
## [b]Stateless.[/b] Every roll reads [param strength] and [param table] and
## writes into [param loot]; nothing here is kept between one encounter and the
## next, so calling this twice on two different fights can never leak a stray
## number from the first into the second.

## Fills [param loot] with everything a fight against a group [param strength]
## strong earns under [param table]. Safe to call on a [param table] with
## nothing authored on it yet - every roll simply has nothing to give.
static func generate(strength: float, loot: CombatLoot, table: CombatLootTable) -> void:
	if loot == null or table == null:
		return

	var size := maxf(strength, 0.0)
	_roll_gems(size, loot, table)
	_roll_hearts(size, loot, table)
	_roll_ammo(size, loot, table)
	_roll_boss_info(size, loot, table)


# --- Gems --------------------------------------------------------------------

static func _roll_gems(size: float, loot: CombatLoot, table: CombatLootTable) -> void:
	if randf() >= table.sample_gem_chance(size):
		return

	var color := table.pick_gem_color()
	if color == null or color.id == &"":
		return

	var quantity := table.roll_gem_quantity(size)
	if quantity <= 0:
		return

	loot.add_gem(color.id, color.display_name, quantity, table.gem_stack_max, color.icon)


# --- Hearts ------------------------------------------------------------------

static func _roll_hearts(size: float, loot: CombatLoot, table: CombatLootTable) -> void:
	if randf() >= table.sample_heart_chance(size):
		return

	var quantity := table.roll_heart_quantity(size)
	if quantity > 0:
		loot.add_heart(quantity)


# --- Ammunition ----------------------------------------------------------------

## "The roll repeats until it fails": one roll against [method CombatLootTable.sample_ammo_chance]
## opens a magazine's worth of a randomly picked weapon's rounds and rolls
## again; the first failure stops the whole thing. [member CombatLootTable.max_ammo_rolls_per_encounter]
## is the safety rail under [member CombatLootTable.ammo_chance_cap] that keeps
## this from ever being an unbounded loop.
static func _roll_ammo(size: float, loot: CombatLoot, table: CombatLootTable) -> void:
	var chance := table.sample_ammo_chance(size)
	var multiplier := table.sample_ammo_quantity_multiplier(size)
	var rolls := 0

	while rolls < table.max_ammo_rolls_per_encounter:
		rolls += 1
		if randf() >= chance:
			break

		var entry := table.pick_ammo_entry()
		if entry == null or entry.ammo_type == null or entry.base_magazine <= 0:
			continue

		var quantity := int(round(float(entry.base_magazine) * multiplier))
		var stack_max := entry.base_magazine * maxi(table.ammo_stack_multiplier, 1)
		loot.add_ammo(entry.ammo_type, quantity, stack_max)


# --- Boss Information ----------------------------------------------------------

## Every open slot - see [method CombatLootTable.get_boss_info_slots] - rolls
## [method CombatLootTable.sample_boss_info_chance] on its own, so a three-slot
## battle can come away with anywhere from none to all three rather than one
## roll deciding the lot.
static func _roll_boss_info(size: float, loot: CombatLoot, table: CombatLootTable) -> void:
	var slots := table.get_boss_info_slots(size)
	if slots <= 0:
		return

	var chance := table.sample_boss_info_chance(size)
	for _slot: int in slots:
		if randf() < chance:
			loot.add_boss_info(&"bounty_lead", table.boss_info_display_name)
