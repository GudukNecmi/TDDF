extends SceneTree
## Headless check that a region's bandit population is spent rather than
## replenished: a group beaten during a run stays gone for the rest of that run
## however many times the region is left and come back to, and once the run has
## ended it is gone from that region for good.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_bandit_population_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on the first failure, the same
## shape [code]world_bandit_navigation_smoke.gd[/code] already follows.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
## Somewhere else entirely, for the "changed region and came back" check - a
## different scene, so returning is a real rebuild rather than a redraw.
const OTHER_MAP_PATH := "res://Scenes/World/Regions/GhostTownMap.tscn"
const REGION := &"A"
const MAP_ID := &"desert"

## How many groups the run beats. The brief's own example.
const DEFEATS := 20

var _failures: int = 0
var _population: BanditPopulationState
var _session: Node
var _state: WorldMapState


func _initialize() -> void:
	_run()


func _run() -> void:
	_population = root.get_node_or_null(^"BanditPopulation") as BanditPopulationState
	_session = root.get_node_or_null(^"RunSession")
	_state = root.get_node_or_null(^"WorldState") as WorldMapState
	_ok(_population != null, "the game carries a bandit population autoload")
	_ok(_session != null and _state != null, "alongside the run session and the world's memory")
	if _population == null or _session == null or _state == null:
		_finish()
		return

	# Every check below is about what one region remembers, so it starts from a
	# world nothing has been done to yet.
	_population.forget_all()
	_state.forget_all()

	var map: Node = await _build(MAP_PATH)
	# The run the losses will belong to. Begun before a single group is beaten,
	# exactly as a real one is, so the tally being cleared as a run starts cannot
	# be mistaken for the tally working. It is begun with a map standing because
	# a session reaches for the world's own nodes as it starts.
	_session.call(&"begin", MAP_ID)


	var authored := _bandits().size()
	_ok(authored > DEFEATS, "the region is built with bandit groups on it",
		"%d groups" % authored)
	_ok(_population.get_starting_population(REGION) == authored,
		"and the region's population is every group its scene authors",
		"population %d" % _population.get_starting_population(REGION))
	if authored <= DEFEATS:
		_finish()
		return

	var beaten := _defeat(DEFEATS)
	_ok(beaten.size() == DEFEATS, "a run beats %d of them" % DEFEATS)
	_ok(_population.get_run_losses(REGION) == DEFEATS,
		"the run's losses are counted against the region",
		"%d lost" % _population.get_run_losses(REGION))
	_ok(_population.get_remaining_population(REGION) == authored - DEFEATS,
		"leaving the region standing at what it had less what it lost",
		"%d of %d" % [_population.get_remaining_population(REGION), authored])
	_ok(_population.get_available_population(REGION) == authored,
		"while the population a run opens on is untouched until this one ends",
		"%d available" % _population.get_available_population(REGION))

	map.free()
	await _check_region_rebuild(authored, beaten, "left the region and came back")
	await _check_other_region(authored, beaten)
	await _check_run_scoped_memory_is_not_what_keeps_them_gone(authored, beaten)
	await _check_run_end(authored, beaten)

	_finish()


## Riding out of a region and back into it is a full rebuild of its scene - see
## [WorldMapState] - and none of the groups beaten in this run may stand up in
## it.
func _check_region_rebuild(authored: int, beaten: Array[StringName], how: String) -> void:
	var map: Node = await _build(MAP_PATH)
	var standing := _bandits()
	_ok(standing.size() == authored - beaten.size(),
		"%s: the groups it beat are not standing there" % how,
		"%d groups, was %d" % [standing.size(), authored])

	var returned: Array[StringName] = []
	for bandit: WorldBandit in standing:
		if beaten.has(bandit.name):
			returned.append(bandit.name)
	_ok(returned.is_empty(), "and it is the very groups it beat that are missing",
		"" if returned.is_empty() else "%d came back: %s" % [returned.size(), returned[0]])
	_ok(_population.get_starting_population(REGION) == authored,
		"while the region's own total is still what it was authored with",
		"%d" % _population.get_starting_population(REGION))
	map.free()


## Going to another region entirely and coming back is the same rebuild, made
## from a different scene - so nothing about the first check can be a scene that
## was never really freed.
func _check_other_region(authored: int, beaten: Array[StringName]) -> void:
	var other: Node = await _build(OTHER_MAP_PATH)
	_ok(other != null, "another region can be ridden to")
	if other != null:
		other.free()
	await _check_region_rebuild(authored, beaten, "changed region and came back")


## The run's own memory of the region - where each group had walked to, and the
## note that says one was beaten - is meant to be thrown away when a run ends.
## Throwing it away here proves the population is what actually keeps a beaten
## group down, rather than that note surviving by accident.
func _check_run_scoped_memory_is_not_what_keeps_them_gone(
		authored: int, beaten: Array[StringName]) -> void:
	_state.forget_all()
	await _check_region_rebuild(authored, beaten, "the run's own memory cleared")


## The run ends the way every run does - the session is told, at the moment the
## player is home - and that is what takes the losses off the region for good.
func _check_run_end(authored: int, beaten: Array[StringName]) -> void:
	_session.call(&"end")
	_ok(_population.get_available_population(REGION) == authored - beaten.size(),
		"the run ending takes its losses off the region for good",
		"%d of %d available" % [
			_population.get_available_population(REGION), authored])
	_ok(_population.get_run_losses(REGION) == 0,
		"and the run's own tally is spent")
	_ok(_population.get_permanent_losses(REGION) == beaten.size(),
		"%d groups are gone permanently" % beaten.size(),
		"%d" % _population.get_permanent_losses(REGION))

	# The next run, opened on a world remembering nothing - which is what a run
	# beginning is meant to leave behind.
	_state.forget_all()
	_session.call(&"begin", MAP_ID)
	var map: Node = await _build(MAP_PATH)
	var standing := _bandits()
	_ok(standing.size() == authored - beaten.size(),
		"a later run opens on the reduced region",
		"%d groups, was %d" % [standing.size(), authored])
	_ok(_population.get_remaining_population(REGION) == standing.size(),
		"and the region's own count agrees with what is standing on it",
		"%d" % _population.get_remaining_population(REGION))

	# One more, beaten in this second run, to show the reduction accumulates
	# rather than being replaced by the latest run's losses.
	var again := _defeat(1)
	_session.call(&"end")
	_ok(_population.get_available_population(REGION) == authored - beaten.size() - again.size(),
		"a second run's losses come off what the first one left",
		"%d of %d" % [_population.get_available_population(REGION), authored])
	map.free()


# --- Helpers ------------------------------------------------------------------


## Beats [param count] of the groups standing on the map, through the very call
## [WorldMapCombatBridge] makes as it takes a fight to an arena, and answers
## which ones they were.
func _defeat(count: int) -> Array[StringName]:
	var beaten: Array[StringName] = []
	for bandit: WorldBandit in _bandits():
		if beaten.size() >= count:
			break
		beaten.append(bandit.name)
		bandit.mark_defeated()
	return beaten


func _build(path: String) -> Node:
	var map: Node = load(path).instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	return map


func _bandits() -> Array[WorldBandit]:
	var found: Array[WorldBandit] = []
	for node: Node in root.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit != null and not bandit.is_queued_for_deletion():
			found.append(bandit)
	return found


func _finish() -> void:
	print("")
	if _failures == 0:
		print("WORLD BANDIT POPULATION SMOKE: all checks passed")
	else:
		print("WORLD BANDIT POPULATION SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label,
		"" if detail.is_empty() else "  -  " + detail])
