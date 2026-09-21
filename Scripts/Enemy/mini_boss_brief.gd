class_name MiniBossBrief
extends RefCounted
## Who a mini boss is and how hard he is, with nothing in it about where he came
## from.
##
## [b]It exists so there is one boss builder rather than two.[/b] A bounty
## contract answers four questions about the man - what he is called, whose face
## he wears, how much health he carries and which contract to close when he falls
## - and until the run map there was nowhere else those answers could come from,
## so [method MiniBossDirector._build_boss] simply read a [Bounty]. A run map's
## mini boss point has no contract behind it and never will: it is a place on a
## graph, not a piece of paper the player is holding. Rather than teach the
## builder about a second kind of origin, the four answers are lifted out into
## this, and both origins fill one in.
##
## [b]Nothing here is authored.[/b] A contract's brief is derived from the
## contract - see [method from_bounty] - and a run map point's from its own
## [RunMapMiniBossEncounter], so there is no third place a boss's numbers could
## be written down and drift out of step with the two real ones.

## The contract this man answers, or empty for one who answers none. What
## [BossDefeat] closes out when he falls; empty means there is nothing to close
## and nothing to pay, which is exactly what a run map boss wants until his own
## rewards are built.
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
