class_name LootRewardCard
extends Button
## One reward on the Loot Screen's table - the reusable card every kind of
## reward is dealt as unless its [LootRewardLook] names a card of its own.
##
## [b]It shows a [LootReward] and nothing else.[/b] Its lettering is the reward's
## own ([method LootReward.get_title] and the rest), its colours are the
## reward's look, and a click is reported as [signal chosen] for the screen to
## activate - the card never learns what the reward is or does. A card made for
## one kind of reward (a charm with its artwork, a question-mark card that flips)
## extends this and overrides [method refresh].
##
## It is a [Button] - flat, with no lettering of its own - so the game's pointer
## shows its hover art over it and the card takes clicks like every other button.

## The card was clicked while it could be taken.
signal chosen(card: LootRewardCard)

## The card's size on the table.
@export var card_size: Vector2 = Vector2(110.0, 146.0):
	set(value):
		card_size = value
		custom_minimum_size = value
		size = value
## The face's frame - duplicated per card and tinted from the reward's look.
@export var face_style: StyleBoxFlat
## How much bigger the card is drawn under the mouse, and how fast it gets there.
@export var hover_scale: float = 1.08
@export var hover_time: float = 0.1
## How a card that is done with is drawn.
@export var resolved_modulate: Color = Color(0.55, 0.5, 0.5, 0.85)
## How a card that cannot be clicked right now is drawn.
@export var locked_modulate: Color = Color(0.8, 0.78, 0.78, 1)
## How much of [LootLayout]'s scatter - the small random nudge of place, timing
## and flight - this card takes, 0..1. A card is dealt exactly to its spot at 0;
## physical loot ([LootTableObject]) takes all of it.
@export_range(0.0, 1.0, 0.01) var table_scatter: float = 0.0

@export_group("Wiring")
@export var face_path: NodePath = ^"Face"
@export var heading_path: NodePath = ^"Face/Body/Heading"
@export var icon_path: NodePath = ^"Face/Body/Icon"
@export var title_path: NodePath = ^"Face/Body/Title"
@export var detail_path: NodePath = ^"Face/Body/Detail"
@export var amount_path: NodePath = ^"Face/Body/Amount"
@export var status_path: NodePath = ^"Face/Body/Status"

@onready var _face: Panel = get_node_or_null(face_path) as Panel
@onready var _heading: Label = get_node_or_null(heading_path) as Label
@onready var _icon: TextureRect = get_node_or_null(icon_path) as TextureRect
@onready var _title: Label = get_node_or_null(title_path) as Label
@onready var _detail: Label = get_node_or_null(detail_path) as Label
@onready var _amount: Label = get_node_or_null(amount_path) as Label
@onready var _status: Label = get_node_or_null(status_path) as Label

var _reward: LootReward
var _interactive: bool = true
var _hover_tween: Tween


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = card_size
	size = card_size
	pivot_offset = card_size * 0.5
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func get_reward() -> LootReward:
	return _reward


## Shows [param reward], and keeps showing it as it changes.
func bind(reward: LootReward) -> void:
	if _reward != null and _reward.changed.is_connected(refresh):
		_reward.changed.disconnect(refresh)
	_reward = reward
	if _reward != null:
		_reward.changed.connect(refresh)
	refresh()


## Whether the card takes clicks at all - off while another reward is busy.
func set_interactive(on: bool) -> void:
	_interactive = on
	refresh()


## Called by the screen as the card touches down at its place. A plain card does
## nothing; physical loot settles with a hop.
func land() -> void:
	pass


## Redraws the card from its reward.
func refresh() -> void:
	if _reward == null or not is_inside_tree():
		return
	var look := _reward.look
	_set_text(_heading, _reward.get_heading())
	_set_text(_title, _reward.get_title())
	_set_text(_detail, _reward.get_detail())
	_set_text(_amount, _reward.get_amount_text())
	_set_text(_status, _reward.get_status_text())
	if _icon != null:
		_icon.texture = look.icon if look != null else null
		_icon.visible = _icon.texture != null
	if look != null:
		for label: Label in [_heading, _status]:
			if label != null:
				label.add_theme_color_override(&"font_color", look.accent_color)
		for label: Label in [_title, _detail, _amount]:
			if label != null:
				label.add_theme_color_override(&"font_color", look.text_color)
		if _face != null and face_style != null:
			var style := face_style.duplicate() as StyleBoxFlat
			style.bg_color = look.face_color
			style.border_color = look.accent_color
			_face.add_theme_stylebox_override(&"panel", style)

	var can_take := _interactive and _reward.can_activate(null)
	disabled = not can_take
	if _reward.is_resolved():
		modulate = resolved_modulate
	elif not can_take:
		modulate = locked_modulate
	else:
		modulate = Color.WHITE


func _set_text(label: Label, value: String) -> void:
	if label == null:
		return
	label.text = value
	label.visible = not value.is_empty()


func _on_pressed() -> void:
	if _reward != null and _interactive and _reward.can_activate(null):
		chosen.emit(self)


func _on_hover(inside: bool) -> void:
	# Not while it is being dealt: the flight owns the card's scale until it lands.
	if not _interactive:
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	var wanted := hover_scale if inside and not disabled else 1.0
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE * wanted, maxf(hover_time, 0.001))
