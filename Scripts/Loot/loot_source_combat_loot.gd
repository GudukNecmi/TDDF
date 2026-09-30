class_name LootSourceCombatLoot
extends LootSource
## What the fight dropped - the bridge's [CombatLoot], rolled by
## [CombatLootDirector] as the fight opened - dealt onto the Loot Screen one card
## per stack.
##
## [b]Nothing is rolled here.[/b] The stacks are exactly those the Horse Cart used
## to show, in the same order and amounts; this only says how each category is
## drawn and whether it is claimed into the Horse Inventory ([LootRewardStack]) or
## spent on the spot as a lead ([LootRewardLead]).

## How each loot category is drawn, keyed by [member RunItemStack.category]
## ([code]gem[/code], [code]heart[/code], [code]ammo[/code],
## [code]boss_info[/code]).
@export var looks: Dictionary = {}
## Used for a category [member looks] does not name.
@export var fallback_look: LootRewardLook
## Categories spent on the spot through [method CombatLoot.teach_lead] rather
## than carried.
@export var lead_categories: Array[StringName] = [&"boss_info"]

@export_group("Wording")
## Shown on a card the Horse Inventory has no room for.
@export var no_room_text: String = "NO ROOM"
## Shown on a lead with nothing left to teach.
@export var nothing_to_learn_text: String = "NOTHING LEFT TO LEARN"


func contribute(bundle: LootBundle, context: LootContext) -> void:
	if bundle == null or context == null or context.bridge == null:
		return
	var loot := context.bridge.get_combat_loot()
	if loot == null:
		return
	for stack: RunItemStack in loot.get_stacks():
		if stack == null or stack.count <= 0:
			continue
		var entry: LootRewardStack
		if lead_categories.has(stack.category):
			var lead := LootRewardLead.new()
			lead.nothing_to_learn_text = nothing_to_learn_text
			entry = lead
		else:
			entry = LootRewardStack.new()
		entry.loot = loot
		entry.stack = stack
		entry.no_room_text = no_room_text
		var look := looks.get(stack.category) as LootRewardLook
		entry.look = look if look != null else fallback_look
		bundle.add(entry)
