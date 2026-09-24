extends SceneTree
## Headless check of the common weapon upgrades: the Base UPGRADE screen offers a
## tab per owned weapon with that weapon's own set of cards, buying one raises the
## level on the weapon and takes the price out of the bank, and what was bought
## really changes combat - a round fired into a real enemy lands harder, crits
## multiply, knockback and stagger grow, range, size, magazine, capacity and ammo
## efficiency move - with the headshot bonus gone but the head region still known.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/weapon_upgrade_smoke.gd
## [/codeblock]

const TITLE_SCENE := "res://Scenes/UI/TitleScreen.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const PELLET_SCENE := "res://Scenes/Projectile/Projectile.tscn"
const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const REVOLVER_SCENE := "res://Scenes/Weapons/Revolver.tscn"
const RIFLE_SCENE := "res://Scenes/Weapons/LeverActionRifle.tscn"

var _failures: int = 0
var _catalog: WeaponCatalog
var _arena: Node2D
## What the last fired round reported as it landed.
var _landed_damage: float = -1.0
var _landed_progress: float = -1.0
var _landed_knockback: float = -1.0
var _landed_stagger: float = -1.0
var _landed_blood: float = -1.0


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
	_catalog = session.get_weapon_catalog()
	var shotgun := _catalog.find(&"shotgun")
	var revolver := _catalog.find(&"revolver")
	var rifle := _catalog.find(&"lever_action")
	for weapon: WeaponDefinition in _catalog.weapons:
		weapon.reset_upgrades()
	var bank: BloodWallet = root.get_node(^"BloodBank")
	bank.reset()
	var locker: AmmoLocker = root.get_node(^"Ammo")

	var baseline_estimate := WorldBanditDecisionEvaluator.medium_range_shot_damage(menu, _catalog)

	print("--- the screen ---")
	(menu.find_child("UpgradeButton", true, false) as BaseMenuEntry).pressed.emit()
	await process_frame
	var screen := menu.find_child("BaseUpgradeScreen", true, false) as BaseUpgradeScreen
	_ok(screen != null and screen.visible, "UPGRADE opens the screen")
	var tabs := screen.get_node(^"Panel/Body/Tabs")
	_ok(tabs.has_node(^"Tab_base") and tabs.has_node(^"Tab_shotgun"), "BASE and SHOTGUN tabs are offered")
	_ok(not tabs.has_node(^"Tab_revolver"), "a weapon not owned has no tab")
	_ok(_titles(screen).has("BOUNTY BOARD"), "the BASE tab still sells the Bounty Board")

	(tabs.get_node(^"Tab_shotgun") as Button).pressed.emit()
	await process_frame
	var titles := _titles(screen)
	_ok(titles.size() == 16, "the shotgun tab has its 16 cards", "%d" % titles.size())
	_ok(titles.has("DAMAGE FALLOFF") and titles.has("AMMO CAPACITY") and not titles.has("MAGAZINE SIZE"),
		"with fall-off and ammo capacity, and no magazine", ", ".join(titles))
	_ok(titles.has("PELLET COUNT") and titles.has("ACCURACY"), "and the shotgun's own PELLET COUNT and ACCURACY",
		", ".join(titles))

	var card := _card(screen, "DAMAGE")
	_press_buy(card)
	await process_frame
	_ok(shotgun.get_upgrade_level(shotgun.upgrades[0]) == 0, "an empty bank cannot buy DAMAGE")
	bank.add(100000)
	await process_frame
	_press_buy(_card(screen, "DAMAGE"))
	await process_frame
	_press_buy(_card(screen, "DAMAGE"))
	await process_frame
	_ok(shotgun.get_upgrade_level(shotgun.upgrades[0]) == 2, "two DAMAGE levels bought onto the shotgun")
	_ok(bank.get_total() == 100000 - 300 - 600, "for 300 then 600", "%d" % bank.get_total())
	card = _card(screen, "DAMAGE")
	_ok(card.detail_text.contains("LEVEL 2 / 5") and card.detail_text.contains("DAMAGE +20% -> +30%"),
		"and the card says what the next level does", card.detail_text)
	_press_buy(_card(screen, "AMMO CAPACITY"))
	await process_frame
	var shells := locker.get_reserve(shotgun.ammo_type)
	_ok(shells.get_max() == shotgun.ammo_type.max_ammo + 8, "AMMO CAPACITY raises the shell reserve at once",
		"%d" % shells.get_max())

	revolver.unlocked = true
	rifle.unlocked = true
	screen.show_tab(&"revolver")
	await process_frame
	titles = _titles(screen)
	_ok(tabs.has_node(^"Tab_revolver") and titles.has("MAGAZINE SIZE") and not titles.has("DAMAGE FALLOFF"),
		"a bought revolver gets its own tab, with a magazine and no fall-off", ", ".join(titles))
	_ok(not titles.has("PELLET COUNT") and not titles.has("ACCURACY"), "and none of the shotgun's own cards")
	screen.show_tab(&"lever_action")
	await process_frame
	titles = _titles(screen)
	_ok(not titles.has("RANGE") and titles.has("MAGAZINE SIZE"), "the rifle is offered no RANGE", ", ".join(titles))
	screen.close()
	await process_frame
	_ok(not paused, "closing it unpauses")

	print("--- combat ---")
	_arena = Node2D.new()
	_arena.name = "UpgradeArena"
	root.add_child(_arena)
	current_scene = _arena

	var enemy := await _spawn_enemy(Vector2(600, 300))
	var body := enemy.get_node(^"BodyHitbox") as Hitbox
	var head := enemy.get_node(^"HeadHitbox") as Hitbox
	_ok(is_equal_approx(head.damage_multiplier, 1.0), "the head hitbox has no default bonus")
	_ok(head.region == &"head" and body.region == &"body", "but still knows it is the head")

	var health := enemy.get_node(^"Health") as Health
	var before := health.get_current()
	await _fire(null, false, body)
	var plain := _landed_damage
	_ok(is_equal_approx(before - health.get_current(), plain), "an un-upgraded pellet lands its profile damage",
		"%.2f vs %.2f" % [before - health.get_current(), plain])
	var reference := _profile_damage(_landed_progress)
	_ok(is_equal_approx(plain, reference), "which is exactly the profile's figure")

	before = health.get_current()
	await _fire(shotgun.get_stats(), false, body)
	_ok(is_equal_approx(_landed_damage, _profile_damage(_landed_progress) * 1.2),
		"DAMAGE level 2 lands 20% harder", "%.2f vs %.2f" % [_landed_damage, _profile_damage(_landed_progress)])
	_ok(is_equal_approx(before - health.get_current(), _landed_damage), "and the enemy loses exactly that")

	await _fire(shotgun.get_stats(), true, body)
	_ok(is_equal_approx(_landed_damage, _profile_damage(_landed_progress) * 1.2 * 1.5),
		"a critical round multiplies it by the base x1.5")

	before = health.get_current()
	await _fire(shotgun.get_stats(), false, head)
	_ok(is_equal_approx(before - health.get_current(), _landed_damage), "a headshot does no extra damage")

	shotgun.raise_upgrade(_upgrade(shotgun, &"knockback"))
	shotgun.raise_upgrade(_upgrade(shotgun, &"stagger"))
	shotgun.raise_upgrade(_upgrade(shotgun, &"blood_gain"))
	var reaction := enemy.get_node(^"HitReaction") as HitReaction
	await _fire(null, false, body)
	var plain_knock := _landed_knockback
	var plain_stagger := _landed_stagger
	await _fire(shotgun.get_stats(), false, body)
	_ok(is_equal_approx(_landed_knockback, plain_knock * 1.2), "KNOCKBACK shoves 20% harder",
		"%.1f vs %.1f" % [_landed_knockback, plain_knock])
	_ok(is_equal_approx(_landed_stagger, plain_stagger * 1.2), "STAGGER slows 20% longer",
		"%.3f vs %.3f" % [_landed_stagger, plain_stagger])
	_ok(is_equal_approx(_landed_blood, 1.1), "BLOOD GAIN reaches the enemy's blood drop")
	_ok(reaction.knockback_speed == 150.0, "the enemy's own authored knockback is untouched")

	shotgun.raise_upgrade(_upgrade(shotgun, &"damage_falloff"))
	shotgun.raise_upgrade(_upgrade(shotgun, &"damage_falloff"))
	shotgun.raise_upgrade(_upgrade(shotgun, &"close_damage"))
	var probe := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	probe.apply_weapon_stats(shotgun.get_stats())
	var profile := probe.profile
	var expected := profile.damage_at(0.5, 0.8) * 1.2 * lerpf(1.15, 1.0, 0.5)
	_ok(is_equal_approx(probe.damage_at_progress(0.5), expected),
		"fall-off and close damage shape the damage along the flight",
		"%.2f vs %.2f" % [probe.damage_at_progress(0.5), expected])

	shotgun.raise_upgrade(_upgrade(shotgun, &"range"))
	shotgun.raise_upgrade(_upgrade(shotgun, &"projectile_speed"))
	shotgun.raise_upgrade(_upgrade(shotgun, &"projectile_size"))
	probe.apply_weapon_stats(shotgun.get_stats())
	_arena.add_child(probe)
	probe.global_position = Vector2(-5000, -5000)
	_ok(is_equal_approx(probe.get_effective_range(), profile.effective_range * 1.1), "RANGE reaches 10% further")
	_ok(probe.scale.is_equal_approx(Vector2.ONE * 1.1), "PROJECTILE SIZE grows the round")
	var spot := probe.global_position
	await physics_frame
	var stepped := probe.global_position.distance_to(spot)
	_ok(stepped > 0.0, "SPEED round still flies", "%.2f" % stepped)
	probe.queue_free()
	_ok(profile.effective_range == 420.0, "the shared profile itself is untouched")

	print("--- one roll per attack ---")
	shotgun.set_modifier_source(&"smoke", [_modifier(WeaponStats.Stat.CRITICAL_CHANCE, 0.5)])
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = shotgun
	_arena.add_child(gun)
	var mixed := false
	var saw_crit := false
	var saw_plain := false
	for i in 24:
		var pellets_before := _arena.get_child_count()
		gun._spawn_pellets()
		var shot: Array[bool] = []
		for index in range(pellets_before, _arena.get_child_count()):
			var pellet := _arena.get_child(index) as Projectile
			if pellet != null:
				shot.append(pellet.is_critical())
		if shot.has(true) and shot.has(false):
			mixed = true
		saw_crit = saw_crit or shot.has(true)
		saw_plain = saw_plain or shot.has(false)
		for index in range(_arena.get_child_count() - 1, pellets_before - 1, -1):
			_arena.get_child(index).free()
	_ok(not mixed, "every pellet of one blast shares one critical roll")
	_ok(saw_crit and saw_plain, "and a 50% chance does roll both ways")
	shotgun.set_modifier_source(&"smoke", [])

	print("--- pellets and spread ---")
	var pellet_upgrade := _upgrade(shotgun, &"pellet_count")
	var accuracy_upgrade := _upgrade(shotgun, &"accuracy")
	var counts: Array[int] = [_blast(gun).size()]
	for i in 3:
		shotgun.raise_upgrade(pellet_upgrade)
		counts.append(_blast(gun).size())
	_ok(counts == [6, 8, 10, 12], "PELLET COUNT fires 6 -> 8 -> 10 -> 12 real pellets", str(counts))
	_ok(not shotgun.raise_upgrade(pellet_upgrade), "and stops at level 3")
	_ok(gun.pellet_count == 6, "the shotgun's authored pellet count is untouched")

	var base_cone := _widest_angle(gun, 20)
	_ok(is_equal_approx(gun.get_spread_degrees(), 12.0), "an un-upgraded cone is the authored 12 degrees")
	for i in 3:
		shotgun.raise_upgrade(accuracy_upgrade)
	_ok(is_equal_approx(gun.get_spread_degrees(), 12.0 * 0.55), "ACCURACY level 3 narrows it to 6.6 degrees",
		"%.2f" % gun.get_spread_degrees())
	var tight_cone := _widest_angle(gun, 20)
	_ok(tight_cone <= deg_to_rad(6.6) * 0.5 + 0.0001 and base_cone > tight_cone,
		"and the pellets really fly inside it", "%.2f -> %.2f deg" % [rad_to_deg(base_cone), rad_to_deg(tight_cone)])
	_ok(gun.spread_angle_degrees == 12.0, "the shotgun's authored spread is untouched")

	print("--- ammo ---")
	shotgun.set_modifier_source(&"smoke", [_modifier(WeaponStats.Stat.AMMO_EFFICIENCY, 1.0)])
	shells.fill()
	var count := shells.get_current()
	gun.spend_ammo()
	_ok(shells.get_current() == count, "a saved shot costs nothing")
	shotgun.set_modifier_source(&"smoke", [])
	gun.spend_ammo()
	_ok(shells.get_current() == count - 1, "without efficiency it costs a shell")
	gun.free()

	revolver.raise_upgrade(_upgrade(revolver, &"magazine"))
	rifle.raise_upgrade(_upgrade(rifle, &"magazine"))
	var cylinder := (load(REVOLVER_SCENE) as PackedScene).instantiate() as Revolver
	cylinder.definition = revolver
	_arena.add_child(cylinder)
	_ok(cylinder.get_chambers().size() == 7, "MAGAZINE SIZE gives the revolver a seventh chamber",
		"%d" % cylinder.get_chambers().size())
	_ok(locker.get_reserve(revolver.ammo_type).get_max() == revolver.ammo_type.max_ammo + 6,
		"and it carries six more rounds")
	var tube := (load(RIFLE_SCENE) as PackedScene).instantiate() as LeverActionRifle
	tube.definition = rifle
	_arena.add_child(tube)
	_ok(tube.get_magazine_size() == 8, "and the rifle an eighth round in the tube", "%d" % tube.get_magazine_size())
	cylinder.free()
	tube.free()

	var upgraded_estimate := WorldBanditDecisionEvaluator.medium_range_shot_damage(menu, _catalog)
	_ok(upgraded_estimate > baseline_estimate, "the fight-or-tribute estimate reads the upgrades",
		"%.1f -> %.1f" % [baseline_estimate, upgraded_estimate])

	for weapon: WeaponDefinition in _catalog.weapons:
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


## Fires one pellet straight into [param at] from 90px to its left, armed with
## [param stats], and waits for it to land.
func _fire(stats: WeaponStats, critical: bool, at: Hitbox) -> void:
	_landed_damage = -1.0
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	if stats != null:
		pellet.apply_weapon_stats(stats, critical)
	pellet.landed.connect(_on_landed.bind(pellet))
	_arena.add_child(pellet)
	pellet.global_position = at.global_position - Vector2(90, 0)
	pellet.global_rotation = 0.0
	var guard := 0
	while _landed_damage < 0.0 and guard < 60:
		guard += 1
		await physics_frame
	if _landed_damage < 0.0:
		_ok(false, "a fired pellet lands on %s" % at.name)
	# Let the reaction settle so the next shot is measured fresh.
	for i in 30:
		await physics_frame


func _on_landed(hitbox: Hitbox, pellet: Projectile) -> void:
	_landed_damage = pellet.get_current_damage()
	_landed_progress = pellet.get_progress()
	var victim := hitbox.get_parent()
	var reaction := victim.get_node(^"HitReaction") as HitReaction
	_landed_knockback = reaction.get_knockback().length()
	_landed_stagger = reaction._slow_window
	_landed_blood = (victim.get_node(^"Health") as Health).get_last_hit_effects().blood_gain_scale


## Fires one real blast out of [param gun] and returns how far off the barrel
## each pellet left, in radians. The pellets are freed straight away.
func _blast(gun: Shotgun) -> Array[float]:
	var offsets: Array[float] = []
	var before := _arena.get_child_count()
	gun._spawn_pellets()
	for index in range(before, _arena.get_child_count()):
		var pellet := _arena.get_child(index) as Projectile
		if pellet != null:
			offsets.append(absf(angle_difference(gun.global_rotation, pellet.global_rotation)))
	for index in range(_arena.get_child_count() - 1, before - 1, -1):
		_arena.get_child(index).free()
	return offsets


## The widest any pellet strays from the barrel over [param shots] blasts.
func _widest_angle(gun: Shotgun, shots: int) -> float:
	var widest := 0.0
	for i in shots:
		for offset: float in _blast(gun):
			widest = maxf(widest, offset)
	return widest


func _profile_damage(progress: float) -> float:
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	var damage := pellet.profile.damage_at(progress)
	pellet.free()
	return damage


func _upgrade(weapon: WeaponDefinition, id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func _modifier(stat: WeaponStats.Stat, amount: float) -> WeaponStatModifier:
	var modifier := WeaponStatModifier.new()
	modifier.stat = stat
	modifier.amount = amount
	return modifier


func _titles(screen: BaseUpgradeScreen) -> PackedStringArray:
	var titles: PackedStringArray = []
	for child: Node in screen.get_node(^"Panel/Body/Scroll/Cards").get_children():
		if child is UpgradeCard and not child.is_queued_for_deletion():
			titles.append((child as UpgradeCard).title_text)
	return titles


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
		print("[PASS] weapon upgrades: every check passed")
	else:
		print("[FAIL] weapon upgrades: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)
