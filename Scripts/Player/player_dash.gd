class_name PlayerDash
extends Node
## The player's dash: a short, violent burst forward the way they are already
## moving, over almost as fast as it began.
##
## [b]It does not take movement over, it is added to it.[/b] The player's own
## walk is worked out exactly as it always was in [Player] and handed here; this
## returns that velocity with the launch added on top - see
## [method apply_dash_velocity]. The launch decays to nothing across the dash
## while the player's own input is eased back to full, so the dash ends by
## simply no longer contributing and the character is already walking again on
## the frame it lands. There is no state to leave them stuck in and nothing to
## switch off if the dash is interrupted.
##
## [b]It is a shove, not a jump.[/b] Nothing is lifted off the ground and nothing
## is rotated: the character does not rise, hang and land, because an arc through
## the air is read as a hop however short it is, and this is meant to read as
## being thrown. What sells the speed instead is everything arriving at once -
## the launch fronted hard into its first moments, the camera left behind and
## then punched, the fire off the horns and the trail burning out behind. The
## only thing written to the artwork is a small backward drag along the dash
## direction, so the character is seen being pulled out from under their own
## drawing rather than leaving the floor. It is written to the
## [code]Visual[/code] node's own [code]position[/code] alone, which is why it
## does not fight the squash idle (that animates [code]Visual:scale[/code]), the
## leg swing, the head's soft follow, or the shadow underneath, which is
## projected from the body's ground position rather than from the artwork.
##
## [b]Everything it triggers is an existing system asked to do its own job.[/b]
## The horn flare is the same [OneShotParticles] burst the muzzle flash is,
## spawned into the running scene the same way; the shake and the zoom are
## [CameraController]'s own [method CameraController.shake] and
## [method CameraController.zoom_kick], on a channel of the dash's own so they
## layer with a hit reaction or a shot rather than fighting one; the camera lag
## is that same camera's cinematic follow pointed at a marker left behind at the
## launch; the grain burst is [method FilmPostProcess.grain_burst], laid down
## inside the film pass that was already there. Nothing here draws, films or
## moves a camera itself.
##
## [b]What stops a dash is asked for rather than listed here.[/b] A dash is
## refused whenever the player cannot move under their own power - a death, a
## sleep, an extraction hold, a travel hold - and that is one question,
## [method Player.get_current_speed], rather than a list of components this would
## have to be told about every time another one is added.

## Emitted the instant a dash launches, with the unit direction it went in. The
## door a sound, a stamina cost or a later upgrade knocks on without this having
## to know they exist.
signal dashed(direction: Vector2)

@export_group("Trigger")
## Input action used when the project defines one. Left as it is, the dash simply
## falls back to [member dash_key], so nothing has to be added to the input map
## for Shift to work - and adding a [code]dash[/code] action later takes over
## automatically, rebinding and all.
@export var dash_action: StringName = &"dash"
## Key the dash is read from while no [member dash_action] exists. Read by
## physical position, so it is Shift wherever Shift physically is on the keyboard.
@export var dash_key: Key = KEY_SHIFT
## Shortest gap between two dashes, in seconds.
@export var dash_cooldown: float = 0.55
## The body being dashed, and the one asked whether it is able to move at all.
@export var body_path: NodePath = ^".."
## Read for which way the character is looking when a dash is asked for while
## standing perfectly still with no direction to go on. Optional.
@export var facing_path: NodePath = ^"../FacingFlip"
## Asked whether the player is currently mounted, so a dash cannot be thrown
## while riding. Anything with a [code]player_on_horse[/code] property works
## here; an empty path drops the check entirely.
@export var mount_path: NodePath = ^"../WorldMapHorse"
## Speed at or below which the player counts as being held still by something
## else, and a dash is refused.
@export var held_still_speed: float = 1.0

@export_group("Launch")
## Roughly how far forward the burst carries the player, in pixels, on top of
## whatever they were already walking. Kept short on purpose - the dash is meant
## to read as violent, not as a long travel move.
@export var dash_distance: float = 190.0
## How long the burst lasts, in seconds. The drag, the trail and the return of
## control all run across this same window. Short: most of the ground is covered
## in the first few frames, which is the whole of the feeling.
@export var dash_duration: float = 0.2
## How sharply the burst decays across that window. 0 is a flat shove that ends
## abruptly, higher fronts the speed into the first moments and eases out of it.
## High on purpose - it is what makes a short distance feel like a hard throw.
## The peak speed is worked back out from this and [member dash_distance], so
## changing it changes how the dash feels without changing how far it goes.
@export var dash_falloff: float = 3.0
## How much of the player's own walking input still counts at the start of the
## dash, eased back to all of it by the time it is over. Low is the moment of
## being committed to the burst; 1 leaves them in full control throughout.
@export_range(0.0, 1.0) var air_control: float = 0.25

@export_group("Drag")
## The character's artwork - never the body, so the collision shape, the shadow
## and everything measured from where the player actually is stay put.
@export var visual_path: NodePath = ^"../Visual"
## How far the artwork is dragged back along the dash direction at the peak of
## the burst, in pixels, easing back to nothing as it ends. This is the character
## being pulled out from under their own drawing - deliberately small, and never
## an arc: 0 turns it off entirely.
@export var visual_drag: float = 5.0

@export_group("Horn flare")
## The burst thrown from each horn as the dash launches. The same one-shot
## particle effect the muzzle flash is - see [OneShotParticles].
@export var flare_scene: PackedScene
## Where the flares come from. One burst is spawned at each, so adding a third
## horn is dropping a marker in the Inspector.
@export var flare_point_paths: Array[NodePath] = [
	^"../Visual/Head/LeftHornTip",
	^"../Visual/Head/RightHornTip",
]
## Size of each burst, against the size the effect was authored at.
@export var flare_scale: float = 1.0

@export_group("Fire trail")
## The fire burning off the character for as long as the burst lasts, left
## behind them and going out almost immediately - see the [code]DashTrail[/code]
## particles on the player. Emission is switched on at the launch and off the
## moment it ends; how long a spark then survives, and how fast it fades, are
## the effect's own authored values in the Inspector rather than anything
## decided here.
@export var trail_path: NodePath = ^"../DashTrail"

@export_group("Camera")
## How long the camera is left standing where the dash started before it comes
## after the player. This is the whole of the lag: the character is gone before
## the view has reacted.
@export var camera_hold_time: float = 0.15
## How hard the camera is held on that spot while it waits. High on purpose -
## this is meant to read as the camera not having moved yet, not as it drifting.
@export var camera_lock_speed: float = 30.0
## How quickly it then catches up. Lower drifts back onto the player, higher
## snaps.
@export var camera_catch_up_speed: float = 7.0
## How hard the view is knocked as the burst leaves, in pixels. Strong, and over
## almost at once - see [member camera_shake_time] - so it lands as an impact
## rather than as a wobble. 0 dashes without shaking the camera.
@export var camera_shake_strength: float = 9.0
## How long that knock takes to die away, in seconds. Very short on purpose.
@export var camera_shake_time: float = 0.12
## How far the view is pulled in across the dash, as a fraction: 0.06 is 6%
## closer. It comes home by itself afterwards - the camera returns every impulse
## to whatever resting zoom the place asked for - so this can never leave the
## view zoomed.
@export var camera_zoom_amount: float = 0.06
## How quickly the view pulls in.
@export var camera_zoom_in_time: float = 0.07
## How long it then takes to ease back out to the resting zoom.
@export var camera_zoom_out_time: float = 0.28
## Channel the shake and zoom are written to, and how loudly they speak against
## anything else moving the camera. A hit reaction is louder, so being shot mid
## dash still reads as being shot - see [CameraController].
@export var camera_channel: StringName = &"dash"
@export var camera_priority: int = 1

@export_group("Sound")
## The dash's own [SoundBank]. Which recording is heard, how loud it is, which
## bus it goes to and how far its pitch is allowed to wander are all its fields
## in the Inspector - nothing about the sound is decided here beyond when it
## starts. An empty path, or a bank without [member dash_sound] in it, dashes
## silently.
@export var sound_bank_path: NodePath = ^"DashSounds"
## Name the dash is registered under in that bank.
@export var dash_sound: StringName = &"dash"

@export_group("Grain burst")
## How long the film's grain burst lasts, in seconds. Below 0 leaves the length
## to [member FilmPostProcess.default_grain_burst_time].
@export var grain_burst_seconds: float = 0.3
## How loud that burst is. 0 dashes without touching the film at all.
@export var grain_burst_strength: float = 1.0

@onready var _body: CharacterBody2D = get_node_or_null(body_path) as CharacterBody2D
@onready var _visual: Node2D = get_node_or_null(visual_path) as Node2D
@onready var _facing: Node = get_node_or_null(facing_path)
@onready var _mount: Node = get_node_or_null(mount_path)
@onready var _trail: CPUParticles2D = get_node_or_null(trail_path) as CPUParticles2D
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank

var _flare_points: Array[Node2D] = []
var _visual_rest: Vector2 = Vector2.ZERO

var _active: bool = false
var _elapsed: float = 0.0
var _cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _last_direction: Vector2 = Vector2.RIGHT
var _peak_speed: float = 0.0
var _key_down: bool = false

var _camera_anchor: Node2D
var _camera_hold_left: float = 0.0


func _ready() -> void:
	# Driven entirely from the body's own physics step - see
	# [method apply_dash_velocity] - so the launch, the drag and the timer can
	# never be a frame apart from the movement they belong to.
	set_physics_process(false)

	if _visual != null:
		_visual_rest = _visual.position

	# The trail burns only while a dash is in the air, so it starts cold however
	# the effect was left in the scene.
	if _trail != null:
		_trail.emitting = false

	for path: NodePath in flare_point_paths:
		var point := get_node_or_null(path) as Node2D
		if point != null:
			_flare_points.append(point)


func _exit_tree() -> void:
	_release_camera()


## The player's walk with the dash folded into it. Called once per physics frame
## from [Player], which is also what advances the dash - so a body that has not
## been wired to this simply never dashes, rather than dashing invisibly.
func apply_dash_velocity(walk_velocity: Vector2, delta: float) -> Vector2:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_advance_camera(delta)

	# Read every frame, and before anything can refuse the dash, so releasing and
	# pressing again during a cooldown is still a fresh press afterwards.
	var pressed := _read_press()
	if pressed and not _active and _can_dash():
		dash()

	if not _active:
		return walk_velocity

	_elapsed += delta
	var u := clampf(_elapsed / maxf(dash_duration, 0.0001), 0.0, 1.0)
	_apply_drag(u)

	if u >= 1.0:
		_settle()
		return walk_velocity

	var launch := _dash_direction * _peak_speed * pow(1.0 - u, maxf(dash_falloff, 0.0))
	return walk_velocity * lerpf(clampf(air_control, 0.0, 1.0), 1.0, u) + launch


## Launches a dash now, whatever the input is doing. [param direction] left at
## zero uses the direction the player is currently moving or looking. The one
## door another system - a scripted moment, a later upgrade - can dash them
## through.
func dash(direction: Vector2 = Vector2.ZERO) -> void:
	var heading := direction if not direction.is_zero_approx() else _pick_direction()
	if heading.is_zero_approx():
		return

	_active = true
	_elapsed = 0.0
	_dash_direction = heading.normalized()
	_last_direction = _dash_direction
	_cooldown_left = maxf(dash_cooldown, 0.0)
	# Worked back out from the distance so the falloff shapes the launch without
	# also deciding how far it carries: the area under the curve is the distance.
	_peak_speed = maxf(dash_distance, 0.0) \
		* (maxf(dash_falloff, 0.0) + 1.0) / maxf(dash_duration, 0.0001)

	# First, so the noise lands on the same frame as the shove rather than after
	# everything else it sets off has been built.
	_play_dash_sound()
	_spawn_horn_flares()
	_start_trail()
	_hold_camera()
	_punch_camera()
	_burst_grain()
	dashed.emit(_dash_direction)


## Whether a launch is in the air right now.
func is_dashing() -> bool:
	return _active


## The direction of the dash in flight, or of the last one thrown.
func get_dash_direction() -> Vector2:
	return _dash_direction


## How far through the launch it is, 0 to 1. 0 whenever nothing is in the air.
func get_dash_progress() -> float:
	if not _active:
		return 0.0
	return clampf(_elapsed / maxf(dash_duration, 0.0001), 0.0, 1.0)


## Whether the dash is off cooldown and nothing is holding the player.
func _can_dash() -> bool:
	if _cooldown_left > 0.0:
		return false
	# One question rather than a list: anything that pins the player answers it
	# by pinning their speed, which is what every hold in the scene already does.
	if _body != null and _body.has_method(&"get_current_speed") \
			and float(_body.call(&"get_current_speed")) <= held_still_speed:
		return false
	if _mount != null and bool(_mount.get(&"player_on_horse")):
		return false
	return true


## The action if the project has one, the raw physical key otherwise. The key's
## own edge is tracked here because a modifier held down is not a press.
func _read_press() -> bool:
	if dash_action != &"" and InputMap.has_action(dash_action):
		return Input.is_action_just_pressed(dash_action)

	var down := Input.is_physical_key_pressed(dash_key)
	var edge := down and not _key_down
	_key_down = down
	return edge


## Where they are going: what they are steering, then what they are moving at,
## then - standing perfectly still - the way they are looking.
func _pick_direction() -> Vector2:
	var steer := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if not steer.is_zero_approx():
		_last_direction = steer.normalized()
		return _last_direction

	if _body != null and not _body.velocity.is_zero_approx():
		_last_direction = _body.velocity.normalized()
		return _last_direction

	if _facing != null:
		var facing := float(_facing.get(&"facing"))
		if not is_zero_approx(facing):
			_last_direction = Vector2(signf(facing), 0.0)

	return _last_direction


## The backward drag, written to the artwork alone.
##
## It follows the launch's own decay rather than a shape of its own, so the
## drawing is furthest behind exactly when the player is moving fastest and is
## back on its mark the instant the burst is spent. There is no rise and no fall
## in it anywhere - a dash is a shove, and an arc would read as a hop however
## small it was made.
func _apply_drag(u: float) -> void:
	if _visual == null:
		return
	var pull := pow(1.0 - clampf(u, 0.0, 1.0), maxf(dash_falloff, 0.0))
	_visual.position = _visual_rest - _dash_direction * maxf(visual_drag, 0.0) * pull


func _settle() -> void:
	_active = false
	_elapsed = 0.0
	if _visual != null:
		_visual.position = _visual_rest
	_stop_trail()


## One burst per horn, thrown backwards out of them - the fire is what launches
## the character, so it leaves the way they came from.
##
## Spawned into the running scene rather than parented to the horns, exactly as
## the muzzle flash is: the head sits at a fraction of a scale and is mirrored by
## [FacingFlip], so a burst hanging off it would be shrunk to nothing and dragged
## around after it had gone off.
func _spawn_horn_flares() -> void:
	if flare_scene == null or _flare_points.is_empty():
		return

	var container := get_tree().current_scene
	if container == null:
		return

	var angle := (-_dash_direction).angle()
	for point: Node2D in _flare_points:
		var flare := flare_scene.instantiate() as Node2D
		if flare == null:
			continue
		container.add_child(flare)
		flare.global_position = point.global_position
		flare.global_rotation = angle
		flare.scale = Vector2.ONE * maxf(flare_scale, 0.01)
		flare.reset_physics_interpolation()
		# Started only once it is standing on the horn: these bursts emit in
		# global particle space, so wherever the node is the instant emission
		# begins is where the fire is stamped.
		if flare.has_method(&"play"):
			flare.play()
		elif flare is CPUParticles2D:
			(flare as CPUParticles2D).emitting = true


## The dash going off, through the bank's own pooled voices.
##
## [b]The pitch wander is the bank's, not the dash's.[/b] [SoundBank] already
## rolls a fresh pitch for every playback out of its own
## [member SoundBank.pitch_variation], which is what keeps a repeated sound from
## being mechanically identical - the same spread the player's hurt sound is
## already heard through. Rolling one here as well would be a second, competing
## answer to a question the bank has already settled.
func _play_dash_sound() -> void:
	if _sounds == null:
		return
	_sounds.play(dash_sound)


## Lights the fire trailing off the character. It burns for exactly as long as
## the burst does and no longer - what is already in the air keeps burning out
## behind them on its own, which is what leaves a trail rather than a plume
## hanging off the player.
func _start_trail() -> void:
	if _trail == null:
		return
	_trail.restart()
	_trail.emitting = true


func _stop_trail() -> void:
	if _trail != null:
		_trail.emitting = false


## The knock and the pull-in, both asked of the camera on the dash's own channel
## so they layer with whatever else is moving the view instead of replacing it.
## Neither is ever driven home from here: the camera returns every impulse to
## the resting zoom the place asked for, so a dash cannot leave the view punched
## or zoomed even if the player is killed mid-burst.
func _punch_camera() -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	if camera_shake_strength > 0.0 and camera_shake_time > 0.0:
		camera.shake(camera_shake_strength, camera_shake_time)

	if not is_zero_approx(camera_zoom_amount):
		camera.zoom_kick(
			camera_zoom_amount,
			maxf(camera_zoom_in_time, 0.0001),
			maxf(camera_zoom_out_time, 0.0001),
			camera_channel,
			camera_priority)


## Leaves the camera standing where the launch began, by handing
## [CameraController] a marker at that spot to look at and taking it away again
## once the hold is up - so the catch-up is the camera's own release easing
## rather than a second way of moving it.
##
## A view something louder already owns - a coin in flight, a boss, a death - is
## left alone entirely. A dash is not worth interrupting a cinematic for.
func _hold_camera() -> void:
	if camera_hold_time <= 0.0 or _body == null:
		return

	var camera := CameraController.get_active(self)
	if camera == null or camera.get_follow_subject() != null:
		return

	var container := get_tree().current_scene
	if container == null:
		return

	_release_camera()
	_camera_anchor = Node2D.new()
	_camera_anchor.name = "DashCameraAnchor"
	container.add_child(_camera_anchor)
	# Where the camera is looking right now, not where the player is: the camera
	# rests above them, and centring it on the body itself would drop the view by
	# exactly that much on the first frame of every dash.
	_camera_anchor.global_position = camera.global_position
	camera.follow(_camera_anchor, camera_lock_speed)
	_camera_hold_left = camera_hold_time


func _advance_camera(delta: float) -> void:
	if _camera_anchor == null:
		return
	_camera_hold_left -= delta
	if _camera_hold_left <= 0.0:
		_release_camera()


func _release_camera() -> void:
	if _camera_anchor == null:
		return

	var camera := CameraController.get_active(self)
	# Only if it is still ours: something louder may have taken the view during
	# the hold, and releasing then would be stealing it back.
	if camera != null and camera.get_follow_subject() == _camera_anchor:
		camera.release_follow(camera_catch_up_speed)

	# The marker lives in the running scene, so a scene change can have taken it
	# already by the time the dash is cleaned up.
	if is_instance_valid(_camera_anchor):
		_camera_anchor.queue_free()
	_camera_anchor = null


func _burst_grain() -> void:
	if grain_burst_strength <= 0.0:
		return
	var film := FilmPostProcess.get_active(self)
	if film == null:
		return
	film.grain_burst(grain_burst_seconds, grain_burst_strength)
