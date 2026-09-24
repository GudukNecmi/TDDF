class_name RunMapUpgradeGood
extends RunMapSaloonGood
## One run-only level of one weapon's [WeaponUpgrade], on a run map market's
## shelf.
##
## [b]Not a second copy of the upgrade.[/b] Which upgrade, what it does per level
## and how high it goes are all the existing [WeaponUpgrade] resource's; a
## purchase raises the weapon's run stack through
## [method WeaponDefinition.raise_run_level], and the weapon's own
## [method WeaponDefinition.get_stats] folds that stack in beside the Base levels,
## so combat sees it through the path it already reads. Paid for in carried blood
## through [BloodWallet], never the [BloodBank].
##
## Built by [RunMapMarketProducts] as the shelf is dealt, so there is no
## [code].tres[/code] of these to keep in step with the upgrades.

## Where carried blood is counted.
@export var wallet_path: NodePath = ^"/root/Blood"
## The locker the ammo capacity bonus is pushed into after a purchase, exactly as
## [WeaponStatUpgrade] does for a Base level.
@export var ammo_locker_path: NodePath = ^"/root/Ammo"

var weapon: WeaponDefinition
var upgrade: WeaponUpgrade
## What the first run level costs, in carried blood.
var base_price: int = 0
## What each run level already held adds to the next one's price.
var price_per_level: int = 0
## The most run levels this upgrade can be stacked to. Negative is no cap.
var run_cap: int = -1
## How the row names it: [code]%s[/code] is the upgrade's name and
## [code]%d[/code] the run level buying it reaches.
var label_format: String = "%s  LV %d"
## The run level this product was sold at, so a sold row still names the level
## it sold rather than the next one. -1 while unsold.
var _sold_level: int = -1


static func create(for_weapon: WeaponDefinition, for_upgrade: WeaponUpgrade) -> RunMapUpgradeGood:
	var made := RunMapUpgradeGood.new()
	made.weapon = for_weapon
	made.upgrade = for_upgrade
	made.display_name = for_upgrade.display_name
	# One slot is one product: once bought it is sold for this shelf.
	made.stock = 1
	return made


## Whether [param for_weapon]'s run stack of [param for_upgrade] has room for one
## more level under [param cap]. What the pool deals by, so a maxed stack is never
## put on a shelf.
static func has_room(for_weapon: WeaponDefinition, for_upgrade: WeaponUpgrade, cap: int) -> bool:
	return cap < 0 or for_weapon.get_run_level(for_upgrade) < cap


## The key a shelf remembers this product by, and the key a refresh excludes.
func get_product_key() -> StringName:
	return product_key(weapon, upgrade)


static func product_key(for_weapon: WeaponDefinition, for_upgrade: WeaponUpgrade) -> StringName:
	return StringName("upgrade:%s:%s" % [for_weapon.weapon_id, for_upgrade.id])


func get_label(_from: Node) -> String:
	if weapon == null or upgrade == null:
		return display_name
	var level := _sold_level if _sold_level >= 0 else weapon.get_run_level(upgrade) + 1
	return label_format % [display_name, level]


## Notes this product as already sold - what a shelf walked back into says of a
## slot bought on an earlier visit.
func mark_sold() -> void:
	if weapon != null and upgrade != null:
		_sold_level = weapon.get_run_level(upgrade)


func get_price(_from: Node) -> int:
	if weapon == null or upgrade == null:
		return 0
	return maxi(base_price + price_per_level * weapon.get_run_level(upgrade), 0)


func can_buy(from: Node) -> bool:
	if weapon == null or upgrade == null or not has_room(weapon, upgrade, run_cap):
		return false
	var price := get_price(from)
	if price <= 0:
		return true
	var wallet := _wallet(from)
	return wallet != null and wallet.can_afford(price)


func buy(from: Node) -> bool:
	if not can_buy(from):
		return false
	var price := get_price(from)
	var wallet := _wallet(from)
	if price > 0 and (wallet == null or not wallet.spend(price)):
		return false
	if not weapon.raise_run_level(upgrade, run_cap):
		# A refusal never costs anything.
		if price > 0:
			wallet.add(price)
		return false
	mark_sold()
	if from != null and from.is_inside_tree():
		weapon.sync_ammo_capacity(from.get_node_or_null(ammo_locker_path) as AmmoLocker)
	return true


func _wallet(from: Node) -> BloodWallet:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null(wallet_path) as BloodWallet
