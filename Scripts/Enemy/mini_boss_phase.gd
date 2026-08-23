class_name MiniBossPhase
extends Resource
## One band of a mini boss's health, and everything that is true of the fight while
## the boss is in it: how its support arrives, how fast it moves, and what colour it
## is.
##
## [b]A boss fight changes as it is worn down, and this is where that is written.[/b]
## [BossPhases] holds an ordered list of these, highest band first, and reads the one
## the boss's current health falls into - so the whole shape of the fight is an array
## of resources in the inspector rather than thresholds in a script. Retuning where
## the support thins out, or adding a fourth band at a quarter health, is a number on
## a [code].tres[/code] or one more entry in the list; nothing about it comes back to
## code.
##
## The three bands the game ships with are the brief's:
##
##   [codeblock]
##   above 75%   groups of 2     ordinary speed
##   75% - 50%   groups of 3     ordinary speed
##   below 50%   no support      +20% speed, washed red
##   [/codeblock]
##
## [b]It is deliberately one resource covering both halves[/b] rather than a wave
## table and a separate enrage table. The support drying up and the boss turning on
## the player are the same event described twice - the fight becoming one on one -
## and splitting them across two lists would make it possible to author a band where
## only one of the two happened.
##
## What it is [i]not[/i] is how tough the boss is. That is [MiniBossTier], chosen once
## from the contract's knowledge and applied as the boss is built. A phase multiplies
## what the tier already decided, so the same phase table works for the easiest boss
## and the hardest one.

## What to call this band, for a readout, a log line or a test. Nothing is derived
## from it.
@export var phase_name: String = ""
## The bottom of the band, as a fraction of the boss's maximum health. The band covers
## everything [i]above[/i] this, down to whichever band comes next in the list.
##
## The last entry's value is not really read - see [method BossPhases.find_phase],
## which falls back to the final band for anything no band claims - so the bottom of
## the table can be authored as 0 and means "everything left".
@export_range(0.0, 1.0, 0.01) var hp_above: float = 0.0

@export_group("Support")
## How many enemies arrive together while the boss is in this band. [b]0 is what ends
## the support for good[/b]: a band that sends nobody makes the rest of the fight one
## on one, and because a boss's health only ever falls, a band once left is never
## returned to.
@export var group_size: int = 0
## Seconds between one group and the next.
@export var group_interval: float = 2.0
## Seconds between the individual men of one group.
##
## [b]Deliberately a tenth of a second[/b], which is the brief's number: a group is
## meant to arrive as a group rather than as a single simultaneous pop, and staggering
## them by a frame or two is the difference between men walking in and men appearing.
## It is not a pause - three men at this spacing are all on the field inside a third
## of a second.
@export var spawn_spacing: float = 0.1

@export_group("The boss")
## What the boss's walking speed is multiplied by in this band, against the speed it
## started the fight at.
##
## [b]Measured from the start of the fight, not from the band before[/b], so the
## multipliers do not compound: a band at 1.2 is 20% faster than the boss ever was,
## whichever bands it passed through on the way down. That is what keeps a fourth
## band addable without every number after it moving.
@export var speed_multiplier: float = 1.0
## How heavily the boss is washed in [member tint_color] in this band. 0 leaves the
## art exactly as it is, which is every band but the last.
##
## [b]It is a wash, not a repaint[/b] - subtle on purpose, so an enraged boss reads as
## the same man in a worse mood rather than as a different enemy. The red outline is a
## separate uniform and is unaffected; see [method MiniBoss.apply_tint].
@export_range(0.0, 1.0, 0.01) var tint_strength: float = 0.0
## The colour of that wash. The game's own red.
@export var tint_color := Color(1.0, 0.16, 0.14, 1.0)


## Whether [param fraction] of the boss's health falls in this band.
func covers(fraction: float) -> bool:
	return fraction > hp_above


## Whether this band sends anybody at all.
func sends_support() -> bool:
	return group_size > 0


func _to_string() -> String:
	var who := phase_name if not phase_name.is_empty() else "unnamed"
	return "<MiniBossPhase %s  above %.0f%%  groups of %d  speed x%.2f>" % [
		who, hp_above * 100.0, group_size, speed_multiplier,
	]
