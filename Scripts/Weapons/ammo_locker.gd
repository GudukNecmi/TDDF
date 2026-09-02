class_name AmmoLocker
extends Node
## Every round the player is carrying, of every kind, kept across the run.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet], [DayClock] and [RunSessionState] are: a [code]class_name[/code]
## matching an autoload's name shadows it and refuses to compile. Reach the live
## one as [code]Ammo[/code]; the type is [AmmoLocker] where a reference has to be
## statically typed.
##
## [b]This is the persistence.[/b] Setting out on a run rebuilds the World scene,
## and an autoload is the one thing in the tree that
## [method SceneTree.reload_current_scene] does not touch - which is exactly how
## the player's blood already survives a run. A weapon rebuilt with the world
## asks for its ammunition and is handed back the same reserve it had before, so
## 47 shells are still 47 shells in the next round and in the camp. Nothing in a
## run's teardown clears them and nothing refills them; the only ways the count
## moves are firing and buying.
##
## It is a filing cabinet and nothing more. One [AmmoReserve] per [AmmoType],
## filed under that type's id - so two weapons chambered for the same round
## share a supply, and two weapons chambered differently cannot touch each
## other's. What ammunition *is* - its capacity, its bundle size, its price -
## lives in the [AmmoType] resource, so the locker never learns anything about
## shells in particular.

## Emitted on every change to any reserve, tagged with which ammunition moved.
## A readout that has not got hold of a specific reserve can listen here.
signal ammo_changed(ammo_id: StringName, current: int, maximum: int)
## Emitted when the weapon in the player's hands changes, so a shop can follow
## what it is allowed to sell for. Carries an empty id when nothing is equipped.
signal equipped_changed(ammo_id: StringName)
## Emitted when a purchase goes through, with what was actually handed over and
## what it cost.
signal ammo_purchased(ammo_id: StringName, rounds: int, cost: int)

## The wallet ammunition is paid for out of, reached by path the way every other
## node in the project reaches an autoload. Resolved on first use rather than in
## [method Node._ready], so it does not matter which of the two autoloads the
## project registers first.
@export var wallet_path: NodePath = ^"/root/Blood"

## Live counts, keyed by [member AmmoType.id].
var _reserves: Dictionary[StringName, AmmoReserve] = {}
var _wallet: BloodWallet
## Which ammunition the weapon currently in hand feeds on. The camp will only
## sell for this one.
var _equipped_id: StringName = &""


## The live count for [param type], created on the first ask and held forever
## after.
##
## [b]Creating it here is what makes the starting load a one-time thing.[/b] The
## resource's [member AmmoType.starting_ammo] is read when the reserve is built
## and never again, so a weapon coming back after a scene rebuild gets the count
## it had rather than a full gun.
func get_reserve(type: AmmoType) -> AmmoReserve:
	if type == null:
		return null
	if type.id == &"":
		push_warning("AmmoLocker: an ammo type with no id cannot be tracked - give it one.")
		return null

	var existing: AmmoReserve = _reserves.get(type.id)
	if existing != null:
		return existing

	var reserve := type.create_reserve()
	_reserves[type.id] = reserve
	# Relayed rather than re-implemented, so the broadcast and the reserve's own
	# signal can never disagree about the count.
	reserve.ammo_changed.connect(_on_reserve_changed.bind(type.id))
	return reserve


## The count for [param ammo_id], or null when no weapon has ever asked for that
## ammunition. Deliberately does not create one: a caller with only an id does
## not know the capacity or the price, so it has nothing to build a reserve from.
func find_reserve(ammo_id: StringName) -> AmmoReserve:
	var reserve: AmmoReserve = _reserves.get(ammo_id)
	return reserve


## Every kind of ammunition the player is carrying. What a future ammo screen
## would list.
func get_reserves() -> Array[AmmoReserve]:
	var all: Array[AmmoReserve] = []
	for reserve: AmmoReserve in _reserves.values():
		all.append(reserve)
	return all


## Notes which ammunition is in the player's hands. Called by [WeaponAmmo] as a
## weapon becomes the active one, so weapon switching - whenever it arrives -
## only has to hand the locker the new weapon.
func set_equipped(ammo_id: StringName) -> void:
	if ammo_id == _equipped_id:
		return
	_equipped_id = ammo_id
	equipped_changed.emit(_equipped_id)


## Puts the locker back to nothing equipped, but only if [param ammo_id] is
## still the one in hand - so a weapon leaving the tree cannot disarm a weapon
## that has already replaced it.
func clear_equipped(ammo_id: StringName) -> void:
	if ammo_id == _equipped_id:
		set_equipped(&"")


func get_equipped_id() -> StringName:
	return _equipped_id


## The wallet, found on the first purchase and held after. A missing wallet makes
## every price unaffordable rather than crashing the shop.
func _get_wallet() -> BloodWallet:
	if _wallet == null:
		_wallet = get_node_or_null(wallet_path) as BloodWallet
	return _wallet


## The count belonging to the weapon in the player's hands, or null when they
## are empty-handed. [b]This is the seam the camp shop hangs off[/b]: it sells
## for whatever this returns, which is what makes "only the equipped weapon's
## ammo can be bought" true without the shop knowing which weapons exist.
func get_equipped_reserve() -> AmmoReserve:
	return find_reserve(_equipped_id)


## Whether a box of [param bundles] can be bought for [param reserve] right now:
## the ammunition is known, there is room for at least some of it, and the player
## has the blood.
func can_purchase(reserve: AmmoReserve, bundles: int = 1) -> bool:
	if reserve == null or bundles <= 0 or reserve.is_full():
		return false
	var type := reserve.get_type()
	if type == null or type.purchase_bundle <= 0:
		return false
	var wallet := _get_wallet()
	return wallet != null and wallet.can_afford(type.cost_for_bundles(bundles))


## How many boxes the player's blood would stretch to. For a shop showing a
## "buy max" button; it does not consider how much room is left.
func max_affordable_bundles(reserve: AmmoReserve) -> int:
	if reserve == null:
		return 0
	var type := reserve.get_type()
	if type == null or type.purchase_cost <= 0:
		return 0
	var wallet := _get_wallet()
	if wallet == null:
		return 0
	# Whole boxes only - a half box cannot be bought, so the remainder is meant
	# to be discarded.
	@warning_ignore("integer_division")
	return wallet.get_total() / type.purchase_cost


## Buys [param bundles] boxes for [param reserve] and returns how many rounds
## were actually handed over; 0 means nothing was bought and nothing was paid.
##
## Blood is taken through [method BloodWallet.spend], which is the single place
## that decides whether a price is affordable, so the locker never has to check
## the total itself beyond offering the button. Rounds that do not fit the
## capacity are refused rather than paid for silently - a purchase is only ever
## made when it can be delivered in full.
func purchase(reserve: AmmoReserve, bundles: int = 1) -> int:
	if not can_purchase(reserve, bundles):
		return 0

	var type := reserve.get_type()
	var rounds := type.rounds_for_bundles(bundles)
	if rounds > reserve.get_max() - reserve.get_current():
		return 0

	var cost := type.cost_for_bundles(bundles)
	if not _get_wallet().spend(cost):
		return 0

	var taken := reserve.add(rounds)
	ammo_purchased.emit(reserve.get_ammo_id(), taken, cost)
	return taken


## Buys a box for whatever the player is holding. What the camp's "buy ammo"
## interaction will call, and the reason it needs to know nothing about weapons.
func purchase_for_equipped(bundles: int = 1) -> int:
	return purchase(get_equipped_reserve(), bundles)


## How many rounds a purchase of [param bundles] boxes would actually hand over:
## the whole box, or only what is left to fill when the player is nearly at
## capacity.
func purchasable_rounds(reserve: AmmoReserve, bundles: int = 1) -> int:
	if reserve == null or bundles <= 0:
		return 0
	var type := reserve.get_type()
	if type == null:
		return 0
	return mini(type.rounds_for_bundles(bundles), reserve.get_max() - reserve.get_current())


## What that purchase would cost. A part box is priced by the round - see
## [method AmmoType.cost_for_rounds] - so a shop can show the real price before
## the player commits to it.
func purchase_price(reserve: AmmoReserve, bundles: int = 1) -> int:
	if reserve == null:
		return 0
	var type := reserve.get_type()
	if type == null:
		return 0

	var rounds := purchasable_rounds(reserve, bundles)
	if rounds >= type.rounds_for_bundles(bundles):
		return type.cost_for_bundles(bundles)
	return type.cost_for_rounds(rounds)


## Whether a purchase would hand anything over and can be paid for. The affordable
## companion to [method can_purchase], for the shop that sells part boxes.
func can_purchase_available(reserve: AmmoReserve, bundles: int = 1) -> bool:
	var rounds := purchasable_rounds(reserve, bundles)
	if rounds <= 0:
		return false
	var wallet := _get_wallet()
	return wallet != null and wallet.can_afford(purchase_price(reserve, bundles))


## Buys as much of [param bundles] boxes as the player has room for, and returns
## how many rounds were handed over.
##
## [b]The difference from [method purchase] is what happens near capacity.[/b]
## That one is all or nothing - it refuses a box that would not fit whole, which
## is right for a vending machine and wrong for a camp: a player four shells short
## of full would be unable to buy anything at all. This hands over the four and
## charges for four. Blood is still only ever taken when rounds are actually
## delivered, and still only through [method BloodWallet.spend].
func purchase_available(reserve: AmmoReserve, bundles: int = 1) -> int:
	if not can_purchase_available(reserve, bundles):
		return 0

	var rounds := purchasable_rounds(reserve, bundles)
	var cost := purchase_price(reserve, bundles)
	# A free part box - a price that rounds to nothing - is still a purchase, so
	# the wallet is only asked when there is something to ask it for.
	if cost > 0 and not _get_wallet().spend(cost):
		return 0

	var taken := reserve.add(rounds)
	ammo_purchased.emit(reserve.get_ammo_id(), taken, cost)
	return taken


## Buys what fits for whatever the player is holding. [b]This is the call the camp
## makes[/b], and the reason the camp needs to know nothing about weapons: which
## ammunition, what it costs and how big a box is are all answered by the equipped
## weapon's own reserve.
func purchase_available_for_equipped(bundles: int = 1) -> int:
	return purchase_available(get_equipped_reserve(), bundles)


## Fills every reserve the player owns to its capacity, and returns how many
## rounds that took in total.
##
## [b]This is a resupply, not a refill of one gun.[/b] It is what setting out on a
## round calls - the player leaves for the arena carrying everything they can
## carry - so it deliberately does not care which weapon is in hand: the rifle's
## rounds are there when they next pick the rifle up. Nothing during a round calls
## it, which is what keeps ammunition something that runs out while the clock is
## running.
##
## Only ammunition a weapon has actually asked for exists to be filled. A type
## nobody has ever carried has no count yet and will be created at its own
## starting load the first time it is.
func refill_all() -> int:
	var added := 0
	for reserve: AmmoReserve in _reserves.values():
		added += reserve.fill()
	return added


## Tops the weapon currently in the player's hands up from the run's own
## Horse Inventory - see [RunInventory] - and returns how many rounds actually
## moved.
##
## [b]Only ever the missing amount, never a fixed refill.[/b] What is asked
## for is [method AmmoReserve.get_max] minus [method AmmoReserve.get_current] -
## a weapon already sitting at 45/60 asks for 15, one already full asks for
## nothing at all - and what is actually taken off [param inventory] is
## whatever its own ammo stacks for that exact [AmmoType] can cover, through
## the same [method RunInventory.remove_item] a Heart or a treasure map would
## be spent through. A reserve that cannot be topped up in full is simply
## topped up by however much the inventory had: nothing here manufactures a
## round that was not already sitting in a stack, and nothing here ever
## touches a Heart or any other category - nothing about this call reaches
## for anything but the one [AmmoType] the equipped weapon actually feeds on.
##
## [b]What "entering a new combat" calls.[/b] The weapon that comes out of a
## fight sitting on 20/60 goes into the next one at 60/60 - not for free, the
## Horse Inventory is charged exactly the 40 that closed the gap - so ammo
## carried home from one fight is what the next one is actually fought with.
## This is deliberately not [method refill_all]: that one is the *free*
## resupply a Base round or a road [DangerDirector] encounter already grants
## on setting out, and stays exactly as it was: this only ever spends what the
## player is carrying.
func resupply_equipped_from_inventory(inventory: RunInventory) -> int:
	if inventory == null:
		return 0
	var reserve := get_equipped_reserve()
	if reserve == null:
		return 0
	var missing := reserve.get_max() - reserve.get_current()
	if missing <= 0:
		return 0
	var type := reserve.get_type()
	if type == null or type.id == &"":
		return 0

	var taken := inventory.remove_item(type.id, missing)
	if taken <= 0:
		return 0

	var added := reserve.add(taken)
	# add() can only ever hand back less than what was just taken off the
	# inventory if something else changed the reserve's own ceiling in
	# between the two calls - vanishingly unlikely, but a round taken off the
	# player is handed straight back rather than risking it vanish, per the
	# class doc's "the count can never be driven below zero" - the identical
	# carefulness this file already affords every other spend.
	if added < taken:
		inventory.add_ammo(type, taken - added)
	return added


## The World Map ambush's own twin of [method resupply_equipped_from_inventory] -
## identical in every other way, but what can move is additionally held to
## [param cap_fraction] of the weapon's own [method AmmoReserve.get_max],
## worked out fresh from that ceiling rather than from whatever the reserve
## happens to be carrying. [WorldMapCombatBridge] calls this instead of the
## ordinary resupply only for the three groups an actual ambush caught the
## player with - see [member WorldBandit.in_ambush] - never for a group simply
## walked into.
##
## [b]The cap is on the capacity, not on the reserve.[/b] A thousand rounds
## sitting in the Horse Inventory still only ever hands over 60% of the gun's
## own maximum the instant an ambush closes - see the worked examples on the
## feature's own design note - so a deep reserve can never buy a fully loaded
## gun at the one moment the game means to punish being caught unprepared.
## Still never more than what is actually missing and still never more than
## what the inventory actually holds, exactly like the ordinary resupply -
## this only ever narrows what [method AmmoReserve.get_max] minus
## [method AmmoReserve.get_current] would otherwise ask for.
func resupply_equipped_from_inventory_ambush(inventory: RunInventory, cap_fraction: float = 0.6) -> int:
	if inventory == null:
		return 0
	var reserve := get_equipped_reserve()
	if reserve == null:
		return 0
	var missing := reserve.get_max() - reserve.get_current()
	if missing <= 0:
		return 0
	var type := reserve.get_type()
	if type == null or type.id == &"":
		return 0

	var cap := int(floor(float(reserve.get_max()) * clampf(cap_fraction, 0.0, 1.0)))
	var wanted := mini(missing, cap)
	if wanted <= 0:
		return 0

	var taken := inventory.remove_item(type.id, wanted)
	if taken <= 0:
		return 0

	var added := reserve.add(taken)
	# See [method resupply_equipped_from_inventory]'s identical note - the
	# same vanishingly unlikely safeguard, kept for the same reason.
	if added < taken:
		inventory.add_ammo(type, taken - added)
	return added


## Re-announces every capacity, for when the authored ceilings themselves have
## moved underneath the reserves - which today is the developer balance panel
## retuning [member AmmoType.max_ammo]. A reserve already reads the new number; this
## is what makes anything watching one redraw against it.
func refresh_capacities() -> void:
	for reserve: AmmoReserve in _reserves.values():
		reserve.refresh_capacity()


## Forgets every count, so the next weapon to ask is handed a fresh reserve at
## its starting load. For a new save or a debug reset; nothing in a run calls it,
## the same way nothing calls [method BloodWallet.reset].
func reset() -> void:
	_reserves.clear()
	set_equipped(&"")


func _on_reserve_changed(current: int, maximum: int, ammo_id: StringName) -> void:
	ammo_changed.emit(ammo_id, current, maximum)
