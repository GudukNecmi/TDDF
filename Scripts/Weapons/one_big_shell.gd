class_name OneBigShell
extends Resource
## The part behind the shotgun's Legendary ONE BIG SHELL: every shot leaves as one
## enormous cannon round instead of a spread of pellets.
##
## [b]It changes the shape of the shot, never what the shot is.[/b] The round is
## armed from the very [WeaponStats] block the pellets would have been - every
## common upgrade, BLOOD PUMP and HELL CHAMBER charge, every Legendary part and
## whatever is added to that block later - through the weapon's own release path
## (see [code]Shotgun._release_pellet()[/code]), so nothing here names any other
## Legendary or stat. All this decides is that there is one round, where it points,
## how big it is and how a hit on it is measured.
##
## [b]Where a hit lands on the shell decides what it is worth.[/b] Each hit is
## measured as its distance off the shell's centre line, 0 dead centre to 1 barely
## touching the rim, and everything the hit does - damage, shove, which way it
## throws, whether the shell flies on - is read off that one number through the
## values below. See [CannonShell], which does the measuring.
##
## A weapon reads it off [member WeaponStats.one_big_shell] - put there by a
## [WeaponLegendary] - and every value is read as it is needed, so retuning it in
## the Inspector is felt on the next shot.

@export_group("Shell")
## The round fired - a [CannonShell] scene. Its look is tuned on the scene.
@export var shell_scene: PackedScene
## What the shell's drawn size is multiplied by, on top of the scene as authored
## and the weapon's projectile size stat. Drawing only - see [member hit_radius].
@export var visual_scale: float = 1.0
## Half the width of what the shell hits, in pixels, before the weapon's
## projectile size stat grows it.
@export var hit_radius: float = 22.0
## What the shell's flight speed is multiplied by, on top of the profile, the
## weapon's projectile speed stat and anything else that sets it.
@export var speed_multiplier: float = 0.8
## What the shell's range - and the distance its damage falls off over - is
## multiplied by, on top of the weapon's range stat. Its lifetime stretches with it.
@export var range_multiplier: float = 1.5

@export_group("Look")
## What the shell's glow, light and hot core are multiplied by. 1 is as authored.
@export var glow_intensity: float = 1.0
## Strength of the heat shimmer around the shell. 0 turns it off.
@export var shimmer_strength: float = 1.0
## Spawned into the world behind the shell - see [FollowingParticles]. Its
## particles stay behind as a residual trail once the shell is gone. Null trails
## nothing beyond the streak the scene carries.
@export var trail_scene: PackedScene
## What the trail's particle count and opacity are multiplied by.
@export var trail_intensity: float = 1.0

@export_group("Damage")
## What a dead-centre hit deals, as a multiple of the damage one of the shot's
## pellets would deal at that point in its flight - so every damage stat, the
## fall-off, a critical and any charge reach it.
@export var core_damage_multiplier: float = 1.0
## Whether [member core_damage_multiplier] is also multiplied by the pellets the
## shot would have fired, so the shell carries the whole blast's weight and pellet
## count upgrades still count.
@export var damage_per_pellet: bool = true
## Share of the core damage left at the very rim of the shell.
@export_range(0.0, 1.0, 0.01) var min_edge_damage: float = 0.15
## Distance off the centre line, 0..1, inside which a hit is a full core hit.
@export_range(0.0, 1.0, 0.01) var core_radius: float = 0.25
## How the damage falls from the core to the rim: x runs from the edge of the core
## (0) to the rim (1), y is how much of the way from full damage to
## [member min_edge_damage] a hit there has fallen. Empty is a straight line.
@export var edge_falloff_curve: Curve
## Distance off the centre line, 0..1, beyond which a hit only grazes: the victim
## is struck and shoved aside, and the shell flies on. A hit nearer the centre stops
## it, as any round is stopped - unless it has a pierce left.
@export_range(0.0, 1.0, 0.01) var graze_from: float = 0.55

@export_group("Knockback")
## What the victim's knockback is multiplied by on a dead-centre hit, on top of
## the weapon's knockback stat.
@export var core_knockback_multiplier: float = 2.2
## The same at the very rim - above the core's, so a graze reads as a shove.
@export var edge_knockback_multiplier: float = 3.0
## A shove every hit throws on its own account, in pixels per second, along the
## hit direction - see [member HitEffects.knockback_push].
@export var knockback_push: float = 140.0
## How far a rim hit's shove is turned from the flight out to the side the victim
## was clipped on, 0..1. A centre hit always goes straight along the flight.
@export_range(0.0, 1.0, 0.01) var edge_side_push: float = 0.55
## What the victim's stagger is multiplied by, on top of the weapon's stagger stat.
@export var stagger_multiplier: float = 1.5

@export_group("Kill gore")
## What a man killed by a near-centre hit comes apart into - the game's
## [Explosion] scene, through [method Explosion.tear_if_fatal], as a charged HELL
## CHAMBER pellet tears. Null leaves every kill dying the ordinary way.
@export var kill_gore_effect: PackedScene
## How near the centre, 0..1 with 1 dead centre, a fatal hit must be to tear.
@export_range(0.0, 1.0, 0.01) var gore_min_centrality: float = 0.6
@export var kill_gore_requires: StringName = &"EnemyHeadPop"
@export var kill_gore_excludes: Array[StringName] = [&"MiniBoss", &"BomberFuse"]

@export_group("Feedback")
## Centrality, 0..1 with 1 dead centre, from which a hit gets the heavy impact
## feedback rather than the graze's - see [OneBigShellFeedback].
@export_range(0.0, 1.0, 0.01) var heavy_hit_from: float = 0.5


## What the pellet damage is multiplied by for a dead-centre hit of a shot that
## would have fired [param pellets].
func core_factor(pellets: int) -> float:
	return maxf(core_damage_multiplier, 0.0) * (float(maxi(pellets, 1)) if damage_per_pellet else 1.0)


## How far a hit [param distance] off the centre line (0..1) has fallen from the
## core towards the rim, 0..1, through [member edge_falloff_curve].
func edge_fall(distance: float) -> float:
	var d := clampf(distance, 0.0, 1.0)
	if d <= core_radius:
		return 0.0
	var t := 1.0 if core_radius >= 1.0 else clampf(inverse_lerp(core_radius, 1.0, d), 0.0, 1.0)
	if edge_falloff_curve != null:
		t = clampf(edge_falloff_curve.sample_baked(t), 0.0, 1.0)
	return t


## Share of the core damage a hit [param distance] off the centre line deals.
func damage_factor(distance: float) -> float:
	return lerpf(1.0, clampf(min_edge_damage, 0.0, 1.0), edge_fall(distance))


## What the victim's knockback is multiplied by for a hit [param distance] off.
## Straight across the width, so the shove grows steadily towards the rim.
func knockback_factor(distance: float) -> float:
	return lerpf(core_knockback_multiplier, edge_knockback_multiplier, clampf(distance, 0.0, 1.0))


## Whether a hit [param distance] off only grazes, letting the shell fly on.
func grazes(distance: float) -> bool:
	return distance > graze_from


## Whether a hit [param distance] off is a heavy hit for the feedback.
func is_heavy(distance: float) -> bool:
	return 1.0 - clampf(distance, 0.0, 1.0) >= heavy_hit_from


## Readies [param shell] - already armed with the shot's block and prepared by
## every other part - as this shell, for a shot that would have fired
## [param pellets]. Called before it enters the tree.
func prepare(shell: Projectile, pellets: int) -> void:
	shell.set_speed_scale(shell.get_speed_scale() * maxf(speed_multiplier, 0.05))
	var cannon := shell as CannonShell
	if cannon != null:
		cannon.set_big_shell(self, core_factor(pellets))


## Spawns the shell's trail behind [param shell]. See
## [method ShotPattern.attach_trail], which this mirrors.
func attach_trail(shell: Projectile, container: Node, size_scale: float = 1.0) -> void:
	if trail_scene == null or container == null:
		return
	var trail := trail_scene.instantiate() as FollowingParticles
	if trail == null:
		return
	trail.amount = maxi(roundi(trail.amount * maxf(trail_intensity, 0.0)), 1)
	trail.modulate.a *= clampf(trail_intensity, 0.0, 1.0)
	container.add_child(trail)
	trail.follow(shell, size_scale * maxf(visual_scale, 0.05))
