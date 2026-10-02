class_name RewardChoicePool
extends Resource
## Where one kind of reward card is dealt from - normal Upgrade Cards, Weapon
## Legendaries, and later Legendary Upgrades.
##
## [b]A pool reads the weapon's own data and nothing else.[/b] What it can deal
## is whatever the [WeaponDefinition] lists, so a new upgrade or Legendary added
## to a weapon is dealt here without this or any screen changing. A new kind of
## card is a new subclass and an entry in [member RewardChoiceGenerator.entries].


## Override: one card for [param weapon], none of whose
## [method RewardChoice.get_key] is in [param excluded]. Null when nothing is
## left to deal.
func draw(_weapon: WeaponDefinition, _rng: RandomNumberGenerator,
		_excluded: Array[StringName] = []) -> RewardChoice:
	return null
