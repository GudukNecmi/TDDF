class_name ExtractionSettlement
extends RefCounted
## What one Extraction was worth, worked out once by [WorldMapExtractionService]
## and read by everything downstream of it: the result screen that shows it
## to the player, and [signal WorldMapExtractionService.run_extracted] - the
## clean run-ended hook rule 20 of the Extraction phase asks for, so a later
## Score system can total a finished run without this file knowing Score
## exists.
##
## [b]It is a receipt, not a calculator.[/b] Every field here is already
## final by the time this is built - see [method WorldMapExtractionService._settle] -
## so nothing that reads this ever recomputes the formula rule 11 defines;
## it only ever prints numbers that are already true.
##
## [b]Horse Blood and Depot Blood are the same total, read twice.[/b] This
## project keeps one run-scoped "protected" wallet - [code]HorseBlood[/code],
## the [HorseBloodStorage] autoload - and a Blood Depot's own job is only
## ever to move blood onto it; see that class's own doc, "the blood a Blood
## Depot has moved onto the horse". There is no second, separate depot stash
## anywhere in this project for [member horse_blood] to be confused with, so
## rather than invent one to make two numbers where the game only has one,
## [member horse_blood] is deliberately what both "Horse Protected Blood"
## and "Secured Depot Blood" name in the Extraction phase's own rules 9 and
## 14 - one figure, honestly read out under both descriptions, rather than a
## phantom currency that would let the same blood be paid out twice.

## What the player was carrying at the moment of extraction - the [code]Blood[/code]
## autoload's total, read before it was cleared.
var player_blood: int = 0
## What had been moved onto the horse, through however many Blood Depot
## visits this run made - the [code]HorseBlood[/code] autoload's total,
## read before it was cleared. See the class doc for why this is also what
## a "Depot Blood" line reads.
var horse_blood: int = 0
## [member player_blood] plus [member horse_blood], before any bounty
## reward or penalty - the [code]base_run_blood[/code] rule 11 names.
var base_run_blood: int = 0

## Every carried bounty that was completed this run.
var completed_bounties: Array[Bounty] = []
## Every carried bounty that was still outstanding - accepted, not finished -
## at the moment of extraction. A missed boss is exactly this: rule 20 of the
## bounty camps phase already refuses to mark a missed schedule failed on its
## own, so it is Extraction, not a missed encounter, that finally decides a
## contract did not get finished in time.
var incomplete_bounties: Array[Bounty] = []
## [member completed_bounties].size() times the reward configured on
## [member WorldMapExtractionService.completed_bounty_reward].
var bounty_reward_total: int = 0
## The sum of every incomplete bounty's own region penalty - see
## [member WorldMapExtractionService.region_incomplete_penalties].
var bounty_penalty_total: int = 0

## [member base_run_blood] + [member bounty_reward_total] - [member bounty_penalty_total],
## clamped so a run whose penalties outweighed everything it earned pays the
## permanent economy nothing rather than a negative figure - rule 11's own
## clamp. This is what was actually added to [code]BloodBank[/code].
var final_blood: int = 0


## One line per figure, for a developer readout or a print during a test.
func get_debug_text() -> String:
	var lines := PackedStringArray([
		"EXTRACTION SETTLEMENT",
		"  player blood      %d" % player_blood,
		"  horse/depot blood %d" % horse_blood,
		"  base run blood    %d" % base_run_blood,
		"  bounties done     %d  (+%d)" % [completed_bounties.size(), bounty_reward_total],
		"  bounties missed   %d  (-%d)" % [incomplete_bounties.size(), bounty_penalty_total],
		"  FINAL BLOOD       %d" % final_blood,
	])
	return "\n".join(lines)
