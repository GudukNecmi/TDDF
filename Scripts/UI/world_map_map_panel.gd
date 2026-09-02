class_name WorldMapMapPanel
extends Control
## The MAP tab of [WorldMapOverlayMenu], and what M opens directly - rule 27
## of the run inventory phase's "show the actual World Map state... do not
## create a duplicate map simulation".
##
## [b]It is [WorldMapMinimap]'s own technique, not a second one.[/b] A
## [SubViewport] holding a [Camera2D] explicitly pointed at the main
## viewport's own [World2D] - see [method Node._ready] - is a second camera on
## the exact running scene the minimap already points one at: the same
## terrain, the same [WorldMapLocation] markers already obeying
## [WorldMapFog], the same [WorldBandit]s already hidden or shown by their own
## fog check. Nothing here re-reads fog, region or bandit state by hand, and
## nothing here is a copy of [WorldMapMinimap]'s script - it is a second,
## larger instance of the identical idea, built directly rather than by
## subclassing, since the minimap's own script ties its visibility to being on
## screen at all times rather than to a tab being the one currently open.
##
## The camera follows the player exactly as the minimap's does, simply pulled
## back much further - "current player position" is always the middle of the
## panel, with far more of the roads, the discovered locations and the region
## layout around it in view at once.

@export var body_group: StringName = &"player"
## World units of radius shown around the player. Deliberately much larger
## than [member WorldMapMinimap.view_radius], so a look at the whole map's
## layout is the point rather than a glance at what is nearby.
@export var view_radius: float = 2600.0

var _viewport: SubViewport
var _camera: Camera2D
var _player: Node2D


func _ready() -> void:
	_build_frame()


func _build_frame() -> void:
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(container)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.size = Vector2i(1024, 640)
	container.add_child(_viewport)

	_camera = Camera2D.new()
	_camera.enabled = true
	_viewport.add_child(_camera)

	if _viewport != null:
		_viewport.world_2d = get_viewport().world_2d
	resized.connect(_apply_zoom)


## Called by [WorldMapOverlayMenu] each time the MAP tab becomes current, so
## the viewport starts pointed at the player immediately rather than wherever
## the camera last was.
func refresh() -> void:
	_apply_zoom()
	_follow_player()


func _process(_delta: float) -> void:
	if not visible:
		return
	_follow_player()


func _follow_player() -> void:
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
