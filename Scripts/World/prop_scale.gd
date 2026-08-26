class_name PropScale
extends Node
## How big this map's scenery is drawn. One node per map, sitting in the map's own
## scene, holding the single number every prop in it is sized by.
##
## It exists for the same reason [SunController] does, and works the same way. The
## prop scenes - a cactus, a bush, a pile of bones - are shared, and each one is
## authored at the size its artwork was drawn at. How large that reads on a
## particular map is the *map's* business: a desert seen from further out wants
## everything smaller, and that is one number here rather than a scale on every
## prop scene, on every scatter layer and on every shadow, all of which would have
## to be found and kept in step every time the framing changed.
##
## [b]It scales whole prop instances, never artwork.[/b] The multiplier is applied
## to the root of each prop as it is placed, so the picture, its shadow, its
## collision shape and its touch area all grow and shrink together and a prop can
## never end up with a body that does not match its drawing.
##
## Nothing is scaled retroactively: props read it as they are created. That is
## deliberate and is what keeps it a single multiply at spawn rather than
## something watching every prop in the arena forever - but it does mean that
## changing the number while the game is running only affects scenery placed after
## it. Adjust it and reload the map.

## Group this joins, so anything placing a prop can find it without a path across
## the scene.
const GROUP := &"prop_scale"

## Multiplier applied to every prop this map places. 1 draws each prop at exactly
## the size its own artwork was authored at; below 1 makes the whole map's
## scenery smaller without touching a single prop scene.
@export var scale_multiplier: float = 1.0


func _enter_tree() -> void:
	# Joined here rather than in `_ready`, because the scatter places the whole
	# map from its own `_ready` and every node's `_enter_tree` runs before any
	# node's `_ready` - so the setting is findable whatever order the map's nodes
	# happen to sit in.
	add_to_group(GROUP)


## The map's prop scale, or 1 when it has none - which every caller reads as
## "draw props at the size they were authored". Static so a prop can ask without
## being wired to anything.
static func get_multiplier(from_node: Node) -> float:
	if from_node == null or not from_node.is_inside_tree():
		return 1.0

	var node := from_node.get_tree().get_first_node_in_group(GROUP) as PropScale
	if node == null:
		return 1.0
	return maxf(node.scale_multiplier, 0.0)


## Applies the map's scale to [param prop], on top of whatever scale it is already
## carrying. Called by whatever placed it.
##
## Multiplying rather than assigning is what lets a caller that has its own reason
## to resize a prop keep doing so - the map's setting rides on top of it instead
## of overwriting it.
static func apply_to(prop: Node2D, from_node: Node) -> void:
	if prop == null:
		return
	prop.scale *= get_multiplier(from_node)
