class_name MapSelectMenu
extends Control
## Where the player chooses where to go. What the base's pit opens when B is
## pressed standing in it.
##
## The list is generated from a [MapCatalog] rather than authored as five
## buttons, so the roster is a resource: unlocking the forest is ticking a box on
## a [code].tres[/code] file, and a sixth map is one more entry. Nothing in this
## file names a single map.
##
## A locked map is still listed. That is the whole point of showing four of them
## when only one can be played - the player should be able to see what is coming.
## It is drawn dimmed, says so, and cannot be pressed.
##
## Choosing a map does two things and stops: it tells [RunSessionState] where the
## player is going, and it reports [signal map_chosen]. What happens next - the
## camera pulling out, the world being rebuilt - belongs to the [RunPortal] that
## opened this, exactly as it did before there was a menu in the way. That is
## what keeps the transition in one place instead of two.
##
## It is styled from the inspector rather than in code: the same stylebox
## resources the pause and upgrade menus use are handed to it, so it matches them
## and is retuned alongside them.

## Emitted when the player picks a map that can actually be played.
signal map_chosen(map_id: StringName)
## Emitted when the menu is closed without a choice, so whatever opened it can
## put itself back the way it was.
signal cancelled
signal opened

## Group the menu joins, so the base's portal can find it without a path across
## the scene - the portal lives inside the base's own scene and this lives on the
## HUD, so there is no sensible path between them.
const GROUP := &"map_select_menu"

## The maps on offer, in order.
@export var catalog: MapCatalog
## Container the entries are built into. A vertical box.
@export var list_path: NodePath = ^"Panel/Body/Maps"
## Freezes the world while the menu is up, the same way the pause and upgrade
## menus do.
@export var pauses_game: bool = true
## Key that backs out without choosing. The portal is still standing there to be
## used again.
@export var close_action: StringName = &"pause_menu"

@export_group("Entry style")
## Styleboxes the generated buttons wear. The same resources the rest of the
## game's menus use, handed in rather than rebuilt, so the whole UI stays one
## thing.
@export var button_normal: StyleBox
@export var button_hover: StyleBox
@export var button_pressed: StyleBox
@export var button_disabled: StyleBox
@export var font_size: int = 30
@export var font_colour := Color(0.84, 0.76, 0.73)
@export var font_hover_colour := Color(1.0, 0.9, 0.87)
@export var font_disabled_colour := Color(0.4, 0.32, 0.32)
## How a locked entry is written. The map's name and its own locked wording are
## substituted in, in that order.
@export var locked_format: String = "%s  -  %s"

@onready var _list: Container = get_node_or_null(list_path) as Container

var _choosing: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_build()


## The menu the base's portal should open. Null means this world has none, which
## the portal reads as "start the run the way you always did".
static func get_active(from_node: Node) -> MapSelectMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as MapSelectMenu


func is_open() -> bool:
	return visible


## Raises the menu. Called by the portal rather than by a key, so it cannot be
## opened from anywhere the player is not standing.
func open() -> void:
	if visible:
		return

	_choosing = false
	show()
	# Deliberately unfocused, for the same reason the pause and upgrade menus are:
	# the accept key is bound to gameplay too, and a focused button would swallow
	# it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Closes without choosing. [param report] is false only on the way out of a
## choice, where the run is already starting and nothing should be told the
## player backed out.
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


## One button per map in the catalogue, built once. A menu with no catalogue
## offers nothing rather than erroring, so the base still works without one.
func _build() -> void:
	if _list == null or catalog == null:
		return

	for map: MapDefinition in catalog.maps:
		if map == null:
			continue
		_list.add_child(_build_entry(map))


func _build_entry(map: MapDefinition) -> Button:
	var button := Button.new()
	button.text = map.display_name if map.unlocked \
		else locked_format % [map.display_name, map.locked_label]
	button.disabled = not map.unlocked
	# A disabled button does not report mouse events, so the whole row stops
	# reacting rather than only refusing at the last moment.
	button.focus_mode = Control.FOCUS_NONE

	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", font_colour)
	button.add_theme_color_override(&"font_hover_color", font_hover_colour)
	button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	button.add_theme_color_override(&"font_disabled_color", font_disabled_colour)
	if button_normal != null:
		button.add_theme_stylebox_override(&"normal", button_normal)
	if button_hover != null:
		button.add_theme_stylebox_override(&"hover", button_hover)
	if button_pressed != null:
		button.add_theme_stylebox_override(&"pressed", button_pressed)
	if button_disabled != null:
		button.add_theme_stylebox_override(&"disabled", button_disabled)

	if map.unlocked:
		button.pressed.connect(_on_map_pressed.bind(map))
	return button


## Guarded, so a second press while the world is already being taken apart cannot
## start two runs.
func _on_map_pressed(map: MapDefinition) -> void:
	if _choosing or map == null or not map.unlocked:
		return
	_choosing = true

	var session := get_node_or_null(^"/root/RunSession")
	if session != null and session.has_method(&"begin"):
		session.call(&"begin", map.map_id)

	close(false)
	map_chosen.emit(map.map_id)


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
