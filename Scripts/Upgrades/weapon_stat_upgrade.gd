class_name WeaponStatUpgrade
extends BaseUpgrade
## One [WeaponUpgrade] for one weapon, as a card on the Base's UPGRADE screen.
##
## Built by [BaseUpgradeScreen] for every upgrade an owned weapon lists in
## [member WeaponDefinition.upgrades], so there is no [code].tres[/code] of these to
## keep in step with the roster. Like every [BaseUpgrade] it keeps nothing: the
## level is read off the weapon and a purchase raises it there through
## [method WeaponDefinition.raise_upgrade].

## The locker the ammo capacity bonus is pushed into after a purchase, so a
## refill on setting out already fills to the new ceiling.
@export var ammo_locker_path: NodePath = ^"/root/Ammo"

var weapon: WeaponDefinition
var upgrade: WeaponUpgrade


static func create(for_weapon: WeaponDefinition, for_upgrade: WeaponUpgrade) -> WeaponStatUpgrade:
	var made := WeaponStatUpgrade.new()
	made.weapon = for_weapon
	made.upgrade = for_upgrade
	made.display_name = for_upgrade.display_name
	made.level_costs = for_upgrade.level_costs.duplicate()
	return made


func get_level(_from: Node) -> int:
	return 0 if weapon == null else weapon.get_upgrade_level(upgrade)


func get_max_level(_from: Node) -> int:
	return 0 if upgrade == null else maxi(upgrade.max_level, 0)


func _apply(from: Node) -> bool:
	if weapon == null or not weapon.raise_upgrade(upgrade):
		return false
	if from != null and from.is_inside_tree():
		weapon.sync_ammo_capacity(from.get_node_or_null(ammo_locker_path) as AmmoLocker)
	return true


func get_effect_text(from: Node) -> String:
	if upgrade == null:
		return ""
	var level := get_level(from)
	if is_maxed(from):
		return upgrade.describe_level(level)
	return upgrade.describe_step(level)
