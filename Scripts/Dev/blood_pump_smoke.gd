extends SceneTree
## Headless check of the shotgun's Legendary BLOOD PUMP: it is listed as a
## Legendary and in no upgrade pool; off, the pump behaves exactly as before; on,
## each full cycle banks one charge up to five, a charged shot carries more damage,
## range and spread through the ordinary stats and spends the charge, the common
## upgrades still stack with it, and the K panel reads, resets and switches it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/blood_pump_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"

var _failures: int = 0
var _arena: Node2D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	var def := session.get_weapon_catalog().find(&"shotgun")
	def.reset_upgrades()

	print("--- the Legendary ---")
	var pump: WeaponLegendary = null
	for legendary: WeaponLegendary in def.legendaries:
		if legendary.id == &"blood_pump":
			pump = legendary
	_ok(pump != null and pump.pump_charge != null, "the shotgun lists BLOOD PUMP with a pump charge")
	if pump == null:
		_finish()
		return
	var in_pool := false
	for upgrade: WeaponUpgrade in def.upgrades:
		in_pool = in_pool or upgrade.id == pump.id
	_ok(not in_pool, "and not among the upgrades the Base, markets and rewards deal from")

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var view := CameraController.new()
	_arena.add_child(view)
	view.make_current()
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = def
	_arena.add_child(gun)
	await process_frame
	var ammo := gun.get_ammo()
	if ammo != null and ammo.get_reserve() != null:
		ammo.get_reserve().fill()
	var feedback := gun.get_node(^"Feedback") as ShotgunFeedback
	var camera := gun.get_node(^"Camera") as WeaponCamera

	print("--- off: the ordinary pump ---")
	var rounds := _rounds(ammo)
	_pump(gun)
	_ok(_rounds(ammo) == rounds - gun.rounds_lost_on_eject, "working a loaded gun still throws the live round", "%d -> %d" % [rounds, _rounds(ammo)])
	_pump(gun)
	_ok(gun.get_pump_charge() == 0, "and banks no charge")
	_ok(gun.get_stage_label().is_empty() and gun.get_charge_ratio() == 0.0, "the readout and the sight stay blank")

	print("--- on: charging ---")
	def.set_legendary_active(pump, true)
	gun.reload_to_ready()
	rounds = _rounds(ammo)
	var ejected := [0]
	gun.shell_ejected.connect(func() -> void: ejected[0] += 1)
	for i in 5:
		_pump(gun)
		_pump(gun)
		_ok(gun.get_pump_charge() == i + 1, "cycle %d banks charge %d" % [i + 1, i + 1], str(gun.get_pump_charge()))
		_ok(is_equal_approx(feedback.pump_pitch, 1.0 + 0.045 * (i + 1)), "and the pump pitch rises", str(feedback.pump_pitch))
	_ok(_rounds(ammo) == rounds and ejected[0] == 0, "charging costs no round and throws no shell")
	_ok(feedback.pump_bus == &"BloodPump", "the pump goes through the echo bus while charged")
	_pump(gun)
	_pump(gun)
	_ok(gun.get_pump_charge() == 5, "a sixth cycle does not pass MAX")
	_ok(gun.get_stage_label() == "MAX CHARGE" and gun.get_charge_ratio() == 1.0, "the readout says MAX CHARGE", gun.get_stage_label())
	await _frames(40)
	_ok(camera.get_hold_zoom() > 1.4, "the view has crept in towards 1.1^5", "%.3f" % camera.get_hold_zoom())
	_ok(gun.handling_scale < 0.8, "and the gun handles heavier", "%.3f" % gun.handling_scale)

	print("--- the charged shot ---")
	var plain := def.get_stats()
	var charged := gun._shot_stats()
	_ok(charged != plain, "a charged shot is armed from its own copy of the stats")
	_ok(charged.damage_scale_at(0.0) > plain.damage_scale_at(0.0) * 1.8, "with more close damage", "%.2f vs %.2f" % [charged.damage_scale_at(0.0), plain.damage_scale_at(0.0)])
	_ok(charged.damage_scale_at(1.0) > plain.damage_scale_at(1.0) * 1.8, "with more long damage", "%.2f vs %.2f" % [charged.damage_scale_at(1.0), plain.damage_scale_at(1.0)])
	_ok(charged.range_scale() > plain.range_scale(), "further range", "%.2f" % charged.range_scale())
	_ok(gun.get_spread_degrees() > gun.spread_angle_degrees, "and a wider cone", "%.1f" % gun.get_spread_degrees())
	_ok(charged.pierce_bonus() == 4, "at MAX every pellet is armed to pierce", str(charged.pierce_bonus()))
	_ok(charged.shot_pattern == pump.pump_charge.max_charge_pattern, "and wears the piercing look")
	_ok(plain.get_bonus(WeaponStats.Stat.DAMAGE) == 0.0, "the weapon's own stats are untouched")

	var released := [0]
	gun.charge_released.connect(func(c: int) -> void: released[0] = c)
	var before := _arena.get_children()
	gun._try_fire()
	var pellets: Array[Projectile] = []
	for child: Node in _arena.get_children():
		if not before.has(child) and child is Projectile:
			pellets.append(child)
	_ok(released[0] == 5, "firing announces the five charges it spent")
	_ok(pellets.size() == gun.pellet_count, "the ordinary number of pellets leave", str(pellets.size()))
	_ok(pellets.size() > 0 and pellets[0].get_effective_range() > pellets[0].profile.effective_range * 1.3, "and they fly further")
	var piercing := pellets.size() > 0
	for pellet: Projectile in pellets:
		piercing = piercing and pellet.get_pierces_left() == 4
	_ok(piercing, "every pellet that left carries 4 pierces")
	_ok(gun.get_pump_charge() == 0, "the shot spends all the charge")
	_ok(is_equal_approx(feedback.pump_pitch, 1.0) and feedback.pump_bus.is_empty(), "and the pump sound is back to normal")
	await create_timer(1.5).timeout
	_ok(camera.get_hold_zoom() < 1.1, "the view eases home", "%.3f" % camera.get_hold_zoom())
	for pellet: Projectile in pellets:
		if is_instance_valid(pellet):
			pellet.free()

	print("--- firing early ---")
	_pump(gun)
	_pump(gun)
	_pump(gun)
	_pump(gun)
	_ok(gun.get_pump_charge() == 2, "reload after the shot plus one more cycle is charge 2")
	var two := gun._shot_stats().get_bonus(WeaponStats.Stat.DAMAGE)
	_ok(two > 0.0 and two < charged.get_bonus(WeaponStats.Stat.DAMAGE), "charge 2 is worth less than MAX", "%.2f" % two)
	_ok(gun._shot_stats().pierce_bonus() == 0 and gun._shot_stats().shot_pattern == null, "and does not pierce")
	released[0] = 0
	gun._try_fire()
	_ok(released[0] == 2 and gun.get_pump_charge() == 0, "and can be fired without reaching MAX")

	print("--- common upgrades stack ---")
	var damage := _upgrade(def, &"damage")
	def.set_run_level(damage, 3)
	_pump(gun)
	_pump(gun)
	var stacked := gun._shot_stats().get_bonus(WeaponStats.Stat.DAMAGE)
	_ok(is_equal_approx(stacked, def.get_stats().get_bonus(WeaponStats.Stat.DAMAGE) + pump.pump_charge.weight(1) * 0.16), "the damage upgrade and the charge add together", "%.3f" % stacked)
	_ok(gun.get_pump_charge() == 1, "and an upgrade bought mid-charge keeps the charge")
	def.set_run_level(damage, 0)

	print("--- spread grows every charge, accuracy or not ---")
	var accuracy := _upgrade(def, &"accuracy")
	def.set_run_level(accuracy, accuracy.max_level)
	gun.reset_pump_charge()
	var cones: Array[float] = [gun.get_spread_degrees()]
	for i in 5:
		_pump(gun)
		_pump(gun)
		cones.append(gun.get_spread_degrees())
	var widening := true
	for i in 5:
		widening = widening and cones[i + 1] > cones[i] + 1.0
	_ok(widening, "every pump widens the cone with ACCURACY maxed", str(cones))
	var spread_step := 0.0
	for modifier: WeaponStatModifier in pump.pump_charge.per_charge:
		if modifier.stat == WeaponStats.Stat.SPREAD:
			spread_step += modifier.amount
	_ok(is_equal_approx(cones[5] - cones[0], gun.spread_angle_degrees * pump.pump_charge.weight(5) * spread_step), "and accuracy takes none of the widening back", "%.1f -> %.1f" % [cones[0], cones[5]])
	def.set_run_level(accuracy, 0)
	gun.reset_pump_charge()
	_pump(gun)
	_pump(gun)

	print("--- the K panel ---")
	var mount := WeaponMount.new()
	_arena.add_child(mount)
	mount.set(&"_weapon", gun)
	var panel := _make_panel()
	panel.open()
	_ok(_charge_readout(panel).begins_with("CHARGE 1 / 5"), "the panel reads the live charge", _charge_readout(panel))
	var reset := _find_button(panel, "RESET CHARGE")
	_ok(reset != null, "and has RESET CHARGE")
	if reset != null:
		reset.pressed.emit()
	_ok(gun.get_pump_charge() == 0 and _charge_readout(panel).begins_with("CHARGE 0 / 5"), "which drops the charge", _charge_readout(panel))
	panel.close()
	paused = false
	_pump(gun)
	_pump(gun)
	_pump(gun)
	_pump(gun)
	_ok(gun.get_pump_charge() == 2, "charged again")
	panel.open()
	var off := _find_button(panel, "OFF", "BLOOD PUMP")
	_ok(off != null, "BLOOD PUMP has its own OFF")
	if off != null:
		off.pressed.emit()
	_ok(not def.is_legendary_active(pump), "OFF switches it off")
	_ok(gun.get_pump_charge() == 0, "and takes the charge with it at once")
	panel.close()
	paused = false
	rounds = _rounds(ammo)
	gun.reload_to_ready()
	_pump(gun)
	_ok(_rounds(ammo) == rounds - gun.rounds_lost_on_eject, "the pump is back to the ordinary one")
	_pump(gun)
	_ok(gun.get_pump_charge() == 0, "and banks nothing")

	def.set_legendary_active(pump, true)
	def.clear_run_levels()
	_ok(not def.is_legendary_active(pump), "it is forgotten with the run levels")

	_finish()


func _pump(gun: Shotgun) -> void:
	gun._try_pump()


func _rounds(ammo: WeaponAmmo) -> int:
	return -1 if ammo == null else ammo.get_current()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _upgrade(weapon: WeaponDefinition, id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in weapon.upgrades:
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


func _charge_readout(panel: WeaponDebugPanel) -> String:
	for line: Node in panel.get_node(^"Panel/Body/Scroll/Rows").get_children():
		if line is HBoxContainer and (line.get_child(0) as Label).text == panel.charge_row_label:
			return (line.get_child(1) as Label).text
	return ""


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("BLOOD PUMP SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
