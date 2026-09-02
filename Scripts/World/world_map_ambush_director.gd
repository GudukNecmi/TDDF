class_name WorldMapAmbushDirector
extends Node
## The World Map's own organised ambush: three roaming [WorldBandit] groups,
## ordered to converge on the player together, that the player can outrun.
##
## [b]It never spawns anything.[/b] Every group it ever moves is one of the
## same roaming [WorldBandit] instances [WorldMap.tscn] already authors -
## [method _find_ambush_candidates] only ever picks among them and
## [method WorldBandit.begin_ambush] only ever redirects one already walking
## its own patrol route. No second bandit system, no second AI and no second
## combat entry exist anywhere in this file - see that method's own doc for
## what actually changes about a group's behaviour while it is ambushing.
##
## [b]The regional number is the base; the hour is what it is multiplied
## by.[/b] [method MapRegion.get_difficulty] - the same 0..1 figure
## [WorldMapCombatBridge] already reads to size an ordinary fight - is read
## once a roll and never written to, so nothing here touches how dangerous a
## region already is. [member period_multipliers] is the whole of "evening
## and night are worse", indexed by [enum WorldTimeManager.TimePeriod] and
## tuned from the inspector rather than branched on by name.
##
## [b]A catch is not a second fight.[/b] The three groups this chooses are
## ordinary [WorldBandit] instances, so the instant one of them actually
## reaches the player, [WorldMapCombatBridge]'s own [method Node._process]
## notices the contact exactly as it would any other and opens the identical
## decision-then-fight it always does - nothing here knows that flow exists.
## The only trace this leaves for that fight is [member WorldBandit.in_ambush]
## still being true on whichever group caught the player, which is what lets
## [method WorldMapCombatBridge._resupply_equipped_weapon] tell an ambush's
## own catch apart from an ordinary contact.
##
## [b]An escape is not a deletion.[/b] [method _update_active_ambush] watches
## the player's distance to whichever of the three groups are still
## ambushing and, once every one of them is past [member escape_distance],
## calls [method WorldBandit.end_ambush] on each - which is [method WorldBandit._enter_patrol]
## under another name. The groups stay on the map, roaming their routes, and
## can spot the player again later exactly as any other group would.

## Group this joins, so a caller can find the one active director the same
## way it finds [WorldMapCombatBridge] or [WorldMapState].
const GROUP := &"world_map_ambush_director"
## Group every candidate is read off - the same one [WorldMapCombatBridge]
## already watches for contact.
const BANDIT_GROUP := &"world_bandit"
## The three group sizes an ambush's own attackers are drawn from. Never a
## fourth size and never invented: a candidate whose [member WorldBandit.group_strength]
## does not land within [member size_tolerance] of one of these is simply not
## considered.
const FORMATION_SIZES: PackedFloat32Array = [10.0, 20.0, 30.0]

@export var player_group: StringName = &"player"
@export var combat_bridge_path: NodePath = ^"../WorldMapCombatBridge"
@export var world_state_path: NodePath = ^"../WorldMap/WorldTime"
@export var world_clock_path: NodePath = ^"/root/WorldClock"
## The banner shown for as long as at least one of the three chosen groups is
## still ambushing - see [AmbushBanner]. Optional: a build with none simply
## never shows anything, exactly as every ambush behaved before this screen
## existed.
@export var banner_path: NodePath = ^"../RunHUD/AmbushBanner"
## The cue played once as an ambush actually opens - see [StingerBoard]'s own
## [code]&"ambush"[/code] variant set. Optional: a build with none plays this
## in silence.
@export var stinger_path: NodePath = ^"../RunHUD/StingerBoard"

@export_group("Probability")
## How often, in seconds, a fresh ambush is rolled for while none is active
## and no cooldown is running.
@export var roll_interval: float = 6.0
## The base chance used when the player is standing in no authored region at
## all - which every other roll reads [method MapRegion.get_difficulty]
## for instead. Kept low on purpose: this is the map's own way in, not one of
## its named places.
@export_range(0.0, 1.0, 0.01) var fallback_base_probability: float = 0.05
## What the region's own base probability is multiplied by for each of
## [enum WorldTimeManager.TimePeriod], in that same order - Dawn, Morning,
## Noon, Evening, Twilight, Night. Above 1 makes an hour more dangerous than
## the region's own number alone would say; 1 leaves it untouched. Tuned here
## rather than branched on a period's name, so retuning "evening and night are
## worse" is five numbers rather than an edit to this script.
@export var period_multipliers: Array[float] = [1.0, 1.0, 1.0, 1.6, 2.1, 2.6]
## Seconds an ambush stays impossible to roll again after the last one ends,
## whichever way it ended - escaped or caught.
@export var cooldown_seconds: float = 25.0

@export_group("Formation")
## How far from the player a candidate group is still allowed to be chosen
## from. Generous on purpose - an ambush's own three groups are meant to be
## seen converging from genuinely different starts, not standing shoulder to
## shoulder - and safe to be, since a chosen group ignores its own
## [member WorldBandit.detection_radius] and [member WorldBandit.chase_break_distance]
## entirely for as long as it is ambushing; see [method WorldBandit.begin_ambush].
@export var search_radius: float = 2600.0
## How far a candidate's [member WorldBandit.group_strength] may sit from one
## of [constant FORMATION_SIZES] and still count as that size.
@export var size_tolerance: float = 4.0
## How many of the three formation sizes must actually be found nearby before
## an ambush is allowed to trigger at all. Left at 3 - a real "three groups
## converging" - a roll that cannot fill every size simply does nothing and
## tries again at the next interval.
@export_range(1, 3) var min_ambush_groups: int = 3

@export_group("Escape")
## How far the player has to be from every one of an ambush's own groups
## before it is considered escaped - the one number that decides it, read
## here rather than off each group's own [member WorldBandit.chase_break_distance],
## which an ambushed group ignores for exactly this reason. See
## [method WorldBandit.end_ambush].
@export var escape_distance: float = 1400.0

var _roll_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _ambush_bandits: Array[WorldBandit] = []
var _ambush_active: bool = false
## True for as long as the banner was lowered on account of a fight or a
## decision screen being open, rather than the ambush itself actually ending -
## see [method _process]. What tells the restore in that same method a banner
## it takes back down should really be brought back up, instead of leaving a
## finished ambush's own banner stuck showing.
var _banner_suppressed_for_combat: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


## The director in this world, or null when there is none - which every
## caller reads as "no World Map ambush exists to ask about".
static func get_active(from_node: Node) -> WorldMapAmbushDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapAmbushDirector


func is_ambush_active() -> bool:
	return _ambush_active


func _process(delta: float) -> void:
	var bridge := _resolve_bridge()
	# Held entirely still while a fight or a decision is open - see the class
	# doc's note on a catch never being a second fight - so this never rolls a
	# second ambush over the top of one already resolving, and never measures
	# the player's World Map position against it while they are actually
	# standing in the Arena.
	if bridge != null and (bridge.is_running() or bridge.is_deciding()):
		# The banner is a World Map presentation exactly like the formation
		# boxes [WorldMapCombatBridge] itself hides for the fight - see rule
		# 10 of the combat-leak fix: no AMBUSH banner is meant to be on
		# screen for a fight that is not itself an authored Ambush
		# presentation. Lowered rather than ended: [member _ambush_active]
		# and every chosen group are untouched, so the ambush this interrupted
		# is exactly what [method _update_active_ambush] resumes reading the
		# instant the fight or the decision is over.
		if _ambush_active and not _banner_suppressed_for_combat:
			_banner_suppressed_for_combat = true
			_hide_banner()
		return

	var resuming_after_combat := _banner_suppressed_for_combat
	_banner_suppressed_for_combat = false

	if _ambush_active:
		_update_active_ambush()
		# Only brought back once [method _update_active_ambush] has had its say -
		# a fight that just ended the whole ambush already called
		# [method _end_ambush_state] above, which leaves [member _ambush_active]
		# false by now, so this never flashes the banner back up for a beat
		# before immediately lowering it again.
		if resuming_after_combat and _ambush_active:
			_show_banner()
		return

	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_roll_timer += delta
	if _roll_timer < roll_interval:
		return
	_roll_timer = 0.0
	if _cooldown_timer > 0.0:
		return
	_try_trigger_ambush()


# --- Rolling a fresh ambush ---------------------------------------------

func _try_trigger_ambush() -> void:
	var player := _resolve_player()
	if player == null:
		return

	var chance := clampf(_base_probability() * _time_of_day_multiplier(), 0.0, 1.0)
	if chance <= 0.0 or randf() > chance:
		return

	var chosen := _find_ambush_candidates(player)
	if chosen.size() < min_ambush_groups:
		return

	_ambush_bandits = chosen
	for bandit: WorldBandit in _ambush_bandits:
		bandit.begin_ambush(player.global_position)

	_ambush_active = true
	_show_banner()
	_play_ambush_cue()


## The region's own authored danger, read exactly as [WorldMapCombatBridge]
## already reads it to size an ordinary fight - never a second scale
## invented for this feature. [member fallback_base_probability] stands in
## only when the player is in no authored region at all.
func _base_probability() -> float:
	var state := _resolve_world_state()
	var region: MapRegion = state.current_region if state != null else null
	if region == null:
		return fallback_base_probability
	return region.get_difficulty()


func _time_of_day_multiplier() -> float:
	var clock := _resolve_world_clock()
	if clock == null or not clock.has_method(&"get_time_period_index"):
		return 1.0
	var index: int = clock.call(&"get_time_period_index")
	if index < 0 or index >= period_multipliers.size():
		return 1.0
	return maxf(period_multipliers[index], 0.0)


## Picks up to one group per [constant FORMATION_SIZES] entry - the nearest
## candidate of that size to [param player], among every currently roaming,
## unengaged [WorldBandit] within [member search_radius]. Never more than one
## group per size and never a group already ambushing or already stood down.
func _find_ambush_candidates(player: Node2D) -> Array[WorldBandit]:
	var best_by_size: Array[WorldBandit] = [null, null, null]
	var best_distance: Array[float] = [INF, INF, INF]

	for node: Node in get_tree().get_nodes_in_group(BANDIT_GROUP):
		var bandit := node as WorldBandit
		if bandit == null or not bandit.active or bandit.in_ambush:
			continue
		if bandit.behavior_state != WorldBandit.BehaviorState.PATROL:
			continue

		var size_index := _formation_size_index(bandit.group_strength)
		if size_index < 0:
			continue

		var distance := bandit.global_position.distance_to(player.global_position)
		if distance > search_radius:
			continue
		if distance < best_distance[size_index]:
			best_distance[size_index] = distance
			best_by_size[size_index] = bandit

	var chosen: Array[WorldBandit] = []
	for bandit: WorldBandit in best_by_size:
		if bandit != null:
			chosen.append(bandit)
	return chosen


## Which of [constant FORMATION_SIZES] [param strength] reads as, or -1 when
## it lands within [member size_tolerance] of none of them - the "each group
## must have one of these sizes" rule, applied at the point a candidate is
## considered rather than assumed of whatever this picks.
func _formation_size_index(strength: float) -> int:
	for i in FORMATION_SIZES.size():
		if absf(strength - FORMATION_SIZES[i]) <= size_tolerance:
			return i
	return -1


# --- Watching an ambush already under way -------------------------------

## Ends the instant every chosen group has already left the ambush on its
## own - engaged by [WorldMapCombatBridge], freed, or simply stood down - and
## otherwise ends it by hand for every group still ambushing once the player
## is past [member escape_distance] from all of them. Left running, with the
## banner up, for as long as even one group is both still ambushing and still
## within reach.
func _update_active_ambush() -> void:
	var player := _resolve_player()

	var still_ambushing: Array[WorldBandit] = []
	var any_within_reach := false
	for bandit: WorldBandit in _ambush_bandits:
		if bandit == null or not is_instance_valid(bandit) or not bandit.active or not bandit.in_ambush:
			continue
		still_ambushing.append(bandit)
		if player != null and bandit.global_position.distance_to(player.global_position) <= escape_distance:
			any_within_reach = true

	if still_ambushing.is_empty():
		_end_ambush_state()
		return

	if not any_within_reach:
		for bandit: WorldBandit in still_ambushing:
			bandit.end_ambush()
		_end_ambush_state()
		return

	_ambush_bandits = still_ambushing


func _end_ambush_state() -> void:
	_ambush_active = false
	_ambush_bandits = []
	_cooldown_timer = cooldown_seconds
	_hide_banner()


# --- Presentation ---------------------------------------------------------

func _show_banner() -> void:
	var banner := _resolve_banner()
	if banner != null and banner.has_method(&"show_banner"):
		banner.call(&"show_banner")


func _hide_banner() -> void:
	var banner := _resolve_banner()
	if banner != null and banner.has_method(&"hide_banner"):
		banner.call(&"hide_banner")


func _play_ambush_cue() -> void:
	var stinger := get_node_or_null(stinger_path) as StingerBoard
	if stinger == null:
		stinger = StingerBoard.get_active(self)
	if stinger != null:
		stinger.play_variant(&"ambush")


# --- Looking things up -----------------------------------------------------

func _resolve_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D


func _resolve_bridge() -> WorldMapCombatBridge:
	var named := get_node_or_null(combat_bridge_path) as WorldMapCombatBridge
	return named if named != null else WorldMapCombatBridge.get_active(self)


func _resolve_world_state() -> WorldMapState:
	var named := get_node_or_null(world_state_path) as WorldMapState
	return named if named != null else WorldMapState.get_active(self)


func _resolve_world_clock() -> Node:
	return get_node_or_null(world_clock_path)


func _resolve_banner() -> Node:
	var named := get_node_or_null(banner_path)
	if named != null:
		return named
	return get_tree().get_first_node_in_group(&"ambush_banner")
