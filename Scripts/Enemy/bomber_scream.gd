class_name BomberScream
extends Node
## The noise a bomber makes on its way in, from the moment it lights itself to the
## moment it stops existing.
##
## [b]It is the fuse's twin, and deliberately not part of it.[/b] The burn is
## [BomberFuse]'s own voice and is built to [i]survive[/i] the man - it is lifted
## off the corpse with the countdown and is still hissing on the sand when the
## blast arrives. A scream is the opposite: it belongs to the man, so it stops the
## instant he does. Writing the two into one component would mean one of them
## having to argue with the other about what a death means, so they are two.
##
## [b]It ends hard.[/b] Both endings - the blast, and being shot on the way in -
## cut the voice on the frame they happen rather than fading it. A scream that
## tails off after the man is gone reads as a second bomber somewhere off screen;
## one that stops dead reads as the man stopping dead, which is what happened.
##
## Left with an empty [member screams] the bomber charges silently, which is a
## bomber with its voice switched off rather than a broken one.

## Emitted as a scream starts, with the recording that was picked.
signal screamed(stream: AudioStream)
## Emitted when one is cut off, whichever ending did it.
signal silenced

## The fuse this follows. Its ignition is the moment the scream starts - the same
## moment the burn starts - and its detonation is one of the two things that end
## it.
@export var fuse_path: NodePath = ^"../Fuse"
## The pool watched for the other ending: the bomber being shot on its way in.
@export var health_path: NodePath = ^"../Health"

@export_group("The voice")
## The recordings, one picked at random per charge. A list rather than anything
## named in code, so a fifth scream is dropping a file into the Inspector.
@export var screams: Array[AudioStream] = []
## The player the scream comes out of. A child of the bomber rather than of the
## fuse, which is the whole of why it dies with the man: the fuse walks out of the
## corpse and this does not.
@export var voice_path: NodePath = ^"Voice"
## Level this sits at, in decibels.
@export var volume_db: float = 0.0
## How far either side of normal a scream may be pitched, as a fraction, so four
## recordings do not become four sounds the player learns.
@export_range(0.0, 0.5) var pitch_variation: float = 0.07

@onready var _fuse: BomberFuse = get_node_or_null(fuse_path) as BomberFuse
@onready var _health: Health = get_node_or_null(health_path) as Health

var _screaming: bool = false


func _ready() -> void:
	if _fuse != null:
		_fuse.ignited.connect(scream)
		_fuse.detonated.connect(_on_detonated)
	if _health != null:
		_health.died.connect(silence)


## Whether this bomber is screaming right now.
func is_screaming() -> bool:
	return _screaming


## Starts one. Public and guarded, so a test - or anything else that wants a man
## to scream - can ask without reproducing the ignition, and so a second call
## cannot restart a scream already under way.
func scream() -> void:
	if _screaming:
		return
	var voice := _voice()
	if voice == null or screams.is_empty():
		return

	var stream := screams[randi() % screams.size()]
	if stream == null:
		return

	_screaming = true
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	voice.play()
	screamed.emit(stream)


## Cuts it, now. Safe on a bomber that never screamed, and safe twice - which it
## very often is, because a bomber that reaches the player dies and detonates on
## the same frame.
func silence() -> void:
	var voice := _voice()
	if voice != null:
		voice.stop()
	if not _screaming:
		return
	_screaming = false
	silenced.emit()


func _on_detonated(_at: Vector2) -> void:
	silence()


func _voice() -> AudioStreamPlayer2D:
	return get_node_or_null(voice_path) as AudioStreamPlayer2D
