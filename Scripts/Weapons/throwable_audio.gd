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
##
## [b]It knows which throwable it is by looking at it.[/b] The player throws
## whatever they picked up off the sand, and two of the ten things the enemy carries
## are bottles rather than knives - so the recording is chosen from the artwork the
## throwable is currently wearing, not from its scene. See [member variant_textures].

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

@export_group("Variants")
## The artwork this component's own sound is the wrong recording for.
##
## A throwable wears the picture of the thing that was picked up off the floor -
## see [method GroundPickup._dress] - and not every one of those pictures is the
## weapon the bank was recorded for. Two of the ten blades the enemy carries are
## bottles, and a bottle neither leaves the hand nor arrives sounding like steel.
##
## The texture is read off [member art_path] at the instant the sound is played,
## so it follows whatever the throwable was dressed as rather than whatever its
## scene shipped with. Adding a third bottle is dropping its PNG into this array:
## there is no name, index or threshold anywhere in this file for a new one to
## have to be added to.
@export var variant_textures: Array[Texture2D] = []
## What is heard instead for those. Left empty they are silent, which is the right
## answer for a bottle leaving the hand - it is the arrival that makes the noise.
@export var variant_sound: StringName = &""
## The picture that decides. Left unresolved - or resolved to a sprite with no
## texture - every throw is the ordinary one, so this costs nothing on a throwable
## that has no variants.
@export var art_path: NodePath

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _origin: Node2D = get_node_or_null(origin_path) as Node2D
@onready var _art: Sprite2D = get_node_or_null(art_path) as Sprite2D


func _ready() -> void:
	if _source == null or not _source.has_signal(event_signal):
		return
	_source.connect(event_signal, _on_event)


## Makes the noise. Public so something other than the signal can ask for it - a
## throw spent by a scripted disarm rather than by the fire key.
func play() -> void:
	if _sounds == null:
		return

	var chosen := _sound_for_art()
	if chosen == &"":
		return

	if _origin != null and is_instance_valid(_origin):
		_sounds.play_detached_at(chosen, _origin.global_position, volume_db_offset)
		return

	_sounds.play_detached(chosen, volume_db_offset)


## Which recording this moment should make: [member sound], unless the throwable
## has been dressed as one of [member variant_textures], in which case
## [member variant_sound]. An empty name is silence rather than a missing sound,
## so a variant that should make no noise at all is an empty field rather than a
## second component switched off.
func _sound_for_art() -> StringName:
	if variant_textures.is_empty():
		return sound
	if _art == null or not is_instance_valid(_art) or _art.texture == null:
		return sound
	return variant_sound if variant_textures.has(_art.texture) else sound


## Written with every argument optional because the signals this is hung off carry
## different payloads - a thrown projectile, a struck hitbox - and it wants none of
## them. That is the point: it is told a moment happened, and where it happened is
## read off [member origin_path] rather than out of the announcement, so the same
## handler serves any signal a throwable might grow.
func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	play()
