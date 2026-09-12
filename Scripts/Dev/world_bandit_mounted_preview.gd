extends SceneTree
## Photographs a mounted bandit group swinging right round on the real Dust
## Camp, so the turn can be looked at rather than only measured by
## [code]world_bandit_mounted_smoke.gd[/code].
##
## Run with (no [code]--headless[/code]: it has to actually draw):
## [codeblock]
## godot --path . --script res://Scripts/Dev/world_bandit_mounted_preview.gd
## [/codeblock]
##
## Writes [code]user://world_bandit_turn_<n>.png[/code] across the turn: the
## group riding straight, three frames through the swing, and the block formed
## up again on the new heading.
##
## [b]The group is walked by hand and every other one is stood down.[/b] The
## camera follows the player, so the player has to stand next to the group being
## looked at - and a group that spotted them there would ride them down and open
## an encounter over the top of the picture. So the subject's own AI is off and
## [method WorldBandit._move_along_heading] is called directly, which is the
## same walk [method WorldBandit._simulate] makes and no other.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const SETTLE_FRAMES := 150
## How far the camera's own player stands off the group, in pixels - inside
## [member WorldMapFog.visibility_radius], or the group is fogged out of its own
## photograph and its horses stop animating with it.
const WATCH_FROM := 380.0
## How long the group rides each way, in seconds.
const STRAIGHT_SECONDS := 1.5
const TURN_SECONDS := 3.0
## Where the world clock is wound to for the photographs - the middle of NOON,
## see [member WorldTimeManager.period_boundaries].
const DAYLIGHT_DEGREE := 150

var _map: Node
var _player: Node2D
var _subject: WorldBandit
var _shot: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_map = load(MAP_PATH).instantiate()
	root.add_child(_map)
	for i in SETTLE_FRAMES:
		await process_frame

	_player = get_first_node_in_group(&"player") as Node2D
	for node: Node in get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit == null:
			continue
		bandit.active = false
		if _subject == null and bandit.get_visible_bandit_count() >= 3:
			_subject = bandit
	if _subject == null or _player == null:
		push_error("no group of three or more, or no player")
		quit(1)
		return

	_subject.uses_navigation = false
	print("watching %s - %d riders at %.0fpx/s"
		% [_subject.name, _subject.get_visible_bandit_count(), _subject.movement_speed])

	# Wound on to full daylight and given the camera time to arrive: the map
	# opens at dawn, and a picture taken then is a black rectangle with a group
	# somewhere in it.
	var clock := root.get_node_or_null(^"/root/WorldClock")
	if clock != null:
		clock.call(&"advance_ticks", DAYLIGHT_DEGREE - int(clock.call(&"get_world_degree")))
	_player.global_position = _subject.global_position + Vector2(0.0, WATCH_FROM)
	for i in 120:
		await process_frame

	await _ride(Vector2.RIGHT, STRAIGHT_SECONDS, 1)
	await _ride(Vector2.LEFT, TURN_SECONDS, 4)
	_report()
	quit(0)


## Walks the group [param toward] for [param seconds], taking [param shots]
## evenly spaced photographs while it does.
func _ride(toward: Vector2, seconds: float, shots: int) -> void:
	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	var frames := int(seconds * float(Engine.physics_ticks_per_second))
	var every := maxi(frames / maxi(shots, 1), 1)
	for i in frames:
		var target := _subject.global_position + toward * 4000.0
		# The same four calls [method WorldBandit._simulate] makes in this
		# order, minus the AI tick that would send the group after the player
		# standing next to it.
		_subject._update_fog_visibility()
		_subject._move_along_heading(target, step)
		_subject._update_formation_heading(step)
		_subject._rebuild_rider_horses()
		_subject._place_rider_horses()
		# Kept beside the group rather than in front of it, so the camera holds
		# the whole block in shot without the player ever being in its way.
		_player.global_position = _subject.global_position + Vector2(0.0, WATCH_FROM)
		await physics_frame
		if i % every == 0:
			await _photograph()


func _photograph() -> void:
	await process_frame
	await process_frame
	_shot += 1
	var path := "user://world_bandit_turn_%d.png" % _shot
	root.get_texture().get_image().save_png(path)
	print("  wrote %s" % ProjectSettings.globalize_path(path))


## Where the riders ended up relative to the leader, in the group's own frame -
## across its heading and behind it - so the block can be read as numbers beside
## the pictures.
func _report() -> void:
	var heading := _subject._movement_heading
	print("formed up on heading (%.2f, %.2f):" % [heading.x, heading.y])
	for box: Sprite2D in _subject._formation_boxes:
		print("  rider %5.0fpx across, %5.0fpx behind"
			% [box.position.dot(heading.orthogonal()), -box.position.dot(heading)])
	for horse: HorseRig in _subject._rider_horses:
		print("  horse facing %s at %.1f strides/s (drawn %s)"
			% ["right" if horse.facing > 0.0 else "left", horse.get_cycles_per_second(),
				horse.is_visible_in_tree()])
