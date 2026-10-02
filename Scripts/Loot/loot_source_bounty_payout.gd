class_name LootSourceBountyPayout
extends LootSource
## The bounty a beaten outlaw was worth, put on the Loot Screen as Blood to be
## collected ([LootRewardBlood]).
##
## [b]The amount is the contract's, never this source's.[/b] [BossDefeat] holds
## the bounty back on the killing hit when a Loot Screen will present the win,
## and this takes it over with [method BossDefeat.hand_over_owed] - so it can
## only be handed out once, and collecting it is the one payment. Like everything
## on the table it is optional: left lying there, it is forfeited with the rest
## and never paid afterwards. A bounty that
## was paid on the kill (no Loot Screen claimed the win) is shown already paid,
## as before, and never paid a second time. A fight with no outlaw in it adds
## nothing.

## How the Blood looks.
@export var look: LootRewardLook
@export_group("Wording")
## The Blood's main line.
@export var title_text: String = "BOUNTY BLOOD"
## The Blood's detail: [code]%d[/code] is the blood.
@export var detail_format: String = "+%d Kan"
## Under the Blood once it has been collected.
@export var collected_text: String = "ALINDI"
## Under a bounty that was paid on the kill.
@export var paid_text: String = "ÖDENDİ"


func contribute(bundle: LootBundle, context: LootContext) -> void:
	if bundle == null or context == null:
		return
	var defeat := BossDefeat.get_active(context.host)
	if defeat == null or defeat.get_paid_amount() <= 0:
		return
	var entry := LootRewardBlood.new()
	entry.look = look
	entry.title = title_text
	entry.detail_format = detail_format
	var owed := defeat.hand_over_owed()
	if owed > 0:
		entry.amount = owed
		entry.resolved_text = collected_text
	else:
		entry.amount = defeat.get_paid_amount()
		entry.resolved_text = paid_text
		entry.mark_resolved()
	bundle.add(entry)
