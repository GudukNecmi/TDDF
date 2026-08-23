class_name TerrainSlow
extends Node
## Scenery holding the player back. One more speed modifier on the player,
## alongside the ones the blood collector and the death sequence already provide.
##
## The player's own script never learns that cacti exist: it asks every node in
## its [member speed_modifier_paths] for a multiplier and multiplies the answers
## together, and this is one of those nodes. Nothing here writes to the player's
## speed, so no amount of scenery can leave them permanently slower - walk out of
## the cactus and the modifier is gone.
##
## What is slowing them down is not listed here either. A [PropTouch] anywhere in
## the world registers itself while the player is against it and unregisters as
## they leave, so a new kind of slow ground is a prop with an area on it and not
## an edit to this file.

## Group this joins so a prop can find it without a path into the player.
const GROUP := &"terrain_slow"

## Whether several things touching at once compound. Off - the default - takes
## the strongest single slow, so "a cactus costs you 20%" stays true in a thicket
## instead of quietly becoming 50%. On multiplies them together.
@export var stack_sources: bool = false
## Floor on the result however many things are pressing in, so the player can
## never be brought to a standstill by scenery.
@export_range(0.05, 1.0) var minimum_multiplier: float = 0.4

## Multiplier per source, keyed by the source's instance id so a prop that is
## freed while the player is standing in it cannot leave its slow behind.
var _sources: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)


## The component the props should talk to, found the same way [BloodField] and
## [CameraController] are. Null means this world has none, which every caller
## reads as "scenery does not slow anybody down here".
static func get_active(from_node: Node) -> TerrainSlow:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TerrainSlow


## Registers [param source] as holding the player to [param multiplier] of their
## speed. Calling again with the same source replaces its entry rather than
## adding a second one, so an area that reports contact repeatedly is harmless.
func add_source(source: Object, multiplier: float) -> void:
	if source == null:
		return
	_sources[source.get_instance_id()] = clampf(multiplier, 0.0, 1.0)


func remove_source(source: Object) -> void:
	if source == null:
		return
	_sources.erase(source.get_instance_id())


## Drops every registered slow. For anything that moves the player somewhere else
## outright - a teleport - where no area will ever report them leaving.
func clear() -> void:
	_sources.clear()


## True while anything at all is holding the player back, for a sound or a
## particle to hang off.
func is_slowed() -> bool:
	return get_speed_multiplier() < 1.0


## Read by the player every physics frame. 1 with nothing registered, so a world
## with no scenery in it moves exactly as it always did.
func get_speed_multiplier() -> float:
	if _sources.is_empty():
		return 1.0

	var result := 1.0
	for key: int in _sources.keys():
		# The source going away without saying so - a prop freed underfoot - is
		# cleaned up here rather than being left to hold the player forever.
		if not is_instance_id_valid(key):
			_sources.erase(key)
			continue
		var multiplier: float = _sources[key]
		result = result * multiplier if stack_sources else minf(result, multiplier)

	return maxf(result, minimum_multiplier)
