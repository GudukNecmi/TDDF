class_name RewardChoiceUpgrade
extends RewardChoice
## A normal Upgrade Card: one of the weapon's own [WeaponUpgrade]s at a rarity.
##
## [b]It is the existing run-only upgrade, not a second stat system.[/b] Taking it
## raises the upgrade's run stack by [member UpgradeRarity.strength_multiplier]
## levels through [method WeaponDefinition.raise_run_level] with no cap, so an
## Epic +10% DAMAGE card is four run levels - +40% - and every further copy adds
## on top for as long as the run lasts.

var weapon: WeaponDefinition
var upgrade: WeaponUpgrade


static func create(for_weapon: WeaponDefinition, of_upgrade: WeaponUpgrade,
		at_rarity: UpgradeRarity) -> RewardChoiceUpgrade:
	var choice := RewardChoiceUpgrade.new()
	choice.weapon = for_weapon
	choice.upgrade = of_upgrade
	choice.rarity = at_rarity
	return choice


## How many run levels taking this card adds.
func get_levels() -> int:
	return maxi(rarity.strength_multiplier, 1) if rarity != null else 1


func get_title() -> String:
	return upgrade.card_name if upgrade != null else ""


func get_description() -> String:
	return upgrade.describe_card(get_levels()) if upgrade != null else ""


func get_key() -> StringName:
	return StringName("upgrade:%s" % upgrade.id) if upgrade != null else &""


func apply() -> bool:
	if weapon == null or upgrade == null:
		return false
	return weapon.raise_run_level(upgrade, -1, get_levels())
