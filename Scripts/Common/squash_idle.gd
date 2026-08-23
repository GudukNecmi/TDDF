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


func _ready() -> void:
	if has_animation(animation_name):
		play(animation_name)


func _physics_process(delta: float) -> void:
	if _body == null:
		return

	# The idle never stops while the character is alive.
	if not is_playing():
		play(animation_name)

	var goal := idle_speed
	if not _body.velocity.is_zero_approx():
		goal = moving_speed
	speed_scale = lerpf(speed_scale, goal, 1.0 - exp(-blend_speed * delta))
