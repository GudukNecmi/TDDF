class_name WorldBanditSpeedProfile
extends Resource
## The group-size -> movement-speed mapping every [WorldBandit] reads its
## [member WorldBandit.movement_speed] from.
##
## [b]A curve, not a ladder of if/else checks.[/b] A group's speed is never
## branched on its exact [member WorldBandit.group_strength] - there is no
## "if strength == 20" anywhere - it is [member speed_curve] sampled at where
## that strength falls between [member min_group_strength] and
## [member max_group_strength], so a designer retunes the whole curve from
## the inspector and a group strength the curve has never been tuned for
## still gets a sensible answer instead of falling through to nothing.
##
## Smaller groups move faster and larger ones slower by construction: the
## curve is sampled from 0 (the smallest authored group) to 1 (the largest)
## and lerped from [member fastest_speed] down to [member slowest_speed], so
## raising [member slowest_speed] to sit near the player's own walking speed
## is the entire tuning knob for "a sixty-strong group ambles about as fast
## as the player can walk".
##
## [b]The biome multiplier lives here, not in [WorldBandit].[/b] A later map
## with its own terrain simply gets its own [WorldBanditSpeedProfile]
## resource with [member biome_speed_multiplier] set to whatever that ground
## should cost a group crossing it - the World Map's bandits swap to it by
## having their [member WorldBandit.speed_profile] pointed at the new
## resource, and nothing in [code]world_bandit.gd[/code] is touched.

## The smallest group strength the curve is authored for. Sampled at the
## curve's start (0).
@export var min_group_strength: float = 10.0
## The largest group strength the curve is authored for. Sampled at the
## curve's end (1).
@export var max_group_strength: float = 60.0
## Speed, in pixels per second, for a group at [member min_group_strength] or
## below.
@export var fastest_speed: float = 300.0
## Speed, in pixels per second, for a group at [member max_group_strength] or
## above. Left near the player's own walking speed - see [member Player.speed]
## - so the largest groups amble at roughly the pace the player themselves
## moves at.
@export var slowest_speed: float = 220.0
## Eases the speed between the two ends above. A straight line from (0,0) to
## (1,1) is a plain lerp; reshaping it is the entire way to make, say, the
## middle group sizes fall off faster than the small-to-medium ones.
@export var speed_curve: Curve
## What every speed out of this profile is finally multiplied by - the one
## seam a later biome overrides to make its own ground slower or faster to
## cross, without any change to [WorldBandit] itself. 1 leaves the desert
## exactly as authored.
@export var biome_speed_multiplier: float = 1.0


## The pixels-per-second a group of [param strength] should move at, with the
## biome multiplier already folded in.
func get_speed(strength: float) -> float:
	var span := maxf(max_group_strength - min_group_strength, 0.001)
	var t := clampf((strength - min_group_strength) / span, 0.0, 1.0)
	var eased := speed_curve.sample_baked(t) if speed_curve != null else t
	return lerpf(fastest_speed, slowest_speed, clampf(eased, 0.0, 1.0)) * biome_speed_multiplier
