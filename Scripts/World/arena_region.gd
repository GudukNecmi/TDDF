class_name ArenaRegion
extends Node
## Which part of the map an arena scene is a fight in.
##
## [b]It exists so an arena scene can say what it is.[/b] The arena's ground and
## its regional props already come from a [MapRegion] - see
## [method RegionGround.apply] and [member PropScatter.include_region_layers] -
## but both used to ask [RunSessionState] for it, because there was only ever one
## arena and the only way to know which place it was standing in was to ask what
## the run had chosen. There is an arena scene per region now, so the scene knows,
## and saying so here is more direct and cannot disagree with the map the fight
## was picked up from.
##
## [b]Nothing was rewritten to read this.[/b] It answers [code]get_region()[/code],
## which is exactly the method [RegionGround] and [PropScatter] already call on
## whatever their own region source is pointed at, so binding an arena to a place
## is pointing those two at this node in the Inspector - no branch, no second
## ground system and no second scatter path.

## Group this joins, so anything that wants to know which region an arena is can
## find it without a path.
const GROUP := &"arena_region"

## The place this arena is a fight in. One of the map's own
## [code]region_a.tres[/code] through [code]region_e.tres[/code] files.
##
## Left empty, this falls back to asking the session, which is what a bare arena
## scene opened on its own for tuning wants.
@export var region: MapRegion
## Where the region is asked when this node has not been given one.
@export var session_path: NodePath = ^"/root/RunSession"


func _enter_tree() -> void:
	add_to_group(GROUP)


## The arena region in this world, or null when the scene has none.
static func get_active(from_node: Node) -> ArenaRegion:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as ArenaRegion


## The place this arena is, for anything that asks a region source the same way
## [RegionGround] and [PropScatter] already do.
func get_region() -> MapRegion:
	if region != null:
		return region
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_region"):
		return null
	return session.call(&"get_region") as MapRegion
