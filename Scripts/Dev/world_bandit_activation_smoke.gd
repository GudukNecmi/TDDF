extends SceneTree
## Headless check that World Map bandit AI activation does what it claims -
## and, just as importantly, that it changed nothing else about a group.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_bandit_activation_smoke.gd
## [/codeblock]
##
## It builds the Dust Camp map for real - the same scene the router changes
## to - and then walks the player across it, asking after every leg the
## questions the optimisation actually has to answer: that far groups fall
## dormant, that near ones are awake, that a dormant group keeps walking its
## route rather than freezing, that riding up to one wakes it before it could
## ever have needed to see the player, that a group reacting to the player is
## never put to sleep underneath its reaction, and that no group is lost,
## reset or moved by any of it. Prints a line per check and exits non-zero on
## the first failure, so it is usable from a script.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame
	await physics_frame

	var director := WorldBanditActivationDirector.get_active(map)
	var bandits := _bandits()
	var player := _player()

	_ok(director != null, "activation director is in the map")
	_ok(not bandits.is_empty(), "map has bandit groups", "%d found" % bandits.size())
	_ok(player != null, "player is in the map")
	if director == null or bandits.is_empty() or player == null:
		_finish(map)
		return

	await _settle()

	await _check_partition(director, bandits, player)
	await _check_dormant_still_walks(director, bandits, player)
	await _check_waking(map, director, bandits, player)
	await _check_reaction_is_never_slept(director, bandits, player)
	await _check_population_intact(director, bandits)

	_finish(map)


func _finish(map: Node) -> void:
	map.free()
	print("")
	if _failures == 0:
		print("BANDIT ACTIVATION SMOKE: all checks passed")
	else:
		print("BANDIT ACTIVATION SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label, "" if detail.is_empty() else "  -  " + detail])


# --- The checks --------------------------------------------------------------


## Every group past the sleep radius is dormant and every group inside the
## wake radius is awake - the partition the whole optimisation rests on.
func _check_partition(
		director: WorldBanditActivationDirector,
		bandits: Array[WorldBandit],
		player: Node2D) -> void:
	var wrong_awake := 0
	var wrong_asleep := 0
	var awake := 0
	for bandit in bandits:
		var distance := bandit.global_position.distance_to(player.global_position)
		var is_awake := bandit.activation_level == WorldBandit.ActivationLevel.ACTIVE
		if is_awake:
			awake += 1
		if is_awake and distance > director.sleep_radius and bandit.can_sleep():
			wrong_awake += 1
		if not is_awake and distance < director.activate_radius:
			wrong_asleep += 1

	_ok(wrong_awake == 0, "far groups are dormant", "%d still awake past %dpx" % [
		wrong_awake, int(director.sleep_radius)])
	_ok(wrong_asleep == 0, "near groups are awake", "%d asleep inside %dpx" % [
		wrong_asleep, int(director.activate_radius)])
	_ok(awake < bandits.size(), "the sweep actually saves work", "%d of %d awake" % [
		awake, bandits.size()])
	_ok(director.get_group_count() == bandits.size(), "director sees every group", "%d of %d" % [
		director.get_group_count(), bandits.size()])


## A dormant group is lightweight, not frozen: it keeps advancing along its
## own route, and at the same average speed a full-rate group would.
##
## Measured as the ground it actually covers rather than as how far it ends up
## from where it started. The two were the same thing when every route was a
## long open road; a group working a camp's own ring can walk most of a leg
## and round a corner inside the same two seconds, which leaves it barely any
## further from its starting point while having walked exactly as far as it
## should. Ground covered is what "keeps walking its route" means, and it
## brackets the speed from both sides: a frozen group covers nothing, and a
## group taking coarse steps that overshoot would cover more than its own
## pace allows.
func _check_dormant_still_walks(
		director: WorldBanditActivationDirector,
		bandits: Array[WorldBandit],
		player: Node2D) -> void:
	var sleeper: WorldBandit = null
	for bandit in bandits:
		if bandit.activation_level == WorldBandit.ActivationLevel.DORMANT \
				and bandit.movement_speed > 0.0:
			sleeper = bandit
			break
	if sleeper == null:
		_ok(false, "a dormant group was available to watch")
		return

	var start_state := sleeper.behavior_state
	var seconds := 2.0
	var walked := 0.0
	var last := sleeper.global_position
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		walked += last.distance_to(sleeper.global_position)
		last = sleeper.global_position
		elapsed += 1.0 / 60.0

	# Its patrol pace, not its top speed - the same multiplier the group
	# itself walks a route at.
	var pace := sleeper.movement_speed * sleeper.roam_speed_multiplier
	_ok(walked > pace * seconds * 0.5, "a dormant group keeps walking its route",
		"%dpx of ground in %.0fs at a %dpx/s pace" % [int(walked), seconds, int(pace)])
	_ok(walked <= pace * seconds * 1.1, "a dormant group does not outrun its own speed",
		"%dpx of ground in %.0fs at a %dpx/s pace" % [int(walked), seconds, int(pace)])
	_ok(sleeper.behavior_state == start_state, "a dormant group keeps its behaviour",
		sleeper.get_state_name())
	_ok(sleeper.active, "a dormant group is not stood down")
	_ok(is_instance_valid(sleeper) and sleeper.is_inside_tree(),
		"a dormant group is still in the tree")


## Riding up to a dormant group wakes it, and wakes it with thousands of
## pixels to spare over the distance at which it could first see the player.
func _check_waking(
		map: Node,
		director: WorldBanditActivationDirector,
		bandits: Array[WorldBandit],
		player: Node2D) -> void:
	var sleeper: WorldBandit = null
	for bandit in bandits:
		if bandit.activation_level == WorldBandit.ActivationLevel.DORMANT:
			sleeper = bandit
			break
	if sleeper == null:
		_ok(false, "a dormant group was available to ride at")
		return

	# Put the player a whisker inside the wake radius, then give the sweep a
	# full pass to reach this group.
	var toward := sleeper.global_position.direction_to(player.global_position)
	player.global_position = sleeper.global_position + toward * (director.activate_radius - 50.0)
	await _sweep_passes(director, bandits, 2)

	_ok(sleeper.activation_level == WorldBandit.ActivationLevel.ACTIVE,
		"riding into range wakes a group",
		"%dpx away" % int(sleeper.global_position.distance_to(player.global_position)))
	_ok(director.activate_radius > sleeper.detection_radius * 2.0,
		"a group wakes long before it could see the player",
		"wake %dpx vs sight %dpx" % [
			int(director.activate_radius), int(sleeper.detection_radius)])

	# And riding back out returns it to the lightweight state.
	player.global_position = sleeper.global_position + toward * (director.sleep_radius + 400.0)
	await _sweep_passes(director, bandits, 2)
	_ok(sleeper.activation_level == WorldBandit.ActivationLevel.DORMANT,
		"riding back out returns it to the lightweight state")


## A group reacting to the player is never put to sleep underneath its own
## reaction, however far away the director thinks it is.
func _check_reaction_is_never_slept(
		director: WorldBanditActivationDirector,
		bandits: Array[WorldBandit],
		player: Node2D) -> void:
	var subject := bandits[0]
	# Park the player on the far side of the map, so the sweep would sleep
	# this group on every single tick if it were allowed to.
	player.global_position = subject.global_position + Vector2(9000.0, 9000.0)
	subject.begin_ambush(player.global_position)
	await _sweep_passes(director, bandits, 2)

	_ok(subject.behavior_state == WorldBandit.BehaviorState.CHASE,
		"an ordered chase starts", subject.get_state_name())
	_ok(subject.activation_level == WorldBandit.ActivationLevel.ACTIVE,
		"a chasing group is never put to sleep")
	_ok(not subject.can_sleep(), "a chasing group reports that it cannot sleep")

	subject.end_ambush()
	_ok(subject.behavior_state == WorldBandit.BehaviorState.PATROL,
		"ending the chase returns it to patrol", subject.get_state_name())
	await _sweep_passes(director, bandits, 2)
	_ok(subject.activation_level == WorldBandit.ActivationLevel.DORMANT,
		"and it then falls back to the lightweight state")


## Nothing above removed, replaced or duplicated a group.
func _check_population_intact(
		director: WorldBanditActivationDirector,
		bandits: Array[WorldBandit]) -> void:
	var still_here := 0
	for bandit in bandits:
		if is_instance_valid(bandit) and bandit.is_inside_tree():
			still_here += 1
	_ok(still_here == bandits.size(), "every group survived activation changes",
		"%d of %d" % [still_here, bandits.size()])
	_ok(_bandits().size() == bandits.size(), "no group was added either",
		"%d now, %d before" % [_bandits().size(), bandits.size()])
	_ok(director.get_awake_count() <= director.get_group_count(),
		"the director's tally is sane", "%d/%d" % [
			director.get_awake_count(), director.get_group_count()])


# --- Helpers -----------------------------------------------------------------


func _bandits() -> Array[WorldBandit]:
	var found: Array[WorldBandit] = []
	for node: Node in root.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit != null:
			found.append(bandit)
	return found


func _player() -> Node2D:
	return root.get_tree().get_first_node_in_group(&"player") as Node2D


## Long enough for the director to have completed a full pass over every
## group [param passes] times over, whatever its slice size is.
func _sweep_passes(
		director: WorldBanditActivationDirector,
		bandits: Array[WorldBandit],
		passes: int) -> void:
	var slice := bandits.size() if director.max_groups_per_tick <= 0 \
		else director.max_groups_per_tick
	var ticks := int(ceil(float(bandits.size()) / float(maxi(slice, 1)))) + 1
	await _wait(director.update_interval * float(ticks * passes) + 0.1)


## Settles the map for a moment so every group has taken its first AI tick
## and the director has swept at least once.
func _settle() -> void:
	await _wait(1.0)


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / 60.0
