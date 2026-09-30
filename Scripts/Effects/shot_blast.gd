class_name ShotBlast
extends Node2D
## One explosive round going off - the blast a [ShotExplosion] sets off where a
## DEVIL'S BREATH pellet lands.
##
## [b]Its damage is an ordinary hit.[/b] Every enemy inside the radius is struck
## once through one of his own [Hitbox]es, with the blast's [HitEffects], so the
## damage figure, the [Health] loss, the [HitReaction] shove and slow and the blood
## a kill spills are all the systems a pellet already drives. The blast stays live
## for its lifetime so a man stepping into it is caught too, and remembers
## everybody it has struck so none of them is struck twice.
##
## [b]Many of them go off at once[/b] - a whole blast of pellets - so the camera
## is not punched per blast. Blasts inside one [member stack_window] are counted
## together, the kick grows with the count along [member stack_exponent] up to
## [member stack_max], and the zoom, the tilt and the screen flash are started at
## most once per [member kick_interval]. The shake is the camera's own max, so it
## never adds up either. Particles are per blast and overlap freely; sounds are
## too, up to [member max_sounds_per_volley] a volley.
##
## Its size, flash and weight all scale off the radius and damage it was set off
## with, against [member reference_radius] and [member reference_damage], so a
## blast retuned on the Legendary - or grown by an upgrade later - looks the part
## without anything here being authored twice.

@export_group("Scaling")
## The radius the parts below are authored for. A larger blast draws its flare,
## fire, smoke and embers larger by (radius / this) ^ [member radius_influence].
@export var reference_radius: float = 48.0
@export_range(0.0, 2.0, 0.01) var radius_influence: float = 1.0
## The damage the camera and flash below are authored for. A heavier blast kicks
## harder by (damage / this) ^ [member damage_influence].
@export var reference_damage: float = 30.0
@export_range(0.0, 2.0, 0.01) var damage_influence: float = 0.35
## Ceiling on either factor, so a huge upgrade cannot fill the screen.
@export var max_scale_factor: float = 2.5

@export_group("Flare")
## The bright core - drawn over everything for an instant.
@export var flare_path: NodePath = ^"Flare"
@export var flare_scale: float = 0.08
@export var flare_growth: float = 1.6
@export var flare_seconds: float = 0.14
@export var flare_modulate := Color(2.2, 1.35, 0.7, 1.0)
## The light it throws on the ground and the men nearby.
@export var light_path: NodePath = ^"Light"
@export var light_colour := Color(1.0, 0.45, 0.12)
@export var light_energy: float = 2.4
@export var light_texture_scale: float = 1.6
@export var light_seconds: float = 0.16

@export_group("Particles")
## Bursts restarted as the blast goes off: the fire, the smoke, the embers. Each
## is an ordinary [CPUParticles2D] tuned in its own inspector; their particle size
## is multiplied by the radius factor.
@export var burst_paths: Array[NodePath] = [^"Fire", ^"Smoke", ^"Embers"]
## Smoke artwork, one picked per blast, handed to the particles at [member smoke_path].
@export var smoke_path: NodePath = ^"Smoke"
@export var smoke_textures: Array[Texture2D] = []

@export_group("Camera")
## How hard one blast right under the camera shakes it, in pixels.
@export var shake_strength: float = 5.0
@export var shake_duration: float = 0.14
## Extra zoom per kick - 0.02 is 2% closer - out and back.
@export var zoom_kick: float = 0.018
@export var zoom_out_time: float = 0.03
@export var zoom_back_time: float = 0.14
## Most the screen tilts per kick, in degrees, away from the side the blast is on.
@export var rotation_degrees_kick: float = 0.35
@export var rotation_out_time: float = 0.03
@export var rotation_back_time: float = 0.16
@export var camera_channel: StringName = &"devils_breath"
@export var camera_priority: int = 0
## Beyond this distance from the centre of the screen, in pixels, a blast is felt
## at [member far_scale]. Nearer ones are felt more.
@export var falloff_distance: float = 900.0
@export_range(0.0, 1.0, 0.01) var far_scale: float = 0.25

@export_group("Camera stacking")
## Blasts closer together than this, in seconds, count as one volley.
@export var stack_window: float = 0.12
## How the kick grows with the blasts in one volley: count ^ this. 0 keeps every
## volley as strong as one blast; 1 grows it linearly.
@export_range(0.0, 1.0, 0.01) var stack_exponent: float = 0.4
## The most one volley's kick is multiplied by.
@export var stack_max: float = 2.2
## Least time between two zoom / tilt / flash kicks, however many blasts land.
@export var kick_interval: float = 0.06

@export_group("Screen flash")
@export var screen_flash_enabled: bool = true
@export var screen_flash_colour := Color(1.0, 0.5, 0.18)
@export_range(0.0, 1.0) var screen_flash_peak: float = 0.07
@export var screen_flash_fade: float = 0.1

@export_group("Sound")
## The bank the blast is heard through - its bus and positional fields.
@export var sound_bank_path: NodePath = ^"Sounds"
## The Legendary's explosion layer, one picked per blast. Empty is silent.
@export var sounds: Array[AudioStream] = []
@export var sound_volume_db: float = 0.0
## Pitch picked per blast, between the two. Below 1 is deeper.
@export var sound_pitch := Vector2(0.86, 1.02)
## Level taken off each further blast in the same volley, so eight at once are a
## heavier sound rather than eight times louder.
@export var stack_volume_drop_db: float = 1.5
## Most taken off by that.
@export var stack_volume_floor_db: float = -9.0
## Most blasts in one volley that are heard. A full shot of pellets going off
## together is a few overlapping blasts rather than a wall of them; the rest still
## flash, burn and hurt, silently. 0 or below hears every one.
@export var max_sounds_per_volley: int = 3
## The sound is faded from its level down to silence from here, in seconds, over
## [member sound_fade] - it is kept short however long the recording runs. 0 plays
## it all and fades only its last [member sound_fade] - see [method SoundBank.fade_tail].
@export var sound_cut_after: float = 0.9
@export var sound_fade: float = 0.35

@export_group("Gore")
## What a man killed by this blast comes apart into - the game's own [Explosion]
## scene, whose [method Explosion.tear_apart_by_hit] is the gore pieces, the gore
## sound and the body taken away, with none of that explosion's own blast. The
## killing hit itself still lands through his [Hitbox] like any other, so his
## blood, his payout and the blast's effects are all his ordinary death. A man the
## blast does not kill is only hit. Null leaves blast kills dying the ordinary way.
@export var gore_effect: PackedScene
## Only a man carrying a node of this class comes apart - the ordinary head-pop
## death that the gore stands in for. Empty allows anybody.
@export var gore_requires: StringName = &"EnemyHeadPop"
## Never a man carrying a node of any of these classes: a boss has his own defeat,
## and a bomber his own blast.
@export var gore_excludes: Array[StringName] = [&"MiniBoss", &"BomberFuse"]

## Shared by every blast, so a volley is counted across all of them.
static var _volley_start_ms: int = -100000
static var _volley_count: int = 0
static var _last_kick_ms: int = -100000

var _damage: float = 0.0
var _radius: float = 0.0
var _mask: int = 0
var _effects: HitEffects
var _falloff: float = 0.0
var _falloff_exponent: float = 1.0
var _live_left: float = 0.0
var _struck: Array[Node] = []
var _shape := CircleShape2D.new()
## What the camera kick is multiplied by - a BLOOD REAPER volley's blast is turned
## down with it. See [member WeaponStats.power_scale].
var _power: float = 1.0
## Handed to [method Explosion.tear_if_fatal] for every man this blast tears apart.
var _on_executed: Callable


func _ready() -> void:
	for path: NodePath in [flare_path, light_path]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false
	set_physics_process(false)


## Sets the blast off where it stands: [param damage] to each enemy within
## [param radius] pixels, live for [param lifetime] seconds, looking for hitboxes on
## [param mask], each struck with [param effects]. [param falloff] is the share of
## the damage lost at the edge, shaped by [param falloff_exponent] - see
## [member ShotExplosion.falloff]. [param spared] is never struck - the enemy the
## round already hit directly, when he is not to take the blast too. [param power]
## scales the camera kick - see [member WeaponStats.power_scale] - and
## [param on_executed] is told of every man the blast tears apart.
func detonate(damage: float, radius: float, lifetime: float, mask: int, effects: HitEffects,
		falloff: float = 0.0, falloff_exponent: float = 1.0, spared: Node = null,
		power: float = 1.0, on_executed: Callable = Callable()) -> void:
	_power = maxf(power, 0.0)
	_on_executed = on_executed
	_damage = maxf(damage, 0.0)
	_radius = maxf(radius, 0.0)
	_mask = mask
	_effects = effects
	_falloff = clampf(falloff, 0.0, 1.0)
	_falloff_exponent = maxf(falloff_exponent, 0.01)
	if spared != null:
		_struck.append(spared)
	_shape.radius = maxf(_radius, 0.01)

	var size := _factor(_radius, reference_radius, radius_influence)
	var weight := _factor(_damage, reference_damage, damage_influence)
	_flare(size)
	_bursts(size)
	var volley := _join_volley()
	_camera(weight, volley)
	_sound(volley)

	_catch()
	_live_left = maxf(lifetime, 0.0)
	set_physics_process(_live_left > 0.0)
	get_tree().create_timer(_life(), false).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	_live_left -= delta
	_catch()
	if _live_left <= 0.0:
		set_physics_process(false)


## Strikes every enemy inside the radius not yet struck by this blast, once each.
## A blast with no damage but with [HitEffects] - HELL CHAMBER's shockwave - is
## crowd control only: it shoves and staggers each man through his own
## [HitReaction] and never touches his [Health].
func _catch() -> void:
	if (_damage <= 0.0 and _effects == null) or _radius <= 0.0 or _mask == 0 or not is_inside_tree():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = _mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found := get_world_2d().direct_space_state.intersect_shape(query, 64)
	# One hitbox per man - his nearest - so a head and a body are one victim.
	var nearest: Dictionary = {}
	for entry: Dictionary in found:
		var hitbox := entry.get("collider") as Hitbox
		if hitbox == null:
			continue
		var victim := hitbox.owner if hitbox.owner != null else hitbox.get_parent()
		if victim == null or _struck.has(victim):
			continue
		var current := nearest.get(victim) as Hitbox
		if current == null or _closer(hitbox, current):
			nearest[victim] = hitbox
	for victim: Node in nearest:
		_struck.append(victim)
		var hitbox := nearest[victim] as Hitbox
		if not is_instance_valid(hitbox):
			continue
		var away := hitbox.global_position - global_position
		var damage := _damage_at(away.length())
		if away.is_zero_approx():
			away = Vector2.RIGHT.rotated(randf() * TAU)
		if _damage <= 0.0:
			_shove(victim, hitbox, away.normalized())
			continue
		if not _tear_if_fatal(victim, hitbox, damage, away.normalized()):
			hitbox.take_hit(damage, away.normalized(), hitbox.global_position, false, _effects)


## Knocks [param victim] away along [param away] and staggers him with this blast's
## [HitEffects], without a hit - the damage-free blast's whole effect. A man who is
## dead, or has no [HitReaction], is left alone.
func _shove(victim: Node, hitbox: Hitbox, away: Vector2) -> void:
	var health := hitbox.get_node_or_null(hitbox.health_path) as Health
	if health != null and not health.is_alive():
		return
	var reactions := victim.find_children("*", &"HitReaction", true, false)
	if not reactions.is_empty():
		(reactions[0] as HitReaction).react(away, _effects, false)


## The blast's damage to a man [param distance] pixels from its centre, after the
## falloff towards the edge.
func _damage_at(distance: float) -> float:
	if _falloff <= 0.0 or _radius <= 0.0:
		return _damage
	var reach := pow(clampf(distance / _radius, 0.0, 1.0), _falloff_exponent)
	return _damage * (1.0 - _falloff * reach)


## Lands the blast on [param victim] through [member gore_effect] when it is going
## to kill him, so he comes apart - and reports whether it did. Worked out exactly
## as the hit will be: the hitbox's multiplier on the blast's damage against what
## he has left, and nothing while he is in a grace window that would drop the hit.
## A man already dead or already going is never torn twice.
##
## It is a real blast, so the man is thrown apart from its centre rather than torn
## where he stood - see [member Explosion.throws_bodies].
func _tear_if_fatal(victim: Node, hitbox: Hitbox, damage: float, away: Vector2) -> bool:
	return Explosion.tear_if_fatal(gore_effect, victim, hitbox, damage, away,
		hitbox.global_position, _effects, gore_requires, gore_excludes, false, _on_executed,
		global_position, _radius)


func _closer(a: Hitbox, b: Hitbox) -> bool:
	return a.global_position.distance_squared_to(global_position) \
		< b.global_position.distance_squared_to(global_position)


func _factor(value: float, reference: float, influence: float) -> float:
	if reference <= 0.0 or value <= 0.0:
		return 1.0
	return clampf(pow(value / reference, influence), 1.0 / maxf(max_scale_factor, 1.0), maxf(max_scale_factor, 1.0))


func _flare(size: float) -> void:
	var flare := get_node_or_null(flare_path) as Sprite2D
	if flare != null and flare_seconds > 0.0:
		flare.visible = true
		flare.modulate = flare_modulate
		flare.rotation = randf() * TAU
		flare.scale = Vector2.ONE * flare_scale * size
		var tween := create_tween().set_parallel(true)
		tween.tween_property(flare, "scale", Vector2.ONE * flare_scale * size * maxf(flare_growth, 0.01),
			flare_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(flare, "modulate:a", 0.0, flare_seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var light := get_node_or_null(light_path) as PointLight2D
	if light != null and light_seconds > 0.0:
		light.visible = true
		light.color = light_colour
		light.energy = light_energy
		light.texture_scale = maxf(light_texture_scale * size, 0.01)
		var fade := create_tween()
		fade.tween_property(light, "energy", 0.0, light_seconds) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _bursts(size: float) -> void:
	var smoke := get_node_or_null(smoke_path) as CPUParticles2D
	if smoke != null and not smoke_textures.is_empty():
		var pick := smoke_textures[randi() % smoke_textures.size()]
		if pick != null:
			smoke.texture = pick
	for path: NodePath in burst_paths:
		var burst := get_node_or_null(path) as CPUParticles2D
		if burst == null:
			continue
		burst.scale_amount_min *= size
		burst.scale_amount_max *= size
		burst.initial_velocity_min *= size
		burst.initial_velocity_max *= size
		burst.restart()
		burst.emitting = true


## Counts this blast into the volley it belongs to and returns the count so far.
func _join_volley() -> int:
	var now := Time.get_ticks_msec()
	if now - _volley_start_ms > int(stack_window * 1000.0):
		_volley_start_ms = now
		_volley_count = 0
	_volley_count += 1
	return _volley_count


func _camera(weight: float, volley: int) -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	var stack := minf(pow(float(volley), stack_exponent), maxf(stack_max, 1.0))
	var offset := global_position - camera.get_screen_center_position()
	var near := 1.0
	if falloff_distance > 0.0:
		near = lerpf(1.0, far_scale, clampf(offset.length() / falloff_distance, 0.0, 1.0))
	var strength := weight * stack * near * _power

	# The camera keeps the larger shake, so every blast may ask.
	if shake_strength > 0.0 and shake_duration > 0.0:
		camera.shake(shake_strength * strength, shake_duration)

	var now := Time.get_ticks_msec()
	if now - _last_kick_ms < int(kick_interval * 1000.0):
		return
	_last_kick_ms = now
	if not is_zero_approx(zoom_kick):
		camera.zoom_kick(zoom_kick * strength, zoom_out_time, zoom_back_time,
			camera_channel, camera_priority)
	if not is_zero_approx(rotation_degrees_kick):
		var side := -1.0 if offset.x > 0.0 else 1.0
		camera.rotation_kick(rotation_degrees_kick * strength * side, rotation_out_time,
			rotation_back_time, camera_channel, camera_priority)
	if screen_flash_enabled and screen_flash_peak > 0.0:
		var flash := ScreenFlash.get_active(self)
		if flash != null:
			flash.flash(screen_flash_colour, clampf(screen_flash_peak * strength, 0.0, 1.0),
				0.0, screen_flash_fade)


func _sound(volley: int) -> void:
	if sounds.is_empty() or (max_sounds_per_volley > 0 and volley > max_sounds_per_volley):
		return
	var bank := get_node_or_null(sound_bank_path) as SoundBank
	if bank == null:
		return
	var drop := maxf(-stack_volume_drop_db * float(volley - 1), stack_volume_floor_db)
	var voice := bank.play_detached_stream_at(sounds[randi() % sounds.size()], global_position,
		sound_volume_db + drop)
	if voice == null:
		return
	voice.pitch_scale = randf_range(minf(sound_pitch.x, sound_pitch.y), maxf(sound_pitch.x, sound_pitch.y))
	# Down to true silence either way, through the bank's shared fade. A cut that
	# would land past the end of the recording is its natural tail instead.
	var length := voice.stream.get_length() / maxf(voice.pitch_scale, 0.01)
	if sound_cut_after > 0.0 and sound_cut_after + sound_fade < length:
		bank.fade_out(voice, sound_cut_after, sound_fade)
	else:
		bank.fade_tail(voice, sound_fade)


## How long the node lives: the longest of its parts, and its damage window.
func _life() -> float:
	var longest := maxf(maxf(flare_seconds, light_seconds), _live_left)
	for path: NodePath in burst_paths:
		var burst := get_node_or_null(path) as CPUParticles2D
		if burst != null:
			longest = maxf(longest, burst.lifetime * (1.0 + burst.lifetime_randomness))
	return longest + 0.2
