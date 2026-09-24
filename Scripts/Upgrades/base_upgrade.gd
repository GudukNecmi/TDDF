class_name BaseUpgrade
extends Resource
## One line of the Base's upgrade screen: what it is called, what each step
## costs, and the system it raises.
##
## [b]It holds no progress of its own.[/b] The level is always read back off the
## system the upgrade belongs to - the Bounty Board's capacity lives on the
## [code]Bounties[/code] autoload, a future weapon upgrade will live on the weapon -
## so the shop can never disagree with the thing it sold. A subclass only answers
## three questions: what level that system is on, how high it goes, and how to
## raise it one step. See [BountyCapacityUpgrade].
##
## Adding a weapon or player upgrade later is a new subclass and a [code].tres[/code]
## dropped into [member BaseUpgradeScreen.upgrades]; nothing in the screen changes.

## What the card is headed with.
@export var display_name: String = "UPGRADE"
## What each step costs, in banked blood: the first entry takes the system from
## its starting level to the next, and so on. A system with more levels than
## entries charges the last entry for the rest.
@export var level_costs: Array[int] = []
## How the card writes the level it is on and the most it can reach.
@export var level_format: String = "LEVEL %d / %d"


## The level [param from]'s tree currently has this upgrade at, 0 being none
## bought. Overridden.
func get_level(_from: Node) -> int:
	return 0


## The highest level there is. Overridden.
func get_max_level(_from: Node) -> int:
	return 0


## Raises the owning system one step and reports whether it went. Overridden;
## only ever called by [method purchase], after the price has been taken.
func _apply(_from: Node) -> bool:
	return false


## A short line saying what the next step does, for the card. Overridden where
## there is something to say.
func get_effect_text(_from: Node) -> String:
	return ""


func is_maxed(from: Node) -> bool:
	return get_level(from) >= get_max_level(from)


## What the next step costs, or -1 when there is no next step.
func get_next_cost(from: Node) -> int:
	if is_maxed(from) or level_costs.is_empty():
		return -1
	var index := clampi(get_level(from), 0, level_costs.size() - 1)
	return maxi(level_costs[index], 0)


func get_level_text(from: Node) -> String:
	return level_format % [get_level(from), get_max_level(from)]


## Buys the next step out of [param wallet]. The wallet decides whether it can be
## afforded, exactly as it does for every other purchase; the blood is handed back
## if the system then refuses the step, so a refusal never costs anything.
func purchase(from: Node, wallet: BloodWallet) -> bool:
	var cost := get_next_cost(from)
	if cost < 0 or wallet == null:
		return false
	if not wallet.spend(cost):
		return false
	if _apply(from):
		return true
	wallet.add(cost)
	return false
