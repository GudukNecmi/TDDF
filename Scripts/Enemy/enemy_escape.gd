class_name EnemyEscape
extends Node
## What an enemy does when an encounter ends: it throws its knife down, turns its
## back and runs.
##
## [b]This is not a death, and none of the death happens.[/b] The old ending killed
## whatever was still standing - X marks over the eyes, a beat, smoke, a fade - and
## an enemy the player never beat was being played out as though they had. A retreat
## says the opposite thing: the enemy gives up and tries to get away.
##
## The beat is:
##
##   1. The knife hits the floor, thrown by the same code a death throws it with -
##      see [method EnemyHeadPop.drop_knife].
##   2. Its head and body turn away from the player. That is one flag on the aim
##      pivots it already has - see [member LookAtTarget.look_away] - so a retreat
##      faces the way it is running without a second way of aiming existing.
##   3. It heads away from the player at [member speed_multiplier] times its speed
##      and stops swinging, both of which are [method Enemy.begin_flight]'s.
##   4. Once it has been [b]completely off the screen[/b] for
##      [member offscreen_grace] seconds it is gone.
##
## [b]A running enemy is still a live enemy.[/b] It stays in the [code]enemies[/code]
## group with its hitboxes on their layer, so it can be shot, killed and looted
## exactly like one that never gave up - a retreat is a chance the player is being
## offered, not a body being taken off the table. Nothing here touches [Health], so
## a kill during a retreat runs the ordinary death and [BloodEmitter] spills the
## ordinary blood, because as far as either of them is concerned nothing unusual
## happened. See [member stays_killable] for the switch that takes that back off.
##
## [b]It is never removed while the player can still see it.[/b] Distance is not the
## test and deliberately cannot be: a player who chases a retreat keeps it on screen
## at whatever range, and an enemy popping out of existence in front of them is the
## one thing this must not do. So the question asked is the one the player is
## actually asking - is it still there - measured against the camera's own view, and
## it is the only question asked. A retreat that cannot get away - cornered against a
## wall with the player standing over it - simply stays there, because it is still
## killable and walking off is still what makes it run again, so neither of those is
## a reason to make it disappear. See [member max_escape_time] for the ceiling that
## exists for a fight that has to end on a schedule, and is off.
##
## [b]An enemy that gives up stops being one that got away.[/b] A retreat can be
## broken mid-stride by a shot going off beside it, and from that moment the enemy
## belongs to [EnemySurrender] rather than to this - so surrendering calls the
## retreat off through [method cancel] and the removal below stops applying to it
## entirely. A man lying on the floor waiting to be spoken to is not something that
## can be allowed to vanish behind the camera.
##
## The check itself is deliberately cheap and deliberately not every frame. A whole
## arena's worth of enemies leaving at once should cost nothing to supervise, so
## each one tests its own rectangle a few times a second, with no search and no
## allocation - see [member check_interval].

## Emitted as the enemy turns and runs, not when it finally disappears.
signal escaped
## Emitted as it is removed, so anything counting bodies can stop counting this one.
signal escape_finished

## The enemy's own knife-thrower, borrowed to put the knife on the floor. Optional -
## an enemy without one simply runs empty-handed.
@export var head_pop_path: NodePath = ^"../HeadPop"
## Whether the knife is thrown down as the retreat begins.
@export var drops_knife: bool = true

@export_group("Retreat")
## How much faster than usual the enemy runs away.
##
## Above 1 on purpose: a retreat has to visibly break off rather than back away at
## walking pace. It is no longer a way of putting the enemy out of reach - it is
## killable the whole way out - so this is how the escape [i]reads[/i] rather than
## how hard it is to catch.
@export var speed_multiplier: float = 2.0
## Whether the enemy's head and body turn away from the player as it runs.
##
## On. Every aim pivot underneath the enemy is flipped to
## [member LookAtTarget.look_away], so this reaches the head, the knife hand and
## anything a future enemy aims with, without any of them being named here.
@export var turns_away: bool = true

@export_group("Leaving")
## How long the enemy has to have been completely off the screen before it is
## removed, in seconds.
##
## [b]This is the whole of when a retreat disappears.[/b] The grace is what stops an
## enemy blinking out at the instant it crosses the edge, which reads as a bug even
## though the player cannot see it happen; it also means an enemy that clips back
## into view - the player turning, the camera swinging - starts the wait again
## rather than being removed a frame later.
@export var offscreen_grace: float = 2.0
## How far past the edge of the screen the enemy's artwork has to be before it
## counts as off it, in pixels. Extra insurance on top of the extent below; 0 takes
## the edge of the screen literally.
@export var screen_margin: float = 8.0
## How far the enemy's artwork reaches from its origin, which stands at its feet:
## x sideways, y upwards.
##
## The same measurement [member EnemySpawner.enemy_art_extent] makes for the
## opposite reason - it is what an enemy has to clear to arrive unseen - so an enemy
## leaves the screen by the same rule it came in past.
@export var art_extent := Vector2(60.0, 90.0)
## Longest a retreat may last before the enemy is removed wherever it has got to,
## in seconds. [b]0 - the default - is no ceiling at all.[/b]
##
## Off, because it is the one thing here that could take an enemy the player is
## still looking at, and a retreat vanishing in plain sight is exactly what the
## screen test above exists to prevent. It is kept rather than deleted because it is
## the right tool for a fight that must end on a schedule whatever is left standing,
## and because it is the only answer to a retreat that can never leave the screen -
## but that case has an answer already, and it is a better one: a fleeing enemy is
## still killable, so a player who has cornered one can simply shoot it, and one who
## walks away is no longer something for it to run from.
@export var max_escape_time: float = 0.0
## How often the screen test is actually made, in seconds. Rarely, because a
## fleeing enemy covers a lot of ground between checks and being removed a fraction
## of a second late off the edge of the screen is invisible - while testing every
## frame for every enemy is not free.
@export var check_interval: float = 0.2

@export_group("Untouchable")
## Whether a fleeing enemy can still be shot, killed and looted.
##
## [b]On, and that is the point of the state.[/b] The player is offered a last few
## seconds to take what is running away from them, and an enemy killed during its
## retreat pays exactly what it would have paid standing still.
##
## Off restores the older behaviour, in which the retreat was untouchable: the enemy
## leaves the [code]enemies[/code] group - which alone is what makes every search in
## the game stop finding it - and the regions below come off their collision layer
## so a shot already in the air passes through. That is kept rather than deleted
## because it is the right answer for an enemy that is meant to be gone the moment
## it turns, and it is one tick in the inspector.
@export var stays_killable: bool = true
## The enemy's damageable regions, taken off their collision layer when
## [member stays_killable] is off. Every [Hitbox] on the enemy belongs here.
@export var hitbox_paths: Array[NodePath] = [^"../BodyHitbox", ^"../HeadHitbox"]
## Whether an untouchable enemy's body still collides with the world and with the
## player while it runs. On, so a retreat walks round scenery rather than through
## it - it is the *damage* that is switched off, not the physics.
@export var keeps_body_collision: bool = true

@onready var _head_pop: EnemyHeadPop = get_node_or_null(head_pop_path) as EnemyHeadPop

var _escaping: bool = false
## Whether the retreat has been called off for good - see [method cancel].
var _cancelled: bool = false
var _age: float = 0.0
var _since_check: float = 0.0
## How long the enemy has been continuously off the screen. Reset to zero the
## moment any part of it comes back into view, which is what makes the grace a
## grace rather than a countdown that survives being looked at.
var _unseen: float = 0.0


func _ready() -> void:
	# Nothing to supervise until there is a retreat to supervise.
	set_physics_process(false)


func is_escaping() -> bool:
	return _escaping


## Sends this enemy home. [param delay] staggers it, so a whole arena called at once
## leaves as a ripple rather than in a single frame.
##
## Guarded, so a second call cannot restart a retreat already under way.
func escape(delay: float = 0.0) -> void:
	if _escaping or _cancelled:
		return
	_escaping = true

	if delay > 0.0:
		var wait := get_tree().create_timer(delay, true, false, true)
		wait.timeout.connect(_begin)
		return
	_begin()


## Calls the retreat off and leaves the enemy exactly where it is - for good.
##
## [b]This is what surrendering does to a retreat.[/b] An enemy can be running
## already when a shot goes off beside it and its nerve goes: from that moment it
## is a man on the floor rather than a man getting away, and the screen test above
## must stop applying to it. [EnemySurrender] is explicit that such an enemy stays
## in the world until the player deals with it one way or the other - talks to it
## or shoots it - so a surrendered enemy that happened to be mid-retreat must not
## quietly disappear two seconds after the camera loses sight of it.
##
## The supervision is refused rather than merely suspended, which is what makes it
## survive a staggered [method escape] whose timer has not fired yet: a retreat
## called off before it has visibly begun never begins.
func cancel() -> void:
	if _cancelled:
		return
	_cancelled = true
	set_physics_process(false)


## Whether this enemy's retreat has been called off.
func is_cancelled() -> bool:
	return _cancelled


func _begin() -> void:
	if _cancelled or not is_inside_tree():
		return

	var host := get_parent()
	if host == null:
		return

	_leave_the_fight(host)
	if drops_knife and _head_pop != null:
		_head_pop.drop_knife()
	if turns_away:
		_turn_away(host)

	if host.has_method(&"begin_flight"):
		host.call(&"begin_flight", speed_multiplier)

	_age = 0.0
	_since_check = 0.0
	_unseen = 0.0
	set_physics_process(true)
	escaped.emit()


## Turns the enemy's back on the player.
##
## Found by type rather than by path, for the reason every other component here is:
## an enemy that aims with more pivots, or keeps them somewhere else, still turns
## round, and nothing about which parts an enemy has is written down twice.
func _turn_away(host: Node) -> void:
	for node: Node in host.find_children("*", "LookAtTarget", true, false):
		var aim := node as LookAtTarget
		if aim != null:
			aim.look_away = true


## Takes the enemy off the board, and only when it has been asked for.
##
## The two halves are separate on purpose: the group is what everything that
## *searches* for enemies reads, and the collision layer is what a shot already in
## the air runs into. One without the other leaves a hole - a bullet mid-flight
## would still land, or a coin would still be sent at a body that cannot be hurt.
func _leave_the_fight(host: Node) -> void:
	if stays_killable:
		return

	if host.is_in_group(EnemyTargeting.ENEMY_GROUP):
		host.remove_from_group(EnemyTargeting.ENEMY_GROUP)

	for path: NodePath in hitbox_paths:
		var region := get_node_or_null(path) as Area2D
		if region == null:
			continue
		# Layer cleared rather than the node disabled, so nothing has to be put back
		# and no signal is left half-connected. A region on no layer is a region no
		# ray and no overlap can find.
		region.collision_layer = 0
		region.set_deferred(&"monitorable", false)

	if not keeps_body_collision and host is CollisionObject2D:
		var body := host as CollisionObject2D
		body.set_deferred(&"collision_layer", 0)
		body.set_deferred(&"collision_mask", 0)


## Watches the screen and removes the enemy once it has been off it long enough to
## stop mattering. Cheap by construction: two rectangles and no lookups.
##
## Nothing here has to guard against the enemy being killed part way through. A
## death freezes every component on the body - see [method DeathFade._freeze] - so
## this stops running on the frame the enemy dies and the corpse is freed by the
## fade that owns it, exactly as any other corpse is.
func _physics_process(delta: float) -> void:
	_age += delta

	_since_check += delta
	if _since_check < check_interval:
		return
	var elapsed := _since_check
	_since_check = 0.0

	var host := get_parent() as Node2D
	if host == null:
		_finish()
		return

	if _is_off_screen(host):
		_unseen += elapsed
		if _unseen >= offscreen_grace:
			_finish()
			return
	else:
		_unseen = 0.0

	# Last, and after the screen test, so an enemy that is about to be removed for
	# the right reason is removed for the right reason.
	if max_escape_time > 0.0 and _age >= max_escape_time:
		_finish()


## Whether none of the enemy's artwork is on the screen any more.
##
## The enemy is measured as the rectangle its art actually occupies rather than as
## the point it stands on, because its origin is at its feet: an enemy whose origin
## has just crossed the top edge is still showing its whole body.
func _is_off_screen(host: Node2D) -> bool:
	var at := host.global_position
	var art := Rect2(
		at.x - absf(art_extent.x), at.y - absf(art_extent.y),
		absf(art_extent.x) * 2.0, absf(art_extent.y))
	return not _view_rect().grow(maxf(screen_margin, 0.0)).intersects(art)


## The camera's visible rectangle in world space, read the same way
## [method EnemySpawner.get_view_rect] reads it - off the camera's own screen
## centre, so position smoothing and limits are already accounted for.
##
## A world with no camera falls back to a viewport-sized box at the origin, which
## keeps this answering something sensible in a scene opened on its own.
func _view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()

	var viewport_size := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2(-viewport_size * 0.5, viewport_size)

	var size := viewport_size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)


## Gone, and gone quietly. No death, no blood, no kill - the enemy that got away is
## simply not there any more, which is what getting away means. An enemy the player
## caught never reaches here at all; it dies.
func _finish() -> void:
	set_physics_process(false)
	escape_finished.emit()

	var host := get_parent()
	if host != null:
		host.queue_free()
