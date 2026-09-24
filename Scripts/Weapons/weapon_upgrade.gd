class_name WeaponUpgrade
extends Resource
## One common upgrade a weapon can have bought for it at the Base: what it is
## called, how many levels it has, what each costs, and what one level does to the
## weapon's stats.
##
## [b]It is data, not a system.[/b] What a level does is a list of
## [WeaponStatModifier]s summed into the weapon's [WeaponStats]; the projectile,
## the magazine, the reserve and the enemy's reaction then apply those stats
## through their own existing calculations. A weapon offers an upgrade by listing
## it in [member WeaponDefinition.upgrades], so different weapons can offer
## different sets - and a weapon that wants different numbers for the same upgrade
## simply lists its own copy of the [code].tres[/code].
##
## How many levels a weapon has of it lives on the [WeaponDefinition], keyed by
## [member id], never here - so one file can be shared by every weapon.

## Stable key the weapon files its level under. [b]Must be unique among one
## weapon's upgrades and must not change[/b], or the level bought is lost.
@export var id: StringName = &""
## What the card is headed with.
@export var display_name: String = "UPGRADE"
## How many times it can be bought.
@export var max_level: int = 5
## What each level costs, in banked blood: the first entry buys level 1, and so on.
## A level past the last entry costs the last entry.
@export var level_costs: Array[int] = []
## What one level adds. Applied once per level held.
@export var modifiers_per_level: Array[WeaponStatModifier] = []

@export_group("Run Market")
## Whether this is a weapon's Unique upgrade rather than a common one. A run map
## market deals Uniques only on its Unique roll - see
## [member RunMapMarketProducts.unique_chance] - and only for a weapon that lists
## this upgrade itself, so one weapon's Unique never shows for another.
@export var unique: bool = false
## Whether a run map market may offer this upgrade at all. The gate the Base's Gem
## progression unlocks through; a locked upgrade is never dealt onto a shelf.
@export var market_unlocked: bool = true


## What the modifiers add at [param level], as a card line per stat -
## "DAMAGE +20%".
func describe_level(level: int) -> String:
	var lines: PackedStringArray = []
	for modifier: WeaponStatModifier in modifiers_per_level:
		if modifier != null:
			lines.append("%s %s" % [modifier.label, modifier.format_amount(level)])
	return "\n".join(lines)


## What [param level] -> [param level] + 1 changes, per stat - "DAMAGE +10% -> +20%".
func describe_step(level: int) -> String:
	var lines: PackedStringArray = []
	for modifier: WeaponStatModifier in modifiers_per_level:
		if modifier != null:
			lines.append("%s %s -> %s" % [
				modifier.label, modifier.format_amount(level), modifier.format_amount(level + 1)])
	return "\n".join(lines)


## What buying the level after [param level] costs, or -1 when there is none.
func cost_after(level: int) -> int:
	if level >= max_level or level_costs.is_empty():
		return -1
	return maxi(level_costs[clampi(level, 0, level_costs.size() - 1)], 0)


## Sums [param level] levels of this upgrade into [param stats].
func apply_to(stats: WeaponStats, level: int) -> void:
	if level <= 0:
		return
	for modifier: WeaponStatModifier in modifiers_per_level:
		stats.add_modifier(modifier, float(level))
