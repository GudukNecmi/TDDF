class_name MusicState
extends Resource
## One place the soundtrack can be: the base, the road, a camp, a night's sleep,
## or a search for trouble.
##
## [b]A state is a resource, not a branch.[/b] [MusicStateBoard] holds an array of
## these and builds one player per entry, so adding a sixth state - a boss fight, a
## saloon, a new map's own theme - is dropping a [code].tres[/code] into that array
## and nothing else: there is no id named in code, no threshold, and no player to
## wire up.
##
## What a state deliberately does [i]not[/i] carry is where its music has got to.
## That is playback rather than authoring - it changes every second the track is
## running and has to survive the world being rebuilt - so the board keeps it. See
## [method MusicStateBoard.get_saved_position].

## What this state is called. Every call into the board names a state by this, and
## it is the key its playback position is remembered under, so two states must
## never share one.
@export var state_id: StringName = &""
## The track. Left unset the state still exists and is simply silent, which is what
## a state whose music has not been written yet should be rather than a crash.
@export var stream: AudioStream
## Level the track settles at once it has faded in, in decibels. Per state, because
## a camp fire and a fight are not mixed at the same level.
@export var volume_db: float = -6.0
## Bus it plays on. The game's own [code]Game[/code] bus by default, which is what
## the teleport's silence and the master mix already reach.
@export var bus: StringName = &"Game"
## Whether the track starts again when it reaches its end. On for everything that
## has to hold a place indefinitely, which is all five of the states this game
## ships with.
@export var loops: bool = true
## Whether this state always opens at the top of its track rather than resuming
## where it was left.
##
## [b]Off for every state the game ships with[/b], because not restarting is the
## whole point of the system: walking back into a camp picks the same take up mid
## bar rather than starting the song again. The base's own restart after a death is
## deliberately [i]not[/i] this - it is asked for at the moment it happens, by the
## death itself, so returning home any other way still resumes. See
## [method MusicStateBoard.play_now].
@export var always_from_start: bool = false


## Where in the track a fresh start begins, folded back inside the track's own
## length so a remembered position from a longer take can never be seeked past the
## end of a shorter one.
func wrap_position(position: float) -> float:
	if stream == null:
		return 0.0
	var length := stream.get_length()
	if length <= 0.0:
		return 0.0
	return fposmod(maxf(position, 0.0), length)
