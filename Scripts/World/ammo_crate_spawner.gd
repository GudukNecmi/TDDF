class_name AmmoCrateSpawner
extends Node
## Drops ammunition into a locked arena while the fight is on: one crate every ten
## seconds, never more than a few standing at once, and always out towards the edges.
##
## [b]It hangs off the arena, not off the boss.[/b] [signal BossArena.locked] is what
## starts it and [signal BossArena.unlocked] is what stops it, so it needs to know
## nothing about bosses, bounties or phases - and any later fixed-screen encounter that
## locks the same arena gets its ammunition supply for free. The rectangle it drops
## crates into is the arena's own, handed over by that signal, which is also why a crate
## can never land outside the picture or outside the fence.
##
## The pacing is the brief's, and all of it is inspector-tunable:
##
##   [codeblock]
##   fight starts  ->  10s  ->  crate  ->  10s  ->  crate  ->  10s  ->  ...
##                                            (skipped while 3 are standing)
##   [/codeblock]
##
## [b]The ceiling is on uncollected crates, not on crates dropped.[/b] The clock keeps
## running whatever happens; each time it comes round, a crate appears only if fewer
## than [member max_uncollected] are still waiting to be picked up - see
## [method _try_spawn]. So a player who leaves them lying about stops receiving more
## until they collect one, and a player who takes each crate as it appears gets one every
## ten seconds indefinitely. Nothing is owed and nothing accumulates: a check that is
## skipped is simply skipped.
##
## [b]They land out near the walls.[/b] Where exactly is [method pick_position], which
## rolls a point in a band around the outside of the arena rather than anywhere in it -
## so ammunition is somewhere the player has to break off and go to, instead of appearing
## under the fight in the middle of the screen.

## Emitted for each crate dropped, with the crate and where it landed.
signal crate_spawned(crate: Node2D, at: Vector2)
## Emitted when a crate is collected, with how many rounds it was worth.
signal crate_collected(rounds: int)

## Group this node joins, so a test can find it without a path.
const GROUP := &"ammo_crate_spawner"

## The arena whose lock starts and stops the supply. Left unresolved, the active one is
## found by group - so this node does not have to be a sibling of it.
@export var arena_path: NodePath = ^"../BossArena"
## What is dropped. Left empty, nothing is - which is what a world with no crate scene
## should do rather than erroring every ten seconds.
@export var crate_scene: PackedScene
## Node crates are parented to. Left empty they are parented to the arena, so they go
## away with it.
@export var container_path: NodePath
## Group the player is found in, so a crate is not dropped on top of them.
@export var player_group: StringName = &"player"
## Group every crate joins, counted to enforce the ceiling. Crates leave it the instant
## they are taken - see [method AmmoCrate.use] - so this counts the uncollected ones
## only.
@export var crate_group: StringName = &"ammo_crate"

@export_group("Pacing")
## Seconds after the arena locks before the first crate appears.
##
## [b]Ten, and deliberately not zero.[/b] The fight opens with the player already
## carrying whatever they walked in with; ammunition arriving immediately would mean
## the opening was never fought on the load they chose to bring.
@export var first_delay: float = 10.0
## Seconds between one attempt at a crate and the next.
@export var interval: float = 10.0
## Most uncollected crates allowed standing at once. A check that finds this many
## already waiting passes without dropping anything.
@export var max_uncollected: int = 3
## Whether crates left over are cleared when the arena is given back. On, so ammunition
## from a fight cannot be walked back to and collected in the open desert afterwards.
@export var clears_on_unlock: bool = true

@export_group("Where they land")
## The band a crate lands in, as a fraction of the way from the middle of the arena to
## its wall: 0 is the centre, 1 is the wall itself.
##
## [b]This is the whole of "prefer the edges, never the centre".[/b] The default keeps
## crates in the outer half, so going for one means leaving the fight - which is the
## decision a crate is meant to be. Widening it towards 0 makes ammunition safer to
## reach; nothing in the script has to change either way.
@export var edge_band := Vector2(0.62, 0.94)
## How far inside the arena's walls a crate is held, in pixels, so its artwork and its
## reach circle are both comfortably on screen rather than half behind a wall.
@export var wall_clearance: float = 150.0
## How far a crate is kept from the player where possible, in pixels. Somewhere to walk
## to, not something that lands at their feet.
@export var player_clearance: float = 420.0
## How far crates are kept from each other where possible, in pixels, so three standing
## at once are three places rather than one pile.
@export var crate_clearance: float = 360.0
## How many points are tried before the best one so far is accepted. Spacing is a
## preference, not a guarantee - a crowded arena still gets its crate rather than
## silently skipping it.
@export var placement_attempts: int = 14
## Whether a crate is only ever put down somewhere the player can currently see.
##
## [b]On, and it is what stops a crate being dropped behind the player's back.[/b]
## The band below throws crates out towards the edges of whatever they are being
## placed in, and that rectangle used to be the whole arena - which is several
## screens across, so a crate could quite legitimately land somewhere the player
## would never look. With this on the rectangle is first cut down to the patch of
## world the camera is actually showing - see
## [method CameraController.get_visible_world_rect] - so "out near the edge" becomes
## "out near the edge of the picture" and everything downstream is unchanged.
##
## It is "when possible": a camera that cannot be found, or a visible patch with no
## room left in it once the clearances are taken off, falls back to the full area
## rather than refusing to drop a crate at all.
@export var keeps_on_screen: bool = true
## How far inside the edge of the picture a crate must land, in pixels, so it is
## never half off the side of the screen.
@export var screen_margin: float = 170.0
## Whether crates fall in from above rather than simply being there.
##
## [b]On for every crate, not only the one a search promises.[/b] The arrival - the
## fall, the shake as it hits, the bounce - is [method AmmoCrate.drop_in] and was
## already written; the arena's own supply just never asked for it, which is most of
## why a crate appearing out near a wall was easy to miss.
@export var drops_in: bool = true
## How large a patch crates are dropped into when there is no arena rectangle to drop
## them into - a crate asked for directly, in the open desert, rather than one the
## fight's own clock produced.
##
## [b]It never applies during a fight.[/b] The rectangle handed over by
## [signal BossArena.locked] is used whenever there is one, so this only decides where
## a crate lands when something has asked for one outside a locked arena, and it is
## measured round the player so the crate is somewhere they can reach.
@export var open_area_size := Vector2(1800.0, 1000.0)

var _arena: BossArena
var _area := Rect2()
var _running: bool = false
var _timer: float = 0.0
## Where a crate asked for through [method spawn_crate_in] is parented, for the length
## of that one call. Null the rest of the time, which is every crate the arena's own
## clock drops.
var _handed_container: Node


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_process(false)
	var arena := _resolve_arena()
	if arena == null:
		return
	if not arena.locked.is_connected(_on_arena_locked):
		arena.locked.connect(_on_arena_locked)
	if not arena.unlocked.is_connected(_on_arena_unlocked):
		arena.unlocked.connect(_on_arena_unlocked)


## The crate supply in this world, or null when it has none.
static func get_active(from_node: Node) -> AmmoCrateSpawner:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as AmmoCrateSpawner


func is_running() -> bool:
	return _running


## Seconds until the next attempt at a crate, for a readout or a test.
func get_time_to_next() -> float:
	return maxf(_timer, 0.0)


## How many uncollected crates are standing.
func get_uncollected() -> int:
	return get_tree().get_nodes_in_group(crate_group).size()


## Starts dropping crates into [param area], with the first one [member first_delay]
## away.
##
## Public and callable directly, so a fight that is not an arena lock - a test, a later
## set piece - can turn the supply on without one.
func begin(area: Rect2) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	_area = area
	_running = true
	_timer = maxf(first_delay, 0.0)
	set_process(true)


## Stops the supply. Crates already standing are cleared or left according to
## [member clears_on_unlock].
func stop() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	if clears_on_unlock:
		clear_crates()


## Takes away every uncollected crate. What the arena being given back calls, so
## ammunition dropped for a fight cannot be collected long after it.
func clear_crates() -> void:
	for node: Node in get_tree().get_nodes_in_group(crate_group):
		node.queue_free()


func _on_arena_locked(area: Rect2) -> void:
	begin(area)


func _on_arena_unlocked() -> void:
	stop()


func _process(delta: float) -> void:
	if not _running:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	# The clock is reset whether a crate was dropped or not. A check skipped because the
	# player is hoarding is not owed to them later - it simply did not happen.
	_timer = maxf(interval, 0.5)
	spawn_crate()


## One crate, unless there are already enough standing. Returns the crate, or null when
## nothing was dropped - which is the ceiling being reached far more often than it is a
## failure.
##
## [b]This is the whole of dropping a crate[/b], and the ten-second clock is only one
## caller of it. Anything else asking for one - a later set piece, or the developer
## panel - gets the same ceiling, the same placing and the same wiring rather than a
## second way of putting a crate on the ground.
func spawn_crate() -> Node2D:
	if crate_scene == null:
		return null
	if max_uncollected > 0 and get_uncollected() >= max_uncollected:
		return null

	var crate := crate_scene.instantiate() as Node2D
	if crate == null:
		push_warning("AmmoCrateSpawner: crate scene is not a Node2D.")
		return null

	var point := pick_position()
	_container().add_child(crate)
	crate.global_position = point
	# Physics interpolation is on project-wide; without this the crate would be visibly
	# smeared in from wherever its container sat last frame.
	crate.reset_physics_interpolation()

	var box := crate as AmmoCrate
	if box != null and not box.collected.is_connected(_on_crate_collected):
		box.collected.connect(_on_crate_collected)

	# Dropped in after it has been placed and parented, because the fall is measured
	# against where it is standing and against what the camera is showing.
	if drops_in and box != null:
		box.drop_in()

	crate_spawned.emit(crate, point)
	return crate


## One crate placed inside [param area] and parented to [param into], rather than
## inside whatever rectangle an arena lock happened to hand over.
##
## [b]It is [method spawn_crate] with the rectangle handed in.[/b] A fight that is not
## an arena lock - the search for trouble, which drops its single crate through here -
## still gets the same placing, the same ceiling, the same wiring and the same
## artwork, so there is one way a crate reaches the ground rather than two. Returns the
## crate, or null when nothing was dropped.
func spawn_crate_in(area: Rect2, into: Node = null) -> Node2D:
	var saved_area := _area
	var saved_container := _handed_container
	_area = area
	_handed_container = into

	var crate := spawn_crate()

	_area = saved_area
	_handed_container = saved_container
	return crate


func _on_crate_collected(rounds: int, _ammo_id: StringName) -> void:
	crate_collected.emit(rounds)


## Where one crate lands: in the band described by [member edge_band], away from the
## player and away from the other crates.
##
## The band is measured on the arena's own half-extents rather than in pixels, so it
## reads the same for an arena of any size: a point is rolled inside the rectangle,
## pushed out until the further of its two axes sits in the band, and that is what puts
## every crate out towards a wall without any of the four corners being named.
##
## Spacing is ranked rather than required, exactly as [EnemySpawner] ranks its own - a
## crowded arena still gets a crate, in the roomiest place found, instead of the check
## being skipped and the player left without ammunition.
func pick_position() -> Vector2:
	var box := _on_screen_part_of(_drop_area())
	var usable := box.grow(-maxf(wall_clearance, 0.0))
	if usable.size.x <= 0.0 or usable.size.y <= 0.0:
		usable = box

	var best := usable.get_center()
	var best_room := -INF

	for attempt: int in range(maxi(placement_attempts, 1)):
		var point := _point_in_band(usable)
		var room := _room_at(point)
		if room >= 0.0:
			return point
		if room > best_room:
			best_room = room
			best = point

	return best


## [param area] cut down to the part of it the player can currently see.
##
## Handed back whole when there is no camera to ask, or when what is left of it once
## the margin is taken off has no room in it - which is the "when possible" in
## [member keeps_on_screen]: a crate somewhere awkward is better than no crate.
func _on_screen_part_of(area: Rect2) -> Rect2:
	if not keeps_on_screen:
		return area

	var camera := CameraController.get_active(self)
	if camera == null:
		return area

	var shown := camera.get_visible_world_rect().grow(-maxf(screen_margin, 0.0))
	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		return area

	var both := area.intersection(shown)
	return area if both.size.x <= 0.0 or both.size.y <= 0.0 else both


## A point in [param box] whose distance from the middle, measured as a fraction of the
## way to the wall, falls inside [member edge_band].
func _point_in_band(box: Rect2) -> Vector2:
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	# How far out this direction already is, on whichever axis is further - which is the
	# axis that decides which wall the point is near.
	var reach := maxf(absf(offset.x), absf(offset.y))
	if reach < 0.001:
		offset = Vector2.RIGHT.rotated(randf() * TAU)
		reach = maxf(absf(offset.x), absf(offset.y))

	var wanted := randf_range(
		minf(edge_band.x, edge_band.y), maxf(edge_band.x, edge_band.y))
	offset *= clampf(wanted, 0.0, 1.0) / maxf(reach, 0.001)
	return box.get_center() + offset * box.size * 0.5


## How much clear room [param point] has: how far past the nearest required gap it is.
## Negative means something is too close, and by how much.
func _room_at(point: Vector2) -> float:
	var slack := INF

	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player != null:
		slack = minf(slack, point.distance_to(player.global_position) - maxf(player_clearance, 0.0))

	for node: Node in get_tree().get_nodes_in_group(crate_group):
		var other := node as Node2D
		if other == null:
			continue
		slack = minf(slack, point.distance_to(other.global_position) - maxf(crate_clearance, 0.0))

	return 0.0 if slack == INF else slack


## The rectangle crates are dropped into: the arena's own whenever there is one, and a
## patch round the player when there is not - see [member open_area_size].
func _drop_area() -> Rect2:
	if _area.size.x > 0.0 and _area.size.y > 0.0:
		return _area

	# Round the player, or round the middle of the world when there is nobody to measure
	# from - this node is a plain [Node] and has no position of its own.
	var centre := Vector2.ZERO
	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player != null:
		centre = player.global_position
	return Rect2(centre - open_area_size * 0.5, open_area_size)


## Where crates are parented: whatever was named, or the arena - so crates go away with
## the thing that owns the fight rather than outliving it somewhere in the world.
func _container() -> Node:
	# Whoever asked for this one crate directly wins, so a crate dropped for something
	# that is not the arena does not end up parented to the arena.
	if _handed_container != null and is_instance_valid(_handed_container):
		return _handed_container
	var named := get_node_or_null(container_path)
	if named != null:
		return named
	var arena := _resolve_arena()
	if arena != null:
		return arena
	return self


func _resolve_arena() -> BossArena:
	if _arena == null or not is_instance_valid(_arena):
		var named := get_node_or_null(arena_path) as BossArena
		_arena = named if named != null else BossArena.get_active(self)
	return _arena
