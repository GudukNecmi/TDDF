class_name RewardChoiceLegendary
extends RewardChoice
## A Weapon Legendary Card: one of the equipped weapon's own
## [member WeaponDefinition.legendaries], switched on for the run through
## [method WeaponDefinition.set_legendary_active] when taken - the same switch the
## developer panel throws.

var weapon: WeaponDefinition
var legendary: WeaponLegendary


static func create(for_weapon: WeaponDefinition, of_legendary: WeaponLegendary,
		at_rarity: UpgradeRarity) -> RewardChoiceLegendary:
	var choice := RewardChoiceLegendary.new()
	choice.weapon = for_weapon
	choice.legendary = of_legendary
	choice.rarity = at_rarity
	return choice


func get_title() -> String:
	return legendary.card_name if legendary != null else ""


func get_description() -> String:
	return legendary.card_description if legendary != null else ""


func get_key() -> StringName:
	return StringName("legendary:%s" % legendary.id) if legendary != null else &""


func apply() -> bool:
	if weapon == null or legendary == null:
		return false
	return weapon.set_legendary_active(legendary, true)
