class_name BanditPopulationState
extends Node
## How many bandit groups each region of the world still has, and which
## particular ones are gone.
##
## [b]It is an autoload, for exactly the reason [ExtractionUnlockState] and
## [BountyLedger] are.[/b] A region is its own scene now - see [WorldMapState] -
## so riding out of the desert's A and back into it frees and rebuilds every
## group in it, and ending a run rebuilds the whole world from the base. Neither
## of those may bring a beaten group back, so the fact that it is beaten cannot
## live on the group, on the map, or on anything the world rebuilds.
##
## [b]It is deliberately not a second copy of [WorldMapState]'s memory.[/b] That
## autoload remembers what a region was doing - where each group had walked to,
## what strength it was, which way round its route it was going - and it is
## written to be thrown away when a run ends, so the next run opens on a world
## nobody has ridden across. A region's population is the opposite kind of fact:
## it is the one thing about the region that a run is [i]meant[/i] to leave
## behind. Keeping it here rather than there is what lets both be true at once.
##
## [b]Nothing here knows what a bandit is, or how many a region has.[/b] Each
## [WorldBandit] registers itself as it is built - see [method note_group] - so a
## region's total population is simply every group its own scene authors, counted
## the first time the player ever rides into it. There is no population number
## authored anywhere that could drift out of step with the groups actually
## placed, and adding or removing a group from a region's scene changes that
## region's population by exactly one with nothing here to edit.
##
## [b]A run's losses are held apart until the run is over.[/b] Defeating a group
## puts it in [member _pending] and it stays gone for the rest of the run -
## across every region change and every arena the run visits - but the region's
## permanent population is untouched until [method commit_run_losses] folds them
## in, which is what the run ending does. That split is what makes "gone for this
## run" and "gone for good" two separate answers rather than one, so a later rule
## about how a run ends - dying costing less than extracting, say - is a choice
## about which of these two methods to call and nothing else.
##
## Deliberately not here yet, all of it the next phase's: scouts, Blood or Streak
## driving aggression, and any way for a region's population to grow back.

## Group this joins, so anything that wants the population can find it without a
## path across the scene - the same lookup convention [WorldMapState],
## [WorldMapFog] and [WorldBanditGallopDirector] all use. It joins the group as
## an autoload, so the lookup answers the same whether the caller is on a region
## map, in an arena, or standing in the base.
const GROUP := &"bandit_population"

## Emitted as a group is beaten, with the region it belonged to and how many that
## region has left for the rest of this run. Nothing listens yet; it is what a
## region readout or a "the desert is thinning out" system would raise itself
## off, rather than polling.
signal group_defeated(region_id: StringName, remaining: int)
## Emitted once a run's losses have been made permanent - see
## [method commit_run_losses]. [param lost] is how many groups the whole world
## lost, across every region the run touched.
signal run_losses_committed(lost: int)

## The run's own state - the [code]RunSession[/code] autoload. Listened to rather
## than polled: a run ending is what makes this run's losses permanent, and
## [signal RunSessionState.run_ended] is already emitted at the one moment the
## player is actually home - by both the extraction and the death paths alike.
##
## A path rather than a node because an autoload script has no scene and so no
## inspector to drop one into - the same arrangement [BountyLedger] and
## [HorseBloodStorage] use.
@export var session_path: NodePath = ^"/root/RunSession"

## Every group each region has ever been built with, as region_id to a set of
## group keys. Written by [method note_group] as each group comes up, so a
## region's population is the count of what its scene actually authors.
var _roster: Dictionary = {}
## The groups each region has lost for good, as region_id to a set of group keys.
## Only [method commit_run_losses] ever adds to it.
var _lost: Dictionary = {}
## The groups beaten in the run currently under way, held apart from
## [member _lost] until that run ends. Read alongside it by
## [method is_group_lost], so a group beaten an hour ago and one beaten a moment
## ago are equally gone while the run lasts.
var _pending: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var session := get_node_or_null(session_path)
	if session == null:
		return
	if session.has_signal(&"run_ended") \
			and not session.is_connected(&"run_ended", _on_run_ended):
		session.connect(&"run_ended", _on_run_ended)
	if session.has_signal(&"run_began") \
			and not session.is_connected(&"run_began", _on_run_began):
		session.connect(&"run_began", _on_run_began)


## The population ledger, found by group. As an autoload it is always there once
## the game is running; the null answer is kept for a scene opened on its own in
## the editor, and every caller reads it as "nothing is being kept, play the
## region exactly as it was authored" - the same fail-open
## [WorldMapState.get_active] and [WorldMapFog.get_active] already use.
static func get_active(from_node: Node) -> BanditPopulationState:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BanditPopulationState


# --- What a region is made of ------------------------------------------------

## Notes that [param key] is one of [param region_id]'s own bandit groups.
##
## Called by every [WorldBandit] as it is built, [b]including one that is about
## to remove itself because it has already been beaten[/b] - see
## [method WorldBandit._ready]. That is what keeps a region's total population
## the number it started with rather than the number still standing: the roster
## is what the region [i]has[/i], and [member _lost] is what has been taken off
## it.
##
## Registering the same key twice is free, so rebuilding a region does not grow
## it.
func note_group(region_id: StringName, key: StringName) -> void:
	if region_id.is_empty() or key.is_empty():
		return
	var groups: Dictionary = _roster.get(region_id, {})
	groups[key] = true
	_roster[region_id] = groups


## Whether this region has ever been built, and so whether the numbers below mean
## anything yet. A region the player has never ridden into has no population
## recorded, because nothing has told this what it is made of.
func knows_region(region_id: StringName) -> bool:
	return _roster.has(region_id)


## Every region this has a population for, for a developer readout.
func get_known_regions() -> Array[StringName]:
	var regions: Array[StringName] = []
	for key: Variant in _roster.keys():
		regions.append(key as StringName)
	return regions


# --- Losing a group ----------------------------------------------------------

## Records that one of [param region_id]'s groups has been beaten.
##
## Called by [method WorldBandit.mark_defeated], which [WorldMapCombatBridge]
## calls for the group the fight was picked up from and for every group folded
## into it as reinforcements - so a fight that pulls three groups in costs the
## region three, not one.
##
## The loss is this run's until the run ends. See [method commit_run_losses].
func record_defeat(region_id: StringName, key: StringName) -> void:
	if region_id.is_empty() or key.is_empty():
		return
	# A group can be beaten without ever having been noted - a group added to a
	# region at runtime, or one whose region was crossed into after it was built -
	# so the roster is kept honest here rather than assumed.
	note_group(region_id, key)

	var beaten: Dictionary = _pending.get(region_id, {})
	if beaten.has(key):
		return
	beaten[key] = true
	_pending[region_id] = beaten
	group_defeated.emit(region_id, get_remaining_population(region_id))


## Whether this particular group is gone - beaten either in the run under way or
## in a run that has already ended.
##
## This is the whole of what a rebuilt region asks: a group whose answer is true
## does not stand up at all. See [method WorldBandit._restore].
func is_group_lost(region_id: StringName, key: StringName) -> bool:
	if region_id.is_empty() or key.is_empty():
		return false
	var gone: Dictionary = _lost.get(region_id, {})
	if gone.has(key):
		return true
	var beaten: Dictionary = _pending.get(region_id, {})
	return beaten.has(key)


# --- The numbers -------------------------------------------------------------

## How many bandit groups [param region_id] was authored with - the population it
## had before any run had ever been made into it. 0 for a region that has never
## been built.
func get_starting_population(region_id: StringName) -> int:
	var groups: Dictionary = _roster.get(region_id, {})
	return groups.size()


## How many groups [param region_id] has going into a run: everything it started
## with, less every group beaten in a run that has already ended.
##
## [b]This is the number a new run opens on.[/b] A region of 100 that lost 20 in
## a finished run is a region of 80, and stays one.
func get_available_population(region_id: StringName) -> int:
	var gone: Dictionary = _lost.get(region_id, {})
	return maxi(get_starting_population(region_id) - gone.size(), 0)


## How many groups [param region_id] has standing right now: its available
## population, less the ones beaten in the run under way.
##
## The difference between this and [method get_available_population] is exactly
## what this run has cost the region so far, and it is what riding back into the
## region mid-run actually shows.
func get_remaining_population(region_id: StringName) -> int:
	var beaten: Dictionary = _pending.get(region_id, {})
	return maxi(get_available_population(region_id) - beaten.size(), 0)


## How many of [param region_id]'s groups this run has beaten so far.
func get_run_losses(region_id: StringName) -> int:
	var beaten: Dictionary = _pending.get(region_id, {})
	return beaten.size()


## How many of [param region_id]'s groups are gone for good, from every run that
## has ended.
func get_permanent_losses(region_id: StringName) -> int:
	var gone: Dictionary = _lost.get(region_id, {})
	return gone.size()


# --- The run ending ----------------------------------------------------------

## Makes this run's losses permanent: every group beaten during it comes off its
## region's population for every run after this one, and the run's own tally
## starts empty again.
##
## Called when [signal RunSessionState.run_ended] arrives, which is the moment
## the player is actually standing back in the base - the same moment the wanted
## board refills and a resupply becomes owed. Both ways home end a run, so a run
## that ended in a death costs the desert exactly what one that extracted does;
## making the two differ is a change to who calls this and to nothing else.
##
## Reports how many groups were folded in, across every region.
func commit_run_losses() -> int:
	var folded := 0
	for region_id: Variant in _pending.keys():
		var beaten: Dictionary = _pending[region_id]
		var gone: Dictionary = _lost.get(region_id, {})
		for key: Variant in beaten.keys():
			if not gone.has(key):
				gone[key] = true
				folded += 1
		_lost[region_id] = gone
	_pending.clear()
	if folded > 0:
		run_losses_committed.emit(folded)
	return folded


## Throws this run's losses away without making them permanent, leaving every
## region's population exactly as the run found it.
##
## Nothing calls it: every run today makes its losses permanent. It is the seam a
## rule about how a run ended would use - a run abandoned before it properly
## began, or a difficulty setting under which dying costs the desert nothing.
func discard_run_losses() -> void:
	_pending.clear()


## Puts one region back to its authored population, for a developer control. The
## region has to be built again for its roster to be filled back in.
func forget_region(region_id: StringName) -> void:
	_roster.erase(region_id)
	_lost.erase(region_id)
	_pending.erase(region_id)


## Puts the whole world back to the population it was authored with.
func forget_all() -> void:
	_roster.clear()
	_lost.clear()
	_pending.clear()


func _on_run_ended() -> void:
	commit_run_losses()


## A run beginning cannot inherit a previous one's tally. Every path out of a run
## already commits, so this only ever clears an empty tally - it is here so that
## a run left half-finished by something going wrong cannot charge its losses to
## the next one.
func _on_run_began(_map_id: StringName) -> void:
	_pending.clear()
