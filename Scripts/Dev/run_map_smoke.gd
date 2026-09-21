extends SceneTree
## Headless check of the run map: that the graph it generates obeys the brief's
## distance rule, and that riding one of its roads spends exactly one day cycle
## per visible tick.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_smoke.gd
## [/codeblock]
##
## The generator half is checked against a fixed seed so a failure can be
## reproduced; the travel half is checked in the real scene, through the real
## [RunMapTravel], so what is measured is the clock the game actually moves.

const GENERATOR_PATH := "res://Resources/RunMap/dust_camp_run_map.tres"
const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const SEEDS: Array[int] = [1, 7, 42, 1337, 90210, 555001]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var generator: RunMapGenerator = load(GENERATOR_PATH)
	if generator == null:
		print("[FAIL] no generator at %s" % GENERATOR_PATH)
		quit(1)
		return

	print("--- the generated graph ---")
	for map_seed: int in SEEDS:
		_check_graph(generator, map_seed)

	print("--- the shape of the map ---")
	_check_shape(generator.generate(42))

	print("--- the clock stands still until a road is ridden ---")
	await _check_clock_is_still()

	print("--- riding a road ---")
	await _check_travel()

	print("")
	if _failures == 0:
		print("[PASS] run map: every check passed")
	else:
		print("[FAIL] run map: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


## Every road is a legal length, every band is tight, and the bands are ordered -
## a three-day road really is longer than a two-day one, and two three-day roads
## are close to each other.
func _check_graph(generator: RunMapGenerator, map_seed: int) -> void:
	var graph := generator.generate(map_seed)
	_ok(graph != null and not graph.is_empty(), "seed %d: a map was made" % map_seed)
	if graph == null or graph.is_empty():
		return

	_ok(graph.reachable_from(graph.start_id).has(graph.boss_id),
		"seed %d: the boss can be reached from the start" % map_seed)
	_ok(graph.sites.size() >= generator.row_count * 2,
		"seed %d: rejecting over-long roads did not gut the map" % map_seed,
		"%d points left over %d rows" % [graph.sites.size(), generator.row_count])

	var boss := graph.get_site(graph.boss_id)
	var start := graph.get_site(graph.start_id)
	_ok(boss.position.y < start.position.y,
		"seed %d: the boss is at the northern end" % map_seed,
		"boss y %.0f, start y %.0f" % [boss.position.y, start.position.y])

	var by_cycles := {}
	var bad := 0
	for link: RunMapLink in graph.links:
		var measured: float = graph.get_site(link.from_id).position.distance_to(
			graph.get_site(link.to_id).position)
		if absf(measured - link.distance) > 1.0:
			bad += 1
		if generator.day_cycles_for(measured) != link.day_cycles:
			bad += 1
		var bucket: Array = by_cycles.get(link.day_cycles, [])
		bucket.append(measured)
		by_cycles[link.day_cycles] = bucket
	_ok(bad == 0, "seed %d: every road's cost matches its measured length" % map_seed,
		"%d road(s) disagreed" % bad)

	var previous_longest := 0.0
	for cycles: int in [1, 2, 3]:
		var lengths: Array = by_cycles.get(cycles, [])
		if lengths.is_empty():
			continue
		var shortest: float = lengths.min()
		var longest: float = lengths.max()
		var band := generator.band_distances[cycles - 1]
		_ok(shortest >= band * (1.0 - generator.band_tolerance)
				and longest <= band * (1.0 + generator.band_tolerance),
			"seed %d: every %d-day road is within tolerance of its band" % [map_seed, cycles],
			"%.0f..%.0f against band %.0f" % [shortest, longest, band])
		_ok(shortest > previous_longest,
			"seed %d: no %d-day road is shorter than a %d-day one" % [map_seed, cycles, cycles - 1],
			"shortest %.0f against the previous band's longest %.0f"
				% [shortest, previous_longest])
		previous_longest = longest


## The map is wide, branchy, reconnecting and not laid out on a grid.
func _check_shape(graph: RunMapGraph) -> void:
	var widest := 0
	var junctions := 0
	var rows := {}
	for site: RunMapSite in graph.sites:
		var degree := graph.links_of(site.id).size()
		widest = maxi(widest, degree)
		if degree >= 3:
			junctions += 1
		var row: Array = rows.get(site.row, [])
		row.append(site)
		rows[site.row] = row

	_ok(widest >= 3, "a junction offers three or more roads", "widest is %d" % widest)
	_ok(junctions >= 3, "the map has several junctions, not one spine",
		"%d junction(s)" % junctions)

	var widest_row := 0
	var misaligned := 0
	for row: Array in rows.values():
		widest_row = maxi(widest_row, row.size())
		if row.size() < 2:
			continue
		var lowest: float = INF
		var highest: float = -INF
		for site: RunMapSite in row:
			lowest = minf(lowest, site.position.y)
			highest = maxf(highest, site.position.y)
		if highest - lowest > 1.0:
			misaligned += 1
	_ok(widest_row >= 4, "the map is wide", "widest row holds %d points" % widest_row)
	_ok(misaligned >= rows.size() / 2, "the rows are not perfectly aligned",
		"%d of %d rows are staggered" % [misaligned, rows.size()])

	var sideways := 0
	for link: RunMapLink in graph.links:
		var a := graph.get_site(link.from_id)
		var b := graph.get_site(link.to_id)
		if a.row == b.row:
			sideways += 1
	_ok(sideways >= 1, "the map has at least one sideways road",
		"%d sideways road(s)" % sideways)


## Nothing moves the clock on its own any more: no sun crosses the sky while the
## player is deciding.
func _check_clock_is_still() -> void:
	var clock: Node = root.get_node_or_null(^"WorldClock")
	if clock == null:
		_ok(false, "the world clock autoload is there")
		return
	var before: float = clock.call(&"get_world_degree")
	for _frame: int in range(60):
		await process_frame
	var after: float = clock.call(&"get_world_degree")
	_ok(is_equal_approx(before, after), "the clock did not turn on its own",
		"%.3f became %.3f" % [before, after])


## The real scene, the real ride: one tick per day cycle, exactly 60° each, the
## piece arriving where it was sent.
func _check_travel() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(4):
		await process_frame

	var director := _find_first("RunMapDirector") as RunMapDirector
	var view := _find_first("RunMapView") as RunMapView
	var travel := _find_first("RunMapTravel") as RunMapTravel
	_ok(director != null and view != null and travel != null,
		"the run map scene opened with its director, view and travel")
	if director == null or view == null or travel == null:
		return

	var graph := director.get_graph()
	_ok(graph != null and not graph.is_empty(), "the map has a graph")
	if graph == null or graph.is_empty():
		return
	_ok(graph.current_id == graph.start_id, "the piece begins at the start")
	_ok(view.is_picking(), "the map opens taking a choice")

	var markers := _count_scripted(root, "RunMapSiteMarker")
	_ok(markers == graph.sites.size(), "every point on the graph is drawn",
		"%d markers against %d sites" % [markers, graph.sites.size()])

	var choices := graph.neighbours_of(graph.current_id)
	_ok(choices.size() >= 2, "the first point offers more than one road",
		"%d road(s)" % choices.size())
	if choices.is_empty():
		return

	# The longest road out of the start, so the multi-tick path is the one
	# measured rather than a one-tick special case wherever possible.
	var target := choices[0]
	for site_id: int in choices:
		if graph.find_link(graph.current_id, site_id).day_cycles \
				> graph.find_link(graph.current_id, target).day_cycles:
			target = site_id
	var link := graph.find_link(graph.current_id, target)
	var clock: Node = root.get_node_or_null(^"WorldClock")
	var before_degree: float = clock.call(&"get_world_degree")
	var before_day: int = clock.call(&"get_world_day")
	var before_period: int = clock.call(&"get_time_period_index")

	var ticks: Array[float] = []
	travel.day_cycle_spent.connect(func(_spent: int, _total: int) -> void:
		ticks.append(clock.call(&"get_world_degree")))

	view.site_chosen.emit(target, link)
	_ok(travel.is_travelling(), "the ride began")
	_ok(not view.is_picking(), "the map's choices closed for the ride")

	var frames := 0
	while travel.is_travelling() and frames < 2000:
		frames += 1
		await process_frame
	_ok(not travel.is_travelling(), "the ride finished", "%d frames" % frames)

	_ok(ticks.size() == link.day_cycles,
		"the ride was %d tick(s), one per day cycle" % link.day_cycles,
		"%d tick(s)" % ticks.size())

	var elapsed := _degrees_between(before_degree, before_day,
		clock.call(&"get_world_degree"), clock.call(&"get_world_day"))
	_ok(is_equal_approx(snappedf(elapsed, 0.001), 60.0 * float(link.day_cycles)),
		"the clock advanced 60 degrees per tick",
		"%.3f degrees for a %d day road" % [elapsed, link.day_cycles])

	var wanted_period := (before_period + link.day_cycles) % 6
	_ok(int(clock.call(&"get_time_period_index")) == wanted_period,
		"the day stage moved on by one per tick",
		"period %d, wanted %d" % [clock.call(&"get_time_period_index"), wanted_period])

	_ok(graph.current_id == target, "the piece arrived where it was sent")
	_ok(graph.get_site(target).revealed, "arriving revealed the point")
	_ok(view.is_picking(), "the map came back taking a choice")

	var sun := _find_first("SunController") as SunController
	_ok(sun != null and not sun.is_travelling(),
		"the sun is standing at one authored hour rather than blending")


func _degrees_between(from_degree: float, from_day: int,
		to_degree: float, to_day: int) -> float:
	return (to_degree - from_degree) + 360.0 * float(to_day - from_day)


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


func _count_scripted(node: Node, wanted: String) -> int:
	var total := 0
	if node.get_script() != null and node.get_script().get_global_name() == wanted:
		total += 1
	for child: Node in node.get_children():
		total += _count_scripted(child, wanted)
	return total
