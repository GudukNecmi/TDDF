class_name RunTimerLabel
extends Label
## Shows how many seconds are left in the run, counting down to 0, and gives the
## number a short pulse at the milestone seconds.
##
## It runs no clock of its own: it reads [WaveManager]'s remaining time every
## frame, so the two can never drift apart, and it keeps working unchanged if
## the run length is retuned.

## Manager whose run this mirrors.
@export var wave_manager_path: NodePath = ^"../../WaveManager"

@export_group("Run end")
## Takes the countdown off the screen once the clock has stopped, rather than
## leaving a 0 hanging over the collection phase and the portal that follows it.
## The clock itself is untouched - this is only what is drawn - so the label
## comes straight back if the manager is ever started again.
@export var hide_when_finished: bool = true
## Beat the 0 is left on screen for, so the countdown is seen to finish rather
## than blinking out on its last tick.
@export var hide_delay: float = 0.7
@export var hide_fade_time: float = 0.45

@export_group("Pulse")
## Individual second marks that each pulse once as they appear.
@export var pulse_at_seconds: Array[int] = [30, 20]
## At or below this many seconds left, every tick pulses.
@export var pulse_every_second_below: int = 10
## How much larger the number gets at the peak of a pulse. Kept small - this is
## a nudge, not a jump.
@export var pulse_scale: float = 1.28
@export var pulse_out_time: float = 0.08
@export var pulse_back_time: float = 0.18

@onready var _manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager

var _last_shown: int = -1
var _last_pulsed: int = -1
var _pulse_tween: Tween
var _fade_tween: Tween
var _packed_away: bool = false


func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	_follow_run_state()


## Mirrors whether the run is still spawning. Guarded on the last state it acted
## on, so the fade is started once rather than restarted every frame, and a
## manager that is started again brings the countdown straight back.
func _follow_run_state() -> void:
	if not hide_when_finished or _manager == null:
		return

	var away := _manager.is_collection_phase()
	if away == _packed_away:
		return

	_packed_away = away
	if away:
		_fade_away()
	else:
		_come_back()


func _fade_away() -> void:
	_kill_fade()
	_fade_tween = create_tween()
	if hide_delay > 0.0:
		_fade_tween.tween_interval(hide_delay)
	_fade_tween.tween_property(self, "modulate:a", 0.0, maxf(hide_fade_time, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Hidden as well as transparent, so a finished countdown costs nothing to
	# draw and cannot be left as an invisible label catching anything.
	_fade_tween.tween_callback(hide)


func _come_back() -> void:
	_kill_fade()
	modulate.a = 1.0
	show()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()


## Scaling happens around the middle of the label rather than its top-left
## corner, so a pulse grows the number in place instead of shoving it sideways.
func _centre_pivot() -> void:
	pivot_offset = size * 0.5


func _refresh() -> void:
	if _manager == null:
		return

	var seconds := ceili(_manager.get_time_left())
	if seconds == _last_shown:
		return

	_last_shown = seconds
	text = str(seconds)
	_maybe_pulse(seconds)


## Guarded on the second it last fired for, so one number can never pulse twice
## however many frames it stays on screen.
func _maybe_pulse(seconds: int) -> void:
	if seconds == _last_pulsed or not _should_pulse(seconds):
		return
	_last_pulsed = seconds
	_play_pulse()


func _should_pulse(seconds: int) -> bool:
	if seconds < 0:
		return false
	if seconds <= pulse_every_second_below:
		return true
	return pulse_at_seconds.has(seconds)


## Restarts from the resting scale every time, so interrupting one pulse with
## the next can never stack them or leave the number permanently enlarged.
func _play_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	scale = Vector2.ONE
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_out_time) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_back_time) \
		.set_ease(Tween.EASE_IN)
