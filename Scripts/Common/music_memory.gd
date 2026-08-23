class_name MusicCarryover
extends Node
## Carries the arena soundtrack across the scene rebuild that starts a new round.
##
## The class and the singleton are named apart on purpose, exactly as
## [RoundCounter] and its [code]RunProgress[/code] autoload are, and [BloodWallet]
## and its [code]Blood[/code] one: a [code]class_name[/code] that matches an
## autoload's name shadows it and refuses to compile. Reach the live one as
## [code]MusicMemory[/code]; the type is [MusicCarryover] where a reference has to
## be statically typed.
##
## Pressing NEXT ROUND reloads the world, and the reload takes the music player
## down with everything else. Without somewhere outside the scene to leave it, the
## only thing the next round could do is start the track again from the top -
## which is exactly what the soundtrack is not supposed to do. The song is meant
## to run continuously across the whole session, winding up through each minute
## and back down between them, and a round boundary must not be audible in it.
##
## So this remembers the three things a new player needs to carry on rather than
## begin: which track was playing, how far into it the last round got, and what
## speed it had wound down to. [MusicPlayer] hands them over as it leaves and
## picks them up again on the other side, so the new player resumes mid-bar at
## the speed the old one stopped at.
##
## It is an autoload for the same reason [BloodWallet] and [RunProgress] are: it
## is state that belongs to the session rather than to any one world, and a
## rebuilt world has to find it already holding what the last one left.
##
## Nothing is remembered when the arena track was not playing - a death hands the
## soundtrack to the base track and stops the arena one - so the run after a death
## opens fresh, on the opening, exactly as the first run of a session does.

## Emitted as state is stored and as it is taken up again, for anything that wants
## to follow the handover without polling.
signal remembered
signal resumed

var _stream: AudioStream
var _position: float = 0.0
var _pitch: float = 1.0
var _stored: bool = false


## Leaves the soundtrack where the next round can find it. [param position] is in
## seconds into [param stream], and [param pitch] is the playback speed the round
## ended at - which is what the next one has to open on.
func remember(stream: AudioStream, position: float, pitch: float) -> void:
	if stream == null:
		return

	_stream = stream
	_position = maxf(position, 0.0)
	_pitch = maxf(pitch, 0.01)
	_stored = true
	remembered.emit()


func has_state() -> bool:
	return _stored and _stream != null


func get_stream() -> AudioStream:
	return _stream


func get_position() -> float:
	return _position


func get_pitch() -> float:
	return _pitch


## Marks the stored state as taken. It is deliberately not thrown away, so a
## second player built in the same world - a test harness, a second listener -
## still sees what the round resumed on.
func mark_resumed() -> void:
	resumed.emit()


## Forgets everything, so the next round opens as a first round does. This is what
## a session genuinely starting over calls.
func clear() -> void:
	_stream = null
	_position = 0.0
	_pitch = 1.0
	_stored = false
