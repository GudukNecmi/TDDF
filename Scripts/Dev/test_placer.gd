class_name TestPlacer
extends Node2D
## Puts things on the ground where the mouse is pointing.
##
## [b]It does not know what it is placing.[/b] [method begin] is handed a
## [Callable] that takes a world position and returns whatever was built, so this
## node contains no enemy, no boss and no scene - it owns the [i]mode[/i]: pull the
## view out, follow the mouse, and hand a point over on every click until the player
## says stop. That is what lets the same component place a prop, a pickup or a piece
## of scenery later without being taught about any of them.
##
## [b]The point is read off the canvas, not worked out.[/b] Every frame it asks for
## [method CanvasItem.get_global_mouse_position], which is the mouse run back through
## the viewport's own canvas transform - the camera's position, its zoom, its shake
## and its rotation are all already in that transform. So panning, zooming or a
## screen shake mid-placement cannot put the marker anywhere but under the cursor,
## and there is no screen-to-world arithmetic here to drift out of step with the
## camera.
##
## [b]The trigger is silenced while it is up.[/b] A click that places a man must not
## also fire the gun, and the ordinary way this game stops a weapon listening is to
## take [method Node.set_process_unhandled_input] off it - the same call the death
## sequence and the sleep both make. So the weapon is silenced on the way in and
## handed back on the way out, and nothing about how a weapon fires is duplicated or
## special-cased here.
##
## Nothing about the run is touched: the tree is not paused, the clock is not
## stopped, and the camera is put back exactly where it was found.

## Emitted as placement starts, with the label of whatever is being placed.
signal began(label: String)
## Emitted for each thing actually put down.
signal placed(node: Node)
## Emitted when placement ends, however it ended.
signal ended

## Group this joins, so a station can find it without a path across the scene.
const GROUP := &"test_placer"

## Mouse button that puts one down. Left, and taken as a raw button rather than
## through an action, because the fire action is bound to the same button and this
## is deliberately not firing.
@export var place_button: MouseButton = MOUSE_BUTTON_LEFT
## Mouse button that ends placement.
@export var cancel_button: MouseButton = MOUSE_BUTTON_RIGHT
## Key that also ends it, for a player who would rather reach for the keyboard.
@export var cancel_action: StringName = &"pause_menu"
## Whether one selection can be put down over and over. On: the station is chosen
## from once and the map can be filled without reopening it.
@export var repeats: bool = true

@export_group("The view")
## Whether the camera is pulled out while placing, so the whole test map can be
## seen at once.
@export var pulls_the_view_out: bool = true
## What the camera's resting zoom is multiplied by while placing. Below 1 is
## further away; 0.55 shows roughly twice as much map in each direction.
##
## It is a multiplier on whatever the camera was already resting at, applied through
## [method CameraController.set_zoom_multiplier] - the same one call a [WorldZone]
## uses - so every other camera effect goes on riding on top of it untouched, and
## the value found on the way in is what is put back on the way out.
@export var overview_zoom: float = 0.55
## Whether the pull-out is instant. Off eases, which reads better but means the
## first click lands while the view is still moving - harmless, since the point is
## read off the canvas either way.
@export var instant_zoom: bool = false

@export_group("The weapon")
## Whether the weapon stops listening for the trigger while placing, so the click
## that puts a man down cannot also fire.
@export var silences_weapon: bool = true

@export_group("The marker")
## Whether the cursor is drawn at all. Off leaves the mouse cursor to do the job.
@export var draws_marker: bool = true
## Radius of the ring drawn at the point that would be used, in pixels.
@export var marker_radius: float = 46.0
## Length of the cross drawn through it.
@export var marker_cross: float = 78.0
@export var marker_width: float = 3.0
@export var marker_colour := Color(0.95, 0.2, 0.2, 0.9)
## Second, fainter ring, so the marker reads against both the light floor and the
## dark one.
@export var marker_shadow_colour := Color(0.05, 0.02, 0.02, 0.75)

var _builder: Callable
var _label: String = ""
var _placing: bool = false
var _point := Vector2.ZERO
var _restore_zoom: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false)
	set_process_unhandled_input(false)


## The placer the rest of the scene should talk to. Null means this world has none,
## which every caller reads as "there is nowhere to place anything".
static func get_active(from_node: Node) -> TestPlacer:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TestPlacer


func is_placing() -> bool:
	return _placing


## What is being placed right now, for a banner that wants to say so.
func get_label() -> String:
	return _label


## Enters placement mode.
##
## [param builder] is called once per click with the world position that was
## clicked, and whatever it returns is reported through [signal placed]. A builder
## that cannot build simply returns null and the click is spent quietly.
##
## Returns false when placement was already under way or there is nothing to call,
## so a caller can tell the difference between "it started" and "nothing happened".
func begin(builder: Callable, label: String = "") -> bool:
	if _placing or not builder.is_valid():
		return false

	_builder = builder
	_label = label
	_placing = true
	_point = get_global_mouse_position()

	set_process(true)
	set_process_unhandled_input(true)
	_pull_the_view_out()
	_silence_weapon(true)
	queue_redraw()
	began.emit(_label)
	return true


## Leaves placement mode and puts the view and the trigger back. Safe on a placer
## that is not placing, which is what makes it callable from every way the mode can
## end.
func cancel() -> void:
	if not _placing:
		return

	_placing = false
	_builder = Callable()
	_label = ""
	set_process(false)
	set_process_unhandled_input(false)
	_restore_the_view()
	_silence_weapon(false)
	queue_redraw()
	ended.emit()


func _process(_delta: float) -> void:
	var point := get_global_mouse_position()
	if point.is_equal_approx(_point):
		return
	_point = point
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _placing:
		return

	if event.is_action_pressed(cancel_action):
		cancel()
		get_viewport().set_input_as_handled()
		return

	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return

	if click.button_index == cancel_button:
		cancel()
		get_viewport().set_input_as_handled()
		return

	if click.button_index != place_button:
		return

	# The point is taken from the canvas rather than from the event, so a click that
	# arrives on a frame the camera has already moved lands where the marker is
	# drawn rather than where the mouse was when the button went down.
	_place(get_global_mouse_position())
	get_viewport().set_input_as_handled()


## One thing, at [param point]. Kept separate from the click so a caller can place
## something without a mouse at all - a scripted test laying out a formation.
func _place(point: Vector2) -> void:
	if not _builder.is_valid():
		return

	var built: Variant = _builder.call(point)
	var node := built as Node
	if node != null:
		placed.emit(node)

	if not repeats:
		cancel()


func _pull_the_view_out() -> void:
	if not pulls_the_view_out:
		return
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	# Remembered rather than assumed, so leaving hands the camera back to whatever
	# had it - the test map's own zone, a menu that had pulled it in - instead of to
	# a 1.0 written down here.
	_restore_zoom = camera.get_zoom_multiplier()
	camera.set_zoom_multiplier(_restore_zoom * maxf(overview_zoom, 0.05), instant_zoom)


func _restore_the_view() -> void:
	if not pulls_the_view_out:
		return
	var camera := CameraController.get_active(self)
	if camera != null:
		camera.set_zoom_multiplier(_restore_zoom, instant_zoom)


## Asked of the [WeaponMount] rather than held, for the same reason every other
## component that touches the weapon asks: the weapon is built from the player's
## choice and can be replaced while this is up.
func _silence_weapon(silenced: bool) -> void:
	if not silences_weapon:
		return
	var mount := WeaponMount.get_active(self)
	if mount == null:
		return
	var weapon := mount.get_weapon()
	if weapon != null:
		weapon.set_process_unhandled_input(not silenced)


func _draw() -> void:
	if not _placing or not draws_marker:
		return

	var at := to_local(_point)
	var radius := maxf(marker_radius, 1.0)
	var arm := maxf(marker_cross, 0.0) * 0.5
	var width := maxf(marker_width, 1.0)

	draw_arc(at, radius + width, 0.0, TAU, 48, marker_shadow_colour, width * 2.0)
	draw_arc(at, radius, 0.0, TAU, 48, marker_colour, width)
	draw_line(at - Vector2(arm, 0.0), at + Vector2(arm, 0.0), marker_colour, width)
	draw_line(at - Vector2(0.0, arm), at + Vector2(0.0, arm), marker_colour, width)


## Nothing is left half-placed behind us: a world torn down mid-placement would
## otherwise leave the camera pulled out and the trigger silenced in the next one.
func _exit_tree() -> void:
	if _placing:
		_placing = false
		_silence_weapon(false)
