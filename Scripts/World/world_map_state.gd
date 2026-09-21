class_name WorldMapState
extends Node
## What the world remembers about itself between the scenes it is played in:
## which region the player is standing in, where in it they are, and what every
## bandit group, location and portal in every region they have visited was last
## doing.
##
## [b]It is an autoload, and that is the whole reason the world can be five
## scenes.[/b] The desert used to be one ten-thousand-pixel map with five bands
## in it, so nothing had to be remembered - the mine was still in the tree while
## the player stood in the dust camp, and a fight was somewhere else in the same
## scene. Each region is now its own scene and going anywhere is a real
## [method SceneTree.change_scene_to_packed], which frees everything that was
## standing a moment ago. Every fact that has to outlive that is written here,
## because this node is one of the few things a scene change does not destroy.
##
## This node's own earlier notes asked for exactly this promotion before anything
## relied on surviving a rebuild - see the history of [member world_position],
## which existed for a survival the node could not yet provide. It provides it
## now.
##
## [b]It is deliberately its own authority, not a second copy of
## [RunSessionState]'s.[/b] That autoload already owns "which map and which
## region is the run in" for the desert's existing Travel/Sleep/Search-for-Trouble
## systems. Writing the World Map's own region here instead means riding across
## the map can never be mistaken by the old systems for a journey they made.
##
## [b]It stores facts, never nodes.[/b] Everything here is plain data in
## dictionaries, so a region's memory costs nothing while that region is not
## built and cannot keep a freed scene alive. A bandit group writes its own
## record as it leaves the tree and reads it back as it enters - see
## [method remember] - so nothing here knows what a bandit is, and a system that
## wants to survive a scene change adds itself by calling these two methods
## rather than by this node growing a field for it.
##
## The hour is asked of [WorldTimeManager] - the [code]WorldClock[/code] autoload
## - rather than kept as a second number, for the same reason [DayCycleDirector]
## asks [code]DayCycle[/code] rather than storing its own. It is deliberately not
## [code]DayCycle[/code] itself: that clock is the base and the arena's own
## event-driven hour, moved a stage at a time by a completed round, a day of
## travel or a slept segment, and the World Map needs one that turns continuously
## instead - see [WorldTimeManager]'s own notes for why the two do not become one
## clock yet.

## Group this joins, so anything that wants the World Map's own state can find it
## without a path across the scene - the same lookup convention
## [DayCycleDirector], [WorldZone] and [CameraController] all use. It joins the
## group as an autoload, so the lookup answers the same whether the caller is on
## a region map, in an arena, or standing in the base.
const GROUP := &"world_map_state"

## Kind handle for a bandit group's record. Kinds exist only to keep one system's
## names from colliding with another's - see [method remember].
const KIND_BANDIT := &"bandit"
## Kind handle for a map location's record - whether it has been cleared, looted
## or found.
const KIND_LOCATION := &"location"
## Kind handle for a travel portal's record.
const KIND_PORTAL := &"portal"
## Kind handle for a region's fog of war.
const KIND_FOG := &"fog"
## Kind handle for a region's generated run map - the node graph a run is played
## through, written here as plain data by [RunMapDirector] so that opening a
## node's event, which is a real scene change, cannot lose the run.
const KIND_RUN_MAP := &"run_map"

## Handle for this place, for anything later that asks "which map is this" the
## way [method RunSessionState.get_map_id] does for a run.
@export var current_map_id: StringName = &"world_map"
## The World Map's own continuous clock, asked rather than copied - the same
## autoload [SunController] resolves it by.
@export var world_time_path: NodePath = ^"/root/WorldClock"

## Emitted when the region the player is standing in changes.
signal region_changed(region: MapRegion)

## Where the player last stood on the region they are on, in that region's own
## local space. Written continuously while the player is on a map, so it still
## holds the last real position after the map has been freed.
var world_position: Vector2 = Vector2.ZERO
## The region the player is currently standing in, or null outside every authored
## [WorldMapRegionZone].
var current_region: MapRegion

## Every region's memory, as region_id then kind then key to a dictionary. Only
## ever read and written through [method remember] and [method recall].
var _memory: Dictionary = {}
## Where the player should be standing the next time a region is built, as
## region_id to a position. Written by whatever sent them there - a portal states
## its own far side, a finished fight states where the fight was picked up from -
## and taken by the map as it opens.
var _arrivals: Dictionary = {}
## The fight that is being changed scene into, or empty when none is pending.
## See [method stage_combat].
var _pending_combat: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


## The state node, found by group. As an autoload it is always there once the
## game is running; the null answer is kept for callers written before it was
## one, and for a scene opened on its own in the editor.
static func get_active(from_node: Node) -> WorldMapState:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapState


## Records where the player is, in the current region's own local space. Called
## every frame the player is on a map rather than read live off them, because the
## whole point of keeping this is to still have an answer once they are not.
func capture_position(position: Vector2) -> void:
	world_position = position


## Sets the region the player is standing in and announces it if it changed.
## Called by [WorldMapRegionZone] as the map opens - never written to directly by
## anything reading the desert's own regions.
func set_region(region: MapRegion) -> void:
	if region == current_region:
		return
	current_region = region
	region_changed.emit(current_region)


## The current region's handle, or empty when no map is open.
func get_region_id() -> StringName:
	return &"" if current_region == null else current_region.region_id


# --- What each region remembers ---

## Writes one system's record for one region, under a kind and a key of its own
## choosing. The key is normally the node's own name, which is stable across
## builds of the same scene because the scene file is what names it.
##
## [b]Nothing here knows what is being remembered.[/b] A bandit group writes its
## position, strength and behaviour; a location writes whether it has been
## cleared. Both are dictionaries to this node, so a system that wants to survive
## a scene change is written entirely in that system rather than half here.
func remember(region_id: StringName, kind: StringName, key: StringName, data: Dictionary) -> void:
	if region_id.is_empty() or key.is_empty():
		return
	var region: Dictionary = _memory.get(region_id, {})
	var bucket: Dictionary = region.get(kind, {})
	bucket[key] = data.duplicate(true)
	region[kind] = bucket
	_memory[region_id] = region


## Reads back what [method remember] was last given, or an empty dictionary for
## something that has never been recorded - which every caller reads as "this has
## not been here before, keep what the scene was authored with".
func recall(region_id: StringName, kind: StringName, key: StringName) -> Dictionary:
	var region: Dictionary = _memory.get(region_id, {})
	var bucket: Dictionary = region.get(kind, {})
	var record: Dictionary = bucket.get(key, {})
	return record.duplicate(true)


## Whether this region has ever been built and left. False means the region is
## about to be visited for the first time and every node in it should keep the
## values its scene authored.
func has_visited(region_id: StringName) -> bool:
	return _memory.has(region_id)


## Marks a region as visited without recording anything in particular, so the
## first build of a map can be told apart from a rebuild even when nothing in it
## had a record to write.
func mark_visited(region_id: StringName) -> void:
	if region_id.is_empty() or _memory.has(region_id):
		return
	_memory[region_id] = {}


## Throws away everything one region remembers, so it is next built exactly as it
## was authored. This is what a new run does - never a scene change.
func forget_region(region_id: StringName) -> void:
	_memory.erase(region_id)
	_arrivals.erase(region_id)


## Throws away every region's memory and any pending fight. Called when a run
## ends, so the next one opens on a world that has not been ridden across yet.
func forget_all() -> void:
	_memory.clear()
	_arrivals.clear()
	_pending_combat.clear()
	world_position = Vector2.ZERO


# --- Where the player is standing when a map opens ---

## States where the player should be put the next time a region is built. Set by
## whatever sends them there rather than by the map itself: a travel portal names
## its own far side, and a finished fight names the spot it was picked up from.
func set_arrival(region_id: StringName, at: Vector2) -> void:
	if region_id.is_empty():
		return
	_arrivals[region_id] = at


## Takes the arrival point for a region, clearing it, so a map opened a second
## time without anyone naming a point stands the player where it was authored to
## rather than where they came out last time. Returns [code]Vector2.INF[/code]
## when no point was named, which every caller reads as "use the scene's own
## spawn point".
func take_arrival(region_id: StringName) -> Vector2:
	if not _arrivals.has(region_id):
		return Vector2.INF
	var at: Vector2 = _arrivals[region_id]
	_arrivals.erase(region_id)
	return at


## Whether a point has been named for this region, without taking it.
func has_arrival(region_id: StringName) -> bool:
	return _arrivals.has(region_id)


# --- The fight being changed scene into ---

## Parks everything an arena needs to know about the fight it is being built for,
## and everything the map needs to pick itself back up afterwards.
##
## [b]This is the whole of the hand-off.[/b] The fight used to be somewhere else
## in the same scene, so the bridge could simply hold the bandit it was fighting
## in a variable. The arena is now its own scene and the map is freed to build
## it, so what survives has to be data - how many men, which region, the spot on
## the map to come back to - and this is where it waits.
func stage_combat(payload: Dictionary) -> void:
	_pending_combat = payload.duplicate(true)


## What the arena being built is a fight against, or an empty dictionary when no
## fight was staged - which the arena reads as "opened on its own, fight whatever
## the scene was authored with".
func get_staged_combat() -> Dictionary:
	return _pending_combat.duplicate(true)


## Whether a fight is waiting to be picked up.
func has_staged_combat() -> bool:
	return not _pending_combat.is_empty()


## Takes the staged fight, clearing it, so the arena that reads it is the only
## one that can - a second arena built without a fight being staged is not the
## same fight over again.
func take_staged_combat() -> Dictionary:
	var payload := _pending_combat
	_pending_combat = {}
	return payload


## Drops a staged fight that is never going to be opened - an encounter aborted
## between the decision and the scene change.
func clear_staged_combat() -> void:
	_pending_combat.clear()


# --- The world's clock, asked rather than kept ---

## Which world day the World Map is showing, read off [WorldTimeManager] rather
## than kept as a value of its own. 0 when there is no clock to ask, which every
## caller reads as "no world time is known yet".
func get_world_day() -> int:
	var clock := _resolve_world_time()
	if clock == null or not clock.has_method(&"get_world_day"):
		return 0
	return clock.call(&"get_world_day")


## Where the World Map's own clock stands in its day, in continuous degrees.
## 0 when there is no clock to ask.
func get_world_degree() -> float:
	var clock := _resolve_world_time()
	if clock == null or not clock.has_method(&"get_world_degree"):
		return 0.0
	return clock.call(&"get_world_degree")


## What the World Map's current period is called - DAWN through NIGHT. Empty when
## there is no clock to ask, which every caller reads as "no time of day is known
## yet".
func get_time_period_name() -> StringName:
	var clock := _resolve_world_time()
	if clock == null or not clock.has_method(&"get_time_period_name"):
		return &""
	return clock.call(&"get_time_period_name")


func _resolve_world_time() -> Node:
	return get_node_or_null(world_time_path)
