class_name BountyRewardTier
extends Resource
## What a bounty pays for being worth taking blind.
##
## The whole of the reward rule is "the less you know, the more it pays", and
## this is one rung of it: a knowledge count, and the range a bounty generated at
## that count is worth. The tiers are an inspector array on [BountySettings], so
## retuning the economy is editing four [code].tres[/code] files and adding a
## fourth kind of knowledge is adding a fifth one - there is no table of numbers
## in any script.
##
## [b]The range is where this rung leans, not a fence around it.[/b] Every contract
## is rolled from the one band on [member BountySettings.reward_minimum] to
## [member BountySettings.reward_maximum], and what a rung does is pull that roll
## towards its own middle - so a blind contract is usually worth 1500-2000 and
## occasionally is not, and a poster the player has read inside out can still,
## rarely, be the richest one on the board. Nothing about a price is therefore proof
## of anything, which is the property the wanted board wants.
##
## See [method BountySettings.get_knowledge_centre] for how the middle is read, and
## [method BountySettings.roll_reward] for how hard it pulls.

## How many pieces of knowledge a bounty has to have for this rung to be the one
## that leans it.
@export var knowledge_count: int = 0
## The cheap end of what it is normally worth, in blood.
@export var min_reward: int = 100
## The rich end of the same.
@export var max_reward: int = 500
