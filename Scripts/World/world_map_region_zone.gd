class_name WorldMapRegionZone
extends Node2D
## One rectangle of the World Map that answers to one of the desert's own
## regions.
##
## [b]It introduces no second notion of a region.[/b] [member region] is the
## same [MapRegion] resource the old Travel/Sleep screens already read off
## [member MapDefinition.regions] - region A through E are the very files
## this points at - so a wanted poster, a difficulty curve or anything else
## that already understands a [MapRegion] understands whatever this zone is
## standing on. All this adds is a physical rectangle in the World Map's own
## space and the crossing that tells [WorldMapState] about it.
##
## Placing a sixth region, or redrawing where the five sit, is dragging this
## node's [member area] around the editor and pointing [member region] at a
## resource - never a hardcoded check anywhere in gameplay code.

## Group every zone joins, so a debug readout can find them all without being
## wired to any one of them.
const GROUP := &"world_map_region_zone"

## The region this rectangle answers to. One of the desert's existing
## [code]region_a.tres[/code] through [code]region_e.tres[/code] files, or a
## new [MapRegion] for a map of its own later.
@export var region: MapRegion
## The rectangle, in this node's own local space.
@export var area := Rect2(-500.0, -500.0, 1000.0, 1000.0)
## Only bodies in this group can be standing in a region.
@export var body_group: StringName = &"player"

var _inside: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


## The rectangle in world space.
func get_world_area() -> Rect2:
	return Rect2(global_position + area.position, area.size)


## Whether [param body] is standing in here.
func is_inside(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return get_world_area().has_point(body.global_position)


## Only tells [WorldMapState] on the way in. Leaving one zone for an
## adjoining one is the next zone's own crossing telling it the new answer;
## leaving every zone at once simply stops updating it, which for this
## foundation is close enough - a region readout that holds the last region
## the player was actually standing in.
func _process(_delta: float) -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var inside := is_inside(body)
	if inside == _inside:
		return

	_inside = inside
	if not _inside:
		return

	var state := WorldMapState.get_active(self)
	if state != null:
		state.set_region(region)
