extends SceneTree
## Headless check of the shotgun's Legendary VOLATILE BLOOD: it is listed as a
## Legendary and in no upgrade pool, and DEVIL'S COIN is no longer one; off, a
## shotgun kill leaves no bag; on, it leaves exactly one where the man fell, and so
## does a kill by any round or blast armed from the shotgun's block - a DEVIL'S
## BREATH blast, a HELL CHAMBER round, ONE BIG SHELL's cannon, a BLOOD REAPER chain -
## with no case for any of them; a death no shot caused leaves none; a bag lives its
## Inspector lifetime and fades; walked through it bursts, hurting the enemies in
## reach and nobody out of it, never the player, leaving no scorch; shot by a round
## carrying it, it bursts, while any other round passes; a man the burst kills
## leaves a bag of his own; and the K panel lists it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/volatile_blood_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const PLAYER_SCENE := "res://Scenes/Player/Player.tscn"

var _failures: int = 0
var _arena: Node2D
var _gun: Shotgun
var _def: WeaponDefinition
var _legend: WeaponLegendary
var _part: VolatileBlood


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_def = session.get_weapon_catalog().find(&"shotgun")
	_def.reset_upgrades()

	print("--- the Legendary ---")
	_legend = _legendary(&"volatile_blood")
	_part = null if _legend == null else _legend.kill_reward as VolatileBlood
	_ok(_part != null, "the shotgun lists VOLATILE BLOOD with a Volatile Blood part")
	if _part == null:
		_finish()
		return
	var in_pool := false
	for upgrade: WeaponUpgrade in _def.upgrades:
		in_pool = in_pool or upgrade.id == _legend.id
	_ok(not in_pool, "and not among the upgrades the Base, markets and rewards deal from")
	var coin_legendary := false
	for legendary: WeaponLegendary in _def.legendaries:
		coin_legendary = coin_legendary or legendary.id == &"devils_coin" \
			or legendary.kill_reward is DevilsCoin
	_ok(not coin_legendary, "DEVIL'S COIN is no longer a shotgun Legendary")
	_ok(is_equal_approx(_part.lifetime, 3.0), "a 3 second bag", "%.2f" % _part.lifetime)
	var burst_scene := _part.burst_scene.instantiate() as BloodBurst
	_ok(burst_scene != null and burst_scene.gore_effect == null and not burst_scene.sounds.is_empty()
		and burst_scene.sounds[0] != null, "the burst is a BloodBurst with its sound and no gore scene")
	if burst_scene != null:
		burst_scene.free()

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var view := CameraController.new()
	_arena.add_child(view)
	view.make_current()
	var holder := Node2D.new()
	holder.name = "Holder"
	_arena.add_child(holder)
	_gun = (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	_gun.definition = _def
	_gun.target_path = ^"../Holder"
	_arena.add_child(_gun)
	await process_frame
	var origin := Vector2(3000, 3000)

	print("--- off ---")
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(20)
	_ok(_bags().is_empty(), "a shotgun kill leaves no bag")
	await _clear()

	_def.set_legendary_active(_legend, true)

	print("--- on: a pellet kill ---")
	var man := await _enemy(origin, 1.0)
	var fell := [Vector2.INF]
	(man.get_node(^"Health") as Health).died.connect(func() -> void: fell[0] = man.global_position)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	var bags := _bags()
	_ok(bags.size() == 1, "one kill, exactly one bag", "%d bags" % bags.size())
	_ok(bags.size() == 1 and bags[0].global_position.distance_to(fell[0]) < 0.5, "lying where he fell")
	_ok(BloodBag.count_active(self) == bags.size(), "and counted as live")
	await _clear()

	print("--- not the shotgun's kill ---")
	var killed := await _enemy(origin, 50.0)
	(killed.get_node(^"Health") as Health).kill()
	var removed := await _enemy(origin + Vector2(200, 0), 50.0)
	(removed.get_node(^"Health") as Health).remove()
	var blown := await _enemy(origin + Vector2(400, 0), 50.0)
	(blown.get_node(^"Health") as Health).take_damage(1000.0, Vector2.RIGHT)
	await _frames(4)
	_ok(_bags().is_empty(), "a plain death, a removal and unattributed damage leave none")
	await _clear()

	print("--- other shots armed from the shotgun's block ---")
	var breath := _legendary(&"devils_breath")
	for i in 3:
		await _enemy(origin + Vector2(i * 30.0, 0.0), 1.0)
	breath.shot_explosion.detonate(_arena, origin, _gun.get_stats(), 2)
	await _frames(12)
	_ok(_bags().size() == 3, "a DEVIL'S BREATH blast's kills, one each", "%d" % _bags().size())
	await _clear()

	var chamber := _legendary(&"hell_chamber")
	await _enemy(origin, 1.0)
	_shoot_at(origin, chamber.hell_chamber.charged_stats(_gun.get_stats(), 1.0))
	await _frames(12)
	_ok(_bags().size() == 1, "a charged HELL CHAMBER round's kill", "%d" % _bags().size())
	await _clear()

	var shell := _legendary(&"one_big_shell")
	await _enemy(origin, 1.0)
	_gun._release_pellet(_arena, _gun.get_stats(), false, origin - Vector2(60, 26), 0.0,
		false, null, null, shell.one_big_shell)
	await _frames(20)
	_ok(_bags().size() == 1, "ONE BIG SHELL's cannon kill", "%d" % _bags().size())
	await _clear()

	var reaper := _legendary(&"blood_reaper")
	_def.set_legendary_active(reaper, true)
	await _enemy(origin, 1.0)
	for i in 3:
		await _enemy(origin + Vector2(90.0 + i * 70.0, 0.0), 0.01)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(90)
	_ok(_bags().size() == 4, "a BLOOD REAPER execution and every kill of its chain, none popped by the echoes",
		"%d bags" % _bags().size())
	_def.set_legendary_active(reaper, false)
	await _clear()

	print("--- left alone ---")
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	var left := _bags()
	var sitter := await _enemy(origin + Vector2(10, 0), 1000.0)
	var sitter_health := sitter.get_node(^"Health") as Health
	await create_timer(_part.lifetime * 0.5).timeout
	_ok(left.size() == 1 and is_instance_valid(left[0]) and not (left[0] as BloodBag).is_done(),
		"half way through its life it is still there")
	await create_timer(_part.lifetime * 0.5 + 0.05).timeout
	_ok(left.size() == 1 and is_instance_valid(left[0]) and (left[0] as BloodBag).is_done()
		and BloodBag.count_active(self) == 0 and (left[0] as BloodBag).modulate.a < 1.0,
		"at 3 seconds it can no longer be triggered and is fading")
	await create_timer(_part.fade_duration + 0.2).timeout
	_ok(not is_instance_valid(left[0]), "then it is gone")
	_ok(is_equal_approx(sitter_health.get_current(), 1000.0), "having hurt nobody")
	await _clear()

	print("--- walked through ---")
	var bag := await _drop_bag(origin)
	var near := await _enemy(origin + Vector2(40, 0), 1000.0)
	var far := await _enemy(origin + Vector2(_part.burst_radius + 150.0, 0), 1000.0)
	var walker := Node2D.new()
	walker.add_to_group(&"player")
	_arena.add_child(walker)
	var walker_health := Health.new()
	walker_health.name = "Health"
	walker.add_child(walker_health)
	walker.global_position = origin + Vector2(0, 400)
	await _frames(3)
	_ok(is_instance_valid(bag) and not bag.is_done(), "out of reach it waits")
	var bursts := [0]
	bag.burst.connect(func(_at: Vector2) -> void: bursts[0] += 1)
	var walker_start := walker_health.get_current()
	walker.global_position = origin + Vector2(8, 4)
	await _frames(6)
	_ok(bursts[0] == 1 and (not is_instance_valid(bag) or bag.is_done()), "walked into, it bursts once and is consumed")
	var near_health := near.get_node(^"Health") as Health
	var far_health := far.get_node(^"Health") as Health
	_ok(near_health.get_current() < 1000.0, "hurting the enemy in reach",
		"%.1f dealt" % (1000.0 - near_health.get_current()))
	_ok(is_equal_approx(far_health.get_current(), 1000.0), "and not the one out of reach")
	_ok(is_equal_approx(walker_health.get_current(), walker_start), "and never the player")
	var burst_nodes := 0
	var scorch := 0
	for child: Node in _arena.get_children():
		if child is BloodBurst:
			burst_nodes += 1
		if String(child.name).contains("Explosion") or String(child.name).contains("Mark"):
			scorch += 1
	_ok(burst_nodes == 1 and scorch == 0, "one blood burst, no explosion or scorch mark",
		"%d bursts, %d scorch" % [burst_nodes, scorch])
	walker.queue_free()
	await _clear()

	print("--- the player's own hurtbox ---")
	var player_scene := load(PLAYER_SCENE) as PackedScene
	var state := player_scene.get_state()
	var on_layer := 0
	for i in state.get_node_count():
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"collision_layer" \
					and (int(state.get_node_property_value(i, p)) & _part.hitbox_mask) != 0:
				on_layer += 1
	_ok(on_layer == 0, "nothing on the player sits on the layer the burst hits")

	print("--- shot ---")
	bag = await _drop_bag(origin)
	var plain := WeaponStats.new()
	_gun._release_pellet(_arena, plain, false, origin - Vector2(60, _part.float_base_height), 0.0)
	await _frames(10)
	_ok(is_instance_valid(bag) and not bag.is_done(), "a round not carrying VOLATILE BLOOD passes it by")
	var hurt := await _enemy(origin + Vector2(0, 80), 1000.0)
	_gun._release_pellet(_arena, _gun.get_stats(), false, origin - Vector2(60, _part.float_base_height), 0.0)
	await _frames(10)
	_ok(not is_instance_valid(bag) or bag.is_done(), "a shotgun round bursts it")
	_ok((hurt.get_node(^"Health") as Health).get_current() < 1000.0, "and the burst hurts the enemy beside it")
	await _clear()

	print("--- armed only after its delay ---")
	bag = await _drop_bag(origin, 0)
	_ok(not bag.take_projectile_hit(_fake_round(), origin) and not bag.is_done(),
		"a round reaching it the instant it drops is let through")
	bag.queue_free()
	await _clear()

	print("--- chain ---")
	bag = await _drop_bag(origin)
	var second := await _enemy(origin + Vector2(50, 0), 1.0)
	var second_fell := [Vector2.INF]
	(second.get_node(^"Health") as Health).died.connect(func() -> void: second_fell[0] = second.global_position)
	bag.trigger(_gun.get_stats())
	await _frames(8)
	var chained := _bags()
	_ok(chained.size() == 1 and chained[0].global_position.distance_to(second_fell[0]) < 0.5,
		"a man the burst kills leaves a bag of his own", "%d bags" % chained.size())
	await _clear()

	print("--- the blob ---")
	var shield := RecoilShield.new()
	_ok(is_equal_approx(_part.blob_radius, shield.radius * 0.5),
		"half the RECOIL DEVIL ward's size", "%.1f vs %.1f" % [_part.blob_radius, shield.radius])
	shield.free()
	_ok(is_equal_approx(_part.shot_radius, 17.0), "its shot target is the size it was")
	bag = await _drop_bag(origin)
	var blob := bag.get_node(^"Blob") as Node2D
	var blob_material := blob.material as ShaderMaterial
	_ok(blob_material != null and blob_material.shader.resource_path.ends_with("volatile_blood.gdshader"),
		"drawn by its own Volatile Blood shader")
	var heights: Array[float] = []
	var widths: Array[float] = []
	for i in 40:
		await create_timer(0.03).timeout
		heights.append(blob.position.y)
		widths.append(blob.scale.x)
	var steps: Array[float] = []
	for i in range(1, heights.size()):
		steps.append(absf(heights[i] - heights[i - 1]))
	_ok(heights.max() - heights.min() > 0.3 and heights.max() - heights.min() <= _part.float_height * 2.0 + 0.01
		and heights.max() < 0.0, "it hovers off the ground and bobs, within its float height",
		"%.2f .. %.2f" % [heights.min(), heights.max()])
	_ok(steps.max() < 1.0, "smoothly, with no snap", "largest step %.2f" % steps.max())
	_ok(widths.max() - widths.min() > 0.001, "and squashes as it bobs")
	var idle := bag.get_node(^"IdleSound") as AudioStreamPlayer2D
	_ok(idle.stream != null and idle.playing and (idle.stream as AudioStreamOggVorbis).loop,
		"its quiet loop is playing, looped")
	_ok(is_equal_approx(idle.volume_db, _part.idle_volume_db) and _part.idle_volume_db >= -6.0,
		"faded in to its Inspector level, loud enough to hear", "%.1f dB" % idle.volume_db)
	var burst_look := _part.burst_scene.instantiate() as BloodBurst
	_ok(burst_look.sound_volume_db >= 3.0 and burst_look.sound_volume_db <= 8.0,
		"the burst is heard at a rupture's level, short of a bomb's", "%.1f dB" % burst_look.sound_volume_db)
	burst_look.free()
	var stats_back := _part.globule_count
	_ok(stats_back > 0 and bag._globules.size() == stats_back, "with its globules round it",
		"%d" % bag._globules.size())
	bag.trigger(_gun.get_stats())
	_ok(bag.is_done() and is_instance_valid(bag), "bursting, it tears apart rather than vanishing")
	await create_timer(_part.rupture_time + 0.1).timeout
	_ok(not is_instance_valid(bag), "and is gone once it has torn")
	await _clear()

	var silent_part := _part.duplicate() as VolatileBlood
	silent_part.idle_sound = null
	var silent := silent_part.bag_scene.instantiate() as BloodBag
	silent.setup(silent_part, _gun.get_stats())
	_arena.add_child(silent)
	await _frames(2)
	_ok(not (silent.get_node(^"IdleSound") as AudioStreamPlayer2D).playing, "with no loop set it is simply silent")
	await _clear()

	print("--- the burst ---")
	var look := _part.burst_scene.instantiate() as BloodBurst
	var layers: Array[String] = []
	for path: NodePath in look.burst_paths:
		layers.append(String(path))
	var fire := false
	for node: Node in look.find_children("*", "", true, false):
		var particles := node as CPUParticles2D
		if particles != null and particles.texture != null and particles.texture.resource_path.contains("Boom"):
			fire = true
	_ok(layers.has("Rupture") and layers.has("Chunks") and layers.has("Spray") and layers.has("Mist")
		and not layers.has("Fire") and not layers.has("Smoke") and not fire,
		"rupture, droplets, chunks and mist - no fire, smoke or Boom flare", ", ".join(layers))
	look.free()

	print("--- off again ---")
	_def.set_legendary_active(_legend, false)
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	_ok(_bags().is_empty(), "no new bag")
	await _clear()

	print("--- the K panel ---")
	var listed := false
	for method: Dictionary in (load("res://Scripts/UI/weapon_debug_panel.gd") as Script).get_script_method_list():
		listed = listed or method.get("name") == "_add_kill_reward_row"
	_ok(listed and not _part.describe_debug(self).is_empty(), "the panel has an ON KILL row for it")

	_def.reset_upgrades()
	_finish()


## A bag of this Legendary lying at [param at], [param age] seconds old - past the
## shot arming delay unless told otherwise - credited to the shotgun's block.
func _drop_bag(at: Vector2, age: float = -1.0) -> BloodBag:
	var bag := _part.bag_scene.instantiate() as BloodBag
	var stats := _gun.get_stats()
	bag.setup(_part, stats)
	_arena.add_child(bag)
	bag.global_position = at
	bag._age = _part.shot_arm_delay + 0.05 if age < 0.0 else age
	await _frames(2)
	return bag


func _fake_round() -> Projectile:
	var shot := Projectile.new()
	shot.apply_weapon_stats(_gun.get_stats())
	_arena.add_child(shot)
	shot.set_physics_process(false)
	return shot


func _shoot_at(at: Vector2, stats: WeaponStats) -> void:
	_gun._release_pellet(_arena, stats, false, at - Vector2(60, 26), 0.0)


func _bags() -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _arena.get_children():
		if child is BloodBag and not (child as BloodBag).is_done():
			found.append(child)
	return found


func _legendary(id: StringName) -> WeaponLegendary:
	for legendary: WeaponLegendary in _def.legendaries:
		if legendary.id == id:
			return legendary
	return null


func _enemy(at: Vector2, health: float) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(health)
	await _frames(2)
	return enemy


func _clear() -> void:
	for child: Node in _arena.get_children():
		if child != _gun and child.name != &"Holder" and not child is CameraController:
			child.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("VOLATILE BLOOD SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
