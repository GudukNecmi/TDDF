class_name DevilsBreathFeedback
extends Node
## What a DEVIL'S BREATH shot adds on top of an ordinary one: an optional firing
## layer under the ordinary blast. The ordinary shot's sound is still all
## [ShotgunFeedback]'s and is left exactly as it is; the blasts' own sound is the
## [ShotBlast]'s.
##
## The weapon announces [code]explosive_shot[/code] once per shot - never per
## pellet - while a [ShotExplosion] is active, and this plays the layer through
## the weapon's own [SoundBank] on a voice of its own with the bank's tail fade, so
## shots overlap freely. With the Legendary off the signal is never sent.

## The weapon whose shots are followed. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the layer is played through.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Audio")
## Layer played with each explosive shot, over the ordinary blast. Empty plays none.
@export var fire_layer_sound: AudioStream
@export var fire_layer_volume_db: float = -8.0
@export var fire_layer_pitch: float = 1.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank


func _ready() -> void:
	if _source != null and _source.has_signal(&"explosive_shot"):
		_source.connect(&"explosive_shot", _on_explosive_shot)


func _on_explosive_shot() -> void:
	if _sounds == null or fire_layer_sound == null:
		return
	var voice := _sounds.play_stream(fire_layer_sound, fire_layer_volume_db)
	if voice != null:
		voice.pitch_scale *= maxf(fire_layer_pitch, 0.01)
		_sounds.fade_tail(voice)
