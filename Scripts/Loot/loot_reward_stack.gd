class_name LootRewardStack
extends LootReward
## One stack of a fight's [CombatLoot] - gems, hearts, ammunition - as a card on
## the Loot Screen.
##
## [b]Claiming it is the run inventory's add, nothing else.[/b] A click hands the
## stack to [RunInventory] - where Gems and the rest of a run's loot are carried -
## through [method RunInventory.add_item] and takes off the loot only what found
## room, so a stack with no room left is left standing, never destroyed. The card
## settles once the whole stack has gone across.

## The loot the stack belongs to.
var loot: CombatLoot
## The stack itself - the same object [member CombatLoot.stacks] holds, so a
## partial claim shows at once.
var stack: RunItemStack
## Shown when the run inventory has no room for any of it.
var no_room_text: String = "NO ROOM"


func get_title() -> String:
	if stack != null and not stack.display_name.is_empty():
		return stack.display_name
	return super.get_title()


func get_amount() -> int:
	return stack.count if stack != null else 0


func get_icon() -> Texture2D:
	if stack != null and stack.icon != null:
		return stack.icon
	return super.get_icon()


func _activate(context: LootContext) -> void:
	var inventory := RunInventory.get_active(context.host if context != null else null)
	if inventory == null or loot == null or stack == null:
		_finish(false, no_room_text)
		return
	var index := loot.stacks.find(stack)
	if index < 0:
		_finish(true)
		return
	var added := inventory.add_item(
		stack.item_id, stack.display_name, stack.count, stack.max_count,
		stack.category, stack.icon, stack.payload)
	if added > 0:
		loot.remove_from_stack(index, added)
	var gone := loot.stacks.find(stack) < 0
	_finish(gone, "" if added > 0 else no_room_text)
