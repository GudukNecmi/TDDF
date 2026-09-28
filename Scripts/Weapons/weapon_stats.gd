class_name WeaponStats
extends RefCounted
## Everything that has been done to one weapon's numbers, summed into one place
## the combat code reads.
##
## [b]It holds no base values of its own.[/b] What a round does at the muzzle, how
## far it reaches, how fast it flies, how many rounds a weapon holds and how hard
## an enemy is shoved all stay exactly where they were authored - the
## [ProjectileProfile], the weapon's own scene, the [AmmoType], the enemy's
## [HitReaction]. This is only the change on top: a bonus per [enum Stat], and a
## set of methods that turn those bonuses into the multipliers and extra rounds
## those systems apply to their own numbers. An un-upgraded weapon's block is all
## zeroes and every method answers "no change", which is why a weapon with no
## block at all behaves exactly as it always did.
##
## Where the bonuses come from is not its business. [WeaponDefinition] fills one
## from the Base upgrades bought for that weapon today; a card, a unique weapon
## upgrade or anything else later is just more [WeaponStatModifier]s summed into
## the same block, so every source changes the same underlying stats and none of
## them needs to know the others exist.

## Every stat a modifier can move. Each is a bonus that starts at 0 and is summed
## across every source, and each is read the way its comment says.
##
## [b]Append new stats at the end.[/b] The value is what a [code].tres[/code]
## stores, so inserting one in the middle would silently repoint every modifier
## already saved after it.
enum Stat {
	## Fraction added to all damage. 0.1 is +10%.
	DAMAGE,
	## Fraction added to damage at the muzzle, fading to nothing at full range.
	CLOSE_DAMAGE,
	## Fraction added to damage at the end of the range, fading to nothing at the
	## muzzle.
	LONG_DAMAGE,
	## Fraction added to the profile's effective range.
	RANGE,
	## Fraction added to the round's flight speed.
	PROJECTILE_SPEED,
	## Chance, 0..1, added to the weapon's base critical chance.
	CRITICAL_CHANCE,
	## Added to the weapon's base critical multiplier. 0.25 turns x1.5 into x1.75.
	CRITICAL_DAMAGE,
	## Whole rounds added to the magazine - the cylinder, the tube. A weapon with
	## no magazine of its own ignores it.
	MAGAZINE_SIZE,
	## Whole rounds added to how many the player can carry - the [AmmoReserve]'s
	## capacity bonus.
	AMMO_CAPACITY,
	## Fraction added to how hard a hit shoves the enemy.
	KNOCKBACK,
	## Fraction added to how long a hit slows the enemy.
	STAGGER,
	## Fraction added to the size of the round, drawn and hit alike.
	PROJECTILE_SIZE,
	## Fraction of the profile's damage fall-off taken away. 1 is none at all.
	DAMAGE_FALLOFF,
	## Chance, 0..1, that a shot costs no ammunition.
	AMMO_EFFICIENCY,
	## Fraction added to the blood a kill with this weapon spills.
	BLOOD_GAIN,
	## Whole pellets added to each shot of a weapon that fires several at once. A
	## weapon that fires one round ignores it.
	PELLET_COUNT,
	## Fraction taken off the weapon's authored spread cone. 0.25 is a cone a
	## quarter narrower; 1 would send every pellet straight down the barrel.
	ACCURACY,
	## Whole enemies a round carries on to after the one it hits, added to the
	## projectile's own [member Projectile.bounce_count]. See [method bounce_bonus].
	BOUNCE_COUNT,
	## Whole enemies a round passes straight through after the one it hits, added
	## to the projectile's own [member Projectile.pierce_count]. See
	## [method pierce_bonus].
	PIERCE_COUNT,
	## Fraction of the weapon's authored spread cone added on top of it. 0.3 is a
	## cone 30% of the authored width wider. Added [i]after[/i] [constant ACCURACY]
	## has tightened the cone, so accuracy never takes it back - a deliberately wider
	## blast, such as a charged BLOOD PUMP shot, stays wide on an accurate gun.
	SPREAD,
}

## Stats measured as a fraction and shown as a percentage. Everything else is a
## count of rounds.
const PERCENT_STATS: Array[Stat] = [
	Stat.DAMAGE, Stat.CLOSE_DAMAGE, Stat.LONG_DAMAGE, Stat.RANGE,
	Stat.PROJECTILE_SPEED, Stat.CRITICAL_CHANCE, Stat.CRITICAL_DAMAGE,
	Stat.KNOCKBACK, Stat.STAGGER, Stat.PROJECTILE_SIZE, Stat.DAMAGE_FALLOFF,
	Stat.AMMO_EFFICIENCY, Stat.BLOOD_GAIN, Stat.ACCURACY, Stat.SPREAD,
]

## The weapon's critical chance before anything is added to it - see
## [member WeaponDefinition.base_critical_chance].
var base_critical_chance: float = 0.0
## The weapon's critical multiplier before anything is added to it - see
## [member WeaponDefinition.base_critical_multiplier].
var base_critical_multiplier: float = 1.5
## How the rounds of each shot leave and fly, when an active [WeaponLegendary]
## changes that - see [ShotPattern]. Null is the weapon firing as authored.
var shot_pattern: ShotPattern
## How working the pump past ready banks charge into the next shot, when an active
## [WeaponLegendary] adds that - see [PumpCharge]. Null is a pump that only cycles.
var pump_charge: PumpCharge
## What every round of a shot does as it lands or runs out, when an active
## [WeaponLegendary] makes it explosive - see [ShotExplosion]. Null is a round that
## only hits.
var shot_explosion: ShotExplosion
## How the pump is worked with the trigger held, when an active [WeaponLegendary]
## allows it - see [FanHammer]. Null is a pump worked in two presses.
var fan_hammer: FanHammer
## The shove each shot gives the holder, when an active [WeaponLegendary] adds one
## - see [ShotRecoil]. Null is a weapon that leaves its holder where they stand.
var shot_recoil: ShotRecoil

var _bonus: Dictionary[int, float] = {}


## Adds [param amount] to [param stat]'s bonus.
func add(stat: Stat, amount: float) -> void:
	_bonus[stat] = get_bonus(stat) + amount


## Adds [param modifier] [param times] over - a level-3 upgrade is its step three
## times.
func add_modifier(modifier: WeaponStatModifier, times: float = 1.0) -> void:
	if modifier != null:
		add(modifier.stat, modifier.amount * times)


## A separate block holding the same numbers, for one shot that changes them on
## top - see [method PumpCharge.charged_stats]. Changing the copy leaves this block,
## and every round already armed from it, as it was.
func duplicate_stats() -> WeaponStats:
	var copy := WeaponStats.new()
	copy.base_critical_chance = base_critical_chance
	copy.base_critical_multiplier = base_critical_multiplier
	copy.shot_pattern = shot_pattern
	copy.pump_charge = pump_charge
	copy.shot_explosion = shot_explosion
	copy.fan_hammer = fan_hammer
	copy.shot_recoil = shot_recoil
	copy._bonus = _bonus.duplicate()
	return copy


## The summed bonus on [param stat], 0 when nothing has touched it.
func get_bonus(stat: Stat) -> float:
	return _bonus.get(stat, 0.0)


static func is_percent(stat: Stat) -> bool:
	return PERCENT_STATS.has(stat)


## What a round's damage is multiplied by at [param progress] along its range,
## 0 at the muzzle and 1 at the end - the flat damage bonus times the close and
## long bonuses blended across the flight.
func damage_scale_at(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	var near := 1.0 + get_bonus(Stat.CLOSE_DAMAGE)
	var far := 1.0 + get_bonus(Stat.LONG_DAMAGE)
	return maxf(1.0 + get_bonus(Stat.DAMAGE), 0.0) * maxf(lerpf(near, far, p), 0.0)


## How much of the profile's damage fall-off is left - 1 is all of it, 0 none.
func falloff_scale() -> float:
	return clampf(1.0 - get_bonus(Stat.DAMAGE_FALLOFF), 0.0, 1.0)


func range_scale() -> float:
	return maxf(1.0 + get_bonus(Stat.RANGE), 0.05)


func speed_scale() -> float:
	return maxf(1.0 + get_bonus(Stat.PROJECTILE_SPEED), 0.05)


func size_scale() -> float:
	return maxf(1.0 + get_bonus(Stat.PROJECTILE_SIZE), 0.05)


func knockback_scale() -> float:
	return maxf(1.0 + get_bonus(Stat.KNOCKBACK), 0.0)


func stagger_scale() -> float:
	return maxf(1.0 + get_bonus(Stat.STAGGER), 0.0)


func blood_gain_scale() -> float:
	return maxf(1.0 + get_bonus(Stat.BLOOD_GAIN), 0.0)


func critical_chance() -> float:
	return clampf(base_critical_chance + get_bonus(Stat.CRITICAL_CHANCE), 0.0, 1.0)


func critical_multiplier() -> float:
	return maxf(base_critical_multiplier + get_bonus(Stat.CRITICAL_DAMAGE), 1.0)


func ammo_save_chance() -> float:
	return clampf(get_bonus(Stat.AMMO_EFFICIENCY), 0.0, 1.0)


func magazine_bonus() -> int:
	return roundi(get_bonus(Stat.MAGAZINE_SIZE))


func ammo_capacity_bonus() -> int:
	return roundi(get_bonus(Stat.AMMO_CAPACITY))


func pellet_bonus() -> int:
	return roundi(get_bonus(Stat.PELLET_COUNT))


## Extra enemies each round carries on to - see [member Projectile.bounce_count].
func bounce_bonus() -> int:
	return maxi(roundi(get_bonus(Stat.BOUNCE_COUNT)), 0)


## Extra enemies each round passes through - see [member Projectile.pierce_count].
func pierce_bonus() -> int:
	return maxi(roundi(get_bonus(Stat.PIERCE_COUNT)), 0)


## What the weapon's authored spread cone is multiplied by - 1 is as authored.
## Accuracy tightens it first; [constant Stat.SPREAD] is then added on top, so the
## one never cancels the other.
func spread_scale() -> float:
	return maxf(maxf(1.0 - get_bonus(Stat.ACCURACY), 0.0) + get_bonus(Stat.SPREAD), 0.0)


## The on-hit half of this block, in the form a [Hitbox] hands to [Health] - see
## [HitEffects].
func make_hit_effects() -> HitEffects:
	var effects := HitEffects.new()
	effects.knockback_scale = knockback_scale()
	effects.stagger_scale = stagger_scale()
	effects.blood_gain_scale = blood_gain_scale()
	return effects
