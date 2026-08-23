class_name DevBalance
extends Resource
## The whole of what the developer panel can tune, in one saveable resource.
##
## It is a list and nothing else: one [DevWeaponBalance] per weapon, in the order
## the panel should show them. Everything about what a row *means* lives on those
## entries, so adding a weapon to the panel is adding an entry in the inspector and
## pointing it at that weapon's ammunition and bullet - there is no weapon named in
## this file and nothing here to edit for one.
##
## [b]This is the thing that is saved.[/b] The authored copy at
## [code]res://Resources/dev_balance.tres[/code] carries only the links - which
## resources each weapon is made of - and the numbers are captured off those
## resources the first time the panel is opened. Pressing SAVE writes the edited
## copy to [code]user://[/code], which is what makes an override survive the game
## being closed while leaving the project's own authored values untouched. See
## [DevBalanceStore], which owns both halves of that.

## The weapons the panel offers, in the order it lists them.
@export var weapons: Array[DevWeaponBalance] = []


## Fills every entry from the resources it points at, so the panel opens showing
## the numbers the game is actually running.
func capture() -> void:
	for weapon: DevWeaponBalance in weapons:
		if weapon != null:
			weapon.capture()


## Pushes every entry back into those resources. This is the whole of how a saved
## balance reaches the game.
func apply() -> void:
	for weapon: DevWeaponBalance in weapons:
		if weapon != null:
			weapon.apply()


## A copy that can be edited without the live one moving, which is what the panel
## stages its edits in - so typing in a box changes nothing until SAVE is pressed.
##
## Deep, because the entries are what actually hold the numbers; a shallow copy
## would hand the panel the very objects it is meant not to be writing to yet. It
## is deliberately the *internal* deep copy: the entries are built into this
## resource and are duplicated, while the [AmmoType] and [ProjectileProfile] each
## one points at are files of their own and must come through as the very same
## objects the game is reading, or applying the copy would write into nothing.
func working_copy() -> DevBalance:
	return duplicate_deep() as DevBalance
