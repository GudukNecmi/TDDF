class_name EnemyTargeting
extends RefCounted
## Finding enemies to aim something at.
##
## Static helpers with no state and no node of their own, because "who is nearest"
## is a question, not a thing: a bullet looking for its next bounce, a coin
## deciding where to fly and whatever is added later all ask it the same way and
## get the same answer.
##
## What counts as a target is deliberately decided in one place. An enemy is
## valid when it is in the [code]enemies[/code] group, still in the tree, and
## still alive - a corpse mid-fade is in the group for another second or two, and
## nothing should ever be redirected into one. Anything wanting different rules
## passes a different group rather than reimplementing the search.

## Group every enemy joins. The one place the name is written down.
const ENEMY_GROUP := &"enemies"


## The nearest valid enemy to [param from], or null when there is none.
##
## [param radius] of 0 or less searches the whole arena; anything else ignores
## enemies beyond it, which is what stops a bounce crossing the entire map to find
## somebody. [param exclude] is skipped entirely - a bounce passing over the enemy
## it just hit is what that is for.
static func nearest(
	origin: Node,
	from: Vector2,
	radius: float = 0.0,
	exclude: Array = []
) -> Node2D:
	var found := nearest_many(origin, from, 1, radius, exclude)
	return found[0] if not found.is_empty() else null


## The [param count] nearest valid enemies, closest first.
##
## Returns fewer than asked for when there are fewer to be had - which is exactly
## what "the coin and the bullet take different targets when there are two, and
## the same one when there is only one" is built on. The caller reads the size
## rather than being told there was nothing.
static func nearest_many(
	origin: Node,
	from: Vector2,
	count: int,
	radius: float = 0.0,
	exclude: Array = []
) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if origin == null or not origin.is_inside_tree() or count <= 0:
		return found

	var limit := radius * radius
	var ranked: Array[Dictionary] = []
	for node: Node in origin.get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node2D
		if enemy == null or exclude.has(enemy) or not is_valid(enemy):
			continue

		var distance := from.distance_squared_to(enemy.global_position)
		if radius > 0.0 and distance > limit:
			continue
		ranked.append({"enemy": enemy, "distance": distance})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"])

	for row: Dictionary in ranked.slice(0, count):
		found.append(row["enemy"])
	return found


## Whether [param enemy] is something worth aiming at: in the tree, and not
## already dead.
##
## The health check is what keeps a bounce out of a corpse. An enemy with no
## [Health] at all is treated as alive, so a target built differently is not
## silently ignored.
static func is_valid(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false

	var health := enemy.get_node_or_null(^"Health") as Health
	return health == null or health.is_alive()
