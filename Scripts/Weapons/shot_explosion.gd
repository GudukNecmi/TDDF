class_name ShotExplosion
extends Resource
## Makes every round of a shot explosive - the part behind the shotgun's Legendary
## DEVIL'S BREATH.
##
## [b]It adds, it never replaces.[/b] A round armed with one still flies, hits,
## pierces and falls off exactly as it would without it: its direct hit lands
## first through the ordinary [method Hitbox.take_hit], and only then does the
## round set off a [ShotBlast] at the point it landed. The blast's damage is its
## own number, [member damage], and reaches the enemies around it through the same
## [Hitbox] / [Health] / [HitReaction] path a pellet uses - so there is one damage
## system, and the blast is simply another hit on it.
##
## A weapon reads it off [member WeaponStats.shot_explosion] - put there by a
## [WeaponLegendary] - and [Projectile] does the rest, so any weapon that fires
## [Projectile]s can take one. Nothing here names a weapon, and it sits beside a
## [ShotPattern] rather than inside one, so a round can weave, home and explode at
## once.

@export_group("Blast")
## The scene set off where a round explodes - see [ShotBlast]. Everything it looks,
## sounds and feels like is tuned on that scene.
@export var blast_scene: PackedScene
## Area damage dealt to each enemy the blast catches, in hit points. Its own figure,
## deliberately not the pellet's: the weapon's damage upgrades raise the direct hit
## and leave this alone.
@export var damage: float = 30.0
## What [member damage] is multiplied by - the dial for turning the whole blast up
## or down without retyping its figure. See [method get_damage].
@export var damage_multiplier: float = 1.0
## How far the blast reaches from where the round exploded, in pixels.
@export var radius: float = 48.0
## Share of [method get_damage] lost by an enemy caught at the very edge of the
## blast rather than at its centre. 0 hits everybody inside the radius equally; 1
## leaves the edge unhurt.
@export_range(0.0, 1.0, 0.01) var falloff: float = 0.0
## Shape of that falloff across the radius: 1 is linear, above 1 keeps the damage
## up further out before it drops, below 1 drops it sooner.
@export_range(0.1, 4.0, 0.05) var falloff_exponent: float = 1.0
## Whether the enemy a round landed on is caught by its own blast as well, when he
## is inside the radius. Off, the blast only reaches the men around him and his
## hit is the pellet's alone.
@export var direct_hit_takes_blast: bool = true
## What an enemy's own authored knockback is multiplied by when the blast catches
## him - see [member HitEffects.knockback_scale].
@export var knockback: float = 1.4
## A shove the blast throws on its own account, in pixels per second, outwards
## from its centre - see [member HitEffects.knockback_push].
@export var knockback_push: float = 60.0
## What an enemy's own authored stagger is multiplied by when the blast catches him
## - see [member HitEffects.stagger_scale].
@export var stagger: float = 1.2
## How long, in seconds, the blast stays live. An enemy that walks into it during
## that time is caught too, but no enemy is ever caught twice by one blast.
@export var lifetime: float = 0.1
## Physics layers the blast looks for [Hitbox]es on. Below 0 uses the firing
## round's own collision mask, so it hits exactly what the round could.
@export_flags_2d_physics var hitbox_mask: int = -1

@export_group("Triggers")
## Whether a round explodes where it lands on an enemy.
@export var explode_on_hit: bool = true
## Whether a round passing through an enemy - a piercing round - explodes on each
## body it passes through. Off, a piercing round only explodes where it stops.
@export var explode_on_pierce: bool = true
## Whether a round explodes where it runs out of range - its end in the dirt.
@export var explode_at_range_end: bool = true
## Solid world the round explodes against - walls and solid props. The round is
## stopped there as well, so it does not carry on through a wall it has already
## blown up on. 0 leaves rounds flying through the world as they always have.
@export_flags_2d_physics var surface_mask: int = 33
## Bodies in this group are never treated as a surface - the player the round
## leaves from.
@export var surface_ignore_group: StringName = &"player"

@export_group("Kill gore")
## What a man killed by the round's own hit comes apart into - the game's
## [Explosion] scene, through [method Explosion.tear_if_fatal], the same way a
## DEVIL'S BREATH blast tears apart who it kills. The round's hit still lands
## through his [Hitbox] as ever; this only decides how a fatal one looks. Null
## leaves direct kills dying the ordinary way - HELL CHAMBER's charged shockwave
## sets it, DEVIL'S BREATH does not.
@export var kill_gore_effect: PackedScene
## Only a man carrying a node of this class comes apart. Empty allows anybody.
@export var kill_gore_requires: StringName = &"EnemyHeadPop"
## Never a man carrying a node of any of these classes.
@export var kill_gore_excludes: Array[StringName] = [&"MiniBoss", &"BomberFuse"]

@export_group("Weapon stats")
## How much the weapon's knockback upgrades reach into the blast's knockback. 0 is
## none - a common knockback upgrade is the pellet's - and 1 is all of it.
@export_range(0.0, 1.0, 0.01) var knockback_stat_influence: float = 0.0
## The same for the weapon's stagger upgrades.
@export_range(0.0, 1.0, 0.01) var stagger_stat_influence: float = 0.0
## The same for the weapon's blood gain - what a kill with the weapon is worth. On
## by default, since a blast kill is still a kill with the weapon.
@export_range(0.0, 1.0, 0.01) var blood_gain_stat_influence: float = 1.0

@export_group("Look")
## Colour a round's sprite, glow and light are pulled towards - a dark fiery
## orange-red. Applied only to a round no [ShotPattern] has already coloured, so
## DEVIL'S BARREL and BLOOD PUMP's piercing blast keep their own look.
@export var tint := Color(1.0, 0.36, 0.08)
## How far they are pulled - 0 leaves the profile's colours.
@export_range(0.0, 1.0, 0.01) var tint_strength: float = 0.45
## What the glow halo's size is multiplied by.
@export var glow_scale: float = 1.25
## How much the glow's brightness flickers, as a fraction either way.
@export_range(0.0, 1.0, 0.01) var glow_pulse: float = 0.3
## Flickers per second.
@export var glow_pulse_rate: float = 16.0
## Spawned into the world with each round and handed it to follow - see
## [FollowingParticles]. Always attached, pattern or not, so an explosive round is
## recognisable under any other Legendary's look. Null trails nothing.
@export var trail_scene: PackedScene


## Sets [param projectile]'s look. Called before it enters the tree, after any
## [ShotPattern] has prepared it; [param patterned] is whether one did.
func prepare(projectile: Projectile, patterned: bool) -> void:
	if not patterned:
		projectile.set_look(tint, tint_strength, glow_scale, glow_pulse, glow_pulse_rate)


## Spawns this explosion's trail behind [param projectile]. See
## [method ShotPattern.attach_trail], which this mirrors.
func attach_trail(projectile: Projectile, container: Node, size_scale: float = 1.0) -> void:
	if trail_scene == null or container == null:
		return
	var trail := trail_scene.instantiate() as FollowingParticles
	if trail == null:
		return
	container.add_child(trail)
	trail.follow(projectile, size_scale)


## What the blast does beyond damage, with the weapon's own on-hit stats folded in
## as far as the influences above allow.
func make_hit_effects(stats: WeaponStats) -> HitEffects:
	var effects := HitEffects.new()
	effects.knockback_scale = maxf(knockback, 0.0)
	effects.stagger_scale = maxf(stagger, 0.0)
	effects.knockback_push = maxf(knockback_push, 0.0)
	# A man the blast kills is the shot's kill, as one its round killed would be.
	effects.shot_stats = stats
	if stats != null:
		effects.knockback_scale *= lerpf(1.0, stats.knockback_scale(), knockback_stat_influence)
		effects.stagger_scale *= lerpf(1.0, stats.stagger_scale(), stagger_stat_influence)
		effects.blood_gain_scale = lerpf(1.0, stats.blood_gain_scale(), blood_gain_stat_influence)
		# A BLOOD REAPER volley's blast shoves and staggers at its power.
		effects.knockback_scale *= stats.power_scale
		effects.stagger_scale *= stats.power_scale
		effects.knockback_push *= stats.power_scale
	return effects


## Sets off one blast at [param at] for a round armed with [param stats]. Returns
## it, or null when there is no scene to set off. [param direct_victim] is the
## enemy the round itself just landed on, if any - spared the blast unless
## [member direct_hit_takes_blast] is on.
##
## The block's [member WeaponStats.power_scale] scales the blast's damage, radius and
## camera kick along with its shove - a BLOOD REAPER volley's blast is a lesser one.
## [param on_executed] is told of every man the blast tears apart.
func detonate(from: Node, at: Vector2, stats: WeaponStats, fallback_mask: int,
		direct_victim: Node = null, on_executed: Callable = Callable()) -> ShotBlast:
	if blast_scene == null or from == null or not from.is_inside_tree():
		return null
	var container := from.get_tree().current_scene
	if container == null:
		return null
	var blast := blast_scene.instantiate() as ShotBlast
	if blast == null:
		return null
	container.add_child(blast)
	blast.global_position = at
	blast.reset_physics_interpolation()
	var mask := fallback_mask if hitbox_mask < 0 else hitbox_mask
	var spared: Node = null if direct_hit_takes_blast else direct_victim
	var power := 1.0 if stats == null else maxf(stats.power_scale, 0.0)
	blast.detonate(get_damage() * power, radius * power, lifetime, mask, make_hit_effects(stats),
		falloff, falloff_exponent, spared, power, on_executed)
	return blast


## The damage each blast deals: [member damage] times [member damage_multiplier].
func get_damage() -> float:
	return maxf(damage * damage_multiplier, 0.0)
