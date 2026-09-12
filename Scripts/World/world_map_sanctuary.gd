class_name WorldMapSanctuary
extends Node2D
## A circle of the World Map that bandits will not pursue the player into -
## the Saloon and the Market, and anywhere later that should read as safe
## ground.
##
## [b]It is a place, not a rule.[/b] Nothing here touches a bandit, a chase or
## a combat system. All this node does is answer [method contains] for a
## point, the same way [WorldZone] answers [method WorldZone.is_inside] and
## [WorldMapRegionZone] answers which region a position falls in. What that
## answer means is entirely [WorldBandit]'s: a group already chasing the
## player holds on for its own [member WorldBandit.sanctuary_hold_duration]
## and then enters its own, existing [constant WorldBandit.BehaviorState.DISENGAGE] -
## the identical wind-down it already runs when a chase is broken off any
## other way. No new state, no new pursuit rule and no new combat rule exists
## because this node does.
##
## [b]Authored as a child of the place it protects.[/b] Dropped under the
## Saloon's or the Market's own location node, it inherits that location's
## position, so moving the landmark moves the safe ground with it and there is
## no second copy of where the Saloon is to fall out of step. [member radius]
## is the whole of its tuning.
##
## [b]A map with none behaves exactly as it always did.[/b] Every query walks
## the group below and finds nothing, which every caller reads as "nowhere is
## safe", so no scene authored before this node existed changes.

## Group every sanctuary joins, so a bandit finds them all without being wired
## to any one of them - the same convention [WorldBandit], [WorldMapLocation]
## and [WorldMapRegionZone] already use.
const GROUP := &"world_map_sanctuary"

## How far the safe ground reaches from this node, in pixels.
@export var radius: float = 1500.0
## Whether this sanctuary is in force at all. Off leaves the node in the scene
## and simply stops it answering, which is how a later system closes one down
## without removing it.
@export var active: bool = true


func _ready() -> void:
	add_to_group(GROUP)


## Whether [param point] is standing on safe ground anywhere on this map.
## False on a map with no sanctuaries in it at all.
static func contains(from_node: Node, point: Vector2) -> bool:
	if from_node == null or not from_node.is_inside_tree():
		return false
	for node: Node in from_node.get_tree().get_nodes_in_group(GROUP):
		var sanctuary := node as WorldMapSanctuary
		if sanctuary != null and sanctuary.covers(point):
			return true
	return false


## Whether [param point] falls inside this one sanctuary.
func covers(point: Vector2) -> bool:
	return active and global_position.distance_squared_to(point) <= radius * radius
