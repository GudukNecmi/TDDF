class_name ScreenFade
extends ColorRect
## The black the game hides its transitions behind.
##
## Two things in the game move the player somewhere they must not be seen being
## moved to: the trip home after a death, and the rebuild of the world for the
## next round. Both are covered the same way - fade to black, do the thing, fade
## back - and both go through this one node rather than each growing an overlay
## of its own.
##
## The awkward half is the round transition, because the scene the fade lives in
## is the scene being rebuilt: fading out, reloading, and fading back in spans a
## node being freed and a different one taking its place. That is what
## [method request_fade_in_after_reload] is for. The request is held in a static,
## which belongs to the *class* rather than to any instance, so it survives the
## rebuild without a singleton to register or an autoload to add - and the next
## fade to enter the tree opens already black and takes itself off.
##
## Like [ScreenFlash] it is found by group rather than by path, so the death
## sequence on the player and the upgrade menu on the HUD can both reach it
## without either being wired to the other. It runs with
## [constant Node.PROCESS_MODE_ALWAYS] so a transition started from a paused menu
## still plays.

## Emitted once the screen is fully black.
signal faded_out
## Emitted once the screen is fully clear again.
signal faded_in

## Group used by [method get_active].
const GROUP := &"screen_fade"

## Colour the screen is covered with.
@export var fade_colour := Color(0, 0, 0)
## Default time a fade to black takes when a caller does not say.
@export var fade_out_time: float = 1.0
## Default time a fade back in takes when a caller does not say.
@export var fade_in_time: float = 1.0

## Carried across a scene rebuild: how long the fade that comes up on the other
## side should take, or below 0 for "no transition is in progress". Static
## deliberately - see the class notes.
static var _pending_fade_in: float = -1.0

var _tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(fade_colour.r, fade_colour.g, fade_colour.b, 0.0)
	visible = false

	# A rebuild that was asked for under cover opens already black and clears
	# itself, so the new scene's first frame is never seen assembling.
	if _pending_fade_in >= 0.0:
		var duration := _pending_fade_in
		_pending_fade_in = -1.0
		_set_alpha(1.0)
		fade_in(duration)


## The fade any system should talk to. Null means this scene has none, which
## every caller treats as "transitions are not covered", and every one of them
## still completes - the player simply sees the cut.
static func get_active(from_node: Node) -> ScreenFade:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as ScreenFade


## Asks whichever fade comes up after the next scene rebuild to open black and
## clear itself over [param duration]. Called before the reload, by whatever is
## doing the reloading.
static func request_fade_in_after_reload(duration: float) -> void:
	_pending_fade_in = maxf(duration, 0.0)


## Clears any pending request, so a transition that was abandoned cannot black
## out an unrelated scene later.
static func cancel_pending_fade_in() -> void:
	_pending_fade_in = -1.0


func is_black() -> bool:
	return visible and color.a >= 0.999


## Covers the screen. [param then] is called on the frame the screen is fully
## black, which is where the thing being hidden belongs - a teleport, a rebuild.
## A duration of 0 or less blacks out immediately and still calls back.
func fade_out(duration: float = -1.0, then: Callable = Callable()) -> void:
	var seconds := duration if duration >= 0.0 else fade_out_time
	_kill_tween()
	visible = true

	if seconds <= 0.0:
		_set_alpha(1.0)
		_finish_out(then)
		return

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_alpha, color.a, 1.0, seconds)
	_tween.tween_callback(_finish_out.bind(then))


## Takes the black back off. Hidden outright at the end, so a cleared screen is
## not composited over the game every frame.
func fade_in(duration: float = -1.0, then: Callable = Callable()) -> void:
	var seconds := duration if duration >= 0.0 else fade_in_time
	_kill_tween()
	visible = true

	if seconds <= 0.0:
		_set_alpha(0.0)
		_finish_in(then)
		return

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_alpha, color.a, 0.0, seconds)
	_tween.tween_callback(_finish_in.bind(then))


## Out, hold, and back in, with [param during] run while the screen is black.
## The whole of a covered transition in one call, for a caller that has nothing
## to do on the far side but carry on.
func fade_through(
	out_time: float = -1.0,
	hold: float = 0.0,
	in_time: float = -1.0,
	during: Callable = Callable()
) -> void:
	fade_out(out_time, func() -> void:
		if during.is_valid():
			during.call()
		if hold > 0.0:
			var wait := get_tree().create_timer(hold, true, false, true)
			wait.timeout.connect(fade_in.bind(in_time))
		else:
			fade_in(in_time))


## Drops the black immediately, for a scene reset or a debug key.
func clear() -> void:
	_kill_tween()
	_set_alpha(0.0)
	visible = false


func _set_alpha(value: float) -> void:
	color = Color(fade_colour.r, fade_colour.g, fade_colour.b, clampf(value, 0.0, 1.0))


func _finish_out(then: Callable) -> void:
	faded_out.emit()
	if then.is_valid():
		then.call()


func _finish_in(then: Callable) -> void:
	visible = false
	faded_in.emit()
	if then.is_valid():
		then.call()


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
