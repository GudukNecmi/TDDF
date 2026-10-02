class_name LootBundle
extends Resource
## Everything one finished encounter hands over, as a list of [LootReward]s -
## what [LootScreen] is given and all it is given.
##
## [b]It does not say where it came from.[/b] Which encounter was won, and so
## what it pays, is settled by the [LootSource]s that fill this - see
## [PostCombatLootDirector] - and the screen presenting it never learns whether
## it was a bandit group, a camp or a bounty boss.

## Emitted whenever a reward in the bundle settles.
signal reward_settled(reward: LootReward)

## The rewards, in the order they are dealt onto the table.
@export var rewards: Array[LootReward] = []

## What the rewards are activated with - see [LootContext]. Set by whoever built
## the bundle.
var context: LootContext


func add(reward: LootReward) -> void:
	if reward == null or rewards.has(reward):
		return
	rewards.append(reward)
	reward.settled.connect(_on_reward_settled.bind(reward))


func is_empty() -> bool:
	return rewards.is_empty()


func size() -> int:
	return rewards.size()


## Whether every reward is done with.
func is_resolved() -> bool:
	for reward: LootReward in rewards:
		if reward != null and not reward.is_resolved():
			return false
	return true


## The rewards not yet done with - what leaving the table now would give up.
## Nothing on the table is ever owed: any of it, of any kind, may be left behind.
func get_unclaimed() -> Array[LootReward]:
	var unclaimed: Array[LootReward] = []
	for reward: LootReward in rewards:
		if reward != null and not reward.is_resolved() and not reward.is_forfeited():
			unclaimed.append(reward)
	return unclaimed


func has_unclaimed() -> bool:
	return not get_unclaimed().is_empty()


## Whether the screen may be closed now - only a reward in the middle of being
## taken holds it. Unclaimed rewards never do; see [method forfeit_unclaimed].
func can_leave() -> bool:
	for reward: LootReward in rewards:
		if reward != null and reward.is_busy():
			return false
	return true


## Gives up every reward still unclaimed, for good - the table has been left.
func forfeit_unclaimed() -> void:
	for reward: LootReward in get_unclaimed():
		reward.forfeit()


func _on_reward_settled(reward: LootReward) -> void:
	reward_settled.emit(reward)
