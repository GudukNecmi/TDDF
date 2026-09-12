extends SceneTree
## Headless check of the M map screen and the location knowledge behind it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_map_screen_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on any failure, the same shape
## [code]world_map_horse_smoke.gd[/code] already follows.
##
## [b]It rides the real map to discover a place.[/b] Nothing here calls
## [method MapKnowledge.mark_discovered] to make a check pass - the player is
## stood at a location, the region's own [WorldMapFog] is left to notice, and
## what the screen then draws is read back out of it. A discovery that only
## happened because the test made it happen would prove nothing about the game.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const BASE_PATH := "res://Scenes/World/WorldMapBase.tscn"
const MINIMAP_SCRIPT := "res://Scripts/UI/world_map_minimap.gd"

## The Dust Camp's public places - a saloon, a market, the arena and the two
## road outposts - authored with [member MapLocation.known_from_start], so they
## are on the map as question marks before the player has ridden anywhere.
const KNOWN_AT_START: Array[StringName] = [
	&"saloon_dust_camp",
	&"market_dust_camp",
	&"arena_a",
	&"extraction_a1",
	&"extraction_a2",
]
## The camps, which nobody tells the player about. Not on the map at all until
## they are ridden to.
const HIDDEN_AT_START: Array[StringName] = [
	&"bounty_camp_a1",
	&"bounty_camp_a2",
	&"bounty_camp_a3",
	&"normal_camp_a1",
	&"normal_camp_a2",
	&"normal_camp_a3",
	&"normal_camp_a4",
	&"normal_camp_a5",
]
## The camp ridden to, and what it is called once found.
const RIDDEN_TO := &"normal_camp_a3"
const RIDDEN_TO_NAME := "Middle Flats Bandit Camp"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_check_minimap_removed()
	await _check_map()

	if _failures > 0:
		print("FAILED: %d check(s)" % _failures)
		quit(1)
		return
	print("OK")
	quit(0)


## The gameplay minimap is gone - the script, the node in the World Map every
## region inherits, and the always-on player dot that sat in the middle of it.
func _check_minimap_removed() -> void:
	_check(not ResourceLoader.exists(MINIMAP_SCRIPT), "the minimap script is gone")

	var base := FileAccess.get_file_as_string(BASE_PATH)
	_check(not base.is_empty(), "the World Map base scene reads back")
	_check(not base.contains("world_map_minimap.gd"),
		"the World Map base no longer loads the minimap script")
	_check(not base.contains("name=\"Minimap\""),
		"the World Map base has no Minimap node")
	_check(not base.contains("name=\"PlayerDot\""),
		"and no player dot anywhere on the HUD")


func _check_map() -> void:
	# A player who has never ridden anywhere. Cleared before the map is built,
	# because building it is what seeds the places already heard of.
	MapKnowledge.forget_all()

	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	for i in 10:
		await process_frame

	_check_starting_knowledge()

	var screen := _find_screen()
	if not _check(screen != null, "the MAP tab is a WorldMapScreen"):
		return

	screen.refresh()
	_check(screen.get_entries().size() == KNOWN_AT_START.size(),
		"the map opens on %d question marks (got %d)"
			% [KNOWN_AT_START.size(), screen.get_entries().size()])
	var discovered_now := 0
	for entry: WorldMapScreen.Entry in screen.get_entries():
		if entry.discovered:
			discovered_now += 1
	_check(discovered_now == 0, "none of them is a real marker yet (got %d)" % discovered_now)

	await _ride_to(RIDDEN_TO)

	_check(MapKnowledge.is_discovered(RIDDEN_TO),
		"riding to %s discovers it" % RIDDEN_TO)
	screen.refresh()
	_check(screen.get_entries().size() == KNOWN_AT_START.size() + 1,
		"the camp is now on the map (%d places)" % screen.get_entries().size())
	var named := false
	for entry: WorldMapScreen.Entry in screen.get_entries():
		if entry.discovered and entry.display_name == RIDDEN_TO_NAME:
			named = true
	_check(named, "and it is drawn with its own name and marker")

	# The places still only heard of did not become markers by being on the same
	# screen as one that was found.
	var still_unknown := 0
	for id: StringName in KNOWN_AT_START:
		if not MapKnowledge.is_discovered(id):
			still_unknown += 1
	_check(still_unknown == KNOWN_AT_START.size(),
		"finding one place reveals no other (%d still question marks)" % still_unknown)

	await _check_persistence(map)


## What the player knows before riding anywhere: the public places heard of, the
## camps not, and none of them found.
func _check_starting_knowledge() -> void:
	var heard := 0
	var found := 0
	for id: StringName in KNOWN_AT_START:
		if MapKnowledge.is_known(id):
			heard += 1
		if MapKnowledge.is_discovered(id):
			found += 1
	_check(heard == KNOWN_AT_START.size(),
		"the player rides out having heard of %d places (got %d)"
			% [KNOWN_AT_START.size(), heard])
	_check(found == 0, "but has stood at none of them (got %d)" % found)

	var leaked := 0
	for id: StringName in HIDDEN_AT_START:
		if MapKnowledge.is_known(id):
			leaked += 1
	_check(leaked == 0, "and knows nothing of the %d camps (got %d)"
		% [HIDDEN_AT_START.size(), leaked])


## Stands the player at a location and lets the region's own fog notice, rather
## than recording the discovery by hand - see the class doc.
func _ride_to(location_id: StringName) -> void:
	var target := _find_location(location_id)
	if not _check(target != null, "%s is in the map" % location_id):
		return
	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	if not _check(player != null, "the map has a player to ride"):
		return

	# Held there across several fog recomputes - the fog ticks on its own
	# interval, not on the frame the player arrived.
	for i in 40:
		player.global_position = target.global_position
		await process_frame


## Discovery outlives the run it was made in. A run ending is
## [method WorldMapState.forget_all] and the region scene being freed - which is
## exactly what is done here, before the same map is built again from scratch.
func _check_persistence(map: Node) -> void:
	var state := WorldMapState.get_active(map)
	map.free()
	if state != null:
		state.forget_all()
	for i in 5:
		await process_frame

	_check(MapKnowledge.is_discovered(RIDDEN_TO),
		"the run ending does not unfind %s" % RIDDEN_TO)

	var rebuilt: Node = load(MAP_PATH).instantiate()
	root.add_child(rebuilt)
	for i in 10:
		await process_frame

	_check(MapKnowledge.is_discovered(RIDDEN_TO),
		"and the next run opens the map still knowing it")

	var screen := _find_screen()
	if screen == null:
		return
	screen.refresh()
	_check(screen.get_entries().size() == KNOWN_AT_START.size() + 1,
		"which draws %d places on the new run's map" % screen.get_entries().size())


func _find_screen() -> WorldMapScreen:
	var menu := WorldMapOverlayMenu.get_active(root)
	if menu == null:
		return null
	return _first_screen(menu)


func _first_screen(node: Node) -> WorldMapScreen:
	for child: Node in node.get_children():
		if child is WorldMapScreen:
			return child as WorldMapScreen
		var found := _first_screen(child)
		if found != null:
			return found
	return null


func _find_location(location_id: StringName) -> WorldMapLocation:
	for node: Node in root.get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location != null and location.get_location_id() == location_id:
			return location
	return null


func _check(passed: bool, label: String) -> bool:
	if passed:
		print("  ok   %s" % label)
	else:
		print("  FAIL %s" % label)
		_failures += 1
	return passed
