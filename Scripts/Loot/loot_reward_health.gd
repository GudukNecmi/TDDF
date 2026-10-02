class_name LootRewardHealth
extends LootReward
## A Health item lying on the Loot Screen's table - drunk on the spot.
##
## [b]The heal is the player's own [Health], unchanged.[/b] A click finds the
## player's pool exactly as the Horse Cart's Heart does and calls
## [method Health.heal] with [member HealthLootDefinition.heal_fraction] of its
## maximum; [HealthCarry] carries the result home as it carries any other heal.
## A full pool refuses the item, so nothing is wasted - it is optional loot and
## never holds the table.

## What the item is and is worth.
var item: HealthLootDefinition
## The group the player is found in.
var player_group: StringName = &"player"
## Shown when the player is already whole.
var full_text: String = "CANIN DOLU"
## Shown when there is no player to heal.
var unavailable_text: String = "KAPALI"


func get_title() -> String:
	if item != null and not item.display_name.is_empty():
		return item.display_name
	return super.get_title()


func get_detail() -> String:
	if item != null and not item.description.is_empty():
		return item.description
	return super.get_detail()


func get_art() -> LootObjectArt:
	if item != null and item.art != null:
		return item.art
	return super.get_art()


## The amount [param health] would be given back.
func heal_amount_for(health: Health) -> float:
	if health == null or item == null:
		return 0.0
	return health.get_max() * maxf(item.heal_fraction, 0.0)


func _activate(context: LootContext) -> void:
	var health := _find_health(context.host if context != null else null)
	if health == null or item == null:
		_finish(false, unavailable_text)
		return
	if health.is_full():
		_finish(false, full_text)
		return
	health.heal(heal_amount_for(health))
	_finish(true)


func _find_health(host: Node) -> Health:
	if host == null or not host.is_inside_tree():
		return null
	var player := host.get_tree().get_first_node_in_group(player_group)
	if player == null:
		return null
	for node: Node in player.find_children("*", "Health", true, false):
		if node is Health:
			return node as Health
	return null
