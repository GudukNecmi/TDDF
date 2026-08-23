class_name HorseCart
extends ArenaPortal
## The waggon waiting at the far side of a travel map: the only way off the road.
##
## [b]It is an arena portal, exactly as the camp is.[/b] Everything about standing
## near a thing and holding a key on it - the reach test, the crossing signals,
## the hold and its progress, swallowing the tap so it cannot also fire the gun -
## belongs to [ArenaPortal] and is not repeated here. The cart is that portal with
## [member ArenaPortal.open_on_ready] on, because there is no round to wait for:
## it is standing there from the moment the road is built.
##
## What it adds is one thing the camp has no use for: a mark over it, so that the
## moment the waggon comes on screen the player can see it is the place rather
## than another piece of scenery. Off screen there is nothing to mark - the
## [DestinationArrow] on the HUD does that job instead - so the mark shows itself
## only while the cart is genuinely in view, and both it and the arrow read that
## from [method is_on_screen] so they cannot disagree about where the edge of the
## screen is.
##
## Nothing about travel is decided here. Holding the key calls
## [method ArenaPortal.use], which opens whatever [member ArenaPortal.menu_path]
## points at - the [TravelMenu] - and how long a journey takes, what it costs the
## clock and what happens on the far side are all that screen's and
## [TravelDirector]'s business. The cart only says the player is standing at it.

## Group the cart joins, so the HUD's prompt, the arrow and the director can find
## it without a path across a scene that is instanced at runtime.
const CART_GROUP := &"horse_cart"

@export_group("Destination mark")
## The mark drawn over the cart while it is on screen. Optional - a cart with
## none is simply unmarked.
##
## It is deliberately not a child of [member ArenaPortal.art_path]: the portal
## drives that node's scale for its opening and its idle pulse, so a mark parented
## under it would breathe along with the waggon.
@export var marker_path: NodePath = ^"Marker"
## Where the mark sits relative to the cart's own origin, in pixels. Negative y is
## above it.
@export var marker_offset := Vector2(0.0, -210.0)
## How large it is drawn, as a multiple of the artwork's own size.
@export var marker_scale: float = 1.0
## Whether the mark hides itself while the cart is off screen. On - an unseen mark
## marks nothing, and the arrow is what points at the cart from off screen.
@export var marker_only_on_screen: bool = true
## How far the mark rises and falls as it sits there, in pixels. 0 pins it still.
@export var marker_bob_height: float = 10.0
## Rises and falls per second.
@export var marker_bob_speed: float = 0.8

@export_group("On screen")
## How far inside the edge of the screen the cart has to be before it counts as
## visible, in pixels. A little inset, so the mark and the arrow do not trade
## places every frame while the cart is sitting exactly on the edge.
@export var on_screen_inset: float = 90.0

@onready var _marker: Node2D = get_node_or_null(marker_path) as Node2D

var _marker_time: float = 0.0


func _ready() -> void:
	super()
	add_to_group(CART_GROUP)
	if _marker != null:
		_marker.position = marker_offset
		_marker.scale = Vector2.ONE * maxf(marker_scale, 0.0)
		_marker.visible = false


## The cart the road's systems should talk to. Null means this world has none -
## an arena, the base, or a travel map being looked at in the editor - which every
## caller reads as "there is nowhere to ride to from here".
static func get_active(from_node: Node) -> HorseCart:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(CART_GROUP) as HorseCart


## Whether the cart is currently within the camera's view, inset a little so the
## answer does not flicker on the boundary.
##
## [b]The single answer to "can the player see it".[/b] The mark over the cart
## shows itself on it and the [DestinationArrow] hides itself on it, so there is
## no way for the game to be drawing both or neither.
func is_on_screen() -> bool:
	var camera := _view_camera()
	if camera == null:
		return true

	var size := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - size * 0.5, size)
	return view.grow(-maxf(on_screen_inset, 0.0)).has_point(global_position)


func _process(delta: float) -> void:
	super(delta)
	_drive_marker(delta)


## The mark, shown or hidden on the one visibility answer and nudged up and down
## so it reads as something placed rather than something painted on the ground.
func _drive_marker(delta: float) -> void:
	if _marker == null:
		return

	var showing := is_open() and (not marker_only_on_screen or is_on_screen())
	_marker.visible = showing
	if not showing:
		return

	_marker_time += delta
	var bob := 0.0
	if marker_bob_height > 0.0 and marker_bob_speed > 0.0:
		bob = sin(_marker_time * marker_bob_speed * TAU) * marker_bob_height
	_marker.position = marker_offset + Vector2(0.0, bob)


func _view_camera() -> Camera2D:
	var camera := CameraController.get_active(self)
	if camera != null:
		return camera
	return get_viewport().get_camera_2d()
