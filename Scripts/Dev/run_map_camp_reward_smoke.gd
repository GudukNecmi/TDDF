extends SceneTree
## Headless check of the Bandit Camp post-fight reward: ride to a real Bandit
## Camp point, FIGHT, clear the arena, and confirm the reward screen deals two
## selections of three of the equipped weapon's own upgrades, each choice lands
## one free run-only level, the first choice is kept out of the second selection,
## and the last choice returns to the same point on the same run map.
##
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_camp_reward_smoke.gd
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

	var route := _route_to(bandits, graph, &"bandit_camp")
	if route.is_empty():
		# Every Camp sits behind another bandit point on this map: stand the
		# piece on a quiet neighbour of one and ride the last leg for real.
		route = _stand_beside(bandits, graph, &"bandit_camp")
		view.refresh()
	_ok(not route.is_empty(), "a Bandit Camp point is within reach")
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
	_ok(target >= 0, "arrived on the Bandit Camp point with its screen up")
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
	_ok(bridge.get_site_kind() == &"bandit_camp", "the staged record carries the point kind",
		String(bridge.get_site_kind()))
	var weapon := WeaponMount.get_active(root).get_definition()
	var levels_before := _run_levels(weapon)

	var ambush := _find("AmbushWaveDirector") as AmbushWaveDirector
	ambush.cleared.emit()
	for _i: int in 30:
		await process_frame
	var screen := _find("RunMapUpgradeRewardScreen") as RunMapUpgradeRewardScreen
	_ok(screen != null and screen.visible, "the Upgrade Reward screen opened after the win")
	if screen == null or not screen.visible:
		_finish()
		return
	_ok(_scene_name() == "DustCampArena", "the ride home is held while it is up", _scene_name())
	_ok(screen.get_pick() == 1, "it is on the first pick", str(screen.get_pick()))
	var first_offer := screen.get_offer()
	_check_offer(screen, weapon, first_offer, "first selection")
	_ok(not (screen.get_node(^"Panel/Body/Take") as Button).visible,
		"the single TAKE is put away for a selection")
	print("       heading: %s" % (screen.get_node(^"Panel/Body/Heading") as Label).text)

	var chosen := first_offer[0]
	var chosen_run := weapon.get_run_level(chosen)
	var chosen_base := weapon.get_upgrade_level(chosen)
	_ok(screen.choose(0), "the first choice was given")
	_ok(weapon.get_run_level(chosen) == chosen_run + 1, "it raised that run level by one")
	_ok(weapon.get_upgrade_level(chosen) == chosen_base, "the permanent Base level is untouched")
	_ok(screen.visible and screen.get_pick() == 2, "the second selection followed",
		str(screen.get_pick()))
	for _i: int in 5:
		await process_frame
	_ok(_scene_name() == "DustCampArena", "still held in the arena between picks", _scene_name())
	var second_offer := screen.get_offer()
	_check_offer(screen, weapon, second_offer, "second selection")
	_ok(not second_offer.has(chosen), "the first choice is not offered again")
	_ok(screen.choose(second_offer.size() - 1), "the second choice was given")
	_ok(not screen.visible, "the screen closed after the second choice")

	var total_gain := _sum(_run_levels(weapon)) - _sum(levels_before)
	_ok(total_gain == 2, "exactly two upgrade levels were awarded", str(total_gain))
	_ok(wallet.get_total() == carried_before, "no carried Blood was spent",
		"%d -> %d" % [carried_before, wallet.get_total()])
	_ok(bank == null or bank.get_total() == banked_before, "no banked Blood was spent")

	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "the last choice returned to the run map", _scene_name())
	var back := (_find("RunMapDirector") as RunMapDirector).get_graph()
	_ok(back.seed == made_seed and back.current_id == target,
		"it is the same map, standing at the same point")
	_ok(back.get_site(target).kind == &"bandit_camp_cleared", "the point is cleared",
		String(back.get_site(target).kind))
	_ok(_sum(_run_levels(weapon)) - _sum(levels_before) == 2,
		"the run levels survived the scene change")

	session.end()
	_ok(_sum(_run_levels(weapon)) == 0, "the rewards are forgotten when the run ends")
	_finish()


func _stand_beside(bandits: RunMapBanditNode, graph: RunMapGraph, wanted: StringName) -> PackedInt32Array:
	for site: RunMapSite in graph.sites:
		if site.kind != wanted:
			continue
		for next: int in graph.neighbours_of(site.id):
			if bandits.encounter_for(graph.get_site(next).kind) == null:
				graph.move_to(next)
				return PackedInt32Array([site.id])
	return PackedInt32Array()


func _check_offer(screen: RunMapUpgradeRewardScreen, weapon: WeaponDefinition,
		offer: Array[WeaponUpgrade], what: String) -> void:
	var names: Array[String] = []
	var own := true
	for up: WeaponUpgrade in offer:
		names.append(("*" if up.unique else "") + up.display_name)
		if not weapon.upgrades.has(up) or not up.market_unlocked:
			own = false
	print("       %s for %s: %s" % [what, weapon.weapon_id, ", ".join(names)])
	_ok(offer.size() == 3, "%s: three choices" % what, str(offer.size()))
	_ok(own, "%s: all the equipped weapon's own unlocked upgrades" % what)
	var distinct := {}
	for up: WeaponUpgrade in offer:
		distinct[up] = true
	_ok(distinct.size() == offer.size(), "%s: no upgrade twice" % what)
	var shown := 0
	for child: Node in screen.get_node(^"Panel/Body/Choices").get_children():
		if (child as Control).visible:
			shown += 1
	_ok(shown == offer.size(), "%s: one row shown per choice" % what, str(shown))


## The pool rules, checked directly against the real resources.
func _pure_checks(session: RunSessionState) -> void:
	var reward := load("res://Resources/RunMap/Rewards/bandit_camp_upgrade_reward.tres") \
		as RunMapUpgradeReward
	_ok(is_equal_approx(reward.unique_chance, 0.1), "unique chance is 10% in data")
	_ok(reward.picks == 2 and reward.choices == 3, "two picks of three in data")
	_ok(reward.pays_for(&"bandit_camp") and not reward.pays_for(&"bandit_group"),
		"only Bandit Camp points pay it")
	var catalog := session.get_weapon_catalog()
	var rng := RandomNumberGenerator.new()
	for weapon: WeaponDefinition in catalog.weapons:
		var own_uniques := 0
		for up: WeaponUpgrade in weapon.upgrades:
			if up != null and up.unique and up.market_unlocked:
				own_uniques += 1
		# The roll is once per selection: ~10% of selections carry a Unique.
		var with_unique := 0
		var ok := true
		var trials := 4000
		for i: int in trials:
			rng.seed = i
			var uniques := 0
			for up: WeaponUpgrade in reward.draw_choices(weapon, rng):
				if not weapon.upgrades.has(up) or not up.market_unlocked:
					ok = false
				if up.unique:
					uniques += 1
			if uniques > 1:
				ok = false
			with_unique += uniques
		_ok(ok, "%s: only its own unlocked upgrades, at most one Unique" % weapon.weapon_id)
		var rate := float(with_unique) / trials
		if own_uniques > 0:
			_ok(absf(rate - 0.1) < 0.02, "%s: a Unique joins ~10%% of selections" % weapon.weapon_id,
				"%.3f" % rate)
		else:
			_ok(with_unique == 0, "%s: no eligible Unique, common pool only" % weapon.weapon_id)
		# The chosen upgrade is kept out while enough else is left.
		rng.seed = 3
		var first := reward.draw_choices(weapon, rng)
		if first.is_empty():
			continue
		var avoid: Array[StringName] = [RunMapUpgradeGood.product_key(weapon, first[0])]
		var kept_out := true
		for i: int in 200:
			rng.seed = 1000 + i
			if reward.draw_choices(weapon, rng, avoid).has(first[0]):
				kept_out = false
		_ok(kept_out, "%s: the chosen upgrade is not dealt again" % weapon.weapon_id)


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
	print("[PASS] camp reward: every check passed" if _failures == 0
		else "[FAIL] camp reward: %d check(s) failed" % _failures)
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
