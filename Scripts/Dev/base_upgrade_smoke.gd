extends SceneTree
## Headless check of the Base menu's UPGRADE screen: the line opens it instead of
## saying it is coming, the Bounty Board card shows its level and price, a card the
## bank cannot pay for cannot be bought, buying one raises the board through
## [method BountyLedger.upgrade_capacity] and takes the price out of the bank, and
## the top level reads as maxed.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/base_upgrade_smoke.gd
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
	var title := current_scene as TitleScreen
	if title == null:
		_ok(false, "the title screen is up", _scene_name())
		_finish()
		return
	title.start_story()
	await _settle()
	var menu := current_scene as BaseMenu
	_ok(menu != null, "STORY lands on the Base menu", _scene_name())
	if menu == null:
		_finish()
		return

	var ledger: BountyLedger = root.get_node(^"Bounties")
	var bank: BloodWallet = root.get_node(^"BloodBank")
	bank.reset()

	print("--- the line ---")
	var entry := menu.find_child("UpgradeButton", true, false) as BaseMenuEntry
	entry.pressed.emit()
	await process_frame
	var screen := menu.find_child("BaseUpgradeScreen", true, false) as BaseUpgradeScreen
	var soon := menu.get_node(^"Layout/ComingSoonLabel") as Label
	_ok(screen != null and screen.visible, "UPGRADE opens the upgrade screen")
	_ok(not soon.visible, "and nothing says COMING SOON")
	_ok(paused, "the world is paused behind it")
	_ok((menu.get_node(^"BackButton") as Button).visible, "BACK is offered over it")
	if screen == null:
		_finish()
		return

	print("--- the Bounty Board card ---")
	var card := _card(screen)
	_ok(card != null and card.title_text == "BOUNTY BOARD", "a Bounty Board card is on offer")
	_ok(card != null and card.cost == 1500, "the first step costs 1500", "%d" % (card.cost if card else -1))
	_ok(card != null and card.detail_text.contains("CONTRACTS HELD  1 -> 2"), "and says what it does",
		card.detail_text if card else "")
	_press_buy(card)
	await process_frame
	_ok(ledger.get_active_slots() == 1, "an empty bank cannot buy it")

	bank.add(10000)
	await process_frame
	_press_buy(_card(screen))
	await process_frame
	_ok(ledger.get_capacity_level() == 1 and ledger.get_active_slots() == 2,
		"buying it raises the board to 2 through the ledger")
	_ok(bank.get_total() == 8500, "and takes 1500 from the bank", "%d" % bank.get_total())
	card = _card(screen)
	_ok(card.cost == 3000, "the next step costs 3000", "%d" % card.cost)
	_ok((screen.get_node(^"Panel/Body/Header/Blood") as Label).text == "BANKED 8500",
		"the screen shows the bank")

	_press_buy(card)
	await process_frame
	_ok(ledger.get_active_slots() == 3 and bank.get_total() == 5500,
		"the second step raises it to 3 for 3000", "%d / %d" % [ledger.get_active_slots(), bank.get_total()])
	card = _card(screen)
	_ok(card.is_bought() and card.detail_text.ends_with("CONTRACTS HELD  3"), "and the card reads maxed",
		card.detail_text)
	_press_buy(card)
	await process_frame
	_ok(ledger.get_active_slots() == 3 and bank.get_total() == 5500, "a maxed card sells nothing")

	print("--- back ---")
	(menu.get_node(^"BackButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	_ok(not screen.visible and not paused, "BACK closes it and unpauses")

	_finish()


func _card(screen: BaseUpgradeScreen) -> UpgradeCard:
	for child: Node in screen.get_node(^"Panel/Body/Scroll/Cards").get_children():
		if child is UpgradeCard and not child.is_queued_for_deletion():
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
	for _step: int in 12:
		await process_frame


func _finish() -> void:
	print("")
	if _failures == 0:
		print("[PASS] base upgrades: every check passed")
	else:
		print("[FAIL] base upgrades: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)
