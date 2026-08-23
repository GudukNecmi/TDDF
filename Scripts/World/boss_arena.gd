class_name BossArena
extends Node2D
## Turns a patch of the open desert into a fixed-screen fight: the introduction that
## hands the camera over to the boss, and the lock that hands it back and then nails
## it down.
##
## [b]It owns the view and the walls, and nothing else.[/b] Who the boss is, when it
## appears and what it is worth are [MiniBossDirector]'s; all this knows is that it
## has been given something to introduce and somewhere to fence in. That split is
## what makes it reusable: a later encounter that wants the same treatment - a duel,
## a set piece - calls the same two methods and needs none of the bounty system.
##
## The two halves happen in order and are deliberately separate calls, because the
## thing between them is the player reading a name off the screen:
##
##   [codeblock]
##   play_intro(boss)  ->  intro_finished  ->  lock(boss)
##   [/codeblock]
##
##   * [b]The introduction.[/b] The camera crosses off the player and onto the boss
##     and pulls in to [member intro_zoom], over about [member intro_seconds]. Both
##     are [CameraController]'s own mechanisms - [method CameraController.follow] and
##     [method CameraController.set_zoom_multiplier] - so the shake, the hit reaction
##     and every other channel keep working through it and the camera cannot be left
##     stranded on a boss that dies.
##   * [b]The lock.[/b] The camera is released back to the player and taken out to
##     [member fight_zoom]. The rectangle a screenful of that zoom covers around the
##     boss becomes the arena - where crates are dropped and where reinforcements come
##     in around - trimmed to the ground the map actually has.
##
## [b]Whether that rectangle is also a fixed screen is two flags, and for the mini boss
## both are off.[/b] [member locks_camera] pins the camera inside it and
## [member fences_area] walls it in; together they are the fixed-screen encounter this
## was first written for. The boss fight is fought with the ordinary player-follow
## camera and inside the map's own walls instead, so the only thing the arena does for
## it is measure the picture - [member fight_zoom] is 1, the ordinary gameplay framing,
## so the view is handed back exactly as it was rather than being pulled out to a wider
## arena.
##
## [b]Nobody can walk out of a fixed picture[/b] because the same rectangle is fenced.
## Four static walls are built round it on the layer the arena's own bounds already
## use, so the player, the boss and the support group are all held by exactly the
## thing that already holds them inside the map - see [method _build_walls]. There is
## no per-character clamp anywhere, which is what keeps knockback, retreats and the
## separation steering working normally right up against the edge.
##
## [b]The fence is one-way for anything arriving.[/b] Reinforcements are spawned just
## outside the picture and walk in, which a solid wall would stop dead - so a body can
## be handed to [method admit] and is let through once, then held by the same wall as
## everybody else the moment it is inside. It is a collision exception against the
## wall body alone rather than a change to the body's own mask, so an enemy walking in
## is still stopped by the map, by the player and by everything else it ever collided
## with.

## Emitted when the introduction has finished playing. [b]The only thing that ends
## it[/b]; the caller starts the fight on this.
signal intro_finished
## Emitted as the arena is locked, with the rectangle the fight happens in.
signal locked(area: Rect2)
## Emitted when the arena is given back - the limits restored and the walls taken
## down.
signal unlocked

## Group this node joins, so a director can find it without a path.
const GROUP := &"boss_arena"

@export_group("Introduction")
## How long the camera is given to cross onto the boss and settle, in seconds.
## [signal intro_finished] arrives at the end of it.
@export var intro_seconds: float = 2.0
## How close the view pulls in while the boss is being introduced, as a multiple of
## the camera's authored zoom. Above 1 is closer.
@export var intro_zoom: float = 2.0
## How hard the camera grabs the boss, in the usual exponential-smoothing units.
##
## Deliberately low. The brief asks for the camera to move away from the player
## *slowly*, and this is the number that means slowly: around 2 crosses most of the
## way in a second and settles inside [member intro_seconds], where the camera's own
## default of 11 would snap across in a fifth of a second and leave the rest of the
## introduction sitting still.
@export var intro_camera_speed: float = 2.0
## How quickly the view crosses to [member intro_zoom]. Applied to the camera for
## the length of the introduction and put back exactly as it was afterwards, so a
## slow cinematic pull does not leave every later zoom sluggish.
@export var intro_zoom_speed: float = 1.6

@export_group("The fight")
## How far out the view sits for the fight itself, as a multiple of the authored zoom.
##
## [b]1 is the ordinary gameplay framing, and that is what a boss fight is fought at.[/b]
## It used to be 0.6 - a deliberate pull back to a wider arena, which is what the fixed
## screen this node was first written for needed. The mini boss is not fought on a fixed
## screen: it is fought with the player-follow camera, in a map of its own, and a view
## that snapped out to show half a desert at the moment the fight started made the man
## the player had walked all that way to find smaller rather than larger. Below 1 is
## still wider, for a set piece that wants one, so the mechanism is kept and only the
## value it is set to has changed.
##
## The introduction's own pull in on the boss - [member intro_zoom] - is untouched:
## that is framing the player is meant to notice, and it hands back to this the moment
## the fight begins.
@export var fight_zoom: float = 1.0
## How quickly the view crosses back out once the introduction is over.
@export var fight_zoom_speed: float = 2.2
## How much of the screen the walls are brought in by, in pixels, so a body pressed
## against one is fully inside the picture rather than half off it.
@export var wall_inset: float = 40.0
## How thick the walls are, in pixels. Thick enough that nothing at speed can be
## pushed through one in a single physics step.
@export var wall_thickness: float = 400.0
## Collision layer the walls sit on. 1 by default, which is the layer the arena's own
## bounds use and the layer both the player and the enemies collide with - so the
## fence needs no change to either of them.
@export_flags_2d_physics var wall_layer: int = 1
## How far inside the walls a body handed to [method admit] has to get before the
## fence is closed behind it, in pixels.
##
## It exists so the gate cannot shut on somebody standing in the doorway: a body
## judged "inside" the instant it crosses the wall's own centre line would still be
## overlapping the wall, and would be pushed straight back out by the solve on the
## next step. A clearance comfortably wider than a character means the wall is behind
## them by the time it starts applying to them.
@export var entry_clearance: float = 90.0

@export_group("Camera")
## Whether the camera's limits are taken over at all.
##
## [b]Off is an ordinary fight in the open, and it is what the mini boss uses.[/b] The
## camera is still handed back to the player by [method lock] and the view still crosses
## out to [member fight_zoom]; all that is left out is the pinning, so the player is
## followed through the boss fight exactly as they are followed through a round. On
## leaves the fixed screen this was first written for, for a set piece that wants one.
@export var locks_camera: bool = false
## Whether the picture is fenced.
##
## [b]It exists for the fixed screen and should go with it.[/b] The walls are what stops
## anybody walking out of a view that cannot follow them - so with the camera free they
## are no longer a fight held on screen, they are an invisible box in the middle of the
## desert that the player runs into for no reason they can see. The map's own bounds
## still hold the fight, which is what holds every other fight in the game.
##
## Reinforcements do not need it: [method admit] on an unfenced arena reports that there
## was nothing to let anybody through and they simply walk in.
##
## It is a flag of its own rather than a second reading of [member locks_camera] because
## the two are genuinely separable - an encounter that wants to hold the fight in one
## place while the camera roams is a coherent thing to ask for - but the pair of them is
## what "fixed screen" means, and they are meant to be turned on together.
@export var fences_area: bool = false

## The camera being driven, held only while something is in flight so a rebuilt world
## re-finds its own.
var _camera: CameraController
## The rectangle the fight happens in, once there is one.
var _area := Rect2()
var _locked: bool = false
var _introducing: bool = false
## The camera's own zoom speed, captured before anything here changes it, and the
## flag saying it has been. Both halves are needed because an encounter whose
## introduction could not play goes straight to [method lock] - so the capture cannot
## live in [method play_intro] alone or unlocking would hand the camera back a zoom
## speed of nothing.
var _zoom_speed_was: float = 0.0
var _zoom_speed_taken: bool = false
## The limits the camera had before the arena took them, put back on unlock.
var _limits_were := Vector4i.ZERO
var _walls: StaticBody2D
## Bodies currently being let in through the fence, watched until each is inside.
var _entering: Array[PhysicsBody2D] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# Nothing to run until there is a fence with somebody walking through it.
	set_physics_process(false)


## The arena this world fights bosses in, or null when it has none - which
## [MiniBossDirector] reads as "there is no fixed screen here" and runs the fight in
## the open arena instead.
static func get_active(from_node: Node) -> BossArena:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BossArena


func is_introducing() -> bool:
	return _introducing


func is_locked() -> bool:
	return _locked


## The rectangle the fight is being held in. Empty before [method lock].
func get_area() -> Rect2:
	return _area


## Hands the camera to [param subject] and pulls in on it, then reports itself done
## through [signal intro_finished] after [member intro_seconds].
##
## Returns whether an introduction actually started. False means there is no camera
## to move or nothing to move it to, and the caller should go straight to the fight -
## [b]an introduction that cannot play must never be the reason the encounter does not
## begin.[/b]
func play_intro(subject: Node2D) -> bool:
	if _introducing or subject == null or not is_instance_valid(subject):
		return false

	var camera := _resolve_camera()
	if camera == null:
		return false

	_introducing = true
	_take_zoom_speed(camera)
	camera.zoom_multiplier_speed = maxf(intro_zoom_speed, 0.01)
	camera.set_zoom_multiplier(intro_zoom)
	camera.follow(subject, maxf(intro_camera_speed, 0.01))

	_finish_intro_after(maxf(intro_seconds, 0.0))
	return true


## Ends the introduction now, wherever the camera had got to. For a boss that dies
## during it, a world being torn down, or a skip key later - the signal still arrives,
## so whatever was waiting on the introduction is never left waiting.
func end_intro() -> void:
	if not _introducing:
		return
	_introducing = false

	var camera := _resolve_camera()
	if camera != null and _zoom_speed_taken:
		# Put back before the fight's own zoom is asked for, so the crossing out to
		# [member fight_zoom] runs at the fight's speed rather than the cinematic's.
		camera.zoom_multiplier_speed = _zoom_speed_was

	intro_finished.emit()


## Nails the fight down around [param centre_node]: the camera given back to the
## player, taken out to [member fight_zoom], and then pinned to a rectangle the size
## of the screen - which is also the rectangle that gets fenced.
##
## Returns whether the arena was actually built. False means there was no camera to
## measure the screen against, and the caller carries on with a fight in the open
## desert rather than a fixed screen.
func lock(centre_node: Node2D) -> bool:
	if _locked:
		return false

	var camera := _resolve_camera()
	if camera == null or centre_node == null or not is_instance_valid(centre_node):
		return false

	# Released before the zoom is changed, so the camera is already heading home when
	# the view starts widening rather than doing both from the boss's position.
	camera.release_follow()
	_take_zoom_speed(camera)
	camera.zoom_multiplier_speed = maxf(fight_zoom_speed, 0.01)
	camera.set_zoom_multiplier(fight_zoom)

	# Measured at the zoom the fight will actually be at rather than at the one the
	# camera is easing through this frame, so the screen and the walls agree from the
	# first frame instead of settling into agreement.
	var size := camera.get_view_size_at(fight_zoom)
	_area = _held_in_play(Rect2(centre_node.global_position - size * 0.5, size), camera)
	_locked = true

	if locks_camera:
		_take_limits(camera)
	if fences_area:
		_build_walls()

	locked.emit(_area)
	return true


## The fight's rectangle with whatever hangs off the map trimmed away.
##
## [b]A fight near a wall is a smaller picture, not a picture with desert behind it.[/b]
## The rectangle is a screenful centred on the boss, and the boss can stand anywhere he
## fits - so up against an edge, a good part of that screenful is ground the player can
## never walk on. Everything that reads the arena reads this: crates dropped out towards
## its walls would be dropped behind the map's, and arrivals would be measured from a
## perimeter that is partly inside solid rock.
##
## The map's own extent is taken off the camera rather than off the spawner or the world
## - [CameraBounds] has already handed it the playable rectangle, so this needs nothing
## wired to it and cannot disagree with the limits the player is already being followed
## inside. A camera that has never been given limits carries enormous defaults, which
## trims nothing, which is the right answer for a world that never said how big it was.
func _held_in_play(area: Rect2, camera: CameraController) -> Rect2:
	var play := Rect2(
		float(camera.limit_left),
		float(camera.limit_top),
		float(camera.limit_right - camera.limit_left),
		float(camera.limit_bottom - camera.limit_top))
	if play.size.x <= 0.0 or play.size.y <= 0.0:
		return area

	var held := area.intersection(play)
	return area if held.size.x <= 0.0 or held.size.y <= 0.0 else held


## Lets [param body] in through the fence, and returns whether it needed letting in.
##
## [b]This is how anything arrives after the arena is locked.[/b] Reinforcements are
## spawned outside the picture on purpose - the brief asks for them to walk in rather
## than appear in the middle of the fight - and the walls that keep the fight on screen
## would otherwise keep them out of it. So the wall body is excepted for this one body,
## and the exception is dropped again by [method _physics_process] the moment it is
## properly inside, from which point it is held exactly as everybody else is.
##
## [b]It is an exception rather than a mask change[/b] because a mask change would take
## the body out of every wall in the world at once: an enemy let in that way would also
## be free of the map's own bounds while it walked. Excepting the one body it must pass
## through leaves every other collision it has exactly as it was.
##
## False means there was nothing to do - no fence, or a body already inside it - and is
## not a failure.
func admit(body: PhysicsBody2D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not _locked or _walls == null or not is_instance_valid(_walls):
		return false
	if _is_inside(body):
		return false
	if _entering.has(body):
		return true

	body.add_collision_exception_with(_walls)
	_entering.append(body)
	set_physics_process(true)
	return true


## Whether [param body] is far enough inside the walls for the fence to apply to it.
func _is_inside(body: Node2D) -> bool:
	if _area.size.x <= 0.0 or _area.size.y <= 0.0:
		return true
	var room := _area.grow(-(maxf(wall_inset, 0.0) + maxf(entry_clearance, 0.0)))
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		room = _area
	return room.has_point(body.global_position)


## Closes the fence behind everything that has finished walking in.
##
## Bodies that died on the way in are dropped without their exception being removed,
## because there is nothing left to remove it from - and the walls themselves are freed
## on unlock, which takes every exception still on them with it.
func _physics_process(_delta: float) -> void:
	for index: int in range(_entering.size() - 1, -1, -1):
		var body := _entering[index]
		if body == null or not is_instance_valid(body):
			_entering.remove_at(index)
			continue
		if not _is_inside(body):
			continue
		_close_fence_behind(body)
		_entering.remove_at(index)

	if _entering.is_empty():
		set_physics_process(false)


func _close_fence_behind(body: PhysicsBody2D) -> void:
	if _walls != null and is_instance_valid(_walls):
		body.remove_collision_exception_with(_walls)


## Gives the arena back: the camera returned to the player, the limits restored, the
## walls taken down and the view returned to an ordinary round's.
##
## [b]The follow is released whatever was holding it.[/b] The camera may well be on the
## boss rather than on the player when this arrives - it is during the fall [BossDefeat]
## plays over him, and it is again for an encounter torn down from the developer panel
## while the introduction is still running - and an arena handed back with the view
## still locked onto a body that is about to be freed is exactly the camera stranded in
## the middle of nowhere that this is meant to prevent. Releasing a camera that was
## already following the player does nothing, so being certain costs the ordinary path
## nothing.
##
## [BossDefeat] is what calls it when the man goes down, and the developer panel calls
## it to put a fresh encounter up. Both want the same thing, which is what keeps the
## lock something that can be lifted rather than a one-way change to the world.
func unlock() -> void:
	if not _locked:
		return
	_locked = false

	var camera := _resolve_camera()
	if camera != null:
		camera.release_follow()
		if locks_camera:
			camera.limit_left = _limits_were.x
			camera.limit_top = _limits_were.y
			camera.limit_right = _limits_were.z
			camera.limit_bottom = _limits_were.w
			camera.reset_smoothing()
		if _zoom_speed_taken:
			camera.zoom_multiplier_speed = _zoom_speed_was
			_zoom_speed_taken = false
		camera.set_zoom_multiplier(1.0)

	_drop_walls()
	unlocked.emit()


## Nothing is left locked behind us: a world torn down mid-fight - a death, a reload -
## would otherwise hand the next round a camera pinned to a rectangle in the middle of
## nowhere. The camera goes with the world, so only the tuning it carries has to be
## put back.
func _exit_tree() -> void:
	if _introducing:
		_introducing = false
	_drop_walls()


## The limits taken over, with what was there first written down so it can be given
## back.
##
## A rectangle exactly the size of the screen is what pins the camera: a [Camera2D]
## holds its view inside its limits, so a box it exactly fills has nowhere to move to.
## No smoothing has to be switched off and no follow refused - the clamp does all of
## it, and putting the numbers back is the whole of releasing it.
func _take_limits(camera: CameraController) -> void:
	_limits_were = Vector4i(
		camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)

	camera.limit_left = int(floor(_area.position.x))
	camera.limit_top = int(floor(_area.position.y))
	camera.limit_right = int(ceil(_area.end.x))
	camera.limit_bottom = int(ceil(_area.end.y))
	camera.reset_smoothing()


## Four static walls round the inside of the picture.
##
## They are ordinary collision rather than a clamp on each character, and that is the
## point: knockback, the separation steering and a retreat all keep behaving exactly
## as they do against the map's own walls, and a body added to the fight later is held
## without anything being told about it. The layer is the arena bounds' own, so
## neither the player's nor the enemy's mask needs touching.
func _build_walls() -> void:
	_drop_walls()
	if _area.size.x <= 0.0 or _area.size.y <= 0.0:
		return

	var inner := _area.grow(-maxf(wall_inset, 0.0))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		inner = _area

	_walls = StaticBody2D.new()
	_walls.name = "BossArenaWalls"
	_walls.collision_layer = wall_layer
	# Nothing is asked of the walls; they only have to be hit.
	_walls.collision_mask = 0
	add_child(_walls)
	# The rectangle is in world space and this node may sit anywhere, so the body is
	# put where the maths says rather than inheriting a parent's transform.
	_walls.global_position = Vector2.ZERO

	var thickness := maxf(wall_thickness, 8.0)
	var half := thickness * 0.5
	# Each wall is grown by the thickness along its own length so the corners meet
	# rather than leaving a gap a body could be squeezed out through.
	_add_wall(inner.get_center() - Vector2(0.0, inner.size.y * 0.5 + half),
		Vector2(inner.size.x + thickness * 2.0, thickness))
	_add_wall(inner.get_center() + Vector2(0.0, inner.size.y * 0.5 + half),
		Vector2(inner.size.x + thickness * 2.0, thickness))
	_add_wall(inner.get_center() - Vector2(inner.size.x * 0.5 + half, 0.0),
		Vector2(thickness, inner.size.y + thickness * 2.0))
	_add_wall(inner.get_center() + Vector2(inner.size.x * 0.5 + half, 0.0),
		Vector2(thickness, inner.size.y + thickness * 2.0))


func _add_wall(centre: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size

	var wall := CollisionShape2D.new()
	wall.shape = shape
	_walls.add_child(wall)
	wall.global_position = centre


## The fence comes down, and with it every exception against it - freeing the body the
## exceptions were registered on is what clears them, so nothing has to be walked back
## through one at a time. The watch list is emptied so a rebuilt fence starts with
## nobody in its doorway.
func _drop_walls() -> void:
	if _walls != null and is_instance_valid(_walls):
		_walls.queue_free()
	_walls = null
	_entering.clear()
	set_physics_process(false)


## The introduction's length, run on a timer rather than counted in
## [method Node._process] so this node has nothing to run between encounters.
##
## It ignores the world's time scale for the same reason
## [method CameraController._advance_follow] does: the introduction is meant to take
## two seconds of the player's time whatever the arena around it is doing.
func _finish_intro_after(seconds: float) -> void:
	if seconds <= 0.0:
		end_intro()
		return

	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(end_intro, CONNECT_ONE_SHOT)


## Writes the camera's own zoom speed down, once, so it can be handed back however
## the encounter ends and whichever of the two halves ran first.
func _take_zoom_speed(camera: CameraController) -> void:
	if _zoom_speed_taken:
		return
	_zoom_speed_taken = true
	_zoom_speed_was = camera.zoom_multiplier_speed


func _resolve_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
