class_name SurrenderKnowledge
extends Node
## What a man who has given up turns out to be worth: he talks, and the player
## learns one thing about somebody they are already hunting.

## [b]It is a separate node from the surrender itself[/b], for the same reason
## [GunshotSurrender] is separate from the weapon. An enemy's job is to fight and
## then to stop fighting; knowing that contracts exist, that the player holds some
## of them and that one line of one of them can be filled in is the bounty system's
## business. Taking this node off an enemy leaves a man who still gives up, still
## drops his knife and still shows an E - he simply has nothing to say.
##
## [b]It invents no knowledge of its own.[/b] Everything goes through
## [method BountyLedger.reveal], which is already the single door every piece of
## information in the game arrives by, so the reward is untouched - see
## [method Bounty.set_reward], which refuses outright on an accepted contract -
## the count cannot exceed the lines the contract actually has, and anything
## watching the ledger hears about it. What is learned is drawn from
## [method Bounty.get_unknown_categories], so a piece the player already has can
## never be handed over as though it were new.
##
## [b]Who he talks about is the player's own business, literally.[/b] Only
## contracts that have been accepted and are still outstanding are candidates, and
## only those with something left to find out - so a man cannot spend himself
## telling the player what they already knew. When every contract is complete, or
## there are none, he says nothing and is [i]not[/i] used up: the prompt stays over
## him and he can be asked again after the next contract is taken.

## Emitted when the player actually learns something, with the contract it was
## about and which line was filled in.
signal knowledge_given(bounty: Bounty, category_id: StringName)
## Emitted when the player interacted but there was nothing worth telling them.
## The enemy is left interactable.
signal nothing_to_tell

## The give-up component whose interaction this answers. Left empty it is found by
## type on the enemy, which is what every other component here does.
@export var surrender_path: NodePath = ^"../Surrender"
## The ledger every contract lives in. A world without it simply has enemies with
## nothing to say.
@export var ledger_path: NodePath = ^"/root/Bounties"
## Whether the man talks at all. Off leaves the interaction reporting itself and
## paying nothing, which is what it did before there was anything to pay.
@export var enabled: bool = true

@export_group("What he tells you")
## How many pieces of information one man is worth.
##
## One. Kept as a value rather than as a fact about the code because an informant
## who is worth more - a mini boss handing over what he knew, an interrogation
## that went well - is the same routine run twice, and because whichever way this
## is tuned no single piece can be handed over twice: each is drawn from what is
## still unknown at that moment.
@export var pieces: int = 1
## Whether telling the player something uses the man up, so a second press of E
## pays nothing.
##
## [b]On, and it is only ever done on a piece actually handed over.[/b] An
## interaction that found nothing to say leaves him exactly as he was - see
## [signal nothing_to_tell] - because spending a man for nothing is the one way
## this could cost the player something.
@export var spends_the_enemy: bool = true

var _surrender: EnemySurrender


func _ready() -> void:
	_surrender = _find_surrender()
	if _surrender != null:
		_surrender.used.connect(_on_used)


## The give-up component this answers for: the one named, or whichever one the
## enemy turns out to have.
func _find_surrender() -> EnemySurrender:
	var named := get_node_or_null(surrender_path) as EnemySurrender
	if named != null:
		return named

	var host := get_parent()
	return null if host == null else EnemySurrender.find_on(host)


## The ledger, asked for each time rather than held, so this works in a scene where
## the autoload is absent and in one where it is added later.
func _get_ledger() -> BountyLedger:
	return get_node_or_null(ledger_path) as BountyLedger


## The player pressed E. Everything that can be handed over is handed over first,
## and only then - and only if something was - is the man spent.
func _on_used() -> void:
	if not enabled:
		return

	var ledger := _get_ledger()
	if ledger == null:
		nothing_to_tell.emit()
		return

	var given := 0
	for _piece: int in maxi(pieces, 0):
		if not _tell_one(ledger):
			# Nothing left worth saying: stop rather than spin, since every further
			# attempt would ask the same question of the same contracts.
			break
		given += 1

	if given <= 0:
		nothing_to_tell.emit()
		return
	if spends_the_enemy and _surrender != null:
		_surrender.consume()


## Fills in one line of one contract. Returns whether anything was actually learned.
##
## The contract is picked first and the line second, both from what is still
## missing, so the two questions "who does he talk about" and "what does he say
## about them" are each answered against the live state - which is what makes a
## second piece in the same breath land somewhere useful rather than on a line the
## first one just filled in.
func _tell_one(ledger: BountyLedger) -> bool:
	var bounty := _pick_bounty(ledger)
	if bounty == null:
		return false

	var missing := bounty.get_unknown_categories()
	if missing.is_empty():
		return false

	var category: StringName = missing[randi() % missing.size()]
	if not ledger.reveal(bounty.bounty_id, category):
		return false

	knowledge_given.emit(bounty, category)
	return true


## Which contract he talks about: one the player has taken, has not finished, and
## still has a question mark on.
##
## Drawn at random from all of them rather than from the first that qualifies, so a
## player holding several contracts is not fed information about the same one every
## time. A contract that is already filled in is never a candidate, which is the
## whole of "do not reveal duplicate information".
func _pick_bounty(ledger: BountyLedger) -> Bounty:
	var pool: Array[Bounty] = []
	for bounty: Bounty in ledger.get_outstanding():
		if bounty != null and not bounty.is_fully_known():
			pool.append(bounty)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]
