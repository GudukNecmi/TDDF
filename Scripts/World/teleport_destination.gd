class_name TeleportDestination
extends Node2D
## A place the player can be sent to, which knows its own size and its own
## arrival point.
##
## This exists so teleporting is "go to that area" rather than "move to these
## coordinates". Everything location-specific - where you land, how far the
## camera may roam - is declared here, on the destination itself, so [Teleporter]
## never contains a single hard-coded position and a second destination is a new
## scene rather than new code.
##
## It is a normal scene sitting somewhere else in world space, not a separate
## viewport or level file, so it can be looked at in the editor next to the arena
## and can hold real geometry, props and lights. When it eventually becomes a
## proper location, this script does not have to change: only what is parented
## under it does.

## Group used by [method get_by_id] so a teleporter can find a destination
## without a NodePath into another branch of the scene.
const GROUP := &"teleport_destination"

## Name a teleporter asks for. Lets several destinations coexist and be chosen
## between later, without any of them knowing about the others.
@export var id: StringName = &"sanctum"
## Where the player arrives. Falls back to this node's own origin when unset.
@export var spawn_point_path: NodePath = ^"SpawnPoint"
## The playable rectangle, in this scene's local space. The camera is clamped to
## it on arrival, which is what stops the view drifting off into empty world
## between here and the arena.
@export var bounds := Rect2(-400.0, -225.0, 800.0, 450.0)

@onready var _spawn: Node2D = get_node_or_null(spawn_point_path) as Node2D


func _ready() -> void:
	add_to_group(GROUP)


## Finds a destination by [member id]. Returns null when there is none, which
## every caller treats as "teleporting is switched off".
static func get_by_id(from_node: Node, wanted: StringName) -> TeleportDestination:
	if from_node == null or not from_node.is_inside_tree():
		return null

	for node: Node in from_node.get_tree().get_nodes_in_group(GROUP):
		var destination := node as TeleportDestination
		if destination != null and destination.id == wanted:
			return destination
	return null


## Where a body should be placed on arrival, in world space.
func get_spawn_position() -> Vector2:
	return _spawn.global_position if _spawn != null else global_position


## The playable rectangle in world space, for the camera limits.
func get_world_bounds() -> Rect2:
	return Rect2(global_position + bounds.position, bounds.size)
