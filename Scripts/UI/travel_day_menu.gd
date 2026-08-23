class_name TravelDayMenu
extends Control
## The stop at the end of a day on the road: patch yourself up, buy shells, change
## your gun, and then carry on.
##
## [b]It is not a second travel system and it owns no journey.[/b] The ride is
## [TravelDirector]'s from the first day to the arrival; all this is is the screen
## that goes up over the travel transition while the road is standing still, and the
## only thing it reports is that the player wants to move on - see
## [signal continued]. Which day it is, how many are left and what the next one holds
## are none of its business.
##
## [b]It owns no camp systems either.[/b] Every action on it is the camp's own,
## asked to do exactly what it does at the waggon:
##
##   * HEAL is [method CampMenu.heal], so the price, the part-helping rule and the
##     pool being healed are the ones the player has been buying from all run.
##   * AMMO is [method CampMenu.buy_ammo]. Nothing here knows what a shotgun is -
##     which round is for sale, what a box holds and what it costs are the weapon's
##     own answers.
##   * WEAPONS raises [CampWeaponMenu], the same screen the camp raises, which swaps
##     the gun in the player's hands where they stand.
##
## So there is one heal, one shop and one weapon rack in the game, and this is a
## second place to reach them rather than a second copy of them. Anything the camp
## grows later is one more button here.
##
## [b]It only ever freezes the world, never hands it back.[/b] The road is ridden
## behind black with the tree paused, and it is the director that decides when that
## stops - so closing this screen deliberately leaves the pause exactly as it found
## it, and the one thing that is put back is the freeze the weapon screen lifts on
## its way out.

## Emitted when the player asks to move on. [b]The only thing this screen decides.[/b]
signal continued

## Group the screen joins, so the director can find it without a path across the HUD.
const GROUP := &"travel_day_menu"

## Freezes the world while the stop is up. It is already frozen when the screen is
## raised - the ride is made behind black - so this is a guarantee rather than a
## change, and it is what puts the freeze back after the weapon screen has lifted it.
@export var pauses_game: bool = true
## The carried wallet the readout is taken from - the [code]Blood[/code] autoload.
## Deliberately the carried one and not the base's bank, for the same reason the
## camp spends out of it: what is banked is safe from the run, and the road is
## inside the run.
@export var wallet_path: NodePath = ^"/root/Blood"

@export_group("Nodes")
## The column of things that can be done before riding on.
@export var heal_button_path: NodePath = ^"Actions/HealButton"
@export var ammo_button_path: NodePath = ^"Actions/AmmoButton"
@export var weapon_button_path: NodePath = ^"Actions/WeaponButton"
## The one thing on the other side of the screen.
@export var continue_button_path: NodePath = ^"ContinueButton"
## Readout of what there is to spend, so a price on a button can be weighed against
## it without the camp being open. Optional.
@export var blood_label_path: NodePath = ^"Actions/Blood"

@export_group("Wording")
@export var continue_text: String = "CONTINUE TRAVEL"
## How the heal button is written. The price is substituted in.
@export var heal_format: String = "HEAL  -  %d BLOOD"
## What it says once there is nothing to heal.
@export var heal_full_text: String = "HEALTH FULL"
## How the ammunition button is written: what is being bought, then the price.
@export var ammo_format: String = "BUY %s  -  %d BLOOD"
## What it says once the player is carrying all they can.
@export var ammo_full_text: String = "AMMUNITION FULL"
## What it says when there is no weapon to buy for.
@export var ammo_empty_text: String = "NO WEAPON IN HAND"
## How the weapon button is written. What is in hand is substituted in.
@export var weapon_format: String = "WEAPONS  -  %s"
@export var weapon_none_text: String = "EMPTY HANDED"
## How what the player is carrying is written.
@export var blood_format: String = "BLOOD %d"

@onready var _heal_button: Button = get_node_or_null(heal_button_path) as Button
@onready var _ammo_button: Button = get_node_or_null(ammo_button_path) as Button
@onready var _weapon_button: Button = get_node_or_null(weapon_button_path) as Button
@onready var _continue_button: Button = get_node_or_null(continue_button_path) as Button
@onready var _blood_label: Label = get_node_or_null(blood_label_path) as Label

## True from the moment CONTINUE is pressed, so a second press during the fade
## cannot ride two days at once.
var _answered: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()

	if _heal_button != null:
		_heal_button.pressed.connect(_on_heal_pressed)
	if _ammo_button != null:
		_ammo_button.pressed.connect(_on_ammo_pressed)
	if _weapon_button != null:
		_weapon_button.pressed.connect(_on_weapon_pressed)
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue_pressed)


## The screen the director should raise. Null means this world has none, which the
## director reads as "there is nowhere to stop" and rides straight through.
static func get_active(from_node: Node) -> TravelDayMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelDayMenu


func is_open() -> bool:
	return visible


## Raises the stop. Every button is written from the live prices as it goes up,
## because a fight on the road has probably changed all of them.
func open() -> void:
	if visible:
		return

	_answered = false
	_refresh()
	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true


## Takes the stop down. [b]The pause is deliberately left alone[/b] - the road picks
## up behind black with the world still frozen, and it is the director that decides
## when it is handed back.
func close() -> void:
	if not visible:
		return
	hide()
	_drop_focus()


# --- The actions ---------------------------------------------------------------

## The camp, which is where every action on this screen actually happens. Null in a
## world with no camp menu in it, which leaves the stop as its CONTINUE button alone
## rather than stranding the ride.
func _camp() -> CampMenu:
	return CampMenu.get_active(self)


func _on_heal_pressed() -> void:
	var camp := _camp()
	if camp != null:
		camp.heal()
	_refresh()


func _on_ammo_pressed() -> void:
	var camp := _camp()
	if camp != null:
		camp.buy_ammo()
	_refresh()


## Steps aside for the weapon screen and comes back when it closes.
##
## The freeze is put back on the way back in, because [method CampWeaponMenu.close]
## hands the world over as it goes - which is right at the camp, where closing it
## means going back to playing, and wrong here, where the world behind the black must
## stay stopped.
func _on_weapon_pressed() -> void:
	var screen := CampWeaponMenu.get_active(self)
	if screen == null:
		return

	hide()
	_drop_focus()
	if not screen.closed.is_connected(_on_weapon_screen_closed):
		screen.closed.connect(_on_weapon_screen_closed, CONNECT_ONE_SHOT)
	screen.open()


func _on_weapon_screen_closed() -> void:
	if _answered or not is_inside_tree():
		return
	visible = false
	open()


func _on_continue_pressed() -> void:
	if _answered:
		return
	_answered = true
	close()
	continued.emit()


# --- Readouts ------------------------------------------------------------------

## The single place every button on the stop is written, so a price on a button and
## the total beside it can never disagree.
func _refresh() -> void:
	var camp := _camp()
	_refresh_blood()
	_refresh_heal(camp)
	_refresh_ammo(camp)
	_refresh_weapon()
	if _continue_button != null:
		_continue_button.text = continue_text


func _refresh_blood() -> void:
	if _blood_label == null:
		return
	var wallet := get_node_or_null(wallet_path) as BloodWallet
	_blood_label.text = "" if wallet == null else blood_format % wallet.get_total()


func _refresh_heal(camp: CampMenu) -> void:
	if _heal_button == null:
		return
	if camp == null:
		_heal_button.disabled = true
		return

	if camp.get_heal_amount() <= 0.0:
		_heal_button.text = heal_full_text
	else:
		_heal_button.text = heal_format % camp.get_heal_price()
	_heal_button.disabled = not camp.can_heal()


func _refresh_ammo(camp: CampMenu) -> void:
	if _ammo_button == null:
		return
	if camp == null:
		_ammo_button.disabled = true
		return

	var reserve := camp.get_equipped_reserve()
	var type := null if reserve == null else reserve.get_type()
	if reserve == null or type == null:
		_ammo_button.text = ammo_empty_text
		_ammo_button.disabled = true
		return

	var rounds := camp.get_ammo_rounds()
	if rounds <= 0:
		_ammo_button.text = ammo_full_text
		_ammo_button.disabled = true
		return

	_ammo_button.text = ammo_format % [type.format_count(rounds).to_upper(), camp.get_ammo_price()]
	_ammo_button.disabled = not camp.can_buy_ammo()


## What is in the player's hands, named from the roster rather than from the gun, the
## same way the camp names it - so the two screens cannot call one weapon two things.
func _refresh_weapon() -> void:
	if _weapon_button == null:
		return

	var screen := CampWeaponMenu.get_active(self)
	if screen == null:
		_weapon_button.disabled = true
		return

	var name_text := weapon_none_text
	if screen.catalog != null:
		var definition := screen.catalog.find(screen.get_equipped_id())
		if definition != null:
			name_text = definition.display_name
	_weapon_button.text = weapon_format % name_text
	_weapon_button.disabled = false


## Dropped for the same reason the screen opens unfocused - a button that kept focus
## would keep eating the accept key once play resumed.
func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
