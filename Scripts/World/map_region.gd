class_name MapRegion
extends Resource
## One named part of a map: the desert's A through E, and whatever a later map
## turns out to be divided into.
##
## A region is a resource rather than a letter in an array so that it can be more
## than a letter. The selection screen needs something to draw - a name, a line of
## description, one day a piece of map artwork - and a wanted poster needs
## something to print. Both read the same file, so the region the player picks and
## the region a poster names cannot end up called different things.
##
## [b]Nothing about it is desert-specific.[/b] The roster lives on the map that
## owns it - see [member MapDefinition.regions] - so a town divided into "The
## Gulch" and "Boot Hill" is two [code].tres[/code] files under that map's own
## folder and a different array. No list of regions exists in any script, and
## neither the bounty generator nor the selection screen knows how many there are
## or what they are called.

## The handle the rest of the game uses: what [RunSessionState] stores as the
## chosen region, and what a [BountyFact] holds as its answer. Unique within one
## map's roster, and never shown to the player.
@export var region_id: StringName = &"region"
## What the player is shown it is called - "A", "THE GULCH". Shown on the
## selection tile and printed on a wanted poster.
@export var display_name: String = "REGION"
## A line under the name on the selection tile, for anything worth saying about
## the place. Optional; a region with none is drawn as its name alone.
@export var description: String = ""
## Picture drawn on the selection tile - a scrap of map, a silhouette. Optional
## and deliberately so: the regions are placeholder tiles until there is art for
## them, and a region with no icon simply shows its name.
@export var icon: Texture2D
## Whether the region can be picked. Every region of the desert is open; the field
## exists so a map can be revealed a piece at a time later without the screen
## having to grow a second notion of availability.
@export var unlocked: bool = true

@export_group("Scenery")
## The ground this part of the map is drawn on, tiled across its floor by
## [RegionGround].
##
## [b]It belongs to the place, not to the map.[/b] The desert is one world scene at
## five places and they do not look alike, so the picture is authored here rather
## than on a floor that would have to be swapped by something that knew the five
## apart. A region left without one keeps whatever ground the world scene was
## authored with, which is what every region looked like before there was regional
## artwork.
@export var ground_texture: Texture2D
## How much world this region's ground covers per tile, in pixels. Left at nothing
## the map's own [member TiledSurface.tile_size] is kept, which is right whenever
## the regional pictures are drawn at the size the map's floor already was.
@export var ground_tile_size: float = 0.0
## The scenery that belongs to this place and nowhere else: a camp's tents, the
## stakes driven into the ground where the dead are.
##
## [b]This is what makes a prop regional.[/b] A layer can only reach the map
## through the region whose file holds it - see
## [member PropScatter.include_region_layers] - so a tent cannot appear in the mine
## by an oversight, and there is no filter, tag or name anywhere in the scatter
## deciding what may go where. Moving a prop set from one place to another is
## dragging one entry between two [code].tres[/code] files.
##
## These are ordinary [ScatterLayer]s and are strewn by exactly the code that
## strews the shared cacti, with the same spacing, the same clearings and the same
## map scale. The map's shared props are unaffected: they remain on
## [member PropScatter.layers] and are placed in every region.
@export var scatter_layers: Array[ScatterLayer] = []

@export_group("Danger")
## How dangerous this part of the map is, from 0 at its way in to 1 at its
## deadliest corner.
##
## [b]It is a fraction, not a number of enemies.[/b] What a given danger is worth
## is the asking system's business - see
## [member AmbushWaveDirector.entry_enemy_count] and
## [member AmbushWaveDirector.deepest_enemy_count], which are the two ends an
## ambush's size is read between - so retuning how hard the game is is two
## inspector fields rather than an edit to five region files, and a second system
## that wants to be harder out in the dunes reads the same fraction rather than
## inventing a scale of its own.
##
## Normalised for the same reason [member map_position] is: a map divided into
## three parts and one divided into nine both run 0 to 1, so nothing anywhere
## counts regions or knows how many a map has.
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.0

@export_group("Arriving")
## Where in the world the player stands when they arrive here, in world pixels.
##
## [b]Where a journey comes out is a fact about the place, not about the ride.[/b]
## Nothing in the travel flow names a position: the road ends, the destination
## becomes the region, and the region says where in the map that put the player -
## so a second map's parts state their own arrival points on their own
## [code].tres[/code] files and [RegionArrival] is unchanged by any of them.
##
## Left at the origin it is the middle of the map, which is where the world scene
## already stands the player, so a region that has not been given one is arrived
## in exactly as the game did before there were arrival points.
@export var start_position := Vector2.ZERO

@export_group("On the map")
## Where this region sits on the map's own picture, as a fraction of it: (0, 0) is
## the top left corner and (1, 1) the bottom right.
##
## [b]Normalised on purpose.[/b] The camp's map is drawn at whatever size the panel
## gives it, so a region pinned in pixels would drift the moment the picture was
## scaled. This is also where a bounty's marker is placed, so the outlaw and the
## region he is hiding in cannot end up in different parts of the map.
@export var map_position := Vector2(0.5, 0.5)
## How large this region's patch is drawn on the map, again as a fraction of the
## picture. Only the patch the player can click and the marker sit inside it - the
## artwork underneath is the map's own.
@export var map_size := Vector2(0.24, 0.24)
## What a locked region says instead of being selectable.
@export var locked_label: String = "LOCKED"


## The scenery belonging to this place alone. Empty for a region that has none,
## which every caller reads as "this place adds nothing to the map's shared props".
##
## Read by [PropScatter] as it lays the map out, so a region's own props are placed
## by the same code, with the same spacing and clearings, as the cacti.
func get_scatter_layers() -> Array[ScatterLayer]:
	return scatter_layers


## How dangerous this place is, held to 0..1 - so a region authored out of range,
## or one from a map that has not been given danger values yet, still answers
## something every caller can lerp between.
func get_difficulty() -> float:
	return clampf(difficulty, 0.0, 1.0)


## What a poster or a tile writes for this region. Falls back to the id, so a
## region that has been given no display name still reads as something rather than
## as an empty tile.
##
## [b]This is the handle, not the place.[/b] On the desert it is the letter - "A" -
## because that is what [member display_name] is authored as. What the place is
## actually called is [method get_place_name], and the two together are
## [method get_full_label].
func get_label() -> String:
	return display_name if not display_name.is_empty() else String(region_id)


## What this part of the map is actually called - "DUST CAMP", "GHOST TOWN".
## Empty for a region that has been given no [member description], which every
## caller reads as "there is nothing to say beyond the letter".
##
## It is [member description] rather than a field of its own because that is where
## the names are already authored, on the region resources themselves. Nothing in
## code names a region, and adding the forest's places is filling this in on its
## own [code].tres[/code] files.
func get_place_name() -> String:
	return description


## The letter and the place's name as one line - "A  -  DUST CAMP" - for the
## screens that have room for both.
##
## A region with no name of its own falls back to the bare label, so this is always
## safe to use in place of [method get_label] and a map whose regions are only ever
## letters reads exactly as it did before.
func get_full_label(separator: String = "  -  ") -> String:
	var place := get_place_name()
	return get_label() if place.is_empty() else get_label() + separator + place
