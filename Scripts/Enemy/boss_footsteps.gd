class_name BossFootsteps
extends Node
## The boss's weight: six recorded footfalls played in order as he walks, each one
## shaking the camera a little.
##
## [b]Two cadences, and they are deliberately separate.[/b] Walking is slow and
## endless - the six steps in order, [member step_interval] apart, then round to the
## first again - and a charge is one urgent run through the same six at
## [member charge_step_interval]. The charge sequence takes the floor while it plays
## and the walking cadence is held and restarted behind it, so the two can never
## interleave into a single muddled rhythm. Which is which is one flag, not two
## systems: they share the list, the voices and the shake.
##
## [b]It is the game's own audio, not a new one.[/b] The recordings are an
## [code]@export[/code] array played through a [SoundBank] of this node's own, which is
## where the pooling, the level and the per-playback pitch spread already live - so two
## steps overlapping layer instead of cutting each other off, and no two footfalls are
## ever pitched identically. Adding a seventh recording is dropping it into the array.
##
## [b]And it is the camera's own feedback.[/b] Each step asks [CameraController] for a
## shake on the same channel every other impulse in the game uses, so a footfall during
## a hit reaction is felt underneath it rather than fighting it. Nothing here touches
## the camera directly.
##
## Nothing about the boss is written here at all: this node only watches. Take it out
## of the world and the boss walks in silence.

## Emitted for each footfall, with its place in the list and whether it belonged to a
## charge. For a test, and for anything that wants to land on the beat.
signal stepped(index: int, charging: bool)
## Emitted as a charge's run through the six begins.
signal charge_sequence_started
## Emitted as it ends and the walking cadence is handed back.
signal charge_sequence_finished

## Group this node joins, so a test can find it without a path.
const GROUP := &"boss_footsteps"

## The boss system whose fight this follows. Its
## [signal MiniBossDirector.fight_started] is what starts the walking cadence.
@export var director_path: NodePath = ^"../MiniBossDirector"
## The charge, whose run is what triggers the fast sequence. Left unresolved the boss
## still walks; he simply never breaks into the quick six.
@export var charge_path: NodePath = ^"../BossCharge"
## The voices the steps are played through. Its own child, so the boss's footfalls
## have their own small pool and nothing else in the mix can starve them.
@export var sound_bank_path: NodePath = ^"SoundBank"
## Whether the boss makes any noise walking at all.
@export var enabled: bool = true

@export_group("The recordings")
## The footfalls, [b]in the order they are played[/b] - Step1 through Step6. Both
## cadences read this one list from the top and walk down it, so a seventh recording
## dropped in here lengthens both without a number being changed anywhere.
@export var steps: Array[AudioStream] = []
## Level they are played at against the rest of the bank, in decibels.
@export var step_volume_db: float = 0.0

@export_group("Walking")
## Seconds between footfalls while the boss is simply walking.
@export var step_interval: float = 1.2
## How fast the boss has to actually be moving before he is considered to be walking,
## in pixels per second. A boss held still by an introduction, planted in a charge's
## wind-up or backed into a wall makes no noise, because he is not taking any steps.
@export var move_threshold: float = 8.0
## Whether the walking cadence loops back to the first recording once it reaches the
## end of the list. Off leaves the boss silent after six steps, which is only useful
## for looking at the sequence once.
@export var loops: bool = true

@export_group("Charging")
## Seconds between footfalls during a charge - the same six, run through once, faster.
@export var charge_step_interval: float = 0.5
## Whether the fast sequence starts as the boss begins running at the marked spot. Off
## plays it after the charge's swing has landed instead, for a charge whose weight
## should be felt on the way out rather than on the way in.
@export var starts_on_run: bool = true
## Whether the walking cadence is silenced while the fast sequence plays. On, which is
## what keeps the two rhythms from overlapping into one.
@export var charge_takes_the_floor: bool = true

@export_group("Camera")
## How hard the camera is shaken by an ordinary footfall, in pixels. Small - this is
## weight, not an impact.
@export var step_shake: float = 2.4
## How long that shake lasts, in seconds.
@export var step_shake_time: float = 0.12
## How hard a charging footfall shakes it. Heavier, because he is running.
@export var charge_step_shake: float = 4.2
## How long that one lasts.
@export var charge_step_shake_time: float = 0.14
## Whether the camera is shaken at all.
@export var shakes_camera: bool = true

var _director: MiniBossDirector
var _charge: BossCharge
var _sounds: SoundBank
var _boss: Node2D
var _boss_health: Health
var _running: bool = false
## Where the walking cadence has got to in [member steps].
var _walk_index: int = 0
var _walk_timer: float = 0.0
## Where a charge's run through the list has got to, and how many of it are left. -1
## when no charge sequence is playing.
var _charge_index: int = -1
var _charge_timer: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_process(false)
	_sounds = get_node_or_null(sound_bank_path) as SoundBank

	var director := _resolve_director()
	if director != null and not director.fight_started.is_connected(_on_fight_started):
		director.fight_started.connect(_on_fight_started)

	var charge := _resolve_charge()
	if charge == null:
		return
	if not charge.charge_run_started.is_connected(_on_charge_run_started):
		charge.charge_run_started.connect(_on_charge_run_started)
	if not charge.charge_finished.is_connected(_on_charge_finished):
		charge.charge_finished.connect(_on_charge_finished)


## The footstep system in this world, or null when it has none.
static func get_active(from_node: Node) -> BossFootsteps:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BossFootsteps


func is_running() -> bool:
	return _running


## Whether a charge's fast run through the six is currently playing.
func is_charge_sequence_playing() -> bool:
	return _charge_index >= 0


## Which recording the walking cadence will play next.
func get_walk_index() -> int:
	return _walk_index


## Starts a charge's fast sequence now, whatever the charge is doing. It is the same
## sequence a charge triggers, so this is what a smoke check presses.
func play_charge_sequence() -> void:
	if steps.is_empty():
		return
	_charge_index = 0
	_charge_timer = 0.0
	if charge_takes_the_floor:
		_walk_timer = maxf(step_interval, 0.05)
	charge_sequence_started.emit()


## Stops it early and hands the floor back to the walking cadence.
func stop_charge_sequence() -> void:
	if _charge_index < 0:
		return
	_charge_index = -1
	_charge_timer = 0.0
	charge_sequence_finished.emit()


## Stops listening. What has already been played is left alone.
func stop() -> void:
	if not _running:
		return
	stop_charge_sequence()
	_running = false
	set_process(false)


## Forgets the fight, so a second one can be set up behind it.
func reset() -> void:
	stop()
	_boss = null
	_boss_health = null
	_walk_index = 0
	_walk_timer = 0.0


# --- The cadences ----------------------------------------------------------------


func _on_fight_started() -> void:
	if _running or not enabled:
		return

	var director := _resolve_director()
	if director == null:
		return

	_boss = director.get_boss()
	if _boss == null or not is_instance_valid(_boss):
		return

	# A dead boss is frozen where he fell with whatever velocity he had, so without this
	# the cadence would keep walking a man who is lying on the ground.
	_boss_health = _find_health(_boss)
	if _boss_health != null and not _boss_health.died.is_connected(stop):
		_boss_health.died.connect(stop, CONNECT_ONE_SHOT)

	_walk_index = 0
	# The first footfall is one interval away rather than immediate, so the fight does
	# not open on a boot coming down at the same instant the card comes up.
	_walk_timer = maxf(step_interval, 0.05)
	_running = true
	set_process(true)


func _on_charge_run_started(_point: Vector2) -> void:
	if _running and starts_on_run:
		play_charge_sequence()


func _on_charge_finished() -> void:
	if _running and not starts_on_run:
		play_charge_sequence()


## Both cadences run on the world's own clock, so a boss walking through a slowed
## finish is heard at the speed of the scene around him.
func _process(delta: float) -> void:
	if not _running:
		return
	if _boss == null or not is_instance_valid(_boss):
		stop()
		return

	var step_delta := delta * WorldSlowdown.get_multiplier(self)

	if _charge_index >= 0:
		_advance_charge(step_delta)
		if charge_takes_the_floor:
			return

	_advance_walk(step_delta)


## One run through the list, once, and then the floor is handed back.
func _advance_charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer > 0.0:
		return

	_play_step(_charge_index, true)
	_charge_index += 1
	_charge_timer = maxf(charge_step_interval, 0.02)

	if _charge_index >= steps.size():
		_charge_index = -1
		_charge_timer = 0.0
		# The walking cadence resumes a full interval later, so his first ordinary step
		# after a charge is not stacked on the last of the fast ones.
		_walk_timer = maxf(step_interval, 0.05)
		charge_sequence_finished.emit()


## The endless one: only while he is actually moving, and only ever one recording on
## from the last.
func _advance_walk(delta: float) -> void:
	if not _is_walking():
		return

	_walk_timer -= delta
	if _walk_timer > 0.0:
		return

	if _walk_index >= steps.size():
		if not loops:
			return
		_walk_index = 0

	_play_step(_walk_index, false)
	_walk_index += 1
	if loops and _walk_index >= steps.size():
		_walk_index = 0
	_walk_timer = maxf(step_interval, 0.05)


## Whether the boss is putting one foot in front of the other. A boss standing still -
## held by an introduction, planted in a charge's wind-up, or pressed against a wall -
## is taking no steps and so makes no noise.
func _is_walking() -> bool:
	if _boss.has_method(&"is_passive") and _boss.call(&"is_passive"):
		return false
	var speed := 0.0
	if _boss is CharacterBody2D:
		speed = (_boss as CharacterBody2D).velocity.length()
	return speed >= maxf(move_threshold, 0.0)


## One footfall: the recording, and the ground moving under it.
func _play_step(index: int, charging: bool) -> void:
	if index < 0 or index >= steps.size():
		return

	var stream := steps[index]
	if _sounds != null and stream != null:
		# Through the bank rather than a player of its own, so the pitch spread, the
		# pooling and the bus are the ones every other sound in the game uses.
		_sounds.play_stream(stream, step_volume_db)

	_shake(charging)
	stepped.emit(index, charging)


func _shake(charging: bool) -> void:
	if not shakes_camera:
		return
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	if charging:
		camera.shake(maxf(charge_step_shake, 0.0), maxf(charge_step_shake_time, 0.0))
		return
	camera.shake(maxf(step_shake, 0.0), maxf(step_shake_time, 0.0))


func _resolve_director() -> MiniBossDirector:
	if _director != null and is_instance_valid(_director):
		return _director
	_director = get_node_or_null(director_path) as MiniBossDirector
	if _director == null:
		_director = MiniBossDirector.get_active(self)
	return _director


func _resolve_charge() -> BossCharge:
	if _charge != null and is_instance_valid(_charge):
		return _charge
	_charge = get_node_or_null(charge_path) as BossCharge
	if _charge == null:
		_charge = BossCharge.get_active(self)
	return _charge


func _find_health(enemy: Node) -> Health:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null
