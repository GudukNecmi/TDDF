class_name LootSourceBountyPayout
extends LootSource
## The bounty a beaten outlaw was worth, shown on the Loot Screen as an
## already-paid [LootRewardPayout].
##
## [b]It pays nothing.[/b] [BossDefeat] paid the contract into the carried blood
## on the killing hit, as it always has; this reads what it paid back off it -
## [method BossDefeat.get_paid_amount] - and adds a card only when something was.
## A fight with no outlaw in it has nothing paid and so adds nothing.

## How the card looks.
@export var look: LootRewardLook
@export_group("Wording")
## The card's main line: [code]%d[/code] is the blood paid.
@export var title_format: String = "%d BLOOD"
## The card's detail: [code]%s[/code] is the outlaw's name.
@export var detail_format: String = "BOUNTY ON %s"
## Under the card - it was paid on the kill.
@export var paid_text: String = "PAID"


func contribute(bundle: LootBundle, context: LootContext) -> void:
	if bundle == null or context == null:
		return
	var defeat := BossDefeat.get_active(context.host)
	if defeat == null or defeat.get_paid_amount() <= 0:
		return
	var entry := LootRewardPayout.new()
	entry.look = look
	entry.title = title_format % defeat.get_paid_amount()
	var bounty := defeat.get_paid_bounty()
	var named := ""
	if bounty != null and bounty.target != null:
		named = bounty.target.display_name
	entry.detail = detail_format % named if not named.is_empty() else ""
	entry.resolved_text = paid_text
	entry.mark_resolved()
	bundle.add(entry)
