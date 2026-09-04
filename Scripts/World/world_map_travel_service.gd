class_name WorldMapTravelService
extends Node
## Both ends of a journey between regions: stepping into a [TravelPortal] and
## leaving, and standing the player where they belong when a region's map opens.
##
## [b]A jump is a real scene change now.[/b] The desert used to be one persistent
## [code]WorldMap.tscn[/code] with all five regions in it, so travelling was a
## reposition inside a scene that was already built - a curtain over a teleport.
## Each region is its own scene, so a jump is a
## [method SceneTree.change_scene_to_packed] through [WorldRegionRouter] and the
## region being left is genuinely freed. Nothing here loads anything: the router
## decides where, the existing [LoadingCurtain] owns the load, and this owns the
## ceremony at either end.
##
## [b]Nothing has to be held still any more, and that is the point.[/b] Holding
## every roaming [WorldBandit] inactive for the length of a jump, and putting
## them back exactly as they were, only existed because they were still standing
## in the same scene the player was being moved across. They are freed with the
## map now. What each group was doing is written to [WorldMapState] as it leaves
## the tree and read back when its region is next built, so the memory outlives
## the jump instead of the nodes having to.
##
## [b]What still freezes.[/b] [WorldClock] is an autoload and keeps turning
## through a scene load, so it is stopped as the jump begins and started again
## on arrival, through the identical [method WorldTimeManager.freeze_for_combat]
## / [method WorldTimeManager.unfreeze_after_combat] pair
## [WorldMapCombatBridge] already uses. A portal jump is travel across the map,
## not across time, so it always hands the clock back with zero degrees
## advanced - unlike a fight, which is worth hours.

## Group used by [method get_active].
const GROUP := &"world_map_travel_service"
## Group every [TravelHold] joins - the reversible player-freeze component on
## the Player, mirroring [ExtractionHold]'s own "extraction_hold".
const TRAVEL_HOLD_GROUP := &"travel_hold"

@export var body_group: StringName = &"player"
@export var world_clock_path: NodePath = ^"/root/WorldClock"
## The shared cinematic bars - see [TravelLetterbox]. Optional: a world with
## none travels exactly as it would with one, just without the bars framing it.
@export var letterbox_path: NodePath = ^"../../RunHUD/TravelLetterbox"
@export var loading_caption: String = "LOADING"
## Where the player is stood when a map opens with nobody having named a point -
## the region's own authored spawn marker.
@export var spawn_point_path: NodePath = ^"../Player/SpawnPoint"
## Whether opening this map stands the player at the arrival point at all. Off
## leaves them wherever the scene placed them, which is what a map opened on its
## own in the editor wants.
@export var places_player_on_arrival: bool = true

var _leaving: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# Deferred by one frame: the player, the camera and the region's own zone all
	# come up in their own _ready, and where the player is standing is only
	# meaningful once they all have.
	_arrive.call_deferred()


## The service in this world, or null when it has none - which a [TravelPortal]
## reads as "nowhere for this jump to go".
static func get_active(from_node: Node) -> WorldMapTravelService:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapTravelService


func is_traveling() -> bool:
	return _leaving


# --- Leaving ----------------------------------------------------------------

## Starts the jump [param from] portal is offering. Ignored while a jump is
## already under way, or when the portal has no destination wired up - the seam
## a portal with nothing on the far side reads as "does nothing", the same way an
## unfinished [member ArenaPortal.menu_path] already does.
##
## [param from] is untyped [Node] rather than [TravelPortal] deliberately - see
## that class's own note on why neither file names the other's
## [code]class_name[/code].
func travel_through(from: Node) -> void:
	if _leaving or from == null or not from.has_method(&"get_destination_region"):
		return

	var region_id: StringName = from.call(&"get_destination_region")
	if region_id.is_empty():
		push_warning("WorldMapTravelService: %s has no destination wired up." % from.name)
		return

	var router := WorldRegionRouter.get_active(self)
	if router == null:
		push_warning("WorldMapTravelService: no router to travel through.")
		return

	var at: Vector2 = from.call(&"get_destination_position")

	_leaving = true
	_set_player_frozen(true)
	_freeze_world_clock(_resolve_world_clock())

	var letterbox := _resolve_letterbox()
	if letterbox != null:
		letterbox.play_loading_transition(loading_caption)

	if not router.go_to_region(region_id, at):
		# Nothing to travel to after all - put everything back rather than
		# leaving the player frozen in front of a portal that did not open.
		_leaving = false
		_unfreeze_world_clock(_resolve_world_clock())
		_set_player_frozen(false)


# --- Arriving ---------------------------------------------------------------

## Stands the player where whatever sent them here said they should be, and
## starts the world's clock again.
##
## [b]It runs on every build of a map, not only after a portal.[/b] Coming back
## out of a fight, riding out from the base and stepping through a portal all
## arrive the same way: something named a point in [WorldMapState] and this is
## what reads it. A map built with nobody having named one - opened on its own,
## or entered for the first time - falls back to the region's own spawn marker.
func _arrive() -> void:
	if not is_inside_tree():
		return

	var clock := _resolve_world_clock()
	_unfreeze_world_clock(clock)
	_set_player_frozen(false)

	if not places_player_on_arrival:
		return

	var player := _resolve_player()
	if player == null:
		return

	var state := WorldMapState.get_active(self)
	var region_id: StringName = state.get_region_id() if state != null else &""
	var at := Vector2.INF
	if state != null and not region_id.is_empty():
		at = state.take_arrival(region_id)
	if at == Vector2.INF:
		var marker := get_node_or_null(spawn_point_path) as Node2D
		if marker == null:
			return
		at = marker.global_position

	player.global_position = at
	# Physics interpolation is on project-wide; without this the player is
	# visibly smeared in from wherever the scene placed them.
	player.reset_physics_interpolation()

	var camera := CameraController.get_active(self)
	if camera != null:
		camera.reset_smoothing()

	var letterbox := _resolve_letterbox()
	if letterbox != null:
		letterbox.play_destination_reveal()


# --- The pieces either end uses ---------------------------------------------

func _resolve_player() -> Node2D:
	return get_tree().get_first_node_in_group(body_group) as Node2D


func _resolve_letterbox() -> TravelLetterbox:
	var named := get_node_or_null(letterbox_path) as TravelLetterbox
	return named if named != null else TravelLetterbox.get_active(self)


func _resolve_world_clock() -> Node:
	return get_node_or_null(world_clock_path)


func _set_player_frozen(value: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group(TRAVEL_HOLD_GROUP):
		if node.has_method(&"set_frozen"):
			node.call(&"set_frozen", value)


## Stopped and locked to the World Map's current lighting the exact way
## [method WorldMapCombatBridge._freeze_world_clock] already does.
func _freeze_world_clock(clock: Node) -> void:
	if clock == null:
		return
	if clock.has_method(&"freeze_for_combat"):
		clock.call(&"freeze_for_combat")
	clock.set_process(false)


## A jump never advances the World Map's own hour, unlike a fight - a Travel
## Portal is instant travel across the map, not across time - so this always
## hands the clock back at 0 degrees advanced.
func _unfreeze_world_clock(clock: Node) -> void:
	if clock == null:
		return
	if clock.has_method(&"unfreeze_after_combat"):
		clock.call(&"unfreeze_after_combat", 0.0)
	clock.set_process(true)
