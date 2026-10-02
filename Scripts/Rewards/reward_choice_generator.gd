class_name RewardChoiceGenerator
extends Resource
## Deals one reward selection: how many cards, and what each one is.
##
## [b]How many is Luck.[/b] [method choice_count] is [member base_choice_count]
## plus [member choices_per_luck] for every point of Luck the weapon carries,
## capped at [member max_choice_count]. Luck is an ordinary weapon stat
## ([member luck_stat]) summed by [WeaponStats] like any other, so anything that
## moves it - the ŞANSLI EL card, a later charm through
## [method WeaponDefinition.set_modifier_source] - widens the selection without
## this or any screen being told.
##
## [b]Every slot rolls on its own.[/b] Each slot picks one of [member entries] by
## weight - Legendary 10, Upgrade 90 - and draws from it. Nothing forces or
## forbids any mix; three Legendaries is as possible as none. A slot whose pool
## has nothing left (no Legendary the weapon does not already carry) draws from
## [member fallback_pool] instead. One selection never deals the same upgrade or
## Legendary twice while anything else is left to fill it.

@export_group("Choice Count")
## Cards in a selection with no Luck.
@export_range(1, 16) var base_choice_count: int = 3
## The weapon stat read as Luck.
@export var luck_stat: WeaponStats.Stat = WeaponStats.Stat.LUCK
## Extra cards per point of Luck. Rounded down.
@export var choices_per_luck: float = 1.0
## The most cards a selection can ever have.
@export_range(1, 16) var max_choice_count: int = 7

@export_group("Card Types")
## The per-slot type roll, by weight.
@export var entries: Array[RewardPoolEntry] = []
## Drawn from when a slot's own pool has nothing left to deal.
@export var fallback_pool: RewardChoicePool


## The Luck [param weapon] carries right now.
func luck_of(weapon: WeaponDefinition) -> float:
	if weapon == null:
		return 0.0
	return weapon.get_stats().get_bonus(luck_stat)


## How many cards a selection has at [param luck].
func choice_count(luck: float) -> int:
	var extra := floori(maxf(luck, 0.0) * choices_per_luck + 0.0001)
	return clampi(base_choice_count + extra, 1, maxi(max_choice_count, 1))


## Deals a selection for [param weapon], left to right. [param count] below one
## uses [method choice_count] at the weapon's Luck. Fewer cards come back only
## when the weapon has nothing at all left to give.
func generate(weapon: WeaponDefinition, rng: RandomNumberGenerator,
		count: int = -1) -> Array[RewardChoice]:
	var dealt: Array[RewardChoice] = []
	if weapon == null or rng == null:
		return dealt
	var wanted := count if count > 0 else choice_count(luck_of(weapon))
	var keys: Array[StringName] = []
	for _slot: int in wanted:
		var choice := roll_slot(weapon, rng, keys)
		# Nothing else left to fill the selection: a repeat is better than a gap.
		if choice == null:
			choice = roll_slot(weapon, rng, [])
		if choice == null:
			break
		keys.append(choice.get_key())
		dealt.append(choice)
	return dealt


## Rolls one slot's card type and draws it, falling back as described above.
func roll_slot(weapon: WeaponDefinition, rng: RandomNumberGenerator,
		excluded: Array[StringName]) -> RewardChoice:
	var pool := pick_pool(rng)
	var choice: RewardChoice = pool.draw(weapon, rng, excluded) if pool != null else null
	if choice == null and fallback_pool != null:
		choice = fallback_pool.draw(weapon, rng, excluded)
	return choice


## Picks one of [member entries] by weight.
func pick_pool(rng: RandomNumberGenerator) -> RewardChoicePool:
	var total := 0.0
	for entry: RewardPoolEntry in entries:
		if entry != null and entry.pool != null:
			total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return fallback_pool
	var pick := rng.randf() * total
	var last: RewardChoicePool = fallback_pool
	for entry: RewardPoolEntry in entries:
		if entry == null or entry.pool == null or entry.weight <= 0.0:
			continue
		last = entry.pool
		pick -= entry.weight
		if pick < 0.0:
			return entry.pool
	return last
