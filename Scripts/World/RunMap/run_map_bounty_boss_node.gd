class_name RunMapBountyBossNode
extends Node
## The run map's bounty boss points: which contract is waiting at each, and what
## happens when the piece arrives on one.
##
## [b]It is a listener on [signal RunMapDirector.site_reached], built exactly
## like the others.[/b] [RunMapBanditNode] answers bandit points and
## [RunMapSaloonNode] answers saloons the same way: each hears an arrival, deals
## with its own kind of point, and knows nothing about riding, generating or
## drawing the map. None of them knows the others exist, which is the whole
## reason the arrival is a signal rather than a branch in [RunMapDirector].
##
## [b]There is one kind of boss in the game and it is a contract.[/b] The run map
## used to deal standalone mini boss points whose difficulty, name and face were
## authored on a resource; it deals bounty boss points now, one for every
## contract the player rode out carrying - see
## [member RunMapSitePlan.one_per_accepted_bounty] - and a player who took
## nothing off the board rides out on a map with no boss point on it anywhere.
##
## [b]Which point is which man is decided once and written onto the map.[/b] The
## points come off the graph in the order they were dealt and the contracts off
## [method BountyLedger.get_outstanding] in the order they were taken, and the
## two are paired the first time this node sees a fresh graph - see
## [method bind_contracts]. It has to be written down rather than counted up at
## the moment of arrival, because beating one outlaw closes his contract and
## would shift every answer counted from the live list.
##
## [b]What happens after the scene change is not written here, and none of it is
## new.[/b] Arriving hands the point to
## [method WorldMapCombatBridge.try_begin_mini_boss_encounter], which stages the
## same record every other encounter stages and goes to the same arena. There
## [RunMiniBossFight] brings the man in among his support group, which is held at
## its count for the whole fight, [BossDefeat] pays the contract and strikes his
## name out, and the player decides what is done with him. This node's whole job
## is saying [i]who[/i] is on a point, [i]how many[/i] men stand with him, and
## holding his poster up on the way.

## Emitted the instant a bounty boss point's fight has been committed to, with
## the point, the contract and the man. For a readout or a smoke check; the point
## has already been written down as dealt with by the time this fires.
signal bounty_boss_committed(site: RunMapSite, bounty: Bounty, boss: MiniBossBrief)
## Emitted once a fresh graph's points have been paired off with the contracts
## they stand for, with how many pairs that came to.
signal contracts_bound(count: int)

@export_group("Wiring")
@export var director_path: NodePath = ^"../RunMapDirector"
@export var view_path: NodePath = ^"../RunMapView"
## The encounter bridge this hands an arrival to. Optional: a map with none
## simply arrives on a bounty boss point and does nothing, which is what a run
## map opened on its own for tuning should do.
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"
## The contract ledger - the [code]Bounties[/code] autoload.
@export var ledger_path: NodePath = ^"/root/Bounties"
## The screen the contract is held up on as the piece lands. Optional, and looked
## up by group when it is not set: a map without one rides straight into the
## fight.
@export var poster_path: NodePath = ^"../UI/RunMapBountyPosterScreen"

@export_group("Which points are bounty bosses")
## Every kind of bounty boss point this map has, one
## [RunMapBountyBossEncounter] each. [b]Adding a heavier sort of bounty point is
## a [code].tres[/code] here[/b] - no threshold, branch or count in this file
## names one.
@export var encounters: Array[RunMapBountyBossEncounter] = []

@export_group("Music")
## The soundtrack - the [code]MusicStates[/code] autoload. Optional: a map with
## none rides in silent.
@export var music_states_path: NodePath = ^"/root/MusicStates"
## The track a bounty boss opens with, entered the instant the poster sets off
## and held all the way through the fight. It is the same state
## [member WorldMapCombatBridge.run_map_boss_state] names, so the arena asking
## for it again on the far side of the scene change changes nothing and the song
## does not so much as blink. Empty leaves the map's own music playing.
@export var music_state: StringName = &"bounty_boss"

var _director: RunMapDirector
var _view: RunMapView
var _bridge: WorldMapCombatBridge
var _ledger: BountyLedger
var _poster: RunMapBountyPosterScreen
## The point whose poster is currently up, held so the fight it opens is the one
## the sheet was printed for. Null whenever no presentation is running.
var _presenting: RunMapSite


func _ready() -> void:
	_director = get_node_or_null(director_path) as RunMapDirector
	_view = get_node_or_null(view_path) as RunMapView
	if _director != null and not _director.site_reached.is_connected(_on_site_reached):
		_director.site_reached.connect(_on_site_reached)
	# Done here rather than off [signal RunMapDirector.map_generated], which a
	# director standing above this node in the tree has already emitted by the
	# time this runs. Binding is idempotent - see [method bind_contracts] - so a
	# map that comes back from storage already paired off is simply left alone.
	if _director != null:
		bind_contracts(_director.get_graph())


## The entry answering points of [param kind], or null for a handle no entry
## names - which every caller reads as "not a bounty boss point".
func encounter_for(kind: StringName) -> RunMapBountyBossEncounter:
	for entry: RunMapBountyBossEncounter in encounters:
		if entry != null and entry.kind == kind:
			return entry
	return null


## Whether [param kind] is a bounty boss point, beaten or not. Both handles
## count, because the pairing has to keep its order over a map whose outlaws are
## being worked through one at a time.
func answers(kind: StringName) -> bool:
	for entry: RunMapBountyBossEncounter in encounters:
		if entry == null:
			continue
		if entry.kind == kind or (not entry.cleared_kind.is_empty()
				and entry.cleared_kind == kind):
			return true
	return false


## Pairs every bounty boss point on [param graph] off with the contract it stands
## for, and reports how many pairs that came to.
##
## [b]It only ever fills a blank.[/b] A point that already names a contract keeps
## it, and a contract already spoken for by some other point is never handed out
## twice - so this can be asked on every build of the map scene and the answer
## never moves, whatever has been beaten in between.
func bind_contracts(graph: RunMapGraph) -> int:
	var ledger := _get_ledger()
	if graph == null or ledger == null:
		return 0

	var points: Array[RunMapSite] = []
	var spoken_for: Dictionary = {}
	for site: RunMapSite in graph.sites:
		if not answers(site.kind):
			continue
		if site.contract_id.is_empty():
			points.append(site)
		else:
			spoken_for[site.contract_id] = true

	if points.is_empty():
		return 0
	# The graph's own order, so the pairing is the order the points were dealt
	# rather than the order they happen to be stored in.
	points.sort_custom(func(a: RunMapSite, b: RunMapSite) -> bool: return a.id < b.id)

	var bound := 0
	for bounty: Bounty in ledger.get_outstanding():
		if bound >= points.size():
			break
		if bounty == null or spoken_for.has(bounty.bounty_id):
			continue
		points[bound].contract_id = bounty.bounty_id
		bound += 1

	if bound > 0:
		if _director != null:
			_director.store_graph()
		contracts_bound.emit(bound)
	return bound


## The contract waiting at [param site], or null for a point that names none or
## whose contract the ledger no longer holds.
func bounty_for(site: RunMapSite) -> Bounty:
	if site == null or site.contract_id.is_empty():
		return null
	var ledger := _get_ledger()
	return null if ledger == null else ledger.find_bounty(site.contract_id)


## How many men stand in front of the outlaw at [param site], on the map
## [param graph]. The same answer every time for the same point on the same map,
## since the roll is seeded from the two of them rather than kept anywhere.
## 0 for a point no entry answers.
func support_count_for(graph: RunMapGraph, site: RunMapSite) -> int:
	if graph == null or site == null:
		return 0
	var entry := encounter_for(site.kind)
	if entry == null:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graph.seed, site.id, &"bounty_boss"])
	return rng.randi_range(
		mini(entry.min_support, entry.max_support),
		maxi(entry.min_support, entry.max_support))


## Who is waiting at [param site] - see [MiniBossBrief]. Null for a point no
## entry answers or one whose contract has gone.
##
## [b]Only the contract is carried.[/b] Everything else about the man - his rung,
## his health, his name and his face - is derived from that contract by
## [method MiniBossBrief.from_bounty] in the arena, where [MiniBossDirector] and
## its own tuning actually live, so a run map boss and a boss found any other way
## are built off one answer rather than two that have to agree.
func boss_for(site: RunMapSite) -> MiniBossBrief:
	var bounty := bounty_for(site)
	if encounter_for(site.kind if site != null else &"") == null or bounty == null:
		return null
	var brief := MiniBossBrief.new()
	brief.contract_id = bounty.bounty_id
	if bounty.target != null and not bounty.target.display_name.is_empty():
		brief.display_name = bounty.target.display_name
	brief.look_key = bounty.target.target_id if bounty.target != null else bounty.bounty_id
	brief.known = bounty.get_generated_knowledge()
	return brief


# --- Arriving on one ------------------------------------------------------------

func _on_site_reached(site: RunMapSite) -> void:
	if site == null or _presenting != null or encounter_for(site.kind) == null:
		return
	if _resolve_bridge() == null:
		return
	if bounty_for(site) == null:
		push_warning("RunMapBountyBossNode: point %d has no contract behind it." % site.id)
		return

	_presenting = site
	# Deferred so it lands after [RunMapDirector] opens the map's choices again -
	# a haloed road behind a poster is a road the player is being invited to take.
	if _view != null:
		_view.set_picking.call_deferred(false)
	_start_the_music()

	var screen := _resolve_poster()
	if screen != null:
		if not screen.finished.is_connected(_on_poster_finished):
			screen.finished.connect(_on_poster_finished, CONNECT_ONE_SHOT)
		if screen.present(bounty_for(site)):
			return
		if screen.finished.is_connected(_on_poster_finished):
			screen.finished.disconnect(_on_poster_finished)

	# No sheet to hold up, or it refused: the fight is the point, so it starts
	# anyway rather than the arrival quietly doing nothing.
	_commit(site)


func _on_poster_finished(_bounty: Bounty) -> void:
	var site := _presenting
	if site == null:
		return
	_commit(site)


## Hands the point to the bridge, which changes scene. The point is written down
## as dealt with first, because there is no coming back to this map to do it -
## see [RunMapBanditNode._on_answered], which writes its point down at the one
## moment it can for the same reason.
func _commit(site: RunMapSite) -> void:
	_presenting = null
	var entry := encounter_for(site.kind)
	var bridge := _resolve_bridge()
	if entry == null or bridge == null:
		_give_the_map_back()
		return

	var graph := _director.get_graph() if _director != null else null
	var region := _director.region_id if _director != null else &""
	# Both are read off the point while it still reads as a bounty boss point: it
	# is renamed a line later, and both answer by the point's own handle.
	var bounty := bounty_for(site)
	var boss := boss_for(site)
	var support := support_count_for(graph, site)
	if boss == null:
		_give_the_map_back()
		return

	if not entry.cleared_kind.is_empty():
		site.kind = entry.cleared_kind
	if _director != null:
		_director.store_graph()
	if _view != null:
		_view.refresh()

	if bridge.try_begin_mini_boss_encounter(region, support, boss):
		bounty_boss_committed.emit(site, bounty, boss)
		return

	# Refused - something else is already running - so the point is put back
	# exactly as it was found and will ask again the next time the piece stands
	# on it.
	site.kind = entry.kind
	if _director != null:
		_director.store_graph()
	_give_the_map_back()


## The roads live again, for the paths that end without a scene change.
func _give_the_map_back() -> void:
	if _view != null:
		_view.refresh()
		_view.set_picking(true)


## Enters the bounty boss's own track, so the music is already running under the
## poster and carries on unbroken through the scene change into the fight - the
## board is an autoload and the arena asks for the state it is already in. See
## [member music_state].
func _start_the_music() -> void:
	if music_state.is_empty():
		return
	var board := get_node_or_null(music_states_path) as MusicStateBoard
	if board == null:
		board = MusicStateBoard.get_active(self)
	if board != null:
		board.enter_immediate(music_state)


func _resolve_bridge() -> WorldMapCombatBridge:
	if _bridge != null and is_instance_valid(_bridge):
		return _bridge
	_bridge = get_node_or_null(bridge_path) as WorldMapCombatBridge
	if _bridge == null:
		_bridge = WorldMapCombatBridge.get_active(self)
	return _bridge


func _resolve_poster() -> RunMapBountyPosterScreen:
	if _poster != null and is_instance_valid(_poster):
		return _poster
	_poster = get_node_or_null(poster_path) as RunMapBountyPosterScreen
	if _poster == null:
		_poster = RunMapBountyPosterScreen.get_active(self)
	return _poster


func _get_ledger() -> BountyLedger:
	if _ledger != null and is_instance_valid(_ledger):
		return _ledger
	_ledger = get_node_or_null(ledger_path) as BountyLedger
	return _ledger
