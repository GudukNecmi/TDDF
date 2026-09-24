class_name RunCardHolder
extends Node
## The Cards the player holds for the current run - the one authority a Card is
## added through, and what a Card's effect will later read. Registered as the
## [code]RunCards[/code] autoload.
##
## [b]Run-only, never permanent.[/b] Nothing here belongs to the Base's upgrades:
## the hand is emptied as a run begins and as it ends, the same two moments
## [RunSessionState] forgets the carried health. It is an autoload rather than a
## node in a scene because a run is played across real scene changes - the run
## map, each fight - and a card bought at a market has to still be held in the
## arena it was bought for.
##
## [b]It holds cards, it does not play them.[/b] No card has an effect yet; what
## one does later listens to [signal card_added] or asks [method get_count].

## Emitted once a card has been added, with how many of it are now held.
signal card_added(card: RunCard, count: int)
## Emitted whenever the hand changes, including being emptied.
signal cards_changed

## The run's state - the [code]RunSession[/code] autoload - listened to for the
## moments the hand is emptied.
@export var session_path: NodePath = ^"/root/RunSession"

## Every card held, in the order it was added. A card bought twice is in here
## twice.
var _cards: Array[RunCard] = []


func _ready() -> void:
	var session := get_node_or_null(session_path)
	if session == null:
		return
	if session.has_signal(&"run_began") and not session.is_connected(&"run_began", _on_run_began):
		session.connect(&"run_began", _on_run_began)
	if session.has_signal(&"run_ended") and not session.is_connected(&"run_ended", clear):
		session.connect(&"run_ended", clear)


## Adds one copy of [param card] to the hand. Returns whether it went.
func add_card(card: RunCard) -> bool:
	if card == null:
		return false
	_cards.append(card)
	card_added.emit(card, get_count(card))
	cards_changed.emit()
	return true


## Every card held, in order. A copy, so a readout cannot edit the hand.
func get_cards() -> Array[RunCard]:
	return _cards.duplicate()


## How many copies of [param card] are held, matched by [member RunCard.id].
func get_count(card: RunCard) -> int:
	if card == null:
		return 0
	var count := 0
	for held: RunCard in _cards:
		if held != null and held.id == card.id:
			count += 1
	return count


func has_card(card: RunCard) -> bool:
	return get_count(card) > 0


## Empties the hand.
func clear() -> void:
	if _cards.is_empty():
		return
	_cards.clear()
	cards_changed.emit()


func _on_run_began(_map_id: StringName) -> void:
	clear()
