class_name Crosshair
extends Control
## The sight the player aims with: four pieces of one drawing, arranged around the
## cursor, opening and closing with how far out the player is aiming.
##
## It is a control on a [CanvasLayer] rather than a custom hardware cursor
## ([method Input.set_custom_mouse_cursor]) for two reasons: a hardware cursor is
## capped at a small size and is not scaled, and it is drawn by the window rather
## than by the game, so it would sit outside the game's own look. Drawing it
## ourselves also means its size, its colour and its spread are inspector values.
##
## [b]Centring.[/b] The one thing that must be exactly right is that the middle of
## the sight sits on the mouse, at any window size. The project stretches its
## canvas ([code]canvas_items[/code], expand), so a control's coordinates and the
## viewport's mouse position are already in the same stretched space - which makes
## the whole of the centring one assignment, with no resolution anywhere in it.
##
## [b]Which sight is shown is not decided here.[/b] The styles are an array of
## [CrosshairStyle] resources, each carrying a weapon id, and the one whose id
## matches the weapon [WeaponMount] built is the one drawn. No weapon is named in
## this script: a fourth weapon's sight is a resource dropped into the array.
##
## [b]Three things move it.[/b] The spread, which is the distance from the player
## to the cursor read through the style's own curve; the flash, a blown-out kick as
## the weapon fires; and the charge, which crosses the whole sight from the style's
## normal colour to its charged one. The charge is asked for by method from
## whatever is in the [code]weapon_charge[/code] group, so a weapon that has no
## charge simply never turns red and nothing here knows which weapon does.

## The eight directions a black copy of a piece is thrown in to outline it. Eight
## rather than four so a one-pixel outline has no gaps at its corners, and a fixed
## ring rather than a shader because the pieces are ordinary [TextureRect]s and a
## shader would have nowhere outside them to draw.
const OUTLINE_DIRECTIONS: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.7071, 0.7071),
	Vector2(0.0, 1.0),
	Vector2(-0.7071, 0.7071),
	Vector2(-1.0, 0.0),
	Vector2(-0.7071, -0.7071),
	Vector2(0.0, -1.0),
	Vector2(0.7071, -0.7071),
]

## Sights this crosshair can draw, one per weapon. Matched by
## [member CrosshairStyle.weapon_id] against whatever the mount built.
@export var styles: Array[CrosshairStyle] = []
## Style used when the weapon in the player's hands matches none of the above -
## and when there is no mount at all, which is what a scene run on its own has.
## Left empty the sight is simply not drawn.
@export var fallback_style: CrosshairStyle
## Whether the sight is drawn at all. Turned off by [GameCursor] while a menu owns
## the screen, so the pointer and the sight are never both up.
@export var crosshair_visible: bool = true:
	set(value):
		crosshair_visible = value
		if is_node_ready():
			visible = crosshair_visible

@export_group("Nodes")
## The mount the equipped weapon is read from. Left unresolved it is found by
## group, so this needs no path across the scene.
@export var mount_path: NodePath
## Group the player is found in, so the spread has something to measure from.
@export var player_group: StringName = &"player"
## Group a weapon's charge is found in. Anything in it answering
## [code]get_charge_ratio()[/code] drives the colour; nothing in it means no
## weapon in this game has a charge, and the sight stays its normal colour.
@export var charge_group: StringName = &"weapon_charge"

var _style: CrosshairStyle
var _pieces: Array[TextureRect] = []
## The black copies behind them, [constant OUTLINE_DIRECTIONS] per arm, laid out
## arm by arm so the copy for arm [code]a[/code] in direction [code]d[/code] is at
## [code]a * OUTLINE_DIRECTIONS.size() + d[/code].
var _outlines: Array[TextureRect] = []
var _spacing: float = 0.0
var _charge: float = 0.0
var _flash: float = 0.0
## 0 to 1: how far towards [member CrosshairStyle.ready_colour] the sight is
## currently blended, from [member CrosshairStyle.not_ready_colour] - see
## [method _advance_readiness]. Started at 1 rather than 0, so a weapon that
## is in fact ready the instant it is drawn does not read yellow for the first
## fraction of a second before its own state has been asked.
var _readiness: float = 1.0
var _mount: WeaponMount
var _weapon: CarriedWeapon


func _ready() -> void:
	# It must never eat a click: the buttons underneath it are what the mouse is
	# actually pointing at.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = crosshair_visible

	_mount = get_node_or_null(mount_path) as WeaponMount
	if _mount == null:
		_mount = WeaponMount.get_active(self)
	if _mount != null:
		_mount.weapon_built.connect(_on_weapon_built)
		_on_weapon_built(_mount.get_weapon())
	else:
		_use_style(fallback_style)


## Followed every frame rather than on mouse-motion events, so the sight keeps up
## with the pointer while the game is paused and while a menu has the input.
func _process(delta: float) -> void:
	global_position = get_viewport().get_mouse_position()
	if _style == null:
		return

	_advance_spacing(delta)
	_advance_charge(delta)
	_advance_readiness(delta)
	_advance_flash(delta)
	_place_pieces()


## Blown out for a moment in whatever colour the sight is currently wearing, so a
## charged shot flashes red and an ordinary one yellow without either being
## written down twice.
func flash() -> void:
	if _style == null:
		return
	_flash = 1.0


## What the sight is showing, for a test or a readout: 0 is the style's normal
## colour, 1 its charged one.
func get_charge_ratio() -> float:
	return _charge


## The style currently being drawn, or null when the sight is not drawn at all.
## What anything hanging off the sight - the ammunition beside it - reads its own
## placement from, so that placement stays a per-weapon resource value.
func get_style() -> CrosshairStyle:
	return _style


## The weapon the sight was built for, or null when there is none.
func get_weapon() -> CarriedWeapon:
	return _weapon if is_instance_valid(_weapon) else null


## Builds the four pieces for [param style] and throws away whatever was there.
##
## Rebuilt rather than retinted because the piece itself changes with the weapon -
## a bullet is not a corner - and four nodes is cheap enough that a weapon swap can
## simply start again.
func _use_style(style: CrosshairStyle) -> void:
	for piece: TextureRect in _pieces + _outlines:
		if is_instance_valid(piece):
			piece.queue_free()
	_pieces.clear()
	_outlines.clear()

	_style = style
	_charge = 0.0
	_flash = 0.0
	# Ready rather than not, so a newly-drawn weapon that is in fact ready does
	# not flash yellow for the first fraction of a second before its own state
	# has been asked - see [member _readiness].
	_readiness = 1.0
	if _style == null:
		return

	_spacing = _style.closed_spacing
	# Every outline copy is built before every coloured piece, so the whole ring of
	# dark sits behind the whole sight - children are drawn in the order they were
	# added, and an outline for one arm must not land on top of the arm beside it.
	if _style.outline_thickness > 0.0 and _style.outline_colour.a > 0.0:
		for arm: int in 4:
			for _direction: Vector2 in OUTLINE_DIRECTIONS:
				_outlines.append(_build_piece(arm))
	for arm: int in 4:
		_pieces.append(_build_piece(arm))

	_place_pieces()


## One copy of the style's drawing, squared up and turned for [param arm].
func _build_piece(arm: int) -> TextureRect:
	var piece := TextureRect.new()
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	piece.texture = _style.piece_texture
	piece.size = _style.piece_size
	piece.pivot_offset = _style.piece_size * 0.5
	# The quarter turn per arm is what makes one drawing into four, and the style's
	# own offset squares the drawing up first - so the source art is never rotated by
	# anything but a right angle and never distorted.
	if _style.rotate_with_arm:
		piece.rotation = deg_to_rad(_style.piece_rotation_offset_degrees + arm * 90.0)
	else:
		piece.rotation = deg_to_rad(_style.piece_rotation_offset_degrees)
	add_child(piece)
	return piece


## Which way each arm points, in the order the pieces were built. The diagonal set
## is the same four directions turned an eighth of a turn, so a bracket drawn as a
## corner lands on the corners.
func _arm_direction(arm: int) -> Vector2:
	var turn := arm * TAU * 0.25
	if _style != null and _style.diagonal:
		turn += TAU * 0.125
	# Arm 0 points up, which is the way every supplied piece is drawn.
	return Vector2.UP.rotated(turn)


## Slides the spread towards where the cursor's distance from the player says it
## belongs. Eased rather than assigned, so the sight opens as a movement rather
## than tracking the mouse pixel for pixel.
func _advance_spacing(delta: float) -> void:
	var wanted := _style.closed_spacing
	var player := _get_player()
	if player != null and _style.spread_distance > 0.0:
		var reach := player.get_global_mouse_position().distance_to(player.global_position)
		var ratio := clampf(reach / _style.spread_distance, 0.0, 1.0)
		wanted = lerpf(
			_style.closed_spacing,
			_style.open_spacing,
			pow(ratio, maxf(_style.spread_curve, 0.01)))

	_spacing = lerpf(_spacing, wanted, 1.0 - exp(-maxf(_style.spread_speed, 0.01) * delta))


## Crosses the sight towards whatever the weapon's charge says. The charge is
## asked for rather than pushed in, so a weapon that has none needs no wiring at
## all and this simply reads 0 forever.
func _advance_charge(delta: float) -> void:
	var wanted := 0.0
	var source := get_tree().get_first_node_in_group(charge_group)
	if source != null and source.has_method(&"get_charge_ratio"):
		wanted = clampf(source.call(&"get_charge_ratio") as float, 0.0, 1.0)

	_charge = lerpf(
		_charge, wanted, 1.0 - exp(-maxf(_style.charge_fade_speed, 0.01) * delta))


## Slides towards [member CrosshairStyle.ready_colour] while the weapon in
## hand could actually fire right now, and towards
## [member CrosshairStyle.not_ready_colour] while it could not - read straight
## off [method CarriedWeapon.is_ready_to_fire], never off whether the fire key
## was pressed, so a shotgun mid-pump reads yellow for exactly as long as it
## is genuinely unable to fire and not a moment longer or shorter.
func _advance_readiness(delta: float) -> void:
	var ready := true
	if _weapon != null and is_instance_valid(_weapon):
		ready = _weapon.is_ready_to_fire()
	var wanted := 1.0 if ready else 0.0
	_readiness = lerpf(
		_readiness, wanted, 1.0 - exp(-maxf(_style.readiness_fade_speed, 0.01) * delta))


func _advance_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(_flash - delta / maxf(_style.flash_time, 0.0001), 0.0)


## Puts the four pieces where the spread, the flash and the charge between them
## say they belong. One place writes position and colour, so the three can never
## drift out of step.
func _place_pieces() -> void:
	var ready_tint := _style.not_ready_colour.lerp(_style.ready_colour, _readiness)
	var tint := ready_tint.lerp(_style.charged_colour, _charge)
	if _flash > 0.0:
		tint = tint * lerpf(1.0, maxf(_style.flash_gain, 1.0), _flash)
		tint.a = 1.0

	var spacing := _spacing + _style.flash_kick * _flash
	var ring := OUTLINE_DIRECTIONS.size()
	for arm: int in _pieces.size():
		var piece := _pieces[arm]
		var base := _arm_direction(arm) * spacing - _style.piece_size * 0.5
		piece.self_modulate = tint
		piece.position = base

		# The outline follows the arm rather than being drawn once: the pieces move
		# apart with the spread and flash outwards as the weapon fires, and a hairline
		# left behind would be a second sight sitting where the first one was.
		for i: int in ring:
			var index := arm * ring + i
			if index >= _outlines.size():
				break
			var copy := _outlines[index]
			copy.self_modulate = _style.outline_colour
			copy.position = base + OUTLINE_DIRECTIONS[i] * _style.outline_thickness


## Rebuilds the sight for whatever the mount just made, and starts listening for
## that weapon's shots so the flash follows the weapon rather than being wired to
## one of them.
func _on_weapon_built(weapon: CarriedWeapon) -> void:
	if _weapon != null and is_instance_valid(_weapon) and _weapon.has_signal(&"fired"):
		if _weapon.is_connected(&"fired", flash):
			_weapon.disconnect(&"fired", flash)

	_weapon = weapon
	if _weapon != null and _weapon.has_signal(&"fired"):
		_weapon.connect(&"fired", flash)

	_use_style(_style_for(_weapon_id()))


func _weapon_id() -> StringName:
	if _mount == null:
		return &""
	var definition := _mount.get_definition()
	return definition.weapon_id if definition != null else &""


func _style_for(weapon_id: StringName) -> CrosshairStyle:
	for style: CrosshairStyle in styles:
		if style != null and style.weapon_id == weapon_id:
			return style
	return fallback_style


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D
