class_name Torch
extends Node2D
## Wall torch: a looping flame sprite, an unsteady light, and embers that come
## off it every few seconds.
##
## The sprite loop on its own reads as a clean 4-frame cycle, which is far too
## regular to pass for fire. The light is what sells it, so its energy is driven
## by layered [FastNoiseLite] rather than the animation: two noise fields at
## different rates, one slow enough to read as the flame guttering and one fast
## enough to read as it snapping. Because they are noise and not sine waves the
## pattern never repeats audibly, which is the whole point of "unstable".
##
## The same noise nudges the light's radius and horizontal position by a pixel
## or two, so the pool of light breathes instead of just changing brightness.
##
## Embers are a one-shot [GPUParticles2D] restarted on a randomised interval, so
## the torch spits a few sparks now and then instead of streaming them
## constantly.

@export var light_path: NodePath = ^"Light"
@export var flame_path: NodePath = ^"Flame"
@export var embers_path: NodePath = ^"Embers"

@export_group("Flicker")
## Light energy the flicker swings around. The node's own energy is captured at
## `_ready()` when this is left at 0, so tuning the light in the inspector works.
@export var base_energy: float = 0.0
## Fraction of [member base_energy] the slow gutter removes at its lowest.
@export_range(0.0, 1.0) var gutter_depth: float = 0.30
## Fraction removed by the fast snap. Kept smaller so it reads as texture on top
## of the gutter rather than a second, competing rhythm.
@export_range(0.0, 1.0) var snap_depth: float = 0.14
## Noise samples per second for each layer.
@export var gutter_speed: float = 2.6
@export var snap_speed: float = 11.0
## How far the lit radius breathes, as a fraction of the light's texture scale.
@export_range(0.0, 0.5) var radius_jitter: float = 0.07
## Horizontal sway of the light's centre, in local pixels.
@export var sway_pixels: float = 1.2
## How much of the flicker is mirrored onto the flame sprite's brightness.
@export_range(0.0, 1.0) var flame_response: float = 0.35

@export_group("Embers")
## Random delay range, in seconds, between ember bursts.
@export var ember_interval := Vector2(1.4, 4.0)
## Skips the wait once on spawn so a fresh torch does not sit sparkless.
@export var ember_burst_on_start: bool = true
## Below this much flame, the torch stops spitting sparks. A dying torch that
## kept throwing embers would read as burning at full strength however dim its
## light had become.
@export_range(0.0, 1.0) var ember_lit_threshold: float = 0.35

@onready var _light: PointLight2D = get_node_or_null(light_path) as PointLight2D
@onready var _flame: AnimatedSprite2D = get_node_or_null(flame_path) as AnimatedSprite2D
@onready var _embers: GPUParticles2D = get_node_or_null(embers_path) as GPUParticles2D

var _gutter := FastNoiseLite.new()
var _snap := FastNoiseLite.new()
var _time: float = 0.0
var _ember_countdown: float = 0.0

var _rest_energy: float = 1.0
var _rest_texture_scale: float = 1.0
var _rest_light_x: float = 0.0
var _flame_colour := Color.WHITE
var _lit: float = 1.0


func _ready() -> void:
	# Every torch gets its own noise offset, otherwise a row of them along a
	# wall would gutter in perfect unison and read as one flashing light.
	_gutter.seed = randi()
	_snap.seed = randi()
	_gutter.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_snap.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_time = randf() * 1000.0

	if _light != null:
		_rest_energy = base_energy if base_energy > 0.0 else _light.energy
		_rest_texture_scale = _light.texture_scale
		_rest_light_x = _light.position.x
	if _flame != null:
		_flame_colour = _flame.modulate
		if not _flame.is_playing():
			_flame.play()

	_ember_countdown = 0.0 if ember_burst_on_start else _next_ember_delay()


func _process(delta: float) -> void:
	_time += delta
	_update_light()
	_update_embers(delta)


## How much of its full flame this torch is currently carrying: 0 is out, 1 is
## burning normally. Whatever owns the torch's *state* writes this - see
## [TorchProximity], which brings a ring of them up as the player approaches.
##
## It is applied as a plain multiplier on top of everything the torch already
## does, so a torch fading out keeps guttering and snapping the whole way down
## rather than freezing and then vanishing. None of the resting values captured
## at [method _ready] are touched, so a torch can be faded to nothing and back
## without losing its tuning.
func set_lit_amount(amount: float) -> void:
	_lit = clampf(amount, 0.0, 1.0)


func get_lit_amount() -> float:
	return _lit


func _update_light() -> void:
	if _light == null:
		return

	# get_noise_1d() returns roughly -1..1; remapped to 0..1 so each layer only
	# ever subtracts from the resting energy. A torch that brightens past its own
	# rest value looks electrical rather than lit.
	var gutter := _unit_noise(_gutter, _time * gutter_speed)
	var snap := _unit_noise(_snap, _time * snap_speed)
	var dim := gutter_depth * gutter + snap_depth * snap

	_light.energy = _rest_energy * maxf(1.0 - dim, 0.05) * _lit
	_light.texture_scale = _rest_texture_scale * (1.0 + radius_jitter * (0.5 - gutter) * 2.0)
	# Sampled off-axis so the sway is independent of the brightness curve.
	_light.position.x = _rest_light_x + sway_pixels * _gutter.get_noise_2d(_time * gutter_speed, 137.0)

	if _flame != null:
		# The flame sprite fades out with the light rather than only dimming, so a
		# dead torch is a dead torch instead of a grey sprite sitting in the dark.
		var lit := 1.0 - dim * flame_response
		_flame.modulate = Color(
			_flame_colour.r * lit, _flame_colour.g * lit, _flame_colour.b * lit,
			_flame_colour.a * _lit)
		_flame.visible = _lit > 0.01


func _update_embers(delta: float) -> void:
	if _embers == null or _lit < ember_lit_threshold:
		return
	_ember_countdown -= delta
	if _ember_countdown > 0.0:
		return
	# restart() re-fires a one_shot emitter; existing sparks keep living out
	# their lifetime, so overlapping bursts fade into each other.
	_embers.restart()
	_ember_countdown = _next_ember_delay()


func _next_ember_delay() -> float:
	return randf_range(minf(ember_interval.x, ember_interval.y), maxf(ember_interval.x, ember_interval.y))


## FastNoiseLite's -1..1 output squashed into 0..1.
func _unit_noise(noise: FastNoiseLite, at: float) -> float:
	return clampf(noise.get_noise_1d(at) * 0.5 + 0.5, 0.0, 1.0)
