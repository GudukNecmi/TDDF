extends SceneTree
## Headless check that the Dust Camp World Map is built the way it is authored.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/dust_camp_smoke.gd
## [/codeblock]
##
## It builds the map for real - the same scene the router changes to - and then
## asks it the questions that would otherwise have to be eyeballed: how large the
## ground actually is, whether the navigation mesh baked, whether every prop and
## every bandit is standing on walkable ground, and whether a path across a rock
## mass genuinely goes round it rather than through it. Prints a line per check
## and exits non-zero on the first failure, so it is usable from a script.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const ARENA_PATH := "res://Scenes/World/Arenas/DustCampArena.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	# Two frames: one for every node to ready, one for the deferred navigation
	# bake and the navigation server's own synchronisation.
	await process_frame
	await physics_frame
	await physics_frame

	var shape: TerrainShape = load("res://Resources/Maps/Desert/Regions/dust_camp_terrain.tres")
	_check_bounds(map, shape)
	_check_scale(map)
	_check_terrain(map, shape)
	await _check_navigation(map, shape)
	_check_props(map, shape)
	_check_bandits(map, shape)
	await _check_bandit_walks_round(map, shape)
	_check_singletons(map)
	_check_arena()

	map.free()
	print("")
	if _failures == 0:
		print("DUST CAMP SMOKE: all checks passed")
	else:
		print("DUST CAMP SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label, "" if detail.is_empty() else "  -  " + detail])


# --- checks -----------------------------------------------------------------

func _check_bounds(map: Node, shape: TerrainShape) -> void:
	print("--- extent ---")
	var bounds := map.get_node("CameraBounds") as CameraBounds
	var fenced := bounds.get_world_region()
	_ok(is_equal_approx(fenced.size.x, 20000.0) and is_equal_approx(fenced.size.y, 16000.0),
		"playable area measured off the walls",
		"%.0f x %.0f at %s" % [fenced.size.x, fenced.size.y, fenced.position])
	_ok(shape.bounds.size == fenced.size, "terrain shape matches the walls",
		"shape %s" % shape.bounds)

	var masses := map.get_node("WorldMap/Terrain/Masses") as TerrainMasses
	var surround := masses.get_node("Surround") as Polygon2D
	var ground := masses.get_node("Ground") as Polygon2D
	_ok(Rect2(surround.polygon[0], surround.polygon[2] - surround.polygon[0])
			.is_equal_approx(fenced),
		"background covers the playable area",
		"%s over %.0f x %.0f" % [
			masses.ground_texture.resource_path.get_file(),
			fenced.size.x, fenced.size.y])
	_ok(ground.polygon.size() == shape.walkable_outline.size()
			and surround.z_index < ground.z_index
			and ground.z_index < masses.mass_z_index,
		"rock is painted over the background, not baked into it",
		"surround z%d, desert z%d, %d masses at z%d" % [
			surround.z_index, ground.z_index,
			masses.get_mass_count(), masses.mass_z_index])


func _check_scale(map: Node) -> void:
	print("--- scale ---")
	var zone := map.get_node("WorldMap/Camera/Zone") as WorldZone
	var arena: Node = load(ARENA_PATH).instantiate()
	var arena_scale: float = 1.0
	for node: Node in arena.find_children("*", "Node", true, false):
		if node is PropScale:
			arena_scale = (node as PropScale).scale_multiplier
	var map_scale: float = 1.0
	for node: Node in map.find_children("*", "Node", true, false):
		if node is PropScale:
			map_scale = (node as PropScale).scale_multiplier
	arena.queue_free()

	_ok(is_equal_approx(zone.camera_zoom_multiplier, 0.4),
		"world map camera is 2.5x wider than arena zoom",
		"zoom multiplier %.2f" % zone.camera_zoom_multiplier)
	_ok(is_equal_approx(map_scale, arena_scale),
		"props are drawn at arena scale", "map %.2f, arena %.2f" % [map_scale, arena_scale])

	var view := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	print("       camera shows %.0f x %.0f px at normal zoom" % [
		view.x / zone.camera_zoom_multiplier, view.y / zone.camera_zoom_multiplier])


func _check_terrain(map: Node, shape: TerrainShape) -> void:
	print("--- terrain ---")
	var masses := map.get_node("WorldMap/Terrain/Masses") as TerrainMasses
	_ok(masses.get_mass_count() == shape.masses.size(),
		"a collision body per rock mass",
		"%d built, %d authored" % [masses.get_mass_count(), shape.masses.size()])
	_ok(masses.has_node("Boundary"), "the desert edge is walled")
	_ok(shape.has_clearance_grid(), "clearance grid is baked",
		"%d x %d cells" % [shape.clearance_size.x, shape.clearance_size.y])


func _check_navigation(map: Node, shape: TerrainShape) -> void:
	print("--- navigation ---")
	var nav := map.get_node("WorldMap/Navigation") as WorldMapNavigation
	_ok(nav.get_polygon_count() > 0, "navigation mesh baked",
		"%d polygons" % nav.get_polygon_count())

	var nav_map: RID = nav.get_world_2d().navigation_map
	# Straight across the widest rock mass in the middle of the map: the way in
	# a straight line is through it, so a path that does not touch it is proof
	# the mesh is being used rather than ignored.
	var from := Vector2(-4600.0, -4900.0)
	var to := Vector2(4200.0, -4900.0)
	var straight_blocked := false
	for step: int in 60:
		if not shape.is_walkable(from.lerp(to, float(step) / 59.0)):
			straight_blocked = true
			break
	_ok(straight_blocked, "the test line really is blocked by rock")

	var path: PackedVector2Array = NavigationServer2D.map_get_path(nav_map, from, to, true)
	_ok(path.size() >= 2, "a way round was found", "%d corners" % path.size())
	var off: int = 0
	var samples: int = 0
	for index: int in maxi(path.size() - 1, 0):
		var a := path[index]
		var b := path[index + 1]
		var steps := maxi(int(a.distance_to(b) / 60.0), 1)
		for step: int in steps + 1:
			samples += 1
			if not shape.is_walkable(a.lerp(b, float(step) / float(steps))):
				off += 1
	_ok(off == 0, "every step of that path is on walkable ground",
		"%d of %d samples off it" % [off, samples])


func _check_props(map: Node, shape: TerrainShape) -> void:
	print("--- scenery ---")
	var total: int = 0
	var off: int = 0
	for node: Node in map.find_children("*", "Node2D", true, false):
		var scatter := node as PropScatter
		if scatter == null:
			continue
		# Drains whatever the staged spawn has not built yet, so the check sees
		# the whole desert rather than the first frame of it.
		while scatter.get_pending_count() > 0:
			scatter._pump_stream(1000.0)
		for prop: Node in scatter.get_children():
			var prop2d := prop as Node2D
			if prop2d == null:
				continue
			total += 1
			if not shape.is_walkable(prop2d.global_position):
				off += 1
	_ok(total > 0, "scenery was placed", "%d props" % total)
	_ok(off == 0, "no prop stands in the rock", "%d off walkable ground" % off)


func _check_bandits(map: Node, shape: TerrainShape) -> void:
	print("--- bandits ---")
	var groups: Array[Node] = map.get_node("WorldMap/WorldBandits/Groups").get_children()
	var off: int = 0
	var routes_off: int = 0
	var route_points: int = 0
	for node: Node in groups:
		var bandit := node as WorldBandit
		if bandit == null:
			continue
		if not shape.is_walkable(bandit.global_position):
			off += 1
	for node: Node in map.get_node("WorldMap/WorldBandits/Routes").get_children():
		var route := node as WorldBanditRoute
		if route == null:
			continue
		for point: Vector2 in route.get_points():
			route_points += 1
			if not shape.is_walkable(point):
				routes_off += 1
	_ok(groups.size() > 0, "bandit groups placed", "%d groups" % groups.size())
	_ok(off == 0, "every group starts on walkable ground", "%d off it" % off)
	_ok(routes_off == 0, "every patrol point is on walkable ground",
		"%d of %d off it" % [routes_off, route_points])

	var first := groups[0] as WorldBandit
	_ok(first.uses_navigation, "groups walk the navigation mesh")


## The behaviour itself, not the query behind it: a group is stood on one side of
## a rock mass, the player on the other, and the fight is actually simulated for
## a few hundred physics frames while every position it passes through is tested.
## Walking through the rock would show up as a single sample inside it.
func _check_bandit_walks_round(map: Node, shape: TerrainShape) -> void:
	print("--- bandits walking round rock ---")
	var bandit := map.get_node("WorldMap/WorldBandits/Groups").get_child(0) as WorldBandit
	var player := map.get_node("Player") as Node2D
	var start := Vector2(-4600.0, -4900.0)
	var goal := Vector2(4200.0, -4900.0)

	bandit.global_position = start
	player.global_position = goal
	bandit.begin_ambush(goal)

	var opening := start.distance_to(goal)
	var inside: int = 0
	var samples: int = 0
	var worst := Vector2.ZERO
	for _step: int in 900:
		await physics_frame
		player.global_position = goal
		samples += 1
		if not shape.is_walkable(bandit.global_position):
			inside += 1
			worst = bandit.global_position
	var closing := bandit.global_position.distance_to(goal)

	_ok(inside == 0, "the group never crossed into the rock",
		"%d of %d samples inside it%s" % [inside, samples,
			"" if inside == 0 else " (e.g. %s)" % worst])
	_ok(closing < opening - 400.0, "the group closed on a player it cannot walk straight to",
		"%.0f px away, was %.0f" % [closing, opening])
	_ok(bandit.behavior_state == WorldBandit.BehaviorState.CHASE,
		"it was chasing the whole way", bandit.get_state_name())
	bandit.end_ambush()


func _check_singletons(map: Node) -> void:
	print("--- one of each ---")
	var cameras: int = 0
	var suns: int = 0
	var clocks: int = 0
	var navs: int = 0
	for node: Node in map.find_children("*", "Node", true, false):
		if node is Camera2D and not (node.get_parent() is SubViewport):
			cameras += 1
		if node.is_in_group(&"sun"):
			suns += 1
		if node is NavigationRegion2D:
			navs += 1
	for name: String in ["WorldClock", "LoadingScreen", "WorldRouter", "WorldState"]:
		if root.has_node(NodePath(name)):
			clocks += 1
	_ok(cameras == 1, "one gameplay camera", "%d found" % cameras)
	_ok(suns == 1, "one sun", "%d found" % suns)
	_ok(navs == 1, "one navigation region", "%d found" % navs)
	_ok(clocks == 4, "the world clock, curtain, router and state are all autoloads",
		"%d of 4 present" % clocks)


func _check_arena() -> void:
	print("--- arena ---")
	var arena: Node = load(ARENA_PATH).instantiate()
	var sun: SunController = null
	for node: Node in arena.find_children("*", "Node2D", true, false):
		if node is SunController:
			sun = node as SunController
	_ok(sun != null and sun.holds_for_combat, "the arena sun is held for the fight")
	_ok(sun != null and not sun.hold_uses_longest_shadow,
		"it keeps the current day stage exactly as authored")

	var clock: Node = root.get_node_or_null(^"WorldClock")
	if clock != null and sun != null:
		root.add_child(arena)
		var stage := sun.get_stage_index()
		var period: int = clock.call(&"get_time_period_index")
		_ok(stage == period, "the held hour is the world clock's own",
			"sun stage %d, clock period %d" % [stage, period])
		var before := sun.get_state().direction
		for _step: int in 4:
			sun._process(1.0)
		_ok(before.is_equal_approx(sun.get_state().direction),
			"the shadow direction does not move during the fight")
		arena.queue_free()
	else:
		arena.queue_free()
