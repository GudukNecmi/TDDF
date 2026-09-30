class_name RunCard
extends Resource
## One Card: something bought for the current run only, held by the
## [code]RunCards[/code] autoload - see [RunCardHolder].
##
## [b]It is data, not an effect.[/b] This is what a card is called, what it costs
## off a market's shelf, whether it can be dealt at all, and the parts it hands to
## systems that already exist: a [member kill_reward] is pushed onto the weapons'
## stats by [RunCardHolder] through [method WeaponDefinition.set_kill_reward_source].
## A card with none of those parts is held and does nothing. Later kinds of effect
## hang off [RunCardHolder]'s own signals, or off
## [method WeaponDefinition.set_modifier_source] for a card that moves weapon stats.
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

@export_group("Effect")
## What a kill with one of [member weapon_ids] leaves behind while this card is held
## - DEVIL'S COIN's Blood Coin. Pushed onto those weapons' [WeaponStats] by
## [RunCardHolder], so it is credited through the same kill attribution a Legendary's
## reward is. Null is a card with no kill reward.
@export var kill_reward: KillReward
## The weapons, by [member WeaponDefinition.weapon_id], whose kills [member kill_reward]
## rides on. Empty is every weapon.
@export var weapon_ids: Array[StringName] = []


## Whether this card's effect reaches [param weapon].
func applies_to(weapon: WeaponDefinition) -> bool:
	return weapon != null and (weapon_ids.is_empty() or weapon_ids.has(weapon.weapon_id))
