class_name PlayerDamageFeedback
extends Node
## Everything the player *feels* when they get hit: the sound, the red slam over
## the screen, the momentary freeze, and the camera punching in.
##
## Like [HitReaction] it is driven by a [Health] component rather than by
## whatever dealt the damage, so anything that can hurt the player gets the whole
## reaction for free. It writes to no one: the sound goes through the player's
## own [SoundBank], the flash through the shared [ScreenFlash], and the zoom is
## *requested* from [CameraController], which owns its own transform and always
## drives itself back to rest. There is no second camera and no second flash.
##
## Health's own grace window means this cannot fire twice for one contact - a hit
## inside the window never emits [signal Health.damaged] at all.
##
## The freeze is a real time-scale stop, which is why its timer is created with
## `ignore_time_scale` - a timer running on scaled time while time is stopped
## would never tick, and the game would hang frozen forever.

## Health whose hits are reacted to.
@export var health_path: NodePath = ^"../Health"
## Bank the impact sound is played through.
@export var sound_bank_path: NodePath = ^"../Sounds"
## Name of the impact sound in that bank.
@export var damage_sound: StringName = &"hurt"

@export_group("Red flash")
@export var flash_colour := Color(0.78, 0.03, 0.05)
## Alpha at the instant of impact. High on purpose - this is a slam, and it is
## gone again before it can read as a tint.
@export_range(0.0, 1.0) var flash_peak: float = 0.62
## How long it sits at full strength. This is the "freeze frame" part of the
## look, so it is held for the length of the freeze rather than fading at once.
@export var flash_hold: float = 0.05
@export var flash_fade: float = 0.22

@export_group("Freeze")
## Stops time dead for this long at the moment of impact, which is what turns the
## red flash into a hit-stop rather than a tint. 0 disables it.
@export var freeze_time: float = 0.07
## Time scale during the freeze. 0 is a full stop.
@export_range(0.0, 1.0) var freeze_time_scale: float = 0.0

@export_group("Camera")
## Zoom multiplier at the moment of impact. 1.5 is half again as close.
@export var zoom_multiplier: float = 1.5
## How long the camera takes to punch in. Near-instant by design.
@export var zoom_in_time: float = 0.04
## How long the impact zoom is held before easing back out.
@export var zoom_hold_time: float = 1.2
## How long the return to the normal zoom takes.
@export var zoom_return_time: float = 0.55
## Shake thrown in with the hit. 0 disables it.
@export var shake_strength: float = 16.0
@export var shake_duration: float = 0.22
## Small turn thrown in with the hit, in degrees. 0 disables it.
@export var rotation_degrees_kick: float = 0.0
@export var rotation_out_time: float = 0.05
@export var rotation_return_time: float = 0.4

@export_group("Camera channel")
## Layer on [CameraController] this reaction writes to.
##
## Its own channel is what makes taking damage survive being shot at the same
## moment: the shotgun writes to a different one, the two are summed, and neither
## can restart or cancel the other. Before this existed both wrote to the same
## value and a shot fired a frame after a hit wiped the hit's zoom out entirely.
@export var camera_channel: StringName = &"damage"
## How loudly it speaks against the other channels. Above the weapon's, so a shot
## landing during the hit reaction is felt underneath it rather than over it -
## see [member CameraController.low_priority_scale].
@export var camera_priority: int = 100

@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank

var _flash: ScreenFlash
var _camera: CameraController
var _freezing: bool = false


func _ready() -> void:
	if _health != null:
		_health.damaged.connect(_on_damaged)


func _on_damaged(_amount: float, _hit_direction: Vector2) -> void:
	if _sounds != null:
		_sounds.play(damage_sound)

	var flash := _get_screen_flash()
	if flash != null:
		flash.flash(flash_colour, flash_peak, flash_hold, flash_fade)

	_punch_camera()
	_freeze()


## The same shared flash the shotgun uses, found by group. Looked up lazily so
## the HUD is free to enter the tree after the player does.
func _get_screen_flash() -> ScreenFlash:
	if _flash == null or not is_instance_valid(_flash):
		_flash = ScreenFlash.get_active(self)
	return _flash


## Zoom in hard, hold, then ease home. The hold is its own step rather than a
## long ease, so the camera sits at the impact zoom for a readable beat instead
## of immediately drifting back out of it.
func _punch_camera() -> void:
	var camera := _get_camera()
	if camera == null:
		return

	# The controller works in *extra* zoom as a fraction, so 1.5x is +0.5.
	var amount := zoom_multiplier - 1.0
	camera.zoom_impulse([
		Vector2(amount, zoom_in_time),
		Vector2(amount, zoom_hold_time),
		Vector2(0.0, zoom_return_time),
	], camera_channel, camera_priority)

	if not is_zero_approx(rotation_degrees_kick):
		camera.rotation_kick(
			rotation_degrees_kick, rotation_out_time, rotation_return_time,
			camera_channel, camera_priority)

	if shake_strength > 0.0:
		camera.shake(shake_strength, shake_duration)


## Guarded against overlapping freezes: a second hit during one would otherwise
## restore the time scale early and leave the first freeze's timer to set it
## again, which can strand the game at the frozen scale.
func _freeze() -> void:
	if freeze_time <= 0.0 or _freezing:
		return

	_freezing = true
	Engine.time_scale = freeze_time_scale
	# ignore_time_scale is the whole reason this works: with time stopped, a
	# normal timer would never reach its timeout.
	var timer := get_tree().create_timer(freeze_time, true, false, true)
	timer.timeout.connect(_end_freeze)


func _end_freeze() -> void:
	Engine.time_scale = 1.0
	_freezing = false


## Restored on the way out too, so a scene reload part way through a freeze can
## never leave the next run running in slow motion.
func _exit_tree() -> void:
	if _freezing:
		_end_freeze()


## Looked up lazily and re-looked-up if the camera goes away, matching how
## [ShotgunFeedback] finds it.
func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
