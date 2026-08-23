class_name CloudShadows
extends Node2D
## The shadows of clouds nobody can see, crossing the desert.
##
## [b]Purely weather.[/b] There is no collision here, no area, no input handling
## and nothing any other system can ask this about: a cloud shadow is a sprite
## drifting across the ground and that is the whole of it. It cannot block a click
## because a [Sprite2D] has no notion of one, it cannot block the player because it
## is on no collision layer, and it cannot affect a prop or an enemy because
## nothing about it is ever read.
##
## [b]They come and go rather than being placed.[/b] One is started every so often
## - see [member spawn_interval] - just off the windward edge of whatever the
## camera can currently see, drifts across at [member drift_speed], and is dropped
## once it is clear of the far edge. So the sky is busy at times and empty at
## others without any of that being authored, and the desert can be any size
## without a cloud ever being placed outside it.
##
## [b]The screen is asked, not assumed.[/b] Where a cloud starts and where it is
## finished is worked out from the live camera's own visible rectangle, so the
## effect follows every zoom the game does - the shotgun's closer view, a boss
## introduction - without a screen coordinate written down anywhere here.
##
## Everything a cloud is is rolled per cloud from a range: which drawing, how
## large, how faint, how fast. Adding a fifth cloud drawing is dropping a PNG into
## [member textures].

## The drawings a cloud may be. One is picked at random per cloud, so adding a
## variant is dropping a PNG in here and nothing else.
@export var textures: Array[Texture2D] = []
## Whether clouds are made at all. Off leaves a clear sky, for measuring what they
## cost or for a map that has none.
@export var enabled: bool = true

@export_group("Look")
## What a cloud shadow is tinted. Dark and warm rather than grey, because it is a
## patch of desert with less sun on it and not a grey object lying on the sand.
@export var shadow_colour := Color(0.25, 0.13, 0.05)
## How faint they are. The range is rolled per cloud, so a sky has heavier and
## lighter ones in it at once rather than one repeated opacity.
@export var opacity_range := Vector2(0.07, 0.16)
## How large, as a multiplier on the drawing's own size. Rolled per cloud.
@export var scale_range := Vector2(1.6, 3.4)
## Layer they are drawn on. Above the ground and the marks on it, below the
## scenery and everybody standing on it - a shadow lies on the sand, it does not
## lie on a cactus.
@export var shadow_z_index: int = -9

@export_group("Drift")
## How fast they cross, in pixels per second, rolled per cloud. Slow on purpose:
## the effect is meant to be noticed after the fact rather than watched.
@export var drift_speed := Vector2(11.0, 22.0)
## Which way they go, as a direction. Right, as the weather in this desert runs. It
## is normalised, so any vector works and only its direction matters.
@export var drift_direction := Vector2.RIGHT
## How far a cloud drifts vertically for every pixel it drifts across, rolled per
## cloud. A little, so the sky is not a conveyor belt.
@export var vertical_drift := Vector2(-0.06, 0.06)

@export_group("Weather")
## How long between one cloud being started and the next, in seconds. Rolled fresh
## each time, so they arrive in ones and threes rather than on a metronome.
@export var spawn_interval := Vector2(6.0, 20.0)
## How many may be crossing at once. The ceiling on how busy the sky can get.
@export var max_active: int = 4
## How many are already crossing when the round begins, so the first minute of a
## round is not a conspicuously clear sky.
@export var initial_clouds: int = 2
## How far beyond the edge of the screen a cloud is started and finished, as a
## fraction of the screen's width. Enough that neither end is ever seen happening.
@export var offscreen_margin: float = 0.6

var _next: float = 0.0
var _clouds: Array[Sprite2D] = []


func _ready() -> void:
	if not enabled:
		set_process(false)
		return

	_next = randf_range(minf(spawn_interval.x, spawn_interval.y), maxf(spawn_interval.x, spawn_interval.y))
	for i: int in maxi(initial_clouds, 0):
		# Started already part way across, so the round does not open with a row of
		# clouds entering from the same edge together.
		_spawn(randf())


func _process(delta: float) -> void:
	_advance_clouds(delta)

	_next -= delta
	if _next > 0.0:
		return
	_next = randf_range(
		minf(spawn_interval.x, spawn_interval.y), maxf(spawn_interval.x, spawn_interval.y))
	_spawn(0.0)


## How many are crossing right now. For a readout, and for a test.
func get_active_count() -> int:
	return _clouds.size()


## Moves every cloud along and drops the ones that have finished crossing.
func _advance_clouds(delta: float) -> void:
	if _clouds.is_empty():
		return

	var view := _view_rect()
	var margin := view.size.x * maxf(offscreen_margin, 0.0)
	var live: Array[Sprite2D] = []
	for cloud: Sprite2D in _clouds:
		if not is_instance_valid(cloud):
			continue
		cloud.global_position += cloud.get_meta(&"velocity", Vector2.ZERO) as Vector2 * delta
		# Measured against the direction of travel rather than against "the right
		# edge", so a map that blows its weather the other way needs nothing here
		# changed.
		var along := (cloud.global_position - view.get_center()).dot(drift_direction.normalized())
		if along > view.size.length() * 0.5 + margin:
			cloud.queue_free()
			continue
		live.append(cloud)
	_clouds = live


## Starts one cloud. [param across] is how far over the screen it begins - 0 is
## just off the windward edge, 1 is just short of the far one - which is what lets
## the opening sky be populated without every cloud entering from the same place.
func _spawn(across: float) -> void:
	if textures.is_empty() or _clouds.size() >= maxi(max_active, 0):
		return

	var texture := textures[randi() % textures.size()]
	if texture == null:
		return

	var view := _view_rect()
	var heading := drift_direction.normalized()
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	var margin := view.size.x * maxf(offscreen_margin, 0.0)
	var span := view.size.length() + margin * 2.0

	var cloud := Sprite2D.new()
	cloud.texture = texture
	cloud.z_index = shadow_z_index
	cloud.z_as_relative = false
	# It must never sort against the scenery: a cloud shadow is on the ground the
	# whole way across, whatever its own y happens to be as it passes a cactus.
	cloud.y_sort_enabled = false

	var size := randf_range(minf(scale_range.x, scale_range.y), maxf(scale_range.x, scale_range.y))
	cloud.scale = Vector2(size, size)

	var tint := shadow_colour
	tint.a = randf_range(minf(opacity_range.x, opacity_range.y), maxf(opacity_range.x, opacity_range.y))
	cloud.modulate = tint

	# Across the direction of travel, so a cloud can begin anywhere on the edge it
	# is coming in over rather than always at the middle of it.
	var sideways := heading.orthogonal()
	var start := view.get_center() \
		- heading * (span * 0.5 - span * clampf(across, 0.0, 1.0)) \
		+ sideways * randf_range(-view.size.length() * 0.5, view.size.length() * 0.5)

	var speed := randf_range(minf(drift_speed.x, drift_speed.y), maxf(drift_speed.x, drift_speed.y))
	var sink := randf_range(minf(vertical_drift.x, vertical_drift.y), maxf(vertical_drift.x, vertical_drift.y))
	cloud.set_meta(&"velocity", (heading + Vector2(0.0, sink)).normalized() * speed)

	add_child(cloud)
	cloud.global_position = start
	_clouds.append(cloud)


## What the camera can currently see, in world coordinates.
##
## Taken from the live camera rather than from a rectangle of our own, so the
## weather follows every zoom and every place the view is taken to. A scene with no
## camera at all falls back to the viewport's own size around this node, which is
## enough for a cloud to be started and finished in an editor preview.
func _view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if camera == null:
		return Rect2(global_position - size * 0.5, size)

	var zoom := camera.zoom
	size /= Vector2(maxf(zoom.x, 0.01), maxf(zoom.y, 0.01))
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
