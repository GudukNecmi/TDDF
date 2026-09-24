extends SceneTree
## Headless check of the run map's bandit points: that the two sizes the
## generator deals out are each worth a steady, hidden number of men, that
## arriving on one raises the existing decision screen, and that each of the
## answers ends where it should.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_bandit_smoke.gd
## [/codeblock]
##
## It rides the real scene through the real [RunMapTravel] and answers the real
## [WorldBanditDecisionMenu] by pressing its buttons, so what is measured is the
## screen the player actually gets and the record the arena is actually built
## from. Which points are bandit points is the generator's business and is
## checked by [code]run_map_distribution_smoke.gd[/code]; this one rides until
## it finds one, which is also what proves that arriving on a market or a
## saloon quietly does nothing yet.

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
	_ok(menu != null, "the map has the bandit decision screen on it")
	_ok(bridge != null, "the map has the encounter bridge on it")
	if director == null or view == null or travel == null or bandits == null \
			or menu == null or bridge == null:
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

	print("--- how the bandit points read ---")
	_report_tiers(bandits, bridge, director.region_id, graph)

	# A fresh run carries no Blood, and the wallet refuses a payment it cannot
	# cover - so the player is handed enough for the bridge's own pay amount
	# before a peaceful answer is measured.
	var wallet := root.get_node_or_null(^"Blood") as BloodWallet
	if wallet != null and not wallet.can_afford(bridge.decision_pay_amount):
		wallet.add(bridge.decision_pay_amount - wallet.get_total())

	print("--- arriving, and talking the way out ---")
	await _check_answer(director, view, travel, menu, bandits, bridge, graph, true)

	print("--- arriving, and fighting ---")
	await _check_answer(director, view, travel, menu, bandits, bridge, graph, false)

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


## One whole arrival: ride until a bandit point is reached, meet the screen,
## press one of its buttons and check where that left things.
func _check_answer(director: RunMapDirector, view: RunMapView, travel: RunMapTravel,
		menu: WorldBanditDecisionMenu, bandits: RunMapBanditNode,
		bridge: WorldMapCombatBridge, graph: RunMapGraph, peaceful: bool) -> void:
	var target := await _ride_to_bandits(
		view, travel, menu, bandits, bridge, director.region_id, graph, peaceful)
	_ok(target >= 0, "the ride reached a bandit point")
	if target < 0:
		return
	var entry := bandits.encounter_for(graph.get_site(target).kind)
	print("       arrived at a '%s'" % graph.get_site(target).kind)

	_ok(menu.is_open(), "arriving raised the bandit decision screen")
	_ok(paused, "the world is held still for the question")
	if not menu.is_open() or entry == null:
		return

	# How many men are waiting, and the same number the arena would be built with.
	var count_row := menu.get_node_or_null(^"Panel/Body/Enemies") as CanvasItem
	var count_label := menu.get_node_or_null(^"Panel/Body/Enemies/Count") as Label
	_ok(count_row != null and count_row.visible and count_label != null
			and count_label.text == str(bridge._site_enemy_count),
		"the screen says how many men are waiting",
		"" if count_label == null else "%s shown, %d staged"
			% [count_label.text, bridge._site_enemy_count])
	var blood_label := menu.get_node_or_null(^"Panel/Body/Resources/Blood/Value") as Label
	_ok(blood_label != null and blood_label.text == str(_blood()),
		"the screen shows the Blood being carried")
	var art := menu.get_node_or_null(^"Panel/Body/Art") as CanvasItem
	_ok(art != null and art.visible, "the bandits are still pictured")
	var line := menu.get_node_or_null(^"Panel/Body/Line") as Label
	_ok(line != null and not line.text.is_empty(), "the bandits said something")

	var button := _peaceful_button(menu) if peaceful else _button_for(menu, &"fight")
	_ok(button != null, "the screen offers %s" %
		["a way out other than fighting" if peaceful else "a fight"])
	if button == null:
		return
	var wanted: StringName = button.get_meta(&"outcome", &"fight")
	print("       pressed '%s' - \"%s\"" % [wanted, button.text])
	var tag := button.get_node_or_null(^"Blood") as Label
	if wanted == &"pay" or wanted == &"take":
		var sign := "-" if wanted == &"pay" else "+"
		_ok(tag != null and tag.visible and tag.text.begins_with(sign),
			"the answer shows its Blood as %s" % sign,
			"" if tag == null else "\"%s\"" % tag.text)
	else:
		_ok(tag == null or not tag.visible, "the answer shows no Blood")

	var before_blood := _blood()
	var owed := bandits.enemy_count_for(graph, graph.get_site(target))
	button.pressed.emit()
	await process_frame

	_ok(not menu.is_open(), "the screen came down on the answer")
	_ok(not paused, "the world was let go again")
	_ok(graph.get_site(target).kind == entry.cleared_kind,
		"the point is written down as dealt with",
		"it reads as '%s', not '%s'" % [graph.get_site(target).kind, entry.cleared_kind])

	var state: Node = root.get_node_or_null(^"WorldState")
	var staged: Dictionary = {} if state == null else state.call(&"get_staged_combat")
	if wanted == &"fight":
		_ok(not staged.is_empty(), "a fight was staged for the arena")
		_ok(staged.get(&"region_id", &"") == director.region_id,
			"the fight is in this map's own region")
		var count := int(staged.get(&"enemy_count", 0))
		_ok(count == owed, "the arena was asked for exactly what the point is worth",
			"%d against %d" % [count, owed])
		_ok(count >= entry.min_enemies and count <= entry.max_enemies,
			"the arena was asked for %d to %d men"
				% [entry.min_enemies, entry.max_enemies], "%d men" % count)
		_ok(staged.get(&"kind", &"") == &"bandit", "it is staged as a bandit fight")
		_ok(staged.get(&"return_region", &"") == director.region_id,
			"the way back leads to this map")
		# Cleared so nothing downstream opens a fight this check only staged.
		if state != null:
			state.call(&"clear_staged_combat")
		return

	_ok(staged.is_empty(), "the peaceful answer staged no fight")
	_ok(view.is_picking(), "the map came back taking a choice")
	var moved := _blood() - before_blood
	match wanted:
		&"walk_away":
			_ok(moved == 0, "walking away moved no blood", "%d moved" % moved)
		&"pay":
			_ok(moved == -bridge.decision_pay_amount, "paying cost blood",
				"%d moved" % moved)
		&"take":
			_ok(moved == bridge.decision_take_amount, "taking paid blood",
				"%d moved" % moved)


## Rides to the nearest bandit point that will answer the question being asked
## of it, and answers which point that was.
##
## The route is worked out first rather than hop by hop, because most of the
## map is not a bandit point at all and a point whose tier only offers a fight
## is no use to the peaceful half of this check. Every point on the way there
## is an ordinary one - a market, an event - so riding through it is expected
## to raise nothing, which is the other half of what this proves.
func _ride_to_bandits(view: RunMapView, travel: RunMapTravel,
		menu: WorldBanditDecisionMenu, bandits: RunMapBanditNode,
		bridge: WorldMapCombatBridge, region_id: StringName, graph: RunMapGraph,
		peaceful: bool) -> int:
	var route := _route_to_bandits(bandits, bridge, region_id, graph, peaceful)
	if route.is_empty():
		return -1

	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame
		if menu.is_open():
			return step
		if bandits.encounter_for(graph.get_site(step).kind) != null:
			# A bandit point that raised nothing is a failure to report, not a
			# hop to make again.
			return step
	return -1


## The shortest run of roads from where the piece stands to a bandit point that
## has not been dealt with and whose tier offers the answer wanted, passing only
## through points that are not bandit points at all. Empty when the map has no
## such point left within reach.
func _route_to_bandits(bandits: RunMapBanditNode, bridge: WorldMapCombatBridge,
		region_id: StringName, graph: RunMapGraph, peaceful: bool) -> PackedInt32Array:
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
				if peaceful and _tier_of(bandits, bridge, region_id, graph, site) \
						== WorldBanditDecisionEvaluator.Tier.STRONGER:
					continue
				return _walk_back(came_from, next, graph.current_id)
			if _raises_a_screen(site):
				# A saloon on the way would put its own screen up and hold the
				# world still, which is somebody else's check - so the route goes
				# round one rather than through it. This is the other half of
				# "every point on the way raises nothing".
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


## The button on the screen carrying [param outcome], or null when this tier
## does not offer that answer.
func _button_for(menu: WorldBanditDecisionMenu, outcome: StringName) -> Button:
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button == null or not button.visible:
			continue
		if button.get_meta(&"outcome", &"") == outcome:
			return button
	return null


## The first answer on the screen that is not a fight, or null when this tier
## only offers one.
func _peaceful_button(menu: WorldBanditDecisionMenu) -> Button:
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button == null or not button.visible:
			continue
		if button.get_meta(&"outcome", &"fight") != &"fight":
			return button
	return null


## Which of the three screens a point would raise, worked out the same way
## [WorldMapCombatBridge] works it out - so the check can go looking for one
## that offers a way out rather than hoping the first one does.
func _tier_of(bandits: RunMapBanditNode, bridge: WorldMapCombatBridge,
		region_id: StringName, graph: RunMapGraph, site: RunMapSite) -> int:
	var strength := float(bandits.enemy_count_for(graph, site)) \
		/ maxf(bridge.enemy_count_scale, 0.01)
	return WorldBanditDecisionEvaluator.evaluate_group(
		region_id, strength, bridge, bridge.weapon_catalog)


## How the bandit points on this map read, as a line for the log - what says
## whether the three authored screens are all actually reachable.
func _report_tiers(bandits: RunMapBanditNode, bridge: WorldMapCombatBridge,
		region_id: StringName, graph: RunMapGraph) -> void:
	var counted := {}
	for site: RunMapSite in graph.sites:
		if bandits.encounter_for(site.kind) == null:
			continue
		var tier := _tier_of(bandits, bridge, region_id, graph, site)
		counted[tier] = int(counted.get(tier, 0)) + 1
	print("       points reading STRONGER %d, EQUAL %d, WEAKER %d" % [
		counted.get(WorldBanditDecisionEvaluator.Tier.STRONGER, 0),
		counted.get(WorldBanditDecisionEvaluator.Tier.EQUAL, 0),
		counted.get(WorldBanditDecisionEvaluator.Tier.WEAKER, 0)])


func _blood() -> int:
	var wallet := root.get_node_or_null(^"Blood") as BloodWallet
	return 0 if wallet == null else wallet.get_total()


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
