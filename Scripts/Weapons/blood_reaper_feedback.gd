class_name BloodReaperFeedback
extends Node
## What a BLOOD REAPER execution adds on top of the gore that is already there: a
## violent burst of blood where the man comes apart and the volley leaves him, and
## an optional Legendary layer. Blood and meat only - an execution is not a bomb,
## so there is no flare, fire, smoke or scorch here. The gore itself is the [Explosion]'s and is left exactly as it is, and the
## ordinary shot's sound is still all [ShotgunFeedback]'s.
##
## The weapon announces [code]reaped[/code] once per execution - never per round -
## and this answers each one on its own voice, placed where it happened, so
## executions close together overlap freely. With the Legendary off the signal is
## never sent.

## The weapon whose executions are followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the layer is played through - its bus and positional fields.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Burst")
## Thrown together where the volley leaves, one of each - see [OneShotParticles]:
## the blood-red burst and the heavy spray of blood arcing out in every direction.
## Adding a layer is adding a scene here. Purely a look - none of it is the
## collectable blood a death spills.
@export var burst_scenes: Array[PackedScene] = []
## What each layer's size and speed are multiplied by per round of the volley past
## [member reference_rounds], as (rounds / reference) ^ this - so a volley grown by
## pellet upgrades bursts larger. 0 keeps it one size.
@export_range(0.0, 2.0, 0.01) var rounds_influence: float = 0.35
@export var reference_rounds: int = 6
## Ceiling on that growth.
@export var max_burst_scale: float = 1.8

@export_group("Audio")
## Played once per execution, where it happened. Empty plays none.
@export var activation_sound: AudioStream
@export var activation_volume_db: float = -6.0
@export var activation_pitch: float = 1.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank


func _ready() -> void:
	if _source != null and _source.has_signal(&"reaped"):
		_source.connect(&"reaped", _on_reaped)


func _on_reaped(at: Vector2, rounds: int) -> void:
	_burst(at, rounds)
	if _sounds == null or activation_sound == null:
		return
	var voice := _sounds.play_detached_stream_at(activation_sound, at, activation_volume_db)
	if voice != null:
		voice.pitch_scale *= maxf(activation_pitch, 0.01)


func _burst(at: Vector2, rounds: int) -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	if container == null:
		return
	var size := 1.0
	if reference_rounds > 0 and rounds > 0:
		size = clampf(pow(float(rounds) / float(reference_rounds), rounds_influence),
			1.0 / maxf(max_burst_scale, 1.0), maxf(max_burst_scale, 1.0))
	for scene: PackedScene in burst_scenes:
		var burst: CPUParticles2D = null if scene == null else scene.instantiate() as CPUParticles2D
		if burst == null:
			continue
		burst.scale_amount_min *= size
		burst.scale_amount_max *= size
		burst.initial_velocity_min *= size
		burst.initial_velocity_max *= size
		container.add_child(burst)
		burst.global_position = at
		burst.reset_physics_interpolation()
		if burst.has_method(&"play"):
			burst.play()
		else:
			burst.emitting = true
