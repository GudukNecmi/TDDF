class_name PumpChargeFeedback
extends Node
## Everything the player sees, hears and feels as a pump weapon banks charge -
## the shotgun's Legendary BLOOD PUMP - and the hit of the shot that spends it.
##
## [b]It owns no charge and no sound of the pump.[/b] The weapon counts the charge
## and announces it through [code]pump_charge_changed[/code] and
## [code]charge_released[/code]; the pump's own strokes are still played by
## [ShotgunFeedback], which this only retunes - [member ShotgunFeedback.pump_pitch]
## a step higher per charge and [member ShotgunFeedback.pump_bus] through an echo
## that deepens with it. The fire sound is never touched.
##
## [b]Every effect is authored once and scaled by the charge.[/b] Each one reads
## the same ratio - charge over the most that can be banked - through its own
## curve and its own Inspector values, so a [PumpCharge] with more or fewer charges
## needs nothing here changed. At 0 every effect is at rest, which is also exactly
## what the weapon looks like with the Legendary off: a shotgun without a
## [PumpCharge] never announces any charge, so none of this ever wakes up.
##
## Camera effects go through the shared [CameraController] as one-off kicks, and
## the held part - the creeping zoom and the tremor - through this weapon's own
## [WeaponCamera], so a cinematic silences them and nothing is ever left on the
## camera after the charge is gone.

## The weapon whose charge is followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## The weapon's own feedback, whose pump sounds are retuned.
@export var shotgun_feedback_path: NodePath = ^"../Feedback"
## The weapon's framing, which holds the charge's zoom and tremor.
@export var weapon_camera_path: NodePath = ^"../Camera"
## Bank the Legendary layer is played through.
@export var sound_bank_path: NodePath = ^"../Sounds"
## The weapon's artwork, which sags, trembles and reddens with the charge.
@export var art_path: NodePath = ^"../Art"
## Embers along the barrel, emitting while anything is banked.
@export var embers_path: NodePath = ^"../MuzzleRig/ChargeEmbers"
## Where the bursts are thrown from.
@export var muzzle_path: NodePath = ^"../MuzzleRig/Muzzle"

@export_group("Camera - building")
## Extra zoom held per charge, multiplied in cumulatively: 1.1 is 1.1x at one
## charge, 1.21x at two, 1.61x at five. 1 holds none.
@export var zoom_per_charge: float = 1.1
## Tremor held on the view at full charge, in pixels. It is 0 with nothing banked.
@export var hold_shake_max: float = 3.2
## Shape of the tremor's build. Above 1 keeps the early charges steady.
@export_range(0.25, 4.0, 0.05) var hold_shake_curve: float = 1.6
## Knock thrown into the camera as each charge lands, in pixels, at one charge and
## at full.
@export var charge_kick_shake_min: float = 2.0
@export var charge_kick_shake_max: float = 7.0
@export var charge_kick_duration: float = 0.12
## Short zoom pulse on each charge landing, as a fraction, at one charge and at
## full. It rides on top of the held zoom.
@export var charge_kick_zoom_min: float = 0.015
@export var charge_kick_zoom_max: float = 0.045
@export var charge_kick_zoom_out_time: float = 0.05
@export var charge_kick_zoom_back_time: float = 0.2

@export_group("Camera - max charge")
## The extra knock the charge landing on full gets, on top of its ordinary kick.
@export var max_shake: float = 11.0
@export var max_shake_duration: float = 0.22
@export var max_zoom_kick: float = 0.06
@export var max_zoom_out_time: float = 0.06
@export var max_zoom_back_time: float = 0.28

@export_group("Camera - release")
## The knock of a charged shot, in pixels, at one charge and at full - on top of
## the ordinary shot's own shake.
@export var release_shake_min: float = 10.0
@export var release_shake_max: float = 34.0
@export var release_shake_duration_min: float = 0.12
@export var release_shake_duration_max: float = 0.22
## Zoom punch of a charged shot, as a fraction. Negative throws the view out.
@export var release_zoom_min: float = -0.04
@export var release_zoom_max: float = -0.14
@export var release_zoom_out_time: float = 0.04
@export var release_zoom_back_time: float = 0.22
## Turn thrown into a charged shot, in degrees, at one charge and at full.
@export var release_rotation_min: float = 0.8
@export var release_rotation_max: float = 3.0
@export var release_rotation_out_time: float = 0.04
@export var release_rotation_back_time: float = 0.26
## Layer on [CameraController] the kicks are written to, and how loudly.
@export var camera_channel: StringName = &"weapon_charge"
@export var camera_priority: int = 0

@export_group("Screen")
## Faint wash of colour over the screen each time a charge lands - the buildup.
@export var screen_colour := Color(0.45, 0.0, 0.03)
## Its strength at one charge and at the last charge before full.
@export_range(0.0, 1.0) var screen_peak_min: float = 0.03
@export_range(0.0, 1.0) var screen_peak_max: float = 0.1
@export var screen_fade: float = 0.3
## The wash the charge landing on full gets instead - still short, so the screen
## is never hidden.
@export_range(0.0, 1.0) var screen_max_peak: float = 0.22
@export var screen_max_hold: float = 0.04
@export var screen_max_fade: float = 0.45

@export_group("Weapon")
## What the weapon's follow and aim speed are multiplied by at full charge - see
## [member CarriedWeapon.handling_scale]. 1 changes nothing.
@export_range(0.1, 1.0, 0.01) var heft_at_max: float = 0.62
## How far the barrel droops at full charge, in degrees.
@export var sag_degrees_max: float = 3.0
## Tremble of the artwork at full charge, in degrees either way.
@export var tremble_degrees_max: float = 0.9
## Colour the artwork is pulled towards as charge builds, and how far at full.
@export var tint_colour := Color(1.0, 0.42, 0.38)
@export_range(0.0, 1.0) var tint_max: float = 0.55
## Throb of the tint - a heartbeat - as a fraction of it, and its rate at one
## charge and at full, in beats per second.
@export_range(0.0, 1.0) var tint_pulse: float = 0.45
@export var pulse_rate_min: float = 1.4
@export var pulse_rate_max: float = 3.6
## Shape of how the look follows the charge. Above 1 keeps the low charges subtle.
@export_range(0.25, 4.0, 0.05) var look_curve: float = 1.4
## How quickly the look follows the charge, and how quickly it lets go after a
## shot, in the usual exponential-smoothing units.
@export var look_in_speed: float = 9.0
@export var look_out_speed: float = 6.0

@export_group("Particles")
## How visible the embers are at one charge; full charge shows them at their
## authored strength.
@export_range(0.0, 1.0) var embers_min_alpha: float = 0.3
## What the embers' authored size and speed are multiplied by at one charge and at
## full - thin and lazy at first, fat and quick at the top. Changed without
## restarting the emitter, so what is already in the air is never cut off.
@export var embers_size_min: float = 0.6
@export var embers_size_max: float = 1.35
@export var embers_speed_min: float = 0.7
@export var embers_speed_max: float = 1.6
## Burst thrown from the muzzle as each charge lands and as a charged shot leaves.
## One scene, authored for full strength and thinned for lower charges.
@export var burst_scene: PackedScene
## Share of the burst's particles thrown at one charge, rising to all at full.
@export_range(0.0, 1.0) var burst_min_ratio: float = 0.25
## Size the burst is grown by when the charge lands on full - what makes that one
## read as distinct.
@export var burst_max_scale: float = 1.7

@export_group("Max charge - piercing")
## At full charge the shot pierces - see [member PumpCharge.max_charge_modifiers] -
## and the weapon says so: its artwork is pulled on past the red towards this
## white heat, flickering fast, for as long as the full charge is held.
@export var pierce_tint_colour := Color(1.0, 0.88, 0.8)
@export_range(0.0, 1.0) var pierce_tint_mix: float = 0.45
## How much that white heat flickers, as a fraction of it, and how fast, in
## flickers per second.
@export_range(0.0, 1.0) var pierce_flicker: float = 0.5
@export var pierce_flicker_rate: float = 11.0
## A narrow lance thrown straight down the barrel as the charge lands on full and
## again as the piercing shot leaves - the shot's shape before and as it goes.
## Null throws nothing.
@export var pierce_lance_scene: PackedScene

@export_group("Audio")
## What the pump's pitch is raised by per charge. 0.05 is five per cent a charge.
@export var pitch_per_charge: float = 0.045
## Bus the pump strokes are sent through while charged - the echo.
@export var echo_bus: StringName = &"BloodPump"
## The echo bus's reverb wet level and room size at one charge and at full.
@export_range(0.0, 1.0) var reverb_wet_min: float = 0.08
@export_range(0.0, 1.0) var reverb_wet_max: float = 0.55
@export_range(0.0, 1.0) var reverb_room_min: float = 0.35
@export_range(0.0, 1.0) var reverb_room_max: float = 0.92
## The echo bus's delay taps, in decibels, at one charge and at full.
@export var echo_tap_db_min: float = -30.0
@export var echo_tap_db_max: float = -9.0
## How much quieter the second tap is than the first.
@export var echo_second_tap_drop_db: float = 6.0
## The Legendary's own layer over each completed pump. Optional - empty is the pump
## alone, retuned.
@export var layer_sound: AudioStream
@export var layer_volume_db: float = -9.0
## Level added to the layer per charge.
@export var layer_volume_per_charge_db: float = 1.2
## The layer's pitch at one charge, and what each further charge adds.
@export var layer_pitch: float = 1.0
@export var layer_pitch_per_charge: float = 0.03
## Played when the charge lands on full, instead of the layer. Empty uses
## [member layer_sound].
@export var max_sound: AudioStream
@export var max_volume_db: float = -1.0
## One copy of the max sound is played at each of these pitches at once - below 1
## is deeper. Several detuned together is what makes it heavy and unnatural.
@export var max_pitches: Array[float] = [0.72, 0.5]
## A short cue of its own on top of the max sound, saying the next shot will
## pierce. Played dry, off the echo, so it cuts through the heavy max layer. Empty
## plays nothing.
@export var pierce_cue_sound: AudioStream
@export var pierce_cue_volume_db: float = -4.0
@export var pierce_cue_pitch: float = 1.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _weapon: CarriedWeapon = _source as CarriedWeapon
@onready var _shotgun_feedback: ShotgunFeedback = get_node_or_null(shotgun_feedback_path) as ShotgunFeedback
@onready var _weapon_camera: WeaponCamera = get_node_or_null(weapon_camera_path) as WeaponCamera
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _embers: CPUParticles2D = get_node_or_null(embers_path) as CPUParticles2D
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D

var _charge: int = 0
var _max_charge: int = 0
## The look's own ratio, eased after the charge so nothing snaps.
var _look: float = 0.0
var _pulse_phase: float = 0.0
## The white heat's own ratio - 1 while a full charge is held - eased like the look.
var _pierce_look: float = 0.0
var _flicker_phase: float = 0.0
## Whether the look was put on the artwork last frame, so it is cleared once.
var _look_written: bool = false
## The embers' authored particle size, min and max, which the charge scales from.
var _embers_scale := Vector2.ONE
var _camera: CameraController
var _screen_flash: ScreenFlash


func _ready() -> void:
	if _embers != null:
		_embers.emitting = false
		_embers_scale = Vector2(_embers.scale_amount_min, _embers.scale_amount_max)
	if _source == null:
		return
	if _source.has_signal(&"pump_charge_changed"):
		_source.connect(&"pump_charge_changed", _on_charge_changed)
	if _source.has_signal(&"charge_released"):
		_source.connect(&"charge_released", _on_charge_released)
	_apply_audio()


func _process(delta: float) -> void:
	var wanted := _ratio()
	var speed := look_in_speed if wanted > _look else look_out_speed
	_look = lerpf(_look, wanted, 1.0 - exp(-maxf(speed, 0.01) * delta))
	if _look < 0.001 and wanted <= 0.0:
		_look = 0.0

	var shaped := pow(_look, maxf(look_curve, 0.01))
	_pulse_phase = fmod(_pulse_phase + lerpf(pulse_rate_min, pulse_rate_max, _look) * TAU * delta, TAU)
	var pierce_wanted := 1.0 if _is_full() else 0.0
	var pierce_speed := look_in_speed if pierce_wanted > _pierce_look else look_out_speed
	_pierce_look = lerpf(_pierce_look, pierce_wanted, 1.0 - exp(-maxf(pierce_speed, 0.01) * delta))
	if _pierce_look < 0.001 and pierce_wanted <= 0.0:
		_pierce_look = 0.0
	_flicker_phase = fmod(_flicker_phase + pierce_flicker_rate * TAU * delta, TAU)

	if _weapon != null:
		_weapon.handling_scale = lerpf(1.0, heft_at_max, shaped)
	if _weapon_camera != null:
		_weapon_camera.set_hold_shake(hold_shake_max * pow(_ratio(), maxf(hold_shake_curve, 0.01)))

	# At rest nothing is written, so a weapon that never charges is never touched.
	if _art != null and (shaped > 0.0 or _look_written):
		_look_written = shaped > 0.0
		var facing := signf(_art.scale.y) if not is_zero_approx(_art.scale.y) else 1.0
		var tremble := randf_range(-1.0, 1.0) * tremble_degrees_max * shaped
		_art.rotation = deg_to_rad((sag_degrees_max * shaped + tremble) * facing)
		var beat := 1.0 - tint_pulse * 0.5 * (1.0 + sin(_pulse_phase))
		var red := Color.WHITE.lerp(tint_colour, tint_max * shaped * beat)
		var flicker := 1.0 - pierce_flicker * 0.5 * (1.0 + sin(_flicker_phase))
		_art.modulate = red.lerp(pierce_tint_colour, pierce_tint_mix * _pierce_look * flicker)


## Put back on the way out, so a weapon swapped away charged cannot leave anything
## tuned, tinted or held.
func _exit_tree() -> void:
	if _weapon != null:
		_weapon.handling_scale = 1.0
	if _art != null:
		_art.rotation = 0.0
		_art.modulate = Color.WHITE
	if _weapon_camera != null:
		_weapon_camera.set_hold_zoom(1.0)
		_weapon_camera.set_hold_shake(0.0)
	if _shotgun_feedback != null:
		_shotgun_feedback.pump_pitch = 1.0
		_shotgun_feedback.pump_bus = &""


# --- Reactions -------------------------------------------------------------------

func _on_charge_changed(charge: int, max_charge: int) -> void:
	var gained := charge > _charge
	_charge = charge
	_max_charge = max_charge
	_apply_audio()
	_apply_hold()
	if gained:
		_on_charge_gained()


## One more charge banked: the kick, the wash, the puff, the layer - or, landing on
## full, the heavier version of each.
func _on_charge_gained() -> void:
	var ratio := _ratio()
	var full := _is_full()
	_spawn_burst(ratio, burst_max_scale if full else 1.0)
	if full:
		_spawn_burst(1.0, 1.0, pierce_lance_scene)
	_play_layer(full)

	var flash := _get_screen_flash()
	if flash != null:
		if full:
			flash.flash(screen_colour, screen_max_peak, screen_max_hold, screen_max_fade)
		else:
			var step := _step_ratio()
			flash.flash(screen_colour, lerpf(screen_peak_min, screen_peak_max, step), 0.0, screen_fade)

	var camera := _get_camera()
	if camera == null:
		return
	camera.shake(lerpf(charge_kick_shake_min, charge_kick_shake_max, ratio), charge_kick_duration)
	camera.zoom_kick(
		lerpf(charge_kick_zoom_min, charge_kick_zoom_max, ratio),
		charge_kick_zoom_out_time, charge_kick_zoom_back_time, camera_channel, camera_priority)
	if full:
		camera.shake(max_shake, max_shake_duration)
		camera.zoom_kick(max_zoom_kick, max_zoom_out_time, max_zoom_back_time,
			camera_channel, camera_priority)


## A charged shot leaving: a hard short knock scaled by what it spent, and the
## held zoom let go so the view eases home.
func _on_charge_released(charge: int) -> void:
	var ratio := clampf(float(charge) / maxf(float(_max_charge), 1.0), 0.0, 1.0)
	_spawn_burst(ratio, 1.0)
	if _max_charge > 0 and charge >= _max_charge:
		_spawn_burst(1.0, 1.0, pierce_lance_scene)
	var camera := _get_camera()
	if camera == null:
		return
	camera.shake(
		lerpf(release_shake_min, release_shake_max, ratio),
		lerpf(release_shake_duration_min, release_shake_duration_max, ratio))
	camera.zoom_kick(
		lerpf(release_zoom_min, release_zoom_max, ratio),
		release_zoom_out_time, release_zoom_back_time, camera_channel, camera_priority)
	var degrees := lerpf(release_rotation_min, release_rotation_max, ratio) * (1.0 if randf() < 0.5 else -1.0)
	camera.rotation_kick(degrees, release_rotation_out_time, release_rotation_back_time,
		camera_channel, camera_priority)


# --- Pieces ----------------------------------------------------------------------

## How full the charge is, 0..1.
func _ratio() -> float:
	if _max_charge <= 0:
		return 0.0
	return clampf(float(_charge) / float(_max_charge), 0.0, 1.0)


## Whether the charge is full - the next shot pierces.
func _is_full() -> bool:
	return _max_charge > 0 and _charge >= _max_charge


## Where this charge sits between the first and the last before full, 0..1 - so
## the lowest and highest ordinary charges get exactly the min and max values.
func _step_ratio() -> float:
	if _max_charge <= 2:
		return 1.0
	return clampf(float(_charge - 1) / float(_max_charge - 2), 0.0, 1.0)


func _apply_hold() -> void:
	if _weapon_camera != null:
		_weapon_camera.set_hold_zoom(pow(maxf(zoom_per_charge, 0.01), _charge))
	if _embers != null:
		if _charge > 0:
			var ratio := _ratio()
			var size := lerpf(embers_size_min, embers_size_max, ratio)
			_embers.modulate.a = lerpf(embers_min_alpha, 1.0, ratio)
			_embers.scale_amount_min = _embers_scale.x * size
			_embers.scale_amount_max = _embers_scale.y * size
			_embers.speed_scale = lerpf(embers_speed_min, embers_speed_max, ratio)
			_embers.emitting = true
		else:
			# Left to die out rather than cleared, so the last embers drift off.
			_embers.emitting = false


## Retunes the pump strokes and the echo to the current charge. At 0 both go back
## to exactly the pump as recorded, on its own bus.
func _apply_audio() -> void:
	if _shotgun_feedback != null:
		_shotgun_feedback.pump_pitch = 1.0 + pitch_per_charge * _charge
		_shotgun_feedback.pump_bus = echo_bus if _charge > 0 and _echo_bus_index() >= 0 else &""

	var bus := _echo_bus_index()
	if bus < 0 or _charge <= 0:
		return
	var ratio := _ratio()
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectReverb:
			(effect as AudioEffectReverb).wet = lerpf(reverb_wet_min, reverb_wet_max, ratio)
			(effect as AudioEffectReverb).room_size = lerpf(reverb_room_min, reverb_room_max, ratio)
		elif effect is AudioEffectDelay:
			var tap := lerpf(echo_tap_db_min, echo_tap_db_max, ratio)
			(effect as AudioEffectDelay).tap1_level_db = tap
			(effect as AudioEffectDelay).tap2_level_db = tap - echo_second_tap_drop_db


func _echo_bus_index() -> int:
	return -1 if echo_bus.is_empty() else AudioServer.get_bus_index(echo_bus)


## The Legendary's layer over the stroke that earned the charge - or, landing on
## full, the max sound at each of [member max_pitches] at once.
func _play_layer(full: bool) -> void:
	if _sounds == null:
		return
	if full:
		var stream := max_sound if max_sound != null else layer_sound
		for pitch: float in max_pitches:
			_play_on_echo(stream, max_volume_db, pitch)
		var cue := _sounds.play_stream(pierce_cue_sound, pierce_cue_volume_db)
		if cue != null:
			cue.pitch_scale = maxf(pierce_cue_pitch, 0.01)
			_sounds.fade_tail(cue)
		return
	_play_on_echo(layer_sound,
		layer_volume_db + layer_volume_per_charge_db * (_charge - 1),
		layer_pitch + layer_pitch_per_charge * (_charge - 1))


func _play_on_echo(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var voice := _sounds.play_stream(stream, volume_db)
	if voice == null:
		return
	voice.pitch_scale = maxf(pitch, 0.01)
	if _echo_bus_index() >= 0:
		voice.bus = echo_bus
	_sounds.fade_tail(voice)


## One burst from the muzzle, thinned to [param ratio] of its particles and grown
## by [param size]. Added to the running scene so it stays where it was thrown.
## [param scene] is [member burst_scene] unless another is handed in.
func _spawn_burst(ratio: float, size: float, scene: PackedScene = burst_scene) -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	if scene == null or _muzzle == null or container == null:
		return
	var burst := scene.instantiate() as CPUParticles2D
	if burst == null:
		return
	burst.amount = maxi(roundi(burst.amount * lerpf(burst_min_ratio, 1.0, ratio)), 1)
	burst.scale_amount_min *= size
	burst.scale_amount_max *= size
	burst.initial_velocity_min *= size
	burst.initial_velocity_max *= size
	container.add_child(burst)
	burst.global_position = _muzzle.global_position
	burst.global_rotation = _muzzle.global_rotation
	burst.reset_physics_interpolation()
	if burst.has_method(&"play"):
		burst.play()
	else:
		burst.emitting = true


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera


func _get_screen_flash() -> ScreenFlash:
	if _screen_flash == null or not is_instance_valid(_screen_flash):
		_screen_flash = ScreenFlash.get_active(self)
	return _screen_flash
