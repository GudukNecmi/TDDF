class_name SquashIdle
extends AnimationPlayer
## Keeps a character's squash-and-stretch idle running at all times and speeds
## it up slightly while the character moves.
##
## This is the AnimationPlayer itself rather than a separate component, so any
## future character gets the behaviour just by using this script and pointing
## its library at the shared idle animation.

## Character whose velocity decides the playback speed.
@export var body_path: NodePath = ^".."
@export var animation_name: StringName = &"idle"
## Playback speed while standing still.
@export var idle_speed: float = 1.0
## Playback speed while moving - keep the gap small, it should be subtle.
@export var moving_speed: float = 1.35
## How quickly playback blends between the two speeds.
@export var blend_speed: float = 8.0

@onready var _body: CharacterBody2D = get_node_or_null(body_path) as CharacterBody2D

## Whether this character has been laid to rest. Once, and it never comes back - see
## [method lie_still].
var _still: bool = false


func _ready() -> void:
	if _still:
		return
	if has_animation(animation_name):
		play(animation_name)


## Stops the idle for good, leaving the character in whatever pose it had reached.
##
## [b]It is the only way to stop this animation.[/b] The idle is relentless by
## design - see [method _physics_process] - so anything that merely called
## [method AnimationPlayer.stop] would find it running again on the next physics
## frame, and shooting a body that had been stopped that way would visibly start it
## breathing. This is the switch that puts the restart itself away, so a man who has
## been laid out stays laid out however he is treated afterwards.
##
## Paused rather than stopped, so the pose is kept: a corpse should be lying in the
## sand at whatever point of the breath it was caught on, not snapped back to the
## first frame of one.
func lie_still() -> void:
	if _still:
		return
	_still = true
	pause()
	speed_scale = 0.0
	set_physics_process(false)


## Whether the idle has been stopped for good.
func is_still() -> bool:
	return _still


func _physics_process(delta: float) -> void:
	if _still or _body == null:
		return

	# The idle never stops while the character is alive.
	if not is_playing():
		play(animation_name)

	var goal := idle_speed
	if not _body.velocity.is_zero_approx():
		goal = moving_speed
	speed_scale = lerpf(speed_scale, goal, 1.0 - exp(-blend_speed * delta))
