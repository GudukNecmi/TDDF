extends SceneTree
## Headless check of the shotgun's Legendary RECOIL DEVIL: it is listed as a
## Legendary, the K panel switches it on and off and reads back right on reopening;
## off, a shot leaves the player where they stand; on, each shot throws the real
## player straight away from the aim, once per shot however many pellets, chained
## shots never pass the ceiling, the shove dies away, a wall stops it; and it
## stacks with the other Legendaries without touching their parts.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/recoil_devil_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const PLAYER_SCENE := "res://Scenes/Player/Player.tscn"

var _failures: int = 0
var _arena: Node2D
var _shotgun: WeaponDefinition
var _devil: WeaponLegendary
var _others: Array[WeaponLegendary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_shotgun = session.get_weapon_catalog().find(&"shotgun")
	_shotgun.reset_upgrades()
	for legendary: WeaponLegendary in _shotgun.legendaries:
		if legendary.id == &"recoil_devil":
			_devil = legendary
		else:
			_others.append(legendary)

	print("--- the Legendary ---")
	_ok(_devil != null and _devil.shot_recoil != null, "the shotgun lists RECOIL DEVIL as a Legendary")
	if _devil == null:
		_finish()
		return
	_ok(_shotgun.get_stats().shot_recoil == null, "off, the stats carry no recoil")

	print("--- the K panel ---")
	var panel := _make_panel()
	panel.open()
	_find_button(panel, "ON", "RECOIL DEVIL").pressed.emit()
	_ok(_shotgun.is_legendary_active(_devil) and _shotgun.get_stats().shot_recoil == _devil.shot_recoil, "ON switches it on")
	_ok(_readout(panel, "RECOIL DEVIL").begins_with("ON"), "the row reads ON")
	panel.close()
	panel.open()
	_ok(_readout(panel, "RECOIL DEVIL").begins_with("ON"), "reopened, it still reads ON")
	_find_button(panel, "OFF", "RECOIL DEVIL").pressed.emit()
	_ok(not _shotgun.is_legendary_active(_devil) and _shotgun.get_stats().shot_recoil == null, "OFF switches it off")
	panel.close()
	panel.open()
	_ok(_readout(panel, "RECOIL DEVIL").begins_with("OFF"), "reopened, it reads OFF")
	panel.close()
	panel.free()
	paused = false

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody2D
	_arena.add_child(player)
	player.global_position = Vector2.ZERO
	var recoil := player.get_node(^"Recoil") as PlayerRecoil
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = _shotgun
	gun.target_path = NodePath("../" + String(player.name))
	_arena.add_child(gun)
	await _wait(0.3)
	var shots := [0]
	gun.fired.connect(func() -> void: shots[0] += 1)
	var kicks := [0]
	gun.recoil_kicked.connect(func(_push: Vector2, _holder: Node2D) -> void: kicks[0] += 1)

	print("--- off: exactly as before ---")
	var start := player.global_position
	_fire(gun, 0.0)
	await _wait(0.3)
	_ok(shots[0] == 1 and kicks[0] == 0, "the shot fires and kicks nothing")
	_ok(player.global_position.distance_to(start) < 1.0 and not recoil.is_recoiling(),
		"the player stays where they stood", str(player.global_position - start))

	print("--- on: aim right, pushed left ---")
	_shotgun.set_legendary_active(_devil, true)
	start = player.global_position
	_fire(gun, 0.0)
	_ok(kicks[0] == 1, "one kick for a shot of %d pellets" % gun.get_pellet_count())
	_ok(recoil.get_recoil_velocity().x < -500.0 and absf(recoil.get_recoil_velocity().y) < 1.0,
		"the push is straight left", str(recoil.get_recoil_velocity()))
	await _wait(0.2)
	var moved := player.global_position - start
	_ok(moved.x < -60.0, "the real body is carried left", str(moved))
	await _wait(1.0)
	_ok(not recoil.is_recoiling(), "the shove dies away")

	print("--- aim up-right, pushed down-left ---")
	_fire(gun, -PI / 4.0)
	var v := recoil.get_recoil_velocity()
	_ok(v.x < 0.0 and v.y > 0.0 and absf(absf(v.x) - absf(v.y)) < 1.0, "the push is down-left", str(v))
	await _wait(1.2)

	print("--- chained shots stay under the ceiling ---")
	var ceiling := _devil.shot_recoil.max_recoil_velocity
	for i in 8:
		_fire(gun, 0.0)
	_ok(recoil.get_recoil_velocity().length() <= ceiling + 0.5, "eight shots in a row never pass %d" % ceiling,
		"%.0f" % recoil.get_recoil_velocity().length())
	_ok(recoil.get_recoil_velocity().length() > _devil.shot_recoil.recoil_impulse, "but they do build")
	await _wait(1.5)

	print("--- a wall stops it ---")
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 2000)
	shape.shape = box
	wall.add_child(shape)
	_arena.add_child(wall)
	wall.collision_layer = player.collision_mask
	wall.global_position = player.global_position + Vector2(-90, 0)
	var wall_face := wall.global_position.x + 20.0
	await _wait(0.1)
	for i in 6:
		_fire(gun, 0.0)
		await _wait(0.05)
	await _wait(0.3)
	_ok(player.global_position.x > wall_face, "the player is still on their side of the wall",
		"x %.1f, wall face %.1f" % [player.global_position.x, wall_face])
	_ok(not recoil.is_recoiling() or recoil.get_recoil_velocity().x > -1.0, "and the push into it is spent")
	wall.free()
	await _wait(1.0)

	print("--- with the other Legendaries ---")
	for other: WeaponLegendary in _others:
		_shotgun.set_legendary_active(other, true)
	var stats := _shotgun.get_stats()
	_ok(stats.shot_recoil != null and stats.fan_hammer != null and stats.shot_pattern != null \
		and stats.pump_charge != null and stats.shot_explosion != null, "all five parts sit in the one block")
	_ok(stats.duplicate_stats().shot_recoil == stats.shot_recoil, "a charged or hot shot keeps the recoil")
	var before_kicks: int = kicks[0]
	_fire(gun, PI)
	_ok(kicks[0] == before_kicks + 1 and recoil.get_recoil_velocity().x > 0.0,
		"aimed left with everything on, one kick to the right", str(recoil.get_recoil_velocity()))
	await _wait(0.4)
	_shotgun.set_legendary_active(_devil, false)
	before_kicks = kicks[0]
	_fire(gun, 0.0)
	_ok(kicks[0] == before_kicks, "Recoil Devil off again, the others fire without a kick")
	for other: WeaponLegendary in _others:
		_shotgun.set_legendary_active(other, false)

	gun.free()
	player.free()
	_shotgun.clear_run_levels()
	_ok(not _shotgun.is_legendary_active(_devil), "it is forgotten with the run levels")
	_shotgun.reset_upgrades()
	_finish()


## One shot along [param angle], from a ready and loaded gun.
func _fire(gun: Shotgun, angle: float) -> void:
	var locker := root.get_node_or_null(^"Ammo") as AmmoLocker
	if locker != null and locker.has_method(&"refill_all"):
		locker.call(&"refill_all")
	gun.reload_to_ready()
	gun.global_rotation = angle
	gun._try_fire()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


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


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("RECOIL DEVIL SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
