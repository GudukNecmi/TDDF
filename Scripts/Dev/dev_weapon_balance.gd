class_name DevWeaponBalance
extends Resource
## One weapon's tuning numbers, as the developer panel shows them.
##
## [b]It is a view of the real resources, not a second copy of them.[/b] Every
## number here belongs to something the game already reads - a capacity on an
## [AmmoType], a damage or a speed on a [ProjectileProfile] - and this holds a
## reference to those resources rather than a duplicate of their contents. It is
## filled by [method capture], which reads the live values out of them, and it is
## spent by [method apply], which writes the edited values back in.
##
## That is what stops the balance panel becoming a second place the game's numbers
## are written down. Retuning a weapon in the inspector, in its own [code].tres[/code],
## still works exactly as it did; the panel picks the new value up the next time it
## captures, because there is nowhere else for it to read one from.
##
## Adding a weapon to the panel is adding one of these to [DevBalance] and pointing
## its two resource fields at that weapon's ammunition and its bullet. No field
## below names a weapon, so nothing here has to be edited for it.

## What the panel calls this weapon. Free text: it is a heading, not an id.
@export var display_name: String = ""
## The ammunition this weapon feeds on - the same [AmmoType] resource its
## [WeaponAmmo] points at. Left unset, the ammunition row is simply not offered.
@export var ammo_type: AmmoType
## The bullet's distance profile - the same [ProjectileProfile] its projectile
## scene carries. Left unset, the damage, speed and range rows are not offered.
@export var projectile_profile: ProjectileProfile

@export_group("Ammunition")
## Total rounds the player can carry of this ammunition, before any shop upgrade.
## This is the reserve, not the magazine: the cylinder, the tube and the breech
## are the weapon's own business and are untouched by it.
@export var max_ammo: int = 0

@export_group("Damage")
## What one round does at point blank.
@export var damage_near: float = 0.0
## What it is down to at the far end of its range. The fall-off between the two is
## the profile's own curve and is not exposed here - it is shape, not balance.
@export var damage_far: float = 0.0

@export_group("Flight")
## How fast the round leaves the barrel, in pixels per second.
@export var projectile_speed: float = 0.0
## How far it reaches before it is spent, in pixels.
##
## It is the master number of the whole profile: damage, speed, colour, glow and
## light are all sampled against it, so moving this moves where every one of them
## falls off, together.
@export var projectile_range: float = 0.0


## Every number on this resource the panel should offer a row for, in the order
## they are declared, each tagged with the [code]@export_group[/code] it sits under.
##
## [b]It is read off the resource itself rather than listed here.[/b] Godot already
## knows what is exported, what type it is and which group it belongs to, so asking
## it is what makes adding a tunable value a matter of writing one
## [code]@export[/code] above - the panel grows a row for it with no list anywhere
## to be kept in step, and no name of a field written down twice.
##
## Only numbers are offered. The two resource references are what this is pointed
## at rather than something to tune, and the display name is a heading.
func get_editable_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var group := ""
	for property: Dictionary in get_property_list():
		var usage: int = property.get("usage", 0)
		if usage & PROPERTY_USAGE_GROUP:
			group = String(property.get("name", ""))
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue

		var type: int = property.get("type", TYPE_NIL)
		if type != TYPE_INT and type != TYPE_FLOAT:
			continue

		var name := String(property.get("name", ""))
		rows.append({
			"name": name,
			"label": name.capitalize(),
			"group": group,
			"is_int": type == TYPE_INT,
		})
	return rows


## Reads the live numbers out of the resources this is pointed at, so the panel
## opens showing what the game is actually running rather than what somebody typed
## into a copy of it.
func capture() -> void:
	if ammo_type != null:
		max_ammo = ammo_type.max_ammo
	if projectile_profile != null:
		damage_near = projectile_profile.damage_near
		damage_far = projectile_profile.damage_far
		projectile_speed = projectile_profile.speed_near
		projectile_range = projectile_profile.effective_range


## Writes the edited numbers back into those same resources, which is what makes a
## change to this actually change the game.
##
## [b]It writes to the loaded resources, not to the files on disk.[/b] The
## [code].tres[/code] the project ships stays exactly as it was authored, so the
## developer's overrides live entirely in their own saved balance and can be thrown
## away by deleting it.
func apply() -> void:
	if ammo_type != null:
		ammo_type.max_ammo = maxi(max_ammo, 0)
	if projectile_profile == null:
		return

	projectile_profile.damage_near = maxf(damage_near, 0.0)
	projectile_profile.damage_far = maxf(damage_far, 0.0)
	projectile_profile.speed_near = maxf(projectile_speed, 1.0)
	projectile_profile.effective_range = maxf(projectile_range, 1.0)
