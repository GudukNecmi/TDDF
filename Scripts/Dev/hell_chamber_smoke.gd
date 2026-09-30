extends SceneTree
## Headless check of the shotgun's Legendary HELL CHAMBER: it is listed as a
## Legendary and in no upgrade pool; off, the trigger fires on the press; on, the
## press only charges, the release fires with the charge built, each stage folds its
## multipliers into the ordinary stats, the top stages carry a damage-free
## shockwave that shoves and staggers, the holder is slowed while charging, other
## Legendaries keep riding the same pellets, and the K panel reads, resets and
## switches it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/hell_chamber_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const PELLET_SCENE := "res://Scenes/Projectile/Projectile.tscn"

var _failures: int = 0
var _arena: Node2D
var _gun: Shotgun
var _def: WeaponDefinition


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_def = session.get_weapon_catalog().find(&"shotgun")
	_def.reset_upgrades()

	print("--- the Legendary ---")
	var hell := _legendary(&"hell_chamber")
	_ok(hell != null and hell.hell_chamber != null, "the shotgun lists HELL CHAMBER with a charge part")
	if hell == null:
		_finish()
		return
	var chamber := hell.hell_chamber
	var in_pool := false
	for upgrade: WeaponUpgrade in _def.upgrades:
		in_pool = in_pool or upgrade.id == hell.id
	_ok(not in_pool, "and not among the upgrades the Base, markets and rewards deal from")

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var view := CameraController.new()
	_arena.add_child(view)
	view.make_current()
	var holder := Node2D.new()
	holder.name = "Holder"
	_arena.add_child(holder)
	var heft := WeaponHeft.new()
	heft.name = "WeaponHeft"
	holder.add_child(heft)
	_gun = (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	_gun.definition = _def
	_gun.target_path = ^"../Holder"
	_arena.add_child(_gun)
	await process_frame
	var ammo := _gun.get_ammo()
	if ammo != null and ammo.get_reserve() != null:
		ammo.get_reserve().fill()

	print("--- off: the ordinary trigger ---")
	var shots := [0]
	_gun.fired.connect(func() -> void: shots[0] += 1)
	_press()
	_ok(shots[0] == 1, "the press fires at once")
	_release()
	await _frames(3)
	_ok(shots[0] == 1 and _gun.get_chamber_charge() == 0.0, "and the release does nothing")

	print("--- on: charging ---")
	_def.set_legendary_active(hell, true)
	_gun.reload_to_ready()
	var released := [-1.0, false]
	_gun.chamber_released.connect(func(c: float, m: bool) -> void:
		released[0] = c
		released[1] = m)
	var maxed := [0]
	_gun.chamber_maxed.connect(func() -> void: maxed[0] += 1)
	shots[0] = 0
	_press()
	_ok(shots[0] == 0, "the press does not fire")
	await create_timer(chamber.charge_duration * 0.4).timeout
	var partial := _gun.get_chamber_charge()
	_ok(partial > 0.25 and partial < 0.5, "holding builds the charge continuously", "%.2f" % partial)
	_ok(shots[0] == 0, "and holding never fires")
	_ok(heft.get_speed_multiplier() < 1.0 and heft.get_speed_multiplier() > chamber.move_speed_at_full,
		"the holder is slowed, less than at full", "%.2f" % heft.get_speed_multiplier())
	_ok(_gun.get_stage_label().begins_with("HELL") and is_equal_approx(_gun.get_charge_ratio(), partial),
		"the readout and the sight follow it", _gun.get_stage_label())
	var glow := _gun.get_node(^"Art/Body/ChamberGlow") as Sprite2D
	var hum := _gun.get_node(^"ChamberHum") as LoopingSound
	_ok(glow.visible and glow.modulate.a > 0.0, "the barrel glows", "%.2f" % glow.modulate.a)
	_ok(hum.get_level() > 0.0 and hum.playing, "the buildup hum is playing", "%.2f" % hum.get_level())
	var plain := _def.get_stats()
	var stage1 := _gun._shot_stats()
	_ok(is_equal_approx(stage1.speed_scale(), plain.speed_scale() * chamber.speed_multiplier), "25-50%: the pellets fly faster", "%.2f" % stage1.speed_scale())
	_ok(is_equal_approx(stage1.size_scale(), plain.size_scale()) and stage1.shot_shockwave == null, "but are not bigger and carry no shockwave")
	_ok(plain.get_bonus(WeaponStats.Stat.PROJECTILE_SPEED) == 0.0, "the weapon's own stats are untouched")

	var before := _arena.get_children()
	_release()
	var pellets := _new_pellets(before)
	_ok(shots[0] == 1 and is_equal_approx(released[0], partial) and not released[1], "the release fires at once with the charge built", "%.2f" % released[0])
	_ok(pellets.size() == _gun.get_pellet_count(), "the ordinary number of pellets leave", str(pellets.size()))
	_ok(_gun.get_chamber_charge() == 0.0, "the shot spends the charge")
	await _frames(3)
	_ok(heft.get_speed_multiplier() == 1.0, "and the holder walks at full speed again")
	_free(pellets)

	print("--- stages ---")
	var weight := chamber.charged_stats(plain, 0.6)
	_ok(is_equal_approx(weight.size_scale(), chamber.size_multiplier) and is_equal_approx(weight.knockback_scale(), chamber.knockback_multiplier), "50-75%: bigger pellets that shove harder")
	_ok(weight.shot_shockwave == null, "and still no shockwave")
	var wave := chamber.charged_stats(plain, 0.8)
	_ok(wave.shot_shockwave == chamber.shockwave and wave.shot_shockwave.get_damage() == 0.0, "75-100%: every pellet carries a damage-free shockwave")
	_ok(chamber.charged_stats(plain, 0.1).shot_shockwave == null and is_equal_approx(chamber.charged_stats(plain, 0.1).speed_scale(), 1.0), "0-25%: the ordinary shot")

	print("--- common upgrades compound ---")
	var speed_up := _upgrade(&"projectile_speed")
	if speed_up != null:
		_def.set_run_level(speed_up, 2)
		var upgraded := _def.get_stats()
		var boosted := chamber.charged_stats(upgraded, 0.3)
		_ok(is_equal_approx(boosted.speed_scale(), upgraded.speed_scale() * chamber.speed_multiplier), "a speed upgrade is multiplied, not replaced", "%.2f" % boosted.speed_scale())
		_def.set_run_level(speed_up, 0)

	print("--- MAX ---")
	_gun.reload_to_ready()
	_press()
	await create_timer(chamber.charge_duration + 0.25).timeout
	_ok(is_equal_approx(_gun.get_chamber_charge(), 1.0) and maxed[0] == 1, "a full hold reaches MAX once")
	_ok(_gun.get_stage_label() == chamber.max_label, "the readout says MAX", _gun.get_stage_label())
	var max_stats := _gun._shot_stats()
	_ok(max_stats.shot_shockwave == chamber.max_shockwave and max_stats.shot_shockwave.radius > chamber.shockwave.radius, "MAX carries the wider shockwave")
	_ok(is_equal_approx(max_stats.damage_scale_at(0.0), plain.damage_scale_at(0.0) * 2.0), "MAX doubles the damage at the muzzle", "%.2f" % max_stats.damage_scale_at(0.0))
	_ok(is_equal_approx(max_stats.damage_scale_at(1.0), plain.damage_scale_at(1.0) * 2.0 * 1.4), "and adds 40% on top at the end of the range", "%.2f" % max_stats.damage_scale_at(1.0))
	_ok(is_equal_approx(chamber.charged_stats(plain, 0.9).damage_scale_at(0.0), plain.damage_scale_at(0.0)), "below MAX the damage is untouched")
	_ok(is_equal_approx(heft.get_speed_multiplier(), chamber.move_speed_at_full), "the holder is at the tuned full slowdown, not rooted", "%.2f" % heft.get_speed_multiplier())
	var volleys: Array = []
	_gun.chamber_volley.connect(func(at: Vector2, rounds: int) -> void: volleys.append([at, rounds]))
	before = _arena.get_children()
	_release()
	pellets = _new_pellets(before)
	_ok(released[1] and pellets.size() > 0 and pellets[0]._shockwave == chamber.max_shockwave, "the MAX release fires pellets armed with it")
	_ok(pellets.size() == _gun._pellets_for(pellets[0]._stats) and volleys.is_empty(), "the shot itself is the ordinary shot - the volley has not left yet", str(pellets.size()))
	var volley := await _await_volley(pellets, volleys)
	_ok(volleys.size() == 1 and volley.size() == pellets.size() and volleys[0][1] == pellets.size(), "MAX bursts a secondary volley of one round per pellet fired", str(volley.size()))
	_ok(_is_echo(volley, pellets[0], chamber), "every volley round is the shot's own block and roll at 10% power", _echo_detail(volley, pellets[0]))
	_ok(_is_ring(volley, volleys[0][0]), "and they spread outward all round the source point")
	var dressed := volley.size() > 0
	for bullet: Projectile in volley:
		dressed = dressed and is_equal_approx(bullet._tint_strength, chamber.max_volley_tint_strength)
	_ok(dressed, "volley rounds are dressed white-hot")
	_ok(_arena.get_children().any(func(n: Node) -> bool: return n is ShotBlast), "a ring goes off where it bursts from")
	_ok(is_equal_approx(pellets[0]._stats.power_scale, 1.0), "the original shot is untouched at full power")
	_free(pellets)
	_free(volley)
	_clear()
	await _frames(2)

	print("--- below MAX there is no volley ---")
	_gun.reload_to_ready()
	volleys.clear()
	_press()
	await create_timer(chamber.charge_duration * 0.85).timeout
	before = _arena.get_children()
	_release()
	pellets = _new_pellets(before)
	await create_timer(chamber.max_volley_delay + 0.15).timeout
	_ok(volleys.is_empty() and _new_pellets(before).size() == pellets.size(), "an 85% shot is only the shot")
	_free(pellets)
	_clear()

	print("--- the shockwave is crowd control ---")
	var result := await _shock_test(chamber.charged_stats(plain, 0.8))
	_ok(result.neighbour == 0.0 and result.knocked, "a man beside the one hit is shoved but loses nothing", str(result))
	_ok(result.target > 0.0 and is_equal_approx(result.target, result.direct), "the man hit loses only the pellet's own damage", str(result))
	_ok(result.outside_knocked == false, "a man out of reach is left alone")

	print("--- charged kills come apart ---")
	var wave_scene := chamber.shockwave.blast_scene.instantiate() as ShotBlast
	var impact := wave_scene.sounds.size() == 1 and wave_scene.sounds[0].resource_path.ends_with("HellChamberImpact.wav")
	wave_scene.free()
	var max_scene := chamber.max_shockwave.blast_scene.instantiate() as ShotBlast
	impact = impact and max_scene.sounds.size() == 1 and max_scene.sounds[0].resource_path.ends_with("HellChamberImpact.wav")
	max_scene.free()
	_ok(impact, "every shockwave impact plays the demonic impact sound")
	for case: Array in [[0.8, true, "a 75%+ kill"], [1.0, true, "a MAX kill"], [0.6, false, "a 50-75% kill"]]:
		var kill := await _kill_test(chamber.charged_stats(plain, case[0]))
		if case[1]:
			_ok(kill.deaths == 1 and kill.gore == 1 and kill.pieces > 0 and kill.pops == 0, "%s tears him apart into the existing gore" % case[2], str(kill))
		else:
			_ok(kill.deaths == 1 and kill.gore == 0 and kill.pops > 0, "%s dies the ordinary way" % case[2], str(kill))
	var survivor := await _kill_test(chamber.charged_stats(plain, 0.8), 100000.0)
	_ok(survivor.deaths == 0 and survivor.gore == 0, "a 75%+ hit that does not kill is only a hit", str(survivor))

	print("--- other Legendaries ride the same pellets ---")
	var barrel := _legendary(&"devils_barrel")
	var breath := _legendary(&"devils_breath")
	_def.set_legendary_active(barrel, true)
	_def.set_legendary_active(breath, true)
	_gun.reload_to_ready()
	_press()
	await create_timer(chamber.charge_duration * 0.85).timeout
	var combo := _gun._shot_stats()
	_ok(combo.shot_pattern == barrel.shot_pattern and combo.shot_explosion == breath.shot_explosion and combo.shot_shockwave == chamber.shockwave, "pattern, explosion and shockwave all on one shot")
	before = _arena.get_children()
	_release()
	pellets = _new_pellets(before)
	var both := pellets.size() > 0
	for pellet: Projectile in pellets:
		both = both and pellet._explosion == breath.shot_explosion and pellet._shockwave == chamber.shockwave and is_equal_approx(pellet._speed_scale, barrel.shot_pattern.speed_scale)
	_ok(both, "every pellet explodes, shocks and keeps DEVIL'S BARREL's flight")
	_free(pellets)
	_clear()
	_def.set_legendary_active(barrel, false)
	_def.set_legendary_active(breath, false)

	var pump := _legendary(&"blood_pump")
	_def.set_legendary_active(pump, true)
	_gun.reload_to_ready()
	_gun._try_pump()
	_gun._try_pump()
	_press()
	await create_timer(0.55).timeout
	_ok(_gun.get_pump_charge() == 1 and _gun.get_chamber_charge() > 0.0, "BLOOD PUMP's charge and the chamber's are kept apart")
	var pump_and_hell := _gun._shot_stats()
	_ok(pump_and_hell.get_bonus(WeaponStats.Stat.DAMAGE) > 0.0 and pump_and_hell.speed_scale() > 1.0, "and both reach the same shot")
	_release()
	_ok(_gun.get_pump_charge() == 0 and _gun.get_chamber_charge() == 0.0, "which spends both")
	_def.set_legendary_active(pump, false)
	_clear()

	print("--- the MAX volley inherits the whole shot ---")
	for combo_ids: Array in [[&"blood_pump"], [&"devils_breath"], [&"devils_barrel"],
			[&"blood_pump", &"devils_breath", &"devils_barrel", &"black_powder", &"blood_reaper"]]:
		for id: StringName in combo_ids:
			_def.set_legendary_active(_legendary(id), true)
		_gun.reload_to_ready()
		if combo_ids.has(&"blood_pump"):
			for i in 4:
				_gun._try_pump()
		volleys.clear()
		_press()
		await create_timer(chamber.charge_duration + 0.2).timeout
		before = _arena.get_children()
		_release()
		pellets = _new_pellets(before)
		volley = await _await_volley(pellets, volleys)
		var label := "+".join(combo_ids)
		_ok(volley.size() == pellets.size() and _is_echo(volley, pellets[0], chamber), "%s: the volley is the shot at 10%%" % label, _echo_detail(volley, pellets[0]))
		var shot: WeaponStats = pellets[0]._stats if pellets.size() > 0 else null
		if combo_ids.has(&"blood_pump") and shot != null:
			var plain_damage := _def.get_stats().get_bonus(WeaponStats.Stat.DAMAGE)
			_ok(shot.get_bonus(WeaponStats.Stat.DAMAGE) > plain_damage and _same_bonuses(volley[0]._stats, shot), "%s: the banked BLOOD PUMP charge rides the volley" % label)
		if combo_ids.has(&"devils_breath"):
			var breath_ok := volley.size() > 0
			for bullet: Projectile in volley:
				breath_ok = breath_ok and bullet._explosion == _legendary(&"devils_breath").shot_explosion
			_ok(breath_ok, "%s: every volley round explodes like DEVIL'S BREATH" % label)
		if combo_ids.has(&"devils_barrel"):
			var barrel_ok := volley.size() > 0
			var pattern := _legendary(&"devils_barrel").shot_pattern
			for bullet: Projectile in volley:
				barrel_ok = barrel_ok and is_equal_approx(bullet._speed_scale, pattern.speed_scale)
			_ok(barrel_ok, "%s: every volley round flies DEVIL'S BARREL's way" % label)
		_free(pellets)
		_free(volley)
		_clear()
		for id: StringName in combo_ids:
			_def.set_legendary_active(_legendary(id), false)
		await _frames(2)

	print("--- a modifier Hell Chamber has never heard of still reaches the volley ---")
	_gun.reload_to_ready()
	var future := _gun._shot_stats().duplicate_stats()
	for stat: int in WeaponStats.Stat.values():
		future.add(stat as WeaponStats.Stat, 0.01 * float(stat + 1))
	future.shot_recoil = ShotRecoil.new()
	volleys.clear()
	before = _arena.get_children()
	_gun._chamber_volley(future, true, Vector2(300, -300))
	volley = _new_pellets(before)
	var future_ok := volley.size() == _gun._pellets_for(future) and volleys.size() == 1
	for bullet: Projectile in volley:
		future_ok = future_ok and _same_bonuses(bullet._stats, future) and bullet._stats.shot_recoil == future.shot_recoil and bullet._critical
	_ok(future_ok, "every stat bonus, part and the critical roll of an arbitrary shot are carried", str(volley.size()))
	_free(volley)
	_clear()

	print("--- a tap is the ordinary shot ---")
	_gun.reload_to_ready()
	released[0] = -1.0
	shots[0] = 0
	_press()
	_release()
	_ok(shots[0] == 1 and released[0] == 0.0, "press and release at once fires an uncharged shot")
	_clear()

	print("--- pausing through a charge ---")
	_gun.reload_to_ready()
	shots[0] = 0
	_press()
	await create_timer(0.3).timeout
	paused = true
	await process_frame
	Input.action_release(&"fire")
	paused = false
	await _frames(3)
	_ok(shots[0] == 0 and _gun.get_chamber_charge() == 0.0 and heft.get_speed_multiplier() == 1.0, "a trigger let go while paused cancels rather than fires")

	print("--- the K panel ---")
	_gun.reload_to_ready()
	_press()
	await create_timer(chamber.charge_duration * 0.5).timeout
	var held := _gun.get_chamber_charge()
	var mount := WeaponMount.new()
	_arena.add_child(mount)
	mount.set(&"_weapon", _gun)
	var panel := _make_panel()
	panel.open()
	_ok(_readout(panel).begins_with("CHARGE %d%%" % roundi(held * 100.0)), "the panel reads the live charge", _readout(panel))
	var reset := _find_button(panel, "RESET CHARGE", "HELL")
	_ok(reset != null, "and has RESET CHARGE")
	if reset != null:
		reset.pressed.emit()
	_ok(_gun.get_chamber_charge() == 0.0 and _readout(panel).begins_with("CHARGE 0%"), "which drops the charge", _readout(panel))
	panel.close()
	paused = false
	await create_timer(0.3).timeout
	_ok(_gun.get_chamber_charge() > 0.0, "still held, it builds again")
	panel.open()
	var off := _find_button(panel, "OFF", "HELL CHAMBER")
	_ok(off != null, "HELL CHAMBER has its own OFF")
	if off != null:
		off.pressed.emit()
	_ok(not _def.is_legendary_active(hell), "OFF switches it off")
	_ok(_gun.get_chamber_charge() == 0.0 and heft.get_speed_multiplier() == 1.0, "and drops the charge and the slowdown at once")
	panel.close()
	paused = false
	Input.action_release(&"fire")
	await _frames(5)
	_ok(not glow.visible, "the glow is gone")
	shots[0] = 0
	_press()
	_ok(shots[0] == 1, "the next press fires on the press again")
	_release()

	_def.set_legendary_active(hell, true)
	_def.clear_run_levels()
	_ok(not _def.is_legendary_active(hell), "it is forgotten with the run levels")
	_def.reset_upgrades()
	_finish()


func _press() -> void:
	Input.action_press(&"fire")
	var event := InputEventAction.new()
	event.action = &"fire"
	event.pressed = true
	_gun._weapon_input(event)


func _release() -> void:
	Input.action_release(&"fire")
	var event := InputEventAction.new()
	event.action = &"fire"
	event.pressed = false
	_gun._weapon_input(event)


## One pellet armed with [param stats] at an enemy 80px off, with a neighbour 30px
## behind him along the line and one far off, and what each lost.
func _shock_test(stats: WeaponStats) -> Dictionary:
	var origin := Vector2(-2000, 0)
	var target := await _spawn_enemy(origin + Vector2(80, 0))
	var neighbour := await _spawn_enemy(origin + Vector2(110, 0))
	var outside := await _spawn_enemy(origin + Vector2(80, 500))
	var healths: Array[Health] = []
	var starts: Array[float] = []
	for enemy: Node2D in [target, neighbour, outside]:
		var health := enemy.get_node(^"Health") as Health
		healths.append(health)
		starts.append(health.get_current())
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	pellet.apply_weapon_stats(stats, false)
	_arena.add_child(pellet)
	pellet.global_position = origin
	var direct := [0.0]
	pellet.landed.connect(func(_hitbox: Hitbox) -> void: direct[0] = starts[0] - healths[0].get_current())
	var knocked := false
	var outside_knocked := false
	for i in 20:
		await physics_frame
		knocked = knocked or _reaction(neighbour).get_knockback() != Vector2.ZERO
		outside_knocked = outside_knocked or _reaction(outside).get_knockback() != Vector2.ZERO
	var result := {
		"direct": direct[0],
		"target": starts[0] - healths[0].get_current(),
		"neighbour": starts[1] - healths[1].get_current(),
		"knocked": knocked,
		"outside_knocked": outside_knocked,
	}
	for enemy: Node2D in [target, neighbour, outside]:
		enemy.free()
	if is_instance_valid(pellet):
		pellet.free()
	_clear()
	return result


## One pellet armed with [param stats] at a lone enemy with [param health] - how
## often he died, how many gore effects and pieces and ordinary head-pops followed.
func _kill_test(stats: WeaponStats, health: float = 1.0) -> Dictionary:
	var origin := Vector2(4000, 4000)
	var enemy := (load("res://Scenes/Enemy/Enemy.tscn") as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = origin
	var pool := enemy.get_node(^"Health") as Health
	pool.set_max_health(health)
	var deaths := [0]
	pool.died.connect(func() -> void: deaths[0] += 1)
	await physics_frame
	await physics_frame
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	pellet.apply_weapon_stats(stats, false)
	_arena.add_child(pellet)
	pellet.global_position = origin - Vector2(60, 26)
	await _frames(20)
	var result := {"deaths": deaths[0], "gore": 0, "pieces": 0, "pops": 0}
	for child: Node in _arena.get_children():
		if child is Explosion:
			result.gore += 1
		elif child is DeathDebris:
			if child.name.begins_with("GorePiece"):
				result.pieces += 1
			else:
				result.pops += 1
	if is_instance_valid(enemy):
		enemy.free()
	for child: Node in _arena.get_children():
		if child is Explosion or child is DeathDebris or child is Projectile:
			child.free()
	_clear()
	return result


## The volley rounds that follow the shot [param shot_pellets], once it has burst.
func _await_volley(shot_pellets: Array[Projectile], volleys: Array) -> Array[Projectile]:
	var chamber := _legendary(&"hell_chamber").hell_chamber
	var known: Array[Node] = _arena.get_children()
	for pellet: Projectile in shot_pellets:
		known.erase(pellet)
	var waited := 0.0
	while volleys.is_empty() and waited < chamber.max_volley_delay + 0.5:
		await process_frame
		waited += 1.0 / 60.0
	var volley: Array[Projectile] = []
	for child: Node in _arena.get_children():
		if child is Projectile and not shot_pellets.has(child) and not known.has(child):
			volley.append(child)
	return volley


## Whether every round of [param volley] is armed from a copy of the block
## [param primary] left with - every stat bonus and every part - at the chamber's
## volley power, with its critical roll.
func _is_echo(volley: Array[Projectile], primary: Projectile, chamber: HellChamber) -> bool:
	if volley.is_empty() or primary == null:
		return false
	var shot := primary._stats
	for bullet: Projectile in volley:
		var stats := bullet._stats
		if stats == shot or not _same_bonuses(stats, shot):
			return false
		if not is_equal_approx(stats.power_scale, shot.power_scale * chamber.max_volley_power_multiplier):
			return false
		for part: String in ["shot_pattern", "pump_charge", "shot_explosion", "fan_hammer",
				"shot_recoil", "black_powder", "hell_chamber", "shot_shockwave", "blood_reaper"]:
			if stats.get(part) != shot.get(part):
				return false
		if bullet._critical != primary._critical or bullet._shockwave != primary._shockwave \
				or bullet._explosion != primary._explosion:
			return false
	return true


func _echo_detail(volley: Array[Projectile], primary: Projectile) -> String:
	if volley.is_empty() or primary == null:
		return "no volley"
	return "%d rounds, power %.2f vs %.2f, damage x%.2f vs x%.2f" % [volley.size(),
		volley[0]._stats.power_scale, primary._stats.power_scale,
		volley[0].damage_at_progress(0.0), primary.damage_at_progress(0.0)]


func _same_bonuses(a: WeaponStats, b: WeaponStats) -> bool:
	for stat: int in WeaponStats.Stat.values():
		if not is_equal_approx(a.get_bonus(stat as WeaponStats.Stat), b.get_bonus(stat as WeaponStats.Stat)):
			return false
	return is_equal_approx(a.base_critical_chance, b.base_critical_chance) \
		and is_equal_approx(a.base_critical_multiplier, b.base_critical_multiplier)


## Whether [param volley] leaves from [param at] spread all the way round it - no
## half of the circle empty.
func _is_ring(volley: Array[Projectile], at: Vector2) -> bool:
	if volley.size() < 3:
		return false
	var angles: Array[float] = []
	for bullet: Projectile in volley:
		angles.append(fposmod(bullet.global_rotation, TAU))
	angles.sort()
	var widest := TAU - angles[-1] + angles[0]
	for i in range(1, angles.size()):
		widest = maxf(widest, angles[i] - angles[i - 1])
	return widest < PI


func _reaction(enemy: Node) -> HitReaction:
	return enemy.find_children("*", "HitReaction", true, false)[0] as HitReaction


func _spawn_enemy(at: Vector2) -> Node2D:
	var enemy := (load("res://Scenes/Enemy/Enemy.tscn") as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(100000.0)
	await physics_frame
	await physics_frame
	return enemy


func _new_pellets(before: Array[Node]) -> Array[Projectile]:
	var pellets: Array[Projectile] = []
	for child: Node in _arena.get_children():
		if not before.has(child) and child is Projectile:
			pellets.append(child)
	return pellets


func _free(pellets: Array[Projectile]) -> void:
	for pellet: Projectile in pellets:
		if is_instance_valid(pellet):
			pellet.free()


func _clear() -> void:
	for child: Node in _arena.get_children():
		if child is Projectile or child is FollowingParticles or child is ShotBlast or child is CPUParticles2D:
			child.free()


func _legendary(id: StringName) -> WeaponLegendary:
	for legendary: WeaponLegendary in _def.legendaries:
		if legendary.id == id:
			return legendary
	return null


func _upgrade(id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in _def.upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _make_panel() -> WeaponDebugPanel:
	var panel := WeaponDebugPanel.new()
	var box := PanelContainer.new()
	box.name = "Panel"
	panel.add_child(box)
	var body := VBoxContainer.new()
	body.name = "Body"
	box.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	scroll.add_child(rows)
	root.add_child(panel)
	return panel


func _find_button(panel: WeaponDebugPanel, text: String, row: String = "") -> Button:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if not (line is HBoxContainer):
			continue
		if not row.is_empty() and not (line.get_child(0) as Label).text.contains(row):
			continue
		for child: Node in line.get_children():
			if child is Button and child.text == text:
				return child
	return null


func _readout(panel: WeaponDebugPanel) -> String:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if line is HBoxContainer and (line.get_child(0) as Label).text == panel.chamber_row_label:
			return (line.get_child(1) as Label).text
	return ""


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("HELL CHAMBER SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
