extends SceneTree
## Headless check of the Base menu flow: the title screen's STORY lands on the
## Base menu (never the walkable base), every line opens its screen or says it is
## coming, RIDE OUT raises the wanted board with its confirm button, confirming
## rides onto the Run Map, and the way home lands back on the Base menu.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/base_menu_smoke.gd
## [/codeblock]

const TITLE_SCENE := "res://Scenes/UI/TitleScreen.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	change_scene_to_file(TITLE_SCENE)
	await process_frame
	await process_frame

	print("--- STORY ---")
	var title := current_scene as TitleScreen
	_ok(title != null, "the title screen is up", _scene_name())
	if title == null:
		_finish()
		return
	title.start_story()
	await _settle()
	_ok(_scene_name() == "BaseMenu", "STORY lands on the Base menu", _scene_name())
	_ok(_count_named("BaseWorld") == 0 and _count_named("Base") == 0,
		"and the walkable base was never built")
	var menu := current_scene as BaseMenu
	if menu == null:
		_finish()
		return

	print("--- the lines ---")
	for line: String in ["BountyBoardButton", "SelectWeaponButton", "UpgradeButton", "BuyWeaponButton", "ShopButton"]:
		var entry := menu.find_child(line, true, false) as BaseMenuEntry
		var screen := entry.find_screen() if entry != null else null
		_ok(screen != null, "%s has a screen behind it" % line)
		if entry == null or screen == null:
			continue
		entry.pressed.emit()
		await process_frame
		_ok(screen.visible, "%s opens it" % line)
		var back := menu.get_node(^"BackButton") as Button
		_ok(back.visible, "and BACK is offered over it")
		back.pressed.emit()
		await process_frame
		await process_frame
		_ok(not screen.visible and not paused, "BACK closes it and unpauses")

	print("--- BUY WEAPON ---")
	var bank: BloodWallet = root.get_node(^"BloodBank")
	var shop := menu.find_child("BuyWeaponScreen", true, false) as BuyWeaponScreen
	var catalog: WeaponCatalog = root.get_node(^"RunSession").call(&"get_weapon_catalog")
	_ok(shop != null and shop.catalog == catalog, "the gunsmith sells the session's own roster")
	var for_sale: WeaponDefinition = null
	for weapon: WeaponDefinition in catalog.weapons:
		if weapon != null and not weapon.is_owned():
			for_sale = weapon
			break
	_ok(for_sale != null and for_sale.purchase_cost > 0, "something is for sale, at a price")
	if shop != null and for_sale != null:
		(menu.find_child("BuyWeaponButton", true, false) as BaseMenuEntry).pressed.emit()
		await process_frame
		var cards := shop.get_node(^"Panel/Body/Cards")
		_ok(cards.get_child_count() == catalog.weapons.size(), "one card per weapon")
		var owned_cards := 0
		for card: Node in cards.get_children():
			if (card as UpgradeCard).is_bought():
				owned_cards += 1
		_ok(owned_cards == catalog.unlocked_weapons().size(), "owned weapons read OWNED")

		bank.reset()
		bank.add(for_sale.purchase_cost - 1)
		_ok(not for_sale.purchase(bank) and not for_sale.is_owned()
			and bank.get_total() == for_sale.purchase_cost - 1, "short of blood buys nothing")
		bank.add(1)
		var card_index := catalog.weapons.find(for_sale)
		(cards.get_child(card_index) as UpgradeCard).buy_requested.emit(cards.get_child(card_index))
		await process_frame
		_ok(for_sale.is_owned() and bank.get_total() == 0, "buying unlocks it and takes the price")
		var fresh := cards.get_child(card_index) as UpgradeCard
		_ok(fresh != null and fresh.is_bought(), "and the screen reads OWNED at once")
		_ok(not for_sale.purchase(bank), "an owned weapon cannot be bought again")
		(menu.get_node(^"BackButton") as Button).pressed.emit()
		await process_frame

		var select := menu.find_child("WeaponSelectMenu", true, false) as WeaponSelectMenu
		select.open()
		await process_frame
		var picks := select.get_node(^"Panel/Body/Weapons")
		var live := picks.get_child(card_index) as Button
		_ok(live != null and not live.disabled, "SELECT WEAPON offers the bought weapon")
		select.close()
		await process_frame
	var owned_after_buy := catalog.unlocked_weapons().size()

	print("--- the pool ---")
	var wallet: BloodWallet = root.get_node(^"Blood")
	var pool := menu.find_child("BloodPool", true, false) as BloodPool
	wallet.add(50)
	var banked_before := bank.get_total()
	_ok(pool != null and pool.deposit() == 50 and bank.get_total() == banked_before + 50,
		"the pool banks carried blood")

	print("--- RIDE OUT ---")
	var board := menu.find_child("WantedBoardMenu", true, false) as WantedBoardMenu
	var ride := menu.get_node(^"Layout/RideOutButton") as Button
	ride.pressed.emit()
	await process_frame
	var confirm := board.get_node(^"Panel/Body/ConfirmButton") as Button
	_ok(board.visible, "RIDE OUT raises the wanted board")
	_ok(confirm.visible, "with its RIDE OUT confirm showing")
	var ledger: BountyLedger = root.get_node(^"Bounties")
	var bounties := ledger.get_board_bounties()
	if not bounties.is_empty():
		ledger.accept(bounties[0])
	_ok(_scene_name() == "BaseMenu", "nothing has left before confirming")
	confirm.pressed.emit()
	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "confirming rides onto the Run Map", _scene_name())

	print("--- home ---")
	var router: WorldRegionRouter = root.get_node(^"WorldRouter")
	root.get_node(^"RunSession").call(&"end")
	_ok(router.go_to_base(), "the router accepts the ride home")
	await _settle()
	_ok(_scene_name() == "BaseMenu", "home is the Base menu", _scene_name())
	var again := current_scene.find_child("WantedBoardMenu", true, false) as WantedBoardMenu
	_ok(again != null and not again.get_node(^"Panel/Body/ConfirmButton").visible,
		"and the board's confirm is hidden again on a fresh visit")
	var home_select := current_scene.find_child("WeaponSelectMenu", true, false) as WeaponSelectMenu
	_ok(home_select != null and home_select.catalog == catalog
		and catalog.unlocked_weapons().size() == owned_after_buy,
		"a bought weapon is still owned after the ride out and back")

	_finish()


func _settle() -> void:
	var guard := 0
	var curtain := LoadingCurtain.get_active(root)
	while curtain != null and curtain.is_loading() and guard < 4000:
		guard += 1
		await process_frame
	for _step: int in 12:
		await process_frame


func _count_named(wanted: String) -> int:
	return root.find_children(wanted, "", true, false).size()


func _finish() -> void:
	print("")
	if _failures == 0:
		print("[PASS] base menu: every check passed")
	else:
		print("[FAIL] base menu: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)
