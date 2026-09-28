class_name FanHammer
extends Resource
## A pump weapon worked with the trigger held: one pump press runs the whole
## cycle and the held trigger drops the hammer as the action closes - the part
## behind the shotgun's Legendary FAN THE HAMMER.
##
## [b]It adds no pump, no ammunition and no second stat system.[/b] The weapon
## runs its own two strokes back to back through the code every other pump goes
## through, so each shot still spends a real shell and a live round worked out
## still costs what it always did. What it adds is speed, paid for in control:
## every fanned shot builds [i]heat[/i], 0..1, and the heat is read as
##
##   * extra spread - [constant WeaponStats.Stat.SPREAD] added to a copy of the
##     weapon's block for the next shot only, so the weapon's own spread is never
##     touched and accuracy upgrades still tighten the cone underneath it;
##   * slower aim - [member CarriedWeapon.aim_scale];
##   * a random throw of the aim after each shot.
##
## Heat drains quickly once the firing stops. A weapon reads it off
## [member WeaponStats.fan_hammer] - put there by a [WeaponLegendary] - and keeps
## the heat itself; see [Shotgun]. Nothing here names a weapon.

@export_group("Action")
## Whether the held trigger fires on its own as the fanned action closes. On: hold
## the trigger and every pump press is a shot. Off: the press only makes the
## weapon ready, and the trigger has to be pulled again.
@export var held_trigger_fires: bool = true
## How long after the action closes the held trigger drops the hammer, in seconds,
## so the chambering is heard a hair before the blast. 0 is the same frame.
@export_range(0.0, 0.3, 0.005) var hammer_delay: float = 0.035
## How long the fore-end takes to go back and to come home on a fanned stroke.
## Faster than an ordinary stroke - it is one slam, not two presses.
@export var stroke_back_time: float = 0.035
@export var stroke_forward_time: float = 0.05

@export_group("Heat")
## Heat one fanned shot adds. 0.34 is full heat on the third shot in a row.
@export_range(0.0, 1.0, 0.01) var heat_per_shot: float = 0.34
## How long heat is held after a fanned shot before it starts to drain.
@export var recovery_delay: float = 0.12
## Heat drained per second once it does. 4 empties full heat in a quarter second.
@export var recovery_rate: float = 4.0

@export_group("Penalties at full heat")
## Spread added at full heat, as a fraction of the weapon's authored cone - see
## [constant WeaponStats.Stat.SPREAD]. 0.35 is a cone 35% of the authored width
## wider.
@export var spread_at_max: float = 0.35
## What the weapon's aim speed is multiplied by at full heat - see
## [member CarriedWeapon.aim_scale]. 1 changes nothing.
@export_range(0.05, 1.0, 0.01) var aim_responsiveness_at_max: float = 0.45
## The random throw of the aim after a fanned shot, in degrees either way, at no
## heat and at full. The weapon then turns back to the cursor at its slowed speed.
@export var aim_kick_degrees_min: float = 1.5
@export var aim_kick_degrees_max: float = 4.5


## Heat after one more fanned shot on top of [param heat].
func heat_after_shot(heat: float) -> float:
	return clampf(heat + heat_per_shot, 0.0, 1.0)


## Heat [param delta] seconds on, [param since_shot] seconds after the last shot.
func cooled(heat: float, since_shot: float, delta: float) -> float:
	if since_shot < recovery_delay:
		return heat
	return maxf(heat - recovery_rate * delta, 0.0)


## A copy of [param stats] with the spread of [param heat] folded in - the block
## the next shot leaves with. [param stats] itself is never touched. With no heat
## it is handed back as it came.
func unsteady_stats(stats: WeaponStats, heat: float) -> WeaponStats:
	if heat <= 0.0 or is_zero_approx(spread_at_max):
		return stats
	var copy := stats.duplicate_stats()
	copy.add(WeaponStats.Stat.SPREAD, spread_at_max * heat)
	return copy


func aim_scale_at(heat: float) -> float:
	return lerpf(1.0, aim_responsiveness_at_max, clampf(heat, 0.0, 1.0))


func aim_kick_at(heat: float) -> float:
	return lerpf(aim_kick_degrees_min, aim_kick_degrees_max, clampf(heat, 0.0, 1.0))
