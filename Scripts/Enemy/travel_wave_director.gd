class_name TravelWaveDirector
extends Node
## The fighting on a travel map: enemies that form up [i]across the player's route
## to the horse cart[/i] rather than appearing around them.
##
## [b]Why this is not the arena's [WaveManager].[/b] An arena round is a minute
## long and the player is standing in the middle of it, so enemies arriving from
## every edge is the whole shape of the fight. A road is nineteen thousand pixels
## end to end, the player is faster than anything chasing them, and there is no
## clock - so the same spawning produces a fight the player can simply walk out of
## and never return to. The arena's manager is untouched and still owns every
## round; this owns the road, and only the road.
##
## What it does instead is the one idea the road is built on:
##
## [codeblock]
##   PLAYER  ->  ENEMY WALL  ->  HORSE CART
## [/codeblock]
##
## Every wave is aimed down the line from where the player is to where the cart
## stands, and re-aimed from scratch each time - so drifting off the straight line
## does not lose the pursuit, it only changes where the next wall is built. What
## stops a crossing is never an enemy being faster than the player; it is that the
## ground between them and the cart already has a formation standing on it.
##
## [b]Nothing about an enemy is written here.[/b] The bodies are the world's own,
## built by the world's own [EnemySpawner] through [method EnemySpawner.spawn_at]
## and scaled by the world's own [RoundScaling] - so travel enemies are ordinary
## enemies with ordinary AI, and there is no second enemy, no second AI and no
## second difficulty curve. All this decides is [i]where[/i] and [i]how many[/i].
##
## The shapes themselves are not here either. A wall, a V, a knot and an arc are
## [TravelFormation] resources in [member formations], so a new shape is a
## [code].tres[/code] file and nothing in this script names one.

## Emitted as a wave is placed, with how many enemies it was worth.
signal wave_spawned(wave_number: int, enemy_count: int)

## Group the director joins, so anything can find it without a path into a scene
## that is instanced at runtime.
const GROUP := &"travel_wave_director"

## Whether the road fights at all. Off leaves it empty, for crossing it while
## tuning its size or its scenery.
@export var enabled: bool = true

@export_group("Nodes")
## The road this belongs to, read for the rectangle enemies must stay inside.
## Left as the parent, which is where this node lives.
@export var map_path: NodePath = ^".."
## Group the player is found in, so the director is not wired to them.
@export var player_group: StringName = &"player"
## Group the destination is found in.
@export var cart_group: StringName = &"horse_cart"
## Group the living enemies are counted in, for the ceiling and for noticing that
## a wave has been broken.
@export var enemy_group: StringName = &"enemies"

@export_group("Route")
## How far down the route a wave forms up, in pixels from the player.
##
## [b]This is the reaction time.[/b] It has to clear the screen - about 660 pixels
## from the middle to a corner - or the wall would be drawn on top of the player
## instead of being seen coming; and the further out it is, the longer they have to
## pick a side to go round before it closes.
@export var spawn_distance: float = 1250.0
## How much the distance of a single group varies from that, in pixels, so a wave
## reads as several bodies arriving rather than one drawn rank.
@export var spawn_variance: float = 240.0
## Extra ground given to the formation past the player, in pixels. Positive builds
## the wall further towards the cart, negative closer to the player. 0 is the
## honest interception point and is what the road is tuned at.
@export var interception_offset: float = 0.0
## How far ahead of the player the route is aimed, in seconds of their own current
## movement.
##
## A wall built at where the player is standing is a wall they have already left by
## the time it forms. Leading it slightly puts it where they are going, which is
## what makes running at the cart run [i]into[/i] something. Too much and the
## formation lands beside them instead; 0 turns the prediction off.
@export var player_lead_time: float = 0.4
## Closest an enemy may be placed to the player, in pixels. A hard floor under
## every other number here: nothing is ever put on top of them, however the route
## and the formation happened to work out.
@export var min_distance_from_player: float = 820.0
## Closest an enemy may be placed to the horse cart, in pixels. The cart has to
## stay a readable destination rather than a pile, so the final approach is fought
## through what is already on the field instead of through a wave dropped onto it.
@export var min_distance_from_horse: float = 900.0
## Whether every spawn point is pushed clear of the camera's view before it is
## used, so nothing is ever seen appearing. On, and it is the last word: a
## formation that would have clipped the screen is moved rather than drawn.
@export var require_off_screen: bool = true
## Clear gap left between the view's edge and a spawn point, in pixels.
@export var off_screen_margin: float = 60.0
## How far inside the road's own rectangle enemies are kept, in pixels, so nothing
## spawns embedded in a wall.
@export var region_inset: float = 120.0

@export_group("Wave size")
## Enemies in a wave at the start of the road.
##
## Deliberately several times an arena wave. A wall the player can shoot through in
## two shells is not a wall, and the whole point of the road is that the crowd
## between them and the cart has to be dealt with rather than jogged around.
@export var base_enemies_per_wave: int = 11
## Ceiling on a single wave, however far along the road the player is.
@export var max_enemies_per_wave: int = 34
## How much larger a wave gets across the whole crossing, as a fraction. 1.4 means
## the wave at the cart asks for 2.4 times what the wave at the start did, subject
## to [member max_enemies_per_wave].
@export var enemy_count_scaling: float = 1.4

@export_group("Groups")
## The shapes a group may form up in, chosen between per group by
## [member TravelFormation.weight].
##
## [b]Adding a shape is adding an entry here[/b] - see [TravelFormation]. An empty
## array still fights: every group falls back to a plain line across the route.
@export var formations: Array[TravelFormation] = []
## Separate bodies a wave is broken into at the start of the road.
@export var base_group_count: int = 2
## Separate bodies a wave is broken into at the cart.
@export var max_group_count: int = 4
## Gap between the centres of two neighbouring groups, across the route, in pixels.
## Wide enough to read as two forces with a lane between them rather than one
## ragged line.
@export var group_spacing: float = 640.0
## Fewest enemies worth breaking a group off for. A wave that cannot fill its
## groups forms fewer, larger ones instead of a scatter of pairs.
@export var min_group_size: int = 3

@export_group("Formation")
## How wide a formation is drawn across the route at the start of the road, in
## pixels, before its own [member TravelFormation.width_scale].
##
## Measured against the screen, which is about 1150 pixels across: a formation
## near that wide fills the view and has to be broken or gone round, and a much
## narrower one is a knot to be walked past.
@export var formation_width: float = 980.0
## How much wider formations are drawn at the cart, as a fraction. 0.6 is 60%
## wider on the final approach, which is what closes the ends of the road as the
## player nears it.
@export var formation_width_scaling: float = 0.6
## How deep a formation's bow is, in pixels, before its own
## [member TravelFormation.depth_scale]. This is what a V or an arc is measured in;
## a straight line ignores it.
@export var formation_depth: float = 320.0

@export_group("Side pressure")
## Groups coming in from the player's flanks at the start of the road.
##
## [b]They support the interception, they are not it.[/b] Their job is that walking
## round the end of the wall costs something too - without them the widest
## formation is still just an obstacle to be skirted. The main force always comes
## from the direction of travel, which is what
## [member side_group_share] holds to.
@export var base_side_groups: int = 1
## Groups coming in from the flanks at the cart.
@export var max_side_groups: int = 3
## Share of a wave the flanks are allowed between them, from 0 to 1. Kept well
## under half, so the road never becomes a ring closing on the player and there is
## always a readable way out sideways.
@export_range(0.0, 0.9, 0.01) var side_group_share: float = 0.3
## Range of angles a flanking group comes in at, in degrees off the route. Under
## 90 is ahead of the player's shoulder; over 90 is behind it.
@export var side_angle_degrees := Vector2(55.0, 105.0)
## How far out a flanking group forms up, in pixels from the player.
@export var side_spawn_distance: float = 1100.0

@export_group("Pacing")
## Quiet at the start of the road before the first wave forms, in seconds, so the
## player is on their feet and moving before anything is between them and the cart.
@export var first_wave_delay: float = 3.0
## Seconds between waves at the start of the road.
@export var wave_interval: float = 10.0
## Seconds between waves at the cart. Lower than
## [member wave_interval] is what makes the last stretch relentless.
@export var min_wave_interval: float = 5.0
## Share of a wave that has to be left standing before the next one is allowed to
## form early, from 0 to 1.
##
## [b]This is what stops the road being outrun.[/b] Waiting out the whole gap means
## a player who fought through a wall in four seconds then walks unopposed for six;
## breaking a wall instead [i]summons[/i] the next one. Either the player is
## fighting or the clock is running, and neither is a free crossing.
@export_range(0.0, 1.0, 0.01) var clear_fraction: float = 0.3
## Gap between the individual enemies of one wave, in seconds. Small - a formation
## should arrive as a formation - but not zero, so a large wave does not cost a
## frame.
@export var spawn_interval: float = 0.04

@export_group("Pressure")
## Most enemies alive at once at the start of the road.
##
## The road has no clock to end it, so without a ceiling a slow crossing finishes
## under an unplayable crowd. A wave held back by it is not lost: it waits, and
## resumes the frame there is room.
@export var max_active_enemies: int = 34
## Most enemies alive at once at the cart.
@export var max_active_enemies_at_arrival: int = 58
## Enemy maximum health at the start of the road, as a multiplier laid over the
## campaign curve - see [member RoundScaling.extra_health_multiplier]. It
## multiplies rather than replaces, so the road stays harder than whichever round
## the player left.
@export var enemy_health_multiplier: float = 1.6
## The same, at the cart.
@export var enemy_health_multiplier_at_arrival: float = 2.2
## How hard the road's enemies hit at the start of it, on the same footing.
@export var enemy_damage_multiplier: float = 1.4
## The same, at the cart.
@export var enemy_damage_multiplier_at_arrival: float = 1.7

@export_group("Arrival")
## How close to the cart the player has to be for the road to stop forming new
## waves, in pixels. [b]0 - the default - never stops[/b]: the last stretch is
## fought through, and what is already on the field is what has to be survived.
@export var stop_distance: float = 0.0

## The world's spawner, handed over by [TravelDirector] as the road is built.
var _spawner: EnemySpawner
## The world's difficulty curve, given the road's multipliers as each wave forms.
var _scaling: RoundScaling
var _map: TravelMap
var _player: Node2D
var _cart: Node2D

var _running: bool = false
var _wave: int = 0
var _wave_size: int = 0
var _timer: float = 0.0
var _spawn_timer: float = 0.0
var _cap: int = 0
## Spawn points of the wave being placed, drained one per [member spawn_interval].
## A wave held at the ceiling keeps its unplaced points here rather than losing
## them, so a capped road delivers the same formation more slowly.
var _queue: Array[Vector2] = []
## The crossing's full length, measured once as the road opens, so progress is a
## share of the journey rather than of whatever is left of it.
var _crossing: float = 0.0
## Used when [member formations] is empty, so a road with no shapes authored on it
## still fights instead of standing empty.
var _fallback: TravelFormation


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_map = get_node_or_null(map_path) as TravelMap
	set_process(false)


## The road's waves, or null when nobody is travelling.
static func get_active(from_node: Node) -> TravelWaveDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelWaveDirector


## Starts the road fighting, through [param spawner] and [param scaling] - the
## world's own, handed over rather than looked up, because which spawner belongs
## to a road is the director's question and not this node's.
##
## Reports whether it actually started. A false answer means the road is quiet:
## either it was authored that way, or there is nothing to spawn through, and
## neither is worth an error - a crossing with no enemies on it is still a
## crossing.
func begin(spawner: EnemySpawner, scaling: RoundScaling = null) -> bool:
	if not enabled or spawner == null:
		return false

	_spawner = spawner
	_scaling = scaling
	_wave = 0
	_wave_size = 0
	_queue.clear()
	_timer = maxf(first_wave_delay, 0.0)
	_running = true
	set_process(true)

	# Measured now rather than per wave: the length of the crossing is a fact about
	# the road, and taking it live would make progress creep back up every time the
	# player walked the wrong way.
	_crossing = _map.get_crossing_distance() if _map != null else 0.0
	return true


## Stops the road forming waves and leaves everything already on it alone - the
## enemies keep chasing, exactly as [method WaveManager.stop] leaves an arena.
##
## Called when the player rides off and when they are killed, so nothing is still
## being placed on a road nobody is on.
func stop() -> void:
	_running = false
	_queue.clear()
	set_process(false)


func is_running() -> bool:
	return _running


func get_wave() -> int:
	return _wave


## How far across the road the player is, from 0 at the spawn to 1 at the cart.
##
## [b]Every difficulty number is a lerp on this.[/b] The road has no clock and no
## round, so "how hard is it right now" cannot be a time or a wave number - it is
## how close the player is to getting off, which is also the only measure that
## makes the last stretch the hardest however long they took over it.
func get_progress() -> float:
	if _crossing <= 0.0 or not _resolve_ends():
		return 0.0
	var left := _player.global_position.distance_to(_cart.global_position)
	return clampf(1.0 - left / _crossing, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _running or not _resolve_ends():
		return

	if not _queue.is_empty():
		_drain_queue(delta)
		return

	_timer -= delta
	if _timer > 0.0 and not _wave_broken():
		return
	if stop_distance > 0.0 \
			and _player.global_position.distance_to(_cart.global_position) <= stop_distance:
		return

	_build_wave()


## Lets the wave being placed out one at a time, and holds it at the ceiling
## rather than throwing away what is left of it.
func _drain_queue(delta: float) -> void:
	_spawn_timer -= delta
	while not _queue.is_empty() and _spawn_timer <= 0.0:
		if _cap > 0 and _living() >= _cap:
			return
		_spawner.spawn_at(_queue.pop_front())
		if spawn_interval > 0.0:
			_spawn_timer += spawn_interval

	if _queue.is_empty():
		_timer = _current_interval()


## Whether enough of the last wave has been killed to summon the next one early.
func _wave_broken() -> bool:
	if _wave_size <= 0:
		return true
	return _living() <= int(floor(float(_wave_size) * clear_fraction))


func _living() -> int:
	return get_tree().get_nodes_in_group(enemy_group).size()


# --- Building a wave -----------------------------------------------------------

## One interception: the main force across the route, plus whatever the flanks are
## worth, queued as plain points for [method _drain_queue] to let out.
func _build_wave() -> void:
	var progress := get_progress()
	_apply_difficulty(progress)

	_wave += 1
	_wave_size = _wave_enemy_count(progress)
	_spawn_timer = 0.0
	# The spacing memory is per burst, exactly as an arena wave uses it, so the
	# formation about to be placed is not measured against one long since walked off.
	_spawner.begin_batch()

	var forward := _route_direction()
	var width := formation_width * (1.0 + maxf(formation_width_scaling, 0.0) * progress)

	var side_total := _side_enemy_count(progress, _wave_size)
	var main_total := maxi(_wave_size - side_total, 1)

	_queue.clear()
	_build_interception(main_total, forward, width, progress)
	_build_flanks(side_total, forward, width, progress)

	wave_spawned.emit(_wave, _queue.size())


## The wall itself: several groups spread across the route, each in its own shape,
## all of them between the player and the cart.
func _build_interception(total: int, forward: Vector2, width: float, progress: float) -> void:
	var groups := _group_count(progress, total)
	var counts := _split(total, groups)
	var anchor := _interception_anchor(forward)
	var across := forward.orthogonal()

	for i in counts.size():
		# Centred on the route, so the wall straddles it rather than sitting to one
		# side of it however many groups it was broken into.
		var lateral := (float(i) - float(counts.size() - 1) * 0.5) * group_spacing
		var along := randf_range(-spawn_variance, spawn_variance)
		var centre := anchor + across * lateral + forward * along
		_place_group(counts[i], _pick_formation(), centre, forward, width, progress)


## The flanks. Each is a group of its own, coming in at an angle off the route -
## so going round the end of the wall is met rather than free - and each is
## anchored on the player rather than on the wall, because its whole purpose is
## the ground beside them.
func _build_flanks(total: int, forward: Vector2, width: float, progress: float) -> void:
	if total <= 0:
		return

	var groups := maxi(_side_group_count(progress), 1)
	var counts := _split(total, groups)
	# Alternated rather than rolled per group, so two flanks are never both on the
	# same side leaving the other wide open.
	var side := 1.0 if randf() < 0.5 else -1.0

	for i in counts.size():
		var angle := deg_to_rad(randf_range(side_angle_degrees.x, side_angle_degrees.y))
		var heading := forward.rotated(angle * side)
		var distance := side_spawn_distance + randf_range(-spawn_variance, spawn_variance)
		var centre := _player.global_position + heading * maxf(distance, 0.0)
		# Drawn across its own heading, so a flank is a line the player runs into
		# sideways rather than a column pointed at them.
		_place_group(counts[i], _pick_formation(), centre, heading, width * 0.6, progress)
		side = -side


## Turns one group's shape into world points, then holds every one of them to the
## road's rules before it is queued.
func _place_group(count: int, formation: TravelFormation, centre: Vector2,
		forward: Vector2, width: float, progress: float) -> void:
	if count <= 0:
		return

	var shape := formation if formation != null else _get_fallback()
	var across := forward.orthogonal()
	var view := _spawner.get_view_rect()
	var depth := formation_depth * (1.0 + maxf(formation_width_scaling, 0.0) * progress)

	for offset: Vector2 in shape.build_offsets(count, width, depth):
		var point := centre + across * offset.x + forward * offset.y
		_queue.append(_hold_to_rules(point, view))


## The four promises the road makes about where an enemy may appear, applied in
## order and then applied again: never on the player, never on the cart, never on
## screen, never outside the map.
##
## [b]Twice, because they pull against each other.[/b] Pushing a point off the
## screen can walk it back towards the cart, and pushing it off the cart can walk
## it back on screen - so one pass is not a fixed point. Two settles every case the
## road actually produces, and the map clamp is last because a spawn inside a wall
## is the one failure that cannot be lived with.
func _hold_to_rules(point: Vector2, view: Rect2) -> Vector2:
	var held := point
	for pass_index in 2:
		held = _push_from(held, _player.global_position, min_distance_from_player)
		held = _push_from(held, _cart.global_position, min_distance_from_horse)
		if require_off_screen:
			held = _push_off_screen(held, view)
	return _clamp_to_map(held)


## [param point] moved out to [param distance] from [param centre] if it was
## nearer than that, along the line it already sat on - so a formation squeezed by
## this opens outwards instead of collapsing to one spot.
func _push_from(point: Vector2, centre: Vector2, distance: float) -> Vector2:
	if distance <= 0.0:
		return point
	var offset := point - centre
	if offset.length_squared() >= distance * distance:
		return point
	var heading := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
	return centre + heading * distance


## [param point] moved out of the camera's view along the line from the middle of
## it, which is the shortest way out and the one that disturbs a formation least.
func _push_off_screen(point: Vector2, view: Rect2) -> Vector2:
	var box := view.grow(maxf(off_screen_margin, 0.0))
	if not box.has_point(point):
		return point

	var heading := point - box.get_center()
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	heading = heading.normalized()

	# How far along that line the edge is. Both are positive from inside the box,
	# and the nearer of the two is where it leaves.
	var travel := INF
	if absf(heading.x) > 0.0001:
		var edge_x := box.end.x if heading.x > 0.0 else box.position.x
		travel = minf(travel, (edge_x - point.x) / heading.x)
	if absf(heading.y) > 0.0001:
		var edge_y := box.end.y if heading.y > 0.0 else box.position.y
		travel = minf(travel, (edge_y - point.y) / heading.y)
	if travel == INF:
		return point

	return point + heading * (travel + 1.0)


func _clamp_to_map(point: Vector2) -> Vector2:
	if _map == null:
		return point
	var inner := _map.get_world_region().grow(-maxf(region_inset, 0.0))
	return point.clamp(inner.position, inner.end)


# --- The route -----------------------------------------------------------------

## The line the wave is built across: from where the player is about to be, to the
## cart.
##
## Re-read every wave and never remembered, which is the whole of "the road keeps
## intercepting". A player who turns aside has not escaped the pursuit; they have
## only moved where the next wall goes up.
func _route_direction() -> Vector2:
	var from := _player.global_position + _player_drift()
	var heading := from.direction_to(_cart.global_position)
	if heading.is_zero_approx():
		# Standing on the cart. Nothing sensible to aim at, so the wave is thrown
		# out at random rather than all landing on one point.
		return Vector2.RIGHT.rotated(randf() * TAU)
	return heading


## Where the player will have got to by the time the wave lands, from the movement
## they are actually making. Zero when the prediction is switched off or they are
## standing still.
func _player_drift() -> Vector2:
	if player_lead_time <= 0.0 or not "velocity" in _player:
		return Vector2.ZERO
	return (_player.velocity as Vector2) * player_lead_time


## The middle of the wall: down the route from the player, but never so far down it
## that it forms up on the cart's doorstep or behind it.
func _interception_anchor(forward: Vector2) -> Vector2:
	var from := _player.global_position + _player_drift()
	var to_cart := from.distance_to(_cart.global_position)
	var reach := spawn_distance + interception_offset

	# The gap actually available between the two of them. On the final approach
	# there may be none, and the wall is then built as close to the player as the
	# rules allow rather than on top of the waggon.
	var room := maxf(to_cart - min_distance_from_horse, min_distance_from_player)
	return from + forward * clampf(reach, min_distance_from_player, room)


# --- How much of everything ----------------------------------------------------

## Whether both ends of the route are known. Looked up lazily and re-looked-up
## when one goes away, because the road is instanced at runtime and the player can
## be carried off it.
func _resolve_ends() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	if _cart == null or not is_instance_valid(_cart):
		_cart = get_tree().get_first_node_in_group(cart_group) as Node2D
	return _player != null and _cart != null and _spawner != null


func _wave_enemy_count(progress: float) -> int:
	var raw := float(base_enemies_per_wave) * (1.0 + maxf(enemy_count_scaling, 0.0) * progress)
	return clampi(int(round(raw)), 1, maxi(max_enemies_per_wave, 1))


func _side_enemy_count(progress: float, total: int) -> int:
	if _side_group_count(progress) <= 0:
		return 0
	return int(floor(float(total) * clampf(side_group_share, 0.0, 0.9)))


func _side_group_count(progress: float) -> int:
	return maxi(int(round(lerpf(float(base_side_groups), float(max_side_groups), progress))), 0)


## How many bodies a wave of [param total] is broken into. Wanting more groups
## than the wave can fill gives fewer, fuller ones instead - a wave of six split
## four ways is a scatter, not four formations.
func _group_count(progress: float, total: int) -> int:
	var wanted := int(round(lerpf(float(base_group_count), float(max_group_count), progress)))
	var affordable := total / maxi(min_group_size, 1)
	return clampi(mini(wanted, affordable), 1, maxi(total, 1))


func _current_interval() -> float:
	return maxf(lerpf(wave_interval, min_wave_interval, get_progress()), 0.1)


## The road's difficulty, pushed onto the world's own curve as each wave forms.
##
## The spawn multiplier is deliberately put back to 1: how many enemies a travel
## wave is worth is decided here, so leaving the road's own count to be multiplied
## again by the arena's would count it twice.
func _apply_difficulty(progress: float) -> void:
	_cap = maxi(int(round(lerpf(
		float(max_active_enemies), float(max_active_enemies_at_arrival), progress))), 0)

	if _scaling == null:
		return
	_scaling.set_extra_multipliers(
		lerpf(enemy_health_multiplier, enemy_health_multiplier_at_arrival, progress),
		lerpf(enemy_damage_multiplier, enemy_damage_multiplier_at_arrival, progress),
		1.0)


## [param total] dealt out over [param groups], with the remainder going to the
## first ones - so the group the player meets first is never the thin one.
func _split(total: int, groups: int) -> PackedInt32Array:
	var counts := PackedInt32Array()
	var count := maxi(groups, 1)
	var base := total / count
	var spare := total % count
	for i in count:
		counts.append(base + (1 if i < spare else 0))
	return counts


## One shape, rolled against the weights in [member formations]. Null when there
## are none, which [method _place_group] reads as "use the plain line".
func _pick_formation() -> TravelFormation:
	var total := 0.0
	for shape: TravelFormation in formations:
		if shape != null:
			total += maxf(shape.weight, 0.0)
	if total <= 0.0:
		return null

	var roll := randf() * total
	for shape: TravelFormation in formations:
		if shape == null:
			continue
		roll -= maxf(shape.weight, 0.0)
		if roll <= 0.0:
			return shape
	return null


func _get_fallback() -> TravelFormation:
	if _fallback == null:
		_fallback = TravelFormation.new()
	return _fallback
