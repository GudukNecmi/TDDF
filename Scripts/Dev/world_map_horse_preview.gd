extends SceneTree
## Rides the real World Map and photographs it, so the horse system can be
## looked at in the place it actually plays rather than on a blank background.
##
## Run with (no [code]--headless[/code]: it has to actually draw):
## [codeblock]
## godot --path . --script res://Scripts/Dev/world_map_horse_preview.gd
## [/codeblock]
##
## Writes [code]user://horse_map_<name>.png[/code] - the player standing, the
## player at a gallop, and a bandit group's own riders alongside them.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
## Long enough for the map's staged prop spawning to finish and for the fog to
## open up around wherever the player has been put.
const SETTLE_FRAMES := 150

var _map: Node
var _player: Node2D
var _horse: WorldMapHorse


func _initialize() -> void:
	_run()


func _run() -> void:
	_map = load(MAP_PATH).instantiate()
	root.add_child(_map)
	for i in SETTLE_FRAMES:
		await process_frame

	_player = get_first_node_in_group(&"player") as Node2D
	if _player == null:
		push_error("no player on the map")
		quit(1)
		return
	_horse = _player.get_node_or_null("WorldMapHorse") as WorldMapHorse

	await _shot("standing")
	await _ride(&"move_left", 2.0)
	await _shot("gallop_left")
	await _ride(&"move_right", 2.0)
	await _shot("gallop_right")

	# The long ride: the gallop must still be running at the end of it.
	await _ride_and_watch(&"move_left", 20.0)
	await _shot("gallop_sustained")

	await _ride_to_bandits()
	await _shot("bandits")
	quit(0)


## Rides the player across the map by holding the game's own movement action, so
## the player is moved by [code]player.gd[/code] in physics exactly as a person
## playing would move them - never by this script writing a position, which is
## not how anything in the game travels and would hide a rig that reads the
## travel on the wrong clock.
func _ride(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += root.get_physics_process_delta_time()
	Input.action_release(action)


## Rides for a good long while, watching the horse's own stride rate the whole
## time - the check that the gallop does not wind itself down partway through.
func _ride_and_watch(action: StringName, seconds: float) -> void:
	var rig := _player.get_node_or_null("MountedHorse") as HorseRig
	Input.action_press(action)
	var elapsed := 0.0
	var lowest := INF
	var highest := 0.0
	var settle := 1.5
	var last := _player.global_position
	# A rate that falls while the player is genuinely still moving is the bug; a
	# rate that falls because the player has been stopped by a wall or a mesa is
	# the horse doing exactly what it should, so both are watched together and
	# the moment they disagree is reported.
	var worst_stride_while_moving := INF
	while elapsed < seconds:
		await physics_frame
		var step := root.get_physics_process_delta_time()
		elapsed += step
		var travelled := _player.global_position.distance_to(last) / maxf(step, 0.0001)
		last = _player.global_position
		if rig == null or elapsed <= settle:
			continue
		var rate := rig.get_cycles_per_second()
		lowest = minf(lowest, rate)
		highest = maxf(highest, rate)
		if travelled > 20.0:
			worst_stride_while_moving = minf(worst_stride_while_moving, rate)
	Input.action_release(action)
	print("rode %.0fs holding %s: stride rate %.2f..%.2f /s, worst while genuinely moving %.2f /s"
		% [seconds, action, lowest, highest, worst_stride_while_moving])


## Puts the player down beside the nearest bandit group and waits for the fog to
## open and its horses to be built.
func _ride_to_bandits() -> void:
	var nearest: Node2D = null
	var best := INF
	for node in get_nodes_in_group(&"world_bandit"):
		var bandit := node as Node2D
		if bandit == null:
			continue
		var distance := bandit.global_position.distance_to(_player.global_position)
		if distance < best:
			best = distance
			nearest = bandit
	if nearest == null:
		return
	for i in SETTLE_FRAMES:
		_player.global_position = nearest.global_position + Vector2(260.0, 30.0)
		await physics_frame
	var horses := 0
	for child in nearest.get_children():
		if child is HorseRig:
			horses += 1
	print("group visible=%s horses=%d at %s (player %s)"
		% [nearest.visible, horses, nearest.global_position, _player.global_position])


func _shot(name: String) -> void:
	if _horse != null and not _horse.is_mounted():
		_horse.set_mounted(true)
	await process_frame
	await process_frame
	var path := "user://horse_map_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("wrote %s" % ProjectSettings.globalize_path(path))
