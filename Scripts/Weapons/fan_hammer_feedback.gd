class_name FanHammerFeedback
extends Node
## What a fanned shot adds on top of an ordinary one - the shotgun's Legendary FAN
## THE HAMMER. The ordinary shot's blast, flash, kick and sound are still all
## [ShotgunFeedback]'s and are left exactly as they are; this only layers on.
##
## [b]It owns nothing of the pump or the shot.[/b] The weapon announces
## [code]fan_pumped[/code] and [code]fanned_shot[/code] - see [FanHammer] - and
## this answers with:
##
##   * a heavier kick of the artwork, through [member ShotgunFeedback.recoil_scale]
##     for that one shot, growing with the heat;
##   * a small shake, zoom punch and turn of the camera on a channel of its own, so
##     rapid shots run into one another and into the ordinary shot's own kick
##     rather than cutting them off;
##   * a lower-pitched layer of the shot and an optional chambering layer on the
##     fanned stroke, played through the weapon's own [SoundBank] - one per shot or
##     stroke, never per pellet, on separate voices so they can overlap.
##
## A shotgun without an active [FanHammer] never sends either signal, so none of
## this ever wakes up with the Legendary off.

## The weapon whose fanning is followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## The weapon's own feedback, whose kick is scaled.
@export var shotgun_feedback_path: NodePath = ^"../Feedback"
## Bank the layers are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Recoil")
## What the artwork's kick is multiplied by on a fanned shot, at no heat and at
## full heat.
@export var recoil_scale_min: float = 1.25
@export var recoil_scale_max: float = 1.6

@export_group("Camera")
## Master strength for every camera value below. Amplitudes only, never times.
@export var camera_scale: float = 1.0
## Shake of a fanned shot, in pixels. The camera keeps the stronger of two shakes
## rather than adding them, so this only shows where it is above the ordinary
## shot's own.
@export var shake_strength: float = 27.0
@export var shake_duration: float = 0.12
## Zoom punch of a fanned shot, as a fraction. Negative throws the view out.
@export var zoom_punch: float = -0.035
@export var zoom_out_time: float = 0.03
@export var zoom_back_time: float = 0.14
## Turn of a fanned shot, in degrees. Its side alternates shot to shot, so a
## string of them rocks the view rather than winding it one way.
@export var rotation_degrees: float = 1.1
@export var rotation_out_time: float = 0.03
@export var rotation_back_time: float = 0.16
## How much more of all three a fanned shot at full heat gets. 0.3 is 30% more.
@export var heat_camera_boost: float = 0.3
## Layer on [CameraController] these are written to, and how loudly.
@export var camera_channel: StringName = &"weapon_fan"
@export var camera_priority: int = 0

@export_group("Audio")
## Second layer of the shot, under the ordinary blast. Empty plays none.
@export var fire_layer_sound: AudioStream
@export var fire_layer_volume_db: float = -7.0
## Its pitch - below 1, so the layer sits under the ordinary shot.
@export var fire_layer_pitch: float = 0.86
## Played on each fanned stroke, over the pump's own two strokes. Empty plays none.
@export var pump_layer_sound: AudioStream
@export var pump_layer_volume_db: float = -5.0
@export var pump_layer_pitch: float = 1.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _shotgun_feedback: ShotgunFeedback = get_node_or_null(shotgun_feedback_path) as ShotgunFeedback
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank

var _camera: CameraController
var _side: float = 1.0


func _ready() -> void:
	if _source == null:
		return
	if _source.has_signal(&"fanned_shot"):
		_source.connect(&"fanned_shot", _on_fanned_shot)
	if _source.has_signal(&"fan_pumped"):
		_source.connect(&"fan_pumped", _on_fan_pumped)


func _exit_tree() -> void:
	if _shotgun_feedback != null:
		_shotgun_feedback.recoil_scale = 1.0


## Sent before the shot's own [code]fired[/code], so the kick is scaled for this
## shot and put back once the shot has been handled.
func _on_fanned_shot(heat: float) -> void:
	if _shotgun_feedback != null:
		_shotgun_feedback.recoil_scale = lerpf(recoil_scale_min, recoil_scale_max, heat)
		_reset_recoil.call_deferred()
	_play(fire_layer_sound, fire_layer_volume_db, fire_layer_pitch)

	var camera := _get_camera()
	if camera == null:
		return
	var strength := camera_scale * (1.0 + heat_camera_boost * clampf(heat, 0.0, 1.0))
	if shake_strength > 0.0:
		camera.shake(shake_strength * strength, shake_duration)
	if not is_zero_approx(zoom_punch):
		camera.zoom_kick(zoom_punch * strength, zoom_out_time, zoom_back_time,
			camera_channel, camera_priority)
	if not is_zero_approx(rotation_degrees):
		_side = -_side
		camera.rotation_kick(rotation_degrees * strength * _side, rotation_out_time,
			rotation_back_time, camera_channel, camera_priority)


func _on_fan_pumped() -> void:
	_play(pump_layer_sound, pump_layer_volume_db, pump_layer_pitch)


func _reset_recoil() -> void:
	if _shotgun_feedback != null:
		_shotgun_feedback.recoil_scale = 1.0


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if _sounds == null:
		return
	var voice := _sounds.play_stream(stream, volume_db)
	if voice != null:
		voice.pitch_scale *= maxf(pitch, 0.01)
		_sounds.fade_tail(voice)


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
