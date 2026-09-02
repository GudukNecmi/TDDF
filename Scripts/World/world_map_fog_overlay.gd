class_name WorldMapFogOverlay
extends Node2D
## The fog of war's only visual - a smooth, per-pixel gradient painted by
## [code]Shaders/world_map_fog.gdshader[/code] rather than the flat, one
## colour per grid cell this used to draw with [method CanvasItem.draw_rect].
## [WorldMapFog]'s own coarse cell grid is still the one and only authority
## for UNEXPLORED / EXPLORED / VISIBLE - see [method WorldMapFog.get_state] -
## this only changes how that same data is *shown*.
##
## [b]Why the old draw looked pixelated.[/b] Each fog cell used to be filled
## with one flat [Color], so neighbouring cells met at a hard edge no matter
## how the alpha inside them was chosen - that edge is what read as a grid of
## square blocks. Nothing about [WorldMapFog]'s own cell size caused that; a
## finer grid would only have made more, smaller blocks.
##
## [b]Two things replace the flat fill, both computed in the shader itself:[/b]
##   1. [member WorldMapFog]'s explored set is baked into a small texture -
##      [member mask_resolution] cells per texel - sampled with bilinear
##      filtering ([code]filter_linear[/code] in the shader), which is what
##      turns a boundary between a 0 texel and a 1 texel into a gradient
##      instead of a step. See [method _rebuild_mask].
##   2. The boundary that actually matters most - what is visible right now -
##      is not sampled from the grid at all. It is a smooth radial falloff
##      computed fresh per pixel from [member soft_edge_width] and
##      [member reveal_falloff] around the player's own position, so it is
##      exactly as smooth as the shader's floating-point math regardless of
##      [member WorldMapFog.cell_size].
##
## [b]Cheap by construction, not by throttling a redraw.[/b] The geometry this
## draws - one rectangle covering the map's bounds - is only ever drawn once,
## on ready, because the two things above are shader uniforms: the GPU
## reevaluates the fragment shader every rendered frame on its own, with
## whatever the uniforms currently hold, the same way a plain [Sprite2D] never
## needs [method CanvasItem.queue_redraw] to keep appearing on screen.
## [member player_pos] is pushed every [method _process] - one [Vector2], not
## worth gating - and the mask texture is only rebuilt when
## [signal WorldMapFog.fog_changed] fires, which is [WorldMapFog]'s own 10Hz
## tick, not this node's.
##
## [b]Lives in world space, on purpose.[/b] This is a plain child of
## [code]WorldMap[/code], not fixed to the camera or the HUD, so whichever
## camera looks at the World Map sees the same shroud - the main gameplay
## camera and [WorldMapMinimap]'s own camera both, since a [SubViewport]
## shares its parent's [World2D] by default. A [WorldMapLocation] or a hidden
## [WorldBandit] underneath is genuinely covered, not just visually implied
## to be.

@export var fog_path: NodePath
@export var body_group: StringName = &"player"
## Base colour of the fog, unlit ground beneath it.
@export var fog_color: Color = Color(0.03, 0.02, 0.02)
## Resting alpha over ground that has never been seen.
@export_range(0.0, 1.0) var unexplored_alpha: float = 1.0
## Resting alpha over ground that has been seen before but is not currently
## VISIBLE - "remembered, not in sight".
@export_range(0.0, 1.0) var explored_alpha: float = 0.6
## World units of the smooth boundary's transition band. The band always
## ends exactly at [WorldMapFog]'s own effective visibility radius - see
## [member visible_radius_override] - and starts this many units inside it.
@export var soft_edge_width: float = 220.0
## Shapes the transition curve: 1 is a linear fade across the band, above 1
## stays clearer for longer before falling away faster near the edge, below 1
## the opposite. Purely a look; never changes which ground is logically
## VISIBLE.
@export var reveal_falloff: float = 1.6
## When 0 or greater, overrides [method WorldMapFog.get_effective_radius] for
## the visual boundary only. Left at the default -1, the glow always matches
## the radius that actually decides [enum WorldMapFog.VisibilityState], so
## the two can never drift apart.
@export var visible_radius_override: float = -1.0
## How many logical [member WorldMapFog.cell_size] cells are merged into one
## texel of the explored mask. 1 keeps the mask at the grid's own resolution
## - already smoothed by the shader's bilinear filtering and, near the
## player, dominated by the radial glow above - larger values shrink the
## mask texture and the per-tick rebuild cost further, at some loss of
## precision in remembered ground far from the player.
@export var mask_resolution: int = 2
## Extra world units the drawn rectangle and the mask extend beyond the
## region zones' own combined rectangle, so nothing at the map's authored
## edge is clipped.
@export var draw_margin: float = 200.0

var _fog: WorldMapFog
var _player: Node2D
var _bounds: Rect2
var _bounds_ready: bool = false
var _local_origin: Vector2
var _local_size: Vector2
var _mask_texture: ImageTexture
var _material: ShaderMaterial


func _ready() -> void:
	_fog = get_node_or_null(fog_path) as WorldMapFog
	if _fog == null:
		_fog = WorldMapFog.get_active(self)

	_material = ShaderMaterial.new()
	_material.shader = load("res://Shaders/world_map_fog.gdshader") as Shader
	material = _material

	# High and non-relative so this always paints over the terrain, roads,
	# location markers and WorldBandits beneath it regardless of where in
	# the tree it happens to sit.
	z_index = 4096
	z_as_relative = false

	_compute_bounds()
	_push_static_params()
	queue_redraw()

	if _fog != null:
		_fog.fog_changed.connect(_rebuild_mask)
		_rebuild_mask()


func _process(_delta: float) -> void:
	if _material == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	if _player == null:
		return

	_material.set_shader_parameter("player_pos", to_local(_player.global_position))
	_material.set_shader_parameter("visible_radius", _current_visible_radius())


## The combined rectangle of every [WorldMapRegionZone] on this map, in
## global space, expanded by [member draw_margin] - the map's real extent,
## asked from the same authority the regions themselves already are rather
## than measured out by hand a second time.
func _compute_bounds() -> void:
	var result: Rect2
	var found := false
	for node in get_tree().get_nodes_in_group(WorldMapRegionZone.GROUP):
		var zone := node as WorldMapRegionZone
		if zone == null:
			continue
		var area := zone.get_world_area()
		result = area if not found else result.merge(area)
		found = true
	if not found:
		return

	_bounds = result.grow(draw_margin)
	_bounds_ready = true
	_local_origin = to_local(_bounds.position)
	_local_size = _bounds.size


func _draw() -> void:
	if not _bounds_ready:
		_compute_bounds()
		if not _bounds_ready:
			return
	draw_rect(Rect2(_local_origin, _local_size), Color.WHITE)


func _push_static_params() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("mask_origin", _local_origin)
	_material.set_shader_parameter("mask_size", _local_size)
	_material.set_shader_parameter("fog_color", Vector3(fog_color.r, fog_color.g, fog_color.b))
	_material.set_shader_parameter("unexplored_alpha", unexplored_alpha)
	_material.set_shader_parameter("explored_alpha", explored_alpha)
	_material.set_shader_parameter("soft_edge_width", soft_edge_width)
	_material.set_shader_parameter("reveal_falloff", reveal_falloff)


func _current_visible_radius() -> float:
	if visible_radius_override >= 0.0:
		return visible_radius_override
	if _fog == null:
		return 0.0
	return _fog.get_effective_radius()


## Bakes [member WorldMapFog]'s explored set into [member _mask_texture] -
## every mask cell that is EXPLORED or VISIBLE becomes a 1, everything else a
## 0 - so the shader's bilinear sampling has something smooth to read at the
## remembered/unseen boundary. Only ever called off
## [signal WorldMapFog.fog_changed], never every frame - see the class doc.
func _rebuild_mask() -> void:
	if _fog == null or not _bounds_ready or _material == null:
		return

	var mask_cell := _fog.cell_size * maxf(float(mask_resolution), 1.0)
	var width := maxi(int(ceili(_bounds.size.x / mask_cell)), 1)
	var height := maxi(int(ceili(_bounds.size.y / mask_cell)), 1)

	var image := Image.create(width, height, false, Image.FORMAT_R8)
	for y in range(height):
		for x in range(width):
			var world_pos := _bounds.position + Vector2((x + 0.5) * mask_cell, (y + 0.5) * mask_cell)
			var explored := _fog.get_state(world_pos) != WorldMapFog.VisibilityState.UNEXPLORED
			image.set_pixel(x, y, Color(1.0 if explored else 0.0, 0.0, 0.0))

	if _mask_texture == null:
		_mask_texture = ImageTexture.create_from_image(image)
	else:
		_mask_texture.set_image(image)
	_material.set_shader_parameter("mask_texture", _mask_texture)
