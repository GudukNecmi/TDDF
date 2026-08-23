class_name ProjectileProfile
extends Resource
## Everything about a pellet that changes with distance, in one place.
##
## [member effective_range] is the single value the whole progression is built
## on. A pellet works out one normalised number per frame -
## `travelled / effective_range`, clamped to 0..1 - and every distance-driven
## effect is sampled from that same number:
##
##   * how much damage it still carries
##   * how fast it is still flying
##   * what colour it has burned down to
##   * how strong its glow is
##   * how far and how brightly it still lights the ground
##
## There is deliberately no second notion of range anywhere. Raising
## [member effective_range] pushes out where damage drops, where the pellet
## slows, where the colour dies and where the light fades, all together, and the
## pellet's despawn distance moves with them. An upgrade only ever has to touch
## this resource - ideally only this one field.

## THE master value: how far a pellet reaches, in pixels. It is spent the moment
## it has travelled this far, so it can never fly on indefinitely.
@export var effective_range: float = 420.0
## Hard safety cut-off in seconds. Nothing should ever reach it - the range
## check retires a pellet first - but it guarantees a pellet cannot live forever
## even if its speed were ever configured down to nothing.
@export var max_lifetime: float = 3.0

@export_group("Damage")
## Damage at the muzzle, before the hitbox's own multiplier.
@export var damage_near: float = 120.0
## Damage left at the very end of the range.
@export var damage_far: float = 5.0
## Shapes the drop across the progression. Below 1 bleeds damage off early and
## steeply, which is what makes the shotgun a close-range weapon.
@export var damage_exponent: float = 0.55

@export_group("Speed")
## Speed at the muzzle, in pixels per second.
@export var speed_near: float = 900.0
## Speed at the end of the range. Kept above zero so a pellet always reaches the
## end of its range and retires itself.
@export var speed_far: float = 320.0
## Above 1 holds full speed longer, then drops late.
@export var speed_exponent: float = 1.35

@export_group("Colour and glow")
## Colour at the muzzle - a hot, vivid dark red.
@export var color_near := Color(0.85, 0.10, 0.05)
## Colour it has burned down to by the end of its flight.
@export var color_far := Color(0.09, 0.01, 0.01)
## Brightness of the additive glow sprite at the muzzle. Deliberately modest -
## the pellet should read as hot, not wash the screen out.
@export var glow_near: float = 0.85
## Glow left at the end of the range.
@export var glow_far: float = 0.0
## Above 1 makes the glow die back quickly after leaving the barrel.
@export var glow_exponent: float = 1.6

@export_group("Light")
## Light energy at the muzzle.
@export var light_energy_near: float = 1.1
## Light energy at the end of the range.
@export var light_energy_far: float = 0.0
## Light radius multiplier at the muzzle.
@export var light_scale_near: float = 1.0
## Light radius multiplier at the end of the range.
@export var light_scale_far: float = 0.3
## Above 1 makes the light shrink away quickly.
@export var light_exponent: float = 1.4


## Converts a raw travelled distance into the shared 0..1 progression every
## other method on this profile expects. This is the only place the division
## happens.
func progress_for(travelled: float) -> float:
	return clampf(travelled / maxf(effective_range, 0.001), 0.0, 1.0)


func damage_at(progress: float) -> float:
	return lerpf(damage_near, damage_far, _shape(progress, damage_exponent))


func speed_at(progress: float) -> float:
	return lerpf(speed_near, maxf(speed_far, 1.0), _shape(progress, speed_exponent))


func color_at(progress: float) -> Color:
	return color_near.lerp(color_far, _shape(progress, 1.0))


func glow_at(progress: float) -> float:
	return lerpf(glow_near, glow_far, _shape(progress, glow_exponent))


func light_energy_at(progress: float) -> float:
	return lerpf(light_energy_near, light_energy_far, _shape(progress, light_exponent))


func light_scale_at(progress: float) -> float:
	return lerpf(light_scale_near, light_scale_far, _shape(progress, light_exponent))


## Bends the shared progression without changing what it means. Each effect gets
## its own curve shape, but they are all reading the same underlying number.
func _shape(progress: float, exponent: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if is_equal_approx(exponent, 1.0):
		return p
	return pow(p, maxf(exponent, 0.001))
