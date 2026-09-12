extends SceneTree
## Headless check that the journeys into and out of Dust Camp are real scene
## changes through the existing router and curtain.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/dust_camp_journey_smoke.gd
## [/codeblock]
##
## Base to the map, the map to the arena and the arena back to the map are each
## made through [WorldRegionRouter] - the same call the run platform and the
## combat bridge make - and after each one the tree is inspected to confirm the
## place just left is gone rather than merely hidden, and that no other region's
## map was built alongside the one asked for.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	if router == null:
		print("[FAIL] no WorldRouter autoload")
		quit(1)
		return

	# A run has to have picked its map before the router can find a region on
	# it - the same thing the pit does before the run platform is ever used.
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file("res://Scenes/Base/BaseWorld.tscn")
	await process_frame
	await process_frame
	_ok(_scene_name() == "BaseWorld", "the base opens", _scene_name())

	print("--- base to dust camp ---")
	_ok(router.go_to_region(&"A"), "the router accepted the ride")
	await _settle()
	_ok(_scene_name() == "DustCampMap", "dust camp is the current scene", _scene_name())
	_ok(_count_nodes("BaseWorld") == 0, "the base is gone, not hidden behind it")
	_ok(_count_maps() == 1, "exactly one world map is loaded",
		"%d map scenes in the tree" % _count_maps())
	_ok(_find_first("WorldBandit") != null, "the map's bandits exist")
	var world_map := _scene_root().get_node_or_null(^"WorldMap")
	_ok(world_map != null and world_map.get_node_or_null(^"Navigation") != null,
		"the map brought its navigation region")

	print("--- dust camp to the arena ---")
	var carried := {&"return_region": &"A", &"return_position": Vector2(-8680.0, -280.0)}
	_ok(router.go_to_combat(&"A", carried), "the router accepted the fight")
	await _settle()
	_ok(_scene_name() == "DustCampArena", "the arena is the current scene", _scene_name())
	_ok(_count_maps() == 0, "no world map is left rendering behind the fight",
		"%d map scenes in the tree" % _count_maps())
	var region := _find_first("ArenaRegion") as ArenaRegion
	_ok(region != null and region.get_region() != null
			and region.get_region().region_id == &"A",
		"the arena knows it is dust camp's")
	_ok(_find_first("PropScatter") != null, "the arena laid its own props out")
	_ok(_count_nodes("Enemy") == 0, "the arena floor opens clean")

	print("--- the arena back to dust camp ---")
	var state: WorldMapState = root.get_node_or_null(^"WorldState")
	var payload: Dictionary = carried if state == null else state.get_staged_combat()
	if payload.is_empty():
		payload = carried
	_ok(router.return_from_combat(payload), "the router accepted the ride back")
	await _settle()
	_ok(_scene_name() == "DustCampMap", "dust camp is back", _scene_name())
	_ok(_count_nodes("DustCampArena") == 0, "the arena is unloaded, not kept around")
	_ok(root.get_node_or_null(^"WorldClock") != null, "the world clock survived all three")

	print("")
	if _failures == 0:
		print("DUST CAMP JOURNEY SMOKE: all checks passed")
	else:
		print("DUST CAMP JOURNEY SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label, "" if detail.is_empty() else "  -  " + detail])


## Waits out the curtain: its minimum display time, the threaded load and the
## reveal, however long each happens to take.
func _settle() -> void:
	var curtain := LoadingCurtain.get_active(root)
	var guard: int = 0
	while curtain != null and curtain.is_loading() and guard < 2000:
		guard += 1
		await process_frame
	for _step: int in 8:
		await process_frame


func _scene_root() -> Node:
	return current_scene


func _scene_name() -> String:
	var scene := current_scene
	return "<none>" if scene == null else scene.name


func _count_nodes(node_name: String) -> int:
	var found: int = 0
	for node: Node in root.find_children(node_name, "", true, false):
		found += 1
	return found


## How many region map scenes stand in the tree - the check behind "only Dust
## Camp exists". Counted by the [code]world_map[/code] group the map root joins,
## so a second region loaded any way at all would show up.
func _count_maps() -> int:
	return root.get_tree().get_nodes_in_group(&"world_map").size() \
		if root.get_tree() != null else 0


func _find_first(class_name_wanted: String) -> Node:
	for node: Node in root.find_children("*", class_name_wanted, true, false):
		return node
	return null
