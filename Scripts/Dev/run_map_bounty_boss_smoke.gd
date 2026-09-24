extends SceneTree
## Headless check of the whole bounty boss point round trip: the contracts taken
## before the run, the points the map is dealt for them, the poster held up on
## arrival, the arena, the man arriving among his dozen men, his charge, his sword
## circle and dash, the reward paid, his fate decided, and the same run map
## standing again afterwards.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_bounty_boss_smoke.gd
## [/codeblock]
##
## [b]The order is the whole of what this is for.[/b] Everything that could go
## wrong about a bounty boss point is a step happening at the wrong moment: the
## player sent home when his men fall, the crowd running dry, a shot hurting him
## inside his circle, the ride home arriving before his fate is asked. So this walks
## the encounter a beat at a time and checks what is true at each one.
##
## [b]And the rule the points are dealt by is checked before any of that.[/b] A
## run has a boss point for every contract the player rode out carrying and none
## at all for a player who took nothing, so the map is laid out twice - once with
## contracts and once without - and the standalone mini boss point the run map
## used to deal is checked to be gone from both.

const GENERATOR := "res://Resources/RunMap/dust_camp_run_map.tres"
## How many contracts to ride out with. Three is the ledger's own ceiling.
const CONTRACTS := 2

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var router: WorldRegionRouter = root.get_node_or_null(^"WorldRouter")
	var session: Node = root.get_node_or_null(^"RunSession")
	var ledger: BountyLedger = root.get_node_or_null(^"Bounties")
	if router == null or ledger == null:
		print("[FAIL] no WorldRouter or Bounties autoload")
		quit(1)
		return
	await process_frame
	await process_frame

	print("--- how many boss points a run is dealt ---")
	_check_distribution()

	# The board starts holding one; carrying two is the upgraded board.
	ledger.set_capacity_level(ledger.get_max_capacity_level())
	var taken := _take_contracts(ledger, CONTRACTS)
	_ok(taken == CONTRACTS, "the player rode out holding %d contracts" % CONTRACTS,
		"%d taken" % taken)
	if taken <= 0:
		_finish()
		return

	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	print("--- the run map ---")
	_ok(router.go_to_region(&"A"), "the router accepted the ride out")
	await _settle()
	_ok(_scene_name() == "DustCampRunMap", "the run map opened", _scene_name())

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var node := _find("RunMapBountyBossNode") as RunMapBountyBossNode
	var poster := _find("RunMapBountyPosterScreen") as RunMapBountyPosterScreen
	if director == null or view == null or travel == null or node == null:
		_ok(false, "the run map opened with everything a bounty boss point needs")
		_finish()
		return
	_ok(not node.encounters.is_empty(), "the map has a bounty boss point authored")
	_ok(poster != null, "and the sheet it holds the contract up on")

	var graph := director.get_graph()
	var made_seed := graph.seed
	var made_points := graph.sites.size()
	var points := _boss_points(graph, node)
	_ok(points.size() == taken,
		"the generator dealt one boss point per contract",
		"%d points against %d contracts" % [points.size(), taken])
	_ok(_count_kind(graph, &"mini_boss") == 0 and _count_kind(graph, &"mini_boss_cleared") == 0,
		"and no standalone mini boss point anywhere on it")

	var bound: Dictionary = {}
	var every_point_named := true
	for site: RunMapSite in points:
		if site.contract_id.is_empty() or bound.has(site.contract_id):
			every_point_named = false
		bound[site.contract_id] = true
	_ok(every_point_named,
		"every boss point names a contract, and no two name the same one")

	print("--- riding to a bounty boss point ---")
	# The bandit points on the way are muted for the ride - their own screen would
	# be a second encounter in the middle of the one being measured. Done by
	# emptying the array that says which points that node answers, which is the
	# same switch an author has. Bandit points have their own round trip check.
	var bandits := _find("RunMapBanditNode") as RunMapBanditNode
	if bandits != null:
		bandits.encounters.clear()
	# The sheet is flown at a pace a check can wait for; the real timings are on
	# the screen in the scene and are what the game actually plays.
	if poster != null:
		poster.fly_time = 0.05
		poster.hold_time = 0.05
		poster.leave_time = 0.05

	var route := _route_to_boss(node, graph)
	_ok(not route.is_empty(), "there is a way to one")
	if route.is_empty():
		_finish()
		return

	var target := route[route.size() - 1]
	var site := graph.get_site(target)
	var entry := node.encounter_for(site.kind)
	var wanted_support := node.support_count_for(graph, site)
	var contract := node.bounty_for(site)
	var who := node.boss_for(site)
	print("       a '%s' with %d men in front of %s"
		% [site.kind, wanted_support, who.display_name if who != null else "<nobody>"])
	_ok(contract != null, "the point has a contract behind it")
	_ok(who != null and contract != null and who.contract_id == contract.bounty_id,
		"and the man on it answers that very contract",
		"'%s'" % (who.contract_id if who != null else ""))
	_ok(entry != null and wanted_support >= entry.min_support
			and wanted_support <= entry.max_support,
		"the men in front of him are what this point is worth",
		"%d against %d-%d" % [wanted_support,
			entry.min_support if entry != null else 0,
			entry.max_support if entry != null else 0])

	# A one-entry array rather than a bool: a GDScript lambda captures by value,
	# so a plain local written to inside one never comes back out.
	var seen_poster := [false]
	if poster != null:
		poster.presented.connect(func(_b: Bounty) -> void: seen_poster[0] = true)

	for step: int in route:
		view.site_chosen.emit(step, graph.find_link(graph.current_id, step))
		var frames := 0
		while travel.is_travelling() and frames < 4000:
			frames += 1
			await process_frame
		for _beat: int in 4:
			await process_frame

	# The last arrival raises the poster, and the fight is not asked for until the
	# sheet has been held and taken away again.
	await _wait_for(func() -> bool: return not poster.is_presenting() and bool(seen_poster[0]),
		8.0)
	_ok(bool(seen_poster[0]), "the contract was held up as the piece landed")

	print("--- the arena opens ---")
	await _settle()
	await _wait_for(func() -> bool: return _scene_name() == "DustCampArena", 20.0)
	await _settle()
	_ok(_scene_name() == "DustCampArena", "the fight is held in dust camp's arena",
		_scene_name())
	_ok(not paused, "the world is running once the fight is up")

	var board := MusicStateBoard.get_active(root)
	_ok(board != null and board.get_target() == &"bounty_boss",
		"the bounty boss track that started on the map is still the one playing",
		"%s" % (board.get_target() if board != null else &"<no board>"))

	var bridge := _find("WorldMapCombatBridge") as WorldMapCombatBridge
	var fight := _find("RunMiniBossFight") as RunMiniBossFight
	var ambush := _find("AmbushWaveDirector") as AmbushWaveDirector
	var boss_director := _find("MiniBossDirector") as MiniBossDirector
	var charge := _find("BossCharge") as BossCharge
	var storm := _find("BossSwordStorm") as BossSwordStorm
	var defeat := _find("BossDefeat") as BossDefeat
	var spawner := _find("EnemySpawner") as EnemySpawner
	if bridge == null or fight == null or ambush == null or boss_director == null \
			or charge == null or storm == null or defeat == null or spawner == null:
		_ok(false, "the arena has the bridge, the sequencer, the crowd, the boss system, the charge, the sword and the ending")
		_finish()
		return
	_ok(_find("BossPhases") == null, "the old in-arena support waves are gone from the arena")

	_ok(ambush.get_enemies_alive() == 12, "twelve of his men are on the field",
		"%d" % ambush.get_enemies_alive())
	_ok(ambush.is_sustained(), "and the crowd is held at that count for the fight")
	_ok(bridge.is_ending_held(), "the ending is held, so clearing them cannot send the player home")

	print("--- he arrives among them ---")
	await _wait_for(func() -> bool: return fight.has_arrived(), fight.arrival_delay + 2.0)
	_ok(fight.has_arrived(), "the boss walked in with his men still standing")
	var body := boss_director.get_boss()
	_ok(body != null and is_instance_valid(body), "there is a man standing in the arena")
	if body == null or contract == null:
		_finish()
		return
	var component := body.get_node_or_null(^"MiniBoss") as MiniBoss
	_ok(component != null and component.bounty_id == contract.bounty_id,
		"he is carrying the contract, so beating him closes it")
	var health := _find_health(body)
	var wanted_pool := boss_director.get_boss_health_multiplier(contract)
	var got_pool := 0.0
	if health != null and health.get_authored_max_health() > 0.0:
		got_pool = health.max_health / health.get_authored_max_health()
	_ok(is_equal_approx(got_pool, wanted_pool),
		"he is carrying the health his contract pays for",
		"%.2fx against the contract's %.2fx" % [got_pool, wanted_pool])
	_ok(_passive_men(body) == 12, "his men stand still while he is introduced",
		"%d passive" % _passive_men(body))

	await _wait_for(func() -> bool: return defeat.get_stage() == BossDefeat.Stage.FIGHTING, 8.0)
	_ok(defeat.get_stage() == BossDefeat.Stage.FIGHTING, "the fight starts once the introduction is over")
	_ok(_passive_men(body) == 0, "and his men are let go with him")

	# The player is kept alive for the length of the check - the fight is real and
	# a dozen men are on them. Lifted again wherever a hit on them is measured.
	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	var player_health := _find_health(player) if player != null else null
	if player_health != null:
		player_health.set_shielded(true)

	print("--- a man goes down and another walks in ---")
	var victim := _one_man(body)
	var arrivals: Array[Node2D] = []
	var watch := func(n: Node) -> void:
		if n is Node2D and n.is_in_group(&"enemies"):
			arrivals.append(n)
	root.get_tree().node_added.connect(watch)
	if victim != null:
		_find_health(victim).kill()
	for _beat: int in 6:
		await process_frame
	root.get_tree().node_added.disconnect(watch)
	_ok(ambush.get_enemies_alive() == 12, "the count is back at twelve",
		"%d" % ambush.get_enemies_alive())
	var picture := spawner.get_view_rect()
	var outside := not arrivals.is_empty()
	for man: Node2D in arrivals:
		if picture.has_point(man.global_position):
			outside = false
	_ok(outside, "and the replacement came in outside the picture",
		"%d arrivals, view %s" % [arrivals.size(), picture])

	print("--- the charge ---")
	_ok(is_equal_approx(charge.charge_duration, 0.3), "the charge telegraphs for 0.3 seconds",
		"%.2f" % charge.charge_duration)
	var started := Time.get_ticks_msec()
	var charged := charge.charge_now()
	await _wait_for(func() -> bool: return charge.get_step() != BossCharge.Step.WINDUP, 2.0)
	var wound := float(Time.get_ticks_msec() - started) / 1000.0
	_ok(charged and wound >= 0.25 and wound <= 0.5, "and then runs",
		"wind-up took %.2fs" % wound)
	_ok(charge.get_step() == BossCharge.Step.RUN or charge.get_step() == BossCharge.Step.SWING,
		"at the player")
	await _wait_for(func() -> bool: return not charge.is_charging(), 5.0)
	_ok(not charge.is_charging(), "and goes back to his ordinary fight afterwards")

	print("--- ten percent: the sword circle ---")
	var hitboxes := body.find_children("*", "Hitbox", true, false)
	health.take_damage(health.get_max() * 0.11)
	await process_frame
	await process_frame
	_ok(storm.is_spinning(), "losing a tenth of his health put the circle up")
	_ok(charge.is_held(), "and stood the charge down")
	var before := health.get_current()
	health.take_damage(500.0)
	_ok(is_equal_approx(health.get_current(), before), "he cannot be hurt inside it")
	var layers_off := true
	for box: Node in hitboxes:
		if (box as Area2D).collision_layer != 0:
			layers_off = false
	_ok(layers_off, "and shots cannot find his hitboxes")

	# A real round, fired at him from outside the circle.
	var round_scene: PackedScene = load("res://Scenes/Projectile/RevolverBullet.tscn")
	var shot := round_scene.instantiate() as Projectile
	var centre := (body.get_node(^"KnifeAim") as Node2D).global_position
	var from := centre + Vector2.LEFT * (storm.get_spin_radius() + 120.0)
	shot.global_position = from
	shot.global_rotation = 0.0
	current_scene.add_child(shot)
	var turned := [false]
	var shield := storm.get_node_or_null(^"SwordCircle") as RicochetShield
	if shield != null:
		shield.deflected.connect(func(_s: Projectile, _a: Vector2) -> void: turned[0] = true)
	await _wait_for(func() -> bool: return bool(turned[0]) or not is_instance_valid(shot), 1.0)
	await process_frame
	_ok(bool(turned[0]), "a shot into the circle ricochets off it")
	_ok(is_instance_valid(shot) and cos(shot.global_rotation) < 0.0,
		"and flies on away from him")
	_ok(is_equal_approx(health.get_current(), before), "without hurting him")

	# The player stood in the circle: hurt and thrown out of it.
	var reaction := player.get_node_or_null(^"HitReaction") as HitReaction
	if player_health != null:
		player_health.set_shielded(false)
		var hearts := player_health.get_current()
		player.global_position = centre + Vector2.RIGHT * 30.0
		await process_frame
		await process_frame
		_ok(player_health.get_current() < hearts, "standing in the circle costs the player",
			"%.1f -> %.1f" % [hearts, player_health.get_current()])
		_ok(reaction != null and reaction.get_knockback().length() > 200.0,
			"and throws them out of it",
			"%.0f px/s" % (reaction.get_knockback().length() if reaction != null else 0.0))
		player_health.set_shielded(true)
		player_health.set_current(player_health.get_max())

	print("--- out of the circle: the dash ---")
	await _wait_for(func() -> bool: return storm.is_dashing(), storm.spin_seconds + 2.0)
	_ok(storm.is_dashing(), "the circle ended in a dash at the player")
	_ok(not health.is_shielded(), "he can be hurt again the moment the circle is down")
	var layers_back := true
	for box: Node in hitboxes:
		if (box as Area2D).collision_layer == 0:
			layers_back = false
	_ok(layers_back, "and his hitboxes are back where shots can find them")

	var torn := [0]
	storm.bandit_torn.connect(func(_m: Node2D) -> void: torn[0] += 1)
	var swings := [0]
	var slash := body.get_node(^"KnifeAim/KnifeSlash") as KnifeSlash
	slash.swing_started.connect(func() -> void: swings[0] += 1)
	var in_the_way := _one_man(body)
	if in_the_way != null:
		in_the_way.global_position = body.global_position + Vector2(20.0, 0.0)
	var gore_before := _count("GorePiece")
	await _wait_for(func() -> bool: return not storm.is_dashing(), storm.dash_seconds + 1.0)
	_ok(torn[0] >= 1, "a man in his way was torn apart", "%d" % torn[0])
	_ok(_count("GorePiece") > gore_before, "into the blast's own gore")
	_ok(swings[0] >= 5 and swings[0] <= 7, "he cut about three times a second",
		"%d swings in %.1fs" % [swings[0], storm.dash_seconds])
	_ok(not charge.is_held(), "and afterwards his charge is his again")
	await _wait_for(func() -> bool: return ambush.get_enemies_alive() == 12, 1.0)
	_ok(ambush.get_enemies_alive() == 12, "the men he killed were replaced as well",
		"%d" % ambush.get_enemies_alive())

	print("--- he falls ---")
	var sounds := defeat.get_node_or_null(defeat.sound_bank_path) as SoundBank
	var defeat_stream: AudioStream = null
	if sounds != null:
		defeat_stream = sounds.sounds.get(defeat.strike_sound) as AudioStream
	var wallet: BloodWallet = root.get_node_or_null(^"Blood")
	var purse := wallet.get_total() if wallet != null else 0
	var reward := contract.reward
	var struck := [false]
	defeat.name_struck.connect(func() -> void: struck[0] = true)
	health.take_damage(health.max_health * 2.0)
	_ok(defeat.is_defeated(), "the killing hit beat him rather than killing him")
	var heard := false
	if sounds != null:
		for voice: Node in sounds.get_children():
			var sound := voice as AudioStreamPlayer
			if sound != null and sound.playing and sound.stream == defeat_stream:
				heard = true
	_ok(heard, "the defeat sound is playing the instant the killing hit lands")
	_ok(contract.completed, "the contract is closed out the moment he goes down")
	_ok(wallet == null or wallet.get_total() == purse + reward, "and its blood is paid")
	_ok(not ambush.is_sustained() and ambush.is_routing(), "his men break and run")
	await _wait_for(func() -> bool: return bool(struck[0]),
		defeat.fall_time + defeat.strike_delay + 2.0)
	_ok(bool(struck[0]), "his name is struck through on the card")

	print("--- his fate ---")
	var menu := WorldBanditDecisionMenu.get_active(current_scene)
	await _wait_for(func() -> bool: return menu != null and menu.is_open(), 6.0)
	_ok(menu != null and menu.is_open(), "the decision screen is up before the ride home")
	_ok(_scene_name() == "DustCampArena", "and the player is still in the arena")
	var labels: Array[String] = []
	if menu != null:
		for i: int in 3:
			var button := menu.get_node(menu.button_paths[i]) as Button
			if button.visible:
				labels.append(button.text)
	_ok(labels == ["Shoot him in the head", "Bind him and throw him behind the horse",
			"Throw him behind the horse"], "with the three answers", "%s" % [labels])
	var bank := fight.get_node(fight.fate_sound_bank_path) as SoundBank
	var decided := [&""]
	fight.fate_decided.connect(func(f: StringName, _k: bool) -> void: decided[0] = f)
	if menu != null:
		(menu.get_node(menu.button_paths[0]) as Button).pressed.emit()
	await process_frame
	_ok(decided[0] == &"shot_in_the_head", "shooting him was the answer", "%s" % decided[0])
	var confirm := false
	for voice: Node in bank.get_children():
		var sound := voice as AudioStreamPlayer
		if sound != null and sound.playing:
			confirm = true
	_ok(confirm, "the confirmation sound played")
	var weapon := WeaponMount.get_active(current_scene).get_weapon()
	var gun_heard := false
	var gun_bank := weapon.get_node_or_null(^"Sounds") as SoundBank if weapon != null else null
	if gun_bank != null:
		for voice: Node in gun_bank.get_children():
			var sound := voice as AudioStreamPlayer
			if sound != null and sound.playing and sound.stream == gun_bank.sounds.get(&"blast"):
				gun_heard = true
	_ok(gun_heard, "and the gun in the player's hands went off")
	_ok(defeat.is_corpse_killed(), "the body on the ground is finished")
	var key := ledger.fate_key_for(contract)
	_ok(ledger.has_fate(key) and ledger.was_killed(key)
			and ledger.get_fate(key).get("fate") == &"shot_in_the_head",
		"and the ledger remembers he was killed", "%s" % ledger.get_fate(key))

	print("--- back to the run map ---")
	# Left to the ending's own last step rather than asked for: the card holding
	# the struck-out name is what hands the arena back, and a check that forced it
	# would not notice if it stopped doing so.
	await _wait_for(func() -> bool: return _scene_name() == "DustCampRunMap", 25.0)
	await _settle()

	_ok(_scene_name() == "DustCampRunMap", "the run map came back", _scene_name())
	_ok(_count("DustCampArena") == 0, "the arena is unloaded, not kept around")

	var back := _find("RunMapDirector") as RunMapDirector
	var back_graph := back.get_graph() if back != null else null
	_ok(back_graph != null and back_graph.seed == made_seed
			and back_graph.sites.size() == made_points,
		"it is the same map, not a freshly generated one")
	if back_graph == null:
		_finish()
		return
	_ok(back_graph.current_id == target, "the piece is standing where it rode to")
	_ok(entry != null and back_graph.get_site(target).kind == entry.cleared_kind,
		"the point is written down as dealt with",
		"it reads as '%s'" % back_graph.get_site(target).kind)

	var back_node := _find("RunMapBountyBossNode") as RunMapBountyBossNode
	var kept := true
	for other: RunMapSite in _boss_points(back_graph, back_node):
		if other.contract_id.is_empty():
			kept = false
	_ok(kept, "and the boss points that are left still name their own men")

	var back_view := _find("RunMapView") as RunMapView
	_ok(back_view != null and back_view.is_picking(),
		"the map is taking the next choice")

	_finish()


# --- The rule the points are dealt by -------------------------------------------

## The map laid out for a player carrying contracts and for one carrying none.
## Done straight off the generator rather than through a scene, because this is a
## statement about the distribution and nothing else.
func _check_distribution() -> void:
	var generator: RunMapGenerator = load(GENERATOR)
	if generator == null:
		_ok(false, "the dust camp generator loads")
		return

	var named := false
	for plan: RunMapSitePlan in generator.site_plans:
		if plan != null and plan.kind == &"mini_boss":
			named = true
	_ok(not named, "the distribution no longer deals a mini boss point")

	for carried: int in [0, 1, 2, 3]:
		var worst := -1
		var best := -1
		for run: int in range(12):
			var graph := generator.generate(200000 + run, carried)
			var found := _count_kind(graph, &"bounty")
			worst = found if worst < 0 else mini(worst, found)
			best = maxi(best, found)
		_ok(worst == carried and best == carried,
			"a run carrying %d contracts is dealt %d boss points" % [carried, carried],
			"%d..%d over 12 runs" % [worst, best])


## Takes up to [param wanted] contracts off the board, and reports how many
## actually went through. The board is restocked where a thin week left it short,
## which is the same call coming home already makes.
func _take_contracts(ledger: BountyLedger, wanted: int) -> int:
	var taken := 0
	for _attempt: int in range(6):
		if taken >= wanted:
			break
		for bounty: Bounty in ledger.get_board_bounties():
			if taken >= wanted:
				break
			if ledger.accept(bounty):
				taken += 1
		if taken < wanted:
			ledger.refresh_board()
	return taken


# --- Looking things up -----------------------------------------------------------

## Every bounty boss point on [param graph], beaten or not, in the order they
## were dealt.
func _boss_points(graph: RunMapGraph, node: RunMapBountyBossNode) -> Array[RunMapSite]:
	var found: Array[RunMapSite] = []
	if graph == null or node == null:
		return found
	for site: RunMapSite in graph.sites:
		if node.answers(site.kind):
			found.append(site)
	return found


func _count_kind(graph: RunMapGraph, kind: StringName) -> int:
	var found := 0
	if graph == null:
		return 0
	for site: RunMapSite in graph.sites:
		if site.kind == kind:
			found += 1
	return found


## The shortest run of roads to a bounty boss point, through points that raise
## nothing on the way - so the only encounter this measures is the one it is
## about.
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
				# A boss point is the end of a route, never a step along it.
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


func _find_health(body: Node) -> Health:
	for child: Node in body.find_children("*", "Health", true, false):
		return child as Health
	return null


## Waits up to [param seconds] of real time for [param test] to come true.
## Counted off the clock rather than off a frame count, because everything being
## waited on here - a tween, a scene tree timer, a threaded load - is timed in
## seconds, and a headless run draws far more frames a second than a played one.
func _wait_for(test: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)
	while Time.get_ticks_msec() < until and not bool(test.call()):
		await process_frame


## Waits out the curtain: its minimum display time, the threaded load and the
## reveal, however long each happens to take.
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
		print("[PASS] run map bounty boss: every check passed")
	else:
		print("[FAIL] run map bounty boss: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _scene_name() -> String:
	return "<none>" if current_scene == null else String(current_scene.name)


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


## How many of his men are standing by rather than fighting.
func _passive_men(boss: Node) -> int:
	var found := 0
	for node: Node in root.get_tree().get_nodes_in_group(&"enemies"):
		if node != boss and node.has_method(&"is_passive") and node.call(&"is_passive"):
			found += 1
	return found


## One of his men still standing, or null.
func _one_man(boss: Node) -> Node2D:
	for node: Node in root.get_tree().get_nodes_in_group(&"enemies"):
		var man := node as Node2D
		if man != null and man != boss and not man.is_queued_for_deletion():
			var health := _find_health(man)
			if health != null and health.is_alive():
				return man
	return null
