class_name WeaponAmmo
extends Node
## A weapon's magazine: the one node that connects a gun to the ammunition it
## fires.
##
## Drop it under any weapon, point [member ammo_type] at an [AmmoType] resource
## in the inspector, and the weapon has ammunition - a capacity, a starting load,
## a price and a bundle size, all read from that resource. Nothing about which
## weapon it is hangs off this file, so a pistol added later is a new
## [code].tres[/code] and this same node, not a second ammo system.
##
## [b]It holds no count of its own.[/b] The live rounds live in an [AmmoReserve]
## owned by the [code]Ammo[/code] locker ([AmmoLocker]), which is an autoload and
## therefore survives the world being rebuilt between rounds. This node only
## looks that reserve up and asks it questions, which is what makes the count
## persist through a run, and what makes it impossible for a weapon that is
## rebuilt, stowed or swapped away to reset or overwrite it.
##
## The weapon asks two things of it: [method can_fire] before a shot, and
## [method consume] as the shot leaves. Everything else - buying, refilling,
## capacity upgrades - happens on the reserve, from outside, without the weapon
## being involved.

## Emitted whenever this weapon's count changes, for a readout mounted on the
## weapon. The same change is broadcast by the locker for anything further away.
signal ammo_changed(current: int, maximum: int)
## Emitted when the weapon runs dry. It cannot fire again until it is resupplied.
signal emptied()

## The locker the rounds are kept in, reached by path the way every other node
## in the project reaches an autoload.
@export var locker_path: NodePath = ^"/root/Ammo"
## Which ammunition this weapon feeds on. [b]The only field that has to be set[/b]
## - capacity, starting load, bundle size and price all come with it. Two weapons
## pointed at the same resource share one supply; pointed at different resources
## they are entirely independent.
@export var ammo_type: AmmoType
## Rounds spent per shot. One for the shotgun - a shell is a shell however many
## pellets come out of it - but a burst weapon can charge more.
@export var ammo_per_shot: int = 1
## Whether the weapon claims the "in hand" slot while it is in the tree, which is
## what decides the ammunition a shop is allowed to sell for. Turn it off for a
## weapon that is present but not being carried.
@export var equips_on_ready: bool = true

@onready var _locker: AmmoLocker = get_node_or_null(locker_path) as AmmoLocker

var _reserve: AmmoReserve


## The reserve is claimed here rather than lazily, so the ammunition exists - and
## a readout can find it - before the first shot is fired.
func _ready() -> void:
	if _locker == null:
		push_warning("WeaponAmmo on %s cannot reach the ammo locker at %s." % [get_parent().name, locker_path])
		return

	_reserve = _locker.get_reserve(ammo_type)
	if _reserve == null:
		push_warning("WeaponAmmo on %s has no usable ammo type - the weapon will not fire." % get_parent().name)
		return

	_reserve.ammo_changed.connect(_on_ammo_changed)
	_reserve.emptied.connect(emptied.emit)
	if equips_on_ready:
		_locker.set_equipped(_reserve.get_ammo_id())


## Only the slot is given up, never the rounds. A weapon leaving the tree - the
## world being rebuilt, a weapon being swapped out - leaves its count sitting in
## the locker exactly as it was.
func _exit_tree() -> void:
	if _locker != null and _reserve != null and equips_on_ready:
		_locker.clear_equipped(_reserve.get_ammo_id())


## The live count this weapon draws on, for anything that wants to watch or
## resupply it directly.
func get_reserve() -> AmmoReserve:
	return _reserve


func get_current() -> int:
	return _reserve.get_current() if _reserve != null else 0


func get_max() -> int:
	return _reserve.get_max() if _reserve != null else 0


func is_empty() -> bool:
	return get_current() <= 0


## Whether there is enough left for one more shot. A weapon with no ammunition
## configured at all reports false rather than firing forever, so a missing
## resource shows up immediately instead of quietly disabling the whole system.
func can_fire() -> bool:
	return _reserve != null and _reserve.has_ammo(ammo_per_shot)


## Spends one shot's worth and reports whether it went through.
##
## The reserve refuses a spend it cannot cover in full, so the count can never
## be driven below zero however a weapon calls this - and a weapon that checks
## the return value can never fire a shot it did not pay for.
func consume() -> bool:
	return _reserve != null and _reserve.consume(ammo_per_shot)


## Throws [param count] rounds away without a shot being fired, and reports
## whether there were any there to throw.
##
## Deliberately counted in *rounds* rather than in shots, which is why it is not
## [method consume]: a live round worked out of the breech is one round however
## many of them a shot would have spent, so a burst weapon that costs three per
## trigger pull still only loses the one it had chambered.
##
## A weapon with nothing left drops nothing and returns false - it had no round
## in the breech to lose - so working the action on an empty gun is free.
func discard_rounds(count: int = 1) -> bool:
	return _reserve != null and _reserve.consume(count)


## "42 / 60 Shells", for a readout. Built from the ammo type's own naming, so a
## rifle round reads correctly with no extra work.
func describe() -> String:
	if _reserve == null or ammo_type == null:
		return ""
	return "%d / %d %s" % [get_current(), get_max(), ammo_type.get_plural_name()]


func _on_ammo_changed(current: int, maximum: int) -> void:
	ammo_changed.emit(current, maximum)
