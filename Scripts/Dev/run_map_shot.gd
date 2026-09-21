extends SceneTree
## Takes pictures of the Dust Camp run map so it can be looked at rather than
## only measured, and quits.
##
## The run map smoke check proves the numbers - that the bands are tight, that a tick is
## 60° and that the piece arrives. This is the other half: the map as it opens,
## the map halfway through a three-day ride, and the map once the piece has
## arrived and the hour has moved on, so the fog, the roads, the halos and the
## day-stage darkness can each be seen.
##
## Run it windowed - it needs a renderer:
## [codeblock]
## godot --path . --script res://Scripts/Dev/run_map_shot.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const OUT_DIR := "user://run_map_shots"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(30):
		await process_frame
	await _shoot("1_opened")

	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var director := _find("RunMapDirector") as RunMapDirector
	if view == null or travel == null or director == null:
		print("no run map in the tree")
		quit(1)
		return

	var graph := director.get_graph()
	print("points %d, roads %d, bounds %s"
		% [graph.sites.size(), graph.links.size(), graph.bounds()])

	# The longest road out of the start, so the picture is of a multi-tick ride.
	var choices := graph.neighbours_of(graph.current_id)
	var target: int = choices[0]
	for site_id: int in choices:
		if graph.find_link(graph.current_id, site_id).day_cycles \
				> graph.find_link(graph.current_id, target).day_cycles:
			target = site_id
	var link := graph.find_link(graph.current_id, target)
	print("riding a %d day road" % link.day_cycles)

	# Picked with a real mouse rather than by emitting the signal, because the
	# thing worth proving is that nothing on the HUD above the map swallows the
	# press on its way to it.
	var at := view.get_viewport().get_canvas_transform() * graph.get_site(target).position
	print("  controls above the map that stop the mouse: %s" % _blocking_controls())

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	# in_local_coords, because the position above is already in viewport space:
	# left false, Godot would apply the window stretch transform to it again.
	view.get_viewport().push_input(press, true)
	for _frame: int in range(4):
		await process_frame
	print("the click reached the map: %s" % travel.is_travelling())
	for _frame: int in range(48):
		await process_frame
	await _shoot("2_riding")

	var guard := 0
	while travel.is_travelling() and guard < 2000:
		guard += 1
		await process_frame
	for _frame: int in range(20):
		await process_frame
	# Arriving is an encounter now - see [RunMapBanditNode] - and this script is
	# here to photograph the map, not the screen over it. The question is
	# answered the least destructive way the tier allows: anything but the fight,
	# which would leave for the arena; and failing that the screen is simply
	# taken back down.
	_answer_any_encounter()
	for _frame: int in range(10):
		await process_frame
	await _shoot("3_arrived")

	var clock: Node = root.get_node_or_null(^"WorldClock")
	print("arrived on day %d, %s, %.1f degrees" % [
		clock.call(&"get_world_day"),
		clock.call(&"get_time_period_name"),
		clock.call(&"get_world_degree")])

	# One frame per authored hour, so the day-stage lighting can be seen to be
	# six held states rather than a sun crossing the sky.
	for _step: int in range(6):
		clock.call(&"advance_day_cycle")
		for _frame: int in range(6):
			await process_frame
		var period := String(clock.call(&"get_time_period_name"))
		print("  %s at %.1f degrees" % [period, clock.call(&"get_world_degree")])
		await _shoot("4_stage_%s" % period.to_lower())

	# The fog lifted, so every kind of place the distribution dealt out can be
	# seen drawn on the map at once - which is the only way to look at art that
	# ordinary play reveals one point at a time.
	for site: RunMapSite in graph.sites:
		site.revealed = true
	view.refresh()
	for _frame: int in range(6):
		await process_frame
	await _shoot("8_every_kind")

	print("shots written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _shoot(shot_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, shot_name])


## Every visible Control big enough to cover the map that is set to stop the
## mouse - the list to read when a press never reaches the map behind it.
func _blocking_controls() -> PackedStringArray:
	var found := PackedStringArray()
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control.size.x < 60.0 or control.size.y < 40.0:
			continue
		found.append("%s (%s, %s)" % [control.name, control.size,
			"STOP" if control.mouse_filter == Control.MOUSE_FILTER_STOP else "PASS"])
	return found


func _find(wanted: String) -> Node:
	return _search(root, wanted)


func _search(node: Node, wanted: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == wanted:
		return node
	for child: Node in node.get_children():
		var found := _search(child, wanted)
		if found != null:
			return found
	return null


## Answers whatever encounter the arrival raised, preferring an answer that
## leaves the map standing. Does nothing where nothing was raised.
func _answer_any_encounter() -> void:
	var menu := _find("WorldBanditDecisionMenu") as WorldBanditDecisionMenu
	if menu == null or not menu.is_open():
		return
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button == null or not button.visible:
			continue
		if button.get_meta(&"outcome", &"fight") == &"fight":
			continue
		button.pressed.emit()
		return
	menu.close()
