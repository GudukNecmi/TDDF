class_name RegionSelectMenu
extends Control
## Where in the map the player is going. The screen between choosing the desert
## and setting out into it.
##
## [b]The tiles are generated from the chosen map, not authored.[/b] It reads
## [member MapDefinition.regions] off whichever map [RunSessionState] says was
## picked, so the desert's five parts are five [code].tres[/code] files and a map
## divided into three places with real names needs nothing here changed. No region
## is named in this file and no count is assumed - which is the whole point, since
## the next map will not have five of anything.
##
## [b]Choosing is two steps on purpose.[/b] Pressing a tile selects it and nothing
## else; the run does not begin until GO is pressed, and GO cannot be pressed
## until a tile has been. Nothing is ever picked on the player's behalf - a screen
## that quietly defaulted to A would make the question a formality, and this is
## meant to be a decision. The selected tile is drawn in the selected stylebox so
## which one it is can be read at a glance.
##
## Like every other menu in the game it is styled from the inspector: the same
## stylebox resources the pause, upgrade and map screens use are handed in, so all
## of them are retuned together and this one cannot drift away from the rest.
##
## It reports the choice and stops. Rebuilding the world belongs to the [RunPortal]
## that opened it, exactly as it does for the weapon and map screens before it.

## Emitted when the player commits to a region.
signal region_chosen(region_id: StringName)
## Emitted when the screen is closed without choosing, so whatever opened it can
## put itself back.
signal cancelled
signal opened

## Group the menu joins, so the base's portal can find it without a path across
## the scene - the portal lives in the base and this lives on the HUD.
const GROUP := &"region_select_menu"

## Where the chosen map is read from - the [code]RunSession[/code] autoload. The
## screen asks it which map to show the regions of, so it never has to be told.
@export var session_path: NodePath = ^"/root/RunSession"
## Container the tiles are built into. A grid, so the parts of the map read as
## places rather than as a list of words.
@export var tiles_path: NodePath = ^"Panel/Body/Regions"
## The button that sets out. Disabled until a region has been picked.
@export var confirm_button_path: NodePath = ^"Panel/Body/Footer/ConfirmButton"
## Optional line naming what has been picked so far.
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"
## Optional heading, given the map's name so the player can see where they are
## choosing inside.
@export var title_label_path: NodePath = ^"Panel/Body/Header/Title"
## Freezes the world while the screen is up, the same way every other menu does.
@export var pauses_game: bool = true
## Key that backs out without choosing.
@export var close_action: StringName = &"pause_menu"

@export_group("Wording")
## The heading. The chosen map's name is substituted in.
@export var title_format: String = "%s  -  CHOOSE A REGION"
## The heading used when there is no map to name.
@export var title_fallback: String = "CHOOSE A REGION"
## What the status line says before anything is picked.
@export var status_prompt: String = "PICK A REGION TO RIDE INTO"
## What it says once one is. The region's name is substituted in.
@export var status_format: String = "HEADING FOR REGION %s"
## What a tile with nothing to show says.
@export var empty_text: String = "THIS MAP HAS NOT BEEN DIVIDED UP YET"
## How a locked region is written - its name, then its own locked wording.
@export var locked_format: String = "%s  -  %s"

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
## Smallest a tile is drawn, in pixels. Wide enough to read as an area rather than
## a row of text.
@export var tile_size := Vector2(200.0, 120.0)
@export var name_font_size: int = 40
@export var description_font_size: int = 15
@export var font_colour := Color(0.16, 0.06, 0.05)
@export var font_hover_colour := Color(0.45, 0.07, 0.06)
@export var font_disabled_colour := Color(0.42, 0.36, 0.3)
## Colour the selected tile's name is written in, so the choice reads even at a
## glance across the panel.
@export var font_selected_colour := Color(0.5, 0.08, 0.07)
## Colour of the line under a region's name.
@export var description_colour := Color(0.45, 0.3, 0.3)

@onready var _tiles: Container = get_node_or_null(tiles_path) as Container
@onready var _confirm: Button = get_node_or_null(confirm_button_path) as Button
@onready var _status: Label = get_node_or_null(status_label_path) as Label
@onready var _title: Label = get_node_or_null(title_label_path) as Label

var _session: Node
## The region under the cursor of the player's decision, before GO is pressed.
## Empty means nothing has been picked, which is what keeps GO disabled.
var _selected: StringName = &""
## The tile per region, so the selected look can be moved from one to another
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
## the portal reads as "do not ask the question".
static func get_active(from_node: Node) -> RegionSelectMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RegionSelectMenu


func is_open() -> bool:
	return visible


## Which region is picked but not yet committed, for a test or a readout.
func get_selected_region() -> StringName:
	return _selected


## Raises the screen on whichever map was chosen. Built on every open rather than
## once, because which map it is showing the inside of changes.
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


## One tile per region of the chosen map. A map with none is not an error - it is
## a place that has not been divided up yet - so it says so rather than showing an
## empty grid.
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

	if map == null or map.regions.is_empty():
		_tiles.add_child(_build_notice(empty_text))
		_refresh_confirm()
		return

	for region: MapRegion in map.regions:
		if region == null:
			continue
		var tile := _build_tile(region)
		_buttons[region.region_id] = tile
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


## A region, drawn as an area rather than a row: its name large, and whatever the
## region says about itself underneath.
func _build_tile(region: MapRegion) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = tile_size
	tile.disabled = not region.unlocked
	tile.focus_mode = Control.FOCUS_NONE
	tile.clip_text = true

	# The name and the description are two labels inside the button rather than one
	# string with a newline, so they can be sized and coloured apart - and so the
	# selected look can recolour the name without touching the line under it.
	var box := VBoxContainer.new()
	box.name = "Text"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = region.get_label() if region.unlocked \
		else locked_format % [region.get_label(), region.locked_label]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", name_font_size)
	name_label.add_theme_color_override(
		&"font_color", font_colour if region.unlocked else font_disabled_colour)
	box.add_child(name_label)

	if not region.description.is_empty():
		var line := Label.new()
		line.name = "Description"
		line.text = region.description
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override(&"font_size", description_font_size)
		line.add_theme_color_override(&"font_color", description_colour)
		box.add_child(line)

	tile.add_child(box)
	_apply_tile_style(tile, false)

	if region.unlocked:
		tile.pressed.connect(_on_tile_pressed.bind(region))
	return tile


## The line shown in place of the grid when there is nothing to offer.
func _build_notice(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", description_font_size)
	label.add_theme_color_override(&"font_color", description_colour)
	return label


## Selecting only. [b]Nothing about the run moves here[/b] - the session is not
## told and the world is not touched until GO is pressed, which is what makes
## changing your mind free.
func _on_tile_pressed(region: MapRegion) -> void:
	if _choosing or region == null or not region.unlocked:
		return

	_selected = region.region_id
	for id: StringName in _buttons:
		_apply_tile_style(_buttons[id], id == _selected)

	if _status != null:
		# The letter and the place's own name, matching what the camp and the travel
		# screen say about the same region.
		_status.text = status_format % region.get_full_label()
	_refresh_confirm()


## Commits. This is the only thing on the screen that tells the session anything.
func _on_confirm_pressed() -> void:
	if _choosing or _selected == &"":
		return
	_choosing = true

	if _session != null and _session.has_method(&"choose_region"):
		_session.call(&"choose_region", _selected)

	close(false)
	region_chosen.emit(_selected)


func _refresh_confirm() -> void:
	if _confirm != null:
		_confirm.disabled = _selected == &""
	if _status != null and _selected == &"":
		_status.text = status_prompt


## The one place a tile's look is decided, so a tile can only ever be drawn one
## way and the selected style cannot be left behind on a tile the player has moved
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

	var name_label := tile.get_node_or_null(^"Text/Name") as Label
	if name_label == null or tile.disabled:
		return
	name_label.add_theme_color_override(
		&"font_color", font_selected_colour if selected else font_colour)


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
