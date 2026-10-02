class_name LootRewardBlood
extends LootReward
## Blood lying on the Loot Screen's table, collected into the carried wallet.
##
## [b]The wallet is the [code]Blood[/code] autoload ([BloodWallet]) - the one the
## HUD shows.[/b] A click adds [member LootReward.amount] to it through
## [method BloodWallet.add]; there is no second wallet. How much is never decided
## here: whoever put the reward on the table set the amount from its own data
## (see [LootSourceBountyPayout]).

## The carried wallet.
var wallet_path: NodePath = ^"/root/Blood"
## Shown when there is no wallet to pay into.
var unavailable_text: String = "KAPALI"
## The card's detail: [code]%d[/code] is the amount.
var detail_format: String = "+%d Kan"


func get_detail() -> String:
	if not detail.is_empty():
		return detail
	return detail_format % amount if detail_format.contains("%d") else detail_format


## The amount is in the detail line, never as a stack count.
func get_amount_text() -> String:
	return ""


func _activate(context: LootContext) -> void:
	var host: Node = context.host if context != null else null
	var wallet: BloodWallet = null
	if host != null and host.is_inside_tree():
		wallet = host.get_node_or_null(wallet_path) as BloodWallet
	if wallet == null or amount <= 0:
		_finish(false, unavailable_text)
		return
	wallet.add(amount)
	_finish(true)
