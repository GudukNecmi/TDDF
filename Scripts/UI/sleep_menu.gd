class_name SleepMenu
extends Control
## The night: a screen of its own, with the country the player lay down in behind
## it, the man himself lying in it, the letters coming off him, and the one
## question a night asks.
##
## [b]It is a place the game goes to, not a panel over the place it was.[/b] The
## journey and the walk out to a Danger are both played on a full screen of their
## own - see [TravelLoading] - and sleeping is the third of them: the map, the
## waggon, the prompt to use it and every other thing the camp is made of are behind
## a screen the player cannot see past, so nothing about the camp can be looked at,
## read or reached while somebody is lying down. The camp itself refuses to open
## while a night is under way as well, so those actions are unreachable rather than
## merely hidden. See [method Camp.is_in_reach].
##
## What is on it, and where each piece comes from:
##
##   * [b]The ground.[/b] The region's own [member MapRegion.ground_texture], tiled
##     across the whole screen and darkened by [member ground_tint] - the same
##     picture [RegionGround] lays on the floor of the map itself, so the player
##     sleeps in the place they actually stopped in and a region given new artwork
##     takes its nights with it. A region with no ground of its own leaves the flat
##     dark behind, which is a night like any other.
##   * [b]The sleeper.[/b] Authored on this node in the scene - a body, a head,
##     turned over onto its side - exactly as the walker on the travel screen is,
##     so what the sleeping man is made of is a thing to be looked at and nudged in
##     the inspector rather than a texture named in this file.
##   * [b]The letters.[/b] [PlayerSleep]'s own, through
##     [method PlayerSleep.breathe_out_into]. How they look, how far they drift and
##     how long they live are that node's inspector values, so the Zs over the man
##     on this screen and the Zs over the body in the world are one thing tuned in
##     one place.
##   * [b]The question and the answer.[/b] How many segments may be asked for and
##     how far through the night it is are [SleepDirector]'s; this reads that node
##     for its numbers and reports two presses back to it - a length, and WAKE UP.
##
## [b]It does not freeze the world[/b], and that is still the point of the night:
## the desert goes on turning behind it and the hour keeps moving. What it does do
## is stop the player watching it happen, which is what makes waking up somewhere
## the news it should be - see [method announce], the word thrown up when something
## comes out of the dark, in the same place and in the same way the road announces
## an ambush over its own crossing.
##
## The length buttons are built rather than authored, from
## [method SleepDirector.get_max_segments], so raising the ceiling from four to five
## is one inspector field on the director and nothing here. Their look comes from the
## styleboxes dropped into this node in the scene, exactly as the bounty screens build
## theirs.

## Emitted as the screen goes up and comes down.
signal opened
signal closed

## Group the screen joins, so the director can find it without a path across the HUD.
const GROUP := &"sleep_menu"

## The run's own state - the [code]RunSession[/code] autoload. Asked which part of
## the map is behind the sleeper, and what the hours are called.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Nodes")
## The heading.
@export var title_label_path: NodePath = ^"Panel/Body/Title"
## The line under it: the question while the length is being chosen, and how far
## through the night it is afterwards.
@export var status_label_path: NodePath = ^"Panel/Body/Status"
## The row the length buttons are built into. Emptied and refilled every time the
## screen goes up.
@export var durations_path: NodePath = ^"Panel/Body/Durations"
## The one button that is always there.
@export var wake_button_path: NodePath = ^"Panel/Body/WakeButton"
## The whole block of controls, taken off on its own while a question is being asked
## over the top of the night - see [method pause_for_question]. Everything else on
## the screen stays exactly where it is, so the man is still lying in his own region
## behind whatever is being asked.
@export var panel_path: NodePath = ^"Panel"
## The flat dark the screen is built on. It is what the map is behind, so a screen
## without one shows the world through the gaps.
@export var backdrop_path: NodePath = ^"Backdrop"
## The region's ground, tiled across the screen. Optional; a screen without one is
## the flat dark alone.
@export var ground_path: NodePath = ^"Ground"
## The man lying down. Everything about how he looks is authored on that node.
@export var sleeper_path: NodePath = ^"Sleeper"
## What the letters are added to, so they drift over the sleeper and under the
## controls. Optional; a screen without one simply has no Zs.
@export var letters_path: NodePath = ^"Letters"
## The large word thrown up when the night is broken into - see [method announce].
@export var announce_label_path: NodePath = ^"Announce"

@export_group("Wording")
@export var title_text: String = "SLEEP"
## What the line says while a length is being picked.
@export var choose_text: String = "WHEN WILL YOU WAKE UP?"
## How one length button is written: how many segments, then the hour it would end at.
@export var duration_format: String = "%d  -  %s"
## How the same button is written when the map has no hours to name.
@export var duration_plain_format: String = "%d"
## How the progress line is written: segments slept, segments asked for, and the hour
## it is now.
@export var progress_format: String = "%d / %d  -  %s"
## The same without an hour to name.
@export var progress_plain_format: String = "%d / %d"
@export var wake_text: String = "WAKE UP"

@export_group("The screen")
## How long the screen takes to arrive, in seconds.
@export var fade_in_time: float = 0.4
## Whether the region's own ground is put behind the sleeper.
@export var shows_region_ground: bool = true
## What that ground is washed in, so the country reads as being looked at by night
## rather than as the map in daylight with a panel over it.
@export var ground_tint := Color(0.34, 0.26, 0.28, 1.0)
## Where the letters come from, relative to the middle of the sleeper: the head end
## of a body lying on the ground.
@export var letter_origin := Vector2(24.0, -96.0)
## How long the word thrown up by [method announce] takes to arrive, in seconds, and
## how much larger it pops as it does - the same arrival the road gives its own news.
@export var announce_pop_time: float = 0.22
@export var announce_pop_scale: float = 0.4

@export_group("Length buttons")
## How large the numbers on them are.
@export var duration_font_size: int = 26
@export var duration_font_colour := Color(0.84, 0.76, 0.73, 1.0)
@export var duration_hover_colour := Color(1.0, 0.9, 0.87, 1.0)
## The game's own bordered dark-red buttons, dropped in from the scene so this screen
## is styled where every other one is.
@export var button_normal: StyleBox
@export var button_hover: StyleBox
@export var button_pressed: StyleBox

@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _status: Label = get_node_or_null(status_label_path) as Label
@onready var _durations: Container = get_node_or_null(durations_path) as Container
@onready var _wake: Button = get_node_or_null(wake_button_path) as Button
@onready var _panel: CanvasItem = get_node_or_null(panel_path) as CanvasItem
@onready var _backdrop: CanvasItem = get_node_or_null(backdrop_path) as CanvasItem
@onready var _ground: TextureRect = get_node_or_null(ground_path) as TextureRect
@onready var _sleeper: Control = get_node_or_null(sleeper_path) as Control
@onready var _letters: Control = get_node_or_null(letters_path) as Control
@onready var _announce: Label = get_node_or_null(announce_label_path) as Label

var _director: SleepDirector
var _fade_tween: Tween
var _announce_tween: Tween
## Seconds until the next letter. Paced from [PlayerSleep]'s own interval, so the
## screen breathes at the same rate the body does.
var _letter_timer: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	set_process(false)
	clear_announcement()
	if _wake != null:
		_wake.pressed.connect(_on_wake_pressed)


## The screen the sleep system should raise. Null means this world has none, which it
## reads as "there is nowhere to sleep here" and refuses the night rather than putting
## the player down with no way up.
static func get_active(from_node: Node) -> SleepMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as SleepMenu


func is_open() -> bool:
	return visible


## Raises the screen for [param director], which is the node every press is reported
## back to and every number is read from.
func open_for(director: SleepDirector) -> void:
	_director = director
	_show_controls(true)
	refresh()
	if visible:
		return

	_dress_the_country()
	clear_announcement()
	_letter_timer = 0.0
	show()
	set_process(true)
	_fade_up()
	# Deliberately unfocused, for the same reason every other menu is: the accept key
	# is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	opened.emit()


## Takes it down, and takes the night's letters and its last word with it.
## [b]The pause is never touched[/b] - this screen never took it, and the world has
## been running behind it the whole night.
func close() -> void:
	if not visible:
		return
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	hide()
	set_process(false)
	clear_announcement()
	_forget_letters()
	_drop_focus()
	closed.emit()


## Takes the controls off without taking the night down, for a question asked over the
## top of it - the man on one of the player's posters coming round.
##
## [b]The night is paused, not left.[/b] The player is still lying in the same region
## with the same segments behind them, and answering the question either goes back to
## exactly this screen - [method open_for] puts the controls back - or ends the night
## through the director. Nothing about how far through it is is touched here.
func pause_for_question() -> void:
	_show_controls(false)
	_drop_focus()


## Whether the controls are on show. False while a question is being asked over the
## night.
func is_paused() -> bool:
	return visible and _panel != null and not _panel.visible


## Says what the night turned out to hold - "AMBUSH" - in [param colour], over the
## man still lying there.
##
## [b]It reports and nothing else.[/b] How long the word is left up and what follows
## it are [SleepDirector]'s: this screen is told at the moment the night finds out,
## exactly as the road's own crossing is told a day held an ambush. A screen with no
## line to write on simply does not report, and the night is unchanged.
func announce(text: String, colour: Color) -> void:
	if _announce == null:
		return

	if _announce_tween != null and _announce_tween.is_running():
		_announce_tween.kill()

	_announce.text = text
	_announce.add_theme_color_override(&"font_color", colour)
	_announce.visible = not text.is_empty()
	if text.is_empty():
		return

	# Popped from slightly large and settled, the same arrival the road's news is
	# given, so being woken lands rather than being switched on.
	_announce.pivot_offset = _announce.size * 0.5
	_announce.modulate.a = 0.0
	_announce.scale = Vector2.ONE * (1.0 + maxf(announce_pop_scale, 0.0))
	_announce_tween = create_tween().set_parallel(true)
	_announce_tween.tween_property(_announce, "modulate:a", 1.0, maxf(announce_pop_time, 0.01))
	_announce_tween.tween_property(_announce, "scale", Vector2.ONE, maxf(announce_pop_time, 0.01)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func clear_announcement() -> void:
	if _announce == null:
		return
	if _announce_tween != null and _announce_tween.is_running():
		_announce_tween.kill()
	_announce.text = ""
	_announce.visible = false
	_announce.modulate.a = 0.0
	_announce.scale = Vector2.ONE


## Writes every line and rebuilds the length buttons from the director's own state, so
## the screen and the night can never disagree about how far through it is.
func refresh() -> void:
	if _title != null:
		_title.text = title_text
	if _wake != null:
		_wake.text = wake_text

	var choosing := _director != null and _director.get_segments_wanted() <= 0
	_write_status(choosing)
	_build_durations(choosing)


# --- The country behind him ----------------------------------------------------

## Puts the region the player lay down in behind the sleeper.
##
## [b]It is the map's own ground, asked for rather than copied.[/b]
## [member MapRegion.ground_texture] is the picture [RegionGround] lays on the floor
## of the world itself, so a region given its own artwork is slept in on that artwork
## with nothing here to change - and a region with none leaves the flat dark, which
## is what every region's night looked like before there was regional ground.
func _dress_the_country() -> void:
	if _ground == null:
		return

	var region := _current_region()
	var ground: Texture2D = null
	if shows_region_ground and region != null:
		ground = region.ground_texture

	_ground.texture = ground
	_ground.visible = ground != null
	_ground.modulate = ground_tint


## The part of the map the night is happening in, asked of the session so there is no
## second copy of where the run currently is.
func _current_region() -> MapRegion:
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_region"):
		return null
	return session.call(&"get_region") as MapRegion


# --- The letters ---------------------------------------------------------------

## The Zs, breathed out over the sleeper at the rate the body itself breathes them.
##
## Every letter is [PlayerSleep]'s - see [method PlayerSleep.breathe_out_into] - so
## nothing about how one looks or how far it drifts is decided here, and a world with
## no sleeper in it simply has none.
func _process(delta: float) -> void:
	if not visible or _letters == null:
		return

	var sleeper := PlayerSleep.get_active(self)
	if sleeper == null or not sleeper.shows_letters:
		return

	_letter_timer -= delta
	if _letter_timer > 0.0:
		return
	_letter_timer = maxf(sleeper.letter_interval, 0.05)
	sleeper.breathe_out_into(_letters, _letter_source())


## Where a letter starts: the head end of the sleeper, in the letters node's own
## space. Read off the sleeper rather than authored twice, so moving the man on the
## screen moves what comes off him.
func _letter_source() -> Vector2:
	if _sleeper == null:
		return letter_origin
	return _sleeper.position + _sleeper.size * 0.5 + letter_origin


## Takes away every letter still in the air. Waking is not something a letter should
## outlive, and the screen coming down would otherwise leave two or three of them
## hanging over nothing.
func _forget_letters() -> void:
	if _letters == null:
		return
	for child: Node in _letters.get_children():
		child.queue_free()


# --- The controls ----------------------------------------------------------------

func _show_controls(on: bool) -> void:
	if _panel != null:
		_panel.visible = on


func _write_status(choosing: bool) -> void:
	if _status == null:
		return
	if _director == null:
		_status.text = ""
		return

	if choosing:
		_status.text = choose_text
		return

	var hour := _hour_name(0)
	if hour.is_empty():
		_status.text = progress_plain_format % [
			_director.get_segments_slept(), _director.get_segments_wanted()]
	else:
		_status.text = progress_format % [
			_director.get_segments_slept(), _director.get_segments_wanted(), hour]


## One button per length the night may be asked for, named with the hour it would end
## at - so the choice is read as "sleep until twilight" rather than as a number.
func _build_durations(choosing: bool) -> void:
	if _durations == null:
		return

	for child: Node in _durations.get_children():
		child.queue_free()

	_durations.visible = choosing
	if not choosing or _director == null:
		return

	for segments: int in range(1, _director.get_max_segments() + 1):
		_durations.add_child(_build_duration(segments))


func _build_duration(segments: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", duration_font_size)
	button.add_theme_color_override(&"font_color", duration_font_colour)
	button.add_theme_color_override(&"font_hover_color", duration_hover_colour)
	button.add_theme_color_override(&"font_pressed_color", duration_hover_colour)
	if button_normal != null:
		button.add_theme_stylebox_override(&"normal", button_normal)
		button.add_theme_stylebox_override(&"focus", button_normal)
	if button_hover != null:
		button.add_theme_stylebox_override(&"hover", button_hover)
	if button_pressed != null:
		button.add_theme_stylebox_override(&"pressed", button_pressed)

	var hour := _hour_name(segments)
	button.text = duration_plain_format % segments if hour.is_empty() \
		else duration_format % [segments, hour]
	button.pressed.connect(_on_duration_pressed.bind(segments))
	return button


## What the hour [param offset] segments from now is called.
##
## [b]It is the run's own answer[/b] - [method RunSessionState.get_time_stage_at_offset],
## the same call the travel screen previews an arrival's hour with - so a night names
## the hours it will pass through by exactly the arithmetic that will actually be spent
## on them. Empty for a map with no day cycle, which every line here falls back from.
func _hour_name(offset: int) -> String:
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_time_stage_at_offset"):
		return ""
	var stage := session.call(&"get_time_stage_at_offset", offset) as DayStage
	return "" if stage == null else stage.display_name


## The screen arriving, which is the same fade the road's own crossing arrives on.
func _fade_up() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, maxf(fade_in_time, 0.0001))


func _on_duration_pressed(segments: int) -> void:
	if _director != null:
		_director.choose_duration(segments)


func _on_wake_pressed() -> void:
	if _director != null:
		_director.wake_up()


## Dropped for the same reason the screen opens unfocused - a button that kept focus
## would keep eating the accept key once the player is on their feet again.
func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
