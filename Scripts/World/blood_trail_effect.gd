class_name BloodTrailEffect
extends Node2D
## A drifting hint of blood that leans toward an active bounty boss without
## ever drawing a line to him.
##
## [b]It is a hint, not GPS[/b] - rule 12 of the bounty camps phase, word for
## word. This node is anchored on the player rather than stretched between
## the player and the target, and its particles are only ever nudged toward
## the target's bearing with a wide spread and a short lifetime - never a
## beam, never a raycast through the world's own geometry, and never shown
## at all past [WorldBountyBossDirector]'s own trail radius. Because it never
## reaches further than that short radius from the player, it cannot draw
## through ground the player has not stood near - see rule 14 - without
## having to sample the fog grid particle by particle.
##
## [b]It decides nothing.[/b] [WorldBountyBossDirector] is the only thing
## that calls [method set_active] or [method configure]; every condition in
## rule 12 - carrying the right poster, the right region and hour, being
## close enough - is checked there. This file only ever turns "point here,
## this strongly" into particles.
##
## [b]It borrows the game's own blood.[/b] The colour ramp below is the same
## dark-red-to-nothing gradient [code]BloodSplash.tscn[/code] fades a hit
## through, so a trail on the World Map reads as blood rather than as a new
## visual language invented for it.

## Particles emitted per second at the weakest the trail is ever shown.
@export var base_amount: int = 8
## Particles emitted per second right on top of the target.
@export var max_amount: int = 30
@export var lifetime: float = 1.3
## How wide a cone the particles drift out in around the target's own
## bearing - wide, on purpose, so this never reads as an arrow.
@export var spread_degrees: float = 48.0
@export var min_alpha: float = 0.1
@export var max_alpha: float = 0.85
@export var min_speed: float = 26.0
@export var max_speed: float = 85.0

var _particles: CPUParticles2D
var _active: bool = false


func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.name = "Particles"
	_particles.emitting = false
	_particles.amount = maxi(max_amount, 1)
	_particles.lifetime = maxf(lifetime, 0.05)
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.65
	_particles.gravity = Vector2.ZERO
	_particles.damping_min = 0.3
	_particles.damping_max = 0.9
	_particles.scale_amount_min = 1.1
	_particles.scale_amount_max = 2.8

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.62, 0.07, 0.06, 1.0),
		Color(0.4, 0.03, 0.04, 0.85),
		Color(0.22, 0.01, 0.02, 0.0),
	])
	_particles.color_ramp = gradient
	add_child(_particles)


## Turns the trail on or off outright. Called every tick by
## [WorldBountyBossDirector]; a caller that stops calling [method configure]
## while this is on simply leaves the last direction and intensity drifting,
## so the director always follows a [code]set_active(false)[/code] the moment
## any one of rule 12's conditions stops holding.
func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	_particles.emitting = value


## Points the trail at [param to] from [param from], leaning harder the
## closer [param distance] is to 0 and fading toward nothing as it
## approaches [param max_distance] - rule 13's "distance-based intensity",
## worked the same direction that rule states it: closer is stronger.
func configure(from: Vector2, to: Vector2, distance: float, max_distance: float) -> void:
	if not _active:
		return

	global_position = from

	var direction := from.direction_to(to)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	_particles.direction = direction
	_particles.spread = spread_degrees

	var intensity := 1.0 - clampf(distance / maxf(max_distance, 1.0), 0.0, 1.0)
	_particles.amount = clampi(roundi(lerpf(float(base_amount), float(max_amount), intensity)), 1, maxi(max_amount, 1))
	var speed := lerpf(min_speed, max_speed, intensity)
	_particles.initial_velocity_min = speed * 0.6
	_particles.initial_velocity_max = speed
	modulate.a = lerpf(min_alpha, max_alpha, intensity)
