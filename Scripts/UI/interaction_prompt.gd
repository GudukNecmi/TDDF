class_name InteractionPrompt
extends Node2D
## The small red key hint that appears by the player's head when something
## nearby can be used.
##
## It is drawn in the world rather than on the HUD, and follows the player rather
## than the thing offering the interaction, so the answer to "what do I press" is
## right where the player is already looking instead of somewhere across the
## screen. Being in world space also means it shrinks and grows with the camera,
## which is what keeps it the same apparent size in the base as in the arena.
##
## It knows nothing about what it is prompting for. Whoever owns the interaction
## - [ArenaPortal] today, a shop counter tomorrow - decides when the player is in
## range and calls [method set_prompt_visible]; this only fades in, bobs, and
## fades out again. That is why one prompt can serve every interaction in the
## game and why it needs no distance test of its own.
##
## It is [member CanvasItem.top_level] so that whatever it is parented to can be
## grown, spun or hidden without dragging the prompt along with it.

## Group the prompt follows. The player.
@export var follow_group: StringName = &"player"
## Where it sits relative to the body's origin, which is at their feet - so this
## is up beside the head.
@export var head_offset := Vector2(30.0, -70.0)
## Overall size. Kept small on purpose: this is a hint, not a sign.
@export var prompt_scale: float = 0.55

@export_group("Motion")
## How long it fades in and out over.
@export var fade_time: float = 0.16
## How far it drifts up and down, in pixels, so it reads as prompting rather than
## as part of the artwork.
@export var bob_height: float = 3.0
## Bobs per second.
@export var bob_speed: float = 1.6
## How much larger it pops as it appears, as a fraction.
@export var pop_scale: float = 0.35

var _shown: bool = false
var _time: float = 0.0
var _fade_tween: Tween


func _ready() -> void:
	top_level = true
	modulate.a = 0.0
	visible = false
	scale = Vector2.ONE * prompt_scale


## Whether the prompt is up. Called by whoever owns the interaction; guarded, so
## being told the same thing every frame costs nothing.
func set_prompt_visible(shown: bool) -> void:
	if shown == _shown:
		return
	_shown = shown

	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()

	if _shown:
		visible = true
		# Popped from slightly large and settled, so it arrives rather than
		# simply being switched on.
		scale = Vector2.ONE * prompt_scale * (1.0 + pop_scale)
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(self, "modulate:a", 1.0, fade_time)
		_fade_tween.tween_property(self, "scale", Vector2.ONE * prompt_scale, fade_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	# Hidden at the end of the fade, so a prompt nobody is being offered costs
	# nothing to draw.
	_fade_tween.tween_callback(hide)


func is_prompt_visible() -> bool:
	return _shown


func _process(delta: float) -> void:
	if not visible:
		return

	_time += delta
	var body := get_tree().get_first_node_in_group(follow_group) as Node2D
	if body == null:
		return

	var bob := Vector2(0.0, sin(_time * bob_speed * TAU) * bob_height)
	global_position = body.global_position + head_offset + bob
