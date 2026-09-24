extends SceneTree
## Headless check of the Bounty Board's capacity progression, through the real
## Base menu: the board starts holding one contract and says so, a second TAKE is
## refused, each upgrade raises it by one up to three and no further, and riding
## out carrying three contracts deals the Run Map three bounty boss points.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/bounty_capacity_smoke.gd
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
	var board := menu.find_child("WantedBoardMenu", true, false) as WantedBoardMenu
	var slots := board.get_node(^"Panel/Body/Header/Slots") as Label

	print("--- the default board ---")
	var ride := menu.get_node(^"Layout/RideOutButton") as Button
	ride.pressed.emit()
	await process_frame
	_ok(board.visible, "RIDE OUT raises the wanted board")
	_ok(ledger.get_capacity_level() == 0 and ledger.get_active_slots() == 1,
		"the board starts holding 1 contract", "%d" % ledger.get_active_slots())
	_ok(slots.text.ends_with("0 / 1"), "and the board shows it", slots.text)

	_ok(_take_through_board(board), "the first TAKE goes through")
	await process_frame
	_ok(slots.text.ends_with("1 / 1"), "the board reads full", slots.text)
	_ok(not _any_poster_acceptable(board), "every remaining poster is greyed out")
	var held := ledger.get_used_slots()
	_take_through_board(board)
	_ok(ledger.get_used_slots() == held, "a second TAKE is refused at capacity 1")

	print("--- upgrades ---")
	for expected: int in [2, 3]:
		_ok(ledger.upgrade_capacity(), "an upgrade raises the board to %d" % expected)
		await process_frame
		_ok(ledger.get_active_slots() == expected, "the board holds %d" % expected,
			"%d" % ledger.get_active_slots())
		_ok(slots.text.ends_with("%d / %d" % [expected - 1, expected]),
			"and shows it straight away", slots.text)
		_ok(_take_through_board(board), "so another TAKE goes through")
	_ok(not ledger.upgrade_capacity() and ledger.get_active_slots() == 3,
		"a fourth upgrade is refused - 3 is the maximum")
	_take_through_board(board)
	_ok(ledger.get_used_slots() == 3, "and a fourth contract cannot be taken",
		"%d held" % ledger.get_used_slots())

	print("--- the bosses follow the contracts ---")
	var generator: RunMapGenerator = load("res://Resources/RunMap/dust_camp_run_map.tres")
	for carried: int in [0, 1, 2, 3]:
		var graph := generator.generate(31000 + carried, carried)
		var found := _count_kind(graph, &"bounty")
		_ok(found == carried, "%d accepted = %d bounty boss(es)" % [carried, carried],
			"%d dealt" % found)

	var confirm := board.get_node(^"Panel/Body/ConfirmButton") as Button
	confirm.pressed.emit()
	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "confirming rides onto the Run Map", _scene_name())
	var director := current_scene.find_child("RunMapDirector", true, false) as RunMapDirector
	var live := _count_kind(director.get_graph() if director != null else null, &"bounty")
	_ok(director != null and director.accepted_bounty_count() == 3 and live == 3,
		"riding out with 3 contracts deals 3 bounty bosses", "%d on the map" % live)

	_finish()


## Presses TAKE on the first poster still hanging, the way the player does, and
## reports whether a contract was actually taken.
func _take_through_board(board: WantedBoardMenu) -> bool:
	var ledger: BountyLedger = root.get_node(^"Bounties")
	if ledger.get_board_bounties().is_empty():
		# A thin week can leave nothing hanging; this is not what is being checked.
		ledger.refresh_board()
	var before := ledger.get_used_slots()
	for poster: WantedPoster in board._posters:
		if is_instance_valid(poster) and poster.get_bounty() != null:
			poster.accept_requested.emit(poster)
			break
	return ledger.get_used_slots() == before + 1


func _any_poster_acceptable(board: WantedBoardMenu) -> bool:
	for poster: WantedPoster in board._posters:
		if is_instance_valid(poster) and poster._acceptable:
			return true
	return false


func _count_kind(graph: RunMapGraph, kind: StringName) -> int:
	var found := 0
	if graph == null:
		return 0
	for site: RunMapSite in graph.sites:
		if site.kind == kind:
			found += 1
	return found


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
		print("[PASS] bounty capacity: every check passed")
	else:
		print("[FAIL] bounty capacity: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)
