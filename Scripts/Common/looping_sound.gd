class_name LoopingSound
extends AudioStreamPlayer
## A continuous sound whose level is steered rather than switched.
##
## Callers never call `play()` or `stop()`. They set a level between 0 and 1 with
## [method set_level] and this eases towards it, starting the stream the moment
## the level leaves silence and stopping it once it has genuinely faded away.
## That is what makes a reactive loop fade instead of clicking on and off, and it
## means a caller can set the level every single frame from a changing quantity -
## blood in flight, say - without any of the bookkeeping.
##
## Level is a 0..1 *fraction*, not decibels. It is mapped through
## [method volume_to_db] so that 0.5 sounds like half rather than like -0.5 dB,
## and [member max_volume_db] is a hard ceiling the fraction is scaled into, so a
## reactive sound can never get louder than the value set in the inspector.
##
## [SoundBank] remains the right tool for one-shots. This is only for sustained
## loops, which a voice pool handles badly.
##
## The stream must be imported with a forward loop. [member force_loop] is the
## belt-and-braces fallback for one that is not.

## Loudest this sound may ever get, in decibels, reached at level 1.
@export var max_volume_db: float = 0.0
## Level below which the sound is treated as off and the player is stopped, so a
## silent loop costs no voice.
@export_range(0.0, 0.2) var silence_threshold: float = 0.005
## How fast the level rises towards a higher target, per second. Lower is gentler.
@export var fade_in_speed: float = 4.0
## How fast it falls towards a lower target. Usually slower than the rise, so the
## sound tails off rather than being cut.
@export var fade_out_speed: float = 3.0
## Restarts the stream when it ends, for a stream imported without a loop. Costs
## nothing when the stream already loops, because a looping stream never reports
## finished.
@export var force_loop: bool = true
## Random pitch offset applied once when the loop starts, so repeated runs of
## the same loop are not mechanically identical.
@export_range(0.0, 0.5) var pitch_variation: float = 0.0

var _level: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	# Never plays on its own. Anything that autoplays would be at full volume
	# before the first level is set.
	autoplay = false
	stop()
	volume_db = _silent_db()
	if force_loop:
		finished.connect(_on_finished)


## Asks for a level between 0 (silent) and 1 ([member max_volume_db]). Safe to
## call every frame; values outside the range are clamped.
func set_level(level: float) -> void:
	_target = clampf(level, 0.0, 1.0)


## Where the level is right now, after easing. Mostly useful for debugging and
## for anything that wants to follow the audible level rather than the requested
## one.
func get_level() -> float:
	return _level


func is_audible() -> bool:
	return _level > silence_threshold


## Drops to silence immediately, without a fade. Used when a whole scene is being
## torn down or muted, not during normal play.
func silence_now() -> void:
	_target = 0.0
	_level = 0.0
	volume_db = _silent_db()
	stop()


func _process(delta: float) -> void:
	if is_equal_approx(_level, _target) and not is_audible():
		return

	# Rise and fall are eased at different rates, which is what lets a sound
	# swell quickly with the blood and then linger as it runs out.
	var speed := fade_in_speed if _target > _level else fade_out_speed
	_level = lerpf(_level, _target, 1.0 - exp(-maxf(speed, 0.0001) * delta))

	if _level <= silence_threshold and _target <= 0.0:
		_level = 0.0
		if playing:
			stop()
		return

	if not playing and stream != null:
		pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
		play()

	volume_db = volume_to_db(_level)


## Fraction to decibels, scaled so level 1 lands exactly on
## [member max_volume_db]. Uses the audio server's own curve, so a level of 0.5
## is half as loud to the ear rather than half the dB number.
func volume_to_db(level: float) -> float:
	if level <= silence_threshold:
		return _silent_db()
	return max_volume_db + linear_to_db(clampf(level, 0.0, 1.0))


func _silent_db() -> float:
	return -80.0


## Only ever reached by a stream that was not imported as looping.
func _on_finished() -> void:
	if force_loop and _target > 0.0:
		play()
