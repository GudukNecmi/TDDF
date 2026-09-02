extends Label
## Development-only readout for the stamina/fatigue/food phase's own live
## validation: whether the horse is mounted, whether Shift is actually
## producing a sprint right now, its stamina against both the ceiling fatigue
## has left it and the base ceiling it started with, its fatigue, and how much
## food it is carrying.
##
## Not the real UI - a small, permanent World Map HUD for this is later work,
## per rule 12 of the stamina phase, which keeps this off the Base HUD
## entirely and gates it onto the World Map the identical way every other node
## under [code]Scripts/Dev/[/code] already does: by asking the World Map's own
## [WorldZone] whether the player is inside it.
##
## Reads [WorldMapHorse] directly rather than keeping a second stamina
## simulation of its own - see rule 12 of the stamina phase - so this can
## never disagree with the horse about what it is carrying.

## Group [WorldMapHorse] joins, so this can find the one horse in play without
## a [NodePath] across two different scenes.
@export var horse_group: StringName = &"world_map_horse"
## The World Map's own [WorldZone], asked whether the player is inside it so
## this never draws over anywhere else in the game.
@export var zone_id: StringName = &"world_map"

var _horse: WorldMapHorse


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	if _horse == null or not is_instance_valid(_horse):
		_horse = WorldMapHorse.get_active(self)
	if _horse == null:
		text = "HORSE: -"
		return

	text = ("MOUNTED %s  |  %s  |  STAMINA %.0f / %.0f (BASE %.0f)  |  " +
		"FATIGUE %.2f  |  FOOD %d / %d  |  SPRINTING %s") % [
		"YES" if _horse.is_mounted() else "NO",
		"SPRINT" if _horse.is_running() else "WALK",
		_horse.get_current_stamina(), _horse.get_max_stamina(), _horse.get_base_max_stamina(),
		_horse.get_fatigue(),
		_horse.get_horse_food(), _horse.get_max_horse_food(),
		"YES" if _horse.is_running() else "NO",
	]
