class_name ProjectileTrail
extends Line2D
## A streak drawn behind whatever this is a child of.
##
## Drop it under a projectile - or anything else that moves - and it records where
## that thing has been, keeping the last [member trail_length] pixels of travel and
## dropping the rest. Nothing about it is specific to a bullet, so the same node
## streaks a thrown knife or a falling ember.
##
## [b]It draws in world space, not the projectile's.[/b] [member Node2D.top_level]
## is turned on, so this node ignores its parent's transform entirely and its
## points are plain global positions. That is what keeps the streak lying along the
## path actually flown: parented normally, a projectile that turned would swing its
## whole trail round with it, and one drawn at a fraction of its true scale would
## shrink the trail to nothing.
##
## What it looks like is not decided here. The width, the colour, the taper along
## its length and any glow material are the [Line2D]'s own inspector fields - so
## the streak is tuned where it is drawn, and this file owns only its geometry:
## how long it is and how finely it is recorded.

## How much travel the streak keeps behind it, in pixels. This is the length of
## the tail: raising it draws a longer streak, and nothing else about the
## projectile changes.
@export var trail_length: float = 110.0
## How far the source must move before another point is recorded, in pixels.
##
## The resolution of the streak. Small values follow a curving path exactly and
## cost more points; large ones are cheaper and cut corners. For something flying
## in a straight line it can be generous.
@export var point_spacing: float = 7.0
## Whether the tail is left behind when the projectile is freed, so a bullet that
## hits something does not take its streak with it in the same frame.
@export var lingers_after_source: bool = false
## How long that left-behind tail takes to fade, in seconds.
@export var linger_fade: float = 0.12

var _source: Node2D
var _last_point: Vector2
var _started: bool = false


func _ready() -> void:
	_source = get_parent() as Node2D
	# Points are global from here on, so nothing the source does to its own
	# transform can distort the streak.
	top_level = true
	clear_points()

	# [b]Deliberately no point is recorded here.[/b] A projectile is added to the
	# scene and only then moved to the muzzle, so at this moment the source is
	# still sitting at the world origin - a point recorded now would draw the
	# streak from the middle of the map to the barrel. The first point is taken on
	# the first physics tick instead, by which time the shot has been placed.
	if lingers_after_source and _source != null:
		_source.tree_exiting.connect(_on_source_leaving)


func _physics_process(_delta: float) -> void:
	if _source == null or not is_instance_valid(_source):
		return

	var here := _source.global_position
	if not _started:
		_last_point = here
		_start()
		return

	# A move longer than the whole streak is not flight, it is a teleport - the
	# source being placed, or warped. Starting again is the only honest answer:
	# joining the two ends would draw a line across everything in between.
	if here.distance_to(_last_point) > trail_length:
		clear_points()
		_started = false
		_last_point = here
		return

	if here.distance_to(_last_point) < point_spacing:
		# The head still follows every frame even when no new point is recorded,
		# so the streak stays attached to the projectile rather than lagging a
		# spacing behind it.
		set_point_position(0, here)
		return

	_last_point = here
	add_point(here, 0)
	_trim()


## Seeds the streak with a single point at the source, so the head exists before
## the first movement is recorded.
func _start() -> void:
	if _source == null:
		return
	_started = true
	add_point(_source.global_position)


## Drops points off the tail once the recorded path is longer than
## [member trail_length]. Measured along the path rather than as a straight line
## from the head, so a curving trail is the same length as a straight one.
func _trim() -> void:
	var kept := 0.0
	for i in range(1, get_point_count()):
		kept += get_point_position(i - 1).distance_to(get_point_position(i))
		if kept >= trail_length:
			for extra in range(get_point_count() - 1, i, -1):
				remove_point(extra)
			return


## The projectile has been spent. The streak is handed to the scene so it can fade
## where it was drawn instead of disappearing with the bullet.
func _on_source_leaving() -> void:
	if not is_inside_tree() or _source == null:
		return

	var container := get_tree().current_scene
	if container == null:
		return

	var here := global_position
	_source = null
	set_physics_process(false)
	call_deferred(&"_reparent_and_fade", container, here)


func _reparent_and_fade(container: Node, here: Vector2) -> void:
	if not is_instance_valid(container):
		queue_free()
		return

	reparent(container)
	global_position = here
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, maxf(linger_fade, 0.0001))
	tween.tween_callback(queue_free)
