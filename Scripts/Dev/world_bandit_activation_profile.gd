extends SceneTree
## A/B profile of World Map bandit AI activation - what the optimisation
## actually costs and actually saves, measured on the running map rather than
## reasoned about.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_bandit_activation_profile.gd
## [/codeblock]
##
## It builds the Dust Camp map once and runs it twice: leg A with every group
## forced awake, which is exactly how this map behaved before
## [WorldBanditActivationDirector] existed, and leg B with the director at its
## authored settings. The same map, the same groups, the same player standing
## in the same place - the only difference between the legs is the activation
## level, so the gap between them is the optimisation and nothing else.
##
## [Performance]'s own physics process timer is the measure, sampled every
## physics frame and averaged over the leg after a warm-up the samples throw
## away. A second pass repeats the whole thing over a synthetic crowd of
## cloned groups, so the shape of the saving with population is visible rather
## than guessed at - those clones exist only inside this script and only while
## it runs.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
## Seconds of samples kept per leg, after the warm-up below.
const SAMPLE_SECONDS := 4.0
## Seconds thrown away at the start of each leg, so a leg never measures the
## other leg's last frame or the first path query after a wake.
const WARMUP_SECONDS := 1.5


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame
	await physics_frame

	var director := WorldBanditActivationDirector.get_active(map)
	if director == null:
		print("no WorldBanditActivationDirector in the map - nothing to profile")
		map.free()
		quit(1)
		return

	print("=== World Map bandit AI activation - A/B ===")
	await _profile_population(map, director, 0)
	await _profile_population(map, director, 90)

	map.free()
	quit(0)


## Runs both legs over the map's own groups plus [param extra_clones] more,
## and prints the comparison.
func _profile_population(
		map: Node, director: WorldBanditActivationDirector, extra_clones: int) -> void:
	var clones := await _add_clones(map, extra_clones)
	var total := _bandits().size()
	print("")
	print("-- %d groups%s --" % [total, "" if clones.is_empty() else " (%d of them cloned for this measurement)" % clones.size()])

	# Leg A: every group awake every frame - the behaviour before the director.
	director.set_process(false)
	_force_all(WorldBandit.ActivationLevel.ACTIVE)
	var baseline := await _measure()
	print("A  every group awake      : %.3f ms/frame physics" % baseline)

	# Leg B: the director at its authored settings.
	director.set_process(true)
	await _wait(director.update_interval * float(total) + 0.5)
	var awake := _awake_count()
	var optimised := await _measure()
	print("B  activation director on : %.3f ms/frame physics  (%d of %d awake)" % [
		optimised, awake, total])

	var saved := baseline - optimised
	var percent := 0.0 if baseline <= 0.0 else saved / baseline * 100.0
	print("   saved                  : %.3f ms/frame  (%.1f%%)" % [saved, percent])

	for clone in clones:
		if is_instance_valid(clone):
			clone.free()


## Average milliseconds of physics processing per frame over one leg.
func _measure() -> float:
	await _wait(WARMUP_SECONDS)
	var total := 0.0
	var samples := 0
	var elapsed := 0.0
	while elapsed < SAMPLE_SECONDS:
		await physics_frame
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		samples += 1
		elapsed += 1.0 / 60.0
	return 0.0 if samples == 0 else total / float(samples) * 1000.0


## Duplicates the map's own groups until [param count] more are standing on
## it, spread across the map so the director has a genuine mix to partition.
## Purely a measuring device: these are freed again at the end of the leg and
## never exist outside this script.
func _add_clones(map: Node, count: int) -> Array[Node]:
	var made: Array[Node] = []
	if count <= 0:
		return made
	var originals := _bandits()
	if originals.is_empty():
		return made

	var parent := originals[0].get_parent()
	for i in count:
		var source := originals[i % originals.size()]
		var clone := source.duplicate() as WorldBandit
		# Never written into WorldMapState - a clone is not a group the world
		# is supposed to remember.
		clone.remembers_across_scenes = false
		clone.name = "ProfileClone%d" % i
		var angle := TAU * float(i) / float(count)
		clone.position = source.position + Vector2.from_angle(angle) * (600.0 + float(i) * 40.0)
		parent.add_child(clone)
		made.append(clone)
	await physics_frame
	return made


func _force_all(level: WorldBandit.ActivationLevel) -> void:
	for bandit in _bandits():
		bandit.set_activation_level(level)


func _awake_count() -> int:
	var awake := 0
	for bandit in _bandits():
		if bandit.activation_level == WorldBandit.ActivationLevel.ACTIVE:
			awake += 1
	return awake


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
