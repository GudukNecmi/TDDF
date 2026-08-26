extends Node2D
## Stands a crowd of real enemies on the real arena floor and reports what their
## shadows cost, at several crowd sizes, then quits.
##
## [b]It measures three things per tier.[/b] The frame time with the shadows
## running, the frame time with every [ShadowGroup] switched off, and the wall time
## of one full sweep of [method ShadowGroup.update_group] over every group in the
## world. The first two subtract to give the shadows' share of a frame; the third
## says where that share is being spent per object, and does not depend on what
## else the game happens to be doing that frame.
##
## Run it windowed - a headless run draws nothing, and half the cost of a composite
## shadow is the drawing:
## [code]godot --path . res://Scenes/Dev/ShadowStress.tscn[/code]

@export var world_scene: PackedScene
@export var enemy_scene: PackedScene
## The crowd sizes measured, in order. Each tier tops the crowd up to its size
## rather than starting again, so the run is one continuous world.
@export var tiers: Array[int] = [10, 25, 50, 100]
## How many frames each tier is watched for before its numbers are taken.
@export var settle_frames: int = 30
## How many frames each tier is measured over.
@export var sample_frames: int = 90
## How many timed sweeps the per-sweep figure is averaged over.
@export var sweep_samples: int = 24

## The middle of the arena floor. The run itself starts the player in the Base,
## eight thousand pixels down the world, so the crowd is walked out here.
const ARENA := Vector2.ZERO
## How far apart the crowd stands, in pixels.
const SPACING := 150.0

var _world: Node
var _player: Node2D
var _crowd: Array[Node2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = world_scene.instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame

	_player = _world.get_node_or_null(^"Player") as Node2D
	if _player == null:
		push_error("no player")
		get_tree().quit(1)
		return
	_park_player()

	var sun := SunController.get_active(self)
	if sun != null and sun.stages.size() > 1:
		sun.snap_to_stage(1)

	print("shadow stress - %s" % ProjectSettings.get_setting("application/config/name"))
	for size: int in tiers:
		await _measure_tier(size)
	get_tree().quit(0)


## Tops the crowd up to [param size] and prints what that crowd costs.
func _measure_tier(size: int) -> void:
	while _crowd.size() < size:
		_add_enemy(_crowd.size())
	for _i: int in range(settle_frames):
		_park_player()
		await get_tree().process_frame

	var groups := _groups()
	for i: int in range(ShadowGroup.probe.size()):
		ShadowGroup.probe[i] = 0.0
	var lit := await _frame_cost()
	var frames := float(sample_frames)
	print(("   probe/frame: gather %6.1f us  measure+place %6.1f us  parts %7.1f us"
		+ "  (verts %6.1f  submit %6.1f  material %6.1f)  groups %5.1f  rebuilt %5.1f")
		% [ShadowGroup.probe[0] / frames, ShadowGroup.probe[1] / frames,
			ShadowGroup.probe[2] / frames, ShadowGroup.probe[3] / frames,
			ShadowGroup.probe[4] / frames, ShadowGroup.probe[5] / frames,
			ShadowGroup.probe[6] / frames, ShadowGroup.probe[7] / frames])

	# Drawn but not updated: every shadow still on the floor, nothing recalculated.
	# What this costs over the dark run is the renderer's share - the triangles and
	# the composites - and what the lit run costs over it is the system's own.
	_set_groups_ticking(groups, false)
	for _i: int in range(8):
		await get_tree().process_frame
	var frozen := await _frame_cost()
	_set_groups_ticking(groups, true)

	_set_groups_enabled(groups, false)
	for _i: int in range(8):
		await get_tree().process_frame
	var dark := await _frame_cost()
	_set_groups_enabled(groups, true)
	for _i: int in range(8):
		await get_tree().process_frame

	# Enemies come and go while the tier is being watched, so the list is taken
	# again rather than trusted.
	groups = _groups()
	var idle := _sweep_cost(groups, false)
	var rebuilt := _sweep_cost(groups, true)
	var casters := 0
	for group: ShadowGroup in groups:
		if is_instance_valid(group):
			casters += group.get_caster_count()

	print("%4d enemies | %3d groups %4d parts | frame %6.2f ms off %6.2f ms"
			% [size, groups.size(), casters, lit, dark]
		+ " | shadows %6.2f ms = draw %6.2f + update %6.2f"
			% [maxf(lit - dark, 0.0), maxf(frozen - dark, 0.0), maxf(lit - frozen, 0.0)]
		+ " | sweep idle %6.1f us rebuild %7.1f us (%5.1f us/group)"
			% [idle, rebuilt, rebuilt / maxf(float(groups.size()), 1.0)])


## The average frame time over [member sample_frames] frames, in milliseconds.
func _frame_cost() -> float:
	var started := Time.get_ticks_usec()
	for _i: int in range(sample_frames):
		_park_player()
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - started) / float(sample_frames) / 1000.0


## The wall time of one full update of every shadow group in the world, in
## microseconds.
##
## [param force] says whether every group is made to rebuild its geometry first.
## Off, the figure is what a world of objects standing still costs - the check that
## finds there is nothing to do. On, it is what a world where absolutely everything
## moved at once costs, which is the worst frame the system can have.
func _sweep_cost(groups: Array[ShadowGroup], force: bool) -> float:
	var started := Time.get_ticks_usec()
	for _i: int in range(sweep_samples):
		for group: ShadowGroup in groups:
			if not is_instance_valid(group):
				continue
			if force:
				group.mark_dirty()
			group.update_group(true)
	return float(Time.get_ticks_usec() - started) / float(sweep_samples)


func _groups() -> Array[ShadowGroup]:
	var found: Array[ShadowGroup] = []
	for node: Node in get_tree().get_nodes_in_group(ShadowGroup.GROUP):
		var group := node as ShadowGroup
		if group != null and group.is_inside_tree():
			found.append(group)
	return found


func _set_groups_enabled(groups: Array[ShadowGroup], on: bool) -> void:
	for group: ShadowGroup in groups:
		if is_instance_valid(group):
			group.enabled = on


## Stops the groups recalculating without taking their shadows off the floor, so
## what the renderer costs can be told apart from what the system costs.
func _set_groups_ticking(groups: Array[ShadowGroup], on: bool) -> void:
	for group: ShadowGroup in groups:
		if is_instance_valid(group):
			group.set_process(on)


func _add_enemy(index: int) -> void:
	var body := enemy_scene.instantiate() as Node2D
	if body == null:
		return
	_world.get_node(^"Arena").add_child(body)
	# A block of rows, walked out around the middle of the floor.
	var columns := 10
	@warning_ignore("integer_division")
	var row := index / columns
	var column := index % columns
	body.global_position = ARENA + Vector2(
		(float(column) - 4.5) * SPACING, (float(row) - 2.0) * SPACING - 40.0)
	_crowd.append(body)


## The run keeps putting the player back in the Base while the round has not
## started, so the crowd would be left alone on an empty floor. Held out here.
func _park_player() -> void:
	if not is_instance_valid(_player):
		return
	_player.global_position = ARENA
	var camera := _player.get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.release_follow()
	camera.reset_smoothing()
