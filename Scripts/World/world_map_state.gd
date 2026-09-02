class_name WorldMapState
extends Node
## Phase 1 placeholder for what the World Map itself remembers: where the
## player is on it, which region that is, which map this is, and a stand-in
## for the hour.
##
## [b]It is deliberately its own authority, not a second copy of
## [RunSessionState]'s.[/b] That autoload already owns "which region is the
## run in" for the desert's existing Travel/Sleep/Search-for-Trouble systems,
## and those systems are staying up during this phase. Writing the World
## Map's region here instead means arriving on the map and walking across it
## can never be mistaken by the old systems for a journey they made, and
## nothing about Travel, Camp, Sleep or a wanted poster changes while this
## exists alongside them. Folding the two into one authority is exactly the
## kind of migration a later phase should do on purpose, once the old
## systems are actually being retired region by region - not a side effect
## of this node existing.
##
## [b]It is a scene-local node today, not an autoload.[/b] This project's own
## rule is that [code]project.godot[/code] is never hand-edited - adding an
## autoload needs either the editor's Project Settings UI or the
## [code]godot_mcp[/code] addon's [code]set_project_setting[/code], and
## neither was available while this was built. So this node currently only
## survives for as long as [code]WorldMap.tscn[/code] is in the tree; it does
## not yet survive the world being rebuilt for a fight, which is what
## [member world_position] existing at all is for. Promoting it to an
## autoload - or folding it into [RunSessionState] - is the one thing a later
## phase should do before anything relies on that survival.
##
## The hour is asked of [WorldTimeManager] - the [code]WorldClock[/code]
## autoload - rather than kept as a second number, for the same reason
## [DayCycleDirector] asks [code]DayCycle[/code] rather than storing its own.
## It is deliberately not [code]DayCycle[/code] itself: that clock is the
## base and the arena's own event-driven hour, moved a stage at a time by a
## completed round, a day of travel or a slept segment, and the World Map
## needs one that turns continuously instead - see [WorldTimeManager]'s own
## notes for why the two do not become one clock yet.

## Group this joins, so anything that wants the World Map's own state can
## find it without a path across the scene - the same lookup convention
## [DayCycleDirector], [WorldZone] and [CameraController] all use.
const GROUP := &"world_map_state"

## Handle for this place, for anything later that asks "which map is this"
## the way [method RunSessionState.get_map_id] does for a run.
@export var current_map_id: StringName = &"world_map"
## The World Map's own continuous clock, asked rather than copied - the same
## autoload [SunController] resolves it by.
@export var world_time_path: NodePath = ^"/root/WorldClock"

## Emitted when the region the player is standing in changes.
signal region_changed(region: MapRegion)

## Where the player last stood on this map, in this map's own local space.
## Written continuously while the player is on the map, so it still holds the
## last real position after the player has been moved elsewhere.
var world_position: Vector2 = Vector2.ZERO
## The region the player is currently standing in, or null outside every
## authored [WorldMapRegionZone].
var current_region: MapRegion


func _enter_tree() -> void:
	add_to_group(GROUP)


## The state node for this map, found by group. Null means no World Map is in
## the tree, which every caller reads as "there is nothing to ask".
static func get_active(from_node: Node) -> WorldMapState:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapState


## Records where the player is, in this map's own local space. Called every
## frame the player is on the map rather than read live off them, because the
## whole point of keeping this is to still have an answer once they are not.
func capture_position(position: Vector2) -> void:
	world_position = position


## Sets the region the player is standing in and announces it if it changed.
## Called by [WorldMapRegionZone] as the player crosses into or out of one -
## never written to directly by anything reading the desert's own regions.
func set_region(region: MapRegion) -> void:
	if region == current_region:
		return
	current_region = region
	region_changed.emit(current_region)


## The current region's handle, or empty outside every zone.
func get_region_id() -> StringName:
	return &"" if current_region == null else current_region.region_id


## Which world day the World Map is showing, read off [WorldTimeManager]
## rather than kept as a value of its own. 0 when there is no clock to ask,
## which every caller reads as "no world time is known yet".
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


## What the World Map's current period is called - DAWN through NIGHT. Empty
## when there is no clock to ask, which every caller reads as "no time of day
## is known yet".
func get_time_period_name() -> StringName:
	var clock := _resolve_world_time()
	if clock == null or not clock.has_method(&"get_time_period_name"):
		return &""
	return clock.call(&"get_time_period_name")


func _resolve_world_time() -> Node:
	return get_node_or_null(world_time_path)
