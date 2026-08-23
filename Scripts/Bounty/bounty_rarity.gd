class_name BountyRarity
extends Resource
## One rung of how rare a contract is: how likely it is to be printed, where on
## the board it may hang, and what colour it glows.
##
## [b]Rarity is knowledge.[/b] A poster that gives everything away is common and a
## blind one is legendary, so a rung is keyed by the knowledge count it belongs to
## and nothing else has to be kept in step - the reward tier for that same count
## already exists beside it in [BountySettings], and the two are looked up the
## same way.
##
## It is a resource rather than a table in a script so the whole of the board's
## economy is inspector work: the odds, the slots a rung is allowed to occupy and
## its colour are all fields on a [code].tres[/code]. A fifth rung - a fourth kind
## of knowledge, say - is one more file, with no branch anywhere that would have
## to learn about it.

## How many pieces of knowledge a contract has to have been generated with for
## this to be its rung.
@export var knowledge_count: int = 0
## What the player is shown it is called: "COMMON", "LEGENDARY".
@export var display_name: String = "COMMON"

@export_group("Odds")
## How likely this rung is, as a relative weight against the others. The four
## authored rungs sit at 40, 30, 20 and 10, which reads as percentages because
## they happen to add to a hundred - nothing requires that, and a fifth rung can
## simply be given a weight of its own.
@export var weight: float = 10.0

@export_group("Board")
## First slot on the board this rung may hang in, counting from 1.
@export var first_slot: int = 1
## Last slot it may hang in. Equal to [member first_slot] pins a rung to one
## position, which is what the legendary rung does.
@export var last_slot: int = 5

@export_group("Look")
## Colour of the glow around the poster. What tells the player at a glance which
## rung a contract is without reading it.
@export var outline_colour := Color(0.4, 0.85, 0.4)
## How strong that glow is drawn, as a multiplier on whatever the poster's own
## outline width is. 0 leaves a rung unmarked.
@export var outline_strength: float = 1.0


## Whether this rung is allowed to hang in [param slot], counting from 1.
func allows_slot(slot: int) -> bool:
	return slot >= mini(first_slot, last_slot) and slot <= maxi(first_slot, last_slot)


## Every slot this rung may hang in, for a generator picking one.
func get_slots(slot_count: int) -> Array[int]:
	var slots: Array[int] = []
	for slot: int in range(mini(first_slot, last_slot), maxi(first_slot, last_slot) + 1):
		if slot >= 1 and slot <= slot_count:
			slots.append(slot)
	return slots


## Whether this rung outranks [param other]. [b]Rarer wins[/b], and rarer means
## knowing less - so a blind legendary takes a contested slot from a common one
## that gives all three lines away.
func outranks(other: BountyRarity) -> bool:
	if other == null:
		return true
	return knowledge_count < other.knowledge_count
