class_name PressureWave
extends Node2D
## A short burst of displaced air: a crescent thrown out along +X that swells and
## fades, with whatever dust and sparks are under it kicked up once. What a
## RECOIL DEVIL shot leaves at the player's feet - see [RecoilDevilFeedback].
##
## [b]Spawned, placed, then played[/b], the same way [OneShotParticles] is: the
## bursts run in world space, so they are only started once the node is standing
## where it belongs. It frees itself when the longest of its parts is over, so
## nothing of it lingers.
##
## How big and how bright it is scales off the strength it is played with, so a
## harder kick gives a bigger wave without any of it being authored twice.

@export_group("Wave")
## The crescent. Its artwork bulges towards +X; the root is turned to aim it.
@export var wave_path: NodePath = ^"Wave"
## Scale it starts and ends at, and how long it lives.
@export var wave_start_scale: float = 0.1
@export var wave_end_scale: float = 0.32
@export var wave_seconds: float = 0.2
## How far it travels along +X while it swells, in pixels.
@export var wave_travel: float = 22.0
## Its colour and opacity at the start. It fades to nothing.
@export var wave_color := Color(1.0, 0.36, 0.2, 0.85)

@export_group("Bursts")
## Particle bursts restarted as it plays - the dust, the sparks. Each is an
## ordinary [CPUParticles2D] tuned in its own Inspector; its particle size and
## speed are multiplied by the strength factor.
@export var burst_paths: Array[NodePath] = [^"Dust", ^"Sparks"]
## Dust artwork, one picked per wave, handed to the particles at [member dust_path].
@export var dust_path: NodePath = ^"Dust"
@export var dust_textures: Array[Texture2D] = []

@export_group("Scaling")
## How much of the strength it is played with shows in its size.
## size = strength ^ this.
@export_range(0.0, 2.0, 0.01) var strength_influence: float = 0.6
## Ceiling on that factor.
@export var max_scale_factor: float = 1.8

@onready var _wave: Sprite2D = get_node_or_null(wave_path) as Sprite2D


func _ready() -> void:
	if _wave != null:
		_wave.visible = false
	for path: NodePath in burst_paths:
		var burst := get_node_or_null(path) as CPUParticles2D
		if burst != null:
			burst.emitting = false


## Sets it off. [param strength] 1 is the wave as authored.
func play(strength: float = 1.0) -> void:
	var factor := clampf(pow(maxf(strength, 0.0), strength_influence), 0.0, maxf(max_scale_factor, 0.0))
	var longest := 0.0
	if _wave != null:
		_wave.visible = true
		_wave.modulate = wave_color
		_wave.scale = Vector2.ONE * wave_start_scale * factor
		var rest := _wave.position
		var swell := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		swell.tween_property(_wave, "scale", Vector2.ONE * wave_end_scale * factor, wave_seconds)
		swell.tween_property(_wave, "position", rest + Vector2(wave_travel * factor, 0.0), wave_seconds)
		swell.tween_property(_wave, "modulate:a", 0.0, wave_seconds).set_ease(Tween.EASE_IN)
		longest = wave_seconds

	var dust := get_node_or_null(dust_path) as CPUParticles2D
	if dust != null and not dust_textures.is_empty():
		dust.texture = dust_textures.pick_random()
	for path: NodePath in burst_paths:
		var burst := get_node_or_null(path) as CPUParticles2D
		if burst == null:
			continue
		burst.scale_amount_min *= factor
		burst.scale_amount_max *= factor
		burst.initial_velocity_min *= factor
		burst.initial_velocity_max *= factor
		burst.restart()
		burst.emitting = true
		longest = maxf(longest, burst.lifetime * (1.0 + burst.lifetime_randomness))

	get_tree().create_timer(longest + 0.1).timeout.connect(queue_free)
