class_name WeaponSelectMenu
extends Control
## Where the player chooses what they are taking with them. The first of the two
## questions the base's pit asks before a run: what, then where.
##
## It is [MapSelectMenu] with a different roster, deliberately - same group
## lookup, same generated buttons, same styleboxes handed in from the inspector,
## same "choose one thing and report it" contract - so the two screens behave
## identically and are retuned together. The list is generated from a
## [WeaponCatalog], so a third weapon is one entry in a resource and nothing in
## this file names a single weapon.
##
## A locked weapon is still listed, drawn dimmed and unpressable, for the same
## reason a locked map is: seeing what is coming is the point.
##
## Choosing does two things and stops: it tells [RunSessionState] what the player
## is carrying, and it reports [signal weapon_chosen]. What happens next - the map
## screen, the camera pulling out, the world being rebuilt - belongs to the
## [RunPortal] that opened this, which is what keeps the whole run transition in
## one place instead of scattered across the screens it passes through.

## Emitted when the player picks a weapon that can actually be taken.
signal weapon_chosen(weapon_id: StringName)
## Emitted when the screen is closed without a choice, so whatever opened it can
## put itself back the way it was.
signal cancelled
signal opened

## Group the screen joins, so the base's portal can find it without a path across
## the scene.
const GROUP := &"weapon_select_menu"

## The weapons on offer, in order.
@export var catalog: WeaponCatalog
## Container the entries are built into. A vertical box.
@export var list_path: NodePath = ^"Panel/Body/Weapons"
## Freezes the world while the screen is up, the same way every other menu does.
@export var pauses_game: bool = true
## Key that backs out without choosing.
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
## How an entry with a description under it is written. The weapon's name and its
## description are substituted in, in that order.
@export var described_format: String = "%s\n%s"
## How a locked entry is written.
@export var locked_format: String = "%s  -  %s"

@onready var _list: Container = get_node_or_null(list_path) as Container

var _choosing: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_build()


## The screen the base's portal should open. Null means this world has none, which
## the portal reads as "do not ask, just use whatever is already equipped".
static func get_active(from_node: Node) -> WeaponSelectMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WeaponSelectMenu


func is_open() -> bool:
	return visible


## Raises the screen. Called by the portal rather than by a key, so it cannot be
## opened from anywhere the player is not standing.
func open() -> void:
	if visible:
		return

	_choosing = false
	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Closes without choosing. [param report] is false only on the way out of a
## choice, where the next screen is already opening and nothing should be told the
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


## One button per weapon in the catalogue, built once. A screen with no catalogue
## offers nothing rather than erroring.
func _build() -> void:
	if _list == null or catalog == null:
		return

	for weapon: WeaponDefinition in catalog.weapons:
		if weapon == null:
			continue
		_list.add_child(_build_entry(weapon))


func _build_entry(weapon: WeaponDefinition) -> Button:
	var button := Button.new()
	button.text = _entry_text(weapon)
	button.disabled = not weapon.unlocked
	# A disabled button does not report mouse events, so the whole row stops
	# reacting rather than only refusing at the last moment.
	button.focus_mode = Control.FOCUS_NONE
	if weapon.icon != null:
		button.icon = weapon.icon
		button.expand_icon = true

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

	if weapon.unlocked:
		button.pressed.connect(_on_weapon_pressed.bind(weapon))
	return button


func _entry_text(weapon: WeaponDefinition) -> String:
	if not weapon.unlocked:
		return locked_format % [weapon.display_name, weapon.locked_label]
	if weapon.description.is_empty():
		return weapon.display_name
	return described_format % [weapon.display_name, weapon.description]


## Guarded, so a second press while the next screen is opening cannot choose
## twice.
func _on_weapon_pressed(weapon: WeaponDefinition) -> void:
	if _choosing or weapon == null or not weapon.unlocked:
		return
	_choosing = true

	var session := get_node_or_null(^"/root/RunSession")
	if session != null and session.has_method(&"choose_weapon"):
		session.call(&"choose_weapon", weapon.weapon_id)

	close(false)
	weapon_chosen.emit(weapon.weapon_id)


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
