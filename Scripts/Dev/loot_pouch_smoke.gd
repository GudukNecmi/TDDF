extends SceneTree
## Headless check of the Loot Screen's pouch and the direct loot that comes out
## of it: ride to a real Bandit Group point, win, and confirm that the pouch
## really opens (cord undone, slumped flat) and stays on the table open; that a
## Charm, a Gem heap and a Health item spill out of its mouth as physical
## objects and settle apart from one another; that each is collected through its
## own authority - the Charm into [RunCharmHolder] and the HUD, the Gems into
## [RunInventory], the Health through the player's own [Health] at exactly its
## data's share - with its own sound and never twice; that DEVAM ET is open the
## whole time, asking first while the ? is still unopened; and that riding on
## without it forfeits it - no upgrade given - and returns to the same cleared
## point.
##
## Also checks the pure pieces off any scene: the Gem quantity rule, the Health
## items' values, Charm stacking, and collectible Blood paying once.
##
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/loot_pouch_smoke.gd
## [/codeblock]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	var session := root.get_node_or_null(^"RunSession") as RunSessionState
	await process_frame
	await process_frame
	_pure_checks()

	# Make sure the pouch holds one of each direct kind this time: the drop chance
	# is the data's, so the check raises it rather than hoping.
	var charm_source := load("res://Resources/Loot/Sources/source_charms.tres") as LootSourceCharms
	var health_source := load("res://Resources/Loot/Sources/source_health_items.tres") \
		as LootSourceHealthItems
	charm_source.chance = 1.0
	health_source.chance = 1.0

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

	# A real Gem from the existing Gem data, in a quantity the existing rule rolls.
	var table := load("res://Resources/World/combat_loot_table.tres") as CombatLootTable
	var colour := table.gem_colors[0]
	var gem_count := table.roll_gem_quantity(40.0)
	var fight_loot := (_find("WorldMapCombatBridge") as WorldMapCombatBridge).get_combat_loot()
	fight_loot.add_gem(colour.id, colour.display_name, gem_count, table.gem_stack_max, colour.icon)

	var player := current_scene.get_tree().get_first_node_in_group(&"player")
	var health: Health = null
	for node: Node in player.find_children("*", "Health", true, false):
		health = node as Health
		break
	health.set_current(health.get_max() * 0.2)
	var mouse_mode := Input.get_mouse_mode()

	print("--- the win ---")
	(_find("AmbushWaveDirector") as AmbushWaveDirector).cleared.emit()
	for _i: int in 30:
		await process_frame
	var loot := _find("LootScreen") as LootScreen
	_ok(loot != null and loot.is_open(), "the Loot Screen opened after the win")
	if loot == null or not loot.is_open():
		_finish()
		return
	var cursor := current_scene.find_child("GameCursor", true, false) as GameCursor
	var bundle := loot.get_bundle()
	var kinds := {}
	for reward: LootReward in bundle.rewards:
		kinds[reward.get_script().get_global_name()] = true
	_ok(kinds.has("LootRewardMystery") and kinds.has("LootRewardCharm")
		and kinds.has("LootRewardHealth") and kinds.has("LootRewardStack"),
		"the bundle holds the ?, a Charm, a Health item and the Gems", str(kinds.keys()))

	print("--- the pouch ---")
	var pouch := loot.get_node(^"Table/Pouch") as LootPouch
	var sounds := loot.get_node(^"Sounds") as SoundBank
	for name: StringName in [&"pouch_open", &"pouch_spill", &"loot_land", &"collect_charm",
			&"collect_gem", &"collect_health", &"collect_blood"]:
		_ok(sounds.has_sound(name), "the table's sound bank has %s" % name)
	var spill_flatten := [-1.0]
	var spill_starts: Array[float] = []
	pouch.burst.connect(func() -> void:
		spill_flatten[0] = pouch.flatten
		var mouth := pouch.get_spill_point()
		for card: LootRewardCard in loot.get_cards():
			if card is LootTableObject:
				spill_starts.append(card.get_global_rect().get_center().distance_to(mouth)),
		CONNECT_ONE_SHOT)
	var dealt := [false]
	loot.revealed.connect(func() -> void: dealt[0] = true, CONNECT_ONE_SHOT)
	pouch.pressed.emit()
	_ok(pouch.is_opening(), "clicking the pouch starts its opening")
	_ok(_playing(sounds, &"pouch_open"), "the pouch opening sound plays")
	var untie_seen := false
	var flat_before_burst := true
	var waited := 0
	var pointer_ok := true
	while not dealt[0] and waited < 900:
		waited += 1
		if pouch.untie > 0.0 and pouch.untie < 1.0:
			untie_seen = true
		if spill_flatten[0] < 0.0 and pouch.flatten >= 1.0:
			flat_before_burst = false
		if not (cursor.is_pointer_wanted() and Input.get_mouse_mode() == mouse_mode):
			pointer_ok = false
		await process_frame
	_ok(untie_seen, "the cord was worked loose over several frames")
	_ok(spill_flatten[0] > 0.0 and spill_flatten[0] < 1.0 and flat_before_burst,
		"the rewards poured out part way through the slump", "%.2f" % spill_flatten[0])
	_ok(not spill_starts.is_empty() and spill_starts.max() < 40.0,
		"every piece left from the pouch's mouth",
		"%.0fpx" % (spill_starts.max() if not spill_starts.is_empty() else -1.0))
	_ok(dealt[0] and pouch.is_open(), "the pouch opened and dealt the rewards")
	_ok(pouch.visible and is_equal_approx(pouch.flatten, 1.0), "and lies open, flat, on the table")
	_ok(pouch.mouse_filter == Control.MOUSE_FILTER_IGNORE, "open, it lets the mouse through")
	_ok(pointer_ok, "the game's pointer stayed up through the opening")

	var objects: Array[LootTableObject] = []
	var charm_object: LootTableObject = null
	var gem_object: LootTableObject = null
	var health_object: LootTableObject = null
	var mystery_card: LootRewardCard = null
	for card: LootRewardCard in loot.get_cards():
		var reward := card.get_reward()
		if reward is LootRewardMystery:
			mystery_card = card
		if card is LootTableObject:
			objects.append(card as LootTableObject)
			if reward is LootRewardCharm:
				charm_object = card as LootTableObject
			elif reward is LootRewardHealth:
				health_object = card as LootTableObject
			elif reward is LootRewardStack and (reward as LootRewardStack).stack.category == &"gem":
				gem_object = card as LootTableObject
	_ok(charm_object != null and gem_object != null and health_object != null,
		"the Charm, the Gems and the Health item lie on the table as objects")
	_ok(mystery_card != null and not (mystery_card is LootTableObject), "the ? is still a card")
	var apart := true
	var settled := true
	for i: int in objects.size():
		var a := objects[i].get_global_rect().get_center()
		if not is_equal_approx(objects[i].rotation, 0.0) or not objects[i].scale.is_equal_approx(
				Vector2.ONE):
			settled = false
		for card: LootRewardCard in loot.get_cards():
			if card != objects[i] and card.get_global_rect().get_center().distance_to(a) < 80.0:
				apart = false
	_ok(apart, "no two things on the table lie on top of one another")
	_ok(settled, "every object has come to rest")

	print("--- looking ---")
	charm_object._on_hover(true)
	var tip := charm_object.get_node(^"Tooltip") as Control
	var tip_title := charm_object.get_node(^"Tooltip/Body/Title") as Label
	var tip_detail := charm_object.get_node(^"Tooltip/Body/Detail") as Label
	var charm := (charm_object.get_reward() as LootRewardCharm).charm
	_ok(tip.visible and tip_title.text == charm.display_name and tip_detail.text == charm.description,
		"hovering the Charm shows its Turkish name and description", tip_title.text)
	_ok(not tip_title.text.contains("charm_") and not tip_title.text.contains("res://"),
		"and no internal id")
	charm_object._on_hover(false)
	health_object._on_hover(true)
	var item := (health_object.get_reward() as LootRewardHealth).item
	_ok((health_object.get_node(^"Tooltip/Body/Detail") as Label).text == item.description,
		"hovering the Health item shows its value", item.description)
	health_object._on_hover(false)
	gem_object._on_hover(true)
	_ok((gem_object.get_node(^"Tooltip/Body/Title") as Label).text.begins_with(colour.display_name),
		"hovering the Gems shows the Gem data's own name",
		(gem_object.get_node(^"Tooltip/Body/Title") as Label).text)
	gem_object._on_hover(false)

	print("--- collecting ---")
	_ok(loot.can_leave(), "DEVAM ET is open with everything still on the table")
	var leave := loot.get_node(^"Table/Leave") as Button
	_ok(leave.text == "DEVAM ET" and not leave.disabled, "the button reads DEVAM ET, clickable",
		leave.text)
	var holder := RunCharmHolder.get_active(loot)
	var worn := holder.get_count(charm)
	loot.activate(charm_object)
	_ok(holder.get_count(charm) == worn + 1, "taking the Charm puts it on through the Charm authority")
	_ok(_playing(sounds, &"collect_charm"), "with the Charm sound")
	var hud := current_scene.find_child("CharmHud", true, false) as CharmHud
	_ok(hud != null and hud.is_visible_in_tree() and holder.get_kinds().has(charm),
		"and it shows in the Charm HUD")
	loot.activate(charm_object)
	_ok(holder.get_count(charm) == worn + 1, "a second click takes nothing")
	await create_timer(charm_object.collect_time + 0.25, true).timeout
	_ok(charm_object.is_collected() and not charm_object.visible
		and charm_object.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the collected Charm has left the table")

	var inventory := RunInventory.get_active(current_scene)
	var carried := _carried(inventory, colour.id)
	var heap := gem_object.get_reward().get_amount()
	_ok(heap >= gem_count, "the heap holds the Gems the fight left", "%d" % heap)
	loot.activate(gem_object)
	_ok(_carried(inventory, colour.id) == carried + heap,
		"the Gems went into the run inventory", "%d + %d" % [carried, heap])
	_ok(_playing(sounds, &"collect_gem"), "with the Gem sound")
	loot.activate(gem_object)
	_ok(_carried(inventory, colour.id) == carried + heap, "and cannot be taken twice")

	var before := health.get_current()
	var expected := minf(before + health.get_max() * item.heal_fraction, health.get_max())
	loot.activate(health_object)
	_ok(is_equal_approx(health.get_current(), expected),
		"%s healed exactly its share through the player's Health" % item.display_name,
		"%.2f -> %.2f of %.2f" % [before, health.get_current(), health.get_max()])
	_ok(_playing(sounds, &"collect_health"), "with the Health sound")
	loot.activate(health_object)
	_ok(is_equal_approx(health.get_current(), expected), "and cannot be drunk twice")
	var unclaimed := bundle.get_unclaimed()
	_ok(unclaimed.size() == 1 and unclaimed[0] == mystery_card.get_reward(),
		"only the ? is left unclaimed", str(unclaimed.size()))

	print("--- leaving the ? behind ---")
	var choices := RewardChoiceScreen.get_active(loot)
	var weapon := WeaponMount.get_active(current_scene).get_definition()
	var levels_before := _total_run_levels(weapon)
	_ok(loot.can_leave() and not leave.disabled, "DEVAM ET is still clickable with the ? unopened")
	leave.pressed.emit()
	_ok(loot.is_confirming(), "it asks before riding on without the ?")
	_ok((loot.get_node(^"Confirm/Box/Content/Buttons/Leave") as Button).text == "DEVAM ET"
		and (loot.get_node(^"Confirm/Box/Content/Buttons/Back") as Button).text == "GERİ DÖN",
		"offering DEVAM ET and GERİ DÖN")
	(loot.get_node(^"Confirm/Box/Content/Buttons/Back") as Button).pressed.emit()
	_ok(not loot.is_confirming() and loot.is_open() and not mystery_card.disabled,
		"GERİ DÖN is back at the table, the ? still clickable")
	_ok(bundle.get_unclaimed().size() == 1, "and still unclaimed")
	_ok(cursor.is_pointer_wanted() and Input.get_mouse_mode() == mouse_mode,
		"the game's pointer is still the one up")
	var held := holder.get_count(charm)
	var held_gems := _carried(inventory, colour.id)
	leave.pressed.emit()
	_ok(loot.is_confirming(), "asked again")
	(loot.get_node(^"Confirm/Box/Content/Buttons/Leave") as Button).pressed.emit()
	_ok(mystery_card.get_reward().is_forfeited() and not mystery_card.get_reward().is_resolved(),
		"DEVAM ET forfeits the ?")
	_ok(not choices.is_open(), "no selection was dealt for it")
	loot.activate(mystery_card)
	_ok(not choices.is_open(), "and it cannot be opened any more")
	_ok(_carried(inventory, colour.id) == held_gems and holder.get_count(charm) == held,
		"leaving paid nothing a second time")

	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "DEVAM ET returned to the run map", _scene_name())
	var back := (_find("RunMapDirector") as RunMapDirector).get_graph()
	_ok(back.seed == made_seed and back.current_id == target,
		"the same map, at the same point - not one further")
	_ok(back.get_site(target).kind == &"bandit_group_cleared", "the point is cleared")
	_ok(holder.get_count(charm) == held, "the Charm is still worn on the map")
	_ok(_total_run_levels(weapon) == levels_before, "the forfeited ? gave no upgrade")
	_ok(not paused, "the game runs again")
	session.end()
	_ok(holder.get_total() == 0, "the run ending takes the Charms off")
	_finish()


## The rules and the authorities, off any scene.
func _pure_checks() -> void:
	var table := load("res://Resources/World/combat_loot_table.tres") as CombatLootTable
	var low := 99
	var high := 0
	for strength: float in [5.0, 10.0, 40.0, 70.0, 200.0]:
		for _i: int in 400:
			var count := table.roll_gem_quantity(strength)
			low = mini(low, count)
			high = maxi(high, count)
	_ok(low >= 1 and high <= 5, "the existing Gem rule gives 1-5 Gems", "%d-%d" % [low, high])
	var source := load("res://Resources/Loot/Sources/source_combat_loot.tres") as LootSourceCombatLoot
	_ok(source != null and not source.has_method(&"roll_gem_quantity"),
		"the Loot Screen's Gem source rolls nothing of its own")

	var values := {}
	for path: String in ["res://Resources/Loot/Health/whisky_glass.tres",
			"res://Resources/Loot/Health/whisky_bottle_35.tres",
			"res://Resources/Loot/Health/whisky_bottle_50.tres"]:
		var item := load(path) as HealthLootDefinition
		values[item.id] = item.heal_fraction
	_ok(is_equal_approx(values.get(&"whisky_glass", 0.0), 0.10)
		and is_equal_approx(values.get(&"whisky_bottle_35", 0.0), 0.25)
		and is_equal_approx(values.get(&"whisky_bottle_50", 0.0), 0.50),
		"glass +10%, 35cl +25%, 50cl +50%", str(values))

	var holder := root.get_node_or_null(^"Charms") as RunCharmHolder
	_ok(holder != null, "the Charms autoload is up")
	var step := load("res://Resources/Charms/charm_devils_step.tres") as CharmDefinition
	for _i: int in 25:
		holder.add_charm(step)
	_ok(holder.get_count(step) == 25 and holder.get_kinds().size() == 1,
		"the same Charm stacks, with no cap")
	holder.clear()

	var wallet := root.get_node_or_null(^"Blood") as BloodWallet
	var context := LootContext.new()
	context.host = holder
	var blood := LootRewardBlood.new()
	blood.amount = 25
	_ok(blood.get_detail() == "+25 Kan", "the Blood reads its amount", blood.get_detail())
	var purse := wallet.get_total()
	blood.activate(context)
	blood.activate(context)
	_ok(wallet.get_total() == purse + 25 and blood.is_resolved(),
		"collecting Blood pays the carried wallet once")
	wallet.spend(25)

	var bundle := LootBundle.new()
	var optional := LootRewardHealth.new()
	bundle.add(optional)
	_ok(bundle.can_leave(), "uncollected loot never holds the table")

	var left := LootBundle.new()
	var lying := LootRewardBlood.new()
	lying.amount = 40
	left.add(lying)
	_ok(left.can_leave() and left.has_unclaimed(), "uncollected Blood never holds the table")
	purse = wallet.get_total()
	left.forfeit_unclaimed()
	lying.activate(context)
	_ok(wallet.get_total() == purse and lying.is_forfeited() and not lying.is_resolved(),
		"Blood left on the table is forfeited and never paid")


func _playing(bank: SoundBank, sound: StringName) -> bool:
	var stream := bank.sounds.get(sound) as AudioStream
	for voice: Node in bank.get_children():
		var player := voice as AudioStreamPlayer
		if player != null and player.playing and player.stream == stream:
			return true
	return false


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
		print("LOOT POUCH SMOKE: ALL PASSED")
	else:
		print("LOOT POUCH SMOKE: %d FAILED" % _failures)
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


func _total_run_levels(weapon: WeaponDefinition) -> int:
	var total := 0
	for upgrade: WeaponUpgrade in weapon.upgrades:
		total += weapon.get_run_level(upgrade)
	return total


func _carried(inventory: RunInventory, item_id: StringName) -> int:
	var total := 0
	for stack: RunItemStack in inventory.find_stacks(item_id):
		total += stack.count
	return total
