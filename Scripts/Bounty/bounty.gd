class_name Bounty
extends Resource
## One contract: a face, a price, and however much is known about where to find
## him.
##
## A bounty is generated onto the board by [BountySettings], accepted through
## [BountyLedger], and outlives the run it was taken in. It is a [Resource]
## rather than a node because it is data that has to survive the world being
## rebuilt - the ledger is an autoload holding these, the same way
## [BloodWallet] holds a total.
##
## [b]The reward is locked on acceptance and never recalculated.[/b] What a
## bounty is worth is decided once, from how much was known at the moment it was
## generated, and the whole point of the rule is that finding the outlaw out
## afterwards does not cost the player anything: a 1800-blood contract taken
## blind still pays 1800 once all three lines have been filled in. The boss gets
## easier; the money does not move. [method set_reward] refuses outright once
## [member accepted] is set, so there is no way to write that mistake later - not
## by a shop, not by a knowledge reward, not by a save being reloaded.
##
## What is *known* is a per-line flag on [BountyFact], so information arrives one
## piece at a time through [method reveal] and the knowledge count is counted
## rather than stored. Nothing can set the count to three without there being
## three learned lines to back it up.

## Emitted whenever anything about the bounty changes - accepted, completed, a
## line revealed. The poster listens to this rather than to the three below, so
## it cannot miss one.
##
## Named apart from [Resource]'s own [signal Resource.changed], which every
## resource already has and which a redeclaration here would collide with.
signal bounty_changed
## Emitted only when a piece of information is learned, with the category it
## belonged to.
signal knowledge_revealed(category_id: StringName)
## Emitted when the player takes the contract. The reward is already locked by
## the time this arrives.
signal accepted_changed
## Emitted when the target is finally dead.
signal completed_changed

## The three kinds of information a bounty carries today, as handles rather than
## as string literals typed out at every call site:
## [code]bounty.reveal(Bounty.CATEGORY_REGION)[/code] is the region line, and a
## typo in it is a compile error instead of a reveal that quietly does nothing.
##
## [b]They are conveniences, not the list.[/b] Nothing here decides which
## categories exist - that is the array of [BountyKnowledgeCategory] resources on
## [BountySettings], and a fourth kind of knowledge added there works through
## [method reveal] and is counted by [method get_knowledge_count] without being
## named in this file. These three are only the ones enough of the game already
## talks about to be worth a name.
const CATEGORY_MAP := &"map"
const CATEGORY_REGION := &"region"
const CATEGORY_TIME := &"time"

## Handle for this one contract, unique across the ledger. What persistence keys
## off, and what a later hunt will name when it reports a kill.
@export var bounty_id: StringName = &""
## Who it is on.
@export var target: BountyTarget
## One line per knowledge category, in the order the categories were listed.
@export var facts: Array[BountyFact] = []
## What it pays, in blood. Rolled from the knowledge count at generation, and
## frozen from the moment it is accepted.
@export var reward: int = 0
## How much was known about it when it was dealt, which is what decides its rung -
## see [BountyRarity]. Below 0 on a contract made before rarity existed, which
## every reader falls back to the live count for.
##
## [b]It is remembered rather than recounted[/b] for the same reason the reward is
## frozen: rarity is a fact about the poster that was pinned up, not about how much
## the player has since found out. A legendary contract learned inside out is still
## a legendary contract, still paying what it locked in.
@export var generated_knowledge: int = -1
## Whether the player has taken it off the board.
@export var accepted: bool = false
## Whether the target has been killed and the contract closed out.
@export var completed: bool = false


## The line for [param category_id], or null when this bounty has none - which
## every caller reads as "nothing is known about that, and nothing can be".
func get_fact(category_id: StringName) -> BountyFact:
	for fact: BountyFact in facts:
		if fact != null and fact.category_id == category_id:
			return fact
	return null


## Whether that piece has been learned.
func is_known(category_id: StringName) -> bool:
	var fact := get_fact(category_id)
	return fact != null and fact.known


## The true answer to [param category_id], learned or not. For the systems that
## have to place the boss; the poster asks [method get_fact_text] instead so it
## cannot print something the player has not earned.
func get_fact_value(category_id: StringName) -> StringName:
	var fact := get_fact(category_id)
	return &"" if fact == null else fact.value_id


## What the poster prints for that line.
func get_fact_text(category_id: StringName, unknown_text: String = "?") -> String:
	var fact := get_fact(category_id)
	return unknown_text if fact == null else fact.get_text(unknown_text)


## How many of the three - or however many there turn out to be - are known.
## Counted from the lines every time rather than kept as a number, so it cannot
## disagree with the poster.
func get_knowledge_count() -> int:
	var count := 0
	for fact: BountyFact in facts:
		if fact != null and fact.known:
			count += 1
	return count


## The most this contract could ever know: however many lines it was generated
## with. Three today, and a fourth category makes it four with nothing here to
## change - which is why the boss system below should ask for this rather than
## assume the count tops out at 3.
func get_max_knowledge() -> int:
	var count := 0
	for fact: BountyFact in facts:
		if fact != null:
			count += 1
	return count


## How many lines are still question marks. The other half of the count, kept as
## its own call because it is the half the difficulty reads.
func get_unknown_count() -> int:
	return get_max_knowledge() - get_knowledge_count()


## Whether every line has been filled in.
func is_fully_known() -> bool:
	return get_unknown_count() <= 0


## How blind this contract is, from 1.0 for a poster that gives nothing away to
## 0.0 for one with every line filled in.
##
## [b]This is what mini boss difficulty is meant to be scaled off.[/b] Written as
## a ratio rather than as the raw count so the scaling is authored once, against
## "how much is unknown", and keeps meaning the same thing if a fourth kind of
## knowledge is added - a 0-of-4 contract is as blind as a 0-of-3 one and should
## still produce the hardest fight. A bounty with no lines at all is treated as
## fully known, because there is nothing left to find out about it.
##
## The scaling itself belongs to the boss system, and every exponent and multiplier
## in it belongs in that system's inspector. Nothing here decides what a blind
## contract fights like.
func get_knowledge_ratio() -> float:
	var highest := get_max_knowledge()
	if highest <= 0:
		return 0.0
	return float(get_unknown_count()) / float(highest)


## Every category this contract has a line for, learned or not, in poster order.
func get_category_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for fact: BountyFact in facts:
		if fact != null:
			ids.append(fact.category_id)
	return ids


## The categories the player has found out.
func get_known_categories() -> Array[StringName]:
	var ids: Array[StringName] = []
	for fact: BountyFact in facts:
		if fact != null and fact.known:
			ids.append(fact.category_id)
	return ids


## The categories still to be found out. What a later system handing over one
## piece of information picks from, so it cannot spend a reward on something the
## player already knows.
func get_unknown_categories() -> Array[StringName]:
	var ids: Array[StringName] = []
	for fact: BountyFact in facts:
		if fact != null and not fact.known:
			ids.append(fact.category_id)
	return ids


## Whether this contract has a line for [param category_id] at all - as against
## [method is_known], which asks whether that line has been filled in.
func has_category(category_id: StringName) -> bool:
	return get_fact(category_id) != null


## Learns one piece. Returns whether anything changed, so a caller can tell a
## discovery from a repeat.
##
## Deliberately does not touch [member reward]. This is the call a knowledge
## purchase, an interrogation or a scouting trip will end in, and the contract
## being worth what it was worth when it was taken is the whole rule.
func reveal(category_id: StringName) -> bool:
	var fact := get_fact(category_id)
	if fact == null or not fact.reveal():
		return false

	knowledge_revealed.emit(category_id)
	bounty_changed.emit()
	return true


## Learns everything. For a debug key and for a later "you found his camp"
## reward that hands over the lot at once.
func reveal_all() -> int:
	var learned := 0
	for fact: BountyFact in facts:
		if fact == null or fact.known:
			continue
		if reveal(fact.category_id):
			learned += 1
	return learned


## How much was known when this was dealt - the number its rung is looked up by.
## Falls back to what is known now for a contract generated before rarity existed.
func get_generated_knowledge() -> int:
	return generated_knowledge if generated_knowledge >= 0 else get_knowledge_count()


## This contract's rung, looked up in [param settings]. Null when the settings
## carry no rungs, which every reader draws as no glow and no rarity line.
func get_rarity(settings: BountySettings) -> BountyRarity:
	return null if settings == null else settings.find_rarity(get_generated_knowledge())


## Whether the price is frozen. True from acceptance onwards, forever.
func is_reward_locked() -> bool:
	return accepted


## Sets the price, and refuses once the contract has been taken. The single
## guard behind "learning more later must never reduce the reward" - a caller
## that tries gets false back and changes nothing.
func set_reward(value: int) -> bool:
	if is_reward_locked():
		return false
	reward = maxi(value, 0)
	bounty_changed.emit()
	return true


## Takes the contract, which locks the price where it stands. Returns whether it
## was a change, so accepting twice cannot fill two slots.
func mark_accepted() -> bool:
	if accepted:
		return false
	accepted = true
	accepted_changed.emit()
	bounty_changed.emit()
	return true


## Closes the contract out. Only an accepted bounty can be completed - there is
## nothing to pay out on one the player never took.
func mark_completed() -> bool:
	if completed or not accepted:
		return false
	completed = true
	completed_changed.emit()
	bounty_changed.emit()
	return true


## Whether this contract is still to be hunted: taken, and not yet closed.
func is_outstanding() -> bool:
	return accepted and not completed


## The contract in one line, for a developer readout or a print: who it is on,
## how much of it is known, and what it locked in.
func get_debug_line() -> String:
	var who := "NO TARGET" if target == null else target.display_name
	return "%s  %s  KNOWLEDGE %d/%d  REWARD %d%s%s" % [
		String(bounty_id),
		who,
		get_knowledge_count(),
		get_max_knowledge(),
		reward,
		"  LOCKED" if is_reward_locked() else "",
		"  DONE" if completed else "",
	]


## The contract written out in full, one line per piece of information, with the
## answers the player has not earned shown in brackets. For the developer panel
## and for a print during a test - never for anything the player reads.
func get_debug_text(unknown_text: String = "?") -> String:
	var lines := PackedStringArray([get_debug_line()])
	for fact: BountyFact in facts:
		if fact != null:
			lines.append("    %s: %s" % [String(fact.category_id), fact.describe(unknown_text)])
	return "\n".join(lines)


func _to_string() -> String:
	return "<Bounty %s>" % get_debug_line()


## The bounty flattened to plain values, for a save file.
##
## The game does not write one yet - the ledger is an autoload and autoloads
## already survive the world being rebuilt, which is what "persists between runs"
## means in this project - but this is the shape a disk save would write, and it
## holds exactly what the milestone asked to be preserved: which contract, who it
## is on, whether it was taken, what it locked in, what is known, and whether it
## is done.
##
## [b]The answers are written out as well as the flags.[/b] A contract restored
## from this has to be the same contract, with the outlaw in the same place - the
## knowledge is only worth keeping if what was learned still points somewhere.
## See [method BountyFact.to_save_dictionary].
func to_save_dictionary() -> Dictionary:
	var known: Array[String] = []
	var rows: Array[Dictionary] = []
	for fact: BountyFact in facts:
		if fact == null:
			continue
		rows.append(fact.to_save_dictionary())
		if fact.known:
			known.append(String(fact.category_id))

	return {
		"id": String(bounty_id),
		"target": String(target.target_id) if target != null else "",
		"reward": reward,
		"rarity": get_generated_knowledge(),
		"accepted": accepted,
		"completed": completed,
		"facts": rows,
		# Kept beside the rows on purpose: it is the one field a reader wanting
		# only "what does this contract know" has to look at.
		"known": known,
	}


## Puts a saved state back onto an already-generated bounty. The facts' true
## answers are not restored from here - they come from the generator, or from
## [method from_save_dictionary] when the whole contract is being rebuilt - so
## this only ever turns lines on, which is the same direction play moves in.
##
## [b]It writes the reward straight in rather than through [method set_reward].[/b]
## That is deliberate and is the one place it is right: restoring is putting back
## the number that was locked, not pricing the contract again, and going through
## the guard would refuse exactly the accepted contracts whose reward matters
## most.
func apply_save_dictionary(data: Dictionary) -> void:
	reward = int(data.get("reward", reward))
	generated_knowledge = int(data.get("rarity", generated_knowledge))
	accepted = bool(data.get("accepted", accepted))
	completed = bool(data.get("completed", completed))

	var known: Array = data.get("known", [])
	for entry: Variant in known:
		var fact := get_fact(StringName(entry))
		if fact != null:
			fact.known = true
	bounty_changed.emit()


## A whole contract rebuilt from [method to_save_dictionary], lines and answers
## and all.
##
## [param settings] is only used to find the outlaw again by id, and a bounty
## restored without it is still a valid contract - it simply has no face. That is
## on purpose: what has to survive is the knowledge and the locked price, and
## neither depends on the roster still holding the same targets.
static func from_save_dictionary(data: Dictionary, settings: BountySettings = null) -> Bounty:
	var bounty := Bounty.new()
	bounty.bounty_id = StringName(data.get("id", ""))
	if settings != null:
		bounty.target = settings.find_target(StringName(data.get("target", "")))

	var lines: Array[BountyFact] = []
	var rows: Array = data.get("facts", [])
	for row: Variant in rows:
		if row is Dictionary:
			lines.append(BountyFact.from_save_dictionary(row))
	bounty.facts = lines

	bounty.apply_save_dictionary(data)
	return bounty

