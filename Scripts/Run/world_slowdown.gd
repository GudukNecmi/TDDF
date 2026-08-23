class_name WorldSlowdown
extends Node
## Everything that walks moves at a fraction of its speed for a while.
##
## This is what plays under the round intro. The world used to be *frozen* while
## the title card was up, which stopped the card being read over a fight but also
## stopped the arena being alive at all - the player could not so much as turn
## around while they were being told where they were. A slow motion says the same
## thing without taking the game away: the round is visibly not under way yet, and
## the moment the card has gone everything is back at full speed.
##
## [b]It is deliberately not a time scale.[/b] [code]Engine.time_scale[/code]
## would drag the card's own animation, the soundtrack and every effect in the
## world along with it, and the intro would stretch to fit its own slowdown. What
## this scales is characters, and only characters: the player asks it for a
## multiplier alongside the ones its other components provide, and the enemies ask
## it for the same one. Everything else in the world runs at its ordinary speed.
##
## Nothing is ever written to anybody's speed either. Both readers multiply the
## answer into their movement for the frame, so switching the slowdown off is the
## whole of putting the world back - there is no state left behind on a character
## that could leave it permanently slow, and a character that spawns half way
## through is already moving at the right speed.

## Emitted as the slowdown comes on and goes off, for anything that wants to react
## to the world dropping into slow motion.
signal slowdown_changed(slowed: bool)

## Group this joins, so a character can find it without a path across the scene.
const GROUP := &"world_slowdown"

## What fraction of their speed characters move at while this is on. 0.75 is the
## quarter-slower the round intro plays at; lower is heavier, and 1 makes the
## slowdown do nothing at all without having to be removed.
@export_range(0.05, 1.0) var slow_multiplier: float = 0.75
## Whether the slowdown is on. Exported so the effect can be looked at in the
## editor and left on while a scene is being tuned.
@export var slowed: bool = false:
	set(value):
		if slowed == value:
			return
		slowed = value
		slowdown_changed.emit(slowed)


func _enter_tree() -> void:
	# Joined here rather than in `_ready`, so a character that readies before this
	# node does can still find it on its first frame.
	add_to_group(GROUP)


## The slowdown in this world, or null when it has none - which every caller reads
## as "nothing is slowed here".
static func get_active(from_node: Node) -> WorldSlowdown:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldSlowdown


## What to multiply a character's speed by this frame. 1 when there is no slowdown
## in the world or it is switched off, so a map without one moves exactly as it
## always did and this can be read unconditionally.
static func get_multiplier(from_node: Node) -> float:
	var slowdown := get_active(from_node)
	if slowdown == null or not slowdown.slowed:
		return 1.0
	return slowdown.slow_multiplier


## Turns the slow motion on and off. Called by [WorldBoot] as the round's intro
## begins and ends.
func set_slowed(value: bool) -> void:
	slowed = value
