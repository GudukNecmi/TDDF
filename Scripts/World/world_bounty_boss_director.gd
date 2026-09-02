class_name WorldBountyBossDirector
extends Node
## Turns the bounty posters the player is carrying into physical outlaws on
## the World Map - the seam between [RunInventory]'s posters, the
## [BountyLedger] that owns the contracts themselves, and the "walk up, press
## E, fight" the player actually does at a camp.
##
## [b]A carried, outstanding poster is the only thing that makes a boss
## exist.[/b] Nothing here reads the board or looks at a contract the player
## has not taken - rule 1 of the bounty camps phase - so [method _sync_tracked]
## builds exactly one [WorldBountyBoss] per contract the player is both
## holding and has not finished, and frees it the instant either stops being
## true. [BountyLedger] and [Bounty] remain the only place a contract's own
## facts live; this file only ever reads them.
##
## [b]Where and when he is are derived, never rolled.[/b] The region is
## [constant Bounty.CATEGORY_REGION]'s true value and the active window is
## read straight off [constant Bounty.CATEGORY_TIME]'s matching
## [WorldTimeManager] period - both already on the contract from the moment
## it was generated, see [BountySettings]. The camp is the one piece this
## file adds: see [method _assign_camp], which is the whole of rule 3's
## "three bounty camps per region" and rule 8's "do not create duplicate
## markers" - every camp is an existing [WorldMapLocation], never a node of
## this system's own.
##
## [b]Interaction goes through the location system it already has.[/b] This
## node never intercepts a key press itself: it listens to
## [signal WorldMapLocation.location_interacted] on the camp locations it
## has assigned a boss to, and only opens a fight when that boss is actually
## standing there right now - see [method _on_camp_interacted] and rule 16 of
## the phase, which asks for exactly this signal seam rather than boss
## behaviour written onto [WorldMapLocation] itself. The same rule's "expose
## that the location is active" is [method WorldMapLocation.set_occupied],
## called from [method _update_camp_occupancy] - a generic flag that file
## already reads, with no mention of a boss anywhere in it.
##
## [b]Combat is the existing bridge, asked for a second kind of fight.[/b]
## [method WorldMapCombatBridge.try_begin_boss_encounter] is the same node
## [WorldBandit] contact already opens a fight through - see that class's own
## doc - so nothing about the camera, world time, the player's position, the
## horse or a death is handled twice. See rule 17 and rule 22 of the phase.
##
## [b]One Blood Trail at a time.[/b] [member active_bounty_id] is the seam
## rule 15 asks for: whichever tracked contract it names is the one
## [BloodTrailEffect] is pointed at through [method _update_trail], and every
## other carried contract keeps being scheduled, travelling and waiting with
## no trail of its own. The default is simply the first contract found
## carried; a Bounties UI choosing a different one later is a call to
## [method set_active_bounty] and nothing here needs to change.

const CAMP_TYPE := MapLocation.LocationType.BOUNTY_CAMP

## One contract this director is currently keeping a [WorldBountyBoss] alive
## for.
class _Tracked:
	var bounty: Bounty
	var boss: WorldBountyBoss

@export var inventory_group: StringName = &"run_inventory"
@export var poster_category: StringName = &"bounty_poster"
@export var player_group: StringName = &"player"
@export var ledger_path: NodePath = ^"/root/Bounties"
@export var world_clock_path: NodePath = ^"/root/WorldClock"
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"

@export_group("Schedule")
## How many degrees before a contract's active window its boss starts
## travelling toward the camp. See rule 5 of the phase.
@export var arrival_lead_degrees: float = 40.0
## How many degrees after the window ends the boss keeps travelling away
## before the cycle reads as over.
@export var departure_delay_degrees: float = 25.0
## How far outside the camp a boss's travel begins and ends, in pixels.
@export var approach_distance: float = 1400.0
## How often the whole schedule is re-evaluated, in seconds - the same
## "a timer, not every frame" cadence [WorldMapLocationDirector] and
## [WorldMapFog] already use at this map's scale.
@export var update_interval: float = 0.25

@export_group("Blood Trail")
## How close the player has to be to a present boss for its trail to appear
## at all - see rule 12.
@export var trail_radius: float = 1500.0

## Whichever tracked contract's Blood Trail is currently the primary one -
## see the class doc. Empty when nothing is tracked.
var active_bounty_id: StringName = &""

var _tracked: Dictionary = {}
var _occupied_camps: Dictionary = {}
var _camps_wired: Dictionary = {}
var _trail: BloodTrailEffect
var _timer: float = 0.0

var _ledger: BountyLedger


func _enter_tree() -> void:
	add_to_group(&"world_bounty_boss_director")


func _ready() -> void:
	_ledger = get_node_or_null(ledger_path) as BountyLedger
	if _ledger != null:
		_ledger.bounty_completed.connect(_on_bounty_completed)
		_ledger.bounty_cancelled.connect(_on_bounty_cancelled)
	_trail = _build_trail()


## The director in this world, or null when it has none.
static func get_active(from_node: Node) -> WorldBountyBossDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(&"world_bounty_boss_director") as WorldBountyBossDirector


func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0

	_sync_tracked()
	_update_camp_occupancy()
	_update_trail()


## Names which tracked contract the Blood Trail should point at. Silently
## ignored for a contract this director is not currently tracking, so a
## stale id from a UI that has not refreshed cannot point the trail at
## nothing.
func set_active_bounty(bounty_id: StringName) -> void:
	if _tracked.has(bounty_id):
		active_bounty_id = bounty_id


func get_boss_for(bounty_id: StringName) -> WorldBountyBoss:
	var record: _Tracked = _tracked.get(bounty_id)
	return null if record == null else record.boss


# --- Which contracts exist -------------------------------------------------

func _carried_outstanding_bounties() -> Array[Bounty]:
	var result: Array[Bounty] = []
	var inventory := get_tree().get_first_node_in_group(inventory_group) as RunInventory
	if inventory == null:
		return result

	for stack: RunItemStack in inventory.get_slots():
		if stack == null or stack.category != poster_category:
			continue
		var bounty := stack.payload as Bounty
		if bounty != null and bounty.is_outstanding():
			result.append(bounty)
	return result


func _sync_tracked() -> void:
	var carried := _carried_outstanding_bounties()
	var seen: Dictionary = {}
	for bounty: Bounty in carried:
		seen[bounty.bounty_id] = true
		if not _tracked.has(bounty.bounty_id):
			_begin_tracking(bounty)

	for bounty_id: Variant in _tracked.keys().duplicate():
		if not seen.has(bounty_id):
			_stop_tracking(bounty_id)

	if active_bounty_id == &"" or not _tracked.has(active_bounty_id):
		active_bounty_id = carried[0].bounty_id if not carried.is_empty() else &""


func _begin_tracking(bounty: Bounty) -> void:
	var camp := _assign_camp(bounty)

	var boss := WorldBountyBoss.new()
	boss.name = "BountyBoss_%s" % String(bounty.bounty_id)
	boss.world_clock_path = world_clock_path
	boss.bounty = bounty
	boss.region_id = bounty.get_fact_value(Bounty.CATEGORY_REGION)
	boss.camp = camp
	boss.arrival_lead_degrees = arrival_lead_degrees
	boss.departure_delay_degrees = departure_delay_degrees
	boss.approach_distance = approach_distance
	boss.active_duration_degrees = _period_length_for(bounty)
	boss.period_start_degree = _period_start_for(bounty)
	add_child(boss)

	var record := _Tracked.new()
	record.bounty = bounty
	record.boss = boss
	_tracked[bounty.bounty_id] = record

	if camp != null:
		var camp_id := camp.get_location_id()
		if not _camps_wired.has(camp_id):
			camp.location_interacted.connect(_on_camp_interacted.bind(camp))
			_camps_wired[camp_id] = true


func _stop_tracking(bounty_id: Variant) -> void:
	var record: _Tracked = _tracked.get(bounty_id)
	if record == null:
		return
	_tracked.erase(bounty_id)
	if record.boss != null and is_instance_valid(record.boss):
		record.boss.queue_free()
	if active_bounty_id == bounty_id:
		active_bounty_id = &""


func _on_bounty_completed(bounty: Bounty) -> void:
	if bounty == null:
		return
	var record: _Tracked = _tracked.get(bounty.bounty_id)
	if record != null and record.boss != null and is_instance_valid(record.boss):
		# Left tracked-but-defeated rather than dropped here: the next
		# [method _sync_tracked] finds the contract no longer outstanding and
		# frees it through the ordinary path, so there is exactly one place
		# a tracked boss is ever torn down.
		record.boss.mark_defeated()


func _on_bounty_cancelled(bounty: Bounty) -> void:
	if bounty != null:
		_stop_tracking(bounty.bounty_id)


# --- Where he is, and when ---------------------------------------------------

## One of [param bounty]'s target's [member BountyTarget.possible_camps]
## inside its rolled region if it names any there, or otherwise whichever of
## that region's [constant CAMP_TYPE] locations the contract's own id picks -
## so the same contract always uses the same camp for the run. Null only
## when the region has no bounty camp at all.
func _assign_camp(bounty: Bounty) -> WorldMapLocation:
	var region_id := bounty.get_fact_value(Bounty.CATEGORY_REGION)
	var candidates := _camps_in_region(region_id)
	if candidates.is_empty():
		return null

	var target := bounty.target
	if target != null and not target.possible_camps.is_empty():
		var named: Array[WorldMapLocation] = []
		for location: WorldMapLocation in candidates:
			if target.possible_camps.has(location.get_location_id()):
				named.append(location)
		if not named.is_empty():
			candidates = named

	var index := absi(hash(String(bounty.bounty_id))) % candidates.size()
	return candidates[index]


func _camps_in_region(region_id: StringName) -> Array[WorldMapLocation]:
	var found: Array[WorldMapLocation] = []
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location == null or location.get_location_type() != CAMP_TYPE:
			continue
		if location.get_region_id() == region_id:
			found.append(location)
	return found


## The index into [method WorldTimeManager.period_names] whose name matches
## [param bounty]'s [constant Bounty.CATEGORY_TIME] line - the true answer,
## not whether the player has learned it. [BountySettings] writes that line's
## [member BountyFact.display_text] straight from the matching
## [DayStage.display_name], and the desert's six day stages are named
## exactly [member WorldTimeManager.period_names] - "DAWN" through "NIGHT" -
## so the match is a plain string comparison rather than a second table
## translating one naming scheme into the other. -1 for a contract with no
## time line, or a map whose stage names have drifted from the clock's own.
func _period_index_for(bounty: Bounty) -> int:
	var fact := bounty.get_fact(Bounty.CATEGORY_TIME)
	var clock := _resolve_clock()
	if fact == null or clock == null:
		return -1
	var wanted := StringName(fact.display_text)
	for i: int in range(clock.period_names.size()):
		if clock.period_names[i] == wanted:
			return i
	return -1


func _period_start_for(bounty: Bounty) -> float:
	var clock := _resolve_clock()
	var index := _period_index_for(bounty)
	if clock == null or index < 0 or index >= clock.period_boundaries.size():
		return 0.0
	return clock.period_boundaries[index]


## How many degrees [param bounty]'s active period itself spans - see
## [method WorldTimeManager._period_length], read out here the same way
## rather than duplicated as a guess, since that method is private to the
## clock and this only ever needs the two boundaries either side of it.
func _period_length_for(bounty: Bounty) -> float:
	var clock := _resolve_clock()
	var index := _period_index_for(bounty)
	if clock == null or index < 0:
		return 60.0

	var boundaries := clock.period_boundaries
	var start: float = boundaries[index]
	var next: float = clock.degrees_per_day
	if index + 1 < boundaries.size():
		next = boundaries[index + 1]
	if next <= start:
		next += clock.degrees_per_day
	return next - start


func _resolve_clock() -> WorldTimeManager:
	return get_node_or_null(world_clock_path) as WorldTimeManager


# --- The camp lighting up, and the fight starting -----------------------------

func _update_camp_occupancy() -> void:
	var occupied: Dictionary = {}
	for record: _Tracked in _tracked.values():
		var boss := record.boss
		if boss != null and is_instance_valid(boss) and boss.camp != null and boss.is_present():
			occupied[boss.camp] = true

	for camp: Variant in occupied.keys():
		(camp as WorldMapLocation).set_occupied(true)
	for camp: Variant in _occupied_camps.keys():
		if not occupied.has(camp) and is_instance_valid(camp):
			(camp as WorldMapLocation).set_occupied(false)
	_occupied_camps = occupied


## A camp the player has pressed E on. Ignored unless a boss this director is
## tracking is both assigned to it and actually standing there right now -
## see rule 9 and rule 10, "do not start combat just because the camp exists
## or the player arrived early".
func _on_camp_interacted(camp: WorldMapLocation) -> void:
	var record := _present_record_at(camp)
	if record == null:
		return

	var bridge := _resolve_bridge()
	if bridge == null:
		return
	bridge.try_begin_boss_encounter(record.boss)


func _present_record_at(camp: WorldMapLocation) -> _Tracked:
	for record: _Tracked in _tracked.values():
		var boss := record.boss
		if boss == null or not is_instance_valid(boss) or boss.camp != camp:
			continue
		if boss.get_state() == WorldBountyBoss.State.AT_CAMP:
			return record
	return null


func _resolve_bridge() -> WorldMapCombatBridge:
	var named := get_node_or_null(bridge_path) as WorldMapCombatBridge
	return named if named != null else WorldMapCombatBridge.get_active(self)


# --- Blood Trail --------------------------------------------------------------

func _build_trail() -> BloodTrailEffect:
	var node := Node2D.new()
	node.name = "BloodTrailEffect"
	node.set_script(load("res://Scripts/World/blood_trail_effect.gd"))
	add_child(node)
	return node as BloodTrailEffect


func _update_trail() -> void:
	if _trail == null:
		return

	var record: _Tracked = _tracked.get(active_bounty_id)
	var boss: WorldBountyBoss = null if record == null else record.boss
	if boss == null or not is_instance_valid(boss) or not boss.is_present():
		_trail.set_active(false)
		return

	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null or not _player_matches_situation(record.bounty, player):
		_trail.set_active(false)
		return

	var distance := player.global_position.distance_to(boss.global_position)
	if distance > trail_radius:
		_trail.set_active(false)
		return

	_trail.set_active(true)
	_trail.configure(player.global_position, boss.global_position, distance, trail_radius)


## Whether the player is currently standing in [param bounty]'s own region,
## during its own required period - rule 12's "is in the correct
## region/time window", asked of the player rather than the boss, which
## already carries its own presence check in [method WorldBountyBoss.is_present].
func _player_matches_situation(bounty: Bounty, player: Node2D) -> bool:
	var state := WorldMapState.get_active(self)
	if state == null:
		return false
	if state.get_region_id() != bounty.get_fact_value(Bounty.CATEGORY_REGION):
		return false

	var fact := bounty.get_fact(Bounty.CATEGORY_TIME)
	if fact == null:
		return false
	return String(state.get_time_period_name()) == fact.display_text
