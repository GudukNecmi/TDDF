extends SceneTree
## Opens the real M map screen on the real Dust Camp and photographs it, so what
## the player actually sees can be looked at rather than inferred from the
## checks in [code]world_map_screen_smoke.gd[/code].
##
## Run with (no [code]--headless[/code]: it has to actually draw):
## [codeblock]
## godot --path . --script res://Scripts/Dev/world_map_screen_preview.gd
## [/codeblock]
##
## Writes [code]user://world_map_screen_<name>.png[/code]: the map as the player
## rides out knowing only what they have been told, and the map again after two
## camps have been found.
##
## [b]M is pressed, not called.[/b] The screen is opened by feeding the project's
## own [code]open_world_map[/code] action into the input system, so what is
## photographed is what the key actually does - the gate, the pause and the tab
## included - rather than a method this script reached in and called.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
## Long enough for the map's staged prop spawning to finish and for the fog to
## settle around wherever the player is standing.
const SETTLE_FRAMES := 150
## The camps ridden to before the second photograph.
const RIDE_TO: Array[StringName] = [&"normal_camp_a3", &"bounty_camp_a1"]

var _map: Node
var _player: Node2D


func _initialize() -> void:
	_run()


func _run() -> void:
	MapKnowledge.forget_all()
	_map = load(MAP_PATH).instantiate()
	root.add_child(_map)
	for i in SETTLE_FRAMES:
		await process_frame

	_player = get_first_node_in_group(&"player") as Node2D
	if _player == null:
		push_error("no player on the map")
		quit(1)
		return

	await _open_map()
	await _shot("heard_of_only")
	await _close_map()

	for id: StringName in RIDE_TO:
		await _ride_to(id)

	await _open_map()
	await _shot("after_riding")
	_report()
	quit(0)


## Presses M the way a player does.
func _open_map() -> void:
	_press(&"open_world_map")
	for i in 8:
		await process_frame


func _close_map() -> void:
	_press(&"open_world_map")
	for i in 8:
		await process_frame


func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Stands the player at a location long enough for the region's own fog to
## notice it, which is the only thing that ever records a discovery.
func _ride_to(location_id: StringName) -> void:
	var target := _find_location(location_id)
	if target == null:
		push_warning("no location %s on the map" % location_id)
		return
	for i in 40:
		_player.global_position = target.global_position
		await physics_frame
	print("rode to %s - discovered=%s" % [location_id, MapKnowledge.is_discovered(location_id)])


func _report() -> void:
	var screen := _find_screen()
	if screen == null:
		print("no map screen found")
		return
	for entry: WorldMapScreen.Entry in screen.get_entries():
		print("  %s  %s" % [
			"MARKER" if entry.discovered else "?     ",
			entry.display_name if entry.discovered else "(heard of only)"])
	print("map shows %d places, %d of them found"
		% [screen.get_entries().size(), MapKnowledge.count_at_least(MapKnowledge.Tier.DISCOVERED)])


func _find_screen() -> WorldMapScreen:
	var menu := WorldMapOverlayMenu.get_active(root)
	return null if menu == null else _first_screen(menu)


func _first_screen(node: Node) -> WorldMapScreen:
	for child: Node in node.get_children():
		if child is WorldMapScreen:
			return child as WorldMapScreen
		var found := _first_screen(child)
		if found != null:
			return found
	return null


func _find_location(location_id: StringName) -> WorldMapLocation:
	for node: Node in get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location != null and location.get_location_id() == location_id:
			return location
	return null


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var path := "user://world_map_screen_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("wrote %s" % ProjectSettings.globalize_path(path))
