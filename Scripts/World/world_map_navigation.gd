class_name WorldMapNavigation
extends NavigationRegion2D
## The map's navigation mesh, baked as it loads from the same [TerrainShape] its
## collision is built from.
##
## [b]It is Godot's own navigation, not a second one.[/b] This node is a plain
## [NavigationRegion2D] joining the viewport's default navigation map, so a
## bandit asking [method NavigationServer2D.map_get_path] for a way round a mesa
## is asking the engine, on a mesh baked once at load, rather than testing
## obstacles itself every frame. Nothing else in the project has to know this
## node exists.
##
## [b]The mesh is baked from outlines, not from the scene.[/b] The ordinary bake
## walks the tree collecting collision shapes, which on a map this size is a lot
## of work to arrive back at the outlines [TerrainShape] already holds. The
## walkable edge goes in as the traversable outline and each rock mass as an
## obstruction, which is the same plan the player's own collision was built
## from - so there is no way for the mesh and the rock to disagree.

## The ground plan baked into a mesh. Nothing is baked when it is empty.
@export var shape: TerrainShape

## How far the mesh is pulled back from every wall and rock, in pixels. This is
## the margin that keeps a group's leader from clipping the corner of a mesa as
## it turns: paths are generated on ground already this far clear of the rock,
## so following one cannot scrape it.
@export var agent_radius: float = 110.0

## Group a structure joins to be cut out of the mesh on top of the rock in
## [member shape] - a saloon, a market, a mountain prop.
##
## The map's terrain is traced once and does not move; a building is placed in
## the editor and does. Rather than have both authored the same way, anything in
## this group is measured off the collision it was already given for the player,
## so making a new structure something the bandits walk round is adding it to
## one group. Empty switches the sweep off.
@export var obstruction_group: StringName = &"impassable_terrain"

## Whether the mesh is baked as the map loads.
@export var bake_on_ready: bool = true


func _ready() -> void:
	if not bake_on_ready:
		return
	# Deferred by one call rather than baked here, because the structures swept
	# up by [member obstruction_group] join it in their own readying and this
	# node's own may well run first. By the time a deferred call runs, the whole
	# map is built.
	bake_shape.call_deferred()


## Bakes - or rebakes - this region's mesh from [member shape]. Answers whether
## a mesh was actually produced, which a caller reads as "this map can be
## navigated"; false leaves whatever mesh was there alone.
func bake_shape() -> bool:
	if shape == null or shape.walkable_outline.size() < 3:
		return false

	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(shape.walkable_outline)
	for mass: PackedVector2Array in shape.masses:
		if mass.size() >= 3:
			source.add_obstruction_outline(mass)
	for outline: PackedVector2Array in _collect_structure_outlines():
		source.add_obstruction_outline(outline)

	var mesh := NavigationPolygon.new()
	mesh.agent_radius = maxf(agent_radius, 0.0)
	NavigationServer2D.bake_from_source_geometry_data(mesh, source)
	if mesh.get_polygon_count() <= 0:
		push_warning("WorldMapNavigation: baking produced no navigation polygons.")
		return false

	navigation_polygon = mesh
	return true


## How many polygons the current mesh has - zero for a map that has not been
## baked. What a smoke check reads to confirm the ground is navigable.
func get_polygon_count() -> int:
	return 0 if navigation_polygon == null else navigation_polygon.get_polygon_count()


## The footprint of every [member obstruction_group] structure in the tree, in
## this node's own space, read off the collision each was already authored with
## rather than off a second outline drawn for navigation alone. A disabled shape
## is skipped, exactly as the physics engine would skip it.
func _collect_structure_outlines() -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	if obstruction_group == &"" or not is_inside_tree():
		return outlines

	for node: Node in get_tree().get_nodes_in_group(obstruction_group):
		var structure := node as Node2D
		if structure == null:
			continue
		for child: Node in structure.find_children("*", "CollisionPolygon2D", true, false):
			var polygon := child as CollisionPolygon2D
			if polygon == null or polygon.disabled or polygon.polygon.size() < 3:
				continue
			outlines.append(_to_local_outline(polygon, polygon.polygon))
		for child: Node in structure.find_children("*", "CollisionShape2D", true, false):
			var collision := child as CollisionShape2D
			if collision == null or collision.disabled or collision.shape == null:
				continue
			var rect := collision.shape.get_rect()
			outlines.append(_to_local_outline(collision, PackedVector2Array([
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y)])))
	return outlines


func _to_local_outline(from: Node2D, points: PackedVector2Array) -> PackedVector2Array:
	var xform := global_transform.affine_inverse() * from.global_transform
	var out := PackedVector2Array()
	out.resize(points.size())
	for index: int in points.size():
		out[index] = xform * points[index]
	return out
