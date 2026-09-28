class_name WeaponLegendary
extends Resource
## One Legendary upgrade a weapon can carry: not a level of a stat but a change to
## how the weapon fights.
##
## [b]Kept apart from [WeaponUpgrade] on purpose.[/b] The Base's UPGRADE screen,
## the run map market and the camp rewards all deal from
## [member WeaponDefinition.upgrades]; a Legendary is listed in
## [member WeaponDefinition.legendaries] instead, so none of those ever offers one.
## It is either on or off, and while it is on its parts are folded into the
## weapon's [WeaponStats] like any other source, so the combat code keeps reading
## the one block it always did.
##
## What it does is the parts it carries. Each part is an optional resource the
## combat code already knows how to read; a Legendary that needs a kind of change
## nothing reads yet adds that one part here.

## Stable key the weapon files its state under. Must be unique among one weapon's
## Legendaries and must not change.
@export var id: StringName = &""
## What the developer panel and any later card call it.
@export var display_name: String = "LEGENDARY"
## One line on what it does.
@export_multiline var description: String = ""

@export_group("Parts")
## How the rounds of each shot leave and fly while this is on. Null changes
## nothing about the shot.
@export var shot_pattern: ShotPattern
## How working a pump weapon past ready banks charge into its next shot. Null
## leaves the pump cycling as it always did.
@export var pump_charge: PumpCharge
## What every round does as it lands or runs out of range. Null leaves the rounds
## only hitting.
@export var shot_explosion: ShotExplosion
## How the pump is worked with the trigger held - one press, a whole cycle, the
## held trigger firing as it closes. Null leaves the pump as two presses.
@export var fan_hammer: FanHammer
## The shove every shot gives whoever is holding the weapon. Null leaves the
## holder standing where they fired from.
@export var shot_recoil: ShotRecoil


## Folds this Legendary's parts into [param stats].
func apply_to(stats: WeaponStats) -> void:
	if shot_pattern != null:
		stats.shot_pattern = shot_pattern
	if pump_charge != null:
		stats.pump_charge = pump_charge
	if shot_explosion != null:
		stats.shot_explosion = shot_explosion
	if fan_hammer != null:
		stats.fan_hammer = fan_hammer
	if shot_recoil != null:
		stats.shot_recoil = shot_recoil
