class_name BossEncounterMap
extends TeleportDestination
## The ground a bounty is actually fought on: a map of its own, kept away from the
## desert the player found the man in.
##
## [b]It is a place, not a mode.[/b] The whole encounter is carried into it the moment
## the player reaches the outlaw - the player, the boss, and every man standing with
## him - and carried back out when the fight is over. Nothing about the fight itself is
## changed by the move: it is the same boss, built by the same [EnemySpawner], fought
## through the same [MiniBossDirector], ended by the same [BossDefeat], paying the same
## contract. All this owns is the ground under it.
##
## [b]It is a [TeleportDestination] because that is already what "somewhere else in the
## world you can be sent to" means here.[/b] The base is one, and it works exactly this
## way: a scene sitting a few thousand pixels off in the same world, stating its own
## arrival point and its own playable rectangle, so it can be opened in the editor and
## decorated next to everything else. There is no second viewport, no scene change and
## no second world file - which is why the run, the ledger, the wallet, the HUD and the
## way home all survive the trip without knowing it happened.
##
## What moves, and what is put back:
##
##   [codeblock]
##   walked to him  ->  enter()  ->  the fight  ->  BossDefeat.arena_released  ->  leave()
##   [/codeblock]
##
##   * [b]enter.[/b] Where the player was standing is written down, then they, the boss
##     and the support group are set down here - the group keeping its shape around him,
##     so the ring he was found in is the ring he is fought in. The camera's limits and
##     the spawner's [member EnemySpawner.arena_bounds] are taken over by this map's own
##     rectangle, which is what makes reinforcements arrive here and crates drop here.
##   * [b]leave.[/b] The player is put back exactly where they were found, the body is
##     brought back with them so it can still be walked up to and pressed E on, and both
##     the camera and the spawner are handed back the numbers they had. The camp opens
##     on the same beat - see [method BossDefeat._open_the_way_home] - so the way home is
##     the way home it always was.
##
## [b]Its own ground is the region's.[/b] The floor carries a [RegionGround] of its own,
## pointed at this scene's own surface, so the encounter is fought on the artwork of the
## part of the map the contract pointed at rather than on a ground of its own - which is
## what keeps a bounty in the Red River looking like the Red River. Everything else about
## how it looks is nodes in this scene, to be decorated by hand.

## Emitted as the encounter is carried in, with where the player was standing.
signal entered(from: Vector2)
## Emitted as it is carried back out.
signal left(to: Vector2)

## Group this joins on top of the inherited [constant TeleportDestination.GROUP], so the
## boss system can find it without a path.
##
## It is a second, narrower group rather than a redefinition of the inherited one: every
## destination in the world is in that one - the base pit among them - so asking it for
## "the first one" would just as happily hand back the base.
const ENCOUNTER_GROUP := &"boss_encounter_map"

## Whether the fight is held here at all. Off leaves the boss fought where he was
## found, which is exactly what the game did before this map existed - so it is the one
## switch that turns the whole thing off without anything being unwired.
@export var enabled: bool = true

@export_group("Nodes")
## Where the boss is stood. Falls back to this node's own origin.
@export var boss_point_path: NodePath = ^"BossPoint"
## The world's spawner, whose playable rectangle is taken over for the fight so that
## reinforcements and crates land in this map rather than back in the desert.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## The ending, watched so the encounter is carried back out on the same beat the camp
## opens. Optional; a world without one simply never comes back on its own.
@export var defeat_path: NodePath = ^"../BossDefeat"
## Group the player is found in, so this node is not wired to them.
@export var player_group: StringName = &"player"

@export_group("Carrying them in")
## How far the support group may stand from the boss once it is set down here, in
## pixels. Their ring is kept as it was found and then held inside this map, so a group
## that was spread round a man in the open is not left standing in the walls.
@export var support_reach: float = 420.0
## Clear ground left between any body and the wall it is nearest, in pixels.
@export var wall_clearance: float = 150.0
## Whether the camera is clamped to this map's own rectangle while the fight is here.
@export var takes_camera: bool = true
## Whether the beaten man's body is brought back out with the player.
##
## [b]On, and it is what keeps the ending whole.[/b] A boss is left lying in the sand to
## be walked up to and pressed E on - that is where the knowledge about the other
## posters comes from, see [BossDefeat] - so a body left behind in a map the player can
## no longer reach would quietly delete that half of the reward.
@export var brings_the_body_home: bool = true

var _hosting: bool = false
## Where the player was standing when they were carried in, and what the camera and the
## spawner were set to, so all three can be put back exactly.
var _player_was := Vector2.ZERO
var _limits_were := Vector4i.ZERO
var _bounds_were := Rect2()
var _limits_taken: bool = false
var _boss: Node2D
var _support: Array[Node2D] = []


func _enter_tree() -> void:
	add_to_group(ENCOUNTER_GROUP)


func _ready() -> void:
	super()
	_watch_the_ending.call_deferred()


## The encounter map in this world, or null when it has none - which
## [MiniBossDirector] reads as "there is nowhere else to fight this" and holds the
## fight where the man was found, exactly as it did before this existed.
static func get_active(from_node: Node) -> BossEncounterMap:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(ENCOUNTER_GROUP) as BossEncounterMap


## Whether the fight is currently being held here.
func is_hosting() -> bool:
	return _hosting


## Where the boss is stood, in world space.
func get_boss_position() -> Vector2:
	var point := get_node_or_null(boss_point_path) as Node2D
	return global_position if point == null else point.global_position


## The part of this map a body may stand in with the whole of itself inside the walls.
func get_standing_room() -> Rect2:
	var room := get_world_bounds().grow(-maxf(wall_clearance, 0.0))
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return Rect2(get_world_bounds().get_center(), Vector2.ZERO)
	return room


# --- Carrying them in ------------------------------------------------------------

## Carries the encounter in: the player, [param boss] and [param support] are set down
## here and the world's idea of where the fight is happening follows them.
##
## Returns whether the move actually happened. False means this map is switched off, is
## already hosting, or there was no player or no boss to carry - and nothing is changed
## on the way out, so the caller carries on with the fight exactly where it was.
func enter(boss: Node2D, support: Array[Node2D]) -> bool:
	if not enabled or _hosting:
		return false

	var player := _resolve_player()
	if player == null or boss == null or not is_instance_valid(boss):
		return false

	_hosting = true
	_boss = boss
	_player_was = player.global_position

	# The ring the group was standing in, measured before anybody is moved, so it can
	# be laid down again round the boss's new position rather than being rebuilt.
	var centre := boss.global_position
	var here := get_boss_position()
	var room := get_standing_room()

	_support.clear()
	# Read by index and tested before being given a name, because an entry whose object
	# has already been freed cannot be taken out of a typed array at all - somebody shot
	# on the walk in leaves exactly such an entry behind.
	for index: int in range(support.size()):
		if not is_instance_valid(support[index]):
			continue
		var man: Node2D = support[index]
		var offset := man.global_position - centre
		if offset.length() > maxf(support_reach, 1.0):
			offset = offset.normalized() * maxf(support_reach, 1.0)
		_place(man, (here + offset).clamp(room.position, room.end))
		_support.append(man)

	_place(boss, here)
	_place(player, get_spawn_position())

	_take_the_ground()
	entered.emit(_player_was)
	return true


## Carries it back out: the player to exactly where they were found, the body with them,
## and the camera and the spawner back to the numbers they had.
##
## Safe on a map that is not hosting, which is what makes it callable from the ending,
## from a teardown and from the developer panel without any of them having to check.
func leave() -> void:
	if not _hosting:
		return
	_hosting = false

	var player := _resolve_player()
	if player != null:
		# The body first, measured against where the player is standing now, so it comes
		# out of the trip lying exactly where it was lying relative to them - which is
		# what keeps its reach circle and its E over the same patch of ground.
		if brings_the_body_home and _boss != null and is_instance_valid(_boss):
			var offset := _boss.global_position - player.global_position
			_place(_boss, _player_was + offset)
		_place(player, _player_was)

	_give_the_ground_back()
	# The body comes home; the men who were standing with him do not, and they are let
	# go of rather than followed - by this point they have either run or been killed.
	_support.clear()
	_boss = null
	left.emit(_player_was)


## One body set down, with the smear that physics interpolation would otherwise draw
## across the world taken out - the same move [WorldBoot] makes when it puts the player
## at the base.
func _place(body: Node2D, at: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.global_position = at
	body.reset_physics_interpolation()


# --- The ground the fight is measured against -------------------------------------

## The camera's limits and the spawner's playable rectangle taken over by this map's
## own, with what they were written down so they can be given back.
##
## [b]Both, or the fight is only half here.[/b] The camera decides what the player can
## see and [method BossArena._held_in_play] trims the fight's picture against it; the
## spawner's rectangle decides where reinforcements may be put down and where crates
## are dropped. Leaving either pointed at the desert would put half the encounter back
## in a region nobody is standing in.
func _take_the_ground() -> void:
	var spawner := _resolve_spawner()
	if spawner != null:
		_bounds_were = spawner.arena_bounds
		spawner.arena_bounds = get_world_bounds()

	if not takes_camera:
		return
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	_limits_were = Vector4i(
		camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
	_limits_taken = true
	_clamp_camera_to(camera, get_world_bounds())


func _give_the_ground_back() -> void:
	var spawner := _resolve_spawner()
	if spawner != null and _bounds_were.size.x > 0.0:
		spawner.arena_bounds = _bounds_were
	_bounds_were = Rect2()

	if not _limits_taken:
		return
	_limits_taken = false
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	camera.limit_left = _limits_were.x
	camera.limit_top = _limits_were.y
	camera.limit_right = _limits_were.z
	camera.limit_bottom = _limits_were.w
	camera.reset_smoothing()


## The same growing [CameraBounds] and [Teleporter] do: a limit rectangle smaller than
## the screen is a request the camera cannot satisfy, so a small map is widened around
## its own centre rather than leaving bars down the edges.
func _clamp_camera_to(camera: CameraController, area: Rect2) -> void:
	var view := camera.get_viewport_rect().size / camera.zoom
	var box := area
	if area.size.x < view.x or area.size.y < view.y:
		var size := Vector2(maxf(area.size.x, view.x), maxf(area.size.y, view.y))
		box = Rect2(area.get_center() - size * 0.5, size)

	camera.limit_left = int(box.position.x)
	camera.limit_top = int(box.position.y)
	camera.limit_right = int(box.end.x)
	camera.limit_bottom = int(box.end.y)
	camera.reset_smoothing()


# --- Coming home ------------------------------------------------------------------

## Wired a frame late, because the ending joins its own group in its own
## [method Node._ready] and there is no ordering of the world's children that
## guarantees that has happened before this one runs.
func _watch_the_ending() -> void:
	if not is_inside_tree():
		return
	var defeat := _resolve_defeat()
	if defeat == null:
		return
	if not defeat.arena_released.is_connected(_on_arena_released):
		defeat.arena_released.connect(_on_arena_released)


## The fixed screen has been handed back and the camp has opened. That is the end of the
## encounter, so it is the end of being here.
func _on_arena_released() -> void:
	leave()


## Nothing is left standing in an empty map behind us: a world torn down mid-fight - a
## death, a reload - would otherwise hand the next round a camera clamped to a rectangle
## thousands of pixels from anywhere.
func _exit_tree() -> void:
	if _hosting:
		_hosting = false
		_give_the_ground_back()
		_support.clear()
		_boss = null


func _resolve_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D


func _resolve_spawner() -> EnemySpawner:
	return get_node_or_null(spawner_path) as EnemySpawner


func _resolve_defeat() -> BossDefeat:
	var named := get_node_or_null(defeat_path) as BossDefeat
	return named if named != null else BossDefeat.get_active(self)
