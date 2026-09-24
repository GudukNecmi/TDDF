class_name BountyCapacityUpgrade
extends BaseUpgrade
## Raises how many contracts the Bounty Board lets the player hold, through
## [method BountyLedger.upgrade_capacity]. The levels and how many contracts each
## one holds are [member BountySettings.active_slot_levels]; this only sells them.

## The contracts - the [code]Bounties[/code] autoload.
@export var ledger_path: NodePath = ^"/root/Bounties"
## How the next step is described: the contracts held now and after buying it.
@export var effect_format: String = "CONTRACTS HELD  %d -> %d"
## How a fully upgraded board is described.
@export var maxed_format: String = "CONTRACTS HELD  %d"


func get_level(from: Node) -> int:
	var ledger := _ledger(from)
	return 0 if ledger == null else ledger.get_capacity_level()


func get_max_level(from: Node) -> int:
	var ledger := _ledger(from)
	return 0 if ledger == null else ledger.get_max_capacity_level()


func _apply(from: Node) -> bool:
	var ledger := _ledger(from)
	return ledger != null and ledger.upgrade_capacity()


func get_effect_text(from: Node) -> String:
	var ledger := _ledger(from)
	if ledger == null:
		return ""
	var now := ledger.get_active_slots()
	if is_maxed(from):
		return maxed_format % now
	return effect_format % [now, ledger.get_settings().get_active_slots(ledger.get_capacity_level() + 1)]


func _ledger(from: Node) -> BountyLedger:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null(ledger_path) as BountyLedger
