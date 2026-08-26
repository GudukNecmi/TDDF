class_name TestSpawnMenu
extends Control
## The screen behind the test map's spawn station: everything the game can put on
## the ground, one button each, and a control that takes it all away again.
##
## It is [WeaponSelectMenu] with a different roster, deliberately - same group
## lookup, same generated buttons, same styleboxes handed in from the inspector, same
## "choose one thing and report it" contract - so it looks and behaves like the rest
## of the game's screens rather than like a debug window bolted on.
##
## [b]It builds nothing and knows nothing.[/b] The list is handed to it by
## [TestSpawnStation], which is where the world is actually read; this reports an
## index back and stops. That is what keeps the roster discovered in one place
## instead of half here and half there.
##
## [b]It has two states, and the second is the point.[/b] Choosing something does not
## close the screen, it [i]minimises[/i] it: the panel goes away, the game unpauses,
## and a slim banner along the bottom says what is being placed and how to stop. The
## banner is deliberately transparent to the mouse - see [method minimise] - because
## the click that follows belongs to the map, not to this.

## Emitted when something in the list is picked, with its index into the array that
## was handed to [method open].
signal entry_chosen(index: int)
## Emitted when the clear control is pressed.
signal clear_requested
## Emitted when the screen is closed without a choice.
signal cancelled
signal opened

## Group the screen joins, so the station can find it without a path across the
## scene.
const GROUP := &"test_spawn_menu"

## Container the entries are built into. A vertical box, usually inside a scroller.
@export var list_path: NodePath = ^"Panel/Body/Scroll/Entries"
## The half of the screen that is the actual panel, hidden while placing.
@export var panel_path: NodePath = ^"Panel"
## What is behind the panel. Hidden with it.
@export var blur_path: NodePath = ^"Blur"
## The slim bar shown instead while something is being placed.
@export var banner_path: NodePath = ^"Banner"
## Label inside that bar.
@export var banner_label_path: NodePath = ^"Banner/Panel/Text"
## The control that empties the map.
@export var clear_button_path: NodePath = ^"Panel/Body/Footer/ClearButton"
## Line under the list, used to report what a clear did.
@export var hint_path: NodePath = ^"Panel/Body/Footer/Hint"
## Freezes the world while the panel is up, the same way every other menu does. It is
## released again the moment the screen minimises, because placing happens in a
## running world.
@export var pauses_game: bool = true
## Key that backs out without choosing.
@export var close_action: StringName = &"pause_menu"

@export_group("Wording")
## How the clear control is written. The number standing is substituted in.
@export var clear_format: String = "CLEAR SPAWNED  (%d)"
## How the banner is written: what is being placed.
@export var banner_format: String = "PLACING  %s      LEFT CLICK TO PLACE      RIGHT CLICK OR ESC TO STOP"
## The resting line under the list.
@export var hint_text: String = "DEVELOPER ONLY  ·  NOTHING HERE TOUCHES A RUN"
## How a finished clear is reported on that line.
@export var cleared_format: String = "REMOVED %d"

@export_group("Entry style")
## Styleboxes the generated buttons wear. The same resources the rest of the game's
## menus use, handed in rather than rebuilt, so the whole UI stays one thing.
@export var button_normal: StyleBox
@export var button_hover: StyleBox
@export var button_pressed: StyleBox
@export var button_disabled: StyleBox
@export var font_size: int = 24
@export var font_colour := Color(0.84, 0.76, 0.73)
@export var font_hover_colour := Color(1.0, 0.9, 0.87)

@onready var _list: Container = get_node_or_null(list_path) as Container
@onready var _panel: CanvasItem = get_node_or_null(panel_path) as CanvasItem
@onready var _blur: CanvasItem = get_node_or_null(blur_path) as CanvasItem
@onready var _banner: CanvasItem = get_node_or_null(banner_path) as CanvasItem
@onready var _banner_label: Label = get_node_or_null(banner_label_path) as Label
@onready var _clear_button: Button = get_node_or_null(clear_button_path) as Button
@onready var _hint: Label = get_node_or_null(hint_path) as Label

var _choosing: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_show_banner(false)
	if _clear_button != null and not _clear_button.pressed.is_connected(_on_clear_pressed):
		_clear_button.pressed.connect(_on_clear_pressed)


## The screen the station should open. Null means this world has none, which the
## station reads as "there is nothing to open".
static func get_active(from_node: Node) -> TestSpawnMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TestSpawnMenu


func is_open() -> bool:
	return visible


## Whether the screen is up but out of the way, with something being placed.
func is_minimised() -> bool:
	return visible and _panel != null and not _panel.visible


## Raises the screen on [param entries], rebuilding the list from scratch.
##
## [param spawned] is how many test spawns are standing, so the clear control can say
## so. It is passed in rather than counted here for the same reason the list is: the
## world is read in one place.
func open(entries: Array[TestSpawnEntry], spawned: int = 0) -> void:
	_choosing = false
	_build(entries)
	_set_clear_count(spawned)
	_set_hint(hint_text)

	show()
	_show_banner(false)
	_show_panel(true)
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Puts the screen out of the way so the map underneath can be worked on: the panel
## goes, the world runs again, and a bar along the bottom says what is happening.
##
## [b]The bar cannot be clicked.[/b] Everything in it is left transparent to the
## mouse in the scene, so the click that places a man passes straight through to the
## world. A banner that swallowed clicks would make the bottom strip of the map
## unplaceable, which is exactly the sort of thing a placement mode must not do.
func minimise(label: String) -> void:
	if not visible:
		show()

	_choosing = false
	_show_panel(false)
	_show_banner(true)
	if _banner_label != null:
		_banner_label.text = banner_format % label
	_drop_focus()
	if pauses_game:
		get_tree().paused = false


## Closes the screen entirely. [param report] is false on the way out of a choice,
## where nothing should be told the player backed out.
func close(report: bool = true) -> void:
	if not visible:
		return

	hide()
	_show_banner(false)
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	if report:
		cancelled.emit()


## Told what a clear actually did, so the button and the line under the list read the
## world rather than what the screen assumed.
func report_cleared(removed: int, remaining: int) -> void:
	_set_clear_count(remaining)
	_set_hint(cleared_format % removed)


func _unhandled_input(event: InputEvent) -> void:
	# Only the panel answers the back key. While minimised the press belongs to
	# [TestPlacer], which is what actually has something to cancel.
	if not visible or _choosing or is_minimised():
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


## One button per entry, rebuilt on every open. A screen handed nothing shows an
## empty list rather than erroring.
func _build(entries: Array[TestSpawnEntry]) -> void:
	if _list == null:
		return

	for child: Node in _list.get_children():
		child.queue_free()

	for index: int in entries.size():
		var entry := entries[index]
		if entry == null:
			continue
		_list.add_child(_build_entry(entry, index))


func _build_entry(entry: TestSpawnEntry, index: int) -> Button:
	var button := Button.new()
	button.text = entry.label
	# A focused button would swallow the accept key, which is bound to gameplay too -
	# the same reason every other generated menu in the game drops focus.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", font_size)
	button.add_theme_color_override(&"font_color", font_colour)
	button.add_theme_color_override(&"font_hover_color", font_hover_colour)
	button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	if button_normal != null:
		button.add_theme_stylebox_override(&"normal", button_normal)
	if button_hover != null:
		button.add_theme_stylebox_override(&"hover", button_hover)
	if button_pressed != null:
		button.add_theme_stylebox_override(&"pressed", button_pressed)
	if button_disabled != null:
		button.add_theme_stylebox_override(&"disabled", button_disabled)

	button.pressed.connect(_on_entry_pressed.bind(index))
	return button


## Guarded, so a second press while the screen is minimising cannot choose twice.
func _on_entry_pressed(index: int) -> void:
	if _choosing:
		return
	_choosing = true
	entry_chosen.emit(index)
	_choosing = false


func _on_clear_pressed() -> void:
	clear_requested.emit()


func _set_clear_count(count: int) -> void:
	if _clear_button != null:
		_clear_button.text = clear_format % count


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


func _show_panel(shown: bool) -> void:
	if _panel != null:
		_panel.visible = shown
	if _blur != null:
		_blur.visible = shown


func _show_banner(shown: bool) -> void:
	if _banner != null:
		_banner.visible = shown


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
