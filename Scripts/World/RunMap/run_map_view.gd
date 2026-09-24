class_name RunMapView
extends Node2D
## The run map, drawn and picked from: every point, every road between them, and
## the piece the player is.
##
## [b]The roads are always drawn; the points are not always known.[/b] That is
## the whole of the map's fog, and it lives here rather than in the graph: a site
## that has not been revealed is drawn with the map's unknown-point art and no
## name, but it is drawn, and so is every road running into it. The player can
## always see where they [i]could[/i] go and how long each road takes - what they
## cannot see is what is waiting at the far end. See [member fog_kind]. What
## lifts that fog is not here either: arriving somewhere turns over the points
## it is joined to - see [member RunMapDirector.reveal_depth] - and so does
## being told where something is in a saloon.
##
## [b]It offers every road, not only the ones going east.[/b] The choices are
## simply [method RunMapGraph.neighbours_of] the point the piece is standing on,
## so a sideways or backward road the generator happened to make is a move the
## player may take, and nothing here has a rule about direction.
##
## [b]The point the piece is already on is a choice too.[/b] Clicking it does
## not set out - there is nowhere to ride - it walks back in, which is how a
## saloon slept in is drunk in afterwards and how a market is gone back to. Only
## points whose authored kind says so answer that click, which is where "a
## fight is not replayable" is written: see
## [member RunMapSiteKind.re_enterable].
##
## [b]It owns picking, not travelling.[/b] Choosing a road closes the map's
## choices and hands the road to [RunMapTravel], which spends the day cycles and
## walks the piece along it; this node is asked to put the piece at a fraction of
## the way along while that happens - see [method place_token_on]. Keeping the
## two apart is what lets the tick pacing be retuned without touching the
## drawing, and what will let a node event open a scene between the arrival and
## the map coming back.

## Emitted when the player picks a road, with the point at the far end of it and
## the road itself.
signal site_chosen(site_id: int, link: RunMapLink)
## Emitted when the player clicks the point the piece is already standing on and
## that point is one that can be walked back into. [b]No ride, no day cycles,
## nothing moved[/b] - [RunMapDirector] answers it by announcing the arrival
## again, so a saloon or a market reopens through exactly the seam it opened
## through the first time.
signal site_re_entered(site_id: int)
## Emitted as the mouse moves over, or off, a point. -1 and null when it is over
## nothing, which the panel reads as "show the standing instruction instead";
## a point with no road from where the piece stands reports itself with a null
## road, which the panel reads as a name with no ride to price.
signal hover_changed(site_id: int, link: RunMapLink)
## Emitted as a presentation sets off, before anything has moved - see
## [method present_site]. The map's own readout goes quiet on it, since the
## player is being shown something rather than asked something.
signal presentation_started(site_id: int)
## Emitted at the moment a presentation reaches the place it is pointing out and
## the question mark comes off it - see [method present_site]. Whatever asked
## for the presentation writes the map down here.
signal presentation_revealed(site_id: int)
## Emitted once a presentation has flown back and the map is the player's again.
signal presentation_finished(site_id: int)

## Where each part of the map is built. Containers rather than one flat list, so
## the roads are always drawn beneath the points and the piece always on top,
## without anything here setting a z index per node.
@export var links_container_path: NodePath = ^"Links"
@export var sites_container_path: NodePath = ^"Sites"
@export var token_path: NodePath = ^"Token"
## The camera looking at the map.
@export var camera_path: NodePath = ^"Camera"

@export_group("Pieces")
## The marker one point is drawn with - see [RunMapSiteMarker].
@export var site_scene: PackedScene
## Every kind of place this map can show, matched to a site by its handle. An
## array rather than a field per kind: adding the bandit, market or saloon point
## a later task brings is dropping its [code].tres[/code] in here.
@export var site_kinds: Array[RunMapSiteKind] = []
## Which handle a point the player has not learned is drawn as. [b]The fog is
## this one line[/b]: an unrevealed site is drawn with this entry's art whatever
## it actually turns out to be.
@export var fog_kind: StringName = &"unknown"

@export_group("Roads")
## The dash tiled along a road.
@export var link_texture: Texture2D
## How thick a road is drawn.
@export var link_width: float = 14.0
## Colour of a road the player cannot take from where they are standing.
@export var link_color: Color = Color(0.72, 0.64, 0.52, 0.65)
## Colour of a road running out of the point the piece is standing on - one of
## this turn's choices.
@export var link_choice_color: Color = Color(0.95, 0.86, 0.66, 1.0)
## Colour of the road the mouse is over.
@export var link_hover_color: Color = Color(0.86, 0.26, 0.2, 1.0)
## Colour of a road already ridden.
@export var link_taken_color: Color = Color(0.45, 0.38, 0.31, 0.55)

@export_group("Camera")
## How far out the map is seen, as a Camera2D zoom. Below 1 shows more map.
@export_range(0.05, 2.0, 0.01) var map_zoom: float = 0.62
## The closest the wheel may bring the map.
@export_range(0.05, 4.0, 0.01) var max_zoom: float = 1.1
## The furthest out the wheel may take it.
@export_range(0.05, 4.0, 0.01) var min_zoom: float = 0.3
## How much one notch of the wheel changes the zoom.
@export_range(0.0, 1.0, 0.01) var zoom_step: float = 0.08
## How quickly the camera settles on the piece.
@export var camera_speed: float = 6.0
## How much empty map is kept round the edge of the graph before the camera
## stops following, in map pixels.
@export var camera_margin: float = 420.0
## How far east of the piece the camera actually looks, in map pixels. The map
## runs west to east, so the choices are all to the right of the player and a
## camera centred exactly on the piece spends half the screen on ground already
## ridden and pushes the roads being chosen between up against the right edge.
@export var camera_lead: float = 320.0

@export_group("Pointing a place out")
## How much closer the camera goes while it is framing the place it has flown
## out to, against however far out the map is currently being seen. Four times
## in, so a single point fills the screen and the marker coming out from under
## its question mark is unmissable.
@export_range(1.0, 12.0, 0.1) var presentation_zoom_scale: float = 4.0
## How many seconds the flight out takes.
@export var presentation_travel_time: float = 1.2
## How long the camera holds on the place once the question mark is off it.
@export var presentation_hold_time: float = 1.4
## How many seconds the flight back to the piece takes.
@export var presentation_return_time: float = 1.0

var _graph: RunMapGraph
var _links_root: Node2D
var _sites_root: Node2D
var _token: Node2D
var _camera: Camera2D
var _markers: Dictionary = {}
var _lines: Array[Line2D] = []
var _hovered: int = -1
## Whether the map is taking choices. False while the piece is on the road - the
## map's choices "close" for the length of the ride and open again on arrival.
var _picking: bool = false
## Whether a presentation is flying the camera somewhere. The camera stops
## following the piece for the length of it and the map takes no choices.
var _presenting: bool = false
## The tween a presentation is running on, so a second request cannot start one
## over the top of the first.
var _presentation: Tween


func _ready() -> void:
	_links_root = get_node_or_null(links_container_path) as Node2D
	_sites_root = get_node_or_null(sites_container_path) as Node2D
	_token = get_node_or_null(token_path) as Node2D
	_camera = get_node_or_null(camera_path) as Camera2D
	if _camera != null:
		_camera.zoom = Vector2.ONE * map_zoom


func _physics_process(delta: float) -> void:
	if _presenting:
		return
	_follow_camera(delta)
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if _presenting:
		return
	if event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(zoom_step)
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(-zoom_step)
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			# Picked from where the press actually landed rather than from
			# wherever the cursor is standing this instant. In play the two are
			# the same point; they come apart for anything that sends a press
			# without a cursor behind it, and a map that only answered the
			# cursor could not be driven by one.
			_pick(_world_of(button.position))


## Builds the whole map from [param graph] and stands the piece where the graph
## says it is. Called once as the scene opens and again whenever a fresh map is
## generated, so nothing has to be torn down by the caller.
func build(graph: RunMapGraph) -> void:
	_graph = graph
	_clear()
	if _graph == null or _graph.is_empty():
		return

	for link: RunMapLink in _graph.links:
		_lines.append(_build_line(link))
	for site: RunMapSite in _graph.sites:
		_build_marker(site)

	place_token_at(_graph.current_id)
	_snap_camera()
	refresh()


## Re-dresses every point and road against the graph as it now stands - which
## point the piece is on, which have been revealed, which roads are this turn's
## choices. Called after every arrival, and after anything that turns a point
## over.
func refresh() -> void:
	if _graph == null:
		return
	var choices := _graph.neighbours_of(_graph.current_id)

	for site: RunMapSite in _graph.sites:
		var marker: RunMapSiteMarker = _markers.get(site.id)
		if marker == null:
			continue
		marker.apply(site, _kind_for(site), _picking and choices.has(site.id),
			site.id == _graph.current_id)

	_paint_lines()


## Whether the map is currently taking a choice.
func is_picking() -> bool:
	return _picking


## Opens or closes the map's choices. Closed, no point is haloed and a click
## does nothing - what the map does for the length of a ride.
func set_picking(picking: bool) -> void:
	if _picking == picking:
		return
	_picking = picking
	if not picking:
		_set_hovered(-1)
	refresh()


## Puts the piece exactly on a point.
func place_token_at(site_id: int) -> void:
	var site := _graph.get_site(site_id) if _graph != null else null
	if site == null or _token == null:
		return
	_token.position = site.position


## Puts the piece [param fraction] of the way along a road, from
## [param from_id]'s end towards the other. What [RunMapTravel] calls on every
## tick, so the piece advances by an equal share of the road each time.
func place_token_on(link: RunMapLink, from_id: int, fraction: float) -> void:
	if _graph == null or link == null or _token == null:
		return
	var from := _graph.get_site(from_id)
	var to := _graph.get_site(link.other_end(from_id))
	if from == null or to == null:
		return
	_token.position = from.position.lerp(to.position, clampf(fraction, 0.0, 1.0))


## The graph being drawn, for a panel or a readout that wants to ask it
## something. Null in a scene opened on its own before anything has built it.
func get_graph() -> RunMapGraph:
	return _graph


## What a point is called, or empty for one the player has not learned and for
## one whose kind was authored without a name. [b]The same fog rule the art
## follows[/b], asked of the same authored kinds, so a readout and the map can
## never disagree about whether something is known.
func display_name_of(site_id: int) -> String:
	if _graph == null:
		return ""
	var site := _graph.get_site(site_id)
	if site == null or not site.revealed:
		return ""
	var kind := _kind_for(site)
	return "" if kind == null else kind.display_name


## What a point will be called once it is known, fog or no fog. [b]What
## something telling the player where a place is has to ask[/b], since the
## telling is the thing that lifts the fog - see [RunMapSaloonInformation].
## Nothing that merely draws the map may use this.
func true_name_of(site_id: int) -> String:
	var kind := _true_kind_of(site_id)
	return "" if kind == null else kind.display_name


## Whether clicking [param site_id] while the piece is standing on it walks back
## in. Its authored kind's own answer - see [member RunMapSiteKind.re_enterable].
func can_re_enter(site_id: int) -> bool:
	var kind := _true_kind_of(site_id)
	return kind != null and kind.re_enterable


## Whether learning where [param site_id] is deserves the camera being flown out
## to it - see [method present_site] and
## [member RunMapSiteKind.presented_when_revealed].
func presented_when_revealed(site_id: int) -> bool:
	var kind := _true_kind_of(site_id)
	return kind != null and kind.presented_when_revealed


## The road from where the piece is standing to [param site_id], or null when
## there is none - which includes the point the piece is standing on itself.
func link_to(site_id: int) -> RunMapLink:
	if _graph == null:
		return null
	return _graph.find_link(_graph.current_id, site_id)


# --- Pointing a place out -------------------------------------------------------

## Whether the camera is currently away from the piece showing the player
## something.
func is_presenting() -> bool:
	return _presenting


## Flies the camera out to [param site_id], frames it close while the question
## mark comes off it, holds, and comes back to the piece. [b]The piece does not
## move and no day cycle is spent[/b]: this is the map showing the player
## something they have just been told, not a journey.
##
## [b]The point is turned over at the far end of the flight, not before[/b] - so
## the marker is watched changing rather than found already changed - and
## [signal presentation_revealed] fires at that instant for whatever has to
## write the map down. The map's choices are closed for the length of it and
## restored to however they were found, so a presentation played on the way out
## of a saloon hands the roads back exactly as it got them.
func present_site(site_id: int) -> void:
	if _presenting or _graph == null or _camera == null or _token == null:
		return
	var site := _graph.get_site(site_id)
	if site == null:
		return

	var was_picking := _picking
	set_picking(false)
	_presenting = true
	presentation_started.emit(site_id)
	if _presentation != null and _presentation.is_valid():
		_presentation.kill()

	var home := _wanted_camera_position()
	var home_zoom := Vector2.ONE * map_zoom
	var close_zoom := Vector2.ONE * maxf(
		map_zoom * maxf(presentation_zoom_scale, 1.0), 0.01)

	_presentation = create_tween()
	_presentation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation.tween_property(_camera, ^"position", site.position,
		maxf(presentation_travel_time, 0.01))
	_presentation.parallel().tween_property(_camera, ^"zoom", close_zoom,
		maxf(presentation_travel_time, 0.01))
	_presentation.tween_callback(_on_presentation_arrived.bind(site_id))
	_presentation.tween_interval(maxf(presentation_hold_time, 0.0))
	_presentation.tween_property(_camera, ^"position", home,
		maxf(presentation_return_time, 0.01))
	_presentation.parallel().tween_property(_camera, ^"zoom", home_zoom,
		maxf(presentation_return_time, 0.01))
	_presentation.tween_callback(_on_presentation_done.bind(site_id, was_picking))


func _on_presentation_arrived(site_id: int) -> void:
	if _graph != null:
		_graph.reveal(site_id)
	refresh()
	presentation_revealed.emit(site_id)


func _on_presentation_done(site_id: int, was_picking: bool) -> void:
	_presenting = false
	_presentation = null
	if _camera != null:
		_camera.zoom = Vector2.ONE * map_zoom
	set_picking(was_picking)
	presentation_finished.emit(site_id)


# --- Building ------------------------------------------------------------------

func _clear() -> void:
	for line: Line2D in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	for marker: Variant in _markers.values():
		if is_instance_valid(marker):
			(marker as Node).queue_free()
	_markers.clear()
	_hovered = -1


func _build_line(link: RunMapLink) -> Line2D:
	var line := Line2D.new()
	line.width = link_width
	line.texture = link_texture
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	# Tiling a line's texture means sampling past the end of it, so the repeat
	# has to be switched on here: left at the project default the sampler clamps
	# instead, smearing the dash's own trailing transparency down the whole road
	# and drawing nothing at all.
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = PackedVector2Array([
		_graph.get_site(link.from_id).position,
		_graph.get_site(link.to_id).position])
	if _links_root != null:
		_links_root.add_child(line)
	else:
		add_child(line)
	return line


func _build_marker(site: RunMapSite) -> void:
	if site_scene == null:
		return
	var marker := site_scene.instantiate() as RunMapSiteMarker
	if marker == null:
		return
	if _sites_root != null:
		_sites_root.add_child(marker)
	else:
		add_child(marker)
	marker.apply(site, _kind_for(site), false, site.id == _graph.current_id)
	_markers[site.id] = marker


## The art a site is drawn with: its own kind once the player has learned what is
## there, and the map's fog entry until then.
func _kind_for(site: RunMapSite) -> RunMapSiteKind:
	return _kind_named(site.kind if site.revealed else fog_kind)


## The entry a site's own handle names, whether or not the player has learned
## it. Only for questions about what a place [i]is[/i] - never for drawing one.
func _true_kind_of(site_id: int) -> RunMapSiteKind:
	if _graph == null:
		return null
	var site := _graph.get_site(site_id)
	return null if site == null else _kind_named(site.kind)


func _kind_named(handle: StringName) -> RunMapSiteKind:
	var fallback: RunMapSiteKind = null
	for kind: RunMapSiteKind in site_kinds:
		if kind == null:
			continue
		if kind.kind == handle:
			return kind
		if kind.is_fallback and fallback == null:
			fallback = kind
	return fallback


func _paint_lines() -> void:
	if _graph == null:
		return
	var current := _graph.current_id
	for index: int in range(_lines.size()):
		var line := _lines[index]
		var link := _graph.links[index]
		if not is_instance_valid(line):
			continue
		line.default_color = _color_for(link, current)


func _color_for(link: RunMapLink, current: int) -> Color:
	if _hovered >= 0 and link.joins(current, _hovered):
		return link_hover_color
	if _picking and link.touches(current):
		return link_choice_color
	var a := _graph.get_site(link.from_id)
	var b := _graph.get_site(link.to_id)
	if a != null and b != null and a.visited and b.visited:
		return link_taken_color
	return link_color


# --- Picking -------------------------------------------------------------------

func _update_hover() -> void:
	if not _picking or _graph == null:
		return
	_set_hovered(_site_at(get_global_mouse_position()))


## Which point is under [param at], in map space, or -1 for none. [b]Every
## point, not only the ones that can be ridden to[/b]: the mouse resting on a
## place is how the player asks what it is called, and that question is worth
## answering about a point two rows away as much as about a road out of here.
## What a click on the point then does is [method _pick]'s to decide.
func _site_at(at: Vector2) -> int:
	if _graph == null:
		return -1
	var found := -1
	var best := INF
	for site: RunMapSite in _graph.sites:
		var marker: RunMapSiteMarker = _markers.get(site.id)
		if marker == null or not marker.covers(at):
			continue
		var distance := marker.position.distance_to(at)
		if distance < best:
			best = distance
			found = site.id
	return found


## A point on the screen, in the map's own space.
func _world_of(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _set_hovered(site_id: int) -> void:
	if _hovered == site_id:
		return
	var was: RunMapSiteMarker = _markers.get(_hovered)
	if was != null:
		was.set_hovered(false)
	_hovered = site_id
	var now: RunMapSiteMarker = _markers.get(_hovered)
	if now != null:
		now.set_hovered(true)
	_paint_lines()
	hover_changed.emit(_hovered, link_to(_hovered) if _hovered >= 0 else null)


## The one click the map takes. A point with a road out of here is set out for;
## the point already underfoot is walked back into, if its kind allows it; and
## anything else - a place across the map the mouse happened to be resting on -
## is looked at and nothing more.
func _pick(at: Vector2) -> void:
	if not _picking:
		return
	var site_id := _site_at(at)
	if site_id < 0 or _graph == null:
		return
	if site_id == _graph.current_id:
		if can_re_enter(site_id):
			site_re_entered.emit(site_id)
		return
	var link := link_to(site_id)
	if link == null:
		return
	site_chosen.emit(site_id, link)


# --- Camera --------------------------------------------------------------------

func _zoom_by(amount: float) -> void:
	if _camera == null:
		return
	map_zoom = clampf(map_zoom + amount, min_zoom, max_zoom)
	_camera.zoom = Vector2.ONE * map_zoom


func _follow_camera(delta: float) -> void:
	if _camera == null or _token == null:
		return
	_camera.position = _camera.position.lerp(
		_wanted_camera_position(), 1.0 - exp(-maxf(camera_speed, 0.01) * delta))


func _snap_camera() -> void:
	if _camera == null:
		return
	_camera.position = _wanted_camera_position()


## The piece, kept inside the map rather than followed off the end of it: the
## camera stops short so the boss's end and the start's end each stay framed
## against the map instead of sitting in the middle of empty ground.
func _wanted_camera_position() -> Vector2:
	if _token == null:
		return Vector2.ZERO
	if _graph == null or _camera == null:
		return _token.position
	var shown := get_viewport_rect().size / maxf(map_zoom, 0.01)
	var box := _graph.bounds().grow(maxf(camera_margin, 0.0))
	var at := _token.position + Vector2(camera_lead, 0.0)
	if box.size.x > shown.x:
		at.x = clampf(at.x, box.position.x + shown.x * 0.5, box.end.x - shown.x * 0.5)
	else:
		at.x = box.get_center().x
	if box.size.y > shown.y:
		at.y = clampf(at.y, box.position.y + shown.y * 0.5, box.end.y - shown.y * 0.5)
	else:
		at.y = box.get_center().y
	return at
