class_name RunMapUpgradeReward
extends Resource
## A free, run-only weapon upgrade handed over for winning the fight at a run
## map point - what [RunMapUpgradeRewardScreen] awards and shows.
##
## [b]It is the Market's upgrade with the price taken off, not a second upgrade
## system.[/b] Which upgrade is drawn is [method RunMapMarketProducts.draw_upgrade]
## on [member pool] - the equipped weapon's own [member WeaponDefinition.upgrades],
## only the [member WeaponUpgrade.market_unlocked] ones, only under the run level
## cap, a weapon's Uniques only ever for that weapon - and it is delivered as a
## [RunMapUpgradeGood] priced at nothing, so the level lands on the weapon's run
## stack through [method WeaponDefinition.raise_run_level] exactly as a purchase
## does and is forgotten with the run like one. No blood is asked for.
##
## [b]Which points pay out is a list here, not a branch anywhere.[/b] A point
## whose [member RunMapSite.kind] is in [member site_kinds] earns this reward; a
## later reward for another kind of point is another of these resources.
##
## [b]How many upgrades, and how they are chosen, is data too.[/b] [member picks]
## upgrades are given one after another; with [member choices] above one, each is
## chosen from a selection of that many dealt by [method draw_choices], whose
## Unique roll is made once per selection. With one choice the upgrade is simply
## handed over, drawn by [method draw].

## The run map point kinds - [member RunMapSite.kind] as it stood before the
## fight cleared it - whose won fight earns this reward.
@export var site_kinds: Array[StringName] = []
## Chance, 0..1, that the reward is one of the equipped weapon's Uniques rather
## than a common upgrade. A weapon with no eligible Unique gets a common one.
@export_range(0.0, 1.0, 0.001) var unique_chance: float = 0.03
## The upgrade pool the reward is drawn from - the Market's own, so the unlock
## gate and the run level cap are the ones the Market deals by. Its prices and
## its own unique chance are not used.
@export var pool: RunMapMarketProducts
## How many upgrades a won fight gives, one after another.
@export_range(1, 8) var picks: int = 1
## How many upgrades each pick is chosen from. One hands the upgrade over with no
## choice to make.
@export_range(1, 8) var choices: int = 1


## Whether a won fight at a point of [param site_kind] earns this reward.
func pays_for(site_kind: StringName) -> bool:
	return not site_kind.is_empty() and site_kinds.has(site_kind)


## Draws the upgrade [param weapon] is rewarded with, or null when it has nothing
## left to be given.
func draw(weapon: WeaponDefinition, rng: RandomNumberGenerator) -> WeaponUpgrade:
	if pool == null:
		return null
	return pool.draw_upgrade(weapon, unique_chance, rng)


## Deals one selection of up to [member choices] different upgrades for
## [param weapon]. The Unique roll is made once for the whole selection: on a hit
## one slot is drawn from the weapon's own Uniques - its common pool when it has
## none left - and every other slot from the common pool. Nothing in
## [param avoid] - the product keys of what was just chosen - is dealt while
## enough else is left to fill the selection. Empty when nothing is left to give.
func draw_choices(weapon: WeaponDefinition, rng: RandomNumberGenerator,
		avoid: Array[StringName] = []) -> Array[WeaponUpgrade]:
	var offer: Array[WeaponUpgrade] = []
	if pool == null or weapon == null or rng == null:
		return offer
	var dealt: Array[StringName] = []
	var unique_rolled := rng.randf() < unique_chance
	for slot: int in range(maxi(choices, 1)):
		var chance := 1.0 if slot == 0 and unique_rolled else 0.0
		var shunned: Array[StringName] = dealt.duplicate()
		shunned.append_array(avoid)
		var upgrade := pool.draw_upgrade(weapon, chance, rng, shunned)
		# Not enough else to fill the selection: what was just chosen may return.
		if upgrade == null and not avoid.is_empty():
			upgrade = pool.draw_upgrade(weapon, chance, rng, dealt)
		if upgrade == null:
			break
		dealt.append(RunMapUpgradeGood.product_key(weapon, upgrade))
		# The Unique is not always the first card.
		offer.insert(rng.randi_range(0, offer.size()), upgrade)
	return offer


## The free good that delivers one run level of [param upgrade] to
## [param weapon] - see [method RunMapUpgradeGood.buy].
func make_good(weapon: WeaponDefinition, upgrade: WeaponUpgrade) -> RunMapUpgradeGood:
	var good := RunMapUpgradeGood.create(weapon, upgrade)
	good.base_price = 0
	good.price_per_level = 0
	good.run_cap = pool.cap_for(upgrade) if pool != null else -1
	return good
