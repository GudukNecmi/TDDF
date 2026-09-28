extends SceneTree
## Headless check of the shotgun's Legendary FAN THE HAMMER: it is listed as a
## Legendary, the K panel switches it on and off and reads back right on reopening;
## off, Space with the trigger held is the ordinary half-stroke; on, it runs the
## whole cycle and the held trigger fires, each shot spending a real shell; heat
## widens the next shot's spread and slows the aim without touching the base
## spread, and drains again; and it stacks with the other Legendaries.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/fan_the_hammer_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"

var _failures: int = 0
var _arena: Node2D
var _shotgun: WeaponDefinition
var _fan: WeaponLegendary
var _others: Array[WeaponLegendary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_shotgun = session.get_weapon_catalog().find(&"shotgun")
	_shotgun.reset_upgrades()
	for legendary: WeaponLegendary in _shotgun.legendaries:
		if legendary.id == &"fan_the_hammer":
			_fan = legendary
		else:
			_others.append(legendary)

	print("--- the Legendary ---")
	_ok(_fan != null and _fan.fan_hammer != null, "the shotgun lists FAN THE HAMMER as a Legendary")
	if _fan == null:
		_finish()
		return
	_ok(_shotgun.get_stats().fan_hammer == null, "off, the stats carry no fan")

	print("--- the K panel ---")
	var panel := _make_panel()
	panel.open()
	_find_button(panel, "ON", "FAN THE HAMMER").pressed.emit()
	_ok(_shotgun.is_legendary_active(_fan) and _shotgun.get_stats().fan_hammer == _fan.fan_hammer, "ON switches it on")
	_ok(_readout(panel, "FAN THE HAMMER").begins_with("ON"), "the row reads ON")
	panel.close()
	panel.open()
	_ok(_readout(panel, "FAN THE HAMMER").begins_with("ON"), "reopened, it still reads ON")
	_find_button(panel, "OFF", "FAN THE HAMMER").pressed.emit()
	_ok(not _shotgun.is_legendary_active(_fan) and _shotgun.get_stats().fan_hammer == null, "OFF switches it off")
	panel.close()
	panel.open()
	_ok(_readout(panel, "FAN THE HAMMER").begins_with("OFF"), "reopened, it reads OFF")
	panel.close()
	panel.free()
	paused = false

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = _shotgun
	_arena.add_child(gun)
	gun.global_position = Vector2(-3000, -3000)
	await process_frame
	var ammo := gun.get_ammo()
	var shots := [0]
	gun.fired.connect(func() -> void: shots[0] += 1)
	var fanned := [0]
	gun.fanned_shot.connect(func(_heat: float) -> void: fanned[0] += 1)

	print("--- off: exactly as before ---")
	Input.action_press(&"fire")
	gun._try_fire()
	_pump(gun)
	_ok(gun._state == Shotgun.State.PUMP_BACK, "Space with the trigger held is still only the back stroke")
	await _wait(0.2)
	_ok(shots[0] == 1 and fanned[0] == 0, "and nothing fires", "%d shots" % shots[0])
	_pump(gun)
	_ok(gun._state == Shotgun.State.READY, "the second press closes it")
	Input.action_release(&"fire")

	print("--- on: fire, Space, fire ---")
	_shotgun.set_legendary_active(_fan, true)
	gun.reload_to_ready()
	var start := ammo.get_current()
	var base_spread := gun.get_spread_degrees()
	Input.action_press(&"fire")
	gun._try_fire()
	_ok(ammo.get_current() == start - 1, "the first shot spends a shell")
	for i in 3:
		_pump(gun)
		await _wait(0.1)
	_ok(shots[0] == 5 and fanned[0] == 3, "each Space fires one fanned shot", "%d shots, %d fanned" % [shots[0], fanned[0]])
	_ok(ammo.get_current() == start - 4, "and each one spends a real shell", "%d of %d" % [ammo.get_current(), start])
	_ok(gun.get_fan_heat() > 0.9, "three in a row is full heat", "%.2f" % gun.get_fan_heat())
	_ok(gun.get_spread_degrees() > base_spread * 1.2, "the next shot is wider",
		"%.1f vs %.1f" % [gun.get_spread_degrees(), base_spread])
	_ok(is_equal_approx(_shotgun.get_stats().spread_scale(), 1.0), "but the weapon's own spread is untouched")
	_ok(gun.aim_scale < 0.6, "and the aim is slowed", "%.2f" % gun.aim_scale)
	Input.action_release(&"fire")
	_pump(gun)
	_ok(gun._state == Shotgun.State.PUMP_BACK, "trigger released, Space is the ordinary half-stroke again")
	_pump(gun)
	await _wait(0.6)
	_ok(is_zero_approx(gun.get_fan_heat()) and is_equal_approx(gun.aim_scale, 1.0), "heat drains once firing stops")
	_ok(is_equal_approx(gun.get_spread_degrees(), base_spread), "and the spread is back")

	print("--- no free shells ---")
	Input.action_press(&"fire")
	while ammo.get_current() > 0:
		gun._try_fire()
		_pump(gun)
		await _wait(0.06)
	var before: int = shots[0]
	var clicks := [0]
	gun.dry_fired.connect(func() -> void: clicks[0] += 1)
	_pump(gun)
	await _wait(0.1)
	_ok(shots[0] == before and clicks[0] >= 1, "dry, a fanned stroke only clicks")
	Input.action_release(&"fire")
	var locker := root.get_node_or_null(^"Ammo") as AmmoLocker
	if locker != null and locker.has_method(&"refill_all"):
		locker.call(&"refill_all")

	print("--- with the other Legendaries ---")
	for other: WeaponLegendary in _others:
		_shotgun.set_legendary_active(other, true)
	var stats := _shotgun.get_stats()
	_ok(stats.fan_hammer != null and stats.shot_pattern != null and stats.pump_charge != null and stats.shot_explosion != null,
		"all four parts sit in the one block")
	var hot := _fan.fan_hammer.unsteady_stats(stats, 1.0)
	_ok(hot.shot_pattern == stats.shot_pattern and hot.shot_explosion == stats.shot_explosion and hot.pump_charge == stats.pump_charge,
		"a hot shot keeps the other Legendaries' parts")
	_shotgun.set_legendary_active(_fan, false)
	for other: WeaponLegendary in _others:
		_shotgun.set_legendary_active(other, false)

	gun.free()
	_shotgun.clear_run_levels()
	_ok(not _shotgun.is_legendary_active(_fan), "it is forgotten with the run levels")
	_shotgun.reset_upgrades()
	_finish()


func _pump(gun: Shotgun) -> void:
	var event := InputEventAction.new()
	event.action = &"pump"
	event.pressed = true
	gun._weapon_input(event)


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
	print("FAN THE HAMMER SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
