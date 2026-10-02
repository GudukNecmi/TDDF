class_name LootRewardCharm
extends LootReward
## A Charm lying on the Loot Screen's table, straight out of the pouch.
##
## [b]Taking it is the Charm authority's add, nothing else.[/b] A click hands the
## Charm to [RunCharmHolder] - the [code]Charms[/code] autoload - which stacks it
## with any copy already worn and never refuses one. It is not a Card and never
## goes near the Card hand or the weapon.

## The Charm.
var charm: CharmDefinition
## Shown when there is no Charm authority to give it to.
var unavailable_text: String = "KAPALI"


func get_title() -> String:
	if charm != null and not charm.display_name.is_empty():
		return charm.display_name
	return super.get_title()


func get_detail() -> String:
	if charm != null and not charm.description.is_empty():
		return charm.description
	return super.get_detail()


func get_tint() -> Color:
	return charm.color if charm != null else super.get_tint()


func _activate(context: LootContext) -> void:
	var holder := RunCharmHolder.get_active(context.host if context != null else null)
	if holder == null or charm == null:
		_finish(false, unavailable_text)
		return
	_finish(holder.add_charm(charm), unavailable_text)
