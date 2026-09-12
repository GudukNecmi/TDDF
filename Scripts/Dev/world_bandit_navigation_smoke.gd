extends SceneTree
## Headless check that World Map bandit groups get where they are going - that
## none of them is left pushing at a rock, orbiting a waypoint it can never
## reach, or standing still because the way to its destination is blocked.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_bandit_navigation_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on the first failure, the same
## shape [code]dust_camp_bandit_layout_smoke.gd[/code] already follows.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const TERRAIN_PATH := "res://Resources/Maps/Desert/Regions/dust_camp_terrain.tres"

## How long the whole map is watched patrolling, in seconds.
const RUN_SECONDS := 45.0
## How often every group's position is sampled during that, in seconds.
const STEP := 0.25
## How little ground a group may cover in one sample and still count as walking,
## as a fraction of the ground its own speed says it should have covered. A
## group under this is standing still, however hard it is pushing.
const WALKING_FRACTION := 0.35
## The longest any group may stand still before this calls it stuck, in seconds.
## Comfortably longer than [member WorldBandit.stall_window] times
## [member WorldBandit.stall_repath_attempts], so the recovery has every chance
## to run before this is held against it.
const STALL_LIMIT := 6.0

## How long one group is watched with the player standing at its destination -
## see [method _check_watched_group].
const WATCH_SECONDS := 20.0
## How far back the player stands while doing it, in pixels. Comfortably outside
## [member WorldBandit.contact_radius], so the watching never becomes an
## encounter, and well inside [member WorldBandit.near_range], so the group
## really does re-run its AI every frame.
const WATCH_STAND_OFF := 300.0
## The most a watched group's heading may turn in that time, in full turns. An
## ordinary route walk is about one; a group circling the spot it stands on
## managed sixty-eight.
const WATCH_SPIN_LIMIT := 5.0
## The least ground a watched group must cover between one waypoint and the
## next, in pixels. A real leg of a route is several hundred; the flip-flop this
## guards against averaged two hundred and read as arriving thirty times a
## minute without going anywhere.
const WATCH_LEG_GROUND := 400.0

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	for i in 4:
		await physics_frame

	var nav := map.find_child("Navigation", true, false) as WorldMapNavigation
	_ok(nav != null and nav.get_polygon_count() > 0, "the map bakes navigable ground",
		"%d polygons" % (0 if nav == null else nav.get_polygon_count()))

	var bandits := _bandits()
	_ok(not bandits.is_empty(), "the map has bandit groups on it",
		"%d found" % bandits.size())
	var terrain := load(TERRAIN_PATH) as TerrainShape
	_ok(terrain != null and not terrain.masses.is_empty(),
		"the map has a ground plan with rock in it")
	if bandits.is_empty() or nav == null or terrain == null:
		_finish(map)
		return

	# On safe ground before a single group is watched walking. Groups give
	# chase to a player they can beat now - see
	# [member WorldBanditThreatProfile.chase_power_ratio] - so a player left
	# standing wherever the scene spawned them is ridden down, contacted, and
	# the World Map's own encounter freezes the whole map with it: every group
	# on it then reads as pinned against an obstacle for the rest of the run.
	# A [WorldMapSanctuary] is the game's own answer to that and costs this
	# check nothing, since none of what it measures is about the player at all.
	_park_player_safely()

	await _check_patrols(bandits)
	await _check_blocked_waypoint(bandits, terrain)
	await _check_blocked_chase(bandits, terrain)
	# Last of the four on purpose: it is the only one that stands the player
	# close enough to a group for the World Map's own encounter to fire, and an
	# encounter freezes the group it caught along with every reinforcement near
	# it. Run earlier, that would be measured as the next check's group refusing
	# to move.
	await _check_watched_group(bandits)

	_finish(map)


## The whole map, left to walk itself for three quarters of a minute. Every
## group should cover ground, reach waypoints, and never stand pressed against
## anything for more than a few seconds together.
func _check_patrols(bandits: Array[WorldBandit]) -> void:
	var travelled := {}
	var advances := {}
	var stall := {}
	var worst_stall := {}
	var last_point := {}
	var last_index := {}
	for b in bandits:
		travelled[b] = 0.0
		advances[b] = 0
		stall[b] = 0.0
		worst_stall[b] = 0.0
		last_point[b] = b.global_position
		last_index[b] = b.current_route_index

	var elapsed := 0.0
	while elapsed < RUN_SECONDS:
		await _wait(STEP)
		elapsed += STEP
		for b in bandits:
			if not is_instance_valid(b):
				continue
			var covered: float = (last_point[b] as Vector2).distance_to(b.global_position)
			last_point[b] = b.global_position
			travelled[b] = float(travelled[b]) + covered
			if b.current_route_index != int(last_index[b]):
				advances[b] = int(advances[b]) + 1
				last_index[b] = b.current_route_index
			# Measured against the group's own speed rather than a flat number,
			# so a heavy slow group is judged as one and a light quick one as
			# one, exactly the way the recovery itself judges them.
			if covered < b.movement_speed * b.roam_speed_multiplier * STEP * WALKING_FRACTION:
				stall[b] = float(stall[b]) + STEP
				worst_stall[b] = maxf(float(worst_stall[b]), float(stall[b]))
			else:
				stall[b] = 0.0

	var frozen: Array[String] = []
	var never_arrived: Array[String] = []
	var pinned: Array[String] = []
	var patrolling := 0
	for b in bandits:
		if not is_instance_valid(b) or b.behavior_state != WorldBandit.BehaviorState.PATROL:
			continue
		patrolling += 1
		if float(travelled[b]) < 60.0:
			frozen.append(b.name)
		elif int(advances[b]) == 0:
			never_arrived.append(b.name)
		if float(worst_stall[b]) > STALL_LIMIT:
			pinned.append("%s (%.1fs)" % [b.name, float(worst_stall[b])])

	_ok(frozen.is_empty(), "no group stands still for the whole patrol",
		"%d frozen: %s" % [frozen.size(), ", ".join(frozen.slice(0, 6))])
	_ok(never_arrived.is_empty(), "every group reaches waypoints rather than circling one",
		"%d never arrived: %s" % [never_arrived.size(), ", ".join(never_arrived.slice(0, 6))])
	_ok(pinned.is_empty(),
		"no group is pinned against an obstacle for longer than %ds" % int(STALL_LIMIT),
		"%d pinned: %s" % [pinned.size(), ", ".join(pinned.slice(0, 6))])
	_ok(patrolling > 0, "the map was actually patrolling", "%d groups" % patrolling)


## A group being watched by a player it will neither give chase to nor run from
## keeps walking its route rather than turning on the spot.
##
## Staged as the player standing at the place the group is walking to, which is
## what a player does at an interactable location: they ride up to it and stop,
## and the group's route brings it to them. A player that close makes the group
## re-run its AI every frame - see [member WorldBandit.near_range] - and a
## player it can neither chase nor flee stands it down into patrol on every one
## of those frames. Re-entering patrol used to re-snap the route index to
## whichever waypoint was nearest, which for a group beside one is the one it has
## just left: it turned back to it, arrived, was pointed at the next, and turned
## back again, circling that spot for as long as the player stood there.
##
## Measured as heading rotation and as ground covered per waypoint, because that
## is what separates the two: the fault walked at full speed the whole time it
## was stuck, so distance alone says nothing.
func _check_watched_group(bandits: Array[WorldBandit]) -> void:
	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	var power := root.get_tree().get_first_node_in_group(
		WorldMapPlayerPower.GROUP) as WorldMapPlayerPower
	_ok(player != null and power != null, "the map has a player with a readable power")
	if player == null or power == null:
		return

	# A group the player is neither strong enough to be chased by nor weak
	# enough to be fled from - the band that stands down into patrol every tick.
	var subject: WorldBandit = null
	for b in bandits:
		if b.get_node_or_null(b.current_route) == null:
			continue
		var flee: float = b.threat_profile.flee_power_ratio if b.threat_profile != null else 1.6
		var chase: float = b.threat_profile.chase_power_ratio if b.threat_profile != null else 1.6
		if power.player_power < b.group_strength * flee \
				and b.group_strength < power.player_power * chase:
			subject = b
			break
	_ok(subject != null, "a group was found that the player neither chases nor flees")
	if subject == null:
		return

	var walked := 0.0
	var spin := 0.0
	var legs := 0
	var last := subject.global_position
	var heading := subject._movement_heading.angle()
	var index := subject.current_route_index
	var elapsed := 0.0
	while elapsed < WATCH_SECONDS:
		await _wait(STEP)
		elapsed += STEP
		# Standing at where the group is going, and stood far enough back that
		# walking up to the player never becomes the encounter this is not
		# measuring - which would pause the tree and stop the group outright.
		player.global_position = subject.target_position + Vector2(WATCH_STAND_OFF, 0.0)
		if root.get_tree().paused:
			root.get_tree().paused = false
			subject.active = true
		walked += last.distance_to(subject.global_position)
		last = subject.global_position
		var now := subject._movement_heading.angle()
		spin += absf(angle_difference(heading, now))
		heading = now
		if subject.current_route_index != index:
			legs += 1
			index = subject.current_route_index

	_ok(spin / TAU <= WATCH_SPIN_LIMIT,
		"a watched group walks its route instead of turning on the spot",
		"heading turned %.1f full turns in %ds" % [spin / TAU, int(WATCH_SECONDS)])
	_ok(walked >= subject.movement_speed * subject.roam_speed_multiplier * WATCH_SECONDS * 0.5,
		"and covers the ground its own speed says it should",
		"%d px of a possible %d" % [int(walked),
			int(subject.movement_speed * subject.roam_speed_multiplier * WATCH_SECONDS)])
	_ok(legs == 0 or walked / float(legs) >= WATCH_LEG_GROUND,
		"and puts real distance between one waypoint and the next",
		"%d waypoints reached, %d px each" % [legs, int(walked / maxf(float(legs), 1.0))])


## A patrol waypoint that turns out to be unreachable - one inside a rock - is
## given up on and the route carried on with, rather than walked at until the
## rock stops the group and then leaned on for good.
##
## Staged rather than waited for, and staged on the map's own rock: the point
## is moved to the middle of a mass taken from the region's [TerrainShape], so
## it is inside the rock the player can see rather than a coordinate this
## script invented.
func _check_blocked_waypoint(bandits: Array[WorldBandit], terrain: TerrainShape) -> void:
	var subject: WorldBandit = null
	var route: WorldBanditRoute = null
	var rock := Vector2.ZERO
	for b in bandits:
		route = b.get_node_or_null(b.current_route) as WorldBanditRoute
		if route == null or route.get_child_count() < 3:
			route = null
			continue
		rock = _rock_near(terrain, b.global_position, 4000.0)
		if rock != Vector2.INF:
			subject = b
			break
		route = null

	_ok(subject != null, "a group was patrolling within reach of a rock")
	if subject == null:
		return

	# The waypoint the group is walking to right now is buried in the rock. The
	# route is the group's own, unchanged in every other way - this is exactly
	# the map's own authoring mistake, made on purpose.
	var point := route.get_child(subject.current_route_index) as Node2D
	point.global_position = rock
	subject._enter_patrol()
	var entered := subject.current_route_index

	var moved := 0.0
	var last := subject.global_position
	var stalled := 0.0
	var worst := 0.0
	var elapsed := 0.0
	while elapsed < 20.0:
		await _wait(STEP)
		elapsed += STEP
		if not is_instance_valid(subject):
			break
		var covered := last.distance_to(subject.global_position)
		last = subject.global_position
		moved += covered
		if covered < subject.movement_speed * subject.roam_speed_multiplier * STEP * WALKING_FRACTION:
			stalled += STEP
			worst = maxf(worst, stalled)
		else:
			stalled = 0.0

	_ok(subject.current_route_index != entered,
		"a waypoint inside a rock is given up on and the route carried on with",
		"index %d, was %d" % [subject.current_route_index, entered])
	_ok(worst <= STALL_LIMIT, "and the group never leans on the rock while doing it",
		"longest stall %.1fs" % worst)
	_ok(terrain.is_walkable(subject.global_position), "nor ends up inside it")


## A chase whose straight line runs through a mesa goes round it and closes on
## the player, rather than pressing into the near face of it.
##
## Run as an ambush - see [method WorldBandit.begin_ambush] - purely so the
## chase lasts long enough to watch: an ordinary chase of somebody out of sight
## behind a mesa is given up on in a couple of seconds by the group's own
## existing rules, which is correct behaviour and leaves nothing to measure.
func _check_blocked_chase(bandits: Array[WorldBandit], terrain: TerrainShape) -> void:
	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	_ok(player != null, "the map has a player to be chased")
	if player == null:
		return

	# Two spots on opposite sides of the same mesa, both on open ground, with
	# the rock squarely between them.
	var here := Vector2.INF
	var across := Vector2.INF
	for mass: PackedVector2Array in terrain.masses:
		if mass.size() < 8:
			continue
		var centre := Vector2.ZERO
		for p: Vector2 in mass:
			centre += p
		centre /= float(mass.size())
		if terrain.is_walkable(centre):
			continue
		var span := 0.0
		for p: Vector2 in mass:
			span = maxf(span, centre.distance_to(p))
		if span < 700.0:
			continue
		for i in 12:
			var outward := Vector2.from_angle(TAU * float(i) / 12.0)
			var a := centre + outward * (span + 500.0)
			var b := centre - outward * (span + 500.0)
			if terrain.is_clear(a, 260.0) and terrain.is_clear(b, 260.0) \
					and not terrain.is_walkable(centre):
				here = a
				across = b
				break
		if here != Vector2.INF:
			break

	_ok(here != Vector2.INF, "the map has a mesa with open ground either side of it")
	if here == Vector2.INF:
		return

	var subject := bandits[0]
	subject.territory_radius = 0.0
	subject.global_position = here
	player.global_position = across
	# Every other group stood down for the length of this one, and put back
	# afterwards. The player has to stand out in the open here for the chase to
	# have somewhere to go, and a player in the open is now something any group
	# that spots them rides down - see
	# [member WorldBanditThreatProfile.chase_power_ratio]. One of them reaching
	# the player opens the World Map's encounter and freezes the map, which
	# would be measured as this group giving up on the mesa.
	for other in bandits:
		if other != subject and is_instance_valid(other):
			other.active = false

	var opening := subject.global_position.distance_to(player.global_position)
	subject.begin_ambush(player.global_position)

	var stalled := 0.0
	var worst := 0.0
	var closest := opening
	var last := subject.global_position
	var elapsed := 0.0
	while elapsed < 25.0:
		await _wait(STEP)
		elapsed += STEP
		var covered := last.distance_to(subject.global_position)
		last = subject.global_position
		closest = minf(closest, subject.global_position.distance_to(player.global_position))
		if covered < subject.movement_speed * STEP * WALKING_FRACTION:
			stalled += STEP
			worst = maxf(worst, stalled)
		else:
			stalled = 0.0

	_ok(worst <= STALL_LIMIT, "a chase blocked by a mesa is not spent pushing at it",
		"longest stall %.1fs" % worst)
	_ok(closest < opening * 0.6, "and the group works its way round and closes on the player",
		"closed from %dpx to %dpx" % [int(opening), int(closest)])
	_ok(terrain.is_walkable(subject.global_position), "without walking into the mesa itself")

	for other in bandits:
		if other != subject and is_instance_valid(other):
			other.active = true


## The middle of the nearest rock mass to [param from] within [param reach], or
## [constant Vector2.INF] when there is none - a point the mesh will refuse to
## path to, taken from the map's own ground plan.
func _rock_near(terrain: TerrainShape, from: Vector2, reach: float) -> Vector2:
	var best := Vector2.INF
	var best_distance := reach
	for mass: PackedVector2Array in terrain.masses:
		if mass.size() < 3:
			continue
		var centre := Vector2.ZERO
		for p: Vector2 in mass:
			centre += p
		centre /= float(mass.size())
		if terrain.is_walkable(centre):
			continue
		var distance := from.distance_to(centre)
		if distance < best_distance and distance > 500.0:
			best_distance = distance
			best = centre
	return best


# --- Helpers ------------------------------------------------------------------


func _finish(map: Node) -> void:
	map.free()
	print("")
	if _failures == 0:
		print("WORLD BANDIT NAVIGATION SMOKE: all checks passed")
	else:
		print("WORLD BANDIT NAVIGATION SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label,
		"" if detail.is_empty() else "  -  " + detail])


func _bandits() -> Array[WorldBandit]:
	var found: Array[WorldBandit] = []
	for node: Node in root.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit != null:
			found.append(bandit)
	return found


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / 60.0


## Stands the player on the first sanctuary the map authors - safe ground no
## group will follow them onto. A map with none leaves them exactly where they
## were, which is what every map behaved as before groups chased at all.
func _park_player_safely() -> void:
	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	for node: Node in root.get_tree().get_nodes_in_group(WorldMapSanctuary.GROUP):
		var sanctuary := node as WorldMapSanctuary
		if sanctuary != null and sanctuary.active:
			player.global_position = sanctuary.global_position
			return
