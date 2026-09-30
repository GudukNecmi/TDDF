class_name OneBigShellFeedback
extends Node
## What ONE BIG SHELL adds on top of an ordinary shot: the cannon leaving the
## barrel, and the weight of every hit it lands. The ordinary shot's sound, blast
## artwork, light and kick are still all [ShotgunFeedback]'s and are left as they
## are - only its pellet spark spray is withheld for a shell shot, and the burst
## here stands in for it.
##
## [b]It owns nothing about the shot.[/b] The weapon announces
## [code]big_shell_fired[/code] once per shell and [code]big_shell_struck[/code]
## once per landing, with where it struck, the way the shell was flying and how
## centred the hit was - see [signal CannonShell.struck] - and this only answers
## them. Every effect is oriented along the shell's own flight. With the Legendary
## off neither signal is ever sent.
##
## Audio goes through the weapon's own [SoundBank], each layer on a voice of its
## own, so layers - this, and any other Legendary's - overlap freely.

## The weapon whose shots are followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the layers are played through - its bus and positional fields.
@export var sound_bank_path: NodePath = ^"../Sounds"
## Where the muzzle effects are thrown from.
@export var muzzle_path: NodePath = ^"../MuzzleRig/Muzzle"

@export_group("Muzzle")
## The big flash thrown down the barrel - a [OneShotParticles] burst, aimed along
## the shot.
@export var muzzle_burst_scene: PackedScene
## What its particle size and speed are multiplied by.
@export var muzzle_burst_scale: float = 1.0
## The secondary ring a moment after the flash - a [ShotBlast] set off with no
## damage and no mask, so it is only a look.
@export var muzzle_ring_scene: PackedScene
@export var muzzle_ring_radius: float = 70.0
## Seconds after the flash before the ring.
@export var muzzle_ring_delay: float = 0.04
## How far ahead of the muzzle, along the aim, the ring goes off, in pixels.
@export var muzzle_ring_offset: float = 26.0
## Smoke rolled out of the barrel after the shot - a [OneShotParticles] burst.
@export var muzzle_smoke_scene: PackedScene

@export_group("Camera - fire")
## The punch of a shell leaving, on top of the ordinary shot's.
@export var fire_shake: float = 9.0
@export var fire_shake_duration: float = 0.2
## Zoom punch as a fraction - negative throws the view out.
@export var fire_zoom: float = -0.045
@export var fire_zoom_out_time: float = 0.04
@export var fire_zoom_back_time: float = 0.28
@export var fire_rotation: float = 1.4
@export var fire_rotation_back_time: float = 0.25
@export var fire_flash_colour := Color(1.0, 0.32, 0.08)
@export_range(0.0, 1.0) var fire_flash_peak: float = 0.1
@export var fire_flash_fade: float = 0.18
## Layer on [CameraController] the kicks are written to, and how loudly.
@export var camera_channel: StringName = &"one_big_shell"
@export var camera_priority: int = 0

@export_group("Impact - heavy")
## Everything a hit near the centre line throws at the point it struck, aimed
## along the flight - see [member OneBigShell.heavy_hit_from]. Each is a
## [OneShotParticles] burst, a [PressureWave] (the directional impact wave) or a
## [ShotBlast] (the flash, set off with no damage and no mask).
@export var heavy_impact_scenes: Array[PackedScene] = []
## Radius a [ShotBlast] among them is set off at.
@export var heavy_flash_radius: float = 60.0
## Strength a [PressureWave] among them is played at.
@export var heavy_wave_strength: float = 1.6
@export var heavy_shake: float = 11.0
@export var heavy_shake_duration: float = 0.22
@export var heavy_zoom: float = 0.03
@export var heavy_zoom_out_time: float = 0.03
@export var heavy_zoom_back_time: float = 0.2
## Added on top for a heavy hit that kills - blood thrown on along the flight.
## Blood only: a man the shell tears apart has the gore scene's own gore.
@export var lethal_scenes: Array[PackedScene] = []
## What the lethal blood's size and speed are multiplied by.
@export var lethal_scale: float = 1.4

@export_group("Impact - graze")
## What a hit out towards the rim throws instead - lighter, and aimed out to the
## side the victim was clipped on as well as along the flight.
@export var graze_impact_scenes: Array[PackedScene] = []
@export var graze_flash_radius: float = 30.0
@export var graze_wave_strength: float = 0.7
@export var graze_shake: float = 3.5
@export var graze_shake_duration: float = 0.12

@export_group("Audio")
## Layer played with each shell, over the ordinary blast. Empty plays none.
@export var fire_layer_sound: AudioStream
@export var fire_layer_volume_db: float = -3.0
@export var fire_layer_pitch: float = 1.0
## Played where each hit lands. Empty plays none.
@export var impact_sound: AudioStream
@export var impact_heavy_volume_db: float = -2.0
@export var impact_graze_volume_db: float = -9.0
@export var impact_heavy_pitch: float = 0.92
@export var impact_graze_pitch: float = 1.15

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D


func _ready() -> void:
	if _source == null:
		return
	if _source.has_signal(&"big_shell_fired"):
		_source.connect(&"big_shell_fired", _on_fired)
	if _source.has_signal(&"big_shell_struck"):
		_source.connect(&"big_shell_struck", _on_struck)


# --- Firing ----------------------------------------------------------------------

func _on_fired(_shell: Node) -> void:
	_play_layer(fire_layer_sound, fire_layer_volume_db, fire_layer_pitch)
	if _muzzle != null:
		var at := _muzzle.global_position
		var aim := _muzzle.global_rotation
		_spawn(muzzle_burst_scene, at, aim, muzzle_burst_scale)
		_spawn(muzzle_smoke_scene, at, aim, 1.0)
		if muzzle_ring_scene != null:
			var ring_at := at + Vector2.from_angle(aim) * muzzle_ring_offset
			if muzzle_ring_delay <= 0.0:
				_spawn_blast(muzzle_ring_scene, ring_at, aim, muzzle_ring_radius)
			else:
				get_tree().create_timer(muzzle_ring_delay, false).timeout.connect(
					_spawn_blast.bind(muzzle_ring_scene, ring_at, aim, muzzle_ring_radius))

	var flash := ScreenFlash.get_active(self)
	if flash != null and fire_flash_peak > 0.0:
		flash.flash(fire_flash_colour, fire_flash_peak, 0.0, fire_flash_fade)
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	camera.shake(fire_shake, fire_shake_duration)
	camera.zoom_kick(fire_zoom, fire_zoom_out_time, fire_zoom_back_time, camera_channel, camera_priority)
	camera.rotation_kick(fire_rotation * (1.0 if randf() < 0.5 else -1.0), fire_zoom_out_time,
		fire_rotation_back_time, camera_channel, camera_priority)


# --- Hits ------------------------------------------------------------------------

func _on_struck(at: Vector2, direction: Vector2, centrality: float, killed: bool) -> void:
	var heavy := _is_heavy(centrality)
	var angle := direction.angle()
	var scenes := heavy_impact_scenes if heavy else graze_impact_scenes
	var radius := heavy_flash_radius if heavy else graze_flash_radius
	var wave := heavy_wave_strength if heavy else graze_wave_strength
	for scene: PackedScene in scenes:
		_spawn_impact(scene, at, angle, radius, wave)
	if heavy and killed:
		for scene: PackedScene in lethal_scenes:
			_spawn(scene, at, angle, lethal_scale)

	if _sounds != null and impact_sound != null:
		var voice := _sounds.play_detached_stream_at(impact_sound, at,
			impact_heavy_volume_db if heavy else impact_graze_volume_db)
		if voice != null:
			voice.pitch_scale *= maxf(impact_heavy_pitch if heavy else impact_graze_pitch, 0.01)

	var camera := CameraController.get_active(self)
	if camera == null:
		return
	if heavy:
		camera.shake(heavy_shake, heavy_shake_duration)
		camera.zoom_kick(heavy_zoom, heavy_zoom_out_time, heavy_zoom_back_time,
			camera_channel, camera_priority)
	else:
		camera.shake(graze_shake, graze_shake_duration)


## Whether a hit [param centrality] from the centre gets the heavy feedback - the
## Legendary's own threshold, read off the weapon's block.
func _is_heavy(centrality: float) -> bool:
	var weapon := _source as CarriedWeapon
	var stats: WeaponStats = null if weapon == null else weapon.get_stats()
	var shell: OneBigShell = null if stats == null else stats.one_big_shell
	if shell == null:
		return centrality >= 0.5
	return shell.is_heavy(1.0 - centrality)


# --- Pieces ----------------------------------------------------------------------

func _play_layer(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if _sounds == null or stream == null:
		return
	var voice := _sounds.play_stream(stream, volume_db)
	if voice != null:
		voice.pitch_scale *= maxf(pitch, 0.01)
		_sounds.fade_tail(voice)


## One impact piece at [param at], aimed along [param angle] - whichever kind of
## effect the scene is.
func _spawn_impact(scene: PackedScene, at: Vector2, angle: float, radius: float, wave: float) -> void:
	if scene == null:
		return
	var probe := scene.instantiate()
	if probe is ShotBlast:
		probe.free()
		_spawn_blast(scene, at, angle, radius)
	elif probe is PressureWave:
		var container := _container()
		if container == null:
			probe.free()
			return
		container.add_child(probe)
		probe.global_position = at
		probe.global_rotation = angle
		(probe as PressureWave).play(wave)
	else:
		probe.free()
		_spawn(scene, at, angle, 1.0)


## A particle burst from [param scene] at [param at], aimed along [param angle],
## its particle size and speed multiplied by [param size].
func _spawn(scene: PackedScene, at: Vector2, angle: float, size: float) -> void:
	var container := _container()
	if scene == null or container == null:
		return
	var burst := scene.instantiate() as CPUParticles2D
	if burst == null:
		return
	if not is_equal_approx(size, 1.0):
		burst.scale_amount_min *= size
		burst.scale_amount_max *= size
		burst.initial_velocity_min *= size
		burst.initial_velocity_max *= size
	container.add_child(burst)
	burst.global_position = at
	burst.global_rotation = angle
	burst.reset_physics_interpolation()
	if burst.has_method(&"play"):
		burst.call(&"play")
	else:
		burst.emitting = true


## A look-only [ShotBlast] - no damage, no mask - at [param at].
func _spawn_blast(scene: PackedScene, at: Vector2, angle: float, radius: float) -> void:
	var container := _container()
	if scene == null or container == null:
		return
	var blast := scene.instantiate() as ShotBlast
	if blast == null:
		return
	container.add_child(blast)
	blast.global_position = at
	blast.global_rotation = angle
	blast.reset_physics_interpolation()
	blast.detonate(0.0, radius, 0.0, 0, null)


func _container() -> Node:
	return get_tree().current_scene if is_inside_tree() else null
