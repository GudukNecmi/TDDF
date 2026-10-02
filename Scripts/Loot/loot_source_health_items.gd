class_name LootSourceHealthItems
extends LootSourceDirect
## Health items the pouch may hold - whisky glass, 35cl and 50cl bottles - dealt
## onto the table as [LootRewardHealth]s.
##
## Which item is drawn is a weighted pick by [member HealthLootDefinition.weight];
## what each is worth is the item's own data.

## Every Health item the pouch can hold.
@export var items: Array[HealthLootDefinition] = []

@export_group("Wording")
## Shown when the player is already whole.
@export var full_text: String = "CANIN DOLU"
## Shown when there is no player to heal.
@export var unavailable_text: String = "KAPALI"


func _make_reward(rng: RandomNumberGenerator, _context: LootContext) -> LootReward:
	var item := pick(rng)
	if item == null:
		return null
	var entry := LootRewardHealth.new()
	entry.item = item
	entry.full_text = full_text
	entry.unavailable_text = unavailable_text
	return entry


## One item, weighted, or null when none can be drawn.
func pick(rng: RandomNumberGenerator) -> HealthLootDefinition:
	var total := 0.0
	for item: HealthLootDefinition in items:
		if item != null:
			total += maxf(item.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for item: HealthLootDefinition in items:
		if item == null:
			continue
		roll -= maxf(item.weight, 0.0)
		if roll < 0.0:
			return item
	return null
