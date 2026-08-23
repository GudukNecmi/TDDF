class_name BloodScreen
extends Control
## The blood the player's own wounds leave across the screen.
##
## Every hit plays one [BloodStage] out: the blood hits the glass, runs, and
## settles - and what settles stays there for a beat before it blurs and dries
## away. The killing hit is the exception and the point of the whole thing: its
## settled blood is never cleaned up on a timer, because the player is dead
## behind it. It sits there until [method dissolve_final] is called, which
## [PlayerDeathSequence] does as the hearts start coming back, so the screen
## clears at exactly the pace the player is put back together.
##
## Which stage a hit plays is worked out from how much health is LEFT, counting
## back from the end of the list - so the last entry is always the killing blow,
## the one before it is the hit before that, and so on. That is deliberately not
## "how many hits have landed": a player with more hearts than there are stages
## simply gets no screen blood for their early hits and the sequence still lands
## exactly on their last four, whatever an upgrade did to their maximum. There is
## no total health anywhere in this file to keep in step with the player's.
##
## The blur is a shader on one overlay rather than a second layer, so drying is a
## uniform going up rather than anything being spawned, and an idle overlay costs
## no more than a hidden sprite.

## Emitted as a stage begins.
signal stage_started(index: int)
## Emitted once a stage has cleared itself off the screen.
signal stage_cleared(index: int)

## Group used by [method get_active], so the blood can be reached from anywhere -
## the death sequence lives on the player and this lives on the HUD.
const GROUP := &"blood_screen"

## The stages, mildest first and the killing blow last. See the class notes for
## how one is chosen: it is by health remaining, counting back from the end, so
## the order of this list is what decides the whole mapping.
@export var stages: Array[BloodStage] = []
## Health whose hits are drawn. Found by group, so nothing is wired to the player.
@export var health_group: StringName = &"player_health"
## The overlay the artwork is drawn on. Its material must carry the blood blur
## shader; without one the blood still plays and simply never blurs.
@export var overlay_path: NodePath = ^"Overlay"

@export_group("Timing")
## How long the hit frame is on screen.
@export var burst_time: float = 0.16
## How long the running frame is on screen.
@export var spread_time: float = 0.28
## How long the settled blood stays before it starts to dry, for every stage but
## the last.
@export var settle_hold: float = 4.0
## How long it takes to fade away afterwards.
@export var settle_fade_time: float = 1.8
## How long the blur takes to build over the same window. Run alongside the fade
## rather than before it, so the blood softens as it goes rather than going soft
## and then disappearing.
@export var settle_blur_time: float = 1.8
## How far the blood is smeared as it dries, in texture pixels.
@export var settle_blur: float = 5.0

@export_group("Final stage")
## Whether the last stage's settled blood stays put instead of drying on a timer.
## This is what leaves the screen bloodied through the death and the trip home.
@export var final_stage_holds: bool = true
## How long the held blood takes to fade once the healing starts. Long on
## purpose: it should still be going as the last heart lands.
@export var final_fade_time: float = 3.2
## How long its blur takes to build over the same window.
@export var final_blur_time: float = 3.2
## How far the held blood is smeared as it goes. Heavier than an ordinary stage,
## so death washes off rather than merely fading.
@export var final_blur: float = 9.0

@export_group("Appearance")
## How strongly the blood is drawn at its peak.
@export_range(0.0, 1.0) var opacity: float = 1.0

@onready var _overlay: TextureRect = get_node_or_null(overlay_path) as TextureRect

var _health: Health
var _material: ShaderMaterial
var _stage_index: int = -1
var _holding_final: bool = false
var _tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	if _overlay != null:
		_material = _overlay.material as ShaderMaterial
	_clear_now()
	_bind_health()


## The blood any system should talk to. Null means this scene has none, which
## every caller reads as "screen blood is switched off".
static func get_active(from_node: Node) -> BloodScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BloodScreen


## The health may enter the tree after the HUD does, so it is looked for until it
## turns up. Once bound this stops running.
func _process(_delta: float) -> void:
	if _health == null or not is_instance_valid(_health):
		_bind_health()


func _bind_health() -> void:
	_health = get_tree().get_first_node_in_group(health_group) as Health
	if _health == null:
		return
	_health.damaged.connect(_on_damaged)
	set_process(false)


## [Health] announces the new total before it announces the hit, so by the time
## this runs the pool already holds what is LEFT - which is exactly the number
## the stage is chosen by.
func _on_damaged(_amount: float, _hit_direction: Vector2) -> void:
	if _health == null:
		return
	play_for_remaining(int(round(_health.get_current())))


## Plays the stage for [param remaining] hearts left. Counts back from the end of
## the list, so 0 remaining is always the last stage - the killing blow - however
## many stages there are and however much health the player has.
##
## A player still further from death than there are stages gets nothing here,
## which is what leaves the ordinary damage feedback to speak for those hits.
func play_for_remaining(remaining: int) -> void:
	var index := stages.size() - 1 - maxi(remaining, 0)
	if index < 0 or index >= stages.size():
		return
	play_stage(index)


## Plays one stage by index. Restarts cleanly from whatever was already on
## screen, so two hits close together cannot leave two sequences running.
func play_stage(index: int) -> void:
	if _overlay == null or index < 0 or index >= stages.size():
		return

	var stage := stages[index]
	if stage == null:
		return

	_kill_tween()
	_stage_index = index
	_holding_final = false
	_set_blur(0.0)
	_set_alpha(opacity)
	show()

	_tween = create_tween()
	_queue_frame(stage.burst, burst_time)
	_queue_frame(stage.spread, spread_time)

	if stage.settle == null:
		# A stage with nothing to leave behind simply fades out where it stands.
		_queue_dissolve(settle_fade_time, settle_blur_time, settle_blur)
		stage_started.emit(index)
		return

	_tween.tween_callback(_show_frame.bind(stage.settle))

	var is_final := index >= stages.size() - 1
	if is_final and final_stage_holds:
		# Nothing further is queued on purpose: the blood stays exactly as it is
		# until somebody asks for it to go.
		_holding_final = true
	else:
		_tween.tween_interval(maxf(settle_hold, 0.0))
		_queue_dissolve(settle_fade_time, settle_blur_time, settle_blur)

	stage_started.emit(index)


## Whether the held final blood is still sitting on the screen.
func is_holding_final() -> bool:
	return _holding_final


## Washes the held final blood away. Called as the player's hearts start coming
## back, so the screen clears at the pace they are put back together rather than
## on a timer of its own.
##
## Times default to the exported final ones and can be overridden per call, for a
## revival that wants to take longer or shorter than usual.
func dissolve_final(fade_time: float = -1.0, blur_time: float = -1.0) -> void:
	if not _holding_final:
		return
	_holding_final = false

	_kill_tween()
	_tween = create_tween()
	_queue_dissolve(
		fade_time if fade_time >= 0.0 else final_fade_time,
		blur_time if blur_time >= 0.0 else final_blur_time,
		final_blur)


## Takes everything off the screen at once, for a scene rebuild or a debug reset.
func clear() -> void:
	_kill_tween()
	_clear_now()


func _queue_frame(texture: Texture2D, hold: float) -> void:
	if texture == null:
		return
	_tween.tween_callback(_show_frame.bind(texture))
	_tween.tween_interval(maxf(hold, 0.0))


## The fade and the blur run together rather than one after the other, so the
## blood softens as it disappears instead of going soft and then vanishing.
func _queue_dissolve(fade_time: float, blur_time: float, blur: float) -> void:
	if _material == null:
		_tween.tween_property(_overlay, "modulate:a", 0.0, maxf(fade_time, 0.0001))
		_tween.tween_callback(_clear_now)
		return

	_tween.tween_property(_material, "shader_parameter/alpha", 0.0, maxf(fade_time, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(
		_material, "shader_parameter/blur_amount", blur, maxf(blur_time, 0.0001))
	_tween.chain().tween_callback(_finish_stage)


func _show_frame(texture: Texture2D) -> void:
	if _overlay != null:
		_overlay.texture = texture


func _finish_stage() -> void:
	var index := _stage_index
	_clear_now()
	stage_cleared.emit(index)


## Hidden as well as cleared, so blood nobody is looking at is not composited over
## the screen every frame.
func _clear_now() -> void:
	_stage_index = -1
	_holding_final = false
	_set_blur(0.0)
	_set_alpha(0.0)
	if _overlay != null:
		_overlay.texture = null
		_overlay.modulate.a = 1.0
	hide()


func _set_alpha(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter(&"alpha", value)
	elif _overlay != null:
		_overlay.modulate.a = value


func _set_blur(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter(&"blur_amount", value)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
