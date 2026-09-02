class_name WorldBanditDecisionTier
extends Resource
## What a bandit group says, and what the player may say back, at one of the
## three readings a contact can come out as - STRONGER, EQUAL or WEAKER. See
## [WorldBanditDecisionEvaluator] for how a contact is sorted into one of
## the three, and [Resources/World/Decision/] for the three files this
## project ships: one bandit line picked at random from
## [member bandit_lines], and however many buttons [member choices] carries.

## What the bandit says, picked at random each time this tier is shown.
@export var bandit_lines: Array[String] = []
## The player's own replies - one button per entry, in order.
@export var choices: Array[WorldBanditDecisionChoice] = []


## One line, picked at random. Empty when nothing is authored, which
## [WorldBanditDecisionMenu] reads as a blank line rather than an error.
func pick_line() -> String:
	if bandit_lines.is_empty():
		return ""
	return bandit_lines[randi() % bandit_lines.size()]
