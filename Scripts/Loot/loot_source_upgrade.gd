class_name LootSourceUpgrade
extends LootSource
## The free weapon upgrade a won run map point pays - [RunMapUpgradeReward],
## dealt onto the Loot Screen as a [LootRewardUpgrade].
##
## [b]Which points pay, and how much, is still the reward's.[/b] The first of
## [member rewards] whose [member RunMapUpgradeReward.site_kinds] names the point
## is used, exactly as [RunMapUpgradeRewardScreen] picked it before; a point none
## of them names adds nothing. The draw is made when the bundle is built - the
## moment of the win, as it always was.

## What each kind of point pays. The first entry that pays for the point's kind
## is the one used.
@export var rewards: Array[RunMapUpgradeReward] = []
## How the card looks.
@export var look: LootRewardLook
## The run's state, asked which weapon is carried when no [WeaponMount] answers.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Wording")
## The card's detail for a single upgrade: [code]%s[/code] is the weapon.
@export var single_detail_format: String = "FOR YOUR %s\nFREE  -  THIS RUN ONLY"
## The card's detail for a selection: the picks, the choices per pick, then the
## weapon.
@export var selection_detail_format: String = "%d PICKS OF %d\nFOR YOUR %s"


func contribute(bundle: LootBundle, context: LootContext) -> void:
	if bundle == null or context == null:
		return
	var reward := _reward_for(context.site_kind)
	if reward == null:
		return
	var weapon := _equipped_weapon(context.host)
	if weapon == null:
		return

	var entry := LootRewardUpgrade.new()
	entry.look = look
	entry.reward = reward
	entry.weapon = weapon
	entry.rng = context.rng
	entry.required = true
	entry.amount = reward.picks
	if reward.choices > 1:
		# Nothing to choose from is the old flow's "no screen" - checked on a
		# throwaway generator so the real selection is dealt exactly as before.
		var probe := RandomNumberGenerator.new()
		probe.seed = context.rng.seed
		if reward.draw_choices(weapon, probe).is_empty():
			return
		entry.detail = selection_detail_format % [reward.picks, reward.choices,
			weapon.display_name]
	else:
		entry.upgrade = reward.draw(weapon, context.rng)
		if entry.upgrade == null:
			return
		entry.detail = single_detail_format % weapon.display_name
	bundle.add(entry)


func _reward_for(site_kind: StringName) -> RunMapUpgradeReward:
	for reward: RunMapUpgradeReward in rewards:
		if reward != null and reward.pays_for(site_kind):
			return reward
	return null


## The weapon in the player's hands - the one the Market deals for too.
func _equipped_weapon(host: Node) -> WeaponDefinition:
	if host == null:
		return null
	var mount := WeaponMount.get_active(host)
	if mount != null and mount.get_definition() != null:
		return mount.get_definition()
	var session := host.get_node_or_null(session_path) as RunSessionState
	if session == null or session.get_weapon_catalog() == null:
		return null
	var catalog := session.get_weapon_catalog()
	var chosen := catalog.find(session.get_weapon_id())
	return chosen if chosen != null else catalog.get_default()
