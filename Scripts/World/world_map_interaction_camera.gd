class_name WorldMapInteractionCamera
extends Node
## The World Map's own cinematic zoom for a walk-up interaction - a bandit
## contact's decision, the market, a bandit fight's own return framing -
## and nothing more than that: one shared push/pop onto
## [member CameraController.zoom_multiplier].
##
## [b]It is [CameraController]'s own resting-zoom knob, not a second camera
## system.[/b] [method zoom_in], [method zoom_out] and [method snap_and_release]
## only ever call [method CameraController.set_zoom_multiplier] and
## temporarily ride its own [member CameraController.zoom_multiplier_speed] -
## the identical trick [WorldZone], [BossArena] and [BossDefeat] already use
## for their own zoom pushes, borrowed rather than reinvented. Nothing here
## ever touches [member Camera2D.position] or calls
## [method CameraController.follow]: the World Map's camera already rests on
## the player at every moment - see [CameraController]'s own class doc,
## "the camera hangs off the player" - so "the player becomes the visual
## centre of the frame" is simply what is already true, and a zoom on top of
## it is the entire effect asked for.
##
## [b]The push is counted, not flagged.[/b] [member _pushes] is how many
## callers currently want the zoom held; only the last one releasing it
## actually eases the camera back. Two interactions can never overlap in
## practice - the bandit decision and a World Map location both hold the
## player in place for as long as they are open - but the counter is what
## makes an unexpected overlap fail safe instead of stranding the camera
## zoomed in.
##
## [b]The ease speed is borrowed, then given back.[/b] [member CameraController.zoom_multiplier_speed]
## is a single shared field, so every push here saves it once (the first
## push of a run) and only writes it back once the outgoing ease has actually
## had time to land - [method _schedule_speed_restore] - never leaving the
## camera's own default zoom speed changed once an interaction is over. This
## is what "do not change World Map camera behaviour permanently" means in
## practice: everything this touches is put back.

const GROUP := &"world_map_interaction_camera"

## The multiplier a caller gets when it does not name its own - 3x, per
## every place this is asked for today.
@export var default_multiplier: float = 3.0
## How long a push or a release takes when a caller does not name its own
## duration - "approximately 1.0 second" for both directions.
@export var default_zoom_seconds: float = 1.0

var _pushes: int = 0
var _restore_to: float = 1.0
var _speed_was: float = 0.0
var _speed_taken: bool = false
## Bumped on every push and release, so a speed-restore timer scheduled by
## an earlier release can tell it is stale - see [method _on_restore_timeout] -
## rather than clobbering a speed a later push has since taken over.
var _epoch: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


## The interaction camera in this world, or null when it has none - which
## every caller reads as "no cinematic zoom for this moment", exactly like
## every other [code]get_active[/code] in this project.
static func get_active(from_node: Node) -> WorldMapInteractionCamera:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapInteractionCamera


## Eases the camera in to [param multiplier] over [param seconds]. Below 0 on
## either uses this node's own [member default_multiplier] /
## [member default_zoom_seconds]. Safe to call while already pushed in -
## see the class doc on [member _pushes].
func zoom_in(seconds: float = -1.0, multiplier: float = -1.0) -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	var target := multiplier if multiplier > 0.0 else default_multiplier
	var duration := seconds if seconds > 0.0 else default_zoom_seconds

	_take_baseline(camera)
	_pushes += 1
	_epoch += 1

	camera.zoom_multiplier_speed = _speed_for(duration)
	camera.set_zoom_multiplier(target)


## Eases the camera back out over [param seconds] - only once every
## [method zoom_in] that pushed it in has been matched by a release. Below 0
## uses [member default_zoom_seconds].
func zoom_out(seconds: float = -1.0) -> void:
	var camera := CameraController.get_active(self)
	if camera == null or _pushes <= 0:
		return

	_pushes = maxi(_pushes - 1, 0)
	_epoch += 1
	if _pushes > 0:
		return

	var duration := seconds if seconds > 0.0 else default_zoom_seconds
	camera.zoom_multiplier_speed = _speed_for(duration)
	camera.set_zoom_multiplier(_restore_to)
	_schedule_speed_restore(camera, duration)


## Snaps the camera straight to [param multiplier] with no ease in at all,
## then eases it back out over [param seconds] exactly as [method zoom_out]
## would. What a fight's own return framing wants - "start there with the
## camera still at 3x zoom" - since there is nothing to zoom into: the
## camera simply is at the multiplier the instant control is handed back,
## and only the release is a smooth beat.
func snap_and_release(multiplier: float = -1.0, seconds: float = -1.0) -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	var target := multiplier if multiplier > 0.0 else default_multiplier
	_take_baseline(camera)
	_pushes += 1
	_epoch += 1
	# True immediate: skips CameraController's own ease outright rather than
	# merely setting a fast speed for it, so there is no visible climb to
	# 3x at all - see [method CameraController.set_zoom_multiplier].
	camera.set_zoom_multiplier(target, true)

	zoom_out(seconds)


func _take_baseline(camera: CameraController) -> void:
	if _pushes != 0:
		return
	_restore_to = camera.get_zoom_multiplier()
	_speed_was = camera.zoom_multiplier_speed
	_speed_taken = true


## The [member CameraController.zoom_multiplier_speed] that reaches its
## target in roughly [param duration] seconds under the camera's own
## exponential ease - three time constants reads as "arrived" to the eye, so
## the speed handed over is three divided by the duration asked for. See
## [method CameraController._physics_process].
func _speed_for(duration: float) -> float:
	return 3.0 / maxf(duration, 0.05)


## Hands [member CameraController.zoom_multiplier_speed] back to whatever it
## was before the first push of this run, once the outgoing ease has had
## [param seconds] to actually land - not sooner, or the camera's default
## speed would cut the release itself short.
func _schedule_speed_restore(camera: CameraController, seconds: float) -> void:
	if not _speed_taken or not is_inside_tree():
		return
	var epoch := _epoch
	var timer := get_tree().create_timer(maxf(seconds, 0.0), true, false, true)
	timer.timeout.connect(_on_restore_timeout.bind(camera, epoch))


## Only acts if nothing has pushed or released again since this restore was
## scheduled - [param epoch] is what tells a stale timer apart from the
## current one, since [SceneTreeTimer] itself cannot be cancelled.
func _on_restore_timeout(camera: CameraController, epoch: int) -> void:
	if epoch != _epoch or not _speed_taken:
		return
	if camera != null and is_instance_valid(camera):
		camera.zoom_multiplier_speed = _speed_was
	_speed_taken = false
