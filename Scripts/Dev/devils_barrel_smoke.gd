extends SceneTree
## Headless check of the shotgun's Legendary DEVIL'S BARREL: it is listed as a
## Legendary and in no upgrade pool, the K panel switches it on and off, and while
## it is on the real shotgun's pellets leave along the aim in a widened cone, fly
## slower, weave, trail particles and curve onto the nearest enemy - with the same
## count and the same damage as without it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/devils_barrel_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"

var _failures: int = 0
var _arena: Node2D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	var shotgun := session.get_weapon_catalog().find(&"shotgun")
	shotgun.reset_upgrades()

	print("--- the Legendary ---")
	var barrel: WeaponLegendary = null
	for legendary: WeaponLegendary in shotgun.legendaries:
		if legendary.id == &"devils_barrel":
			barrel = legendary
	_ok(barrel != null, "the shotgun lists DEVIL'S BARREL as a Legendary")
	if barrel == null:
		_finish()
		return
	var in_pool := false
	for upgrade: WeaponUpgrade in shotgun.upgrades:
		in_pool = in_pool or upgrade.id == barrel.id
	_ok(not in_pool, "and not among the upgrades the Base, markets and rewards deal from")
	_ok(shotgun.get_stats().shot_pattern == null, "off, the shotgun has no shot pattern")

	print("--- the K panel ---")
	var panel := _make_panel()
	panel.open()
	var on := _button(panel, "ON")
	var off := _button(panel, "OFF", true)
	_ok(on != null and off != null, "the Legendary row has ON and OFF")
	on.pressed.emit()
	_ok(shotgun.is_legendary_active(barrel), "ON switches it on")
	_ok(shotgun.get_stats().shot_pattern == barrel.shot_pattern, "and the weapon's stats carry its pattern at once")
	panel.close()
	panel.open()
	_ok(_legendary_readout(panel).begins_with("ON"), "reopened, the panel reads ON", _legendary_readout(panel))
	panel.close()
	paused = false

	print("--- the real shotgun ---")
	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = shotgun
	_arena.add_child(gun)
	gun.global_position = Vector2(-3000, -3000)
	gun.global_rotation = 0.0

	var accuracy := _upgrade(shotgun, &"accuracy")
	var pellets_up := _upgrade(shotgun, &"pellet_count")
	shotgun.set_run_level(accuracy, accuracy.max_level)
	var aimed := _fire(gun)
	var multiplier := barrel.shot_pattern.spread_multiplier
	_ok(aimed["widest"] <= gun.get_spread_degrees() * multiplier + 0.01,
		"with ACCURACY maxed the cone is %.1fx the tightened spread" % multiplier,
		"%.1f deg of %.1f" % [aimed["widest"], gun.get_spread_degrees() * multiplier])
	_clear(aimed)
	shotgun.set_run_level(accuracy, 0)
	var wild := _fire(gun)
	_ok(wild["pellets"].size() == 6, "six pellets by default", str(wild["pellets"].size()))
	_ok(wild["trails"] == 6, "each with its own trail", str(wild["trails"]))
	_ok(wild["widest"] <= gun.spread_angle_degrees * multiplier + 0.01,
		"all leave along the aim, inside %.1fx the normal cone" % multiplier,
		"%.1f deg of %.1f" % [wild["widest"], gun.spread_angle_degrees * multiplier])
	var widest_drawn := 0.0
	for i in 2000:
		widest_drawn = maxf(widest_drawn, absf(barrel.shot_pattern.heading(0.0, deg_to_rad(6.0))))
	_ok(rad_to_deg(widest_drawn) > 6.0 * multiplier * 0.97 and rad_to_deg(widest_drawn) <= 6.0 * multiplier,
		"a 12 deg cone is drawn out to 24 deg", "half cone %.2f deg" % rad_to_deg(widest_drawn))
	shotgun.set_run_level(pellets_up, 2)
	var more := _fire(gun)
	_ok(more["pellets"].size() == 6 + 2 * roundi(pellets_up.modifiers_per_level[0].amount),
		"the PELLET COUNT upgrade still sets how many", str(more["pellets"].size()))
	_clear(more)
	shotgun.set_run_level(pellets_up, 0)

	var wild_flight := await _fly(wild["pellets"])
	_clear(wild)

	barrel_off(shotgun, barrel, panel)
	var tame := _fire(gun)
	_ok(tame["trails"] == 0, "OFF: no trails")
	_ok(tame["widest"] <= gun.spread_angle_degrees + 0.01, "OFF: back inside the cone",
		"%.1f deg" % tame["widest"])
	var tame_flight := await _fly(tame["pellets"])
	_clear(tame)

	var ratio: float = wild_flight["speed"] / maxf(tame_flight["speed"], 0.001)
	_ok(absf(ratio - barrel.shot_pattern.speed_scale) < 0.08, "Devil's Barrel pellets fly slower",
		"x%.2f" % ratio)
	_ok(wild_flight["drift"] > 3.0, "and weave off their heading", "%.1f px" % wild_flight["drift"])
	_ok(tame_flight["drift"] < 0.01, "while normal pellets fly straight", "%.2f px" % tame_flight["drift"])

	print("--- tracking ---")
	var pattern := barrel.shot_pattern
	var origin := Vector2(-3000, -3000)
	# Fired side-on to an enemy 260px away - a turn the earlier, gentler tracking
	# could not make.
	var near := await _spawn_enemy(origin + Vector2(260, 0))
	var pellet := _pellet(pattern, origin, PI * 0.5)
	var hits: Array[Node] = []
	pellet.landed.connect(func(hitbox: Hitbox) -> void: hits.append(hitbox.owner))
	var cap := deg_to_rad(pattern.tracking_max_angle_per_update)
	var worst_turn := 0.0
	var last := pellet.global_rotation
	var turned_towards := false
	for i in 240:
		await physics_frame
		if not is_instance_valid(pellet) or not pellet.visible:
			break
		worst_turn = maxf(worst_turn, absf(angle_difference(last, pellet.global_rotation)))
		var bearing := (near.global_position - pellet.global_position).angle()
		turned_towards = turned_towards or absf(angle_difference(pellet.global_rotation, bearing)) \
			< absf(angle_difference(last, bearing)) - 0.0001
		last = pellet.global_rotation
	_ok(turned_towards, "a pellet fired wide of an enemy curves towards it")
	_ok(worst_turn <= cap + 0.0001, "never turning more than the per-update cap",
		"%.2f deg max, cap %.2f" % [rad_to_deg(worst_turn), pattern.tracking_max_angle_per_update])
	_ok(hits == [near], "and lands on it", str(hits))

	var far := await _spawn_enemy(origin + Vector2(0, -560))
	near.global_position = origin + Vector2(0, 5000)
	await physics_frame
	var switcher := _pellet(pattern, origin, 0.0)
	for i in 3:
		await physics_frame
	_ok(switcher._home_target == far, "with one enemy in reach it tracks that one")
	near.global_position = origin + Vector2(80, 120)
	for i in 12:
		await physics_frame
	_ok(is_instance_valid(switcher) and switcher._home_target == near,
		"and switches when a closer one appears")
	if is_instance_valid(switcher):
		switcher.free()
	near.free()
	far.free()
	await physics_frame
	var loner := _pellet(pattern, origin, 1.0)
	for i in 10:
		await physics_frame
	_ok(is_instance_valid(loner) and is_equal_approx(loner.global_rotation, 1.0),
		"with nobody in reach it keeps its own heading")
	if is_instance_valid(loner):
		loner.free()

	print("--- damage ---")
	shotgun.set_legendary_active(barrel, true)
	var probe_on := (load("res://Scenes/Projectile/Projectile.tscn") as PackedScene).instantiate() as Projectile
	probe_on.apply_weapon_stats(shotgun.get_stats())
	shotgun.set_legendary_active(barrel, false)
	var probe_off := (load("res://Scenes/Projectile/Projectile.tscn") as PackedScene).instantiate() as Projectile
	probe_off.apply_weapon_stats(shotgun.get_stats())
	_ok(is_equal_approx(probe_on.damage_at_progress(0.3), probe_off.damage_at_progress(0.3)),
		"it adds no damage of its own")
	probe_on.free()
	probe_off.free()

	shotgun.set_legendary_active(barrel, true)
	shotgun.clear_run_levels()
	_ok(not shotgun.is_legendary_active(barrel), "and it is forgotten with the run levels")

	gun.free()
	panel.free()
	shotgun.reset_upgrades()
	_finish()


func barrel_off(shotgun: WeaponDefinition, barrel: WeaponLegendary, panel: WeaponDebugPanel) -> void:
	panel.open()
	_button(panel, "OFF", true).pressed.emit()
	_ok(not shotgun.is_legendary_active(barrel), "OFF switches it off")
	panel.close()
	panel.open()
	_ok(_legendary_readout(panel).begins_with("OFF"), "reopened, the panel reads OFF", _legendary_readout(panel))
	panel.close()
	paused = false


## Spawns one blast and reports its pellets, trails and widest heading off the aim.
func _fire(gun: Shotgun) -> Dictionary:
	var before := _arena.get_children()
	gun._spawn_pellets()
	var pellets: Array[Projectile] = []
	var trails := 0
	var widest := 0.0
	for child: Node in _arena.get_children():
		if before.has(child):
			continue
		if child is Projectile:
			pellets.append(child)
			widest = maxf(widest, absf(rad_to_deg(angle_difference(gun.global_rotation, child.global_rotation))) * 2.0)
		elif child is FollowingParticles:
			trails += 1
	return {"pellets": pellets, "trails": trails, "widest": widest}


## Flies [param pellets] a few ticks and reports their mean speed along their
## heading and the furthest any strayed sideways off it.
func _fly(pellets: Array) -> Dictionary:
	var starts: Array[Vector2] = []
	for pellet: Projectile in pellets:
		starts.append(pellet.global_position)
	# The first awaited tick can land before the pellets step, so the speed is
	# measured over the next one, still close to the muzzle for both kinds.
	await physics_frame
	var marks: Array[Vector2] = []
	for pellet: Projectile in pellets:
		marks.append(pellet.global_position if is_instance_valid(pellet) else Vector2.ZERO)
	await physics_frame
	var along := 0.0
	var counted := 0
	for i in pellets.size():
		var pellet: Projectile = pellets[i]
		if is_instance_valid(pellet):
			along += (pellet.global_position - marks[i]).dot(pellet.transform.x.normalized())
			counted += 1
	for i in 14:
		await physics_frame
	var drift := 0.0
	for i in pellets.size():
		var pellet: Projectile = pellets[i]
		if is_instance_valid(pellet):
			var moved := pellet.global_position - starts[i]
			drift = maxf(drift, absf(moved.dot(pellet.transform.y.normalized())))
	return {"speed": along / maxi(counted, 1), "drift": drift}


## One Devil's Barrel pellet, fired from [param at] along [param heading].
func _pellet(pattern: ShotPattern, at: Vector2, heading: float) -> Projectile:
	var pellet := (load("res://Scenes/Projectile/Projectile.tscn") as PackedScene).instantiate() as Projectile
	pattern.prepare(pellet)
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


func _clear(blast: Dictionary) -> void:
	for pellet: Projectile in blast["pellets"]:
		if is_instance_valid(pellet):
			pellet.free()
	for child: Node in _arena.get_children():
		if child is FollowingParticles:
			child.free()


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


## The Legendary row's button reading [param text] - the last such button in the
## panel when [param last], since common upgrade rows have an OFF too.
func _button(panel: WeaponDebugPanel, text: String, last: bool = false) -> Button:
	var found: Button = null
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		# DEVIL'S BARREL's own row: the shotgun carries more than one Legendary.
		if not (line is HBoxContainer) or not (line.get_child(0) as Label).text.begins_with(panel.legendary_prefix + "DEVIL'S BARREL"):
			continue
		for child: Node in line.get_children():
			if child is Button and child.text == text:
				found = child
				if not last:
					return found
	return found


func _legendary_readout(panel: WeaponDebugPanel) -> String:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if line is HBoxContainer and (line.get_child(0) as Label).text.begins_with(panel.legendary_prefix):
			return (line.get_child(1) as Label).text
	return ""


func _upgrade(weapon: WeaponDefinition, id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("DEVILS BARREL SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
