class_name SoundBank
extends Node
## A named set of one-shot sound effects, played through a small pool of voices.
##
## Drop it under any node that needs to make noise, fill [member sounds] in the
## inspector, then call `play(&"name")`. Overlapping calls go to separate
## voices, so a sound is never cut off by the next one - firing twice in quick
## succession layers the two blasts instead of restarting one.
##
## It owns its own [AudioStreamPlayer] children and touches nothing else, so it
## can never interfere with music or with the node it is parented to.
##
## [b]Sounds made by something that is about to die[/b] need
## [method play_detached] instead. A pooled voice is a child of this bank, which is
## a child of whatever is making the noise, so a coin that is spent on the enemy it
## was sent at takes its own strike sound down with it half way through. A detached
## voice is parented to the running scene and cleans itself up when the stream
## ends, so the sound is heard out whatever becomes of the thing that made it.

## Sound name -> [AudioStream]. The keys are what `play()` is called with.
@export var sounds: Dictionary = {}
## How many effects may overlap before the oldest voice is reused.
@export_range(1, 16) var voice_count: int = 4
## Bus every voice plays on.
@export var bus: StringName = &"Master"
## Level applied to every voice, in decibels.
@export var volume_db: float = 0.0
## Random pitch spread per playback, as a fraction of 1.0. Stops a repeated
## sound from being mechanically identical every time. 0 disables it.
@export_range(0.0, 0.5) var pitch_variation: float = 0.0

@export_group("Positional")
## How the voices made by [method play_detached_at] sit in the world. They are the
## only ones any of this touches - every other voice in the bank is heard at the
## same level wherever it came from, which is what the rest of the game does.
##
## How far a sound of this bank's carries, in pixels. Past it the sound is
## inaudible, so it wants to be comfortably wider than the screen: a knife landing
## just off the edge of it should still be heard.
@export var max_distance: float = 2400.0
## How sharply it falls away with distance. 1 is a straight fade to nothing at
## [member max_distance]; higher drops it off close in, lower keeps it loud almost
## all the way out.
@export_range(0.0, 4.0) var attenuation: float = 1.0
## How far left and right a sound is allowed to move. Kept low by default because
## the camera sits on the player and the whole fight happens within a screen of
## them - this is meant to place a sound, not to throw it into one ear.
@export_range(0.0, 3.0) var panning_strength: float = 0.6

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	for i in voice_count:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		voice.bus = bus
		voice.volume_db = volume_db
		add_child(voice)
		_voices.append(voice)


## Plays the stream registered under [param sound_name]. Unknown names and
## empty entries are ignored, so a half-filled bank can never crash a caller.
##
## [param volume_db_offset] lifts or drops this one sound against the rest of the
## bank, for a sound that has to carry over the others - a gunshot against the
## clicks of the same weapon - without a second bank to hold it.
##
## Returns the voice it went to, or null when nothing was played. Most callers
## ignore it; one that wants to keep shaping the sound after it has started - a
## pitch that slides across the report, say - needs the player it is coming out
## of, and this is the only place that knows which one that was.
func play(sound_name: StringName, volume_db_offset: float = 0.0) -> AudioStreamPlayer:
	return play_stream(sounds.get(sound_name) as AudioStream, volume_db_offset)


## Plays [param stream] itself, through the same pool of voices, for a caller whose
## sounds are an authored [i]list[/i] rather than a named set - an attack with four
## recordings of it, where which one is heard is a choice made per swing.
##
## [b]It is the same bank, not a second one.[/b] The pooling, the level, the pitch
## spread and the bus are shared with [method play], so a component holding its
## variants in an [code]@export[/code] array gets voices that behave exactly like
## every other sound in the game without keeping a dictionary of names it would
## then have to invent.
##
## A null stream is ignored, so an unfilled array can never crash a caller.
func play_stream(stream: AudioStream, volume_db_offset: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null

	var voice := _take_voice()
	if voice == null:
		return null

	voice.stream = stream
	voice.volume_db = volume_db + volume_db_offset
	voice.pitch_scale = _spread_pitch()
	voice.play()
	return voice


## Plays [param sound_name] on a voice of its own that nothing can take away.
##
## Two things can cut a pooled voice short, and this is free of both. It is
## parented to the running scene rather than to this bank, so whatever made the
## noise can be freed on the very next frame without the sound going with it; and
## it is not part of the pool, so a later call can never steal it the way
## [method _take_voice] steals the oldest voice under pressure. Nothing stops it
## but the end of the stream.
##
## It frees itself on [signal AudioStreamPlayer.finished], which is why the stream
## behind [param sound_name] must be a one-shot: a looping stream never finishes
## and the voice would be left behind.
##
## Returns the voice, so a caller can still shape it - the pitch, say - exactly as
## it would a pooled one.
func play_detached(sound_name: StringName, volume_db_offset: float = 0.0) -> AudioStreamPlayer:
	var stream := sounds.get(sound_name) as AudioStream
	var container := _detached_container(stream)
	if container == null:
		return null

	var voice := AudioStreamPlayer.new()
	voice.name = "DetachedVoice"
	voice.bus = bus
	voice.stream = stream
	voice.volume_db = volume_db + volume_db_offset
	voice.pitch_scale = _spread_pitch()
	# Kept running while the tree is paused, for the same reason it is detached: the
	# point of this voice is that nothing interrupts it.
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	voice.finished.connect(voice.queue_free, CONNECT_ONE_SHOT)

	container.add_child(voice)
	voice.play()
	return voice


## Plays [param sound_name] at a place in the world, on a voice of its own that
## nothing can take away.
##
## [b]The positional companion to [method play_detached], and detached for exactly
## the same reason.[/b] A sound that belongs to a point rather than to the mix is
## almost always one made by something that is about to stop existing - a thrown
## knife arriving, which is spent on the frame it lands - so leaving it on a pooled
## voice inside the thing that made it would cut it off mid-impact. This is that
## same rescued voice with a position on it.
##
## [param at] is a global position, and it is where the sound stays: the voice is
## parented to the running scene rather than to whatever made the noise, so the
## impact is heard from the place the impact happened even though the projectile
## left immediately. How far it carries, how it fades and how far it may travel
## across the stereo field are the bank's own [code]Positional[/code] fields, so a
## bank is tuned once and every sound out of it sits in the world the same way.
##
## Returns the voice, so a caller can still shape it exactly as it would any other.
func play_detached_at(
		sound_name: StringName, at: Vector2, volume_db_offset: float = 0.0
) -> AudioStreamPlayer2D:
	var stream := sounds.get(sound_name) as AudioStream
	var container := _detached_container(stream)
	if container == null:
		return null

	var voice := AudioStreamPlayer2D.new()
	voice.name = "DetachedVoice2D"
	voice.bus = bus
	voice.stream = stream
	voice.volume_db = volume_db + volume_db_offset
	voice.pitch_scale = _spread_pitch()
	voice.max_distance = max_distance
	voice.attenuation = attenuation
	voice.panning_strength = panning_strength
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	voice.finished.connect(voice.queue_free, CONNECT_ONE_SHOT)

	container.add_child(voice)
	# Placed after it is in the tree, so the position is read against the running
	# scene rather than against whatever transform the bank happens to sit under -
	# a weapon carried at 0.2 scale is exactly that case.
	voice.global_position = at
	voice.reset_physics_interpolation()
	voice.play()
	return voice


func has_sound(sound_name: StringName) -> bool:
	return sounds.get(sound_name) != null


## Where a detached voice is hung, or null when there is nothing to play or
## nowhere to hang it. Shared by both detached paths so "the running scene owns
## it" is stated once.
func _detached_container(stream: AudioStream) -> Node:
	if stream == null or not is_inside_tree():
		return null
	return get_tree().current_scene


## One playback's pitch. [member pitch_variation] of 0 always returns 1, which is
## how the spread is switched off without a branch at every call site.
func _spread_pitch() -> float:
	return 1.0 + randf_range(-pitch_variation, pitch_variation)


## Prefers a voice that is already free, and falls back to round-robin stealing
## so a burst of calls still makes noise instead of being silently dropped.
func _take_voice() -> AudioStreamPlayer:
	if _voices.is_empty():
		return null

	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice

	var stolen := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen
