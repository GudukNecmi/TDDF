class_name RevolverFeedback
extends Node
## Sound and camera for the revolver.
##
## Built the way [ShotgunFeedback] and [LeverActionFeedback] are: the weapon
## announces what happened and everything cosmetic lives here.
##
## [b]Nothing about this weapon should sound the same twice.[/b] It is fired in
## fast strings of six and reloaded a round at a time, so a single sample per
## event would turn into a machine noise within one magazine. Both the shot and
## the reload therefore draw from a *set* of recordings and shift the pitch of
## whichever comes up, which is enough that a full cylinder emptied at speed reads
## as six separate shots rather than one sound repeated.

## Node whose revolver signals are listened to. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the sound effects are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Fire")
## The shot's recording. One sound for every shot, which is why the pitch below
## has to do the work of keeping a string of six from sounding mechanical.
@export var fire_sound: StringName = &"blast"
## How much louder the shot is than the rest of the weapon, in decibels.
@export var fire_volume_db: float = 6.0
## The range a shot's pitch is drawn from, fresh for every round.
##
## [b]This is what stops one sample from reading as one sample.[/b] The weapon is
## fired in fast strings of six, so a fixed pitch would turn the cylinder into a
## machine noise within a magazine; a small spread either side of normal is enough
## that six shots read as six separate reports. Widening it much past this starts
## to sound like six different guns.
@export var fire_pitch_min: float = 0.92
@export var fire_pitch_max: float = 1.08
## How far the pitch drifts downward across the report, as a fraction, and over
## how long. 0 leaves each shot at the single pitch it was given.
@export var fire_pitch_fall: float = 0.0
@export var fire_pitch_fall_time: float = 0.35

@export_group("Muzzle blast")
## The burst sitting on the barrel. A child of the muzzle rather than something
## spawned, so it is exactly at the muzzle tip and turns with the weapon's aim for
## the whole time it is up.
@export var blast_path: NodePath = ^"../MuzzleRig/Muzzle/Blast"
## Nudge from where the artwork is authored, in the muzzle's own space. +X is
## further down the barrel.
@export var blast_offset := Vector2.ZERO
## Size it is drawn at, as a fraction of the authored scale. Small: a revolver's
## flash is a spit of fire, not the shotgun's ball of it.
@export var blast_scale: float = 0.55
## How long it holds before fading, and how long the fade takes. Both tiny - the
## burst must be gone before the player has finished seeing it.
@export var blast_hold: float = 0.02
@export var blast_fade: float = 0.05
## Tint laid over the artwork, and how hard it is blown out against the additive
## material.
@export var blast_colour := Color(1.0, 0.88, 0.55)
@export var blast_glow: float = 1.25

@export_group("Muzzle light")
## The light punched on the barrel as the shot leaves, so the flash throws
## something onto the sand and the men standing in front of it rather than being a
## sprite on its own. The same arrangement [LeverActionFeedback] already uses - the
## light is authored in the weapon's scene and only its energy is touched here.
@export var muzzle_light_path: NodePath = ^"../MuzzleRig/MuzzleLight"
## How hard it burns at its peak. 0 switches it off.
@export var muzzle_light_energy: float = 0.9
## How long it takes to fall back to nothing, in seconds.
@export var muzzle_light_time: float = 0.07

@export_group("Fire camera")
@export var fire_shake_strength: float = 11.0
@export var fire_shake_duration: float = 0.07
@export var fire_rotation_degrees: float = 0.7
@export var fire_rotation_out_time: float = 0.04
@export var fire_rotation_return_time: float = 0.11
@export var camera_channel: StringName = &"weapon"
@export var camera_priority: int = 0

@export_group("Dry fire")
@export var dry_fire_sound: StringName = &"dry_fire"
@export var dry_fire_shake_strength: float = 1.2
@export var dry_fire_shake_duration: float = 0.05

@export_group("Reload")
## The reload's recordings, drawn from at random as each round goes in.
@export var reload_sounds: Array[StringName] = [&"reload_1", &"reload_2", &"reload_3"]
@export var reload_volume_db: float = 0.0
## How far either side of normal a reload may be pitched. Subtle - it is the same
## hand loading the same weapon, only never quite identically.
@export_range(0.0, 0.5) var reload_pitch_spread: float = 0.07

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _blast: CanvasItem = get_node_or_null(blast_path) as CanvasItem
@onready var _muzzle_light: PointLight2D = get_node_or_null(muzzle_light_path) as PointLight2D

var _camera: CameraController
var _blast_rest_scale := Vector2.ONE
var _blast_rest_position := Vector2.ZERO
var _blast_tween: Tween
var _light_tween: Tween
## The pitch drift running on each voice, so a voice reused by a later shot has
## its old drift killed rather than blended.
var _pitch_tweens: Dictionary = {}


func _ready() -> void:
	if _blast != null:
		var blast_node := _blast as Node2D
		if blast_node != null:
			# The authored transform is the base and every exported value is
			# measured from it, so tuning the burst never loses where the sprite was
			# placed on the barrel.
			_blast_rest_scale = blast_node.scale
			_blast_rest_position = blast_node.position
		_blast.visible = false
		_blast.modulate.a = 0.0

	# Dark until it is fired, whatever the scene was saved with.
	if _muzzle_light != null:
		_muzzle_light.energy = 0.0

	if _source == null:
		return
	_listen(&"fired", _on_fired)
	_listen(&"dry_fired", _on_dry_fired)
	_listen(&"chamber_loaded", _on_chamber_loaded)


## Connected by name rather than statically, so a weapon without one of these
## signals simply gets no feedback for it instead of erroring.
func _listen(signal_name: StringName, handler: Callable) -> void:
	if _source.has_signal(signal_name) and not _source.is_connected(signal_name, handler):
		_source.connect(signal_name, handler)


func _on_fired() -> void:
	_play_shot()
	_flash_blast()
	_punch_muzzle_light()

	var camera := _get_camera()
	if camera == null:
		return
	camera.shake(fire_shake_strength, fire_shake_duration)
	if not is_zero_approx(fire_rotation_degrees):
		camera.rotation_kick(
			fire_rotation_degrees, fire_rotation_out_time, fire_rotation_return_time,
			camera_channel, camera_priority)


## A trigger pull that produced nothing - an empty chamber, or the lock after a
## round has just gone in. The player hears the same click for both, because from
## their side it is the same thing: the weapon was not ready.
func _on_dry_fired() -> void:
	if _sounds != null:
		_sounds.play(dry_fire_sound)

	if dry_fire_shake_strength <= 0.0:
		return
	var camera := _get_camera()
	if camera != null:
		camera.shake(dry_fire_shake_strength, dry_fire_shake_duration)


func _on_chamber_loaded(_chamber: int) -> void:
	_play_reload()


## The shot: one recording, pitched somewhere new every time it is fired.
##
## The pitch is drawn per round rather than cycled, so there is no pattern to hear
## across a magazine, and it is applied after the bank has played the voice
## because the bank's own small variation would otherwise fight this one.
func _play_shot() -> void:
	if _sounds == null:
		return

	var voice := _sounds.play(fire_sound, fire_volume_db)
	if voice == null:
		return

	var pitch := randf_range(
		minf(fire_pitch_min, fire_pitch_max), maxf(fire_pitch_min, fire_pitch_max))
	voice.pitch_scale = maxf(pitch, 0.05)

	if fire_pitch_fall <= 0.0:
		return

	# Each voice keeps its own drift, killed if that voice is stolen by a later
	# shot, so two overlapping reports slide independently.
	var id := voice.get_instance_id()
	var running: Tween = _pitch_tweens.get(id)
	if running != null and running.is_running():
		running.kill()

	var tween := create_tween()
	tween.tween_property(voice, "pitch_scale", maxf(pitch - fire_pitch_fall, 0.05),
		maxf(fire_pitch_fall_time, 0.0001))
	_pitch_tweens[id] = tween


## One of the reload recordings, drawn at random and pitched a little away from
## normal - the same hand loading the same weapon, only never quite identically.
func _play_reload() -> void:
	if _sounds == null or reload_sounds.is_empty():
		return

	var voice := _sounds.play(reload_sounds[randi() % reload_sounds.size()], reload_volume_db)
	if voice != null and reload_pitch_spread > 0.0:
		voice.pitch_scale = 1.0 + randf_range(-reload_pitch_spread, reload_pitch_spread)


## Puts the burst on the barrel and takes it off again. Everything is measured
## from the authored transform, and it always ends hidden, so however fast the
## player fires the burst can never be left on screen.
func _flash_blast() -> void:
	if _blast == null:
		return

	if _blast_tween != null and _blast_tween.is_running():
		_blast_tween.kill()

	var blast_node := _blast as Node2D
	if blast_node != null:
		blast_node.scale = _blast_rest_scale * blast_scale
		blast_node.position = _blast_rest_position + blast_offset

	var tint := blast_colour * blast_glow
	tint.a = 1.0
	_blast.modulate = tint
	_blast.visible = true

	_blast_tween = create_tween()
	_blast_tween.tween_interval(maxf(blast_hold, 0.0))
	_blast_tween.tween_property(_blast, "modulate:a", 0.0, maxf(blast_fade, 0.0001))
	_blast_tween.tween_callback(_blast.hide)


## Lights the barrel and lets it fall straight back to nothing.
##
## Written the same way [method LeverActionFeedback._punch_muzzle_light] is - the
## energy is punched to its peak and tweened down, and a second shot kills the
## first fall rather than blending with it - so a string of six reads as six
## flashes rather than one long glow.
func _punch_muzzle_light() -> void:
	if _muzzle_light == null or muzzle_light_energy <= 0.0:
		return

	if _light_tween != null and _light_tween.is_running():
		_light_tween.kill()

	_muzzle_light.energy = muzzle_light_energy
	_light_tween = create_tween()
	_light_tween.tween_property(
		_muzzle_light, "energy", 0.0, maxf(muzzle_light_time, 0.0001))


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
