class_name MapLocation
extends Resource
## Physical World Map location data - a discoverable point on the map that a
## later system (bounties, camps, extraction, a market, ...) can read without
## the World Map itself knowing anything about what happens there.
##
## [b]Phase 3A only ever places these.[/b] Nothing here is gameplay: no script
## reads [member location_type] to do anything yet, and none should until the
## system that owns that type of location is actually built. This is the
## clean data shape [WorldMapLocationMarker] draws a placeholder for, and the
## one later systems are meant to discover locations through - walking
## [code]WorldMap/Locations[/code] and reading each marker's resource, rather
## than anything being hardcoded onto [WorldMap] itself.

## The physical kind of location this is. Generic on purpose, so a future
## system finds every location of its kind without WorldMap knowing that
## system exists.
enum LocationType {
	BOUNTY_CAMP,
	NORMAL_CAMP,
	TAVERN,
	MARKET,
	ARENA,
	EXTRACTION,
	## Added in Phase 3B-3A, appended rather than inserted so every existing
	## location's already-serialized [member location_type] int keeps meaning
	## exactly what it always has.
	BLOOD_DEPOT,
	## A Travel Portal - a fast-travel connector between two points of the
	## World Map. Appended for the same reason [constant BLOOD_DEPOT] was: no
	## existing location's serialized [member location_type] int shifts. See
	## [TravelPortal].
	TRAVEL_PORTAL,
}

## Stable handle for this location, unique across the whole map.
@export var location_id: StringName = &""
## What kind of location this physically is.
@export var location_type: LocationType = LocationType.NORMAL_CAMP
## Which region this location sits inside - the same region_id
## [MapRegion] and [WorldMapRegionZone] already use.
@export var region_id: StringName = &""
## Where this location sits, in the World Map's own local space.
@export var world_position: Vector2 = Vector2.ZERO
## What is shown for this location once something reads it aloud.
@export var display_name: String = ""
## Whether this location is currently live. A disabled location is data the
## World Map still knows about but nothing should offer the player yet.
@export var enabled: bool = true
