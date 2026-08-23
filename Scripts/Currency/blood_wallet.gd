class_name BloodWallet
extends Node
## The player's blood, kept across runs.
##
## Registered as the [code]Blood[/code] autoload, which is what makes it
## persistent: "Next Run" rebuilds the World scene, and an autoload is the one
## thing in the tree that a [method SceneTree.reload_current_scene] does not
## touch. Nothing in a run's teardown clears it, so the total only ever changes
## through [method add] and [method spend].
##
## It is deliberately ignorant of how blood is earned. [BloodMagnet] deposits
## into it when specks reach the player; [BloodField], [BloodSpray] and
## [BloodStream] - the nodes that actually draw blood - never touch it at all.
## That separation is what lets the visuals be retuned, or replaced, without
## touching the currency.
##
## Access it as [code]Blood[/code] from anywhere: [code]Blood.add(3)[/code],
## [code]Blood.get_total()[/code]. The type is [BloodWallet], so it can still be
## statically typed where a reference is stored.
##
## This is the seam future upgrades hang off: [method can_afford] and
## [method spend] already exist and are unused by the run itself.

## Emitted on every change to the total, whatever caused it. UI should listen to
## this rather than to the deposit and spend signals, so it cannot miss one.
signal changed(total: int)
## Emitted only when blood is earned.
signal deposited(amount: int, total: int)
## Emitted only when blood is paid out.
signal spent(amount: int, total: int)

var _total: int = 0


func get_total() -> int:
	return _total


## Banks [param amount] and returns the new total. Non-positive amounts are
## ignored rather than treated as a withdrawal, so a miscounted collection can
## never quietly drain the wallet.
func add(amount: int) -> int:
	if amount <= 0:
		return _total

	_total += amount
	deposited.emit(amount, _total)
	changed.emit(_total)
	return _total


func can_afford(cost: int) -> bool:
	return cost <= _total


## Pays [param cost] and returns whether it went through. An unaffordable cost
## changes nothing and returns false, so callers can offer a purchase and let
## this be the single place that decides.
func spend(cost: int) -> bool:
	if cost <= 0 or not can_afford(cost):
		return false

	_total -= cost
	spent.emit(cost, _total)
	changed.emit(_total)
	return true


## Moves up to [param amount] from this wallet into [param other] and returns how
## much actually moved. Nothing is created or destroyed: the pair of totals
## always sums to what it did before, so a transfer can never mint or lose blood
## however it is clamped.
##
## This is the single primitive both directions of the base's pool are built on -
## depositing is the player's wallet transferring into [BloodBank], withdrawing is
## the bank transferring back - so neither direction needs its own accounting.
func transfer_to(other: BloodWallet, amount: int) -> int:
	if other == null or other == self:
		return 0

	var moving := mini(amount, _total)
	if moving <= 0:
		return 0

	# Taken out before it is put in, so a failure part way through can only ever
	# leave blood where it started rather than in both places at once.
	if not spend(moving):
		return 0
	other.add(moving)
	return moving


## Wipes the total. Nothing in a run calls this - it exists for a "new save" or a
## debug reset, and is deliberately the only way to lose blood other than
## spending it.
func reset() -> void:
	if _total == 0:
		return
	_total = 0
	changed.emit(_total)
