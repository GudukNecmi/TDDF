class_name RunMapDirector
extends Node
## The run map's own director: it makes the map for this run, draws it, takes the
## player's choice, pays for the ride and hands the arrival on.
##
## [b]This is what replaced riding the desert freely.[/b] A run used to be a
## player body walking across a ten-thousand-pixel region; it is now a piece
## standing on a generated node graph. Setting out from the base opens this
## scene, the player picks one of the roads leading out of the point they are
## standing on, the map's choices close, the ride is spent in whole day cycles,
## and the map comes back with the piece somewhere new.
##
## [b]The map outlives the scene.[/b] The graph is generated once per run and
## written into [WorldMapState]'s between-scenes memory under
## [constant WorldMapState.KIND_RUN_MAP], so a node's own event - which will be a
## real scene change, like every other place in this game - can open and close
## without the run losing its map. Which run it belongs to is stamped on it from
## [method RunSessionState.get_run_index]: a stamp that no longer matches is the
## one thing that makes a new map.
##
## [b]What is at a point is deliberately not decided here.[/b] Which kind of
## place each point is was dealt out by the generator's node distribution - see
## [member RunMapGenerator.site_plans] - and what [i]happens[/i] at one is a
## listener on [signal site_reached] that runs its own encounter and comes back,
## not a branch added to this file. [RunMapBanditNode] is the first of them,
## answering the two sizes of bandit point; the market, saloon, treasure,
## deposit, extraction, event and sheriff outpost are already on the map and
## arrive the same way once each has a listener of its own.

## Emitted the moment the piece arrives somewhere, before the map's choices open
## again. [b]The seam every node event will hang off.[/b]
signal site_reached(site: RunMapSite)
## Emitted once a fresh map has been generated, with the graph. For a debug
## readout or a smoke check.
signal map_generated(graph: RunMapGraph)

## Which region of the map this run map is. Its own, not the session's: a run map
## belongs to one place, and the graph it generates is stored under this handle.
@export var region_id: StringName = &"A"
## The numbers this map's graph is laid out with. [b]A map's own, and the whole
## of what makes one region's run map different from another's[/b] - see
## [RunMapGenerator].
@export var generator: RunMapGenerator
## Fixed seed for the graph, for reproducing a layout. 0 - the default, and what
## a real run uses - makes a different map every run.
@export var map_seed: int = 0

@export_group("Discovery")
## How far the fog lifts around a point the piece arrives on, counted in roads.
## [b]One[/b]: standing somewhere turns over every point its own roads lead to,
## so the map opens out one ring at a time as it is walked and the player
## chooses between places they can see rather than between question marks. 0
## learns only the point underfoot, which is the map as it was before; a larger
## number is a map that gives itself away faster. Nothing here reaches past the
## roads that exist, so a distant unconnected point is never turned over.
@export var reveal_depth: int = 1

@export_group("Wiring")
@export var view_path: NodePath = ^"../RunMapView"
@export var travel_path: NodePath = ^"../RunMapTravel"
@export var world_state_path: NodePath = ^"/root/WorldState"
@export var session_path: NodePath = ^"/root/RunSession"
## The contract ledger - the [code]Bounties[/code] autoload. Read for one number
## only, at the moment a map is made: how many contracts the player rode out
## carrying, which is what the plans flagged
## [member RunMapSitePlan.one_per_accepted_bounty] are counted off. A map with no
## ledger to ask is made as though nothing had been taken off the board.
@export var ledger_path: NodePath = ^"/root/Bounties"

var _graph: RunMapGraph
var _view: RunMapView
var _travel: RunMapTravel
var _state: Node
var _session: Node


func _ready() -> void:
	_view = get_node_or_null(view_path) as RunMapView
	_travel = get_node_or_null(travel_path) as RunMapTravel
	_state = get_node_or_null(world_state_path)
	_session = get_node_or_null(session_path)

	_graph = _load_graph()
	if _graph == null:
		_graph = _make_graph()
	# The point the run opens on gives its own roads away exactly as every point
	# reached after it does, so the map is never first seen as an unbroken field
	# of question marks.
	_discover(_graph.current_id if _graph != null else -1)

	if _view != null:
		if not _view.site_chosen.is_connected(_on_site_chosen):
			_view.site_chosen.connect(_on_site_chosen)
		if not _view.site_re_entered.is_connected(_on_site_re_entered):
			_view.site_re_entered.connect(_on_site_re_entered)
		_view.build(_graph)
		_view.set_picking(true)

	if _travel != null and not _travel.travel_finished.is_connected(_on_travel_finished):
		_travel.travel_finished.connect(_on_travel_finished)


## The graph this run is being played on. Null only in a scene opened on its own
## with no generator dropped on it.
func get_graph() -> RunMapGraph:
	return _graph


## Makes a fresh map and stores it, throwing away whatever was there. Public so a
## debug control can reroll the run map without restarting the game.
func regenerate() -> RunMapGraph:
	_graph = _make_graph()
	if _view != null:
		_view.build(_graph)
		_view.set_picking(true)
	return _graph


## Writes the map back into the run's between-scenes memory. Public because a
## node event may change what is on the graph - a bandit point written down as
## dealt with, say - and that has to survive the scene the event opens. See
## [RunMapBanditNode].
func store_graph() -> void:
	_store(_graph)


func _make_graph() -> RunMapGraph:
	if generator == null:
		push_warning("RunMapDirector: no generator on '%s' - there is no map to make."
			% region_id)
		return null
	var graph := generator.generate(map_seed, accepted_bounty_count())
	_store(graph)
	map_generated.emit(graph)
	return graph


## How many contracts the player is carrying into this run. What decides how many
## bounty boss points the map is dealt - see
## [member RunMapSitePlan.one_per_accepted_bounty] - and public so the listener
## that binds those points to their men can count off the same list.
func accepted_bounty_count() -> int:
	var ledger := get_node_or_null(ledger_path) as BountyLedger
	return 0 if ledger == null else ledger.get_outstanding().size()


## The graph this run already has, or null when there is none - which includes a
## graph left over from a previous run, since the stamp will not match.
func _load_graph() -> RunMapGraph:
	if _state == null or not _state.has_method(&"recall"):
		return null
	var record: Dictionary = _state.call(
		&"recall", region_id, WorldMapState.KIND_RUN_MAP, &"graph")
	if record.is_empty():
		return null
	if int(record.get(&"run_index", -1)) != _run_index():
		return null
	return RunMapGraph.from_dict(record.get(&"graph", {}))


func _store(graph: RunMapGraph) -> void:
	if graph == null or _state == null or not _state.has_method(&"remember"):
		return
	_state.call(&"remember", region_id, WorldMapState.KIND_RUN_MAP, &"graph", {
		&"run_index": _run_index(),
		&"graph": graph.to_dict(),
	})


func _run_index() -> int:
	if _session == null or not _session.has_method(&"get_run_index"):
		return 0
	return int(_session.call(&"get_run_index"))


# --- Choosing, riding, arriving -------------------------------------------------

## The map's choices close the instant one is taken, so the ride cannot be
## interrupted by a second click and nothing is haloed while the piece is between
## two points.
func _on_site_chosen(_site_id: int, link: RunMapLink) -> void:
	if _travel == null or _view == null or _travel.is_travelling():
		return
	_view.set_picking(false)
	if not _travel.begin(_view, link, _graph.current_id):
		_view.set_picking(true)


## The arrival: the piece is standing somewhere new, the point is learned, the
## map is written back, and whatever is there is announced. The choices open
## again straight after, which is the whole of the flow until there are events to
## run in between.
func _on_travel_finished(site_id: int) -> void:
	if _graph == null:
		return
	_graph.move_to(site_id)
	# Arriving somewhere is also learning what its roads lead to - see
	# [member reveal_depth].
	_graph.reveal_around(site_id, reveal_depth)
	_store(_graph)
	if _view != null:
		_view.refresh()
	site_reached.emit(_graph.get_site(site_id))
	if _view != null:
		_view.set_picking(true)


## Clicking the point the piece is already standing on. [b]Nothing moves and
## nothing is spent[/b] - the arrival is simply announced again, so a saloon or
## a market is walked back into through the very seam it opened through the
## first time and no listener needs a second entry point. Which points answer
## this at all is each kind's own [member RunMapSiteKind.re_enterable], read by
## [RunMapView] before the click ever reaches here, so a fight already had is
## not had again.
func _on_site_re_entered(site_id: int) -> void:
	if _graph == null or site_id != _graph.current_id:
		return
	site_reached.emit(_graph.get_site(site_id))


## Turns over [param site_id] and everything within [member reveal_depth] roads
## of it, and writes the map down if that actually learned anything. Kept in one
## place because the run's opening point and every arrival after it discover by
## exactly the same rule.
func _discover(site_id: int) -> void:
	if _graph == null or site_id < 0:
		return
	if _graph.reveal_around(site_id, reveal_depth).is_empty():
		return
	_store(_graph)
	if _view != null:
		_view.refresh()
