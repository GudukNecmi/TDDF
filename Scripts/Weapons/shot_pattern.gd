class_name ShotPattern
extends Resource
## How the rounds of one shot leave the muzzle and fly: where each one is pointed,
## how fast it goes, whether its path weaves, what it looks like and what it trails.
##
## [b]It changes behaviour only.[/b] Damage, range, size, criticals and hit effects
## still come from the weapon's [WeaponStats] and the round's own
## [ProjectileProfile]; this only multiplies the round's speed and bends its path,
## so every common upgrade keeps working on a round fired through it.
##
## A weapon reads it off [member WeaponStats.shot_pattern] - put there by a
## [WeaponLegendary] - so any weapon that fires [Projectile]s can take one. Nothing
## here names a weapon.

@export_group("Direction")
## What the weapon's current spread cone - accuracy upgrades included - is
## multiplied by. Each round leaves along the aim, nudged at random inside the
## widened cone. 1 keeps the weapon's own cone.
@export var spread_multiplier: float = 2.0

@export_group("Flight")
## What each round's flight speed is multiplied by, on top of the profile and the
## weapon's projectile speed stat. Below 1 is slower.
@export_range(0.05, 2.0, 0.01) var speed_scale: float = 0.45
## How far either side of its heading a round weaves, in pixels. 0 flies straight.
@export var wave_amplitude: float = 16.0
## Distance travelled per full weave, in pixels.
@export var wave_length: float = 140.0
## Fraction each round's amplitude and weave length are randomly varied by, so the
## rounds of one shot never weave in step.
@export_range(0.0, 1.0, 0.01) var wave_jitter: float = 0.35
## Distance over which the weave grows from nothing to full, so rounds leave the
## muzzle cleanly.
@export var wave_ramp: float = 45.0

@export_group("Tracking")
## How fast each round's heading turns towards the nearest living enemy, in
## degrees per second. 0 never tracks. Kept finite, the round curves in rather
## than snapping round like a missile.
@export var tracking_turn_rate: float = 360.0
## The most the heading may turn in one update, in degrees - a hard cap on top of
## the turn rate. 0 is no cap.
@export var tracking_max_angle_per_update: float = 7.0
## How far a round looks for an enemy to curve towards, in pixels. 0 is the whole
## arena.
@export var tracking_radius: float = 600.0
## How often, in seconds, a round looks again for the nearest enemy, so it can
## switch to a closer one.
@export var tracking_retarget_interval: float = 0.1
## Where on an enemy a round curves towards, from the enemy's origin at its feet -
## the body's centre, as [member KnifeSlash.target_centre_offset] is for the knife.
@export var tracking_aim_offset := Vector2(0.0, -12.0)

@export_group("Look")
## Colour each round's sprite, glow and light are pulled towards.
@export var tint := Color(0.62, 0.02, 0.16)
## How far they are pulled - 0 leaves the profile's colours, 1 is the tint alone.
@export_range(0.0, 1.0, 0.01) var tint_strength: float = 0.7
## What the glow halo's size is multiplied by.
@export var glow_scale: float = 1.5
## How much the glow's brightness throbs, as a fraction either way. 0 is steady.
@export_range(0.0, 1.0, 0.01) var glow_pulse: float = 0.35
## Throbs per second.
@export var glow_pulse_rate: float = 9.0
## Spawned into the world with each round and handed it to follow - see
## [FollowingParticles]. Null trails nothing.
@export var trail_scene: PackedScene


## The heading for one round: [param aim] nudged at random inside the weapon's
## [param half_spread] widened by [member spread_multiplier].
func heading(aim: float, half_spread: float) -> float:
	var reach := half_spread * maxf(spread_multiplier, 0.0)
	return aim + randf_range(-reach, reach)


## Sets [param projectile] up to fly this way. Called before it enters the tree,
## alongside [method CarriedWeapon.arm_projectile].
func prepare(projectile: Projectile) -> void:
	projectile.set_speed_scale(speed_scale)
	var jitter := func(value: float) -> float:
		return value * (1.0 + randf_range(-wave_jitter, wave_jitter))
	var amplitude: float = jitter.call(wave_amplitude) * (1.0 if randf() < 0.5 else -1.0)
	projectile.set_wave(amplitude, jitter.call(wave_length), randf() * TAU, wave_ramp)
	projectile.set_homing(deg_to_rad(tracking_turn_rate), deg_to_rad(tracking_max_angle_per_update),
		tracking_radius, tracking_retarget_interval, tracking_aim_offset)
	projectile.set_look(tint, tint_strength, glow_scale, glow_pulse, glow_pulse_rate)


## Spawns this pattern's trail into [param container] behind [param projectile],
## its particles grown by [param size_scale] - the weapon's projectile size stat -
## so a bigger round leaves a bigger trail. Called once the round has been placed,
## so the trail starts where it does.
func attach_trail(projectile: Projectile, container: Node, size_scale: float = 1.0) -> void:
	if trail_scene == null or container == null:
		return
	var trail := trail_scene.instantiate() as FollowingParticles
	if trail == null:
		return
	container.add_child(trail)
	trail.follow(projectile, size_scale)
