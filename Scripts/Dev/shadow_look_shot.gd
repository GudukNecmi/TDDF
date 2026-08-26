extends Node2D
## Takes pictures of the real Desert so the shadows can be looked at rather than
## only measured, and quits.
##
## Every check in [ShadowArchitectureTest] is a number. This is the other half: it
## loads [code]World.tscn[/code], stands a few things next to the player, and saves
## one frame per case to disk - the same hour with the player facing right and then
## left, so the two can be laid side by side, and a later hour so the day is seen
## to move the light rather than the player moving it.
##
## Run it windowed - it needs a renderer:
## [code]godot --path . res://Scenes/Dev/ShadowLookShot.tscn[/code]

@export var world_scene: PackedScene
@export var enemy_scene: PackedScene
@export var cactus_scene: PackedScene
@export var revolver_scene: PackedScene
## Where the frames are written. One PNG per case, named after it.
@export_dir var out_dir: String = "user://"

## The middle of the arena floor. The run itself starts the player standing in the
## Base, which is 8000px down the world and lit as an interior, so every shot walks
## them back out here first.
const ARENA := Vector2.ZERO

var _world: Node
var _player: Node2D
var _source: Sprite2D


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
	var caster := _first_caster(_player)
	_source = caster.get_source_sprite() if caster != null else null

	# A little group out on the arena floor, so one frame carries a character, an
	# enemy, a prop and a weapon and the four can be compared against each other.
	var at := ARENA
	_place(enemy_scene, at + Vector2(230.0, -30.0))
	_place(cactus_scene, at + Vector2(-230.0, 10.0))
	_place(cactus_scene, at + Vector2(30.0, 260.0))
	# Three of the same weapon, turned to three very different angles. If the
	# projection were still taking its direction from the source, these three would
	# each throw their shadow a different way; they must not.
	for spin: float in [20.0, 160.0, 285.0]:
		var revolver := _place(revolver_scene,
			at + Vector2(-260.0 + spin, -190.0))
		if revolver != null:
			revolver.rotation = deg_to_rad(spin)

	await _shoot(&"morning", false, "1_morning_facing_right")
	await _shoot(&"morning", true, "2_morning_facing_left")
	await _shoot(&"evening", false, "3_evening_facing_right")
	await _shoot(&"noon", false, "4_noon_facing_right")
	get_tree().quit(0)


## Sets the hour, points the player one way or the other, lets it settle and saves
## the frame.
func _shoot(hour: StringName, face_left: bool, name: String) -> void:
	# The hour is set on the day itself, not on the shadows alone: the ambient light
	# and the shadows have to agree or the picture is a night sky over noon shadows.
	var director := SunController.get_active(self)
	var cycle := get_tree().get_first_node_in_group(&"day_cycle") as DayCycleDirector
	if director != null:
		for i: int in range(director.stages.size()):
			if director.stages[i].stage_name == hour:
				director.snap_to_stage(i)
				if cycle != null and cycle.stages.size() == director.stages.size():
					DayCycle.set_stage_index(i, cycle.stages.size())
					cycle.refresh()
				break
	if _source != null:
		_source.flip_h = face_left
	# Walked back out every time: the run keeps putting the player back in the Base
	# while the round has not started.
	_player.global_position = ARENA
	var camera := _player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		# The run's boot pins the camera inside the Base while the round has not
		# started, which is why walking the player out is not enough on its own.
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		camera.release_follow()
		camera.reset_smoothing()
	for _i: int in range(8):
		await get_tree().process_frame
		_player.global_position = ARENA
		if camera != null:
			camera.reset_smoothing()
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join("shadow_%s.png" % name)
	var err := image.save_png(path)
	print("%s -> %s (%d)" % [name, path, err])


func _place(scene: PackedScene, at: Vector2) -> Node2D:
	if scene == null:
		return null
	var node := scene.instantiate() as Node2D
	if node == null:
		return null
	_world.get_node(^"Arena").add_child(node)
	node.global_position = at
	return node


func _first_caster(node: Node) -> ShadowCaster:
	for child: Node in node.get_children():
		var caster := child as ShadowCaster
		if caster != null:
			return caster
	return null
