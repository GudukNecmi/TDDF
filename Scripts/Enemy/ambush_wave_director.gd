class_name AmbushWaveDirector
extends Node
## The fight that is already happening: a short, dense ambush on the road, with
## the first of them standing in front of the player before the screen has
## finished clearing.
##
## [b]Why this is not the arena's [WaveManager].[/b] A round is a minute long and
## opens quiet - the first wave is two enemies walking in from off screen, and
## everything about it is paced against a clock that has to last sixty seconds. An
## ambush is the opposite shape: it is over in about twenty, nothing about it
## ramps, and being jumped means there are already men in front of you rather than
## men on their way. Driving one out of the other would mean bending every number
## the round is tuned on, so the round's manager is untouched and still owns every
## round; this owns ambushes, and only ambushes.
##
## What it does is two things in order:
##
##   [codeblock]
##   OPENING GROUP (visible, medium range)  ->  GROUPS, every second or so
##   [/codeblock]
##
##   * [b]The opening.[/b] [member opening_count] enemies placed [i]on screen[/i],
##     [member opening_distance] away from the player - see
##     [method _opening_point], which holds every point inside the view rather than
##     pushing it out of one. That is the whole difference between an ambush and a
##     wave: the player is not waiting for anything to arrive.
##   * [b]The rest.[/b] Whatever the region is worth, released in groups every
##     [member group_interval] across [member spawn_window], each group arriving
##     just past the edge of the view - so nothing is seen appearing and everything
##     that appears is on top of the player within seconds. The gap is deliberately
##     about a second: there is no between-waves lull here, because a lull is what a
##     round has and an ambush does not.
##
## [b]It places its own arrivals rather than using the spawner's edge picker.[/b]
## [method EnemySpawner.pick_spawn_position] spreads along the whole length of an
## arena wall, which is right for a minute-long round in an eight-thousand-pixel
## desert and wrong for this: an enemy put out three thousand pixels up the map
## walks for half a minute and arrives after the ambush is over. So the distance is
## measured from the player instead - see [method _arrival_point] - and the
## spawner is asked only to build the body, which is the part that must not be
## duplicated. Nothing about how an arena round spawns is touched.
##
## [b]Nothing about an enemy is written here.[/b] The bodies are the world's own,
## built by the world's own [EnemySpawner] - which hands each one the chase target
## and the round's difficulty on the way in - so an ambush is fought against
## ordinary enemies with ordinary AI, and there is no second enemy, no second AI
## and no second difficulty curve. All this decides is [i]how many[/i], [i]where[/i]
## and [i]how fast[/i].
##
## [b]How many is the region's answer, not this file's.[/b] The count is read
## between [member entry_enemy_count] and [member deepest_enemy_count] against
## [method MapRegion.get_difficulty], so the desert's way in is a fifteen-man
## ambush, its deepest corner is a fifty-man one, and a sixth region - or a whole
## second map - is a number on a [code].tres[/code] file rather than a threshold
## here. Nothing in this script names a region or counts them.
##
## [b]A caller that has worked out its own size says so instead.[/b] See
## [method begin_with], which is the whole of the ambush with the count, the
## opening group and the breaking point handed to it - what [DangerDirector] uses
## to run a Trouble encounter, whose size comes from the Danger number as well as
## from the region. [method begin] is that call with the region's own answer, so
## there is one ambush and two ways of asking for it rather than two ambushes.
##
## It ends exactly once, when the last of the enemies it put out is off the field,
## and says so through [signal cleared]. What happens then is the caller's: the
## black comes back and the journey carries on from the next day, or the player is
## asked whether they want more of it.
##
## [b]Not every ambush is fought to the last man.[/b] Where a breaking point is
## asked for - [member rout_fraction], off by default - killing enough of them
## makes the rest give up: nothing more is put out and everybody still standing
## turns and runs through the retreat they already carry. See
## [method _rout_the_rest]. An ambush that has broken still ends the same way and
## through the same signal, once the last of the runners is off the field, so
## nothing downstream has to know whether the fight was won or merely survived.

## Emitted as an ambush opens, with how many enemies it is worth in total.
signal began(enemy_count: int)
## Emitted when enough of an ambush has been killed for the rest to break, with
## how many were still standing when they turned. The ambush is not over yet -
## they still have to get away.
signal routed(remaining: int)
## Emitted when the last enemy of the ambush is off the field and there are none
## left to come. [b]The only thing that ends an ambush.[/b]
signal cleared()

## Group the director joins, so anything can find it without a path.
const GROUP := &"ambush_director"

## The world's spawner, which builds every enemy an ambush puts on the road.
## [b]There is no ambush enemy[/b] - they are the game's ordinary enemies, made by
## the thing that already makes them.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## Group the player is found in, so the opening can be placed around them without
## this node being wired to them.
## The mix this director fills an ambush with, as opposed to how large it is.
##
## [b]It is the arena's own [WaveRoster], not a second one.[/b] What a wave is made
## of is a question the game already answers - one [WaveRosterEntry] per type, each
## carrying the wave it first appears on and how quickly its share grows - so a
## Trouble encounter is filled by dropping that same resource in here rather than by
## this file knowing there is such a thing as a bomber. Left unresolved, every body
## is the spawner's own enemy and an ambush is exactly the fight it was before.
##
## The wave number the roster is asked against is [method begin_with]'s, which for a
## Trouble encounter is the Danger number - so "from Danger 3" is
## [member WaveRosterEntry.first_wave] on a resource and not a threshold here. An
## ambush on the road never says which wave it is and so is always wave one, which
## is what keeps the roster out of the ordinary desert.
@export var roster_path: NodePath = ^"WaveRoster"

@export var player_group: StringName = &"player"
## Group every living enemy joins, counted when there is a ceiling to enforce.
@export var enemy_group: StringName = &"enemies"
## Whether a man who gives up stops being counted as somebody left to fight.
##
## [b]On, and the ambush cannot end without it.[/b] What takes an enemy off
## [member _alive] is his [signal Health.died], and a man who has given up has not
## died - he is face down on the floor with a full pool, waiting to be talked to.
## Left counted, he holds [method _check_cleared] open for good: the search never
## reports the Danger cleared, [DangerFinale] never plays the last man out, and the
## only way past him is for the player to walk over and shoot somebody who had
## already surrendered. He stopped being an opponent the moment he went down -
## [EnemySurrender] takes him out of [member enemy_group] and out of the enemy
## container in the same breath - so he is counted out here for the same reason and
## at the same moment.
##
## He is [i]not[/i] removed, hurried or altered in any way: the speech bubble, the E,
## the four seconds and the run away are all still his to play out. He simply stops
## being one of the men the fight is waiting on.
@export var surrender_ends_the_fight: bool = true
## Whether a man who gives up counts towards [member rout_fraction] as one the player
## beat.
##
## Off, and deliberately: the breaking point measures how much of the ambush was
## actually put down, and a broken nerve gets the same reading a runner gets - see
## [method _on_enemy_gone]. On makes fields break sooner.
@export var surrender_counts_as_beaten: bool = false
## Whether the men on the floor hold the encounter open until each of them has
## finished one way or the other.
##
## [b]On, and it is the difference between "nobody is fighting" and "it is over".[/b]
## A man who gives up stops being an opponent immediately - see
## [member surrender_ends_the_fight] - and for a while that was also treated as him
## being finished with, so the last surrender in a fight closed the encounter and put
## the next-round question on screen while he was still lying in the sand waiting to
## be talked to. He is unresolved rather than gone: he resolves by getting to his feet
## and making it off the screen, or by being shot, and either way the ending waits for
## it - see [method _leave_the_floor], which is where both of those arrive.
##
## The player is never made to shoot him. He gets up by himself - see
## [member EnemySurrender.stand_after_alone] - so waiting on him is bounded by his own
## timings, and none of them are touched here.
##
## Off ends the encounter on the attackers alone, which is what it did before.
@export var downed_hold_the_fight: bool = true

@export_group("How many")
## Enemies in an ambush at a region of danger 0 - a map's way in, the desert's A.
## The roll adds up to [member enemy_count_spread] on top, so this is the bottom
## of the range rather than the whole of it.
@export var entry_enemy_count: int = 15
## Enemies in an ambush at a region of danger 1 - a map's deadliest corner.
@export var deepest_enemy_count: int = 45
## How much an ambush of the same danger varies from one to the next. 5 on a
## fifteen-man ambush is "fifteen to twenty".
@export var enemy_count_spread: int = 5

@export_group("The opening")
## How many are standing there when the screen clears, as a range rolled between.
##
## [b]This is what makes it an ambush.[/b] They are placed in view rather than
## outside it, so the fight is already under way on the first frame the player can
## see - there is nothing to wait for and nowhere the danger is coming from.
@export var opening_count := Vector2i(2, 5)
## How far from the player the opening stands, in pixels, as a range. Medium
## range on purpose: close enough to read as an ambush, far enough that the player
## is not knifed before they have their bearings.
@export var opening_distance := Vector2(460.0, 700.0)
## Clear gap left between an opening spawn and the edge of the view, in pixels, so
## nobody is placed half off the screen they are supposed to be seen on.
@export var opening_screen_margin: float = 110.0
## How far inside the map's own rectangle a spawn is kept, so nothing is placed
## embedded in a wall.
@export var region_inset: float = 120.0

@export_group("Arrivals")
## How far from the player everything after the opening arrives, in pixels, as a
## range.
##
## [b]Measured from the player, not from the map.[/b] Just past the edge of the
## view is close enough that a man put out here is on the player within a few
## seconds, which is what keeps an ambush relentless in an arena wide enough to
## walk across for half a minute. Anything landing on screen is pushed back out -
## see [method _arrival_point] - so this is a floor rather than a promise.
@export var arrival_distance := Vector2(720.0, 980.0)
## Clear gap left between the edge of the view and an arrival, in pixels. What
## guarantees nobody is watched walking into existence.
@export var arrival_screen_margin: float = 80.0
## How many angles are tried before the roomiest one is accepted. Only matters near
## a wall, where most directions would put a spawn outside the map.
@export var arrival_attempts: int = 8

@export_group("Pacing")
## How long the ambush keeps putting enemies out for, in seconds. Everything the
## region is worth is delivered inside this, so an ambush is over in about this
## long plus however long the last of them takes to kill.
@export var spawn_window: float = 22.0
## Seconds between one group and the next. [b]Deliberately about a second[/b] -
## there is no between-waves gap in an ambush, and new bodies are meant to arrive
## while the last ones are still being dealt with.
@export var group_interval: float = 1.1
## Fewest enemies worth releasing at once.
##
## 1, so that a small ambush is spread across the whole of
## [member spawn_window] rather than being emptied out in half of it - at a group
## every second or so, one at a time is still constant pressure. Raising it makes
## small ambushes arrive faster and end sooner.
@export var min_group_size: int = 1
## Most enemies allowed alive at once. [b]0 - the default - is no ceiling[/b],
## which is what "fast and dense" wants: an ambush is short enough that the crowd
## cannot outrun the player.
##
## A positive value holds the rest back rather than throwing them away, so a capped
## ambush delivers the same enemies more slowly and still ends only when the last
## of them is down.
@export var max_active_enemies: int = 0

@export_group("Breaking")
## How much of an ambush has to be killed before the rest give up and run for it,
## as a fraction of what it was worth in total. 0.75 is "three of every four".
##
## [b]0 - the default - is off[/b], and off is what the road's ambushes are: a
## fight on the way somewhere is fought to the last man, exactly as it always has
## been. It is turned on per encounter rather than in the inspector by whatever
## wants it - see [method begin_with] - so a Trouble Danger can break at
## three-quarters without every ambush in the game changing shape.
##
## What "the rest" then do is not invented here: each of them is asked to play the
## retreat it already carries - see [EnemyEscape] - so a man who has had enough
## throws his knife down and runs by exactly the beat that ends a round.
@export_range(0.0, 1.0, 0.01) var rout_fraction: float = 0.0
## Gap between one man breaking and the next, in seconds, so a field that gives up
## does so as a ripple rather than as one synchronised turn.
@export var rout_stagger: float = 0.07
## Ceiling on the total spread, however many are still standing. Without it a
## packed field would take an unreasonable time to turn at a fixed gap.
@export var rout_max_spread: float = 1.2

var _spawner: EnemySpawner
var _roster: WaveRoster
## One entry per body this ambush is worth, in the order they will be built - the
## roster's answer, kept rather than re-rolled, so the mix an encounter was
## promised is the mix it actually gets however the men end up being released. A
## null is the spawner's own enemy, which is what most of them are.
var _plan: Array[PackedScene] = []
var _running: bool = false
## How many of the ambush have still to be put out.
var _owed: int = 0
## How many of the ones already put out are still standing. The ambush is over when
## this reaches zero with nothing left owed, which is the only thing that ends it.
var _alive: int = 0
## How many the ambush was worth in total, and how many of them the player has
## actually killed - the two numbers the breaking point is measured between.
var _total: int = 0
var _killed: int = 0
## The breaking point this ambush is being fought under, taken once as it opens so
## a caller's answer cannot change under a fight already happening.
var _rout: float = 0.0
var _routing: bool = false
## Everybody this ambush put out who is still on the field, kept so they can be
## sent home in one pass when the rest break. Entries come off it as each of them
## goes, which is also what stops one man being counted out twice.
var _standing: Array[Node2D] = []
## Everybody this ambush put out who has given up and is still on the floor. They
## are off [member _alive] - they are nobody's opponent any more - but they are
## still this encounter's men until they run or are killed. See
## [method get_enemies_downed].
var _downed: Array[Node2D] = []
## How many go out per release, worked out once as the ambush opens so the whole of
## it lands inside [member spawn_window].
var _group_size: int = 1
var _timer: float = 0.0
var _player: Node2D
## The player's own pool, followed only for as long as an ambush is running - see
## [method _on_player_died].
var _player_health: Health


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_process(false)


## The ambush system this world fights through, or null when it has none - which
## [TravelDirector] reads as "an ambush here is an ordinary handful of enemies"
## and falls back to its own spawning.
static func get_active(from_node: Node) -> AmbushWaveDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as AmbushWaveDirector


func is_running() -> bool:
	return _running


## How many are still to come, for a readout or a test.
func get_enemies_owed() -> int:
	return _owed


## How many of this ambush are still standing - [b]the active attackers[/b], and
## the only number the ambush's own ending is measured on.
##
## A man who has given up is not one of them. See [method get_enemies_downed] for
## the men who are on the floor, and [method get_encounter_count] for the two
## together.
func get_enemies_alive() -> int:
	return _alive


## How many of this ambush are lying on the floor having given up.
##
## [b]They are not attackers and they are not gone.[/b] That distinction is the
## whole reason this is a second number rather than a flag on the first: a man who
## has surrendered stops being somebody to fight the instant he goes down - which
## is what lets the fight end over the top of him - but he is still one of the men
## this encounter put on the field, and he stays one until he gets to his feet and
## runs or somebody shoots him.
##
## Nothing is gated on this today. [method _check_cleared] deliberately still ends
## the ambush on the attackers alone, so a man on the floor can never hold a fight
## open; this is here for whatever decides the encounter's final word on him.
func get_enemies_downed() -> int:
	return _downed.size()


## Everybody this encounter still has on the field in any state: the men still
## fighting and the men on the floor.
func get_encounter_count() -> int:
	return _alive + _downed.size()


## How many the ambush being fought was worth in total, for a readout or a test.
func get_enemy_total() -> int:
	return _total


## How many of them the player has actually killed. What the breaking point is
## measured against - see [member rout_fraction] - so a man who ran off rather than
## going down is not counted here.
func get_enemies_killed() -> int:
	return _killed


## Whether the rest have already given up and are running.
func is_routing() -> bool:
	return _routing


## Whether an ambush could be run at all: something to build enemies with, and a
## size worth building. Asked [i]before[/i] the world is handed back, so a director
## that cannot fight is never the reason a journey is left staring at a fade with
## nothing in front of it.
func can_begin() -> bool:
	if _running:
		return false
	return _resolve_spawner() != null and maxi(entry_enemy_count, deepest_enemy_count) > 0


## How many enemies an ambush in [param region] is worth: read between
## [member entry_enemy_count] and [member deepest_enemy_count] against that
## region's own danger, with up to [member enemy_count_spread] rolled on top.
##
## A null region - a map that has not been divided up, or a journey with nowhere
## named at the end of it - is read as danger 0 rather than as an error, so the
## quietest ambush is what an unknown road produces.
func get_enemy_count_for(region: MapRegion) -> int:
	var danger := 0.0 if region == null else region.get_difficulty()
	var size := lerpf(float(entry_enemy_count), float(deepest_enemy_count), danger)
	return maxi(int(round(size)) + randi() % maxi(enemy_count_spread + 1, 1), 1)


## Opens an ambush in [param region] and reports how many enemies it is worth.
##
## [b]The opening group is placed on this call[/b], not on the next frame, so by
## the time the screen has finished clearing there are already men in front of the
## player. Zero means nothing happened and nothing was changed - no spawner, or a
## size of nothing - which the caller reads as "there is no ambush to fight".
func begin(region: MapRegion) -> int:
	return begin_with(get_enemy_count_for(region))


## The same ambush, with its size decided by the caller rather than by a region.
##
## [b]This is the whole of it and [method begin] is a wrapper round it[/b], so an
## ambush asked for by hand is the same fight the road deals itself - same opening
## in view, same groups arriving just off the screen, same ending - and there is no
## second ambush anywhere in the project.
##
## [param total] is how many enemies it is worth altogether. [param opening] is how
## many of them are already standing in view when it opens; below zero rolls
## [member opening_count] as usual, which is what [method begin] leaves it at.
## [param rout_at] is the fraction of the total that has to be killed before the rest
## break and run - see [member rout_fraction] - and below zero uses the authored
## value, so a caller that says nothing about breaking gets whatever this world's
## ambushes are set to.
##
## [param wave_number] is which wave of the fight this is, for the roster - see
## [member roster_path]. For a Trouble encounter that is the Danger number, so what
## turns up in it deepens with the search; an ambush on the road leaves it at one
## and gets whatever a roster's first wave is worth, which for the bomber is
## nothing.
##
## The last three are arguments rather than properties written before the call
## because they belong to [i]this[/i] ambush: one director serves the road and the
## Trouble encounters alike, and a Danger that breaks at three-quarters must not
## leave the next ambush on the road doing the same.
func begin_with(total: int, opening: int = -1, rout_at: float = -1.0,
		wave_number: int = 1) -> int:
	if _running or _resolve_spawner() == null:
		return 0
	if total <= 0:
		return 0

	_running = true
	_routing = false
	_owed = total
	_total = total
	_killed = 0
	_alive = 0
	_standing.clear()
	_downed.clear()
	# Rolled once, here, and taken from as the men are built. Reversed because the
	# plan is popped from the back, so the order the roster laid out is the order the
	# fight actually arrives in - the opening group included.
	_plan = _build_plan(total, wave_number)
	_rout = clampf(rout_fraction if rout_at < 0.0 else rout_at, 0.0, 1.0)
	_timer = maxf(group_interval, 0.0)
	# The spawner's own spacing memory is dropped, because this director places every
	# point itself and would otherwise be measured against a fight long over.
	_spawner.begin_batch()

	_follow_player_death()
	_open_with(mini(_rolled_opening() if opening < 0 else opening, total))
	_group_size = _sized_group()
	set_process(true)

	began.emit(total)
	return total


## Stops an ambush putting anything more out and leaves everything already on the
## field alone - the enemies keep chasing, exactly as [method WaveManager.stop]
## leaves an arena.
##
## Called when the journey is abandoned or a world is torn down. [b]It reports
## nothing[/b], because a stopped ambush was not cleared.
##
## [b]It is not what a death should call.[/b] A field of men left chasing a player who
## has been carried home is the very thing a death has to clear, and this drops the
## death watch that would have cleared it - so whoever owns an ambush asks for
## [method rout] instead when the player goes down, and the two never race.
func stop() -> void:
	if not _running:
		return
	_running = false
	_routing = false
	_owed = 0
	_alive = 0
	_standing.clear()
	_downed.clear()
	_plan.clear()
	_drop_player_death()
	set_process(false)


## Breaks the ambush now: nothing more is put out, and everybody still standing turns
## and runs through the retreat they already carry.
##
## [b]It is the same breaking [member rout_fraction] produces[/b] - see
## [method _rout_the_rest] - asked for rather than earned by killing enough of them. So
## an ambush that can no longer be finished, because the man fighting it is dead, empties
## through the one ending an ambush has instead of being left standing in a world nobody
## is in. The fight still ends through [signal cleared] once the last of them is off the
## field, so nothing downstream has to know which of the two broke it.
##
## Reports whether anything was actually broken - false for an ambush that is not
## running, or one that has already turned.
func rout() -> bool:
	if not _running or _routing:
		return false
	_rout_the_rest()
	return true


func _process(delta: float) -> void:
	if not _running or _owed <= 0:
		return

	_timer -= delta
	if _timer > 0.0:
		return
	if max_active_enemies > 0 and _living() >= max_active_enemies:
		# Held rather than dropped: the group is still owed and goes out the frame
		# there is room for it.
		return

	_release_group()
	_timer = maxf(group_interval, 0.05)


# --- Putting them out ----------------------------------------------------------

## The men who were waiting. Placed inside the view rather than outside it, which
## is the one thing that separates this from every other spawn in the game.
func _open_with(count: int) -> void:
	var arc := randf() * TAU
	for index: int in range(count):
		# Dealt round a circle rather than rolled independently, so a group of four
		# comes at the player from four sides instead of clumping on one.
		var angle := arc + TAU * float(index) / float(maxi(count, 1)) \
			+ randf_range(-0.3, 0.3)
		_spawn_one(_opening_point(angle))


## Where one of the opening group stands: out at [member opening_distance] on
## [param angle], then held inside the screen and inside the map.
##
## The screen clamp is what makes them visible, and it is applied before the map
## clamp because a spawn inside a wall is the one failure that cannot be lived
## with - a man standing slightly nearer than intended is not.
##
## [b]It is only applied when the screen is actually showing the player.[/b] The
## view is being used here as "where the player can see", and that is only true
## while the camera is on them - a camera left clamped somewhere else, or one still
## travelling, describes a rectangle the player is nowhere near, and clamping into
## it would put the ambush across the map instead of around them. Where they are
## standing is the fact that is always true, so when the two disagree the screen is
## the one that is dropped.
func _opening_point(angle: float) -> Vector2:
	var origin := _player_position()
	var distance := randf_range(
		minf(opening_distance.x, opening_distance.y),
		maxf(opening_distance.x, opening_distance.y))
	var point := origin + Vector2.RIGHT.rotated(angle) * maxf(distance, 0.0)

	var view := _spawner.get_view_rect()
	if view.has_point(origin):
		var seen := view.grow(-maxf(opening_screen_margin, 0.0))
		if seen.size.x > 0.0 and seen.size.y > 0.0:
			point = point.clamp(seen.position, seen.end)

	return _held_in_map(point)


## One group of the rest, arriving from just beyond the edge of the view.
func _release_group() -> void:
	for index: int in range(mini(_group_size, _owed)):
		if max_active_enemies > 0 and _living() >= max_active_enemies:
			return
		_spawn_one(_arrival_point())


## Where one arrival comes in: off the screen, but only just, and never outside the
## map.
##
## Several angles are tried and the one that lands furthest outside the view wins,
## because near a wall most directions are unusable - the map clamp would drag the
## spawn back on screen - and trying again is cheaper than accepting the first
## answer and being seen. A player standing in a corner still gets their ambush;
## it simply comes from the two sides that have room.
func _arrival_point() -> Vector2:
	var origin := _player_position()
	var view := _spawner.get_view_rect().grow(maxf(arrival_screen_margin, 0.0))
	var watched := view.has_point(origin)

	var best := origin
	var best_clearance := -INF

	for attempt: int in range(maxi(arrival_attempts, 1)):
		var heading := Vector2.RIGHT.rotated(randf() * TAU)
		var distance := randf_range(
			minf(arrival_distance.x, arrival_distance.y),
			maxf(arrival_distance.x, arrival_distance.y))
		# Pushed out to the edge of the view first, so the roll is a distance past
		# the screen rather than a distance that might still be on it.
		if watched:
			distance = maxf(distance, _distance_to_edge(origin, heading, view) + 1.0)

		var point := _held_in_map(origin + heading * maxf(distance, 0.0))
		# How far outside the view it actually ended up once the map had its say.
		var clearance := INF if not watched else _clearance_from(point, view)
		if clearance > 0.0:
			return point
		if clearance > best_clearance:
			best_clearance = clearance
			best = point

	return best


func _held_in_map(point: Vector2) -> Vector2:
	var inner := _spawner.arena_bounds.grow(-maxf(region_inset, 0.0))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return point
	return point.clamp(inner.position, inner.end)


## How far along [param dir] from [param from] the edge of [param box] is. Positive
## from inside it; the nearer of the two axes is where the line leaves.
func _distance_to_edge(from: Vector2, dir: Vector2, box: Rect2) -> float:
	var travel := INF
	if absf(dir.x) > 0.0001:
		var edge_x := box.end.x if dir.x > 0.0 else box.position.x
		travel = minf(travel, (edge_x - from.x) / dir.x)
	if absf(dir.y) > 0.0001:
		var edge_y := box.end.y if dir.y > 0.0 else box.position.y
		travel = minf(travel, (edge_y - from.y) / dir.y)
	return 0.0 if travel == INF else maxf(travel, 0.0)


## How far outside [param box] a point sits. Negative inside it, which is what
## [method _arrival_point] ranks its attempts on.
func _clearance_from(point: Vector2, box: Rect2) -> float:
	var out_x := maxf(box.position.x - point.x, point.x - box.end.x)
	var out_y := maxf(box.position.y - point.y, point.y - box.end.y)
	return maxf(out_x, out_y)


## Builds one enemy and starts following its death. An enemy that could not be
## built is not counted as owed either, so a spawner that refuses cannot leave an
## ambush waiting forever on a body that was never made.
func _spawn_one(point: Vector2) -> void:
	if _owed <= 0:
		return

	var enemy := _spawner.spawn_at(point, _next_body())
	if enemy == null:
		_owed -= 1
		_check_cleared()
		return

	_owed -= 1
	var health := _find_health(enemy)
	if health == null:
		# Nothing to wait on. Counted out rather than counted in, so an enemy with no
		# health pool cannot hold the road up after everything else is dead.
		_check_cleared()
		return

	_alive += 1
	_standing.append(enemy)
	health.died.connect(_on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
	_follow_surrender(enemy)


## Starts waiting on this man's nerve as well as on his health, so the fight hears
## about him going down the moment it happens rather than never - see
## [member surrender_ends_the_fight]. An enemy carrying no [EnemySurrender] has
## nothing to wait on and is left as it was.
func _follow_surrender(enemy: Node2D) -> void:
	if not surrender_ends_the_fight:
		return
	var surrender := EnemySurrender.find_on(enemy)
	if surrender == null:
		return
	surrender.surrendered.connect(_on_enemy_gave_up.bind(enemy), CONNECT_ONE_SHOT)


## One of the ambush is off the field.
##
## [b]Killed and got away are the same thing to the count[/b], and deliberately:
## what this number is for is knowing when there is nobody left to fight, and a man
## running over the horizon is no longer somebody to fight. What the two do differ
## on is [member _killed], which only a death moves - the breaking point is a
## measure of how much of the ambush the player actually beat, so an ambush cannot
## rout itself by its own runners leaving.
##
## The list is what stops one man being counted out twice: a runner is followed to
## both its death and its removal, and only whichever happens first finds it there.
func _on_enemy_gone(enemy: Node2D) -> void:
	if not _running:
		return

	# Shooting a man who had already given up is what finally settles him: he was
	# taken off the attackers when he went down, so this is the only count his death
	# still moves. Done before the guard below, which will refuse him.
	_leave_the_floor(enemy)
	if not _forget(enemy):
		return

	_alive = maxi(_alive - 1, 0)
	if not _routing:
		_killed += 1
		if _check_rout():
			return
	_check_cleared()


## One of the ambush has given up, which ends him as an opponent exactly as being
## killed or getting away does.
##
## [b]The body stays and the count moves anyway[/b], and that is the whole of it. He
## comes off [member _standing], so a rout can never order a man on the floor to get
## up and run, and off [member _alive], so [method _check_cleared] stops waiting for
## him - and then he is left entirely alone to play out his own ending.
##
## Shooting him afterwards is still an ordinary death and cannot count him out twice:
## [method _on_enemy_gone] asks [method _forget] first and finds him already gone
## from the list.
func _on_enemy_gave_up(enemy: Node2D) -> void:
	if not _running or not surrender_ends_the_fight or not _forget(enemy):
		return

	# Off the attackers and onto the floor - two lists rather than one, because he is
	# no longer somebody to fight but is still one of this encounter's men.
	_downed.append(enemy)
	_follow_escape(enemy)
	_alive = maxi(_alive - 1, 0)
	if not _routing and surrender_counts_as_beaten:
		_killed += 1
		if _check_rout():
			return
	_check_cleared()


## Starts waiting for a man on the floor to get to his feet and run, which is the
## other of the two ways he stops being this encounter's - see
## [method EnemySurrender.stand_up], which hands him back to his ordinary retreat.
##
## [b]It waits for the end of the retreat rather than the start of it.[/b]
## [signal EnemyEscape.escaped] is the moment he turns and runs and
## [signal EnemyEscape.escape_finished] is the moment he is off the screen and gone -
## and he is this encounter's man for the whole of the run between them, killable the
## entire way. The second is what [method _send_home] already waits on for a routed
## man, so both kinds of runner are finished with at the same point.
func _follow_escape(enemy: Node2D) -> void:
	var escape := _find_escape(enemy)
	if escape == null or escape.escape_finished.is_connected(_on_downed_ran):
		return
	escape.escape_finished.connect(_on_downed_ran.bind(enemy), CONNECT_ONE_SHOT)


func _on_downed_ran(enemy: Node2D) -> void:
	_leave_the_floor(enemy)


## Takes one man off the floor, whichever way he left it - shot where he lay, shot on
## his way out, or gone over the horizon - and asks whether he was the last thing the
## encounter was waiting on.
##
## [b]The ending arrives here as often as it arrives anywhere else.[/b] A fight whose
## attackers are all down is finished by whichever of these men resolves last, so the
## check belongs on the leaving rather than on any one of the three ways of leaving.
## Read by index and compared for the same reason [method _forget] is: an entry whose
## body has already been freed cannot be read out into a typed name at all.
func _leave_the_floor(enemy: Node2D) -> void:
	for index: int in range(_downed.size()):
		if _downed[index] == enemy:
			_downed.remove_at(index)
			_check_cleared()
			return


## Takes one man off the list of who is still out there, and reports whether he was
## on it. Read by index and compared rather than assigned, because an entry whose
## body has already been freed cannot be read out into a typed name at all.
func _forget(enemy: Node2D) -> bool:
	for index: int in range(_standing.size()):
		if _standing[index] == enemy:
			_standing.remove_at(index)
			return true
	return false


## Whether enough of the ambush is down for the rest to break - and the breaking
## itself, if it is. Reports whether it fired, so the caller knows the ending has
## already been dealt with.
func _check_rout() -> bool:
	if _routing or _rout <= 0.0 or _total <= 0:
		return false
	if _killed < int(ceil(float(_total) * _rout)):
		return false
	_rout_the_rest()
	return true


## Enough of them are down: the rest give up.
##
## [b]Nothing more is put out[/b] - what is still owed is written off exactly as it
## is when the player falls - and everybody still standing is asked to play the
## ending they already carry. There is no ambush retreat and no ambush death here:
## it is [EnemyEscape] where there is one and [EnemyDefeat] where there is not,
## which is the same pair, in the same order, that ends an arena round.
##
## [b]The ambush is not over at this point.[/b] The men who broke are still on the
## field, still killable, and still worth their blood to a player who chases them -
## the fight ends when the last of them is gone, through the same
## [method _check_cleared] every other ending goes through.
func _rout_the_rest() -> void:
	_routing = true
	_owed = 0

	var remaining := _standing.size()
	# Squeezed rather than truncated, so a packed field turns in the same window a
	# sparse one does and the last man is never left standing there.
	var gap := rout_stagger
	if rout_max_spread > 0.0 and remaining > 1:
		gap = minf(rout_stagger, rout_max_spread / float(remaining - 1))

	# Copied before it is walked: an enemy with no retreat is played out where it
	# stands, which can take it off the list in the same breath.
	var leaving := _standing.duplicate()
	var told := 0
	for index: int in range(leaving.size()):
		if not is_instance_valid(leaving[index]):
			continue
		if _send_home(leaving[index], gap * float(told)):
			told += 1

	routed.emit(remaining)
	# Asked here as well, for the field that had nobody left to tell - everybody
	# already dead on the frame the threshold was crossed.
	_check_cleared()


## One man's way out of a fight he has given up on, and whether he was given one.
##
## The retreat is preferred wherever there is one; the defeat is what an enemy built
## without one still gets, so a broken ambush can never be left with somebody
## standing in it who was never told anything.
##
## A runner is followed to its removal as well as to its death, because getting away
## is not a death and would otherwise leave the ambush waiting forever on a man who
## is already over the horizon.
func _send_home(enemy: Node2D, delay: float) -> bool:
	var escape := _find_escape(enemy)
	if escape != null and not escape.is_escaping() and not escape.is_cancelled():
		escape.escape_finished.connect(_on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
		escape.escape(delay)
		return true

	var defeat := _find_defeat(enemy)
	if defeat != null and not defeat.is_defeated():
		defeat.defeat(delay)
		return true
	return false


## The one place an ambush ends, and it now has three halves.
##
## Nobody still to come, nobody still fighting, and nobody left unresolved on the
## floor - see [member downed_hold_the_fight]. The first two are the fight itself:
## an ambush whose first group is already dead is not over while there are still men
## coming. The third is everything that happened after the fighting stopped, and it
## is what keeps the next-round question from arriving over the top of a man who is
## still lying in the sand, still getting to his feet, or still running for the edge
## of the screen.
func _check_cleared() -> void:
	if not _running or _owed > 0 or _alive > 0:
		return
	if downed_hold_the_fight and not _downed.is_empty():
		return
	_running = false
	_standing.clear()
	_downed.clear()
	_plan.clear()
	_drop_player_death()
	set_process(false)
	cleared.emit()


## [b]The fight is over when the player is down, and so is the ambush.[/b] A death is
## the player's own death sequence, which carries them home to the base - and an
## ambush still counting down its window would go on placing men around them, several
## thousand pixels from where the fight was. So what is still owed is written off the
## moment they fall.
##
## [b]The men still standing break and run, and that is the change.[/b] Writing off
## what was owed and leaving the field alone was not an ending: [method _check_cleared]
## needs an empty field as well as an empty debt, and the man who has just killed the
## player is not going to be killed by anybody, so [signal cleared] was never emitted -
## the road, the night or the search that opened the ambush hung on it for good, and a
## dozen men were left chasing a body that was no longer in the world. They are asked
## to leave instead, through the very [method _rout_the_rest] a broken ambush already
## uses, so there is one way an ambush empties and a death goes through it: no ambush
## retreat of its own, no bodies deleted, and the ending arrives through the same
## [signal cleared] every other one does.
func _on_player_died() -> void:
	if not _running:
		return
	if not rout():
		# Already breaking - the men are on their way off the field and are left to
		# finish leaving. Only what is still owed is written off again.
		_owed = 0
		_check_cleared()


func _follow_player_death() -> void:
	_drop_player_death()
	var player := _resolve_player()
	if player == null:
		return
	_player_health = _find_health(player)
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their death
## - they are revived into the same [Health] - so a connection left behind would
## still be listening at the next ambush but one.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


# --- Sizing --------------------------------------------------------------------

## How many go out per release, so that whatever is left after the opening is all
## on the field by the end of [member spawn_window].
func _sized_group() -> int:
	var releases := maxi(int(floor(maxf(spawn_window, 0.0) / maxf(group_interval, 0.05))), 1)
	return maxi(int(ceil(float(_owed) / float(releases))), maxi(min_group_size, 1))


func _rolled_opening() -> int:
	var low := mini(opening_count.x, opening_count.y)
	var high := maxi(opening_count.x, opening_count.y)
	return maxi(low + randi() % maxi(high - low + 1, 1), 0)


# --- Looking things up ---------------------------------------------------------

## The next body off the plan, or null for the spawner's own enemy - which is also
## what an ambush with no roster answers for every man in it.
## The mix this ambush is worth, one entry per body, or an empty plan when there is
## no roster to ask - which every body then reads as the spawner's own enemy.
func _build_plan(total: int, wave_number: int) -> Array[PackedScene]:
	var roster := _resolve_roster()
	if roster == null:
		return []

	var plan := roster.build_wave(maxi(wave_number, 1), total)
	plan.reverse()
	return plan


## The next body off the plan, or null for the spawner's own enemy - which is also
## what an ambush with no roster answers for every man in it.
func _next_body() -> PackedScene:
	if _plan.is_empty():
		return null
	return _plan.pop_back()


## The roster this world fills its ambushes from, or null when it has none.
func _resolve_roster() -> WaveRoster:
	if _roster == null or not is_instance_valid(_roster):
		_roster = get_node_or_null(roster_path) as WaveRoster
	return _roster


func _resolve_spawner() -> EnemySpawner:
	if _spawner == null or not is_instance_valid(_spawner):
		_spawner = get_node_or_null(spawner_path) as EnemySpawner
	return _spawner


## Looked up lazily and re-looked-up when it goes away, so a world rebuilt around
## this director still finds its player.
func _resolve_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	return _player


## Where the ambush is centred. A world with no player - one opened on its own in
## the editor - is ambushed at the origin rather than erroring.
func _player_position() -> Vector2:
	var player := _resolve_player()
	return Vector2.ZERO if player == null else player.global_position


func _living() -> int:
	return get_tree().get_nodes_in_group(enemy_group).size()


func _find_health(enemy: Node) -> Health:
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


## Found by type rather than by a fixed child name, for the same reason
## [RunEndDefeat] finds them that way: an enemy that keeps its components somewhere
## else still gives up properly.
func _find_escape(enemy: Node) -> EnemyEscape:
	for node: Node in enemy.find_children("*", "EnemyEscape", true, false):
		var escape := node as EnemyEscape
		if escape != null:
			return escape
	return null


func _find_defeat(enemy: Node) -> EnemyDefeat:
	for node: Node in enemy.find_children("*", "EnemyDefeat", true, false):
		var defeat := node as EnemyDefeat
		if defeat != null:
			return defeat
	return null
