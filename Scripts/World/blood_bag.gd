class_name BloodBag
extends Area2D
## The diseased blood blob a VOLATILE BLOOD kill leaves where the man fell: a small
## mass of almost black, corrupted blood under a dark blood-red rim, hovering just
## off the ground with a slow slime-like wobble, a few thick droplets of blood hung
## round it. Walk through it or shoot it and it ruptures - see
## [method VolatileBlood.burst]. Left alone it fades, having done nothing.
##
## [b]Shooting it uses the shots' own path.[/b] It is an [Area2D] on the layer a
## round sweeps for, answering [method take_projectile_hit] - the same hook the
## thrown coin and a boss's sword circle answer - so no weapon needs to know it
## exists. Only a round armed from a block carrying this bag's [VolatileBlood]
## bursts it; any other passes straight through. It is not a [Hitbox], so blasts,
## enemies and the burst itself never see it. Its hit circle is
## [member VolatileBlood.shot_radius] across, whatever size the blob is drawn at, and
## centred where the blob hovers at rest. Walking into it is still measured from its
## foot, where the man fell, and the burst goes off there.
##
## [b]The blob is RECOIL DEVIL's ward, gone bad.[/b] It is drawn by its own
## [code]volatile_blood.gdshader[/code], built on the ward's shimmer and wandering
## edge but with a near-black body - the ward itself is never touched. Everything
## it is drawn and moved with is the [VolatileBlood] part's, handed over by
## [method setup] before it enters the tree.

## Emitted as it bursts, with where.
signal burst(at: Vector2)
## Emitted as it starts to fade, untriggered.
signal expired

## Group every live bag is in - one that has burst or is fading has left it.
const GROUP := &"blood_bag"

## The faint glow on the ground under it, drawn additive.
@export var glow_path: NodePath = ^"Glow"
## The shadow on the ground under it.
@export var shadow_path: NodePath = ^"Shadow"
## The blob itself, carrying the Volatile Blood shader.
@export var blob_path: NodePath = ^"Blob"
## Where the globules behind the blob and in front of it are drawn, so they read as
## hanging round it rather than stuck on top.
@export var globules_back_path: NodePath = ^"GlobulesBack"
@export var globules_front_path: NodePath = ^"GlobulesFront"
## The quiet loop it makes while it waits.
@export var idle_sound_path: NodePath = ^"IdleSound"

@export_group("Appearing")
## Seconds it takes to swell up to full size as it drops.
@export var appear_time: float = 0.18
## What size it swells up from, as a share of full size.
@export_range(0.0, 1.0, 0.01) var appear_from: float = 0.3
## Seconds the idle loop takes to fade in and, on fading or bursting, out.
@export var idle_fade_time: float = 0.3

var _part: VolatileBlood
var _stats: WeaponStats
var _age: float = 0.0
var _phase: float = 0.0
var _beat: float = 1.0
var _done: bool = false
var _spawn_at := Vector2.INF
## 0 to 1 while it tears apart as it bursts; below 0 while it is whole.
var _rupture: float = -1.0
## Per globule: its angle round the blob, its share of the spread, its size and its
## own phase.
var _globules: Array[Vector4] = []
var _material: ShaderMaterial


## Hands the bag the part it was left by, the block that killed the man and where
## he fell, which it is stood on as it enters the tree. Call it before it does.
func setup(part: VolatileBlood, stats: WeaponStats, at: Vector2 = Vector2.INF) -> void:
	_part = part
	_stats = stats
	_spawn_at = at


## How many bags are lying on the ground in [param tree].
static func count_active(tree: SceneTree) -> int:
	return 0 if tree == null else tree.get_nodes_in_group(GROUP).size()


func _enter_tree() -> void:
	if _spawn_at != Vector2.INF:
		global_position = _spawn_at
		_spawn_at = Vector2.INF
		reset_physics_interpolation()
	if not _done:
		add_to_group(GROUP)


func _ready() -> void:
	if _part == null:
		_part = VolatileBlood.new()
	var shape := get_node_or_null(^"Shape") as CollisionShape2D
	if shape != null:
		var circle := CircleShape2D.new()
		circle.radius = maxf(_part.shot_radius, 1.0)
		shape.shape = circle
		# Centred where the blob hovers, so a shot at what is seen lands.
		shape.position = Vector2(0.0, -_part.float_base_height)

	var blob := get_node_or_null(blob_path) as Node2D
	if blob != null:
		# Its own copy, so one bag's pulse never shows on another.
		var shared := blob.material as ShaderMaterial
		if shared != null:
			_material = shared.duplicate() as ShaderMaterial
			blob.material = _material
		blob.draw.connect(_draw_blob.bind(blob))
	var shadow := get_node_or_null(shadow_path) as Node2D
	if shadow != null:
		shadow.draw.connect(_draw_shadow.bind(shadow))
	var back := get_node_or_null(globules_back_path) as Node2D
	if back != null:
		back.draw.connect(_draw_globules.bind(back, false))
	var front := get_node_or_null(globules_front_path) as Node2D
	if front != null:
		front.draw.connect(_draw_globules.bind(front, true))

	_scatter_globules()
	_setup_glow()
	_setup_idle_sound()
	_apply_shader()

	var full := Vector2.ONE * maxf(_part.bag_scale, 0.01)
	if appear_time > 0.0:
		scale = full * appear_from
		create_tween().tween_property(self, ^"scale", full, appear_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale = full
	_animate(0.0)


func _process(delta: float) -> void:
	if _rupture >= 0.0:
		_rupture = minf(_rupture + delta / maxf(_part.rupture_time, 0.001), 1.0)
		_animate(delta)
		if _rupture >= 1.0:
			queue_free()
		return
	_animate(delta)
	if _done:
		return
	_age += delta
	if _find_toucher() != null:
		trigger(_stats)
		return
	if _age >= maxf(_part.lifetime, 0.0):
		_expire()


## Seconds left before it fades.
func get_time_left() -> float:
	return 0.0 if _part == null else maxf(_part.lifetime - _age, 0.0)


func is_done() -> bool:
	return _done


## A round's sweep has reached the bag at [param at]. Bursts it - credited to the
## round's own block - when that block carries this bag's [VolatileBlood]; any other
## round is refused, which the projectile reads as "fly straight through". Answers
## whether the round is spent on it.
func take_projectile_hit(shot: Projectile, _at: Vector2) -> bool:
	if _done or shot == null or not is_instance_valid(shot) or _age < _part.shot_arm_delay:
		return false
	var stats := shot.get_weapon_stats()
	if stats == null or not stats.kill_rewards.has(_part):
		return false
	trigger(stats)
	return _part.consumes_projectile


## Bursts the bag now, credited to [param stats] - see [method VolatileBlood.burst].
## Once only: a bag walked into and shot in the same frame bursts once. The burst
## and its damage land at once; the blob then tears apart over
## [member VolatileBlood.rupture_time] and is gone.
func trigger(stats: WeaponStats) -> void:
	if _done:
		return
	_finish()
	var at := global_position
	_part.burst(get_tree().current_scene, at, stats if stats != null else _stats)
	burst.emit(at)
	_fade_idle_sound()
	if _part.rupture_time <= 0.0:
		queue_free()
		return
	_rupture = 0.0


# --- Presentation ----------------------------------------------------------------

## Moves every drawn part for this frame: the pulse, the float and squash, the
## rupture, the globules.
func _animate(delta: float) -> void:
	var life := maxf(_part.lifetime, 0.001)
	var rate := _part.pulse_rate * lerpf(1.0, _part.end_pulse_rate_multiplier,
		clampf(_age / life, 0.0, 1.0))
	_phase += delta * rate * TAU
	var swing := clampf(_part.pulse_strength, 0.0, 1.0)
	_beat = 1.0 - swing + swing * (0.5 + 0.5 * cos(_phase))

	var bob := _bob()
	var blob := get_node_or_null(blob_path) as Node2D
	if blob != null:
		blob.position = Vector2(0.0, -(_part.float_base_height + bob * _part.float_height))
		# Squashed wide at the bottom of the bob, stretched tall at the top, the area
		# kept - a slime settling and lifting.
		var squash := clampf(_part.squash_amount, 0.0, 0.5) * -bob
		var shape := Vector2(1.0 + squash, 1.0 / (1.0 + squash))
		if _rupture >= 0.0:
			var tear := _ease_out(_rupture)
			shape *= lerpf(1.0, maxf(_part.rupture_swell, 0.0), tear)
			blob.modulate.a = 1.0 - _rupture
		blob.scale = shape
		blob.queue_redraw()
	if _material != null:
		_material.set_shader_parameter(&"pulse", swing * (0.5 + 0.5 * cos(_phase)))

	var glow := get_node_or_null(glow_path) as Node2D
	if glow != null:
		glow.modulate.a = _part.glow_color.a * (0.6 + 0.4 * _beat) * (1.0 - maxf(_rupture, 0.0))
	for path: NodePath in [shadow_path, globules_back_path, globules_front_path]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.queue_redraw()


## -1 at the bottom of the float, 1 at the top - one smooth sine, never a snap.
func _bob() -> float:
	return sin(_age * maxf(_part.float_speed, 0.0) * TAU)


func _draw_blob(blob: Node2D) -> void:
	# One quad big enough for the wobble; the shader decides what of it is drawn.
	var reach := _part.blob_radius + absf(_part.wobble_strength) + 3.0
	blob.draw_rect(Rect2(-Vector2.ONE * reach, Vector2.ONE * reach * 2.0), Color.WHITE)


## A soft ellipse on the ground, smaller and fainter as the blob rises.
func _draw_shadow(shadow: Node2D) -> void:
	var lift := 0.5 + 0.5 * _bob()
	var size := _part.shadow_size * lerpf(1.0, 0.85, lift)
	var colour := _part.shadow_color
	colour.a *= lerpf(1.0, 0.75, lift) * (1.0 - maxf(_rupture, 0.0))
	if colour.a <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / size.x))
	# Two rings, so its edge is soft rather than a hard disc.
	shadow.draw_circle(Vector2.ZERO, size.x * 0.5, Color(colour, colour.a * 0.55))
	shadow.draw_circle(Vector2.ZERO, size.x * 0.34, Color(colour, colour.a * 0.6))
	shadow.draw_set_transform(Vector2.ZERO)


## The globules on one side of the blob - those behind it, or those in front.
func _draw_globules(node: Node2D, front: bool) -> void:
	var centre := Vector2(0.0, -_part.float_base_height)
	var t := _age * _part.globule_speed
	var fling := 1.0
	var fade := 1.0
	if _rupture >= 0.0:
		fling = lerpf(1.0, maxf(_part.rupture_fling, 1.0), _ease_out(_rupture))
		fade = 1.0 - _rupture
	for g: Vector4 in _globules:
		var angle := g.x + t * (0.35 + 0.3 * g.w)
		# Round the blob in a flattened ring - the far side is behind it.
		var in_front := sin(angle) > 0.0
		if in_front != front:
			continue
		var spread := _part.globule_spread * g.y \
			+ _part.globule_spread_wander * sin(t * 1.7 + g.w * TAU)
		var at := centre + Vector2(cos(angle), sin(angle) * 0.6) * spread * fling
		at.y -= _part.globule_bob * sin(t * 2.3 + g.w * 11.0)
		var radius := g.z * (1.0 + 0.1 * sin(t * 3.1 + g.w * 5.0))
		# Heavier at the bottom: a droop, then a darker underside and a pinprick of wet.
		node.draw_set_transform(at, 0.0, Vector2(1.0, 1.12))
		node.draw_circle(Vector2.ZERO, radius, Color(_part.globule_dark_color, _part.globule_dark_color.a * fade))
		node.draw_circle(Vector2(0.0, -radius * 0.18), radius * 0.78,
			Color(_part.globule_color, _part.globule_color.a * fade))
		node.draw_circle(Vector2(-radius * 0.3, -radius * 0.42), radius * 0.22,
			Color(_part.sheen_color, _part.sheen_color.a * fade))
	node.draw_set_transform(Vector2.ZERO)


## Where each globule hangs, fixed for the bag's life: evenly round the blob with a
## little randomness, so no two bags look alike.
func _scatter_globules() -> void:
	_globules.clear()
	var count := maxi(_part.globule_count, 0)
	var offset := randf() * TAU
	for i in count:
		var angle := offset + TAU * float(i) / float(maxi(count, 1)) + randf_range(-0.35, 0.35)
		var size := _part.globule_size * (1.0 + randf_range(-1.0, 1.0) * _part.globule_size_variation)
		_globules.append(Vector4(angle, randf_range(0.8, 1.1), maxf(size, 0.5), randf()))


func _setup_glow() -> void:
	var sprite := get_node_or_null(glow_path) as Sprite2D
	if sprite == null:
		return
	sprite.modulate = _part.glow_color
	if sprite.texture != null:
		var across := _part.blob_radius * 2.0 * maxf(_part.glow_scale, 0.0)
		var tex := sprite.texture.get_size()
		sprite.scale = Vector2(across / maxf(tex.x, 1.0), across * 0.4 / maxf(tex.y, 1.0))


func _setup_idle_sound() -> void:
	var player := get_node_or_null(idle_sound_path) as AudioStreamPlayer2D
	if player == null:
		return
	if _part.idle_sound == null:
		player.stream = null
		return
	player.stream = _part.idle_sound
	player.pitch_scale = maxf(_part.idle_pitch, 0.01) * randf_range(0.95, 1.05)
	player.max_distance = maxf(_part.idle_max_distance, 1.0)
	player.volume_db = -60.0
	player.play(randf() * maxf(_part.idle_sound.get_length() - 0.1, 0.0))
	create_tween().tween_property(player, ^"volume_db", _part.idle_volume_db, maxf(idle_fade_time, 0.01))


func _fade_idle_sound() -> void:
	var player := get_node_or_null(idle_sound_path) as AudioStreamPlayer2D
	if player == null or not player.playing:
		return
	create_tween().tween_property(player, ^"volume_db", -60.0, maxf(idle_fade_time, 0.01))


func _apply_shader() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"radius_px", _part.blob_radius)
	_material.set_shader_parameter(&"edge_wobble_px", _part.wobble_strength)
	_material.set_shader_parameter(&"wobble_speed", _part.wobble_speed)
	_material.set_shader_parameter(&"lobes", float(_part.wobble_lobes))
	_material.set_shader_parameter(&"rim_width_px", _part.rim_width)
	_material.set_shader_parameter(&"distortion_px", _part.distortion)
	_material.set_shader_parameter(&"core_color", _part.core_color)
	_material.set_shader_parameter(&"rim_color", _part.rim_color)
	_material.set_shader_parameter(&"vein_color", _part.vein_color)
	_material.set_shader_parameter(&"sheen_color", _part.sheen_color)


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.0)


# --- Gameplay --------------------------------------------------------------------

## The first body of [member VolatileBlood.toucher_group] standing within reach and
## still alive, or null.
func _find_toucher() -> Node2D:
	var reach := maxf(_part.trigger_radius, 0.0) * scale.x
	for node: Node in get_tree().get_nodes_in_group(_part.toucher_group):
		var body := node as Node2D
		if body == null or body.global_position.distance_to(global_position) > reach:
			continue
		var health := body.get_node_or_null(^"Health") as Health
		if health != null and not health.is_alive():
			continue
		return body
	return null


func _expire() -> void:
	_finish()
	expired.emit()
	_fade_idle_sound()
	var fade := maxf(_part.fade_duration, 0.0)
	if fade <= 0.0:
		queue_free()
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"modulate:a", 0.0, fade)
	tween.tween_property(self, ^"scale", scale * 0.7, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## Out of the live bags for good: no more bursting, and no shot stops on it.
func _finish() -> void:
	_done = true
	remove_from_group(GROUP)
	set_deferred(&"monitorable", false)
	var shape := get_node_or_null(^"Shape") as CollisionShape2D
	if shape != null:
		shape.set_deferred(&"disabled", true)
