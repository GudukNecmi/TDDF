class_name WeaponDebugPanel
extends Control
## Developer panel for one weapon's build: every upgrade level, Card and weapon
## phase that can change how that weapon fights, switched on and off in one list.
##
## [b]It owns nothing.[/b] Each row reads and writes the authority that already
## holds that thing, and the weapon's combat code reads the same authority, so a
## change here is a change the real weapon sees:
##
##   * Upgrade levels go into the weapon's [b]run-only[/b] stack through
##     [method WeaponDefinition.set_run_level] - the same stack a run map market
##     raises. Base levels are shown beside them but never written, no blood is
##     spent, and [RunSessionState] forgets the run stack as a run begins and ends
##     exactly as it forgets a market purchase.
##   * Cards go into and out of the [code]RunCards[/code] autoload through
##     [method RunCardHolder.add_card] and [method RunCardHolder.remove_card]. A Card
##     with no effect built is held and does nothing, as it would from a market.
##   * Legendaries are switched ON and OFF through
##     [method WeaponDefinition.set_legendary_active] - run-only, cleared with the
##     run levels - and listed from [member WeaponDefinition.legendaries]. One that
##     banks pump charge gets a line under it reading the charge off the weapon in
##     the player's hands, with a reset - see [PumpCharge].
##   * Weapon phases are listed only when the weapon has some; nothing here invents
##     one.
##
## Which rows exist is read off data, never named here: the upgrades are whatever
## [member WeaponDefinition.upgrades] lists for [member weapon_id], split into the
## common and Unique sections by [member WeaponUpgrade.unique], and the Cards are
## whatever [member card_pool] deals. Pointing the panel at another weapon is one
## Inspector value.
##
## While it is up the tree is paused, so nothing - combat, enemies, the world
## clock - moves behind it. It puts back whatever paused state it found, so opening
## it over another paused menu does not unpause that menu on the way out.

signal opened
signal closed

## Key that opens and closes the panel.
@export var open_action: StringName = &"weapon_debug"
## Second key that closes it, shared with the pause menu so Escape means "back".
@export var close_action: StringName = &"pause_menu"
@export var pauses_game: bool = true

@export_group("Sources")
## Which weapon's build the panel edits, as [member WeaponDefinition.weapon_id].
@export var weapon_id: StringName = &"shotgun"
## The run's state - the [code]RunSession[/code] autoload - which holds the weapon
## catalogue.
@export var session_path: NodePath = ^"/root/RunSession"
## The run's Card hand - the [code]RunCards[/code] autoload.
@export var card_holder_path: NodePath = ^"/root/RunCards"
## The ammunition locker the weapon's capacity bonus is pushed into after a level
## changes, so a capacity upgrade takes the reserve's ceiling with it.
@export var ammo_locker_path: NodePath = ^"/root/Ammo"
## The Cards on offer - the same product list a run map market deals from, so the
## panel lists exactly the Cards that are authored for play.
@export var card_pool: RunMapMarketProducts

@export_group("Nodes")
@export var rows_path: NodePath = ^"Panel/Body/Scroll/Rows"
@export var title_label_path: NodePath = ^"Panel/Body/Header/Title"
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"

@export_group("Style")
@export var button_normal_style: StyleBox
@export var button_hover_style: StyleBox
@export var button_pressed_style: StyleBox
@export var button_font_color := Color(0.16, 0.06, 0.05)
@export var button_font_size: int = 20
## Padding inside a button, sideways and down - tighter than a menu footer's.
@export var button_padding := Vector2(12.0, 2.0)
## Smallest a button is drawn. The shared button art is a nine-slice with wide
## margins, and a button shorter or narrower than twice them draws no paper at all.
@export var button_min_size := Vector2(96.0, 54.0)
@export var section_color := Color(0.85, 0.11, 0.11)
@export var section_font_size: int = 26
@export var section_spacing: float = 18.0
@export var label_color := Color(0.72, 0.09, 0.1)
@export var label_width: float = 230.0
@export var value_width: float = 260.0
@export var row_font_size: int = 17
## Colour of a row that is active - a level above zero, a Card held.
@export var active_color := Color(0.86, 0.78, 0.72)
## Colour of a row that is off, or a line saying there is nothing to list.
@export var inactive_color := Color(0.5, 0.33, 0.32)
## Colour a Legendary's name is always drawn in, and its readout while it is on.
@export var legendary_color := Color(1.0, 0.72, 0.25)

@export_group("Wording")
## Title, with %s standing for the weapon's display name.
@export var title_format: String = "%s DEBUG"
@export var upgrades_heading: String = "WEAPON UPGRADES"
@export var unique_heading: String = "UNIQUE / LEGENDARY"
@export var cards_heading: String = "CARDS"
@export var phases_heading: String = "WEAPON PHASES"
## Level readout: run level, most, then the Base level it stacks on.
@export var level_format: String = "RUN %d / %d   (BASE %d)"
@export var card_held_format: String = "HELD x%d"
@export var card_not_held_text: String = "NOT HELD"
@export var no_legendary_text: String = "NO LEGENDARY UPGRADES IMPLEMENTED YET"
## Put in front of a Legendary's name, so it reads as one beside the Uniques.
@export var legendary_prefix: String = "[L] "
@export var legendary_on_text: String = "ON  -  LEGENDARY ACTIVE"
@export var legendary_off_text: String = "OFF"
## The line under a Legendary that banks pump charge - see [PumpCharge].
@export var charge_row_label: String = "      PUMP CHARGE"
## Its readout: charge banked, then the most. Read off the weapon in the player's
## hands, since the charge is that weapon's rather than the build's.
@export var charge_format: String = "CHARGE %d / %d"
@export var charge_off_suffix: String = "   (LEGENDARY OFF)"
@export var charge_no_weapon_text: String = "NOT IN HAND"
@export var reset_charge_text: String = "RESET CHARGE"
## Widest the reset button is drawn - it carries more words than the others.
@export var reset_charge_min_width: float = 190.0
@export var no_unique_text: String = "NO UNIQUE UPGRADES FOR THIS WEAPON"
@export var no_cards_text: String = "NO CARDS AUTHORED"
@export var no_phases_text: String = "NO WEAPON PHASES IMPLEMENTED YET"
@export var no_weapon_text: String = "WEAPON NOT FOUND IN THE CATALOGUE"
@export var status_text: String = "RUN-ONLY  -  NO BLOOD SPENT  -  CLEARED WHEN A RUN BEGINS OR ENDS"

@onready var _rows: Container = get_node_or_null(rows_path) as Container
@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _status: Label = get_node_or_null(status_label_path) as Label

## Paused state found on opening, put back on closing.
var _was_paused: bool = false
## One callable per row that rewrites its readout from the authority, so a press
## refreshes the panel without the rows being rebuilt and the scroll jumping.
var _refreshers: Array[Callable] = []
var _tightened: Dictionary = {}


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(open_action):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Builds the rows from the authorities as they stand now, so a reopen always shows
## the live state rather than what the panel last set.
func open() -> void:
	if visible:
		return
	_rebuild()
	show()
	if pauses_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	if _status != null:
		_status.text = status_text
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	_refreshers.clear()
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
	if pauses_game:
		get_tree().paused = _was_paused
	closed.emit()


# --- Building --------------------------------------------------------------------

func _rebuild() -> void:
	_refreshers.clear()
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var weapon := _get_weapon()
	if _title != null:
		_title.text = title_format % (weapon.display_name if weapon != null else String(weapon_id).to_upper())
	if weapon == null:
		_add_note(no_weapon_text)
		return

	var common: Array[WeaponUpgrade] = []
	var uniques: Array[WeaponUpgrade] = []
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade == null:
			continue
		if upgrade.unique:
			uniques.append(upgrade)
		else:
			common.append(upgrade)

	_add_heading(upgrades_heading)
	for upgrade: WeaponUpgrade in common:
		_add_upgrade_row(weapon, upgrade)

	_add_heading(unique_heading)
	if uniques.is_empty():
		_add_note(no_unique_text)
	for upgrade: WeaponUpgrade in uniques:
		_add_upgrade_row(weapon, upgrade)
	if weapon.legendaries.is_empty():
		_add_note(no_legendary_text)
	for legendary: WeaponLegendary in weapon.legendaries:
		if legendary != null:
			_add_legendary_row(weapon, legendary)

	_add_heading(cards_heading)
	var cards := _authored_cards()
	if cards.is_empty():
		_add_note(no_cards_text)
	for card: RunCard in cards:
		_add_card_row(card)

	_add_heading(phases_heading)
	_add_note(no_phases_text)

	_refresh()


func _add_upgrade_row(weapon: WeaponDefinition, upgrade: WeaponUpgrade) -> void:
	var line := _new_line(upgrade.display_name)
	var value := _new_value()
	line.add_child(value)
	line.add_child(_button("OFF", _set_level.bind(weapon, upgrade, 0)))
	line.add_child(_button("-", _step_level.bind(weapon, upgrade, -1)))
	line.add_child(_button("+", _step_level.bind(weapon, upgrade, 1)))
	line.add_child(_button("MAX", _set_level.bind(weapon, upgrade, upgrade.max_level)))
	_rows.add_child(line)

	_refreshers.append(func() -> void:
		var run := weapon.get_run_level(upgrade)
		var base := weapon.get_upgrade_level(upgrade)
		var text := level_format % [run, upgrade.max_level, base]
		var effect := upgrade.describe_level(run + base).replace("\n", ", ")
		if not effect.is_empty() and run + base > 0:
			text += "   " + effect
		_paint(value, text, run > 0))


func _add_legendary_row(weapon: WeaponDefinition, legendary: WeaponLegendary) -> void:
	var line := _new_line(legendary_prefix + legendary.display_name)
	(line.get_child(0) as Label).add_theme_color_override(&"font_color", legendary_color)
	var value := _new_value()
	line.add_child(value)
	line.add_child(_button("ON", _set_legendary.bind(weapon, legendary, true)))
	line.add_child(_button("OFF", _set_legendary.bind(weapon, legendary, false)))
	_rows.add_child(line)

	_refreshers.append(func() -> void:
		var active := weapon.is_legendary_active(legendary)
		var text := legendary_on_text if active else legendary_off_text
		if not legendary.description.is_empty():
			text += "   " + legendary.description
		_paint(value, text, active)
		if active:
			value.add_theme_color_override(&"font_color", legendary_color))

	if legendary.pump_charge != null:
		_add_charge_row(weapon, legendary)


## The charge a [PumpCharge] Legendary has banked in the weapon being carried, and
## the button that drops it. The charge lives on that weapon, not on the build, so
## this reads it there; with the Legendary off the weapon holds none.
func _add_charge_row(weapon: WeaponDefinition, legendary: WeaponLegendary) -> void:
	var line := _new_line(charge_row_label)
	var value := _new_value()
	line.add_child(value)
	var reset := _button(reset_charge_text, _reset_charge.bind(weapon))
	reset.custom_minimum_size.x = maxf(reset.custom_minimum_size.x, reset_charge_min_width)
	line.add_child(reset)
	_rows.add_child(line)

	_refreshers.append(func() -> void:
		var carried := _carried(weapon)
		var active := weapon.is_legendary_active(legendary)
		if carried == null:
			_paint(value, charge_no_weapon_text, false)
			return
		var charge: int = carried.call(&"get_pump_charge")
		var text := charge_format % [charge, maxi(legendary.pump_charge.max_charges, 1)]
		if not active:
			text += charge_off_suffix
		_paint(value, text, active and charge > 0)
		if active and charge > 0:
			value.add_theme_color_override(&"font_color", legendary_color))
func _add_card_row(card: RunCard) -> void:
	var line := _new_line(card.display_name)
	var value := _new_value()
	line.add_child(value)
	line.add_child(_button("ADD", _add_card.bind(card)))
	line.add_child(_button("REMOVE", _remove_card.bind(card)))
	_rows.add_child(line)

	_refreshers.append(func() -> void:
		var holder := _get_card_holder()
		var count := 0 if holder == null else holder.get_count(card)
		var text := card_held_format % count if count > 0 else card_not_held_text
		if not card.description.is_empty():
			text += "   " + card.description
		_paint(value, text, count > 0))


# --- Actions ---------------------------------------------------------------------

func _set_level(weapon: WeaponDefinition, upgrade: WeaponUpgrade, level: int) -> void:
	if weapon.set_run_level(upgrade, level):
		weapon.sync_ammo_capacity(get_node_or_null(ammo_locker_path) as AmmoLocker)
	_refresh()


func _step_level(weapon: WeaponDefinition, upgrade: WeaponUpgrade, step: int) -> void:
	_set_level(weapon, upgrade, weapon.get_run_level(upgrade) + step)


func _set_legendary(weapon: WeaponDefinition, legendary: WeaponLegendary, active: bool) -> void:
	weapon.set_legendary_active(legendary, active)
	_refresh()


func _reset_charge(weapon: WeaponDefinition) -> void:
	var carried := _carried(weapon)
	if carried != null:
		carried.call(&"reset_pump_charge")
	_refresh()


func _add_card(card: RunCard) -> void:
	var holder := _get_card_holder()
	if holder != null:
		holder.add_card(card)
	_refresh()


func _remove_card(card: RunCard) -> void:
	var holder := _get_card_holder()
	if holder != null:
		holder.remove_card(card)
	_refresh()


func _refresh() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()


# --- Pieces ----------------------------------------------------------------------

func _add_heading(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, section_spacing)
	_rows.add_child(spacer)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", section_color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_font_size_override(&"font_size", section_font_size)
	_rows.add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", inactive_color)
	label.add_theme_font_size_override(&"font_size", row_font_size)
	_rows.add_child(label)


func _new_line(title: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(label_width, 0.0)
	label.add_theme_color_override(&"font_color", label_color)
	label.add_theme_font_size_override(&"font_size", row_font_size)
	line.add_child(label)
	return line


func _new_value() -> Label:
	var value := Label.new()
	value.custom_minimum_size = Vector2(value_width, 0.0)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_size_override(&"font_size", row_font_size)
	return value


func _paint(label: Label, text: String, active: bool) -> void:
	label.text = text
	label.tooltip_text = text
	label.add_theme_color_override(&"font_color", active_color if active else inactive_color)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = button_min_size
	button.add_theme_font_size_override(&"font_size", button_font_size)
	button.add_theme_color_override(&"font_color", button_font_color)
	button.add_theme_color_override(&"font_hover_color", button_font_color.lightened(0.2))
	button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	var normal := _tighten(button_normal_style)
	if normal != null:
		button.add_theme_stylebox_override(&"normal", normal)
		button.add_theme_stylebox_override(&"focus", normal)
		button.add_theme_stylebox_override(&"disabled", normal)
	var hover := _tighten(button_hover_style)
	if hover != null:
		button.add_theme_stylebox_override(&"hover", hover)
	var pressed := _tighten(button_pressed_style)
	if pressed != null:
		button.add_theme_stylebox_override(&"pressed", pressed)
	button.pressed.connect(action)
	return button


## A padded-down copy of a shared HUD style, made once - copied so the menus that
## share the original keep their own padding.
func _tighten(style: StyleBox) -> StyleBox:
	if style == null:
		return null
	if _tightened.has(style):
		return _tightened[style]
	var copy := style.duplicate() as StyleBox
	copy.content_margin_left = button_padding.x
	copy.content_margin_right = button_padding.x
	copy.content_margin_top = button_padding.y
	copy.content_margin_bottom = button_padding.y
	_tightened[style] = copy
	return copy


# --- Looking things up -----------------------------------------------------------

func _get_weapon() -> WeaponDefinition:
	var session := get_node_or_null(session_path) as RunSessionState
	if session == null:
		return null
	var catalog := session.get_weapon_catalog()
	return null if catalog == null else catalog.find(weapon_id)


## The weapon in the player's hands, when it was built from [param weapon] and
## can bank pump charge; null otherwise.
func _carried(weapon: WeaponDefinition) -> CarriedWeapon:
	var mount := WeaponMount.get_active(self)
	var carried: CarriedWeapon = null if mount == null else mount.get_weapon()
	if carried == null or carried.definition != weapon or not carried.has_method(&"get_pump_charge"):
		return null
	return carried


func _get_card_holder() -> RunCardHolder:
	return get_node_or_null(card_holder_path) as RunCardHolder


func _authored_cards() -> Array[RunCard]:
	var cards: Array[RunCard] = []
	if card_pool == null:
		return cards
	for card: RunCard in card_pool.cards:
		if card != null:
			cards.append(card)
	return cards
