class_name RunMapBanditEncounter
extends Resource
## One kind of bandit point on a run map: what it is called on the graph, how
## many men are waiting there, and what the point is written down as once it has
## been dealt with.
##
## [b]A second kind of bandit point is one of these in the Inspector.[/b] The
## desert has two - a group of twenty to forty and a camp of forty to eighty -
## and they are the same node event answered by the same decision screen and the
## same arena, differing only in the numbers on this resource. See
## [member RunMapBanditNode.encounters].
##
## [b]The count is never stored on the map.[/b] It is rolled from the graph's own
## seed and the point's id, so it is the same number every time it is asked for
## and survives the arena being built and torn down without being written
## anywhere - see [method RunMapBanditNode.enemy_count_for].

## The handle the generator writes onto the points this answers - matched
## against [member RunMapSite.kind].
@export var kind: StringName = &""
## The fewest and the most men such a point can be worth. Rolled per point and
## never shown before the fight.
@export var min_enemies: int = 20
@export var max_enemies: int = 40
## What the point is rewritten as once its question has been answered, whichever
## way it was answered. A point the piece rides back through is not a second
## encounter - the men there have been paid, robbed, walked away from or killed.
@export var cleared_kind: StringName = &""
