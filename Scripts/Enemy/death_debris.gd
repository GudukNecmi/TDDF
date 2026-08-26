class_name DeathDebris
extends Node2D
## A piece of an enemy after it has come off: a head, a dropped knife - anything
## thrown clear of a body, tumbling and rolling to a stop.
##
## It is a plain node running a few lines of arithmetic, not a physics body: no
## shape, no collisions, no queries. It cannot touch the player, an enemy or a
## pellet, and a screenful of them costs nothing. That is deliberate - the effect
## wanted here is *weight*, and weight is sold by a bounce and a roll, not by a
## simulation.
##
## The "ground" is a short drop below wherever the piece separated, the same trick
## [Casing] uses for spent shells: enough to read as falling in a top-down view
## without the game pretending it has a third axis. Once it is down it keeps its
## sideways speed and rolls, spinning at a rate tied to how fast it is still
## travelling, until friction stops it.
##
## Nothing about the enemy is referenced here. [EnemyHeadPop] tears the artwork
## off, hands it to one of these, and this owns it from that moment on - which is
## why the pieces outlive the body they came from and can still be rolling after
## the corpse itself has been freed.

## Emitted every time this piece touches the ground: once as it first arrives, and
## again on each bounce after that. [param impact_speed] is how hard it came down,
## in pixels per second, and [param first_touch] is true only for the arrival.
##
## [b]Nothing here decides what a landing sounds or looks like.[/b] The piece only
## says that it happened and where; whoever threw it is what knows whether that is
## a lump of gore hitting the sand or a knife - see [member Explosion.gore_impact_sounds]
## - so one signal serves every kind of debris the game throws. It stops for good
## once the piece has settled, so a piece lying still is silent by construction
## rather than by a guard at the other end.
signal landed(at: Vector2, impact_speed: float, first_touch: bool)

## Downward pull while airborne.
@export var gravity: float = 1500.0
## How much of its speed a bounce keeps. 0 lands dead, 1 never settles.
@export_range(0.0, 1.0) var bounce: float = 0.42
## Below this vertical speed a bounce is not worth playing and the head simply
## lands.
@export var min_bounce_speed: float = 90.0
## How quickly the roll bleeds off once it is on the ground, per second.
@export var ground_friction: float = 2.6
## How quickly it slows while still in the air.
@export var air_drag: float = 0.35
## Below this sideways speed the head is considered stopped.
@export var stop_speed: float = 8.0

@export_group("Spin")
## How fast it turns per pixel per second of sideways travel, in degrees. This is
## what makes the head look like it is rolling rather than sliding.
@export var spin_per_speed: float = 1.6
## Ceiling on that, in degrees per second.
@export var max_spin_degrees: float = 900.0
## How much of the spin survives once it has stopped moving, so it settles rather
## than freezing mid-turn.
@export var spin_settle: float = 6.0

@export_group("Lifetime")
## How long it lies still before it starts to fade.
@export var settle_time: float = 2.2
## How long the fade itself takes. 0 leaves the head on the ground for good.
@export var fade_time: float = 1.2

var _velocity := Vector2.ZERO
var _spin: float = 0.0
var _rest_y: float = 0.0
var _grounded: bool = false
## Whether it has ever reached the ground line, so the arrival can be told from the
## bounces that follow it.
var _touched_down: bool = false
var _still_age: float = 0.0
## Whether it has been thrown yet, so the frame between being placed and being
## launched does not report a ground line it has not been given.
var _launched: bool = false


## Joined so that anything hanging off this piece stands where the piece stands.
##
## [b]It is how a part torn off a body becomes an object in its own right.[/b] A
## [ShadowCaster] that came along with the artwork asks what it is attached to
## every time the tree changes under it; while the head was on the body the answer
## was the body, and now that it is rolling across the sand the answer is this. No
## code anywhere says "head", and nothing had to be told the separation happened.
func _ready() -> void:
	add_to_group(&"shadow_ground_root")


## Throws the piece. [param velocity] is its starting speed in pixels per second
## and [param drop] is how far below its starting point the ground is.
##
## Called after the piece has been placed, for the same reason a particle burst is
## started after being placed: everything here is measured from where it is
## standing the moment it is launched.
func launch(velocity: Vector2, drop: float) -> void:
	_velocity = velocity
	_rest_y = global_position.y + maxf(drop, 0.0)
	_grounded = false
	_touched_down = false
	_still_age = 0.0
	_launched = true


func is_grounded() -> bool:
	return _grounded


## Where this piece is standing on the arena floor - the line it will land on, not
## the point it is currently drawn at.
##
## The two are different for exactly as long as it is in the air, and keeping them
## apart is what lets the sun light a bouncing head the same way it lights a man
## walking: the mark stays on the floor underneath while the artwork travels above
## it. Read by [ShadowCaster] through
## [member ShadowCaster.ground_position_method]; any node that answers it qualifies.
func get_shadow_ground_position() -> Vector2:
	if not _launched:
		return global_position
	return Vector2(global_position.x, maxf(_rest_y, global_position.y))


## How far above that floor the piece is drawn right now, in world pixels. Zero
## once it is down, so its shadow settles under it without a landing callback.
func get_visual_height() -> float:
	if not _launched:
		return 0.0
	return maxf(_rest_y - global_position.y, 0.0)


func _physics_process(delta: float) -> void:
	if _grounded:
		_roll(delta)
	else:
		_fall(delta)

	rotation += _spin * delta
	_age(delta)


## Ballistic until it reaches the ground line, then it bounces - keeping a
## fraction of whatever it arrived with - until a bounce is too small to be worth
## playing, at which point it is simply down.
func _fall(delta: float) -> void:
	_velocity.y += gravity * delta
	_velocity.x = move_toward(_velocity.x, 0.0, air_drag * absf(_velocity.x) * delta)
	global_position += _velocity * delta
	_apply_spin()

	if global_position.y < _rest_y:
		return

	var came_down := absf(_velocity.y)
	var first_touch := not _touched_down
	_touched_down = true

	global_position.y = _rest_y
	if came_down < min_bounce_speed:
		_velocity.y = 0.0
		_grounded = true
		landed.emit(global_position, came_down, first_touch)
		return
	_velocity.y = -came_down * bounce
	landed.emit(global_position, came_down, first_touch)


## Down and rolling: it keeps its sideways speed, loses it to friction, and its
## spin follows that speed exactly - so the piece visibly stops turning as it
## stops travelling instead of the two drifting apart.
func _roll(delta: float) -> void:
	_velocity.y = 0.0
	_velocity.x = move_toward(_velocity.x, 0.0, ground_friction * absf(_velocity.x) * delta)
	if absf(_velocity.x) < stop_speed:
		_velocity.x = 0.0

	global_position.x += _velocity.x * delta

	if is_zero_approx(_velocity.x):
		_spin = lerpf(_spin, 0.0, 1.0 - exp(-spin_settle * delta))
		return
	_apply_spin()


func _apply_spin() -> void:
	var wanted := deg_to_rad(clampf(
		_velocity.x * spin_per_speed, -max_spin_degrees, max_spin_degrees))
	_spin = wanted


## Only a piece that has actually come to rest starts ageing, so one that is still
## rolling is never cut short by its own timer.
func _age(delta: float) -> void:
	if not _grounded or not is_zero_approx(_velocity.x):
		return

	_still_age += delta
	if _still_age < settle_time or fade_time <= 0.0:
		return

	var t := clampf((_still_age - settle_time) / fade_time, 0.0, 1.0)
	modulate.a = 1.0 - t
	if t >= 1.0:
		queue_free()
