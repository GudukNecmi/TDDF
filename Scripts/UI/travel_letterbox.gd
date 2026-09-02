class_name TravelLetterbox
extends Control
## The reusable cinematic bars used everywhere the game wants to frame a scene
## the way an old western picture would: one fixed black bar across the top,
## one across the bottom, drawn on the shared [RunHUD] canvas layer above every
## camera, zone and menu in the game.
##
## [b]One instance, every destination.[/b] Nothing about entering the Arena,
## the Saloon, the Market or anywhere else the World Map leads to gets its own
## copy of this - a caller anywhere in the game asks the one instance already
## in the scene for one of the four things it knows how to do:
## [method show_letterbox], [method hide_letterbox],
## [method play_loading_transition] and [method play_destination_reveal].
## Building a second destination's own bars and its own "Loading" word is
## exactly the duplication this exists to rule out.
##
## [b]It never touches a camera, a zone or a scene.[/b] The bars are pure UI
## on [RunHUD]'s own [CanvasLayer], sized and positioned in screen space -
## nothing here reads [CameraController], moves the player or knows what
## [WorldZone] the game is even in right now. [code]travel_letterbox_gate.gd[/code]
## is what listens for the World Map's own [WorldZone] crossing and turns that
## into [method show_letterbox] / [method hide_letterbox]; this file only ever
## answers the ask.
##
## [b]A scripted transition holds the wheel.[/b] [method play_loading_transition]
## makes [method is_transitioning] true the instant it is called, and nothing
## clears it until [method play_destination_reveal] has finished sliding the
## bars away. That matters because the World Map → Arena hand-off moves the
## player clean out of the World Map's own [WorldZone] rectangle before the
## reveal has even begun - see [code]travel_letterbox_gate.gd[/code]'s own
## doc - and a gate reacting to that crossing on its own would snap the bars
## away out from under a loading screen that is deliberately still holding
## them up.

## Emitted once [method play_destination_reveal] has finished sliding both
## bars fully off screen - the "the destination now owns the whole frame"
## moment, for anything that would rather wait on this than assume how long
## the slide took.
signal reveal_finished

## Group this joins, so a system anywhere in the world can reach the one
## letterbox in the scene without a [NodePath] across branches it does not
## own - the same convention [WorldZone] and [WorldMapCombatBridge] already
## use for themselves.
const GROUP := &"travel_letterbox"

## Which presentation state the bars are in right now.
enum State {
	## Off screen, entirely out of the way - an ordinary round in the Base or
	## the Arena, with nothing cinematic being asked for.
	HIDDEN,
	## Framing the shot with nothing else on screen - the World Map's own
	## resting presentation.
	SHOWN,
	## Framing the shot with the "Loading" word turning in the middle of it.
	LOADING,
	## Sliding both bars off screen after a loading transition. The other
	## state [method is_transitioning] reports true for, alongside
	## [constant LOADING].
	REVEALING,
}

@export_group("Nodes")
@export var top_bar_path: NodePath = ^"TopBar"
@export var bottom_bar_path: NodePath = ^"BottomBar"
@export var loading_path: NodePath = ^"Loading"
@export var loading_label_path: NodePath = ^"Loading/Row/Label"
@export var loading_dot_path: NodePath = ^"Loading/Row/DotOrbit/Dot"
@export var dot_orbit_box_path: NodePath = ^"Loading/Row/DotOrbit"

@export_group("Bars")
## How tall each bar is, in pixels - the one number that decides how much of
## the screen the World Map's own picture is framed down to.
@export var bar_height: float = 64.0
## How long [method show_letterbox] and [method hide_letterbox] take to slide
## the bars into or out of place when [param animated] is left on.
@export var show_hide_time: float = 0.5

@export_group("Loading")
## What the loading word says by default - overridable per call, see
## [method play_loading_transition].
@export var loading_text: String = "Loading"
## How far the dot orbits from the middle of its little box, in pixels.
@export var dot_orbit_radius: float = 11.0
## How many full turns the dot makes every second while loading is up.
@export var dot_orbit_speed: float = 1.1

@export_group("Reveal")
## How long the letterbox is held fully framed, with the "Loading" word
## already gone, before the bars start sliding away - the beat that keeps the
## reveal from reading as the word being swapped instantly for the
## destination.
@export var reveal_hold_time: float = 0.15
## How long the slide off screen takes. Clamped to the 0.4-0.7s window the
## whole presentation is built around.
@export_range(0.4, 0.7) var reveal_slide_time: float = 0.55

@onready var _top_bar: Control = get_node_or_null(top_bar_path) as Control
@onready var _bottom_bar: Control = get_node_or_null(bottom_bar_path) as Control
@onready var _loading: CanvasItem = get_node_or_null(loading_path) as CanvasItem
@onready var _loading_label: Label = get_node_or_null(loading_label_path) as Label
@onready var _loading_dot: Control = get_node_or_null(loading_dot_path) as Control
@onready var _dot_orbit_box: Control = get_node_or_null(dot_orbit_box_path) as Control

var _state: State = State.HIDDEN
var _bar_tween: Tween
var _dot_angle: float = 0.0
var _dot_center: Vector2 = Vector2(16.0, 16.0)
## Each bar's own authored resting [member Control.position], captured once
## before anything here ever moves them. [method _set_bar_progress] reads
## these rather than assuming a resting Y of 0 for both: [member Control.position]
## already folds each bar's anchor ratio into an absolute local coordinate, so
## a bar anchored to the bottom of the screen rests at a position nowhere near
## the top bar's - only the *displacement* away from that rest position is
## ever the same 0-to-[member bar_height] number for both.
var _top_rest_y: float = 0.0
var _bottom_rest_y: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	if _loading_label != null:
		_loading_label.text = loading_text
	if _loading != null:
		_loading.visible = false
	if _dot_orbit_box != null:
		_dot_center = _dot_orbit_box.size * 0.5
	if _top_bar != null:
		_top_rest_y = _top_bar.position.y
	if _bottom_bar != null:
		_bottom_rest_y = _bottom_bar.position.y
	_snap_to(State.HIDDEN)


## The letterbox in the scene, or null when this world has none - which every
## caller reads as "there is no cinematic presentation to ask for".
static func get_active(from_node: Node) -> TravelLetterbox:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelLetterbox


func get_state() -> State:
	return _state


## Whether a scripted transition currently owns the bars - true for the whole
## of [constant State.LOADING] and [constant State.REVEALING]. A passive gate
## like [code]travel_letterbox_gate.gd[/code] asks this before touching the
## bars on its own, so it can never fight a sequence already under way.
func is_transitioning() -> bool:
	return _state == State.LOADING or _state == State.REVEALING


## Frames the shot: both bars slide (or snap) into place. Safe to call while
## already shown, or mid-transition - a second call, or one made while a
## loading transition already has the bars up, changes nothing.
func show_letterbox(animated: bool = true) -> void:
	if _state == State.SHOWN or is_transitioning():
		return
	_state = State.SHOWN
	# The only state this can be leaving is HIDDEN - SHOWN and the two
	# transition states were already ruled out above - so the bars are always
	# coming from fully off screen.
	if animated:
		_animate_bars(1.0, 0.0, show_hide_time)
	else:
		_snap_to(State.SHOWN)


## Clears the shot: both bars slide (or snap) fully off screen. Refuses to
## interrupt a scripted transition - see [method is_transitioning] - so a
## gate's own reaction to the player leaving the World Map can never cut a
## loading transition short by asking for this while one is already running.
func hide_letterbox(animated: bool = true) -> void:
	if is_transitioning() or _state == State.HIDDEN:
		return
	_state = State.HIDDEN
	# The only state this can be leaving is SHOWN, by the same reasoning as
	# [method show_letterbox] above.
	if animated:
		_animate_bars(0.0, 1.0, show_hide_time)
	else:
		_snap_to(State.HIDDEN)


## Opens a loading transition: the bars are framed - instantly, if they were
## not already up, since there is nothing to animate into for a screen that is
## about to be covered by the loading word anyway - and the word starts
## turning in the middle of them. [method is_transitioning] reads true from
## the instant this returns, and stays true until [method play_destination_reveal]
## has finished.
func play_loading_transition(text: String = "") -> void:
	if _bar_tween != null and _bar_tween.is_running():
		_bar_tween.kill()
	_state = State.LOADING
	_set_bar_progress(0.0)
	if _loading_label != null:
		_loading_label.text = loading_text if text.is_empty() else text
	if _loading != null:
		_loading.visible = true
	_dot_angle = 0.0
	set_process(true)


## Cancels a loading transition without revealing anything: the "Loading" word
## is taken back down and the bars are simply left standing, framed. What a
## caller like [WorldMapCombatBridge] asks for when the encounter it just
## opened [method play_loading_transition] for turns out not to be able to
## start after all, so the World Map is left looking exactly as it does
## whenever nothing is loading, rather than stuck mid-transition.
func cancel_loading_transition() -> void:
	if _state != State.LOADING:
		return
	_state = State.SHOWN
	if _loading != null:
		_loading.visible = false
	set_process(false)


## Closes a loading transition: the "Loading" word comes down, the frame is
## held for [member reveal_hold_time] exactly as it already was, and only then
## do both bars slide fully off screen over [member reveal_slide_time]. Emits
## [signal reveal_finished] the instant they are clear - the frame the
## destination is allowed to be considered full screen.
func play_destination_reveal() -> void:
	if _state != State.LOADING:
		return
	_state = State.REVEALING
	if _loading != null:
		_loading.visible = false
	set_process(false)

	var hold := maxf(reveal_hold_time, 0.0)
	if hold <= 0.0:
		_slide_away()
		return
	# Real time and process-always, so the reveal still lands whatever else -
	# a fight opening, a menu - has paused the tree by the time it fires.
	var timer := get_tree().create_timer(hold, true, false, true)
	timer.timeout.connect(_slide_away)


func _slide_away() -> void:
	if not is_inside_tree() or _state != State.REVEALING:
		return
	var slide := clampf(reveal_slide_time, 0.4, 0.7)
	if _bar_tween != null and _bar_tween.is_running():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_bar_tween.tween_method(_set_bar_progress, 0.0, 1.0, slide)
	_bar_tween.finished.connect(_on_reveal_finished)


func _on_reveal_finished() -> void:
	_state = State.HIDDEN
	reveal_finished.emit()


func _animate_bars(start: float, target: float, duration: float) -> void:
	if _bar_tween != null and _bar_tween.is_running():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bar_tween.tween_method(_set_bar_progress, start, target, maxf(duration, 0.0001))


## Positions both bars along the same 0-1 line: 0 is fully framed at each
## bar's own resting [member Control.position], 1 is fully off screen - the
## top bar displaced upward by [member bar_height], the bottom bar displaced
## downward by the same amount. One shared number driving both bars, so they
## can never end up a frame apart from each other however a tween is
## interrupted and restarted.
func _set_bar_progress(t: float) -> void:
	if _top_bar != null:
		_top_bar.position.y = _top_rest_y - bar_height * t
	if _bottom_bar != null:
		_bottom_bar.position.y = _bottom_rest_y + bar_height * t


func _snap_to(state: State) -> void:
	_state = state
	_set_bar_progress(1.0 if state == State.HIDDEN else 0.0)


## Turns the loading dot in a small, continuous orbit rather than strobing it
## between frames of an animation - the same "always moving, never jarring"
## rule the rest of the presentation follows.
func _process(delta: float) -> void:
	if _loading_dot == null:
		return
	_dot_angle = fmod(_dot_angle + delta * dot_orbit_speed * TAU, TAU)
	var offset := Vector2(cos(_dot_angle), sin(_dot_angle)) * dot_orbit_radius
	_loading_dot.position = _dot_center + offset - _loading_dot.size * 0.5
