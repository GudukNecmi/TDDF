extends Label
## Development-only readout for Phase 1 and Phase 2 validation: which region
## the player is standing in, whether the horse is walking or running, and
## the World Map's own continuous world day, degree and period.
##
## Not the World Map's real UI - a HUD, a minimap and fog of war are
## later-phase work - this exists only so the foundation can be checked by
## eye while it is being built, the same purpose every other node under
## [code]Scripts/Dev/[/code] serves.
##
## [b]It only shows itself on the World Map.[/b] This label lives on a
## [CanvasLayer], which draws over the whole viewport regardless of where the
## camera is - and the World Map is never removed from the tree, it is a
## permanent sibling of the Base and the arena in [code]World.tscn[/code], the
## same way [WorldZone] already documents "being in the base" as a position
## rather than a state. Left unguarded this readout would stay on screen over
## every other place in the game. [member zone_id] is the World Map's own
## [WorldZone] - already authored on [code]WorldMap/Camera/Zone[/code] - asked
## the same way anything else that cares "is the player actually here" would.

@export var state_group: StringName = &"world_map_state"
@export var horse_group: StringName = &"world_map_horse"
## The World Map's own [WorldZone], asked whether the player is inside it so
## this never draws over anywhere else in the game.
@export var zone_id: StringName = &"world_map"


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	var state := get_tree().get_first_node_in_group(state_group) as WorldMapState
	var region_text := "REGION: -"
	var time_text := ""
	if state != null:
		var region_id := state.get_region_id()
		region_text = "REGION: %s" % (String(region_id) if region_id != &"" else "-")
		var period := state.get_time_period_name()
		if period != &"":
			time_text = "  |  DAY %d  |  %.0f°  |  %s" % [
				state.get_world_day(), state.get_world_degree(), String(period)]

	var horse := get_tree().get_first_node_in_group(horse_group) as WorldMapHorse
	var horse_text := ""
	if horse != null and horse.is_mounted():
		horse_text = "  |  RUNNING" if horse.is_running() else "  |  WALKING"

	text = region_text + time_text + horse_text
