class_name RewardChoiceCard
extends Button
## One card of a reward selection, drawn on the [code]Cards.PNG[/code] stock: dealt
## face down, turned face up, and then lifted, leaned and lit by the mouse like a
## physical card.
##
## [b]It shows a [RewardChoice] and nothing else.[/b] The name, the rarity line and
## the description are the choice's own; every colour - the rarity line, the rim,
## the particles round the edge and the glare - is its [UpgradeRarity]'s. It never
## learns what the card does; a click is reported as [signal chosen].
##
## [b]The face is a picture of itself.[/b] The card's face is laid out in a
## [SubViewport] and drawn through [code]reward_card.gdshader[/code], which is what
## lets lettering and stock tilt together in 3D. The button itself never moves or
## scales - only what is drawn does - so the click area is the resting card and a
## lean can never pull the card out from under the mouse.
##
## It is a flat [Button], so the game's own pointer ([GameCursor]) shows its hover
## art over it; the system pointer is never touched here.

## Clicked while it could be taken.
signal chosen(card: RewardChoiceCard)

## The card's size, in pixels - [code]Cards.PNG[/code]'s proportions.
@export var card_size: Vector2 = Vector2(196.0, 284.0):
	set(value):
		card_size = value
		custom_minimum_size = value
		size = value

@export_group("Hover")
## The largest lean, in degrees, with the mouse at the card's edge.
@export_range(0.0, 45.0, 0.1) var max_tilt_degrees: float = 9.0
## Positive leans the side under the mouse towards the player; negative presses it
## away.
@export_range(-1.0, 1.0, 1.0) var tilt_direction: float = 1.0
## Eye distance for the lean's perspective, in pixels. Smaller is stronger.
@export var perspective: float = 900.0
## How far the card lifts off the table, in pixels.
@export var lift: float = 14.0
## How much bigger it is drawn while lifted.
@export var hover_scale: float = 1.06
## How quickly it eases into and out of the hover - higher is snappier.
@export var hover_response: float = 12.0
## How quickly the lean follows the mouse.
@export var tilt_response: float = 14.0

@export_group("Shadow")
## The shadow's offset at rest and fully lifted, in pixels.
@export var shadow_offset_rest: Vector2 = Vector2(0.0, 6.0)
@export var shadow_offset_lifted: Vector2 = Vector2(0.0, 22.0)
## The shadow's opacity at rest and fully lifted.
@export_range(0.0, 1.0, 0.01) var shadow_alpha_rest: float = 0.45
@export_range(0.0, 1.0, 0.01) var shadow_alpha_lifted: float = 0.3
## How much bigger the shadow spreads when lifted.
@export var shadow_scale_lifted: float = 1.04

@export_group("Glare")
## How strong the rarity-coloured light following the mouse is.
@export_range(0.0, 2.0, 0.01) var glare_strength: float = 0.6
## Its radius, as a fraction of the card's height.
@export_range(0.01, 2.0, 0.01) var glare_size: float = 0.45
## 0 is a hard disc; 1 fades from the very centre.
@export_range(0.0, 1.0, 0.01) var glare_softness: float = 0.85
@export_range(0.0, 1.0, 0.01) var glare_opacity: float = 0.55
## How quickly it follows the mouse - higher sticks closer.
@export var glare_response: float = 10.0
## How far the glare blends from the rarity colour towards white, so a dark
## rarity still reads as light on the stock rather than as neon.
@export_range(0.0, 1.0, 0.01) var glare_whiten: float = 0.45

@export_group("Particles")
## Multiplies every rarity's particle amount, size, spread, speed and intensity -
## one dial for the whole selection.
@export var particle_amount_scale: float = 1.0
@export var particle_size_scale: float = 1.0
@export var particle_spread_scale: float = 1.0
@export var particle_speed_scale: float = 1.0
@export var particle_intensity_scale: float = 1.0
## How many points round the edge the particles start from.
@export_range(8, 256) var edge_points: int = 64

@export_group("Text Fit")
## The description is drawn at its scene font size and stepped down to this, a
## point at a time, until the whole lettering fits the card's text area - so a
## long Legendary never runs off the stock.
@export_range(6, 32) var description_min_font_size: int = 8
## The container holding the rarity line, name and description.
@export var text_box_path: NodePath = ^"Viewport/Face/Text"

@export_group("Reveal")
## How far the rim flares as the card turns face up, and how fast it settles.
@export var flare_time: float = 0.45

@export_group("Wiring")
@export var shadow_path: NodePath = ^"Shadow"
@export var pivot_path: NodePath = ^"Pivot"
@export var flipper_path: NodePath = ^"Pivot/Flipper"
@export var rim_path: NodePath = ^"Pivot/Flipper/Rim"
@export var particles_path: NodePath = ^"Pivot/Flipper/Particles"
@export var display_path: NodePath = ^"Pivot/Flipper/Display"
@export var viewport_path: NodePath = ^"Viewport"
@export var face_path: NodePath = ^"Viewport/Face"
@export var back_path: NodePath = ^"Viewport/Back"
@export var rarity_label_path: NodePath = ^"Viewport/Face/Text/Rarity"
@export var title_label_path: NodePath = ^"Viewport/Face/Text/Title"
@export var description_label_path: NodePath = ^"Viewport/Face/Text/Description"
@export var art_path: NodePath = ^"Viewport/Face/ArtWindow/Art"
@export var art_tint_path: NodePath = ^"Viewport/Face/ArtWindow"

@onready var _shadow: Control = get_node_or_null(shadow_path) as Control
@onready var _pivot: Control = get_node_or_null(pivot_path) as Control
@onready var _flipper: Control = get_node_or_null(flipper_path) as Control
@onready var _rim: Panel = get_node_or_null(rim_path) as Panel
@onready var _particles: CPUParticles2D = get_node_or_null(particles_path) as CPUParticles2D
@onready var _display: TextureRect = get_node_or_null(display_path) as TextureRect
@onready var _viewport: SubViewport = get_node_or_null(viewport_path) as SubViewport
@onready var _face: Control = get_node_or_null(face_path) as Control
@onready var _back: Control = get_node_or_null(back_path) as Control
@onready var _rarity_label: Label = get_node_or_null(rarity_label_path) as Label
@onready var _title_label: Label = get_node_or_null(title_label_path) as Label
@onready var _description_label: Label = get_node_or_null(description_label_path) as Label
@onready var _art: TextureRect = get_node_or_null(art_path) as TextureRect
@onready var _art_tint: CanvasItem = get_node_or_null(art_tint_path) as CanvasItem

var _choice: RewardChoice
var _face_up: bool = false
var _selectable: bool = false
var _hovered: bool = false
## Where the pointer last was, in the card's canvas - see [method _input].
var _pointer: Vector2 = Vector2.ZERO
var _pointer_known: bool = false
## 0 resting .. 1 fully lifted.
var _hover: float = 0.0
var _tilt: Vector2 = Vector2.ZERO
var _glare_pos: Vector2 = Vector2(0.5, 0.5)
var _material: ShaderMaterial
var _rim_style: StyleBoxFlat
var _rim_level: float = 0.0
## Extra vertical offset while the card is being dealt in, in pixels.
var enter_offset: float = 0.0:
	set(value):
		enter_offset = value
		_place_pivot()
## Extra scale on top of the hover, for the selection's emphasis.
var emphasis: float = 1.0


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = card_size
	size = card_size
	pressed.connect(_on_pressed)
	_quiet_children(self)
	if _viewport != null:
		_viewport.size = Vector2i(card_size)
		_viewport.transparent_bg = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _display != null:
		_display.texture = _viewport.get_texture() if _viewport != null else null
		var source := _display.material as ShaderMaterial
		_material = source.duplicate() as ShaderMaterial if source != null else null
		_display.material = _material
	for control: Control in [_pivot, _flipper, _display, _rim, _shadow]:
		if control != null:
			control.size = card_size
			control.pivot_offset = card_size * 0.5
	if _rim != null:
		var style := _rim.get_theme_stylebox(&"panel") as StyleBoxFlat
		_rim_style = style.duplicate() as StyleBoxFlat if style != null else StyleBoxFlat.new()
		_rim.add_theme_stylebox_override(&"panel", _rim_style)
	if _particles != null:
		_particles.position = card_size * 0.5
		_particles.emitting = false
	set_face_up(false)
	_set_selectable(false)
	_apply_visuals(0.0)


func get_choice() -> RewardChoice:
	return _choice


func is_face_up() -> bool:
	return _face_up


## Whether it can be clicked to be taken.
func is_selectable() -> bool:
	return _selectable


## Shows [param choice]. The card stays face down until [method set_face_up].
func bind(choice: RewardChoice) -> void:
	_choice = choice
	if choice == null:
		return
	var color := choice.get_color()
	_set_text(_rarity_label, choice.get_rarity_name())
	_set_text(_title_label, choice.get_title())
	_set_text(_description_label, choice.get_description())
	# Fitted once the face has been laid out.
	_fit_text.call_deferred()
	if _rarity_label != null:
		_rarity_label.add_theme_color_override(&"font_color", color)
	if _art != null:
		_art.texture = choice.get_art()
		_art.visible = _art.texture != null
	if _art_tint != null:
		var tint := color
		tint.a = (_art_tint as CanvasItem).self_modulate.a
		_art_tint.self_modulate = tint
	if _material != null:
		_material.set_shader_parameter(&"glare_color", color.lerp(Color.WHITE, glare_whiten))
	if _rim_style != null:
		_rim_style.shadow_color = Color(color, 0.0)
		_rim_style.shadow_size = int(choice.rarity.rim_size) if choice.rarity != null else 8
	_configure_particles()


## Turns the card face up or down at once. The flip's turn itself is the screen's,
## which calls this at the edge-on moment.
func set_face_up(up: bool) -> void:
	_face_up = up
	if _face != null:
		_face.visible = up
	if _back != null:
		_back.visible = not up
	if _particles != null:
		_particles.emitting = up and _particles.amount > 0 and _choice != null


## The rarity feedback the moment the card is readable: the rim flares and settles
## to its resting glow, and the particles start round the edge.
func play_rarity_feedback() -> void:
	if _choice == null or _choice.rarity == null:
		return
	var rarity := _choice.rarity
	var rest := rarity.rim_intensity
	_rim_level = rest + rarity.reveal_flare
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _rim_level = v, _rim_level, rest,
		maxf(flare_time, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _particles != null:
		_particles.restart()
		_particles.emitting = _particles.amount > 0


## Whether the card takes clicks now. Off while the selection is being dealt and
## once a card has been taken.
func set_selectable(on: bool) -> void:
	_set_selectable(on)


func _set_selectable(on: bool) -> void:
	_selectable = on
	disabled = not on


func _on_pressed() -> void:
	if _selectable and _face_up:
		chosen.emit(self)


## The pointer is followed from the same mouse events a click is picked by, so
## the card leans exactly where it would be clicked.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = get_canvas_transform().affine_inverse() * (event as InputEventMouse).position
		_pointer_known = true


func _process(delta: float) -> void:
	# The resting rect, not a mouse_entered flag: the button itself never moves, so
	# this is exactly where a click lands.
	var pointer := _pointer if _pointer_known else get_global_mouse_position()
	_hovered = is_visible_in_tree() and get_global_rect().has_point(pointer)
	var lifting := _hovered and _face_up and _selectable
	var target_hover := 1.0 if lifting else 0.0
	_hover = lerpf(_hover, target_hover, 1.0 - exp(-hover_response * delta))
	var target_tilt := Vector2.ZERO
	if lifting:
		var local := get_global_transform().affine_inverse() * pointer
		var n := (local / card_size).clamp(Vector2.ZERO, Vector2.ONE)
		_glare_pos = _glare_pos.lerp(n, 1.0 - exp(-glare_response * delta))
		var centred := n * 2.0 - Vector2.ONE
		var max_tilt := deg_to_rad(max_tilt_degrees) * tilt_direction
		# Turning about the vertical axis follows the mouse across; about the
		# horizontal axis, up and down.
		target_tilt = Vector2(-centred.x, -centred.y) * max_tilt
	_tilt = _tilt.lerp(target_tilt, 1.0 - exp(-tilt_response * delta))
	_apply_visuals(_hover)


func _apply_visuals(amount: float) -> void:
	_place_pivot()
	if _pivot != null:
		_pivot.scale = Vector2.ONE * lerpf(1.0, hover_scale, amount) * emphasis
	if _shadow != null:
		_shadow.position = shadow_offset_rest.lerp(shadow_offset_lifted, amount)
		_shadow.scale = Vector2.ONE * lerpf(1.0, shadow_scale_lifted, amount) * emphasis
		_shadow.modulate.a = lerpf(shadow_alpha_rest, shadow_alpha_lifted, amount)
	if _material != null:
		_material.set_shader_parameter(&"rect_size", card_size)
		_material.set_shader_parameter(&"tilt", _tilt)
		_material.set_shader_parameter(&"perspective", perspective)
		_material.set_shader_parameter(&"glare_pos", _glare_pos)
		_material.set_shader_parameter(&"glare_amount", amount)
		_material.set_shader_parameter(&"glare_strength", glare_strength)
		_material.set_shader_parameter(&"glare_size", glare_size)
		_material.set_shader_parameter(&"glare_softness", glare_softness)
		_material.set_shader_parameter(&"glare_opacity", glare_opacity)
	if _rim_style != null and _choice != null:
		var shown := _rim_level if _face_up else 0.0
		_rim_style.shadow_color = Color(_choice.get_color(), clampf(shown, 0.0, 1.0))


func _place_pivot() -> void:
	if _pivot != null:
		_pivot.position = Vector2(0.0, -lift * _hover + enter_offset)


## Lays the particles round the card's edge in the rarity's numbers. They sit
## behind the card's face, so they never cover its lettering.
func _configure_particles() -> void:
	if _particles == null or _choice == null or _choice.rarity == null:
		return
	var rarity := _choice.rarity
	var spread := rarity.particle_spread * particle_spread_scale
	var half := card_size * 0.5 + Vector2(spread, spread)
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	var perimeter := 4.0 * (half.x + half.y)
	for i: int in edge_points:
		var d := perimeter * float(i) / float(edge_points)
		var p: Vector2
		var n: Vector2
		if d < 2.0 * half.x:
			p = Vector2(-half.x + d, -half.y)
			n = Vector2.UP
		elif d < 2.0 * half.x + 2.0 * half.y:
			p = Vector2(half.x, -half.y + d - 2.0 * half.x)
			n = Vector2.RIGHT
		elif d < 4.0 * half.x + 2.0 * half.y:
			p = Vector2(half.x - (d - 2.0 * half.x - 2.0 * half.y), half.y)
			n = Vector2.DOWN
		else:
			p = Vector2(-half.x, half.y - (d - 4.0 * half.x - 2.0 * half.y))
			n = Vector2.LEFT
		points.append(p)
		normals.append(n)
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	_particles.emission_points = points
	_particles.emission_normals = normals
	_particles.amount = maxi(roundi(rarity.particle_amount * particle_amount_scale), 1)
	_particles.lifetime = maxf(rarity.particle_lifetime, 0.05)
	_particles.gravity = Vector2.ZERO
	_particles.spread = 25.0
	var speed := rarity.particle_speed * particle_speed_scale
	_particles.initial_velocity_min = speed * 0.5
	_particles.initial_velocity_max = speed
	if _particles.texture == null:
		_particles.texture = _dot_texture()
	var dot := float(_particles.texture.get_width())
	var scale_px := rarity.particle_size * particle_size_scale
	_particles.scale_amount_min = scale_px * 0.6 / dot
	_particles.scale_amount_max = scale_px / dot
	var intensity := clampf(rarity.particle_intensity * particle_intensity_scale, 0.0, 1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(rarity.color, intensity))
	ramp.set_color(1, Color(rarity.color, 0.0))
	_particles.color_ramp = ramp
	_particles.visible = _particles.amount > 0 and intensity > 0.0


static func _dot_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	return texture


## The height the lettering may take: the text box's anchored area on the face,
## not its current size - a container grows to whatever it holds.
func get_text_room() -> float:
	var box := get_node_or_null(text_box_path) as Control
	var parent := box.get_parent() as Control if box != null else null
	if box == null or parent == null:
		return 0.0
	return (box.anchor_bottom - box.anchor_top) * parent.size.y + box.offset_bottom - box.offset_top


## Whether the lettering fits [method get_text_room].
func text_fits() -> bool:
	return lettering_height() <= get_text_room() + 0.5


## The height the rarity line, the name and the description take at the box's
## width, with the description at [param description_size] (its current size when
## negative). Measured with each label's own font, so it holds before the box has
## laid its children out.
func lettering_height(description_size: int = -1) -> float:
	var box := get_node_or_null(text_box_path) as Control
	var parent := box.get_parent() as Control if box != null else null
	if box == null or parent == null:
		return 0.0
	var width := (box.anchor_right - box.anchor_left) * parent.size.x + box.offset_right - box.offset_left
	var total := 0.0
	var shown := 0
	for label: Label in [_rarity_label, _title_label, _description_label]:
		if label == null or not label.visible or label.text.is_empty():
			continue
		var font_size := label.get_theme_font_size(&"font_size")
		if label == _description_label and description_size > 0:
			font_size = description_size
		var font := label.get_theme_font(&"font")
		total += font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER,
			width, font_size).y
		shown += 1
	return total + box.get_theme_constant(&"separation") * maxi(shown - 1, 0)


## Steps the description's font down until the lettering fits its room.
func _fit_text() -> void:
	var room := get_text_room()
	if _description_label == null or room <= 0.0:
		return
	if not _description_label.has_theme_font_size_override(&"font_size"):
		return
	if not has_meta(&"description_font_size"):
		set_meta(&"description_font_size",
			_description_label.get_theme_font_size(&"font_size"))
	var font_size: int = get_meta(&"description_font_size")
	while font_size > description_min_font_size and lettering_height(font_size) > room:
		font_size -= 1
	_description_label.add_theme_font_size_override(&"font_size", font_size)


func _set_text(label: Label, value: String) -> void:
	if label == null:
		return
	label.text = value
	label.visible = not value.is_empty()


## Everything drawn on the card is only to be looked at - the button alone takes
## the mouse.
static func _quiet_children(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quiet_children(child)
