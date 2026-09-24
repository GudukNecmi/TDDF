class_name TraderMenu
extends Control
## Base pre-run preparation, rule 15 of the run inventory phase: Hearts and
## reserve ammunition, bought before the player ever presses B to depart, and
## delivered straight into the [RunInventory] rather than a second storage.
##
## [b]Opened at the Base's own trader station.[/b] [ShopStation] already
## exists as exactly the marker rule 15 asks for - "a place in the base an
## upgrade will later be sold... whatever the upgrade system turns out to be
## can be hung off [signal ShopStation.player_entered]" - so this hangs off
## the one whose [member ShopStation.shop_id] is [member shop_id] rather than
## adding a node or a script to [code]Shop.tscn[/code], which the other three
## placeholder stations still share untouched.
##
## [b]Reuses the project's existing prices rather than inventing new
## ones.[/b] An ammunition purchase reads its bundle size and cost straight
## off the real [AmmoType] the camp's own ammo shop already prices from - see
## [method AmmoType.cost_for_rounds] - so retuning a round's price in one
## place retunes it here too. Only the room to carry it is new: a purchase
## buys at most one bundle, capped to whatever [method RunInventory.get_room_for_item]
## says still fits, and is priced for exactly that many rounds - never a whole
## bundle charged when only part of one arrived, which is rule 31's "do not
## charge the player and then fail to add the item" and "respect the actual
## remaining capacity" in one rule.
##
## [b]A Heart is priced flat[/b], the same way the camp's own healing is,
## because there is no [AmmoType]-shaped resource behind it to read a price
## from - see rule 7 of the phase, which asks for exactly this and nothing
## cleverer.
##
## [b]What is on the counter is chosen per trader.[/b] [member sells_hearts] and
## [member sells_ammo] take a line off the counter without touching the stock
## behind it, so the Base's trader can sell neither - the Health Bar is the
## default health and RIDE OUT already leaves with every pouch full - while the
## resources stay assigned for the day it sells them again. A trader with nothing
## on it still opens, says [member empty_stock_text] and closes as before.
##
## [b]Its look can be authored in the scene.[/b] When [member stock_path]
## names a container, the counter is laid into it and the title, status and
## blood readout go on labels the scene already has - which is how the Base
## menu's trader wears the same blurred backdrop and panel as its UPGRADE and
## GUNSMITH screens. With no layout authored it builds its own, as it always has.

signal opened
signal closed
## Emitted once a purchase actually lands, with what was bought and what it
## cost.
signal purchased(item_id: StringName, amount: int, cost: int)

const GROUP := &"trader_menu"

## The station this opens at - [member ShopStation.shop_id] on the Base's own
## trader.
@export var station_shop_id: StringName = &"trader"
@export var wallet_path: NodePath = ^"/root/Blood"
@export var inventory_group: StringName = &"run_inventory"
@export var interact_action: StringName = &"interact"
@export var close_action: StringName = &"pause_menu"
@export var pauses_game: bool = true

@export_group("Stock")
## Whether a Heart is on the counter. Off keeps [member heart_cost] but offers
## and sells none.
@export var sells_hearts: bool = true
## Whether the ammunition below is on the counter. Off keeps the three
## [AmmoType]s assigned but offers and sells none of them.
@export var sells_ammo: bool = true
@export var shotgun_ammo: AmmoType
@export var revolver_ammo: AmmoType
@export var lever_ammo: AmmoType
@export var heart_cost: int = 300

@export_group("Wording")
@export var title_text: String = "TRADER"
@export var hint_text: String = "E — TRADE"
@export var heart_format: String = "HEART  -  %d BLOOD"
@export var ammo_format: String = "%s  -  %d BLOOD"
@export var ammo_full_text: String = "%s  -  FULL"
@export var status_text: String = "SUPPLIES BOUGHT HERE GO STRAIGHT INTO THE RUN INVENTORY"
## What the counter says when nothing is on it.
@export var empty_stock_text: String = "NOTHING FOR SALE"
## What the blood readout says, given the readout wallet's total.
@export var blood_format: String = "BANKED %d"

@export_group("Nodes")
## Container the counter is laid into. Left empty, the screen builds its own
## layout and none of the paths below are used.
@export var stock_path: NodePath
@export var title_label_path: NodePath
@export var status_label_path: NodePath
## Label showing the blood in [member blood_wallet_path].
@export var blood_label_path: NodePath
## Wallet the blood readout shows. Empty shows [member wallet_path], the one
## purchases are paid from.
@export var blood_wallet_path: NodePath

var _wallet: BloodWallet
var _inventory: RunInventory
var _station: ShopStation
var _hint: Label
var _heart_button: Button
var _ammo_buttons: Dictionary[AmmoType, Button] = {}
var _blood_label: Label
var _blood_wallet: BloodWallet


func _ready() -> void:
	add_to_group(GROUP)
	_wallet = get_node_or_null(wallet_path) as BloodWallet
	_blood_wallet = _wallet if blood_wallet_path.is_empty() \
		else get_node_or_null(blood_wallet_path) as BloodWallet
	if _blood_wallet != null:
		_blood_wallet.changed.connect(_on_blood_changed)
	_build()
	hide()


static func get_active(from_node: Node) -> TraderMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TraderMenu


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_bind_inventory()
	_refresh()
	show()
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


func _process(_delta: float) -> void:
	if _station == null or not is_instance_valid(_station):
		_station = ShopStation.get_by_id(self, station_shop_id)

	if _hint != null:
		_hint.visible = not visible and _station != null and _station.is_player_present()

	if visible:
		return
	if _station != null and _station.is_player_present():
		return


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if _station != null and _station.is_player_present() and event.is_action_pressed(interact_action):
			open()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


func _bind_inventory() -> void:
	_inventory = RunInventory.get_active(self)
	if _inventory != null and not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)


func _build() -> void:
	var stock := get_node_or_null(stock_path) as Container
	if stock == null:
		stock = _build_default_layout()
	else:
		_set_label(title_label_path, title_text)
		_set_label(status_label_path, status_text)
		_blood_label = get_node_or_null(blood_label_path) as Label

	if sells_hearts:
		_heart_button = Button.new()
		_heart_button.focus_mode = Control.FOCUS_NONE
		_heart_button.pressed.connect(_on_heart_pressed)
		stock.add_child(_heart_button)

	for ammo_type: AmmoType in [shotgun_ammo, revolver_ammo, lever_ammo]:
		if ammo_type == null or not sells_ammo:
			continue
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_ammo_pressed.bind(ammo_type))
		stock.add_child(button)
		_ammo_buttons[ammo_type] = button

	if _heart_button == null and _ammo_buttons.is_empty():
		var empty := Label.new()
		empty.text = empty_stock_text
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock.add_child(empty)

	_hint = Label.new()
	_hint.text = hint_text
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 24
	_hint.offset_bottom = -24
	_hint.offset_top = -60
	add_child(_hint)


## The layout the trader has always built for itself, used wherever the scene
## authors none. Returns the container the counter is laid into.
func _build_default_layout() -> Container:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -220
	root.offset_top = -160
	root.offset_right = 220
	root.offset_bottom = 160
	root.add_theme_constant_override(&"separation", 10)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.02, 0.02, 0.86)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	move_child(backdrop, 0)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override(&"font_size", 28)
	root.add_child(title)

	var stock := VBoxContainer.new()
	stock.add_theme_constant_override(&"separation", 10)
	root.add_child(stock)

	var status := Label.new()
	status.text = status_text
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	return stock


func _set_label(path: NodePath, text: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = text


func _refresh_blood() -> void:
	if _blood_label != null:
		_blood_label.text = blood_format % (0 if _blood_wallet == null else _blood_wallet.get_total())


func _on_blood_changed(_total: int) -> void:
	if visible:
		_refresh_blood()


# --- Hearts ------------------------------------------------------------

func can_buy_heart() -> bool:
	if not sells_hearts:
		return false
	if _inventory == null or not _inventory.can_add_item(&"heart"):
		return false
	return _wallet != null and _wallet.can_afford(heart_cost)


func buy_heart() -> bool:
	if not can_buy_heart():
		return false
	if not _wallet.spend(heart_cost):
		return false
	_inventory.add_heart(1)
	purchased.emit(&"heart", 1, heart_cost)
	_refresh()
	return true


# --- Ammunition ----------------------------------------------------------

## How many rounds of [param ammo_type] one purchase would hand over: one
## bundle, or only what is left to fill - the same shape
## [method AmmoLocker.purchasable_rounds] already uses for the camp's ammo
## shop.
func get_purchasable_rounds(ammo_type: AmmoType) -> int:
	if ammo_type == null or _inventory == null:
		return 0
	var max_stack := _inventory.get_ammo_max_stack(ammo_type)
	var room := _inventory.get_room_for_item(ammo_type.id, max_stack)
	return mini(maxi(ammo_type.purchase_bundle, 0), room)


func get_purchase_price(ammo_type: AmmoType) -> int:
	if ammo_type == null:
		return 0
	var rounds := get_purchasable_rounds(ammo_type)
	if rounds >= maxi(ammo_type.purchase_bundle, 0):
		return ammo_type.purchase_cost
	return ammo_type.cost_for_rounds(rounds)


func can_buy_ammo(ammo_type: AmmoType) -> bool:
	if not sells_ammo:
		return false
	if get_purchasable_rounds(ammo_type) <= 0:
		return false
	return _wallet != null and _wallet.can_afford(get_purchase_price(ammo_type))


## Buys as much of one bundle of [param ammo_type] as the run inventory has
## room for. Blood is only ever spent once the rounds are known to fit - see
## the class doc - so a purchase can never be charged for and then fail to
## arrive.
func buy_ammo(ammo_type: AmmoType) -> int:
	if not can_buy_ammo(ammo_type):
		return 0

	var rounds := get_purchasable_rounds(ammo_type)
	var cost := get_purchase_price(ammo_type)
	if not _wallet.spend(cost):
		return 0

	var added := _inventory.add_ammo(ammo_type, rounds)
	purchased.emit(ammo_type.id, added, cost)
	_refresh()
	return added


func _on_heart_pressed() -> void:
	buy_heart()


func _on_ammo_pressed(ammo_type: AmmoType) -> void:
	buy_ammo(ammo_type)


func _refresh() -> void:
	_refresh_blood()
	if _heart_button != null:
		_heart_button.text = heart_format % heart_cost
		_heart_button.disabled = not can_buy_heart()

	for ammo_type: AmmoType in _ammo_buttons:
		var button: Button = _ammo_buttons[ammo_type]
		var rounds := get_purchasable_rounds(ammo_type)
		if rounds <= 0:
			button.text = ammo_full_text % ammo_type.get_plural_name().to_upper()
			button.disabled = true
			continue
		button.text = ammo_format % [
			"%d %s" % [rounds, ammo_type.get_plural_name().to_upper()], get_purchase_price(ammo_type)]
		button.disabled = not can_buy_ammo(ammo_type)


func _on_inventory_changed() -> void:
	if visible:
		_refresh()


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
