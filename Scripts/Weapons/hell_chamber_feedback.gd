class_name HellChamberFeedback
extends Node
## Everything the player sees, hears and feels as a HELL CHAMBER charge builds in
## the shotgun, and the kick of the shot that spends it.
##
## [b]It owns no charge.[/b] The weapon holds it - see [method Shotgun.get_chamber_charge]
## - and this follows it every frame, and reacts to [code]chamber_maxed[/code] and
## [code]chamber_released[/code]. The ordinary shot's sound, flash and kick are all
## still [ShotgunFeedback]'s and are never touched.
##
## [b]Every effect is authored once and scaled by the charge.[/b] Each reads the
## same 0..1 through its own Inspector values, and at 0 every one of them is at
## rest - which is exactly the weapon with the Legendary off, since then the charge
## never leaves 0. Nothing here writes anything BLOOD PUMP's own feedback writes:
## the glow is its own additive copy of the artwork, the tremble is the sprites'
## offset rather than the art's rotation, and the held zoom and tremor go through
## [method WeaponCamera.set_source_hold] under their own name, so both charges can
## be on at once.

## The weapon whose charge is followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## The weapon's framing, which holds the charge's zoom and tremor.
@export var weapon_camera_path: NodePath = ^"../Camera"
## Bank the fire layers are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"
## The weapon's sprites, which tremble with the charge. The glow copies the first.
@export var sprite_paths: Array[NodePath] = [^"../Art/Body", ^"../Art/Pump"]
## Additive copy of the body drawn over it - the metal heating from inside.
@export var glow_path: NodePath = ^"../Art/Body/ChamberGlow"
## The light the charge throws around the barrel.
@export var light_path: NodePath = ^"../MuzzleRig/ChamberLight"
## Energy crawling along the barrel while charging.
@export var energy_path: NodePath = ^"../MuzzleRig/ChamberEnergy"
## The buildup loop - a [LoopingSound] whose level follows the charge.
@export var hum_path: NodePath = ^"../ChamberHum"
## Where the bursts are thrown from.
@export var muzzle_path: NodePath = ^"../MuzzleRig/Muzzle"

@export_group("Glow")
## Colour of the heat at the start of the charge and near the top - HDR, so above 1
## blooms.
@export var glow_colour_low := Color(0.9, 0.06, 0.02)
@export var glow_colour_high := Color(2.2, 0.55, 0.12)
## How strong the glow is at full, and the shape of its build. Above 1 keeps the
## low charge subtle.
@export_range(0.0, 1.0) var glow_max_alpha: float = 0.85
@export_range(0.25, 4.0, 0.05) var glow_curve: float = 1.5
## Throb of the glow as a fraction of it, at the start and at full, in beats per
## second.
@export_range(0.0, 1.0) var glow_pulse: float = 0.3
@export var pulse_rate_min: float = 2.0
@export var pulse_rate_max: float = 9.0
## The light's energy at full, and its reach at the start and at full.
@export var light_energy_max: float = 1.6
@export var light_scale_min: float = 0.6
@export var light_scale_max: float = 1.6

@export_group("Vibration")
## How far the weapon's sprites tremble at full charge, in the artwork's own pixels
## - the art is drawn scaled down, so these are larger than on screen.
@export var tremble_pixels_max: float = 14.0
## Shape of the tremble's build. Above 1 keeps it steady until late.
@export_range(0.25, 4.0, 0.05) var tremble_curve: float = 2.0

@export_group("Energy")
## Charge from which energy starts crawling along the barrel.
@export_range(0.0, 1.0) var energy_from: float = 0.2
## Its opacity, and what its authored speed and size are multiplied by, just past
## that point and at full.
@export_range(0.0, 1.0) var energy_min_alpha: float = 0.25
@export var energy_speed_min: float = 0.6
@export var energy_speed_max: float = 1.8
@export var energy_size_min: float = 0.6
@export var energy_size_max: float = 1.5

@export_group("MAX")
## At MAX the glow is pulled on towards white heat and flickers fast, for as long
## as MAX is held.
@export var max_colour := Color(2.6, 1.9, 1.3)
@export_range(0.0, 1.0) var max_mix: float = 0.55
@export_range(0.0, 1.0) var max_flicker: float = 0.5
@export var max_flicker_rate: float = 16.0
## The knock as the charge lands on MAX.
@export var max_reached_shake: float = 8.0
@export var max_reached_shake_duration: float = 0.2
@export var max_reached_zoom: float = 0.05
@export var max_reached_zoom_out_time: float = 0.05
@export var max_reached_zoom_back_time: float = 0.3
## The wash of colour as it lands on MAX.
@export var max_screen_colour := Color(0.55, 0.02, 0.02)
@export_range(0.0, 1.0) var max_screen_peak: float = 0.18
@export var max_screen_fade: float = 0.4
## Burst thrown from the muzzle as it lands on MAX and again as the MAX shot leaves.
@export var max_burst_scene: PackedScene

@export_group("Camera - holding")
## Extra zoom held at full charge - 1.15 is 15% closer. 1 holds none.
@export var hold_zoom_max: float = 1.15
## Tremor held on the view at full charge, in pixels.
@export var hold_shake_max: float = 2.6
@export_range(0.25, 4.0, 0.05) var hold_shake_curve: float = 1.8
## The name the hold is kept under on [WeaponCamera].
@export var hold_source: StringName = &"hell_chamber"

@export_group("Camera - release")
## The knock of a charged shot, in pixels, just past 0 and at full - on top of the
## ordinary shot's own shake. A tap adds nothing.
@export var release_shake_min: float = 2.0
@export var release_shake_max: float = 16.0
@export var release_shake_duration: float = 0.18
## Zoom punch of a charged shot, as a fraction. Negative throws the view out.
@export var release_zoom_min: float = -0.01
@export var release_zoom_max: float = -0.07
@export var release_zoom_out_time: float = 0.04
@export var release_zoom_back_time: float = 0.24
## What a MAX shot adds on top of the full-charge values.
@export var max_release_shake: float = 22.0
@export var max_release_shake_duration: float = 0.3
@export var max_release_zoom: float = -0.1
@export var max_release_rotation: float = 3.0
@export var max_release_rotation_back_time: float = 0.3
@export var max_release_flash_peak: float = 0.25
@export var max_release_flash_fade: float = 0.35
## Layer on [CameraController] the kicks are written to, and how loudly.
@export var camera_channel: StringName = &"hell_chamber"
@export var camera_priority: int = 0
## Burst thrown from the muzzle with any charged shot, thinned for low charges.
@export var release_burst_scene: PackedScene
@export_range(0.0, 1.0) var release_burst_min_ratio: float = 0.2

@export_group("Audio")
## The buildup's level at the start of the charge and at full, 0..1 of the loop's
## own [member LoopingSound.max_volume_db], and its pitch at each end.
@export_range(0.0, 1.0) var hum_level_min: float = 0.25
@export_range(0.0, 1.0) var hum_level_max: float = 1.0
@export var hum_pitch_min: float = 0.8
@export var hum_pitch_max: float = 1.45
## Played once as the charge lands on MAX. Empty plays nothing.
@export var max_reached_sound: AudioStream
@export var max_reached_volume_db: float = -4.0
@export var max_reached_pitch: float = 1.0
## Layer played under the ordinary blast by a shot charged past
## [member charged_layer_from]. Empty plays nothing.
@export var charged_layer_sound: AudioStream
@export_range(0.0, 1.0) var charged_layer_from: float = 0.5
@export var charged_layer_volume_min_db: float = -16.0
@export var charged_layer_volume_max_db: float = -8.0
@export var charged_layer_pitch: float = 1.3
## The heavier layer a MAX shot plays instead.
@export var max_fire_sound: AudioStream
@export var max_fire_volume_db: float = -2.0
@export var max_fire_pitch: float = 1.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _weapon_camera: WeaponCamera = get_node_or_null(weapon_camera_path) as WeaponCamera
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _glow: Sprite2D = get_node_or_null(glow_path) as Sprite2D
@onready var _light: PointLight2D = get_node_or_null(light_path) as PointLight2D
@onready var _energy: CPUParticles2D = get_node_or_null(energy_path) as CPUParticles2D
@onready var _hum: LoopingSound = get_node_or_null(hum_path) as LoopingSound
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D

var _sprites: Array[Sprite2D] = []
var _energy_scale := Vector2.ONE
var _pulse_phase: float = 0.0
var _flicker_phase: float = 0.0
## Whether the look was on last frame, so it is taken off exactly once.
var _look_on: bool = false


func _ready() -> void:
	for path: NodePath in sprite_paths:
		var sprite := get_node_or_null(path) as Sprite2D
		if sprite != null:
			_sprites.append(sprite)
	if _energy != null:
		_energy.emitting = false
		_energy_scale = Vector2(_energy.scale_amount_min, _energy.scale_amount_max)
	_rest()
	if _source == null:
		return
	if _source.has_signal(&"chamber_maxed"):
		_source.connect(&"chamber_maxed", _on_maxed)
	if _source.has_signal(&"chamber_released"):
		_source.connect(&"chamber_released", _on_released)


func _process(delta: float) -> void:
	var charge := _charge()
	if charge <= 0.0:
		if _look_on:
			_rest()
		return
	_look_on = true
	var maxed := _is_max(charge)
	_pulse_phase = fmod(_pulse_phase + lerpf(pulse_rate_min, pulse_rate_max, charge) * TAU * delta, TAU)
	_flicker_phase = fmod(_flicker_phase + max_flicker_rate * TAU * delta, TAU)

	var heat := pow(charge, maxf(glow_curve, 0.01))
	var beat := 1.0 - glow_pulse * 0.5 * (1.0 + sin(_pulse_phase))
	if _glow != null:
		var body := _sprites[0] if not _sprites.is_empty() else null
		if body != null and _glow.texture != body.texture:
			_glow.texture = body.texture
		var colour := glow_colour_low.lerp(glow_colour_high, charge)
		if maxed:
			var flicker := 1.0 - max_flicker * 0.5 * (1.0 + sin(_flicker_phase))
			colour = colour.lerp(max_colour, max_mix * flicker)
		colour.a = glow_max_alpha * heat * (beat if not maxed else 1.0)
		_glow.modulate = colour
		_glow.visible = true
	if _light != null:
		_light.visible = true
		_light.energy = light_energy_max * heat * beat
		_light.texture_scale = lerpf(light_scale_min, light_scale_max, charge)

	var tremble := tremble_pixels_max * pow(charge, maxf(tremble_curve, 0.01))
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremble
	for sprite: Sprite2D in _sprites:
		sprite.offset = jitter
	if _glow != null:
		_glow.offset = jitter

	if _energy != null:
		if charge >= energy_from:
			var t := inverse_lerp(energy_from, 1.0, charge) if energy_from < 1.0 else 1.0
			_energy.modulate.a = lerpf(energy_min_alpha, 1.0, t)
			_energy.speed_scale = lerpf(energy_speed_min, energy_speed_max, t)
			var size := lerpf(energy_size_min, energy_size_max, t)
			_energy.scale_amount_min = _energy_scale.x * size
			_energy.scale_amount_max = _energy_scale.y * size
			_energy.emitting = true
		else:
			_energy.emitting = false

	if _weapon_camera != null:
		_weapon_camera.set_source_hold(hold_source, lerpf(1.0, hold_zoom_max, charge),
			hold_shake_max * pow(charge, maxf(hold_shake_curve, 0.01)))
	if _hum != null:
		_hum.set_level(lerpf(hum_level_min, hum_level_max, charge))
		_hum.pitch_scale = lerpf(hum_pitch_min, hum_pitch_max, charge)


## Everything put back to the weapon as authored, with the hum let fade.
func _rest() -> void:
	_look_on = false
	if _glow != null:
		_glow.visible = false
	if _light != null:
		_light.visible = false
		_light.energy = 0.0
	for sprite: Sprite2D in _sprites:
		sprite.offset = Vector2.ZERO
	if _energy != null:
		# Left to die out rather than cleared, so the last sparks drift off.
		_energy.emitting = false
	if _weapon_camera != null:
		_weapon_camera.set_source_hold(hold_source, 1.0, 0.0)
	if _hum != null:
		_hum.set_level(0.0)


func _exit_tree() -> void:
	_rest()
	if _hum != null:
		_hum.silence_now()


# --- Reactions -------------------------------------------------------------------

func _on_maxed() -> void:
	_spawn_burst(max_burst_scene, 1.0)
	_play(max_reached_sound, max_reached_volume_db, max_reached_pitch)
	var flash := ScreenFlash.get_active(self)
	if flash != null and max_screen_peak > 0.0:
		flash.flash(max_screen_colour, max_screen_peak, 0.0, max_screen_fade)
	var camera := CameraController.get_active(self)
	if camera != null:
		camera.shake(max_reached_shake, max_reached_shake_duration)
		camera.zoom_kick(max_reached_zoom, max_reached_zoom_out_time, max_reached_zoom_back_time,
			camera_channel, camera_priority)


## A shot leaving on release. A tap - no charge built - is the ordinary shot and
## adds nothing.
func _on_released(charge: float, maxed: bool) -> void:
	if charge <= 0.0:
		return
	_spawn_burst(release_burst_scene, charge)
	if maxed:
		_spawn_burst(max_burst_scene, 1.0)
		_play(max_fire_sound, max_fire_volume_db, max_fire_pitch)
	elif charge >= charged_layer_from:
		var t := inverse_lerp(charged_layer_from, 1.0, charge) if charged_layer_from < 1.0 else 1.0
		_play(charged_layer_sound, lerpf(charged_layer_volume_min_db, charged_layer_volume_max_db, t),
			charged_layer_pitch)

	var camera := CameraController.get_active(self)
	if camera == null:
		return
	camera.shake(lerpf(release_shake_min, release_shake_max, charge), release_shake_duration)
	camera.zoom_kick(lerpf(release_zoom_min, release_zoom_max, charge),
		release_zoom_out_time, release_zoom_back_time, camera_channel, camera_priority)
	if not maxed:
		return
	camera.shake(max_release_shake, max_release_shake_duration)
	camera.zoom_kick(max_release_zoom, release_zoom_out_time, release_zoom_back_time,
		camera_channel, camera_priority)
	camera.rotation_kick(max_release_rotation * (1.0 if randf() < 0.5 else -1.0),
		release_zoom_out_time, max_release_rotation_back_time, camera_channel, camera_priority)
	var flash := ScreenFlash.get_active(self)
	if flash != null and max_release_flash_peak > 0.0:
		flash.flash(max_screen_colour, max_release_flash_peak, 0.0, max_release_flash_fade)


# --- Pieces ----------------------------------------------------------------------

func _charge() -> float:
	if _source == null or not _source.has_method(&"get_chamber_charge"):
		return 0.0
	return _source.call(&"get_chamber_charge") as float


func _is_max(charge: float) -> bool:
	var weapon := _source as CarriedWeapon
	var stats: WeaponStats = null if weapon == null else weapon.get_stats()
	return stats != null and stats.hell_chamber != null and stats.hell_chamber.is_max(charge)


## One layer on its own voice with the bank's tail fade, so layers overlap freely.
func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if _sounds == null or stream == null:
		return
	var voice := _sounds.play_stream(stream, volume_db)
	if voice != null:
		voice.pitch_scale *= maxf(pitch, 0.01)
		_sounds.fade_tail(voice)


## One burst from the muzzle, thinned to [param ratio] of its particles. Added to
## the running scene so it stays where it was thrown.
func _spawn_burst(scene: PackedScene, ratio: float) -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	if scene == null or _muzzle == null or container == null:
		return
	var burst := scene.instantiate() as CPUParticles2D
	if burst == null:
		return
	burst.amount = maxi(roundi(burst.amount * lerpf(release_burst_min_ratio, 1.0, clampf(ratio, 0.0, 1.0))), 1)
	container.add_child(burst)
	burst.global_position = _muzzle.global_position
	burst.global_rotation = _muzzle.global_rotation
	burst.reset_physics_interpolation()
	if burst.has_method(&"play"):
		burst.play()
	else:
		burst.emitting = true
