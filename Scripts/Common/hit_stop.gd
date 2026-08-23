class_name HitStop
extends Node
## The whole game holding still for a fraction of a second on an impact.
##
## [b]This is not [WorldSlowdown].[/b] That one scales how fast *characters* walk
## and deliberately leaves everything else running, because it plays underneath a
## title card for seconds at a time. This is the opposite thing: a hit landing so
## hard that the frame itself stops - every animation, every projectile, every
## tween - for a few hundredths of a second, and then it is over. Nothing about
## the two overlaps, and using either for the other's job would feel wrong.
##
## It works by dropping [member Engine.time_scale] and putting it back, which is
## exactly the sledgehammer [WorldSlowdown] refuses to use and exactly right here:
## a hit stop is *meant* to take the whole world with it, sound and effects
## included, and it is over before anything can drift.
##
## [b]It always ends.[/b] The recovery is a real-time timer running independently
## of the scale it just changed, and the scale it returns to is the one that was
## there when it started, so back-to-back hits cannot stack into slow motion and a
## hit landing during a stop simply refreshes the one already running.
##
## Found by group rather than by path, the way [ScreenFlash] and
## [CameraController] are, so anything anywhere can ask for one:
## [code]HitStop.request(self, 0.05)[/code].

## Group used by [method get_active].
const GROUP := &"hit_stop"

## Whether stops are played at all. Off makes every request do nothing, which is
## how the effect is switched off wholesale without callers being touched.
@export var enabled: bool = true
## What the world's time scale drops to during a stop. 0 is a true freeze; a small
## fraction leaves everything crawling, which reads as heavier than a hard stop
## on very short durations.
@export_range(0.0, 1.0) var stopped_scale: float = 0.02
## Longest a single request may last, in real seconds. A guard rather than a
## tuning value: nothing should ever ask for a long stop, and this makes certain
## that a mistake cannot take the game away from the player.
@export var max_duration: float = 0.25

## When the current stop ends, on the real clock. Milliseconds since start-up, so
## it is untouched by the very time scale this is changing.
var _ends_at_msec: int = 0
var _restore_scale: float = 1.0


func _enter_tree() -> void:
	# Joined here rather than in `_ready`, so something that impacts on its own
	# first frame can still find it.
	add_to_group(GROUP)


func _ready() -> void:
	# Runs while the tree is paused, so a stop can never be left in place by a
	# menu opening on the frame it started.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## The hit stop in this world, or null when it has none - which every caller
## treats as "hit stops are switched off here".
static func get_active(from_node: Node) -> HitStop:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as HitStop


## Asks for a stop of [param duration] real seconds. Safe to call from anywhere
## and safe to call when there is no hit stop in the world.
static func request(from_node: Node, duration: float) -> void:
	var found := get_active(from_node)
	if found != null:
		found.stop(duration)


## Stops the world for [param duration] real seconds.
##
## Retriggering keeps the longer of the two rather than adding, so a coin struck
## in the middle of another impact cannot chain two stops into a stutter.
func stop(duration: float) -> void:
	if not enabled or duration <= 0.0:
		return

	if not is_stopping():
		# Captured only when starting from normal speed, so a stop beginning during
		# another one restores the world's real scale rather than the frozen one.
		_restore_scale = Engine.time_scale

	var ends := Time.get_ticks_msec() + int(minf(duration, max_duration) * 1000.0)
	_ends_at_msec = maxi(_ends_at_msec, ends)
	Engine.time_scale = stopped_scale
	set_process(true)


func is_stopping() -> bool:
	return _ends_at_msec > Time.get_ticks_msec()


## Timed off the real clock rather than off [param _delta], which is already
## multiplied by the scale this just changed - counting with that would make the
## stop last as long as the scale is small, which is to say forever.
func _process(_delta: float) -> void:
	if is_stopping():
		return

	Engine.time_scale = _restore_scale
	set_process(false)


## The world is going away with the scale still dropped - a scene rebuild during a
## stop, or the game closing. Put back rather than left, because the scale is
## global state and outlives every scene.
func _exit_tree() -> void:
	if is_stopping():
		Engine.time_scale = _restore_scale
		_ends_at_msec = 0
