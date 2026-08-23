class_name TroubleRewardTier
extends Resource
## What a search for trouble is worth, for one band of Dangers.
##
## [b]The whole reward table is an array of these[/b] - see
## [member TroubleRewardDirector.tiers] - so the game's three bands are three
## [code].tres[/code] files and a fourth is a fourth file. There is no threshold, no
## band and no payout named anywhere in code, which is what lets the ladder be
## retuned, extended or rebalanced entirely from the inspector.
##
## A tier is asked one question - [method covers] - and answers two:
## [method roll_blood] and [member item_count].

## The band of Dangers this tier pays for, inclusive at both ends. The deepest
## Danger actually beaten is what is matched against it, so a search that went to 6
## and stopped is paid at the tier covering 6.
@export var min_danger: int = 1
@export var max_danger: int = 3

@export_group("Blood")
## The range paid straight into the player's hands, rolled per chest. Both ends
## inclusive; a tier with the two set the same pays a flat amount.
@export var blood_min: int = 500
@export var blood_max: int = 1500

@export_group("Items")
## How many items the chest holds on top of the blood. 0 is a purse and nothing
## else, which is what the shallow end of the ladder pays.
@export var item_count: int = 0


## Whether this tier is the one that pays for [param danger].
func covers(danger: int) -> bool:
	return danger >= min_danger and (max_danger <= 0 or danger <= max_danger)


## What this chest pays this time, rolled between the two ends of the range.
func roll_blood() -> int:
	var low := mini(blood_min, blood_max)
	var high := maxi(blood_min, blood_max)
	if high <= low:
		return maxi(low, 0)
	return randi_range(maxi(low, 0), high)
