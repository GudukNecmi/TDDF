extends SceneTree
## Headless check of the run map's saloon point: that arriving on one opens the
## saloon, that the three things that can be done in one do what they say, and
## that leaving puts the piece back on the map exactly where it was standing.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_saloon_smoke.gd
## [/codeblock]
##
## The saloon is checked in the real scene, through the real screen and the real
## world clock, because what is being measured is the clock the game actually
## moves and the ammunition the game actually carries.

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await _check_saloon()

	print("")
	if _failures == 0:
		print("[PASS] run map saloon: every check passed")
	else:
		print("[FAIL] run map saloon: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_saloon() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(4):
		await process_frame

	var director := _find_first("RunMapDirector") as RunMapDirector
	var view := _find_first("RunMapView") as RunMapView
	var node := _find_first("RunMapSaloonNode") as RunMapSaloonNode
	var screen := _find_first("RunMapSaloonScreen") as RunMapSaloonScreen
	_ok(director != null and view != null and node != null and screen != null,
		"the map opened with its saloon point and its saloon screen")
	if director == null or view == null or node == null or screen == null:
		return

	var graph := director.get_graph()
	_ok(graph != null and not graph.is_empty(), "the map has a graph")
	if graph == null or graph.is_empty():
		return

	var saloon: RunMapSite = null
	for site: RunMapSite in graph.sites:
		if node.answers(site.kind):
			saloon = site
			break
	_ok(saloon != null, "the map dealt out at least one saloon")
	if saloon == null:
		return

	_ok(not screen.is_open(), "the saloon is shut until the piece arrives on one")
	var standing_on := graph.current_id

	# --- walking in ---------------------------------------------------------
	director.site_reached.emit(saloon)
	await process_frame
	_ok(screen.is_open(), "arriving on a saloon opened it")
	_ok(not view.is_picking(), "the map's roads are closed while the saloon is up")
	_ok(screen.get_site() == saloon, "the saloon knows which point it is")

	# --- rest ---------------------------------------------------------------
	var clock: Node = root.get_node_or_null(^"WorldClock")
	var before_degree: float = clock.call(&"get_world_degree")
	var before_day: int = clock.call(&"get_world_day")
	var before_period: int = clock.call(&"get_time_period_index")

	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Rest")
	await process_frame

	var elapsed := (float(clock.call(&"get_world_degree")) - before_degree) \
		+ 360.0 * float(int(clock.call(&"get_world_day")) - before_day)
	_ok(is_equal_approx(snappedf(elapsed, 0.001), 60.0 * float(screen.rest_day_cycles)),
		"resting spent exactly %d day cycles" % screen.rest_day_cycles,
		"%.3f degrees" % elapsed)
	_ok(int(clock.call(&"get_time_period_index"))
			== (before_period + screen.rest_day_cycles) % 6,
		"the day stage moved on by one per cycle slept",
		"period %d from %d" % [clock.call(&"get_time_period_index"), before_period])
	_ok(graph.current_id == standing_on, "resting did not move the piece")

	# --- information --------------------------------------------------------
	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Information")
	await process_frame
	var topic_rows := _rows(screen)
	_ok(topic_rows.size() == screen.topics.size(),
		"every subject the saloon knows about has a row",
		"%d row(s) against %d topic(s)" % [topic_rows.size(), screen.topics.size()])
	if topic_rows.is_empty():
		return

	var line: Label = screen.get_node_or_null(^"Panel/Body/Line") as Label

	# Asked about a subject with nothing behind it - [RunMapSaloonInformation]
	# answers the two that point somewhere out, so the placeholder path is
	# checked on one that points nowhere.
	var quiet := -1
	for index: int in range(screen.topics.size()):
		if screen.topics[index] != null and screen.topics[index].reveals_kinds.is_empty():
			quiet = index
			break
	_ok(quiet >= 0, "the saloon still has a subject with only a placeholder behind it")
	if quiet < 0:
		return

	topic_rows[quiet].pressed.emit()
	await process_frame
	_ok(line != null and line.text == screen.topics[quiet].placeholder_line,
		"a subject nothing answers says its own placeholder line")

	# Whatever eventually knows an answer speaks by listening for the ask and
	# calling tell - the seam the whole information half is built on.
	var answered := "THE MAN YOU ARE AFTER DRINKS AT THE CROSSROADS."
	var teller := func(_topic: RunMapSaloonTopic) -> void: screen.tell(answered)
	screen.information_asked.connect(teller)
	topic_rows[quiet].pressed.emit()
	await process_frame
	_ok(line != null and line.text == answered,
		"a listener that knows the answer is what the bartender says")
	screen.information_asked.disconnect(teller)

	_press(screen, ^"Panel/Body/Back")
	await process_frame
	_ok(_rows(screen).is_empty(), "going back took the list down")

	# --- shopping -----------------------------------------------------------
	var wallet: BloodWallet = root.get_node_or_null(^"Blood") as BloodWallet
	var locker: AmmoLocker = root.get_node_or_null(^"Ammo") as AmmoLocker
	_ok(wallet != null and locker != null, "the blood and the ammunition are there")
	if wallet == null or locker == null:
		return
	wallet.add(5000)

	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Shop")
	await process_frame
	var goods_rows := _rows(screen)
	_ok(goods_rows.size() == screen.goods.size(),
		"everything on the shelf has a row",
		"%d row(s) against %d good(s)" % [goods_rows.size(), screen.goods.size()])
	if goods_rows.is_empty():
		return

	var good := screen.goods[0] as RunMapSaloonAmmoGood
	_ok(good != null, "the first thing on the shelf is a box of rounds")
	if good == null:
		return
	var reserve := locker.get_reserve(good.ammo_type)
	reserve.set_current(0)
	var price := good.get_price(screen)
	var purse := wallet.get_total()

	goods_rows[0].pressed.emit()
	await process_frame
	_ok(reserve.get_current() > 0, "buying a box put rounds in the reserve",
		"%d round(s)" % reserve.get_current())
	_ok(wallet.get_total() == purse - price, "it cost exactly what the row said",
		"%d spent against %d quoted" % [purse - wallet.get_total(), price])

	# A full reserve has nothing left to sell, so the row refuses rather than
	# charging for rounds it cannot hand over.
	reserve.fill()
	_ok(not good.can_buy(screen), "a full reserve is nothing left to sell")

	# --- leaving ------------------------------------------------------------
	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Leave")
	await process_frame
	_ok(not screen.is_open(), "leaving shut the saloon")
	_ok(view.is_picking(), "the map is taking a choice again")
	_ok(graph.current_id == standing_on,
		"the piece is standing on the same point it walked in from")
	_ok(not paused, "the world is running again")


## Every row a list built - the children of the list that are not the hidden
## template the rows were copied from.
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
	if button == null:
		_ok(false, "there is a button at %s" % path)
		return
	button.pressed.emit()


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _find_first(class_name_wanted: String) -> Node:
	return _search(root, class_name_wanted)


func _search(node: Node, wanted: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == wanted:
		return node
	for child: Node in node.get_children():
		var found := _search(child, wanted)
		if found != null:
			return found
	return null
