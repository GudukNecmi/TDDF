class_name HellChamber
extends Resource
## Hold the trigger to charge, let go to fire - the part behind the shotgun's
## Legendary HELL CHAMBER.
##
## [b]A continuous charge, never a pump count.[/b] The weapon holds one number,
## 0..1, that climbs over [member charge_duration] while the trigger is held and is
## spent by the shot that leaves on release - see [Shotgun]. It shares nothing with
## [PumpCharge]: BLOOD PUMP banks whole cycles of the action, this fills while the
## player aims.
##
## [b]It changes numbers only through [WeaponStats].[/b] What each stage does is a
## multiplier folded into a copy of the weapon's block for the one shot that
## spends the charge - see [method charged_stats] - so the pellets are the
## weapon's own, flying and hitting through the ordinary code, and every common
## upgrade and every other Legendary still reaches them. The multipliers are true
## multipliers on the upgraded figure, so a speed upgrade and a charged shot
## compound rather than one being added to the other.
##
## The crowd-control shockwave of the top stages is a [ShotExplosion] with no
## damage of its own, carried on [member WeaponStats.shot_shockwave] - beside
## DEVIL'S BREATH's own explosion rather than in its place, so both go off.
##
## [b]MAX releases the shot outward again.[/b] The block the MAX shot left with is
## fired a second time as a ring of rounds - see [method volley_stats] - through the
## weapon's own release path, so the volley inherits everything that shot carried
## without this naming any of it.
##
## A weapon reads it off [member WeaponStats.hell_chamber] - put there by a
## [WeaponLegendary] - and every value is read at the moment it is needed, so
## retuning it in the Inspector is felt on the next shot.

@export_group("Charge")
## Seconds the trigger has to be held to go from nothing to full.
@export var charge_duration: float = 1.4

@export_group("Movement")
## What the holder's walk is multiplied by at full charge. 1 is no slowdown at all,
## 0 would root them to the spot.
@export_range(0.0, 1.0, 0.01) var move_speed_at_full: float = 0.55
## How the slowdown builds across the charge: x is the charge, y is how much of the
## way from full speed to [member move_speed_at_full] the walk has gone. Empty is a
## straight line.
@export var move_speed_curve: Curve

@export_group("Stage - speed")
## Charge from which the pellets fly faster. Below it the shot is the ordinary shot.
@export_range(0.0, 1.0, 0.01) var speed_stage_at: float = 0.25
## What the pellets' flight speed is multiplied by from that stage on.
@export var speed_multiplier: float = 1.4

@export_group("Stage - weight")
## Charge from which the pellets are bigger and shove harder.
@export_range(0.0, 1.0, 0.01) var weight_stage_at: float = 0.5
## What the pellets' size - drawn and hit alike - is multiplied by from that stage on.
@export var size_multiplier: float = 1.45
## What the pellets' knockback is multiplied by from that stage on.
@export var knockback_multiplier: float = 1.7

@export_group("Stage - shockwave")
## Charge from which every pellet impact sets off a shockwave.
@export_range(0.0, 1.0, 0.01) var shockwave_stage_at: float = 0.75
## The shockwave each pellet sets off where it lands - crowd control, knockback
## and stagger. Keep its damage at 0: this stage is not a damage stage.
@export var shockwave: ShotExplosion

@export_group("Max charge")
## Charge that counts as MAX. 1 is only a charge held all the way.
@export_range(0.5, 1.0, 0.01) var max_at: float = 1.0
## Used instead of the stage values for a MAX shot, so MAX is its own tier.
@export var max_speed_multiplier: float = 1.6
@export var max_size_multiplier: float = 1.7
@export var max_knockback_multiplier: float = 2.3
## What a MAX shot's damage is multiplied by - every pellet, at any distance, on top
## of the weapon's damage upgrades. 1 adds nothing.
@export var max_damage_multiplier: float = 2.0
## What a MAX shot's long damage - its damage at the end of its range, fading to
## nothing at the muzzle - is multiplied by, on top of the above. 1.4 is +40%.
@export var max_long_damage_multiplier: float = 1.4
## The shockwave a MAX shot's pellets set off instead of [member shockwave] -
## wider, heavier and louder. Empty falls back to [member shockwave].
@export var max_shockwave: ShotExplosion

@export_group("Max volley")
## At MAX the shot is released outward again: a moment after it leaves, the very
## block it was armed with - every upgrade, charge and Legendary on it - is fired a
## second time as a ring of rounds from just ahead of the muzzle. See
## [code]Shotgun._chamber_volley()[/code]. Off, MAX is only the stronger shot.
@export var max_volley_enabled: bool = true
## What the volley's strength is multiplied by, against the shot it copies: damage,
## blast damage and radius, knockback, stagger and camera kick together - through
## [member WeaponStats.power_scale], as BLOOD REAPER's volley. 0.1 is a tenth.
@export_range(0.0, 2.0, 0.01) var max_volley_power_multiplier: float = 0.10
## Seconds after the shot before the volley bursts out, so it reads as the blast
## being released again rather than as part of it.
@export var max_volley_delay: float = 0.07
## How far ahead of the muzzle, along the aim, the volley bursts from, in pixels.
@export var max_volley_offset: float = 56.0
## Random turn either way on each round's share of the ring, in degrees - what
## makes the ring a chaotic burst instead of a clock face.
@export_range(0.0, 90.0, 0.5) var max_volley_jitter_degrees: float = 12.0
## Colour a volley round is pulled towards - white-hot - over HELL CHAMBER's own
## look. A round another Legendary has already coloured keeps its colour.
@export var max_volley_tint := Color(1.0, 0.82, 0.4)
@export_range(0.0, 1.0, 0.01) var max_volley_tint_strength: float = 0.65
@export var max_volley_glow_scale: float = 2.2
@export_range(0.0, 1.0, 0.01) var max_volley_glow_pulse: float = 0.6
@export var max_volley_glow_pulse_rate: float = 26.0
## Trail every volley round leaves on top of whatever trails it inherits, so it
## always reads as the volley. Null trails nothing extra.
@export var max_volley_trail_scene: PackedScene
## Ring set off where the volley bursts from - a [ShotBlast] set off with no
## damage and no mask, so it is only a look and a sound. Null shows none.
@export var max_volley_ring_scene: PackedScene
## Radius the ring is drawn at, in pixels.
@export var max_volley_ring_radius: float = 110.0
## Particles thrown out with the ring. Null throws none.
@export var max_volley_burst_scene: PackedScene

@export_group("Readout")
## What the readout over the ammunition shows while charging, %d standing for the
## charge in per cent. Empty at 0, so it is only up while the trigger is held.
@export var label_format: String = "HELL %d%%"
## Shown instead at MAX.
@export var max_label: String = "HELL CHAMBER MAX"
## Size of the readout at the start of the charge and at MAX.
@export var label_scale_min: float = 0.8
@export var label_scale_max: float = 1.35


## The charge added by holding for [param delta] seconds.
func charge_step(delta: float) -> float:
	return 1.0 if charge_duration <= 0.0 else delta / charge_duration


func is_max(charge: float) -> bool:
	return charge > 0.0 and charge >= max_at - 0.0001


## Which stage [param charge] is in: 0 ordinary, 1 speed, 2 weight, 3 shockwave,
## 4 MAX.
func stage_for(charge: float) -> int:
	if is_max(charge):
		return 4
	if charge >= shockwave_stage_at:
		return 3
	if charge >= weight_stage_at:
		return 2
	if charge >= speed_stage_at:
		return 1
	return 0


## What the holder's walk is multiplied by at [param charge].
func move_speed_multiplier(charge: float) -> float:
	var t := clampf(charge, 0.0, 1.0)
	if move_speed_curve != null:
		t = clampf(move_speed_curve.sample_baked(t), 0.0, 1.0)
	return lerpf(1.0, clampf(move_speed_at_full, 0.0, 1.0), t)


## A copy of [param stats] with [param charge] folded in - the block the shot that
## spends it is armed with. [param stats] itself is never touched. Below the first
## stage the copy is the same numbers, so a tap is the ordinary shot.
func charged_stats(stats: WeaponStats, charge: float) -> WeaponStats:
	var copy := stats.duplicate_stats()
	var stage := stage_for(charge)
	var speed := 1.0
	var size := 1.0
	var knockback := 1.0
	if stage >= 4:
		speed = max_speed_multiplier
		size = max_size_multiplier
		knockback = max_knockback_multiplier
		_multiply(copy, WeaponStats.Stat.DAMAGE,
			maxf(1.0 + stats.get_bonus(WeaponStats.Stat.DAMAGE), 0.0), max_damage_multiplier)
		_multiply(copy, WeaponStats.Stat.LONG_DAMAGE,
			1.0 + stats.get_bonus(WeaponStats.Stat.LONG_DAMAGE), max_long_damage_multiplier)
	else:
		if stage >= 1:
			speed = speed_multiplier
		if stage >= 2:
			size = size_multiplier
			knockback = knockback_multiplier
	_multiply(copy, WeaponStats.Stat.PROJECTILE_SPEED, stats.speed_scale(), speed)
	_multiply(copy, WeaponStats.Stat.PROJECTILE_SIZE, stats.size_scale(), size)
	_multiply(copy, WeaponStats.Stat.KNOCKBACK, stats.knockback_scale(), knockback)
	copy.shot_shockwave = shockwave_for(charge)
	return copy


## The shockwave the pellets of a shot at [param charge] set off, or null below the
## shockwave stage.
func shockwave_for(charge: float) -> ShotExplosion:
	var stage := stage_for(charge)
	if stage >= 4:
		return max_shockwave if max_shockwave != null else shockwave
	return shockwave if stage >= 3 else null


## Whether a shot at [param charge] is released outward again - see
## [member max_volley_enabled].
func releases_volley(charge: float) -> bool:
	return max_volley_enabled and is_max(charge)


## The block the MAX volley is armed with: a copy of [param shot] - the block the
## MAX shot itself left with, untouched - at [member max_volley_power_multiplier]
## of its power. Nothing else is read or rebuilt, so whatever the shot carried the
## volley carries.
func volley_stats(shot: WeaponStats) -> WeaponStats:
	var copy := shot.duplicate_stats()
	copy.power_scale *= maxf(max_volley_power_multiplier, 0.0)
	return copy


## Dresses a volley round. Called before it enters the tree, after everything else
## has prepared it; [param dressed] is whether another Legendary already coloured
## it, in which case only the trail marks it.
func prepare_volley(projectile: Projectile, dressed: bool) -> void:
	if not dressed:
		projectile.set_look(max_volley_tint, max_volley_tint_strength, max_volley_glow_scale,
			max_volley_glow_pulse, max_volley_glow_pulse_rate)


## Spawns the volley's own trail behind [param projectile]. See
## [method ShotPattern.attach_trail], which this mirrors.
func attach_volley_trail(projectile: Projectile, container: Node, size_scale: float = 1.0) -> void:
	if max_volley_trail_scene == null or container == null:
		return
	var trail := max_volley_trail_scene.instantiate() as FollowingParticles
	if trail == null:
		return
	container.add_child(trail)
	trail.follow(projectile, size_scale)


## The ring and burst the volley leaves from, at [param at] in [param container].
## Look and sound only: the ring strikes nothing. [param power] scales its camera
## kick, as it does any blast's.
func release_ring(container: Node, at: Vector2, power: float) -> void:
	if container == null:
		return
	if max_volley_ring_scene != null:
		var ring := max_volley_ring_scene.instantiate() as ShotBlast
		if ring != null:
			container.add_child(ring)
			ring.global_position = at
			ring.reset_physics_interpolation()
			ring.detonate(0.0, max_volley_ring_radius, 0.0, 0, null, 0.0, 1.0, null, power)
	if max_volley_burst_scene != null:
		var burst := max_volley_burst_scene.instantiate() as CPUParticles2D
		if burst != null:
			container.add_child(burst)
			burst.global_position = at
			burst.global_rotation = randf() * TAU
			burst.reset_physics_interpolation()
			if burst.has_method(&"play"):
				burst.call(&"play")
			else:
				burst.emitting = true


## The readout text at [param charge], or an empty string for none.
func label_for(charge: float) -> String:
	if charge <= 0.0:
		return ""
	if is_max(charge):
		return max_label
	return label_format % roundi(charge * 100.0) if label_format.contains("%d") else label_format


func label_scale_for(charge: float) -> float:
	return lerpf(label_scale_min, label_scale_max, clampf(charge, 0.0, 1.0))


## Turns [param stat]'s scale, currently [param current], into [param multiplier]
## times that - the stat's scale is 1 plus its bonus, so the bonus that does it is
## the current scale times what the multiplier adds.
func _multiply(stats: WeaponStats, stat: WeaponStats.Stat, current: float, multiplier: float) -> void:
	if not is_equal_approx(multiplier, 1.0):
		stats.add(stat, current * (multiplier - 1.0))
