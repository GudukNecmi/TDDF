class_name ThrowableAudio
extends Node
## The noise a thrown weapon makes: leaving the hand, and arriving.
##
## [b]It is one component placed twice, not two.[/b] A throw and a hit are the same
## job - something announced a moment, and a sound has to be heard at the place it
## happened by something that is about to stop existing - so what differs between
## them is which signal is listened for and which recording is played, and both of
## those are inspector fields. In the weapon's own scene it hangs off
## [signal ThrowableWeapon.thrown]; in the scene of the thing the weapon sends it
## hangs off [signal Projectile.landed]. Adding a third throwable is two nodes in
## its two scenes and no code at all.
##
## [b]It listens to the announcement, never to the collision.[/b] The hit sound is
## hung on [signal Projectile.landed], which the projectile emits from the one place
## a landing is settled - after the damage has been handed to the [Hitbox] and only
## for a landing that actually found one. So a knife that flies past somebody, runs
## out of range and breaks makes no hit sound at all, and a knife caught by both the
## sweep and the overlap in the same frame still makes exactly one, because the
## projectile itself has already decided it landed once. There is no second
## hit-detection anywhere in here.
##
## [b]The sound outlives what made it.[/b] Both sources die immediately after they
## speak - the weapon is spent on the throw and handed back a tenth of a second
## later, the flight is retired on the frame it lands - so the voice cannot be a
## pooled one inside their own [SoundBank] or it would be freed part way through the
## very moment it exists for. It goes out through [method SoundBank.play_detached_at]
## instead, which parents it to the running scene at the position it is given and
## leaves it there until the stream ends. That is also what puts the throw at the
## hand and the hit at the point of impact rather than both of them in the middle
## of the mix.

## Who is listened to. Defaults to this node's parent, which is the weapon in the
## weapon's scene and the flight in the flight's.
@export var source_path: NodePath = ^".."
## The voices this is played through - its own child, so a throwable carries its
## sounds with it and nothing outside has to be wired up when one is spawned.
@export var sound_bank_path: NodePath = ^"SoundBank"
## What the source announces. It is a name rather than a connection because the two
## things this component is placed on announce different moments, and because a
## source that does not have this signal is then simply silent instead of an error.
@export var event_signal: StringName = &"thrown"
## Which sound in the bank is played. Left unfilled in the bank, nothing is heard.
@export var sound: StringName = &"throw"
## Where the sound is placed, at the instant it is played. The source itself by
## default: a weapon is in the player's hand as it lets go, and a projectile has
## already been moved onto the thing it struck by the time it says so, so in both
## cases the source's own position is the place the player should hear.
##
## Unresolved - or resolved to something with no position - the sound is played
## into the mix instead of into the world, so a bank dropped somewhere without a
## transform is still heard.
@export var origin_path: NodePath = ^".."
## Level this sits at against the rest of its bank, in decibels.
@export var volume_db_offset: float = 0.0

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _origin: Node2D = get_node_or_null(origin_path) as Node2D


func _ready() -> void:
	if _source == null or not _source.has_signal(event_signal):
		return
	_source.connect(event_signal, _on_event)


## Makes the noise. Public so something other than the signal can ask for it - a
## throw spent by a scripted disarm rather than by the fire key.
func play() -> void:
	if _sounds == null:
		return

	if _origin != null and is_instance_valid(_origin):
		_sounds.play_detached_at(sound, _origin.global_position, volume_db_offset)
		return

	_sounds.play_detached(sound, volume_db_offset)


## Written with every argument optional because the signals this is hung off carry
## different payloads - a thrown projectile, a struck hitbox - and it wants none of
## them. That is the point: it is told a moment happened, and where it happened is
## read off [member origin_path] rather than out of the announcement, so the same
## handler serves any signal a throwable might grow.
func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	play()
