class_name RoundLabel
extends Label
## Shows which round the player is on.
##
## It keeps no count of its own: the number comes from the persistent
## [RoundCounter] - the [code]RunProgress[/code] autoload - and it follows that
## counter's own [signal RoundCounter.round_changed] rather than polling, so it
## cannot drift from the round the waves are actually being scaled by and it is
## already correct on the first frame of a rebuilt world rather than counting up
## to it.
##
## Everything about how it *looks* - where it sits, its size, its colour, its
## margin - is left on the node, so it is retuned in the inspector alongside the
## rest of the HUD instead of here.

## Counter this mirrors.
@export var progress_path: NodePath = ^"/root/RunProgress"
## How the number is written. The count is substituted in, so the wording can
## change without touching code.
@export var format: String = "ROUND %d"

@export_group("Pulse")
## How much larger the label gets as a new round begins. A round starting is
## worth marking, so this is a little more emphatic than the blood counter's nudge.
@export var pulse_scale: float = 1.35
@export var pulse_out_time: float = 0.12
@export var pulse_back_time: float = 0.28

@onready var _progress: RoundCounter = get_node_or_null(progress_path) as RoundCounter

var _pulse_tween: Tween


func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)

	if _progress == null:
		text = format % 1
		return

	_progress.round_changed.connect(_on_round_changed)
	_refresh(_progress.get_round())


## Scaled around its own middle rather than its top-left corner, so a pulse grows
## the label in place instead of shoving it sideways.
func _centre_pivot() -> void:
	pivot_offset = size * 0.5


func _on_round_changed(round_number: int) -> void:
	_refresh(round_number)
	_play_pulse()


func _refresh(round_number: int) -> void:
	text = format % round_number


## Restarts from the resting scale every time, so a pulse interrupted by another
## cannot stack or leave the label permanently enlarged.
func _play_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	scale = Vector2.ONE
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_out_time) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_back_time) \
		.set_ease(Tween.EASE_IN)
