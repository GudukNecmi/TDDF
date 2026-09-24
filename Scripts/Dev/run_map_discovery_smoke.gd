extends SceneTree
## Headless check of the run map's node interaction and discovery: that standing
## somewhere turns over the points its roads lead to, that the point underfoot
## can be walked back into unless it was a fight, that the map names whatever the
## mouse is resting on, and that a place the bartender points out comes out from
## under its question mark and stays out.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_discovery_smoke.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await _check()

	print("")
	if _failures == 0:
		print("[PASS] run map discovery: every check passed")
	else:
		print("[FAIL] run map discovery: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _check() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	# A bounty boss point only exists where a contract does - see
	# [RunMapBountyBossNode] - so one is taken off the board before the map is
	# laid out, exactly as the player would have taken it before riding out.
	_take_a_contract()

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(4):
		await process_frame

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var panel := _find("RunMapPanel") as RunMapPanel
	var screen := _find("RunMapSaloonScreen") as RunMapSaloonScreen
	var informant := _find("RunMapSaloonInformation") as RunMapSaloonInformation
	_ok(director != null and view != null and travel != null and panel != null
			and screen != null and informant != null,
		"the map opened with its panel, its saloon and its bartender")
	if director == null or view == null or travel == null or panel == null \
			or screen == null or informant == null:
		return

	var graph := director.get_graph()
	if graph == null or graph.is_empty():
		_ok(false, "the map has a graph")
		return

	# --- discovery from where the run opens ---------------------------------
	var start := graph.start_id
	var opening_known := true
	for neighbour: int in graph.neighbours_of(start):
		if not graph.get_site(neighbour).revealed:
			opening_known = false
	_ok(opening_known, "every road out of the opening point leads somewhere known")

	var hidden := _unrevealed(graph)
	_ok(hidden.size() > 0, "the rest of the map is still under question marks",
		"%d of %d still unknown" % [hidden.size(), graph.sites.size()])

	# --- discovery on arriving somewhere ------------------------------------
	var step := graph.neighbours_of(start)[0]
	var before := _revealed_ids(graph)
	travel.travel_finished.emit(step)
	await process_frame
	view.place_token_at(step)

	var learned := _revealed_ids(graph)
	var only_neighbours := true
	var ring := graph.neighbours_of(step)
	for site_id: int in learned:
		if before.has(site_id) or site_id == step:
			continue
		if not ring.has(site_id):
			only_neighbours = false
	_ok(learned.size() > before.size(), "arriving somewhere turned more of the map over",
		"%d known, was %d" % [learned.size(), before.size()])
	_ok(only_neighbours, "and turned over nothing that is not joined to it")
	for neighbour: int in ring:
		if not graph.get_site(neighbour).revealed:
			_ok(false, "every point joined to the arrival is known")
			break

	# --- what the mouse is resting on ---------------------------------------
	var line: Label = panel.get_node_or_null(^"Line") as Label
	var far := _unrevealed(graph)
	if not far.is_empty():
		view.hover_changed.emit(far[0], null)
		await process_frame
		_ok(line != null and line.text == panel.place_text % panel.unknown_name,
			"a place across the map is named at the foot of the screen",
			"" if line == null else line.text)

	view.hover_changed.emit(step, null)
	await process_frame
	var here := view.display_name_of(step)
	var standing_now := panel.re_enter_text if view.can_re_enter(step) else panel.standing_text
	_ok(line != null and line.text == standing_now % here,
		"the point underfoot says so rather than being priced",
		"" if line == null else line.text)

	view.hover_changed.emit(-1, null)
	await process_frame
	_ok(line != null and line.text == panel.idle_text,
		"the mouse off every point puts the standing instruction back")

	# --- the rings ----------------------------------------------------------
	var on := _marker(view, step)
	_ok(on != null and _ring(on, ^"CurrentRing"), "the point the piece is on wears the standing ring")
	_ok(on != null and not _ring(on, ^"VisitedRing"),
		"and not the been-here ring as well - the stronger one wins")
	var behind := _marker(view, start)
	_ok(behind != null and _ring(behind, ^"VisitedRing"),
		"a point already ridden through wears the been-here ring")
	if not far.is_empty():
		var untouched := _marker(view, far[0])
		_ok(untouched != null and not _ring(untouched, ^"VisitedRing")
				and not _ring(untouched, ^"CurrentRing"),
			"and a place never stood on wears neither")

	# --- walking back into the point underfoot ------------------------------
	var saloon: RunMapSite = null
	for site: RunMapSite in graph.sites:
		if site.kind == &"saloon":
			saloon = site
			break
	_ok(saloon != null, "the map dealt out a saloon to walk back into")
	if saloon == null:
		return

	travel.travel_finished.emit(saloon.id)
	await process_frame
	view.place_token_at(saloon.id)
	_ok(screen.is_open(), "arriving on the saloon opened it")
	screen.close()
	await process_frame
	await process_frame
	_ok(not screen.is_open() and graph.current_id == saloon.id,
		"leaving it left the piece standing on the same point")

	_ok(view.can_re_enter(saloon.id), "a saloon is a place that can be walked back into")
	view._pick(saloon.position)
	await process_frame
	_ok(screen.is_open(), "clicking the point underfoot opened the saloon again")
	_ok(graph.current_id == saloon.id and graph.get_site(saloon.id).visited,
		"walking back in spent no ride and moved nothing")
	screen.close()
	await process_frame
	await process_frame

	# A fight already had is not had again: the very same click, on a point
	# wearing a combat handle, does nothing at all.
	var was_kind := saloon.kind
	saloon.kind = &"bandit_camp"
	view.refresh()
	_ok(not view.can_re_enter(saloon.id), "a bandit camp is not a place to walk back into")
	# Boxed in an array: a GDScript lambda captures a plain local by value, so a
	# counter kept as a bare int would never be seen to move.
	var re_entries := [0]
	var count := func(_site_id: int) -> void: re_entries[0] = int(re_entries[0]) + 1
	view.site_re_entered.connect(count)
	view._pick(saloon.position)
	await process_frame
	_ok(int(re_entries[0]) == 0 and not screen.is_open(),
		"clicking a resolved fight underfoot does nothing")
	view.site_re_entered.disconnect(count)
	saloon.kind = was_kind
	view.refresh()

	# --- what the bartender points out --------------------------------------
	# Flown at a pace a check can wait for; the map's own timings are on the
	# view in the scene and are what the game actually plays.
	view.presentation_travel_time = 0.06
	view.presentation_hold_time = 0.04
	view.presentation_return_time = 0.06

	view._pick(saloon.position)
	await process_frame
	_ok(screen.is_open(), "back in the saloon to ask about the country")
	if not screen.is_open():
		return

	var pointed: Array[RunMapSite] = []
	var watch := func(site: RunMapSite, _topic: RunMapSaloonTopic) -> void: pointed.append(site)
	informant.place_pointed_out.connect(watch)

	_press(screen, ^"Panel/Body/Pages/Stack/Menu/Information")
	await process_frame
	var rows := _rows(screen)
	var quiet_index := _topic_index(screen, &"", true)
	var place_index := _topic_index(screen, &"market", false)
	var bounty_index := _topic_index(screen, &"bounty", false)
	_ok(rows.size() == screen.topics.size() and place_index >= 0 and bounty_index >= 0,
		"the saloon has a subject for the covered country and one for wanted men")
	if place_index < 0 or bounty_index < 0 or rows.size() != screen.topics.size():
		return

	# An ordinary place is simply learned, there and then.
	rows[place_index].pressed.emit()
	await process_frame
	_ok(pointed.size() == 1, "asking about the covered country pointed one place out")
	if pointed.size() == 1:
		_ok(pointed[0].revealed, "an ordinary place is known the moment it is named",
			"%s" % view.true_name_of(pointed[0].id))
		_ok(line_of(screen) == screen.topics[place_index].reveal_line
				% view.true_name_of(pointed[0].id),
			"and the bartender names it")

	# A bounty is held back, because it is worth being shown rather than told.
	rows[bounty_index].pressed.emit()
	await process_frame
	_ok(pointed.size() == 2, "asking about wanted men pointed one out too")
	if pointed.size() != 2:
		return
	var wanted := pointed[1]
	_ok(wanted.kind == &"bounty", "and what it pointed at is a bounty", "%s" % wanted.kind)
	_ok(not wanted.revealed,
		"its question mark is still on until the map has shown the player where")

	informant.place_pointed_out.disconnect(watch)

	# --- the map showing the player where -----------------------------------
	var token := view.get_node_or_null(^"Token") as Node2D
	var stood_at := Vector2.ZERO if token == null else token.position
	var standing_on := graph.current_id
	var home_zoom := view.map_zoom

	screen.close()
	var started := await _wait_for(view, true)
	_ok(started, "leaving the saloon set the camera off across the map")
	_ok(not wanted.revealed or view.is_presenting(),
		"the question mark is not taken off before the camera gets there")

	var ended := await _wait_for(view, false)
	_ok(ended, "and the camera came back")
	_ok(wanted.revealed, "the bounty is on the map now")
	_ok(graph.current_id == standing_on, "the piece never left the saloon")
	_ok(token == null or token.position.is_equal_approx(stood_at),
		"and was not dragged along behind the camera")
	_ok(view.is_picking(), "the map is the player's again")
	var camera := view.get_node_or_null(^"Camera") as Camera2D
	_ok(camera != null and is_equal_approx(camera.zoom.x, home_zoom),
		"zoomed back out to exactly where the player had it",
		"" if camera == null else "%.3f against %.3f" % [camera.zoom.x, home_zoom])

	# --- and it is kept -----------------------------------------------------
	var state: Node = root.get_node_or_null(^"WorldState")
	var record: Dictionary = {} if state == null else state.call(
		&"recall", director.region_id, WorldMapState.KIND_RUN_MAP, &"graph")
	var kept := RunMapGraph.from_dict(record.get(&"graph", {}))
	_ok(kept != null and kept.get_site(wanted.id) != null
			and kept.get_site(wanted.id).revealed,
		"and written into the run's own memory, so it survives the map closing")


# --- Odds and ends --------------------------------------------------------------

## Waits for the map's presentation to start, or to finish, giving up rather
## than hanging if it never does.
func _wait_for(view: RunMapView, presenting: bool) -> bool:
	for _frame: int in range(600):
		await process_frame
		if view.is_presenting() == presenting:
			return true
	return false


## Which subject points at [param kind], or - with [param quiet] - the first
## subject that points nowhere at all. -1 for neither.
func _topic_index(screen: RunMapSaloonScreen, kind: StringName, quiet: bool) -> int:
	for index: int in range(screen.topics.size()):
		var topic := screen.topics[index]
		if topic == null:
			continue
		if quiet and topic.reveals_kinds.is_empty():
			return index
		if not quiet and topic.reveals_kinds.has(kind):
			return index
	return -1


func line_of(screen: RunMapSaloonScreen) -> String:
	var label: Label = screen.get_node_or_null(^"Panel/Body/Line") as Label
	return "" if label == null else label.text


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


## The marker drawing one point, found the way anything outside the view has to
## find one - by the id each marker carries.
func _marker(view: RunMapView, site_id: int) -> RunMapSiteMarker:
	var sites: Node = view.get_node_or_null(^"Sites")
	if sites == null:
		return null
	for child: Node in sites.get_children():
		var marker := child as RunMapSiteMarker
		if marker != null and marker.site_id == site_id:
			return marker
	return null


func _ring(marker: RunMapSiteMarker, ring: NodePath) -> bool:
	var sprite := marker.get_node_or_null(ring) as Sprite2D
	return sprite != null and sprite.visible


func _revealed_ids(graph: RunMapGraph) -> PackedInt32Array:
	var found := PackedInt32Array()
	for site: RunMapSite in graph.sites:
		if site.revealed:
			found.append(site.id)
	return found


func _unrevealed(graph: RunMapGraph) -> PackedInt32Array:
	var found := PackedInt32Array()
	for site: RunMapSite in graph.sites:
		if not site.revealed:
			found.append(site.id)
	return found


## Takes the first contract the board will part with, and reports whether one
## went through. The board is restocked where a thin week left it bare, which is
## the same call coming home already makes.
func _take_a_contract() -> bool:
	var ledger: BountyLedger = root.get_node_or_null(^"Bounties")
	if ledger == null:
		return false
	for _attempt: int in range(6):
		for bounty: Bounty in ledger.get_board_bounties():
			if ledger.accept(bounty):
				return true
		ledger.refresh_board()
	return false


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


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
