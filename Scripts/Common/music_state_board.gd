class_name MusicStateBoard
extends Node
## The soundtrack as a set of places rather than a set of songs: the base, the
## road, a camp, a night's sleep, a search for trouble - each with its own track
## and its own needle resting where it was last left.
##
## [b]Nothing here restarts.[/b] Walking out of a camp stows that camp's music at
## 01:42 and walking back in lifts it from 01:42, mid bar, however many days of
## riding and fighting happened in between. That is the whole point of the system,
## and it is why the position is kept here rather than on the player: this is an
## autoload, and the world being rebuilt - which is what setting out, sleeping and
## arriving all do - does not touch it. A track is the same playback instance from
## the first frame of a session to the last.
##
## [b]The handover.[/b] Every change of state is the same two-second shape, and
## they overlap:
##
##   [codeblock]
##   0s                    1s                    2s                    3s
##   |-- outgoing: 100% -> 5% speed, fading to silence --|
##                         |-- incoming: 5% -> 100% speed, fading up --|
##   [/codeblock]
##
##   * the state being left is slowed to [member low_pitch] and faded out over
##     [member exit_time], and only then stopped - so what is remembered is where
##     the music genuinely got to, not where it was when the player pressed the
##     button
##   * the state being entered opens [member overlap] seconds before that finishes,
##     from its own saved position, at [member low_pitch], and winds up to full
##     speed and full level over [member enter_time]
##
## Both halves ignore [member Engine.time_scale] on purpose: fast travel, a hit
## stop and a death all turn that dial, and a handover that sped up or crawled with
## them would be a different length every time it happened.
##
## [b]Two things break the shape, and both are asked for explicitly.[/b]
## [method slow_to_silence] winds the current track down without handing over to
## anything - what a death does - and [method play_now] opens a state at once, at
## full speed, with no ramp - what the base does on the far side of that death.
## Everything else goes through [method enter].
##
## Which states exist is [member states], an array of [MusicState] resources, and
## which state the game should be in at any moment is nobody's business here: see
## [MusicStateWatcher] for the world's own answer and [MusicDirector] for the
## systems that ask for a particular one.

## Emitted as a state's track actually begins - which is one second into the
## handover, not when it was asked for.
signal state_entered(state_id: StringName)
## Emitted as a state's track is stopped and its position remembered.
signal state_stowed(state_id: StringName, position: float)

## Group the board joins, so anything can reach the soundtrack without a path to
## an autoload.
const GROUP := &"music_states"

## Every place the soundtrack can be. One [MusicState] per entry, one player built
## per state - see [MusicState], where all the authoring lives.
##
## [b]Adding a state is adding an entry.[/b] Nothing in this file names one, so a
## sixth place with a sixth track needs no code at all; only whoever decides the
## game is in it needs to know its id.
@export var states: Array[MusicState] = []

@export_group("Handover")
## How long the state being left takes to slow to [member low_pitch] and fade to
## silence, in seconds.
@export var exit_time: float = 2.0
## How long the state being entered takes to wind from [member low_pitch] up to
## full speed and full level, in seconds.
@export var enter_time: float = 2.0
## How much of the outgoing fade is still to run when the incoming track begins,
## in seconds - the length of the overlap the two are heard through.
##
## Held to [member exit_time], so asking for more overlap than there is fade simply
## starts the new track as the old one begins going.
@export var overlap: float = 1.0
## Speed a track is dragged down to as it leaves, and opened at as it arrives, as a
## fraction of its authored speed.
@export_range(0.01, 1.0, 0.01) var low_pitch: float = 0.05
## Level a track is taken to before it is stopped, in decibels. Low enough to be
## silence.
@export var silent_db: float = -60.0

@export_group("Death")
## How long the soundtrack takes to run down to [member low_pitch] and silence when
## the player dies, in seconds.
##
## [b]It is longer than an ordinary handover and hands over to nothing.[/b] Dying
## is the world winding down rather than the music being cut, so whatever was
## playing keeps playing from exactly where it was and simply slows to a stop. See
## [method slow_to_silence].
@export var death_slow_time: float = 5.0

## state_id -> the [MusicPlayer] carrying it. Built once, on ready, and never
## rebuilt: these players are the reason a song survives the world being torn down.
var _players: Dictionary = {}
## state_id -> [MusicState], for the authoring behind a player.
var _authored: Dictionary = {}
## state_id -> seconds into that state's own track, as of the last time it was
## stowed. The memory that makes this a board of states rather than a switch.
var _positions: Dictionary = {}
## state_id -> the [Tween] currently shaping it, so a handover interrupted half way
## can never leave two tweens writing the same pitch.
var _tweens: Dictionary = {}

## The state whose track is sounding, and the state whose track has been asked for
## but has not opened yet - the one-second gap at the top of every handover.
var _current: StringName = &""
var _pending: StringName = &""


func _ready() -> void:
	add_to_group(GROUP)
	# Always, because most of the states this board holds are entered from a menu
	# that has frozen the world behind it - the camp, the travel screen - and a
	# handover that stopped with the tree would strand the music half faded.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_players()


## The soundtrack any system should talk to. Null means this game was built without
## one, which every caller treats as "the music looks after itself".
static func get_active(from_node: Node) -> MusicStateBoard:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as MusicStateBoard


## One player per authored state, built here rather than left on the scene so that
## adding a state stays a matter of dropping a resource into [member states].
##
## They are [MusicPlayer]s with the run tempo programme switched off - the same
## player the arena's own soundtrack uses, doing the half of its job that is
## looping and keeping track of where in the song it has got to. Nothing about the
## round-by-round speed climb is wanted here: the only thing that moves the pitch
## of these tracks is a handover.
func _build_players() -> void:
	for state: MusicState in states:
		if state == null or state.state_id == &"":
			continue
		if _players.has(state.state_id):
			push_warning("MusicStateBoard: two states share the id %s." % state.state_id)
			continue

		var player := MusicPlayer.new()
		player.name = "Music_%s" % state.state_id
		player.stream = state.stream
		player.volume_db = state.volume_db
		player.bus = state.bus
		player.loop = state.loops
		player.autoplay = false
		# The three things that would make this player something other than a plain
		# looping track: the speed programme, the hunt for a new run to open it on,
		# and the handover to the next round. A state's music is none of those.
		player.tempo_ramp_enabled = false
		player.persistent = false
		player.remember_across_rounds = false
		player.wave_manager_path = ^""
		player.process_mode = Node.PROCESS_MODE_ALWAYS

		add_child(player)
		_players[state.state_id] = player
		_authored[state.state_id] = state


## Whether [param state_id] is one of the authored states.
func has_state(state_id: StringName) -> bool:
	return _players.has(state_id)


## Which state is sounding. Empty before the first one has opened.
func get_state() -> StringName:
	return _current


## Which state the board is on its way to: whatever has been asked for, or what is
## already playing when nothing is pending. This is what [method enter] compares
## against, so asking twice for the same state during a handover is still one
## handover.
func get_target() -> StringName:
	return _pending if _pending != &"" else _current


## The player carrying the soundtrack right now, for anything that has to shape it
## for a moment without knowing which state it is - the pause menu ducking it, a
## test reading its level. Null when nothing is playing.
func get_active_player() -> MusicPlayer:
	return _players.get(_current) as MusicPlayer


## How far into its own track a state was when it was last stowed. 0 for a state
## that has never played.
func get_saved_position(state_id: StringName) -> float:
	return float(_positions.get(state_id, 0.0))


## Puts a state back to the top of its track, so the next entry opens it fresh.
## What a death does to the base - see [method play_now] - and the only thing in
## the whole board that throws a position away.
func forget(state_id: StringName) -> void:
	_positions[state_id] = 0.0


## Changes state: the current track is slowed and faded out over
## [member exit_time], and [param state_id] opens [member overlap] seconds before
## that finishes, from where it was last left.
##
## [b]Asking for the state that is already playing does nothing at all[/b], and
## that is what stops the music restarting. A travel day screen, an ambush, a
## Danger and a second press of the same button all ask again and are all ignored,
## so nothing that happens inside a state can interrupt it.
##
## Returns whether a handover was actually begun.
func enter(state_id: StringName) -> bool:
	if not _players.has(state_id):
		if state_id != &"":
			push_warning("MusicStateBoard: no state authored as %s." % state_id)
		return false
	if state_id == get_target():
		return false

	var leaving := _current
	_pending = state_id

	if leaving == &"":
		# Nothing to hand over from - the first state of a session, or the first
		# after a death stopped everything. It simply begins.
		_open(state_id)
		return true

	_stow(leaving, exit_time)

	var lead := maxf(exit_time - maxf(overlap, 0.0), 0.0)
	if lead <= 0.0:
		_open(state_id)
		return true

	# Real time and process-always: the world is frozen behind most of the menus
	# this is called from, and the length of a handover is not something fast travel
	# or a hit stop should be able to change.
	var timer := get_tree().create_timer(lead, true, false, true)
	timer.timeout.connect(_open_if_pending.bind(state_id))
	return true


## Opens a state at once: full speed, full level, no ramp and no overlap, with
## everything else stopped where it stands.
##
## [b]This is the one way in that is not a handover[/b], and it exists for the far
## side of a death: the soundtrack has already been wound down to nothing by
## [method slow_to_silence], so there is nothing to fade out of and no reason to
## creep the base's own track up from 5% - the player is coming round, and the base
## is simply playing.
##
## [param from_start] opens at the top of the track instead of where the state was
## left, which is what a death asks for and nothing else does.
func play_now(state_id: StringName, from_start: bool = false) -> bool:
	var player := _players.get(state_id) as MusicPlayer
	if player == null:
		return false

	_pending = &""
	for other: StringName in _players.keys():
		if other != state_id:
			_park(other)

	_kill_tween(state_id)
	if from_start:
		forget(state_id)

	var state := _authored[state_id] as MusicState
	player.volume_db = state.volume_db
	player.pitch_scale = 1.0
	player.play_from(_opening_position(state_id))
	_current = state_id
	state_entered.emit(state_id)
	return true


## Winds whatever is playing down to [member low_pitch] and silence over
## [param seconds], and hands over to nothing.
##
## The track is deliberately left running rather than stopped: it carries on from
## exactly where it was, slower and quieter every second, which is what a death
## sounds like. It is still the current state afterwards, and whatever comes next
## stops it - see [method play_now].
##
## A negative [param seconds] uses [member death_slow_time].
func slow_to_silence(seconds: float = -1.0) -> void:
	var player := get_active_player()
	if player == null:
		return

	# Anything on its way in is called off. A death during a handover must not be
	# followed a moment later by the state that was arriving.
	_pending = &""

	var time := maxf(seconds if seconds >= 0.0 else death_slow_time, 0.0001)
	_kill_tween(_current)
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(player, "pitch_scale", low_pitch, time)
	tween.tween_property(player, "volume_db", silent_db, time)
	_tweens[_current] = tween


## The incoming half of a handover, one second before the outgoing half finishes.
func _open_if_pending(state_id: StringName) -> void:
	# Only if it is still what was asked for. A second change of state during the
	# overlap leaves this timer running with nothing to do, and this is what makes
	# that harmless.
	if _pending != state_id or not is_inside_tree():
		return
	_open(state_id)


func _open(state_id: StringName) -> void:
	var player := _players.get(state_id) as MusicPlayer
	var state := _authored.get(state_id) as MusicState
	if player == null or state == null:
		return

	_pending = &""
	_current = state_id

	_kill_tween(state_id)
	player.volume_db = silent_db
	player.pitch_scale = low_pitch
	player.play_from(_opening_position(state_id))

	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(player, "pitch_scale", 1.0, maxf(enter_time, 0.0001))
	tween.tween_property(player, "volume_db", state.volume_db, maxf(enter_time, 0.0001))
	_tweens[state_id] = tween

	state_entered.emit(state_id)


## The outgoing half: slowed, faded, and only stopped once it is already inaudible,
## so where it is remembered from is where it was actually heard to.
func _stow(state_id: StringName, seconds: float) -> void:
	var player := _players.get(state_id) as MusicPlayer
	if player == null or not player.playing:
		_park(state_id)
		return

	_kill_tween(state_id)
	var time := maxf(seconds, 0.0001)
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(player, "pitch_scale", low_pitch, time)
	tween.tween_property(player, "volume_db", silent_db, time)
	tween.chain().tween_callback(_park.bind(state_id))
	_tweens[state_id] = tween


## Stops a state and remembers where it had got to. Safe on a state that was never
## playing, which is what makes it the one way a track is ever stopped.
func _park(state_id: StringName) -> void:
	var player := _players.get(state_id) as MusicPlayer
	var state := _authored.get(state_id) as MusicState
	if player == null or state == null:
		return

	_kill_tween(state_id)

	if player.playing:
		var at := state.wrap_position(player.get_stream_position())
		_positions[state_id] = at
		player.stop()
		state_stowed.emit(state_id, at)

	# Left ready rather than left as the fade found it, so nothing can start a track
	# silent or at a twentieth speed later on.
	player.volume_db = state.volume_db
	player.pitch_scale = 1.0

	if _current == state_id:
		_current = &""


## Where a state opens: the top of its track when it is authored to, and otherwise
## exactly where it was stowed.
func _opening_position(state_id: StringName) -> float:
	var state := _authored.get(state_id) as MusicState
	if state == null or state.always_from_start:
		return 0.0
	return state.wrap_position(get_saved_position(state_id))


func _kill_tween(state_id: StringName) -> void:
	var tween := _tweens.get(state_id) as Tween
	if tween != null and tween.is_valid() and tween.is_running():
		tween.kill()
	_tweens.erase(state_id)
