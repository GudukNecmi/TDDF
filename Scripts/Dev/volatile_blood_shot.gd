extends SceneTree
## Renders the VOLATILE BLOOD blob and its burst to images, for a look without
## playing - the blob idling on sand, then the
## burst a few frames in.
##
## Run with (not headless - it needs a renderer):
## [codeblock]
## godot --path . --script res://Scripts/Dev/volatile_blood_shot.gd -- <out_dir>
## [/codeblock]

func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "user://"
	await process_frame
	var def := (root.get_node(^"RunSession") as RunSessionState).get_weapon_catalog().find(&"shotgun")
	var part: VolatileBlood = null
	for legendary: WeaponLegendary in def.legendaries:
		if legendary.id == &"volatile_blood":
			part = legendary.kill_reward as VolatileBlood
	root.size = Vector2i(480, 270)
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var ground := ColorRect.new()
	ground.color = Color(0.72, 0.58, 0.4)
	ground.size = Vector2(2000, 2000)
	ground.position = Vector2(-1000, -1000)
	ground.z_index = -10
	arena.add_child(ground)
	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	arena.add_child(camera)
	camera.make_current()

	var bag := part.bag_scene.instantiate() as BloodBag
	bag.setup(part, def.get_stats(), Vector2(-20, 20))
	arena.add_child(bag)
	for i in 30:
		await process_frame
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("blob_a.png"))
	await create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("blob_b.png"))
	bag.trigger(def.get_stats())
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("burst_a.png"))
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("burst_b.png"))
	quit()
