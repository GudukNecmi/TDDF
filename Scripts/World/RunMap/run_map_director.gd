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
## answering the two sizes of bandit point; the mini boss, market, saloon,
## treasure, deposit, extraction, event, bounty and sheriff outpost are already
## on the map and arrive the same way once each has a listener of its own.

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

@export_group("Wiring")
@export var view_path: NodePath = ^"../RunMapView"
@export var travel_path: NodePath = ^"../RunMapTravel"
@export var world_state_path: NodePath = ^"/root/WorldState"
@export var session_path: NodePath = ^"/root/RunSession"

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

	if _view != null:
		if not _view.site_chosen.is_connected(_on_site_chosen):
			_view.site_chosen.connect(_on_site_chosen)
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
	var graph := generator.generate(map_seed)
	_store(graph)
	map_generated.emit(graph)
	return graph


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
	_store(_graph)
	if _view != null:
		_view.refresh()
	site_reached.emit(_graph.get_site(site_id))
	if _view != null:
		_view.set_picking(true)
