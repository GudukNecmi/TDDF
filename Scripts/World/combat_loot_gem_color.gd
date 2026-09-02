class_name CombatLootGemColor
extends Resource
## One colour a Gem can drop in - see [member CombatLootTable.gem_colors].
##
## A colour is a resource rather than a string literal or an enum entry so that
## the roster of them is an inspector array on [CombatLootTable]: a fifth
## colour later is a fourth [code].tres[/code] dropped in beside these, with its
## own identity and its own picture, and nothing in [CombatLootGenerator] has to
## learn a new name to draw it.

## The stacking identity - what [method CombatLoot.add] and [method RunInventory.add_item]
## key two Gems of the same colour together on. Never shown.
@export var id: StringName = &"gem"
## What the stack prints - "GREEN GEM".
@export var display_name: String = "GEM"
## Picture for the stack. [HorseCartScreen] does not draw item icons yet - see
## [member RunItemStack.icon]'s own doc - so this is read for the day it does,
## and left null costs nothing today.
@export var icon: Texture2D
