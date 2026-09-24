extends SceneTree
## Takes pictures of the run map's bandit point so it can be looked at rather
## than only measured, and quits.
##
## The bandit smoke checks prove the numbers - that a camp is worth 20 to 40
## men, that the screen says how many, and that the answer ends where it
## should. This is the other half: the camp on the map before it is ridden to,
## the decision screen as the player meets it, and the same map afterwards with
## the camp struck through.
##
## Run it windowed - it needs a renderer:
## [codeblock]
## godot --path . --script res://Scripts/Dev/run_map_bandit_shot.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const OUT_DIR := "user://run_map_shots"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await process_frame
	await process_frame

	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(30):
		await process_frame
	await _shoot("5_camps_ahead")

	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var director := _find("RunMapDirector") as RunMapDirector
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	var menu := _find("WorldBanditDecisionMenu") as WorldBanditDecisionMenu
	if view == null or travel == null or director == null or bandits == null \
			or menu == null:
		print("the run map opened without its bandit wiring")
		quit(1)
		return

	var graph := director.get_graph()
	# Which points are bandit points is the generator's node distribution, so
	# ride on through anything else until one of them raises its screen.
	var target := -1
	for _hop: int in range(24):
		var step := -1
		var spare := -1
		for site_id: int in graph.neighbours_of(graph.current_id):
			var site := graph.get_site(site_id)
			if not site.visited:
				spare = site_id
			if bandits.encounter_for(site.kind) != null:
				step = site_id
				break
		if step < 0:
			step = spare
		if step < 0:
			break
		print("riding to point %d, a '%s'" % [step, graph.get_site(step).kind])
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var guard := 0
		while travel.is_travelling() and guard < 2000:
			guard += 1
			await process_frame
		for _frame: int in range(12):
			await process_frame
		if menu.is_open():
			target = step
			break
	if target < 0:
		print("no bandit point to ride to")
		quit(1)
		return
	print("that one is worth %d men"
		% bandits.enemy_count_for(graph, graph.get_site(target)))
	await _shoot("6_the_bandits")
	print("the screen is up: %s" % menu.is_open())

	var answer: Button = null
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button != null and button.visible:
			answer = button
			print("  offered: \"%s\" (%s)"
				% [button.text, button.get_meta(&"outcome", &"fight")])
	# The last button offered, which is always the fight - but a peaceful answer
	# is taken where the tier has one, since the fight leaves this scene.
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button != null and button.visible \
				and button.get_meta(&"outcome", &"fight") != &"fight":
			answer = button
			break
	if answer == null:
		quit(1)
		return

	answer.pressed.emit()
	for _frame: int in range(20):
		await process_frame
	await _shoot("7_camp_dealt_with")
	print("the point now reads as '%s'" % graph.get_site(target).kind)

	print("shots written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


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
