class_name RunMapSaloonInformation
extends Node
## What the bartender actually knows: the first real answer behind the saloon's
## information seam, and the thing that takes question marks off the run map.
##
## [b]It is a listener, not a branch.[/b] [RunMapSaloonScreen] was built with its
## information half deliberately empty - asking a subject emits
## [signal RunMapSaloonScreen.information_asked] and whatever knows the answer
## replies by calling [method RunMapSaloonScreen.tell] from inside that handler.
## This is the first thing to reply. The screen still reads no database, still
## has no branch about bounties or covered places, and a second source of
## information - a bounty log, a scout, a map bought in a market - arrives as a
## second listener beside this one.
##
## [b]What a subject can point out is on the subject.[/b] A topic lists the
## kinds of place asking about it may turn over - see
## [member RunMapSaloonTopic.reveals_kinds] - and this finds the nearest point
## of one of those kinds the player has not learned yet, measured from where the
## piece is standing. A subject that lists nothing points nothing out and keeps
## saying its placeholder line, which is what every subject did before this
## existed.
##
## [b]A reveal is kept for the rest of the run.[/b] It is written onto the graph
## itself, which [RunMapDirector] stores in [WorldMapState]'s between-scenes
## memory - so a place pointed out in a saloon is still known after a fight, an
## arena and a ride across half the map.
##
## [b]Some places are worth flying out to.[/b] A kind whose
## [member RunMapSiteKind.presented_when_revealed] is set - the bounty, the
## final boss - is not simply turned over: it is held back until the player
## leaves the saloon and then shown, the camera crossing the map to frame it as
## the question mark comes off. See [method RunMapView.present_site]. It waits
## for the saloon to close because the saloon is a full screen over the board:
## a presentation played behind it would be a presentation nobody sees.

## Emitted once a place has been pointed out, with the point and the subject
## that pointed at it. The point may not be revealed yet - one worth a
## presentation is turned over when the camera reaches it.
signal place_pointed_out(site: RunMapSite, topic: RunMapSaloonTopic)

@export_group("Wiring")
@export var director_path: NodePath = ^"../RunMapDirector"
@export var view_path: NodePath = ^"../RunMapView"
## The saloon this listens to. Optional, and looked up by group when it is not
## set, exactly as [RunMapSaloonNode] finds it.
@export var screen_path: NodePath = ^"../UI/RunMapSaloonScreen"

var _director: RunMapDirector
var _view: RunMapView
var _screen: RunMapSaloonScreen
## Places pointed out that are still owed their presentation, in the order they
## were asked about. Held until the saloon is out of the way - see the class doc.
var _owed: Array[int] = []


func _ready() -> void:
	_director = get_node_or_null(director_path) as RunMapDirector
	_view = get_node_or_null(view_path) as RunMapView
	var screen := _resolve_screen()
	if screen == null:
		return
	if not screen.information_asked.is_connected(_on_information_asked):
		screen.information_asked.connect(_on_information_asked)
	if not screen.closed.is_connected(_on_screen_closed):
		screen.closed.connect(_on_screen_closed)
	if _view != null:
		if not _view.presentation_revealed.is_connected(_on_presentation_revealed):
			_view.presentation_revealed.connect(_on_presentation_revealed)
		if not _view.presentation_finished.is_connected(_on_presentation_finished):
			_view.presentation_finished.connect(_on_presentation_finished)


## The nearest point of one of [param kinds] the player has not learned yet,
## measured from where the piece is standing, or null when every one of them is
## already on the map. Ties are broken by id, so the same question on the same
## map always points at the same place.
func nearest_unknown(kinds: Array[StringName]) -> RunMapSite:
	var graph := _graph()
	if graph == null or kinds.is_empty():
		return null
	var from := graph.get_current_site()
	var origin := Vector2.ZERO if from == null else from.position
	var found: RunMapSite = null
	var best := INF
	for site: RunMapSite in graph.sites:
		if site.revealed or not kinds.has(site.kind):
			continue
		var distance := site.position.distance_to(origin)
		if distance < best:
			best = distance
			found = site
	return found


# --- Answering ------------------------------------------------------------------

func _on_information_asked(topic: RunMapSaloonTopic) -> void:
	if topic == null or topic.reveals_kinds.is_empty():
		return
	var screen := _resolve_screen()
	if screen == null:
		return

	var site := nearest_unknown(topic.reveals_kinds)
	if site == null:
		# Everything this subject knows about is already on the map. Said in the
		# subject's own words when it has them, and left to the placeholder line
		# when it does not.
		if not topic.nothing_left_line.is_empty():
			screen.tell(topic.nothing_left_line)
		return

	if _view != null and _view.presented_when_revealed(site.id):
		# Held back so the question mark comes off while the player is watching
		# it - the presentation turns the point over itself.
		if not _owed.has(site.id):
			_owed.append(site.id)
	else:
		_reveal_now(site.id)

	if not topic.reveal_line.is_empty():
		screen.tell(topic.reveal_line % _name_of(site.id))
	place_pointed_out.emit(site, topic)


## A place learned outright: onto the graph, into the run's memory and onto the
## map, with nothing to watch.
func _reveal_now(site_id: int) -> void:
	var graph := _graph()
	if graph == null or not graph.reveal(site_id):
		return
	if _director != null:
		_director.store_graph()
	if _view != null:
		_view.refresh()


func _on_screen_closed() -> void:
	# Deferred for the same reason [RunMapSaloonNode] defers its own call: the
	# saloon point reopens the map's choices on this very signal, and a
	# presentation has to start after that rather than have its close of them
	# undone.
	_play_next.call_deferred()


func _play_next() -> void:
	if _owed.is_empty() or _view == null or _view.is_presenting():
		return
	_view.present_site(_owed[0])


## The camera has reached the place and taken its question mark off, so the run
## is told about it now rather than when the flight ends - a map written down
## the moment it changes.
func _on_presentation_revealed(_site_id: int) -> void:
	if _director != null:
		_director.store_graph()


func _on_presentation_finished(site_id: int) -> void:
	_owed.erase(site_id)
	_play_next()


# --- Odds and ends --------------------------------------------------------------

## What a place is called even though the player has not learned it yet - the
## bartender is the one doing the telling, so the fog is not asked about here.
func _name_of(site_id: int) -> String:
	return "" if _view == null else _view.true_name_of(site_id)


func _graph() -> RunMapGraph:
	if _director != null:
		return _director.get_graph()
	return null if _view == null else _view.get_graph()


func _resolve_screen() -> RunMapSaloonScreen:
	if _screen != null and is_instance_valid(_screen):
		return _screen
	_screen = get_node_or_null(screen_path) as RunMapSaloonScreen
	if _screen == null:
		_screen = RunMapSaloonScreen.get_active(self)
	return _screen
