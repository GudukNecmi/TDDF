extends Label
## Development-only readout for the nearest [WorldBandit] to the player -
## its group strength, speed, behaviour state, region and current target.
##
## Not the World Map's real UI - a bandit encounter prompt and any combat
## hand-off are later-phase work - this exists only so Phase 3B-1's living
## groups can be checked by eye while they are being built, the same purpose
## [code]world_map_debug_readout.gd[/code] already serves for region and
## clock state, and it is gated onto the World Map the identical way: by
## asking the World Map's own [WorldZone] whether the player is inside it,
## never a mechanism of its own. Deleting this label, or its parent gate, is
## the entire way to remove it later.

@export var body_group: StringName = &"player"
## The World Map's own [WorldZone], asked whether the player is inside it so
## this never draws over anywhere else in the game.
@export var zone_id: StringName = &"world_map"
## Only bandits within this many pixels of the player are reported at all,
## so the readout goes quiet rather than naming a group on the other side of
## the map.
@export var report_range: float = 1400.0


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	var player := get_tree().get_first_node_in_group(body_group) as Node2D
	var nearest := _nearest_bandit(player)
	if nearest == null:
		text = "BANDIT: -"
		return

	text = "BANDIT: %s  |  STR %d  |  SPD %d  |  %s  |  REGION %s  |  TARGET (%d, %d)" % [
		nearest.name,
		int(nearest.group_strength),
		int(nearest.movement_speed),
		nearest.get_state_name(),
		String(nearest.region_id) if nearest.region_id != &"" else "-",
		int(nearest.target_position.x),
		int(nearest.target_position.y),
	]


func _nearest_bandit(player: Node2D) -> WorldBandit:
	if player == null:
		return null

	var nearest: WorldBandit = null
	var nearest_distance := report_range
	for node: Node in get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit == null:
			continue
		var distance := bandit.global_position.distance_to(player.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = bandit
	return nearest
