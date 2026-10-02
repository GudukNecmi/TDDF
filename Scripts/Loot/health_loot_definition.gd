class_name HealthLootDefinition
extends Resource
## One Health item the pouch can hold - a whisky glass, a 35cl bottle, a 50cl
## bottle - and what drinking it is worth.
##
## [b]It is data, not a Health system.[/b] [LootRewardHealth] heals the player's
## own [Health] by [member heal_fraction] of its maximum through
## [method Health.heal]; nothing here holds or changes health itself.

## A handle for readouts and smoke checks. Never shown.
@export var id: StringName = &""
## The item's name on the table.
@export var display_name: String = ""
## What it does, in one line.
@export_multiline var description: String = ""
## How much of the player's maximum health it gives back, 0..1.
@export_range(0.0, 1.0, 0.01) var heal_fraction: float = 0.1
## How likely this item is against the others in a [LootSourceHealthItems] roll.
@export var weight: float = 1.0
## How it is drawn on the table.
@export var art: LootObjectArt
