class_name FilmPostProcess
extends ColorRect
## The old-western film-reel feel laid over the whole final image - world,
## characters and effects, and every last piece of UI on top of them: the
## HUD, every menu, the letterbox, the title screen and the drawn cursor
## alike. It reaches all of that by living on its own [CanvasLayer] -
## [code]FilmPostProcess.tscn[/code]'s own root, at [member CanvasLayer.layer]
## [code]3[/code] - one above [code]RunHUD[/code]'s own layer [code]2[/code],
## which is itself one above [code]WorldMap.tscn[/code]'s [code]UI[/code]
## layer [code]1[/code]. [code]RunHUD[/code] and [code]TitleScreen.tscn[/code]
## both simply instance this scene as a child; nesting a [CanvasLayer] inside
## another one does not fold its layer into its parent's - [member CanvasLayer.layer]
## is always resolved against the viewport, so this draws after the whole
## HUD and every menu on it regardless of where in the tree it is parented.
##
## [b]This has to be its own [CanvasLayer], not just the highest z_index on
## [code]RunHUD[/code]'s own.[/b] That was tried first and does not work:
## [code skip-lint]screen_texture[/code] is only ever a backbuffer copy taken
## once, at the start of a [CanvasLayer]'s own contribution to the frame, of
## whatever every [i]lower[/i] layer (and the base scene) has drawn so far -
## never of anything else sharing that same layer, no matter its
## [member CanvasItem.z_index] or where it sits in the child list. A
## same-layer [code]ColorRect[/code] at the z_index ceiling still only ever
## reads the frame from underneath [code]RunHUD[/code] entirely, which is
## indistinguishable from every menu on it simply failing to open. Giving
## this its own, later layer is what actually moves the point
## [code]screen_texture[/code] is sampled from to "everything RunHUD has
## drawn, menus included".
##
## A menu that pauses the tree, blurs its own backdrop or reads
## [code]screen_texture[/code] for its own effect - the Blur nodes on
## [code]UpgradeMenu[/code], [code]WeaponSelectMenu[/code] and the rest - is
## untouched by this: they live on [code]RunHUD[/code]'s own layer, this
## reads the frame they left behind one layer up, exactly the ordering
## [code]screen_texture[/code] always implies across layers.
##
## [b]Every knob that shapes the look lives on the shader itself.[/b] Grain,
## dust, scratches, flicker, frame jitter and the film's own vignette are all
## uniforms on [code]film_post_process.gdshader[/code], which is what makes
## them ordinary inspector fields on this node's material - nothing about
## their strength, size or timing is decided in this script. This script only
## drives the shader's single [code]global_intensity[/code] dial: a bit
## higher at night, folded by weather when a weather system asks it to be,
## and free to be pulsed for a moment of cinematic weight.
##
## [b]It does not touch what it sits on top of.[/b] No [DayStage] colour, no
## [SunStage], no fog, no weather value is ever written here - only read, and
## only to decide how strong an already-authored effect should look right
## now. The palette underneath is whatever [DayCycleDirector] and
## [SunController] already painted.
##
## [b]Weather hook, not a weather system.[/b] [method set_weather_state] is
## the one door a future weather system can knock on - "it is raining now" -
## without this class ever deciding what weather is or when it changes. Until
## something calls it, the effect behaves exactly as it does in clear
## weather, which is the only state this project currently has.
##
## [b]The cinematic hook.[/b] [method pulse] is the one door a boss death, an
## extraction or the player's own death can knock on later for a brief lift
## in the whole effect's weight. Nothing here decides when that happens -
## calling it is entirely up to whichever of those systems is built next.

## Group used by [method get_active], the same pattern [ScreenFlash] and
## [SunController] are already found by.
const GROUP := &"film_post_process"

@export_group("Night response")
## Whether the effect leans in at night at all. Off holds
## [member global_intensity] at [member base_intensity] regardless of the
## clock.
@export var react_to_time_of_day: bool = true
## The world clock read for the current hour - the same
## [code]/root/WorldClock[/code] [SunController] already follows, so Base,
## Arena and World Map are always describing the same moment rather than each
## reading their own idea of "now".
@export var clock_path: NodePath = ^"/root/WorldClock"
## How strong the effect is with no time-of-day or weather lean applied at
## all - the floor everything else is multiplied against.
@export var base_intensity: float = 1.0
## Per-period multiplier on [member base_intensity], in the same
## dawn/morning/noon/evening/twilight/night order [SunController]'s own
## stages run in. Blended smoothly between neighbours by the clock's own
## progress through the period - the same way [SunStage.blend] eases the sky
## - so this never snaps at a period boundary either.
@export var period_intensity: PackedFloat32Array = PackedFloat32Array(
	[1.0, 0.9, 0.8, 1.0, 1.2, 1.4]
)

@export_group("Weather response")
## What the effect currently believes the weather to be. Nothing in this
## project sets this yet - see [method set_weather_state] - so it stays
## [code]&"clear"[/code] and the multipliers below never come into play.
@export var weather_state: StringName = &"clear"
## Multiplier applied while [member weather_state] is [code]&"rain"[/code] -
## a lighter atmospheric read, so the film's own dust does not compete with
## rain.
@export var rain_intensity_scale: float = 0.7
## Multiplier applied while [member weather_state] is
## [code]&"sandstorm"[/code] - stronger and slightly harder-edged, to sit
## with a sandstorm's own reduced contrast rather than against it.
@export var sandstorm_intensity_scale: float = 1.35

@export_group("Cinematic pulse")
## How the pulse eases in, holds and eases back out by default - see
## [method pulse].
@export var default_pulse_curve := Vector3(0.15, 0.5, 1.0)

## The material's own shader, cached once so every frame is a single
## [method ShaderMaterial.set_shader_parameter] rather than a resource fetch.
var _shader_material: ShaderMaterial
var _clock: Node
var _pulse_amount: float = 0.0
var _pulse_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = material as ShaderMaterial
	if clock_path != NodePath(""):
		_clock = get_node_or_null(clock_path)
	set_process(_shader_material != null)


func _process(_delta: float) -> void:
	_shader_material.set_shader_parameter("global_intensity", _compute_intensity())


## The film effect on the shared HUD, the same way [method ScreenFlash.get_active]
## and [method SunController.get_active] are already found - by group, so a
## caller anywhere in the tree can reach it without a path across scenes.
static func get_active(from_node: Node) -> FilmPostProcess:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as FilmPostProcess


## The door a future weather system calls through. [param state] is expected
## to be [code]&"clear"[/code], [code]&"rain"[/code] or [code]&"sandstorm"[/code];
## anything else is treated as clear. Nothing here schedules, detects or
## invents weather - it only remembers the last state it was told.
func set_weather_state(state: StringName) -> void:
	weather_state = state


## Lifts [member global_intensity] briefly for a cinematic beat - a boss's
## death, an extraction, the player's own. [param strength] is added on top
## of whatever the time-of-day and weather lean already are; [param curve]
## overrides [member default_pulse_curve] as (attack seconds, hold seconds,
## release seconds) when given.
func pulse(strength: float = 0.6, curve: Vector3 = Vector3.ZERO) -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	var shape := default_pulse_curve if curve == Vector3.ZERO else curve
	_pulse_amount = 0.0
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "_pulse_amount", strength, maxf(shape.x, 0.0)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if shape.y > 0.0:
		_pulse_tween.tween_interval(shape.y)
	_pulse_tween.tween_property(self, "_pulse_amount", 0.0, maxf(shape.z, 0.0001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Cancels any pulse in flight and drops straight back to the resting level.
func clear_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()
	_pulse_amount = 0.0


func _compute_intensity() -> float:
	var value := base_intensity

	if react_to_time_of_day and _clock != null and period_intensity.size() > 0:
		var count := period_intensity.size()
		var index: int = clampi(int(_clock.call("get_time_period_index")), 0, count - 1)
		var next_index := (index + 1) % count
		var t: float = _clock.call("get_period_progress")
		value *= lerpf(period_intensity[index], period_intensity[next_index], t)

	match weather_state:
		&"rain":
			value *= rain_intensity_scale
		&"sandstorm":
			value *= sandstorm_intensity_scale
		_:
			pass

	return maxf(value + _pulse_amount, 0.0)
