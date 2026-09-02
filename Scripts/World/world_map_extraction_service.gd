class_name WorldMapExtractionService
extends Node
## The run's single Extraction authority - owns which of the World Map's 13
## Extraction points are live this run, the instant no-countdown trigger,
## the Blood settlement, the bounty payout and penalty, and carrying the
## player home. See the Extraction phase's own rule 7: nothing about run
## settlement belongs on [WorldMapLocation] itself, and this is the one
## place it lives instead.
##
## [b]Extraction points are the existing [WorldMapLocation]s, never
## duplicated.[/b] Exactly like [BloodDepotService] before it, this never
## builds a marker of its own - it walks every [WorldMapLocation] already in
## the scene, keeps the ones whose [method WorldMapLocation.get_location_type]
## is [constant MapLocation.LocationType.EXTRACTION], and listens to each
## one's own [signal WorldMapLocation.location_interacted].
##
## [b]Active selection happens once, in [method _ready].[/b] The World Map is
## only rebuilt at a true run boundary - riding home, the next run - so a
## fresh [WorldMapExtractionService] coming up the first time this scene
## loads [i]is[/i] "run start" with nothing else needed to detect it, and the
## selection it makes here is never rerolled again until the next rebuild -
## rule 3's "do not reroll during the run", for free.
##
## [b]Unlocked but unlit and locked read the same, deliberately.[/b] Only the
## ids [method _activate_extractions] actually picked ever have
## [method WorldMapLocation.set_occupied] called true on them - reusing the
## exact generic "something notable is here" flag the bounty camps phase
## already built rather than adding a second one, see that class's own doc -
## and every other Extraction point, unlocked-but-not-chosen or still locked
## alike, is left with its ordinary green Extraction colour and an
## [member WorldMapLocation.action_label_override] naming it inert. Rule 5
## only ever asks for the two states "active" and everything else; this
## phase does not need a third look for "locked forever" against "not picked
## this time".
##
## [b]Triggering is instant and cannot be duplicated.[/b] [member run_active]
## goes false the instant the first active Extraction is reached - see
## [method _on_location_interacted] - so a second location interacted with a
## frame later, or the same one pressed twice, changes nothing.
## [ExtractionHold] is frozen in the same beat, which is rule 8's "do not
## allow the player to continue moving" kept the same way every other speed
## modifier in this game already is.
##
## [b]Settlement happens before the result screen ever opens.[/b] Rule 6 is
## explicit - Extraction is instant, with no secondary confirmation - so the
## moment of walking into an active point's reach is the moment the money
## actually moves and every carried bounty is judged; the
## [ExtractionResultScreen] that follows only ever reads what
## [ExtractionSettlement] already recorded. There is no way to back out of it
## the way [CashOutScreen] can be escaped, because by the time it is showing
## anything, extraction has already happened.
##
## [b]Getting home is the existing journey, asked a second time.[/b]
## [method Teleporter.teleport] with no override sends the player to
## whatever [member Teleporter.destination_id] already names - the base - the
## same call [PlayerDeathSequence] makes to carry a beaten player home. This
## never opens a second transition system; it only waits for
## [signal Teleporter.teleported] before finally calling
## [method RunSessionState.end], in the same order the death sequence already
## does it.

## Emitted once an Extraction has actually happened, with the full receipt -
## the clean run-ended hook rule 20 asks for, so a later Score system can
## total the run without this file ever mentioning Score.
signal run_extracted(settlement: ExtractionSettlement)
## Emitted the instant an active Extraction is reached, before settlement is
## computed - for a result screen or a debug readout to raise itself off of.
signal extraction_triggered(location: WorldMapLocation)

const EXTRACTION_TYPE := MapLocation.LocationType.EXTRACTION

@export_group("Selection")
## How many Extraction points are made active this run. Rule 22's own
## default; a future Base upgrade raising this is one call to
## [method set_max_active_extractions] away, 1 through 5, with nothing else
## here needing to change.
@export var max_active_extractions: int = 2
## The permanent unlock state - the [code]ExtractionUnlocks[/code] autoload.
## Missing or absent, every point is treated as unlocked, which is the same
## fail-open [WorldMapFog.get_active] and [WorldMapPlayerPower.get_active]
## already answer with for a scene that has not added the system they ask
## about.
@export var unlock_state_path: NodePath = ^"/root/ExtractionUnlocks"
## How much less likely a region is to have an active Extraction chosen in
## it as its own [method MapRegion.get_difficulty] rises toward 1 - rule 4's
## "simple weighted region selection", kept to one configurable knob rather
## than a curve, since no per-player progression figure exists yet to weigh
## against. 0 makes every region equally likely regardless of danger; 1 makes
## the easiest region roughly [member region_weight_floor] as likely again as
## the hardest one.
@export_range(0.0, 1.0) var region_weight_bias: float = 0.7
## The least a region's own weight is ever allowed to fall to, however
## dangerous it is - what stops the highest region from becoming
## impossible to land in outright, only unlikely. See rule 4: "do not place
## every active extraction in the highest region", not "never".
@export_range(0.01, 1.0) var region_weight_floor: float = 0.2
## What an Extraction not chosen active this run - unlocked or not - says
## instead of EXTRACT.
@export var inactive_action_label: String = "INACTIVE"

@export_group("Wiring")
@export var player_group: StringName = &"player"
@export var inventory_group: StringName = &"run_inventory"
@export var extraction_hold_group: StringName = &"extraction_hold"
@export var region_zone_group: StringName = &"world_map_region_zone"
@export var carried_wallet_path: NodePath = ^"/root/Blood"
@export var horse_blood_path: NodePath = ^"/root/HorseBlood"
@export var bank_path: NodePath = ^"/root/BloodBank"
@export var ledger_path: NodePath = ^"/root/Bounties"
@export var session_path: NodePath = ^"/root/RunSession"
@export var result_screen_path: NodePath = ^"../RunHUD/ExtractionResultScreen"

@export_group("Bounty settlement")
## Rule 10's flat reward for a bounty poster that was completed by the time
## the player extracted. Deliberately not [member Bounty.reward] - that
## figure is the contract's own locked price for a payout this phase is
## explicitly told not to build yet; see the class doc on [Bounty.reward]
## and rule 18 of the Extraction phase, "do NOT implement the final +100
## Blood Extraction settlement" as part of the bounty camps phase - this
## file is that settlement, and its number is this export, not that field.
@export var completed_bounty_reward: int = 100
## What an incomplete bounty costs when its region has no entry below.
@export var default_incomplete_penalty: int = 200
## Per-region penalty for a bounty that was still outstanding at extraction -
## rule 10's own table, kept as data rather than a branch so a sixth region
## is one more entry rather than a code change.
@export var region_incomplete_penalties: Dictionary = {
	&"A": 200, &"B": 250, &"C": 300, &"D": 350, &"E": 400,
}

## Whether this Extraction service still believes the World Map run is
## under way. Rule 8's own name for the flag, false from the instant an
## active Extraction is first reached and never set back true - a fresh one
## comes with the next rebuild.
var run_active: bool = true

var _active_ids: Dictionary = {}
var _extracted: bool = false
var _locations: Array[WorldMapLocation] = []


func _ready() -> void:
	_locations = _find_extraction_locations()
	_activate_extractions()
	for location: WorldMapLocation in _locations:
		location.location_interacted.connect(_on_location_interacted.bind(location))


func is_active(extraction_id: StringName) -> bool:
	return _active_ids.has(extraction_id)


func get_active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in _active_ids.keys():
		ids.append(key as StringName)
	return ids


## Raises or lowers how many Extraction points a run activates - the seam a
## future Base upgrade calls, 1 through 5 per rule 22. Only ever meaningful
## before [method _ready] has run its own selection; changing it mid-run
## does not reroll what is already active, per rule 3.
func set_max_active_extractions(value: int) -> void:
	max_active_extractions = maxi(value, 0)


# --- Selecting the run's active points ---------------------------------------

func _find_extraction_locations() -> Array[WorldMapLocation]:
	var found: Array[WorldMapLocation] = []
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location != null and location.get_location_type() == EXTRACTION_TYPE:
			found.append(location)
	return found


## Rolls [member max_active_extractions] distinct Extraction points active,
## weighted by region per [method _region_weight], and marks every other one
## - unlocked or not - as inert. Never activates a locked point; see
## [method _unlocks].
func _activate_extractions() -> void:
	var unlocks := get_node_or_null(unlock_state_path) as ExtractionUnlockState

	var pool: Array[WorldMapLocation] = []
	for location: WorldMapLocation in _locations:
		var unlocked := unlocks == null or unlocks.is_unlocked(location.get_location_id())
		if unlocked:
			pool.append(location)

	var chosen := _weighted_pick(pool, maxi(max_active_extractions, 0))

	_active_ids.clear()
	for location: WorldMapLocation in chosen:
		_active_ids[location.get_location_id()] = true

	for location: WorldMapLocation in _locations:
		if _active_ids.has(location.get_location_id()):
			location.action_label_override = ""
			location.set_occupied(true)
		else:
			location.action_label_override = inactive_action_label
			location.set_occupied(false)


## Picks up to [param count] distinct locations out of [param pool] without
## replacement, weighted by [method _region_weight] - rule 4's "simple
## weighted region selection seam", worked as the textbook
## weighted-sampling-without-replacement it is rather than anything
## cleverer: sum the remaining pool's weights, roll under that sum, walk the
## pool until the roll is spent, remove what was found and repeat.
func _weighted_pick(pool: Array[WorldMapLocation], count: int) -> Array[WorldMapLocation]:
	var remaining := pool.duplicate()
	var chosen: Array[WorldMapLocation] = []

	while chosen.size() < count and not remaining.is_empty():
		var weights: Array[float] = []
		var total := 0.0
		for location: WorldMapLocation in remaining:
			var weight := _region_weight(location.get_region_id())
			weights.append(weight)
			total += weight

		if total <= 0.0:
			# Every remaining candidate weighed to nothing - falls back to a
			# plain uniform pick rather than picking nobody, so a region
			# table authored all the way down to 0 still lets a run start.
			var index := randi() % remaining.size()
			chosen.append(remaining[index])
			remaining.remove_at(index)
			continue

		var roll := randf() * total
		var walked := 0.0
		for i: int in range(remaining.size()):
			walked += weights[i]
			if roll <= walked:
				chosen.append(remaining[i])
				remaining.remove_at(i)
				break

	return chosen


## How likely [param region_id] is to have an active Extraction rolled into
## it, relative to another region - 1 for a region with no danger at all,
## sliding down to [member region_weight_floor] for the most dangerous one
## a [WorldMapRegionZone] currently reports, scaled by [member region_weight_bias].
## A region with no zone found - or [member region_weight_bias] left at 0 -
## answers 1, which is every region weighed equally, exactly rule 4's
## fallback for "no suitable progression source exists yet".
func _region_weight(region_id: StringName) -> float:
	var difficulty := _region_difficulty(region_id)
	var floor_weight := clampf(region_weight_floor, 0.01, 1.0)
	return lerpf(1.0, floor_weight, clampf(region_weight_bias, 0.0, 1.0) * difficulty)


func _region_difficulty(region_id: StringName) -> float:
	for node: Node in get_tree().get_nodes_in_group(region_zone_group):
		var zone := node as WorldMapRegionZone
		if zone != null and zone.region != null and zone.region.region_id == region_id:
			return zone.region.get_difficulty()
	return 0.0


# --- Triggering ----------------------------------------------------------------

## Rule 18's "should not become an interaction target" for a point this
## service never activated: a location whose signal fires without ever being
## in [member _active_ids] simply changes nothing.
func _on_location_interacted(location: WorldMapLocation) -> void:
	if not run_active or _extracted:
		return
	if not is_active(location.get_location_id()):
		return

	_extracted = true
	run_active = false
	extraction_triggered.emit(location)

	_freeze_player()

	var settlement := _settle()
	_clear_run_scoped_resources()
	run_extracted.emit(settlement)

	_show_result(settlement)


func _freeze_player() -> void:
	var hold := get_tree().get_first_node_in_group(extraction_hold_group)
	if hold != null and hold.has_method(&"set_frozen"):
		hold.call(&"set_frozen", true)


# --- Settlement ------------------------------------------------------------

## Rule 11's single deterministic calculation, worked exactly once and
## handed back as a receipt. Nothing here is shown to the player directly -
## see [method _show_result] - so a result screen and a debug print read the
## identical numbers rather than two copies of the formula.
func _settle() -> ExtractionSettlement:
	var settlement := ExtractionSettlement.new()

	var wallet := get_node_or_null(carried_wallet_path) as BloodWallet
	var horse := get_node_or_null(horse_blood_path) as BloodWallet
	var bank := get_node_or_null(bank_path) as BloodWallet
	var ledger := get_node_or_null(ledger_path) as BountyLedger

	settlement.player_blood = 0 if wallet == null else wallet.get_total()
	settlement.horse_blood = 0 if horse == null else horse.get_total()
	settlement.base_run_blood = settlement.player_blood + settlement.horse_blood

	_settle_bounties(settlement, ledger)

	settlement.final_blood = maxi(
		settlement.base_run_blood + settlement.bounty_reward_total - settlement.bounty_penalty_total, 0)

	# The whole of this run's Blood becomes the permanent figure computed
	# above - never a plain transfer of the carried and horse totals, since
	# a bounty penalty can eat into blood that was actually carried home and
	# the clamp above can throw away more still. Both run-scoped wallets are
	# emptied regardless of which way the arithmetic went, because every
	# Blood they held has already been accounted for in [member ExtractionSettlement.final_blood]
	# one way or the other - see rule 12: this never rewrites
	# [code]Total Blood Collected[/code] or any other history, because it
	# never reads or writes anything but these three run/permanent wallets.
	if bank != null and settlement.final_blood > 0:
		bank.add(settlement.final_blood)
	if wallet != null:
		wallet.reset()
	if horse != null:
		horse.reset()

	return settlement


## Judges every bounty poster the player is carrying and folds it into
## [param settlement], and gives up any that came home unfinished - rule 10's
## "do not carry incomplete bounty into the next run", spent the same way
## giving up a contract by hand already is: [method BountyLedger.cancel]
## leaves its board slot bare until the ride home refills it, which
## [method RunSessionState.end] triggers a beat later in [method _return_to_base].
func _settle_bounties(settlement: ExtractionSettlement, ledger: BountyLedger) -> void:
	var inventory := get_tree().get_first_node_in_group(inventory_group) as RunInventory
	if inventory == null:
		return

	for stack: RunItemStack in inventory.get_slots():
		if stack == null or stack.category != &"bounty_poster":
			continue
		var bounty := stack.payload as Bounty
		if bounty == null:
			continue

		if bounty.completed:
			settlement.completed_bounties.append(bounty)
			settlement.bounty_reward_total += maxi(completed_bounty_reward, 0)
		elif bounty.is_outstanding():
			settlement.incomplete_bounties.append(bounty)
			settlement.bounty_penalty_total += _penalty_for(bounty)
			if ledger != null:
				ledger.cancel(bounty.bounty_id)


func _penalty_for(bounty: Bounty) -> int:
	var region_id := bounty.get_fact_value(Bounty.CATEGORY_REGION)
	if region_incomplete_penalties.has(region_id):
		return maxi(int(region_incomplete_penalties[region_id]), 0)
	return maxi(default_incomplete_penalty, 0)


## Rule 13's "Run Inventory ends with the run" and "Horse run state ends
## with the run", spent the instant Extraction settles rather than left to
## wait on [method SceneTree.reload_current_scene].
##
## [b]Why this cannot simply be assumed.[/b] [RunInventory]'s own doc names
## a scene reload as the one thing that ever empties it, and that is true
## for the story's round-to-round loop - but [RunPortal] answering a World
## Map run deliberately never reloads the scene to get there, by design; see
## [member RunPortal.enters_world_map]'s own doc, "no scene reload". Nothing
## about that is this phase's to change, so rather than lean on a reload
## that this run's own journey home never triggers, this clears both by
## hand at the one moment rule 13 says they should end - using only each
## class's own already-public surface, never a rewrite of either.
func _clear_run_scoped_resources() -> void:
	var inventory := get_tree().get_first_node_in_group(inventory_group) as RunInventory
	if inventory != null:
		var slots := inventory.get_slots()
		for i: int in range(slots.size()):
			var stack := slots[i]
			# The weapon slot is left standing. It only ever mirrors
			# [WeaponMount]'s own choice - see [method RunInventory._seed_starting_weapon] -
			# and nothing about Extraction changes what is actually in the
			# player's hands, so clearing it here would desync the row from
			# the weapon still drawn rather than end anything.
			if stack != null and stack.category != &"weapon":
				inventory.remove_slot(i)

	var horse := get_tree().get_first_node_in_group(&"world_map_horse")
	if horse != null:
		horse.set_mounted(false)
		# Fatigue is cleared first - [method WorldMapHorse.get_max_stamina]
		# reads the current fatigue to work out the ceiling, so asking for it
		# before the reset would hand back a fresh horse still capped by the
		# tired one's ceiling.
		horse.set(&"fatigue", 0.0)
		if horse.has_method(&"get_max_stamina"):
			horse.set(&"current_stamina", horse.call(&"get_max_stamina"))
		horse.set(&"horse_food", horse.get(&"starting_horse_food"))


# --- The result screen, and the ride home ------------------------------------

func _show_result(settlement: ExtractionSettlement) -> void:
	var screen := get_node_or_null(result_screen_path)
	if screen != null and screen.has_method(&"show_settlement"):
		screen.call(&"show_settlement", settlement)
		if not screen.is_connected(&"continued", Callable(self, &"_return_to_base")):
			screen.connect(&"continued", Callable(self, &"_return_to_base"))
		return

	# No result screen wired up: the settlement already happened above, so
	# the run still ends correctly, just without anything shown for it.
	_return_to_base()


## The existing Base return journey, asked for a second time rather than
## rebuilt - see the class doc. [b]The World Map run is fully over before
## this is even called[/b]: [member run_active] went false and every wallet
## was already settled the instant Extraction triggered, so nothing about
## rule 15's "World Map run must be completely terminated before Base
## arrival" is still pending by the time the body actually moves.
func _return_to_base() -> void:
	var player := get_tree().get_first_node_in_group(player_group) as Node
	var teleporter: Teleporter = null
	if player != null:
		for node: Node in player.find_children("*", "Teleporter", true, false):
			teleporter = node as Teleporter
			break

	if teleporter == null:
		_end_session()
		return

	if not teleporter.teleported.is_connected(_on_arrived_home):
		teleporter.teleported.connect(_on_arrived_home, CONNECT_ONE_SHOT)
	if not teleporter.teleport(false, false):
		teleporter.teleported.disconnect(_on_arrived_home)
		_end_session()


func _on_arrived_home(_destination: TeleportDestination) -> void:
	_end_session()


## The other half of coming home - see [method PlayerDeathSequence._end_the_run]
## for the identical call, made at the identical moment: once the body has
## actually arrived. [RunSessionState] is what a resupply, the wanted board's
## refill and the next world built read to know the run is over.
func _end_session() -> void:
	var session := get_node_or_null(session_path)
	if session != null and session.has_method(&"end"):
		session.call(&"end")
