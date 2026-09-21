class_name RunMapMiniBossEncounter
extends Resource
## One kind of mini boss point on a run map: how many men stand in front of him,
## which rung he is fought at, and what the point becomes once he is down.
##
## [b]It is the twin of [RunMapBanditEncounter], for the same reason.[/b] A run
## map's points are dealt out by kind - see [RunMapSitePlan] - and what each kind
## is worth belongs beside the kind rather than in a branch. Adding a second,
## harder mini boss point to a map is a second [code].tres[/code] dropped into
## [member RunMapMiniBossNode.encounters]; nothing in any script names one.
##
## Nothing here says who the man is. That is [MiniBossWardrobe]'s, reached
## through [member look_key], so a run map boss is dressed by the same wardrobe
## as a bounty target and there is no second set of artwork for him.

## The site handle this answers - see [member RunMapSite.kind]. Empty answers
## nothing, which is a resource that has not been filled in.
@export var kind: StringName = &""
## What the point becomes once the fight is over, so a beaten boss is not
## standing there again when the piece rides back through. Empty leaves the
## point exactly as it was.
@export var cleared_kind: StringName = &""

@export_group("The men in front of him")
## Fewest supporting bandits the point can be worth. They are the whole of the
## first half of the encounter: the boss does not appear until they are dealt
## with.
@export var min_support: int = 12
## Most supporting bandits the point can be worth.
@export var max_support: int = 20

@export_group("The man himself")
## How much is taken as known about him, which is what picks his rung out of
## [member MiniBossDirector.tiers]. [b]There is no second difficulty curve[/b] -
## a run map boss is built at one of the rungs a bounty boss is built at, chosen
## here rather than read off a contract the player is not holding.
@export var boss_knowledge: int = 2
## His health as a multiple of an ordinary enemy's pool. A bounty boss reads this
## off what his contract pays; a run map point has no contract, so it is authored
## - and authored here rather than in a script, so a harder point is a number in
## the Inspector.
@export var boss_health_multiplier: float = 14.0
## What the title card calls him.
@export var display_name: String = "THE OUTLAW"
## Which face, body and weapon the wardrobe puts on him - see
## [method MiniBossDirector.look_key_for]. Left empty, the point's own site id is
## used instead, so every mini boss point on a map is a different man and the
## same point is the same man every time it is looked at.
@export var look_key: StringName = &""
