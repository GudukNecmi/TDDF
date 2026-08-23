class_name TravelMap
extends Node2D
## The road between two regions: a stretch of open country, far larger than an
## arena, with a horse cart standing at the far end of it.
##
## [b]It is a description of a place, not a system.[/b] Everything that happens on
## it happens through machinery the game already had - the same player, the same
## camera, the same [EnemySpawner], the same enemies - and [TravelDirector] is what
## points that machinery at this map. What lives here is only the set of facts that
## are *this road's own*: how big it is, where the player is set down, where the
## cart is waiting, and - on its own [TravelWaveDirector] child - what its country
## throws at whoever crosses it.
##
## They live here rather than on the director for the reason every per-map value
## in this project does: a second map is a second scene with its own numbers, and
## nothing in a shared script should have to name the desert or be edited to add
## a forest. The director reads whatever the map it was handed says.
##
## [b]There is no clock on it.[/b] A journey is not a round, so the run's minute is
## never started - the road ends when the player reaches the cart and not before,
## and the enemies keep coming for exactly as long as that takes. That is also why
## the road does not use the arena's [WaveManager]: waves timed against a minute
## that is never running, arriving around a player who is faster than they are,
## make a crossing that can simply be walked. What the road uses instead is
## [TravelWaveDirector], which measures its difficulty against how close the player
## is to the cart and puts its enemies between them and it.

## Group the road joins, so the director and anything else can find it without a
## path into a scene that is instanced at runtime.
const GROUP := &"travel_map"

## The ground the player and the enemies may be on, in this node's own local
## space. The walls are authored around it; this is their inner face.
##
## Everything about the size of the road is this one rectangle: the camera is
## clamped to it, the spawner is told to keep enemies inside it, and the scenery
## is strewn across it.
@export var playable_region := Rect2(-9800.0, -6125.0, 19600.0, 12250.0)

@export_group("Nodes")
## Where the player is set down as the road is built. Left unresolved they are
## put at this node's own origin.
@export var player_spawn_path: NodePath = ^"PlayerSpawn"
## The waggon at the far end. Left unresolved the road has no way off it, which
## the director reports rather than hiding.
@export var cart_path: NodePath = ^"HorseCart"
## The camera limits for this road. Applied by the director once the player has
## been carried here, rather than on ready, because the camera has to be told
## about a place the player is actually standing in.
@export var camera_bounds_path: NodePath = ^"CameraBounds"
## This road's fighting - its [TravelWaveDirector]. A child of the map rather than
## of the world for the same reason everything else on this list is: how thickly a
## road is defended, how wide its formations are and how hard its enemies hit are
## facts about a place, and a second road is a second scene with its own answers.
##
## Left unresolved the road is simply quiet, which is a map that can be walked
## across while its size and its scenery are being tuned.
@export var wave_director_path: NodePath = ^"TravelWaves"


func _ready() -> void:
	add_to_group(GROUP)


## The road any travel system should talk to. Null means this world has none,
## which every caller reads as "nobody is on the road".
static func get_active(from_node: Node) -> TravelMap:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelMap


## The playable rectangle in world space, which is what the camera and the
## spawner both want.
func get_world_region() -> Rect2:
	return Rect2(global_position + playable_region.position, playable_region.size)


## Where the player begins the crossing, in world space.
func get_spawn_position() -> Vector2:
	var marker := get_node_or_null(player_spawn_path) as Node2D
	return global_position if marker == null else marker.global_position


## The waggon waiting at the far end, or null on a road that has been given none.
func get_cart() -> HorseCart:
	return get_node_or_null(cart_path) as HorseCart


## This road's waves, or null on a road authored without any.
func get_wave_director() -> TravelWaveDirector:
	return get_node_or_null(wave_director_path) as TravelWaveDirector


## Hands this road's extent to the camera. Called by the director once the player
## has been carried here.
func apply_camera_bounds() -> void:
	var bounds := get_node_or_null(camera_bounds_path) as CameraBounds
	if bounds != null:
		bounds.apply()


## How far the player has to cross, for a readout or for tuning. Measured from
## where they are set down to where the cart stands.
func get_crossing_distance() -> float:
	var cart := get_cart()
	if cart == null:
		return 0.0
	return get_spawn_position().distance_to(cart.global_position)
