class_name BaseUpgradeScreen
extends Control
## The Base menu's UPGRADE screen: one [UpgradeCard] per [BaseUpgrade], each
## showing its level, what the next step does and what it costs, paid for out of
## the blood banked in the pool.
##
## [b]It sells, it does not keep.[/b] Every level is read back off the system the
## upgrade belongs to and every purchase goes through [method BaseUpgrade.purchase]
## into that system - the Bounty Board's capacity through
## [method BountyLedger.upgrade_capacity], a weapon's upgrades through
## [method WeaponDefinition.raise_upgrade] - so there is no second record of what
## has been bought that could drift from the real one. The cards are the arena
## shop's own [UpgradeCard], so the two shops look the same.
##
## The cards are split across tabs: the Base's own upgrades in [member upgrades],
## then one tab per owned weapon in [member weapon_catalog] showing the
## [WeaponUpgrade]s that weapon lists. The screen has no idea what any of them do.

signal opened
signal closed
## Emitted when a step is actually bought.
signal upgrade_bought(upgrade: BaseUpgrade, cost: int)

## Group the screen joins, which is what the Base menu's UPGRADE line names.
const GROUP := &"base_upgrade_menu"
## The tab holding [member upgrades] rather than a weapon's.
const BASE_TAB := &""

## The Base's own upgrades, in the order the cards are laid out on the first tab.
@export var upgrades: Array[BaseUpgrade] = []
## The weapon roster. Every owned weapon gets a tab of its own upgrades; left
## empty, the screen is the Base tab alone.
@export var weapon_catalog: WeaponCatalog
## Scene one card is built from.
@export var card_scene: PackedScene
## Scene one tab button is built from. Left empty, no tab row is drawn.
@export var tab_scene: PackedScene
## What a purchase is paid out of - the blood banked in the pool.
@export var wallet_path: NodePath = ^"/root/BloodBank"
## Freezes the world while the screen is up, the same way the base's other
## screens do.
@export var pauses_game: bool = true
## Key that closes it, as it does every other base screen.
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
@export var cards_path: NodePath = ^"Panel/Body/Scroll/Cards"
@export var tabs_path: NodePath = ^"Panel/Body/Tabs"
@export var blood_label_path: NodePath = ^"Panel/Body/Header/Blood"

@export_group("Wording")
@export var blood_format: String = "BANKED %d"
## What a fully upgraded card reads instead of a price.
@export var maxed_text: String = "MAXED"
## What the Base's own tab is called.
@export var base_tab_text: String = "BASE"
## Minimum size each Base card is built at, so the detail line has room.
@export var card_size := Vector2(240.0, 330.0)
## Minimum size each weapon card is built at - smaller, since a weapon has many.
@export var weapon_card_size := Vector2(200.0, 290.0)
## Title size on a weapon card, so the longer names fit. 0 leaves it as authored.
@export var weapon_card_title_font_size: int = 22

@onready var _cards_box: Container = get_node_or_null(cards_path) as Container
@onready var _tabs_box: Container = get_node_or_null(tabs_path) as Container
@onready var _blood_label: Label = get_node_or_null(blood_label_path) as Label

var _wallet: BloodWallet
## Which tab is showing: [constant BASE_TAB] or a weapon id.
var _tab: StringName = BASE_TAB
## The cards each weapon sells, built once per weapon and kept, by weapon id.
var _weapon_upgrades: Dictionary[StringName, Array] = {}


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_wallet = get_node_or_null(wallet_path) as BloodWallet
	if _wallet != null:
		_wallet.changed.connect(_on_wallet_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_build()
	show()
	get_viewport().gui_release_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	get_viewport().gui_release_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


## Shows [param tab] - [constant BASE_TAB] or an owned weapon's id.
func show_tab(tab: StringName) -> void:
	_tab = tab
	_build()


func get_tab() -> StringName:
	return _tab


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


## Rebuilt from scratch whenever something changes, so every card always shows
## what its system says now rather than what it said when the screen opened.
func _build() -> void:
	var total := 0 if _wallet == null else _wallet.get_total()
	if _blood_label != null:
		_blood_label.text = blood_format % total
	var weapons := _owned_weapons()
	var weapon := _find_weapon(weapons, _tab)
	if weapon == null:
		_tab = BASE_TAB
	_build_tabs(weapons)
	if _cards_box == null or card_scene == null:
		return

	for child: Node in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()

	var on_sale: Array = upgrades
	var card_min := card_size
	var title_size := 0
	if weapon != null:
		on_sale = _upgrades_for(weapon)
		card_min = weapon_card_size
		title_size = weapon_card_title_font_size

	for upgrade: BaseUpgrade in on_sale:
		if upgrade == null:
			continue
		var card := card_scene.instantiate() as UpgradeCard
		if card == null:
			continue
		card.custom_minimum_size = card_min
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.title_text = upgrade.display_name
		card.title_font_size = title_size
		card.detail_text = "%s\n\n%s" % [upgrade.get_level_text(self), upgrade.get_effect_text(self)]
		card.bought_text = maxed_text
		var cost := upgrade.get_next_cost(self)
		card.cost = maxi(cost, 0)
		_cards_box.add_child(card)
		if cost < 0:
			card.mark_bought()
		else:
			card.set_affordable(total >= cost)
		card.buy_requested.connect(_on_buy_requested.bind(upgrade))


## One tab for the Base and one per owned weapon, the showing one held down.
func _build_tabs(weapons: Array[WeaponDefinition]) -> void:
	if _tabs_box == null:
		return
	for child: Node in _tabs_box.get_children():
		_tabs_box.remove_child(child)
		child.queue_free()
	_tabs_box.visible = tab_scene != null and not weapons.is_empty()
	if not _tabs_box.visible:
		return

	_add_tab(base_tab_text, BASE_TAB)
	for weapon: WeaponDefinition in weapons:
		_add_tab(weapon.display_name, weapon.weapon_id)


func _add_tab(text: String, tab: StringName) -> void:
	var button := tab_scene.instantiate() as Button
	if button == null:
		return
	button.text = text
	button.name = "Tab_%s" % ("base" if tab == BASE_TAB else String(tab))
	button.toggle_mode = true
	button.button_pressed = tab == _tab
	button.pressed.connect(show_tab.bind(tab))
	_tabs_box.add_child(button)


## The weapons the player owns, in roster order - only those can be upgraded.
func _owned_weapons() -> Array[WeaponDefinition]:
	var owned: Array[WeaponDefinition] = []
	if weapon_catalog == null:
		return owned
	for weapon: WeaponDefinition in weapon_catalog.weapons:
		if weapon != null and weapon.is_owned() and not weapon.upgrades.is_empty():
			owned.append(weapon)
	return owned


func _find_weapon(weapons: Array[WeaponDefinition], weapon_id: StringName) -> WeaponDefinition:
	if weapon_id == BASE_TAB:
		return null
	for weapon: WeaponDefinition in weapons:
		if weapon.weapon_id == weapon_id:
			return weapon
	return null


## A card per upgrade [param weapon] lists, each selling into that weapon.
func _upgrades_for(weapon: WeaponDefinition) -> Array:
	if not _weapon_upgrades.has(weapon.weapon_id):
		var made: Array = []
		for upgrade: WeaponUpgrade in weapon.upgrades:
			if upgrade != null:
				made.append(WeaponStatUpgrade.create(weapon, upgrade))
		_weapon_upgrades[weapon.weapon_id] = made
	return _weapon_upgrades[weapon.weapon_id]


func _on_buy_requested(_card: UpgradeCard, upgrade: BaseUpgrade) -> void:
	var cost := upgrade.get_next_cost(self)
	if upgrade.purchase(self, _wallet):
		upgrade_bought.emit(upgrade, cost)
	_build()


func _on_wallet_changed(_total: int) -> void:
	if visible:
		_build()
