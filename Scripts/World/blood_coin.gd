class_name BloodCoin
extends Node2D
## The coin a DEVIL'S COIN kill leaves where the man fell: lying on the ground for a
## moment, pulsing, a ring round it running down the time left. The player takes it
## by walking over it - no key - and it pays its blood into the carried wallet.
## Left alone it fades out and pays nothing.
##
## Every number it is played with - reward, life, reach, size, glow, pulse, fade -
## is the [DevilsCoin] part's, handed over by [method setup] before it enters the
## tree, so the whole Legendary is tuned in one resource. It never hurts, pushes or
## changes anything; taking it is the only thing it does.

## Emitted as it is taken, with the blood it paid.
signal collected(amount: int)
## Emitted as it starts to fade, untaken.
signal expired

## Group every live coin is in - one that is fading or taken has left it - so the
## developer panel, or a test, can count them without holding any.
const GROUP := &"blood_coin"

## The carried wallet the reward is paid into.
@export var wallet_path: NodePath = ^"/root/Blood"
## The coin face, tinted with [member DevilsCoin.tint].
@export var art_path: NodePath = ^"Art"
## The glow under it that pulses.
@export var glow_path: NodePath = ^"Glow"
## Sounds the taking plays, detached so they outlive the coin.
@export var sound_bank_path: NodePath = ^"Sounds"
@export var pickup_sound: StringName = &"pickup"

@export_group("Time ring")
## The ring drawn round the coin, emptying as its life runs out, in pixels at
## a coin scale of 1.
@export var ring_radius: float = 19.0
@export var ring_width: float = 2.0
@export var ring_color := Color(1.0, 0.18, 0.1, 0.85)
## Where the ring and glow sit against the node, which stands on the ground.
@export var ring_offset := Vector2.ZERO

@export_group("Appearing")
## Seconds it takes to pop up to full size as it drops.
@export var appear_time: float = 0.16
## What size it pops up from, as a share of full size.
@export_range(0.0, 1.0, 0.01) var appear_from: float = 0.35

var _coin: DevilsCoin
var _age: float = 0.0
var _phase: float = 0.0
var _done: bool = false
var _glow_base_scale := Vector2.ONE
var _glow_base_alpha: float = 1.0


## Hands the coin the part it was left by. Call it before it enters the tree.
func setup(coin: DevilsCoin) -> void:
	_coin = coin


## How many coins are lying on the ground to be taken, in [param tree].
static func count_active(tree: SceneTree) -> int:
	return 0 if tree == null else tree.get_nodes_in_group(GROUP).size()


func _enter_tree() -> void:
	if not _done:
		add_to_group(GROUP)


func _ready() -> void:
	if _coin == null:
		_coin = DevilsCoin.new()
	var art := get_node_or_null(art_path) as CanvasItem
	if art != null:
		art.modulate = _coin.tint
	var glow := get_node_or_null(glow_path) as Node2D
	if glow != null:
		glow.modulate = _coin.glow_color
		_glow_base_alpha = _coin.glow_color.a
		glow.scale *= maxf(_coin.glow_scale, 0.0)
		_glow_base_scale = glow.scale

	var full := Vector2.ONE * maxf(_coin.coin_scale, 0.01)
	if appear_time > 0.0:
		scale = full * appear_from
		create_tween().tween_property(self, ^"scale", full, appear_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale = full


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_pulse(delta)
	queue_redraw()

	if _find_taker() != null:
		_collect()
		return
	if _age >= maxf(_coin.lifetime, 0.0):
		_expire()


## Seconds left before it fades.
func get_time_left() -> float:
	return 0.0 if _coin == null else maxf(_coin.lifetime - _age, 0.0)


func is_done() -> bool:
	return _done


## The glow beats, faster as the coin runs out.
func _pulse(delta: float) -> void:
	var glow := get_node_or_null(glow_path) as Node2D
	if glow == null:
		return
	var life := maxf(_coin.lifetime, 0.001)
	var rate := _coin.pulse_rate * lerpf(1.0, _coin.end_pulse_rate_multiplier,
		clampf(_age / life, 0.0, 1.0))
	_phase += delta * rate * TAU
	# 0..1, starting bright.
	var beat := 0.5 + 0.5 * cos(_phase)
	var swing := clampf(_coin.pulse_strength, 0.0, 1.0)
	var strength := 1.0 - swing + swing * beat
	glow.scale = _glow_base_scale * (1.0 - swing * 0.35 + swing * 0.35 * beat)
	glow.modulate.a = _glow_base_alpha * strength


func _draw() -> void:
	if _done or _coin == null:
		return
	var left := get_time_left() / maxf(_coin.lifetime, 0.001)
	if left <= 0.0:
		return
	var start := -PI * 0.5
	draw_arc(ring_offset, ring_radius, start, start + TAU * left, 40, ring_color,
		ring_width, true)


## The first body of [member DevilsCoin.collector_group] standing within reach and
## still alive, or null.
func _find_taker() -> Node2D:
	var reach := maxf(_coin.pickup_radius, 0.0)
	for node: Node in get_tree().get_nodes_in_group(_coin.collector_group):
		var body := node as Node2D
		if body == null or body.global_position.distance_to(global_position) > reach:
			continue
		var health := body.get_node_or_null(^"Health") as Health
		if health != null and not health.is_alive():
			continue
		return body
	return null


func _collect() -> void:
	_finish()
	var amount := maxi(_coin.blood_reward, 0)
	var wallet := get_node_or_null(wallet_path) as BloodWallet
	if wallet != null and amount > 0:
		wallet.add(amount)
	_play_burst()
	var bank := get_node_or_null(sound_bank_path) as SoundBank
	if bank != null:
		bank.play_detached_at(pickup_sound, global_position)
	collected.emit(amount)
	queue_free()


func _expire() -> void:
	_finish()
	expired.emit()
	var fade := maxf(_coin.fade_duration, 0.0)
	if fade <= 0.0:
		queue_free()
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"modulate:a", 0.0, fade)
	tween.tween_property(self, ^"scale", scale * 0.6, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Out of the live coins for good: no more taking, pulsing or ring.
func _finish() -> void:
	_done = true
	remove_from_group(GROUP)
	queue_redraw()


## Parented to the running scene, not to the coin, which goes this frame.
func _play_burst() -> void:
	var container := get_tree().current_scene
	if _coin.pickup_burst == null or container == null:
		return
	var burst := _coin.pickup_burst.instantiate() as Node2D
	if burst == null:
		return
	container.add_child(burst)
	burst.global_position = global_position + ring_offset * scale
	burst.reset_physics_interpolation()
	if burst.has_method(&"play"):
		burst.call(&"play")
	elif burst is CPUParticles2D:
		(burst as CPUParticles2D).emitting = true
