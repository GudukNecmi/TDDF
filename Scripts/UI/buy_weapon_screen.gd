class_name BuyWeaponScreen
extends Control
## The Base menu's BUY WEAPON screen: one [UpgradeCard] per weapon in the
## [WeaponCatalog], showing what it is, what it feeds on and what it costs, paid
## for out of the blood banked in the pool.
##
## [b]It sells, it does not keep.[/b] Owning a weapon is the weapon's own
## [member WeaponDefinition.unlocked] - the same flag the SELECT WEAPON screen
## already reads - and a purchase goes through [method WeaponDefinition.purchase],
## so there is no second record of what has been bought. The roster, the names and
## the prices all come from the catalogue, so a new weapon for sale is a
## [code].tres[/code] with a [member WeaponDefinition.purchase_cost] and nothing
## here changes.
##
## It is laid out and behaves exactly as [BaseUpgradeScreen] does, cards and all,
## so the base's two shops look and close the same way.

signal opened
signal closed
## Emitted when a weapon is actually bought.
signal weapon_bought(weapon: WeaponDefinition, cost: int)

## Group the screen joins, which is what the Base menu's BUY WEAPON line names.
const GROUP := &"buy_weapon_menu"

## The weapons on offer, in order - the same roster SELECT WEAPON lists.
@export var catalog: WeaponCatalog
## Scene one card is built from.
@export var card_scene: PackedScene
## What a purchase is paid out of - the blood banked in the pool.
@export var wallet_path: NodePath = ^"/root/BloodBank"
## Freezes the world while the screen is up, the same way the base's other
## screens do.
@export var pauses_game: bool = true
## Key that closes it, as it does every other base screen.
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
@export var cards_path: NodePath = ^"Panel/Body/Cards"
@export var blood_label_path: NodePath = ^"Panel/Body/Header/Blood"

@export_group("Wording")
@export var blood_format: String = "BANKED %d"
## What an owned weapon's card reads instead of a price.
@export var owned_text: String = "OWNED"
## How the ammunition line under a weapon's description is written. The ammo
## type's plural name is substituted in.
@export var ammo_format: String = "AMMO: %s"
## Minimum size each card is built at, so the description has room.
@export var card_size := Vector2(260.0, 360.0)
## How far an owned card is faded. Lighter than a spent upgrade, so OWNED stays
## readable.
@export_range(0.0, 1.0) var owned_alpha: float = 0.6

@onready var _cards_box: Container = get_node_or_null(cards_path) as Container
@onready var _blood_label: Label = get_node_or_null(blood_label_path) as Label

var _wallet: BloodWallet


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


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


## Rebuilt from scratch whenever something changes, so every card always shows
## what the weapon says now rather than what it said when the screen opened.
func _build() -> void:
	var total := 0 if _wallet == null else _wallet.get_total()
	if _blood_label != null:
		_blood_label.text = blood_format % total
	if _cards_box == null or card_scene == null or catalog == null:
		return

	for child: Node in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()

	for weapon: WeaponDefinition in catalog.weapons:
		if weapon == null:
			continue
		var card := card_scene.instantiate() as UpgradeCard
		if card == null:
			continue
		card.custom_minimum_size = card_size
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.title_text = weapon.display_name
		card.detail_text = _detail_text(weapon)
		card.bought_text = owned_text
		card.bought_alpha = owned_alpha
		card.cost = maxi(weapon.purchase_cost, 0)
		_cards_box.add_child(card)
		if weapon.is_owned():
			card.mark_bought()
		else:
			card.set_affordable(total >= weapon.purchase_cost)
		card.buy_requested.connect(_on_buy_requested.bind(weapon))


func _detail_text(weapon: WeaponDefinition) -> String:
	var lines: PackedStringArray = []
	if not weapon.description.is_empty():
		lines.append(weapon.description)
	if weapon.ammo_type != null:
		lines.append(ammo_format % weapon.ammo_type.get_plural_name().to_upper())
	return "\n\n".join(lines)


func _on_buy_requested(_card: UpgradeCard, weapon: WeaponDefinition) -> void:
	var cost := weapon.purchase_cost
	if weapon.purchase(_wallet):
		weapon_bought.emit(weapon, cost)
	_build()


func _on_wallet_changed(_total: int) -> void:
	if visible:
		_build()
