class_name Casing
extends Node2D
## One ejected shotgun shell. Thrown out to the side of the barrel, pulled down,
## then it settles on the ground and fades away.
##
## Purely cosmetic: it has no collision shape and no physics body, so it can
## never touch the player, an enemy or a pellet. The "ground" is simply a short
## drop below wherever it was ejected - enough to read as falling in a top-down
## view without pretending the game has a third axis.

## Sideways speed it is flung out at.
@export var eject_speed_min: float = 90.0
@export var eject_speed_max: float = 190.0
## Upward kick, so the shells arc instead of sliding straight out.
@export var lift_min: float = 120.0
@export var lift_max: float = 230.0
## Downward pull.
@export var gravity: float = 900.0
## How far below the ejection point a shell comes to rest.
@export var drop_min: float = 26.0
@export var drop_max: float = 58.0
## Tumble rate, in degrees per second, either way.
@export var spin_degrees: float = 720.0
## How long it lies still before it starts to fade. The shell's whole lifetime on
## the ground is this plus [member fade_time], and lengthening this is what leaves
## spent shells lying around the arena rather than blinking out from under the
## player's feet - the fall, the tumble and the fade itself are untouched by it.
@export var settle_time: float = 4.45
## How long the fade itself takes.
@export var fade_time: float = 0.3

var _velocity := Vector2.ZERO
var _spin: float = 0.0
var _rest_y: float = 0.0
var _settled: bool = false
var _settled_age: float = 0.0


## Throws the shell clear of the weapon. [param facing] is the direction the
## barrel points, so shells always leave sideways relative to the gun rather
## than in a fixed screen direction. Call this after placing the shell.
func launch(facing: Vector2) -> void:
	var aim := facing
	if aim.is_zero_approx():
		aim = Vector2.RIGHT
	aim = aim.normalized()

	# Perpendicular to the barrel, flipped at random so the two shells of one
	# shot rarely leave on the same side.
	var side := Vector2(-aim.y, aim.x)
	if randf() < 0.5:
		side = -side

	_velocity = side * randf_range(eject_speed_min, eject_speed_max)
	_velocity += -aim * randf_range(10.0, 50.0)
	_velocity.y -= randf_range(lift_min, lift_max)

	_spin = deg_to_rad(randf_range(-spin_degrees, spin_degrees))
	_rest_y = global_position.y + randf_range(drop_min, drop_max)


func _physics_process(delta: float) -> void:
	if not _settled:
		_velocity.y += gravity * delta
		global_position += _velocity * delta
		rotation += _spin * delta

		if global_position.y >= _rest_y:
			global_position.y = _rest_y
			_settled = true
		return

	_settled_age += delta
	if _settled_age < settle_time:
		return

	var t := clampf((_settled_age - settle_time) / maxf(fade_time, 0.001), 0.0, 1.0)
	modulate.a = 1.0 - t
	if t >= 1.0:
		queue_free()
