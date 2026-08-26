class_name PropScatter
extends Node2D
## Strews a map's scenery across it.
##
## A desert big enough that its edges are never seen is far too big to place
## cactus by cactus, and placing them by hand would also pin the map to one size
## - growing it would mean a thousand more nodes to drag out. So the arrangement
## is described rather than authored: a region, and a list of [ScatterLayer]s
## saying what goes in it and how much of it there is.
##
## The density and the mix come from the concept art. Nothing about *which*
## props exist is in this file: adding a kind of scenery to the map is adding a
## layer in the inspector, and adding a variant of an existing kind is dropping a
## PNG into that prop's own [member PropArt.textures].
##
## Two things are kept clear of scenery. A circle around where the round begins,
## so nobody starts the round wedged in a cactus, and whatever rectangles the map
## lists in [member keep_clear]. Everything else is fair game.
##
## Layers are placed in order and each one is kept off the ones before it, so a
## map reads front to back: put the big solid things first and the litter after,
## and the litter arranges itself around them.
##
## Spacing is checked against a coarse grid of the points already placed rather
## than against all of them, so the whole arrangement stays close to linear in
## how many props there are. A map with a thousand of them is laid out in one
## frame at load rather than being something the player waits for.

## Where scenery may go, in this node's own local space. Normally the whole
## playable rectangle.
@export var region := Rect2(-4000.0, -2500.0, 8000.0, 5000.0)
## What is strewn about, in the order it is placed. These are the map's shared
## props - the ones that are there at every hour of the day.
@export var layers: Array[ScatterLayer] = []
## Whether the map's [DayCycleDirector], if it has one, is asked for scenery
## belonging to the hour currently being played - a dawn's birds, a night's
## fireflies - which is then strewn about after the shared layers by exactly this
## same code. Off ignores the clock and places only [member layers].
##
## The director is found by group and is allowed not to exist, so a map with no
## day cycle scatters exactly as it always did.
@export var include_day_stage_layers: bool = true
## Whether the part of the map being played is asked for scenery of its own - a
## camp's tents, a boneyard's stakes - which is then strewn about after the shared
## layers by exactly this same code.
##
## [b]This is the whole of what makes a prop regional.[/b] The layers come from the
## [MapRegion] the run is in and from nowhere else, so a prop belonging to one
## place cannot be placed in another: there is no filter here deciding what may go
## where, only a different region answering with a different list. Off scatters
## the map's shared props alone, which is every region exactly as it was before
## there was regional scenery.
##
## The run is allowed not to have picked a region - a world opened straight from
## the editor has not - and a region is allowed to have no scenery of its own, so
## both simply add nothing.
@export var include_region_layers: bool = true
## Whether the region's own props are placed before the map's shared ones.
##
## Off by default, so the tents and the stakes are laid out around the cacti
## already standing rather than the other way round - the same reasoning that puts
## the hour's scenery last. On places them first, which is what a region whose own
## props are the big solid things in it wants: the shared litter then arranges
## itself around them instead.
@export var region_layers_first: bool = false
## Node the scenery is parented to. Left unresolved, it is parented to this node.
## Point it at a y-sorted container to have the scenery sort among itself.
@export var container_path: NodePath

@export_group("Nodes")
## The run, asked which region is being played so its own scenery can be fetched.
## The same autoload the HUD's place-name and the floor's ground read, so the props
## standing in a place, the ground under them and the name on the HUD are all
## answering from one source.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Clearings")
## Middle of the circle kept free of scenery - where the round begins.
@export var clear_centre := Vector2.ZERO
## Radius of that circle, in pixels.
@export var clear_radius: float = 300.0
## Further rectangles nothing may be placed in, in local space.
@export var keep_clear: Array[Rect2] = []

@export_group("Randomness")
## Seed the arrangement is rolled from. 0 rolls a different desert every run,
## which is what a run-based game wants; any other value pins it, for looking at
## the same map twice while tuning it.
@export var random_seed: int = 0
## Whether the scenery is placed at all. Off leaves an empty map, for measuring
## what the scenery costs.
@export var enabled: bool = true
## Side of one cell of the spacing grid, in pixels. Only affects how fast the
## layout runs, never how it looks: it wants to be roughly the largest separation
## any layer asks for.
@export var grid_cell_size: float = 160.0


## A coarse bucketed grid of points, so "how close is the nearest thing to here"
## is answered by looking at a handful of neighbouring cells instead of at every
## point already placed.
class PointGrid:
	var cell: float = 160.0
	var _cells: Dictionary = {}

	func _init(cell_size: float) -> void:
		cell = maxf(cell_size, 1.0)

	func clear() -> void:
		_cells.clear()

	func add(point: Vector2) -> void:
		var key := _key(point)
		var bucket: PackedVector2Array = _cells.get(key, PackedVector2Array())
		bucket.append(point)
		_cells[key] = bucket

	## Distance to the nearest point within [param radius], or [constant INF]
	## when there is none - which reads as "all the room in the world" at every
	## call site, and is exactly right for an empty map.
	func nearest_within(point: Vector2, radius: float) -> float:
		if radius <= 0.0 or _cells.is_empty():
			return INF

		var reach := int(ceil(radius / cell))
		var origin := _key(point)
		var nearest := INF
		for dx: int in range(-reach, reach + 1):
			for dy: int in range(-reach, reach + 1):
				var bucket: PackedVector2Array = _cells.get(
					Vector2i(origin.x + dx, origin.y + dy), PackedVector2Array())
				for other: Vector2 in bucket:
					nearest = minf(nearest, point.distance_to(other))
		return nearest

	func _key(point: Vector2) -> Vector2i:
		return Vector2i(int(floor(point.x / cell)), int(floor(point.y / cell)))


var _rng := RandomNumberGenerator.new()
var _container: Node
var _all_points: PointGrid
var _layer_points: PointGrid
var _count: int = 0
## Everything this scatter has put down, so a re-roll takes away exactly what it
## placed and nothing else. The container is shared with whatever else the map
## parents into it - a region's own extras, a prop dropped in by hand - and those
## are none of this node's business to remove.
var _placed: Array[Node] = []


func _ready() -> void:
	if not enabled:
		return

	_container = get_node_or_null(container_path)
	if _container == null:
		_container = self

	_lay_out()


## Takes away what this scatter put down and strews the map again.
##
## [b]The map is re-rolled, never re-authored.[/b] The layers are read afresh - the
## map's shared ones, the region's own and the hour's - so a new arrangement is the
## same scenery in a different place, and the region's prop pool, the ground under
## it and everything written down about the run are untouched. It is what a world
## that has to look like somewhere else without the scene being rebuilt asks for;
## see [WorldReset].
##
## [param around] is a point in global space kept clear of scenery instead of
## [member clear_centre] - normally where the player is standing, since a re-roll is
## made with them already out in the desert rather than at the spot a round begins.
## [constant Vector2.INF] leaves the authored clearing alone.
##
## Returns how many props were actually placed.
func rescatter(around := Vector2.INF) -> int:
	if not enabled:
		return 0
	if _container == null:
		_container = get_node_or_null(container_path)
		if _container == null:
			_container = self

	for prop: Node in _placed:
		if is_instance_valid(prop):
			prop.queue_free()
	_placed.clear()

	var kept := clear_centre
	if around != Vector2.INF:
		clear_centre = to_local(around)
	_lay_out()
	clear_centre = kept
	return _count


## One pass of the arrangement, from an empty map. The seed is rolled here rather
## than at load, so a re-roll is a different desert while a pinned
## [member random_seed] still lays out the same one every time.
func _lay_out() -> void:
	_all_points = PointGrid.new(grid_cell_size)
	_layer_points = PointGrid.new(grid_cell_size)
	_rng.seed = random_seed if random_seed != 0 else randi()
	_count = 0

	for layer: ScatterLayer in _all_layers():
		_place_layer(layer)


## The map's shared layers, whatever the place being played adds, and whatever the
## hour being played adds. The hour's own scenery is placed last so it is kept
## clear of everything already standing rather than the other way round, and the
## region's sits either side of the shared props - see
## [member region_layers_first].
func _all_layers() -> Array[ScatterLayer]:
	var regional := _region_layers()

	var all: Array[ScatterLayer] = []
	if region_layers_first:
		all.append_array(regional)
	all.append_array(layers)
	if not region_layers_first:
		all.append_array(regional)

	if not include_day_stage_layers:
		return all

	var day := DayCycleDirector.get_active(self)
	if day == null:
		return all

	all.append_array(day.get_extra_scatter_layers())
	return all


## The scenery belonging to the part of the map being played, and nothing else.
##
## Empty for a run that has not picked a region and for a region with no props of
## its own, both of which read as "this map is its shared scenery alone". The
## session is asked by method rather than by type so a world opened with no
## autoloads - a scene run on its own in the editor - still lays itself out.
func _region_layers() -> Array[ScatterLayer]:
	# Typed rather than a bare `[]`, because an untyped empty array assigned into an
	# `Array[ScatterLayer]` is a runtime error rather than a conversion.
	var none: Array[ScatterLayer] = []
	if not include_region_layers:
		return none

	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_region"):
		return none

	var place := session.get_region() as MapRegion
	if place == null:
		return none
	return place.get_scatter_layers()


## How many things this scatter actually put down. For a map being tuned - the
## numbers in the inspector are what was *asked* for, and a crowded region or a
## large clearing can fall short of them.
func get_placed_count() -> int:
	return _count


func _place_layer(layer: ScatterLayer) -> void:
	if layer == null or not layer.enabled or layer.scenes.is_empty():
		return

	_layer_points.clear()
	for i: int in maxi(layer.count, 0):
		_place_one(layer)


## Picks a spot and puts one thing on it. Returns false when every attempt landed
## somewhere scenery is forbidden, which is how a prop that would have to stand
## in a clearing is dropped rather than forced.
func _place_one(layer: ScatterLayer) -> bool:
	var best := Vector2.ZERO
	var best_score := -1.0
	var found := false

	for attempt: int in maxi(layer.max_attempts, 1):
		var point := Vector2(
			_rng.randf_range(region.position.x, region.end.x),
			_rng.randf_range(region.position.y, region.end.y))
		if not _is_allowed(point):
			continue

		var own := _layer_points.nearest_within(point, layer.min_separation)
		var others := _all_points.nearest_within(point, layer.min_separation_from_others)
		if own >= layer.min_separation and others >= layer.min_separation_from_others:
			best = point
			found = true
			break

		# Scored as how badly each rule is broken relative to what it asked for,
		# so a layer that wants a lot of room and one that wants none are compared
		# fairly rather than by raw distance.
		var score := minf(
			own / maxf(layer.min_separation, 0.001),
			others / maxf(layer.min_separation_from_others, 0.001))
		if score > best_score:
			best_score = score
			best = point
			found = true

	if not found:
		return false

	_spawn(layer, best)
	_layer_points.add(best)
	_all_points.add(best)
	_count += 1
	return true


func _spawn(layer: ScatterLayer, point: Vector2) -> void:
	var scene := layer.scenes[_rng.randi() % layer.scenes.size()]
	if scene == null:
		return

	var prop := scene.instantiate() as Node2D
	if prop == null:
		return

	prop.position = point
	# A layer asking for no variation is left strictly alone rather than being
	# assigned a scale of one: the prop then keeps whatever its own scene was
	# authored at, and the scatter cannot quietly resize artwork that was drawn to
	# a particular size.
	#
	# When a range is given, the roll is applied to the whole instance rather than
	# to its artwork, so the collision shape, the touch area and the shadow all
	# grow with the picture. Uniform, so nothing is sheared.
	if not _is_fixed_scale(layer):
		var size := _rng.randf_range(layer.scale_range.x, layer.scale_range.y)
		prop.scale = Vector2(size, size)
	# The map's own scale rides on top of whatever the layer decided, so how large
	# this map draws its scenery stays one number in one place - see [PropScale] -
	# rather than something every layer would have to be told about.
	PropScale.apply_to(prop, self)
	_container.add_child(prop)
	_placed.append(prop)


func _is_fixed_scale(layer: ScatterLayer) -> bool:
	return is_equal_approx(layer.scale_range.x, 1.0) and is_equal_approx(layer.scale_range.y, 1.0)


func _is_allowed(point: Vector2) -> bool:
	if clear_radius > 0.0 and point.distance_to(clear_centre) < clear_radius:
		return false
	for box: Rect2 in keep_clear:
		if box.has_point(point):
			return false
	return true
