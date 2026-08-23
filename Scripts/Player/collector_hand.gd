class_name CollectorHand
extends Node2D
## The clawed hand, and the cone it can be drawn reaching into.
##
## [b]Nothing drives this node.[/b] Blood is no longer collected by hand - it
## comes to the player on its own through [BloodMagnet] - so the hand is held
## here, hidden and inert, as the weapon it is about to become. It is kept whole
## rather than deleted because the artwork, the pose controls and the reaction to
## blood are the parts a future off-hand weapon will want, and rebuilding them
## would be rebuilding work that already exists.
##
## To put it back in play, something has to position it, rotate it, show it, and
## feed it [method set_collecting] and [method set_cone]. Until then it never
## appears: it is authored hidden and nothing in the player switches it on.
##
## The hand itself is the [Sprite2D] child carrying the Guns/Hand artwork. This
## script never draws it - it only tints it - so the art can be repositioned,
## rescaled or swapped in the inspector without touching code.
##
## [member draw_hand] keeps the older generated hand available as a fallback for
## when there is no sprite to point at. It is off by default.
##
## The hand is drawn and aimed along +X, so whatever rotates this node aims the
## artwork, the cone and the reach together without any of them knowing the
## angle.
##
## This is pure decoration. It has no shape, no area and no physics.

## The hand artwork. Tinted while blood is coming in; otherwise left alone.
@export var sprite_path: NodePath = ^"Sprite"
## Falls back to the generated hand. Only useful when there is no sprite.
@export var draw_hand: bool = false
## Draws a reach cone in front of the hand, sized by [method set_cone]. Off by
## default, and nothing decides anything by it - it is a drawing waiting for a
## weapon that wants one.
@export var draw_cone: bool = false

@export_group("Artwork")
## Turn given to the hand *sprite* so the claw lines up with +X, which is the
## direction the whole node is aimed along.
##
## Only the sprite is ever rotated. The [code]Art[/code] pivot above it has to
## stay at zero rotation for [HeldItemFlip] to mirror on the aim axis rather than
## on some angle of its own, which is why this lives here and not on that node.
@export var sprite_rotation_degrees: float = -120.0:
	set(value):
		sprite_rotation_degrees = value
		_apply_artwork()
## Where the wrist sits in the artwork, in texture pixels, negated. The sprite is
## drawn uncentred, so this is what puts the wrist on the pivot and keeps the
## hand attached to the arm however the rest of the artwork is retuned.
@export var sprite_offset := Vector2(-208.0, -633.0):
	set(value):
		sprite_offset = value
		_apply_artwork()
## Size the artwork is drawn at.
@export var sprite_scale: float = 0.09:
	set(value):
		sprite_scale = value
		_apply_artwork()
## Mirrors the claw across its own length, which is what turns the palm over.
##
## The artwork is drawn palm-up. Blood is pulled off the *floor*, so the palm has
## to be the side facing down and the fingers have to lead into it - and a mirror
## is the only way to change which face of a hand is showing. A half turn would
## show the same palm and point the fingers back at the player instead.
##
## Because the mirror happens in the sprite's own space, before its rotation, it
## is [member sprite_rotation_degrees] that decides where the fingers end up
## pointing afterwards - the two are set together.
@export var sprite_palm_down: bool = true:
	set(value):
		sprite_palm_down = value
		_apply_artwork()

@export_group("Blood reaction")
## Colour the artwork is tinted towards while blood is being drawn in. Above 1 on
## a channel brightens rather than tints, which is what makes the claw look lit
## by the blood instead of painted over.
@export var glow_tint := Color(1.45, 0.72, 0.74)
## Ceiling on that tint, so the reaction stays a flicker of life rather than a
## red floodlight. Lower is subtler.
@export_range(0.0, 1.0) var glow_strength: float = 0.5
## Pulses per second while collecting.
@export var glow_pulse_speed: float = 5.5
## How much of the pulse is a steady glow rather than the oscillation. 0 pulses
## all the way down to untinted between beats; 1 is a constant tint.
@export_range(0.0, 1.0) var glow_floor: float = 0.35
## How quickly the reaction fades in and out as blood starts and stops arriving,
## so it breathes rather than snapping on.
@export var glow_blend_speed: float = 6.0

@export_group("Halo")
## Soft halo behind the hand while collecting, sold as a few stacked translucent
## circles rather than a light, so it costs nothing and needs no texture.
@export var halo_colour := Color(0.75, 0.09, 0.11, 0.22)
@export var halo_radius: float = 22.0
@export var halo_layers: int = 4

@export_group("Generated hand")
## Only used when [member draw_hand] is on.
@export var palm_radius: float = 7.0
@export var finger_count: int = 4
@export var finger_length: float = 9.0
@export var finger_spread_degrees: float = 96.0
@export var finger_width: float = 2.2
@export var hand_colour := Color(0.86, 0.78, 0.72, 0.95)

@export_group("Cone")
@export var cone_fill_colour := Color(0.8, 0.1, 0.12, 0.045)
@export var cone_edge_colour := Color(0.85, 0.15, 0.16, 0.12)
## Segments the cone's far arc is drawn with. Only affects how round it looks.
@export var cone_segments: int = 20

@onready var _sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D

var _cone_half_angle: float = 0.6
var _cone_range: float = 240.0
var _collecting: bool = false
var _intensity: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	# Whatever drives the hand will position it every frame, so interpolating it
	# from its previous physics transform would only ever lag it behind.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply_artwork()
	_apply_tint()


## Writes the exported pose onto the sprite. Called from every setter as well as
## from ready, so the hand can be turned the right way up in the inspector with
## the game running rather than by guessing at numbers and restarting.
##
## Nothing else here writes to the sprite's transform, and [HeldItemFlip] only
## ever touches the pivot above it, so this is the single place the artwork's
## orientation is decided.
func _apply_artwork() -> void:
	if _sprite == null:
		return
	_sprite.rotation = deg_to_rad(sprite_rotation_degrees)
	_sprite.offset = sprite_offset
	var palm := -1.0 if sprite_palm_down else 1.0
	_sprite.scale = Vector2(sprite_scale, sprite_scale * palm)


## Told to the hand rather than read from anywhere, so the drawing has no opinion
## about where the numbers come from and the two stay independent.
func set_cone(half_angle_radians: float, cone_range: float) -> void:
	if is_equal_approx(half_angle_radians, _cone_half_angle) \
			and is_equal_approx(cone_range, _cone_range):
		return
	_cone_half_angle = half_angle_radians
	_cone_range = cone_range
	queue_redraw()


## Whether blood is actually arriving right now. The reaction eases towards this
## rather than following it exactly, so a gap between specks does not make the
## hand stutter.
func set_collecting(collecting: bool) -> void:
	_collecting = collecting


func _process(delta: float) -> void:
	if not visible:
		return

	var goal := 1.0 if _collecting else 0.0
	var previous := _intensity
	_intensity = lerpf(_intensity, goal, 1.0 - exp(-glow_blend_speed * delta))
	if _collecting or _intensity > 0.001:
		_pulse += delta * glow_pulse_speed
		_apply_tint()
		queue_redraw()
	elif previous > 0.001:
		# One last pass to land exactly on untinted, so a hand that stops
		# collecting cannot be left holding a sliver of glow.
		_intensity = 0.0
		_apply_tint()
		queue_redraw()


## Blends between a steady glow and a pulsing one, so the beat never fully
## disappears and never fully takes over.
func _glow_amount() -> float:
	var beat := 0.5 + 0.5 * sin(_pulse)
	return _intensity * glow_strength * lerpf(beat, 1.0, glow_floor)


func _apply_tint() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color.WHITE.lerp(glow_tint, _glow_amount())


func _draw() -> void:
	if draw_cone:
		_draw_cone()
	if _intensity > 0.001:
		_draw_halo()
	if draw_hand:
		_draw_palm()


## A fan from the origin out to the far arc. Drawn first so the hand sits on top.
func _draw_cone() -> void:
	var segments := maxi(cone_segments, 3)
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i: int in segments + 1:
		var angle := lerpf(-_cone_half_angle, _cone_half_angle, float(i) / float(segments))
		points.append(Vector2(_cone_range, 0.0).rotated(angle))

	draw_colored_polygon(points, cone_fill_colour)
	# Closed back through the origin, so both straight edges are outlined too.
	points.append(Vector2.ZERO)
	draw_polyline(points, cone_edge_colour, 1.0, true)


## Stacked translucent circles, largest and faintest first. Overlapping alpha is
## what fakes the falloff - no texture and no light involved. Scaled by the same
## intensity as the tint, so it appears only while blood is coming in.
func _draw_halo() -> void:
	var layers := maxi(halo_layers, 1)
	var colour := halo_colour
	colour.a *= _intensity
	for i: int in layers:
		var fraction := 1.0 - float(i) / float(layers)
		draw_circle(Vector2.ZERO, halo_radius * fraction, colour)


func _draw_palm() -> void:
	draw_circle(Vector2.ZERO, palm_radius, hand_colour)

	var fingers := maxi(finger_count, 0)
	if fingers <= 0:
		return

	var spread := deg_to_rad(finger_spread_degrees)
	for i: int in fingers:
		# A single finger points straight ahead rather than dividing by zero.
		var t := 0.5 if fingers == 1 else float(i) / float(fingers - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(
			direction * palm_radius * 0.7,
			direction * (palm_radius + finger_length),
			hand_colour,
			finger_width,
			true)
