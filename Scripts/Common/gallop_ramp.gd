class_name GallopRamp
extends RefCounted
## One rider's gallop: how loud and how fast the loop plays for a horse moving
## at a given speed, and how it eases from one speed to the next.
##
## [b]This is the player's own gallop behaviour, lifted out so there is one of
## it.[/b] Every number and every curve here came from [WorldMapHorseGallop],
## which now drives its loop through this rather than keeping its own copy - so
## the World Map's bandits gallop the way the player's horse does because they
## are running the same ramp, not because two files were tuned to agree. See
## [WorldBanditGallopDirector] for the other caller.
##
## [b]Acceleration and the gallop are the same clock.[/b] [member speed] eases
## toward whatever speed it is handed over [member acceleration_duration]
## rising and [member deceleration_duration] falling, and both [method level]
## and [method pitch] are read straight off that one eased number. That is what
## keeps volume and playback rate synchronized rather than two timers that
## happen to agree today, and it is the whole of "starts softly, smoothly
## accelerates, smoothly slows when movement stops, no abrupt start or stop":
## a rider that stops dead still takes [member deceleration_duration] to fall
## silent, because the number the sound is read off does.
##
## Owned by whatever is making the noise - one of these per voice, not one per
## game - and holding no node, no stream and no bus. It decides what a gallop
## should sound like; it never plays anything.

## The speed an ordinary, unhurried gallop is heard at, in pixels per second.
## [method level] reaches 1 here and [method pitch] is
## [member normal_playback_rate] here.
var walk_speed: float = 0.0
## The speed a full sprint is heard at, in pixels per second - where
## [method pitch] reaches [member sprint_playback_rate]. Never louder than
## [member walk_speed] already is; reaching a sprint changes the rate, not the
## level.
var run_speed: float = 0.0

## How long the climb from a standstill to whatever speed is being asked for
## takes, in seconds.
var acceleration_duration: float = 1.0
## How long the fall back toward a standstill - or toward a lower speed - takes.
var deceleration_duration: float = 1.0

## Playback rate at [member walk_speed].
var normal_playback_rate: float = 1.0
## Playback rate at [member run_speed]. Authored rather than derived from the
## speed ratio, so a sprint sounds like one without the rate being yanked
## around 1:1 with the movement.
var sprint_playback_rate: float = 1.5
## Shapes the climb between the two rates. 1 is a straight line; above 1 holds
## near the normal rate until the horse is most of the way to a full sprint, so
## a light push past an ordinary pace does not already sound like one.
var playback_scaling: float = 1.0

## The eased speed reading everything else is taken from, in pixels per second -
## the same unit [member walk_speed] and [member run_speed] are in, so 0 is
## unambiguously "not moving" rather than a level or a rate to be reasoned
## about separately.
var speed: float = 0.0


## Eases [member speed] one step of [param delta] toward [param target].
##
## The step is a fraction of the ramp's own whole span rather than of the gap
## still to close, so the climb takes [member acceleration_duration] from a
## standstill to a full sprint whatever speed it happens to be passing through -
## the ramp is a rate, not a spring that crawls as it arrives.
func advance(target: float, delta: float) -> void:
	var duration := acceleration_duration if target > speed else deceleration_duration
	var span := maxf(maxf(walk_speed, run_speed), 1.0)
	speed = move_toward(speed, target, span / maxf(duration, 0.0001) * delta)


## 0 at a standstill, climbing to 1 by [member walk_speed] and held there
## through a sprint - a fraction, the way [method LoopingSound.set_level] takes
## one, never decibels. Nothing about reaching a sprint makes a gallop louder
## than ordinary movement already does; that is what [method pitch] is for.
func level() -> float:
	if walk_speed <= 0.0:
		return 0.0 if speed <= 0.0 else 1.0
	return clampf(speed / walk_speed, 0.0, 1.0)


## [member normal_playback_rate] up to [member walk_speed], easing toward
## [member sprint_playback_rate] as [member speed] closes the gap to
## [member run_speed], shaped by [member playback_scaling].
func pitch() -> float:
	if run_speed <= walk_speed:
		return normal_playback_rate
	var t := clampf((speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)
	return lerpf(normal_playback_rate, sprint_playback_rate, pow(t, playback_scaling))


## Drops straight to a standstill without a ramp - for a voice being handed to a
## different rider, which must not inherit the last one's speed.
func reset() -> void:
	speed = 0.0
