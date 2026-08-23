class_name StreakCounter
extends Node
## How many outlaws the player has put down since they were last paid.
##
## The class and the singleton are named apart on purpose, exactly as [BloodWallet],
## [RoundCounter] and [RunSessionState] are: a [code]class_name[/code] matching an
## autoload's name shadows it and refuses to compile. Reach the live one as
## [code]Streak[/code]; the type is [StreakCounter] where a reference has to be
## statically typed.
##
## It is an autoload for the same reason the round counter is. A streak is built up
## across several rounds of one run, and every round rebuilds the World scene - an
## autoload is the one thing a [method SceneTree.reload_current_scene] does not touch,
## so the count is still standing when the player walks into the next arena.
##
## [b]It is worth nothing at all until blood is put somewhere safe.[/b] Nothing while the
## player is out in the world reads this: an enemy that drops thirty blood drops thirty
## blood on a streak of one and on a streak of five, the boss's own body is worth what it
## says, and a contract pays what it locked in. The multiplication only ever happens as a
## pile leaves the player's hands - carried through the door of the base, see
## [CashOutScreen], or stashed at a camp on the way, see [method CampMenu.deposit_blood] -
## which is what makes a streak a bet rather than an income: every outlaw put down raises
## what the run will pay and raises what dying costs, and the two rise together.
##
## [b]Stashing does not end it; the two ways home do.[/b] A camp pays the streak and leaves
## it standing - it is a place to leave blood, not the reckoning, and what stops that being
## free money is that a camp only holds so much, see [member CampMenu.camp_blood_capacity].
## Getting home banks the streak and clears it; being killed clears it and banks nothing -
## see [method PlayerDeathSequence._spill_carried_blood], which drops both in the same
## breath. Those two are the only things that clear it, and nothing else in the game writes
## to this.

## Emitted on every change to the count, whatever caused it. A readout should follow
## this rather than the two below, so it cannot miss one.
signal changed(streak: int)
## Emitted only when the streak is extended, with what it now stands at.
signal increased(streak: int)
## Emitted as the streak is given up - banked at the base, or lost with the player.
signal cleared(from_streak: int)

var _streak: int = 0


## How many outlaws are on the current streak. 0 on a run where none has been beaten.
func get_streak() -> int:
	return _streak


## What the ride home pays out at: 1 for a run with no boss beaten and for a run with
## one, then one further multiple per outlaw after that.
##
## [b]A streak of nothing is not a payout of nothing.[/b] The count is the honest
## number of men put down, so it starts at zero and reads zero on the screen; the floor
## of 1 is applied here, at the one place the count is turned into money, rather than
## by pretending the player has a streak they have not earned.
func get_multiplier() -> int:
	return maxi(_streak, 1)


## What [param amount] is worth at the current streak. The single place the
## multiplication happens, so a readout showing the player what they are about to be
## paid and the payment itself are the same arithmetic rather than two copies of it.
func apply_to(amount: int) -> int:
	return maxi(amount, 0) * get_multiplier()


## The part of [method apply_to] that is the streak's doing rather than the player's
## own blood - what has to be minted on top of a straight transfer into the base's
## pool.
func get_bonus(amount: int) -> int:
	return apply_to(amount) - maxi(amount, 0)


## Extends the streak and returns what it now stands at. Called once per outlaw put
## down, at the moment he goes down - see [method BossDefeat._begin_defeat] - and never
## for the body being finished off afterwards, which is the same man a second time.
func add(count: int = 1) -> int:
	if count <= 0:
		return _streak

	_streak += count
	increased.emit(_streak)
	changed.emit(_streak)
	return _streak


## Back to nothing, reporting what was given up. Paid out at the base and lost on a
## death; both go through here, so there is one place a streak ends.
func reset() -> int:
	if _streak == 0:
		return 0

	var was := _streak
	_streak = 0
	cleared.emit(was)
	changed.emit(_streak)
	return was
