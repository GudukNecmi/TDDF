class_name RunMapPanel
extends Control
## The line of text beside the run map: what the player is being asked, and what
## the road under the mouse costs.
##
## [b]It reads, it does not decide.[/b] [RunMapView] says what the mouse is over
## and [RunMapTravel] says which beat of a ride is being played; this only puts
## that into words. Every one of those words is an export, so retitling the
## screen or writing the durations differently is done in the inspector.
##
## [b]It never takes a click.[/b] The whole panel is mouse-transparent, so it can
## never swallow a press meant for a point on the map behind it.

## Where the map is asked what the mouse is over.
@export var view_path: NodePath = ^"../../RunMapView"
## Where the ride is asked which day cycle it is on.
@export var travel_path: NodePath = ^"../../RunMapTravel"
## The label the instruction is written into.
@export var line_path: NodePath = ^"Line"

@export_group("Wording")
## Shown while the map is waiting for a choice and the mouse is over nothing.
@export var idle_text: String = "CHOOSE A ROAD NORTH"
## Shown while the mouse is over a point that may be ridden to. [code]%s[/code]
## is the place's name, [code]%d[/code] how many day cycles the road costs, and
## [code]%s[/code] again the word for that many - see [member cycle_words].
@export var hover_text: String = "%s  —  %d %s"
## Shown while the piece is on the road. The two numbers are day cycles spent
## and the road's total.
@export var travel_text: String = "RIDING  —  DAY %d OF %d"
## What a point whose contents have not been learned is called.
@export var unknown_name: String = "UNKNOWN"
## The word for one day cycle, two, three, and so on - the first entry is one.
## An array rather than a plural rule, so the wording of a four-day road is a
## fourth entry here and no edit to this file.
@export var cycle_words: PackedStringArray = PackedStringArray(
	["DAY", "DAYS", "DAYS"])

var _view: RunMapView
var _travel: RunMapTravel
var _line: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = get_node_or_null(line_path) as Label
	_view = get_node_or_null(view_path) as RunMapView
	_travel = get_node_or_null(travel_path) as RunMapTravel

	if _view != null and not _view.hover_changed.is_connected(_on_hover_changed):
		_view.hover_changed.connect(_on_hover_changed)
	if _travel != null:
		if not _travel.travel_started.is_connected(_on_travel_started):
			_travel.travel_started.connect(_on_travel_started)
		if not _travel.day_cycle_spent.is_connected(_on_day_cycle_spent):
			_travel.day_cycle_spent.connect(_on_day_cycle_spent)
		if not _travel.travel_finished.is_connected(_on_travel_finished):
			_travel.travel_finished.connect(_on_travel_finished)

	_write(idle_text)


func _on_hover_changed(site_id: int, link: RunMapLink) -> void:
	if _travel != null and _travel.is_travelling():
		return
	if site_id < 0 or link == null:
		_write(idle_text)
		return
	_write(hover_text % [_name_of(site_id), link.day_cycles, _word_for(link.day_cycles)])


func _on_travel_started(link: RunMapLink, _from_id: int, _to_id: int) -> void:
	_write(travel_text % [1, maxi(link.day_cycles, 1)])


func _on_day_cycle_spent(spent: int, total: int) -> void:
	if spent >= total:
		return
	_write(travel_text % [spent + 1, total])


func _on_travel_finished(_site_id: int) -> void:
	_write(idle_text)


## What a point is called: its kind's own name once the player has learned what
## is there, and [member unknown_name] until then - the same fog rule the map's
## art follows, asked of the same authored kinds rather than kept twice.
func _name_of(site_id: int) -> String:
	if _view == null:
		return unknown_name
	var named := _view.display_name_of(site_id)
	return unknown_name if named.is_empty() else named


func _word_for(cycles: int) -> String:
	if cycle_words.is_empty():
		return ""
	return cycle_words[clampi(cycles - 1, 0, cycle_words.size() - 1)]


func _write(text: String) -> void:
	if _line != null:
		_line.text = text
