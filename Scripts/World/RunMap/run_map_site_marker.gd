class_name RunMapSiteMarker
extends Node2D
## One point on the run map, drawn.
##
## [b]It decides nothing.[/b] [RunMapView] owns the graph, works out which points
## may be ridden to and hands each marker its answer through [method apply]; this
## node only wears it. That split is what keeps the fog rule in one place: a
## marker is never asked whether it is revealed, it is told.
##
## [b]It knows no kinds.[/b] The picture and the name come in as a
## [RunMapSiteKind] the map itself authored, so the bandit, market, saloon and
## treasure points a later task adds reach the screen without this file changing.
##
## [b]Three rings, and only ever one of them at a time.[/b] A point may be
## somewhere the piece could ride to next, somewhere it has already been, or the
## place it is standing right now, and each of those is its own sprite authored
## in this marker's scene - so how each reads is a texture, a colour and a scale
## in the Inspector and there is not a colour in this file. Standing somewhere
## beats having been there, because the piece is on it now; being able to ride
## somewhere is drawn alongside either, because that is a different question.

## The picture of the place.
@export var icon_path: NodePath = ^"Icon"
## The ring drawn round a point the player may ride to next.
@export var halo_path: NodePath = ^"Halo"
## The ring drawn round a point the piece has already stood on.
@export var visited_ring_path: NodePath = ^"VisitedRing"
## The ring drawn round the point the piece is standing on now - the stronger of
## the two, since it is the one place a click does something other than set out.
@export var current_ring_path: NodePath = ^"CurrentRing"

@export_group("Feel")
## How far from this point a click still counts as clicking it, in map pixels.
## Generous on purpose: the map is zoomed out and a point is a target to be
## casually aimed at, not a pixel to be found - the same reasoning
## [member RunPortal.radius] is written with.
@export var pick_radius: float = 90.0
## How much bigger the halo swells at the top of its pulse.
@export_range(1.0, 2.0, 0.01) var halo_pulse_scale: float = 1.12
## How many seconds one full swell of the halo takes.
@export var halo_pulse_period: float = 1.4
## How much bigger the standing ring swells at the top of its own, slower pulse.
@export_range(1.0, 2.0, 0.01) var current_pulse_scale: float = 1.06
## How many seconds one full swell of the standing ring takes.
@export var current_pulse_period: float = 2.2
## How much bigger the point itself is drawn while the mouse is over it.
@export_range(1.0, 2.0, 0.01) var hover_scale: float = 1.15
## How quickly the point settles into or out of that.
@export var hover_speed: float = 14.0
## How closely the three rings follow the size of the picture they are drawn
## round. 1 - the default - means a place drawn half again as big wears a ring
## half again as big, so the boss and the bounty are not swallowed by their own
## art; 0 draws every ring at the size it was authored at, whatever it rings.
@export_range(0.0, 2.0, 0.01) var ring_follows_icon: float = 1.0
## What the piece stands on: how far the point is dimmed once it has been
## ridden through, so the route already taken reads as behind the player. The
## visited ring is what marks it; this only takes the edge off the picture, so
## it is kept light enough that the place is still legible.
@export_range(0.0, 1.0, 0.01) var visited_dim: float = 0.25

## Which site on the graph this marker is - read back by [RunMapView] when the
## mouse picks one.
var site_id: int = -1

var _icon: Sprite2D
var _halo: Sprite2D
var _visited_ring: Sprite2D
var _current_ring: Sprite2D
var _base_scale := Vector2.ONE
## The size each ring was authored at in the marker scene, kept so a ring can be
## grown to match a bigger picture without that growth compounding every time
## the marker is dressed again.
var _halo_authored := Vector2.ONE
var _visited_authored := Vector2.ONE
var _current_authored := Vector2.ONE
## The same three, grown to whatever the point is currently drawn at. The two
## that pulse swell from these rather than from Vector2.ONE.
var _halo_base := Vector2.ONE
var _current_base := Vector2.ONE
var _hovered: bool = false
var _pulse: float = 0.0
var _current_pulse: float = 0.0


func _ready() -> void:
	_icon = get_node_or_null(icon_path) as Sprite2D
	_halo = get_node_or_null(halo_path) as Sprite2D
	_visited_ring = get_node_or_null(visited_ring_path) as Sprite2D
	_current_ring = get_node_or_null(current_ring_path) as Sprite2D
	if _halo != null:
		_halo_authored = _halo.scale
		_halo_base = _halo_authored
		_halo.visible = false
	if _visited_ring != null:
		_visited_authored = _visited_ring.scale
		_visited_ring.visible = false
	if _current_ring != null:
		_current_authored = _current_ring.scale
		_current_base = _current_authored
		_current_ring.visible = false


func _physics_process(delta: float) -> void:
	if _icon == null:
		return

	var wanted := _base_scale * (hover_scale if _hovered else 1.0)
	_icon.scale = _icon.scale.lerp(wanted, 1.0 - exp(-maxf(hover_speed, 0.01) * delta))

	if _halo != null and _halo.visible:
		_pulse += delta
		_halo.scale = _halo_base * _swell(_pulse, halo_pulse_period, halo_pulse_scale)

	if _current_ring != null and _current_ring.visible:
		_current_pulse += delta
		_current_ring.scale = _current_base * _swell(
			_current_pulse, current_pulse_period, current_pulse_scale)


## Dresses the marker for one site. [param kind] is the entry the map authored
## for whatever the site currently reads as - the unknown point for anything the
## player has not learned - [param reachable] is whether a road runs from where
## the piece is standing to here, and [param standing] whether the piece is on
## this very point.
func apply(site: RunMapSite, kind: RunMapSiteKind, reachable: bool,
		standing: bool = false) -> void:
	site_id = site.id
	position = site.position

	# Every ring is grown to match the picture it is drawn round, so a place the
	# map draws half again as big does not swallow its own ring - see
	# [member ring_follows_icon].
	var drawn := 1.0 if kind == null else maxf(kind.icon_scale, 0.01)
	var ring := lerpf(1.0, drawn, ring_follows_icon)
	_halo_base = _halo_authored * ring
	_current_base = _current_authored * ring

	if _icon != null and kind != null:
		var art := kind.icon
		var tint := kind.tint
		if site.visited:
			if kind.visited_icon != null:
				art = kind.visited_icon
			tint = tint.darkened(clampf(visited_dim, 0.0, 1.0))
		_icon.texture = art
		_base_scale = Vector2.ONE * maxf(kind.icon_scale, 0.01)
		_icon.modulate = tint
		_icon.scale = _base_scale

	if _halo != null:
		_halo.visible = reachable
		if reachable:
			_pulse = 0.0
			_halo.scale = _halo_base

	if _current_ring != null:
		var was_standing := _current_ring.visible
		_current_ring.visible = standing
		if standing and not was_standing:
			_current_pulse = 0.0
			_current_ring.scale = _current_base

	if _visited_ring != null:
		_visited_ring.scale = _visited_authored * ring
		_visited_ring.visible = site.visited and not standing


## Whether the mouse, in map space, is over this point.
func covers(at: Vector2) -> bool:
	return position.distance_to(at) <= maxf(pick_radius, 1.0)


func set_hovered(hovered: bool) -> void:
	_hovered = hovered


func _swell(elapsed: float, period: float, peak: float) -> float:
	var span := maxf(period, 0.05)
	return lerpf(1.0, peak, 0.5 + 0.5 * sin(elapsed / span * TAU))
