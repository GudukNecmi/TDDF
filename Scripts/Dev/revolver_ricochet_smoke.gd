extends SceneTree
## Headless check of the revolver's RICOCHET upgrade: the card is on the revolver's
## tab and nowhere else, each level bought adds one bounce to the rounds the real
## revolver fires, and a bounced round works outwards through real enemies - never
## landing on the same enemy twice - while every landing is still the weapon's own
## damage calculation.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/revolver_ricochet_smoke.gd
## [/codeblock]

const TITLE_SCENE := "res://Scenes/UI/TitleScreen.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const BULLET_SCENE := "res://Scenes/Projectile/RevolverBullet.tscn"
const REVOLVER_SCENE := "res://Scenes/Weapons/Revolver.tscn"

var _failures: int = 0
var _arena: Node2D
## Every landing of the round in flight: the enemy, and the damage it carried.
var _hits: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	change_scene_to_file(TITLE_SCENE)
	await process_frame
	await process_frame
	var title := current_scene as TitleScreen
	if title == null:
		_ok(false, "the title screen is up")
		_finish()
		return
	title.start_story()
	await _settle()
	var menu := current_scene as BaseMenu
	_ok(menu != null, "STORY lands on the Base menu")
	if menu == null:
		_finish()
		return

	var session := root.get_node(^"RunSession") as RunSessionState
	var catalog := session.get_weapon_catalog()
	var revolver := catalog.find(&"revolver")
	var shotgun := catalog.find(&"shotgun")
	var rifle := catalog.find(&"lever_action")
	for weapon: WeaponDefinition in catalog.weapons:
		weapon.reset_upgrades()
	var bank: BloodWallet = root.get_node(^"BloodBank")
	bank.reset()
	bank.add(100000)
	revolver.unlocked = true
	rifle.unlocked = true

	print("--- the card ---")
	var ricochet := _upgrade(revolver, &"ricochet")
	_ok(ricochet != null, "the revolver offers RICOCHET")
	_ok(_upgrade(shotgun, &"ricochet") == null and _upgrade(rifle, &"ricochet") == null,
		"and neither the shotgun nor the rifle does")
	(menu.find_child("UpgradeButton", true, false) as BaseMenuEntry).pressed.emit()
	await process_frame
	var screen := menu.find_child("BaseUpgradeScreen", true, false) as BaseUpgradeScreen
	screen.show_tab(&"revolver")
	await process_frame
	var card := _card(screen, "RICOCHET")
	_ok(card != null, "the revolver tab shows the RICOCHET card")
	if card != null:
		_ok(card.detail_text.contains("BOUNCES +0 -> +1"), "which says what the first level does", card.detail_text)
	screen.show_tab(&"shotgun")
	await process_frame
	_ok(_card(screen, "RICOCHET") == null, "the shotgun tab does not")
	screen.show_tab(&"lever_action")
	await process_frame
	_ok(_card(screen, "RICOCHET") == null, "nor does the rifle tab")
	screen.show_tab(&"revolver")
	await process_frame
	var spent: Array[int] = []
	for i in 4:
		var before := bank.get_total()
		_press_buy(_card(screen, "RICOCHET"))
		await process_frame
		spent.append(before - bank.get_total())
	_ok(revolver.get_upgrade_level(ricochet) == 3, "three levels can be bought", "%d" % revolver.get_upgrade_level(ricochet))
	_ok(spent == [600, 1200, 2000, 0], "for 600, 1200 and 2000 blood, and no fourth", str(spent))
	screen.close()
	await process_frame
	revolver.reset_upgrades()

	print("--- the real revolver ---")
	_arena = Node2D.new()
	_arena.name = "RicochetArena"
	root.add_child(_arena)
	current_scene = _arena
	var gun := (load(REVOLVER_SCENE) as PackedScene).instantiate() as Revolver
	gun.definition = revolver
	_arena.add_child(gun)
	gun.global_position = Vector2(-3000, -3000)
	var bounces: Array[int] = []
	for level in 4:
		if level > 0:
			revolver.raise_upgrade(ricochet)
		var count := _arena.get_child_count()
		gun._spawn_bullet()
		var bullet := _arena.get_child(count) as Projectile if _arena.get_child_count() > count else null
		bounces.append(-1 if bullet == null else bullet.get_bounces_left())
		if bullet != null:
			bullet.free()
	_ok(bounces == [0, 1, 2, 3], "its rounds carry 0 -> 1 -> 2 -> 3 bounces", str(bounces))
	gun.free()

	print("--- bouncing through enemies ---")
	var a := await _spawn_enemy(Vector2(400, 300))
	var b := await _spawn_enemy(Vector2(560, 300))
	var c := await _spawn_enemy(Vector2(560, 440))
	var d := await _spawn_enemy(Vector2(400, 440))
	var everyone: Array[Node2D] = [a, b, c, d]

	revolver.reset_upgrades()
	await _fire(revolver.get_stats(), a)
	_ok(_victims() == [a], "an un-upgraded round stops on the enemy it hits", _names())

	for level in [1, 2, 3]:
		revolver.reset_upgrades()
		for i in level:
			revolver.raise_upgrade(ricochet)
		await _fire(revolver.get_stats(), a)
		var victims := _victims()
		_ok(victims.size() == level + 1, "level %d lands on %d enemies" % [level, level + 1], _names())
		_ok(_unique(victims), "each of them once", _names())
		_ok(not victims.is_empty() and victims[0] == a, "starting with the one it was fired at", _names())

	print("--- never back into the same enemy ---")
	for enemy: Node2D in [c, d]:
		enemy.queue_free()
	await physics_frame
	await physics_frame
	revolver.reset_upgrades()
	for i in 3:
		revolver.raise_upgrade(ricochet)
	await _fire(revolver.get_stats(), a)
	_ok(_victims() == [a, b], "with three bounces and two enemies it hits each once and stops", _names())

	print("--- the weapon's own damage ---")
	revolver.raise_upgrade(_upgrade(revolver, &"damage"))
	revolver.raise_upgrade(_upgrade(revolver, &"damage"))
	var stats := revolver.get_stats()
	var probe := (load(BULLET_SCENE) as PackedScene).instantiate() as Projectile
	var health_a := a.get_node(^"Health") as Health
	var health_b := b.get_node(^"Health") as Health
	var before_a := health_a.get_current()
	var before_b := health_b.get_current()
	await _fire(stats, a)
	var damage_ok := _hits.size() == 2
	for hit: Dictionary in _hits:
		var expected := probe.profile.damage_at(hit["progress"], stats.falloff_scale()) \
			* stats.damage_scale_at(hit["progress"])
		damage_ok = damage_ok and is_equal_approx(hit["damage"], expected)
	_ok(damage_ok, "every landing, bounce included, is the profile figure times DAMAGE +20%", str(_hits))
	_ok(_hits.size() == 2 and is_equal_approx(before_a - health_a.get_current(), _hits[0]["damage"])
		and is_equal_approx(before_b - health_b.get_current(), _hits[1]["damage"]),
		"and each enemy loses exactly what landed on it")
	probe.free()

	for weapon: WeaponDefinition in catalog.weapons:
		weapon.reset_upgrades()
	revolver.unlocked = false
	rifle.unlocked = false
	_finish()


func _spawn_enemy(at: Vector2) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(100000.0)
	await physics_frame
	await physics_frame
	return enemy


## Fires one revolver round armed with [param stats] into [param at]'s body from
## 90px to its left, and waits until it is gone.
func _fire(stats: WeaponStats, at: Node2D) -> void:
	_hits.clear()
	var bullet := (load(BULLET_SCENE) as PackedScene).instantiate() as Projectile
	bullet.apply_weapon_stats(stats, false)
	bullet.landed.connect(_on_landed.bind(bullet))
	_arena.add_child(bullet)
	var body := at.get_node(^"BodyHitbox") as Hitbox
	bullet.global_position = body.global_position - Vector2(90, 0)
	bullet.global_rotation = 0.0
	var guard := 0
	while is_instance_valid(bullet) and guard < 240:
		guard += 1
		await physics_frame
	for i in 20:
		await physics_frame


func _on_landed(hitbox: Hitbox, bullet: Projectile) -> void:
	_hits.append({
		"enemy": hitbox.owner,
		"damage": bullet.get_current_damage(),
		"progress": bullet.get_progress(),
	})


func _victims() -> Array[Node2D]:
	var victims: Array[Node2D] = []
	for hit: Dictionary in _hits:
		victims.append(hit["enemy"])
	return victims


func _names() -> String:
	var names: PackedStringArray = []
	for victim: Node2D in _victims():
		names.append(victim.name)
	return ", ".join(names)


func _unique(victims: Array[Node2D]) -> bool:
	for i in victims.size():
		if victims.find(victims[i]) != i:
			return false
	return true


func _upgrade(weapon: WeaponDefinition, id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func _card(screen: BaseUpgradeScreen, title: String) -> UpgradeCard:
	for child: Node in screen.get_node(^"Panel/Body/Scroll/Cards").get_children():
		if child is UpgradeCard and not child.is_queued_for_deletion() and child.title_text == title:
			return child
	return null


## Presses BUY the way the mouse does, so a disabled button is honoured.
func _press_buy(card: UpgradeCard) -> void:
	if card == null:
		return
	var buy := card.get_node(^"Layout/BuyButton") as Button
	if not buy.disabled:
		buy.pressed.emit()


func _settle() -> void:
	var guard := 0
	var curtain := LoadingCurtain.get_active(root)
	while curtain != null and curtain.is_loading() and guard < 4000:
		guard += 1
		await process_frame
		curtain = LoadingCurtain.get_active(root)
	for i in 6:
		await process_frame


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("  ok   %s" % what)
	else:
		_failures += 1
		print("  FAIL %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _finish() -> void:
	if _failures == 0:
		print("[PASS] revolver ricochet: every check passed")
	else:
		print("[FAIL] revolver ricochet: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)
