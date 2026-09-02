class_name CombatLootAmmoEntry
extends Resource
## One kind of ammunition a bandit fight can hand over - see
## [member CombatLootTable.ammo_entries].
##
## [member ammo_type] is the real [AmmoType] resource every carried weapon
## already feeds on - see [WeaponAmmo] - so a Combat Loot ammo stack is never a
## second idea of what a Revolver Round is; it stacks into [AmmoLocker] through
## the exact same identity a purchase or an [AmmoCrate] pickup does.
##
## [member base_magazine] is [b]not[/b] [member AmmoType.max_ammo] - that field
## is the reserve's own starting/base capacity, already used for the ordinary
## ammo-pickup stack ceiling elsewhere (see [method RunInventory.get_ammo_max_stack]),
## and this pass deliberately never touches it. What one Combat Loot ammo drop
## is sized against is the weapon's own magazine: the revolver's six-chamber
## cylinder, the lever rifle's seven-round tube - real numbers read off
## [code]revolver.gd[/code]'s [code]chamber_count[/code] and
## [code]lever_action_rifle.gd[/code]'s [code]magazine_size[/code] rather than
## invented here, and copied in rather than reflected out of those scenes so
## this table never has to load a weapon scene to answer a loot roll. The
## shotgun has no magazine field of its own to copy - it fires straight off the
## reserve - so its six is the one authored by hand, matching its own
## [code]pellet_count[/code] and the six rounds a box of shells already costs.

## The real ammunition this entry drops - what [method CombatLoot.add_ammo]
## stacks into.
@export var ammo_type: AmmoType
## One magazine's worth, for this weapon - 6 for the Revolver, 7 for the Lever
## Action Rifle, 6 for the Shotgun. What one successful ammo roll hands over is
## this times [member CombatLootTable.sample_ammo_quantity_multiplier], and what
## one Combat Loot stack of it can ever hold is this times
## [member CombatLootTable.ammo_stack_multiplier].
@export var base_magazine: int = 6
