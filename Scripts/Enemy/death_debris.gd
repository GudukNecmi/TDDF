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
var _still_age: float = 0.0


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
	_still_age = 0.0


func is_grounded() -> bool:
	return _grounded


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

	global_position.y = _rest_y
	if absf(_velocity.y) < min_bounce_speed:
		_velocity.y = 0.0
		_grounded = true
		return
	_velocity.y = -absf(_velocity.y) * bounce


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
