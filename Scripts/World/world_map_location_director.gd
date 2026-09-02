class_name WorldMapLocationDirector
extends Node
## The single place World Map location proximity is evaluated - which
## location, if any, the player is close enough to interact with right now -
## so the answer is computed once per tick rather than by each of
## sixty-some [WorldMapLocation] nodes running its own reach test and owning
## its own prompt. See rules 18 and 19 of the location foundation.
##
## [b]Nearest wins, and only one prompt is ever shown.[/b] More than one
## location's [member WorldMapLocation.interaction_radius] can overlap where
## the player is standing - a bounty camp a few steps from a normal camp -
## and [method _pick_nearest] resolves that by distance, the deterministic
## tie-breaker rule 19 asks for: the closest candidate is the only one told
## [method WorldMapLocation.set_player_in_range]. Anything that had been
## current and loses that race is told the same call with [code]false[/code],
## which drops its own highlight and fires its own
## [signal WorldMapLocation.location_exited].
##
## [b]One shared [InteractionPrompt].[/b] Rather than every location owning a
## copy of the world's own "E" hint - which is how [GroundPickup] and
## [ArenaPortal] each do it, one interaction apiece - this director owns the
## single instance under [member prompt_path] and points its text at
## whichever location is currently nearest, through
## [method InteractionPrompt.set_text]. A World Map with sixty-some locations
## never needs sixty-some prompts, because at most one of them can ever be
## the answer to "what is the player standing at".
##
## [b]Ticks on a timer, not every frame - and only while on the World
## Map.[/b] [member update_interval] matches [WorldMapFog]'s own cadence:
## proximity does not need to be re-evaluated sixty times a second to feel
## immediate at this map's scale. [method _process] also asks the World
## Map's own [WorldZone] whether the player is even here, the same gate
## [WorldMapMinimap] and every [code]Scripts/Dev[/code] readout already use -
## without it, [InteractionPrompt] would keep following the player's head
## into the base or the arena, since it is world-space and player-following
## rather than fixed to a place the camera happens to be pointed at.

## Group this joins, so a debug readout can find the one active director the
## same way it finds [WorldMapState] or [WorldMapFog].
const GROUP := &"world_map_location_director"

@export var body_group: StringName = &"player"
## The World Map's own [WorldZone], asked whether the player is inside it so
## this never evaluates proximity, or shows a prompt, anywhere else in the
## game.
@export var zone_id: StringName = &"world_map"
## Key that interacts with the current location - the project's own
## interact action, the same one every other interactable in the game reads.
@export var interact_action: StringName = &"interact"
## How often the nearest interactable location is re-evaluated, in seconds.
@export var update_interval: float = 0.1
## The one prompt every location shares.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _current: WorldMapLocation
var _player: Node2D
var _timer: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## The director for the World Map currently in the tree, found by group.
static func get_active(from_node: Node) -> WorldMapLocationDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapLocationDirector


func _process(delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	if zone == null or not zone.is_player_inside():
		_set_current(null)
		return

	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_retarget()


func _unhandled_input(event: InputEvent) -> void:
	if _current == null or not event.is_action_pressed(interact_action):
		return
	if _current.try_interact():
		get_viewport().set_input_as_handled()


## The location the player can press the key on right now, or null - what a
## debug readout, or anything else, should point at rather than re-deriving
## its own nearest search.
func get_current_location() -> WorldMapLocation:
	return _current


func _retarget() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	_set_current(_pick_nearest(_player))


## The closest enabled, currently-VISIBLE location the player is within
## reach of.
func _pick_nearest(player: Node2D) -> WorldMapLocation:
	if player == null:
		return null

	var best: WorldMapLocation = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var candidate := node as WorldMapLocation
		if candidate == null or not candidate.is_enabled():
			continue
		if candidate.get_visibility_state() != WorldMapFog.VisibilityState.VISIBLE:
			continue
		if not candidate.is_in_reach(player):
			continue
		var distance := candidate.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _set_current(location: WorldMapLocation) -> void:
	if location == _current:
		return

	if _current != null and is_instance_valid(_current):
		_current.set_player_in_range(false)
	_current = location
	if _current != null:
		_current.set_player_in_range(true)

	if _prompt == null:
		return
	if _current == null:
		_prompt.set_prompt_visible(false)
		return
	_prompt.set_text("E — %s" % _current.get_action_label())
	_prompt.set_prompt_visible(true)
