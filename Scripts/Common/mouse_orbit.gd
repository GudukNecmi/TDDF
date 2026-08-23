class_name MouseOrbit
extends Node
## Watches the mouse circle a point and reports how far round it has got.
##
## This is a [b]gesture[/b], not a distance. It exists because the lever action's
## reload is the player physically winding the cursor around their character, and
## the difference between that and simply flinging the mouse across the screen has
## to be real - so what is measured is the *angle* from the pivot to the cursor,
## accumulated frame by frame, and nothing else. Sweeping the mouse a thousand
## pixels in a straight line past the character turns that angle by a few dozen
## degrees at most and can never complete a turn.
##
## [b]Three guards keep it honest[/b], and each one rules out a specific way of
## cheating it:
##
##   * [member min_radius] - the cursor must be a real distance out from the
##     pivot. Close to the centre the angle is meaningless: a pixel of jitter
##     swings it wildly, so a cursor resting on the character could spin up a full
##     turn without moving. Inside this radius nothing accumulates at all.
##   * [member max_step_degrees] - one frame may only contribute a believable
##     amount of turn. Dragging the cursor *through* the character and out the far
##     side flips the angle by nearly 180 degrees in a single frame; so does the
##     pointer being warped. Neither is a hand going round anything, so a step this
##     big is discarded rather than counted, and the gesture picks up from the new
##     angle.
##   * [member reverse_tolerance_degrees] - the turn has to keep going the same
##     way. Wiggling back and forth accumulates nothing, because the first real
##     backtrack past this tolerance throws the whole attempt away and starts a
##     fresh one in the new direction.
##
## On top of those, [member idle_reset_time] drops a half-finished turn that has
## been abandoned, so the player cannot leave 300 degrees banked for later.
##
## It reports [signal progress_changed] continuously - which is what a tension
## effect part way round hangs off - and [signal completed] once, at which point it
## resets and the next turn starts from nothing.

## Emitted every time the accumulated turn changes, with how far round it is in
## degrees and that as a 0..1 fraction of [member required_degrees].
signal progress_changed(degrees: float, ratio: float)
## Emitted the moment a full turn is finished. [param clockwise] is which way it
## went, in screen terms - positive angles turn clockwise in Godot's 2D space.
signal completed(clockwise: bool)
## Emitted when a turn that was under way is thrown away - backtracked, abandoned
## or interrupted - so anything showing tension can put itself back.
signal cancelled()

## The node the cursor must go round. Left empty, the owner's own position is
## used, which for a weapon means the weapon itself.
@export var pivot_path: NodePath
## Whether the gesture is watched at all. A weapon turns this off while the
## gesture would mean nothing - stowed, or already reloading - so an idle sweep of
## the mouse cannot bank progress for later.
@export var active: bool = true:
	set(value):
		active = value
		if not active:
			_reset(true)

@export_group("Gesture")
## How far round the cursor must travel for one full gesture. The lever action's
## reload is a little short of a complete circle, which is deliberate: a full 360
## asks the player to get back to exactly where they started, and the last few
## degrees of that are all frustration.
@export var required_degrees: float = 320.0
## How far out from the pivot the cursor must be, in pixels, for its angle to
## count at all.
##
## [b]This is the guard against spinning on the spot.[/b] The angle to a point one
## pixel from the pivot is noise; the angle to one a hundred pixels out is a real
## direction. Raising it forces a wider, more deliberate circle.
@export var min_radius: float = 55.0
## The most one frame may contribute, in degrees.
##
## [b]This is the guard against crossing the character.[/b] A hand winding the
## cursor round at speed moves it maybe twenty degrees in a frame; a cursor
## dragged through the pivot and out the other side jumps by up to a hundred and
## eighty. Anything above this is not a turn, so it is dropped.
@export var max_step_degrees: float = 45.0
## How far the cursor may double back before the attempt is abandoned, in degrees.
## Small deliberate corrections survive; genuinely reversing does not.
@export var reverse_tolerance_degrees: float = 30.0
## How long a part-finished turn survives without progress, in seconds. 0 keeps it
## forever.
@export var idle_reset_time: float = 0.75

@onready var _pivot: Node2D = get_node_or_null(pivot_path) as Node2D

## Signed accumulation, in degrees: positive is clockwise. Its sign is the
## direction the current attempt committed to.
var _turned: float = 0.0
var _previous_angle: float = 0.0
var _has_angle: bool = false
var _idle: float = 0.0


func _ready() -> void:
	if _pivot == null:
		_pivot = get_parent() as Node2D


## How far round the current attempt has got, in degrees, always positive.
func get_progress_degrees() -> float:
	return absf(_turned)


## The same as a 0..1 fraction of a full gesture, for anything scaling an effect
## with it.
func get_progress_ratio() -> float:
	if required_degrees <= 0.0:
		return 0.0
	return clampf(absf(_turned) / required_degrees, 0.0, 1.0)


## Points the gesture at a different centre.
##
## For a watcher whose pivot is not known when the scene is authored - a weapon
## built into the world at run time knows which body it follows, and hands that
## body over here, rather than this node carrying a path into a scene it was never
## part of.
func set_pivot(pivot: Node2D) -> void:
	if pivot == _pivot:
		return
	_pivot = pivot
	# The old centre's angle means nothing about the new one, so it is dropped
	# rather than counted as a jump between the two.
	_reset(true)


## Throws away whatever has been accumulated. Called by a weapon that has just
## used a gesture, or that has stopped caring about one.
func reset() -> void:
	_reset(true)


func _process(delta: float) -> void:
	if not active or _pivot == null or not _pivot.is_inside_tree():
		return

	var to_cursor := _pivot.get_global_mouse_position() - _pivot.global_position
	feed(to_cursor.angle(), to_cursor.length(), delta)


## One reading of where the cursor is, in radians around the pivot and pixels out
## from it.
##
## The whole gesture is decided here and [method Node._process] only supplies the
## numbers, which keeps the rule and the input source apart: the same
## accumulation can be driven from a recorded sweep or a right stick without any
## of the guards being written twice.
func feed(angle: float, radius: float, delta: float) -> void:
	# Too close in for an angle to mean anything. The previous angle is dropped as
	# well, so coming back out does not count the jump across the middle.
	if radius < min_radius:
		_has_angle = false
		_tick_idle(delta)
		return

	if not _has_angle:
		_previous_angle = angle
		_has_angle = true
		_tick_idle(delta)
		return

	var step := rad_to_deg(angle_difference(_previous_angle, angle))
	_previous_angle = angle

	# A jump no hand could have made: the cursor crossed the pivot, or was warped.
	# Dropped rather than counted, and the gesture carries on from here.
	if absf(step) > max_step_degrees:
		_tick_idle(delta)
		return

	if is_zero_approx(step):
		_tick_idle(delta)
		return

	_accumulate(step)
	_idle = 0.0


## Adds one frame of turn, and decides whether it belongs to the attempt already
## under way or starts a new one.
func _accumulate(step: float) -> void:
	# Going back the way it came. Small corrections are absorbed - the accumulation
	# simply goes down - but a real reversal past the tolerance abandons the
	# attempt and begins again in the new direction, so wiggling banks nothing.
	if not is_zero_approx(_turned) and signf(step) != signf(_turned):
		if absf(step) > reverse_tolerance_degrees or absf(_turned) < absf(step):
			_reset(true)
			_turned = step
			progress_changed.emit(get_progress_degrees(), get_progress_ratio())
			return

	_turned += step
	progress_changed.emit(get_progress_degrees(), get_progress_ratio())

	if absf(_turned) >= required_degrees:
		var clockwise := _turned > 0.0
		# Reset before the announcement, so anything that reacts by starting
		# another gesture is not immediately cleared by this one finishing.
		_reset(false)
		completed.emit(clockwise)


## A turn nobody is continuing is not a turn. Without this the player could wind
## up 300 degrees, walk away, and finish the reload minutes later with a flick.
func _tick_idle(delta: float) -> void:
	if idle_reset_time <= 0.0 or is_zero_approx(_turned):
		return
	_idle += delta
	if _idle >= idle_reset_time:
		_reset(true)


func _reset(report: bool) -> void:
	var had_progress := not is_zero_approx(_turned)
	_turned = 0.0
	_idle = 0.0
	_has_angle = false
	if report and had_progress:
		progress_changed.emit(0.0, 0.0)
		cancelled.emit()
