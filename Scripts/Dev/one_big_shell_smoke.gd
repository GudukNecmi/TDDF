extends SceneTree
## Headless check of the shotgun's Legendary ONE BIG SHELL: it is listed as a
## Legendary and in no upgrade pool; off, the shotgun fires its pellets; on, one big
## shell leaves straight down the barrel however many pellets the block carries;
## what a hit deals falls off continuously with the victim's distance off the
## shell's centre line; a graze still shoves and lets the shell fly on; a lethal
## centre hit comes apart through the existing gore; common upgrades, charges and
## other Legendaries all reach the shell through the one shot block; the K panel
## switches it; the feedback and audio layers are wired.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/one_big_shell_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const PELLET_SCENE := "res://Scenes/Projectile/Projectile.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
## Where the enemy's body hitbox sits over his feet - see Enemy.tscn.
const BODY_Y := -11.8

var _failures: int = 0
var _arena: Node2D
var _gun: Shotgun
var _def: WeaponDefinition
var _legend: WeaponLegendary
var _part: OneBigShell


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_def = session.get_weapon_catalog().find(&"shotgun")
	_def.reset_upgrades()

	print("--- the Legendary ---")
	_legend = _legendary(&"one_big_shell")
	_ok(_legend != null and _legend.one_big_shell != null and _legend.one_big_shell.shell_scene != null,
		"the shotgun lists ONE BIG SHELL with a shell part")
	if _legend == null:
		_finish()
		return
	_part = _legend.one_big_shell
	var in_pool := false
	for upgrade: WeaponUpgrade in _def.upgrades:
		in_pool = in_pool or upgrade.id == _legend.id
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
	_gun = (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	_gun.definition = _def
	_gun.target_path = ^"../Holder"
	_arena.add_child(_gun)
	await process_frame
	_refill()

	print("--- off: the ordinary pellets ---")
	var fired_shells := [0]
	_gun.big_shell_fired.connect(func(_s: CannonShell) -> void: fired_shells[0] += 1)
	var pellets := _shoot()
	_ok(pellets.size() == _gun.get_pellet_count() and pellets.size() > 1,
		"OFF fires the ordinary pellet count", str(pellets.size()))
	_ok(pellets.all(func(p: Projectile) -> bool: return not (p is CannonShell)) and fired_shells[0] == 0,
		"and none of them is a shell")
	_free(pellets)

	print("--- on: one shell ---")
	_def.set_legendary_active(_legend, true)
	_ok(_gun.fires_one_big_shell(), "switched on, the shotgun fires one big shell")
	_gun.rotation = 0.37
	await process_frame
	pellets = _shoot()
	_ok(pellets.size() == 1 and pellets[0] is CannonShell, "exactly one projectile leaves, and it is the shell", str(pellets.size()))
	if pellets.size() > 0:
		_ok(is_equal_approx(pellets[0].global_rotation, _gun.global_rotation), "straight down the barrel - no spread",
			"%.3f vs %.3f" % [pellets[0].global_rotation, _gun.global_rotation])
	_ok(fired_shells[0] == 1, "announced once as a shell shot")
	_free(pellets)
	var pellet_up := _upgrade(&"pellet_count")
	var accuracy_up := _upgrade(&"accuracy")
	if pellet_up != null:
		_def.set_run_level(pellet_up, pellet_up.max_level)
	if accuracy_up != null:
		_def.set_run_level(accuracy_up, 0)
	var many := _gun.get_pellet_count()
	pellets = _shoot()
	_ok(pellets.size() == 1 and many > 6, "with %d pellets in the block it is still one shell" % many, str(pellets.size()))
	_ok(pellets.size() == 1 and is_equal_approx((pellets[0] as CannonShell)._core_factor, _part.core_factor(many)),
		"and the shell carries the whole blast's pellets in its damage")
	_free(pellets)
	if pellet_up != null:
		_def.set_run_level(pellet_up, 0)
	_gun.rotation = 0.0
	await process_frame

	print("--- a big shell ---")
	var shell := _make_shell(_def.get_stats(), Vector2(9000, 9000))
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	_arena.add_child(pellet)
	_ok(shell.get_hit_radius() >= pellet.hit_half_width * 8.0, "its hit radius is many times a pellet's",
		"%.1f vs %.1f" % [shell.get_hit_radius(), pellet.hit_half_width])
	var shell_size := _drawn(shell.get_node(^"Sprite2D") as Sprite2D)
	var pellet_size := _drawn(pellet.get_node(^"Sprite2D") as Sprite2D)
	_ok(shell_size.x * shell_size.y >= pellet_size.x * pellet_size.y * 15.0 and shell_size.y >= pellet_size.y * 3.0,
		"it is drawn many times a pellet's size", "%s vs %s" % [shell_size, pellet_size])
	_ok(shell.get_node_or_null(^"Streak") is ProjectileTrail and shell.get_node_or_null(^"Shimmer") != null \
		and shell.get_node_or_null(^"Core") != null, "with a hot core, a streak and a heat shimmer")
	pellet.free()
	shell.free()
	_clear()

	print("--- where it hits decides what it deals ---")
	var offsets := [0.0, 8.0, 14.0, 20.0, 26.0, 31.0]
	var hits: Array[Dictionary] = []
	for offset: float in offsets:
		hits.append(await _hit_test(_def.get_stats(), offset))
	var centre: Dictionary = hits[0]
	_ok(centre.hit and centre.centrality > 0.99 and is_equal_approx(centre.ratio, 1.0),
		"a dead-centre hit deals the full core damage", _hit_detail(centre))
	_ok(centre.dealt > 0.0 and is_equal_approx(centre.dealt, centre.full),
		"which is a pellet's damage times the shot's pellets", "%.1f vs %.1f" % [centre.dealt, centre.full])
	var falling := true
	var all_modelled := true
	var distinct := {}
	for i in range(1, hits.size()):
		var hit: Dictionary = hits[i]
		falling = falling and hit.hit and hit.ratio <= hits[i - 1].ratio + 0.0001
		all_modelled = all_modelled and absf(hit.ratio - _part.damage_factor(1.0 - hit.centrality)) < 0.01
		distinct[snappedf(hit.ratio, 0.01)] = true
	_ok(falling, "damage falls steadily the further off the centre line", _ratios(hits))
	_ok(all_modelled, "every hit deals exactly the curve's share for its distance", _ratios(hits))
	_ok(distinct.size() >= 4, "and the shares are continuous rather than a few fixed cases", _ratios(hits))
	var graze: Dictionary = hits[-1]
	_ok(graze.ratio < 0.5 and graze.ratio >= _part.min_edge_damage - 0.001,
		"a graze deals substantially less, never below the rim floor", _hit_detail(graze))
	_ok(graze.knocked and graze.knock.y < 0.0, "a graze still shoves - hard, and out to the side it was clipped on",
		str(graze.knock))
	_ok(graze.flew_on, "and the shell flies on past a graze")
	_ok(not centre.flew_on, "a centre hit stops it, as any round is stopped")
	_ok(centre.knocked and absf(centre.knock.angle()) < 0.05, "a centre hit shoves straight along the flight", str(centre.knock))
	_ok(graze.knock.length() > 0.0 and hits[3].knocked, "every man touched is knocked back")

	print("--- a lethal centre hit uses the existing gore ---")
	var kill := await _kill_test(0.0)
	_ok(kill.deaths == 1 and kill.gore == 1 and kill.pieces > 0, "he comes apart through the Explosion gore", str(kill))
	_ok(kill.credited, "and the death is credited to the shot's own block")
	_ok(kill.struck_killed, "the shell reports the kill to the feedback")
	var graze_kill := await _kill_test(28.0)
	_ok(graze_kill.deaths == 1 and graze_kill.gore == 0, "a fatal graze dies the ordinary way", str(graze_kill))

	print("--- common upgrades reach the shell ---")
	var plain := _def.get_stats()
	var base_shell := _make_shell(plain, Vector2(9000, 9000))
	var base_damage := base_shell.damage_at_distance(0.0)
	var base_radius := base_shell.get_hit_radius()
	var base_range := base_shell.get_effective_range()
	base_shell.free()
	for case: Array in [[&"damage", "damage"], [&"projectile_size", "size"], [&"range", "range"],
			[&"knockback", "knockback"], [&"projectile_speed", "speed"]]:
		var up := _upgrade(case[0])
		if up == null:
			_ok(false, "the %s upgrade exists" % case[1])
			continue
		_def.set_run_level(up, 2)
		var stats := _def.get_stats()
		var upgraded := _make_shell(stats, Vector2(9000, 9000))
		match case[1]:
			"damage":
				_ok(is_equal_approx(upgraded.damage_at_distance(0.0), base_damage * stats.damage_scale_at(0.0)),
					"a damage upgrade raises the shell's core damage", "%.1f vs %.1f" % [upgraded.damage_at_distance(0.0), base_damage])
			"size":
				_ok(is_equal_approx(upgraded.get_hit_radius(), base_radius * stats.size_scale()) and upgraded.scale.x > 1.0,
					"a size upgrade grows the shell and what it hits", "%.1f vs %.1f" % [upgraded.get_hit_radius(), base_radius])
			"range":
				_ok(is_equal_approx(upgraded.get_effective_range(), base_range * stats.range_scale()),
					"a range upgrade carries the shell further", "%.0f vs %.0f" % [upgraded.get_effective_range(), base_range])
			"knockback":
				upgraded._hit_distance = 0.0
				_ok(is_equal_approx(upgraded._landing_effects().knockback_scale,
					stats.knockback_scale() * _part.knockback_factor(0.0)), "a knockback upgrade shoves harder")
			"speed":
				_ok(is_equal_approx(upgraded._stat_speed_scale(), stats.speed_scale()) and stats.speed_scale() > 1.0,
					"a speed upgrade speeds the shell")
		upgraded.free()
		_def.set_run_level(up, 0)
	var crit := _make_shell(_def.get_stats(), Vector2(9000, 9000), true)
	_ok(crit.is_critical() and crit.damage_at_distance(0.0) > base_damage, "a critical roll makes the shell critical")
	crit.free()
	_clear()

	print("--- the shot's temporary state reaches the shell ---")
	var pump := _legendary(&"blood_pump")
	_def.set_legendary_active(pump, true)
	_gun.reload_to_ready()
	for i in 4:
		_gun._try_pump()
	var charged := _gun._shot_stats()
	pellets = _shoot(false)
	_ok(pellets.size() == 1 and pellets[0] is CannonShell and _same_bonuses(pellets[0]._stats, charged) \
		and charged.get_bonus(WeaponStats.Stat.DAMAGE) > 0.0, "a banked BLOOD PUMP charge rides the shell")
	_free(pellets)
	_def.set_legendary_active(pump, false)

	var hell := _legendary(&"hell_chamber")
	_def.set_legendary_active(hell, true)
	_gun.reload_to_ready()
	_press()
	await create_timer(hell.hell_chamber.charge_duration + 0.2).timeout
	var maxed := _gun._shot_stats()
	var volleys := [0]
	_gun.chamber_volley.connect(func(_at: Vector2, _rounds: int) -> void: volleys[0] += 1)
	var before := _arena.get_children()
	_release()
	pellets = _new_pellets(before)
	_ok(pellets.size() == 1 and pellets[0] is CannonShell, "a MAX HELL CHAMBER shot is still one shell", str(pellets.size()))
	if pellets.size() == 1:
		var hot := pellets[0] as CannonShell
		_ok(hot._shockwave == hell.hell_chamber.max_shockwave and _same_bonuses(hot._stats, maxed)
			and hot.get_hit_radius() > base_radius, "carrying the MAX shockwave, damage and size")
	var volley := await _await_new(before, pellets, hell.hell_chamber.max_volley_delay + 0.3, volleys)
	_ok(volleys[0] == 1 and volley.size() > 1 and volley.all(func(p: Projectile) -> bool: return not (p is CannonShell)),
		"its MAX volley is left as HELL CHAMBER's own ring of rounds", "%d volleys, %d rounds" % [volleys[0], volley.size()])
	_free(pellets)
	_free(volley)
	_clear()
	_def.set_legendary_active(hell, false)
	Input.action_release(&"fire")

	var barrel := _legendary(&"devils_barrel")
	var breath := _legendary(&"devils_breath")
	var reaper := _legendary(&"blood_reaper")
	for other: WeaponLegendary in [barrel, breath, reaper]:
		_def.set_legendary_active(other, true)
	pellets = _shoot()
	if pellets.size() == 1:
		var dressed := pellets[0] as CannonShell
		_ok(dressed._explosion == breath.shot_explosion, "DEVIL'S BREATH makes the shell explosive")
		_ok(is_equal_approx(dressed.get_speed_scale(), barrel.shot_pattern.speed_scale * _part.speed_multiplier),
			"DEVIL'S BARREL's flight rides it, the shell's own speed on top")
		_ok(dressed._on_execution.is_valid() and dressed._stats.blood_reaper == reaper.blood_reaper,
			"and BLOOD REAPER hears its kills through the same attribution")
	else:
		_ok(false, "one shell with other Legendaries on", str(pellets.size()))
	_free(pellets)
	_clear()
	for other: WeaponLegendary in [barrel, breath, reaper]:
		_def.set_legendary_active(other, false)

	var future := _def.get_stats().duplicate_stats()
	for stat: int in WeaponStats.Stat.values():
		future.add(stat as WeaponStats.Stat, 0.01 * float(stat + 1))
	future.shot_recoil = ShotRecoil.new()
	var future_shell := _make_shell(future, Vector2(9000, 9000), true)
	_ok(_same_bonuses(future_shell._stats, future) and future_shell._stats.shot_recoil == future.shot_recoil \
		and future_shell.is_critical(), "a modifier the shell has never heard of still reaches it")
	future_shell.free()
	_clear()

	print("--- feedback and audio ---")
	var feedback := _gun.get_node_or_null(^"ShellFeedback") as OneBigShellFeedback
	_ok(feedback != null and feedback.fire_layer_sound != null and feedback.fire_layer_sound.resource_path.ends_with("OneBigShellFire.mp3"),
		"the shell's firing layer is the generated cannon blast")
	_ok(feedback != null and feedback.impact_sound != null and feedback.impact_sound.resource_path.ends_with("OneBigShellImpact.mp3"),
		"and its impact is the generated heavy thud")
	var ordinary := _gun.get_node(^"Feedback") as ShotgunFeedback
	var bank := _gun.get_node(^"Sounds") as SoundBank
	var blast := bank.sounds.get(ordinary.fire_sound) as AudioStream
	_ok(blast != null and blast.resource_path.ends_with("Shotgun Blast.WAV"),
		"the ordinary shotgun blast is unchanged")
	var bursts := [0]
	var watcher := func(node: Node) -> void:
		if node is CPUParticles2D and node.scene_file_path.ends_with("BigShellMuzzle.tscn"):
			bursts[0] += 1
	_arena.child_entered_tree.connect(watcher)
	pellets = _shoot()
	_arena.child_entered_tree.disconnect(watcher)
	_ok(bursts[0] == 1, "one shell shot throws one big muzzle burst", str(bursts[0]))
	_free(pellets)
	_clear()

	print("--- the K panel ---")
	var mount := WeaponMount.new()
	_arena.add_child(mount)
	mount.set(&"_weapon", _gun)
	var panel := _make_panel()
	panel.open()
	var off := _find_button(panel, "OFF", "ONE BIG SHELL")
	var on := _find_button(panel, "ON", "ONE BIG SHELL")
	_ok(off != null and on != null, "ONE BIG SHELL has its own ON and OFF")
	_ok(_row_text(panel, panel.shell_row_label).begins_with("CORE"), "and a readout of the cannon", _row_text(panel, panel.shell_row_label))
	if off != null:
		off.pressed.emit()
	panel.close()
	paused = false
	_ok(not _def.is_legendary_active(_legend) and not _gun.fires_one_big_shell(), "OFF switches it off at once")
	pellets = _shoot()
	_ok(pellets.size() == _gun.get_pellet_count() and pellets.size() > 1, "and the very next shot is pellets again", str(pellets.size()))
	_free(pellets)
	panel.open()
	on = _find_button(panel, "ON", "ONE BIG SHELL")
	if on != null:
		on.pressed.emit()
	panel.close()
	paused = false
	pellets = _shoot()
	_ok(pellets.size() == 1 and pellets[0] is CannonShell, "ON brings the shell straight back")
	_free(pellets)
	_clear()

	_def.clear_run_levels()
	_ok(not _def.is_legendary_active(_legend), "it is forgotten with the run levels")
	_def.reset_upgrades()
	_finish()


# --- Shots -----------------------------------------------------------------------

## One trigger pull from a ready, loaded gun, and the rounds it released.
func _shoot(reset: bool = true) -> Array[Projectile]:
	if reset:
		_gun.reload_to_ready()
	_refill()
	var before := _arena.get_children()
	_gun._try_fire()
	return _new_pellets(before)


func _refill() -> void:
	var ammo := _gun.get_ammo()
	if ammo != null and ammo.get_reserve() != null:
		ammo.get_reserve().fill()


## A shell armed from [param stats] through the weapon's own release path, parked
## at [param at] heading +X.
func _make_shell(stats: WeaponStats, at: Vector2, critical: bool = false) -> CannonShell:
	var shell := _gun._release_pellet(_arena, stats, critical, at, 0.0, false, null, null, _part) as CannonShell
	shell.set_physics_process(false)
	return shell


## One shell armed from [param stats] fired along +X at a sturdy enemy, its line
## [param offset] pixels below his body's centre (away from his head), and what
## the hit did.
func _hit_test(stats: WeaponStats, offset: float) -> Dictionary:
	var origin := Vector2(-3000, 2000)
	var enemy := await _spawn_enemy(origin + Vector2(160, 0), 1000000.0)
	var health := enemy.get_node(^"Health") as Health
	var start := health.get_current()
	var shell := _gun._release_pellet(_arena, stats, false, origin + Vector2(0, BODY_Y + offset), 0.0,
		false, null, null, _part) as CannonShell
	var result := {"hit": false, "centrality": -1.0, "full": 0.0, "dealt": 0.0, "ratio": 0.0,
		"knocked": false, "knock": Vector2.ZERO, "flew_on": false}
	shell.struck.connect(func(_at: Vector2, _dir: Vector2, centrality: float, _killed: bool) -> void:
		result.hit = true
		result.centrality = centrality
		result.full = shell.damage_at_distance(0.0)
		result.dealt = start - health.get_current())
	var reaction := _reaction(enemy)
	for i in 12:
		await physics_frame
		if reaction.get_knockback() != Vector2.ZERO and result.knock == Vector2.ZERO:
			result.knock = reaction.get_knockback()
			result.knocked = true
	result.ratio = 0.0 if result.full <= 0.0 else result.dealt / result.full
	result.flew_on = is_instance_valid(shell) and shell.visible and shell.is_physics_processing()
	enemy.free()
	if is_instance_valid(shell):
		shell.free()
	_clear()
	return result


## A dead-centre - or [param offset] off - shell at a one-hit-point enemy: how often
## he died, how many gore effects and pieces followed, and whether the death was
## credited to the shot's block.
func _kill_test(offset: float) -> Dictionary:
	var origin := Vector2(4000, 4000)
	var enemy := await _spawn_enemy(origin + Vector2(160, 0), 1.0)
	var pool := enemy.get_node(^"Health") as Health
	var stats := _def.get_stats()
	var result := {"deaths": 0, "gore": 0, "pieces": 0, "credited": false, "struck_killed": false}
	pool.died.connect(func() -> void:
		result.deaths += 1
		var effects := pool.get_last_hit_effects()
		result.credited = effects != null and effects.shot_stats == stats)
	var shell := _gun._release_pellet(_arena, stats, false, origin + Vector2(0, BODY_Y + offset), 0.0,
		false, null, null, _part) as CannonShell
	shell.struck.connect(func(_at: Vector2, _dir: Vector2, _c: float, killed: bool) -> void:
		result.struck_killed = killed)
	await _frames(20)
	for child: Node in _arena.get_children():
		if child is Explosion:
			result.gore += 1
		elif child is DeathDebris and child.name.begins_with("GorePiece"):
			result.pieces += 1
	if is_instance_valid(enemy):
		enemy.free()
	for child: Node in _arena.get_children():
		if child is Explosion or child is DeathDebris or child is Projectile:
			child.free()
	_clear()
	return result


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


# --- Helpers ---------------------------------------------------------------------

func _hit_detail(hit: Dictionary) -> String:
	return "centrality %.2f  dealt %.1f of %.1f  (%.0f%%)" % [hit.centrality, hit.dealt, hit.full, hit.ratio * 100.0]


func _ratios(hits: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for hit: Dictionary in hits:
		parts.append("d%.2f:%.0f%%" % [1.0 - hit.centrality, hit.ratio * 100.0])
	return " ".join(parts)


func _drawn(sprite: Sprite2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	return sprite.texture.get_size() * sprite.global_transform.get_scale().abs()


func _spawn_enemy(at: Vector2, health: float) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(health)
	await physics_frame
	await physics_frame
	return enemy


func _reaction(enemy: Node) -> HitReaction:
	return enemy.find_children("*", "HitReaction", true, false)[0] as HitReaction


## Rounds released after [param before] was taken, other than [param known] -
## collected the frame [param counter] first goes above 0, or after
## [param seconds] at most. Collected at once, since fast rounds are soon spent.
func _await_new(before: Array[Node], known: Array[Projectile], seconds: float,
		counter: Array) -> Array[Projectile]:
	var waited := 0.0
	while counter[0] == 0 and waited < seconds:
		await process_frame
		waited += 1.0 / 60.0
	var found: Array[Projectile] = []
	for child: Node in _arena.get_children():
		if child is Projectile and not before.has(child) and not known.has(child):
			found.append(child)
	return found


func _same_bonuses(a: WeaponStats, b: WeaponStats) -> bool:
	for stat: int in WeaponStats.Stat.values():
		if not is_equal_approx(a.get_bonus(stat as WeaponStats.Stat), b.get_bonus(stat as WeaponStats.Stat)):
			return false
	return is_equal_approx(a.base_critical_chance, b.base_critical_chance) \
		and is_equal_approx(a.base_critical_multiplier, b.base_critical_multiplier)


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
		if child is Projectile or child is FollowingParticles or child is ShotBlast \
				or child is CPUParticles2D or child is PressureWave or child is ProjectileTrail:
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


func _row_text(panel: WeaponDebugPanel, label: String) -> String:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if line is HBoxContainer and (line.get_child(0) as Label).text == label:
			return (line.get_child(1) as Label).text
	return ""


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("ONE BIG SHELL SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
