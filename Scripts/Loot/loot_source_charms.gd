class_name LootSourceCharms
extends LootSourceDirect
## Charms the pouch may hold, dealt onto the table as [LootRewardCharm]s.
##
## Which Charm is drawn is a plain pick from [member charms]; a Charm listed
## twice is twice as likely. Taking one hands it to the Charm authority - see
## [LootRewardCharm].

## Every Charm the pouch can hold.
@export var charms: Array[CharmDefinition] = []

@export_group("Wording")
## Shown when there is no Charm authority to give it to.
@export var unavailable_text: String = "KAPALI"


func _make_reward(rng: RandomNumberGenerator, _context: LootContext) -> LootReward:
	var pool: Array[CharmDefinition] = []
	for charm: CharmDefinition in charms:
		if charm != null:
			pool.append(charm)
	if pool.is_empty():
		return null
	var entry := LootRewardCharm.new()
	entry.charm = pool[rng.randi_range(0, pool.size() - 1)]
	entry.unavailable_text = unavailable_text
	return entry
