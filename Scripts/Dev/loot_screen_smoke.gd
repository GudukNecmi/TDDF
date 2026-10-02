extends SceneTree
## Headless check of the post-combat Loot Screen foundation: ride to a real
## Bandit Group point, win the fight, and confirm the Loot Screen - not the Horse
## Cart, not a straight ride home - opens with the game stopped under it, the
## world clock still, the game's own pointer up and no stale countdown on the HUD;
## that the pouch's real opening deals one card per reward in the bundle around
## it; that DEVAM ET is open with the ? card still unopened, asking first and
## going back to the table on GERİ DÖN with everything still there; that the ?
## opens the card selection under the game's own pointer; and that leaving with
## nothing left on the table goes straight home, without the question, to the
## same, cleared point on the same run map.
##
## Also checks the pure pieces - the layout, and a bundle of every reward type -
## without a scene.
##
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/loot_screen_smoke.gd
## [/codeblock]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	var session := root.get_node_or_null(^"RunSession") as RunSessionState
	var clock := root.get_node_or_null(^"WorldClock")
	await process_frame
	await process_frame
	_pure_checks()

	session.begin(&"desert")
	session.choose_region(&"A")
	_ok(router.go_to_region(&"A"), "the router accepted the ride out")
	await _settle()
	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
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
		target = step
	if target < 0:
		_finish()
		return

	await _await_arena()
	_ok(_scene_name() == "DustCampArena", "the fight opened in the arena", _scene_name())
	var timer_label := current_scene.find_child("TimerLabel", true, false)
	_ok(timer_label == null, "no stale countdown is on the HUD")

	var mouse_mode_in_fight := Input.get_mouse_mode()
	# The fight's own roll may drop nothing; one planted stack makes sure a loot
	# card is dealt and claimed through the real run inventory add.
	var fight_loot := (_find("WorldMapCombatBridge") as WorldMapCombatBridge).get_combat_loot()
	fight_loot.add_gem(&"smoke_gem", "Smoke Gem", 2)

	print("--- the win ---")
	var ambush := _find("AmbushWaveDirector") as AmbushWaveDirector
	ambush.cleared.emit()
	for _i: int in 30:
		await process_frame
	var loot := _find("LootScreen") as LootScreen
	var cart := HorseCartScreen.get_active(current_scene)
	_ok(loot != null and loot.is_open(), "the Loot Screen opened after the win")
	_ok(cart == null or not cart.is_open(), "the Horse Cart stepped aside for it")
	_ok(_scene_name() == "DustCampArena", "the ride home is held while it is up", _scene_name())
	_ok(paused, "the game is stopped under it")
	if loot == null or not loot.is_open():
		_finish()
		return

	var degree_before: float = clock.get_world_degree() if clock != null else 0.0
	for _i: int in 60:
		await process_frame
	var degree_after: float = clock.get_world_degree() if clock != null else 0.0
	_ok(is_equal_approx(degree_before, degree_after), "the world clock does not move under it",
		"%.3f -> %.3f" % [degree_before, degree_after])

	var cursor := current_scene.find_child("GameCursor", true, false) as GameCursor
	_ok(cursor != null and cursor.is_pointer_wanted(), "the game's own pointer is up")
	# The system pointer is [GameCursor]'s to hide; the Loot Screen must never
	# change what it set. (Headless has no real pointer, so the mode is compared,
	# not asserted hidden.)
	_ok(Input.get_mouse_mode() == mouse_mode_in_fight, "the pointer mode is untouched by it",
		"%d -> %d" % [mouse_mode_in_fight, Input.get_mouse_mode()])
	_ok(cursor != null and cursor.hide_system_cursor, "the game cursor is the one hiding the system pointer")

	var player := current_scene.get_tree().get_first_node_in_group(&"player") as Node2D
	var player_at := player.global_position if player != null else Vector2.ZERO
	var move := InputEventAction.new()
	move.action = &"move_right"
	move.pressed = true
	Input.parse_input_event(move)
	for _i: int in 20:
		await process_frame
	move.pressed = false
	Input.parse_input_event(move)
	_ok(player == null or player.global_position.is_equal_approx(player_at),
		"the player cannot move about the arena under it")

	var bundle := loot.get_bundle()
	var stacks := (_find("WorldMapCombatBridge") as WorldMapCombatBridge).get_combat_loot().get_stacks()
	var direct := 0
	for reward: LootReward in bundle.rewards:
		if reward is LootRewardCharm or reward is LootRewardHealth:
			direct += 1
	print("       bundle: %d rewards (%d loot stacks, %d from the pouch)" % [bundle.size(),
		stacks.size(), direct])
	_ok(bundle.size() == stacks.size() + 1 + direct,
		"the bundle is the fight's loot, the pouch's own loot and its ? card")
	_ok(loot.get_cards().is_empty(), "nothing is on the table before the pouch is opened")

	print("--- the pouch ---")
	var pouch := loot.get_node(^"Table/Pouch") as LootPouch
	var dealt := [false]
	loot.revealed.connect(func() -> void: dealt[0] = true, CONNECT_ONE_SHOT)
	pouch.pressed.emit()
	_ok(pouch.is_opening(), "clicking the pouch starts its opening")
	var waited := 0
	while not dealt[0] and waited < 600:
		waited += 1
		await process_frame
	_ok(dealt[0], "the pouch opened and dealt the rewards")
	_ok(pouch.is_open(), "and sits open")
	var cards := loot.get_cards()
	_ok(cards.size() == bundle.size(), "one card per reward", "%d/%d" % [cards.size(), bundle.size()])
	var centre := pouch.get_global_rect().get_center()
	var around := true
	for card: LootRewardCard in cards:
		if card.get_global_rect().get_center().distance_to(centre) < 100.0:
			around = false
	_ok(around, "the cards lie around the pouch, not on it")
	_ok(loot.is_open(), "the screen stays up once the rewards are out")

	print("--- resolving ---")
	var leave_button := loot.get_node(^"Table/Leave") as Button
	_ok(loot.can_leave() and leave_button.visible and not leave_button.disabled,
		"DEVAM ET is clickable with the ? unopened")
	var mysteries: Array[LootRewardCard] = []
	for card: LootRewardCard in cards:
		if card.get_reward() is LootRewardMystery:
			mysteries.append(card)
	_ok(mysteries.size() == 1, "a Bandit Group dealt exactly one ? card", str(mysteries.size()))
	leave_button.pressed.emit()
	var question := loot.get_node(^"Confirm/Box/Content/Question") as Label
	_ok(loot.is_confirming() and question.is_visible_in_tree()
		and question.text == "Almadan devam etmek istediğine emin misin?",
		"pressing it with rewards left asks first", question.text)
	_ok(loot.is_open() and _scene_name() == "DustCampArena", "and nothing has been left yet")
	var choices := RewardChoiceScreen.get_active(loot)
	loot.activate(mysteries[0])
	_ok(not choices.is_open(), "the table is held still under the question")
	(loot.get_node(^"Confirm/Box/Content/Buttons/Back") as Button).pressed.emit()
	_ok(not loot.is_confirming() and loot.is_open(), "GERİ DÖN goes back to the table")
	_ok(not mysteries[0].get_reward().is_resolved() and not mysteries[0].get_reward().is_forfeited()
		and mysteries[0].get_reward().can_activate(loot.get_bundle().context),
		"with the ? still there to take")
	loot.activate(mysteries[0])
	_ok(choices != null and choices.is_open(), "the ? opened the card selection over the table")
	_ok(not loot.can_leave(), "still not while it is up")
	var pointer_ok := true
	var waited_reveal := 0
	while choices != null and not choices.is_choosing() and waited_reveal < 4000:
		waited_reveal += 1
		if not (cursor.is_pointer_wanted() and Input.get_mouse_mode() == mouse_mode_in_fight):
			pointer_ok = false
		await process_frame
	_ok(choices.is_choosing(), "the cards were revealed")
	_ok(choices.get_reveal_order() == [0, 1, 2], "left to right", str(choices.get_reveal_order()))
	var choice := choices.get_cards()[0].get_choice()
	var weapon := WeaponMount.get_active(current_scene).get_definition()
	var before := 0
	for up: WeaponUpgrade in weapon.upgrades:
		before += weapon.get_run_level(up)
	choices.choose(0)
	var waited_close := 0
	while choices.is_open() and waited_close < 4000:
		waited_close += 1
		if not (cursor.is_pointer_wanted() and Input.get_mouse_mode() == mouse_mode_in_fight):
			pointer_ok = false
		await process_frame
	_ok(pointer_ok, "the game's pointer stayed up and the pointer mode untouched throughout")
	var after := 0
	for up: WeaponUpgrade in weapon.upgrades:
		after += weapon.get_run_level(up)
	if choice is RewardChoiceUpgrade:
		_ok(after - before == (choice as RewardChoiceUpgrade).get_levels(),
			"the taken card landed through the weapon's run stack",
			"%s %s" % [choice.get_rarity_name(), choice.get_title()])
	else:
		_ok(weapon.is_legendary_active((choice as RewardChoiceLegendary).legendary),
			"the taken Legendary is on")
	_ok(mysteries[0].get_reward().is_resolved(), "taking it settled the ?")
	var inventory := RunInventory.get_active(current_scene)
	var gem_card: LootRewardCard = null
	for card: LootRewardCard in cards:
		if card.get_reward() is LootRewardStack:
			if (card.get_reward() as LootRewardStack).stack.item_id == &"smoke_gem":
				gem_card = card
			loot.activate(card)
			print("       %s -> %s" % [card.get_reward().get_title(),
				"taken" if card.get_reward().is_resolved() else card.get_reward().get_status_text()])
	_ok(gem_card != null and gem_card.get_reward().is_resolved(), "the gem card was claimed")
	_ok(inventory != null and _carried(inventory, &"smoke_gem") == 2,
		"and the gems are in the run inventory",
		str(_carried(inventory, &"smoke_gem")) if inventory != null else "<no inventory>")
	# Whatever else the pouch gave is taken too, so the table is bare.
	for card: LootRewardCard in cards:
		if not card.get_reward().is_resolved():
			loot.activate(card)
	_ok(not loot.get_bundle().has_unclaimed(), "nothing is left on the table")
	_ok(loot.request_leave() and not loot.is_confirming(),
		"DEVAM ET with nothing left leaves at once, without asking")

	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "leaving returned to the run map", _scene_name())
	_ok(not paused, "the game runs again on the map")
	var back := (_find("RunMapDirector") as RunMapDirector).get_graph()
	_ok(back.seed == made_seed and back.current_id == target,
		"it is the same map, standing at the same point")
	_ok(back.get_site(target).kind == &"bandit_group_cleared", "the point is cleared",
		String(back.get_site(target).kind))
	_ok(_count("LootScreen") == 0 or not (_find("LootScreen") as LootScreen).is_open(),
		"no Loot Screen is left over on the map")

	session.end()
	_finish()


## The layout and every reward type, off any scene.
func _pure_checks() -> void:
	var layout := load("res://Resources/Loot/loot_layout_table.tres") as LootLayout
	_ok(layout != null, "the table layout loads")
	for count: int in [1, 2, 3, 8, 11]:
		var spots := layout.positions(count)
		var distinct := true
		for i: int in spots.size():
			for j: int in range(i + 1, spots.size()):
				if spots[i].distance_to(spots[j]) < 60.0:
					distinct = false
		_ok(spots.size() == count and distinct, "%d cards get %d separate places" % [count, count])

	var bundle := LootBundle.new()
	var plain := LootReward.new()
	var paid := LootRewardPayout.new()
	paid.mark_resolved()
	var other := LootReward.new()
	bundle.add(plain)
	bundle.add(paid)
	bundle.add(other)
	_ok(bundle.can_leave() and bundle.has_unclaimed() and bundle.get_unclaimed().size() == 2,
		"unclaimed rewards never hold the table")
	other.activate(LootContext.new())
	_ok(bundle.get_unclaimed().size() == 1 and bundle.get_unclaimed()[0] == plain, "taking one leaves the other unclaimed")
	bundle.forfeit_unclaimed()
	_ok(plain.is_forfeited() and not plain.is_resolved() and not plain.can_activate(LootContext.new()),
		"leaving forfeits what was left - for good")
	_ok(not other.is_forfeited() and not paid.is_forfeited(), "and touches nothing already taken")
	_ok(not bundle.has_unclaimed(), "nothing is unclaimed once it is forfeited")

	for path: String in ["res://Resources/Loot/Sources/source_mystery_cards.tres",
			"res://Resources/Loot/Sources/source_weapon_upgrade.tres",
			"res://Resources/Loot/Sources/source_combat_loot.tres",
			"res://Resources/Loot/Sources/source_bounty_payout.tres"]:
		_ok(load(path) is LootSource, "%s loads as a source" % path.get_file())
	var upgrade_source := load("res://Resources/Loot/Sources/source_weapon_upgrade.tres") \
		as LootSourceUpgrade
	var group := upgrade_source.rewards[0] if upgrade_source.rewards.size() > 0 else null
	var camp := upgrade_source.rewards[1] if upgrade_source.rewards.size() > 1 else null
	_ok(group != null and group.picks == 1 and group.choices == 1 and group.pays_for(&"bandit_group"),
		"the Bandit Group still pays one upgrade")
	_ok(camp != null and camp.picks == 2 and camp.choices == 3 and camp.pays_for(&"bandit_camp"),
		"the Bandit Camp still pays two picks of three")


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


func _await_arena() -> void:
	var waited := 0.0
	while _scene_name() != "DustCampArena" and waited < 10.0:
		await create_timer(0.05).timeout
		waited += 0.05
	await _settle()


func _settle() -> void:
	var guard := 0
	var curtain := LoadingCurtain.get_active(root)
	while curtain != null and curtain.is_loading() and guard < 4000:
		guard += 1
		await process_frame
	for _step: int in 12:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("LOOT SCREEN SMOKE: ALL PASSED")
	else:
		print("LOOT SCREEN SMOKE: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	var line := ("  ok   " if condition else "  FAIL ") + what
	if not detail.is_empty():
		line += "  (%s)" % detail
	print(line)
	if not condition:
		_failures += 1


func _scene_name() -> String:
	return current_scene.name if current_scene != null else ""


func _count(node_name: String) -> int:
	return root.find_children(node_name, "", true, false).size()


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


func _carried(inventory: RunInventory, item_id: StringName) -> int:
	var total := 0
	for stack: RunItemStack in inventory.find_stacks(item_id):
		total += stack.count
	return total
