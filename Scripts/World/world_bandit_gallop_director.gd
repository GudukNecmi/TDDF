class_name WorldBanditGallopDirector
extends Node
## The horses under the World Map's bandits - one gallop voice per rider a
## group actually shows, riding at the group's own speed, heard from wherever
## the group is.
##
## [b]It is the player's gallop, given to somebody else.[/b] The sound is the
## same [code]HorseGallop.WAV[/code] the player's horse plays, shaped by the
## same [GallopRamp] [WorldMapHorseGallop] drives its own loop through - so a
## bandit group starts softly, climbs as it gets going, drops its pitch back as
## it slows and takes [member GallopRamp.deceleration_duration] to fall silent
## after it stops, because that is what the player's horse does and it is
## literally the same ramp doing it. Nothing about how a gallop sounds is
## decided in this file.
##
## [b]It never decides how a group moves.[/b] Speed is [i]measured[/i] - the
## ground a group actually covered since the last physics frame - never read off
## an intent, a state or a multiplier. A group standing still because it has
## arrived, because it is blocked, or because an encounter has frozen it is
## silent for the same reason and by the same measurement, and nothing here can
## make a group move or stop.
##
## [b]Voices follow the symbolic group, not its strength.[/b]
## [method WorldBandit.get_visible_bandit_count] is the whole answer to how many
## voices a group gets - the leader plus its trailing boxes, which is
## [code]ceil(strength / people_per_box)[/code] - capped by
## [member max_voices_per_group]. A thirty-five strong group shows seven riders
## and is heard as five of them at the default cap. Each voice sits on one of
## those riders' own positions - see
## [method WorldBandit.get_visible_bandit_positions] - so the block is heard as
## a block spread across the ground rather than as a point.
##
## [b]A group is never louder than the player's own horse.[/b] The voices of one
## group are levelled so that all of them together land on the ceiling, not each
## of them - see [method _voice_ceiling_db] - and that ceiling is the player's
## own gallop volume, read off [WorldMapHorseGallop] rather than authored twice.
## Five riders are a fuller sound than one, never a louder one.
##
## [b]Nothing is built for a group that cannot be heard.[/b] Voices are pooled
## and handed to the nearest [member max_groups] groups inside
## [member hearing_radius]; the pool never grows past
## [code]max_groups * max_voices_per_group[/code] players however many hundred
## groups the map holds, and a map whose groups are all far away builds no
## voices at all. Distance itself is [AudioStreamPlayer2D]'s own attenuation,
## which is what makes a group fade as the player rides away and disappear
## entirely past [member hearing_radius].
##
## [b]A map without one is silent, exactly as it was.[/b] This adds a node; it
## changes nothing on [WorldBandit] beyond asking it two questions about its own
## formation.

## Group this joins, so a debug readout can find the one director the same way
## it already finds [WorldMapState] or [WorldBanditActivationDirector].
const GROUP := &"world_bandit_gallop_director"
## Group every [WorldBandit] is already in - the same handle
## [WorldBanditActivationDirector] and [WorldMapCombatBridge] sweep. No second
## registry of groups exists in this file.
const BANDIT_GROUP := &"world_bandit"

## The loop every voice plays - the player's own gallop recording. Left unset,
## nothing is ever heard and no voice is ever built.
@export var stream: AudioStream
## Bus the voices play on. The same one the player's own [code]GallopLoop[/code]
## uses, so the mix treats bandit hooves and the player's as one kind of sound.
@export var bus: StringName = &"Game"
@export var body_group: StringName = &"player"

@export_group("Who is heard")
## How far a group's gallop carries, in pixels - [member AudioStreamPlayer2D.max_distance]
## on every voice, so a group past this is not quietly mixed in at the bottom of
## the scale, it is genuinely gone.
@export var hearing_radius: float = 2600.0
## How sharply a group fades with distance. 1 is a straight fall to nothing at
## [member hearing_radius]; higher drops it off close in, lower keeps it audible
## almost all the way out.
@export_range(0.0, 4.0) var attenuation: float = 1.0
## How far left and right a group is allowed to move in the stereo field. Kept
## modest by default for the same reason [SoundBank] keeps its own modest: this
## is meant to place a group on the map, not to throw it into one ear.
@export_range(0.0, 3.0) var panning_strength: float = 0.6
## The most groups heard at once - the nearest this many inside
## [member hearing_radius]. The one number that bounds what this costs: a map
## of five hundred groups builds exactly as many voices as a map of five.
@export var max_groups: int = 4
## The most voices one group is ever given, however many riders it shows. A
## thirty-five strong group shows seven riders and is heard as this many of
## them; raising it is a fuller group, and every extra voice is levelled down to
## keep the group as a whole at the same ceiling - see [method _voice_ceiling_db].
@export var max_voices_per_group: int = 5
## How often the sweep re-picks which groups are heard, in seconds. Matches
## [member WorldBanditActivationDirector.update_interval]: which groups are near
## the player is not a question that needs re-answering sixty times a second,
## and a group's own voices are updated every physics frame regardless of when
## it was last picked.
@export var update_interval: float = 0.2
## Whether a group the World Map's fog has not currently revealed is silent.
## Read off [WorldMapFog] alone and never off [member Node2D.visible], so a
## group riding past behind a mesa - which is hidden by [WorldMapOcclusion], not
## by fog - is still heard, while one out in ground the player has not lit is
## not heard through the dark.
@export var silent_while_fogged: bool = true

@export_group("Level")
## The loudest a whole group is ever mixed at, in decibels, before distance is
## applied. Held at or below the player's own gallop while
## [member match_player_gallop_volume] is on.
@export var volume_db: float = -6.0
## Whether the ceiling above is additionally held down to the player's own
## [member WorldMapHorseGallop.volume_db], read off the player's gallop node
## rather than authored as a second number here. With this on, retuning the
## player's horse quieter takes the bandits down with it and a bandit group can
## never come out louder than the horse under the player.
@export var match_player_gallop_volume: bool = true
## Level below which a voice is stopped outright, so a silent group costs no
## voice - the same threshold and the same reason
## [member LoopingSound.silence_threshold] has one.
@export_range(0.0, 0.2) var silence_threshold: float = 0.005

@export_group("Gallop")
## How long a group takes to climb from silence to its full gallop, in seconds.
## Handed to [member GallopRamp.acceleration_duration].
@export var acceleration_duration: float = 1.0
## How long a group takes to fall back to silence once it stops.
@export var deceleration_duration: float = 1.0
## Playback rate for a group moving at its own patrol pace.
@export var normal_gallop_playback_rate: float = 1.0
## Playback rate for a group at a full run - a group in a chase. Deliberately
## gentler than the speed ratio between the two, exactly as the player's horse
## is; see [member WorldMapHorseGallop.sprint_gallop_playback_rate].
@export var sprint_gallop_playback_rate: float = 1.5
## Shapes the climb between the two rates - see
## [member GallopRamp.playback_scaling].
@export_range(0.1, 4.0) var speed_to_playback_scaling: float = 1.0
## How far apart, as a fraction of 1, the riders of one group are pitched from
## each other. Fixed per voice rather than rolled per frame, so the riders stay
## distinct from one another instead of shimmering. Without it five voices of
## one recording in one place are simply that recording five times over, which
## reads as one very loud horse rather than five.
@export_range(0.0, 0.5) var voice_pitch_variation: float = 0.12


## One group currently being heard, and the voices it holds. Built by
## [method _take_riders] and released - not freed - by [method _release], so the
## same [AudioStreamPlayer2D] nodes are handed from group to group as the player
## rides across the map.
class Riders extends RefCounted:
	var bandit: WorldBandit
	var voices: Array[AudioStreamPlayer2D] = []
	var ramp := GallopRamp.new()
	var last_position := Vector2.ZERO
	## True once this group has stopped being one of the nearest: it is no
	## longer steered toward its own speed, only run down toward silence, and
	## its voices go back to the pool once it gets there. What keeps a group
	## leaving earshot from being cut off mid-stride.
	var releasing: bool = false


var _riders: Array[Riders] = []
var _pool: Array[AudioStreamPlayer2D] = []
var _timer: float = 0.0
var _ceiling_db: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_ceiling_db = volume_db


## Everything happens on the physics beat because that is the beat a
## [WorldBandit] moves on - see [method WorldBandit._physics_process]. Measuring
## covered ground against a render frame would read zero on every frame physics
## did not step, and a group's gallop would flutter in and out at whatever rate
## the two happened to disagree by.
func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= maxf(update_interval, 0.0):
		_timer = 0.0
		_resweep()
	_drive(delta)


# --- Picking who is heard ----------------------------------------------------

## Re-picks the nearest [member max_groups] audible groups and hands the voices
## round to match. Groups that were being heard and no longer qualify are
## released rather than cut, and groups that already hold voices keep the exact
## voices they had, so nothing restarts over a sweep.
func _resweep() -> void:
	var player := get_tree().get_first_node_in_group(body_group) as Node2D
	if player == null or stream == null:
		for riders in _riders:
			riders.releasing = true
		return

	_ceiling_db = volume_db
	if match_player_gallop_volume:
		var horse := WorldMapHorseGallop.get_active(self)
		if horse != null:
			_ceiling_db = minf(volume_db, horse.volume_db)

	var wanted := _nearest_audible(player)
	for riders in _riders:
		riders.releasing = not wanted.has(riders.bandit)
		wanted.erase(riders.bandit)
	for node in wanted:
		var riders := _take_riders(node as WorldBandit)
		if riders != null:
			_riders.append(riders)


## The nearest groups worth hearing right now, nearest first and at most
## [member max_groups] of them.
##
## One squared distance per group per sweep and no allocation per group, which
## at this cadence is nothing even on a map of hundreds - so unlike
## [WorldBanditActivationDirector] this has no reason to walk the list in
## chunks.
func _nearest_audible(player: Node2D) -> Array:
	var here := player.global_position
	var reach := hearing_radius * hearing_radius
	var fog: WorldMapFog = WorldMapFog.get_active(self) if silent_while_fogged else null
	var keep := maxi(max_groups, 0)
	var found: Array = []
	var distances: Array[float] = []
	for node: Node in get_tree().get_nodes_in_group(BANDIT_GROUP):
		var bandit := node as WorldBandit
		if bandit == null or bandit.is_defeated():
			continue
		var away := here.distance_squared_to(bandit.global_position)
		if away > reach:
			continue
		if fog != null \
				and fog.get_state(bandit.global_position) != WorldMapFog.VisibilityState.VISIBLE:
			continue
		var at := distances.size()
		while at > 0 and distances[at - 1] > away:
			at -= 1
		found.insert(at, bandit)
		distances.insert(at, away)
		if found.size() > keep:
			found.resize(keep)
			distances.resize(keep)
	return found


# --- Making the noise --------------------------------------------------------

## One step of every group currently holding voices: how fast it is actually
## going, what that sounds like, and where each of its riders is standing.
func _drive(delta: float) -> void:
	for i in range(_riders.size() - 1, -1, -1):
		var riders := _riders[i]
		if not is_instance_valid(riders.bandit):
			riders.releasing = true
		_advance(riders, delta)
		# Only once it has genuinely faded out, never the moment it stopped
		# qualifying - which is what makes a group leaving earshot tail off the
		# way one pulling up does.
		if riders.releasing and riders.ramp.level() <= silence_threshold:
			_release(riders)
			_riders.remove_at(i)


func _advance(riders: Riders, delta: float) -> void:
	var alive := is_instance_valid(riders.bandit)
	var target := 0.0
	if alive and not riders.releasing:
		# Measured, never intended: the ground actually covered since the last
		# physics frame. See the class doc.
		var moved := riders.last_position.distance_to(riders.bandit.global_position)
		target = moved / maxf(delta, 0.0001)
		riders.last_position = riders.bandit.global_position
		riders.ramp.walk_speed = maxf(
			riders.bandit.movement_speed * riders.bandit.roam_speed_multiplier, 1.0)
		riders.ramp.run_speed = maxf(riders.bandit.movement_speed, riders.ramp.walk_speed)

	riders.ramp.acceleration_duration = acceleration_duration
	riders.ramp.deceleration_duration = deceleration_duration
	riders.ramp.normal_playback_rate = normal_gallop_playback_rate
	riders.ramp.sprint_playback_rate = sprint_gallop_playback_rate
	riders.ramp.playback_scaling = speed_to_playback_scaling
	riders.ramp.advance(target, delta)

	var level := riders.ramp.level()
	var pitch := riders.ramp.pitch()
	var ceiling := _voice_ceiling_db(riders.voices.size())
	var places := PackedVector2Array()
	if alive:
		places = riders.bandit.get_visible_bandit_positions(riders.voices.size())

	for v in riders.voices.size():
		var voice := riders.voices[v]
		if v < places.size():
			voice.global_position = places[v]
		if level <= silence_threshold:
			if voice.playing:
				voice.stop()
			continue
		if not voice.playing:
			# Each rider enters the loop at its own point in the recording, so
			# the hooves of one group are never in lockstep with each other.
			voice.play(randf() * maxf(stream.get_length(), 0.0))
		voice.volume_db = ceiling + linear_to_db(level)
		voice.pitch_scale = pitch * _voice_pitch_offset(v)


## The level one voice of a group of [param count] is mixed at, so that all of
## them together land on the ceiling rather than each of them doing so.
##
## Voices of the same recording started at different points in it are
## uncorrelated, so their powers add rather than their amplitudes: [param count]
## of them at amplitude [code]1/sqrt(count)[/code] is one of them at full
## amplitude. That is the whole of "maximum volume should not exceed the
## player's own horse" for a group of any size - five riders are a fuller sound,
## never a louder one.
func _voice_ceiling_db(count: int) -> float:
	if count <= 1:
		return _ceiling_db
	return _ceiling_db + linear_to_db(1.0 / sqrt(float(count)))


## A fixed playback offset for the [param index]th rider of a group, spread
## evenly across [member voice_pitch_variation] either side of 1 - fixed rather
## than rolled per frame so a rider keeps its own voice for as long as it has
## one.
func _voice_pitch_offset(index: int) -> float:
	if voice_pitch_variation <= 0.0 or max_voices_per_group <= 1:
		return 1.0
	var t := float(index) / float(maxi(max_voices_per_group - 1, 1))
	return 1.0 + lerpf(-voice_pitch_variation, voice_pitch_variation, t)


# --- The pool ----------------------------------------------------------------

## Voices for [param bandit], taken from the pool and only built when the pool
## has none left to give - which past the first few groups it always does.
func _take_riders(bandit: WorldBandit) -> Riders:
	if bandit == null:
		return null
	var wanted := mini(bandit.get_visible_bandit_count(), maxi(max_voices_per_group, 1))
	if wanted <= 0:
		return null
	var riders := Riders.new()
	riders.bandit = bandit
	riders.last_position = bandit.global_position
	for i in wanted:
		riders.voices.append(_take_voice())
	return riders


func _take_voice() -> AudioStreamPlayer2D:
	if not _pool.is_empty():
		return _pool.pop_back()
	var voice := AudioStreamPlayer2D.new()
	voice.name = "GallopVoice"
	voice.bus = bus
	voice.stream = stream
	voice.max_distance = hearing_radius
	voice.attenuation = attenuation
	voice.panning_strength = panning_strength
	voice.volume_db = -80.0
	add_child(voice)
	return voice


## Hands a group's voices back, stopped and silent, for the next group to take.
func _release(riders: Riders) -> void:
	for voice in riders.voices:
		if not is_instance_valid(voice):
			continue
		voice.stop()
		voice.volume_db = -80.0
		# Re-read on the way back into the pool rather than only when the voice
		# was built, so retuning any of them in the inspector reaches a voice
		# that already exists.
		voice.stream = stream
		voice.bus = bus
		voice.max_distance = hearing_radius
		voice.attenuation = attenuation
		voice.panning_strength = panning_strength
		_pool.append(voice)
	riders.voices.clear()
	riders.ramp.reset()


# --- What a debug readout asks -----------------------------------------------

## How many groups are being heard right now.
func get_audible_group_count() -> int:
	var heard := 0
	for riders in _riders:
		if not riders.releasing:
			heard += 1
	return heard


## How many [AudioStreamPlayer2D] voices exist at all - the number
## [member max_groups] times [member max_voices_per_group] is the ceiling on.
func get_voice_count() -> int:
	var built := _pool.size()
	for riders in _riders:
		built += riders.voices.size()
	return built
