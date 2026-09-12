class_name WorldBanditThreatProfile
extends Resource
## The thresholds a [WorldBandit] compares [member WorldBandit.group_strength]
## against [WorldMapPlayerPower] with, to decide whether spotting the player
## means fleeing, giving chase, or doing neither.
##
## [b]A ratio, not a hardcoded branch.[/b] Nothing in [code]world_bandit.gd[/code]
## reads like "if group_strength < 20" - it divides the two strengths and
## compares the result to [member flee_power_ratio] and
## [member chase_power_ratio], both retunable from the inspector without
## touching the AI script. A group roughly matched with the player crosses
## neither threshold and simply stays alert - see
## [enum WorldBandit.BehaviorState].PATROL and INVESTIGATE - rather than
## picking a side.

## How many times stronger the player has to be, as [member player_power]
## over [member WorldBandit.group_strength], before a group flees on sight.
@export var flee_power_ratio: float = 1.6
## How many times stronger a group has to be, as
## [member WorldBandit.group_strength] over [member player_power], before it
## gives chase on sight.
##
## [b]Below one on purpose: the two ratios together are the band, and the band
## has to be narrow.[/b] A group flees under [member flee_power_ratio] and
## chases over this one, so the two of them at 1.6 apiece left every group
## between 0.63 and 1.6 times the player's own power committing to neither -
## which on the Dust Camp, whose groups run from twelve to fifty-four against a
## player reading thirty, was all but the whole map riding past a player it had
## plainly seen. Bandits are the aggressor here: a group that is not quite the
## player's match still comes for them, and only one genuinely outmatched runs.
@export var chase_power_ratio: float = 1.6
## Seconds a bandit spends investigating the player's last known position
## before giving up and returning to its patrol route.
@export var investigate_duration: float = 4.0
