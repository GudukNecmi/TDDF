extends SceneTree
## Takes pictures of a bounty boss point being ridden into: the point on the
## board, the contract flying in, the sheet held up to be read, and the arena it
## opens onto. For looking at the presentation rather than only measuring it.
##
## Run it windowed - it needs a renderer:
## [codeblock]
## godot --path . --script res://Scripts/Dev/run_map_bounty_boss_shot.gd
## [/codeblock]

const OUT_DIR := "user://run_map_bounty_boss_shots"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	var session: Node = root.get_node_or_null(^"RunSession")
	var ledger: BountyLedger = root.get_node_or_null(^"Bounties")
	if router == null or ledger == null:
		print("no WorldRouter or Bounties autoload")
		quit(1)
		return
	await process_frame
	await process_frame

	# One contract taken off the board, exactly as the player would take it
	# before riding out - without one there is no boss point to ride to.
	var carried: Bounty = null
	for _attempt: int in range(6):
		for bounty: Bounty in ledger.get_board_bounties():
			if ledger.accept(bounty):
				carried = bounty
				break
		if carried != null:
			break
		ledger.refresh_board()
	if carried == null:
		print("the board would not part with a contract")
		quit(1)
		return
	print("riding out after %s, worth %d blood"
		% [carried.target.display_name if carried.target != null else "?", carried.reward])

	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")
	router.go_to_region(&"A")
	await _settle()

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var node := _find("RunMapBountyBossNode") as RunMapBountyBossNode
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	if director == null or view == null or travel == null or node == null:
		print("no run map in the tree")
		quit(1)
		return
	if bandits != null:
		# Silenced for the ride, so the only screen in these pictures is the one
		# they are about.
		bandits.encounters.clear()

	var graph := director.get_graph()
	await _shoot("1_the_board")

	var route := _route_to_boss(node, graph)
	if route.is_empty():
		print("no way to a boss point on this map")
		quit(1)
		return
	print("the point is %d roads away" % route.size())

	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame
		await process_frame

	# The sheet, caught on its way in and again once it has settled.
	await _wait(0.35)
	await _shoot("2_the_contract_flying_in")
	await _wait(0.9)
	await _shoot("3_the_contract_held_up")

	# And the arena it opens onto, once the sheet has gone and the fight has
	# actually been built.
	await _wait(3.0)
	await _settle()
	await _wait(1.5)
	await _shoot("4_the_fight_it_opens")
	print("shots written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _route_to_boss(node: RunMapBountyBossNode, graph: RunMapGraph) -> PackedInt32Array:
	var came_from := {graph.current_id: -1}
	var queue: Array[int] = [graph.current_id]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next: int in graph.neighbours_of(at):
			if came_from.has(next):
				continue
			came_from[next] = at
			if node.encounter_for(graph.get_site(next).kind) != null:
				return _walk_back(came_from, next, graph.current_id)
			queue.append(next)
	return PackedInt32Array()


func _walk_back(came_from: Dictionary, to_id: int, from_id: int) -> PackedInt32Array:
	var backwards: Array[int] = []
	var at := to_id
	while at != from_id and at >= 0:
		backwards.append(at)
		at = int(came_from.get(at, -1))
	backwards.reverse()
	var route := PackedInt32Array()
	for site_id: int in backwards:
		route.append(site_id)
	return route


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _settle() -> void:
	var guard := 0
	var curtain := LoadingCurtain.get_active(root)
	while curtain != null and curtain.is_loading() and guard < 4000:
		guard += 1
		await process_frame
	for _step: int in 12:
		await process_frame


func _shoot(shot_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, shot_name])


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
