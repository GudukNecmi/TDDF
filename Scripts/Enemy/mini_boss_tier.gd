class_name MiniBossTier
extends Resource
## One rung of the mini boss: how much the contract knew, and what that makes the
## man waiting at the end of it.
##
## [b]The rungs are a list, not a branch.[/b] [MiniBossDirector] holds an inspector
## array of these and looks one up by knowledge count - see
## [method MiniBossDirector.find_tier] - so a fourth kind of knowledge, a retune of
## the curve, or a rung between two existing ones is a [code].tres[/code] file
## dropped into that array. No knowledge count, size or health figure appears in
## any script.
##
## What a rung says is deliberately only what varies between them. Everything a
## boss has in common with every other boss - that it hits for two hearts, that it
## is outlined in red, how far off it waits - is one value on the director rather
## than the same value repeated on four resources, so retuning it is one edit.
## Speed and the size of the support group are the two that could reasonably go
## either way, so they are here as *overrides* that inherit from the director until
## a rung actually wants to differ.
##
## [b]A rung no longer decides how much health the boss has.[/b] What the man is
## worth is what he pays: his pool is read off [member Bounty.reward] through
## [method MiniBossDirector.get_reward_health_multiplier], so a 2000-blood contract
## is the hardest fight in the desert whether the player took it blind or knew every
## line of it. The rungs are still what knowledge buys - a known contract is a
## smaller, slower man with fewer men round him - it simply no longer buys a
## shallower health pool.

## How much was known about the contract when it was accepted. The number this rung
## is found by; 3 is a contract the player had read inside out, 0 one they took
## blind.
@export var knowledge: int = 0

@export_group("The boss")
## How large the boss is drawn and collides, as a multiple of an ordinary Bandit.
## Written onto the instance's own [member Node2D.scale], so the artwork, the
## hitboxes, the shadow and the knife all grow together.
@export var scale_multiplier: float = 1.5

@export_group("Overrides")
## What the boss's walk is multiplied by, or 0 to use
## [member MiniBossDirector.boss_speed_multiplier]. For a rung that should be
## faster as well as bigger.
@export var speed_multiplier: float = 0.0
## How many support enemies stand with this boss, or below 0 to use
## [member MiniBossDirector.support_count]. For a rung that should bring a larger
## crowd rather than only a larger man.
@export var support_count: int = -1


## Whether this rung is the one for [param known] pieces of knowledge.
func matches(known: int) -> bool:
	return knowledge == known


func _to_string() -> String:
	return "<MiniBossTier knowledge %d  scale %.2f>" % [knowledge, scale_multiplier]
