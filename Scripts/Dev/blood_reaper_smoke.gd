extends SceneTree
## Headless check of the shotgun's Legendary BLOOD REAPER: it is listed as a
## Legendary and in no upgrade pool; off, a pellet kill is the ordinary head-pop;
## on, the kill executes the man through the gore once, and his death fires one
## volley of one round per live pellet, at the nearest distinct enemies, never at
## him, at 10% power - damage, knockback, stagger and any DEVIL'S BREATH blast's
## damage, radius, shove and camera kick; the volley's kills reap again, each
## death once; and the K panel lists it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/blood_reaper_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"

var _failures: int = 0
var _arena: Node2D
var _gun: Shotgun
var _def: WeaponDefinition
var _reaper: WeaponLegendary
var _reaps: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_def = session.get_weapon_catalog().find(&"shotgun")
	_def.reset_upgrades()

	print("--- the Legendary ---")
	_reaper = _legendary(&"blood_reaper")
	_ok(_reaper != null and _reaper.blood_reaper != null, "the shotgun lists BLOOD REAPER with a reaper part")
	if _reaper == null:
		_finish()
		return
	var in_pool := false
	for upgrade: WeaponUpgrade in _def.upgrades:
		in_pool = in_pool or upgrade.id == _reaper.id
	_ok(not in_pool, "and not among the upgrades the Base, markets and rewards deal from")
	_ok(is_equal_approx(_reaper.blood_reaper.blood_reaper_power_multiplier, 0.1), "at 10% power by default")

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
	_gun.reaped.connect(func(at: Vector2, rounds: int) -> void: _reaps.append([at, rounds, _volley_rounds(), _volley_targets()]))
	await process_frame
	var origin := Vector2(3000, 3000)

	print("--- off: an ordinary kill ---")
	var plain := await _enemy(origin, 1.0)
	var plain_deaths := _count_deaths(plain)
	_shoot_at(origin)
	await _frames(20)
	_ok(plain_deaths[0] == 1 and _reaps.is_empty(), "the kill kills and reaps nothing")
	_ok(_nodes(Explosion).is_empty() and _head_pops() > 0, "with the ordinary head-pop")
	await _clear()

	print("--- on: the execution and its volley ---")
	_def.set_legendary_active(_reaper, true)
	var victim := await _enemy(origin, 1.0)
	var victim_deaths := _count_deaths(victim)
	var crowd: Array[Node2D] = []
	for i in 8:
		crowd.append(await _enemy(origin + Vector2.from_angle(TAU * i / 8.0) * (120.0 + i * 20.0), 1000000.0))
	_shoot_at(origin)
	await _frames(12)
	_ok(victim_deaths[0] == 1, "the kill kills him once")
	_ok(_nodes(Explosion).size() == 1 and _head_pops() == 0, "executed into the gore, not the head-pop")
	var gore := _nodes(Explosion)
	_ok(gore.size() == 1 and gore[0].scene_file_path.ends_with("BloodReaperGore.tscn")
		and _gore_pieces() >= (gore[0] as Explosion).gore_count.x,
		"into its own heavier gore burst", "%d pieces" % _gore_pieces())
	_ok(_blasts().is_empty() and not _bomb_look_shown(), "and never a bomb: no Boom, flash, smoke or scorch")
	var sprays := 0
	for child: Node in _arena.get_children():
		if child is CPUParticles2D and child.name.begins_with("BloodReaperSpray"):
			sprays += 1
	_ok(sprays == 1, "with one heavy blood spray thrown where he came apart")
	_ok(_reaps.size() == 1, "one volley for one execution", str(_reaps.size()))
	var volley: Array = [] if _reaps.is_empty() else _reaps[0][2]
	_ok(_reaps.size() == 1 and _reaps[0][1] == _gun.get_pellet_count() and volley.size() == _gun.get_pellet_count(),
		"one round per live pellet", "%d rounds" % volley.size())
	var targets: Array = [] if _reaps.is_empty() else _reaps[0][3]
	var nearest := EnemyTargeting.nearest_many(_gun, _reaps[0][0] if not _reaps.is_empty() else origin, 6)
	var all_nearest := targets.size() == 6
	for enemy: Node2D in nearest:
		all_nearest = all_nearest and targets.has(enemy)
	_ok(all_nearest, "each goes for its own enemy, the six nearest", "%d distinct" % targets.size())
	_ok(not targets.has(victim), "never the executed man")

	print("--- power ---")
	var live := _gun.get_stats()
	var ordinary := _armed(live)
	var reaped := _armed(_reaper.blood_reaper.reaper_stats(live))
	_ok(is_equal_approx(reaped.damage_at_progress(0.0), ordinary.damage_at_progress(0.0) * 0.1),
		"a volley round hits for 10%", "%.2f vs %.2f" % [reaped.damage_at_progress(0.0), ordinary.damage_at_progress(0.0)])
	_ok(is_equal_approx(reaped._hit_effects.knockback_scale, ordinary._hit_effects.knockback_scale * 0.1)
		and is_equal_approx(reaped._hit_effects.stagger_scale, ordinary._hit_effects.stagger_scale * 0.1),
		"and shoves and staggers at 10%")
	ordinary.free()
	reaped.free()
	await _clear()

	print("--- the fired shot, BLOOD PUMP charge and all ---")
	var pump := _legendary(&"blood_pump")
	_def.set_legendary_active(pump, true)
	_gun._set_charge(_gun.get_max_pump_charge())
	var charged := _gun._shot_stats()
	_reaps.clear()
	await _enemy(origin, 1.0)
	for i in 3:
		await _enemy(origin + Vector2(220.0 + i * 60.0, 180.0), 1000000.0)
	_shoot_at(origin)
	# Spent with the shot, exactly as firing spends it, before the man comes apart.
	_gun._set_charge(0)
	await _frames(12)
	var pumped: Array = [] if _reaps.is_empty() else _reaps[0][2]
	var inherits := not pumped.is_empty()
	for shot: Projectile in pumped:
		inherits = inherits and is_equal_approx(shot._stats.damage_scale_at(0.0), charged.damage_scale_at(0.0)) \
			and shot._stats.pierce_bonus() == charged.pierce_bonus() \
			and is_equal_approx(shot._stats.range_scale(), charged.range_scale()) \
			and is_equal_approx(shot._stats.power_scale, 0.1)
	_ok(inherits and charged.damage_scale_at(0.0) > _gun._shot_stats().damage_scale_at(0.0),
		"the volley carries the full charge the killing shot left with, at 10%",
		"%.2f charged vs %.2f idle" % [charged.damage_scale_at(0.0), _gun._shot_stats().damage_scale_at(0.0)])
	_def.set_legendary_active(pump, false)
	await _clear()

	print("--- pellet count upgrades ---")
	var pellet_upgrade: WeaponUpgrade = null
	for upgrade: WeaponUpgrade in _def.upgrades:
		if upgrade.resource_path.contains("pellet_count"):
			pellet_upgrade = upgrade
	_def.set_run_level(pellet_upgrade, 2)
	var upgraded := _gun.get_pellet_count()
	_reaps.clear()
	await _enemy(origin, 1.0)
	_shoot_at(origin)
	await _frames(12)
	_ok(upgraded > 6 and not _reaps.is_empty() and _reaps[0][1] == upgraded,
		"the volley follows the live pellet count", "%d pellets" % upgraded)
	_def.set_run_level(pellet_upgrade, 0)
	await _clear()

	print("--- the chain ---")
	_reaps.clear()
	var first := await _enemy(origin, 1.0)
	var chained: Array = []
	for i in 3:
		var man := await _enemy(origin + Vector2(90.0 + i * 70.0, 0.0), 0.01)
		chained.append(_count_deaths(man))
	var first_deaths := _count_deaths(first)
	_shoot_at(origin)
	await _frames(90)
	var each_once: bool = first_deaths[0] == 1
	for count: Array in chained:
		each_once = each_once and count[0] == 1
	_ok(each_once, "every man in the chain dies once")
	_ok(_reaps.size() == 4, "and each execution reaps once", "%d volleys" % _reaps.size())
	await _clear()

	print("--- DEVIL'S BREATH on the volley ---")
	var breath := _legendary(&"devils_breath")
	_def.set_legendary_active(breath, true)
	var breath_stats := _reaper.blood_reaper.reaper_stats(_gun.get_stats())
	var blast := breath.shot_explosion.detonate(_arena, origin, breath_stats, 2)
	_ok(blast != null and is_equal_approx(blast._damage, breath.shot_explosion.get_damage() * 0.1)
		and is_equal_approx(blast._radius, breath.shot_explosion.radius * 0.1)
		and is_equal_approx(blast._power, 0.1)
		and is_equal_approx(blast._effects.knockback_push, breath.shot_explosion.knockback_push * 0.1),
		"its blast is 10% damage, radius, shove and camera kick")
	var full := breath.shot_explosion.detonate(_arena, origin, _gun.get_stats(), 2)
	_ok(full != null and is_equal_approx(full._damage, breath.shot_explosion.get_damage())
		and is_equal_approx(full._power, 1.0), "while the shot's own blast is untouched")
	_def.set_legendary_active(breath, false)
	await _clear()

	print("--- off again ---")
	_def.set_legendary_active(_reaper, false)
	_reaps.clear()
	await _enemy(origin, 1.0)
	_shoot_at(origin)
	await _frames(12)
	_ok(_reaps.is_empty() and _nodes(Explosion).is_empty(), "no execution, no volley")
	await _clear()

	print("--- the K panel ---")
	var listed := false
	for method: Dictionary in (load("res://Scripts/UI/weapon_debug_panel.gd") as Script).get_script_method_list():
		listed = listed or method.get("name") == "_add_reaper_row"
	_ok(listed, "the panel has a BLOOD REAPER row")

	_def.reset_upgrades()
	_finish()


## A pellet of the gun's own, released through the same code a shot uses, flying
## into a man standing at [param at].
func _shoot_at(at: Vector2) -> void:
	_gun._release_pellet(_arena, _gun._shot_stats(), false, at - Vector2(60, 26), 0.0)


func _armed(stats: WeaponStats) -> Projectile:
	var pellet := (_gun.projectile_scene.instantiate()) as Projectile
	pellet.apply_weapon_stats(stats, false)
	return pellet


func _volley_rounds() -> Array[Projectile]:
	var found: Array[Projectile] = []
	var look := _reaper.blood_reaper
	for child: Node in _arena.get_children():
		var shot := child as Projectile
		if shot != null and shot._tint == look.tint and is_equal_approx(shot._tint_strength, look.tint_strength):
			found.append(shot)
	return found


## The distinct enemies the volley just released is going for.
func _volley_targets() -> Array:
	var targets: Array = []
	for shot: Projectile in _volley_rounds():
		if shot._target != null and not targets.has(shot._target):
			targets.append(shot._target)
	return targets


## [Explosion]s that left a scorch - a bomb's look, which an execution must never have.
func _blasts() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in _nodes(Explosion):
		var mark := node.get_node_or_null((node as Explosion).mark_path) as CanvasItem
		if mark != null and mark.visible:
			found.append(node)
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


func _count_deaths(enemy: Node) -> Array:
	var count := [0]
	(enemy.get_node(^"Health") as Health).died.connect(func() -> void: count[0] += 1)
	return count


func _head_pops() -> int:
	var found := 0
	for child: Node in _arena.get_children():
		if child is DeathDebris and not child.name.begins_with("GorePiece"):
			found += 1
	return found


func _nodes(type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _arena.get_children():
		if is_instance_of(child, type):
			found.append(child)
	return found


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
	print("BLOOD REAPER SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _gore_pieces() -> int:
	var found := 0
	for child: Node in _arena.get_children():
		if child is DeathDebris and child.name.begins_with("GorePiece"):
			found += 1
	return found


## Whether any [Explosion] in the arena is showing its flare, flash or smoke.
func _bomb_look_shown() -> bool:
	for node: Node in _nodes(Explosion):
		var look := node as Explosion
		for path: NodePath in [look.boom_path, look.flash_path, look.smoke_path]:
			var part := look.get_node_or_null(path) as CanvasItem
			if part != null and part.visible:
				return true
	return false
