class_name RecoilDevilFeedback
extends Node
## What a RECOIL DEVIL shot adds on top of an ordinary one. The ordinary shot's
## blast, flash, kick and sound are still all [ShotgunFeedback]'s and are left
## exactly as they are; this only layers on.
##
## [b]It owns nothing of the shove.[/b] The weapon hands the push to the holder's
## [PlayerRecoil] and announces [code]recoil_kicked[/code] - once per shot, never
## per pellet - and this answers with:
##
##   * a heavier kick of the artwork and a bigger burst at the muzzle;
##   * a [PressureWave] at the holder's feet, thrown the way they are pushed, with
##     the dust it kicks up;
##   * a harder shake, a zoom thrown out, a turn of the view against the way the
##     player is moving and a short shove of the camera, on a channel of its own so
##     chained shots blend into one another rather than cutting each other off;
##   * the blast and echo layers, through the weapon's own [SoundBank] on voices of
##     their own with the bank's tail fade, so they overlap freely.
##
## Everything scales off how hard the shot actually kicked against the
## Legendary's authored impulse - see [method ShotRecoil.strength_for] - so a
## pellet upgrade is seen and felt as well as pushed.
##
## A shotgun without an active [ShotRecoil] never sends the signal, so none of
## this ever wakes up with the Legendary off.

## The weapon whose recoil is followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## The weapon's own feedback, whose kick is scaled.
@export var shotgun_feedback_path: NodePath = ^"../Feedback"
## Bank the layers are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"
## Where the muzzle burst is thrown from.
@export var muzzle_path: NodePath = ^"../MuzzleRig/Muzzle"

@export_group("Weapon")
## What the artwork's kick is multiplied by on a recoil shot.
@export var recoil_scale: float = 1.5
## Extra burst thrown from the muzzle, on top of the ordinary flash. Empty throws
## none.
@export var muzzle_burst_scene: PackedScene
## Its particle size and speed against the scene as authored.
@export var muzzle_burst_size: float = 1.7
@export var muzzle_burst_speed: float = 1.25

@export_group("Pressure wave")
## The wave left at the holder's feet. Empty leaves none.
@export var wave_scene: PackedScene
## How far from the holder's origin it is set down, in pixels, towards where the
## weapon points - the side the blast came from. Y is up and down.
@export var wave_offset := Vector2(-14.0, -6.0)

@export_group("Camera")
## Master strength for every camera value below. Amplitudes only, never times.
@export var camera_scale: float = 1.0
## How much of a harder- or softer-than-authored kick shows in the camera.
## strength = (push / impulse) ^ this.
@export_range(0.0, 2.0, 0.01) var camera_push_influence: float = 0.7
## Shake, in pixels. The camera keeps the stronger of two shakes, so this has to
## be above the ordinary shot's own 24 to be felt as stronger.
@export var shake_strength: float = 36.0
@export var shake_duration: float = 0.17
## Zoom punch, as a fraction. Negative throws the view out.
@export var zoom_punch: float = -0.06
@export var zoom_out_time: float = 0.035
@export var zoom_back_time: float = 0.26
## Turn of the view, in degrees, against the way the player is thrown - pushed
## left, the view turns right. Scaled by how sideways the push is, never below
## [member rotation_min_share] of it, so a push straight up or down still turns.
@export var rotation_degrees: float = 1.6
@export_range(0.0, 1.0, 0.01) var rotation_min_share: float = 0.35
@export var rotation_out_time: float = 0.04
@export var rotation_back_time: float = 0.3
## Shove of the view along the push, in pixels. Negative shoves it the other way.
@export var kick_distance: float = 16.0
@export var kick_out_time: float = 0.04
@export var kick_back_time: float = 0.24
## Layer on [CameraController] these are written to, and how loudly.
@export var camera_channel: StringName = &"weapon_recoil"
@export var camera_priority: int = 0

@export_group("Audio")
## The pressure-wave blast, over the ordinary shot. Empty plays none.
@export var blast_layer_sound: AudioStream
@export var blast_layer_volume_db: float = -4.0
@export var blast_layer_pitch: float = 1.0
## The echo that follows it. Empty plays none.
@export var echo_layer_sound: AudioStream
@export var echo_layer_volume_db: float = -8.0
@export var echo_layer_pitch: float = 1.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _shotgun_feedback: ShotgunFeedback = get_node_or_null(shotgun_feedback_path) as ShotgunFeedback
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D

var _camera: CameraController


func _ready() -> void:
	if _source != null and _source.has_signal(&"recoil_kicked"):
		_source.connect(&"recoil_kicked", _on_recoil_kicked)


## Sent once per shot, after the shot's own [code]fired[/code] has been handled.
func _on_recoil_kicked(push: Vector2, holder: Node2D) -> void:
	var strength := _strength_of(push)
	_kick_art()
	_spawn_muzzle_burst()
	_spawn_wave(push, holder, strength)
	_play(blast_layer_sound, blast_layer_volume_db, blast_layer_pitch)
	_play(echo_layer_sound, echo_layer_volume_db, echo_layer_pitch)
	_punch_camera(push, strength)


## How hard this shot kicked against the Legendary's authored impulse.
func _strength_of(push: Vector2) -> float:
	var stats: WeaponStats = null
	if _source != null and _source.has_method(&"get_stats"):
		stats = _source.call(&"get_stats") as WeaponStats
	var recoil: ShotRecoil = null if stats == null else stats.shot_recoil
	if recoil == null or recoil.recoil_impulse <= 0.0:
		return 1.0
	return push.length() / recoil.recoil_impulse


## The ordinary kick run again at the heavier scale, on top of any a fanned shot
## already has - see [method ShotgunFeedback.kick_recoil].
func _kick_art() -> void:
	if _shotgun_feedback != null and not is_equal_approx(recoil_scale, 1.0):
		_shotgun_feedback.kick_recoil(recoil_scale)


func _spawn_muzzle_burst() -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	if muzzle_burst_scene == null or _muzzle == null or container == null:
		return
	var burst := muzzle_burst_scene.instantiate() as CPUParticles2D
	if burst == null:
		return
	burst.scale_amount_min *= muzzle_burst_size
	burst.scale_amount_max *= muzzle_burst_size
	burst.initial_velocity_min *= muzzle_burst_speed
	burst.initial_velocity_max *= muzzle_burst_speed
	container.add_child(burst)
	burst.global_position = _muzzle.global_position
	burst.global_rotation = _muzzle.global_rotation
	burst.reset_physics_interpolation()
	if burst.has_method(&"play"):
		burst.call(&"play")
	else:
		burst.emitting = true


## Set down at the holder's feet on the blast's side, bulging the way they are
## thrown.
func _spawn_wave(push: Vector2, holder: Node2D, strength: float) -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	if wave_scene == null or holder == null or container == null or push.is_zero_approx():
		return
	var wave := wave_scene.instantiate() as Node2D
	if wave == null:
		return
	var direction := push.normalized()
	container.add_child(wave)
	wave.global_position = holder.global_position \
		+ direction * wave_offset.x + Vector2(0.0, wave_offset.y)
	wave.global_rotation = direction.angle()
	wave.reset_physics_interpolation()
	if wave.has_method(&"play"):
		wave.call(&"play", strength)


func _punch_camera(push: Vector2, strength: float) -> void:
	var camera := _get_camera()
	if camera == null or push.is_zero_approx():
		return
	var scale := camera_scale * pow(maxf(strength, 0.0), camera_push_influence)
	var direction := push.normalized()
	if shake_strength > 0.0:
		camera.shake(shake_strength * scale, shake_duration)
	if not is_zero_approx(zoom_punch):
		camera.zoom_kick(zoom_punch * scale, zoom_out_time, zoom_back_time,
			camera_channel, camera_priority)
	if not is_zero_approx(rotation_degrees):
		var side := -direction.x
		if absf(side) < rotation_min_share:
			side = rotation_min_share * (-1.0 if side < 0.0 else 1.0)
		camera.rotation_kick(rotation_degrees * scale * side, rotation_out_time,
			rotation_back_time, camera_channel, camera_priority)
	if not is_zero_approx(kick_distance):
		camera.offset_kick(direction * kick_distance * scale, kick_out_time, kick_back_time,
			camera_channel, camera_priority)


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
