extends SceneTree
## Takes pictures of the run map's saloon screen so it can be looked at rather
## than only measured, and quits.
##
## The saloon smoke check proves what the three doors do - four day cycles slept,
## the blood really spent, the piece standing where it was. This is the other
## half: the saloon as it opens, the subjects it can be asked about, what it says
## back, and the shelf with its prices on it.
##
## Run it windowed - it needs a renderer:
## [codeblock]
## godot --path . --script res://Scripts/Dev/run_map_saloon_shot.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const OUT_DIR := "user://run_map_saloon_shots"


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
	var node := _find("RunMapSaloonNode") as RunMapSaloonNode
	var screen := _find("RunMapSaloonScreen") as RunMapSaloonScreen
	if director == null or node == null or screen == null:
		print("no saloon in the tree")
		quit(1)
		return

	# Blood in the purse, so the shelf is photographed with its prices live
	# rather than every row greyed out for want of money.
	var wallet: BloodWallet = root.get_node_or_null(^"Blood") as BloodWallet
	if wallet != null:
		wallet.add(5000)

	var graph := director.get_graph()
	var saloon: RunMapSite = null
	for site: RunMapSite in graph.sites:
		if node.answers(site.kind):
			saloon = site
			break
	if saloon == null:
		print("this map dealt out no saloon")
		quit(1)
		return

	# Arriving is announced the way the ride announces it; the ride itself is
	# [run_map_shot.gd]'s picture, not this one's.
	director.site_reached.emit(saloon)
	for _frame: int in range(10):
		await process_frame
	await _shoot("1_saloon")

	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Information")
	for _frame: int in range(6):
		await process_frame
	await _shoot("2_subjects")

	var rows := _rows(screen)
	if not rows.is_empty():
		rows[0].pressed.emit()
		for _frame: int in range(6):
			await process_frame
		await _shoot("3_told")

	_press(screen, ^"Panel/Body/Back")
	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Shop")
	for _frame: int in range(6):
		await process_frame
	await _shoot("4_shelf")
	for row: Button in _rows(screen):
		print("  %s" % row.text)

	rows = _rows(screen)
	if not rows.is_empty():
		rows[0].pressed.emit()
		for _frame: int in range(6):
			await process_frame
		await _shoot("5_bought")

	var clock: Node = root.get_node_or_null(^"WorldClock")
	print("before the rest: day %d, %s" % [
		clock.call(&"get_world_day"), clock.call(&"get_time_period_name")])
	_press(screen, ^"Panel/Body/Back")
	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Rest")
	for _frame: int in range(8):
		await process_frame
	print("after the rest:  day %d, %s" % [
		clock.call(&"get_world_day"), clock.call(&"get_time_period_name")])
	await _shoot("6_rested")

	# Left, so the map underneath can be seen taking a choice again with the
	# piece still standing on the saloon.
	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Leave")
	for _frame: int in range(10):
		await process_frame
	await _shoot("7_back_on_the_road")

	print("shots written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


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
