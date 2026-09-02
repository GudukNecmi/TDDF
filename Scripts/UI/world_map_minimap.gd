class_name WorldMapMinimap
extends Control
## The World Map's minimap - a second camera pointed at the exact same
## running scene [WorldMapFogOverlay] paints, not a duplicate simulation of
## it. [member _camera] sits inside a [SubViewport] explicitly pointed at
## the main viewport's own [World2D] - see [method _ready] - so every
## terrain sprite, [WorldMapLocationMarker] and [WorldBandit] it shows is
## the very node the main camera renders - already obeying [WorldMapFog],
## already hidden or shown by the same [method WorldBandit._update_fog_visibility]
## check. Nothing here re-reads fog, region or bandit state by hand; the
## only thing this script owns is where the little camera points and how
## zoomed out it is.
##
## [b]Sharing the World2D takes one explicit line.[/b] A [SubViewport] does
## not inherit its parent's [World2D] just by being nested under it - each
## one is handed its own, empty [World2D] on creation, which renders as a
## flat, featureless viewport with nothing in it. [method Node._ready]
## points [member _viewport]'s at [method Viewport.world_2d] read off this
## control's own [method Node.get_viewport] the moment it enters the tree,
## which is what actually makes this a second camera on the real world
## rather than a window onto an empty one.
##
## [b]Gated the same way [code]world_map_debug_readout.gd[/code] is, and
## for the same reason.[/b] [code]WorldMap[/code] is a permanent sibling of
## the base and the arena, never rebuilt or reloaded - so this control is
## still sitting in the tree, under its own always-live [CanvasLayer],
## long after the player has left the World Map. A [CanvasLayer] draws to
## screen space regardless of where the camera is pointed, unlike
## [WorldMapFogOverlay]'s world-space rectangles the camera simply isn't
## aimed at elsewhere, so nothing stops this from showing over the base or
## the arena except asking the same [WorldZone] [method DebugReadout] asks.

@export var body_group: StringName = &"player"
## World units of radius shown around the player. Larger reads more of the
## map at a smaller scale.
@export var view_radius: float = 1400.0
@export var viewport_path: NodePath = ^"Frame/ViewportContainer/Viewport"
@export var camera_path: NodePath = ^"Frame/ViewportContainer/Viewport/Camera"
## The World Map's own [WorldZone], asked whether the player is inside it
## so this never draws over anywhere else in the game.
@export var zone_id: StringName = &"world_map"

@onready var _viewport: SubViewport = get_node_or_null(viewport_path) as SubViewport
@onready var _camera: Camera2D = get_node_or_null(camera_path) as Camera2D

var _player: Node2D


func _ready() -> void:
	if _viewport != null:
		_viewport.world_2d = get_viewport().world_2d
	_apply_zoom()
	resized.connect(_apply_zoom)


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	if _player != null and _camera != null:
		_camera.global_position = _player.global_position


func _apply_zoom() -> void:
	if _viewport == null or _camera == null:
		return
	var size := _viewport.size
	if size.x <= 0 or size.y <= 0 or view_radius <= 0.0:
		return
	var diameter := view_radius * 2.0
	_camera.zoom = Vector2(size.x / diameter, size.y / diameter)
