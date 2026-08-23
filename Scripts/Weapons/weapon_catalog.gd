class_name WeaponCatalog
extends Resource
## Every weapon the game knows about, in the order they are offered.
##
## One resource holding the roster, rather than a copy of the list on each thing
## that needs it. The selection screen builds its buttons from this and the
## world's [WeaponMount] looks up what to build in the same file, so the two can
## never disagree about which weapons exist - and a third weapon is one entry seen
## by both.

## The weapons, in menu order.
@export var weapons: Array[WeaponDefinition] = []


## The weapon with [param weapon_id], or null when the catalogue has none - which
## every caller reads as "nothing is known about this weapon".
func find(weapon_id: StringName) -> WeaponDefinition:
	for weapon: WeaponDefinition in weapons:
		if weapon != null and weapon.weapon_id == weapon_id:
			return weapon
	return null


## The weapons that can actually be picked right now.
func unlocked_weapons() -> Array[WeaponDefinition]:
	var open: Array[WeaponDefinition] = []
	for weapon: WeaponDefinition in weapons:
		if weapon != null and weapon.unlocked:
			open.append(weapon)
	return open


## What the player carries when they have not chosen anything - the first weapon
## that can be taken. It is worked out rather than named, so the fallback follows
## the roster instead of being a second place the shotgun is written down.
func get_default() -> WeaponDefinition:
	var open := unlocked_weapons()
	return open[0] if not open.is_empty() else null
