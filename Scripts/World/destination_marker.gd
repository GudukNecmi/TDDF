class_name DestinationMarker
extends Node2D
## The mark over the thing the player is walking towards, and the single answer to
## whether they can see it yet.
##
## [b]It is the pairing the horse cart already uses, made into a component.[/b] A
## destination in this game is marked twice and never both at once: a mark hanging
## over it while it is on screen, and a [DestinationArrow] on the HUD pointing at it
## from off screen. Both read [method is_on_screen] - the mark shows itself on it and
## the arrow hides itself on it - so there is no way for the game to be drawing both
## marks or neither. See [HorseCart], which is where that arrangement was written and
## which is left exactly as it is.
##
## What this adds is that a destination no longer has to be a portal to be marked.
## The mini boss is an [Enemy1] standing in the desert, so the mark is dropped onto
## it as a child instead of being authored into its scene, and the arrow is pointed
## at [member group] rather than at the cart.
##
## [b]Nothing here decides what the mark looks like.[/b] The picture is a
## [Sprite2D] in this node's own scene, so the artwork - the same X the travel map
## already uses - is an inspector field rather than a path in a script.

## Emitted when the mark is taken down for good. What a director listening for
## "the player has arrived" can hang off, so arriving is announced by the thing
## that was being aimed at.
signal removed

## Group this node joins, so a [DestinationArrow] can be pointed at it without
## being wired across a scene the marker is instanced into at runtime.
##
## It is the marker rather than the thing being marked that joins, and deliberately:
## the arrow asks its target for [method is_on_screen], and this is what can answer.
@export var group: StringName = &""

@export_group("Placement")
## Where the mark sits relative to whatever it is parented to, in pixels. Negative y
## is above it.
@export var marker_offset := Vector2(0.0, -210.0)
## How far it rises and falls as it sits there, in pixels. 0 pins it still.
@export var bob_height: float = 10.0
## Rises and falls per second.
@export var bob_speed: float = 0.8
## Whether the mark takes itself off while what it marks is off screen. On - an
## unseen mark marks nothing, and the arrow is what points from off screen.
@export var only_on_screen: bool = true

@export_group("On screen")
## How far inside the edge of the screen this has to be before it counts as visible,
## in pixels. A little inset, so the mark and the arrow do not trade places every
## frame while the target sits exactly on the boundary.
@export var on_screen_inset: float = 90.0

@export_group("Nodes")
## The picture that is moved. Left unresolved this node moves itself, so a marker
## built as a bare sprite with this script on it still works.
@export var art_path: NodePath = ^"Art"

@onready var _art: Node2D = get_node_or_null(art_path) as Node2D

var _time: float = 0.0
## Whether the mark has been taken down. Once, and it never comes back - arriving
## somewhere is not something that un-happens.
var _removed: bool = false


func _ready() -> void:
	if group != &"":
		add_to_group(group)
	position = Vector2.ZERO
	if _art == null:
		_art = self
	_art.position = marker_offset
	_art.visible = false


## The marker the given group should be talking to. Null means there is nothing
## being aimed at right now, which every caller reads as "no destination".
static func get_in_group(from_node: Node, group_name: StringName) -> DestinationMarker:
	if from_node == null or not from_node.is_inside_tree() or group_name == &"":
		return null
	return from_node.get_tree().get_first_node_in_group(group_name) as DestinationMarker


## Whether what this marks is currently within the camera's view, inset a little so
## the answer does not flicker on the boundary.
##
## [b]The single answer to "can the player see it".[/b] [DestinationArrow] calls
## exactly this on whatever it is pointing at, which is why the marker rather than
## the target joins the group.
func is_on_screen() -> bool:
	var camera := _view_camera()
	if camera == null:
		return true

	var size := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - size * 0.5, size)
	return view.grow(-maxf(on_screen_inset, 0.0)).has_point(global_position)


## Takes the mark down for good and leaves the group, so the arrow following it
## loses its target on the same frame the X disappears.
##
## [b]Both halves have to happen here[/b] rather than in whatever noticed the
## player arrive: leaving the group is what stops the arrow, hiding is what stops
## the X, and an arrival that only did one of them would leave the other pointing
## at a fight already under way.
func remove_marker() -> void:
	if _removed:
		return
	_removed = true

	if group != &"" and is_in_group(group):
		remove_from_group(group)
	if _art != null:
		_art.visible = false
	set_process(false)
	removed.emit()


## Whether the mark has been taken down.
func is_removed() -> bool:
	return _removed


func _process(delta: float) -> void:
	if _removed or _art == null:
		return

	var showing := not only_on_screen or is_on_screen()
	_art.visible = showing
	if not showing:
		return

	_time += delta
	var bob := 0.0
	if bob_height > 0.0 and bob_speed > 0.0:
		bob = sin(_time * bob_speed * TAU) * bob_height
	_art.position = marker_offset + Vector2(0.0, bob)


func _view_camera() -> Camera2D:
	var camera := CameraController.get_active(self)
	if camera != null:
		return camera
	return get_viewport().get_camera_2d()
