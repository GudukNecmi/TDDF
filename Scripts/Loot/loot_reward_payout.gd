class_name LootRewardPayout
extends LootReward
## Blood already paid into the player's hands by the time the Loot Screen opens -
## a bounty's reward, credited by [BossDefeat] on the killing hit.
##
## [b]It is shown, not paid.[/b] Paying is still [BossDefeat]'s and happens where
## it always did, so the card is dealt already settled - it is the table telling
## the player what the fight was worth, never a second payment.


func get_amount_text() -> String:
	return ""
