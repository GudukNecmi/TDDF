class_name BloodReaper
extends Resource
## A kill with the weapon executes the man and his death fires a volley of its own
## at the enemies around him - the part behind the shotgun's Legendary BLOOD REAPER.
##
## [b]It adds no projectile and no damage system of its own.[/b] A round armed from a
## block carrying this - see [member WeaponStats.blood_reaper] - lands a fatal hit
## through the game's gore [Explosion], exactly as a charged HELL CHAMBER pellet
## does (see [method Explosion.tear_if_fatal]), and reports the execution to the
## weapon that fired it. The weapon then releases one of its own rounds per pellet
## it currently fires, from where the man came apart, each armed through the same
## code as an ordinary shot - see [code]Shotgun._reap()[/code] - so every upgrade and
## every other Legendary the shot carries reaches the volley too.
##
## [b]What makes it a lesser echo is one number.[/b] The volley's block is a copy of
## the block the killing shot was fired with - its BLOOD PUMP and HELL CHAMBER charge
## included - with [member WeaponStats.power_scale] multiplied by
## [member blood_reaper_power_multiplier], and everything that measures a round's
## strength reads that: its damage, its knockback and stagger, and any blast it sets
## off - that blast's damage, radius, shove and camera kick.
##
## Chains are the same path again: a volley round that kills executes its man, who
## fires his own volley. [Explosion.tear_if_fatal] never tears a man already dead or
## going, so each death is executed once and fires once.

@export_group("Power")
## What the volley's strength is multiplied by, against a shot of the weapon's own:
## damage, blast damage and radius, knockback, stagger and camera kick together.
## 0.1 is a tenth.
@export_range(0.0, 2.0, 0.01) var blood_reaper_power_multiplier: float = 0.10

@export_group("Execution")
## What a man the weapon kills comes apart into - a gore [Explosion] of its own,
## torn through [method Explosion.tear_apart_by_hit]: a violent burst of meat and
## blood, and never a bomb - no flare, fire, smoke or scorch. The blood spray
## thrown with it is [BloodReaperFeedback]'s.
@export var execution_gore: PackedScene
## Only a man carrying a node of this class is executed - the ordinary head-pop
## death the gore stands in for. Empty allows anybody.
@export var gore_requires: StringName = &"EnemyHeadPop"
## Never a man carrying a node of any of these classes: a boss has his own defeat,
## a bomber his own blast.
@export var gore_excludes: Array[StringName] = [&"MiniBoss", &"BomberFuse"]

@export_group("Targeting")
## How far from the execution, in pixels, the volley looks for enemies to go for.
## 0 looks over the whole arena.
@export var target_radius: float = 460.0

@export_group("Look")
## Colour the volley's rounds are pulled towards - a dark blood red. Applied over
## any other Legendary's look, so a reaped round always reads as one.
@export var tint := Color(0.45, 0.0, 0.04)
@export_range(0.0, 1.0, 0.01) var tint_strength: float = 0.85
@export var glow_scale: float = 1.6
@export_range(0.0, 1.0, 0.01) var glow_pulse: float = 0.45
@export var glow_pulse_rate: float = 12.0
## Spawned with each round of the volley and handed it to follow - see
## [FollowingParticles]. Null trails nothing.
@export var trail_scene: PackedScene


## The block a volley is armed with: a copy of [param stats] - the block of the shot
## that killed - at [member blood_reaper_power_multiplier] of its power.
func reaper_stats(stats: WeaponStats) -> WeaponStats:
	var copy := stats.duplicate_stats()
	copy.power_scale *= maxf(blood_reaper_power_multiplier, 0.0)
	return copy


## Dresses a volley round. Called before it enters the tree, after everything else
## has prepared it.
func prepare(projectile: Projectile) -> void:
	projectile.set_look(tint, tint_strength, glow_scale, glow_pulse, glow_pulse_rate)


## Spawns the volley's trail behind [param projectile]. See
## [method ShotPattern.attach_trail], which this mirrors.
func attach_trail(projectile: Projectile, container: Node, size_scale: float = 1.0) -> void:
	if trail_scene == null or container == null:
		return
	var trail := trail_scene.instantiate() as FollowingParticles
	if trail == null:
		return
	container.add_child(trail)
	trail.follow(projectile, size_scale)
