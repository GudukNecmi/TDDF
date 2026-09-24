extends SceneTree
## Headless check of the run map's market point: that arriving on one opens the
## market and not the saloon; that its shelf is four upgrades for the carried
## weapon and one Card; that Uniques, locks and other weapons' upgrades obey the
## pool; that buying raises the run stack or adds the Card out of carried blood
## only; that the reroll tip deals five fresh products none of which were on the
## previous shelf; that BACK and the close key both return to the map; that
## walking back in finds the shelf as it was left; and that ending the run
## forgets everything bought.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_market_smoke.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_check_pool()
	await _check_market()

	print("")
	if _failures == 0:
		print("[PASS] run map market: every check passed")
	else:
		print("[FAIL] run map market: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


# --- The pool on its own ------------------------------------------------------------

func _check_pool() -> void:
	var session := root.get_node_or_null(^"RunSession") as RunSessionState
	var catalog := session.get_weapon_catalog()
	var revolver := catalog.find(&"revolver")
	var shotgun := catalog.find(&"shotgun")
	var products := load("res://Resources/RunMap/Market/market_products_roadside.tres") as RunMapMarketProducts
	_ok(products != null and revolver != null and shotgun != null, "the product pool and weapons load")
	if products == null or revolver == null or shotgun == null:
		return
	_ok(is_equal_approx(products.unique_chance, 0.05), "the Unique chance is 5%")
	var none: Array[StringName] = []

	var shelf := products.deal(revolver, none, 1)
	_ok(shelf.size() == 5, "a shelf is five products", "%d" % shelf.size())
	var upgrades := 0
	for i: int in range(mini(shelf.size(), 4)):
		var good := shelf[i] as RunMapUpgradeGood
		if good != null and good.weapon == revolver and revolver.upgrades.has(good.upgrade):
			upgrades += 1
	_ok(upgrades == 4, "the first four are the revolver's own upgrades", "%d" % upgrades)
	_ok(shelf.size() == 5 and shelf[4] is RunMapCardGood, "the fifth is a Card")

	# Uniques: never another weapon's, and only on the Unique roll.
	var saved_chance := products.unique_chance
	var foreign := false
	var unique_seen := 0
	for seed_value: int in range(400):
		for good: RunMapSaloonGood in products.deal(revolver, none, seed_value):
			var upgrade_good := good as RunMapUpgradeGood
			if upgrade_good == null:
				continue
			if not revolver.upgrades.has(upgrade_good.upgrade):
				foreign = true
			if upgrade_good.upgrade.unique:
				unique_seen += 1
	_ok(not foreign, "no upgrade from another weapon was ever dealt")
	_ok(unique_seen > 0 and unique_seen < 80,
		"Uniques turn up rarely at 5%", "%d in 1600 slots" % unique_seen)

	products.unique_chance = 0.0
	var any_unique := false
	for seed_value: int in range(200):
		for good: RunMapSaloonGood in products.deal(shotgun, none, seed_value):
			if good is RunMapUpgradeGood and (good as RunMapUpgradeGood).upgrade.unique:
				any_unique = true
	_ok(not any_unique, "at 0% no Unique is ever dealt")

	products.unique_chance = 1.0
	var shotgun_shelf := products.deal(shotgun, none, 7)
	var shotgun_uniques := 0
	for good: RunMapSaloonGood in shotgun_shelf:
		if good is RunMapUpgradeGood and (good as RunMapUpgradeGood).upgrade.unique:
			shotgun_uniques += 1
	_ok(shotgun_uniques == 2 and shotgun_shelf.size() == 5,
		"at 100% the shotgun deals both its Uniques, then falls back to commons",
		"%d unique(s), %d product(s)" % [shotgun_uniques, shotgun_shelf.size()])

	var plain := WeaponDefinition.new()
	plain.weapon_id = &"plain"
	for upgrade: WeaponUpgrade in revolver.upgrades:
		if not upgrade.unique:
			plain.upgrades.append(upgrade)
	var plain_shelf := products.deal(plain, none, 3)
	_ok(plain_shelf.size() == 5, "a weapon with no Unique deals from the common pool instead")
	products.unique_chance = saved_chance

	# Locked upgrades never appear.
	var locked := revolver.upgrades[0]
	locked.market_unlocked = false
	var locked_seen := false
	for seed_value: int in range(300):
		for good: RunMapSaloonGood in products.deal(revolver, none, seed_value):
			if good is RunMapUpgradeGood and (good as RunMapUpgradeGood).upgrade == locked:
				locked_seen = true
	locked.market_unlocked = true
	_ok(not locked_seen, "a locked upgrade is never dealt")

	# The previous refresh has no chance; the one after it has its normal odds.
	var previous := RunMapMarketProducts.key_of(shelf[0])
	var repeats := false
	var came_back := false
	var last := shelf
	for refresh: int in range(1, 200):
		var excluded: Array[StringName] = []
		for good: RunMapSaloonGood in last:
			excluded.append(RunMapMarketProducts.key_of(good))
		var next := products.deal(revolver, excluded, refresh)
		for good: RunMapSaloonGood in next:
			if excluded.has(RunMapMarketProducts.key_of(good)):
				repeats = true
			if RunMapMarketProducts.key_of(good) == previous and refresh > 1:
				came_back = true
		last = next
	_ok(not repeats, "no refresh ever repeats a product from the one before it")
	_ok(came_back, "a product excluded once comes back on later refreshes")


# --- The screen, in the run map -----------------------------------------------------

func _check_market() -> void:
	# The autoloads resolve their absolute paths only once the tree is running.
	await process_frame
	var session := root.get_node_or_null(^"RunSession") as RunSessionState
	session.begin(&"desert")
	session.choose_region(&"A")
	session.choose_weapon(&"revolver")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(4):
		await process_frame

	var director := _find_first("RunMapDirector") as RunMapDirector
	var view := _find_first("RunMapView") as RunMapView
	var node := _find_first("RunMapMarketNode") as RunMapMarketNode
	var screen := _find_first("RunMapMarketScreen") as RunMapMarketScreen
	var saloon := _find_first("RunMapSaloonScreen") as RunMapSaloonScreen
	_ok(director != null and view != null and node != null and screen != null,
		"the map opened with its market point and its market screen")
	if director == null or view == null or node == null or screen == null:
		return

	var graph := director.get_graph()
	var market: RunMapSite = null
	for site: RunMapSite in graph.sites:
		if node.answers(site.kind):
			market = site
			break
	_ok(market != null, "the map dealt out at least one market")
	if market == null:
		return
	var standing_on := graph.current_id

	# --- walking in ---------------------------------------------------------
	director.site_reached.emit(market)
	await process_frame
	_ok(screen.is_open(), "arriving on a market opened it")
	_ok(saloon == null or not saloon.is_open(), "a market is not the saloon")
	_ok(not view.is_picking(), "the map's roads are closed while the market is up")
	_ok(paused, "the world is frozen while the market is up")

	var rows := _rows(screen)
	_ok(screen.products != null, "the market has a product pool")
	_ok(rows.size() == 5 and screen.goods.size() == 5,
		"it opened straight onto a five-product shelf",
		"%d row(s) against %d good(s)" % [rows.size(), screen.goods.size()])
	var reroll := screen.get_node_or_null(^"Panel/Body/Reroll") as Button
	_ok(reroll != null and reroll.visible, "the reroll button is up")

	# --- buying -------------------------------------------------------------
	var wallet := root.get_node_or_null(^"Blood") as BloodWallet
	var bank := root.get_node_or_null(^"BloodBank") as BloodWallet
	var cards := root.get_node_or_null(^"RunCards") as RunCardHolder
	wallet.add(5000)
	var banked := bank.get_total()
	var upgrade_good := screen.goods[0] as RunMapUpgradeGood
	var bought_key := RunMapMarketProducts.key_of(upgrade_good)
	var weapon := upgrade_good.weapon
	var base_level := weapon.get_upgrade_level(upgrade_good.upgrade)
	var price := upgrade_good.get_price(screen)
	var purse := wallet.get_total()
	rows[0].pressed.emit()
	await process_frame
	_ok(weapon.get_run_level(upgrade_good.upgrade) == 1, "buying an upgrade raised its run stack to 1")
	_ok(weapon.get_upgrade_level(upgrade_good.upgrade) == base_level, "the Base level did not move")
	_ok(wallet.get_total() == purse - price, "it cost exactly what the row said, in carried blood",
		"%d spent against %d quoted" % [purse - wallet.get_total(), price])
	_ok(bank.get_total() == banked, "the BloodBank was not touched")
	_ok(rows[0].disabled, "the bought slot is sold")

	var card_good := screen.goods[4] as RunMapCardGood
	purse = wallet.get_total()
	rows[4].pressed.emit()
	await process_frame
	_ok(cards.get_count(card_good.card) == 1, "buying the Card put it in the run's hand")
	_ok(wallet.get_total() == purse - card_good.get_price(screen), "the Card cost its price")

	# --- BACK and walking back in -------------------------------------------
	var first_keys := _keys(screen)
	_press(screen, ^"Panel/Body/Back")
	await process_frame
	_ok(not screen.is_open(), "BACK left the market")
	_ok(view.is_picking(), "the map is taking a choice again")
	_ok(graph.current_id == standing_on, "the piece did not move")
	_ok(not paused, "the world is running again")

	director.site_reached.emit(market)
	await process_frame
	rows = _rows(screen)
	_ok(screen.is_open(), "the same market opened again")
	_ok(_keys(screen) == first_keys, "and it carries the same shelf as before")
	_ok(rows.size() == 5 and rows[0].disabled and rows[4].disabled,
		"with what was bought still sold")

	# --- rerolling ----------------------------------------------------------
	var tip := screen.products.reroll_tip
	purse = wallet.get_total()
	reroll.pressed.emit()
	await process_frame
	rows = _rows(screen)
	var second_keys := _keys(screen)
	_ok(wallet.get_total() == purse - tip, "the reroll took the tip from carried blood",
		"%d spent against a %d tip" % [purse - wallet.get_total(), tip])
	var overlap := false
	for key: StringName in second_keys:
		if first_keys.has(key):
			overlap = true
	_ok(second_keys.size() == 5 and not overlap,
		"all five slots were dealt afresh, none of them from the shelf before",
		"%s -> %s" % [first_keys, second_keys])
	_ok(rows.size() == 5 and not rows[0].disabled, "the new shelf is for sale")

	wallet.reset()
	await process_frame
	screen._refresh_blood()
	_ok(reroll.disabled, "the reroll button greys out when the tip cannot be paid")
	_ok(not screen.reroll(), "and a reroll without the tip is refused")
	_ok(_keys(screen) == second_keys, "leaving the shelf as it was")

	# --- the close key ------------------------------------------------------
	var escape := InputEventAction.new()
	escape.action = screen.close_action
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	_ok(not screen.is_open(), "the close key left the market")
	_ok(view.is_picking(), "and the map is live again")

	director.site_reached.emit(market)
	await process_frame
	_ok(_keys(screen) == second_keys, "walking back in after a reroll finds the rerolled shelf")
	screen.close()

	# --- a saloon still opens the saloon ------------------------------------
	var saloon_node := _find_first("RunMapSaloonNode") as RunMapSaloonNode
	if saloon_node != null and saloon != null:
		for site: RunMapSite in graph.sites:
			if saloon_node.answers(site.kind):
				director.site_reached.emit(site)
				await process_frame
				_ok(saloon.is_open() and not screen.is_open(),
					"a saloon point still opens the saloon, not the market")
				saloon.close()
				break

	# --- the run ending -----------------------------------------------------
	session.end()
	_ok(weapon.get_run_level(upgrade_good.upgrade) == 0, "ending the run forgot the run stack")
	_ok(cards.get_cards().is_empty(), "and emptied the hand of Cards")
	_ok(weapon.get_upgrade_level(upgrade_good.upgrade) == base_level, "the Base level is untouched")
	_ok(bought_key != &"", "the bought product had a key")


func _keys(screen: RunMapMarketScreen) -> Array[StringName]:
	var keys: Array[StringName] = []
	for good: RunMapSaloonGood in screen.goods:
		keys.append(RunMapMarketProducts.key_of(good))
	return keys


func _rows(screen: RunMapSaloonScreen) -> Array[Button]:
	var found: Array[Button] = []
	var list: Node = screen.get_node_or_null(^"Panel/Body/Pages/Stack/List")
	if list == null:
		return found
	for child: Node in list.get_children():
		var button := child as Button
		if button != null and String(button.name) != "Row" and not button.is_queued_for_deletion():
			found.append(button)
	return found


func _press(screen: Control, path: NodePath) -> void:
	var button := screen.get_node_or_null(path) as Button
	if button == null:
		_ok(false, "there is a button at %s" % path)
		return
	button.pressed.emit()


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _find_first(class_name_wanted: String) -> Node:
	return _search(root, class_name_wanted)


func _search(node: Node, wanted: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == wanted:
		return node
	for child: Node in node.get_children():
		var found := _search(child, wanted)
		if found != null:
			return found
	return null
