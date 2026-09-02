class_name WorldMapHorseGallop
extends Node
## The Gallop loop: silent with the horse standing still, smoothly under way
## the instant the player asks it to move, and gone again the instant it
## settles - World Map movement only.
##
## [b]One voice, steered rather than switched.[/b] [member loop_path] points at
## a [LoopingSound] - the same reusable, fade-driven [AudioStreamPlayer] every
## other continuous sound in the game already is (see [CollectorAudio] for the
## identical shape) - and this node only ever calls [method LoopingSound.set_level]
## on it and writes its [member AudioStreamPlayer.pitch_scale]. Nothing here
## ever instances a player, so nothing here can ever spawn a second voice by a
## key being pressed twice.
##
## [b]It reads [WorldMapHorse], it never becomes a second one.[/b]
## [member WorldMapHorse.walk_speed] and [member WorldMapHorse.run_speed] are
## exactly "the selected horse's known movement speeds", resolved once when the
## horse is found and cached from then on - see [method _bind_horse] - so this
## never repeats an expensive lookup every frame, and [method WorldMapHorse.is_running]
## is asked rather than re-derived, so whatever the horse's own stamina and
## fatigue rules decide about a sprint actually holding is exactly what the
## Gallop hears, without a second copy of those rules living here. Movement
## intent itself - is a World Map key actually held - is read the same way
## [code]player.gd[/code] already reads it, [code]Input.get_vector[/code] over
## the project's own move actions, because [WorldMapHorse] does not carry that
## bit on its own.
##
## [b]Off the World Map, this is silent by construction.[/b] [method WorldMapHorse.is_mounted]
## is false everywhere movement is not the World Map's own - the same guarantee
## the horse's own speed multiplier already rests on - so target speed is
## always zero there and the loop never starts. Nothing here reaches into
## Base or Arena movement at all.
##
## [b]Acceleration and the Gallop are the same ramp.[/b] [member _current_speed]
## eases toward whatever [WorldMapHorse] says the target speed is - zero at
## rest, [member WorldMapHorse.walk_speed] moving, [member WorldMapHorse.run_speed]
## sprinting - over [member acceleration_duration] rising and
## [member deceleration_duration] falling, and both the loop's level and its
## pitch are read straight off that one eased number every frame. That is what
## keeps the two "synchronized" rather than two separate timers that happen to
## agree today: there is only one clock between them. A direction change while
## still moving never touches [member _current_speed] at all - see
## [method _target_speed] - so the Gallop never restarts over it.

## The reusable voice - a [LoopingSound] this node only ever calls
## [method LoopingSound.set_level] on. Left unresolved, the Gallop simply never
## plays.
@export var loop_path: NodePath = ^"../GallopLoop"
## The horse this Gallop follows. Left unresolved it is found by group the
## first time it is needed and then held - see [method _bind_horse].
@export var horse_path: NodePath = ^"../WorldMapHorse"

@export_group("Timing")
## How long the climb from idle to whatever speed the player is asking for
## takes, in seconds - "approximately 1 second" for both the horse and the
## Gallop, because they are read off the same eased value.
@export var acceleration_duration: float = 1.0
## How long the fall back towards idle - or towards a lower speed, releasing
## Shift while still moving - takes.
@export var deceleration_duration: float = 1.0

@export_group("Audio")
## The loudest the Gallop is ever mixed at - written onto
## [member LoopingSound.max_volume_db] once on ready, so every knob this
## feature owns lives on this one node's inspector rather than being split
## across two.
@export var volume_db: float = -6.0
## Playback rate at [member WorldMapHorse.walk_speed] - ordinary mounted
## movement.
@export var normal_gallop_playback_rate: float = 1.0
## Playback rate at [member WorldMapHorse.run_speed] - Shift held and actually
## sprinting. Authored directly rather than derived, so a designer can hear and
## retune it on its own; the default already follows rule 9's own relationship -
## the horse's own run speed is roughly double its walk speed on every horse
## authored so far, and 1.5x is what that should sound like, deliberately
## gentler than the 2x the movement itself picked up. See
## [member speed_to_playback_scaling] for how a speed between the two is
## shaped, not for what the two ends are.
@export var sprint_gallop_playback_rate: float = 1.5
## Shapes the climb from [member normal_gallop_playback_rate] to
## [member sprint_gallop_playback_rate] as [member _current_speed] rises from
## walk to run speed. 1 is a straight line; above 1 holds close to the normal
## rate until the horse is most of the way to a full sprint and then climbs
## quickly, so a light push past walking pace does not already sound like a
## sprint.
@export_range(0.1, 4.0) var speed_to_playback_scaling: float = 1.0

var _loop: LoopingSound
var _horse: WorldMapHorse
## The horse's own known speeds, cached the moment [member _horse] is found -
## "already known when the horse is selected", read once rather than asked of
## the node again every frame.
var _walk_speed: float = 0.0
var _run_speed: float = 0.0
## The Gallop's own current speed reading, eased toward whatever
## [method _target_speed] asks for - the one clock volume and pitch are both
## read off. Pixels per second, the same unit [member WorldMapHorse.walk_speed]
## and [member WorldMapHorse.run_speed] are authored in, so 0 is unambiguously
## "not moving" rather than a level or a rate that has to be reasoned about
## separately.
var _current_speed: float = 0.0


func _ready() -> void:
	_loop = get_node_or_null(loop_path) as LoopingSound
	if _loop != null:
		_loop.max_volume_db = volume_db


func _process(delta: float) -> void:
	if _loop == null:
		return
	_bind_horse()

	var target := _target_speed()
	var duration := acceleration_duration if target > _current_speed else deceleration_duration
	var span := maxf(maxf(_walk_speed, _run_speed), 1.0)
	var rate := span / maxf(duration, 0.0001)
	_current_speed = move_toward(_current_speed, target, rate * delta)

	_loop.set_level(_level_for(_current_speed))
	_loop.pitch_scale = _pitch_for(_current_speed)


## The horse, found by group once and then reused - see the class doc's "never
## repeat an expensive lookup every frame". Only re-resolves when the reference
## has gone stale, which off the World Map it never does: [WorldMapHorse] is a
## permanent child of the persistent [Player], never rebuilt by anything short
## of a whole new run.
func _bind_horse() -> void:
	if _horse != null and is_instance_valid(_horse):
		return

	_horse = get_node_or_null(horse_path) as WorldMapHorse
	if _horse == null:
		_horse = WorldMapHorse.get_active(self)
	if _horse == null:
		return

	_walk_speed = maxf(_horse.walk_speed, 0.0)
	_run_speed = maxf(_horse.run_speed, 0.0)


## Zero unmounted or standing still, [member _walk_speed] moving, and
## [member _run_speed] the instant [method WorldMapHorse.is_running] says the
## horse's own stamina rules actually granted the sprint - never 1:1 with Shift
## being held, so a sprint refused for want of stamina never plays as one here
## either.
func _target_speed() -> float:
	if _horse == null or not _horse.is_mounted() or not _has_movement_input():
		return 0.0
	return _run_speed if _horse.is_running() else _walk_speed


## Any World Map movement key held - the same four actions [code]player.gd[/code]
## reads its own input direction from, asked directly rather than through a
## second movement system, so a direction change alone can never be mistaken
## for movement starting or stopping.
func _has_movement_input() -> bool:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") != Vector2.ZERO


## 0 at rest, climbing to 1 by the time [member _current_speed] reaches
## [member _walk_speed] and held there through a sprint - "do not instantly
## start the full-volume gallop" is entirely about this leg; nothing about
## reaching a sprint should make the loop louder than ordinary movement
## already does.
func _level_for(speed: float) -> float:
	if _walk_speed <= 0.0:
		return 0.0 if speed <= 0.0 else 1.0
	return clampf(speed / _walk_speed, 0.0, 1.0)


## [member normal_gallop_playback_rate] up to [member _walk_speed], easing
## towards [member sprint_gallop_playback_rate] as [member _current_speed]
## closes the gap to [member _run_speed] - shaped by
## [member speed_to_playback_scaling] rather than a straight line, and never
## the raw speed ratio itself, per rule 9's "do not use a 1:1 speed
## multiplier".
func _pitch_for(speed: float) -> float:
	if _run_speed <= _walk_speed:
		return normal_gallop_playback_rate
	var t := clampf((speed - _walk_speed) / (_run_speed - _walk_speed), 0.0, 1.0)
	var shaped := pow(t, speed_to_playback_scaling)
	return lerpf(normal_gallop_playback_rate, sprint_gallop_playback_rate, shaped)
