class_name BountyLedger
extends Node
## Every contract the game knows about: the ones pinned to the board, and the
## ones the player has taken.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet], [DayClock] and [RunSessionState] are: a [code]class_name[/code]
## matching an autoload's name shadows it and refuses to compile. Reach the live
## one as [code]Bounties[/code]; the type is [BountyLedger] where a reference has
## to be statically typed.
##
## [b]This is the persistence.[/b] Setting out on a run rebuilds the World scene,
## and an autoload is the one thing in the tree that
## [method SceneTree.reload_current_scene] does not touch - which is exactly how
## the player's blood survives a run already. Accepted contracts, their locked
## rewards, what is known about them and whether they are finished all live here,
## so they are still here when the player walks back into the base. Nothing in a
## run's teardown clears them. There is no second save system, because there was
## never a first one.
##
## What a bounty *is* it does not decide. Generation, pricing and every tunable
## number live in the [BountySettings] resource this loads, so the ledger only
## ever does bookkeeping: hand out ids, keep the board stocked, move a contract
## from the board to the active list, and refuse when there is no room.

## Emitted whenever the posters on the board change - one taken down, the board
## refreshed. UI should rebuild on this.
signal board_changed
## Emitted when the player takes a contract. The reward is already locked by the
## time it arrives.
signal bounty_accepted(bounty: Bounty)
## Emitted when an accepted contract is closed out.
signal bounty_completed(bounty: Bounty)
## Emitted when a piece of information is learned about any contract.
signal knowledge_revealed(bounty: Bounty, category_id: StringName)
## Emitted when the player gives a contract up. The slot it came off is not
## refilled here - see [method cancel].
signal bounty_cancelled(bounty: Bounty)

## The tuning resource. Everything adjustable about bounties - slot count, reward
## ranges, the rounding step, the categories, the outlaws - is inspector fields
## on this [code].tres[/code] rather than on the autoload, because an autoload
## script has no scene and so no inspector of its own.
@export var settings_path: String = "res://Resources/Bounty/bounty_settings.tres"
## The run, watched for coming home. [b]That is when the board is looked at
## again[/b] - an empty slot is only ever rolled for while the player is at the
## board, so a contract taken mid-session leaves a gap that stays a gap until they
## ride home.
@export var session_path: NodePath = ^"/root/RunSession"

var _settings: BountySettings
## The posters, one entry per slot. [b]An entry may be null[/b] - that is a slot
## nothing was dealt into, or one whose contract has been taken - and every reader
## skips nulls rather than assuming five.
var _board: Array[Bounty] = []
var _active: Array[Bounty] = []
var _issued: int = 0
var _stocked: bool = false


func _ready() -> void:
	# The one hook the board needs: coming home is when a bare slot may be dealt
	# into again. Nothing else refills it - not accepting, not cancelling, not a
	# new round - so a gap the player made is a gap they ride out with.
	var session := get_node_or_null(session_path)
	if session != null and session.has_signal(&"run_ended"):
		session.connect(&"run_ended", _on_run_ended)


## The tuning. Loaded on first use rather than in [method Node._ready] so the
## resource is read once something actually wants it; a missing or broken file
## leaves a bare settings object, which produces an empty board instead of an
## error.
func get_settings() -> BountySettings:
	if _settings != null:
		return _settings

	if ResourceLoader.exists(settings_path):
		_settings = load(settings_path) as BountySettings
	if _settings == null:
		push_warning("BountyLedger: no bounty settings at %s - the board will be empty." % settings_path)
		_settings = BountySettings.new()
	return _settings


## The posters currently pinned up, one entry per slot and null where a slot is
## bare. Dealt on the first look and then held, so walking away from the board and
## coming back shows the same contracts rather than a fresh set.
func get_board() -> Array[Bounty]:
	if not _stocked:
		_stocked = true
		_stock_board()
	return _board


## The contracts actually hanging up, with the bare slots left out. For anything
## counting posters rather than drawing them.
func get_board_bounties() -> Array[Bounty]:
	var hanging: Array[Bounty] = []
	for bounty: Bounty in get_board():
		if bounty != null:
			hanging.append(bounty)
	return hanging


## How many slots the board has, filled or not.
func get_slot_count() -> int:
	return maxi(get_settings().poster_count, 0)


## How many of them are bare and could be dealt into the next time the player
## comes home.
func get_empty_slot_count() -> int:
	var bare := 0
	for bounty: Bounty in get_board():
		if bounty == null:
			bare += 1
	return bare


## The contracts the player has taken, finished ones included.
func get_active() -> Array[Bounty]:
	return _active


## The taken contracts that are still to be hunted.
func get_outstanding() -> Array[Bounty]:
	var open: Array[Bounty] = []
	for bounty: Bounty in _active:
		if bounty != null and bounty.is_outstanding():
			open.append(bounty)
	return open


## How many contracts may be held at once.
func get_active_slots() -> int:
	return get_settings().get_active_slots()


## How many of those are taken. A finished contract still holds its slot until
## something clears it out - closing that loop belongs to the milestone that
## pays the reward.
func get_used_slots() -> int:
	return _active.size()


func get_free_slots() -> int:
	return maxi(get_active_slots() - get_used_slots(), 0)


func has_free_slot() -> bool:
	return get_free_slots() > 0


## Whether [param bounty] can be taken right now: it exists, it is on the board,
## and there is somewhere to put it.
func can_accept(bounty: Bounty) -> bool:
	if bounty == null or bounty.accepted:
		return false
	return _board.has(bounty) and has_free_slot()


## Takes a contract off the board. Returns whether it went through, so the caller
## can offer the button and let this be the single place that decides.
##
## The order matters: the bounty is marked accepted - which is what locks its
## reward - before anything else touches it, so there is no window in which an
## accepted contract can still be repriced.
func accept(bounty: Bounty) -> bool:
	if not can_accept(bounty):
		return false

	bounty.mark_accepted()
	# The slot is emptied rather than closed up, so the posters that are left stay
	# where they were hanging and the gap is visible. Nothing is dealt into it now -
	# see [method refill_board], which only ever runs when the player comes home.
	var slot := _board.find(bounty)
	if slot >= 0:
		_board[slot] = null
	_active.append(bounty)

	if get_settings().refill_board_on_accept:
		_stock_board()

	bounty_accepted.emit(bounty)
	board_changed.emit()
	return true


## Gives a contract up. It leaves the player's slots and is [b]not[/b] put back on
## the board: the poster came down when it was taken, and the bare slot it left
## behind is only ever eligible again on the next ride home, exactly as an accepted
## one is.
##
## A finished contract cannot be cancelled - there is nothing to give up on a hunt
## that is already closed out.
func cancel(bounty_id: StringName) -> bool:
	var bounty := find_active(bounty_id)
	if bounty == null or bounty.completed:
		return false

	_active.erase(bounty)
	bounty_cancelled.emit(bounty)
	board_changed.emit()
	return true


## Closes out a taken contract. Nothing calls it during play yet - killing the
## target is a later milestone - but it is what that kill will end in, and it
## keeps completion something the ledger owns rather than something a boss
## writes onto a resource directly.
func complete(bounty_id: StringName) -> bool:
	var bounty := find_active(bounty_id)
	if bounty == null or not bounty.mark_completed():
		return false

	bounty_completed.emit(bounty)
	return true


## Learns one piece of information about a contract. [b]This is the call a later
## system reveals knowledge with[/b] - a mini boss handing over what it knew, a
## scout, an interrogation - and it is the reason revealing is a ledger method at
## all rather than something written onto a resource directly: everything that
## learns anything goes through one door, and that door announces it.
##
## [param category_id] names which piece: [constant Bounty.CATEGORY_MAP],
## [constant Bounty.CATEGORY_REGION], [constant Bounty.CATEGORY_TIME], or any
## category added to [BountySettings] later. Revealing a piece that is already
## known changes nothing and reports false, so a caller can tell a discovery from
## a repeat without checking first.
##
## [b]It never touches the reward[/b] - see [method Bounty.set_reward], which
## refuses once a bounty is accepted. Finding the outlaw out makes him easier to
## kill and no cheaper to kill for.
func reveal(bounty_id: StringName, category_id: StringName) -> bool:
	var bounty := find_bounty(bounty_id)
	if bounty == null or not bounty.reveal(category_id):
		return false

	knowledge_revealed.emit(bounty, category_id)
	return true


## Learns everything about one contract, and reports how many pieces that turned
## out to be. For a debug key, and for a later reward that hands over the lot.
func reveal_all(bounty_id: StringName) -> int:
	var bounty := find_bounty(bounty_id)
	if bounty == null:
		return 0

	var learned := 0
	for category_id: StringName in bounty.get_unknown_categories():
		if reveal(bounty_id, category_id):
			learned += 1
	return learned


## How much is known about [param bounty_id], and the most it could know. [b]This
## is what the mini boss system will ask[/b] before it builds a fight: nothing
## known is the hardest boss, everything known the weakest. An unknown contract
## answers 0, which is the blind end - the safe way round, since a fight that
## cannot find its contract should be the hard one rather than the free one.
func get_knowledge_count(bounty_id: StringName) -> int:
	var bounty := find_bounty(bounty_id)
	return 0 if bounty == null else bounty.get_knowledge_count()


## The most any contract can know: however many categories [BountySettings]
## lists.
func get_max_knowledge() -> int:
	return get_settings().get_max_knowledge()


## How blind [param bounty_id] is, 1.0 for a contract that knows nothing and 0.0
## for one that knows everything. The value boss difficulty is meant to be scaled
## off - see [method Bounty.get_knowledge_ratio].
func get_knowledge_ratio(bounty_id: StringName) -> float:
	var bounty := find_bounty(bounty_id)
	return 1.0 if bounty == null else bounty.get_knowledge_ratio()


## The contract with [param bounty_id] wherever it is - taken first, then still
## pinned to the board.
##
## Taken contracts are searched first because they are the ones the game asks
## about: a hunt, a reward and a completion all mean an accepted contract, and a
## board poster only ever shares an id with one by being the same object.
func find_bounty(bounty_id: StringName) -> Bounty:
	var taken := find_active(bounty_id)
	if taken != null:
		return taken
	for bounty: Bounty in _board:
		if bounty != null and bounty.bounty_id == bounty_id:
			return bounty
	return null


## The taken contract with [param bounty_id], or null when the player never took
## it.
func find_active(bounty_id: StringName) -> Bounty:
	for bounty: Bounty in _active:
		if bounty != null and bounty.bounty_id == bounty_id:
			return bounty
	return null


## Tears the board down and deals a fresh set into every slot. Nothing in play
## calls it - coming home goes through [method refill_board], which leaves hanging
## posters alone - but it is what a new day or a debug reset would use. Accepted
## contracts are untouched; they left the board when they were taken.
func refresh_board() -> void:
	_board.clear()
	_stocked = true
	_stock_board()
	board_changed.emit()


## Back to no board and no contracts. For a new save or a debug reset; nothing in
## a run calls it, the same way nothing calls [method BloodWallet.reset].
func reset() -> void:
	_board.clear()
	_active.clear()
	_issued = 0
	_stocked = false
	board_changed.emit()


## The taken contracts flattened to plain values, for a save file. Unused today -
## being an autoload is already what makes them survive a run - but it is the
## shape a disk save would write, and it holds what the milestone asked to be
## preserved: the locked reward, and every piece of information learned about
## each contract.
func save_state() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for bounty: Bounty in _active:
		if bounty != null:
			rows.append(bounty.to_save_dictionary())
	return rows


## Puts the taken contracts back from [method save_state], and reports how many
## were restored.
##
## The board is not restored with them and is deliberately left to be stocked
## fresh: what is pinned up is an offer rather than a possession, and a poster
## nobody took is no loss. What must come back exactly is a contract the player
## holds - the same id, the same locked price, the same lines filled in - and
## that is what this puts back.
##
## Ids carry on from the highest restored number, so a contract generated after a
## load cannot be handed an id a held one is already using.
func restore_state(rows: Array) -> int:
	var settings := get_settings()
	_active.clear()

	var restored := 0
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		var bounty := Bounty.from_save_dictionary(row, settings)
		_active.append(bounty)
		_issued = maxi(_issued, _id_number(bounty.bounty_id))
		restored += 1

	board_changed.emit()
	return restored


## Every contract the game is holding, written out for a developer: what is
## pinned up, what has been taken, and for each one what is known, what is not,
## and what it locked in. For the debug panel and for a print during a test.
func debug_report() -> String:
	var lines := PackedStringArray([
		"BOUNTIES  board %d  taken %d/%d" % [_board.size(), get_used_slots(), get_active_slots()],
	])

	lines.append("TAKEN")
	for bounty: Bounty in _active:
		if bounty != null:
			lines.append(bounty.get_debug_text())
	lines.append("BOARD")
	for bounty: Bounty in _board:
		if bounty != null:
			lines.append(bounty.get_debug_text())
	return "\n".join(lines)


## The running number out of a generated id, or 0 for an id that was not shaped
## like one. Read off the end rather than parsed, so a prefix that itself
## contains a number does not confuse it.
func _id_number(bounty_id: StringName) -> int:
	var text := String(bounty_id)
	var split := text.rfind("_")
	if split < 0:
		return 0
	var tail := text.substr(split + 1)
	return tail.to_int() if tail.is_valid_int() else 0


## Deals into the bare slots and leaves every hanging poster exactly where it is.
##
## [b]This is the only thing that ever puts a new contract on the board[/b], and it
## is called when the player comes home. A slot that already has a poster in it is
## never rerolled - what is pinned up stays pinned up until it is taken - so coming
## home twice without taking anything changes nothing.
##
## Returns how many new contracts were dealt.
func refill_board() -> int:
	if not _stocked:
		# Never looked at before: dealing it now is the same routine, so a first
		# visit and a return home go through one path.
		_stocked = true

	var dealt := _stock_board()
	if dealt > 0:
		board_changed.emit()
	return dealt


func _on_run_ended() -> void:
	refill_board()


## Deals into whichever slots are bare, by rarity, and reports how many contracts
## that produced.
##
## The board is a fixed row of slots rather than a list that is topped up, which is
## what makes an empty one possible: [method BountySettings.roll_board_slots] says
## which slots came up with anything, and the ones it does not name stay bare.
## Settings with no rarity rungs authored fall back to filling every bare slot,
## which is what the board did before rarity existed.
func _stock_board() -> int:
	var settings := get_settings()
	var slot_count := maxi(settings.poster_count, 0)
	_board.resize(slot_count)

	var dealt := 0
	if not settings.has_rarities():
		for slot: int in range(slot_count):
			if _board[slot] == null:
				var plain := settings.create_bounty(_next_id())
				if plain == null:
					break
				_board[slot] = plain
				dealt += 1
		return dealt

	var rolled := settings.roll_board_slots(slot_count)
	for slot_number: int in rolled:
		var index := slot_number - 1
		if index < 0 or index >= slot_count or _board[index] != null:
			# A slot that already has a poster in it is never rerolled, so a roll
			# landing on an occupied one is simply a roll that came to nothing.
			continue
		var bounty := settings.create_bounty(_next_id(), rolled[slot_number])
		if bounty == null:
			continue
		_board[index] = bounty
		dealt += 1
	return dealt


## Ids are handed out here rather than by the generator because this is the thing
## that knows what has already been issued. They stay unique for the life of the
## session, which is the life of the ledger.
func _next_id() -> StringName:
	_issued += 1
	return StringName("%s_%d" % [get_settings().id_prefix, _issued])
