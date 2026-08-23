class_name DestinationArrow
extends Control
## The pointer at the edge of the screen while the horse cart is somewhere off it.
##
## A travel map is far too large to see across, so for most of a crossing the
## thing the player is walking towards is not on screen at all. This is the only
## thing that tells them which way it is.
##
## [b]It lives entirely in screen space.[/b] It is a [Control] on the HUD rather
## than a marker in the world, so it does not scroll, scale or rotate with the
## map: it sits a fixed distance in from the edge of the viewport and turns on the
## spot. Where it sits is worked out by casting the direction the player would
## walk in against the edges of the screen, so it slides round the border as the
## player turns rather than snapping between four corners.
##
## [b]It hides itself the moment the cart is genuinely in view[/b], because at that
## point the cart's own red mark is doing the job and two things pointing at the
## same waggon is one too many. Both read that from
## [method HorseCart.is_on_screen], so there is no way for the arrow and the mark
## to disagree about where the edge of the screen is.
##
## Nothing about travel is decided here, and nothing outside travel is assumed:
## it follows whatever is in [member target_group], so a later bounty marker or a
## second kind of destination is this same node with a different group in it.

## Group the thing being pointed at is found in.
@export var target_group: StringName = &"horse_cart"
## Group the body the direction is measured from is found in.
@export var player_group: StringName = &"player"

@export_group("Nodes")
## The picture that is moved and turned. Its texture, and therefore what the
## arrow looks like, is set on that node in the inspector.
@export var arrow_path: NodePath = ^"Arrow"

@export_group("Placement")
## How large the arrow is drawn, in pixels.
@export var arrow_size := Vector2(72.0, 72.0)
## How far in from the edge of the screen the arrow rides, in pixels. This is the
## distance to the arrow's own middle, so it is never clipped by the border.
@export var edge_distance: float = 96.0
## Turned this much on top of the direction it is pointing, in degrees. 0 suits
## artwork drawn pointing right, which is how the placeholder is drawn; a piece
## drawn pointing up wants -90.
@export var rotation_offset_degrees: float = 0.0
## Whether the arrow turns at all. Off leaves it upright and only slides it round
## the border, for artwork that is not directional.
@export var rotates: bool = true

@export_group("Showing")
## Whether the arrow takes itself off the moment the cart is on screen.
@export var hide_when_on_screen: bool = true
## Beyond this distance from the cart, in world pixels, the arrow is drawn at full
## strength.
@export var full_opacity_distance: float = 2200.0
## At or below this distance it is not drawn at all, and between the two it fades
## - so the arrow thins out as the player closes on the cart rather than blinking
## off the frame it comes into view.
@export var fade_out_distance: float = 900.0
## How quickly the arrow fades in and out, in alpha per second. 0 snaps.
@export var fade_speed: float = 4.0

@onready var _arrow: Control = get_node_or_null(arrow_path) as Control

var _target: Node2D
var _player: Node2D
## Drawn strength, eased towards the strength the distance asks for so the arrow
## never pops.
var _shown: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _arrow != null:
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arrow.custom_minimum_size = arrow_size
		_arrow.size = arrow_size
		# Turned about its own middle rather than its corner, so a rotating arrow
		# stays where it was put.
		_arrow.pivot_offset = arrow_size * 0.5
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	var wanted := _wanted_strength()
	_shown = _approach(_shown, wanted, delta)

	visible = _shown > 0.001
	modulate.a = _shown
	if not visible or _arrow == null:
		return

	_place()


## How strongly the arrow should be drawn right now: nothing at all with no cart
## to point at or the cart in view, and otherwise the distance faded between the
## two exported marks.
func _wanted_strength() -> float:
	var target := _find_target()
	var player := _find_player()
	if target == null or player == null:
		return 0.0

	if hide_when_on_screen and target.has_method(&"is_on_screen") \
			and target.call(&"is_on_screen"):
		return 0.0

	var distance := player.global_position.distance_to(target.global_position)
	var near := minf(fade_out_distance, full_opacity_distance)
	var far := maxf(full_opacity_distance, near + 0.001)
	return clampf((distance - near) / (far - near), 0.0, 1.0)


## The arrow itself: turned to face the cart, and slid round the inside of the
## screen border to the point the player would walk out through.
func _place() -> void:
	var target := _find_target()
	var player := _find_player()
	if target == null or player == null:
		return

	var from := player.get_global_transform_with_canvas().origin
	var to := target.get_global_transform_with_canvas().origin
	var direction := to - from
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()

	var border := get_viewport_rect().grow(-maxf(edge_distance, 0.0))
	_arrow.position = _edge_point(from, direction, border) - _arrow.size * 0.5

	if rotates:
		_arrow.rotation = direction.angle() + deg_to_rad(rotation_offset_degrees)
	else:
		_arrow.rotation = 0.0


## Where a ray leaves [param border]: the nearest of the two axis crossings ahead
## of it. Cast from where the player actually is rather than from the middle of
## the screen, so the arrow sits where they would walk out rather than where the
## camera would.
func _edge_point(from: Vector2, direction: Vector2, border: Rect2) -> Vector2:
	var travel := INF

	if absf(direction.x) > 0.0001:
		var edge_x := border.end.x if direction.x > 0.0 else border.position.x
		travel = minf(travel, (edge_x - from.x) / direction.x)
	if absf(direction.y) > 0.0001:
		var edge_y := border.end.y if direction.y > 0.0 else border.position.y
		travel = minf(travel, (edge_y - from.y) / direction.y)

	if travel == INF:
		return border.get_center()

	# Clamped as a last line of defence: the player standing outside the border -
	# pinned against a camera limit, say - would otherwise put the arrow behind
	# them or off the frame entirely.
	var point := from + direction * maxf(travel, 0.0)
	return point.clamp(border.position, border.end)


## Eased rather than assigned, so the arrow fades instead of blinking as the cart
## crosses the edge of the screen.
func _approach(current: float, wanted: float, delta: float) -> float:
	if fade_speed <= 0.0:
		return wanted
	return move_toward(current, wanted, fade_speed * delta)


## Both ends are looked up by group and re-looked-up if they go away, the same way
## the heart bar finds the player's health - which is what lets this sit on a HUD
## that is built before the travel map is instanced into the world.
func _find_target() -> Node2D:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(target_group) as Node2D
	return _target


func _find_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	return _player
