class_name RunVitals
extends Node
## How much health the player is carrying, kept across the world being rebuilt.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet], [DayClock], [AmmoLocker] and [RunSessionState] are: a
## [code]class_name[/code] matching an autoload's name shadows it and refuses to
## compile. Reach the live one as [code]Vitals[/code]; the type is [RunVitals]
## where a reference has to be statically typed.
##
## [b]It exists because the player is rebuilt and their wounds are not.[/b] Going
## on to the next round rebuilds the World scene, and the player's [Health] comes
## back at its ceiling because that is what a fresh pool is. That was fine while
## rounds ran back to back with nothing in between; it stops being fine the moment
## the camp sells healing, because a heart bought for blood would be handed back
## for free thirty seconds later. So the pool is remembered here - an autoload,
## which is the one thing in the tree a
## [method SceneTree.reload_current_scene] does not touch, and the same mechanism
## the carried blood and the ammunition already survive on.
##
## It holds one number and no rules. Whether a rebuilt player should be given it
## back is [HealthCarry]'s question, and when it should be forgotten is
## [RunSessionState]'s - a run beginning and a run ending both clear it, so
## setting out from the base is always at full health and only the rounds inside
## one run carry their damage forward.

## Emitted whenever the carried pool changes, so a readout could follow it. The
## HUD does not need this - it reads the live [Health] - but a camp screen shown
## outside the arena one day would.
signal carried_changed(current: float)

## Emitted when the way the player's health is presented changes - see
## [method set_display]. Every health readout follows it, so a card switching the
## run to hearts takes effect on screen the moment it is played.
signal display_changed(display: HealthDisplay)

## How the player's health is presented. It changes nothing about the pool itself -
## [Health] is the same number of points either way, hit, healed and killed exactly
## as before - only which readout is drawn over it.
enum HealthDisplay {
	## One continuous bar over the whole pool, read as a percentage. The default.
	BAR,
	## One heart per point, as [HeartBar] draws them. What a card switches a run to.
	HEARTS,
}

## What the player was last seen at, or below zero when nothing is being carried -
## which every caller reads as "give them a full pool".
var _current: float = -1.0
## The ceiling of the last player pool seen, or below zero before any has been.
## [b]Not wounds, so not forgotten by [method clear].[/b] It is what lets a screen
## with no player on it - the World Map - turn the carried points into a fraction,
## or into a row of hearts, without writing the player's maximum down a second time.
var _maximum: float = -1.0
var _display: HealthDisplay = HealthDisplay.BAR


## How the player's health is presented right now.
func get_display() -> HealthDisplay:
	return _display


func uses_hearts() -> bool:
	return _display == HealthDisplay.HEARTS


## Switches the presentation - the single call a card turning a run's health back
## into hearts makes. Announced, so every readout swaps over at once.
func set_display(display: HealthDisplay) -> void:
	if display == _display:
		return
	_display = display
	display_changed.emit(_display)


## Remembers the player's ceiling. Called by [HealthCarry] whenever the pool moves,
## in the base as well as in a run, since the ceiling is not a wound.
func record_maximum(maximum: float) -> void:
	_maximum = maxf(maximum, 0.0)


func has_maximum() -> bool:
	return _maximum > 0.0


## The last ceiling recorded. Meaningless unless [method has_maximum] is true.
func get_maximum() -> float:
	return maxf(_maximum, 0.0)


## Whether there is a remembered pool to give back.
func has_carried() -> bool:
	return _current >= 0.0


## What the player was carrying. Meaningless unless [method has_carried] is true.
func get_carried() -> float:
	return maxf(_current, 0.0)


## Remembers where the pool stands. Called as the player's health changes, so what
## is kept is always the last true answer rather than a snapshot taken at some
## moment somebody had to remember to take.
func carry(current: float) -> void:
	var value := maxf(current, 0.0)
	if is_equal_approx(value, _current):
		return
	_current = value
	carried_changed.emit(_current)


## Forgets the pool, so the next player built is left at full health. Called when
## a run begins and when it ends - see [RunSessionState].
func clear() -> void:
	if _current < 0.0:
		return
	_current = -1.0
	carried_changed.emit(0.0)
