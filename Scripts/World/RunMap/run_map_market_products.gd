class_name RunMapMarketProducts
extends Resource
## What a run map market sells: run-only weapon upgrades for the weapon in the
## player's hands and a Card, dealt into a fixed number of slots - the data
## behind [RunMapMarketScreen]'s shelf.
##
## [b]It lists no upgrades of its own.[/b] The upgrade slots are dealt from the
## equipped weapon's own [member WeaponDefinition.upgrades] - the same list the
## Base's UPGRADE screen reads - so a weapon's market pool is its upgrade list and
## nothing else, one weapon's Unique never turns up for another, and adding an
## upgrade to a weapon adds it here too. An upgrade is dealt only while
## [member WeaponUpgrade.market_unlocked] is on. The Card slot is dealt from
## [member cards], the unlocked ones only.
##
## [b]Each upgrade slot rolls for a Unique first.[/b] With [member unique_chance]
## it draws from the weapon's [member WeaponUpgrade.unique] upgrades instead of its
## common ones; a weapon with no Unique to offer draws from the common pool.
##
## [b]A refresh never repeats the one before it.[/b] [method deal] is handed every
## product the previous refresh put out and gives each of them no chance at all,
## in every slot; the refresh after that forgets them again, so nothing's odds are
## ever lowered for good by having been seen.

@export_group("Slots")
## How many weapon upgrade slots the shelf has.
@export var upgrade_slots: int = 4
## How many Card slots the shelf has, after the upgrade slots.
@export var card_slots: int = 1
## Chance, 0..1, that one upgrade slot deals a Unique rather than a common
## upgrade. Rolled once per slot.
@export_range(0.0, 1.0, 0.001) var unique_chance: float = 0.05

@export_group("Upgrades")
## The most run levels one upgrade can be stacked to in a run. Negative uses each
## upgrade's own [member WeaponUpgrade.max_level]. A stack at its cap is not dealt.
@export var run_level_cap: int = -1
## What a common upgrade's first run level costs, in carried blood.
@export var upgrade_price: int = 60
## What each run level already held adds to a common upgrade's price.
@export var upgrade_price_per_level: int = 30
## What a Unique upgrade's first run level costs, in carried blood.
@export var unique_price: int = 150
## What each run level already held adds to a Unique upgrade's price.
@export var unique_price_per_level: int = 75

@export_group("Cards")
## Every Card a market may deal. Only [member RunCard.unlocked] ones are dealt.
@export var cards: Array[RunCard] = []

@export_group("Reroll")
## The tip "what else do you have?" costs, in carried blood.
@export var reroll_tip: int = 15

@export_group("Wording")
## How a common upgrade row is named: the upgrade, then the run level it reaches.
@export var upgrade_label_format: String = "%s  LV %d"
## How a Unique upgrade row is named.
@export var unique_label_format: String = "UNIQUE: %s  LV %d"
## How a Card row is named.
@export var card_label_format: String = "CARD: %s"


## Deals a fresh shelf for [param weapon]: the upgrade slots, then the Card slots,
## with [param deal_seed]. Nothing in [param excluded] - the product keys of the
## previous refresh - is dealt. A slot with nothing left to deal is left off.
func deal(weapon: WeaponDefinition, excluded: Array[StringName], deal_seed: int) -> Array[RunMapSaloonGood]:
	var rng := RandomNumberGenerator.new()
	rng.seed = deal_seed
	var shelf: Array[RunMapSaloonGood] = []
	var taken: Array[StringName] = excluded.duplicate()

	if weapon != null:
		for _slot: int in range(maxi(upgrade_slots, 0)):
			var upgrade := draw_upgrade(weapon, unique_chance, rng, taken)
			if upgrade == null:
				continue
			taken.append(RunMapUpgradeGood.product_key(weapon, upgrade))
			shelf.append(_make_upgrade_good(weapon, upgrade))

	for _slot: int in range(maxi(card_slots, 0)):
		var pool := _card_pool(taken)
		if pool.is_empty():
			continue
		var card: RunCard = pool[rng.randi_range(0, pool.size() - 1)]
		taken.append(RunMapCardGood.product_key(card))
		shelf.append(_make_card_good(card))

	return shelf


## Draws one upgrade for [param weapon] exactly as one upgrade slot is dealt: a
## Unique with [param chance], from the weapon's own Uniques, falling back to its
## common pool when it has no Unique to offer; only
## [member WeaponUpgrade.market_unlocked] upgrades with run levels still under
## [method cap_for], and nothing in [param excluded]. Null when nothing is left.
## The one draw both a shelf slot and a post-fight reward are made with.
func draw_upgrade(weapon: WeaponDefinition, chance: float, rng: RandomNumberGenerator,
		excluded: Array[StringName] = []) -> WeaponUpgrade:
	if weapon == null or rng == null:
		return null
	var pool: Array[WeaponUpgrade] = []
	if rng.randf() < chance:
		pool = _upgrade_pool(weapon, true, excluded)
	# A weapon with no Unique left to offer deals a common upgrade instead.
	if pool.is_empty():
		pool = _upgrade_pool(weapon, false, excluded)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


## Builds the goods for a shelf already dealt, from the product keys it was
## remembered by. A key that no longer names anything is left off.
func rebuild(weapon: WeaponDefinition, keys: Array[StringName]) -> Array[RunMapSaloonGood]:
	var shelf: Array[RunMapSaloonGood] = []
	for key: StringName in keys:
		var good := _good_for_key(weapon, key)
		if good != null:
			shelf.append(good)
	return shelf


## The product key of [param good], or empty for a good this pool did not deal.
static func key_of(good: RunMapSaloonGood) -> StringName:
	if good is RunMapUpgradeGood:
		return (good as RunMapUpgradeGood).get_product_key()
	if good is RunMapCardGood:
		return (good as RunMapCardGood).get_product_key()
	return &""


## The run level cap for [param upgrade] under [member run_level_cap].
func cap_for(upgrade: WeaponUpgrade) -> int:
	return upgrade.max_level if run_level_cap < 0 else run_level_cap


func _upgrade_pool(weapon: WeaponDefinition, uniques: bool, taken: Array[StringName]) -> Array[WeaponUpgrade]:
	var pool: Array[WeaponUpgrade] = []
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade == null or upgrade.unique != uniques or not upgrade.market_unlocked:
			continue
		if not RunMapUpgradeGood.has_room(weapon, upgrade, cap_for(upgrade)):
			continue
		if taken.has(RunMapUpgradeGood.product_key(weapon, upgrade)):
			continue
		pool.append(upgrade)
	return pool


func _card_pool(taken: Array[StringName]) -> Array[RunCard]:
	var pool: Array[RunCard] = []
	for card: RunCard in cards:
		if card == null or not card.unlocked:
			continue
		if taken.has(RunMapCardGood.product_key(card)):
			continue
		pool.append(card)
	return pool


func _good_for_key(weapon: WeaponDefinition, key: StringName) -> RunMapSaloonGood:
	if weapon != null:
		for upgrade: WeaponUpgrade in weapon.upgrades:
			if upgrade != null and RunMapUpgradeGood.product_key(weapon, upgrade) == key:
				return _make_upgrade_good(weapon, upgrade)
	for card: RunCard in cards:
		if card != null and RunMapCardGood.product_key(card) == key:
			return _make_card_good(card)
	return null


func _make_upgrade_good(weapon: WeaponDefinition, upgrade: WeaponUpgrade) -> RunMapUpgradeGood:
	var good := RunMapUpgradeGood.create(weapon, upgrade)
	good.base_price = unique_price if upgrade.unique else upgrade_price
	good.price_per_level = unique_price_per_level if upgrade.unique else upgrade_price_per_level
	good.run_cap = cap_for(upgrade)
	good.label_format = unique_label_format if upgrade.unique else upgrade_label_format
	return good


func _make_card_good(card: RunCard) -> RunMapCardGood:
	var good := RunMapCardGood.create(card)
	good.label_format = card_label_format
	return good
