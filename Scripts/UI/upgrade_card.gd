class_name UpgradeCard
extends PanelContainer
## One of the cards offered between rounds.
##
## A card is a price and a slot, and deliberately nothing else. There is no
## effect here, no stat and no name - what an upgrade actually *does* has not been
## decided, and inventing a shape for it now would be something to unpick later.
## What this does own is the whole of the presentation: what it costs, whether
## the player can afford it, and what it looks like once it has been bought.
##
## It never touches a wallet. Pressing BUY reports [signal buy_requested] and
## stops there; [UpgradeMenu] owns the money, so the one place that decides
## whether a purchase goes through is the one place that takes the blood.

## Emitted when the player asks to buy this card. Whether they can is not this
## node's decision.
signal buy_requested(card: UpgradeCard)

## The price, in blood.
@export var cost: int = 500:
	set(value):
		cost = value
		_refresh()
## How the price is written. The count is substituted in, so the currency can be
## renamed without touching code.
@export var cost_format: String = "%d BLOOD"
## What an unbought card is called. A placeholder on purpose - see above.
@export var placeholder_title: String = "???"
## What a bought card reads instead of its price.
@export var bought_text: String = "BOUGHT"

@export_group("Nodes")
@export var title_label_path: NodePath = ^"Layout/Title"
@export var cost_label_path: NodePath = ^"Layout/Cost"
@export var buy_button_path: NodePath = ^"Layout/BuyButton"

@export_group("Appearance")
## How far the card is faded when its price is out of reach, so an unaffordable
## card reads as out of reach at a glance rather than only on being pressed.
@export_range(0.0, 1.0) var unaffordable_alpha: float = 0.45
## How far a card that has already been bought is faded.
@export_range(0.0, 1.0) var bought_alpha: float = 0.3

@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _cost: Label = get_node_or_null(cost_label_path) as Label
@onready var _buy: Button = get_node_or_null(buy_button_path) as Button

var _affordable: bool = true
var _bought: bool = false


func _ready() -> void:
	if _buy != null:
		_buy.pressed.connect(_on_buy_pressed)
	_refresh()


func is_bought() -> bool:
	return _bought


## Whether the player can currently afford this card. Told to it rather than
## looked up, so the card needs no idea where the money lives.
func set_affordable(affordable: bool) -> void:
	if affordable == _affordable:
		return
	_affordable = affordable
	_refresh()


## Marks the card spent. It stays on the table rather than disappearing, so the
## player can see what they already took this round.
func mark_bought() -> void:
	if _bought:
		return
	_bought = true
	_refresh()


func _on_buy_pressed() -> void:
	if _bought:
		return
	buy_requested.emit(self)


## The single place the card's look is decided, so its three states cannot get
## out of step with each other.
func _refresh() -> void:
	if _title != null:
		_title.text = placeholder_title

	if _cost != null:
		_cost.text = bought_text if _bought else cost_format % cost

	if _buy != null:
		_buy.disabled = _bought or not _affordable

	var alpha := 1.0
	if _bought:
		alpha = bought_alpha
	elif not _affordable:
		alpha = unaffordable_alpha
	modulate.a = alpha
