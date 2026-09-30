class_name LootRewardUpgrade
extends LootReward
## A won point's free weapon upgrade, as a card on the Loot Screen.
##
## [b]It is the existing reward, handed over through the existing screen.[/b]
## What is drawn, how many picks and choices there are and how the level lands
## on the weapon are all still [RunMapUpgradeReward]'s; taking the card opens
## [RunMapUpgradeRewardScreen] exactly as a win used to, and the card settles when
## that screen reports it is done. Nothing about the reward's balance moves.

## What pays - see [RunMapUpgradeReward].
var reward: RunMapUpgradeReward
## The weapon it is for.
var weapon: WeaponDefinition
## The upgrade handed over when [member RunMapUpgradeReward.choices] is one -
## drawn when the fight was won, as it always was. Null for a selection, which is
## dealt as the screen opens.
var upgrade: WeaponUpgrade
## The generator every selection of this reward is dealt with.
var rng: RandomNumberGenerator

var _screen: RunMapUpgradeRewardScreen


func _activate(context: LootContext) -> void:
	_screen = RunMapUpgradeRewardScreen.get_active(context.host if context != null else null)
	if _screen == null or reward == null or weapon == null:
		_finish(false, "UNAVAILABLE")
		return
	if not _screen.finished.is_connected(_on_screen_finished):
		_screen.finished.connect(_on_screen_finished, CONNECT_ONE_SHOT)
	var opened := false
	if reward.choices > 1:
		opened = _screen.open_selection(weapon, reward, rng)
	else:
		opened = _screen.open_with(weapon, upgrade, reward)
	if opened:
		return
	if _screen.finished.is_connected(_on_screen_finished):
		_screen.finished.disconnect(_on_screen_finished)
	# The weapon has nothing left to be given - exactly the case the old flow
	# skipped the screen for - so there is nothing to hold the player to.
	_finish(true)


func _on_screen_finished() -> void:
	_screen = null
	_finish(true)
