extends SceneTree
## Takes pictures of the run map's market screen so it can be looked at rather
## than only measured, and quits: the shelf as it opens, a purchase, and the map
## live again after BACK.
##
## Run it windowed - it needs a renderer:
## [codeblock]
## godot --path . --script res://Scripts/Dev/run_map_market_shot.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const OUT_DIR := "user://run_map_market_shots"


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

	var director := _find("RunMapDirector") as RunMapDirector
	var node := _find("RunMapMarketNode") as RunMapMarketNode
	var screen := _find("RunMapMarketScreen") as RunMapMarketScreen
	if director == null or node == null or screen == null:
		print("no market in the tree")
		quit(1)
		return

	var wallet: BloodWallet = root.get_node_or_null(^"Blood") as BloodWallet
	if wallet != null:
		wallet.add(5000)

	var market: RunMapSite = null
	for site: RunMapSite in director.get_graph().sites:
		if node.answers(site.kind):
			market = site
			break
	if market == null:
		print("this map dealt out no market")
		quit(1)
		return

	director.site_reached.emit(market)
	for _frame: int in range(10):
		await process_frame
	await _shoot("1_market")
	for row: Button in _rows(screen):
		print("  %s" % row.text)

	var rows := _rows(screen)
	if not rows.is_empty():
		rows[0].pressed.emit()
		for _frame: int in range(6):
			await process_frame
		await _shoot("2_bought")

	var back := screen.get_node_or_null(^"Panel/Body/Back") as Button
	if back != null:
		back.pressed.emit()
	for _frame: int in range(10):
		await process_frame
	await _shoot("3_back_on_the_road")

	print("shots written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _rows(screen: RunMapSaloonScreen) -> Array[Button]:
	var found: Array[Button] = []
	var list: Node = screen.get_node_or_null(^"Panel/Body/Pages/Stack/List")
	if list == null:
		return found
	for child: Node in list.get_children():
		var button := child as Button
		if button != null and String(button.name) != "Row" and not button.is_queued_for_deletion():
			found.append(button)
	return found


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
