extends SceneTree
## Headless check of the run map's EXTRACTION point: that arriving on one runs
## the existing [WorldMapExtractionService] - carried and horse Blood into
## [code]BloodBank[/code], the bounty reward and penalty, both run wallets
## emptied, the run ended - and that the game then changes scene to the Base
## menu.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_extraction_smoke.gd
## [/codeblock]

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"
const BASE_SCENE := "res://Scenes/Base/BaseMenu.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await _check_extraction()

	print("")
	if _failures == 0:
		print("[PASS] run map extraction: every check passed")
	else:
		print("[FAIL] run map extraction: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_extraction() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	var blood := root.get_node_or_null(^"Blood") as BloodWallet
	var horse := root.get_node_or_null(^"HorseBlood") as BloodWallet
	var bank := root.get_node_or_null(^"BloodBank") as BloodWallet
	var ledger := root.get_node_or_null(^"Bounties") as BountyLedger
	_ok(session != null and blood != null and horse != null and bank != null and ledger != null,
		"the run's autoloads are all there")
	if session == null or blood == null or horse == null or bank == null or ledger == null:
		return

	# Two contracts taken: one finished, one still outstanding.
	ledger.set_capacity_level(ledger.get_max_capacity_level())
	ledger.refill_board()
	var taken: Array[Bounty] = []
	for bounty: Bounty in ledger.get_board_bounties():
		if taken.size() >= 2:
			break
		if ledger.accept(bounty):
			taken.append(bounty)
	_ok(taken.size() == 2, "two contracts taken off the board", "took %d" % taken.size())
	if taken.size() < 2:
		return
	ledger.complete(taken[0].bounty_id)

	session.call(&"begin", &"desert")
	session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(4):
		await process_frame

	var director := _find_first("RunMapDirector") as RunMapDirector
	var node := _find_first("RunMapExtractionNode") as RunMapExtractionNode
	var service := _find_first("WorldMapExtractionService") as WorldMapExtractionService
	_ok(director != null and node != null and service != null,
		"the map opened with its extraction listener and the extraction service")
	if director == null or node == null or service == null:
		return

	var graph := director.get_graph()
	var exit: RunMapSite = null
	for site: RunMapSite in graph.sites:
		if site != null and site.kind == &"extraction":
			exit = site
			break
	_ok(exit != null, "the map has an EXTRACTION point")
	if exit == null:
		return

	blood.reset()
	horse.reset()
	blood.add(300)
	horse.add(150)
	var bank_before := bank.get_total()
	var penalty := service._penalty_for(taken[1])
	var expected := maxi(300 + 150 + service.completed_bounty_reward - penalty, 0)

	var extracted: Array = []
	service.run_extracted.connect(func(s: ExtractionSettlement) -> void: extracted.append(s))

	# The arrival itself, through the director's real arrival path.
	director._on_travel_finished(exit.id)
	await process_frame

	_ok(extracted.size() == 1, "arriving on the point extracted once")
	if extracted.is_empty():
		return
	var settlement: ExtractionSettlement = extracted[0]
	print(settlement.get_debug_text())
	_ok(settlement.player_blood == 300 and settlement.horse_blood == 150,
		"carried and horse Blood were both read")
	_ok(settlement.completed_bounties.size() == 1 and settlement.incomplete_bounties.size() == 1,
		"one bounty paid, one penalised")
	_ok(bank.get_total() == bank_before + expected, "BloodBank received the final Blood",
		"%d -> %d, expected +%d" % [bank_before, bank.get_total(), expected])
	_ok(blood.get_total() == 0 and horse.get_total() == 0, "carried and horse Blood cleared")
	_ok(ledger.get_active().is_empty(), "both contracts are off the ledger")
	_ok(not service.extract(), "a second extraction is refused")

	# Arriving again must not pay twice.
	director._on_site_re_entered(exit.id)
	_ok(extracted.size() == 1, "re-entering the point does not extract again")

	var base_up := false
	for _frame: int in range(600):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BASE_SCENE:
			base_up = true
			break
	_ok(base_up, "the game changed scene to the Base menu",
		"at %s" % ("nothing" if current_scene == null else current_scene.scene_file_path))
	_ok(not bool(session.call(&"is_running")),
		"the run session has ended")


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
