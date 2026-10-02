class_name RewardChoice
extends RefCounted
## One card dealt into a reward selection: what it says, its rarity, and what
## taking it does.
##
## [b]The selection screen knows only this class.[/b] It shows
## [method get_title], [method get_rarity_name] and [method get_description] in
## the [member rarity]'s colour and calls [method apply] on the one picked - it
## never learns whether that was an upgrade, a Legendary or something added
## later. A new kind of card is a subclass and a [RewardChoicePool] that deals it.

## The card's rarity - its strength, colour, stinger and particles.
var rarity: UpgradeRarity


## The card's name, in Turkish.
func get_title() -> String:
	return ""


## The rarity line on the card.
func get_rarity_name() -> String:
	return rarity.display_name if rarity != null else ""


## The concise Turkish description with the exact numbers.
func get_description() -> String:
	return ""


## Optional artwork for the card's art window. Null leaves the window empty.
func get_art() -> Texture2D:
	return null


## What this card is, for keeping one selection free of repeats - the same
## upgrade or Legendary twice is the same key whatever its rarity.
func get_key() -> StringName:
	return &""


## The colour of everything rarity-tinted on the card.
func get_color() -> Color:
	return rarity.color if rarity != null else Color.WHITE


## Takes the card: hands it to the authority that owns its effect. Returns
## whether it landed.
func apply() -> bool:
	return false
