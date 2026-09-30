class_name LootScreen
extends Control
## The post-combat Loot Screen: a table, the devil's money pouch in the middle
## of it, and - once the pouch is opened - the fight's rewards dealt out around
## it to be looked at and taken.
##
## [b]It presents a [LootBundle] and knows nothing else.[/b] It is handed the
## bundle by [PostCombatLootDirector] and never learns which encounter paid it:
## each [LootReward] is dealt as the card its [LootRewardLook] names (or
## [member default_card_scene]), placed by [member layout], and activated on a
## click. A new kind of reward needs a reward class and a look - nothing here.
##
## [b]The flow.[/b] [method present] raises the table with the pouch shut.
## Clicking the pouch ([method reveal]) plays its opening, and at the pop the
## cards fly out to their places. The player takes what they want; the leave
## button unlocks once nothing still owed is left ([method LootBundle.can_leave])
## and [method leave] reports [signal finished] - the director takes it home from
## there.
##
## [b]The game is stopped under it.[/b] It pauses the tree while it is up - the
## same pause every full-screen surface uses - which stops the arena, the
## enemies, the player and [code]WorldClock[/code] alike, and is what makes the
## game's own pointer ([GameCursor]) take over from the sight. It lives on
## [code]RunHUD[/code], which runs while paused, and swallows every key while it
## is up so nothing leaks through to the fight underneath.

## Raised with a bundle.
signal presented(bundle: LootBundle)
## The pouch has been opened and the cards dealt.
signal revealed
## The player has left the table.
signal finished

@export var layout: LootLayout
## The card dealt for a reward whose look names none.
@export var default_card_scene: PackedScene
## Pauses the tree while the screen is up.
@export var pauses_game: bool = true
## Leaves by itself once every reward is done with, rather than waiting on the
## button.
@export var auto_leave_when_resolved: bool = false
## How long it waits before leaving by itself, in seconds.
@export var auto_leave_delay: float = 0.8

@export_group("Presentation")
## How long the table takes to come up, in seconds.
@export var appear_time: float = 0.35
## The table's scale as it starts to come up.
@export var appear_scale: float = 0.92
## How long before the leave button shows once the cards are down.
@export var leave_button_delay: float = 0.2

@export_group("Wording")
@export var hint_text: String = "OPEN THE POUCH"
## Shown once the cards are down. Empty by default: a card dealt straight up sits
## where this line would be.
@export var take_hint_text: String = ""
@export var empty_text: String = "THE POUCH IS EMPTY"
@export var leave_text: String = "RIDE ON"
@export var leave_locked_text: String = "TAKE WHAT IS OWED"

@export_group("Wiring")
@export var table_path: NodePath = ^"Table"
@export var pouch_path: NodePath = ^"Table/Pouch"
@export var rewards_path: NodePath = ^"Table/Rewards"
@export var hint_path: NodePath = ^"Table/Hint"
@export var empty_label_path: NodePath = ^"Table/Empty"
@export var leave_button_path: NodePath = ^"Table/Leave"

@onready var _table: Control = get_node_or_null(table_path) as Control
@onready var _pouch: LootPouch = get_node_or_null(pouch_path) as LootPouch
@onready var _rewards: Control = get_node_or_null(rewards_path) as Control
@onready var _hint: Label = get_node_or_null(hint_path) as Label
@onready var _empty: Label = get_node_or_null(empty_label_path) as Label
@onready var _leave: Button = get_node_or_null(leave_button_path) as Button

var _bundle: LootBundle
var _cards: Array[LootRewardCard] = []
var _paused_by_us: bool = false
var _revealed: bool = false
var _dealing: bool = false
var _instant_reveal: bool = false
var _leaving: bool = false
var _busy: LootReward
var _appear_tween: Tween
var _auto_leave_armed: bool = false


func _ready() -> void:
	hide()
	if _pouch != null:
		_pouch.pressed.connect(reveal)
		_pouch.burst.connect(_on_pouch_burst)
	if _leave != null:
		_leave.pressed.connect(leave)
		_leave.focus_mode = Control.FOCUS_NONE


func is_open() -> bool:
	return visible


func get_bundle() -> LootBundle:
	return _bundle


func is_revealed() -> bool:
	return _revealed


## Every card on the table, in the bundle's order.
func get_cards() -> Array[LootRewardCard]:
	return _cards.duplicate()


## Raises the table with [param bundle] in the shut pouch. False when the screen
## is already up with another.
func present(bundle: LootBundle) -> bool:
	if bundle == null or visible:
		return false
	_bundle = bundle
	_revealed = false
	_dealing = false
	_leaving = false
	_busy = null
	_auto_leave_armed = false
	_clear_cards()
	if _pouch != null:
		_pouch.reset()
	_set_label(_hint, hint_text)
	_set_label(_empty, "")
	if _leave != null:
		_leave.visible = false

	if pauses_game and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	show()
	_play_appear()
	presented.emit(bundle)
	return true


## Opens the pouch - the same as clicking it. [param instant] skips the pouch's
## opening and the cards' flight, for a check that does not want to wait.
func reveal(instant: bool = false) -> void:
	if not visible or _revealed or _pouch == null or _pouch.is_opening():
		return
	_revealed = true
	_instant_reveal = instant
	_set_label(_hint, "")
	_pouch.open(instant)


## Activates the reward on [param card] - the same as clicking it.
func activate(card: LootRewardCard) -> void:
	if card == null or _busy != null or _dealing or _leaving:
		return
	var reward := card.get_reward()
	if reward == null or not reward.can_activate(_bundle.context):
		return
	_busy = reward
	if not reward.activation_finished.is_connected(_on_activation_finished):
		reward.activation_finished.connect(_on_activation_finished.bind(reward), CONNECT_ONE_SHOT)
	_set_cards_interactive(false)
	_refresh_leave()
	reward.activate(_bundle.context)


## Whether the table may be left now.
func can_leave() -> bool:
	return visible and _revealed and not _dealing and _busy == null and not _leaving \
		and (_bundle == null or _bundle.can_leave())


## Leaves the table, if nothing still owed is on it. The screen stays up - the
## director decides whether it is closed or carried under the loading curtain.
func leave() -> bool:
	if not can_leave():
		return false
	_leaving = true
	_set_cards_interactive(false)
	if _leave != null:
		_leave.disabled = true
	finished.emit()
	return true


## Takes the screen down and gives the game back.
func close() -> void:
	if not visible:
		return
	hide()
	_clear_cards()
	_bundle = null
	if _paused_by_us:
		_paused_by_us = false
		get_tree().paused = false


# --- Dealing ---------------------------------------------------------------------

## The pouch popped: the cards go out now.
func _on_pouch_burst() -> void:
	_deal_cards(_instant_reveal)


func _deal_cards(instant: bool) -> void:
	if _bundle == null or _rewards == null:
		return
	_clear_cards()
	var rewards := _bundle.rewards
	if rewards.is_empty():
		_set_label(_empty, empty_text)
		_after_dealt()
		return

	var active_layout := layout if layout != null else LootLayout.new()
	var origin := _pouch_centre()
	var targets := active_layout.positions(rewards.size())
	var last: Tween
	_dealing = not instant
	for index: int in rewards.size():
		var card := _make_card(rewards[index])
		if card == null:
			continue
		_rewards.add_child(card)
		card.bind(rewards[index])
		card.chosen.connect(activate)
		_cards.append(card)
		var half := card.size * 0.5
		var rest := origin + targets[index] - half
		if instant:
			card.position = rest
			continue
		card.set_interactive(false)
		card.position = origin - half
		card.scale = Vector2.ONE * active_layout.spawn_scale
		card.rotation = deg_to_rad(active_layout.spawn_spin_degrees
			* (1.0 if index % 2 == 0 else -1.0))
		var flight := create_tween()
		flight.tween_interval(active_layout.stagger * index)
		flight.tween_method(_fly.bind(card, origin - half, rest, active_layout.arc_lift),
			0.0, 1.0, maxf(active_layout.fly_time, 0.001)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flight.parallel().tween_property(card, "scale", Vector2.ONE,
			maxf(active_layout.fly_time, 0.001)) \
			.set_trans(active_layout.fly_transition).set_ease(active_layout.fly_ease)
		flight.parallel().tween_property(card, "rotation", 0.0,
			maxf(active_layout.fly_time, 0.001))
		last = flight
	if last == null:
		_after_dealt()
		return
	last.finished.connect(_after_dealt)


func _fly(t: float, card: LootRewardCard, from: Vector2, to: Vector2, lift: float) -> void:
	if not is_instance_valid(card):
		return
	card.position = from.lerp(to, t) + Vector2(0.0, -lift * 4.0 * t * (1.0 - t))


func _after_dealt() -> void:
	_dealing = false
	_set_cards_interactive(true)
	_set_label(_hint, take_hint_text if not _cards.is_empty() else "")
	if leave_button_delay > 0.0:
		await get_tree().create_timer(leave_button_delay, true).timeout
	if not visible:
		return
	_refresh_leave()
	revealed.emit()


func _make_card(reward: LootReward) -> LootRewardCard:
	if reward == null:
		return null
	var scene := default_card_scene
	if reward.look != null and reward.look.card_scene != null:
		scene = reward.look.card_scene
	if scene == null:
		push_warning("LootScreen: no card scene for a reward.")
		return null
	var card := scene.instantiate() as LootRewardCard
	if card == null:
		push_warning("LootScreen: a card scene has no LootRewardCard at its root.")
	return card


## The pouch's middle, in the rewards layer's own coordinates.
func _pouch_centre() -> Vector2:
	if _pouch == null or _rewards == null:
		return Vector2.ZERO
	var global := _pouch.get_global_rect().get_center()
	return _rewards.get_global_transform().affine_inverse() * global


func _clear_cards() -> void:
	for card: LootRewardCard in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()


func _set_cards_interactive(on: bool) -> void:
	for card: LootRewardCard in _cards:
		if is_instance_valid(card):
			card.set_interactive(on)


# --- Resolving -------------------------------------------------------------------

func _on_activation_finished(reward: LootReward) -> void:
	if _busy == reward:
		_busy = null
	if not visible or _leaving:
		return
	_set_cards_interactive(true)
	_refresh_leave()
	if auto_leave_when_resolved and _bundle != null and _bundle.is_resolved() \
			and not _auto_leave_armed:
		_auto_leave_armed = true
		await get_tree().create_timer(maxf(auto_leave_delay, 0.0), true).timeout
		leave()


func _refresh_leave() -> void:
	if _leave == null:
		return
	_leave.visible = _revealed and not _dealing
	var open_door := can_leave()
	_leave.disabled = not open_door
	_leave.text = leave_text if open_door or _busy != null else leave_locked_text


func _set_label(label: Label, value: String) -> void:
	if label == null:
		return
	label.text = value
	label.visible = not value.is_empty()


func _play_appear() -> void:
	if _table == null:
		return
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	_table.pivot_offset = _table.size * 0.5
	_table.scale = Vector2.ONE * appear_scale
	modulate.a = 0.0
	_appear_tween = create_tween().set_parallel(true)
	_appear_tween.tween_property(self, "modulate:a", 1.0, maxf(appear_time, 0.001))
	_appear_tween.tween_property(_table, "scale", Vector2.ONE, maxf(appear_time, 0.001)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Nothing but the table's own buttons acts while it is up: every key - and the
## back key in particular - is swallowed, so no combat or menu input leaks
## through to the arena underneath.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
