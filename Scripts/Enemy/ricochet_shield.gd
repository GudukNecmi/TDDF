class_name RicochetShield
extends Area2D
## A round area that turns every shot reaching it back out the way it came in,
## hurting nothing.
##
## [b]It is a deflector, and the projectile already knows what those are.[/b]
## Anything a shot's sweep meets that answers [method take_projectile_hit] is
## offered the shot before any body behind it - see [method Projectile._sweep_to],
## which is how the thrown coin already splits a bullet off at an enemy. This one
## answers by reflecting the round off its own rim and handing it back to
## [method Projectile.ricochet], so the same round flies on with the same profile
## and simply never reaches whatever the circle surrounds.
##
## It has no size and no picture of its own: whoever raises it gives it a
## [CollisionShape2D] and puts it on the layer the shots look for - see
## [BossSwordStorm], whose sword circle is the one use today.

## Emitted for every shot turned away, with the shot and where it struck the rim.
## For a spark, a sound or a readout.
signal deflected(shot: Projectile, at: Vector2)

## How far either side of a clean reflection a ricochet is thrown, in degrees, so
## a stream of shots fired at the circle sprays off it rather than coming back in
## one line.
@export var scatter_degrees: float = 18.0


## A shot has reached the rim at [param at]. Answers true when it was turned away.
##
## [b]A shot already on its way out is let go.[/b] One fired from inside the
## circle, or one just turned back off it, is heading away from the centre - it is
## refused, which the projectile reads as "fly straight through", so nothing is
## ever turned back inwards.
func take_projectile_hit(shot: Projectile, at: Vector2) -> bool:
	if shot == null or not is_instance_valid(shot):
		return false

	var heading := shot.global_transform.x.normalized()
	var normal := at - global_position
	normal = -heading if normal.is_zero_approx() else normal.normalized()
	if heading.dot(normal) >= 0.0:
		return false

	var away := heading.bounce(normal).rotated(
		deg_to_rad(randf_range(-absf(scatter_degrees), absf(scatter_degrees))))
	if away.dot(normal) <= 0.0:
		away = normal

	shot.ricochet(away)
	deflected.emit(shot, at)
	return true
