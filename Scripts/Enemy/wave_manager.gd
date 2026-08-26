class_name WaveManager
extends Node
## Drives a timed run of enemy waves through an [EnemySpawner].
##
## Waves are derived from the wave number rather than authored one by one:
## wave N asks for `base_enemy_count * multiplier^(N-1)` enemies, so the run
## keeps escalating for as long as it lasts.
##
## A wave is finished once its enemies have all been *spawned*, not once they
## have been killed - the next wave is queued a fixed gap later, so enemies from
## earlier waves are still alive when the next one arrives.
##
## When [member run_duration] runs out the manager simply stops spawning and
## emits [signal run_finished]. Nothing already in the world is touched: the
## enemies still in the arena keep chasing, the player keeps playing, and the run
## carries on into the blood-collection phase. Ending the run is the player's
## call, through the pause menu.

signal run_started
## Emitted as a wave begins spawning, before its first enemy appears.
signal wave_started(wave_number: int, enemy_count: int)
## Emitted once a wave has finished placing all of its enemies.
signal wave_spawn_completed(wave_number: int)
signal run_finished

enum State { IDLE, SPAWNING, BETWEEN_WAVES, FINISHED }

## Spawner the waves are pushed through.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## Begins the run as soon as the scene starts.
@export var auto_start: bool = true

@export_group("Run")
## Length of the whole run in seconds. Spawning stops when it elapses.
@export var run_duration: float = 60.0
## Enemies in wave 1. Every wave is this number scaled by the multiplier, so
## halving it halves every wave in the run, not just the first.
@export var base_enemy_count: int = 2
## Each wave asks for this much more than the one before it.
@export var enemy_count_multiplier: float = 1.08
## Quiet gap after a wave has finished spawning, before the next one starts.
@export var time_between_waves: float = 3.5
## Gap between the individual enemies of one wave, so a wave streams in instead
## of appearing in a single frame. 0 spawns the whole wave at once.
@export var spawn_interval: float = 0.18
## Most enemies allowed to be alive at once. [b]0 - the default - is no limit at
## all[/b], which is what an arena round has always run with: a minute is short
## enough that the waves cannot outrun the player.
##
## It exists for a fight with no clock on it. The travel map spawns for as long as
## the player takes to cross it, and without a ceiling a slow crossing would end
## with an unplayable crowd - so the road states how many it will have on the
## field at once and the waves queue behind it. A wave held back this way is not
## lost: it simply waits, and resumes the frame there is room, so the pressure is
## constant rather than the total being thrown away.
@export var max_active_enemies: int = 0
## Group the living enemies are counted in when there is a ceiling to enforce.
@export var enemy_group: StringName = &"enemies"
## Group the player's own [Health] is found by, so a round can be stopped if they are
## killed in it - see [method _on_player_died]. The world's own group, the same one
## every other system follows the player's death through.
@export var health_group: StringName = &"player_health"

@export_group("Rounds")
## The difficulty curve. How much larger a round's waves are than the round
## before it is [member RoundScaling.spawn_growth] - one number, in one place,
## alongside the health and damage growth it belongs with - so this manager owns
## the shape of a *run* and that component owns the shape of the *campaign*.
##
## Left unresolved every round is the first one, so a world opened on its own
## still plays.
@export var round_scaling_path: NodePath = ^"../RoundScaling"
## What each wave is [i]made of[/i] - see [WaveRoster]. It is asked once, as a wave
## begins, for one body per enemy the count above already decided on, so the
## composition and the size of a wave are tuned in two separate places and neither
## can change the other.
##
## Left unresolved every enemy is the spawner's own, which is the wave this manager
## has always spawned.
@export var roster_path: NodePath = ^"WaveRoster"

@onready var _spawner: EnemySpawner = get_node_or_null(spawner_path) as EnemySpawner
@onready var _scaling: RoundScaling = get_node_or_null(round_scaling_path) as RoundScaling
@onready var _roster: WaveRoster = get_node_or_null(roster_path) as WaveRoster

var _state: State = State.IDLE
var _elapsed: float = 0.0
var _timer: float = 0.0
var _wave: int = 0
var _remaining: int = 0
## One body per enemy of the wave being spawned, decided in full the moment the
## wave began. Rolling the mix once per wave rather than once per enemy is what
## lets a roster promise "five or six together" and actually deliver it.
var _plan: Array[PackedScene] = []
## The player's pool while a round is running, so the waves can be stopped if they are
## killed in it. Held rather than looked up each time, for the same reason every other
## system that follows this holds it: the connection has to be droppable again.
var _player_health: Health


func _ready() -> void:
	if auto_start:
		start()


## Nothing is left spawning behind us.
func _exit_tree() -> void:
	_drop_player_death()


## Enemies wave [param wave_number] asks for. Wave 1 is [member base_enemy_count]
## and every wave after it is scaled by [member enemy_count_multiplier], with the
## whole curve lifted again by whichever round the player is on.
##
## The fractions are kept rather than thrown away. A wave worth 2.4 enemies is not
## rounded to 2 on its own - the count is the difference between the running
## totals either side of it, so three such waves deliver 2, 3 and 2 and the run
## ends up with the 7 the curve actually asked for. Rounding each wave in
## isolation would quietly lose most of a small round's growth.
func get_wave_enemy_count(wave_number: int) -> int:
	var wave := maxi(wave_number, 1)
	var count := int(round(_cumulative_raw(wave))) - int(round(_cumulative_raw(wave - 1)))
	return maxi(count, 1)


## Which round this run belongs to. 1 when there is no scaling to ask.
func get_round() -> int:
	return 1 if _scaling == null else _scaling.get_round()


## Rounds of growth already banked - 0 on the first round.
func get_rounds_elapsed() -> int:
	return 0 if _scaling == null else _scaling.get_rounds_elapsed()


## How many enemies waves 1..[param wave] are worth in total, unrounded. The
## per-wave geometric series summed in closed form, so this costs the same at
## wave 1 and wave 500.
func _cumulative_raw(wave: int) -> float:
	if wave <= 0:
		return 0.0

	var per_round := 1.0 if _scaling == null else _scaling.get_spawn_multiplier()
	var first := float(base_enemy_count) * per_round
	var ratio := enemy_count_multiplier

	if is_equal_approx(ratio, 1.0):
		return first * float(wave)
	return first * (pow(ratio, float(wave)) - 1.0) / (ratio - 1.0)


func get_wave() -> int:
	return _wave


func get_time_left() -> float:
	return maxf(run_duration - _elapsed, 0.0)


func is_running() -> bool:
	return _state == State.SPAWNING or _state == State.BETWEEN_WAVES


## True once the clock has run out and spawning has stopped. The run itself is
## still live - the enemies already in the arena keep going and the player is
## free to collect - so this marks the blood-collection phase, not the end.
func is_collection_phase() -> bool:
	return _state == State.FINISHED


## Starts the run from wave 1. The first wave begins on the next frame, so every
## other node has finished its own `_ready()` before anything spawns.
func start() -> void:
	if is_running():
		return

	_elapsed = 0.0
	_timer = 0.0
	_wave = 0
	_remaining = 0
	_state = State.BETWEEN_WAVES
	_follow_player_death()
	run_started.emit()


## Stops spawning and leaves everything already in the world alone.
func stop() -> void:
	if _state == State.FINISHED:
		return

	_remaining = 0
	_state = State.FINISHED
	_drop_player_death()
	run_finished.emit()


## [b]A death ends the round.[/b] Dying is the player's own death sequence and it
## carries them home to the base, several thousand pixels from the arena - so a clock
## still counting down and a spawner still placing waves would go on filling a
## rectangle nobody is standing in, and the player would be put back on their feet at
## home with a round still running behind them.
##
## It is the ordinary [method stop], not a second ending: what is already standing is
## sent home by whatever is listening for [signal run_finished] - [RunEndDefeat] - so
## the arena empties exactly the way it does when the clock runs out, and nothing about
## how a round is wound up exists in two places.
func _on_player_died() -> void:
	stop()


func _follow_player_death() -> void:
	_drop_player_death()
	_player_health = get_tree().get_first_node_in_group(health_group) as Health
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their death -
## they are revived into the same [Health] - so a connection left behind would still be
## listening at the round after next.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


func _process(delta: float) -> void:
	if not is_running():
		return

	# Checked before anything spawns, so the run cannot overshoot its duration
	# by a wave - a wave part way through simply stops where it is.
	_elapsed += delta
	if _elapsed >= run_duration:
		stop()
		return

	_timer -= delta

	match _state:
		State.SPAWNING:
			_advance_spawning()
		State.BETWEEN_WAVES:
			if _timer <= 0.0:
				_begin_wave()
		_:
			pass


func _begin_wave() -> void:
	_wave += 1
	_remaining = get_wave_enemy_count(_wave)
	# The count is settled first and handed over, so the roster can only decide what
	# the wave is made of and never how large it is.
	_plan = [] if _roster == null else _roster.build_wave(_wave, _remaining)
	_timer = 0.0
	_state = State.SPAWNING
	# Spacing is measured within a wave, so each one starts from a clean slate.
	if _spawner != null:
		_spawner.begin_batch()
	wave_started.emit(_wave, _remaining)
	_advance_spawning()


## Whether the field is as full as this run allows. Always false when there is no
## ceiling, which is the arena and is why the count is never taken there.
func is_at_enemy_cap() -> bool:
	if max_active_enemies <= 0:
		return false
	return get_tree().get_nodes_in_group(enemy_group).size() >= max_active_enemies


## Releases every enemy whose turn has come this frame, then hands over to the
## gap once the wave is empty.
##
## A wave that runs into the ceiling stops where it is and is picked up again on a
## later frame, with what is left of it still owed - so a capped run delivers the
## same enemies, more slowly, rather than quietly dropping them.
func _advance_spawning() -> void:
	while _remaining > 0 and _timer <= 0.0:
		if is_at_enemy_cap():
			return
		if _spawner != null:
			_spawner.spawn(_planned_scene())
		_remaining -= 1
		if spawn_interval > 0.0:
			_timer += spawn_interval

	if _remaining > 0:
		return

	wave_spawn_completed.emit(_wave)
	_state = State.BETWEEN_WAVES
	_timer = time_between_waves


## The body the next enemy of this wave is built from, or null for the spawner's
## own. Read off the plan by how much of the wave is left, so a wave held back by
## the enemy ceiling picks up exactly where it stopped rather than losing its mix.
func _planned_scene() -> PackedScene:
	var index := _plan.size() - _remaining
	if index < 0 or index >= _plan.size():
		return null
	return _plan[index]
