class_name MapKnowledge
extends RefCounted
## What the player knows about the world's places - the one thing the M map
## screen reads. A location is UNKNOWN, KNOWN or DISCOVERED and never anything
## else.
##
## [b]Two tiers, because a map is worth having before it is complete.[/b]
## [constant Tier.KNOWN] is having been told a place exists without ever having
## stood at it: [WorldMapScreen] prints it as a question mark at the right spot
## on the map, so the player can ride towards something they have only heard of.
## [constant Tier.DISCOVERED] is having actually been there, and is the only tier
## that earns the place's own marker and name.
##
## [b]Knowledge is only ever gained.[/b] [method mark_known] cannot pull a
## discovered place back down to a rumour and nothing here erases an entry, the
## same one-way rule [method BountyFact.reveal] already follows - forgetting a
## place the player has ridden to is not something this game does.
##
## [b]Discovery is not measured here.[/b] [WorldMapFog] already decides what the
## player has physically seen, and [WorldMapLocation] already refreshes itself
## off [signal WorldMapFog.fog_changed]; all that was added is that a location
## going VISIBLE writes itself down here on the way past - see
## [method WorldMapLocation._refresh_state]. Nothing in this file looks at a
## position, a radius or a fog cell, so there is no second discovery rule that
## could disagree with the world the player is actually looking at.
##
## [b]Static, and that is what makes it survive a run.[/b] Fog is deliberately
## run-only and [method WorldMapState.forget_all] throws away everything a region
## remembered the moment a run ends - which is right for where the bandits were
## standing and wrong for a map the player has filled in. Static storage lives
## for as long as the game process does, exactly as an autoload like
## [ExtractionUnlockState] does, without this needing a scene, a signal or an
## entry in the project's autoload list. Every caller goes through the static
## methods below, so promoting this to an autoload later - to give it signals, or
## an inspector - would not change one line of calling code.
##
## [b]The Cartographer is not built yet.[/b] [method mark_known] is the seam he
## will sell through; today the only thing that calls it is a location whose own
## [member MapLocation.known_from_start] says the player rode out already having
## heard of the place. Nothing in this file knows what a Cartographer is.

## How well the player knows one place. The order is the order knowledge is
## gained in, so [method mark_known] can refuse to move backwards with a
## comparison rather than with a table of what may follow what.
enum Tier {
	## Never heard of. Drawn nowhere at all.
	UNKNOWN,
	## Heard of but never stood at. Drawn as a question mark.
	KNOWN,
	## Actually been there. Drawn as the place's own marker.
	DISCOVERED,
}

## What a location this has never been told about counts as. Unknown, so a map
## opened before the player has ridden anywhere is empty rather than complete.
const DEFAULT_TIER := Tier.UNKNOWN

## Every id anything has said anything about, as location_id to a [enum Tier].
## Static so that ending a run, changing region and rebuilding the World Map all
## leave it exactly as it was - see the class doc.
static var _tiers: Dictionary = {}


## How well the player knows [param location_id] right now.
static func get_tier(location_id: StringName) -> Tier:
	if location_id.is_empty():
		return DEFAULT_TIER
	return _tiers.get(location_id, DEFAULT_TIER)


## Whether the player has heard of this place at all - either tier. What decides
## whether the map draws anything here.
static func is_known(location_id: StringName) -> bool:
	return get_tier(location_id) >= Tier.KNOWN


## Whether the player has actually stood at this place. What decides whether the
## map draws its real marker rather than a question mark.
static func is_discovered(location_id: StringName) -> bool:
	return get_tier(location_id) == Tier.DISCOVERED


## Says the player has heard of this place without having been to it. The seam a
## later Cartographer sells through, and what
## [member MapLocation.known_from_start] uses for a place the player rode out
## already knowing about.
##
## Refuses to lower a place that has already been discovered - see the class doc -
## and answers whether the tier actually moved, so a caller can tell "this is
## news" from "they knew that already".
static func mark_known(location_id: StringName) -> bool:
	return _raise(location_id, Tier.KNOWN)


## Says the player has physically found this place. Called by [WorldMapLocation]
## the first time [WorldMapFog] reports it VISIBLE, never by anything that
## measures a distance of its own.
##
## Answers whether the tier actually moved, which is the signal a later
## "discovered a new place" notice would be raised on.
static func mark_discovered(location_id: StringName) -> bool:
	return _raise(location_id, Tier.DISCOVERED)


## Every id this knows anything about, for a developer readout and for
## [method to_save_dictionary].
static func get_recorded_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in _tiers.keys():
		ids.append(key as StringName)
	return ids


## How many places are at [param tier] right now - what a smoke check and a
## developer readout ask rather than walking the dictionary themselves.
static func count_at_least(tier: Tier) -> int:
	var total := 0
	for key: Variant in _tiers:
		if _tiers[key] >= tier:
			total += 1
	return total


## Throws everything away. [b]Not what ending a run does[/b] - the whole point of
## this class is that a run ending leaves it alone. It exists for a new game, and
## for a headless check that wants to start from a player who has never ridden
## anywhere.
static func forget_all() -> void:
	_tiers.clear()


## The whole of what the player knows, flattened to plain values, so a save
## system later has something to write without this class changing. There is no
## save system in the project today - see [BountyLedger]'s own note - and this is
## deliberately the same shape [method BountyFact.to_save_dictionary] already
## offers for exactly that eventual reader.
static func to_save_dictionary() -> Dictionary:
	var data: Dictionary = {}
	for key: Variant in _tiers:
		data[String(key)] = int(_tiers[key])
	return data


## Reads back what [method to_save_dictionary] wrote, over the top of whatever is
## already here - each id is raised to the saved tier rather than replacing it,
## so restoring can only ever agree with knowledge already gained.
static func restore_from_dictionary(data: Dictionary) -> void:
	for key: Variant in data:
		_raise(StringName(key), int(data[key]) as Tier)


static func _raise(location_id: StringName, tier: Tier) -> bool:
	if location_id.is_empty() or tier <= DEFAULT_TIER:
		return false
	if get_tier(location_id) >= tier:
		return false
	_tiers[location_id] = tier
	return true
