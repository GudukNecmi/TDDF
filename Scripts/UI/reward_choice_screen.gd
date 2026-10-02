class_name RewardChoiceScreen
extends Control
## The reward selection laid over the Loot Screen's table when a mystery
## [code]?[/code] card is opened: the dealt cards in a row, revealed one at a time
## left to right, and the one the player takes.
##
## [b]It presents [RewardChoice]s and knows nothing else.[/b] Whoever opens it -
## [LootRewardMystery] - deals the choices and applies the one taken, on
## [signal selected]; this only shows them. Nothing here names an upgrade, a
## Legendary or a rarity: each card's look and sound is its rarity's.
##
## [b]The reveal is strictly in order.[/b] Card by card, left to right: it enters
## the table, turns face up with one flip sound, plays its rarity's stinger and
## flare, holds a beat - and only then does the next one start. Cards take clicks
## once all are face up. Every duration is an export.
##
## It lives inside the Loot Screen, which pauses the game - so the game's own
## pointer stays up throughout and nothing here touches the mouse mode.

## The selection is up.
signal opened(choices: Array[RewardChoice])
## One card has turned face up - [param index] counts from the left.
signal card_revealed(index: int, choice: RewardChoice)
## Every card is face up and the player may choose.
signal all_revealed
## A card was taken. Emitted once, the moment it is clicked.
signal selected(choice: RewardChoice)
## The selection is gone and the table is back.
signal finished

const GROUP := &"reward_choice_screen"

## The card each choice is dealt as. Must have a [RewardChoiceCard] at its root.
@export var card_scene: PackedScene

@export_group("Row")
## Gap between neighbouring cards, in pixels.
@export var card_gap: float = 26.0
## The widest the row may be before the cards are drawn smaller to fit.
@export var max_row_width: float = 1040.0
## Moves the row from the screen's middle.
@export var row_offset: Vector2 = Vector2(0.0, 20.0)

@export_group("Reveal Timing")
## Pause after the selection comes up before the first card enters, in seconds.
@export var start_delay: float = 0.25
## How long a card takes to enter the table.
@export var enter_time: float = 0.28
## How far below its place a card enters from, in pixels.
@export var enter_distance: float = 70.0
## A beat face down before it turns.
@export var pre_flip_hold: float = 0.08
## How long the whole turn takes - half to edge-on, half to face up.
@export var flip_time: float = 0.3
## Wait after the card is face up before its rarity stinger plays.
@export var stinger_delay: float = 0.05
## How long the card holds once its rarity has played, before the next one enters.
@export var after_reveal_hold: float = 0.45
## How long the table title and dim take to come up.
@export var appear_time: float = 0.2

@export_group("Selection")
## How much the taken card swells, and how long the emphasis lasts.
@export var selected_emphasis: float = 1.14
@export var selected_time: float = 0.55
## What the cards not taken fade to as the taken one is emphasised.
@export_range(0.0, 1.0, 0.01) var unselected_alpha: float = 0.25
## How long the selection takes to fade away afterwards.
@export var close_time: float = 0.22

@export_group("Audio")
## The bank the flip and confirm sounds come from - see [SoundBank].
@export var sound_bank_path: NodePath = ^"Sounds"
## The bank sound played once per card as it turns face up.
@export var flip_sound: StringName = &"flip"
## The bank sound played as a card is taken.
@export var select_sound: StringName = &"select"

@export_group("Wording")
@export var choose_text: String = "BİR KART SEÇ"

@export_group("Wiring")
@export var row_path: NodePath = ^"Row"
@export var title_path: NodePath = ^"Title"

@onready var _row: Control = get_node_or_null(row_path) as Control
@onready var _title: Label = get_node_or_null(title_path) as Label
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank

enum State { CLOSED, REVEALING, CHOOSING, CLOSING }

var _state: State = State.CLOSED
var _choices: Array[RewardChoice] = []
var _cards: Array[RewardChoiceCard] = []
## Readouts for the smoke check: every flip and stinger actually played, in order.
var _flip_plays: int = 0
var _stinger_log: Array[UpgradeRarity] = []
var _stinger_hit_log: Array[int] = []
var _reveal_order: Array[int] = []
var _sequence: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	hide()


## The selection surface in this scene, or null when it has none.
static func get_active(from_node: Node) -> RewardChoiceScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RewardChoiceScreen


func is_open() -> bool:
	return _state != State.CLOSED


## Whether every card is face up and one may be taken.
func is_choosing() -> bool:
	return _state == State.CHOOSING


func get_cards() -> Array[RewardChoiceCard]:
	return _cards.duplicate()


func get_flip_plays() -> int:
	return _flip_plays


func get_stinger_log() -> Array[UpgradeRarity]:
	return _stinger_log.duplicate()


## How many guitar hits each stinger played, in reveal order.
func get_stinger_hit_log() -> Array[int]:
	return _stinger_hit_log.duplicate()


## The card indices in the order they were turned face up.
func get_reveal_order() -> Array[int]:
	return _reveal_order.duplicate()


## Deals [param choices] face down and starts the reveal. False when it is already
## up or there is nothing to show.
func open(choices: Array[RewardChoice]) -> bool:
	if _state != State.CLOSED or choices.is_empty() or card_scene == null or _row == null:
		return false
	_choices = choices.duplicate()
	_flip_plays = 0
	_stinger_log.clear()
	_stinger_hit_log.clear()
	_reveal_order.clear()
	_sequence += 1
	_clear_cards()
	_state = State.REVEALING
	if _title != null:
		_title.text = choose_text
		_title.modulate.a = 0.0
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, maxf(appear_time, 0.001))
	_lay_out()
	opened.emit(_choices)
	_reveal_all(_sequence)
	return true


## Takes the card at [param index] - the same as clicking it once all are face up.
func choose(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_on_card_chosen(_cards[index])


func _lay_out() -> void:
	var count := _choices.size()
	var sample := card_scene.instantiate() as RewardChoiceCard
	var card_size := sample.card_size
	sample.free()
	var natural := card_size.x * count + card_gap * maxf(count - 1, 0)
	var fit := minf(1.0, max_row_width / maxf(natural, 1.0))
	var step := (card_size.x + card_gap) * fit
	var centre := _row.size * 0.5 + row_offset
	var first_x := centre.x - step * (count - 1) * 0.5
	for index: int in count:
		var card := card_scene.instantiate() as RewardChoiceCard
		_row.add_child(card)
		card.bind(_choices[index])
		card.scale = Vector2.ONE * fit
		card.pivot_offset = card.card_size * 0.5
		card.position = Vector2(first_x + step * index, centre.y) - card.card_size * 0.5
		card.modulate.a = 0.0
		card.enter_offset = enter_distance
		card.chosen.connect(_on_card_chosen)
		_cards.append(card)


## The strict left-to-right sequence. [param sequence] stops a sequence left
## running from a selection that has since been closed.
func _reveal_all(sequence: int) -> void:
	await _wait(start_delay)
	if _title != null and sequence == _sequence:
		create_tween().tween_property(_title, "modulate:a", 1.0, maxf(appear_time, 0.001))
	for index: int in _cards.size():
		if sequence != _sequence or _state != State.REVEALING:
			return
		await _reveal_one(index, sequence)
	if sequence != _sequence or _state != State.REVEALING:
		return
	_state = State.CHOOSING
	for card: RewardChoiceCard in _cards:
		card.set_selectable(true)
	all_revealed.emit()


func _reveal_one(index: int, sequence: int) -> void:
	var card := _cards[index]
	var enter := create_tween().set_parallel(true)
	enter.tween_property(card, "modulate:a", 1.0, maxf(enter_time, 0.001))
	enter.tween_property(card, "enter_offset", 0.0, maxf(enter_time, 0.001)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await enter.finished
	await _wait(pre_flip_hold)
	if sequence != _sequence:
		return
	var flipper := card.get_node_or_null(card.flipper_path) as Control
	var half := maxf(flip_time * 0.5, 0.001)
	if flipper != null:
		var close := create_tween()
		close.tween_property(flipper, "scale:x", 0.0, half) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await close.finished
	if sequence != _sequence:
		return
	card.set_face_up(true)
	_play_flip()
	if flipper != null:
		var reopen := create_tween()
		reopen.tween_property(flipper, "scale:x", 1.0, half) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await reopen.finished
	if sequence != _sequence:
		return
	_reveal_order.append(index)
	card_revealed.emit(index, card.get_choice())
	await _wait(stinger_delay)
	if sequence != _sequence:
		return
	card.play_rarity_feedback()
	_play_stinger(card.get_choice())
	await _wait(after_reveal_hold)


func _on_card_chosen(card: RewardChoiceCard) -> void:
	if _state != State.CHOOSING or card == null or not _cards.has(card):
		return
	_state = State.CLOSING
	for each: RewardChoiceCard in _cards:
		each.set_selectable(false)
	if _sounds != null and _sounds.has_sound(select_sound):
		_sounds.play(select_sound)
	var choice := card.get_choice()
	selected.emit(choice)

	var emphasis := create_tween().set_parallel(true)
	emphasis.tween_property(card, "emphasis", selected_emphasis, maxf(selected_time * 0.4, 0.001)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.play_rarity_feedback()
	for other: RewardChoiceCard in _cards:
		if other != card:
			emphasis.tween_property(other, "modulate:a", unselected_alpha,
				maxf(selected_time * 0.4, 0.001))
	await _wait(selected_time)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, maxf(close_time, 0.001))
	await fade.finished
	_close()


func _close() -> void:
	_sequence += 1
	_state = State.CLOSED
	hide()
	_clear_cards()
	_choices.clear()
	finished.emit()


func _play_flip() -> void:
	if _sounds != null and _sounds.has_sound(flip_sound):
		_sounds.play(flip_sound)
	_flip_plays += 1


## Plays [param choice]'s rarity stinger: its hits one after another, then its
## layer with the last. Not awaited - the reveal moves on at its own pace.
func _play_stinger(choice: RewardChoice) -> void:
	if choice == null or choice.rarity == null:
		return
	var rarity := choice.rarity
	_stinger_log.append(rarity)
	var hits := rarity.stinger_hits if rarity.stinger_hit != null else 0
	var slot := _stinger_hit_log.size()
	_stinger_hit_log.append(0)
	var sequence := _sequence
	for index: int in hits:
		if index > 0:
			await _wait(rarity.stinger_interval)
		if sequence != _sequence:
			return
		if _sounds != null:
			var voice := _sounds.play_stream(rarity.stinger_hit, rarity.stinger_volume_db)
			if voice != null:
				voice.pitch_scale = rarity.stinger_pitch(index)
		_stinger_hit_log[slot] += 1
	if rarity.stinger_layer != null and _sounds != null:
		_sounds.play_stream(rarity.stinger_layer, rarity.stinger_layer_volume_db)


func _clear_cards() -> void:
	for card: RewardChoiceCard in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds, true).timeout
