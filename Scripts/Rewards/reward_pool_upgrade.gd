class_name RewardPoolUpgrade
extends RewardChoicePool
## Normal Upgrade Cards: one of the equipped weapon's own
## [member WeaponDefinition.upgrades], at a rarity rolled from [member rarities].
##
## [b]The weapon's list is the pool.[/b] Only that weapon's upgrades are dealt, so
## one weapon's upgrade never shows for another, and the Base's unlock gate
## ([member WeaponUpgrade.market_unlocked]) is honoured. There is no level cap:
## a card may be dealt and taken however many run levels it already has.

## The rarity roll, by weight. Common 70 / Uncommon 20 / Rare 8 / Epic 2 to begin.
@export var rarities: Array[RewardRarityChance] = []
## Whether a weapon's Unique upgrades ([member WeaponUpgrade.unique]) are dealt
## alongside its common ones.
@export var include_unique: bool = true
## Whether only [member WeaponUpgrade.market_unlocked] upgrades are dealt.
@export var unlocked_only: bool = true


func draw(weapon: WeaponDefinition, rng: RandomNumberGenerator,
		excluded: Array[StringName] = []) -> RewardChoice:
	if weapon == null or rng == null:
		return null
	var candidates := eligible(weapon, excluded)
	if candidates.is_empty():
		return null
	var rarity := RewardRarityChance.roll(rarities, rng)
	if rarity == null:
		return null
	var upgrade: WeaponUpgrade = candidates[rng.randi_range(0, candidates.size() - 1)]
	return RewardChoiceUpgrade.create(weapon, upgrade, rarity)


## Every upgrade of [param weapon] this pool may deal, leaving out [param excluded].
func eligible(weapon: WeaponDefinition, excluded: Array[StringName] = []) -> Array[WeaponUpgrade]:
	var result: Array[WeaponUpgrade] = []
	if weapon == null:
		return result
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade == null or (unlocked_only and not upgrade.market_unlocked):
			continue
		if upgrade.unique and not include_unique:
			continue
		if excluded.has(StringName("upgrade:%s" % upgrade.id)):
			continue
		result.append(upgrade)
	return result
