class_name EnemyAttackAudio
extends Node
## The noise an enemy makes swinging its knife: the attack itself, and the blade
## going through the air a moment later.
##
## [b]It is hung off the animation, not off the damage.[/b] Both sounds come from
## [KnifeSlash]'s own signals - [signal KnifeSlash.swing_started] as the swing is
## committed to, and [signal KnifeSlash.strike_started] as the blade stops being
## drawn back and starts travelling at its target - so the swoosh lands with the
## movement it describes however the wind-up is retuned, and neither sound waits on
## a hit that may never connect. Nothing in the enemy's own script is involved.
##
## [b]A boss is the same enemy with different recordings.[/b] There is no boss enemy
## and no boss scene - see [MiniBoss] - so this component is on every Bandit and
## simply looks for the boss component beside it as it swings. Both sets of sounds
## are [code]@export[/code] arrays: the man on the poster is louder because his
## array holds his own attack, and dropping a boss swoosh into
## [member boss_swoosh_sounds] later is an inspector change rather than a branch
## here.
##
## The voices are a [SoundBank] of this component's own, which is where the pooling,
## the level and the pitch spread live - so an enemy swinging twice in a second
## layers the two rather than cutting the first off, and none of this can reach the
## music.

## The blade whose swings are listened for.
@export var knife_path: NodePath = ^"../KnifeAim/KnifeSlash"
## The voices these are played through. Its own child, so every enemy has its own
## small pool and one loud fight cannot starve another enemy of a voice.
@export var sound_bank_path: NodePath = ^"SoundBank"
## The boss component, looked for beside this one. It is added to the enemy
## [i]after[/i] it is built - see [MiniBossDirector] - so it is resolved at the
## moment of a swing rather than on ready.
@export var boss_component_path: NodePath = ^"../MiniBoss"

@export_group("Bandit")
## What the man says as he swings. One is picked at random, so four recordings are
## four exports and no two swings in a row have to match.
@export var attack_sounds: Array[AudioStream] = []
## The blade going through the air, played as the strike begins.
@export var swoosh_sounds: Array[AudioStream] = []
## Level these are played at against the rest of the bank, in decibels.
@export var attack_volume_db: float = 0.0
@export var swoosh_volume_db: float = 0.0

@export_group("Boss")
## The same two things for the man on the poster, played instead of the ordinary
## ones whenever this enemy is carrying a [MiniBoss] component.
##
## An empty array falls back to the Bandit sound, so a boss with no recording of his
## own is heard swinging exactly like the men with him rather than falling silent.
@export var boss_attack_sounds: Array[AudioStream] = []
@export var boss_swoosh_sounds: Array[AudioStream] = []
@export var boss_attack_volume_db: float = 0.0
@export var boss_swoosh_volume_db: float = 0.0

@export_group("Hearing")
## How far from the player a swing can be heard, in pixels. 0 is everywhere.
##
## [b]It is a crowd control, not a mix.[/b] These voices are not positional, so a
## Danger with thirty men in it would otherwise put thirty attacks at full level in
## the player's ear at once - most of them from men off the edge of the screen.
## Generous enough to cover anything on screen and then some.
@export var hearing_radius: float = 1400.0
## Group the listener is found in.
@export var listener_group: StringName = &"player"

@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _knife: KnifeSlash = get_node_or_null(knife_path) as KnifeSlash


func _ready() -> void:
	if _knife == null:
		return
	_knife.swing_started.connect(_on_swing)
	_knife.strike_started.connect(_on_strike)


func _on_swing() -> void:
	if _is_boss():
		_play(boss_attack_sounds, attack_sounds, boss_attack_volume_db)
		return
	_play(attack_sounds, attack_sounds, attack_volume_db)


func _on_strike() -> void:
	if _is_boss():
		_play(boss_swoosh_sounds, swoosh_sounds, boss_swoosh_volume_db)
		return
	_play(swoosh_sounds, swoosh_sounds, swoosh_volume_db)


## Plays one of [param choices] at random, falling back to [param fallback] when
## the first list is empty - which is what lets a boss borrow the ordinary swoosh
## until he is given one of his own.
func _play(choices: Array[AudioStream], fallback: Array[AudioStream], level: float) -> void:
	if _sounds == null or not _in_earshot():
		return

	var list := choices if not choices.is_empty() else fallback
	if list.is_empty():
		return

	_sounds.play_stream(list[randi() % list.size()], level)


## Whether this enemy is the man on the poster. Asked per swing rather than cached,
## because the component that makes him one is added after the enemy is built.
func _is_boss() -> bool:
	return get_node_or_null(boss_component_path) != null


func _in_earshot() -> bool:
	if hearing_radius <= 0.0:
		return true

	var body := get_parent() as Node2D
	var listener := get_tree().get_first_node_in_group(listener_group) as Node2D
	if body == null or listener == null:
		return true

	return body.global_position.distance_to(listener.global_position) <= hearing_radius
