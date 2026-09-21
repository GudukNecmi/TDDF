extends SceneTree
## Headless check of the whole mini boss point round trip: the run map, the
## arena, the support group, the man arriving over their bodies, and the same
## run map standing again afterwards.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_mini_boss_smoke.gd
## [/codeblock]
##
## [b]The order is the whole of what this is for.[/b] A mini boss point is two
## fights in one, and everything that could go wrong about it is a step happening
## at the wrong moment: the player sent home when the support group falls, the
## boss standing there from the first frame, the ending never arriving because
## nobody handed it back. So this walks the encounter a beat at a time and checks
## what is true at each one - the crowd is up and the boss is not, the crowd is
## down and the boss is walking in, he is down and the run map is back with the
## point written off.

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
	var node := _find("RunMapMiniBossNode") as RunMapMiniBossNode
	if director == null or view == null or travel == null or node == null:
		_ok(false, "the run map opened with everything a mini boss point needs")
		_finish()
		return
	_ok(not node.encounters.is_empty(), "the map has a mini boss point authored")

	var graph := director.get_graph()
	var made_seed := graph.seed
	var made_points := graph.sites.size()
	var mini_bosses := _count_kind(graph, node)
	_ok(mini_bosses > 0, "the generator dealt at least one mini boss point",
		"%d on this map" % mini_bosses)

	print("--- riding to a mini boss point ---")
	# The bandit points on the way are muted for the ride. A mini boss point sits
	# well up the map - see its [RunMapSitePlan] row band - and on most maps every
	# way to one crosses a bandit point, whose own screen would be a second
	# encounter in the middle of the one being measured. Silencing them is done by
	# emptying the array that says which points it answers, which is the same
	# switch an author has: no code path is bypassed, there is simply nothing for
	# that node to answer. Bandit points have their own round trip check.
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	if bandits != null:
		bandits.encounters.clear()

	var route := _route_to_boss(node, graph)
	_ok(not route.is_empty(), "there is a way to one")
	if route.is_empty():
		_finish()
		return

	var target := route[route.size() - 1]
	var entry := node.encounter_for(graph.get_site(target).kind)
	var wanted_support := node.support_count_for(graph, graph.get_site(target))
	var who := node.boss_for(graph, graph.get_site(target))
	print("       a '%s' with %d men in front of %s"
		% [graph.get_site(target).kind, wanted_support,
			who.display_name if who != null else "<nobody>"])
	_ok(who != null and not who.look_key.is_empty(),
		"the point knows which man is on it",
		"look key '%s'" % (who.look_key if who != null else ""))
	_ok(who != null and who.contract_id.is_empty(),
		"and he has no contract behind him, so nothing will be paid out yet")
	_ok(entry != null and wanted_support >= entry.min_support
			and wanted_support <= entry.max_support,
		"the men in front of him are what this point is worth",
		"%d against %d-%d" % [wanted_support,
			entry.min_support if entry != null else 0,
			entry.max_support if entry != null else 0])

	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame

	print("--- the arena, first half ---")
	await _settle()
	_ok(_scene_name() == "DustCampArena", "the fight is held in dust camp's arena",
		_scene_name())
	_ok(not paused, "the world is running once the fight is up")

	var bridge := _find("WorldMapCombatBridge") as WorldMapCombatBridge
	var fight := _find("RunMiniBossFight") as RunMiniBossFight
	var ambush := _find("AmbushWaveDirector") as AmbushWaveDirector
	var boss_director := _find("MiniBossDirector") as MiniBossDirector
	if bridge == null or fight == null or ambush == null or boss_director == null:
		_ok(false, "the arena has the bridge, the sequencer, the crowd and the boss system")
		_finish()
		return

	var placed := ambush.get_enemy_total()
	_ok(placed == wanted_support,
		"the arena opened with the support group the point was worth",
		"%d men against the point's %d" % [placed, wanted_support])
	_ok(bridge.is_ending_held(),
		"the ending is held, so clearing them cannot send the player home")
	_ok(not fight.has_arrived(), "the boss is not in the arena yet")
	_ok(boss_director.get_boss() == null, "and nothing has been built for him")
	var opening := fight.get_boss_brief()
	_ok(opening != null and opening.display_name == who.display_name,
		"the man the arena is expecting is the man the point named",
		"'%s' against '%s'" % [
			opening.display_name if opening != null else "<nobody>",
			who.display_name])

	print("--- the support group falls ---")
	ambush.cleared.emit()
	_ok(_scene_name() == "DustCampArena",
		"clearing them did not send the player home", _scene_name())
	_ok(bridge.is_running(), "the encounter is still running")
	# The arrival is on a beat of its own, so the arena is deliberately empty for
	# a moment before he walks in.
	await _wait_for(func() -> bool: return fight.has_arrived(),
		fight.arrival_delay + 2.0)

	print("--- he arrives ---")
	_ok(fight.has_arrived(), "the boss walked in once they were down")
	var body := boss_director.get_boss()
	_ok(body != null and is_instance_valid(body), "there is a man standing in the arena")
	if body == null:
		_finish()
		return
	var component := body.get_node_or_null(^"MiniBoss") as MiniBoss
	_ok(component != null, "he is a mini boss, built by the boss system")
	_ok(component != null and component.target_name == who.display_name,
		"and he is the man the point named",
		"'%s'" % (component.target_name if component != null else ""))
	_ok(component != null and component.bounty_id.is_empty(),
		"with no contract on him")

	# Weighed against the pool the ordinary enemy scene was authored with, which
	# is the same thing the multiplier is a multiple of - so this is the point's
	# own authored number read back off the body it was applied to.
	var health := _find_health(body)
	var wanted_pool := entry.boss_health_multiplier if entry != null else 1.0
	var got_pool := 0.0
	if health != null and health.get_authored_max_health() > 0.0:
		got_pool = health.max_health / health.get_authored_max_health()
	_ok(is_equal_approx(got_pool, wanted_pool),
		"he is carrying the health the point authored, not an ordinary man's",
		"%.2fx against the authored %.2fx" % [got_pool, wanted_pool])

	var camera := CameraController.get_active(body)
	_ok(camera != null and camera.get_shake_strength() > 0.0,
		"the ground shook as he landed",
		"shake %.1f" % (camera.get_shake_strength() if camera != null else 0.0))
	_ok(_burst_near(body) != null, "and the sand went up where he landed")

	_ok(boss_director.get_phase() != MiniBossDirector.Phase.NONE,
		"the boss system has the encounter")
	_ok(bridge.is_ending_held(), "the ending is still held while he is up")

	# The man a poster names is built through the same brief and the same builder
	# as the man a run map point names - see [MiniBossBrief]. Checked here because
	# there is no other automated check on the contract half of that builder, and
	# a field dropped out of the brief would show up as a boss with somebody
	# else's face or an ordinary man's health.
	print("--- and the same builder still answers a contract ---")
	var target_sheet := BountyTarget.new()
	target_sheet.target_id = &"test_outlaw"
	target_sheet.display_name = "A NAMED MAN"
	var contract := Bounty.new()
	contract.bounty_id = &"test_contract"
	contract.target = target_sheet
	contract.reward = 900
	var from_paper := MiniBossBrief.from_bounty(contract, boss_director)
	_ok(from_paper != null, "a contract still produces a brief")
	if from_paper != null:
		_ok(from_paper.contract_id == contract.bounty_id,
			"carrying the contract to close out", String(from_paper.contract_id))
		_ok(from_paper.display_name == target_sheet.display_name,
			"the name off the poster", from_paper.display_name)
		_ok(from_paper.look_key == target_sheet.target_id,
			"the outlaw's own face", String(from_paper.look_key))
		_ok(is_equal_approx(from_paper.health_multiplier,
				boss_director.get_boss_health_multiplier(contract)),
			"and the health the contract pays for",
			"%.2fx" % from_paper.health_multiplier)

	print("--- back to the run map ---")
	var defeat := _find("BossDefeat") as BossDefeat
	_ok(defeat != null, "the arena has the ending the project already plays")
	if defeat == null:
		_finish()
		return
	# What the whole of [BossDefeat] arriving at its last step does. The fight
	# itself is not played out here - that is Arena combat's own check.
	defeat.arena_released.emit()
	await _settle()

	_ok(_scene_name() == "DustCampRunMap", "the run map came back", _scene_name())
	_ok(_count("DustCampArena") == 0, "the arena is unloaded, not kept around")

	var back := _find("RunMapDirector") as RunMapDirector
	var back_graph := back.get_graph() if back != null else null
	_ok(back_graph != null and back_graph.seed == made_seed
			and back_graph.sites.size() == made_points,
		"it is the same map, not a freshly generated one")
	if back_graph == null:
		_finish()
		return
	_ok(back_graph.current_id == target, "the piece is standing where it rode to")
	_ok(entry != null and back_graph.get_site(target).kind == entry.cleared_kind,
		"the point is written down as dealt with",
		"it reads as '%s'" % back_graph.get_site(target).kind)

	var back_view := _find("RunMapView") as RunMapView
	_ok(back_view != null and back_view.is_picking(),
		"the map is taking the next choice")
	_ok(back_view != null and not back_view.display_name_of(target).is_empty(),
		"the dealt-with point is still named on the map",
		"it is named '%s'" % (back_view.display_name_of(target) if back_view != null
			else "<no view>"))

	_finish()


## How many points on [param graph] this node answers.
func _count_kind(graph: RunMapGraph, node: RunMapMiniBossNode) -> int:
	var found := 0
	for site: RunMapSite in graph.sites:
		if node.encounter_for(site.kind) != null:
			found += 1
	return found


## The shortest run of roads to a mini boss point, through points that raise
## nothing on the way - so the only encounter this measures is the one it is
## about. A bandit point on the route would put its own screen up.
func _route_to_boss(node: RunMapMiniBossNode, graph: RunMapGraph) -> PackedInt32Array:
	var came_from := {graph.current_id: -1}
	var queue: Array[int] = [graph.current_id]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next: int in graph.neighbours_of(at):
			if came_from.has(next):
				continue
			came_from[next] = at
			var site := graph.get_site(next)
			if node.encounter_for(site.kind) != null:
				# A mini boss point is the end of a route, never a step along it.
				return _walk_back(came_from, next, graph.current_id)
			queue.append(next)
	return PackedInt32Array()


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


func _find_health(body: Node) -> Health:
	for child: Node in body.find_children("*", "Health", true, false):
		return child as Health
	return null


func _wait_for(test: Callable, seconds: float) -> void:
	var waited := 0.0
	while waited < seconds and not bool(test.call()):
		waited += 1.0 / 60.0
		await process_frame


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
		print("[PASS] run map mini boss: every check passed")
	else:
		print("[FAIL] run map mini boss: %d check(s) failed" % _failures)
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


## The burst thrown up as he landed, standing in the world beside him - see
## [method RunMiniBossFight._land]. Null when nothing was thrown.
func _burst_near(body: Node2D) -> OneShotParticles:
	if body == null or body.get_parent() == null:
		return null
	for node: Node in body.get_parent().get_children():
		var burst := node as OneShotParticles
		if burst != null and burst.global_position.distance_to(body.global_position) < 400.0:
			return burst
	return null
