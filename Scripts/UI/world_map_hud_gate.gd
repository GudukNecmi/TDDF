extends Control
## Hides whatever this sits on for as long as the player is on the World
## Map, leaving it exactly as authored everywhere else - Base, the arena,
## and any other place this HUD is shared with.
##
## Built to keep the old round-based [DayStageDisplay]'s corner icon and
## hour name from sitting on top of the World Map's own [code]WorldMapClock[/code]
## now that the World Map is reachable from a normal run. [DayStageDisplay]
## itself is untouched and keeps writing to its targets everywhere,
## including here - Base and the arena still want that; this only ever
## hides the node it is attached to, never the data behind it.
##
## Gated the same way [code]world_map_debug_readout.gd[/code] and
## [code]world_map_clock.gd[/code] already gate the World Map's own HUD
## pieces - by asking the World Map's own [WorldZone] whether the player is
## inside it - rather than a new mechanism of its own.

## The World Map's own [WorldZone], asked whether the player is inside it.
@export var zone_id: StringName = &"world_map"


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = not (zone != null and zone.is_player_inside())
