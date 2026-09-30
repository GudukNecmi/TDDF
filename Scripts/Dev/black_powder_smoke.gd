extends SceneTree
## Headless check of the shotgun's Legendary BLACK POWDER: it is listed, the K panel
## switches it and shows its smoke row; a shot with the cooldown run out leaves a
## cloud and restarts the 6 second wait, a shot before then leaves none; in the smoke
## the enemies lose the player and go to the white last-seen mark instead, which does
## not follow them; only an enemy close by makes them out, leaving yellow marks every
## 0.3s; a shot from hiding leaves a red mark and sends every enemy to it; stepping
## out puts every enemy back on the real player; OFF clears the wait and the smoke.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/black_powder_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const PLAYER_SCENE := "res://Scenes/Player/Player.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"

var _failures: int = 0
var _shotgun: WeaponDefinition
var _powder: WeaponLegendary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_shotgun = session.get_weapon_catalog().find(&"shotgun")
	_shotgun.reset_upgrades()
	for legendary: WeaponLegendary in _shotgun.legendaries:
		if legendary.id == &"black_powder":
			_powder = legendary

	print("--- the Legendary ---")
	_ok(_powder != null and _powder.black_powder != null, "the shotgun lists BLACK POWDER")
	if _powder == null:
		_finish()
		return
	var powder := _powder.black_powder
	_ok(is_equal_approx(powder.cooldown, 6.0), "base cooldown is 6s")
	_ok(_shotgun.get_stats().black_powder == null, "off, the stats carry no powder")

	print("--- the K panel ---")
	var panel := _make_panel()
	panel.open()
	_find_button(panel, "ON", "BLACK POWDER").pressed.emit()
	_ok(_shotgun.get_stats().black_powder == powder, "ON switches it on")
	_ok(_readout(panel, "BLACK POWDER").begins_with("ON"), "the row reads ON")
	_ok(_smoke_row(panel).contains("COOLDOWN 6.0s"), "the smoke row shows the settings", _smoke_row(panel))
	panel.close()
	paused = false

	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody2D
	arena.add_child(player)
	player.global_position = Vector2.ZERO
	var stealth := player.get_node(^"Stealth") as PlayerStealth
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = _shotgun
	gun.target_path = NodePath("../" + String(player.name))
	arena.add_child(gun)
	var far := _enemy(arena, player, Vector2(600, 0))
	var far2 := _enemy(arena, player, Vector2(-700, 300))
	await _wait(0.2)
	_ok(gun.get_cooldown_label().ends_with("READY"), "the HUD label reads ready", gun.get_cooldown_label())

	print("--- the smoke shot ---")
	var marks := {"yellow": 0, "noise": -1}
	stealth.detected.connect(func(_p: Vector2) -> void: marks.yellow += 1)
	stealth.noise_made.connect(func(_p: Vector2, heard: int) -> void: marks.noise = heard)
	_fire(gun)
	_ok(_clouds() == 1, "a ready shot leaves one cloud")
	_ok(gun.get_black_powder_cooldown() > 5.9, "and restarts the 6s wait", str(gun.get_black_powder_cooldown()))
	var cloud := get_nodes_in_group(BlackPowderSmoke.GROUP)[0] as BlackPowderSmoke
	var expected := Vector2.ZERO - Vector2.from_angle(PI) * powder.smoke_back_offset
	_ok(cloud.global_position.distance_to(expected) < 0.5 and is_equal_approx(powder.smoke_back_offset, 100.0),
		"the smoke sits 100px straight back from the aim", str(cloud.global_position))
	_ok(cloud.z_index > player.z_index and cloud.z_index < stealth.mark_z_index, "the smoke draws over the player and under the marks",
		"smoke %d, player %d, marks %d" % [cloud.z_index, player.z_index, stealth.mark_z_index])
	_ok(cloud.get_node_or_null(^"Haze") == null and cloud.get_node(^"Puffs") is CanvasGroup,
		"only the smoke puffs are drawn, merged before fading")
	var peak := [0.0]
	var sampler := func() -> void:
		peak[0] = maxf(peak[0], (cloud.get_node(^"Puffs") as CanvasItem).modulate.a)
	process_frame.connect(sampler)
	await _wait(0.5)
	var fizz := cloud.get_node(^"Fizz") as LoopingSound
	_ok(fizz != null and fizz.playing and fizz.stream != null, "the smoke starts its own fizz loop")
	_ok(_fizz_count() == 1, "one fizz for the one cloud")
	_fire(gun)
	_ok(_clouds() == 1, "a shot during the wait leaves no smoke")
	_ok(_fizz_count() == 1, "a shot that makes no smoke starts no fizz")
	_ok(gun.get_black_powder_cooldown() < 5.6, "and does not restart the wait")
	_ok(marks.noise == 2, "that shot, fired from hiding, is heard by every enemy", str(marks.noise))
	_ok(_count_marks(arena) >= 2, "white and red marks are down", str(_count_marks(arena)))

	print("--- hiding ---")
	_ok(stealth.is_hidden(), "the player is hidden in the cloud")
	var seen := stealth.get_last_seen()
	_ok(seen.distance_to(Vector2.ZERO) < 1.0, "last seen where the smoke went off")
	player.global_position = Vector2(90, 40)
	await _wait(0.2)
	_ok(stealth.get_last_seen() == seen, "the white mark does not follow the player")
	_ok(far.call(&"is_investigating"), "a far enemy has lost the player and investigates")
	_ok((far.call(&"get_investigate_point") as Vector2).distance_to(Vector2.ZERO) < powder.search_radius + 1.0,
		"it heads for the shot, not the real player", str(far.call(&"get_investigate_point")))

	print("--- close detection ---")
	var near := _enemy(arena, player, player.global_position + Vector2(40, 0))
	marks.yellow = 0
	await _wait(0.7)
	_ok(not near.call(&"is_investigating"), "a close enemy makes the player out and chases")
	_ok(marks.yellow >= 2 and marks.yellow <= 4, "yellow marks every 0.3s while it does", str(marks.yellow))
	_ok(far.call(&"is_investigating"), "the far enemy still does not know")
	near.queue_free()
	await _wait(0.1)
	marks.yellow = 0
	await _wait(0.4)
	_ok(marks.yellow == 0, "no yellow with nobody close")

	print("--- stepping out ---")
	player.global_position = cloud.global_position + Vector2(170, 0)
	await _wait(0.1)
	_ok(stealth.is_hidden() and is_equal_approx(cloud.radius, 150.0) and cloud.get_stealth_radius() > 185.0,
		"hidden 170px out - past the 150px smoke drawn, inside the stealth radius", str(cloud.get_stealth_radius()))
	player.global_position = Vector2(900, 900)
	await _wait(0.1)
	_ok(not stealth.is_hidden(), "outside the smoke the player is seen")
	_ok(not far.call(&"is_investigating") and not far2.call(&"is_investigating"), "every enemy is back on the player")

	print("--- OFF ---")
	player.global_position = Vector2.ZERO
	await _wait(0.1)
	_ok(stealth.is_hidden(), "back in the smoke")
	var before_off := (cloud.get_node(^"Puffs") as CanvasItem).modulate.a
	_shotgun.set_legendary_active(_powder, false)
	await process_frame
	var after_off := (cloud.get_node(^"Puffs") as CanvasItem).modulate.a
	_ok(after_off <= before_off + 0.001, "switching off thins the smoke without a spike",
		"%.3f -> %.3f" % [before_off, after_off])
	process_frame.disconnect(sampler)
	_ok(peak[0] <= cloud.smoke_opacity + 0.001 and peak[0] > 0.1, "the smoke never passes its opacity ceiling",
		"peak %.3f, ceiling %.2f" % [peak[0], cloud.smoke_opacity])
	await _wait(0.1)
	_ok(gun.get_black_powder_cooldown() == 0.0 and gun.get_cooldown_label().is_empty(), "OFF clears the wait and the label")
	_ok(not stealth.is_hidden(), "and the smoke stops hiding at once")
	_fire(gun)
	_ok(_clouds() <= 1, "an OFF shot leaves no new smoke")
	await _wait(2.0)
	_ok(not is_instance_valid(cloud) and _fizz_count() == 0, "once the smoke ends its fizz fades out and the cloud is gone")
	_finish()


func _enemy(arena: Node, player: Node2D, at: Vector2) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	enemy.set(&"target_path", player.get_path())
	arena.add_child(enemy)
	enemy.global_position = at
	return enemy


func _clouds() -> int:
	var live := 0
	for node: Node in get_nodes_in_group(BlackPowderSmoke.GROUP):
		if (node as BlackPowderSmoke).is_concealing() or (node as BlackPowderSmoke).get_presence() < 0.5:
			live += 1
	return live


func _count_marks(arena: Node) -> int:
	var count := 0
	for child: Node in arena.get_children():
		if child.name.begins_with("StealthMark"):
			count += 1
	return count


func _fire(gun: Shotgun) -> void:
	var locker := root.get_node_or_null(^"Ammo") as AmmoLocker
	if locker != null and locker.has_method(&"refill_all"):
		locker.call(&"refill_all")
	gun.reload_to_ready()
	# Aimed left, so the cloud goes down to the right, behind the player.
	gun.global_rotation = PI
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
		if line is HBoxContainer and (line.get_child(0) as Label).text == name:
			return line
	return null


func _find_button(panel: WeaponDebugPanel, text: String, name: String) -> Button:
	var line := _row(panel, panel.legendary_prefix + name)
	if line != null:
		for child: Node in line.get_children():
			if child is Button and child.text == text:
				return child
	return null


func _readout(panel: WeaponDebugPanel, name: String) -> String:
	var line := _row(panel, panel.legendary_prefix + name)
	return "" if line == null else (line.get_child(1) as Label).text


func _smoke_row(panel: WeaponDebugPanel) -> String:
	var line := _row(panel, panel.powder_row_label)
	return "" if line == null else (line.get_child(1) as Label).text


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("BLACK POWDER SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _fizz_count() -> int:
	var count := 0
	for node: Node in get_nodes_in_group(BlackPowderSmoke.GROUP):
		var fizz := node.get_node_or_null(^"Fizz") as LoopingSound
		if fizz != null and fizz.playing:
			count += 1
	return count
