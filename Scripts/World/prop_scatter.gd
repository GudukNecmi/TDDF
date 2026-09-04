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
## how many props there are - deciding where a thousand of them go costs almost
## nothing. Building them is the expensive half, and a map large enough for that
## to be felt as a freeze at load hands it to [member stream_enabled] instead of
## paying for it all in the frame the map is built in.

## Where scenery may go, in this node's own local space. Normally the whole
## playable rectangle.
@export var region := Rect2(-4000.0, -2500.0, 8000.0, 5000.0)
## What is strewn about, in the order it is placed. These are the map's shared
## props - the ones that are there at every hour of the day.
@export var layers: Array[ScatterLayer] = []
## How much of each layer's authored count this scatter actually lays down.
##
## [b]It is for a scatter covering less ground than its layers were authored
## for.[/b] The desert's shared scenery - its cacti, bushes and bones - is
## authored as a count for the whole map, and the map used to be one scene: one
## scatter strewing 1220 props across all of it. The map is five region scenes
## now, each covering a fifth of that ground, so a scatter left at the full count
## would put the whole map's worth of scenery into one region and the desert
## would be five times as cluttered as it was drawn to be. A fifth of the ground
## asks for a fifth of the count and the density is exactly what it always was.
##
## Scaled rather than re-authored so the counts stay in one place: retuning how
## dense the desert is is still one edit to the shared layer, and every region
## follows it. A scatter whose region is the ground its layers were authored for
## leaves this at 1.
@export_range(0.0, 4.0, 0.01) var count_scale: float = 1.0
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

@export_group("Impassable clearance")
## Group a large, manually placed obstacle - a mountain, a building, a cliff -
## joins to be automatically kept clear of scenery, on top of whatever
## [member keep_clear] is hand-authored. Read once per layout, off the
## obstacle's own existing collision shape - never a second, per-pixel map of
## the ground - so tagging a new obstacle into this group is the whole of
## teaching every [PropScatter] in the scene to leave room around it. See
## [method _collect_auto_clear].
@export var impassable_group: StringName = &"impassable_terrain"
## How much room is left around an [member impassable_group] obstacle's own
## collision footprint, in pixels, past the footprint itself.
@export var impassable_clearance_margin: float = 80.0

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

@export_group("Staged spawning")
## Whether the props this scatter decided on are built a few at a time over the
## frames after load rather than all at once.
##
## [b]This changes nothing about what is placed, or where, or what it looks
## like.[/b] The whole arrangement is still worked out in one pass, from the
## same seed, in the same order, and every random choice a prop needs - which of
## its layer's scenes it is, what it is scaled to - is rolled at that moment and
## written down. A prop built a second later stands exactly where it would have
## stood otherwise. Nothing here is a level-of-detail system: everything queued
## is built, near or far, and nothing is ever thrown away for being distant.
##
## [b]Why it is worth deferring.[/b] Deciding where a thousand props go is a few
## milliseconds; building a thousand small scenes is most of a second, and all
## of it lands in the one frame the map enters the tree in - a freeze the player
## sees as the world arriving. Spreading it over the frames after that trades a
## stall nobody can miss for a few milliseconds a frame nobody can see. Off
## builds the lot immediately, which is what a map small enough to afford it
## wants, and is what every map did before this existed.
@export var stream_enabled: bool = false
## Side of one streaming cell, in pixels. Props are built a cell at a time,
## nearest cell to the player first, so this is only how coarsely "near" is
## measured - never which props exist or where they stand. It wants to be
## roughly a screen across: much smaller and the nearest cell is found more
## often for less work each time, much larger and the first cell built covers
## more ground than anyone can see.
@export var stream_cell_size: float = 1000.0
## How long, in milliseconds, one frame may spend building queued props. Checked
## between props rather than inside one, so a frame always makes progress and
## can overrun by the cost of the single prop that crossed the line.
@export var stream_budget_ms: float = 3.0
## How long the frame the map is built in may spend, in milliseconds - the one
## chance to have some of the scenery standing before anybody has looked at the
## map at all. Everything past it waits for the frames after. 0 defers the lot.
@export var stream_first_frame_budget_ms: float = 8.0

@export_group("Distance culling")
## Whether scenery far enough away that no camera can see it is hidden.
##
## [b]This changes nothing about what is placed, only about what is drawn.[/b]
## Every prop this scatter laid out stays in the tree, keeps its collision, its
## touch area and its script exactly as before - [member CanvasItem.visible] is
## the only thing touched, and it is put back the moment the prop is in reach
## again. Nothing here is a level-of-detail system and nothing is ever removed.
##
## [b]Why hiding the root is what pays.[/b] A prop is not one drawn thing but a
## small tree of them - artwork, collision shapes, a touch area, a shadow caster -
## and the renderer walks every visible one of them once per camera per frame to
## decide what to draw, whether or not it is anywhere near the screen. Hiding the
## prop's root skips that whole subtree in a single test. On a map large enough
## that most of its scenery is always off screen this is the difference between
## paying for the props in front of the player and paying for all of them; on a
## map small enough that everything is on screen at once it saves nothing, which
## is why this is off unless a map asks for it.
@export var cull_enabled: bool = false
## Smallest radius, in world units, that is always kept drawn regardless of what
## the main camera can see - for a map with a [b]second[/b] camera looking at the
## same world, such as a minimap, which may see further than the main one does.
##
## This node has no way to discover such a camera and deliberately does not try:
## the map that owns both says how far the wider of the two reaches, and that is
## the whole of what has to be kept in step. Left at 0 the main camera's own view
## is the only thing considered.
@export var cull_minimum_radius: float = 0.0
## Extra world units kept drawn past whatever the cameras actually reach, so a
## prop is already there rather than appearing as the view arrives at it.
@export var cull_margin: float = 400.0
## How often, in seconds, which props are near enough is worked out again. Props
## do not move, so this only has to keep up with the camera rather than with the
## frame.
@export var cull_interval: float = 0.15
## Node the cull is measured from when the viewport has no current [Camera2D] -
## normally the player. Found by group, and allowed not to exist, in which case
## nothing is culled and the map draws exactly as it did before.
@export var cull_viewer_group: StringName = &"player"


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


## One prop this scatter has decided on and not yet built - where it goes, which
## of its layer's scenes it rolled, and what it was scaled to. Every random
## choice is already made and written down by the time one of these exists, so
## building it later cannot come out differently to building it now.
class PendingProp:
	var scene: PackedScene
	var point: Vector2
	## The scale rolled for it, or [constant Vector2.ZERO] for a layer that asked
	## for no variation - which leaves the prop at whatever its own scene was
	## authored at, exactly as an unqueued spawn does.
	var scale := Vector2.ZERO

	func _init(from_scene: PackedScene, at: Vector2, sized: Vector2) -> void:
		scene = from_scene
		point = at
		scale = sized


var _rng := RandomNumberGenerator.new()
var _container: Node
var _all_points: PointGrid
var _layer_points: PointGrid
var _count: int = 0
## Every [member impassable_group] obstacle's own footprint, converted into
## this node's own local space and grown by [member impassable_clearance_margin] -
## recomputed once at the top of every [method _lay_out], the same "asked
## fresh, kept for the one pass" lifetime [member _all_points] already has.
## Checked by [method _is_allowed] the same way [member keep_clear] is.
var _auto_keep_clear: Array[Rect2] = []
## Everything this scatter has put down, so a re-roll takes away exactly what it
## placed and nothing else. The container is shared with whatever else the map
## parents into it - a region's own extras, a prop dropped in by hand - and those
## are none of this node's business to remove.
var _placed: Array[Node] = []
## Counts down to the next [method _apply_cull]. Only ever ticked while
## [member cull_enabled] is on - see [method _refresh_processing].
var _cull_timer: float = 0.0
## Props decided on and not yet built, bucketed by streaming cell so the ones
## nearest the player can be found without walking the whole queue - see
## [member stream_enabled]. Always empty for a scatter that is not streaming,
## and empty again the moment the last queued prop is in the world.
var _pending: Dictionary = {}
## How many props are still queued across every cell of [member _pending], kept
## as a running total rather than counted, so asking costs nothing.
var _pending_count: int = 0


func _ready() -> void:
	if not enabled:
		return

	_container = get_node_or_null(container_path)
	if _container == null:
		_container = self

	_lay_out()
	# Straight away rather than on the first tick, so a map never shows a frame of
	# every prop it owns before the first cull takes the far ones back off again.
	_apply_cull()
	# Whatever of the queue this map is willing to pay for in the frame it is
	# built in - see [member stream_first_frame_budget_ms]. A map that is not
	# streaming has no queue and this does nothing at all.
	_pump_stream(stream_first_frame_budget_ms)
	_refresh_processing()


## Only ever running while this map actually has something to do every frame -
## culling, or a queue still being built - so a scatter that wants neither costs
## exactly what it always did, not even an empty callback.
func _refresh_processing() -> void:
	set_process(cull_enabled or _pending_count > 0)


func _process(delta: float) -> void:
	if _pending_count > 0:
		_pump_stream(stream_budget_ms)
		# The frame the queue drains is the frame this stops being a reason to
		# keep processing, so a map that only ever streamed goes quiet again.
		if _pending_count <= 0:
			_refresh_processing()

	if not cull_enabled:
		return
	_cull_timer -= delta
	if _cull_timer > 0.0:
		return
	_cull_timer = maxf(cull_interval, 0.0)
	_apply_cull()


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
	# Thrown away along with what was built from it: a re-roll replaces the whole
	# arrangement, and a prop still waiting to be built belongs to the
	# arrangement being replaced.
	_pending.clear()
	_pending_count = 0

	var kept := clear_centre
	if around != Vector2.INF:
		clear_centre = to_local(around)
	_lay_out()
	clear_centre = kept
	_apply_cull()
	_pump_stream(stream_first_frame_budget_ms)
	_refresh_processing()
	return _count


## One pass of the arrangement, from an empty map. The seed is rolled here rather
## than at load, so a re-roll is a different desert while a pinned
## [member random_seed] still lays out the same one every time.
func _lay_out() -> void:
	_all_points = PointGrid.new(grid_cell_size)
	_layer_points = PointGrid.new(grid_cell_size)
	_rng.seed = random_seed if random_seed != 0 else randi()
	_count = 0
	_auto_keep_clear = _collect_auto_clear()

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
##
## This counts what the arrangement decided on, which on a streaming map is
## ahead of what is standing yet - see [method get_spawned_count] and
## [method get_pending_count].
func get_placed_count() -> int:
	return _count


func _place_layer(layer: ScatterLayer) -> void:
	if layer == null or not layer.enabled or layer.scenes.is_empty():
		return

	_layer_points.clear()
	for i: int in maxi(int(round(float(layer.count) * maxf(count_scale, 0.0))), 0):
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


## Rolls everything about one prop and then either builds it or writes it down
## to be built shortly - see [member stream_enabled]. The rolls happen here
## either way, in the same order, so which desert a seed lays out does not
## depend on whether the map streams.
func _spawn(layer: ScatterLayer, point: Vector2) -> void:
	var scene := layer.scenes[_rng.randi() % layer.scenes.size()]
	if scene == null:
		return

	# A layer asking for no variation is left strictly alone rather than being
	# assigned a scale of one: the prop then keeps whatever its own scene was
	# authored at, and the scatter cannot quietly resize artwork that was drawn to
	# a particular size.
	#
	# When a range is given, the roll is applied to the whole instance rather than
	# to its artwork, so the collision shape, the touch area and the shadow all
	# grow with the picture. Uniform, so nothing is sheared.
	var sized := Vector2.ZERO
	if not _is_fixed_scale(layer):
		var size := _rng.randf_range(layer.scale_range.x, layer.scale_range.y)
		sized = Vector2(size, size)

	if stream_enabled:
		_queue(PendingProp.new(scene, point, sized))
		return
	_build(scene, point, sized)


## Turns one decided prop into nodes standing in the world. The single place a
## prop is ever instantiated, whether it waited in the queue first or not.
func _build(scene: PackedScene, point: Vector2, sized: Vector2) -> Node2D:
	var prop := scene.instantiate() as Node2D
	if prop == null:
		return null

	prop.position = point
	if sized != Vector2.ZERO:
		prop.scale = sized
	# The map's own scale rides on top of whatever the layer decided, so how large
	# this map draws its scenery stays one number in one place - see [PropScale] -
	# rather than something every layer would have to be told about.
	PropScale.apply_to(prop, self)
	_container.add_child(prop)
	_placed.append(prop)
	return prop


func _is_fixed_scale(layer: ScatterLayer) -> bool:
	return is_equal_approx(layer.scale_range.x, 1.0) and is_equal_approx(layer.scale_range.y, 1.0)


func _is_allowed(point: Vector2) -> bool:
	if clear_radius > 0.0 and point.distance_to(clear_centre) < clear_radius:
		return false
	for box: Rect2 in keep_clear:
		if box.has_point(point):
			return false
	for box: Rect2 in _auto_keep_clear:
		if box.has_point(point):
			return false
	return true


# --- Automatic clearance around impassable terrain --------------------------

## The footprint of every [member impassable_group] obstacle currently in the
## tree, expanded by [member impassable_clearance_margin] and converted into
## this node's own local space - the same space [member region] and
## [member keep_clear] are already authored in. Empty for a scene with no
## obstacles tagged into the group, or before this node is in the tree, which
## every caller reads as "nothing extra is kept clear this pass."
func _collect_auto_clear() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	if impassable_group == &"" or not is_inside_tree():
		return boxes

	for node: Node in get_tree().get_nodes_in_group(impassable_group):
		var obstacle := node as Node2D
		if obstacle == null:
			continue
		var world_rect: Variant = _collision_world_rect(obstacle)
		if world_rect == null:
			continue
		var grown: Rect2 = (world_rect as Rect2).grow(impassable_clearance_margin)
		var a := to_local(grown.position)
		var b := to_local(grown.end)
		boxes.append(Rect2(a, Vector2.ZERO).expand(b))
	return boxes


## The world-space bounding rectangle of every [CollisionShape2D] and
## [CollisionPolygon2D] under [param node], or null when it has none - read
## off whichever collision this obstacle was already authored with for
## physics, never a second footprint invented for scenery alone. A disabled
## shape is skipped, the same as the physics engine itself would skip it.
func _collision_world_rect(node: Node2D) -> Variant:
	var found := false
	var rect := Rect2()

	for shape_node: Node in node.find_children("*", "CollisionShape2D", true, false):
		var collision := shape_node as CollisionShape2D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var world_rect := _transform_rect(collision, collision.shape.get_rect())
		rect = world_rect if not found else rect.merge(world_rect)
		found = true

	for poly_node: Node in node.find_children("*", "CollisionPolygon2D", true, false):
		var polygon := poly_node as CollisionPolygon2D
		if polygon == null or polygon.disabled or polygon.polygon.is_empty():
			continue
		var world_rect := _transform_rect(polygon, _polygon_local_rect(polygon.polygon))
		rect = world_rect if not found else rect.merge(world_rect)
		found = true

	return rect if found else null


func _polygon_local_rect(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect


## [param local_rect], authored in [param shape_node]'s own local space,
## converted through its full [member Node2D.global_transform] - every corner,
## not just the two opposite ones - so a rotated or scaled collision shape
## still clears the ground it actually occupies rather than its own unrotated
## bounding box.
func _transform_rect(shape_node: Node2D, local_rect: Rect2) -> Rect2:
	var xform := shape_node.global_transform
	var rect := Rect2(xform * local_rect.position, Vector2.ZERO)
	rect = rect.expand(xform * Vector2(local_rect.end.x, local_rect.position.y))
	rect = rect.expand(xform * Vector2(local_rect.position.x, local_rect.end.y))
	rect = rect.expand(xform * local_rect.end)
	return rect


# --- Distance culling ------------------------------------------------------

## Hides whatever this scatter placed that no camera can currently reach, and
## shows again whatever it can. Cheap enough to run on a timer rather than on a
## frame: props do not move, so the only thing that changes between passes is
## where the camera is.
##
## [method CanvasItem.set_visible] returns immediately when the value is already
## what it was, so a pass over a settled map costs the distance tests alone and
## nothing else.
func _apply_cull() -> void:
	if not cull_enabled:
		return
	var anchor: Variant = _cull_anchor()
	if anchor == null:
		return

	var centre: Vector2 = anchor
	var radius := _cull_radius()
	var radius_sq := radius * radius
	for prop: Node in _placed:
		var item := prop as Node2D
		if item == null or not is_instance_valid(item):
			continue
		item.visible = item.global_position.distance_squared_to(centre) <= radius_sq


## Where the cull is measured from - the viewport's current [Camera2D] when it
## has one, since that and not the player is what actually decides what is on
## screen, and the viewer otherwise. Null when there is neither, which
## [method _apply_cull] reads as "leave everything drawn".
func _cull_anchor() -> Variant:
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_2d()
		if camera != null:
			return camera.get_screen_center_position()
	var viewer := get_tree().get_first_node_in_group(cull_viewer_group) as Node2D
	return null if viewer == null else viewer.global_position


## How far from [method _cull_anchor] scenery is kept drawn: whatever the main
## camera actually reaches at the zoom it is currently at, never less than
## [member cull_minimum_radius], plus [member cull_margin].
##
## Read off the live viewport rather than from a number in the inspector, so a
## window resize, a different display or a zone that zooms the camera out cannot
## leave the map culling scenery the player can see.
func _cull_radius() -> float:
	var radius := cull_minimum_radius
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_2d()
		if camera != null:
			var zoom := camera.zoom
			var half := viewport.get_visible_rect().size * 0.5
			if zoom.x > 0.0 and zoom.y > 0.0:
				radius = maxf(radius, Vector2(half.x / zoom.x, half.y / zoom.y).length())
	return radius + maxf(cull_margin, 0.0)


# --- Staged spawning -------------------------------------------------------

## How many props this scatter has decided on and not yet built. 0 for a scatter
## that is not streaming, and 0 again once the queue has drained - which is what
## "this map has finished arriving" means to anything watching.
func get_pending_count() -> int:
	return _pending_count


## How many of the props this scatter decided on are standing in the world right
## now. Reaches [method get_placed_count] once the queue has drained, and is
## always equal to it on a map that does not stream.
func get_spawned_count() -> int:
	return _placed.size()


func _queue(pending: PendingProp) -> void:
	var key := _stream_key(pending.point)
	var bucket: Array = _pending.get(key, [])
	bucket.append(pending)
	_pending[key] = bucket
	_pending_count += 1


func _stream_key(point: Vector2) -> Vector2i:
	var cell := maxf(stream_cell_size, 1.0)
	return Vector2i(int(floor(point.x / cell)), int(floor(point.y / cell)))


## Builds as much of the queue as [param budget_ms] allows, nearest cell to the
## player first, and leaves the rest for the frame after.
##
## [b]Nearest cell, not nearest prop.[/b] Sorting a thousand props by distance
## every frame would cost more than building a handful of them, and there are
## only ever a hundred or so cells - so the nearest cell is found by walking
## them, and the props inside it are built in whatever order they were decided.
## That is what [member stream_cell_size] is really choosing: how closely the
## order props arrive in follows where the player actually is.
##
## Whatever is built is handed the cull's own answer on the spot, so a prop that
## streams in behind the player is never drawn for the frame or two before the
## next cull pass would have taken it away again.
func _pump_stream(budget_ms: float) -> void:
	if _pending_count <= 0 or budget_ms <= 0.0:
		return

	var deadline := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	var anchor: Variant = _cull_anchor()
	# Where "near" is measured from. A map with no camera and no viewer to ask
	# simply builds itself outwards from the middle of its own region.
	var centre := region.get_center()
	if anchor != null:
		var here: Vector2 = anchor
		centre = to_local(here)

	var culling := cull_enabled and anchor != null
	var cull_centre := Vector2.ZERO
	var cull_radius_sq := 0.0
	if culling:
		var here: Vector2 = anchor
		cull_centre = here
		var radius := _cull_radius()
		cull_radius_sq = radius * radius

	while _pending_count > 0 and not _pending.is_empty():
		var key := _nearest_pending_cell(centre)
		var bucket: Array = _pending[key]
		while not bucket.is_empty():
			var pending: PendingProp = bucket.pop_back()
			_pending_count -= 1
			var prop := _build(pending.scene, pending.point, pending.scale)
			if prop != null and culling:
				prop.visible = prop.global_position.distance_squared_to(
					cull_centre) <= cull_radius_sq
			if Time.get_ticks_usec() >= deadline:
				if bucket.is_empty():
					_pending.erase(key)
				return
		_pending.erase(key)


## The queued cell nearest [param centre], both in this node's own local space.
func _nearest_pending_cell(centre: Vector2) -> Vector2i:
	var cell := maxf(stream_cell_size, 1.0)
	var nearest := Vector2i.ZERO
	var nearest_distance := INF
	for key: Vector2i in _pending:
		var middle := (Vector2(key) + Vector2(0.5, 0.5)) * cell
		var distance := middle.distance_squared_to(centre)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = key
	return nearest
