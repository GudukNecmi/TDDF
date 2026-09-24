class_name RunCard
extends Resource
## One Card: something bought for the current run only, held by the
## [code]RunCards[/code] autoload - see [RunCardHolder].
##
## [b]It is data, not an effect.[/b] What a card does is not built yet; this is
## what a card is called, what it costs off a market's shelf and whether it can be
## dealt at all. A card's effect later hangs off [RunCardHolder]'s own signals, or
## off [method WeaponDefinition.set_modifier_source] for a card that moves weapon
## stats, without this resource having to change shape.
##
## Adding a card is a [code].tres[/code] of this dropped into
## [member RunMapMarketProducts.cards]; nothing names one in a script.

## Stable key the holder counts copies under. [b]Must be unique among cards and
## must not change.[/b]
@export var id: StringName = &""
## What the card is called on a shelf and in any later readout.
@export var display_name: String = "CARD"
## One line on what it will do. Optional.
@export_multiline var description: String = ""
## Picture for the card. Left null the card is lettering only.
@export var icon: Texture2D
## What it costs off a run map market's shelf, in carried blood.
@export var price: int = 100
## Whether a market may deal it. The gate a Base or Gem unlock flips; a locked card
## is never dealt.
@export var unlocked: bool = true
