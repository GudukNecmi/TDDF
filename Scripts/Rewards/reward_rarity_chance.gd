class_name RewardRarityChance
extends Resource
## One line of a pool's rarity roll: a rarity and its weight. Weights are
## relative - 70/20/8/2 is the same roll as 0.7/0.2/0.08/0.02.

@export var rarity: UpgradeRarity
@export_range(0.0, 1000.0, 0.01) var weight: float = 1.0


## Picks one rarity from [param chances] by weight, or null when none can be.
static func roll(chances: Array[RewardRarityChance], rng: RandomNumberGenerator) -> UpgradeRarity:
	var total := 0.0
	for chance: RewardRarityChance in chances:
		if chance != null and chance.rarity != null:
			total += maxf(chance.weight, 0.0)
	if total <= 0.0 or rng == null:
		return null
	var pick := rng.randf() * total
	var last: UpgradeRarity = null
	for chance: RewardRarityChance in chances:
		if chance == null or chance.rarity == null or chance.weight <= 0.0:
			continue
		last = chance.rarity
		pick -= chance.weight
		if pick < 0.0:
			return chance.rarity
	return last
