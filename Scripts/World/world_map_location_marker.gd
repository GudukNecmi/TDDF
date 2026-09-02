class_name WorldMapLocationMarker
extends Node2D
## A placeholder world-space dot for one [MapLocation] - the physical
## stand-in Phase 3A draws so the map is readable while every location's
## actual gameplay is still unbuilt.
##
## Positions and colours itself from [member location] rather than needing a
## node position kept in sync by hand, so moving a camp later is editing one
## resource's [member MapLocation.world_position] rather than a resource and
## a node position both.

## The data this marker stands in for. Assigning a new one moves and
## recolours the marker immediately.
@export var location: MapLocation:
	set(value):
		location = value
		_apply()

@onready var _icon: Sprite2D = get_node_or_null(^"Icon") as Sprite2D

## Placeholder colour per [enum MapLocation.LocationType], purely so the map
## is readable before any of these have real art.
const COLORS := {
	MapLocation.LocationType.BOUNTY_CAMP: Color(0.85, 0.2, 0.15),
	MapLocation.LocationType.NORMAL_CAMP: Color(0.82, 0.62, 0.22),
	MapLocation.LocationType.TAVERN: Color(0.6, 0.38, 0.85),
	MapLocation.LocationType.MARKET: Color(0.25, 0.66, 0.85),
	MapLocation.LocationType.ARENA: Color(0.85, 0.25, 0.6),
	MapLocation.LocationType.EXTRACTION: Color(0.3, 0.85, 0.45),
}
## Placeholder scale per type, so the handful of one-off locations (the
## market, the tavern, an arena) read as more important than a normal camp.
const SCALES := {
	MapLocation.LocationType.BOUNTY_CAMP: 1.15,
	MapLocation.LocationType.NORMAL_CAMP: 0.9,
	MapLocation.LocationType.TAVERN: 1.6,
	MapLocation.LocationType.MARKET: 1.6,
	MapLocation.LocationType.ARENA: 1.8,
	MapLocation.LocationType.EXTRACTION: 1.05,
}


func _ready() -> void:
	_apply()


func _apply() -> void:
	if location == null:
		return
	position = location.world_position
	if _icon == null:
		return
	_icon.modulate = COLORS.get(location.location_type, Color.WHITE)
	var s: float = SCALES.get(location.location_type, 1.0)
	_icon.scale = Vector2(s, s)
	_icon.visible = location.enabled
