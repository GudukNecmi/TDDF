class_name RegionArrival
extends Node
## What the player rides into: standing where the region says arrivals stand, and
## - as often as the map says - somebody already waiting there.
##
## [b]It is the far side of a journey, and it belongs to the world rather than to
## the road.[/b] A ride ends by rebuilding the world - see
## [method TravelDirector._arrive] - so by the time anyone has arrived anywhere the
## director that made the journey no longer exists. What is left behind is one fact
## on [RunSessionState], taken here: this world is one the player rode into. See
## [method RunSessionState.take_arrival].
##
## Two things follow from it, in this order:
##
##   * [b]Standing somewhere.[/b] The player is put at
##     [member MapRegion.start_position] - the region's own answer to where the
##     road comes out. Nothing here names a place; a region with no arrival point
##     authored on it lands the player in the middle of the map, which is where the
##     world scene already stands them.
##   * [b]A fight, or not.[/b] One roll against
##     [member MapDefinition.arrival_combat_chance]. [b]The chance is the map's,
##     not this node's[/b]: the desert is authored at 0.4 and the forest at 0.5 on
##     their own [code].tres[/code] files, so a sixth map states its own without a
##     map name, a threshold or a table appearing anywhere in this script. A roll
##     that fails changes nothing at all and the region is entered as any other
##     round is.
##
## [b]The fight is the ordinary game's, not the ambush system's.[/b] The enemies are
## built by the world's own [EnemySpawner] - the same spawner an arena round uses,
## placed off the edges of the view the same way - so an arrival is fought against
## ordinary enemies with ordinary AI and there is no second enemy, no second
## spawner and no second difficulty curve. [AmbushWaveDirector] is not involved and
## is not asked: being ambushed on the road and riding into an occupied region are
## two different things, and only the first of them is an ambush.
##
## [b]And it is not a round.[/b] [WaveManager] is never started for an arrival, so
## there is no clock and nothing comes after the group that was waiting: when the
## last of them goes down the encounter is simply over. What that ends is the round
## itself - the manager is told to stop, which is the same collection phase the
## sixty-second clock running out produces - so the camp goes up exactly as it does
## at the end of any other round and the player decides what to do next from there.
## How many are waiting is [method MapDefinition.get_arrival_enemy_count], read
## against the region's own danger, so riding into a map's deepest corner is worth
## more men than riding into its way in without a number here changing.

## Emitted once the arrival has been made, with where and whether there is a fight.
## The player has already been moved by the time this arrives; nothing has spawned
## yet.
signal arrived(region_id: StringName, fighting: bool)
## Emitted as the arrival encounter opens, with how many were actually built.
signal encounter_began(enemy_count: int)
## Emitted when the last of them goes down. [b]The only thing that ends an
## arrival encounter[/b] - nothing is on a timer and no wave follows.
signal encounter_cleared()

## Group the node joins, so the world can find it without a path.
const GROUP := &"region_arrival"

## What the roll is allowed to answer. [constant Roll.ROLLED] is the game; the
## other two are for looking at either outcome without playing rides until it comes
## up.
enum Roll {
	## Rolled against the map's own chance, which is the game.
	ROLLED,
	## Every arrival is a fight, whatever the map says.
	ALWAYS,
	## No arrival is ever a fight, whatever the map says.
	NEVER,
}

## The run's own state - the [code]RunSession[/code] autoload. Where the arrival is
## taken from, and where the map and the region are read from.
@export var session_path: NodePath = ^"/root/RunSession"
## The world's own spawner, which builds every enemy waiting in a region.
## [b]There is no arrival enemy[/b] - they are the game's ordinary enemies, made by
## the thing that already makes them.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## The round's clock, told to stop once the arrival encounter is cleared, so the
## camp goes up exactly as it does at the end of an ordinary round. It is never
## started by any of this.
@export var wave_manager_path: NodePath = ^"../WaveManager"
## Group the player is found in, so this node is not wired to them.
@export var player_group: StringName = &"player"
## The map's own extent, asked how large the world is so an arrival cannot be made
## outside it. See [member arrival_inset].
##
## [b]The map is asked rather than told.[/b] The rectangle is
## [method CameraBounds.get_world_region] - the same one the camera is limited to -
## so there is no second copy of how big the desert is here to fall out of step with
## the walls. A world with no [CameraBounds] clamps nothing and arrives exactly
## where the region said, which is how this behaved before there was a clamp.
@export var bounds_path: NodePath = ^"../CameraBounds"

@export_group("Arriving")
## Whether the player is actually moved to the region's own arrival point. Off
## leaves them wherever the world scene placed them, which is what a world being
## looked at in the editor wants.
@export var place_player: bool = true
## How far inside the map's edge an arrival is held, in pixels.
##
## [b]Not a margin for looks - it is what keeps the player in the world.[/b] The
## walls are a closed box, so a player put down outside them is walled *out* and
## cannot walk back in, while the camera stays limited to the arena and leaves them
## off the edge of the screen. Anything the map's own extent does not contain is
## pulled to the nearest point inside it.
##
## Wants to be larger than the player's own body so they are not stood
## overlapping a wall. 0 clamps to the wall faces exactly; the region's authored
## point is untouched whenever it is already inside, so this costs nothing on a
## region that was authored in bounds.
@export var arrival_inset: float = 64.0
## Whether the arrival is also held where the camera can actually centre on it.
##
## [b]Being inside the map is not the same as being framed by it.[/b] The camera is
## limited to the same rectangle the player is - see [CameraBounds] - so on a point
## near a wall it runs out of map before it runs out of the way to the player, stops
## at the edge, and leaves them stood in the corner of the screen. Nothing is wrong
## with the camera when that happens and no amount of following fixes it; the
## arrival is simply somewhere no camera obeying the map's limits can put in the
## middle.
##
## So the point is held half a screen in from the edge, which is exactly as far as
## the camera can follow. A region arrived in further in than that is untouched, and
## a point that has to move is still moved only to the nearest framed spot - so a
## region authored toward a corner still arrives toward that corner.
##
## Off falls back to [member arrival_inset] alone, which keeps the player in the
## world but not necessarily in the middle of the view.
@export var frame_the_arrival: bool = true

@export_group("The fight")
## Whether the roll is taken, or forced one way. See [enum Roll].
@export var roll: Roll = Roll.ROLLED
## Whether clearing the arrival encounter ends the round.
##
## On. An arrival encounter is what this round [i]is[/i] - no clock was started and
## no waves are coming - so the last of them going down is the end of it, and the
## way out of a round has to arrive or the player is left standing in a region with
## nothing to do. Off leaves the world running with the arena quiet, which is what a
## harness watching the encounter alone wants.
@export var ends_the_round: bool = true

var _session: Node
## Whether the arrival has been asked for yet. Taken once - see
## [method _resolve] - because the session hands the answer over rather than
## repeating it.
var _resolved: bool = false
## Whether this world turned out to be one the player rode into.
var _arrived: bool = false
## What the roll said. Cleared again if the encounter turns out to be unbuildable,
## so a world that cannot fight enters its region normally rather than standing
## empty.
var _fighting: bool = false
var _running: bool = false
## How many of the group are still opposing the player. The encounter is over when
## it reaches zero, which is the only thing that ends it.
var _alive: int = 0
## The instance ids of the enemies still being counted, so each one can only ever
## leave the tally once however it left the fight - a man who gave up and was then
## shot is one opponent gone, not two.
var _counted: Dictionary = {}


## Joined here rather than in [method Node._ready] so the node is findable, and has
## already found the session, whatever order the world's nodes happen to sit in.
func _enter_tree() -> void:
	add_to_group(GROUP)
	_session = get_node_or_null(session_path)


func _ready() -> void:
	_resolve()


## The arrival this world should talk to. Null means this world has none, which
## [WorldBoot] reads as "there is nothing waiting here" and starts an ordinary
## round.
static func get_active(from_node: Node) -> RegionArrival:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RegionArrival


## Whether this world was arrived at by riding rather than by starting the next
## round where the player already was.
func is_arrival() -> bool:
	_resolve()
	return _arrived


## Whether the roll said there is somebody waiting. Answered before anything is
## built, so [WorldBoot] can ask without committing to a fight.
func is_fighting() -> bool:
	_resolve()
	return _fighting


## Whether the arrival encounter is being fought right now.
func is_encounter_running() -> bool:
	return _running


## How many are still standing, for a readout or a test.
func get_enemies_alive() -> int:
	return _alive


## How likely an arrival on the map being played is a fight. The map's own number;
## 0 when there is no map to ask, which is a world opened on its own.
func get_combat_chance() -> float:
	var map := _get_map()
	return 0.0 if map == null else map.get_arrival_combat_chance()


## How many are waiting in the region the player has arrived in, read from the map
## against that region's own danger.
func get_enemy_count() -> int:
	var map := _get_map()
	return 0 if map == null else map.get_arrival_enemy_count(_get_region())


## The whole of the arrival, taken once.
##
## Called from [method Node._ready], and again from [method begin_encounter] as
## insurance - which of this node and [WorldBoot] runs first is a question about
## where they sit in the scene rather than anything either should depend on, and the
## session hands the arrival over exactly once, so whichever asks first is the one
## that does the work.
func _resolve() -> void:
	if _resolved:
		return
	_resolved = true

	if _session == null or not _session.has_method(&"take_arrival"):
		return
	if not _session.call(&"take_arrival"):
		return

	_arrived = true
	var region := _get_region()
	if place_player:
		_place_player(region)

	_fighting = _rolls_a_fight()
	arrived.emit(&"" if region == null else region.region_id, _fighting)


## Whether there is somebody waiting. One roll, taken against the map's own chance
## and nothing else, so switching arrival combat off for a map is authoring a zero
## on that map rather than a branch here.
func _rolls_a_fight() -> bool:
	match roll:
		Roll.ALWAYS:
			return true
		Roll.NEVER:
			return false
		_:
			return randf() < get_combat_chance()


## Where the road came out. A region with no arrival point authored on it leaves the
## player where the world scene placed them, which is the middle of the map.
##
## The authored point is held inside the map - see [method _inside_the_map] - because
## where a region says the road comes out and how large the map actually is are two
## separately authored facts, and a point outside the walls strands the player in a
## world they cannot walk back into.
func _place_player(region: MapRegion) -> void:
	if region == null:
		return

	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null:
		return

	player.global_position = _inside_the_map(region.start_position)
	# Physics interpolation is on project-wide; without this the player is visibly
	# smeared in from wherever the scene placed them, exactly as they are when the
	# teleport carries them home.
	player.reset_physics_interpolation()

	var camera := CameraController.get_active(self)
	if camera != null:
		camera.reset_smoothing()


## The nearest point to [param point] that is actually in the map, held
## [member arrival_inset] clear of its edge.
##
## [b]The authored point is kept wherever it can be.[/b] A region arrived in well
## inside the walls is placed exactly where its [code].tres[/code] says, so this is
## invisible to every region that was authored in bounds; only a point the map does
## not contain is moved, and then only as far as the nearest edge - so a region whose
## arrival was written into the top left corner still arrives in the top left corner
## rather than in the middle of the map.
##
## The rectangle is the map's own, read from [CameraBounds] rather than restated
## here, so a map that is resized moves its arrivals with it. A world with no bounds
## node clamps nothing.
##
## How far in is the larger of [member arrival_inset] - enough not to be stood in a
## wall - and half the camera's view, which is what [member frame_the_arrival] is
## for. Both are measured against the map itself rather than authored as a distance,
## so nothing here has to be retuned when the map or the zoom changes.
func _inside_the_map(point: Vector2) -> Vector2:
	var bounds := get_node_or_null(bounds_path) as CameraBounds
	if bounds == null:
		return point

	var area := bounds.get_world_region()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return point

	var margin := Vector2.ONE * maxf(arrival_inset, 0.0)
	if frame_the_arrival:
		margin = margin.max(_half_the_view())
	# Never more than half the map. A map smaller than what is asked of it collapses
	# to its own middle - the one point a camera limited to it can always centre on -
	# rather than to a rectangle turned inside out.
	margin = margin.min(area.size * 0.5)

	return point.clamp(area.position + margin, area.end - margin)


## Half of what the camera can see, in world pixels - the distance between the
## middle of the screen and its edge, and therefore how far from the map's edge the
## player has to stand to be in the middle of it.
##
## Measured off the live camera rather than authored, so a map played at a different
## zoom frames its arrivals correctly without this being told about it. Nothing when
## there is no camera, which leaves [member arrival_inset] as the only margin.
func _half_the_view() -> Vector2:
	var camera := CameraController.get_active(self)
	if camera == null:
		return Vector2.ZERO

	var zoom := camera.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return Vector2.ZERO
	return camera.get_viewport_rect().size / zoom * 0.5


## Builds whatever was waiting and reports how many are actually standing.
##
## Called by [WorldBoot] at the moment the round's clock would have been started -
## after the intro has finished - so the fight begins the frame the round would
## have. A zero answer is not an error: it is a quiet arrival, a world with no
## spawner, or a map that has authored nobody, and the caller starts an ordinary
## round instead. [b]Nothing here can leave a world with neither a round nor a
## fight in it.[/b]
##
## Each enemy is followed by its own death rather than by counting the group, so
## anything else alive in the world - the enemy the scene was authored with,
## something left over from the ride - is neither waited on nor cleared.
func begin_encounter() -> int:
	_resolve()
	if not _fighting or _running:
		return 0

	var spawner := get_node_or_null(spawner_path) as EnemySpawner
	if spawner == null:
		push_warning("RegionArrival: no spawner to build an arrival encounter with.")
		_fighting = false
		return 0

	var wanted := get_enemy_count()
	if wanted <= 0:
		_fighting = false
		return 0

	_alive = 0
	_counted.clear()
	# The spawner's own spacing memory is dropped, so the group is measured against
	# itself rather than against a fight in the world the player rode out of.
	spawner.begin_batch()
	for index: int in range(wanted):
		var enemy := spawner.spawn()
		if enemy == null:
			continue
		var health := _find_health(enemy)
		if health == null:
			continue
		_alive += 1
		_counted[enemy.get_instance_id()] = true
		health.died.connect(_on_enemy_left.bind(enemy))
		# Giving up ends an enemy's part in the encounter just as surely as dying
		# does, and it is the only one of the two that leaves the enemy alive - so
		# without this a man who surrendered during an arrival fight would keep the
		# encounter open forever and the way out of the region would never arrive.
		var surrender := EnemySurrender.find_on(enemy)
		if surrender != null:
			surrender.surrendered.connect(_on_enemy_left.bind(enemy))

	if _alive <= 0:
		_fighting = false
		return 0

	_running = true
	encounter_began.emit(_alive)
	return _alive


## One of the group has stopped being an opponent - killed, or on the floor with its
## knife thrown down. Which of the two it was makes no difference here, and the
## enemy is struck off the tally by identity so the two can never both be counted.
func _on_enemy_left(enemy: Node) -> void:
	if not _running or enemy == null:
		return

	var key := enemy.get_instance_id()
	if not _counted.has(key):
		return
	_counted.erase(key)

	_alive = maxi(_alive - 1, 0)
	if _alive > 0:
		return

	_running = false
	encounter_cleared.emit()
	_end_the_round()


## The last of them is down. [b]No wave follows[/b] - the round's clock was never
## started and is not started here either. All this does is put the run into the
## collection phase the end of an ordinary round produces, which is what the camp
## and the run timer are already watching for, so the way out of the region arrives
## by exactly the existing rule.
func _end_the_round() -> void:
	if not ends_the_round:
		return

	var manager := get_node_or_null(wave_manager_path) as WaveManager
	if manager != null:
		manager.stop()


## The map being played, or null when there is no run and no catalogue - a world
## opened on its own in the editor, which arrives nowhere and fights nobody.
func _get_map() -> MapDefinition:
	if _session == null or not _session.has_method(&"get_map"):
		return null
	return _session.call(&"get_map") as MapDefinition


## The part of the map the player has arrived in. Asked of the session rather than
## kept, because the arrival is what made the destination into the region - see
## [method RunSessionState.arrive_at_destination] - so by the time this world exists
## there is only one answer and it is the session's.
func _get_region() -> MapRegion:
	if _session == null or not _session.has_method(&"get_region"):
		return null
	return _session.call(&"get_region") as MapRegion


func _find_health(enemy: Node) -> Health:
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null
