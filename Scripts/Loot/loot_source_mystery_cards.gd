class_name LootSourceMysteryCards
extends LootSourceUpgrade
## The mystery [code]?[/code] cards a won run map point pays, dealt onto the Loot
## Screen as [LootRewardMystery]s - the weapon-upgrade reward's new form.
##
## [b]How many is still the reward data's.[/b] The first of
## [member LootSourceUpgrade.rewards] that pays for the point's kind is used, as
## the upgrade source always did, and its [member RunMapUpgradeReward.picks] is
## the number of [code]?[/code] cards: Bandit Group 1, Bandit Camp 2, Bounty Boss 3.
## Nothing here or on the screen asks which encounter it was. What each card
## deals is [member generator]'s, so [member RunMapUpgradeReward.choices] and its
## Unique chance are not used by this source.

## Deals every selection - choice count, Luck, card-type and rarity rolls.
@export var generator: RewardChoiceGenerator

@export_group("Mystery Wording")
## Under a mystery card once it has been opened.
@export var opened_text: String = "AÇILDI"
## Under a mystery card when no selection surface could be found.
@export var unavailable_text: String = "KAPALI"


func contribute(bundle: LootBundle, context: LootContext) -> void:
	if bundle == null or context == null or generator == null:
		return
	var reward := _reward_for(context.site_kind)
	if reward == null:
		return
	var weapon := _equipped_weapon(context.host)
	if weapon == null:
		return
	for _card: int in mystery_count(reward):
		var entry := LootRewardMystery.new()
		entry.look = look
		entry.generator = generator
		entry.weapon = weapon
		entry.rng = context.rng
		entry.resolved_text = opened_text
		entry.unavailable_text = unavailable_text
		bundle.add(entry)


## How many mystery cards [param reward] is worth.
func mystery_count(reward: RunMapUpgradeReward) -> int:
	return maxi(reward.picks, 0) if reward != null else 0
