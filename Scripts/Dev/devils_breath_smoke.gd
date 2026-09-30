extends SceneTree
## Headless check of the shotgun's Legendary DEVIL'S BREATH: it is listed as a
## Legendary, the K panel switches it on and off, and while it is on every pellet
## explodes once where it lands, where it drops at the end of its range and against
## a wall - the direct hit unchanged, the blast its own damage through the enemy's
## Hitbox, each enemy caught once per blast - alongside DEVIL'S BARREL and a full
## BLOOD PUMP charge.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/devils_breath_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const PELLET_SCENE := "res://Scenes/Projectile/Projectile.tscn"

var _failures: int = 0
var _arena: Node2D
var _shotgun: WeaponDefinition
var _breath: WeaponLegendary
var _barrel: WeaponLegendary
var _pump: WeaponLegendary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_shotgun = session.get_weapon_catalog().find(&"shotgun")
	_shotgun.reset_upgrades()
	for legendary: WeaponLegendary in _shotgun.legendaries:
		match legendary.id:
			&"devils_breath": _breath = legendary
			&"devils_barrel": _barrel = legendary
			&"blood_pump": _pump = legendary

	print("--- the Legendary ---")
	_ok(_breath != null, "the shotgun lists DEVIL'S BREATH as a Legendary")
	if _breath == null:
		_finish()
		return
	var explosion := _breath.shot_explosion
	_ok(_shotgun.get_stats().shot_explosion == null, "off, the pellets are not explosive")
	_ok(is_equal_approx(explosion.get_damage(), 60.0), "each blast deals 30 x2 = 60",
		"%.1f" % explosion.get_damage())
	var probe := explosion.blast_scene.instantiate() as ShotBlast
	_ok(is_equal_approx(probe._factor(explosion.get_damage(), probe.reference_damage, probe.damage_influence), 1.0),
		"and the camera and flash weigh it as they did before")
	probe.free()

	print("--- the K panel ---")
	var panel := _make_panel()
	panel.open()
	_find_button(panel, "ON", "DEVIL'S BREATH").pressed.emit()
	_ok(_shotgun.is_legendary_active(_breath), "ON switches it on")
	_ok(_shotgun.get_stats().shot_explosion == explosion, "and the stats carry it at once")
	_ok(_readout(panel, "DEVIL'S BREATH").begins_with("ON"), "the row reads ON", _readout(panel, "DEVIL'S BREATH"))
	var settings := _explosion_readout(panel)
	_ok(settings.contains("RADIUS %.0f" % explosion.radius) and settings.contains("FALLOFF")
		and settings.contains("DIRECT HIT"), "the explosion settings are shown under it", settings)
	_find_button(panel, "OFF", "DEVIL'S BREATH").pressed.emit()
	_ok(not _shotgun.is_legendary_active(_breath) and _shotgun.get_stats().shot_explosion == null,
		"OFF switches it off at once")
	_ok(_readout(panel, "DEVIL'S BREATH").begins_with("OFF"), "the row reads OFF")
	panel.close()
	panel.free()
	paused = false

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var origin := Vector2(-3000, -3000)

	print("--- the real shotgun ---")
	_shotgun.set_legendary_active(_breath, true)
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = _shotgun
	_arena.add_child(gun)
	gun.global_position = origin
	gun._spawn_pellets()
	var pellets := _children(Projectile)
	_ok(pellets.size() == 6, "six pellets", str(pellets.size()))
	var armed := 0
	for pellet: Projectile in pellets:
		armed += 1 if pellet._explosion == explosion else 0
	_ok(armed == 6, "every one explosive", str(armed))
	_ok(_children(FollowingParticles).size() == 6, "each with a fiery trail")
	_ok(pellets[0]._tint_strength > 0.0, "and tinted")
	var pellet_up := _upgrade(&"pellet_count")
	_shotgun.set_run_level(pellet_up, 2)
	_clear()
	gun._spawn_pellets()
	_ok(_children(Projectile).size() > 6, "PELLET COUNT gives more explosive pellets", str(_children(Projectile).size()))
	_shotgun.set_run_level(pellet_up, 0)
	_clear()
	gun.free()

	print("--- a hit ---")
	# The flat checks run without falloff; falloff is checked on its own below.
	var authored_falloff := explosion.falloff
	explosion.falloff = 0.0
	_shotgun.set_legendary_active(_breath, false)
	var plain := await _hit_loss(origin, false)
	_shotgun.set_legendary_active(_breath, true)
	var loaded := await _hit_loss(origin, true)
	_ok(is_equal_approx(loaded["direct"], plain["direct"]), "the direct hit is unchanged",
		"%.2f vs %.2f" % [loaded["direct"], plain["direct"]])
	_ok(loaded["blasts"] == 1, "one blast for one hit", str(loaded["blasts"]))
	_ok(is_equal_approx(loaded["target"] - plain["target"], explosion.get_damage()),
		"the struck enemy takes the blast's own damage once on top",
		"%.2f extra" % (loaded["target"] - plain["target"]))
	_ok(is_equal_approx(loaded["neighbour"], explosion.get_damage()), "a neighbour inside the radius takes it once",
		"%.2f" % loaded["neighbour"])
	_ok(is_zero_approx(loaded["outside"]), "one outside the radius takes nothing", "%.2f" % loaded["outside"])
	_ok(loaded["knocked"], "and the blast shoves through the enemy's HitReaction")
	_ok(is_zero_approx(plain["neighbour"]), "off, the neighbour is untouched")

	print("--- the direct-hit toggle ---")
	explosion.direct_hit_takes_blast = false
	var spared := await _hit_loss(origin, true)
	explosion.direct_hit_takes_blast = true
	_ok(is_equal_approx(spared["target"], plain["target"]),
		"off, the struck enemy takes only the pellet's hit",
		"%.2f vs %.2f" % [spared["target"], plain["target"]])
	_ok(is_equal_approx(spared["neighbour"], explosion.get_damage()), "and the neighbour is still caught",
		"%.2f" % spared["neighbour"])

	print("--- falloff ---")
	explosion.falloff = 0.5
	var fallen := await _hit_loss(origin, true)
	_ok(fallen["neighbour"] < explosion.get_damage() and fallen["neighbour"] >= explosion.get_damage() * 0.5,
		"a neighbour away from the centre takes less, never below the edge share",
		"%.2f of %.2f" % [fallen["neighbour"], explosion.get_damage()])
	_ok(is_equal_approx(fallen["direct"], plain["direct"]), "and the direct hit is still unchanged")
	explosion.falloff = authored_falloff

	print("--- audio ---")
	var probe_blast := explosion.blast_scene.instantiate() as ShotBlast
	_ok(probe_blast.max_sounds_per_volley > 0 and probe_blast.max_sounds_per_volley < 6,
		"a volley's blasts are heard only up to a cap", str(probe_blast.max_sounds_per_volley))
	probe_blast.free()
	var shooter := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	shooter.definition = _shotgun
	_arena.add_child(shooter)
	shooter.global_position = origin
	var feedback := shooter.get_node_or_null(^"BreathFeedback") as DevilsBreathFeedback
	_ok(feedback != null and feedback.fire_layer_sound != null, "the shotgun carries the firing layer")
	var shots := [0]
	shooter.explosive_shot.connect(func() -> void: shots[0] += 1)
	var dry := [false]
	shooter.dry_fired.connect(func() -> void: dry[0] = true)
	shooter._try_fire()
	_ok(not dry[0] and _children(Projectile).size() >= 6 and shots[0] == 1,
		"one firing layer per shot, not per pellet",
		"dry %s, %d pellets, %d layers" % [dry[0], _children(Projectile).size(), shots[0]])
	_shotgun.set_legendary_active(_breath, false)
	shots[0] = 0
	shooter._set_state(Shotgun.State.READY)
	shooter._try_fire()
	_ok(shots[0] == 0, "off, no firing layer", str(shots[0]))
	_shotgun.set_legendary_active(_breath, true)
	shooter.free()
	_clear()

	print("--- the end of the range ---")
	var drop := _pellet(origin, 0.0)
	var reach := drop.get_effective_range()
	for i in 400:
		await physics_frame
		if not is_instance_valid(drop):
			break
	var dropped := _children(ShotBlast)
	_ok(dropped.size() == 1, "a pellet that hits nothing explodes once where it drops", str(dropped.size()))
	if dropped.size() == 1:
		_ok(absf((dropped[0] as Node2D).global_position.x - origin.x - reach) < 40.0, "at the end of its range",
			"%.0f of %.0f" % [(dropped[0] as Node2D).global_position.x - origin.x, reach])
	_clear()

	print("--- a wall ---")
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 400)
	shape.shape = rect
	wall.add_child(shape)
	_arena.add_child(wall)
	wall.global_position = origin + Vector2(150, 0)
	await physics_frame
	var walled := _pellet(origin, 0.0)
	for i in 60:
		await physics_frame
		if not is_instance_valid(walled):
			break
	var at_wall := _children(ShotBlast)
	_ok(at_wall.size() == 1, "a pellet explodes once against a wall", str(at_wall.size()))
	if at_wall.size() == 1:
		_ok(absf((at_wall[0] as Node2D).global_position.x - (origin.x + 140.0)) < 2.0, "at the wall's face",
			"%.1f" % ((at_wall[0] as Node2D).global_position.x - origin.x))
	wall.free()
	_clear()

	print("--- one blast, one catch ---")
	var walker := await _spawn_enemy(origin + Vector2(0, 4000))
	var walker_health := walker.get_node(^"Health") as Health
	var before := walker_health.get_current()
	explosion.falloff = 0.0
	explosion.detonate(_arena, origin, _shotgun.get_stats(), 2)
	explosion.falloff = authored_falloff
	await physics_frame
	walker.global_position = origin + Vector2(10, 0)
	for i in 10:
		await physics_frame
	_ok(is_equal_approx(before - walker_health.get_current(), explosion.get_damage()),
		"an enemy stepping into a live blast is caught, once", "%.2f" % (before - walker_health.get_current()))
	walker.free()
	_clear()

	print("--- with the other Legendaries ---")
	_shotgun.set_legendary_active(_barrel, true)
	var both := _shotgun.get_stats()
	_ok(both.shot_pattern == _barrel.shot_pattern and both.shot_explosion == explosion,
		"DEVIL'S BARREL keeps its pattern and the pellets stay explosive")
	_shotgun.set_legendary_active(_barrel, false)
	_shotgun.set_legendary_active(_pump, true)
	var full := _pump.pump_charge.charged_stats(_shotgun.get_stats(), _pump.pump_charge.max_charges)
	_ok(full.shot_explosion == explosion and full.pierce_bonus() > 0,
		"a full BLOOD PUMP charge pierces and is explosive")
	var first := await _spawn_enemy(origin + Vector2(60, 0))
	var second := await _spawn_enemy(origin + Vector2(160, 0))
	var lance := _pellet(origin, 0.0, full)
	for i in 30:
		await physics_frame
	var pierced := _children(ShotBlast).size()
	_ok(pierced >= 2, "and explodes on each body it passes through", str(pierced))
	if is_instance_valid(lance):
		lance.free()
	first.free()
	second.free()
	_shotgun.set_legendary_active(_pump, false)
	_clear()

	_shotgun.clear_run_levels()
	_ok(not _shotgun.is_legendary_active(_breath), "it is forgotten with the run levels")
	_shotgun.reset_upgrades()
	_finish()


## Fires one pellet at an enemy 80px off, with a neighbour 30px behind him along the line and one
## far off to the side, and reports what each lost.
func _hit_loss(origin: Vector2, _on: bool) -> Dictionary:
	var target := await _spawn_enemy(origin + Vector2(80, 0))
	var neighbour := await _spawn_enemy(origin + Vector2(110, 0))
	var outside := await _spawn_enemy(origin + Vector2(80, 400))
	var healths: Array[Health] = []
	var starts: Array[float] = []
	for enemy: Node2D in [target, neighbour, outside]:
		var health := enemy.get_node(^"Health") as Health
		healths.append(health)
		starts.append(health.get_current())
	var pellet := _pellet(origin, 0.0)
	var direct := [0.0]
	pellet.landed.connect(func(_hitbox: Hitbox) -> void: direct[0] = starts[0] - healths[0].get_current())
	var knocked := false
	for i in 20:
		await physics_frame
		var reaction := neighbour.find_children("*", "HitReaction", true, false)
		if not reaction.is_empty() and (reaction[0] as HitReaction).get_knockback() != Vector2.ZERO:
			knocked = true
	var result := {
		"direct": direct[0],
		"target": starts[0] - healths[0].get_current(),
		"neighbour": starts[1] - healths[1].get_current(),
		"outside": starts[2] - healths[2].get_current(),
		"blasts": _children(ShotBlast).size(),
		"knocked": knocked,
	}
	for enemy: Node2D in [target, neighbour, outside]:
		enemy.free()
	if is_instance_valid(pellet):
		pellet.free()
	_clear()
	return result


## One pellet armed from the shotgun's current stats - no critical roll, so a hit
## is the same every time - fired from [param at] along [param heading].
func _pellet(at: Vector2, heading: float, stats: WeaponStats = null) -> Projectile:
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	pellet.apply_weapon_stats(stats if stats != null else _shotgun.get_stats(), false)
	_arena.add_child(pellet)
	pellet.global_position = at
	pellet.global_rotation = heading
	return pellet


func _spawn_enemy(at: Vector2) -> Node2D:
	var enemy := (load("res://Scenes/Enemy/Enemy.tscn") as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(100000.0)
	await physics_frame
	await physics_frame
	return enemy


func _children(type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _arena.get_children():
		if is_instance_of(child, type):
			found.append(child)
	return found


func _clear() -> void:
	for child: Node in _arena.get_children():
		if child is Projectile or child is FollowingParticles or child is ShotBlast:
			child.free()


func _upgrade(id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in _shotgun.upgrades:
		if upgrade.id == id:
			return upgrade
	return null


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


func _row(panel: WeaponDebugPanel, name: String) -> HBoxContainer:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if line is HBoxContainer and (line.get_child(0) as Label).text == panel.legendary_prefix + name:
			return line
	return null


func _find_button(panel: WeaponDebugPanel, text: String, name: String) -> Button:
	var line := _row(panel, name)
	if line != null:
		for child: Node in line.get_children():
			if child is Button and child.text == text:
				return child
	return null


func _readout(panel: WeaponDebugPanel, name: String) -> String:
	var line := _row(panel, name)
	return "" if line == null else (line.get_child(1) as Label).text


func _explosion_readout(panel: WeaponDebugPanel) -> String:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if line is HBoxContainer and (line.get_child(0) as Label).text == panel.explosion_row_label:
			return (line.get_child(1) as Label).text
	return ""


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("DEVILS BREATH SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
