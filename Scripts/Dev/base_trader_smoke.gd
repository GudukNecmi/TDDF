extends SceneTree
## Headless check of the Base trader and the Base health flow: the trader opens
## from the Base menu selling neither Hearts nor ammunition, charges nothing,
## shows and pays from the banked Blood rather than the carried Blood,
## closes on BACK and on the pause key, RIDE OUT leaves at full health with every
## pouch full, and a run ended by Extraction banks what was carried and comes
## home at full health.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/base_trader_smoke.gd
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
	(current_scene as TitleScreen).start_story()
	await _settle()
	var menu := current_scene as BaseMenu
	_ok(menu != null, "STORY lands on the Base menu", _scene_name())
	if menu == null:
		_finish()
		return

	var wallet: BloodWallet = root.get_node(^"Blood")
	var bank: BloodWallet = root.get_node(^"BloodBank")
	var vitals: RunVitals = root.get_node(^"Vitals")
	var session := root.get_node(^"RunSession")
	var locker: AmmoLocker = root.get_node(^"Ammo")

	print("--- the trader ---")
	var trader := menu.find_child("TraderMenu", true, false) as TraderMenu
	var back := menu.get_node(^"BackButton") as Button
	wallet.add(5000)
	bank.add(700)
	var before := wallet.get_total()
	var banked_before := bank.get_total()
	_ok(trader.get(&"_wallet") == bank, "the trader pays from BloodBank")
	for line: String in ["ShopButton"]:
		(menu.find_child(line, true, false) as BaseMenuEntry).pressed.emit()
		await process_frame
		_ok(trader.visible and paused, "%s opens the trader" % line)
		_ok(back.visible, "with BACK over it")
		back.pressed.emit()
		await process_frame
		await process_frame
		_ok(not trader.visible and not paused, "BACK closes it and unpauses")

	trader.open()
	await process_frame
	var buttons := trader.find_children("", "Button", true, false)
	_ok(buttons.is_empty(), "nothing is offered on the counter", "%d buttons" % buttons.size())
	var labels: PackedStringArray = []
	for label: Node in trader.find_children("", "Label", true, false):
		labels.append((label as Label).text)
	_ok(trader.empty_stock_text in labels, "it says it has nothing for sale")
	_ok(not trader.can_buy_heart() and trader.buy_heart() == false, "no Heart can be bought")
	var shell := trader.shotgun_ammo
	_ok(shell != null and trader.revolver_ammo != null and trader.lever_ammo != null,
		"the ammunition stock is still assigned")
	_ok(not trader.can_buy_ammo(shell) and trader.buy_ammo(shell) == 0, "no ammunition can be bought")
	_ok(wallet.get_total() == before and bank.get_total() == banked_before, "and no blood was taken")
	_ok(trader.blood_format % bank.get_total() in labels, "it shows the banked Blood",
		"%s" % [labels])
	_ok(trader.status_text in labels and "BANKED" in trader.status_text,
		"its footer says purchases use banked Blood", trader.status_text)

	var escape := InputEventAction.new()
	escape.action = &"pause_menu"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_ok(not trader.visible and not paused, "the pause key closes it and unpauses")
	_ok(current_scene == menu and not back.visible, "back on the Base menu")

	print("--- RIDE OUT ---")
	var reserve := locker.get_reserve(shell)
	reserve.set_current(0)
	vitals.carry(1.0)
	(menu.get_node(^"Layout/RideOutButton") as Button).pressed.emit()
	await process_frame
	var ledger: BountyLedger = root.get_node(^"Bounties")
	var bounties := ledger.get_board_bounties()
	if not bounties.is_empty():
		ledger.accept(bounties[0])
	var board := menu.find_child("WantedBoardMenu", true, false) as WantedBoardMenu
	(board.get_node(^"Panel/Body/ConfirmButton") as Button).pressed.emit()
	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "RIDE OUT rides onto the Run Map", _scene_name())
	_ok(not vitals.has_carried(), "and leaves at full health")
	_ok(reserve.is_full(), "with the ammunition refilled for free",
		"%d/%d" % [reserve.get_current(), reserve.get_max()])

	print("--- extraction ---")
	vitals.carry(1.0)
	_ok(vitals.has_carried() and session.call(&"is_running"), "wounded out on the run")
	var extraction := WorldMapExtractionService.new()
	root.add_child(extraction)
	wallet.reset()
	wallet.add(320)
	var bank_before_extraction := bank.get_total()
	var settlement := extraction.call(&"_settle") as ExtractionSettlement
	_ok(settlement.player_blood == 320, "extraction counts the carried Blood",
		"%d" % settlement.player_blood)
	_ok(bank.get_total() == bank_before_extraction + settlement.final_blood,
		"and deposits the settlement into BloodBank",
		"%d -> %d, final %d" % [bank_before_extraction, bank.get_total(), settlement.final_blood])
	_ok(wallet.get_total() == 0, "leaving nothing carried")
	extraction.call(&"_end_session")
	extraction.queue_free()
	var router: WorldRegionRouter = root.get_node(^"WorldRouter")
	_ok(router.go_to_base(), "the router takes the player home")
	await _settle()
	_ok(_scene_name() == "BaseMenu", "home is the Base menu", _scene_name())
	_ok(not vitals.has_carried(), "at full health")

	_finish()


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
		print("[PASS] base trader: every check passed")
	else:
		print("[FAIL] base trader: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)
