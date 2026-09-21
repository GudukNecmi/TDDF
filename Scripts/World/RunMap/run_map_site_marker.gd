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

## The picture of the place.
@export var icon_path: NodePath = ^"Icon"
## The ring drawn round a point the player may ride to next.
@export var halo_path: NodePath = ^"Halo"

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
## How much bigger the point itself is drawn while the mouse is over it.
@export_range(1.0, 2.0, 0.01) var hover_scale: float = 1.15
## How quickly the point settles into or out of that.
@export var hover_speed: float = 14.0
## What the piece stands on: how far the point is dimmed once it has been
## ridden through, so the route already taken reads as behind the player.
@export_range(0.0, 1.0, 0.01) var visited_dim: float = 0.55

## Which site on the graph this marker is - read back by [RunMapView] when the
## mouse picks one.
var site_id: int = -1

var _icon: Sprite2D
var _halo: Sprite2D
var _base_scale := Vector2.ONE
var _hovered: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	_icon = get_node_or_null(icon_path) as Sprite2D
	_halo = get_node_or_null(halo_path) as Sprite2D
	if _halo != null:
		_halo.visible = false


func _physics_process(delta: float) -> void:
	if _icon == null:
		return

	var wanted := _base_scale * (hover_scale if _hovered else 1.0)
	_icon.scale = _icon.scale.lerp(wanted, 1.0 - exp(-maxf(hover_speed, 0.01) * delta))

	if _halo != null and _halo.visible:
		_pulse += delta
		var period := maxf(halo_pulse_period, 0.05)
		var swell := 0.5 + 0.5 * sin(_pulse / period * TAU)
		_halo.scale = Vector2.ONE * lerpf(1.0, halo_pulse_scale, swell)


## Dresses the marker for one site. [param kind] is the entry the map authored
## for whatever the site currently reads as - the unknown point for anything the
## player has not learned - and [param reachable] is whether a road runs from
## where the piece is standing to here.
func apply(site: RunMapSite, kind: RunMapSiteKind, reachable: bool) -> void:
	site_id = site.id
	position = site.position

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
			_halo.scale = Vector2.ONE


## Whether the mouse, in map space, is over this point.
func covers(at: Vector2) -> bool:
	return position.distance_to(at) <= maxf(pick_radius, 1.0)


func set_hovered(hovered: bool) -> void:
	_hovered = hovered
