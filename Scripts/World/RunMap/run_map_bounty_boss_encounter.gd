class_name RunMapBountyBossEncounter
extends Resource
## One kind of bounty boss point on a run map: how many men stand with the
## outlaw, and what the point becomes once he is down.
##
## [b]It is the twin of [RunMapBanditEncounter], for the same reason.[/b] A run
## map's points are dealt out by kind - see [RunMapSitePlan] - and what each kind
## is worth belongs beside the kind rather than in a branch. Adding a second,
## heavier sort of bounty point to a map is a second [code].tres[/code] dropped
## into [member RunMapBountyBossNode.encounters]; nothing in any script names
## one.
##
## [b]Nothing here says who the man is or how hard he is.[/b] Both are the
## contract's, read off the [Bounty] the point stands for - what it pays decides
## his health, what was known when it was taken decides his rung, and the outlaw
## named on it decides his face. That is the whole difference between this and
## the authored mini boss point it replaced: a run map boss is a bounty boss, so
## there is no second difficulty curve and no second set of numbers to drift out
## of step with the poster.

## The site handle this answers - see [member RunMapSite.kind]. Empty answers
## nothing, which is a resource that has not been filled in.
@export var kind: StringName = &""
## What the point becomes once the fight is over, so a beaten outlaw is not
## standing there again when the piece rides back through. Empty leaves the
## point exactly as it was.
@export var cleared_kind: StringName = &""

@export_group("The men with him")
## Fewest supporting bandits the point can be worth - how many are kept on the
## field around him for the whole fight, each one who goes down replaced from
## off the screen. See [method AmbushWaveDirector.sustain].
@export var min_support: int = 12
## Most supporting bandits the point can be worth. Equal to [member min_support]
## for a fixed count.
@export var max_support: int = 12
