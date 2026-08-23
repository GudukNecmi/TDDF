class_name MusicPlayer
extends AudioStreamPlayer
## Background music that starts with the session, keeps looping, and winds itself
## up as each round goes on.
##
## The track, the level and `autoplay` are set on the node in the inspector;
## this script adds the looping guarantee, a guard that refuses to restart a track
## that is already playing, and the tempo programme below.
##
## Gameplay sounds live in [SoundBank] and have their own voices, so firing or
## reloading can never interrupt or restart the music.
##
## [b]The tempo programme.[/b] One take of one song carries the whole session. It
## is never stopped, never switched and never rewound between rounds, because a
## round boundary the player can hear undoes the whole effect. What changes from
## round to round is only the speed:
##
##   * a run opens at [member run_start_pitch] and climbs to
##     [member run_end_pitch], arriving exactly as the run's clock reaches zero
##   * the clock reaching zero winds it straight back down to
##     [member run_start_pitch] over [member run_end_slowdown_time] and holds it
##     there - all of it read off the clock here, frame by frame, so there is no
##     signal to miss and nothing that can leave the music stuck at full speed
##   * the collection phase, the walk to the portal and the whole upgrade menu run
##     at that speed, on the same take of the same song
##   * NEXT ROUND rebuilds the world, and this player is not part of it - see
##     [member persistent] - so the same playback carries straight on and simply
##     starts climbing again
##
## Both speeds and the length of the climb are inspector fields, and the climb is
## read from the run's own clock rather than a duplicate of it, so retuning
## [member WaveManager.run_duration] restretches the ramp to match.
##
## [b]More maps later.[/b] The speed programme is the map's, not this track's:
## a second arena hands its own stream to [method play_track] and gets the same
## 0.80 -> 1.25 -> 0.80 shape for free, because nothing here names a song.

## Restarts the track when it reaches the end. A stream that already loops
## internally - such as a WAV imported with a forward loop - never reports
## finished, so this is the fallback for tracks imported without one.
@export var loop: bool = true

@export_group("Opening")
## Played instead of the ordinary track on [member opening_round], and only then.
##
## It is an [AudioStreamPlaylist] holding the opening and the loop back to back
## with no crossfade, rather than two players handing over to each other: a
## playlist is mixed as one continuous stream, so the loop begins on the sample
## after the opening's last one and there is no gap to hear. Two players, or a
## `finished` signal, would both leave an audio buffer's worth of silence in the
## middle.
##
## Leaving it unset makes every session start on the ordinary track.
@export var opening_stream: AudioStream
## What plays once the opening has been through: every later start, and this one
## again if the playlist ever runs out. Left unset, [member AudioStreamPlayer.stream]
## is used, which is what a player with no opening does anyway.
@export var loop_stream: AudioStream
## The round the opening belongs to. Only a session that begins on round 1 opens
## with it; a run started on any other round starts straight in on the loop.
@export var opening_round: int = 1
## The persistent round counter. Unresolved, every start is a first start and the
## opening plays each time.
@export var progress_path: NodePath = ^"/root/RunProgress"
## How long the opening track runs, in seconds. 0 measures it off the playlist's
## first entry, which is what keeps the resume point correct when the opening
## itself is re-cut.
@export var opening_length: float = 0.0

@export_group("Fade in")
## How long the track takes to reach its authored volume when it starts itself.
## 0 opens at full level.
##
## This is only ever heard at the start of a session, or on the first run after a
## death - the two times there is genuinely nothing playing to carry on from. An
## ordinary round boundary never fades anything, because nothing ever stops.
@export var fade_in_time: float = 1.4
## Level it opens at, in decibels. Low enough to be inaudible.
@export var fade_in_from_db: float = -40.0

@export_group("Run tempo")
## Whether this track runs the speed programme at all. Off leaves `pitch_scale`
## alone entirely, so the node behaves as a plain looping music player - which is
## what the base track is.
##
## This is authored, and read once: it says what the track is, not who is driving
## it this instant. Systems that need the speed for a moment take a timed lease
## instead - see [method suspend_ramp] - so none of them can leave the programme
## switched off behind them.
@export var tempo_ramp_enabled: bool = true
## Speed a run opens at, and the speed it settles back to between runs. Every
## round starts here: the first one, the tenth one, and the one after a death.
@export var run_start_pitch: float = 0.8
## Speed the track has reached exactly as the run's clock hits zero.
@export var run_end_pitch: float = 1.25
## How long the wind-down back to [member run_start_pitch] takes once the clock
## has hit zero, in seconds.
##
## This transition is driven here, from the run's own clock, rather than by
## anything listening for the run to end. That is deliberate: a one-shot signal
## can be missed, connected late, or undone a frame later by something else
## writing the pitch, and any of those leave the music stuck at
## [member run_end_pitch] for the whole collection phase. Reading the clock every
## frame cannot be missed, and re-asserts the right speed on the very next frame
## whatever else has touched it.
@export var run_end_slowdown_time: float = 3.0
## How long the climb takes, in seconds. 0 follows the run's own clock, which is
## the default and what keeps the ramp and the on-screen timer from ever drifting
## apart; a positive value drives it from a clock of this node's own instead.
@export var run_ramp_time: float = 0.0
## Run whose progress the tempo is read from. Left empty - which is what a
## player living outside the world scene wants - the run is found in whichever
## world is currently loaded instead.
@export var wave_manager_path: NodePath = ^"../WaveManager"

@export_group("Continuity")
## Whether this player lives outside the world scene and outlasts it.
##
## On, the node is an autoload: NEXT ROUND rebuilds the world underneath it and
## this playback is simply not part of what is torn down, so the song, the
## playback position and the playback instance are all literally the same ones
## before and after. There is no handover to get wrong and no seam to hear.
##
## It also means nothing in the new world starts the music - it was never
## stopped - so the round boundary is found rather than announced: a new
## [WaveManager] appearing is a new run, and [method begin_run] opens the tempo
## programme again on it.
##
## Off is an ordinary in-scene player that begins and ends with its world, which
## is what the base track is.
@export var persistent: bool = false
## How often a persistent player looks for the run it has lost, in seconds. It
## only ever searches while there is no live run to follow - across the rebuild
## between rounds - and caches the one it finds.
@export var run_search_interval: float = 0.2
## Whether an in-scene track is handed to the next round through [MusicCarryover]
## rather than restarted by it. Ignored by a persistent player, which has nothing
## to hand over: it is still playing on the other side.
@export var remember_across_rounds: bool = true
## The store it is left in - the [code]MusicMemory[/code] autoload.
@export var memory_path: NodePath = ^"/root/MusicMemory"

@onready var _memory: MusicCarryover = get_node_or_null(memory_path) as MusicCarryover

## Where [method AudioStreamPlayer.play] was last told to start, and how many
## seconds of audio have been consumed since. Their sum is the position in the
## current stream's own timeline.
##
## Tracked here rather than read back from the playback, because the opening is a
## playlist and what a playlist reports is its *current entry's* position, which
## cannot be told apart from the same number measured against the whole. Counting
## consumed time is unambiguous either way.
var _play_from: float = 0.0
var _stream_time: float = 0.0

var _manager: WaveManager
var _ramp_from_pitch: float = 1.0
var _ramp_from_progress: float = 0.0
var _ramp_clock: float = 0.0
## Seconds since the run's clock hit zero, and the speed it was running at on the
## frame it did. The wind-down is measured from both, so it eases from wherever
## the music actually was - normally exactly [member run_end_pitch] - rather than
## from an assumed speed.
var _finish_clock: float = 0.0
var _slow_from_pitch: float = 1.0
var _run_was_over: bool = false
## Seconds left on the lease something else holds over the speed. Counts itself
## down, so the programme always comes back. See [method suspend_ramp].
var _suspended_for: float = 0.0
## Last progress actually read off a live run. Held rather than recomputed while
## the world is being rebuilt, so the frames with no run in them cannot snap the
## tempo to either end of the ramp.
var _last_progress: float = 0.0
var _search_countdown: float = 0.0

## Whether this player runs the speed programme at all, read once from
## [member tempo_ramp_enabled] on ready. Kept as its own copy so that nothing
## written into the exported flag at runtime - by an inspector poke during a
## playtest, or by anything else - can quietly retire the programme for the rest
## of the session.
var _ramps: bool = true
## The level the mix was authored at. A fade the last world was part way through
## when it was torn down cannot leave the next round quiet, because the run start
## puts the level back to this.
var _authored_volume_db: float = 0.0

## Whether the track was still going as of the last frame.
##
## Sampled rather than read at teardown, because a node on its way out of the
## tree has already been stopped by the time its own [method _exit_tree] runs, so
## asking then would say "stopped" for every track including the one that was
## playing a frame earlier. This is what tells a handover apart from a rebuild.
var _was_playing: bool = false


func _ready() -> void:
	finished.connect(_on_finished)

	_ramps = tempo_ramp_enabled
	_authored_volume_db = volume_db
	_manager = _find_manager()

	var resume_at := _resume_from_memory()
	if resume_at < 0.0:
		_pick_opening_track()
		_ramp_from_pitch = run_start_pitch

	_ramp_from_progress = 0.0
	# Set before the first frame is heard, so the opening note is already at its
	# starting speed rather than snapping to it a frame later.
	if _ramps:
		pitch_scale = _ramp_from_pitch

	if autoplay:
		fade_in()
		# Started by hand rather than left to `autoplay`. Autoplay begins the
		# track as the node enters the tree, and picking the opening above assigns
		# `stream` - and assigning a stream to an AudioStreamPlayer stops whatever
		# it was playing. Without this the chosen track is loaded and silent.
		play_from(maxf(resume_at, 0.0))


## Takes up whatever the last round left, and returns the position to open at -
## or below zero when there was nothing to resume, which is what makes this a
## first start. A persistent player never has anything to resume: it did not stop.
func _resume_from_memory() -> float:
	if persistent or not remember_across_rounds:
		return -1.0
	if _memory == null or not _memory.has_state():
		return -1.0

	stream = _memory.get_stream()
	_ramp_from_pitch = _memory.get_pitch()
	_memory.mark_resumed()
	return _memory.get_position()


## Chosen before the first note: an autoplaying player starts on whichever track
## this leaves in [member AudioStreamPlayer.stream].
##
## A session opening on round 1 gets the opening; a run started on any later round
## - which after a death is the only way the track is ever started again - begins
## on the loop. The round comes from the persistent counter, so this needs nothing
## passed to it.
func _pick_opening_track() -> void:
	if loop_stream == null:
		loop_stream = stream
	if opening_stream == null:
		return

	var progress := get_node_or_null(progress_path) as RoundCounter
	var round_number := 1 if progress == null else progress.get_round()
	stream = opening_stream if round_number == opening_round else loop_stream


## Brings the track up from silence to whatever level it is mixed at. Only a
## track that starts itself does this; a track another system fades in - the base
## music under a handover - is left entirely to that system, so the two can never
## be fading the same player in at once.
func fade_in(duration: float = -1.0) -> void:
	var seconds := duration if duration >= 0.0 else fade_in_time
	if seconds <= 0.0:
		return

	var target := volume_db
	volume_db = fade_in_from_db
	create_tween().tween_property(self, "volume_db", target, seconds)


## Starts playback and remembers where from, which is the whole of what makes the
## resume point measurable. Everything in this script that starts the track goes
## through here rather than calling [method AudioStreamPlayer.play] directly.
func play_from(position: float) -> void:
	_play_from = maxf(position, 0.0)
	_stream_time = 0.0
	play(_play_from)


## Seconds into the current stream's own timeline.
func get_stream_position() -> float:
	return _play_from + _stream_time


## Opens the tempo programme on a new run: the speed goes to
## [member run_start_pitch] and the climb to [member run_end_pitch] is aimed from
## there across the run's own clock.
##
## What it deliberately does *not* do is touch the playback. The track is already
## playing, mid-bar, wherever the last round left it, and that is the entire point
## - so unless it was genuinely stopped, which only a death does, nothing here
## restarts, rewinds or switches anything. The one exception is the level, which
## is put back to what the mix asks for in case the world that was torn down had
## been part way through fading it.
##
## Safe to call directly: a debug key, a test harness, or a future map handing the
## player its own track before starting a round on it.
func begin_run() -> void:
	# Asked before the hold is lifted, and not from [member AudioStreamPlayer.playing]
	# alone: a track being held by the pause menu reports itself as not playing, and
	# a needle resting on the record is the one thing that must never be mistaken
	# for a track that stopped - starting a new run straight out of the menu would
	# throw the song away and begin it again.
	var carrying := playing or stream_paused

	stream_paused = false
	volume_db = _authored_volume_db

	if not carrying:
		# Nothing to carry on from. Only a death stops this track - it hands the
		# soundtrack to the base music - so this is the first run of a session or
		# the first one after dying, and both of those really do start the song.
		_pick_opening_track()
		fade_in()
		play_from(0.0)

	_ramp_clock = 0.0
	_last_progress = 0.0
	_finish_clock = 0.0
	_run_was_over = false
	_ramp_from_pitch = run_start_pitch
	_ramp_from_progress = 0.0
	pitch_scale = run_start_pitch
	# Any lease the last round's death or menu left running is void: a new run is
	# unambiguously the programme's.
	_suspended_for = 0.0


func _process(delta: float) -> void:
	_was_playing = playing

	# Before the early-out below on purpose: after a death there is no playback at
	# all, and this is what notices the next run beginning and starts one.
	if persistent:
		_watch_for_new_run(delta)

	if not playing or stream_paused:
		return

	# Stream seconds, not wall seconds: a track running at 1.25 speed eats its
	# own timeline a quarter faster, and both the resume point and the loop are
	# measured in that timeline.
	_stream_time += delta * pitch_scale
	_ramp_clock += delta
	# Kept running even while something else is driving the speed, so the moment
	# the programme takes over again it already knows how far through the run - or
	# through the wind-down - the music actually is.
	_follow_run_end(delta)

	if not _ramps:
		return

	if _suspended_for > 0.0:
		_suspended_for -= delta
		if _suspended_for > 0.0:
			return
		# Whatever was driving the speed has had its say and has not asked for more
		# time. The programme takes the pitch back from wherever that left it.
		_suspended_for = 0.0
		_anchor_ramp(pitch_scale)

	pitch_scale = _run_pitch()


## Watches the run's clock cross zero and times the wind-down that follows.
##
## The crossing is *noticed* rather than announced, so there is no signal to miss
## and no connection to get wrong: the run either reports itself finished or it
## does not, and the frame it starts reporting it is the frame the slowdown
## starts. It also cannot fire twice, because it is a state the clock is in rather
## than an event that happened.
func _follow_run_end(delta: float) -> void:
	var over := _is_run_over()

	if over and not _run_was_over:
		# Anchored on the speed the music is genuinely at as the clock stops -
		# 1.25 at the end of an ordinary run, whatever a pause or a death left
		# behind otherwise - so the wind-down never jumps before it eases.
		_slow_from_pitch = pitch_scale
		_finish_clock = 0.0
	elif not over:
		_finish_clock = 0.0

	if over:
		_finish_clock += delta

	_run_was_over = over


## Whether the run's clock has stopped. A run that cannot be found at all - the
## frames between one world being torn down and the next being built - is not a
## finished run: it is no run, and the speed simply holds where it is.
func _is_run_over() -> bool:
	if _manager == null or not is_instance_valid(_manager):
		return _run_was_over
	return _manager.is_collection_phase()


## A persistent player outlives the world, so it is the world appearing that tells
## it a round has begun - not the other way round. The run it was following is
## freed by the rebuild; the next one to turn up is the next round.
##
## The search only runs while there is nothing to follow, which is the handful of
## frames the rebuild takes, and is rate limited even then.
func _watch_for_new_run(delta: float) -> void:
	if _manager != null and is_instance_valid(_manager) and _manager.is_inside_tree():
		return

	_search_countdown -= delta
	if _search_countdown > 0.0:
		return
	_search_countdown = maxf(run_search_interval, 0.0)

	var found := _find_manager()
	if found == null:
		return

	_manager = found
	begin_run()


## The run whose clock the tempo follows. The exported path first, so an in-scene
## player is wired exactly as it always was; failing that the loaded world is
## searched, which is how a player that lives outside every world finds the one
## that is currently up.
func _find_manager() -> WaveManager:
	if not is_inside_tree():
		return null

	if not wave_manager_path.is_empty():
		var direct := get_node_or_null(wave_manager_path) as WaveManager
		if direct != null:
			return direct

	return _first_wave_manager(get_tree().current_scene)


func _first_wave_manager(node: Node) -> WaveManager:
	if node == null:
		return null

	var manager := node as WaveManager
	if manager != null:
		return manager

	for child: Node in node.get_children():
		var found := _first_wave_manager(child)
		if found != null:
			return found
	return null


## The speed the programme says the music should be running at right now - the
## whole shape of a round in one function, read from the run's clock rather than
## assembled out of events:
##
##   * while the run is live, the climb from the speed it opened at to
##     [member run_end_pitch], arriving as the clock reaches zero
##   * once the clock has stopped, the wind-down back to
##     [member run_start_pitch] over [member run_end_slowdown_time], and then a
##     hold there for as long as the collection phase, the portal and the menu
##     take
##
## Because it is recomputed every frame, anything that writes the pitch and then
## stops - a tween that was interrupted, a system that set it once - is corrected
## on the next frame instead of leaving the music stranded at the wrong speed.
func _run_pitch() -> float:
	if _is_run_over():
		var over := clampf(_finish_clock / maxf(run_end_slowdown_time, 0.0001), 0.0, 1.0)
		# Eased rather than linear, and eased at both ends, so the slowdown leaves
		# 1.25 and arrives at 0.80 without a corner at either.
		return lerpf(_slow_from_pitch, run_start_pitch, over * over * (3.0 - 2.0 * over))

	var span := 1.0 - _ramp_from_progress
	if span <= 0.0001:
		return run_end_pitch
	var t := clampf((_progress() - _ramp_from_progress) / span, 0.0, 1.0)
	return lerpf(_ramp_from_pitch, run_end_pitch, t)


## Re-aims the climb from wherever the speed is right now.
##
## Used whenever the ramp is handed back after something else has been driving the
## pitch - the pause menu, a wind-down. Taking the anchor from the live value is
## what stops the ramp snapping the speed to a curve the music never actually left.
func _anchor_ramp(from_pitch: float) -> void:
	_ramp_from_pitch = from_pitch
	_ramp_from_progress = _progress()


## The speed the run programme says the music should be running at right now.
##
## What [MusicDirector] asks before handing the pitch back after it has been
## driving it itself: the answer is the programme's, not a remembered number, so a
## menu closed part way through the wind-down returns to where the slowdown has
## actually got to rather than to the speed the run was at when the menu opened.
func get_programmed_pitch() -> float:
	return _run_pitch()


## Stands the run programme down for [param seconds] so something else can drive
## the speed - a death winding the world down, the pause menu ducking it.
##
## It is a lease, not a switch, and that is the whole point. A switch has to be
## turned back on by whoever turned it off, and the systems that turn it off are
## tweens on nodes that get killed, interrupted and rebuilt - so a single lost
## callback used to leave the programme switched off for good, freezing the music
## at whatever speed it happened to be at. That is exactly how the run could end
## with the music stuck at [member run_end_pitch]. A lease cannot be lost: it runs
## out on its own, and the programme takes the speed back on the next frame.
##
## Asking for less time than is already leased does not shorten it, so two systems
## overlapping cannot cut each other off.
##
## A negative [param seconds] leases the speed until the next run begins. That is
## for a death and only a death: the track is stopped moments later and the player
## can only come back through a new run, so [method begin_run] is a clearer that
## cannot be missed - which is what makes an open-ended hold safe there and
## nowhere else.
func suspend_ramp(seconds: float) -> void:
	if seconds < 0.0:
		_suspended_for = INF
		return
	_suspended_for = maxf(_suspended_for, seconds)


## Hands the speed back before the lease is up.
func resume_ramp() -> void:
	if _suspended_for <= 0.0:
		return
	_suspended_for = 0.0
	_anchor_ramp(pitch_scale)


## Whether the programme is currently the thing writing the speed.
func is_ramp_active() -> bool:
	return _ramps and _suspended_for <= 0.0


## 0 at the start of the run and 1 as its clock hits zero. A run that has finished
## reads 1, so the tempo simply holds at the top until something winds it down.
##
## With no run to read - the frames between one world being torn down and the next
## being built - the last figure is held rather than assumed, because assuming
## either end would audibly snap the speed across the rebuild.
func _progress() -> float:
	if run_ramp_time > 0.0:
		_last_progress = clampf(_ramp_clock / run_ramp_time, 0.0, 1.0)
		return _last_progress

	if _manager == null or not is_instance_valid(_manager) or _manager.run_duration <= 0.0:
		return _last_progress

	_last_progress = clampf(
		1.0 - _manager.get_time_left() / _manager.run_duration, 0.0, 1.0)
	return _last_progress


## How long the opening runs for. Measured off the playlist's first entry rather
## than the playlist as a whole, since the whole of it is the opening *and* the
## loop back to back.
func _opening_length() -> float:
	if opening_length > 0.0:
		return opening_length
	if opening_stream == null:
		return 0.0

	if opening_stream.has_method(&"get_list_stream"):
		var first := opening_stream.call(&"get_list_stream", 0) as AudioStream
		if first != null:
			return first.get_length()
	return opening_stream.get_length()


func _is_on_opening() -> bool:
	return opening_stream != null and stream == opening_stream


## Switches tracks - what a second map hands its own soundtrack to. Asking for the
## track that is already playing does nothing, so repeated calls cannot restart the
## music part-way through.
func play_track(track: AudioStream) -> void:
	if track == null:
		return
	if track == stream and playing:
		return

	stream = track
	loop_stream = track
	play_from(0.0)


## The opening is only ever heard once. When the playlist reaches its end the
## player drops back to the plain loop, so a track that runs long enough to finish
## repeats from the loop rather than replaying the opening under it.
func _on_finished() -> void:
	if not loop:
		return

	if loop_stream != null and stream != loop_stream:
		stream = loop_stream
	play_from(0.0)


## Hands this take of this song to the next round on the way out.
##
## A persistent player never does: it is not going anywhere, and leaving a resume
## point would only give the next round something to restart from that it does not
## need. Only a track that is genuinely still playing is handed over either way -
## a death stops the arena track and gives the soundtrack to the base one, and
## there is nothing to carry on from in that.
func _exit_tree() -> void:
	if persistent or not remember_across_rounds or _memory == null:
		return

	if not _was_playing:
		# Already stopped before the world came down, which only the handover to
		# the base track after a death does. There is no take left to carry on
		# from, so anything an earlier round left is forgotten too and the next one
		# opens fresh rather than resuming a song that stopped minutes ago.
		_memory.clear()
		return

	var carried := _resume_point()
	var track := carried[0] as AudioStream
	if track != null:
		_memory.remember(track, carried[1], pitch_scale)


## Which stream the next round should pick up, and where in it.
##
## Mid-opening it is the playlist itself, so the rest of the opening still plays.
## Past the opening it is the plain loop, offset by however much of it has been
## through - which is the position inside the loop, and the reason the next round
## joins the song mid-bar rather than at the top of it.
func _resume_point() -> Array:
	var at := get_stream_position()

	if _is_on_opening():
		var length := _opening_length()
		if at < length:
			return [opening_stream, at]
		if loop_stream != null:
			return [loop_stream, _wrapped(at - length, loop_stream)]
		return [opening_stream, at]

	return [stream, _wrapped(at, stream)]


## Folds a position back inside a track that has already looped round, so a long
## round cannot hand the next one a resume point past the end of the song.
func _wrapped(position: float, track: AudioStream) -> float:
	if track == null:
		return 0.0
	var length := track.get_length()
	if length <= 0.0:
		return 0.0
	return fposmod(maxf(position, 0.0), length)
