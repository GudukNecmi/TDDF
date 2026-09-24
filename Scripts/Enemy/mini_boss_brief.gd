class_name MiniBossBrief
extends RefCounted
## Who a mini boss is and how hard he is, with nothing in it about where he came
## from.
##
## [b]It exists so there is one boss builder rather than two.[/b] A bounty
## contract answers four questions about the man - what he is called, whose face
## he wears, how much health he carries and which contract to close when he falls
## - and [method MiniBossDirector._build_boss] used to simply read a [Bounty] to
## get them. It cannot always: a run map bounty boss point is dealt on one side
## of a scene change and fought on the other, and only the contract's id survives
## the crossing. Rather than teach the builder about a second kind of origin, the
## four answers are lifted out into this, and every origin fills one in.
##
## [b]Nothing here is authored.[/b] Every brief the game builds is derived from a
## contract - see [method from_bounty] - so there is nowhere a boss's numbers
## could be written down and drift out of step with the poster.

## The contract this man answers, or empty for one who answers none. What
## [MiniBossDirector.place_encounter] picks the ledger's copy up by and what
## [BossDefeat] pays and closes out when he falls; empty means there is nothing
## to close and nothing to pay.
var contract_id: StringName = &""
## What the title card and the poster call him.
var display_name: String = "THE OUTLAW"
## Which face, body and weapon the wardrobe dresses him in - see
## [method MiniBossDirector.look_key_for]. The same key gives the same man every
## time, so a boss rebuilt after a reload is recognisably himself.
var look_key: StringName = &""
## His health, as a multiple of the pool the ordinary enemy scene was authored
## with. Already clamped by whoever worked it out.
var health_multiplier: float = 1.0
## How much was known about him when this was settled. Carried onto [MiniBoss] as
## it always was; it is what picked the rung he is built at.
var known: int = 0


## The brief a bounty contract gives, read through [param director] for the parts
## that are its own tuning - the health curve and the look key.
##
## Answers null for no contract, so a caller can tell "this is a contract boss"
## from "this is somebody else's boss" by the same check either way.
static func from_bounty(bounty: Bounty, director: MiniBossDirector) -> MiniBossBrief:
	if bounty == null or director == null:
		return null
	var brief := MiniBossBrief.new()
	brief.contract_id = bounty.bounty_id
	brief.display_name = director.poster_name_for(bounty)
	brief.look_key = director.look_key_for(bounty)
	brief.health_multiplier = director.get_boss_health_multiplier(bounty)
	brief.known = director.get_accepted_knowledge(bounty)
	return brief
