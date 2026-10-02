class_name LootRewardMystery
extends LootReward
## A mystery [code]?[/code] card on the Loot Screen's table: opened, it deals a
## reward selection, the player takes one card, and it is done with.
##
## [b]Opening it is the existing hand-off.[/b] Exactly like [LootRewardUpgrade], a
## click hands over to another surface - [RewardChoiceScreen] - and the reward
## settles when that surface reports back, so the Loot Screen's own rules hold:
## the other cards are held still while it is open and it cannot be opened twice.
## Like every reward it is optional - the table may be left with it unopened.
##
## [b]What is dealt is decided when it is opened[/b], by [member generator] on the
## weapon as it stands then - so a ŞANSLI EL taken from one [code]?[/code] already
## widens the next one on the same table. The card picked is applied the moment
## it is picked, through its own authority (see [method RewardChoice.apply]).

## Emitted with the card taken, as it is applied.
signal choice_taken(choice: RewardChoice)

## Deals the selection - see [RewardChoiceGenerator].
var generator: RewardChoiceGenerator
## The weapon the cards are for.
var weapon: WeaponDefinition
## The generator every selection of this card is dealt with.
var rng: RandomNumberGenerator
## Shown on the card when no selection surface could be found.
var unavailable_text: String = "KAPALI"

var _screen: RewardChoiceScreen
var _taken: RewardChoice


## The card taken from this mystery card, or null before one is.
func get_taken() -> RewardChoice:
	return _taken


func _activate(context: LootContext) -> void:
	_screen = RewardChoiceScreen.get_active(context.host if context != null else null)
	if _screen == null or generator == null or weapon == null:
		_finish(false, unavailable_text)
		return
	var choices := generator.generate(weapon, rng if rng != null else context.rng)
	if choices.is_empty():
		# The weapon has nothing at all left to give - nothing to hold the player to.
		_finish(true)
		return
	_screen.selected.connect(_on_selected, CONNECT_ONE_SHOT)
	_screen.finished.connect(_on_screen_finished, CONNECT_ONE_SHOT)
	if not _screen.open(choices):
		_screen.selected.disconnect(_on_selected)
		_screen.finished.disconnect(_on_screen_finished)
		_finish(false, unavailable_text)


func _on_selected(choice: RewardChoice) -> void:
	_taken = choice
	if choice != null:
		choice.apply()
	choice_taken.emit(choice)


func _on_screen_finished() -> void:
	_screen = null
	_finish(true)
