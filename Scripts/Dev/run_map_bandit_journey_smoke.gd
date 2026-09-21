extends SceneTree
## Headless check of the whole bandit point round trip: the run map, the
## decision screen, the arena the fight is actually held in, and the same run
## map standing again afterwards.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_bandit_journey_smoke.gd
## [/codeblock]
##
## [RunMapBanditNode]'s own check - [code]run_map_bandit_smoke.gd[/code] - stops
## at the staged record, because that is where the map's half of an encounter
## ends. This one carries it through: it presses FIGHT, waits out the curtain,
## confirms the arena opened with the crowd the camp was worth, clears the fight
## the way the last enemy dying clears it, and confirms the map that comes back
## is the same map with the camp written down as dealt with.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	var session: Node = root.get_node_or_null(^"RunSession")
	if router == null:
		print("[FAIL] no WorldRouter autoload")
		quit(1)
		return
	# A frame first: the autoloads are only reachable by absolute path once the
	# tree is actually running, and the router asks for the curtain by one.
	await process_frame
	await process_frame
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	print("--- the run map ---")
	_ok(router.go_to_region(&"A"), "the router accepted the ride out")
	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "the run map opened", _scene_name())

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	var menu := _find("WorldBanditDecisionMenu") as WorldBanditDecisionMenu
	if director == null or view == null or travel == null or bandits == null \
			or menu == null:
		_ok(false, "the run map opened with everything a bandit point needs")
		_finish()
		return

	var graph := director.get_graph()
	var made_seed := graph.seed
	var made_points := graph.sites.size()

	print("--- riding to a bandit point ---")
	# Which points are bandit points is the generator's node distribution, so
	# there may be a market or two to ride through first. Arriving on one of
	# those is expected to do nothing at all.
	var route := _route_to_bandits(bandits, graph, _biggest_kind(bandits))
	if route.is_empty():
		route = _route_to_bandits(bandits, graph, &"")
	var target := -1
	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame
		if menu.is_open():
			target = step
			break
	_ok(target >= 0, "the ride reached a bandit point with its screen up")
	if target < 0:
		_finish()
		return

	var entry := bandits.encounter_for(graph.get_site(target).kind)
	var wanted_count := bandits.enemy_count_for(graph, graph.get_site(target))
	print("       a '%s' worth %d men" % [graph.get_site(target).kind, wanted_count])
	_ok(menu.is_open(), "arriving raised the decision screen")

	var fight := _fight_button(menu)
	_ok(fight != null, "the screen offers a fight")
	if fight == null:
		_finish()
		return
	fight.pressed.emit()

	print("--- the arena ---")
	await _settle()
	_ok(_scene_name() == "DustCampArena", "the fight is held in dust camp's arena",
		_scene_name())
	_ok(not paused, "the world is running again once the fight is up")

	var ambush := _find("AmbushWaveDirector") as AmbushWaveDirector
	_ok(ambush != null, "the arena has its ambush director")
	# The fight the arena was opened with, not how many men happen to be standing
	# this instant - the ambush releases its crowd in groups, so the tree holds
	# only the opening handful a frame after it begins.
	var placed := 0 if ambush == null else ambush.get_enemy_total()
	_ok(placed == wanted_count, "the arena opened with the crowd the point was worth",
		"%d men against the point's %d" % [placed, wanted_count])
	_ok(entry != null and placed >= entry.min_enemies and placed <= entry.max_enemies,
		"that crowd is what this size of bandit point is worth",
		"%d men against %d-%d" % [placed,
			entry.min_enemies if entry != null else 0,
			entry.max_enemies if entry != null else 0])
	_ok(ambush != null and ambush.get_enemies_alive() > 0,
		"the first of them are already on the floor",
		"%d standing" % (0 if ambush == null else ambush.get_enemies_alive()))

	print("--- back to the run map ---")
	if ambush == null:
		_finish()
		return
	# What the last man dying does. The fight itself is not played out here -
	# that is Arena combat's own check, not this one's.
	ambush.cleared.emit()
	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "the run map came back", _scene_name())
	_ok(_count("DustCampArena") == 0, "the arena is unloaded, not kept around")

	var back := _find("RunMapDirector") as RunMapDirector
	var back_graph := back.get_graph() if back != null else null
	_ok(back_graph != null and back_graph.seed == made_seed
			and back_graph.sites.size() == made_points,
		"it is the same map, not a freshly generated one",
		"seed %d/%d, %d/%d points" % [
			back_graph.seed if back_graph != null else 0, made_seed,
			back_graph.sites.size() if back_graph != null else 0, made_points])
	if back_graph == null:
		_finish()
		return
	_ok(back_graph.current_id == target, "the piece is standing at the camp it rode to")
	_ok(entry != null and back_graph.get_site(target).kind == entry.cleared_kind,
		"the point is written down as dealt with",
		"it reads as '%s'" % back_graph.get_site(target).kind)

	var back_view := _find("RunMapView") as RunMapView
	_ok(back_view != null and back_view.is_picking(),
		"the map is taking the next choice")
	_ok(back_view != null and not back_view.display_name_of(target).is_empty(),
		"the dealt-with point is named on the map",
		"it is named '%s'" % (back_view.display_name_of(target) if back_view != null
			else "<no view>"))

	# Riding back onto a camp that has been dealt with is not a second fight.
	var second := _find("RunMapBanditNode") as RunMapBanditNode
	var second_menu := _find("WorldBanditDecisionMenu") as WorldBanditDecisionMenu
	_ok(second != null and second_menu != null and not second_menu.is_open(),
		"no screen is waiting on the map that came back")

	_finish()


func _fight_button(menu: WorldBanditDecisionMenu) -> Button:
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button == null or not button.visible:
			continue
		if button.get_meta(&"outcome", &"fight") == &"fight":
			return button
	return null


## Waits out the curtain: its minimum display time, the threaded load and the
## reveal, however long each happens to take.
func _settle() -> void:
	var guard := 0
	var curtain := LoadingCurtain.get_active(root)
	while curtain != null and curtain.is_loading() and guard < 4000:
		guard += 1
		await process_frame
	for _step: int in 12:
		await process_frame


func _finish() -> void:
	print("")
	if _failures == 0:
		print("[PASS] run map bandit journey: every check passed")
	else:
		print("[FAIL] run map bandit journey: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)


func _count(node_name: String) -> int:
	return root.find_children(node_name, "", true, false).size()


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


## The shortest run of roads to a bandit point, preferring the biggest size the
## map has within reach - a camp over a group - so the round trip is measured
## against the heaviest fight a point can be worth rather than the lightest.
## Every point on the way there is an ordinary one, so riding through it raises
## nothing.
func _route_to_bandits(bandits: RunMapBanditNode, graph: RunMapGraph,
		wanted: StringName) -> PackedInt32Array:
	var came_from := {graph.current_id: -1}
	var queue: Array[int] = [graph.current_id]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next: int in graph.neighbours_of(at):
			if came_from.has(next):
				continue
			came_from[next] = at
			var site := graph.get_site(next)
			if bandits.encounter_for(site.kind) != null:
				# A bandit point is the end of a route, never a step along one.
				if wanted.is_empty() or site.kind == wanted:
					return _walk_back(came_from, next, graph.current_id)
				continue
			queue.append(next)
	return PackedInt32Array()


## The kind of bandit point worth the most men, which is what the round trip
## would rather be measured on.
func _biggest_kind(bandits: RunMapBanditNode) -> StringName:
	var best: RunMapBanditEncounter = null
	for entry: RunMapBanditEncounter in bandits.encounters:
		if best == null or entry.max_enemies > best.max_enemies:
			best = entry
	return &"" if best == null else best.kind


func _walk_back(came_from: Dictionary, to_id: int, from_id: int) -> PackedInt32Array:
	var backwards: Array[int] = []
	var at := to_id
	while at != from_id and at >= 0:
		backwards.append(at)
		at = int(came_from.get(at, -1))
	backwards.reverse()
	var route := PackedInt32Array()
	for site_id: int in backwards:
		route.append(site_id)
	return route
