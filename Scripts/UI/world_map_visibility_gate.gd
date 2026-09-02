extends Node
## Hides another [CanvasItem] for as long as the player is on the World Map,
## leaving it exactly as authored everywhere else - Base, the arena, and any
## other place this HUD is shared with.
##
## A child node rather than a script on the target itself, so a node that
## already carries its own script - like [RegionLabel] - can still be gated
## without a second script being attached to it, or that script being
## touched at all. [code]world_map_hud_gate.gd[/code] does the identical
## job for a bare [Control] with no script of its own; this exists for the
## case where the node being hidden is not free to take one.
##
## Gated the same way [code]world_map_debug_readout.gd[/code],
## [code]world_map_clock.gd[/code] and [code]world_map_hud_gate.gd[/code]
## already gate the World Map's own HUD pieces - by asking the World Map's
## own [WorldZone] whether the player is inside it - rather than a new
## mechanism of its own.

## The World Map's own [WorldZone], asked whether the player is inside it.
@export var zone_id: StringName = &"world_map"
## The [CanvasItem] to hide. Defaults to this node's own parent, which is
## the common case - a gate sitting as a child of the thing it hides.
@export var target_path: NodePath = ^".."


func _process(_delta: float) -> void:
	var target := get_node_or_null(target_path) as CanvasItem
	if target == null:
		return
	var zone := WorldZone.get_by_id(self, zone_id)
	target.visible = not (zone != null and zone.is_player_inside())
