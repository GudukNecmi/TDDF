class_name Teleporter
extends Node
## The B escape: a snap of the fingers, the world falls silent, the camera pulls
## in, and the player is gone.
##
## The whole effect is built out of what already exists. The snap is a
## [SoundBank] one-shot played on the Snap bus, which carries the reverb and
## delay that give it its echo. The silence is an [AudioServer] bus mute on the
## Game bus, so every gameplay sound is *muted in place* - nothing is stopped,
## nothing is freed, and playback positions survive, so unmuting resumes them
## exactly where they were. The zoom is a [CameraController] impulse, the same
## call the shotgun and the damage feedback already use.
##
## The one thing that does change under the mute is the soundtrack: leaving the
## run is leaving the fight, so [MusicDirector] is asked to hand the arena track
## over to the base one while nothing can be heard. See
## [member drive_music].
##
## Where the player lands is not this node's business. It asks a
## [TeleportDestination] by id for its arrival point and its bounds, so adding
## somewhere new to go is a scene, not an edit here.
##
## The sequence is deliberately not instant: snap and silence land first, then
## the camera closes in, and only then does the body move. That gap is what makes
## it read as something happening rather than a position being assigned.

## Emitted once the body has actually been moved.
signal teleported(destination: TeleportDestination)
## Emitted when the world's audio comes back.
signal audio_restored

## Action that fires the teleport.
@export var action: StringName = &"teleport"
## Body that gets moved. Defaults to this component's parent.
@export var body_path: NodePath = ^".."
## Which [TeleportDestination] to send them to.
@export var destination_id: StringName = &"sanctum"
## Makes the key contextual: pressed while the body is already standing in the
## [RunPortal] it would otherwise travel to, it starts the next run instead of
## teleporting on the spot. Turn it off to always teleport.
##
## The portal is found by group rather than by path and is allowed not to exist,
## so a world without one behaves exactly as this always did.
@export var portal_starts_run: bool = true
## Bank the snap is played through. Its bus should be the reverberant one, so the
## echo survives the rest of the mix being muted.
@export var sound_bank_path: NodePath = ^"SnapSounds"
@export var snap_sound: StringName = &"snap"

@export_group("Timing")
## Gap between the snap and the body actually moving. The camera closes in across
## this, so it wants to be long enough to see.
@export var travel_time: float = 0.75
## How long the world stays silent after arrival before it fades back.
@export var silence_hold_time: float = 1.1
## Whether the game's audio comes back at all afterwards. Off leaves the arrival
## area silent, for when the destination gets its own ambience.
@export var restore_audio: bool = true

@export_group("Music")
## Whether leaving the run hands the soundtrack over to the base track: the arena
## music fades out and the base music fades up underneath it, so the player
## arrives home to the base's own soundtrack instead of the fight's.
##
## The handover is started as the journey does, under the bus mute, so none of the
## crossfade itself is heard - by the time the world comes back the base track is
## already the one playing. Which tracks those are, and how long they take to
## trade places, is [MusicDirector]'s business; this only says when.
##
## A body being carried home by the death sequence is deliberately left alone
## here: that sequence runs its own, longer handover at the moment the player is
## put back together, and two crossfades of the same pair of tracks would fight.
@export var drive_music: bool = true

@export_group("Camera")
## Zoom multiplier held during the transition.
@export var zoom_multiplier: float = 1.3
## How long the camera takes to reach it.
@export var zoom_in_time: float = 0.35
## How long it stays there after arrival before easing back out.
@export var zoom_hold_time: float = 0.45
@export var zoom_return_time: float = 0.6

@export_group("Audio buses")
## Bus carrying everything that should fall silent - music and gameplay sound.
@export var game_bus: StringName = &"Game"
## Whether the camera limits are moved to the destination's bounds on arrival.
@export var move_camera_limits: bool = true

@onready var _body: Node2D = get_node_or_null(body_path) as Node2D
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank

var _camera: CameraController
var _teleporting: bool = false


func is_teleporting() -> bool:
	return _teleporting


## Lets go of a transition that never actually happened.
##
## The one path out of [method teleport] that does not move anybody is the run
## portal branch: the press is handed to the portal and this node stands down
## expecting the world to be rebuilt underneath it. If the portal instead opens
## something the player can back out of, nothing would ever clear that expectation
## and the key would be dead for the rest of the visit. The portal calls this when
## that happens.
##
## Only the in-progress flag is touched. Nothing on this path muted the world,
## zoomed the camera or moved the body, so there is nothing else to undo.
func cancel() -> void:
	_teleporting = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action):
		teleport()


## Runs the whole sequence. Ignored while one is already under way, so mashing B
## cannot stack transitions or leave the world permanently muted.
##
## Standing in the run portal turns the same press into "start the next run".
## That branch is taken before anything else happens, and it deliberately still
## plays the snap: leaving for a run and stepping across the world are the same
## gesture, so they sound the same. Nothing is muted on this path - the world is
## about to be rebuilt, and a mute held across a scene reload would arrive in the
## new run still muted.
##
## [param silent] leaves the snap unplayed. The snap is the *player* choosing to
## go - a gesture they make - so a body being carried home after it has died
## should not make it. Everything else about the transition is unchanged, which is
## why this is one argument rather than a second path through the sequence.
##
## [param use_portal] is the same idea for the contextual branch above.
##
## [param to] overrides [member destination_id] for this one journey, so a door
## somewhere in the world can send the player to its own [TeleportDestination]
## without a second teleporter existing on the body. Left empty - which is every
## caller that is answering the B key - this reads the node's own destination
## exactly as it always did. See [TestMapGate], which is nothing but a place, an id
## and this call.
## [b]Only a press can start a run.[/b] The portal branch is what makes B mean two
## things, and it means them because the *player* chose to stand there; a caller that
## is carrying a body rather than answering a key must be able to refuse it, or a
## death in the pit at the foot of the base raises the map screen over a corpse and
## never travels anywhere. Left true this behaves exactly as it always did.
##
## Returns whether a journey home actually began - false for a press that started a
## run instead, and false when there was nothing to travel to or a transition was
## already under way. [b]A caller waiting on [signal teleported] has to know[/b]: on
## every false path that signal is never emitted, and the death sequence waited on it
## for good.
func teleport(silent: bool = false, use_portal: bool = true, to: StringName = &"") -> bool:
	if _teleporting:
		return false

	if use_portal and portal_starts_run and _body != null:
		var portal := RunPortal.get_active(self)
		if portal != null and portal.is_inside(_body):
			_teleporting = true
			_play_snap(silent)
			portal.start_run()
			return false

	var destination := TeleportDestination.get_by_id(self, to if to != &"" else destination_id)
	if destination == null or _body == null:
		return false

	_teleporting = true

	_play_snap(silent)
	_set_world_muted(true)
	_hand_music_to_base(silent)
	_zoom_in()

	# Real time rather than a tween on the body, so the player keeps control of
	# their own movement right up to the moment they vanish.
	var timer := get_tree().create_timer(travel_time, true, false, true)
	timer.timeout.connect(_arrive.bind(destination))
	return true


## Leaving the run takes the soundtrack with it: the arena track goes down and the
## base track comes up, over the same seconds the world is muted for, so the
## crossfade happens inside the silence and the player simply arrives home to a
## different song.
##
## Found by group rather than wired up, so a world with no soundtrack teleports
## exactly as it always did. [param silent] is the death sequence's teleport - it
## is carrying a body home and running its own handover - and it is left alone.
func _hand_music_to_base(silent: bool) -> void:
	if not drive_music or silent:
		return

	var music := MusicDirector.get_active(self)
	if music == null:
		return

	# Given exactly as long as the journey is silent for, rather than a length of
	# its own to keep in step: the two tracks finish trading places on the frame
	# the world comes back, so the crossfade is never half heard.
	music.switch_to_base(travel_time + silence_hold_time)


## The snap is the gesture, not the transition: silencing it changes nothing else
## about the journey, which is why it is the one thing [param silent] touches.
func _play_snap(silent: bool) -> void:
	if silent or _sounds == null:
		return
	_sounds.play(snap_sound)


func _arrive(destination: TeleportDestination) -> void:
	# The destination could have gone away during the transition - a scene reload
	# mid-teleport - so it is rechecked rather than trusted.
	if not is_instance_valid(destination) or _body == null:
		_finish()
		return

	_body.global_position = destination.get_spawn_position()
	# Physics interpolation is on project-wide; without this the body would be
	# visibly smeared across the whole distance it just jumped.
	_body.reset_physics_interpolation()

	if move_camera_limits:
		_apply_camera_limits(destination.get_world_bounds())

	_zoom_out()
	teleported.emit(destination)

	var timer := get_tree().create_timer(silence_hold_time, true, false, true)
	timer.timeout.connect(_finish)


func _finish() -> void:
	if restore_audio:
		_set_world_muted(false)
		audio_restored.emit()
	_teleporting = false


## Muted, never stopped. Every player on the bus keeps running at its own
## position, so the music picks up mid-bar rather than restarting, and the
## collection loops resume at whatever level they had reached.
func _set_world_muted(muted: bool) -> void:
	var index := AudioServer.get_bus_index(game_bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, muted)


## Clamped to the destination so the camera cannot wander back across the empty
## space between the two areas.
##
## The box is first grown to at least the size of the view. A limit rectangle
## smaller than the screen is a request the camera cannot satisfy: Godot pins it
## to the rectangle's centre and the empty world shows as bars around the edges.
## Since a destination is allowed to be smaller than a screenful - this one is
## half the arena - the growing is what keeps a small room filling the display.
func _apply_camera_limits(area: Rect2) -> void:
	var camera := _get_camera()
	if camera == null:
		return

	var box := _at_least_view_sized(area, camera)
	camera.limit_left = int(box.position.x)
	camera.limit_top = int(box.position.y)
	camera.limit_right = int(box.end.x)
	camera.limit_bottom = int(box.end.y)
	# Otherwise the camera glides across the whole gap, showing the void between.
	camera.reset_smoothing()


## Grows [param area] around its own centre until it is at least as large as
## what the camera can see, leaving a larger area untouched.
func _at_least_view_sized(area: Rect2, camera: Camera2D) -> Rect2:
	var view := camera.get_viewport_rect().size / camera.zoom
	if area.size.x >= view.x and area.size.y >= view.y:
		return area

	var size := Vector2(maxf(area.size.x, view.x), maxf(area.size.y, view.y))
	return Rect2(area.get_center() - size * 0.5, size)


func _zoom_in() -> void:
	var camera := _get_camera()
	if camera == null:
		return
	camera.zoom_impulse([
		Vector2(zoom_multiplier - 1.0, zoom_in_time),
		Vector2(zoom_multiplier - 1.0, zoom_hold_time),
	])


func _zoom_out() -> void:
	var camera := _get_camera()
	if camera == null:
		return
	camera.zoom_impulse([
		Vector2(zoom_multiplier - 1.0, zoom_hold_time),
		Vector2(0.0, zoom_return_time),
	])


## Restored on the way out, so a scene reload part way through a teleport can
## never leave the next run muted.
func _exit_tree() -> void:
	if _teleporting:
		_set_world_muted(false)


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
