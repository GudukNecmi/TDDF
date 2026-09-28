class_name PumpCharge
extends Resource
## A pump weapon that keeps being worked after it is ready banks charge into its
## next shot - the part behind the shotgun's Legendary BLOOD PUMP.
##
## [b]It changes numbers only through [WeaponStats].[/b] Each charge is worth
## [member per_charge] - ordinary [WeaponStatModifier]s on ordinary stats - added
## to a copy of the weapon's block for the one shot that spends it. Damage, range,
## spread and the rest are then worked out by exactly the code that works them out
## for every other shot, so the common upgrades stack with it for free and there is
## no second damage or spread system anywhere.
##
## A weapon reads it off [member WeaponStats.pump_charge] - put there by a
## [WeaponLegendary] - and counts the charge itself; see [Shotgun]. Nothing here
## names a weapon.

## Most charge the weapon can bank. One charge is one full back-and-forward cycle.
@export_range(1, 20) var max_charges: int = 5
## What one charge adds to the shot that spends it. Each is applied
## [code]charge ^ charge_curve[/code] times, so five charges of +20% damage at a
## curve of 1 is +100%.
##
## Spread is [constant WeaponStats.Stat.SPREAD], which is added after accuracy has
## tightened the cone - so an accurate gun still blows wider with every charge.
@export var per_charge: Array[WeaponStatModifier] = []
## Shape of the build across the charges. 1 is even steps; above 1 holds the early
## charges back and makes the last ones count most.
@export_range(0.25, 3.0, 0.05) var charge_curve: float = 1.0
## Whether a back-stroke worked on a loaded, closed gun banks charge rather than
## throwing the live round away. On: charging costs no ammunition and ejects no
## shell. Off: every stroke costs what it always did.
@export var charging_keeps_round: bool = true

@export_group("Max charge")
## Added once, on top of [member per_charge], to the shot that spends a full
## charge only - BLOOD PUMP's piercing blast is [constant WeaponStats.Stat.PIERCE_COUNT]
## here, read by the same [member Projectile.pierce_count] logic the lever action's
## PIERCE upgrade uses. Charges below full never get any of it.
@export var max_charge_modifiers: Array[WeaponStatModifier] = []
## How the rounds of that full-charge shot look and trail, so the player can see it
## pierce. Only its look and trail are meant to change anything: keep its spread
## multiplier and speed at 1 and its weave and tracking at 0. Used only while the
## weapon has no [ShotPattern] of its own, so it never replaces another
## Legendary's. Null changes nothing.
@export var max_charge_pattern: ShotPattern

@export_group("Readout")
## What the charge readout over the ammunition shows at each charge, %d standing
## for the charge. Empty at 0, so the readout is only up while something is banked.
@export var label_format: String = "CHARGE %d"
## Shown instead once the charge is full.
@export var max_label: String = "MAX CHARGE"
## Size of the readout at one charge and at full, against its own base size.
@export var label_scale_min: float = 0.8
@export var label_scale_max: float = 1.35


## How many times [member per_charge] applies at [param charge].
func weight(charge: int) -> float:
	if charge <= 0:
		return 0.0
	return pow(float(mini(charge, max_charges)), charge_curve)


## A copy of [param stats] with [param charge] charges folded in - the block the
## shot that spends them is armed with. [param stats] itself is never touched, so
## the weapon's standing numbers are the same before and after.
func charged_stats(stats: WeaponStats, charge: int) -> WeaponStats:
	var copy := stats.duplicate_stats()
	var times := weight(charge)
	if times > 0.0:
		for modifier: WeaponStatModifier in per_charge:
			copy.add_modifier(modifier, times)
	if is_full(charge):
		for modifier: WeaponStatModifier in max_charge_modifiers:
			copy.add_modifier(modifier)
		if copy.shot_pattern == null:
			copy.shot_pattern = max_charge_pattern
	return copy


## Whether [param charge] is a full charge - the piercing blast.
func is_full(charge: int) -> bool:
	return charge > 0 and charge >= max_charges


## The readout text at [param charge], or an empty string for none.
func label_for(charge: int) -> String:
	if charge <= 0:
		return ""
	if is_full(charge):
		return max_label
	return label_format % charge if label_format.contains("%d") else label_format


func label_scale_for(charge: int) -> float:
	var t := clampf(float(charge - 1) / maxf(float(max_charges - 1), 1.0), 0.0, 1.0)
	return lerpf(label_scale_min, label_scale_max, t)
