class_name TravelLoading
extends Control
## What the player watches while the days pass: a cart crossing a black screen,
## and a line saying where it is going and how long it is taking.
##
## [b]It exists so the journey is a journey rather than a hitch.[/b] The road is
## torn down and the arrival is built in the same frame, and both happen behind
## [ScreenFade]'s black - so without this the ride would be a second or two of
## nothing. All this adds is something to look at over that black, and the length
## of it is [member TravelDirector.day_time] rather than however long the
## rebuild happens to take, so the ride reads the same on every machine.
##
## [b]It is also where the player finds out what the day held.[/b] Each day of the
## ride is rolled part way through it and the answer is written here - see
## [method show_result] - so "NOTHING HAPPENED." and "AMBUSH!" arrive over the same
## cart, in the same place, rather than through a second screen that would have to
## be raised and dropped around this one.
##
## It is deliberately the lightest thing that will do: one picture, three lines, two
## tweens. Nothing is loaded, nothing is measured and nothing is waited on, because
## the rebuild it covers is not slow enough to be worth reporting progress for -
## and a bar that filled at the speed of a scene reload would be a lie on one
## machine and a stutter on another.
##
## It draws over the fade rather than under it, which is why it sits after
## [ScreenFade] in the HUD, and it runs with
## [constant Node.PROCESS_MODE_ALWAYS] because the world is frozen behind it.

## Group the presentation joins, so the director can find it without a path.
const GROUP := &"travel_loading"

## Where the region's name is read from - the [code]RunSession[/code] autoload.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Nodes")
## The block holding the three lines. Hidden as a whole for a still - see
## [method play_still] - so a picture is not shown under a heading about a journey.
@export var text_path: NodePath = ^"Text"
## A full-screen picture shown instead of the crossing, for a transition that is a
## moment rather than a distance. Optional; a screen without one falls back to
## plain black with the caption on it.
##
## [b]It is the same screen, not a second one.[/b] Setting out on a run holds a
## picture for three seconds over exactly the black this already draws over the
## fade, with the same process mode, the same z-order and the same fade in - so the
## run's departure and a day of the road are one presentation asked for two things.
@export var picture_path: NodePath = ^"Picture"
## The line written in the corner under a still - what the game is doing while the
## picture is up. Optional.
@export var caption_path: NodePath = ^"Caption"
## The waggon that crosses the screen. Its picture is set on that node.
@export var cart_path: NodePath = ^"Cart"
## The line naming where the ride is going.
@export var title_label_path: NodePath = ^"Text/Title"
## The line naming how long it takes.
@export var days_label_path: NodePath = ^"Text/Days"
## The line saying what the day turned out to be. Optional - a screen without one
## simply does not report it, and the journey is unchanged.
@export var result_label_path: NodePath = ^"Text/Result"
## The line in the corner, used for whatever the caller wants the player to know
## they can do while the screen is up - fast travel, on a day of the road. Optional,
## and cleared at the top of every crossing so a hint can never outlive the screen
## that offered it.
@export var hint_label_path: NodePath = ^"Hint"

## The man on foot, shown instead of the waggon when the player is walking - which is
## how they go looking for trouble; see [DangerDirector].
##
## [b]It is a second node rather than a second picture[/b] for the reason everything
## else here is left on the scene: what the walker is made of - a body, a head, a hat,
## whatever is drawn on him later - is a thing to be looked at and nudged in the
## inspector, not a texture and a size named in this file. Optional; a screen without
## one crosses in the waggon whatever it was asked for, which is the presentation
## exactly as it was before there was a walk to draw.
@export var walker_path: NodePath = ^"Walker"

@export_group("Wording")
## The heading. The region being ridden to is substituted in.
@export var title_format: String = "RIDING FOR REGION %s"
## The heading used when there is nowhere named to ride to.
@export var title_fallback: String = "RIDING OUT"
## How the length of the ride is written.
@export var days_format: String = "%d DAYS ON THE TRAIL"
## How a ride of exactly one day is written.
@export var one_day_text: String = "A DAY ON THE TRAIL"
## What is written when the ride has no length to report - which is every ride
## while [member TravelMenu.offer_durations] is off. Claiming "0 DAYS ON THE
## TRAIL" would be stating a number the game has not worked out yet.
@export var days_unknown_text: String = "ON THE TRAIL"

@export_group("Motion")
## Where the cart starts and finishes, as a fraction of the screen's width - so
## it crosses whatever size the window happens to be.
@export var travel_from: float = -0.15
@export var travel_to: float = 1.15
## How high up the screen the cart rides, as a fraction of its height.
@export var travel_height: float = 0.52
## How much the cart bounces as it goes, in pixels, so it reads as rolling rather
## than sliding.
@export var bounce_height: float = 9.0
## Bounces per second.
@export var bounce_speed: float = 2.4
## How long the picture and the words take to appear, in seconds.
@export var fade_in_time: float = 0.35
## How long the result line takes to arrive, in seconds, and how much larger it
## pops as it does - so being told what happened lands as news rather than as text
## appearing.
@export var result_pop_time: float = 0.22
@export var result_pop_scale: float = 0.4

@onready var _text: CanvasItem = get_node_or_null(text_path) as CanvasItem
@onready var _picture: CanvasItem = get_node_or_null(picture_path) as CanvasItem
@onready var _caption: Label = get_node_or_null(caption_path) as Label
@onready var _cart: Control = get_node_or_null(cart_path) as Control
@onready var _walker: Control = get_node_or_null(walker_path) as Control
@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _days: Label = get_node_or_null(days_label_path) as Label
@onready var _result: Label = get_node_or_null(result_label_path) as Label
@onready var _hint: Label = get_node_or_null(hint_label_path) as Label

var _running: bool = false
var _time: float = 0.0
## How far through the crossing the cart is, 0 to 1. Driven from the ride's own
## length rather than from a tween, so the cart is exactly at the far side on the
## frame the world is rebuilt however long the ride was set to.
var _progress: float = 0.0
var _duration: float = 1.0
var _fade_tween: Tween
var _result_tween: Tween
## Whichever of the two is doing the crossing. Held rather than asked for each frame,
## so the position is written to one node and the other is simply not on screen.
var _traveller: Control


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	set_process(false)
	# The road is what this screen is mostly for, so it settles on the waggon until
	# something asks for the walk.
	_set_traveller(false)
	_show_still(false)


## The presentation the director should raise. Null means this world has none,
## which it reads as "the ride happens behind plain black".
static func get_active(from_node: Node) -> TravelLoading:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelLoading


## Raises the ride. [param region_id] is where it is going, [param days] how long
## it takes, and [param duration] how many real seconds it is on screen for -
## which is what the cart's crossing is paced against.
func play(region_id: StringName, days: int, duration: float) -> void:
	_write_title(region_id)
	_write_days(days)
	# Cleared here rather than by the caller, so a day that is still being ridden
	# can never be sitting under the news from the day before it.
	clear_result()
	_set_traveller(false)
	_begin(duration)


## The same crossing, with both lines handed over instead of read off a region.
##
## [b]It is [method play] with the words given directly.[/b] The walk out to a
## Trouble Danger is the same few seconds of crossing over black that a day of the
## road is - see [DangerDirector] - and the only things that differ are what is
## written on it and who is doing the crossing, so this is the presentation the game
## already has asked for other words rather than a second one built beside it.
## Everything about the crossing, the bounce, the fade and the result line is shared
## and unchanged.
##
## [param on_foot] swaps the waggon for the walker - see [member walking_texture] -
## which is the whole of "there is no horse in this transition".
func play_titled(title: String, subtitle: String, duration: float,
		on_foot: bool = false) -> void:
	if _title != null:
		_title.text = title
	if _days != null:
		_days.text = subtitle
	clear_result()
	_set_traveller(on_foot)
	_begin(duration)


## Holds a picture over the black with [param caption] written in its corner, and
## nothing crossing it.
##
## [b]It is a moment rather than a journey[/b] - setting out on a run - so nothing
## moves and nothing is paced: the screen simply goes up and stays up until
## whoever raised it takes the world away. How long that is is the caller's, the
## same way the length of a day of the road is.
func play_still(caption: String) -> void:
	# Not a crossing, so the per-frame placement is switched off rather than being
	# left running against a traveller nobody can see.
	_running = false
	set_process(false)
	_progress = 0.0
	_time = 0.0

	if _caption != null:
		_caption.text = caption
	_show_still(true)
	clear_result()
	clear_hint()

	visible = true
	_fade_up()


## Whether the screen is showing a picture rather than a crossing. The two are
## mutually exclusive, and this is the one place that is decided.
func _show_still(on: bool) -> void:
	if _picture != null:
		_picture.visible = on
	if _caption != null:
		_caption.visible = on and not _caption.text.is_empty()
	if _text != null:
		_text.visible = not on
	if not on:
		return

	if _cart != null:
		_cart.visible = false
	if _walker != null:
		_walker.visible = false


## Which of the two is doing the crossing: the waggon, or the man on his own feet.
##
## The one that is not crossing is taken off the screen rather than moved out of
## sight, so there is never a second traveller parked at the left edge - and a screen
## that was never given a walker falls back to the waggon, which keeps the crossing
## something that always happens.
func _set_traveller(on_foot: bool) -> void:
	_traveller = _walker if on_foot and _walker != null else _cart

	if _cart != null:
		_cart.visible = _traveller == _cart
	if _walker != null:
		_walker.visible = _traveller == _walker


## The crossing itself, once whatever is written on it has been written. Shared by
## both ways in, so the two can never drift apart.
func _begin(duration: float) -> void:
	_running = true
	_time = 0.0
	_progress = 0.0
	_duration = maxf(duration, 0.0001)
	# Cleared here for the same reason the result line is: a hint belongs to the
	# crossing that offered it, and a walk out to a Danger must not inherit the
	# road's.
	clear_hint()
	# A crossing is never shown over a still, so whichever of the two was up last is
	# put away here rather than by each caller.
	_show_still(false)

	visible = true
	set_process(true)
	_place_cart()
	_fade_up()


## Says what the day turned out to be - "NOTHING HAPPENED.", "AMBUSH!" - in
## [param colour], over the cart that is still crossing.
##
## [b]It reports and nothing else.[/b] How long the word is left up, and whether a
## fight follows it, are [TravelDirector]'s: this screen is told what happened at
## the moment the road finds out, exactly as it is told where the ride is going.
## A screen with no line to write on simply does not report, and the journey is
## unchanged - which is how every optional part of this presentation degrades.
func show_result(text: String, colour: Color) -> void:
	if _result == null:
		return

	_result.text = text
	_result.add_theme_color_override(&"font_color", colour)
	_result.visible = not text.is_empty()

	if _result_tween != null and _result_tween.is_running():
		_result_tween.kill()
	if text.is_empty():
		return

	# Popped from slightly large and settled, the same arrival the world's own
	# prompts are given, so the news reads as landing rather than as being switched
	# on. Pivoted at its middle so it grows into place instead of sliding sideways.
	_result.pivot_offset = _result.size * 0.5
	_result.modulate.a = 0.0
	_result.scale = Vector2.ONE * (1.0 + maxf(result_pop_scale, 0.0))
	_result_tween = create_tween().set_parallel(true)
	_result_tween.tween_property(_result, "modulate:a", 1.0, maxf(result_pop_time, 0.01))
	_result_tween.tween_property(_result, "scale", Vector2.ONE, maxf(result_pop_time, 0.01)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Takes the result line back off. Called at the top of every day, so the news is
## always about the day being ridden.
func clear_result() -> void:
	if _result == null:
		return
	if _result_tween != null and _result_tween.is_running():
		_result_tween.kill()
	_result.text = ""
	_result.visible = false
	_result.modulate.a = 0.0
	_result.scale = Vector2.ONE


## Says what the player can do while this screen is up, in the corner.
##
## [b]It is the screen's only line that is not about the journey[/b], which is why it
## is handed in rather than written here: what can be done depends on who raised the
## screen - fast travel on a day of the road, nothing at all on a walk out to a
## Danger - and this only draws it. A screen with no corner line simply does not
## offer one.
func show_hint(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = not text.is_empty()


func clear_hint() -> void:
	if _hint == null:
		return
	_hint.text = ""
	_hint.visible = false


## Stops the traveller where it stands, with the screen still up.
##
## [b]This is the horse pulling up rather than the screen coming down.[/b] A day that
## turns out to hold something - an ambush, a gang - stops the road at the moment the
## player is told, so what they are looking at when the fight begins is a waggon
## halted about the middle of the screen rather than one that carried on across it;
## and the day screen that follows the fight puts that same halted waggon back, which
## is what makes the road read as having been interrupted and resumed rather than
## started again.
func halt() -> void:
	_running = false
	set_process(false)


## Whether the traveller has been pulled up.
func is_halted() -> bool:
	return visible and not _running


## Takes the screen off [i]without[/i] forgetting where the traveller had got to, so
## the fight the road stopped for is fought over the world rather than over black.
## The companion to [method reveal]; [method stop] is the one that forgets.
func conceal() -> void:
	_running = false
	set_process(false)
	visible = false
	modulate.a = 0.0


## Puts a concealed screen back exactly where it was left: the same position along
## the crossing, the same words, and still halted.
func reveal() -> void:
	# A screen that never went away is left exactly as it is, so a quiet day does not
	# blink as the stop at the end of it goes up.
	if visible:
		return

	visible = true
	_place_cart()
	_fade_up()


## The screen arriving, which is the same fade whether what is on it is a crossing,
## a still or a crossing being put back.
func _fade_up() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, maxf(fade_in_time, 0.0001))


## Takes the ride back off, for a journey abandoned part way. Nothing calls it -
## the world is rebuilt out from under this node instead - but it keeps the
## presentation something that can be stopped rather than only started.
func stop() -> void:
	_running = false
	set_process(false)
	visible = false
	modulate.a = 0.0
	clear_result()
	clear_hint()
	_show_still(false)


func _process(delta: float) -> void:
	if not _running:
		return

	_time += delta
	_progress = clampf(_time / _duration, 0.0, 1.0)
	_place_cart()


## The cart's position, read off how far through the ride we are rather than from
## a tween, so it cannot be left half way by a tween that was killed.
func _place_cart() -> void:
	# Falls back to the waggon for a screen that has not been through [method _begin]
	# yet - the editor, or a first frame - so the traveller is never left unplaced.
	if _traveller == null:
		_traveller = _cart
	if _traveller == null:
		return

	var view := get_viewport_rect().size
	var x := lerpf(travel_from, travel_to, _progress) * view.x
	var y := travel_height * view.y

	var bounce := 0.0
	if bounce_height > 0.0 and bounce_speed > 0.0:
		bounce = absf(sin(_time * bounce_speed * TAU)) * -bounce_height

	_traveller.position = Vector2(x, y + bounce) - _traveller.size * 0.5


func _write_title(region_id: StringName) -> void:
	if _title == null:
		return
	var label := _region_label(region_id)
	_title.text = title_fallback if label.is_empty() else title_format % label


func _write_days(days: int) -> void:
	if _days == null:
		return
	if days <= 0:
		_days.text = days_unknown_text
	elif days == 1:
		_days.text = one_day_text
	else:
		_days.text = days_format % days


## What the region is called, taken from the map's own [MapRegion] so the ride
## names it exactly as the camp's map and the travel screen did.
func _region_label(region_id: StringName) -> String:
	if region_id == &"":
		return ""

	var session := get_node_or_null(session_path)
	if session != null and session.has_method(&"get_map"):
		var map := session.call(&"get_map") as MapDefinition
		if map != null:
			var region := map.find_region(region_id)
			if region != null:
				return region.get_full_label()
	return String(region_id)
