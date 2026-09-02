class_name WorldMapPlayerPower
extends Node
## A single, readable number for how strong the player currently is on the
## World Map - the other half of the comparison every [WorldBandit] makes
## against its own [member WorldBandit.group_strength].
##
## [b]A placeholder seam, not the progression system.[/b] There is no XP,
## gear or upgrade math behind [member player_power] yet - it is one
## inspector-configurable figure a bandit can read, so the fleeing and
## chasing this phase asks for has something real to compare against without
## the permanent power/progression system being built first. A later phase
## replacing it only has to make this number honest - added up from
## whatever the player has actually earned - and nothing in
## [code]world_bandit.gd[/code] has to change, because it only ever asks
## [method WorldMapPlayerPower.get_active] for the current figure.
##
## Found by group the same way [WorldMapState], [DayCycleDirector] and
## [CameraController] already are, rather than by path or autoload, so it
## can sit anywhere under the World Map.

## Group this joins, so [method get_active] can find it without a path
## across the scene.
const GROUP := &"world_map_player_power"

## How strong the player currently reads to a bandit sizing them up. Tune
## this to move where groups start fleeing or giving chase - see
## [WorldBanditThreatProfile] - without touching a single group's own
## strength.
@export var player_power: float = 30.0


func _enter_tree() -> void:
	add_to_group(GROUP)


## The World Map's player-power node, found by group. Null means none is in
## the tree, which every caller reads as "assume nothing about the player's
## strength".
static func get_active(from_node: Node) -> WorldMapPlayerPower:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapPlayerPower
