class_name TerrainShape
extends Resource
## The ground plan of one map: the edge of the walkable desert, and the rock
## masses standing inside it.
##
## [b]It is one authored fact, read by everything that needs to know where the
## ground is.[/b] The map's collision ([TerrainMasses]), its navigation mesh
## ([WorldMapNavigation]) and its scenery ([member PropScatter.terrain_shape])
## are all built from this same resource, so a rock the player is stopped by is
## by construction a rock the bandits path around and a rock no cactus is ever
## planted inside. Nothing measures the ground a second way.
##
## [b]The outlines come from the map's own sketch.[/b] They are traced off the
## layout drawing rather than drawn node by node in the editor - see
## [member walkable_outline] - which is what keeps a map this size authorable at
## all, and what lets the plan be re-traced when the sketch changes without
## anything downstream being touched.

## The whole rectangle this map occupies, in the map's own space. The camera
## fence, the ground sprite and the scatter regions are all sized from it, so a
## map that grows is this number and the outlines that go with it.
@export var bounds := Rect2(-10000.0, -8000.0, 20000.0, 16000.0)

## The edge of the walkable desert, as one closed loop wound around the inside
## of the map's boundary terrain.
##
## Everything inside this loop and outside every [member masses] entry is ground
## the player, the bandits and the scenery may stand on. It is a single loop on
## purpose: a map whose walkable ground came apart into two disconnected pieces
## would be a map with somewhere a bandit could never path to.
@export var walkable_outline: PackedVector2Array = PackedVector2Array()

## The rock masses standing inside [member walkable_outline], each a closed loop.
## Solid: nothing walks into one, and nothing is scattered inside one.
@export var masses: Array[PackedVector2Array] = []

@export_group("Clearance grid")
## How much open ground there is around every point of the map, as one byte per
## cell: zero for rock, and otherwise the distance to the nearest rock or map
## edge divided by [member clearance_scale].
##
## [b]It is what makes a map this size scatterable at all.[/b] Asking the
## outlines directly - eight polygons and three hundred points - costs a
## polygon test per candidate, and a desert wants thousands of candidates; the
## answer is the same either way, so it is worked out once, offline, by the same
## pass that traced the outlines, and read here as a single array lookup.
## Empty falls back to the polygon test, which is what a shape authored by hand
## in the editor will use.
@export var clearance: PackedByteArray = PackedByteArray()
## How many cells across and down [member clearance] is, covering exactly
## [member bounds].
@export var clearance_size := Vector2i.ZERO
## Pixels one step of a [member clearance] byte stands for. A byte of 12 at a
## scale of 4 is forty-eight pixels of room.
@export var clearance_scale: float = 4.0

## Bounding box per mass, built once and kept, so [method is_walkable] rejects
## the overwhelming majority of points with a rectangle test and only runs the
## real point-in-polygon check on the few that could actually be inside a rock.
var _mass_boxes: Array[Rect2] = []
var _boxes_built: bool = false


## Whether [param point] - in this map's own space - is ground something may
## stand on: inside the walkable edge and outside every rock mass.
func is_walkable(point: Vector2) -> bool:
	if not bounds.has_point(point):
		return false
	if has_clearance_grid():
		return _clearance_at(point) > 0
	if walkable_outline.size() >= 3 and not Geometry2D.is_point_in_polygon(point, walkable_outline):
		return false
	_build_boxes()
	for index: int in masses.size():
		if not _mass_boxes[index].has_point(point):
			continue
		if Geometry2D.is_point_in_polygon(point, masses[index]):
			return false
	return true


## The same question with room to spare: true only when [param point] is
## walkable and no rock or map edge comes within [param margin] of it. What
## scenery and spawn points want, so a prop is never left half inside a cliff.
func is_clear(point: Vector2, margin: float) -> bool:
	if margin <= 0.0:
		return is_walkable(point)
	if not bounds.has_point(point):
		return false
	if has_clearance_grid():
		return float(_clearance_at(point)) * clearance_scale >= margin
	if not is_walkable(point):
		return false
	for offset: Vector2 in [
			Vector2(margin, 0.0), Vector2(-margin, 0.0),
			Vector2(0.0, margin), Vector2(0.0, -margin)]:
		if not is_walkable(point + offset):
			return false
	return true


## Whether a baked clearance grid is available - see [member clearance].
func has_clearance_grid() -> bool:
	return clearance_size.x > 0 and clearance_size.y > 0 \
		and clearance.size() >= clearance_size.x * clearance_size.y


## How much open ground there is at [param point], in pixels, or zero for rock.
func get_clearance(point: Vector2) -> float:
	if not has_clearance_grid() or not bounds.has_point(point):
		return 0.0
	return float(_clearance_at(point)) * clearance_scale


func _clearance_at(point: Vector2) -> int:
	var local := point - bounds.position
	var cx := clampi(
		int(local.x / bounds.size.x * float(clearance_size.x)), 0, clearance_size.x - 1)
	var cy := clampi(
		int(local.y / bounds.size.y * float(clearance_size.y)), 0, clearance_size.y - 1)
	return clearance[cy * clearance_size.x + cx]


## Every outline this shape holds - the walkable edge first, then each mass.
## For anything that wants to draw or measure the whole plan at once.
func get_outlines() -> Array[PackedVector2Array]:
	var all: Array[PackedVector2Array] = []
	if walkable_outline.size() >= 3:
		all.append(walkable_outline)
	for mass: PackedVector2Array in masses:
		if mass.size() >= 3:
			all.append(mass)
	return all


func _build_boxes() -> void:
	if _boxes_built and _mass_boxes.size() == masses.size():
		return
	_mass_boxes.clear()
	for mass: PackedVector2Array in masses:
		var box := Rect2()
		var first := true
		for point: Vector2 in mass:
			if first:
				box = Rect2(point, Vector2.ZERO)
				first = false
			else:
				box = box.expand(point)
		_mass_boxes.append(box)
	_boxes_built = true
