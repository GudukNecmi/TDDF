class_name ScreenFlash
extends ColorRect
## A full-screen colour flash, driven entirely by whoever calls [method flash].
##
## One node serves every flash in the game: the shotgun's yellow-white muzzle
## blast and the red hit on the player are the same object with different
## arguments. Nothing about a particular effect is baked in here, so a new one
## costs a call rather than a node.
##
## It sits on the HUD's [CanvasLayer], above the world and outside the arena's
## [CanvasModulate], so a flash genuinely lights the whole screen rather than
## being dimmed along with everything else.
##
## Because it is a plain colour rect with [constant Control.MOUSE_FILTER_IGNORE]
## it costs nothing while idle and never eats input.
##
## Found with [method get_active] rather than by a NodePath, the same way
## [CameraController] and [BloodField] are - so the shotgun, which lives in its
## own scene entirely outside the HUD, can reach it without either knowing where
## the other sits.

## Group used by [method get_active].
const GROUP := &"screen_flash"

## Restarts from transparent every time rather than adding to whatever is already
## showing, so rapid fire cannot stack flashes into a solid wall of colour.
var _tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hidden rather than merely transparent, so an idle flash is not composited
	# over the screen every frame.
	visible = false
	color.a = 0.0


## The flash any system should talk to. Returns null when the scene has none,
## which every caller treats as "screen flashes are switched off".
static func get_active(from_node: Node) -> ScreenFlash:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as ScreenFlash


## Fires a flash. [param peak] is the alpha at its brightest, [param hold] how
## long it stays there, and [param fade] how long it takes to disappear.
##
## A [param hold] of 0 gives the sharpest result: the colour is on for a single
## frame and then falls away, which is what makes the muzzle blast read as a
## flash of light rather than a coloured overlay.
func flash(
	flash_colour: Color, peak: float = 1.0, hold: float = 0.0, fade: float = 0.09
) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	color = Color(flash_colour.r, flash_colour.g, flash_colour.b, peak)
	visible = true

	_tween = create_tween()
	if hold > 0.0:
		_tween.tween_interval(hold)
	_tween.tween_property(self, "color:a", 0.0, maxf(fade, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Hidden again at the end so an idle flash costs nothing to draw.
	_tween.tween_callback(hide)


## Cancels anything in flight and clears the screen immediately.
func clear() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	color.a = 0.0
	hide()
