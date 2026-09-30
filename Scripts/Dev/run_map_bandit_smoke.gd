extends SceneTree
## Headless check of the run map's bandit points: that the two sizes the
## generator deals out are each worth a steady, hidden number of men, and that
## arriving on one asks nothing - the map goes dark and the fight is staged for
## the arena, with the point written down as dealt with.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_bandit_smoke.gd
## [/codeblock]
##
## It rides the real scene through the real [RunMapTravel], so what is measured
## is what the player actually gets on arrival and the record the arena is
## actually built from. Which points are bandit points is the generator's
## business and is checked by [code]run_map_distribution_smoke.gd[/code]; this
## one rides until it finds one, which is also what proves that arriving on a
## market quietly does nothing. The camp and the rest of the round trip are
## [code]run_map_bandit_journey_smoke.gd[/code]'s.

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(6):
		await process_frame

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	var menu := _find("WorldBanditDecisionMenu") as WorldBanditDecisionMenu
	var bridge := _find("WorldMapCombatBridge") as WorldMapCombatBridge
	_ok(director != null and view != null and travel != null, "the run map opened")
	_ok(bandits != null, "the map has a bandit point director")
	_ok(bridge != null, "the map has the encounter bridge on it")
	if director == null or view == null or travel == null or bandits == null \
			or bridge == null:
		_finish()
		return

	var graph := director.get_graph()
	if graph == null or graph.is_empty():
		_ok(false, "the map has a graph")
		_finish()
		return

	print("--- which points are bandit points ---")
	_check_kinds(bandits, graph)

	print("--- how many men are waiting ---")
	_check_counts(bandits, graph)

	print("--- the map survives the arena being built ---")
	_check_stored(director, graph)

	print("--- no bandit point asks ---")
	for entry: RunMapBanditEncounter in bandits.encounters:
		_ok(not entry.asks_before_fighting,
			"a '%s' is a fight outright" % entry.kind)

	print("--- arriving on a bandit group ---")
	await _check_arrival(director, view, travel, menu, bandits, bridge, graph)

	_finish()


## Both sizes of bandit point are on the map, nothing was left unclaimed, and
## the two points that were never a draw are as the generator made them.
func _check_kinds(bandits: RunMapBanditNode, graph: RunMapGraph) -> void:
	var unknown := 0
	var counted := {}
	for site: RunMapSite in graph.sites:
		if site.kind == RunMapSite.KIND_UNKNOWN:
			unknown += 1
		if bandits.encounter_for(site.kind) != null:
			counted[site.kind] = int(counted.get(site.kind, 0)) + 1

	_ok(unknown == 0, "no point was left unclaimed", "%d unknown" % unknown)
	_ok(graph.get_site(graph.start_id).kind == RunMapSite.KIND_START,
		"the start was left as the start")
	_ok(graph.get_site(graph.boss_id).kind == RunMapSite.KIND_BOSS,
		"the boss is the boss")
	for entry: RunMapBanditEncounter in bandits.encounters:
		_ok(int(counted.get(entry.kind, 0)) > 0,
			"the map has at least one '%s'" % entry.kind,
			"%d of them" % int(counted.get(entry.kind, 0)))
	print("       %s" % counted)

	# Every handle the generator wrote has art on this map to draw it with, and
	# so does every handle a dealt-with point is rewritten to.
	var view := _find("RunMapView") as RunMapView
	var wanted := {}
	for site: RunMapSite in graph.sites:
		wanted[site.kind] = true
	for entry: RunMapBanditEncounter in bandits.encounters:
		wanted[entry.cleared_kind] = true
	var unauthored := PackedStringArray()
	for kind: StringName in wanted:
		var art: RunMapSiteKind = null
		for candidate: RunMapSiteKind in view.site_kinds:
			if candidate.kind == kind:
				art = candidate
				break
		if art == null or art.icon == null:
			unauthored.append(String(kind))
	_ok(unauthored.is_empty(), "every kind on the map has its own art",
		"no picture for %s" % String(", ").join(unauthored))

	# The fog is untouched by the distribution: a point the piece has not ridden
	# to is still an unknown point as far as the map is concerned.
	var hidden := 0
	for site: RunMapSite in graph.sites:
		if bandits.encounter_for(site.kind) != null and not site.revealed:
			hidden += 1
	_ok(hidden > 0, "the bandit points ahead are still unknown points",
		"%d hidden" % hidden)


## Each bandit point is worth what its own entry says, and asking twice - or
## asking a graph read back out of its own dictionary - gives the same answer.
func _check_counts(bandits: RunMapBanditNode, graph: RunMapGraph) -> void:
	var rebuilt := RunMapGraph.from_dict(graph.to_dict())
	for entry: RunMapBanditEncounter in bandits.encounters:
		var lowest := 99999
		var highest := -1
		var unsteady := 0
		var seen := 0
		for site: RunMapSite in graph.sites:
			if site.kind != entry.kind:
				continue
			seen += 1
			var count := bandits.enemy_count_for(graph, site)
			lowest = mini(lowest, count)
			highest = maxi(highest, count)
			if count != bandits.enemy_count_for(graph, site):
				unsteady += 1
			elif count != bandits.enemy_count_for(rebuilt, rebuilt.get_site(site.id)):
				unsteady += 1
		if seen <= 0:
			continue
		_ok(lowest >= entry.min_enemies and highest <= entry.max_enemies,
			"every '%s' is worth %d to %d men"
				% [entry.kind, entry.min_enemies, entry.max_enemies],
			"%d..%d over %d of them" % [lowest, highest, seen])
		_ok(unsteady == 0,
			"a '%s' is the same size every time it is asked" % entry.kind,
			"%d disagreed" % unsteady)
		print("       %s: %d of them, %d..%d men" % [entry.kind, seen, lowest, highest])

	# A camp can be worth more men than the bridge would otherwise stage - see
	# [member WorldMapCombatBridge.max_enemy_count], which this map raises.
	var bridge := _find("WorldMapCombatBridge") as WorldMapCombatBridge
	var largest := 0
	for entry: RunMapBanditEncounter in bandits.encounters:
		largest = maxi(largest, entry.max_enemies)
	_ok(bridge != null and bridge.max_enemy_count >= largest,
		"the bridge will stage as big a fight as the biggest point is worth",
		"it caps at %d against %d" % [
			bridge.max_enemy_count if bridge != null else 0, largest])

	# The point of two sizes is that they are different sizes.
	if bandits.encounters.size() >= 2:
		var small := bandits.encounters[0]
		var large := bandits.encounters[1]
		_ok(large.max_enemies > small.max_enemies,
			"a camp is a bigger fight than a group",
			"%d-%d against %d-%d" % [small.min_enemies, small.max_enemies,
				large.min_enemies, large.max_enemies])


## The map is written into the run's own memory, not just held in this scene -
## otherwise the first fight would lose what is where.
func _check_stored(director: RunMapDirector, graph: RunMapGraph) -> void:
	var state: Node = root.get_node_or_null(^"WorldState")
	if state == null:
		_ok(false, "the world state autoload is there")
		return
	var record: Dictionary = state.call(
		&"recall", director.region_id, WorldMapState.KIND_RUN_MAP, &"graph")
	var stored := RunMapGraph.from_dict(record.get(&"graph", {}))
	_ok(stored != null, "the map was written down")
	if stored == null:
		return
	var same := stored.sites.size() == graph.sites.size()
	if same:
		for index: int in range(graph.sites.size()):
			if stored.sites[index].kind != graph.sites[index].kind:
				same = false
				break
	_ok(same, "the written-down map carries the same kinds as the one being played")


## One whole arrival: ride to a bandit point - a group by preference - and check
## that no question was asked, the roads closed while the map went dark, and the
## fight staged for the arena is the one the point is worth.
func _check_arrival(director: RunMapDirector, view: RunMapView, travel: RunMapTravel,
		menu: WorldBanditDecisionMenu, bandits: RunMapBanditNode,
		bridge: WorldMapCombatBridge, graph: RunMapGraph) -> void:
	var route := _route_to_bandits(bandits, graph, &"bandit_group")
	if route.is_empty():
		route = _route_to_bandits(bandits, graph, &"")
	var target := -1
	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame
		target = step
	var entry := bandits.encounter_for(graph.get_site(target).kind) if target >= 0 else null
	_ok(entry != null, "the ride reached a bandit point")
	if entry == null:
		return
	print("       arrived at a '%s'" % graph.get_site(target).kind)
	var owed := bandits.enemy_count_for(graph, graph.get_site(target))

	await process_frame
	_ok(menu == null or not menu.is_open(), "arriving asked no question")
	_ok(not paused, "the world was not held still for a question")
	_ok(bridge.is_deciding() or bridge.is_running(), "the fight is already on its way")
	_ok(not view.is_picking(), "no road can be taken while the map goes dark")

	# The fade is timed in seconds, so it is waited out on the clock.
	var state: Node = root.get_node_or_null(^"WorldState")
	var staged: Dictionary = {}
	var waited := 0.0
	while waited < 10.0:
		staged = {} if state == null else state.call(&"get_staged_combat")
		if not staged.is_empty():
			break
		await create_timer(0.05).timeout
		waited += 0.05

	_ok(not staged.is_empty(), "a fight was staged for the arena")
	_ok(graph.get_site(target).kind == entry.cleared_kind,
		"the point is written down as dealt with",
		"it reads as '%s', not '%s'" % [graph.get_site(target).kind, entry.cleared_kind])
	_ok(staged.get(&"region_id", &"") == director.region_id,
		"the fight is in this map's own region")
	var count := int(staged.get(&"enemy_count", 0))
	_ok(count == owed, "the arena was asked for exactly what the point is worth",
		"%d against %d" % [count, owed])
	_ok(count >= entry.min_enemies and count <= entry.max_enemies,
		"the arena was asked for %d to %d men"
			% [entry.min_enemies, entry.max_enemies], "%d men" % count)
	_ok(staged.get(&"kind", &"") == &"bandit", "it is staged as a bandit fight")
	_ok(staged.get(&"site_kind", &"") == entry.kind, "it carries the point's kind")
	_ok(staged.get(&"return_region", &"") == director.region_id,
		"the way back leads to this map")


## The shortest run of roads to a bandit point of [param wanted] kind - any kind
## when empty - passing only through points that raise nothing of their own.
## Empty when the map has no such point left within reach.
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
			if _raises_a_screen(site):
				# A saloon on the way would put its own screen up and hold the
				# world still, which is somebody else's check - so the route goes
				# round one rather than through it.
				continue
			queue.append(next)
	return PackedInt32Array()


## Whether standing on [param site] would raise a screen of its own. Asked of
## the map's own listeners rather than listed here, so a kind of point that
## starts or stops raising one is not a name to keep up to date in this file.
func _raises_a_screen(site: RunMapSite) -> bool:
	var saloons := _find("RunMapSaloonNode") as RunMapSaloonNode
	if saloons != null and saloons.answers(site.kind):
		return true
	var bosses := _find("RunMapBountyBossNode") as RunMapBountyBossNode
	return bosses != null and bosses.encounter_for(site.kind) != null


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


func _finish() -> void:
	print("")
	if _failures == 0:
		print("[PASS] run map bandit point: every check passed")
	else:
		print("[FAIL] run map bandit point: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


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
