extends SceneTree
## Takes pictures of the run map's node interaction and discovery, so the rings,
## the hover name and the camera flying out to a bounty can be looked at rather
## than only measured, and quits.
##
## Run it windowed - it needs a renderer:
## [codeblock]
## godot --path . --script res://Scripts/Dev/run_map_discovery_shot.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const OUT_DIR := "user://run_map_discovery_shots"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	# A bounty boss point only exists where a contract does - see
	# [RunMapBountyBossNode] - so one is taken off the board before the map is
	# laid out, exactly as the player would have taken it before riding out.
	var ledger: BountyLedger = root.get_node_or_null(^"Bounties")
	if ledger != null:
		for _attempt: int in range(6):
			var taken := false
			for bounty: Bounty in ledger.get_board_bounties():
				if ledger.accept(bounty):
					taken = true
					break
			if taken:
				break
			ledger.refresh_board()

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(40):
		await process_frame

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var screen := _find("RunMapSaloonScreen") as RunMapSaloonScreen
	if director == null or view == null or travel == null or screen == null:
		print("no run map in the tree")
		quit(1)
		return

	var graph := director.get_graph()
	await _shoot("1_opening")
	print("known at the start: %d of %d" % [_known(graph), graph.sites.size()])

	# The mouse resting on the next point along, and then on a place across the
	# map with no road to it from here.
	var choices := graph.neighbours_of(graph.current_id)
	if not choices.is_empty():
		_hover(view, choices[0])
		for _frame: int in range(8):
			await process_frame
		await _shoot("2_hover_a_road")
	var far := _far_unknown(graph)
	if far >= 0:
		_hover(view, far)
		for _frame: int in range(8):
			await process_frame
		await _shoot("3_hover_a_stranger")

	# Ridden one road, so the ring of points it opened up can be counted.
	var saloon := _kind_site(graph, &"saloon")
	var step: int = saloon.id if saloon != null else choices[0]
	travel.travel_finished.emit(step)
	view.place_token_at(step)
	for _frame: int in range(12):
		await process_frame
	print("known after arriving: %d of %d" % [_known(graph), graph.sites.size()])
	if screen.is_open():
		await _shoot("4_arrived")
	else:
		await _shoot("4_arrived")

	if saloon == null:
		print("this map dealt out no saloon")
		quit(0)
		return

	if not screen.is_open():
		view._pick(saloon.position)
		for _frame: int in range(8):
			await process_frame

	# The subject that points a wanted man out.
	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Information")
	for _frame: int in range(6):
		await process_frame
	await _shoot("5_subjects")

	var rows := _rows(screen)
	var wanted := _bounty_row(screen)
	if wanted >= 0 and wanted < rows.size():
		rows[wanted].pressed.emit()
		for _frame: int in range(6):
			await process_frame
		await _shoot("6_told")

	screen.close()
	for _frame: int in range(20):
		await process_frame
	await _shoot("7_camera_out")
	# Boxed in an array: a GDScript lambda captures a plain local by value, so a
	# bare bool set inside one never reaches the loop testing it.
	var shown := [false]
	view.presentation_revealed.connect(func(_id: int) -> void: shown[0] = true)
	while view.is_presenting() and not bool(shown[0]):
		await process_frame
	for _frame: int in range(2):
		await process_frame
	await _shoot("8_framed")
	var frames := 0
	while view.is_presenting() and frames < 2000:
		frames += 1
		await process_frame
	for _frame: int in range(20):
		await process_frame
	await _shoot("9_back_on_the_map")
	print("known after the saloon: %d of %d" % [_known(graph), graph.sites.size()])

	# One road on, so the saloon just left is on screen wearing the been-here
	# ring rather than the standing one.
	# A quiet neighbour rather than whichever comes first, so the picture is of
	# the map itself and not of a bandit decision screen over the top of it.
	var onward := -1
	for neighbour: int in graph.neighbours_of(graph.current_id):
		if not _rowdy(graph.get_site(neighbour).kind):
			onward = neighbour
			break
	if onward >= 0:
		travel.travel_finished.emit(onward)
		view.place_token_at(onward)
		for _frame: int in range(30):
			await process_frame
		if not screen.is_open():
			await _shoot("10_road_behind")
		else:
			screen.close()
			for _frame: int in range(20):
				await process_frame
			await _shoot("10_road_behind")
	print("standing on %s (id %d); visited rings up: %d, current rings up: %d" % [
		graph.get_current_site().kind, graph.current_id,
		_rings(view, ^"VisitedRing"), _rings(view, ^"CurrentRing")])

	print("shots written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)



func _hover(view: RunMapView, site_id: int) -> void:
	view.hover_changed.emit(site_id, view.link_to(site_id))
	var sites: Node = view.get_node_or_null(^"Sites")
	if sites == null:
		return
	for child: Node in sites.get_children():
		var marker := child as RunMapSiteMarker
		if marker != null:
			marker.set_hovered(marker.site_id == site_id)


func _bounty_row(screen: RunMapSaloonScreen) -> int:
	for index: int in range(screen.topics.size()):
		var topic := screen.topics[index]
		if topic != null and topic.reveals_kinds.has(&"bounty"):
			return index
	return -1


func _kind_site(graph: RunMapGraph, kind: StringName) -> RunMapSite:
	for site: RunMapSite in graph.sites:
		if site.kind == kind:
			return site
	return null


func _far_unknown(graph: RunMapGraph) -> int:
	var here := graph.get_current_site()
	var found := -1
	var best := 0.0
	for site: RunMapSite in graph.sites:
		if site.revealed:
			continue
		var distance := site.position.distance_to(here.position)
		if distance > best:
			best = distance
			found = site.id
	return found


func _known(graph: RunMapGraph) -> int:
	var count := 0
	for site: RunMapSite in graph.sites:
		if site.revealed:
			count += 1
	return count


func _rows(screen: RunMapSaloonScreen) -> Array[Button]:
	var found: Array[Button] = []
	var list: Node = screen.get_node_or_null(^"Panel/Body/Pages/Stack/List")
	if list == null:
		return found
	for child: Node in list.get_children():
		var button := child as Button
		if button != null and String(button.name) != "Row":
			found.append(button)
	return found


func _press(screen: RunMapSaloonScreen, path: NodePath) -> void:
	var button := screen.get_node_or_null(path) as Button
	if button != null:
		button.pressed.emit()


func _shoot(shot_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, shot_name])


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


func _rings(view: RunMapView, ring: NodePath) -> int:
	var count := 0
	var sites: Node = view.get_node_or_null(^"Sites")
	if sites == null:
		return 0
	for child: Node in sites.get_children():
		var sprite := child.get_node_or_null(ring) as Sprite2D
		if sprite != null and sprite.visible:
			count += 1
	return count


## Whether arriving on a point of this kind raises a screen over the board.
func _rowdy(kind: StringName) -> bool:
	return kind in [&"bandit_group", &"bandit_camp", &"boss",
		&"bounty", &"saloon"]
