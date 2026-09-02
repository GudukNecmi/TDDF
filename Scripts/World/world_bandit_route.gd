class_name WorldBanditRoute
extends Node2D
## An ordered set of patrol waypoints a [WorldBandit] walks between.
##
## A route is authored as this node's own children rather than as coordinates
## written into a resource or a script: each child's [member Node2D.position]
## is one waypoint, in the order the children appear under it, so dragging a
## point in the editor is the whole of moving a patrol leg and adding one is
## dragging in a new [Node2D]. [WorldBandit] never reads a coordinate off
## this class - only [method get_points], which resolves every child's
## [member Node2D.global_position] - so a route stays correct wherever the
## World Map itself ends up being instanced, exactly the way any other node
## in the scene tree does.
##
## [b]Two shapes, not two systems.[/b] [member loop] chooses between the two
## kinds of route asked for: off is the default "there and back" - a bandit
## walks the points in order and reverses direction at each end, the way
## [code]A -> B -> C -> B -> A[/code] reads - and on is a closed loop that
## wraps from the last point straight back to the first. Nothing about
## [WorldBandit]'s walk changes between the two beyond which index comes
## next; see [method WorldBandit._advance_route_index].

## Wraps from the last point back to the first instead of reversing at the
## ends. Off is a ping-pong route: the bandit walks out to the last point and
## back again, forever.
@export var loop: bool = false


## Every waypoint, in order, as global positions - correct regardless of
## where this route's own parent chain has placed it. Empty for a route
## authored with no children, which every caller reads as "nowhere to
## patrol".
func get_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for child in get_children():
		var point := child as Node2D
		if point != null:
			points.append(point.global_position)
	return points
