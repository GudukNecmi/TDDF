class_name RecoilShield
extends Node2D
## The blood-red ward drawn around the player while RECOIL DEVIL holds them
## untouchable - the visible half of [method PlayerRecoil.is_guarded].
##
## [b]It owns nothing of the immunity.[/b] It only follows the recoil's
## [signal PlayerRecoil.guard_changed], so what is shown is always exactly what
## [Health] is doing. The shimmer is the Noon heat haze's own - see
## [code]recoil_shield.gdshader[/code] - gathered into a wavering disc with a
## tinted rim, so it reads as the desert's hallucination turned into a ward
## rather than a solid bubble.
##
## [b]It never pops off.[/b] As the guard comes down an inner glow grows from the
## middle out past the rim and fades, while the ward itself fades under it.
## Raised again mid-glow, the ward simply comes back from wherever it had faded to.
##
## Hidden while idle, so it costs nothing while the Legendary is off or the
## player is on their feet. Drawn after the player's artwork, and a [Node2D], so
## it can never take the player's aim or fire.

## The ward is drawn round this node's own origin, so where it sits on the player
## is simply the node's position in the scene.

## The recoil whose guard is followed.
@export var recoil_path: NodePath = ^"../Recoil"

@export_group("Shield")
## Radius of the ward, in pixels.
@export var radius: float = 56.0:
	set(value):
		radius = value
		queue_redraw()
## How far its edge wanders in and out, in pixels.
@export var edge_wobble: float = 3.0
## Width of the tinted rim, in pixels.
@export var rim_width: float = 10.0
## How hard what is behind the ward is bent, in screen pixels - the haze's own
## shimmer, stronger.
@export_range(0.0, 8.0, 0.05) var wave_distortion: float = 2.2
## How far apart the ripples are, in pixels.
@export var wave_length: float = 18.0
## How fast they move.
@export var wave_speed: float = 3.2
## The ward's colour.
@export var shield_color := Color(0.78, 0.04, 0.04)
## How strongly the rim is tinted, 0..1.
@export_range(0.0, 1.0, 0.01) var rim_opacity: float = 0.55
## How strongly the inside is tinted, 0..1. Kept low so the player reads through.
@export_range(0.0, 1.0, 0.01) var fill_opacity: float = 0.10
## Master strength on both tints - one knob for how intense the ward is.
@export_range(0.0, 2.0, 0.01) var intensity: float = 1.0
## Seconds the ward takes to come up as the guard is raised.
@export var fade_in_time: float = 0.06

@export_group("Closing glow")
## Seconds the glow takes, from the guard coming down until nothing is left.
## The ward fades away across the same time.
@export var glow_duration: float = 0.32
## How bright the glow is at its peak, 0..1 and beyond for a flare.
@export_range(0.0, 2.0, 0.01) var glow_intensity: float = 0.85
## Share of [member glow_duration] spent brightening before it fades.
@export_range(0.0, 1.0, 0.01) var glow_rise_share: float = 0.18
## Where the glow's front starts and ends, as multiples of [member radius]: it
## starts inside the player and ends past the rim.
@export var glow_start_scale: float = 0.1
@export var glow_expansion: float = 1.45
## How soft the front is, in pixels.
@export var glow_softness: float = 18.0
@export var glow_color := Color(1.0, 0.28, 0.2)

@onready var _recoil: PlayerRecoil = get_node_or_null(recoil_path) as PlayerRecoil

var _material: ShaderMaterial
var _raised: bool = false
var _presence: float = 0.0
## Seconds into the closing glow, below 0 while none is playing.
var _glow_time: float = -1.0
var _presence_at_close: float = 0.0


func _ready() -> void:
	_material = material as ShaderMaterial
	if _recoil != null and not _recoil.guard_changed.is_connected(_on_guard_changed):
		_recoil.guard_changed.connect(_on_guard_changed)
	_raised = _recoil != null and _recoil.is_guarded()
	_presence = 1.0 if _raised else 0.0
	_apply()
	_set_running(_raised)


## True while any part of the ward or its closing glow is on screen.
func is_showing() -> bool:
	return visible


func _on_guard_changed(guarded: bool) -> void:
	_raised = guarded
	if guarded:
		_glow_time = -1.0
	else:
		_glow_time = 0.0
		_presence_at_close = _presence
	_set_running(true)


func _process(delta: float) -> void:
	if _raised:
		_presence = minf(_presence + delta / maxf(fade_in_time, 0.001), 1.0)
	elif _glow_time >= 0.0:
		_glow_time += delta
		var u := clampf(_glow_time / maxf(glow_duration, 0.001), 0.0, 1.0)
		_presence = _presence_at_close * (1.0 - smoothstep(0.0, 1.0, u))
		if u >= 1.0:
			_glow_time = -1.0
			_presence = 0.0
			_apply()
			_set_running(false)
			return
	_apply()


func _set_running(running: bool) -> void:
	visible = running
	set_process(running)
	if running:
		queue_redraw()


## The glow's brightness and the reach of its front, [param u] of the way through.
func _glow_at(u: float) -> Vector2:
	var rise := clampf(glow_rise_share, 0.001, 0.999)
	var envelope := u / rise if u < rise else 1.0 - smoothstep(rise, 1.0, u)
	var grow := 1.0 - pow(1.0 - u, 2.0)
	var reach := radius * lerpf(glow_start_scale, glow_expansion, grow)
	return Vector2(maxf(glow_intensity, 0.0) * envelope, reach)


func _apply() -> void:
	if _material == null:
		return
	var glow := Vector2.ZERO
	if _glow_time >= 0.0:
		glow = _glow_at(clampf(_glow_time / maxf(glow_duration, 0.001), 0.0, 1.0))
	var tint := shield_color
	tint.a = clampf(rim_opacity * intensity, 0.0, 1.0)
	_material.set_shader_parameter(&"presence", _presence)
	_material.set_shader_parameter(&"radius_px", radius)
	_material.set_shader_parameter(&"edge_wobble_px", edge_wobble)
	_material.set_shader_parameter(&"rim_width_px", rim_width)
	_material.set_shader_parameter(&"distortion_px", wave_distortion)
	_material.set_shader_parameter(&"wavelength_px", maxf(wave_length, 1.0))
	_material.set_shader_parameter(&"speed", wave_speed)
	_material.set_shader_parameter(&"shield_color", tint)
	_material.set_shader_parameter(&"fill_opacity", clampf(fill_opacity * intensity, 0.0, 1.0))
	_material.set_shader_parameter(&"glow", glow.x)
	_material.set_shader_parameter(&"glow_radius_px", glow.y)
	_material.set_shader_parameter(&"glow_softness_px", maxf(glow_softness, 1.0))
	_material.set_shader_parameter(&"glow_color", glow_color)


## One quad around the middle, big enough for the ward's wobble and the glow at
## its widest; the shader decides what of it is drawn.
func _draw() -> void:
	var reach := maxf(radius + edge_wobble + 4.0, radius * glow_expansion + glow_softness)
	draw_rect(Rect2(-Vector2.ONE * reach, Vector2.ONE * reach * 2.0), Color.WHITE)
