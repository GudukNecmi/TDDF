class_name MusicDirector
extends Node
## Hands the soundtrack over from the arena track to the base track once the last
## enemy alive is actually dead.
##
## It crossfades rather than switching: the arena track is faded down over the
## same window the base track is faded up, and neither is ever stopped abruptly.
## The outgoing player is left stopped but intact at the end, so it can be
## started again by a later run without being rebuilt.
##
## "The last enemy" is read from the enemies container emptying, not from a kill
## count, so it is correct however enemies come and go - and because [DeathFade]
## keeps a corpse in the tree while it fades, the handover lands when the body
## genuinely disappears rather than the instant its health hits zero.
##
## By default it waits for the wave manager's collection phase before it will
## trigger at all. Without that, clearing the arena for a moment at second 20 -
## with another wave already queued - would switch the music over mid-run.

## Emitted as the crossfade begins, not when it completes.
signal switched_to_base
## Emitted as the crossfade back to the arena begins.
signal switched_to_arena

## Group used by [method get_active], so the death sequence on the player and the
## upgrade menu on the HUD can both reach the soundtrack without either being
## wired to it.
const GROUP := &"music_director"

## Passed as [param hold] to [method set_pitch] by a caller whose hold has no
## length in seconds - it lasts until the next run opens. See [method slow_for_death].
const HOLD_UNTIL_NEXT_RUN := -1.0

## The board of music states - the [code]MusicStates[/code] autoload - which is
## what actually carries the soundtrack now.
##
## [b]This node became the seam rather than the source.[/b] Everything that used to
## be a crossfade between two players in this file is now a change of state on
## [MusicStateBoard]: it owns one playback per state, remembers where each of them
## had got to, and hands them over with the two-second shape every transition in
## the game shares. What is left here is the systems that were already talking to
## the soundtrack - a pause ducking it, a death winding it down, a teleport home
## asking for the base - so none of them had to learn a new name.
##
## Left unresolved, every method below falls back to the two-player crossfade this
## node has always done, which is what a world opened on its own still gets.
@export var states_path: NodePath = ^"/root/MusicStates"
## Which state [method switch_to_base] asks for.
@export var base_state: StringName = &"base"
## Which state [method switch_to_arena] asks for - the road, and everything that
## happens on it.
@export var arena_state: StringName = &"travel"
## Player carrying the arena track - the [code]ArenaMusic[/code] autoload, which
## lives outside the world scene so that rebuilding the world for the next round
## does not take the soundtrack down with it. It is reached by absolute path for
## exactly that reason: it is not a sibling of this node, and it is not rebuilt.
##
## [b]Silent since the state board took the soundtrack over[/b] - see
## [member states_path] - and left wired so that a world without a board still
## plays exactly as it used to.
@export var arena_player_path: NodePath = ^"/root/ArenaMusic"
## Player the base track is faded up on. Should not be autoplaying.
@export var base_player_path: NodePath = ^"../BaseMusic"
## Node whose children are the live enemies.
@export var enemies_path: NodePath = ^"../Enemies"
## Run whose collection phase gates the handover.
@export var wave_manager_path: NodePath = ^"../WaveManager"

@export_group("Trigger")
## Whether the arena falling quiet hands the soundtrack over to the base track at
## all.
##
## Off. Finishing a run is not leaving it: the player stays in the arena to
## collect, and the track they have been fighting to keeps playing - wound down
## to [member MusicPlayer.run_start_pitch] rather than replaced. The handover to the base
## track is now only what a *death* does, where the player really has left.
@export var auto_switch_on_clear: bool = false
## Only hand over once the clock has run out and spawning has stopped. Turn this
## off to switch the moment the arena is ever empty.
@export var require_collection_phase: bool = true
## Ignores an arena that has been empty since the start, so the handover cannot
## fire before the first enemy has ever appeared.
@export var require_enemy_seen: bool = true

@export_group("Run end")
## How long the track takes to wind back up to full speed when something asks it
## to. The same easing a wind-down uses, in the other direction.
##
## The run ending is deliberately not handled here at all. The clock stopping
## winds the track down to [member MusicPlayer.run_start_pitch] over
## [member MusicPlayer.run_end_slowdown_time], and the track does that itself off
## the run's own clock - so there is no signal for this node to miss and no second
## opinion about the speed to fight with. What is left here is only what genuinely
## belongs to this node: a death, a pause, and the handovers between the two
## tracks.
@export var portal_pitch_time: float = 3.0

@export_group("Pause")
## Playback speed the soundtrack is dragged down to as the pause menu comes up.
##
## The music is never restarted and never rewound. It is slowed and faded out
## over [member pause_pitch_time], then held with
## [member AudioStreamPlayer.stream_paused] - the needle stays on the record - and
## closing the menu lifts it from that exact groove and winds it back up to
## whatever speed the round was actually running at.
@export var pause_pitch_scale: float = 0.8
## How long the slowdown, and the wind back up, each take.
@export var pause_pitch_time: float = 1.5
## How long the fade out, and the fade back in, each take.
@export var pause_volume_time: float = 1.5
## Level the track is taken to before it is held. Low enough to be silence.
@export var pause_silent_db: float = -60.0
## Whether playback is actually held at the end of the fade, rather than left
## running inaudibly. Holding it is what guarantees the resume picks up on the
## same sample it left.
@export var pause_stops_playback: bool = true

@export_group("Crossfade")
## How long the two tracks take to trade places.
@export var fade_time: float = 3.0
## Level the base track settles at, in decibels.
@export var base_volume_db: float = -6.0
## Level the arena track is taken down to before it is stopped. Low enough to be
## inaudible well before the fade ends.
@export var silent_db: float = -60.0
## Level the arena track settles at when it is faded back up for a new round.
@export var arena_volume_db: float = -2.0

@export_group("Death")
## Playback speed the arena track winds down to as the player dies. The track is
## never stopped and never restarted - it keeps playing, just slower - which is
## what turns dying into the world running down rather than the music being cut.
@export var death_pitch_scale: float = 0.6
## How long it takes to get there.
@export var death_pitch_time: float = 1.6
## How long the handover to the base track takes while the player is being put
## back together. Long on purpose: it should still be arriving as the last heart
## lands.
@export var death_fade_time: float = 4.0

@onready var _states: MusicStateBoard = get_node_or_null(states_path) as MusicStateBoard
@onready var _arena: AudioStreamPlayer = get_node_or_null(arena_player_path) as AudioStreamPlayer
@onready var _base: AudioStreamPlayer = get_node_or_null(base_player_path) as AudioStreamPlayer
@onready var _enemies: Node = get_node_or_null(enemies_path)
@onready var _manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager

var _seen_enemy: bool = false
var _switched: bool = false
var _tween: Tween
var _pitch_tween: Tween
var _pause_tween: Tween
var _paused_player: MusicPlayer
var _pitch_before_pause: float = -1.0
var _volume_before_pause: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if _states == null:
		_states = MusicStateBoard.get_active(self)


## The track currently carrying the soundtrack: whichever state the board is
## playing, and failing that the base one once it has taken over or the arena one
## until then. Every speed change goes through this rather than naming a player, so
## ducking a pause works wherever the player is standing and whatever is playing
## there.
func _current_player() -> MusicPlayer:
	if _states != null:
		var stated := _states.get_active_player()
		if stated != null:
			return stated

	if _base != null and _base.playing and (_arena == null or not _arena.playing):
		return _base
	return _arena


## The single place playback speed is written.
##
## Every slowdown this node owns comes through here - a death, the pause menu - so
## there is one easing and one tween to interrupt.
##
## The track's own speed programme rewrites the pitch every frame from the run
## clock, so this has to hold it off for as long as the change takes, or the tween
## would be overwritten before it was heard. It does that by leasing the speed for
## a stated number of seconds rather than by switching the programme off:
## [param hold] is how much longer than the tween the caller needs the pitch to
## stay where it put it. When the lease runs out the programme takes the speed
## back on its own, so a tween that is killed, or a director that is freed with the
## world mid-change, can no longer leave the music stranded at the speed it was
## last set to. It is the same reason this stopped owning the run-end wind-down:
## the one transition that must always happen belongs on the clock, not here.
##
## [param then] runs once the change has landed, for a caller that has to do
## something on the far side of it.
func set_pitch(
	target: float, seconds: float, then: Callable = Callable(), hold: float = 0.0
) -> void:
	var player := _current_player()
	if player == null:
		return

	if hold < 0.0:
		player.suspend_ramp(HOLD_UNTIL_NEXT_RUN)
	else:
		player.suspend_ramp(maxf(seconds, 0.0) + hold)

	if _pitch_tween != null and _pitch_tween.is_running():
		_pitch_tween.kill()

	if seconds <= 0.0:
		player.pitch_scale = target
		if then.is_valid():
			then.call()
		return

	_pitch_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pitch_tween.tween_property(player, "pitch_scale", target, seconds)
	if then.is_valid():
		_pitch_tween.tween_callback(then)


## Playback speed the soundtrack is running at right now.
func get_pitch() -> float:
	var player := _current_player()
	return 1.0 if player == null else player.pitch_scale


## Winds the soundtrack back up to full speed. This is what the portal calls: the
## track keeps playing from wherever it had got to and only its speed changes, so
## the song can never restart at the round boundary.
func restore_pitch(seconds: float = -1.0) -> void:
	set_pitch(1.0, seconds if seconds >= 0.0 else portal_pitch_time)


## Takes the soundtrack down as the pause menu comes up: the speed eases to
## [member pause_pitch_scale] while the level fades to silence, and only once both
## have landed is playback held.
##
## What is remembered is the speed and the level the music was actually at, not
## an assumed pair, because both depend entirely on when the player paused -
## mid-run the tempo ramp has the speed somewhere between its own two ends, after
## the clock it is winding down to, or sitting at, [member MusicPlayer.run_start_pitch].
## Whatever it was is
## what the resume has to arrive back at, and hard-coding 1.0 there would put the
## round back at a speed it had not been running at for a minute.
##
## The speed target is the *slower* of the two, so pausing can only ever slow the
## music down and a track already at the pause speed is simply held where it is.
func duck_for_pause() -> void:
	var player := _current_player()
	if player == null or _paused_player != null:
		return

	_paused_player = player
	_pitch_before_pause = player.pitch_scale
	_volume_before_pause = player.volume_db

	# Leased past the fade as well as the slowdown, so the speed is still this
	# node's on the frame playback is held. After that the hold itself is what
	# keeps the music where it is - and if the menu is left open longer than the
	# lease, the programme taking the speed back changes nothing anybody can hear,
	# because the track is silent and stopped by then.
	set_pitch(
		minf(_pitch_before_pause, pause_pitch_scale), pause_pitch_time,
		Callable(), pause_volume_time)

	if _pause_tween != null and _pause_tween.is_running():
		_pause_tween.kill()
	_pause_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pause_tween.tween_property(
		player, "volume_db", pause_silent_db, maxf(pause_volume_time, 0.0001))
	# Held only once it is already inaudible, so the hold itself is never heard as
	# a cut. `stream_paused` keeps the playback head exactly where it is, which is
	# what lets the resume pick up on the same sample rather than the same song.
	_pause_tween.tween_callback(func() -> void:
		if pause_stops_playback and is_instance_valid(player):
			player.stream_paused = true)


## Lifts the needle back off: playback resumes from the sample it was held on, at
## the pause speed, and the speed and level are both eased back to exactly what
## they were before the menu went up.
##
## The tempo ramp is handed back only once the ease has finished, and it re-anchors
## itself from the live pitch when it is - so it cannot snap the speed to its own
## curve part way through the return.
func unduck_after_pause() -> void:
	var player := _paused_player
	if player == null:
		return

	var back_pitch := _pitch_before_pause
	var back_volume := _volume_before_pause
	_paused_player = null
	_pitch_before_pause = -1.0

	if not is_instance_valid(player):
		return

	if _pause_tween != null and _pause_tween.is_running():
		_pause_tween.kill()

	player.stream_paused = false
	# Started from the pause speed rather than from wherever an interrupted duck
	# left it, so releasing the menu always opens on the same note whether it was
	# held for a second or a minute.
	player.pitch_scale = minf(back_pitch, pause_pitch_scale)

	# Where to come back to. Ordinarily this is exactly what the music was doing
	# before the menu went up, and the two answers are the same number - but when
	# the track's own run programme is about to take the pitch back over, it is the
	# programme that decides. A menu opened during the wind-down at the end of a
	# run would otherwise be closed by winding the music back *up* to the speed it
	# was at when the menu opened, only for the programme to drop it again.
	var back_to := back_pitch
	if player.tempo_ramp_enabled:
		back_to = player.get_programmed_pitch()

	# No callback hands the programme back: the lease this takes simply runs out.
	# That is what makes closing the menu safe however it is closed - interrupted
	# by a second pause, by a death, or by the whole world being rebuilt under it.
	set_pitch(back_to, pause_pitch_time)

	_pause_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pause_tween.tween_property(
		player, "volume_db", back_volume, maxf(pause_volume_time, 0.0001))


## The soundtrack any system should talk to. Null means this scene has none,
## which every caller treats as "the music looks after itself".
static func get_active(from_node: Node) -> MusicDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as MusicDirector


func has_switched() -> bool:
	return _switched


## Winds the soundtrack down to [member death_pitch_scale] without touching its
## volume. Called on the killing hit, and nothing more than a speed change - the
## track carries on playing from where it was.
func slow_for_death() -> void:
	if _states != null:
		# Whatever state the player died in keeps playing from exactly where it was,
		# running down to a twentieth speed and silence over five seconds. There is no
		# death track: the music the player died to is the music that dies with them.
		_states.slow_to_silence()
		return

	# Held until the next run rather than for a stated number of seconds. How long
	# a death takes is the death sequence's business, not this node's, and the run
	# programme must not take the speed back and start climbing again while the
	# player is lying on the ground - so the hold ends where the death does, at the
	# run that follows it. Long before then the track has been stopped by
	# [method switch_to_base], and a stopped track's speed is nobody's business.
	set_pitch(death_pitch_scale, death_pitch_time, Callable(), HOLD_UNTIL_NEXT_RUN)


## The second half of a death: the slowed arena track fades away and the base
## track fades in underneath it, over [member death_fade_time]. The pitch is left
## exactly where [method slow_for_death] put it, so what fades out is still the
## wound-down track rather than one that quietly sped back up first.
func hand_over_after_death() -> void:
	if _states != null:
		# Called as the screen begins clearing in the base, which is one second before
		# the trip home has finished - so the base's own track is already playing by
		# the time the player can see where they are.
		#
		# [b]From the top, at full speed, with no ramp.[/b] Coming home from a death is
		# the one entry that is not a handover: there is nothing left to fade out of,
		# and where the base's music had got to belongs to the run that ended badly.
		_states.play_now(base_state, true)
		return

	switch_to_base(death_fade_time)


func _process(_delta: float) -> void:
	if not auto_switch_on_clear or _switched or _enemies == null:
		return

	if _enemies.get_child_count() > 0:
		_seen_enemy = true
		return

	if require_enemy_seen and not _seen_enemy:
		return
	if require_collection_phase and (_manager == null or not _manager.is_collection_phase()):
		return

	switch_to_base()


## Starts the handover. Guarded so it can only ever happen once per run - the
## run's own scene reload is what arms it again.
##
## [param fade_seconds] overrides [member fade_time] for one call, which is how a
## death asks for a longer, sadder handover than the arena simply falling quiet.
func switch_to_base(fade_seconds: float = -1.0) -> void:
	if _states != null:
		# The board's own handover, which is the same two seconds every change of
		# state in the game takes. [param fade_seconds] is deliberately not passed on:
		# how long a transition lasts belongs to the board, so every one of them
		# sounds alike however long the screen going dark happens to take.
		_switched = true
		_states.enter(base_state)
		switched_to_base.emit()
		return

	if _switched:
		return
	_switched = true

	var seconds := maxf(fade_seconds if fade_seconds >= 0.0 else fade_time, 0.0001)

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)

	if _base != null:
		# Started silent and brought up, so the first instant of the base track is
		# never audible at full level before the fade has begun.
		_base.volume_db = silent_db
		if not _base.playing:
			_base.play()
		_tween.tween_property(_base, "volume_db", base_volume_db, seconds)

	if _arena != null:
		_tween.tween_property(_arena, "volume_db", silent_db, seconds)
		# Stopped only once it is already inaudible, and never freed, so the
		# player itself survives for a later run to reuse.
		_tween.chain().tween_callback(_arena.stop)

	switched_to_base.emit()


## The other direction: the base track goes down and the arena track comes back
## up. Called as the next round is starting, under the black screen.
##
## What it does depends entirely on whether the arena track is still playing.
## After an ordinary round it is - the clock only slowed it - and it is left
## completely alone bar its level, so the next round carries on from the same
## note at the same speed. After a death it is not, because [method switch_to_base]
## stopped it, and only then is it started again with its speed put back.
##
## The world is rebuilt a moment after this, but the arena track is not part of
## it - it is the [code]ArenaMusic[/code] autoload and it simply keeps playing -
## so what this is really doing is taking the *base* track back down. The song
## itself needs no handover: the same playback carries straight across the
## rebuild, and the new world's run winds it back up from
## [member MusicPlayer.run_start_pitch] on its own.
func switch_to_arena(fade_seconds: float = -1.0) -> void:
	if _states != null:
		_switched = false
		_states.enter(arena_state)
		switched_to_arena.emit()
		return

	var seconds := maxf(fade_seconds if fade_seconds >= 0.0 else fade_time, 0.0001)
	_switched = false

	if _pitch_tween != null and _pitch_tween.is_running():
		_pitch_tween.kill()
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)

	if _arena != null:
		if _arena.playing:
			# Still carrying the soundtrack, which is the ordinary next-round case:
			# the run wound it down to `run_start_pitch` and left it playing.
			# Neither its speed nor its position is touched here, and it is not
			# faded up from silence either, because it was never faded down - so
			# the round boundary is inaudible and the next round opens on the exact
			# note this one ended on.
			_tween.tween_property(_arena, "volume_db", arena_volume_db, seconds)
		else:
			# Stopped, which only a death does. There is nothing to carry on from,
			# so this one really is a restart - and it opens at the speed a run
			# opens at, read off the track rather than assumed, so a restarted
			# song and a continued one both begin the minute at the same tempo.
			var player := _arena as MusicPlayer
			_arena.pitch_scale = 1.0 if player == null else player.run_start_pitch
			_arena.volume_db = silent_db
			_arena.play()
			_tween.tween_property(_arena, "volume_db", arena_volume_db, seconds)

	if _base != null:
		_tween.tween_property(_base, "volume_db", silent_db, seconds)

	switched_to_arena.emit()
