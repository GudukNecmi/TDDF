class_name RewardPoolEntry
extends Resource
## One line of the per-slot card-type roll: a pool and its weight. Legendary 10
## and Upgrade 90 is a 10% Legendary chance per slot.

@export var pool: RewardChoicePool
@export_range(0.0, 1000.0, 0.01) var weight: float = 1.0
