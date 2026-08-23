class_name RegionGround
extends Node
## Lays the ground the part of the map being played is drawn on.
##
## The desert is one world scene at five places, and the five do not look alike:
## the dust of a camp, the spoil of a mine, the bed of a red river. That difference
## is a property of the [i]place[/i], so it is authored on the place - see
## [member MapRegion.ground_texture] - and this node is only the hand that puts it
## on the floor as the world is built.
##
## [b]It owns no list of regions.[/b] It asks the run which region it is in, asks
## that region for its ground, and writes it to the map's own [TiledSurface]. There
## is no name, letter or branch here that a sixth region, or a second map, would
## have to be added to: giving a place its own ground is dropping a PNG into that
## region's [code].tres[/code] file.
##
## [b]A region with no ground of its own keeps the map's.[/b] The floor is left
## exactly as the scene authored it - which is what every region did before there
## was regional artwork, and what a map whose parts share one ground should keep
## doing.

## Group this joins, so a test or a later readout can find it without a path.
const GROUP := &"region_ground"

## Whether the region's ground is applied at all. Off leaves the floor as the scene
## was authored, which is the map exactly as it was before this existed.
@export var enabled: bool = true

@export_group("Nodes")
## The floor this writes to. The map's own tiled ground - normally the [Floor]
## sitting beside this node.
@export var surface_path: NodePath = ^"../Floor"
## The run, asked which region is being played. The same autoload the HUD's own
## place-name reads, so the ground and the label can never disagree about where the
## player is.
@export var session_path: NodePath = ^"/root/RunSession"


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	apply()


## The texture the floor is currently wearing, for a test.
func get_ground_texture() -> Texture2D:
	var surface := _surface()
	return null if surface == null else surface.texture


## Puts the current region's ground on the floor. Public and safe to call again, so
## anything that changes the region without rebuilding the world can ask for the
## floor to be re-read rather than reloading the map.
func apply() -> void:
	if not enabled:
		return

	var region := _region()
	if region == null:
		return

	var ground := region.ground_texture
	if ground == null:
		# The place has no ground of its own. The map's authored floor is left alone
		# rather than being cleared, so a region without artwork yet is the desert as
		# it always looked.
		return

	var surface := _surface()
	if surface == null:
		return

	surface.texture = ground
	if region.ground_tile_size > 0.0:
		# Setting it re-tiles the surface through the setter, so this is also what
		# rebuilds the floor for the new picture.
		surface.tile_size = region.ground_tile_size
	else:
		# Same texture size, same tiling: the floor is rebuilt against the new
		# picture without the map's own tile size being second-guessed.
		surface.tile_size = surface.tile_size


func _surface() -> TiledSurface:
	return get_node_or_null(surface_path) as TiledSurface


## The region being played, or null when the run has not picked one - which is
## every world opened straight from the editor, and reads as "leave the floor
## alone".
func _region() -> MapRegion:
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_region"):
		return null
	return session.get_region() as MapRegion
