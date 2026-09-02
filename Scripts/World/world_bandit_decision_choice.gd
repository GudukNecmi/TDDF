class_name WorldBanditDecisionChoice
extends Resource
## One button on the bandit-decision screen, and what answering it means.
##
## A resource rather than a struct in code for the same reason [TravelEvent]
## and [WaveRosterEntry] already are: the wording is content, not logic, so
## the exact line on a button - "Kill them all.", "Take the blood. Just
## leave me alone." - is a file a designer can open and reword without
## touching [WorldBanditDecisionMenu] or [WorldMapCombatBridge] at all.

## What the button says, verbatim.
@export var label: String = ""
## What choosing it means to [WorldMapCombatBridge] - one of
## [code]&"pay"[/code] (the player hands the bandits blood and the encounter
## ends), [code]&"walk_away"[/code] (nothing changes hands and it ends),
## [code]&"take"[/code] (the bandits hand the player blood and it ends) or
## [code]&"fight"[/code] (the encounter becomes the ordinary Arena fight).
## Read as a name rather than an enum so the resource stays plain data - see
## the class doc.
@export var outcome: StringName = &"fight"
