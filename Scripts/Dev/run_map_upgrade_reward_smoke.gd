extends SceneTree
## Headless check of the Bandit Group post-fight upgrade reward: ride to a real
## Bandit Group point, FIGHT, clear the arena, and confirm the reward screen
## holds the ride home, grants one free run-only level through the weapon's run
## stack, and TAKE returns to the same point on the same run map.
##
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_upgrade_reward_smoke.gd
## [/codeblock]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	var session := root.get_node_or_null(^"RunSession") as RunSessionState
	var wallet := root.get_node_or_null(^"Blood") as BloodWallet
	var bank := root.get_node_or_null(^"BloodBank") as BloodWallet
	await process_frame
	await process_frame
	session.begin(&"desert")
	session.choose_region(&"A")

	_pure_checks(session)

	_ok(router.go_to_region(&"A"), "the router accepted the ride out")
	await _settle()
	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	var menu := _find("WorldBanditDecisionMenu") as WorldBanditDecisionMenu
	var graph := director.get_graph()
	var made_seed := graph.seed

	var route := _route_to(bandits, graph, &"bandit_group")
	_ok(not route.is_empty(), "a Bandit Group point is within reach")
	var target := -1
	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame
		if menu.is_open():
			target = step
			break
	_ok(target >= 0, "arrived on the Bandit Group point with its screen up")
	if target < 0:
		_finish()
		return

	wallet.add(500)
	var carried_before := wallet.get_total()
	var banked_before := bank.get_total() if bank != null else 0

	_fight_button(menu).pressed.emit()
	await _settle()
	_ok(_scene_name() == "DustCampArena", "the fight opened in the arena", _scene_name())

	var bridge := _find("WorldMapCombatBridge") as WorldMapCombatBridge
	_ok(bridge.get_site_kind() == &"bandit_group", "the staged record carries the point kind",
		String(bridge.get_site_kind()))
	var weapon := WeaponMount.get_active(root).get_definition()
	var levels_before := _run_levels(weapon)

	var ambush := _find("AmbushWaveDirector") as AmbushWaveDirector
	ambush.cleared.emit()
	for _i: int in 30:
		await process_frame
	var screen := _find("RunMapUpgradeRewardScreen") as RunMapUpgradeRewardScreen
	_ok(screen != null and screen.visible, "the Upgrade Reward screen opened after the win")
	_ok(_scene_name() == "DustCampArena", "the ride home is held while it is up", _scene_name())
	var upgrade := screen.get_upgrade()
	_ok(upgrade != null and weapon.upgrades.has(upgrade),
		"the reward is one of the equipped weapon's own upgrades",
		"%s for %s" % [upgrade.display_name if upgrade else "<none>", weapon.weapon_id])
	var name_label := screen.get_node(^"Panel/Body/UpgradeName") as Label
	var level_label := screen.get_node(^"Panel/Body/Level") as Label
	var effect_label := screen.get_node(^"Panel/Body/Effect") as Label
	print("       shown: %s | %s | %s | %s" % [
		(screen.get_node(^"Panel/Body/Heading") as Label).text, name_label.text,
		effect_label.text.replace("\n", " / "), level_label.text])
	_ok(name_label.text == upgrade.display_name and not effect_label.text.is_empty()
			and level_label.text == "RUN LEVEL %d" % (weapon.get_run_level(upgrade) + 1),
		"it shows the name, effect and resulting run level")

	var base_before := weapon.get_upgrade_level(upgrade)
	var run_before := weapon.get_run_level(upgrade)
	(screen.get_node(^"Panel/Body/Take") as Button).pressed.emit()
	_ok(weapon.get_run_level(upgrade) == run_before + 1, "TAKE raised the run level by one",
		"%d -> %d" % [run_before, weapon.get_run_level(upgrade)])
	_ok(weapon.get_upgrade_level(upgrade) == base_before, "the permanent Base level is untouched")
	var total_gain := _sum(_run_levels(weapon)) - _sum(levels_before)
	_ok(total_gain == 1, "exactly one upgrade level was awarded", str(total_gain))
	_ok(wallet.get_total() == carried_before, "no carried Blood was spent",
		"%d -> %d" % [carried_before, wallet.get_total()])
	_ok(bank == null or bank.get_total() == banked_before, "no banked Blood was spent")

	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "TAKE returned to the run map", _scene_name())
	var back := (_find("RunMapDirector") as RunMapDirector).get_graph()
	_ok(back.seed == made_seed and back.current_id == target,
		"it is the same map, standing at the same point")
	_ok(back.get_site(target).kind == &"bandit_group_cleared", "the point is cleared",
		String(back.get_site(target).kind))
	_ok(weapon.get_run_level(upgrade) == run_before + 1, "the run level survived the scene change")

	session.end()
	_ok(weapon.get_run_level(upgrade) == 0, "the reward is forgotten when the run ends")
	_finish()


## The pool rules, checked directly against the real resources.
func _pure_checks(session: RunSessionState) -> void:
	var reward := load("res://Resources/RunMap/Rewards/bandit_group_upgrade_reward.tres") \
		as RunMapUpgradeReward
	_ok(is_equal_approx(reward.unique_chance, 0.03), "unique chance is 3%% in data")
	_ok(reward.pays_for(&"bandit_group") and not reward.pays_for(&"bandit_camp"),
		"only Bandit Group points pay")
	var catalog := session.get_weapon_catalog()
	var sure := reward.duplicate() as RunMapUpgradeReward
	sure.unique_chance = 1.0
	var rng := RandomNumberGenerator.new()
	for weapon: WeaponDefinition in catalog.weapons:
		var own_uniques := 0
		for up: WeaponUpgrade in weapon.upgrades:
			if up != null and up.unique and up.market_unlocked:
				own_uniques += 1
		var ok := true
		for i: int in 40:
			rng.seed = i
			var up := sure.draw(weapon, rng)
			if up == null or not weapon.upgrades.has(up) or (own_uniques > 0 and not up.unique):
				ok = false
		_ok(ok, "%s: a Unique roll gives its own Unique (%d eligible)" % [weapon.weapon_id, own_uniques])
		# Locking every Unique falls back to the common pool.
		var locked: Array[WeaponUpgrade] = []
		for up: WeaponUpgrade in weapon.upgrades:
			if up != null and up.unique and up.market_unlocked:
				up.market_unlocked = false
				locked.append(up)
		rng.seed = 7
		var fallback := sure.draw(weapon, rng)
		_ok(fallback != null and not fallback.unique, "%s: no eligible Unique falls back to common" % weapon.weapon_id)
		for up: WeaponUpgrade in locked:
			up.market_unlocked = true


func _run_levels(weapon: WeaponDefinition) -> Array[int]:
	var levels: Array[int] = []
	for up: WeaponUpgrade in weapon.upgrades:
		levels.append(weapon.get_run_level(up))
	return levels


func _sum(values: Array[int]) -> int:
	var total := 0
	for v: int in values:
		total += v
	return total


func _fight_button(menu: WorldBanditDecisionMenu) -> Button:
	for path: NodePath in menu.button_paths:
		var button := menu.get_node_or_null(path) as Button
		if button != null and button.visible and button.get_meta(&"outcome", &"fight") == &"fight":
			return button
	return null


func _settle() -> void:
	var guard := 0
	var curtain := LoadingCurtain.get_active(root)
	while curtain != null and curtain.is_loading() and guard < 4000:
		guard += 1
		await process_frame
	for _step: int in 12:
		await process_frame


func _finish() -> void:
	print("")
	print("[PASS] upgrade reward: every check passed" if _failures == 0
		else "[FAIL] upgrade reward: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)


func _find(wanted: String) -> Node:
	return _search(root, wanted)


func _search(node: Node, wanted: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == wanted:
		return node
	for child: Node in node.get_children():
		var found := _search(child, wanted)
		if found != null:
			return found
	return null


func _route_to(bandits: RunMapBanditNode, graph: RunMapGraph, wanted: StringName) -> PackedInt32Array:
	var came_from := {graph.current_id: -1}
	var queue: Array[int] = [graph.current_id]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next: int in graph.neighbours_of(at):
			if came_from.has(next):
				continue
			came_from[next] = at
			var site := graph.get_site(next)
			if bandits.encounter_for(site.kind) != null:
				if site.kind == wanted:
					var backwards: Array[int] = []
					var step := next
					while step != graph.current_id and step >= 0:
						backwards.append(step)
						step = int(came_from.get(step, -1))
					backwards.reverse()
					return PackedInt32Array(backwards)
				continue
			queue.append(next)
	return PackedInt32Array()
