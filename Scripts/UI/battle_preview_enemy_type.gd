class_name BattlePreviewEnemyType
extends Resource
## One kind of enemy the [WorldBanditDecisionMenu] briefing knows how to draw.
##
## [b]It is a picture of a type, not a roster of one.[/b] What a fight is
## actually made of is decided entirely by [WaveRoster], when the arena opens
## and long after this has been drawn. This only says how a type should look on
## the briefing, so nothing here can change what the player ends up fighting.
##
## A type is matched by the [PackedScene] the fight will actually spawn, which is
## the same resource the roster entry points at. Adding a third enemy to the
## preview is dropping one of these into
## [member WorldBanditDecisionMenu.enemy_types] with that enemy's own scene and
## artwork in it - there is no name, no branch and no threshold in the preview
## that a new type would have to be written into.

## The body this entry describes. Matched against the scenes the fight has
## planned; an entry with none is the fallback for every planned body that no
## other entry claims, which is how the ordinary Bandit is described without the
## roster ever naming it - see [WaveRoster], where an unclaimed place is the
## spawner's own enemy.
@export var scene: PackedScene
## What this type is called on the screen. Only drawn when
## [member show_name] is on.
@export var display_name: String = ""
## Whether the name is shown beside the portraits.
##
## [b]Off for the ordinary Bandit on purpose.[/b] A crowd of men is drawn as a
## handful of faces and nothing else, because naming them - or showing one face
## on its own - would read as a promise about who is out there rather than what.
## A type the player has to recognise before it reaches them, the bomber above
## all, says its name.
@export var show_name: bool = false

@export_group("Portraits")
## Head artwork this type may be drawn with, taken from the enemy's own existing
## assets. Which of them are shown is rolled fresh every time the screen opens.
@export var icons: Array[Texture2D] = []
## How many of those heads are shown at once. More than one is what keeps a
## crowd reading as a crowd: no single portrait is then the enemy, it is one of
## several faces out of a larger group.
##
## Capped by how many [member icons] there are, and the ones shown are always
## different from each other, so a type with one drawing shows it once rather
## than repeating it.
@export var portrait_count: int = 1


## [param count] heads out of [member icons], all different, in a fresh random
## order each time. Fewer are returned when there are not that many drawings.
func pick_icons(count: int) -> Array[Texture2D]:
	var pool: Array[Texture2D] = []
	for icon: Texture2D in icons:
		if icon != null:
			pool.append(icon)

	pool.shuffle()
	var wanted := clampi(count, 0, pool.size())
	return pool.slice(0, wanted)
