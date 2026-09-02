extends Label
## Development-only readout for the nearest [WorldMapLocation] to the player -
## its id, type, region, whether the player is in reach, and whether it has
## been discovered and is currently visible.
##
## Not the World Map's real UI - a location's actual prompt is
## [WorldMapLocationDirector]'s shared [InteractionPrompt] - this exists only
## so Phase 3B-3A's foundation can be checked by eye while it is being
## built, the same purpose [code]world_bandit_debug_readout.gd[/code] already
## serves for bandit groups, and it is gated onto the World Map the
## identical way: by asking the World Map's own [WorldZone] whether the
## player is inside it, never a mechanism of its own.
##
## [b]Its own nearest search, not the director's.[/b] It reports whatever
## location is physically closest within [member report_range] regardless of
## fog or [member WorldMapLocation.enabled], the same unguarded search
## [code]world_bandit_debug_readout.gd[/code] already runs - useful for a
## developer checking a location that is not yet interactable, which is
## exactly the case [WorldMapLocationDirector]'s own tracked location would
## never surface.

@export var body_group: StringName = &"player"
## The World Map's own [WorldZone], asked whether the player is inside it so
## this never draws over anywhere else in the game.
@export var zone_id: StringName = &"world_map"
## Only locations within this many pixels of the player are reported at all,
## so the readout goes quiet rather than naming something on the other side
## of the map.
@export var report_range: float = 1400.0


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	var player := get_tree().get_first_node_in_group(body_group) as Node2D
	var nearest := _nearest_location(player)
	if nearest == null:
		text = "LOCATION: -"
		return

	var type_name := _type_name(nearest.get_location_type())
	var region_id := nearest.get_region_id()

	text = "LOCATION: %s  |  %s  |  REGION %s  |  IN RANGE %s  |  DISCOVERED %s  |  VISIBLE %s" % [
		String(nearest.get_location_id()),
		type_name,
		String(region_id) if region_id != &"" else "-",
		"YES" if nearest.is_in_reach(player) else "no",
		"YES" if nearest.is_discovered() else "no",
		"YES" if nearest.is_currently_visible() else "no",
	]


func _nearest_location(player: Node2D) -> WorldMapLocation:
	if player == null:
		return null

	var nearest: WorldMapLocation = null
	var nearest_distance := report_range
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location == null:
			continue
		var distance := location.global_position.distance_to(player.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = location
	return nearest


func _type_name(type: MapLocation.LocationType) -> String:
	var keys := MapLocation.LocationType.keys()
	var index := int(type)
	if index >= 0 and index < keys.size():
		return keys[index]
	return "?"
