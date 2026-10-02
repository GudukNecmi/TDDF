class_name RewardPoolLegendary
extends RewardChoicePool
## Weapon Legendary Cards: one of the equipped weapon's own
## [member WeaponDefinition.legendaries] it does not already carry this run.
##
## Any Legendary added to a weapon's list is a candidate from then on; a weapon
## with none left deals nothing, and the generator falls back to a normal card.

## The rarity every card from here carries - Legendary, gold.
@export var rarity: UpgradeRarity


func draw(weapon: WeaponDefinition, rng: RandomNumberGenerator,
		excluded: Array[StringName] = []) -> RewardChoice:
	if weapon == null or rng == null:
		return null
	var candidates := eligible(weapon, excluded)
	if candidates.is_empty():
		return null
	var legendary: WeaponLegendary = candidates[rng.randi_range(0, candidates.size() - 1)]
	return RewardChoiceLegendary.create(weapon, legendary, rarity)


## Every Legendary of [param weapon] this pool may deal, leaving out
## [param excluded] and the ones already switched on.
func eligible(weapon: WeaponDefinition, excluded: Array[StringName] = []) -> Array[WeaponLegendary]:
	var result: Array[WeaponLegendary] = []
	if weapon == null:
		return result
	for legendary: WeaponLegendary in weapon.legendaries:
		if legendary == null or weapon.is_legendary_active(legendary):
			continue
		if excluded.has(StringName("legendary:%s" % legendary.id)):
			continue
		result.append(legendary)
	return result
