class_name WorldMapOcclusion
extends Node
## Whether the player can actually see through to a point on the World Map
## right now - the question Fog of War never asks. Fog says a point is close
## enough, and inside ground the player has already uncovered, to be seen at
## all; this says whether anything physically solid - a rock, a canyon wall -
## is standing directly between the player and it at this instant. A location
## can answer VISIBLE to [WorldMapFog] and still be hidden by this, and that
## is the whole of what this class exists to add.
##
## [b]It is a second question, not a second Fog.[/b] Nothing here discovers,
## remembers or forgets anything - see [WorldMapFog] for that, left entirely
## untouched. This node owns no state of its own between calls; every answer
## is worked out fresh off the physics world as it is asked, so there is
## nothing here that could ever drift out of step with geometry that moved.
##
## [b]One raycast, the same one [WorldBandit] already made for its own AI
## before this file existed.[/b] [member vision_obstruction_mask] is the
## identical "world" + "prop_solid" mask that class's own line-of-sight
## check already used - see [method has_line_of_sight], now the one place
## that raycast lives, with [method WorldBandit._has_line_of_sight] reduced
## to calling it. That is the whole of "the same obstruction information
## remains usable by visual World Map visibility and WorldBandit line-of-
## sight AI": one function, two callers, and neither a second obstruction
## layer nor a second geometry cache anywhere.
##
## [b]Cheap by construction, not by caching.[/b] A World Map has a handful of
## bandits, a dozen-odd locations and at most a couple of bounty bosses alive
## at once, and every caller here already only re-asks on the same throttled
## timers [WorldMapFog] and [WorldMapLocationDirector] use - a few dozen
## single-segment ray tests every fraction of a second, nowhere near "hundreds
## of rays every frame". That is why this stays a plain
## [method PhysicsDirectSpaceState2D.intersect_ray] rather than a visibility
## polygon or a cached mesh: at this scale the plain query is already cheaper
## than building and maintaining anything cleverer.

## Group this joins, so [method get_active] can find it without a path
## across the scene - the same lookup convention every other World Map
## singleton in this project uses.
const GROUP := &"world_map_occlusion"

## Bodies asked for when a caller wants "from the player" rather than naming
## their own start point.
@export var player_group: StringName = &"player"
## Physics layers a sightline can be blocked by. Deliberately the exact
## default [member WorldBandit.vision_obstruction_mask] already shipped with -
## "world" (layer 1) and "prop_solid" (layer 6) - so nothing about which
## geometry blocks sight is decided twice.
@export_flags_2d_physics var vision_obstruction_mask: int = 33


func _enter_tree() -> void:
	add_to_group(GROUP)


## The occlusion node in this world, or null when it has none - which every
## caller reads as "assume nothing blocks anything", the same fail-open
## every [WorldMapFog] and [WorldMapPlayerPower] caller already falls back
## to for a scene that has not added the system being asked about.
static func get_active(from_node: Node) -> WorldMapOcclusion:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapOcclusion


## Whether [param at] is unobstructed as seen from wherever the player
## currently stands. What [WorldMapLocation], [WorldBandit] and
## [WorldBountyBoss] each ask once per throttled visibility tick. True when
## there is no player to ask about, the same "nothing to check against yet"
## fallback the rest of the World Map already uses.
func is_visible_from_player(at: Vector2) -> bool:
	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null:
		return true

	var exclude: Array[RID] = []
	if player is CollisionObject2D:
		exclude.append((player as CollisionObject2D).get_rid())
	return has_line_of_sight(player.global_position, at, exclude)


## The general primitive: whether a straight line from [param from] to
## [param to] is unbroken by anything on [member vision_obstruction_mask].
## [param exclude] is a list of colliders the ray should ignore - pass the
## body standing at either end, the same way [WorldBandit] already excluded
## the player's own [CollisionObject2D] so a ray aimed exactly at a body
## never reports that body hitting itself.
func has_line_of_sight(from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
	if not is_inside_tree():
		return true
	var viewport := get_viewport()
	var space := null if viewport == null else viewport.world_2d.direct_space_state
	if space == null:
		return true

	var params := PhysicsRayQueryParameters2D.create(from, to, vision_obstruction_mask)
	if not exclude.is_empty():
		params.exclude = exclude
	var result := space.intersect_ray(params)
	return result.is_empty()
