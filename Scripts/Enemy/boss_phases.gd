class_name BossPhases
extends Node
## How a mini boss fight changes as the boss is worn down: the support that keeps
## arriving while it is still strong, the moment that support dries up, and the boss
## turning on the player alone.
##
## [b]It is the boss's health that drives all of it.[/b] Nothing here is on a clock and
## nothing counts kills - the fight is read straight off the pool through
## [signal Health.health_changed], so a boss shot down fast reaches its last stand
## fast and one whittled at slowly gets its reinforcements for as long as it holds up.
## Which bands exist and what happens in each is an ordered list of [MiniBossPhase]
## resources; see [member phases]. There is no threshold in this file.
##
## The bands the game ships with are the brief's three:
##
##   [codeblock]
##   above 75%   groups of 2     ordinary speed
##   75% - 50%   groups of 3     ordinary speed
##   below 50%   nobody          +20% speed, washed red
##   [/codeblock]
##
## [b]A band once left is never returned to.[/b] Only a band further down the list is
## ever entered - see [method _apply_phase_for] - which is what makes the support
## stopping permanent and the enrage permanent, without either being a special case. A
## boss healed back above half would stay enraged and stay alone, which is right: the
## fight has already changed.
##
## [b]This is not the arena's [WaveManager] and does not touch it.[/b] A round's waves
## are paced against a minute-long clock and ramp with the round number; this is paced
## against one man's health and ramps [i]down[/i]. The round's manager is never started
## on a boss day at all - see [method WorldBoot._boss_takes_the_round] - so the two
## cannot interfere, and nothing about ordinary waves is read or written here.
##
## [b]Nothing about an enemy is written here either.[/b] The reinforcements are the
## game's ordinary [code]Enemy.tscn[/code], built by the world's own [EnemySpawner] -
## which hands each one its chase target and the round's difficulty on the way in -
## exactly as the boss and its first ten were. All this decides is how many, how often
## and from which side.
##
## [b]They walk in from outside the picture.[/b] The fixed screen is fenced, so a body
## put down outside it would be stuck against the wall; each arrival is handed to
## [method BossArena.admit], which excepts the fence for that one body until it is
## properly inside and then closes it behind them. That is the whole of "enemies may
## enter from just outside the visible screen and move inward, and cannot permanently
## leave".

## Emitted as the fight enters a band, with the band and its place in the list.
signal phase_entered(phase: MiniBossPhase, index: int)
## Emitted for each reinforcement put on the field.
signal support_spawned(enemy: Node2D)
## Emitted when the last band that sends anybody is left behind - the fight is one on
## one from here.
signal support_finished

## Group this node joins, so a test or a readout can find it without a path.
const GROUP := &"boss_phases"

## The boss system whose fight this follows. Its [signal MiniBossDirector.fight_started]
## is the only thing that starts this node, so nothing here can run in a round that has
## no boss in it.
@export var director_path: NodePath = ^"../MiniBossDirector"
## The fixed screen. Its rectangle is where reinforcements come in around, and its
## fence is what they are let through. Left unresolved they arrive at the spawner's
## ordinary off-screen edge instead, so a fight without a fixed screen still gets its
## support.
@export var arena_path: NodePath = ^"../BossArena"
## The world's own spawner, which builds every reinforcement. [b]There is no boss-wave
## enemy[/b] - they are the game's ordinary enemies, made by the thing that already
## makes them.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## Group the player is found in, so this node is not wired to them.
@export var player_group: StringName = &"player"
## Group every living enemy joins, counted when there is a ceiling to enforce.
@export var enemy_group: StringName = &"enemies"

@export_group("The fight")
## The bands, [b]highest health first[/b]. The first one whose
## [method MiniBossPhase.covers] answers for the boss's current health is the one in
## force, so the order in this list is the order of the fight.
##
## An empty list leaves the fight exactly as it starts - the ten who were already there
## and nothing else - rather than guessing at a shape for it.
@export var phases: Array[MiniBossPhase] = []
## Most enemies allowed alive in the arena at once, the boss included. 0 is no ceiling.
##
## [b]This is what keeps the arena from being flooded.[/b] The bands deliver a small
## group often, which is relentless but finite only if something holds the total down -
## a fight the player is losing ground in would otherwise accumulate men for as long as
## it lasted. A group held back is not thrown away: it goes out on the next check that
## has room for it.
@export var max_support_alive: int = 18
## What a reinforcement's health pool is multiplied by. 0 - the default - takes the
## same multiplier the boss's first ten were built with from
## [member MiniBossDirector.support_health_multiplier], so reinforcements are exactly
## as tough as the men already standing there and there is only ever one number to
## tune.
@export var support_health_multiplier: float = 0.0

@export_group("Where they come in")
## How far outside the visible arena a reinforcement is put down, in pixels. Enough
## that nothing is seen appearing, little enough that it is walking into the fight
## within a second or two.
@export var entry_margin: float = 140.0
## How far inside the map's own rectangle an arrival is held, so nothing is placed
## embedded in a wall.
@export var region_inset: float = 80.0
## How many sides are tried before the best is accepted. Only matters for an arena
## pushed up against the edge of the map, where one or two sides have no room outside
## them.
@export var entry_attempts: int = 8

var _director: MiniBossDirector
var _arena: BossArena
var _spawner: EnemySpawner
var _boss: Node2D
var _boss_health: Health
## The speed the boss started the fight at, so every band's multiplier is measured
## against the same number instead of compounding on the band before it.
var _boss_base_speed: float = 0.0
## Which band is in force, as a place in [member phases]. -1 before the fight starts.
var _phase_index: int = -1
var _phase: MiniBossPhase
## Whether the support is over for good, which is true from the first band that sends
## nobody.
var _finished: bool = false
var _running: bool = false
## Seconds until the next group is due.
var _group_timer: float = 0.0
## How many of the group currently arriving have still to be put down, and the gap
## before the next of them. A group is delivered one man at a time so it walks in
## rather than appearing.
var _pending: int = 0
var _stagger_timer: float = 0.0
var _player: Node2D
## The player's own pool, followed only while a fight is running - see
## [method _on_player_died].
var _player_health: Health


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_process(false)
	var director := _resolve_director()
	if director != null and not director.fight_started.is_connected(_on_fight_started):
		director.fight_started.connect(_on_fight_started)


## The phase system in this world, or null when it has none.
static func get_active(from_node: Node) -> BossPhases:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BossPhases


func is_running() -> bool:
	return _running


## The band in force, or null before the fight starts.
func get_phase() -> MiniBossPhase:
	return _phase


func get_phase_index() -> int:
	return _phase_index


## Whether the support has stopped for good.
func is_support_finished() -> bool:
	return _finished


## What fraction of its health the boss has left, or 0 when there is no boss.
func get_boss_fraction() -> float:
	if _boss_health == null or not is_instance_valid(_boss_health):
		return 0.0
	var ceiling := _boss_health.get_max()
	return 0.0 if ceiling <= 0.0 else clampf(_boss_health.get_current() / ceiling, 0.0, 1.0)


## The band [param fraction] of the boss's health falls into.
##
## [b]The list is read in order and the first claim wins[/b], so bands are authored
## highest first and each one only has to say where it stops. Anything no band claims -
## a boss on its last sliver of health, under a table whose bottom entry stops above 0 -
## is given the last band rather than none, which is what makes the bottom of the table
## a catch-all without it having to be authored as one.
func find_phase(fraction: float) -> int:
	for index: int in range(phases.size()):
		var phase := phases[index]
		if phase != null and phase.covers(fraction):
			return index
	return phases.size() - 1


# --- The fight -----------------------------------------------------------------

## The introduction is over and the arena is locked. From here the boss's health is
## what runs the fight.
func _on_fight_started() -> void:
	if _running or phases.is_empty():
		return

	var director := _resolve_director()
	if director == null:
		return

	_boss = director.get_boss()
	if _boss == null or not is_instance_valid(_boss):
		return

	_boss_base_speed = float(_boss.speed) if "speed" in _boss else 0.0
	_boss_health = _find_health(_boss)
	if _boss_health != null and not _boss_health.health_changed.is_connected(_on_boss_health_changed):
		_boss_health.health_changed.connect(_on_boss_health_changed)

	_running = true
	_finished = false
	_phase_index = -1
	_follow_player_death()
	# The band is entered before the first frame runs, so a boss that somehow starts
	# the fight already below half is enraged and alone from the outset rather than
	# after one group has been sent.
	_apply_phase_for(get_boss_fraction())
	set_process(true)


## Stops the support arriving and leaves everything already on the field alone,
## exactly as [method WaveManager.stop] and [method AmbushWaveDirector.stop] do. The
## band the boss is in, its speed and its colour are all left as they are - this stops
## the spawning, it does not undo the fight.
func stop() -> void:
	if not _running:
		return
	_running = false
	_pending = 0
	_drop_player_death()
	set_process(false)


## Puts the fight back to before it started: the support stopped, the band forgotten and
## the boss let go of.
##
## [b]Nothing in play calls it[/b] - a fight is over when the man is on the ground - but
## a fight that can be set up again has to be able to forget the one before it, or the
## next boss would be watched through the pool of a body that no longer exists. What is
## already standing in the arena is left exactly where it is; this forgets a fight, it
## does not clear one.
func reset() -> void:
	stop()

	if _boss_health != null and is_instance_valid(_boss_health) \
			and _boss_health.health_changed.is_connected(_on_boss_health_changed):
		_boss_health.health_changed.disconnect(_on_boss_health_changed)

	_boss = null
	_boss_health = null
	_boss_base_speed = 0.0
	_phase_index = -1
	_phase = null
	_finished = false
	_group_timer = 0.0
	_stagger_timer = 0.0
	_pending = 0
	_drop_player_death()


## Sends [param count] reinforcements in now, whatever the band is doing, and reports how
## many actually arrived.
##
## [b]It is a band's own group, asked for by hand.[/b] Each man goes through
## [method _spawn_one] exactly as a timed one does - built by the world's spawner, put
## down outside the picture, let in through the fence and counted with the men already
## standing - so what this exercises is the real arrival rather than a copy of it.
## Nothing in play calls it; it is what the developer panel's support-wave buttons press.
func spawn_support_group(count: int) -> int:
	var sent := 0
	for index: int in range(maxi(count, 0)):
		if _spawn_one() != null:
			sent += 1
	return sent


func _process(delta: float) -> void:
	if not _running:
		return
	# A boss that has gone - killed, or a world torn down around the fight - takes the
	# support with it. There is nothing left for reinforcements to be reinforcing.
	if _boss == null or not is_instance_valid(_boss):
		stop()
		return
	if _finished or _phase == null:
		return

	# A group already arriving is delivered before the next one is due, so the two
	# timers can never interleave into a single simultaneous pop.
	if _pending > 0:
		_advance_group(delta)
		return

	_group_timer -= delta
	if _group_timer > 0.0:
		return
	if _crowded():
		# Held rather than dropped: the group is still due and goes out on the first
		# check that has room for it.
		return

	_pending = maxi(_phase.group_size, 0)
	_stagger_timer = 0.0
	_group_timer = maxf(_phase.group_interval, 0.05)


## One man of the group currently arriving, every [member MiniBossPhase.spawn_spacing]
## seconds.
func _advance_group(delta: float) -> void:
	_stagger_timer -= delta
	if _stagger_timer > 0.0:
		return

	if _crowded():
		# The rest of the group waits for room rather than being abandoned, so a
		# ceiling slows the support down instead of thinning it out.
		_stagger_timer = maxf(_phase.spawn_spacing, 0.02)
		return

	_spawn_one()
	_pending -= 1
	_stagger_timer = maxf(_phase.spawn_spacing, 0.02)


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if not _running:
		return
	var fraction := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_apply_phase_for(fraction)


## Moves the fight into whichever band [param fraction] falls in.
##
## [b]Only ever forwards.[/b] A band earlier in the list than the one in force is
## refused, which is what makes both of the permanent things permanent - the support
## cannot come back and the enrage cannot be lifted - without either of them being
## written as a special case here or flagged on the resource.
func _apply_phase_for(fraction: float) -> void:
	var index := find_phase(fraction)
	if index < 0 or index >= phases.size() or index <= _phase_index:
		return

	var phase := phases[index]
	if phase == null:
		return

	_phase_index = index
	_phase = phase
	_apply_to_boss(phase)

	if not phase.sends_support():
		_pending = 0
		if not _finished:
			_finished = true
			support_finished.emit()
	else:
		# The first group of a band is one interval away, not immediate: entering a band
		# should not itself be a spawn, or crossing a threshold would land men on the
		# player at the same instant their support was already due.
		_group_timer = maxf(phase.group_interval, 0.05)

	phase_entered.emit(phase, index)


## What a band does to the boss itself: how fast it walks, and what colour it is.
##
## Both are re-applied from the band rather than adjusted, so they are absolute - see
## [member MiniBossPhase.speed_multiplier]. The colour goes through
## [method MiniBoss.apply_tint], which writes a uniform the outline and the hit flash
## do not share, so an enraged boss keeps its red edge and still flashes when it is
## hit.
func _apply_to_boss(phase: MiniBossPhase) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return

	if "speed" in _boss and _boss_base_speed > 0.0:
		_boss.speed = _boss_base_speed * maxf(phase.speed_multiplier, 0.01)

	var component := MiniBoss.find_on(_boss)
	if component != null:
		component.apply_tint(phase.tint_strength, phase.tint_color)


# --- Putting them in -----------------------------------------------------------

## One reinforcement: an ordinary enemy, built by the ordinary spawner, put down just
## outside the picture and let in through the fence. Returns the body, or null when
## there was no spawner to build one with.
func _spawn_one() -> Node2D:
	var spawner := _resolve_spawner()
	if spawner == null:
		return null

	var enemy := spawner.spawn_at(_entry_point(spawner))
	if enemy == null:
		return null

	var health := _find_health(enemy)
	if health != null:
		var multiplier := _support_health_multiplier()
		if not is_equal_approx(multiplier, 1.0):
			health.set_max_health(health.max_health * maxf(multiplier, 0.01), true)

	# Let through the fence, then held by it like everybody else once inside. An arena
	# that is not locked has no fence and refuses, which is not a failure.
	var arena := _resolve_arena()
	var body := enemy as PhysicsBody2D
	if arena != null and body != null:
		arena.admit(body)

	# Counted with the men who were already standing there, so anything reading the
	# support - a readout, a test, whatever ends the fight later - sees one group.
	var director := _resolve_director()
	if director != null:
		director.register_support(enemy)

	support_spawned.emit(enemy)
	return enemy


## What a reinforcement's pool is multiplied by: this node's own number, or the
## director's when it has been left at 0.
func _support_health_multiplier() -> float:
	if support_health_multiplier > 0.0:
		return support_health_multiplier
	var director := _resolve_director()
	return 1.0 if director == null else maxf(director.support_health_multiplier, 0.01)


## Where one arrival comes in: on the perimeter of the arena, [member entry_margin]
## outside it, and never outside the map.
##
## [b]It places its own points rather than using the spawner's edge picker[/b], for the
## same reason [AmbushWaveDirector] does. [method EnemySpawner.pick_spawn_position]
## spreads along the whole length of an arena wall, which for the boss fight means the
## full five thousand pixels of the map's height - so a man meant to walk in from the
## left of a screen-sized arena could be placed two thousand pixels above it and spend
## the rest of the fight walking. Measured from the arena's own rectangle instead, every
## arrival is a screen edge away from the fight.
##
## Sides are tried until one lands genuinely outside the picture, because an arena near
## the edge of the map has sides whose margin the map clamp would eat - and being seen
## appearing is the one failure worth retrying to avoid. An arena with no rectangle at
## all falls back to the spawner's own off-screen point, so a fight without a fixed
## screen still gets its support.
func _entry_point(spawner: EnemySpawner) -> Vector2:
	var area := _arena_area()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return spawner.pick_spawn_position()

	var ring := area.grow(maxf(entry_margin, 0.0))
	var best := _held_in_map(spawner, ring.get_center())
	var best_clearance := -INF

	for attempt: int in range(maxi(entry_attempts, 1)):
		var point := _held_in_map(spawner, _point_on_ring(ring))
		var clearance := _clearance_from(point, area)
		if clearance > 0.0:
			return point
		if clearance > best_clearance:
			best_clearance = clearance
			best = point

	return best


## A random point on one of the four sides of [param ring].
func _point_on_ring(ring: Rect2) -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf_range(ring.position.x, ring.end.x), ring.position.y)
		1:
			return Vector2(randf_range(ring.position.x, ring.end.x), ring.end.y)
		2:
			return Vector2(ring.position.x, randf_range(ring.position.y, ring.end.y))
		_:
			return Vector2(ring.end.x, randf_range(ring.position.y, ring.end.y))


func _held_in_map(spawner: EnemySpawner, point: Vector2) -> Vector2:
	var inner := spawner.arena_bounds.grow(-maxf(region_inset, 0.0))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return point
	return point.clamp(inner.position, inner.end)


## How far outside [param box] a point sits. Negative means it is inside, which is what
## [method _entry_point] ranks its attempts on.
func _clearance_from(point: Vector2, box: Rect2) -> float:
	var out_x := maxf(box.position.x - point.x, point.x - box.end.x)
	var out_y := maxf(box.position.y - point.y, point.y - box.end.y)
	return maxf(out_x, out_y)


func _arena_area() -> Rect2:
	var arena := _resolve_arena()
	return Rect2() if arena == null else arena.get_area()


func _crowded() -> bool:
	if max_support_alive <= 0:
		return false
	return get_tree().get_nodes_in_group(enemy_group).size() >= max_support_alive


# --- The player going down -----------------------------------------------------

## [b]Nothing more arrives once the player is down.[/b] Their death carries them home
## to the base, several thousand pixels from the arena - a fight still counting down its
## interval would go on putting men round a rectangle nobody is standing in. So the
## support is stopped the moment they fall, exactly as an ambush's is.
##
## What is already on the field is left alone. Ending the encounter is not this node's
## to do.
func _on_player_died() -> void:
	stop()


func _follow_player_death() -> void:
	_drop_player_death()
	var player := _resolve_player()
	if player == null:
		return
	_player_health = _find_health(player)
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their death -
## they are revived into the same [Health] - so a connection left behind would still be
## listening at the next boss fight.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


# --- Looking things up ---------------------------------------------------------

func _resolve_director() -> MiniBossDirector:
	if _director == null or not is_instance_valid(_director):
		var named := get_node_or_null(director_path) as MiniBossDirector
		_director = named if named != null else MiniBossDirector.get_active(self)
	return _director


func _resolve_arena() -> BossArena:
	if _arena == null or not is_instance_valid(_arena):
		var named := get_node_or_null(arena_path) as BossArena
		_arena = named if named != null else BossArena.get_active(self)
	return _arena


func _resolve_spawner() -> EnemySpawner:
	if _spawner == null or not is_instance_valid(_spawner):
		_spawner = get_node_or_null(spawner_path) as EnemySpawner
	return _spawner


func _resolve_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	return _player


func _find_health(body: Node) -> Health:
	if body == null:
		return null
	for node: Node in body.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null
