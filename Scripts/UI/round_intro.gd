class_name RoundIntro
extends Control
## The card that opens a run: where you are, what hour it is, what that place is
## called, and what the clock says. Then the wind takes it.
##
## Four things appear one after another and leave together. The order and the
## timing are the whole of the effect, so all of it is inspector values - how
## long the title takes to arrive, the beat between each element after it, how
## long the finished card is held, and how fast it is blown off the screen.
##
## [b]Nothing here decides what it says.[/b] The title card comes from the
## [MapDefinition] for whichever map [RunSessionState] says is being played; the
## hour's name, its colour, its icon and the range its clock time is rolled from
## all come from the [DayStage] the map's [DayCycleDirector] has chosen. So a
## second map is a resource, a different dawn is a different range on that map's
## dawn, and this file names neither.
##
## It reports [signal finished] rather than starting anything itself. [WorldBoot]
## waits on that and starts the run, which is what makes the round begin the
## moment the card has gone rather than while it is still on screen.

## Emitted once the card has finished leaving. The run starts on this.
signal finished
## Emitted as the card begins, for a sound or a camera move to hang off.
signal started

## The roster the title card is looked up in.
@export var catalog: MapCatalog
## The session, which knows which map is being played.
@export var session_path: NodePath = ^"/root/RunSession"
## Map used when the session cannot say - opening the world straight from the
## editor, with no run chosen. Empty falls back to the first unlocked map.
@export var fallback_map_id: StringName = &"desert"

@export_group("Timing")
## How long the title takes to fade in. The slowest part of the card on purpose:
## it is the thing being announced.
@export var title_fade_time: float = 1.0
## Beat between one element finishing its entrance and the next beginning.
@export var element_delay: float = 0.3
## How long each element after the title takes to fade in.
@export var element_fade_time: float = 0.25
## How long the finished card is held before the wind takes it, counted from the
## clock time appearing.
@export var hold_time: float = 1.0
## How long the card takes to blow away. Quick - it is being taken, not dismissed.
@export var blow_time: float = 0.45
## How far everything is carried left as it goes, in pixels.
@export var blow_distance: float = 900.0

@export_group("Nodes")
## The card everything sits on. The wind takes this rather than the four elements
## individually, which is both what "blown away together" means and what lets the
## elements themselves be laid out by an ordinary container.
@export var card_path: NodePath = ^"Card"
## The map's title artwork.
@export var title_path: NodePath = ^"Card/Title"
## Row holding the hour's icon and its name.
@export var time_row_path: NodePath = ^"Card/TimeRow"
@export var time_icon_path: NodePath = ^"Card/TimeRow/Icon"
@export var time_label_path: NodePath = ^"Card/TimeRow/Name"
## The name of the part of the map the run is in.
@export var region_name_path: NodePath = ^"Card/RegionName"
## The clock time rolled from the hour's own range.
@export var clock_label_path: NodePath = ^"Card/Clock"
## How the region's name is written. The name is substituted in, so a card that
## wants it framed - "- %s -" - is an inspector value rather than an edit here.
@export var region_name_format: String = "%s"

@onready var _card: Control = get_node_or_null(card_path) as Control
@onready var _title: Control = get_node_or_null(title_path) as Control
@onready var _time_row: Control = get_node_or_null(time_row_path) as Control
@onready var _time_icon: TextureRect = get_node_or_null(time_icon_path) as TextureRect
@onready var _time_label: Label = get_node_or_null(time_label_path) as Label
@onready var _region_name_label: Label = get_node_or_null(region_name_path) as Label
@onready var _clock_label: Label = get_node_or_null(clock_label_path) as Label

var _elements: Array[Control] = []
var _card_rest := Vector2.ZERO
var _playing: bool = false
var _tween: Tween


func _ready() -> void:
	_elements = _collect_elements()
	for element: Control in _elements:
		element.modulate.a = 0.0
	hide()


func is_playing() -> bool:
	return _playing


## Fills the card in and runs it. Called by [WorldBoot] as a run's world opens.
##
## A card that is asked to play twice does nothing the second time, and one with
## nothing to show reports [signal finished] immediately - so a world missing its
## catalogue or its day cycle still starts its run rather than hanging on an intro
## that never arrives.
func play() -> void:
	if _playing:
		return
	_playing = true

	_fill()
	# Captured on the way up rather than on ready: the card is laid out by a
	# container, so where it rests is not settled until it has been shown once.
	if _card != null:
		_card.modulate.a = 1.0
		_card_rest = _card.position
	show()
	started.emit()

	if _elements.is_empty():
		_end()
		return

	_run_sequence()


## Cuts the card short and starts the run now. For a key that skips the intro,
## and for anything that has to get the player playing immediately.
func skip() -> void:
	if not _playing:
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_end()


## Everything the card says, gathered before any of it is shown so a missing
## piece leaves a gap rather than stopping the sequence part way through.
func _fill() -> void:
	var map := _resolve_map()
	if _title != null:
		var texture_rect := _title as TextureRect
		if texture_rect != null and map != null:
			texture_rect.texture = map.title_texture
	# The place is asked of the region resource itself, which is where the desert's
	# names are already authored - so the card and a wanted poster naming the same
	# part of the map read it out of one file.
	var region := _resolve_region(map)
	if _region_name_label != null and region != null:
		var place := region.get_place_name()
		# A region that has been given no name of its own still reads as something
		# rather than as a blank line in the middle of the card.
		if place.is_empty():
			place = region.get_label()
		_region_name_label.text = region_name_format % place

	var stage := _resolve_stage()
	if stage != null:
		if _time_icon != null:
			_time_icon.texture = stage.icon
		if _time_label != null:
			_time_label.text = stage.display_name
			# The word is written in the colour of the picture beside it, so the
			# two read as one thing rather than as a label and an icon.
			_time_label.add_theme_color_override(&"font_color", stage.icon_colour)
		if _clock_label != null:
			# Rolled by the stage from its own configured range - the hour knows
			# what times it can be, and this only prints the answer.
			_clock_label.text = stage.random_clock_text()


## The card's own choreography. One tween: each element fades up in turn, the
## finished card is held, and then the whole thing is carried off to the left.
func _run_sequence() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	# The world is not paused during the intro - it runs in slow motion, and only
	# the characters in it are slowed - but the tween is set to run regardless so a
	# card started under a menu or a fade cannot stall.
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	for i: int in _elements.size():
		var element := _elements[i]
		var duration := title_fade_time if i == 0 else element_fade_time
		_tween.tween_property(element, "modulate:a", 1.0, maxf(duration, 0.0001))
		if i < _elements.size() - 1:
			_tween.tween_interval(maxf(element_delay, 0.0))

	_tween.tween_interval(maxf(hold_time, 0.0))
	_tween.tween_callback(_blow_away)


## Fade and travel at once, so it reads as being taken by the wind rather than as
## sliding off and separately dimming.
##
## The whole card is moved rather than the four elements one by one, which is
## both what "blown away together" means and what keeps the elements free to be
## laid out by an ordinary container - a container would fight a position tween
## on its own children and put them straight back.
func _blow_away() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	if _card == null:
		_end()
		return

	var duration := maxf(blow_time, 0.0001)
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(
		_card, "position", _card_rest - Vector2(absf(blow_distance), 0.0), duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_card, "modulate:a", 0.0, duration)
	_tween.chain().tween_callback(_end)


func _end() -> void:
	_playing = false
	hide()
	# Put back where it started, so a card played again - a second run in the same
	# process - opens in the middle of the screen rather than off the left edge.
	if _card != null:
		_card.position = _card_rest
		_card.modulate.a = 1.0
	for element: Control in _elements:
		element.modulate.a = 0.0
	finished.emit()


## Only the elements that actually exist, in the order they appear. A card built
## without one of them simply has three things on it.
func _collect_elements() -> Array[Control]:
	var found: Array[Control] = []
	for node: Control in [_title, _time_row, _region_name_label, _clock_label]:
		if node != null:
			found.append(node)
	return found


func _resolve_map() -> MapDefinition:
	if catalog == null:
		return null

	var wanted := fallback_map_id
	var session := get_node_or_null(session_path)
	if session != null and session.has_method(&"get_map_id"):
		var chosen: StringName = session.call(&"get_map_id")
		if chosen != &"":
			wanted = chosen

	var map := catalog.find(wanted)
	if map != null:
		return map

	var open := catalog.unlocked_maps()
	return null if open.is_empty() else open[0]


## Which part of [param map] the run is in. The session is the authority - it is
## what the region screen and travelling both write to - and a run that has not
## been sent anywhere falls back to the map's own way in, so a world opened
## straight from the editor still names a real place.
func _resolve_region(map: MapDefinition) -> MapRegion:
	var session := get_node_or_null(session_path)
	if session != null and session.has_method(&"get_region"):
		var chosen: MapRegion = session.call(&"get_region")
		if chosen != null:
			return chosen
	return null if map == null else map.get_entry_region()


## The hour is asked of the map's own clock face rather than of the session, so
## the card shows whatever the world around it was actually built as.
func _resolve_stage() -> DayStage:
	var day := DayCycleDirector.get_active(self)
	return null if day == null else day.get_stage()
