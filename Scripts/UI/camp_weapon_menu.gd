class_name CampWeaponMenu
extends Control
## What the player is carrying, changed at the camp.
##
## [b]It is the run-start weapon screen's twin, not a second weapon system.[/b]
## Both build their list from the same [WeaponCatalog], both tell
## [RunSessionState] what was picked, and the difference is only when they are
## allowed to: the run-start screen is answered before a world is built, so the
## [WeaponMount] picks the answer up on its way in, while this is answered in the
## middle of one and asks the mount to swap the weapon there and then - through
## [method WeaponMount.rebuild], which was written for exactly this.
##
## [b]Ammunition is never touched.[/b] Each weapon's rounds live in its own
## [AmmoReserve] in the [code]Ammo[/code] locker, filed under the ammunition it
## feeds on, so putting the shotgun away and picking it back up finds the same
## count - the swap moves which gun is in the player's hands and nothing else.
## Nothing here refills, and nothing here knows what a shotgun is: the count, the
## capacity and the name of a round all come off the weapon's own [AmmoType].
##
## A weapon that has not been unlocked is still listed, drawn dimmed and saying so,
## exactly as a locked map or region is - seeing what is coming is the point.

## Emitted when the player actually changes weapon.
signal weapon_chosen(weapon_id: StringName)
## Emitted as the screen is raised and dropped.
signal opened
signal closed

## Group the screen joins, so the camp can find it without a path across the HUD.
const GROUP := &"camp_weapon_menu"

## The roster. The same resource the run-start screen and the world's mount read,
## so none of the three can disagree about which weapons exist.
@export var catalog: WeaponCatalog
## Where the chosen weapon is stored - the [code]RunSession[/code] autoload.
@export var session_path: NodePath = ^"/root/RunSession"
## The ammunition locker, asked what each weapon is carrying.
@export var locker_path: NodePath = ^"/root/Ammo"
## Freezes the world while the screen is up, the same way every other menu does.
@export var pauses_game: bool = true
## Key that backs out. The camp is still standing behind it.
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
## Container the entries are built into. A vertical box.
@export var list_path: NodePath = ^"Panel/Body/Weapons"
## Optional line under the list.
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"

@export_group("Entry style")
## Styleboxes the generated entries wear - the same resources the rest of the
## game's menus use, handed in rather than rebuilt.
@export var button_normal: StyleBox
@export var button_hover: StyleBox
@export var button_pressed: StyleBox
@export var button_disabled: StyleBox
## What the weapon in the player's hands wears, so which one they are carrying
## reads at a glance. Falls back to the pressed style when none is given.
@export var button_equipped: StyleBox
@export var name_font_size: int = 30
@export var ammo_font_size: int = 20
@export var font_colour := Color(0.16, 0.06, 0.05)
@export var font_hover_colour := Color(0.45, 0.07, 0.06)
@export var font_disabled_colour := Color(0.42, 0.36, 0.3)
## Colour the carried weapon's name is written in.
@export var font_equipped_colour := Color(0.5, 0.08, 0.07)
## Colour of the ammunition line under a weapon's name.
@export var ammo_colour := Color(0.6, 0.42, 0.4)
## Smallest an entry is drawn, in pixels.
@export var entry_size := Vector2(0.0, 76.0)

@export_group("Wording")
## How a weapon's ammunition is written: the count, the capacity, then what the
## round is called.
@export var ammo_format: String = "%d / %d %s"
## What is written for a weapon whose ammunition is not configured.
@export var ammo_unknown_text: String = "NO AMMUNITION"
## Appended to the weapon currently in hand.
@export var equipped_suffix: String = "  -  IN HAND"
## How a locked entry is written: its name, then its own locked wording.
@export var locked_format: String = "%s  -  %s"
## What the footer says.
@export var status_text: String = "EACH WEAPON KEEPS ITS OWN ROUNDS"

@onready var _list: Container = get_node_or_null(list_path) as Container
@onready var _status: Label = get_node_or_null(status_label_path) as Label

var _session: Node
var _locker: AmmoLocker
var _choosing: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_session = get_node_or_null(session_path)
	_locker = get_node_or_null(locker_path) as AmmoLocker


## The screen the camp should open. Null means this world has none, which the camp
## reads as "there is no weapon to change".
static func get_active(from_node: Node) -> CampWeaponMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as CampWeaponMenu


func is_open() -> bool:
	return visible


## Raises the screen, rebuilt from the roster and the live counts - because both
## the weapon in hand and what it is carrying have moved since the last look.
func open() -> void:
	if visible:
		return

	_choosing = false
	_build()
	show()
	# Deliberately unfocused, for the same reason every other menu is.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


func close() -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _choosing:
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


## Which weapon is in the player's hands. Asked of the session rather than of the
## world, so the answer is the same one the mount will build from.
func get_equipped_id() -> StringName:
	var chosen := &""
	if _session != null and _session.has_method(&"get_weapon_id"):
		chosen = _session.call(&"get_weapon_id")
	if chosen != &"" or catalog == null:
		return chosen
	# Nothing chosen yet means the roster's own default is what is being carried.
	var fallback := catalog.get_default()
	return &"" if fallback == null else fallback.weapon_id


## One entry per weapon in the roster, rebuilt rather than patched - three
## weapons times two lines is cheap enough that keeping rows and counts in step is
## not worth the bookkeeping it would take.
func _build() -> void:
	if _list == null:
		return

	for child: Node in _list.get_children():
		child.queue_free()

	if _status != null:
		_status.text = status_text
	if catalog == null:
		return

	var equipped := get_equipped_id()
	for weapon: WeaponDefinition in catalog.weapons:
		if weapon != null:
			_list.add_child(_build_entry(weapon, weapon.weapon_id == equipped))


## A weapon: its name, and under it what it is carrying. Both come off the roster
## entry and the locker, so nothing about a particular weapon is written here.
func _build_entry(weapon: WeaponDefinition, equipped: bool) -> Button:
	var entry := Button.new()
	entry.custom_minimum_size = entry_size
	entry.disabled = not weapon.unlocked
	entry.focus_mode = Control.FOCUS_NONE
	entry.clip_text = true

	var box := VBoxContainer.new()
	box.name = "Text"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.name = "Name"
	title.text = weapon.display_name if weapon.unlocked \
		else locked_format % [weapon.display_name, weapon.locked_label]
	if equipped:
		title.text += equipped_suffix
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", name_font_size)
	var colour := font_colour
	if not weapon.unlocked:
		colour = font_disabled_colour
	elif equipped:
		colour = font_equipped_colour
	title.add_theme_color_override(&"font_color", colour)
	box.add_child(title)

	var rounds := Label.new()
	rounds.name = "Ammo"
	rounds.text = _describe_ammo(weapon)
	rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rounds.add_theme_font_size_override(&"font_size", ammo_font_size)
	rounds.add_theme_color_override(&"font_color", ammo_colour)
	box.add_child(rounds)

	entry.add_child(box)
	_apply_style(entry, equipped)

	if weapon.unlocked and not equipped:
		entry.pressed.connect(_on_weapon_pressed.bind(weapon))
	return entry


## What a weapon is carrying, read off its own ammunition rather than off the gun -
## which is what lets the screen show the rifle's rounds while the shotgun is the
## one in the player's hands.
func _describe_ammo(weapon: WeaponDefinition) -> String:
	if _locker == null or weapon.ammo_type == null:
		return ammo_unknown_text
	var reserve := _locker.get_reserve(weapon.ammo_type)
	if reserve == null:
		return ammo_unknown_text
	return ammo_format % [
		reserve.get_current(), reserve.get_max(),
		weapon.ammo_type.get_plural_name().to_upper()]


## Puts the weapon in the player's hands. Two calls and no more: the session is
## told what they chose, and the world's mount is asked to build it. Ammunition is
## deliberately untouched - see [AmmoReserve], which is where it was already
## waiting.
func _on_weapon_pressed(weapon: WeaponDefinition) -> void:
	if _choosing or weapon == null or not weapon.unlocked:
		return
	_choosing = true

	if _session != null and _session.has_method(&"choose_weapon"):
		_session.call(&"choose_weapon", weapon.weapon_id)

	var mount := WeaponMount.get_active(self)
	if mount != null:
		mount.rebuild()

	_choosing = false
	_build()
	weapon_chosen.emit(weapon.weapon_id)


## The one place an entry's look is decided, so the carried weapon can only ever
## be drawn one way.
func _apply_style(entry: Button, equipped: bool) -> void:
	var resting := button_equipped if equipped and button_equipped != null else button_normal
	if equipped and button_equipped == null:
		resting = button_pressed
	if resting != null:
		entry.add_theme_stylebox_override(&"normal", resting)
	if button_hover != null:
		entry.add_theme_stylebox_override(&"hover", button_hover if not equipped else resting)
	if button_pressed != null:
		entry.add_theme_stylebox_override(&"pressed", button_pressed)
	if button_disabled != null:
		entry.add_theme_stylebox_override(&"disabled", button_disabled)
	entry.add_theme_color_override(&"font_hover_color", font_hover_colour)


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
