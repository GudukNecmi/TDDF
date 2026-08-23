class_name CoinFeedback
extends Node
## Everything the player sees and hears at the instant a coin is shot out of the
## air.
##
## Built the way [ShotgunFeedback] and [LeverActionFeedback] are: the coin only
## announces what happened and every cosmetic thing lives here, so the coin's
## flight stays pure gameplay and this whole layer can be muted by disabling one
## node.
##
## [b]This is the instant, and only the instant.[/b] The flash, the burst, the
## sound and the shake all land on the frame of contact and are over almost at
## once, and every one of them belongs to this coin - so they live here, on a node
## inside the coin's own scene, where they are tuned against the coin they belong
## to.
##
## What comes *after* the instant - the freeze, the slow motion, and the camera
## riding the coin to its enemy - is [CoinStrike]'s, out in the world. It has to be
## out there because the coin is spent the moment it arrives and those effects have
## to outlive it. This hands the pair over and has nothing further to do with them.

## Node whose coin signals are listened to. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the sound effects are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Sound")
@export var strike_sound: StringName = &"coin_shot"
## How much louder the strike is than the rest of the coin's sounds, in decibels.
@export var strike_volume_db: float = 4.0
## How far the strike's pitch may wander either way, as a fraction.
@export_range(0.0, 0.5) var strike_pitch_variation: float = 0.08
## Whether the strike is heard out in full whatever happens to the coin.
##
## On, and it has to be: the bank this plays through is a child of the coin, and
## the coin is spent on its enemy a fraction of a second later - so an ordinary
## voice is freed with it and the sound is cut off part way through the one moment
## the weapon is about to. A detached voice belongs to the running scene instead
## and is out of the pool, so neither the coin's death nor a later sound can stop
## it. See [method SoundBank.play_detached].
@export var strike_sound_uninterruptible: bool = true

@export_group("Hit effect")
## Burst spawned at the contact point. It is added to the running scene rather
## than to the coin, because the coin leaves immediately and the burst should stay
## where the shot met it.
@export var hit_effect_scene: PackedScene
## Size it is drawn at, as a fraction of the scene's own scale.
@export var hit_effect_scale: float = 1.0
## How long it lives, in seconds, including its fade.
@export var hit_effect_time: float = 0.22
## How long it holds full brightness before fading.
@export var hit_effect_hold: float = 0.05

@export_group("Screen")
## Colour the screen is washed with at the moment of contact.
##
## A pale, near-white yellow: the strike is the one moment in the run that is not
## about blood, so it deliberately does not use the arena's red. It reads as a
## glint of struck metal, and against everything else on screen being red it is
## unmistakable.
@export var flash_colour := Color(1.0, 0.97, 0.72)
## How strong that wash is at its peak.
@export_range(0.0, 1.0) var flash_peak: float = 0.42
## How long it holds that peak before fading, in seconds. 0 is the sharpest
## result: the colour is on for a single frame and then falls away, which is what
## makes it read as a flash of light rather than a coloured overlay.
@export var flash_hold: float = 0.0
## How long it takes to fade out, in seconds.
@export var flash_fade: float = 0.16

@export_group("Camera")
## The knock on the impact itself. The push in on the coin and the ride out with
## it are [CoinStrike]'s, on their own channel, and are unaffected by this.
@export var shake_strength: float = 9.0
@export var shake_duration: float = 0.1
@export var camera_channel: StringName = &"weapon"

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank


func _ready() -> void:
	if _source != null and _source.has_signal(&"struck"):
		_source.connect(&"struck", _on_struck)


## The strike: a wash of pale yellow, a burst where the round met the coin, the
## sound of it, and a knock on the camera - then the sequence that carries on
## after all of that is handed over.
##
## The hand-over is first deliberately: the freeze it starts has to take the frame
## of the impact rather than the one after it.
func _on_struck(shot: Projectile, at: Vector2) -> void:
	_begin_sequence(shot)
	_flash_screen()
	_spawn_hit_effect(at)
	_play_strike()
	_shake_camera()


## Hands the coin and the round that hit it to the world's [CoinStrike], which
## owns everything that outlasts this node. A world without one plays the instant
## and nothing more, which is exactly what every other lookup-by-group in the
## project does when its counterpart is absent.
func _begin_sequence(shot: Projectile) -> void:
	var sequence := CoinStrike.get_active(self)
	if sequence == null:
		return
	sequence.begin(_source as Projectile, shot)


func _flash_screen() -> void:
	if flash_peak <= 0.0:
		return
	var screen := ScreenFlash.get_active(self)
	if screen != null:
		screen.flash(flash_colour, flash_peak, flash_hold, flash_fade)


## Put where the round actually met the coin rather than at the coin's middle, so
## a glancing hit bursts on the edge it clipped.
func _spawn_hit_effect(at: Vector2) -> void:
	if hit_effect_scene == null:
		return
	var container := get_tree().current_scene
	if container == null:
		return

	var effect := hit_effect_scene.instantiate() as Node2D
	if effect == null:
		return

	container.add_child(effect)
	effect.global_position = at
	effect.scale *= hit_effect_scale
	effect.rotation = randf() * TAU

	# Timed here rather than inside the burst's own scene, so the whole strike is
	# tuned from one place.
	var tween := effect.create_tween()
	tween.tween_interval(maxf(hit_effect_hold, 0.0))
	tween.tween_property(effect, "modulate:a", 0.0,
		maxf(hit_effect_time - hit_effect_hold, 0.0001))
	tween.tween_callback(effect.queue_free)


func _play_strike() -> void:
	if _sounds == null:
		return

	var voice := _sounds.play_detached(strike_sound, strike_volume_db) \
		if strike_sound_uninterruptible \
		else _sounds.play(strike_sound, strike_volume_db)

	# Set once, as the sound starts, and never touched again - the whole point of
	# the detached voice is that nothing reaches into it after this.
	if voice != null and strike_pitch_variation > 0.0:
		voice.pitch_scale = 1.0 + randf_range(-strike_pitch_variation, strike_pitch_variation)


func _shake_camera() -> void:
	if shake_strength <= 0.0:
		return
	var camera := CameraController.get_active(self)
	if camera != null:
		camera.shake(shake_strength, shake_duration)
