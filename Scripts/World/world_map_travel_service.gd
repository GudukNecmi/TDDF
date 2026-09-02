class_name WorldMapTravelService
extends Node
## Carries the player from one [TravelPortal] to its paired destination,
## behind the same Loading Screen and Letterbox every other heavy World Map
## transition already uses.
##
## [b]There is no second map to load.[/b] The whole desert chain - Dust Camp,
## Old Mine, Ghost Town, Red River, The Dead - is one persistent
## [code]WorldMap.tscn[/code], the same way [WorldMapCombatBridge] already
## moves the player into the Arena without ever reloading a scene. A Travel
## Portal jump is a reposition within that one scene, dressed to read as a
## real journey rather than an instant snap - see [method LoadingCurtain.begin_transition],
## added alongside [method LoadingCurtain.begin] for exactly this kind of
## transition, never a second loading system of this file's own.
##
## [b]What freezes, and how.[/b] The player is held through [TravelHold] -
## the reversible twin of [ExtractionHold], both driving nothing but
## [method Player.get_speed_multiplier] - and [WorldClock] is stopped and
## resumed through the identical [method WorldTimeManager.freeze_for_combat] /
## [method WorldTimeManager.unfreeze_after_combat] pair
## [WorldMapCombatBridge] already calls for its own Arena hand-off, so a
## Travel Portal jump is "controlled consistently with the existing loading
## system" by literally sharing its two calls rather than a second freeze of
## this file's own. Every roaming [WorldBandit] is also held inactive for the
## length of the jump - "no enemies act" - and returned to exactly the set
## that was active before, never assumed.

## Group used by [method get_active].
const GROUP := &"world_map_travel_service"
## Group every [TravelHold] joins - the reversible player-freeze component
## on the Player, mirroring [ExtractionHold]'s own [code]"extraction_hold"[/code].
const TRAVEL_HOLD_GROUP := &"travel_hold"
## Group every [WorldBandit] joins - watched here only to hold every one of
## them still for the length of a jump, never to change what any of them are
## individually doing.
const BANDIT_GROUP := &"world_bandit"

@export var body_group: StringName = &"player"
@export var world_clock_path: NodePath = ^"/root/WorldClock"
## The shared cinematic bars - see [TravelLetterbox]. Optional: a world with
## none jumps exactly as it would with one, just without the bars framing it.
@export var letterbox_path: NodePath = ^"../RunHUD/TravelLetterbox"
## How long the curtain is held up before the player arrives on the far
## side - see [method LoadingCurtain.begin_transition].
@export var transition_duration: float = 1.6
@export var loading_caption: String = "LOADING"

var _traveling: bool = false
var _held_bandits: Array[WorldBandit] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


## The service in this world, or null when it has none - which a
## [TravelPortal] reads as "nowhere for this jump to go".
static func get_active(from_node: Node) -> WorldMapTravelService:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapTravelService


func is_traveling() -> bool:
	return _traveling


## Starts the jump [param from] portal is offering. Ignored while a jump is
## already under way, or when [param from] has no [member TravelPortal.destination]
## to send anyone to - the seam a portal with nothing wired up yet reads as
## "does nothing", the same way an unfinished [ArenaPortal.menu_path] already
## does.
##
## [param from] is untyped [Node] rather than [TravelPortal] deliberately -
## see that class's own note on why neither file names the other's
## [code]class_name[/code]. [method Object.call] reads exactly the two
## methods [TravelPortal] promises, [code]get_destination()[/code] and
## [code]get_arrival_position()[/code], the same "found and called, never
## typed" seam every cross-system call here already uses.
func travel_through(from: Node) -> void:
	if _traveling or from == null or not from.has_method(&"get_destination"):
		return
	var destination: Node = from.call(&"get_destination")
	if destination == null or not destination.has_method(&"get_arrival_position"):
		push_warning("WorldMapTravelService: %s has no destination wired up." % from.name)
		return

	var player := _resolve_player()
	if player == null:
		return

	_traveling = true
	_set_player_frozen(true)
	_hold_bandits()
	var clock := _resolve_world_clock()
	_freeze_world_clock(clock)

	var letterbox := _resolve_letterbox()
	if letterbox != null:
		letterbox.play_loading_transition(loading_caption)

	var curtain := LoadingCurtain.get_active(self)
	if curtain == null:
		# No curtain in this build - arrive at once rather than stranding the
		# player mid-jump forever, the same fallback every optional path here
		# already takes.
		_arrive(player, destination, clock, letterbox)
		return

	curtain.begin_transition(
		loading_caption, transition_duration, _arrive.bind(player, destination, clock, letterbox))


## The far side of the jump - called once, from behind [LoadingCurtain]'s own
## curtain, so none of this is ever seen happening. Everything after this is
## the ordinary reveal: the curtain lifts on its own, [method _end_travel]
## gives the player, the clock and every held bandit back the instant this
## returns.
func _arrive(
		player: Node2D, destination: Node, clock: Node, letterbox: TravelLetterbox
) -> void:
	player.global_position = destination.call(&"get_arrival_position")
	player.reset_physics_interpolation()

	var camera := CameraController.get_active(self)
	if camera != null:
		camera.reset_smoothing()

	_unfreeze_world_clock(clock)
	_release_bandits()
	_set_player_frozen(false)
	if letterbox != null:
		letterbox.play_destination_reveal()

	_traveling = false


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
## [method WorldMapCombatBridge._freeze_world_clock] already does - see this
## file's own class doc.
func _freeze_world_clock(clock: Node) -> void:
	if clock == null:
		return
	if clock.has_method(&"freeze_for_combat"):
		clock.call(&"freeze_for_combat")
	clock.set_process(false)


## A jump never advances the World Map's own hour, unlike a fight - a Travel
## Portal is instant travel across the [i]map[/i], not across time - so this
## always hands the clock back at 0 degrees advanced.
func _unfreeze_world_clock(clock: Node) -> void:
	if clock == null:
		return
	if clock.has_method(&"unfreeze_after_combat"):
		clock.call(&"unfreeze_after_combat", 0.0)
	clock.set_process(true)


## Holds every currently-active [WorldBandit] still for the length of the
## jump - "no enemies act" - recording only the ones this actually touched,
## so [method _release_bandits] can never hand activity back to a group some
## other system had already stood down for its own reasons.
func _hold_bandits() -> void:
	_held_bandits = []
	for node: Node in get_tree().get_nodes_in_group(BANDIT_GROUP):
		var bandit := node as WorldBandit
		if bandit == null or not bandit.active:
			continue
		bandit.active = false
		_held_bandits.append(bandit)


func _release_bandits() -> void:
	for bandit: WorldBandit in _held_bandits:
		if bandit != null and is_instance_valid(bandit):
			bandit.active = true
	_held_bandits = []
