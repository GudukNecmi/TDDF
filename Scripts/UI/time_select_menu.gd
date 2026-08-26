class_name TimeSelectMenu
extends Control
## When the player is riding out. The last screen between the base and the run.
##
## [b]The tiles are generated from the chosen map's own hours, not authored.[/b]
## It reads [member MapDefinition.day_stages] off whichever map
## [RunSessionState] says was picked, so the desert's six hours are six
## [code].tres[/code] files and a map that keeps four hours, or different ones,
## needs nothing here changed. No hour is named in this file and no count is
## assumed. Each tile draws the stage's own [member DayStage.icon] and writes its
## name in the stage's own [member DayStage.icon_colour], so the picture on the
## tile is the same picture the HUD and the round intro will show once the run
## begins - one asset, one colour, three places.
##
## [b]Choosing does not invent a second clock.[/b] The hour of the session lives
## in the [code]DayCycle[/code] autoload and always has; this screen only asks
## [method RunSessionState.choose_time] to move it, and everything that shows the
## time of day - the world's darkness, the HUD icon, the round intro - carries on
## reading it from where it always did. See [DayCycleDirector], which is the
## authority on what an hour looks like.
##
## [b]Choosing is two steps on purpose[/b], exactly as [RegionSelectMenu]'s is.
## Pressing a tile selects it and nothing else; the run does not begin until GO is
## pressed, and GO cannot be pressed until a tile has been. Nothing is picked on
## the player's behalf.
##
## Like every other menu in the game it is styled from the inspector: the same
## stylebox resources the pause, upgrade, map and region screens use are handed
## in, so all of them are retuned together.
##
## It reports the choice and stops. Rebuilding the world belongs to the
## [RunPortal] that opened it, exactly as it does for the screens before it.

## Emitted when the player commits to an hour.
signal time_chosen(stage_name: StringName)
## Emitted when the screen is closed without choosing, so whatever opened it can
## put itself back.
signal cancelled
signal opened

## Group the menu joins, so the base's portal can find it without a path across
## the scene - the portal lives in the base and this lives on the HUD.
const GROUP := &"time_select_menu"

## Where the chosen map is read from - the [code]RunSession[/code] autoload. The
## screen asks it which map to show the hours of, so it never has to be told.
@export var session_path: NodePath = ^"/root/RunSession"
## Container the tiles are built into. A grid, so the hours read as a row of
## pictures rather than as a list of words.
@export var tiles_path: NodePath = ^"Panel/Body/Times"
## The button that sets out. Disabled until an hour has been picked.
@export var confirm_button_path: NodePath = ^"Panel/Body/Footer/ConfirmButton"
## Optional line naming what has been picked so far.
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"
## Optional heading, given the map's name so the player can see where they are
## choosing the hour for.
@export var title_label_path: NodePath = ^"Panel/Body/Header/Title"
## Freezes the world while the screen is up, the same way every other menu does.
@export var pauses_game: bool = true
## Key that backs out without choosing.
@export var close_action: StringName = &"pause_menu"

@export_group("Wording")
## The heading. The chosen map's name is substituted in.
@export var title_format: String = "%s  -  CHOOSE A TIME OF DAY"
## The heading used when there is no map to name.
@export var title_fallback: String = "CHOOSE A TIME OF DAY"
## What the status line says before anything is picked.
@export var status_prompt: String = "PICK THE HOUR YOU RIDE OUT AT"
## What it says once an hour is picked. Its name is substituted in.
@export var status_format: String = "RIDING OUT AT %s"
## What is shown in place of the grid for a map that keeps no hours.
@export var empty_text: String = "THIS MAP KEEPS NO HOURS OF ITS OWN"

@export_group("Tile style")
## Styleboxes the generated tiles wear. The same resources the rest of the game's
## menus use, handed in rather than rebuilt.
@export var tile_normal: StyleBox
@export var tile_hover: StyleBox
@export var tile_pressed: StyleBox
@export var tile_disabled: StyleBox
## What the picked tile wears, so the selection can be read without hovering.
## Falls back to the pressed style when none is given.
@export var tile_selected: StyleBox
## How many tiles sit side by side before the grid wraps.
@export var columns: int = 3
## Smallest a tile is drawn, in pixels.
@export var tile_size := Vector2(200.0, 150.0)
## How large the hour's own picture is drawn on its tile.
@export var icon_size := Vector2(72.0, 72.0)
@export var name_font_size: int = 30
@export var font_colour := Color(0.16, 0.06, 0.05)
## Colour the selected tile's name is written in, for a screen where the stage
## colours are being used and a second cue is wanted. Only used when
## [member tint_name_with_stage_colour] is off.
@export var font_selected_colour := Color(0.5, 0.08, 0.07)
## Whether each hour's name is written in that hour's own colour - see
## [member DayStage.icon_colour] - so the word and the picture read as one thing,
## the way they already do on the HUD and the round intro. Off writes every name
## in [member font_colour] instead.
@export var tint_name_with_stage_colour: bool = true
## How much an unpicked tile is faded, so the chosen hour is the bright one. 1.0
## leaves them all at full strength and lets the stylebox carry the selection on
## its own.
@export_range(0.0, 1.0) var unselected_dim: float = 0.55

@onready var _tiles: Container = get_node_or_null(tiles_path) as Container
@onready var _confirm: Button = get_node_or_null(confirm_button_path) as Button
@onready var _status: Label = get_node_or_null(status_label_path) as Label
@onready var _title: Label = get_node_or_null(title_label_path) as Label

var _session: Node
## The hour under the cursor of the player's decision, before GO is pressed.
## Empty means nothing has been picked, which is what keeps GO disabled.
var _selected: StringName = &""
## The tile per hour, so the selected look can be moved from one to another
## without the whole grid being rebuilt.
var _buttons: Dictionary[StringName, Button] = {}
var _choosing: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_session = get_node_or_null(session_path)
	if _confirm != null:
		_confirm.pressed.connect(_on_confirm_pressed)


## The screen the base's portal should open. Null means this world has none, which
## the portal reads as "do not ask the question" - so a world without this screen
## sets out at whatever hour the day cycle was already up to, exactly as it did
## before the question existed.
static func get_active(from_node: Node) -> TimeSelectMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TimeSelectMenu


func is_open() -> bool:
	return visible


## Which hour is picked but not yet committed, for a test or a readout.
func get_selected_time() -> StringName:
	return _selected


## Raises the screen on whichever map was chosen. Built on every open rather than
## once, because which map's hours it is showing changes.
func open() -> void:
	if visible:
		return

	_choosing = false
	_selected = &""
	_build()
	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Closes without choosing. [param report] is false only on the way out of a
## choice, where the run is already starting and nothing should be told the player
## backed out.
func close(report: bool = true) -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	if report:
		cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _choosing:
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


## One tile per hour the chosen map keeps. A map with none is not an error - it is
## a place with no day cycle - so it says so rather than showing an empty grid.
func _build() -> void:
	if _tiles == null:
		return

	for child: Node in _tiles.get_children():
		child.queue_free()
	_buttons.clear()

	var grid := _tiles as GridContainer
	if grid != null:
		grid.columns = maxi(columns, 1)

	var map := _chosen_map()
	_write_title(map)

	if map == null or map.day_stages.is_empty():
		_tiles.add_child(_build_notice(empty_text))
		_refresh_confirm()
		return

	for stage: DayStage in map.day_stages:
		if stage == null:
			continue
		var tile := _build_tile(stage)
		_buttons[stage.stage_name] = tile
		_tiles.add_child(tile)

	_refresh_confirm()


func _chosen_map() -> MapDefinition:
	if _session == null or not _session.has_method(&"get_map"):
		return null
	return _session.call(&"get_map") as MapDefinition


func _write_title(map: MapDefinition) -> void:
	if _title == null:
		return
	_title.text = title_fallback if map == null else title_format % map.display_name


## An hour, drawn as its own picture over its own name. Both come off the
## [DayStage] rather than being authored here, so the tile is the same sun or moon
## the run itself will be shown under.
func _build_tile(stage: DayStage) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = tile_size
	tile.focus_mode = Control.FOCUS_NONE
	tile.clip_text = true

	# The picture and the name are two nodes inside the button rather than the
	# button's own icon and text, so they can be sized, spaced and coloured apart.
	var box := VBoxContainer.new()
	box.name = "Text"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 6)

	if stage.icon != null:
		var picture := TextureRect.new()
		picture.name = "Icon"
		picture.texture = stage.icon
		picture.custom_minimum_size = icon_size
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(picture)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = stage.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", name_font_size)
	name_label.add_theme_color_override(&"font_color", _name_colour(stage, false))
	box.add_child(name_label)

	tile.add_child(box)
	tile.set_meta(&"stage", stage)
	_apply_tile_style(tile, false)

	tile.pressed.connect(_on_tile_pressed.bind(stage))
	return tile


## The line shown in place of the grid when there is nothing to offer.
func _build_notice(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", name_font_size)
	label.add_theme_color_override(&"font_color", font_colour)
	return label


## Selecting only. [b]Nothing about the run moves here[/b] - the clock is not
## touched and the world is not rebuilt until GO is pressed, which is what makes
## changing your mind free.
func _on_tile_pressed(stage: DayStage) -> void:
	if _choosing or stage == null:
		return

	_selected = stage.stage_name
	for id: StringName in _buttons:
		_apply_tile_style(_buttons[id], id == _selected)

	if _status != null:
		_status.text = status_format % stage.display_name
	_refresh_confirm()


## Commits. This is the only thing on the screen that tells the session anything,
## and what it tells it moves the one clock the game already had.
func _on_confirm_pressed() -> void:
	if _choosing or _selected == &"":
		return
	_choosing = true

	if _session != null and _session.has_method(&"choose_time"):
		_session.call(&"choose_time", _selected)

	close(false)
	time_chosen.emit(_selected)


func _refresh_confirm() -> void:
	if _confirm != null:
		_confirm.disabled = _selected == &""
	if _status != null and _selected == &"":
		_status.text = status_prompt


## The one place a tile's look is decided, so a tile can only ever be drawn one
## way and the selected look cannot be left behind on a tile the player has moved
## off.
func _apply_tile_style(tile: Button, selected: bool) -> void:
	if tile == null:
		return

	var resting := tile_selected if selected and tile_selected != null else tile_normal
	if selected and tile_selected == null:
		resting = tile_pressed
	if resting != null:
		tile.add_theme_stylebox_override(&"normal", resting)
	if tile_hover != null:
		tile.add_theme_stylebox_override(&"hover", tile_hover if not selected else resting)
	if tile_pressed != null:
		tile.add_theme_stylebox_override(&"pressed", tile_pressed)
	if tile_disabled != null:
		tile.add_theme_stylebox_override(&"disabled", tile_disabled)

	# Faded rather than recoloured, so an hour's own colour survives being the one
	# not picked - a dimmed dawn still reads as dawn.
	tile.modulate.a = 1.0 if selected or _selected == &"" else unselected_dim

	var name_label := tile.get_node_or_null(^"Text/Name") as Label
	var stage := tile.get_meta(&"stage", null) as DayStage
	if name_label != null:
		name_label.add_theme_color_override(&"font_color", _name_colour(stage, selected))


## What an hour's name is written in: its own colour, so the word matches the
## picture above it and the HUD it will appear on.
func _name_colour(stage: DayStage, selected: bool) -> Color:
	if tint_name_with_stage_colour and stage != null:
		return stage.icon_colour
	return font_selected_colour if selected else font_colour


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
