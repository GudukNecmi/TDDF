class_name LootRewardLead
extends LootRewardStack
## A Boss Information stack of a fight's [CombatLoot], as a card on the Loot
## Screen.
##
## [b]It never goes into the Horse Inventory.[/b] Exactly as on the Horse Cart,
## a lead is spent at once through [method CombatLoot.teach_lead], one line of one
## outstanding contract at a time; a lead with nothing left to teach is refused
## and left standing.

## Shown when every outstanding contract is already fully known.
var nothing_to_learn_text: String = "NOTHING LEFT TO LEARN"
## The contract ledger the lead is spent through - the [code]Bounties[/code]
## autoload.
var ledger_path: NodePath = ^"/root/Bounties"


func _activate(context: LootContext) -> void:
	var host: Node = context.host if context != null else null
	var ledger: BountyLedger = null
	if host != null:
		ledger = host.get_node_or_null(ledger_path) as BountyLedger
	if ledger == null or loot == null or stack == null:
		_finish(false, nothing_to_learn_text)
		return
	var index := loot.stacks.find(stack)
	if index < 0:
		_finish(true)
		return
	if not CombatLoot.teach_lead(ledger):
		_finish(false, nothing_to_learn_text)
		return
	loot.remove_from_stack(index, 1)
	_finish(loot.stacks.find(stack) < 0)
