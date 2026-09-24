class_name WorldRegionRouter
extends Node
## The one place a scene is changed: the base, a region's map, and the arena a
## fight in that region is fought in.
##
## [b]The world is not one scene any more.[/b] It used to be: the base, the arena
## and a ten-thousand-pixel World Map with five regions in it all stood in
## [code]World.tscn[/code] at once, a few thousand pixels apart, and "going"
## anywhere was teleporting the player across it and hiding what they had left.
## Everything the player was not looking at was still built, still simulated and,
## in the World Map's case, still drawing five regions' worth of ground and
## scenery. Each place is now its own scene file and going anywhere is a real
## [method SceneTree.change_scene_to_packed], so the four regions the player is
## not in do not exist, and neither does the arena until there is a fight.
##
## [b]It is not a second loading system.[/b] Every journey here goes through the
## [code]LoadingScreen[/code] autoload's existing [method LoadingCurtain.begin] -
## the same curtain, caption, minimum display time and threaded load the title
## screen has always used to enter the world. This node decides [i]where[/i]; the
## curtain owns [i]how[/i], including the fact that the old scene is released and
## the new one is only shown once it is actually ready.
##
## [b]It is not a second world, either.[/b] Nothing about a place is stored here.
## Which region the player is in, what its bandits were doing and where the player
## should be standing when it opens are all [WorldMapState]'s, and which scene
## file a region is lives on the region's own [MapRegion] resource - see
## [member MapRegion.world_map_scene_path]. This node reads both and calls the
## curtain, so adding a region to the desert, or a second map entirely, is
## authoring resources rather than editing this file.

## Group this joins, so anything can find it without a path - the same lookup
## convention the rest of the world's services use. It joins as an autoload, so
## the answer is the same from the base, a map or an arena.
const GROUP := &"world_region_router"

## The base's own scene - where the player is between runs, and what
## [method go_to_base] changes to. The Base menu; the walkable
## [code]BaseWorld.tscn[/code] is kept but no longer part of the game's flow.
@export_file("*.tscn") var base_scene_path: String = "res://Scenes/Base/BaseMenu.tscn"
## Caption written on the curtain while a region's map is loading.
@export var region_caption: String = "RIDING"
## Caption written while an arena is loading.
@export var combat_caption: String = "AMBUSH"
## Caption written while the base is loading.
@export var base_caption: String = "RETURNING"
## Where the session that owns which map is being played is asked.
@export var session_path: NodePath = ^"/root/RunSession"
## Where the world's own memory is asked - which region, and what it remembers.
@export var world_state_path: NodePath = ^"/root/WorldState"
## Where the curtain is asked.
@export var loading_screen_path: NodePath = ^"/root/LoadingScreen"

## Emitted the moment a journey is accepted, before the curtain goes up. The
## payload is the scene about to be loaded, so a caller that wants to hand music
## or a stinger over can do it without knowing which kind of journey it was.
signal journey_started(scene_path: String)


func _enter_tree() -> void:
	add_to_group(GROUP)


## The router, found by group. Always there once the game is running; the null
## answer is for a scene opened on its own in the editor.
static func get_active(from_node: Node) -> WorldRegionRouter:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldRegionRouter


## Whether a journey is already under way. Every entry point below refuses while
## this is true, so a second press, a bandit reaching the player on the same
## frame a portal was used, or two systems both deciding to leave cannot start
## two scene changes.
func is_travelling() -> bool:
	var curtain := _resolve_curtain()
	return curtain != null and curtain.is_loading()


## Rides to a region's own World Map scene.
##
## [param arrival] is where the player should be standing when it opens, in that
## region's own space; [code]Vector2.INF[/code] leaves the map to stand them at
## its authored spawn point. It is written to [WorldMapState] rather than passed
## through the load, because the scene doing the asking is freed before the scene
## that needs the answer is built.
##
## Refuses - and answers false - for a region that has no map authored, rather
## than changing scene to nothing.
func go_to_region(region_id: StringName, arrival: Vector2 = Vector2.INF) -> bool:
	if is_travelling():
		return false

	var region := find_region(region_id)
	if region == null:
		push_warning("WorldRegionRouter: no region '%s' on the current map." % region_id)
		return false

	var path := region.get_world_map_scene_path()
	if path.is_empty():
		push_warning("WorldRegionRouter: region '%s' has no World Map scene." % region_id)
		return false

	var state := _resolve_state()
	if state != null and arrival != Vector2.INF:
		state.set_arrival(region_id, arrival)

	return _depart(path, region_caption)


## Opens the arena a fight in [param region_id] is fought in, carrying
## [param payload] across for the arena to pick up.
##
## [b]The arena is built fresh and thrown away.[/b] Nothing survives the scene
## change, so the floor of a new fight is clean by construction - no corpse, no
## dropped gun, no shell casing, no blood, and a scatter of props laid out again
## from the arena scene's own placement pass. There is nothing to clear because
## there is nothing left.
##
## The payload is expected to carry [code]return_region[/code] and
## [code]return_position[/code] so the fight knows the map to put the player back
## on and the spot to put them at; both are filled in here from
## [param region_id] and the world's last known position when the caller has not
## already named them.
func go_to_combat(region_id: StringName, payload: Dictionary = {}) -> bool:
	if is_travelling():
		return false

	var region := find_region(region_id)
	if region == null:
		push_warning("WorldRegionRouter: no region '%s' to fight in." % region_id)
		return false

	var path := region.get_arena_scene_path()
	if path.is_empty():
		push_warning("WorldRegionRouter: region '%s' has no arena scene." % region_id)
		return false

	var state := _resolve_state()
	var carried := payload.duplicate(true)
	carried[&"region_id"] = region_id
	if not carried.has(&"return_region"):
		carried[&"return_region"] = region_id
	if not carried.has(&"return_position") and state != null:
		carried[&"return_position"] = state.world_position
	if state != null:
		state.stage_combat(carried)

	return _depart(path, combat_caption)


## Rides back out of a fight onto the map it was picked up from, standing the
## player where they were when it started.
##
## Reads the same payload the arena was built from, so the way back is stated by
## the journey in rather than by the arena having to know anything about the map.
## A payload with no region in it - an arena opened on its own - falls back to
## whichever region the world last knew the player to be in.
func return_from_combat(payload: Dictionary) -> bool:
	var region_id: StringName = payload.get(&"return_region", &"")
	if region_id.is_empty():
		var state := _resolve_state()
		region_id = state.get_region_id() if state != null else &""
	if region_id.is_empty():
		push_warning("WorldRegionRouter: no region to return to after combat.")
		return false

	var at: Vector2 = payload.get(&"return_position", Vector2.INF)
	return go_to_region(region_id, at)


## Rides home to the base.
func go_to_base() -> bool:
	if is_travelling() or base_scene_path.is_empty():
		return false
	return _depart(base_scene_path, base_caption)


## The [MapRegion] resource for a handle, off the map the session is playing.
## Null for a handle the current map does not have, which every caller above
## refuses on rather than guessing at a region.
func find_region(region_id: StringName) -> MapRegion:
	if region_id.is_empty():
		return null
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_map"):
		return null
	var map: MapDefinition = session.call(&"get_map")
	if map == null:
		return null
	return map.find_region(region_id)


## Which region the world last knew the player to be in. Empty when they are not
## on a map at all - in the base, or in an arena opened on its own.
func get_current_region_id() -> StringName:
	var state := _resolve_state()
	return state.get_region_id() if state != null else &""


## The journey itself: announce it, then hand the path to the curtain. Every
## entry point above ends here, so there is exactly one call to the loading
## system in the whole router.
func _depart(scene_path: String, caption: String) -> bool:
	var curtain := _resolve_curtain()
	if curtain == null:
		push_warning("WorldRegionRouter: no loading curtain to travel behind.")
		return false

	journey_started.emit(scene_path)
	curtain.begin(scene_path, caption)
	return true


func _resolve_curtain() -> LoadingCurtain:
	var named := get_node_or_null(loading_screen_path) as LoadingCurtain
	return named if named != null else LoadingCurtain.get_active(self)


func _resolve_state() -> WorldMapState:
	var named := get_node_or_null(world_state_path) as WorldMapState
	return named if named != null else WorldMapState.get_active(self)
