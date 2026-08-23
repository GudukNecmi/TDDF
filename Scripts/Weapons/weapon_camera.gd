class_name WeaponCamera
extends Node
## How the weapon in the player's hands frames the world.
##
## [b]One component, two dials, no weapon named anywhere.[/b] A rifle wants to see
## further the way it is pointed; a shotgun wants the world closer in. Both are
## this node with different numbers in the inspector, dropped into the weapon's own
## scene - so the framing travels with the weapon, a weapon that wants neither
## simply does not have one, and a fourth weapon's view is an inspector value
## rather than a branch in the camera.
##
## [b]The lean is an offset, never a free camera.[/b] The camera goes on following
## the player exactly as it always did; this adds a shift towards where the player
## is looking on top of that, and the shift is a fraction of what the camera can
## already see rather than a number of pixels - see [member offset_fraction]. It is
## therefore the same *proportion* of extra view at any zoom and any window size,
## and a boss arena that pulls the view out does not quietly turn a gentle lean into
## a lurch.
##
## [b]It is the quietest thing touching the camera.[/b] Both dials are written into
## [CameraController]'s weapon layer, which is eased to nothing whenever something
## louder owns the view - a finale, a boss, a coin in flight - and eased back
## afterwards. Nothing here checks for any of that: the camera silences the layer
## and hands it back, so the weapon's framing resumes by itself.
##
## The layer is put back to nothing as the weapon leaves the tree, so a weapon
## swapped out mid-lean can never leave the camera leaning.

@export_group("Lean")
## How far the camera leans at the very edge of the screen, as a fraction of the
## distance from the middle of the view to that edge.
##
## 0.2 is "twenty per cent further in the direction you are looking", which is what
## a rifle wants. 0 is no lean at all, which is what every weapon that does not
## want one leaves it at.
@export var offset_fraction: float = 0.0
## Shape of the lean between the middle of the screen and its edge. 1 is a straight
## line; above 1 holds the camera still near the middle and gives the view up late,
## which is what keeps ordinary aiming from swimming.
@export_range(0.1, 8.0, 0.05) var offset_curve: float = 2.4
## How far out the cursor must be, as a fraction of the way to the screen edge,
## before the camera leans at all. A small dead zone, so a cursor near the player
## reads as "not looking anywhere in particular".
@export_range(0.0, 0.9, 0.01) var offset_deadzone: float = 0.12
## How quickly the lean follows the cursor, in the usual exponential-smoothing
## units. Low: the camera should drift after the aim, never track it.
@export var offset_smoothing: float = 4.5

@export_group("Zoom")
## What this weapon multiplies the resting zoom by. Above 1 is closer: 1.15 is the
## fifteen per cent closer a shotgun wants. 1 leaves the view exactly where the
## place put it.
@export var zoom_multiplier: float = 1.0
## How quickly the view crosses to that zoom, and back to nothing as the weapon
## leaves. Low, because this is a view settling into a weapon rather than a punch.
@export var zoom_smoothing: float = 3.0

@export_group("When it applies")
## Whether the framing relaxes while the weapon is in the belt. On: a weapon that
## is not in the player's hands is not framing anything.
@export var respects_holster: bool = true
## The weapon this belongs to, asked whether it is stowed. Defaults to this node's
## parent.
@export var weapon_path: NodePath = ^".."
## Group the player is found in - the point the cursor's distance is measured from.
@export var player_group: StringName = &"player"

@onready var _weapon: CarriedWeapon = get_node_or_null(weapon_path) as CarriedWeapon

var _camera: CameraController
var _offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0


func _ready() -> void:
	_zoom = 1.0


func _process(delta: float) -> void:
	var camera := _get_camera()
	if camera == null:
		return

	var applies := not (respects_holster and _weapon != null and _weapon.is_stowed())

	_offset = _offset.lerp(
		_wanted_offset(camera) if applies else Vector2.ZERO,
		1.0 - exp(-maxf(offset_smoothing, 0.01) * delta))
	_zoom = lerpf(
		_zoom,
		maxf(zoom_multiplier, 0.01) if applies else 1.0,
		1.0 - exp(-maxf(zoom_smoothing, 0.01) * delta))

	camera.set_weapon_offset(_offset)
	camera.set_weapon_zoom(_zoom)


## Where the camera would like to be right now.
##
## The cursor's distance is measured as a fraction of the way to the edge of the
## *visible rectangle*, not in pixels, which is what makes "the extreme edge" mean
## the same thing on any window and at any zoom. The lean is then that fraction, put
## through the curve, of the distance from the middle of the view to the edge along
## that same direction - so [member offset_fraction] reads as the share of extra
## view it actually gives.
func _wanted_offset(camera: CameraController) -> Vector2:
	if offset_fraction <= 0.0:
		return Vector2.ZERO

	var origin := _anchor(camera)
	var aim := camera.get_global_mouse_position() - origin
	if aim.is_zero_approx():
		return Vector2.ZERO

	var half := camera.get_view_size_at(camera.get_zoom_multiplier()) * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return Vector2.ZERO

	# 1 exactly where the cursor reaches the nearer edge of the view, whichever axis
	# that happens to be on.
	var reach := clampf(maxf(absf(aim.x) / half.x, absf(aim.y) / half.y), 0.0, 1.0)
	if reach <= offset_deadzone:
		return Vector2.ZERO

	# The dead zone is taken out and the rest rescaled, so the lean still reaches
	# its full value at the edge rather than being cut short by the zone.
	var ratio := (reach - offset_deadzone) / maxf(1.0 - offset_deadzone, 0.0001)
	var direction := aim.normalized()
	return direction \
		* pow(ratio, maxf(offset_curve, 0.01)) \
		* offset_fraction \
		* _edge_distance(direction, half)


## How far it is from the middle of the view to its edge along [param direction].
## The exact answer for a rectangle, so a lean towards a corner is measured against
## the corner rather than against a circle that does not exist.
func _edge_distance(direction: Vector2, half: Vector2) -> float:
	var horizontal := half.x / maxf(absf(direction.x), 0.0001)
	var vertical := half.y / maxf(absf(direction.y), 0.0001)
	return minf(horizontal, vertical)


## What the cursor's distance is measured from: the player if there is one, and
## otherwise the middle of the view - which is where the player is anyway, and is
## what a scene run on its own has.
func _anchor(camera: CameraController) -> Vector2:
	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player != null:
		return player.global_position
	return camera.get_screen_center_position()


## Handed back on the way out, so a weapon swapped away mid-lean cannot leave the
## camera holding its framing.
func _exit_tree() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.clear_weapon_modifiers()
	_camera = null


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
