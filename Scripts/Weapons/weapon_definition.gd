class_name WeaponDefinition
extends Resource
## One weapon the player can take out on a run.
##
## Built the same way [MapDefinition] is, and for the same reason: the roster is
## an inspector array rather than a list in a script, so adding a third weapon is
## dropping a [code].tres[/code] into [WeaponCatalog] and nothing else. No file
## anywhere names the shotgun or the rifle, which is what stops the selection
## screen from having to be rewritten every time a weapon is added.
##
## What a weapon *is* is its scene. This resource is only the roster entry - the
## name on the button, whether it can be taken, and which scene to build when it
## is - so the weapon itself stays one self-contained scene with its own
## mechanism, its own feedback and its own magazine.

## The handle the rest of the game uses. What [RunSessionState] stores when the
## player picks it, and what the world's [WeaponMount] matches against to know
## what to build. Never shown.
@export var weapon_id: StringName = &"weapon"
## What the player is shown it is called, in the selection screen.
@export var display_name: String = "WEAPON"
## One line under the name, for what makes this weapon different from the others.
## Left empty, nothing is shown.
@export var description: String = ""
## The weapon itself: the scene built into the world when this is the one chosen.
## It must extend [CarriedWeapon], which is what lets the player's hands, the
## holster and the loadout treat every weapon the same way.
@export var scene: PackedScene
## The ammunition it feeds on, for a shop or a readout that wants to name it
## without the weapon being in the tree. The weapon's own [WeaponAmmo] is still
## what actually holds the rounds; this is a label, not a second source.
@export var ammo_type: AmmoType
## Whether the weapon can be picked. A locked weapon is still listed - seeing what
## is coming is the point - but cannot be selected and is drawn dimmed, exactly as
## a locked map is.
@export var unlocked: bool = true
## What a locked entry says instead of being selectable.
@export var locked_label: String = "LOCKED"
## Optional picture for the entry.
@export var icon: Texture2D
