class_name EnemySpawner
extends Node2D
## Spawns enemies just outside the camera's visible area, along the inside of
## the arena.
##
## It knows nothing about waves - it just places one enemy per [method spawn]
## call and lets a [WaveManager] decide how many and how often.
##
## The spawn point is picked on one of the four screen edges, pushed
## [member spawn_margin] past the edge so the enemy is never visible when it
## appears, then pulled back inside [member arena_bounds] so nothing can spawn
## outside the play area. An edge whose band would end up on screen after that
## clamp is skipped, which is what keeps enemies from popping into view on the
## short sides of a tight arena.
##
## The chase target is handed to the enemy before it enters the tree, so the
## enemy's own `_ready()` wiring resolves it normally - no change to the enemy
## itself is needed.

signal spawned(enemy: Node2D)

enum Edge { LEFT, RIGHT, TOP, BOTTOM }

## How many past spawn points are remembered for the spacing check.
const RECENT_LIMIT := 64

## Enemy scene instanced on every spawn.
@export var enemy_scene: PackedScene
## Node spawned enemies chase. Passed straight to the enemy's own `target_path`.
@export var target_path: NodePath
## Camera whose view enemies must stay outside of. Left empty, the active
## [Camera2D] is used, which is normally the one on the player.
@export var camera_path: NodePath
## Node spawned enemies are parented to. Left empty, they are parented to this
## spawner, which keeps the world scene tidy.
@export var container_path: NodePath
## Difficulty curve applied to every enemy as it is built. Left unresolved,
## enemies spawn at exactly the stats their scene was authored with, which is the
## round-1 baseline - so the spawner works with or without one.
@export var round_scaling_path: NodePath = ^"../RoundScaling"

@export_group("Placement")
## Play area enemies must stay inside - the walls' inner faces, not the walls.
@export var arena_bounds := Rect2(-800.0, -450.0, 1600.0, 900.0)
## Keeps a spawn point off the walls. Must clear the enemy's collision shape,
## which sits above its origin, or it would spawn embedded in a wall.
@export var arena_inset: float = 40.0
## Clear gap left between the enemy's artwork and the edge of the screen. The
## art's own reach is added to this per edge, so this is the amount of genuinely
## empty space, not the distance to the enemy's origin.
@export var spawn_margin: float = 24.0
## How far the enemy's art reaches from its origin: x sideways, y upwards.
## The art is bottom-anchored - it stands well above its origin and barely below
## it - so an enemy spawning below the screen has to sit much further out than
## one spawning above it. Without this the short edges never qualify at all.
@export var enemy_art_extent := Vector2(60.0, 90.0)
## Enemies in one burst are kept at least this far apart where possible.
@export var min_spawn_separation: float = 56.0
## How many positions are tried before the best one so far is accepted.
@export var max_placement_attempts: int = 24

@onready var _target: Node2D = get_node_or_null(target_path) as Node2D
@onready var _camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var _scaling: RoundScaling = get_node_or_null(round_scaling_path) as RoundScaling

var _container: Node
var _recent: Array[Vector2] = []


func _ready() -> void:
	_container = get_node_or_null(container_path)
	if _container == null:
		_container = self


## Forgets previous spawn points so the spacing check only measures the burst
## about to be placed. Without this, enemies that spawned earlier and have long
## since walked away keep crowding the arithmetic and push later waves into
## worse positions.
func begin_batch() -> void:
	_recent.clear()


## Places one enemy off screen and returns it, or null if it could not spawn.
##
## Where it goes is [method pick_spawn_position] - a point on one of the four
## screen edges - which is the whole of how an arena round arrives and has not
## changed.
func spawn() -> Node2D:
	return spawn_at(pick_spawn_position())


## Builds one enemy and puts it at [param point], returning it, or null if it
## could not spawn.
##
## [b]The same spawn, with the choice of place taken out of it.[/b] Everything an
## enemy needs on the way into the world - its chase target handed over before it
## enters the tree, the round's multipliers applied while its health pool can still
## be raised, the container it is parented to, the interpolation reset - happens
## here and therefore happens identically however the point was arrived at.
##
## It exists for a fight that decides its own positions. [TravelWaveDirector]
## forms enemies up across the player's route to the horse cart rather than around
## the edge of the screen, and it does that by choosing points and calling this -
## so a travel enemy is an ordinary enemy, built by this spawner, with ordinary AI,
## and there is no second spawner anywhere in the project.
func spawn_at(point: Vector2) -> Node2D:
	if enemy_scene == null:
		return null

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return null

	# Handed over before the enemy enters the tree so its own @onready lookup
	# resolves on the first frame - that is what wires up its chase, head aim
	# and knife aim. An absolute path, so the container it lands in is free to
	# sit anywhere in the scene.
	if _target != null and "target_path" in enemy:
		enemy.target_path = _target.get_path()

	# Scaled here for the same reason the target is handed over here: the health
	# pool fills itself from its ceiling on ready, so the round's multipliers have
	# to land while the enemy is still outside the tree.
	if _scaling != null:
		_scaling.apply_to(enemy)

	_container.add_child(enemy)
	enemy.global_position = point
	# Physics interpolation is on project-wide; without this the enemy would be
	# visibly smeared in from wherever the container sat last frame.
	enemy.reset_physics_interpolation()

	_remember(point)
	spawned.emit(enemy)
	return enemy


## Best off-screen point found within [member max_placement_attempts] tries.
## Spacing is a preference, not a guarantee - a crowded edge still spawns rather
## than silently dropping the enemy.
func pick_spawn_position() -> Vector2:
	var view := get_view_rect()
	var best := Vector2.ZERO
	var best_separation := -1.0

	for attempt in maxi(max_placement_attempts, 1):
		var point := _random_point_outside(view)
		var separation := _separation_from_recent(point)
		if separation >= min_spawn_separation:
			return point
		if separation > best_separation:
			best_separation = separation
			best = point

	return best


## The camera's visible rectangle in world space. Uses the camera's own screen
## centre, so limits and position smoothing are already accounted for.
func get_view_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var camera := _resolve_camera()
	if camera == null:
		return Rect2(-viewport_size * 0.5, viewport_size)

	var size := viewport_size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)


func _resolve_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	_camera = get_viewport().get_camera_2d()
	return _camera


## Picks an edge that genuinely has off-screen room and returns a point on it.
## When no edge does - an arena barely larger than the screen - the roomiest one
## is used, so spawning degrades instead of failing.
func _random_point_outside(view: Rect2) -> Vector2:
	var usable := _usable_edges(view)
	var edge := Edge.LEFT
	if usable.is_empty():
		edge = _roomiest_edge(view)
	else:
		edge = usable[randi() % usable.size()] as Edge
	return _point_on_edge(edge, view)


func _usable_edges(view: Rect2) -> Array[int]:
	var usable: Array[int] = []
	for edge: int in [Edge.LEFT, Edge.RIGHT, Edge.TOP, Edge.BOTTOM]:
		if _edge_clearance(edge, view) >= _required_clearance(edge):
			usable.append(edge)
	return usable


## Ranked by how much room an edge has *spare*, so edges are compared fairly
## even though they need different amounts.
func _roomiest_edge(view: Rect2) -> Edge:
	var best := Edge.LEFT
	var best_surplus := -INF
	for edge: int in [Edge.LEFT, Edge.RIGHT, Edge.TOP, Edge.BOTTOM]:
		var surplus := _edge_clearance(edge, view) - _required_clearance(edge)
		if surplus > best_surplus:
			best_surplus = surplus
			best = edge as Edge
	return best


## How far an enemy's origin must sit outside a given edge for its art to be
## fully hidden: the clear gap, plus however far the art reaches back towards
## the screen from that side.
func _required_clearance(edge: int) -> float:
	match edge:
		Edge.LEFT, Edge.RIGHT:
			return spawn_margin + absf(enemy_art_extent.x)
		Edge.TOP:
			# Standing above the screen, only the enemy's feet point back at it.
			return spawn_margin
		_:
			return spawn_margin + absf(enemy_art_extent.y)


## Fixed coordinate of an edge's spawn band - x for left/right, y for top/bottom.
## Pushed clear of the view, then clamped into the arena.
func _edge_line(edge: int, view: Rect2) -> float:
	var inner := arena_bounds.grow(-arena_inset)
	var needed := _required_clearance(edge)
	match edge:
		Edge.LEFT:
			return maxf(view.position.x - needed, inner.position.x)
		Edge.RIGHT:
			return minf(view.end.x + needed, inner.end.x)
		Edge.TOP:
			return maxf(view.position.y - needed, inner.position.y)
		_:
			return minf(view.end.y + needed, inner.end.y)


## How far outside the view that band actually sits once clamped. Smaller than
## [member spawn_margin] means the arena ran out before the margin was reached.
func _edge_clearance(edge: int, view: Rect2) -> float:
	var line := _edge_line(edge, view)
	match edge:
		Edge.LEFT:
			return view.position.x - line
		Edge.RIGHT:
			return line - view.end.x
		Edge.TOP:
			return view.position.y - line
		_:
			return line - view.end.y


## Randomised along the whole length of that side of the arena rather than just
## the slice the camera can see. The wider band is what keeps a large wave from
## bunching up: the fixed coordinate already puts the point off screen, so
## spreading along the edge costs nothing.
func _point_on_edge(edge: int, view: Rect2) -> Vector2:
	var inner := arena_bounds.grow(-arena_inset)
	var line := _edge_line(edge, view)

	if edge == Edge.LEFT or edge == Edge.RIGHT:
		return Vector2(line, randf_range(inner.position.y, inner.end.y))

	return Vector2(randf_range(inner.position.x, inner.end.x), line)


## Distance to the nearest recent spawn, or INF when nothing has spawned yet.
func _separation_from_recent(point: Vector2) -> float:
	var nearest := INF
	for other: Vector2 in _recent:
		nearest = minf(nearest, point.distance_to(other))
	return nearest


func _remember(point: Vector2) -> void:
	_recent.append(point)
	if _recent.size() > RECENT_LIMIT:
		_recent.remove_at(0)
