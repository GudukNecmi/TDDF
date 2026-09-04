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
## space, and telling [WorldMapState] which region the map that has just been
## built is.
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


## Tells [WorldMapState] which region this map is, the moment it is built.
##
## [b]It is no longer a crossing.[/b] This used to watch the player every frame
## and announce a region as they walked into the rectangle, because five of these
## shared one ten-thousand-pixel map and which one the player stood in was a
## question only their position could answer. Each region is its own scene now,
## so there is exactly one zone in the tree and the answer is known before the
## player has moved at all - which matters, because everything that opens a map
## needs the region settled before it can ask what this place remembers.
func _ready() -> void:
	_inside = true
	var state := WorldMapState.get_active(self)
	if state != null and region != null:
		state.set_region(region)
