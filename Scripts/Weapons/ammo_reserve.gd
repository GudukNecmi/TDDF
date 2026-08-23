class_name AmmoReserve
extends RefCounted
## How much of one kind of ammunition the player is actually carrying.
##
## An [AmmoType] says what shells *are* - their capacity, their price, their
## name. This is the live count of them, and there is exactly one of these per
## ammo type for the whole session, handed out by the [code]Ammo[/code] locker
## ([AmmoLocker]). That one-per-type rule is the whole of the "each weapon keeps
## its own ammo" requirement: a pistol asks for its own reserve, gets a
## different object, and neither can see or spend the other's rounds. Putting
## the shotgun away and taking it out again finds its shells exactly as it left
## them, because nothing was ever copied anywhere to be overwritten.
##
## [b]Capacity is deliberately two numbers.[/b] The resource's
## [member AmmoType.max_ammo] is the base, and [member _capacity_bonus] is
## everything a shop, a perk or an upgrade has added on top. The base weapon
## shop will call [method set_capacity_bonus] and nothing else; it never writes
## to the [code].tres[/code], so the authored capacity stays the authored
## capacity and an upgrade is a number that can be recalculated or cleared.
##
## It is a [RefCounted] rather than a [Resource] on purpose: it is run state,
## not authored content, so it should never be saveable to - or accidentally
## shared through - a file on disk.

## Emitted on every change to the count, whatever caused it - firing, buying,
## refilling. A readout should listen to this rather than to firing, so it
## cannot miss a change made by something else.
signal ammo_changed(current: int, maximum: int)
## Emitted when the last round is spent. The shot that empties the reserve still
## happens; this fires straight after it.
signal emptied()
## Emitted when the carrying capacity changes, which today only an upgrade can
## do.
signal capacity_changed(maximum: int)

var _type: AmmoType
var _current: int = 0
## Everything added to the base capacity from outside. Owned by upgrades; zero
## on a fresh reserve.
var _capacity_bonus: int = 0


func _init(type: AmmoType) -> void:
	_type = type
	if _type != null:
		_current = clampi(_type.starting_ammo, 0, get_max())


## The authored data behind this count - name, price, bundle size.
func get_type() -> AmmoType:
	return _type


## The id this reserve is filed under in the locker.
func get_ammo_id() -> StringName:
	return _type.id if _type != null else &""


func get_current() -> int:
	return _current


## The live capacity: what the resource authored, plus whatever upgrades have
## added. Never below zero, so a bonus that has been driven negative cannot
## produce a nonsensical ceiling.
func get_max() -> int:
	if _type == null:
		return 0
	return maxi(_type.max_ammo + _capacity_bonus, 0)


## Just the upgraded part, so a shop can show what it has already sold.
func get_capacity_bonus() -> int:
	return _capacity_bonus


## Sets the upgrade on top of the authored capacity. [b]This is the whole of how
## max ammo is raised[/b] - the base weapon shop will call this, and nothing else
## needs to change for it to work.
##
## Lowering the capacity spills the rounds that no longer fit rather than leaving
## a count above its own ceiling.
func set_capacity_bonus(bonus: int) -> void:
	if bonus == _capacity_bonus:
		return
	_capacity_bonus = bonus
	refresh_capacity()


## Re-reads the ceiling and announces it, spilling anything that no longer fits.
##
## The bonus is not the only thing that can move a capacity: the authored
## [member AmmoType.max_ammo] underneath it can be retuned too - by the developer
## balance panel today - and a reserve reads that live, so the number is already
## right the moment it changes and simply nobody has been told. This is how they
## are told, and it is why the two paths share one routine rather than each
## clamping and announcing in its own way.
func refresh_capacity() -> void:
	var ceiling := get_max()
	capacity_changed.emit(ceiling)
	if _current > ceiling:
		_set_current(ceiling)
	else:
		# Announced anyway: a readout showing "42 / 60" has to redraw when the 60
		# moves even though the 42 did not.
		ammo_changed.emit(_current, ceiling)


## Adds [param amount] to the capacity an upgrade has already bought. What a
## "+10 shells" purchase calls, so buying two of them stacks without the shop
## having to track a running total of its own.
func add_capacity(amount: int) -> void:
	set_capacity_bonus(_capacity_bonus + amount)


func is_empty() -> bool:
	return _current <= 0


func is_full() -> bool:
	return _current >= get_max()


## Whether there are at least [param amount] rounds left. A weapon asks this
## before it fires, with its own rounds-per-shot.
func has_ammo(amount: int = 1) -> bool:
	return amount <= 0 or _current >= amount


## Spends [param amount] rounds and returns whether it went through.
##
## [b]All or nothing.[/b] A shot that cannot be paid for in full changes nothing
## and returns false, so a weapon can offer to fire and let this be the single
## place that decides - and the count can never be driven below zero.
func consume(amount: int = 1) -> bool:
	if amount <= 0 or not has_ammo(amount):
		return false

	_set_current(_current - amount)
	if _current <= 0:
		emptied.emit()
	return true


## Puts [param amount] rounds in and returns how many actually fit. Anything over
## the capacity is refused rather than silently held, so a purchase can report
## honestly what the player got.
func add(amount: int) -> int:
	if amount <= 0:
		return 0

	var room := get_max() - _current
	var taken := mini(amount, maxi(room, 0))
	if taken <= 0:
		return 0

	_set_current(_current + taken)
	return taken


## Fills to capacity and returns how many rounds that took. A free refill would
## use this; the camp's paid one goes through [method AmmoLocker.purchase].
func fill() -> int:
	return add(get_max() - _current)


## Forces the count, clamped to the capacity. For a save being loaded or a debug
## command - ordinary play only ever goes through [method consume] and
## [method add].
func set_current(amount: int) -> void:
	_set_current(clampi(amount, 0, get_max()))


## Back to the authored starting load. Nothing in a run calls this: ammunition
## surviving a new round is the point. It exists for a new save or a debug
## reset, exactly as [method BloodWallet.reset] does.
func reset() -> void:
	_capacity_bonus = 0
	set_current(_type.starting_ammo if _type != null else 0)


## The one place the count is written, so every change is announced exactly once
## however it was made.
func _set_current(value: int) -> void:
	if value == _current:
		return
	_current = value
	ammo_changed.emit(_current, get_max())
