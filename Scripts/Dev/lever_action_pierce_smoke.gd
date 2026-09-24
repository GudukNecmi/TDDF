extends SceneTree
## Headless check of the lever action's PIERCE upgrade: the card is on the rifle's
## tab and nowhere else, each level bought adds one pierce to the rounds the real
## rifle fires, and a pierced round carries straight on down a line of real
## enemies - never landing on the same enemy twice - while every landing is still
## the weapon's own damage calculation.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/lever_action_pierce_smoke.gd
## [/codeblock]

const TITLE_SCENE := "res://Scenes/UI/TitleScreen.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const BULLET_SCENE := "res://Scenes/Projectile/RifleBullet.tscn"
const RIFLE_SCENE := "res://Scenes/Weapons/LeverActionRifle.tscn"

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
	var pierce := _upgrade(rifle, &"pierce")
	_ok(pierce != null, "the rifle offers PIERCE")
	_ok(_upgrade(shotgun, &"pierce") == null and _upgrade(revolver, &"pierce") == null,
		"and neither the shotgun nor the revolver does")
	(menu.find_child("UpgradeButton", true, false) as BaseMenuEntry).pressed.emit()
	await process_frame
	var screen := menu.find_child("BaseUpgradeScreen", true, false) as BaseUpgradeScreen
	screen.show_tab(&"lever_action")
	await process_frame
	var card := _card(screen, "PIERCE")
	_ok(card != null, "the rifle tab shows the PIERCE card")
	if card != null:
		_ok(card.detail_text.contains("PIERCES +0 -> +1"), "which says what the first level does", card.detail_text)
	screen.show_tab(&"shotgun")
	await process_frame
	_ok(_card(screen, "PIERCE") == null, "the shotgun tab does not")
	screen.show_tab(&"revolver")
	await process_frame
	_ok(_card(screen, "PIERCE") == null, "nor does the revolver tab")
	screen.show_tab(&"lever_action")
	await process_frame
	var spent: Array[int] = []
	for i in 4:
		var before := bank.get_total()
		_press_buy(_card(screen, "PIERCE"))
		await process_frame
		spent.append(before - bank.get_total())
	_ok(rifle.get_upgrade_level(pierce) == 3, "three levels can be bought", "%d" % rifle.get_upgrade_level(pierce))
	_ok(spent == [600, 1200, 2000, 0], "for 600, 1200 and 2000 blood, and no fourth", str(spent))
	screen.close()
	await process_frame
	rifle.reset_upgrades()

	print("--- the real rifle ---")
	_arena = Node2D.new()
	_arena.name = "PierceArena"
	root.add_child(_arena)
	current_scene = _arena
	var gun := (load(RIFLE_SCENE) as PackedScene).instantiate() as LeverActionRifle
	gun.definition = rifle
	_arena.add_child(gun)
	gun.global_position = Vector2(-3000, -3000)
	var pierces: Array[int] = []
	for level in 4:
		if level > 0:
			rifle.raise_upgrade(pierce)
		var count := _arena.get_child_count()
		gun._spawn_bullet()
		var bullet := _arena.get_child(count) as Projectile if _arena.get_child_count() > count else null
		pierces.append(-1 if bullet == null else bullet.get_pierces_left())
		if bullet != null:
			bullet.free()
	_ok(pierces == [0, 1, 2, 3], "its rounds carry 0 -> 1 -> 2 -> 3 pierces", str(pierces))
	gun.free()

	print("--- through a line of enemies ---")
	var line: Array[Node2D] = []
	for i in 5:
		line.append(await _spawn_enemy(Vector2(400 + i * 110, 300)))
	var a := line[0]

	rifle.reset_upgrades()
	await _fire(rifle.get_stats(), a)
	_ok(_victims() == [a], "an un-upgraded round stops on the enemy it hits", _names())

	for level in [1, 2, 3]:
		rifle.reset_upgrades()
		for i in level:
			rifle.raise_upgrade(pierce)
		await _fire(rifle.get_stats(), a)
		var victims := _victims()
		_ok(victims == line.slice(0, level + 1),
			"level %d passes through to the first %d enemies in the line, in order" % [level, level + 1], _names())
		_ok(_unique(victims), "each of them once", _names())

	print("--- fewer enemies than pierces ---")
	for i in range(2, line.size()):
		line[i].queue_free()
	await physics_frame
	await physics_frame
	rifle.reset_upgrades()
	for i in 3:
		rifle.raise_upgrade(pierce)
	await _fire(rifle.get_stats(), a)
	_ok(_victims() == [a, line[1]], "with three pierces and two enemies it hits each once and flies on", _names())

	print("--- the weapon's own damage ---")
	rifle.raise_upgrade(_upgrade(rifle, &"damage"))
	rifle.raise_upgrade(_upgrade(rifle, &"damage"))
	var stats := rifle.get_stats()
	var probe := (load(BULLET_SCENE) as PackedScene).instantiate() as Projectile
	var health_a := a.get_node(^"Health") as Health
	var health_b := line[1].get_node(^"Health") as Health
	var before_a := health_a.get_current()
	var before_b := health_b.get_current()
	await _fire(stats, a)
	var damage_ok := _hits.size() == 2
	for hit: Dictionary in _hits:
		var expected := probe.profile.damage_at(hit["progress"], stats.falloff_scale()) \
			* stats.damage_scale_at(hit["progress"])
		damage_ok = damage_ok and is_equal_approx(hit["damage"], expected)
	_ok(damage_ok, "every landing, pierce included, is the profile figure times the DAMAGE upgrade", str(_hits))
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


## Fires one rifle round armed with [param stats] into [param at]'s body from
## 90px to its left, straight along +X, and waits until it is gone.
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
		print("[PASS] lever action pierce: every check passed")
	else:
		print("[FAIL] lever action pierce: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)
