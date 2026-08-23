class_name RoundCounter
extends Node
## Which round the player is on, and nothing else.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet] and its [code]Blood[/code] autoload are: a [code]class_name[/code]
## that matches an autoload's name shadows it and refuses to compile. Reach the
## live one as [code]RunProgress[/code]; the type is [RoundCounter] where a
## reference has to be statically typed.
##
## Registered as the [code]RunProgress[/code] autoload for exactly the reason
## [BloodWallet] is: pressing NEXT ROUND rebuilds the World scene, and an
## autoload is the one thing in the tree that a
## [method SceneTree.reload_current_scene] does not touch. The round number is
## therefore the only thing that carries from one round into the next, which is
## what makes each one harder than the last rather than a repeat of the first.
##
## It deliberately holds no difficulty numbers of its own. What a round is
## *worth* is [WaveManager]'s business and is exported there, so the curve can be
## retuned in the inspector without this file knowing what a round means. All
## this owns is the count.

## Emitted whenever the round number moves.
signal round_changed(round_number: int)
## Emitted whenever the player's level moves.
signal level_changed(level: int)

var _round: int = 1
## What the player has grown into. 1 until there is a progression system to move
## it - see [method get_player_level].
var _level: int = 1


## 1 during the first round of a session.
func get_round() -> int:
	return _round


## How many rounds of growth have been banked - 0 on the first round. This is
## the exponent a difficulty curve wants, so a caller never has to remember
## whether the count is one-based.
func get_rounds_elapsed() -> int:
	return maxi(_round - 1, 0)


## What level the player is on. [b]1 until there is a progression system.[/b]
##
## It is here, beside the round, because this is already the thing that survives the
## world being rebuilt and is already what the difficulty curves ask - so the level
## reaches them the same way the round does, and the progression milestone has one
## number to start moving rather than a system to wire in. Everything that scales
## off the player reads this today and keeps working unchanged the day it starts
## going up; see [method MiniBossDirector.get_level_health_multiplier].
func get_player_level() -> int:
	return maxi(_level, 1)


## Sets the level, for the progression system that will own it and for a debug
## readout. Returns whether it was a change.
func set_player_level(level: int) -> bool:
	var wanted := maxi(level, 1)
	if wanted == _level:
		return false
	_level = wanted
	level_changed.emit(_level)
	return true


## Moves on to the next round and returns its number.
func advance() -> int:
	_round += 1
	round_changed.emit(_round)
	return _round


## Back to round 1, for a new save or a debug reset. Nothing in a run calls this,
## so the count can only ever go up during play.
func reset() -> void:
	if _round == 1:
		return
	_round = 1
	round_changed.emit(_round)
