class_name WorldMapFog
extends Node2D
## The World Map's fog of war - the single authority for which of its
## coarse grid cells are UNEXPLORED, EXPLORED or VISIBLE right now, kept as
## two small dictionaries rather than a per-pixel image or a second
## simulation. [WorldMapFogOverlay] paints this in world space,
## [WorldMapMinimap] shows the same painted world through a second camera,
## and [WorldBandit] asks [method get_state] directly to decide whether it
## should currently be drawn - nothing else reaches into how the grid is
## stored.
##
## [b]Run-only, like [WorldBandit]'s own state.[/b] Nothing here is saved;
## the explored set starts empty every time the World Map is entered. A
## later save system reading and restoring what has been explored is the
## whole of what persistence would take - nothing about the grid shape
## would need to change.
##
## [b]A grid, not a texture.[/b] The map is roughly 6000x4000 world units;
## at [member cell_size] 96 that is a ~63x42 grid, small enough that even a
## generous [member visibility_radius] only ever touches a few hundred
## cells a recompute - see [method _recompute] - rather than anything sized
## to the screen or the world in pixels. Everything here is measured in
## [member Node2D.global_position], the same space [WorldMapRegionZone]
## already answers "am I inside this" in, so a cell means the same physical
## square of ground no matter where [WorldMap] itself sits in the
## persistent world.

enum VisibilityState { UNEXPLORED, EXPLORED, VISIBLE }

## Group this joins, so anything on the World Map can find the one active
## fog the same way it finds [WorldMapState] or [WorldMapPlayerPower].
const GROUP := &"world_map_fog"

## Emitted whenever the visible set is recomputed - [WorldMapFogOverlay]
## redraws off this rather than every frame, since a [CanvasItem]'s last
## drawn output stays correctly on screen as the camera pans on its own.
signal fog_changed

@export var body_group: StringName = &"player"
## Side length of one fog grid cell, in world units. Smaller reveals more
## precisely but touches more cells for the same radius.
@export var cell_size: float = 96.0
## How far around the player, in world units, counts as currently VISIBLE.
@export var visibility_radius: float = 640.0
## How many world units before the visibility radius a cell starts
## softening from fully clear towards the explored tint. Purely a
## rendering nicety for [WorldMapFogOverlay] - see
## [method get_visibility_strength] - it never changes which of the three
## states [method get_state] reports.
@export var reveal_falloff: float = 160.0
## What [member visibility_radius] is multiplied by while [WorldMapState]
## reports the NIGHT period. Below 1 shrinks how far the player can see
## after dark; 1 leaves night exactly as bright as day.
@export var night_visibility_multiplier: float = 0.65
## Future-ready only, per this phase's scope - nothing yet sets this to
## anything but 1, and no weather system reads or writes it. Multiplies
## [member visibility_radius] exactly like [member night_visibility_multiplier]
## once one exists, without [WorldMapFog] itself changing.
@export var weather_visibility_multiplier: float = 1.0
## How often, in seconds, the visible set is recomputed and [signal fog_changed]
## fires - not every frame; see the class doc on grid size. A cell this
## coarse recomputing a few times a second reveals smoothly to the eye
## without the fog doing the work every frame.
@export var update_interval: float = 0.1

var _explored: Dictionary = {}
var _visible_cells: Dictionary = {}
var _player: Node2D
var _timer: float = 0.0
var _effective_radius: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(body_group) as Node2D
	_recompute()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_recompute()


## The fog for the World Map currently in the tree, found by group. Null
## means there is no fog to ask, which every caller reads as "assume
## nothing has been explored".
static func get_active(from_node: Node) -> WorldMapFog:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapFog


## Which of the three states [param world_pos] is in right now.
func get_state(world_pos: Vector2) -> VisibilityState:
	var cell := world_to_cell(world_pos)
	if _visible_cells.has(cell):
		return VisibilityState.VISIBLE
	if _explored.has(cell):
		return VisibilityState.EXPLORED
	return VisibilityState.UNEXPLORED


## How far into the soft edge [param world_pos] is: 1 at the player and
## through the fully-visible core, easing down to 0 at the current
## visibility radius and beyond. Purely for a renderer's alpha -
## [method get_state] never consults this.
func get_visibility_strength(world_pos: Vector2) -> float:
	if _player == null:
		return 0.0
	var distance := world_pos.distance_to(_player.global_position)
	var inner := maxf(_effective_radius - reveal_falloff, 0.0)
	if distance <= inner:
		return 1.0
	if distance >= _effective_radius:
		return 0.0
	return 1.0 - (distance - inner) / maxf(_effective_radius - inner, 0.001)


## The visibility radius actually in force this recompute - [member visibility_radius]
## already folded together with the day/night and weather multipliers. Added
## for [WorldMapFogOverlay]'s shader-based glow, so its own boundary reads
## exactly the radius that decides [enum VisibilityState] rather than a second
## copy of the same math kept in sync by hand.
func get_effective_radius() -> float:
	return _effective_radius


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)


func _recompute() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	if _player == null:
		return

	_effective_radius = visibility_radius * _time_multiplier() * weather_visibility_multiplier
	_visible_cells.clear()

	var player_cell := world_to_cell(_player.global_position)
	var reach := int(ceili(_effective_radius / cell_size)) + 1
	var radius_sq := _effective_radius * _effective_radius

	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := player_cell + Vector2i(dx, dy)
			var center := cell_to_world(cell)
			if center.distance_squared_to(_player.global_position) <= radius_sq:
				_visible_cells[cell] = true
				_explored[cell] = true

	fog_changed.emit()


func _time_multiplier() -> float:
	var state := WorldMapState.get_active(self)
	if state == null:
		return 1.0
	if state.get_time_period_name() == &"NIGHT":
		return night_visibility_multiplier
	return 1.0
