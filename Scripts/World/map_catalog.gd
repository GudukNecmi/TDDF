class_name MapCatalog
extends Resource
## Every map the game knows about, in the order they are offered.
##
## One resource holding the roster, rather than a copy of the list on each thing
## that needs it. The selection menu and the round intro both point at this same
## file, so the desert cannot be unlocked in one place and locked in the other,
## and a new map is one entry seen by both.

## The maps, in menu order.
@export var maps: Array[MapDefinition] = []


## The map with [param map_id], or null when the catalogue has none - which every
## caller reads as "nothing is known about this map".
func find(map_id: StringName) -> MapDefinition:
	for map: MapDefinition in maps:
		if map != null and map.map_id == map_id:
			return map
	return null


## The maps that can actually be picked right now.
func unlocked_maps() -> Array[MapDefinition]:
	var open: Array[MapDefinition] = []
	for map: MapDefinition in maps:
		if map != null and map.unlocked:
			open.append(map)
	return open
