class_name ShotRecoil
extends Resource
## A weapon that throws its holder back with every shot - the part behind the
## shotgun's Legendary RECOIL DEVIL.
##
## [b]It adds no movement system of its own.[/b] A shot hands the push worked out
## here to the holder's [PlayerRecoil], which rides it on top of the walk inside
## [code]Player._physics_process[/code] exactly as the dash and a hit's shove do,
## so the one [code]move_and_slide[/code] still does every wall and collision.
## Nothing here touches the shot: pellets, spread, damage, charge and explosions
## are all whatever the weapon's other parts made them.
##
## A weapon reads it off [member WeaponStats.shot_recoil] - put there by a
## [WeaponLegendary] - and every value below is read at the moment of the kick, so
## retuning it in the Inspector is felt on the next shot.

@export_group("Impulse")
## Speed added to the holder per shot, in pixels per second, straight away from
## where the weapon points. The player walks at 220.
@export var recoil_impulse: float = 900.0
## How long one kick counts as a kick: the walk is eased back from
## [member movement_control_multiplier] to full across it, and once it has run out
## any recoil still left is bled off at [member settle_damping] instead.
@export var recoil_duration: float = 0.32
## How fast the recoil speed dies away while the kick lasts, per second. Higher is
## a shorter, harder shove; the distance one kick carries is roughly
## impulse / damping.
@export var recoil_damping: float = 6.0
## The damping once [member recoil_duration] has passed, so the tail of a kick
## never drifts on.
@export var settle_damping: float = 16.0
## Ceiling on the recoil speed, however many shots are chained. The walk is added
## on top of it, so the player can never go faster than this plus their own speed.
@export var max_recoil_velocity: float = 1300.0

@export_group("Direction")
## How much of the recoil already carrying the holder is turned to the new shot's
## direction before its impulse is added, 0..1. 0 simply adds the new push to the
## old one; 1 swings all the momentum round to the new push, so a chained shot
## steers completely.
@export_range(0.0, 1.0, 0.01) var directional_influence: float = 0.55
## What the holder's own walk is multiplied by the instant a kick lands, eased back
## to 1 across [member recoil_duration]. Below 1 the push dominates; the player can
## still steer and aim throughout.
@export_range(0.0, 1.0, 0.01) var movement_control_multiplier: float = 0.4

@export_group("Scaling")
## Pellets the impulse above is authored for. A shot of more pellets kicks harder
## by (pellets / this) ^ [member pellet_influence], so a pellet upgrade is felt in
## the shoulder too.
@export var reference_pellets: int = 6
@export_range(0.0, 2.0, 0.01) var pellet_influence: float = 0.25
## Ceiling on that factor.
@export var max_scale_factor: float = 1.6

@export_group("Defense")
## Whether the holder is untouchable while the shove carries them. Raised through
## the holder's own [Health] - see [method Health.set_shielded] - by their
## [PlayerRecoil], so every hit, shot and touch is dropped at the one point all
## damage already funnels through.
@export var invulnerable_while_recoiling: bool = true
## Recoil speed, in pixels per second, below which the flight counts as over and
## the shield comes down. Well under the walk's 220, so it ends as the shove
## does, not while the player is still visibly flying.
@export var invulnerability_min_speed: float = 40.0
## Extra seconds the shield is held once the flight has ended. 0 drops it the
## instant the movement stops.
@export var invulnerability_extra_time: float = 0.0


## The push one shot fired along [param aim] gives, as a velocity change - the
## exact opposite of the aim.
func push_for(aim: Vector2, pellets: int) -> Vector2:
	if aim.is_zero_approx():
		return Vector2.ZERO
	return -aim.normalized() * recoil_impulse * strength_for(pellets)


## How much harder than authored a shot of [param pellets] kicks.
func strength_for(pellets: int) -> float:
	var ratio := float(maxi(pellets, 1)) / float(maxi(reference_pellets, 1))
	return clampf(pow(ratio, pellet_influence), 0.0, maxf(max_scale_factor, 0.0))
