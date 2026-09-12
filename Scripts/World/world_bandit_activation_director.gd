class_name WorldBanditActivationDirector
extends Node
## The one place a World Map bandit group is told whether it is close enough
## to the player to be worth simulating at full rate - so eighteen groups
## spread over a ten-thousand-pixel map do not each run a sixty-hertz AI the
## player will never see the result of.
##
## [b]It is a level of detail, never a second AI.[/b] Nothing here decides
## what a group does. Patrol, investigation, chase, flight and disengage are
## [WorldBandit]'s own, unchanged, and so are its routes, its formation, its
## detection radius, its threat ratios and the three existing distance-based
## AI tick tiers it already had - see [member WorldBandit.near_range]. All
## this sets is [member WorldBandit.activation_level], the rate that whole
## existing simulation is stepped at: every frame near the player, one coarse
## step every [member WorldBandit.dormant_step_interval] away from them. A
## dormant group is still on its route, still remembers where it had got to
## and is still written down when the region is left; it simply is not
## re-simulated sixty times a second to walk a straight line nobody can see.
##
## [b]No group is checked against the player every frame.[/b] The sweep runs
## on [member update_interval] rather than per frame, and each tick looks at
## only the next [member max_groups_per_tick] entries of the list, so the
## per-frame cost is a fixed handful of squared-distance comparisons whether
## the map holds eighteen groups or five hundred. The margin this can afford
## is enormous: [member activate_radius] sits thousands of pixels outside
## [member WorldBandit.detection_radius], so a group is awake and running its
## own eyesight long before the player is anywhere near close enough for it
## to see them, however many ticks the sweep took to reach it.
##
## [b]A map without one behaves exactly as it always did.[/b] Groups default
## to [constant WorldBandit.ActivationLevel.ACTIVE] and nothing but this
## director ever demotes them, so a region scene opened on its own for tuning
## - and every scene authored before this node existed - simulates every
## group at full rate the way it used to. This is an addition, not a change.

## Group this joins, so a debug readout can find the one active director the
## same way it already finds [WorldMapState] or [WorldMapFog].
const GROUP := &"world_bandit_activation_director"

## Group every [WorldBandit] is already in - the same handle
## [WorldMapCombatBridge] and [WorldMapAmbushDirector] sweep. No second
## registry of groups exists anywhere in this file.
const BANDIT_GROUP := &"world_bandit"

@export var body_group: StringName = &"player"
## The World Map's own [WorldZone], asked whether the player is even here.
## While they are not - away in the base or an arena - every group is allowed
## to fall dormant, since there is nobody on this map for one to react to. A
## map with no zone of this id in it is treated as "no gate", exactly the way
## [WorldBandit] treats a map with no navigation mesh in it, so nothing about
## a scene that has not got one changes.
@export var zone_id: StringName = &"world_map"
## How often the sweep advances, in seconds. Matches [WorldMapFog]'s and
## [WorldMapLocationDirector]'s own cadence: at this map's scale, which
## groups are near the player is not a question that needs re-answering
## sixty times a second.
@export var update_interval: float = 0.1
## Groups within this many pixels of the player are simulated at full rate.
##
## Deliberately far outside [member WorldBandit.detection_radius] and outside
## [member WorldBandit.medium_range]: a group is already awake and running
## its ordinary eyesight well before the player is close enough for it to
## spot them, and the three AI tick tiers the class already had are expressed
## in full inside the awake band rather than clipped by this one.
@export var activate_radius: float = 3000.0
## How far past [member activate_radius] a group has to get before it is put
## back to sleep. The gap is what stops a group walking its route along the
## boundary from waking and sleeping on alternate ticks; it is never allowed
## to be smaller than [member activate_radius], and is clamped up to it if it
## is authored that way.
@export var sleep_radius: float = 3600.0
## The most groups one tick is allowed to test against the player. The whole
## point of the sweep: this, not the population, is what bounds the per-frame
## cost. Zero or less tests every group every tick, which is what a map small
## enough not to care can be set to.
@export var max_groups_per_tick: int = 16

## The groups this sweep is walking, re-collected at the start of each full
## pass rather than every tick - so a group freed or spawned mid-pass is
## picked up by the next pass without a [method Node.get_nodes_in_group] call
## per tick.
var _groups: Array[WorldBandit] = []
## How far through [member _groups] this pass has got.
var _cursor: int = 0
var _timer: float = 0.0
var _player: Node2D
## How many groups the last completed pass found awake, and how many it
## walked. Tallied as the pass runs and published only once it finishes, so a
## readout never shows a half-counted sweep.
var _awake_count: int = 0
var _group_count: int = 0
var _pass_awake: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


## The director for the World Map currently in the tree, found by group.
## Answers null on a map that has not got one, which every caller reads as
## "every group is simulated at full rate".
static func get_active(from_node: Node) -> WorldBanditActivationDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldBanditActivationDirector


## How many groups the last full pass found awake.
func get_awake_count() -> int:
	return _awake_count


## How many groups the last full pass walked.
func get_group_count() -> int:
	return _group_count


func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_advance_sweep()


## One tick of the sweep: collect the list again if the last pass finished,
## then test the next slice of it and no more.
func _advance_sweep() -> void:
	if _cursor >= _groups.size():
		_begin_pass()
	if _groups.is_empty():
		return

	var player := _resolve_player()
	var limit := _groups.size() if max_groups_per_tick <= 0 \
		else mini(_cursor + max_groups_per_tick, _groups.size())
	while _cursor < limit:
		var bandit := _groups[_cursor]
		_cursor += 1
		if not is_instance_valid(bandit):
			continue
		_apply_level(bandit, player)
		if bandit.activation_level == WorldBandit.ActivationLevel.ACTIVE:
			_pass_awake += 1

	if _cursor >= _groups.size():
		_awake_count = _pass_awake


## Wakes or sleeps one group by its distance to the player, with
## [member sleep_radius]'s own gap between the two thresholds so a group
## sitting on the boundary settles rather than flapping.
##
## [b]It only ever asks; the group itself decides.[/b] A group that is
## chasing, fleeing, investigating, winding down out of a chase or running an
## ambush refuses to be put to sleep - see
## [method WorldBandit.set_activation_level] - so nothing here can interrupt
## a reaction to the player half way through. Such a group falls dormant on
## the sweep after its own existing rules have returned it to patrol.
func _apply_level(bandit: WorldBandit, player: Node2D) -> void:
	if player == null:
		bandit.set_activation_level(WorldBandit.ActivationLevel.DORMANT)
		return

	# Squared throughout - these thresholds are compared, never reported, so
	# the square root every one of them would otherwise cost is pure waste.
	var distance_squared := bandit.global_position.distance_squared_to(player.global_position)
	var wake := maxf(activate_radius, 0.0)
	var sleep := maxf(sleep_radius, wake)
	if distance_squared <= wake * wake:
		bandit.set_activation_level(WorldBandit.ActivationLevel.ACTIVE)
	elif distance_squared >= sleep * sleep:
		bandit.set_activation_level(WorldBandit.ActivationLevel.DORMANT)


## Starts a fresh pass over every group currently on the map.
func _begin_pass() -> void:
	_groups.clear()
	for node: Node in get_tree().get_nodes_in_group(BANDIT_GROUP):
		var bandit := node as WorldBandit
		if bandit != null:
			_groups.append(bandit)
	_cursor = 0
	_group_count = _groups.size()
	_pass_awake = 0


## The player, or null when there is nobody on this map to be near - either
## because none is in the tree at all, or because the World Map's own zone
## says they are somewhere else in the game entirely.
func _resolve_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	if _player == null:
		return null
	var zone := WorldZone.get_by_id(self, zone_id)
	if zone != null and not zone.is_player_inside():
		return null
	return _player
