class_name TestSpawnEntry
extends RefCounted
## One thing the [TestSpawnStation] can put on the ground, and everything it needs
## to know to build it.
##
## [b]It is a description, not a kind of enemy.[/b] Nothing here invents a creature:
## an entry names a scene the project already ships and, for a boss, the [MiniBossTier]
## and [BountyTarget] resources the real encounter is built out of. That is what makes
## the station's list a view of the game rather than a second roster to keep in step -
## see [method TestSpawnStation.build_entries], which reads all three off the live
## world.
##
## Built at the moment the station is opened and thrown away when it closes, so a
## resource edited in the inspector shows up the next time the station is used
## without a restart.

## What kind of thing this is. Only used to group the list under headings and to
## decide which half of the build applies.
enum Kind {
	## An ordinary enemy, spawned exactly as a wave spawns one.
	ENEMY,
	## A mini boss: the same enemy, wearing an outlaw's face and grown to a rung's
	## size.
	BOSS,
}

## Which of the two this is.
var kind: Kind = Kind.ENEMY
## What the button says. Built by the station from the pieces below.
var label: String = ""
## The scene that is instanced. For a boss this is still the ordinary enemy scene -
## a mini boss [i]is[/i] an Enemy1, dressed and grown.
var scene: PackedScene
## The rung this boss is built at: how big he is, how fast he moves. Null on an
## ordinary enemy.
var tier: MiniBossTier
## The outlaw whose head, body, weapon and boots the boss wears. Null on an ordinary
## enemy, and null on a boss in a world with no contracts authored.
var target: BountyTarget


func is_boss() -> bool:
	return kind == Kind.BOSS


func _to_string() -> String:
	return "<TestSpawnEntry %s>" % label
