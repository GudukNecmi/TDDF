extends SceneTree
## Headless check of Dust Camp's bandit layout and camp defence - the map built
## for real, and then asked every question the brief actually set.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/dust_camp_bandit_layout_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on the first failure, the same
## shape [code]dust_camp_smoke.gd[/code] already follows.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"

## The whole playable rectangle, and the grid emptiness is measured on.
const MAP_RECT := Rect2(-10000.0, -8000.0, 20000.0, 16000.0)
const GRID_COLUMNS := 4
const GRID_ROWS := 4

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame
	await physics_frame

	var bandits := _bandits()
	var player := _player()
	_ok(player != null, "player is in the map")
	if player == null:
		_finish(map)
		return

	_check_population(bandits)
	_check_camps(map, bandits)
	_check_coverage(map, bandits)
	_check_sanctuaries(map, bandits)
	_check_speed(bandits)
	await _check_camp_defence(map, bandits, player)
	await _check_sanctuary_break_off(map, bandits, player)

	_finish(map)


func _finish(map: Node) -> void:
	map.free()
	print("")
	if _failures == 0:
		print("DUST CAMP BANDIT LAYOUT SMOKE: all checks passed")
	else:
		print("DUST CAMP BANDIT LAYOUT SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label, "" if detail.is_empty() else "  -  " + detail])


# --- Placement ----------------------------------------------------------------


func _check_population(bandits: Array[WorldBandit]) -> void:
	_ok(bandits.size() == 100, "the map holds a hundred bandit groups",
		"%d found" % bandits.size())

	var routed := 0
	var on_ground := 0
	var terrain := _terrain()
	for bandit in bandits:
		if bandit.get_node_or_null(bandit.current_route) != null:
			routed += 1
		if terrain == null or terrain.is_walkable(bandit.global_position):
			on_ground += 1
	_ok(routed == bandits.size(), "every group has a patrol route to walk",
		"%d of %d" % [routed, bandits.size()])
	_ok(on_ground == bandits.size(), "every group is standing on walkable ground",
		"%d of %d" % [on_ground, bandits.size()])


## Five groups around each of the five normal camps, six around each of the
## three boss camps, all of them close to their own camp and to each other -
## and the boss camps' groups genuinely the stronger ones.
func _check_camps(map: Node, bandits: Array[WorldBandit]) -> void:
	var normal_total := 0
	var boss_total := 0
	var normal_strength := 0.0
	var boss_strength := 0.0
	var loose := 0
	var scattered := 0

	for location: Node in map.get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var place := location as WorldMapLocation
		if place == null or place.location == null:
			continue
		var kind: int = place.location.location_type
		if kind != MapLocation.LocationType.NORMAL_CAMP \
				and kind != MapLocation.LocationType.BOUNTY_CAMP:
			continue

		var garrison: Array[WorldBandit] = []
		for bandit in bandits:
			if bandit.territory_radius > 0.0 \
					and bandit.get_node_or_null(bandit.home_path) == location:
				garrison.append(bandit)

		var expected := 5 if kind == MapLocation.LocationType.NORMAL_CAMP else 6
		if garrison.size() != expected:
			loose += 1

		for bandit in garrison:
			if bandit.global_position.distance_to(location.global_position) > 1600.0:
				scattered += 1
			if kind == MapLocation.LocationType.NORMAL_CAMP:
				normal_total += 1
				normal_strength += bandit.group_strength
			else:
				boss_total += 1
				boss_strength += bandit.group_strength

	_ok(loose == 0, "every camp has the garrison it should", "%d camps miscounted" % loose)
	_ok(normal_total == 25, "the five normal camps hold twenty-five groups",
		"%d found" % normal_total)
	_ok(boss_total == 18, "the three boss camps hold eighteen groups",
		"%d found" % boss_total)
	_ok(scattered == 0, "no garrison group stands far from its own camp",
		"%d further than 1600px" % scattered)

	var normal_average := 0.0 if normal_total == 0 else normal_strength / float(normal_total)
	var boss_average := 0.0 if boss_total == 0 else boss_strength / float(boss_total)
	_ok(boss_average > normal_average * 1.5, "boss camps hold the stronger groups",
		"boss %.0f vs normal %.0f" % [boss_average, normal_average])


## No quarter of the desert is left bare - measured on the same grid the layout
## tool fills against, so this is an independent read of the result rather than
## the tool marking its own work.
func _check_coverage(map: Node, bandits: Array[WorldBandit]) -> void:
	var counts := {}
	for bandit in bandits:
		var key := _cell_of(bandit.global_position)
		counts[key] = int(counts.get(key, 0)) + 1

	var terrain := _terrain()
	var empty := 0
	var thinnest := 999
	var cells := 0
	for cx in GRID_COLUMNS:
		for cy in GRID_ROWS:
			var centre := Vector2(
				MAP_RECT.position.x + MAP_RECT.size.x * (float(cx) + 0.5) / float(GRID_COLUMNS),
				MAP_RECT.position.y + MAP_RECT.size.y * (float(cy) + 0.5) / float(GRID_ROWS))
			# A cell with no ground in the middle of it is rock, not a gap in
			# the patrols, so it is not held against the layout.
			if terrain != null and not terrain.is_walkable(centre):
				continue
			cells += 1
			var here := int(counts.get(Vector2i(cx, cy), 0))
			thinnest = mini(thinnest, here)
			if here == 0:
				empty += 1

	_ok(empty == 0, "no walkable quarter of the map is left empty",
		"%d of %d cells bare" % [empty, cells])
	_ok(thinnest >= 3, "even the thinnest sector is genuinely patrolled",
		"%d groups in it" % thinnest)


## The Saloon and the Market are clear of bandits, and the map says so itself
## through the two [WorldMapSanctuary] nodes rather than through this script's
## own idea of where they are.
func _check_sanctuaries(map: Node, bandits: Array[WorldBandit]) -> void:
	var sanctuaries: Array[WorldMapSanctuary] = []
	for node: Node in map.get_tree().get_nodes_in_group(WorldMapSanctuary.GROUP):
		var sanctuary := node as WorldMapSanctuary
		if sanctuary != null:
			sanctuaries.append(sanctuary)

	_ok(sanctuaries.size() == 2, "the Saloon and the Market are marked safe",
		"%d sanctuaries" % sanctuaries.size())

	var intruders := 0
	var nearest := 1.0e12
	for sanctuary in sanctuaries:
		for bandit in bandits:
			var distance := bandit.global_position.distance_to(sanctuary.global_position)
			nearest = minf(nearest, distance)
			if distance <= sanctuary.radius:
				intruders += 1
	_ok(intruders == 0, "no group is placed on safe ground",
		"nearest sits %dpx out" % int(nearest))

	var route_intruders := 0
	for node: Node in map.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit == null:
			continue
		var route := bandit.get_node_or_null(bandit.current_route) as WorldBanditRoute
		if route == null:
			continue
		for point: Vector2 in route.get_points():
			for sanctuary in sanctuaries:
				if sanctuary.covers(point):
					route_intruders += 1
	_ok(route_intruders == 0, "no patrol route runs onto safe ground",
		"%d waypoints inside" % route_intruders)


## The groups walk at a grounded pace rather than the pace they used to.
func _check_speed(bandits: Array[WorldBandit]) -> void:
	var fastest := 0.0
	var fastest_patrol := 0.0
	for bandit in bandits:
		fastest = maxf(fastest, bandit.movement_speed)
		fastest_patrol = maxf(fastest_patrol, bandit.movement_speed * bandit.roam_speed_multiplier)

	# The player's own mounted walk is 220px/s and their gallop 420 - see
	# WorldMapHorse - and on foot they walk at 220 too. Every group rides at
	# fifteen percent under the pace they used to, which puts even a full chase
	# under the slowest of those: a player who keeps moving is never run down,
	# and a group closes only on one who has stopped. What a chase still is, is
	# faster than the amble the same group patrols at, so a group coming for the
	# player reads as a group that has picked up.
	_ok(fastest_patrol < 220.0, "no group patrols faster than the player walks",
		"fastest patrol %.0fpx/s" % fastest_patrol)
	_ok(fastest < 220.0, "and no group outrides the player at any pace of their own",
		"fastest chase %.0fpx/s" % fastest)
	_ok(fastest > fastest_patrol * 1.2, "but a chase is visibly quicker than a patrol",
		"%.0fpx/s against %.0fpx/s" % [fastest, fastest_patrol])


# --- Behaviour ----------------------------------------------------------------


## A garrison group chases the player across its own ground and breaks off the
## moment they are off it - and heads home rather than standing where it gave
## up.
##
## The group watched is deliberately one strong enough to give chase at all:
## whether a sighting becomes a chase, a flight or nothing is
## [WorldBanditThreatProfile]'s own existing ratio against
## [WorldMapPlayerPower], untouched by any of this, so a group the player
## outclasses correctly flees and has no chase to break off.
func _check_camp_defence(map: Node, bandits: Array[WorldBandit], player: Node2D) -> void:
	var guard := _chase_capable(bandits, true)
	if guard == null:
		_ok(false, "a garrison group strong enough to give chase was available")
		return

	var home := guard.get_node_or_null(guard.home_path) as Node2D
	_ok(home != null, "a garrison group knows which camp it belongs to")
	if home == null:
		return

	# Ride up to it well inside its own ground: it should commit. Kept a long
	# way outside WorldBandit.contact_radius throughout, so this measures the
	# chase rather than tripping WorldMapCombatBridge into an encounter.
	player.global_position = guard.global_position + Vector2(400.0, 0.0)
	await _wait(0.5)
	_ok(guard.behavior_state == WorldBandit.BehaviorState.CHASE,
		"a garrison gives chase on its own ground", guard.get_state_name())

	# Now step the pair of them off that ground entirely while staying right
	# beside each other - so the group has not outrun anything, and the only
	# thing that can end this chase is the territory boundary.
	#
	# The spot is chosen off the terrain rather than picked: dropped onto rock
	# or past the map edge the group is clamped straight back onto the
	# navigation mesh, which would separate the two and hand the ending to
	# give_up_distance instead - a different rule passing for this one.
	var beyond := _ground_beyond(home.global_position, guard.territory_radius + 700.0)
	var outward := home.global_position.direction_to(beyond)
	guard.global_position = beyond
	player.global_position = beyond + outward * 400.0
	await _wait(0.6)
	_ok(guard.behavior_state == WorldBandit.BehaviorState.DISENGAGE
			or guard.behavior_state == WorldBandit.BehaviorState.PATROL,
		"it breaks off once the player is off its territory - though still beside it",
		"%s, player %dpx away" % [
			guard.get_state_name(),
			int(guard.global_position.distance_to(player.global_position))])

	var before := guard.global_position.distance_to(home.global_position)
	await _wait(2.5)
	var after := guard.global_position.distance_to(home.global_position)
	_ok(after < before, "and it turns back toward its camp",
		"%dpx from home, was %dpx" % [int(after), int(before)])


## A chase that reaches the Saloon holds on for about two seconds and then
## gives up - through the group's own existing disengage, not a new rule.
##
## Staged with the group a step outside the safe ground and the player a step
## inside it, so nothing else about the chase has changed: the two are well
## within [member WorldBandit.give_up_distance] of each other the whole time,
## and the only new fact is which side of the line the player is standing on.
func _check_sanctuary_break_off(map: Node, bandits: Array[WorldBandit], player: Node2D) -> void:
	var sanctuary: WorldMapSanctuary = null
	for node: Node in map.get_tree().get_nodes_in_group(WorldMapSanctuary.GROUP):
		sanctuary = node as WorldMapSanctuary
		if sanctuary != null:
			break
	if sanctuary == null:
		_ok(false, "a sanctuary was available to run to")
		return

	var chaser := _chase_capable(bandits, false)
	if chaser == null:
		_ok(false, "a group strong enough to give chase was available")
		return
	# Untethered for this check, so the boundary cannot be what ends the chase.
	chaser.territory_radius = 0.0

	var outward := Vector2.RIGHT
	# Far enough apart that the group cannot close to contact inside the two
	# seconds this is watching - WorldMapCombatBridge would open an encounter
	# and there would be no chase left to measure - and still comfortably
	# inside give_up_distance, so distance is never what ends it.
	chaser.global_position = sanctuary.global_position + outward * (sanctuary.radius + 650.0)
	player.global_position = sanctuary.global_position + outward * (sanctuary.radius - 200.0)
	chaser._enter_chase()
	_ok(sanctuary.covers(player.global_position), "the player is standing on safe ground")
	_ok(chaser.global_position.distance_to(player.global_position) < chaser.give_up_distance,
		"and has not outrun the group doing the chasing",
		"%dpx apart, gives up past %dpx" % [
			int(chaser.global_position.distance_to(player.global_position)),
			int(chaser.give_up_distance)])

	await _wait(1.0)
	_ok(chaser._is_pursuing(), "it does not stop dead the instant they cross the line",
		chaser.get_state_name())

	await _wait(1.6)
	_ok(not chaser._is_pursuing(), "and gives up about two seconds later",
		chaser.get_state_name())

	var route := chaser.get_node_or_null(chaser.current_route) as WorldBanditRoute
	var heading_home := false
	if route != null:
		for point: Vector2 in route.get_points():
			if point.distance_to(chaser.target_position) < 1.0:
				heading_home = true
	_ok(heading_home, "and heads for its own route rather than the player",
		"target (%d, %d)" % [int(chaser.target_position.x), int(chaser.target_position.y)])
	_ok(not sanctuary.covers(chaser.global_position),
		"without ever setting foot on the safe ground itself")


## A group the map's own threat ratios would actually send after the player -
## see [method WorldBandit._on_player_spotted]. Asked of the live
## [WorldMapPlayerPower] rather than assumed, so retuning either side of that
## comparison retunes which group this picks instead of breaking the check.
func _chase_capable(bandits: Array[WorldBandit], garrison: bool) -> WorldBandit:
	var power := WorldMapPlayerPower.get_active(root)
	var player_power := power.player_power if power != null else 0.0
	for bandit in bandits:
		if garrison and bandit.territory_radius <= 0.0:
			continue
		var ratio := bandit.threat_profile.chase_power_ratio if bandit.threat_profile != null else 1.6
		if bandit.group_strength >= player_power * ratio:
			return bandit
	return null


# --- Helpers ------------------------------------------------------------------


func _cell_of(point: Vector2) -> Vector2i:
	var local := point - MAP_RECT.position
	return Vector2i(
		clampi(int(local.x / MAP_RECT.size.x * float(GRID_COLUMNS)), 0, GRID_COLUMNS - 1),
		clampi(int(local.y / MAP_RECT.size.y * float(GRID_ROWS)), 0, GRID_ROWS - 1))


func _terrain() -> TerrainShape:
	return load("res://Resources/Maps/Desert/Regions/dust_camp_terrain.tres") as TerrainShape


func _bandits() -> Array[WorldBandit]:
	var found: Array[WorldBandit] = []
	for node: Node in root.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit != null:
			found.append(bandit)
	return found


func _player() -> Node2D:
	return root.get_tree().get_first_node_in_group(&"player") as Node2D


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / 60.0


## A point about [param radius] out from [param centre] that is walkable
## ground with room around it, and stays walkable for another few hundred
## pixels outward so the player can be stood beyond it too.
func _ground_beyond(centre: Vector2, radius: float) -> Vector2:
	var terrain := _terrain()
	if terrain == null:
		return centre + Vector2(radius, 0.0)
	for i in 36:
		var outward := Vector2.from_angle(TAU * float(i) / 36.0)
		var spot := centre + outward * radius
		if terrain.is_clear(spot, 250.0) and terrain.is_clear(spot + outward * 400.0, 250.0):
			return spot
	return centre + Vector2(radius, 0.0)
