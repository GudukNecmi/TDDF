class_name BossCharge
extends Node
## The boss's charge: he plants his feet, marks where the player is standing, and
## two seconds later runs at that spot and swings at it.
##
## [b]It is the boss's own movement and the boss's own knife.[/b] There is no second
## combat framework here and no charge state machine on the enemy - the run is
## [method Enemy.begin_charge], which is the same walk with a different point to walk
## at, and the swing is the enemy's own [KnifeSlash] asked to run its arc faster for
## one attack. Take this node out of the world and the boss fights exactly as he did
## before it existed.
##
## [b]The spot is recorded once, at the start.[/b] That is the whole idea of the
## attack: the player is told where it is going to land and given two seconds to not
## be standing there. A charge that re-aimed itself while it ran would be a homing
## attack with a wind-up on it, which is a different and much worse thing.
##
## The four steps, and how long each lasts:
##
##   [codeblock]
##   waiting   charge_cooldown       - nothing, the timer running down
##   wind-up   charge_duration       - planted, the spot already chosen
##   run       until he reaches it   - the walk, pointed at the spot
##   swing     one fast arc          - KnifeSlash, thrown at the spot
##   [/codeblock]
##
## [b]It never writes the boss's speed.[/b] [BossPhases] owns that number and sets it
## absolutely per band, so a charge that multiplied it would be overwritten by the
## next band and would compound with the one before it. The run's speed is handed to
## the movement per-charge instead - see [member run_speed_multiplier] - and comes off
## again the moment the charge ends, so the two systems never touch the same value.

## Emitted as the boss plants his feet, with the spot he has just marked.
signal charge_started(point: Vector2)
## Emitted as the wind-up ends and he actually starts running, with the same spot.
## [BossFootsteps] hangs its fast sequence off this.
signal charge_run_started(point: Vector2)
## Emitted on the frame the swing is thrown, with the spot it was thrown at.
signal charge_struck(point: Vector2)
## Emitted once the whole thing is over and the cooldown has been rearmed.
signal charge_finished

## Group this node joins, so a test or the developer panel can find it without a path.
const GROUP := &"boss_charge"

## Where the attack has got to. One flag's worth of state per step, entered in order,
## exactly as [MiniBossDirector] does its own.
enum Step {
	## Not charging. The cooldown is running down.
	WAITING,
	## Feet planted, the spot chosen, nothing moving yet.
	WINDUP,
	## Running at the spot.
	RUN,
	## The arc is in the air.
	SWING,
}

## The boss system whose fight this follows. Its
## [signal MiniBossDirector.fight_started] is the only thing that starts this node, so
## nothing here can run in a round that has no boss in it.
@export var director_path: NodePath = ^"../MiniBossDirector"
## Group the player is found in, so this node is not wired to them. The spot is read
## off whoever is in it at the moment the charge begins.
@export var player_group: StringName = &"player"
## Whether the boss charges at all. Off leaves him fighting exactly as he did before
## this node existed, for a fight to be looked at without it.
@export var enabled: bool = true

@export_group("Timing")
## Seconds between charges. Counted from the end of one to the earliest start of the
## next, so a charge that took a long time to run does not immediately owe another.
@export var charge_cooldown: float = 10.0
## How long the boss stands with his feet planted before he runs, in seconds.
## [b]This is the warning[/b] - the spot is already chosen when it starts.
@export var charge_duration: float = 2.0
## Seconds after the fight starts before the first charge may be thrown. A fight that
## opened with one would land it before the player had finished reading the name on
## the card.
@export var first_charge_delay: float = 6.0
## How long the run is given before it is called off, in seconds. A safety net for a
## boss shouldered into a wall on his way across, not a limit the attack is expected
## to reach.
@export var run_timeout: float = 4.0

@export_group("The run")
## What the boss's walk is multiplied by while he is running at the spot. It is handed
## to the movement for the length of the charge and taken off again afterwards, so it
## never touches the speed [BossPhases] owns.
@export var run_speed_multiplier: float = 2.6
## What it is multiplied by during the wind-up. 0 plants him where he stands, which is
## what makes the wind-up readable as one.
@export var windup_speed_multiplier: float = 0.0
## How close to the marked spot counts as having arrived, in pixels. The swing is
## thrown from here rather than from on top of the spot, so the blade travels through
## it instead of stopping in it.
@export var strike_distance: float = 70.0

@export_group("The swing")
## What the blade's own wind-up, strike and recovery times are divided by for the
## charge's arc. Above 1 is faster; 3 is the "very fast" the attack is described with.
## The times themselves are [KnifeSlash]'s and are put back untouched afterwards, so
## an ordinary swing is never affected.
@export var swing_speed_multiplier: float = 3.0
## The blade, relative to the boss.
@export var knife_slash_path: NodePath = ^"KnifeAim/KnifeSlash"
## The pivot that aims it, relative to the boss. It is pointed at the marked spot for
## the length of the charge's arc and handed its ordinary target back afterwards,
## which is the whole of "swings toward that position".
@export var aim_pivot_path: NodePath = ^"KnifeAim"

var _director: MiniBossDirector
var _boss: Node2D
var _boss_health: Health
var _step: Step = Step.WAITING
var _timer: float = 0.0
var _point: Vector2 = Vector2.ZERO
var _running: bool = false
## The thing the blade is aimed at while the charge's arc is in the air. Made once and
## reused, because a marker built per swing would be one more thing to leak.
var _aim_mark: Node2D
## What the pivot was aiming at before the charge borrowed it.
var _aim_rest: Node2D
## The blade's authored timings, taken once so the fast arc can be put back however
## often it is thrown.
var _swing_rest: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_process(false)
	var director := _resolve_director()
	if director != null and not director.fight_started.is_connected(_on_fight_started):
		director.fight_started.connect(_on_fight_started)


## The charge system in this world, or null when it has none.
static func get_active(from_node: Node) -> BossCharge:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BossCharge


## Whether a fight is being watched.
func is_running() -> bool:
	return _running


## Which step the attack is on.
func get_step() -> Step:
	return _step


## Whether the boss is mid-charge - planted, running or swinging.
func is_charging() -> bool:
	return _step != Step.WAITING


## The spot this charge was aimed at. Meaningless while nothing is being charged.
func get_charge_point() -> Vector2:
	return _point


## Seconds until the next charge may begin, or 0 while one is already under way.
func get_cooldown_left() -> float:
	return _timer if _step == Step.WAITING else 0.0


## The boss being watched, or null before a fight starts.
func get_boss() -> Node2D:
	return _boss if _has_boss() else null


## Throws a charge now, whatever the cooldown says, and reports whether there was a
## boss to throw it with.
##
## [b]It is the real attack, started by hand.[/b] Every step it goes through is the
## one a timed charge goes through, so what this exercises is the attack rather than a
## copy of it. Nothing in play calls it; it is what a smoke check and the developer
## panel press.
func charge_now() -> bool:
	if not _has_boss() or not _boss_can_charge():
		return false
	_begin_windup()
	return true


## Puts everything the charge borrowed back and leaves the boss walking normally. Safe
## at any step, including one that was never started.
func cancel() -> void:
	_release_aim()
	_restore_swing_times()
	if _has_boss() and _boss.has_method(&"end_charge"):
		_boss.call(&"end_charge")
	if _step != Step.WAITING:
		_step = Step.WAITING
		_timer = maxf(charge_cooldown, 0.0)
		charge_finished.emit()


## Stops watching the fight. What is already in the air is called off first, so a boss
## cannot be left running at a spot with nothing to end the run.
func stop() -> void:
	if not _running:
		return
	cancel()
	_running = false
	set_process(false)


## Forgets the fight entirely, so a second one can be set up behind it.
func reset() -> void:
	stop()
	_boss = null
	_boss_health = null
	_step = Step.WAITING
	_timer = 0.0


# --- The fight -----------------------------------------------------------------


func _on_fight_started() -> void:
	if _running or not enabled:
		return

	var director := _resolve_director()
	if director == null:
		return

	_boss = director.get_boss()
	if not _has_boss():
		return

	_boss_health = _find_health(_boss)
	# The attack goes down with the man. A dead boss is frozen where he fell rather than
	# freed, so without this a charge that was in the air when he was shot would have
	# nothing left to end it.
	if _boss_health != null and not _boss_health.died.is_connected(stop):
		_boss_health.died.connect(stop, CONNECT_ONE_SHOT)

	_step = Step.WAITING
	_timer = maxf(first_charge_delay, 0.0)
	_running = true
	set_process(true)


## The clock every step is measured on is the world's own, so a charge thrown into a
## slowed finish winds up and lands at the speed of the scene around it rather than
## running to its own beat.
func _process(delta: float) -> void:
	if not _running:
		return
	if not _has_boss():
		stop()
		return

	var step_delta := delta * WorldSlowdown.get_multiplier(self)

	match _step:
		Step.WAITING:
			_advance_cooldown(step_delta)
		Step.WINDUP:
			_advance_windup(step_delta)
		Step.RUN:
			_advance_run(step_delta)
		Step.SWING:
			_advance_swing(step_delta)


func _advance_cooldown(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if not _boss_can_charge():
		# Held rather than thrown away: a boss standing by, or on his way down, owes the
		# charge as soon as he is fighting again.
		return
	_begin_windup()


## Feet planted, and the spot chosen on this frame and never again.
func _begin_windup() -> void:
	_point = _player_position()
	_step = Step.WINDUP
	_timer = maxf(charge_duration, 0.0)
	_drive(windup_speed_multiplier)
	charge_started.emit(_point)


func _advance_windup(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	_step = Step.RUN
	_timer = maxf(run_timeout, 0.05)
	_drive(run_speed_multiplier)
	charge_run_started.emit(_point)


func _advance_run(delta: float) -> void:
	_timer -= delta
	var reached := _boss.global_position.distance_to(_point) <= maxf(strike_distance, 1.0)
	if not reached and _timer > 0.0:
		return
	_begin_swing()


## The arc: the blade aimed at the marked spot, run at several times its authored
## speed, and thrown once.
func _begin_swing() -> void:
	_step = Step.SWING
	var slash := _resolve_slash()
	var arc := 0.0

	if slash != null:
		_take_aim()
		_shorten_swing_times(slash)
		arc = slash.windup_time + slash.strike_time + slash.recover_time
		slash.slash()

	# Held for the whole arc, so the blade is home before its timings and its target are
	# handed back and the recovery is never cut off mid-swing.
	_timer = maxf(arc, 0.05)
	charge_struck.emit(_point)


func _advance_swing(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	_release_aim()
	_restore_swing_times()
	if _boss.has_method(&"end_charge"):
		_boss.call(&"end_charge")

	_step = Step.WAITING
	_timer = maxf(charge_cooldown, 0.0)
	charge_finished.emit()


## Hands the boss a spot to walk at, at [param multiplier] times his own speed. The
## speed itself is never written - see the class notes.
func _drive(multiplier: float) -> void:
	if _has_boss() and _boss.has_method(&"begin_charge"):
		_boss.call(&"begin_charge", _point, maxf(multiplier, 0.0))


# --- What the charge borrows ---------------------------------------------------


## Points the blade's pivot at the marked spot for the length of the arc.
##
## [b]It is the pivot's ordinary target, swapped.[/b] [LookAtTarget] already takes any
## [Node2D] and [KnifeSlash] already aims at whatever the pivot is holding, so a mark
## standing on the spot is all it takes to swing at a place rather than at a person -
## and the head is deliberately left alone, so the boss still looks at the player while
## his knife goes through the ground he charged.
func _take_aim() -> void:
	var pivot := _resolve_pivot()
	if pivot == null:
		return

	if _aim_mark == null or not is_instance_valid(_aim_mark):
		_aim_mark = Node2D.new()
		_aim_mark.name = "ChargeMark"
		add_child(_aim_mark)

	_aim_mark.global_position = _point
	_aim_rest = pivot.target
	pivot.target = _aim_mark


func _release_aim() -> void:
	var pivot := _resolve_pivot()
	if pivot != null and pivot.target == _aim_mark:
		pivot.target = _aim_rest
	_aim_rest = null


## Divides the blade's three timings for one arc, remembering what they were.
func _shorten_swing_times(slash: KnifeSlash) -> void:
	if _swing_rest.is_empty():
		_swing_rest = {
			"windup": slash.windup_time,
			"strike": slash.strike_time,
			"recover": slash.recover_time,
		}

	var faster := maxf(swing_speed_multiplier, 0.01)
	slash.windup_time = float(_swing_rest["windup"]) / faster
	slash.strike_time = float(_swing_rest["strike"]) / faster
	slash.recover_time = float(_swing_rest["recover"]) / faster


func _restore_swing_times() -> void:
	if _swing_rest.is_empty():
		return
	var slash := _resolve_slash()
	if slash != null:
		slash.windup_time = float(_swing_rest["windup"])
		slash.strike_time = float(_swing_rest["strike"])
		slash.recover_time = float(_swing_rest["recover"])
	_swing_rest.clear()


# --- Who and where -------------------------------------------------------------


func _has_boss() -> bool:
	return _boss != null and is_instance_valid(_boss)


## Whether the boss is in a state to be thrown at anybody: alive, fighting, and
## neither standing by for an introduction nor running for the edge of the map.
func _boss_can_charge() -> bool:
	if not _has_boss():
		return false
	if _boss_health != null and is_instance_valid(_boss_health) and not _boss_health.is_alive():
		return false
	if _boss.has_method(&"is_passive") and _boss.call(&"is_passive"):
		return false
	if _boss.has_method(&"is_fleeing") and _boss.call(&"is_fleeing"):
		return false
	return _resolve_player() != null


func _player_position() -> Vector2:
	var player := _resolve_player()
	if player != null:
		return player.global_position
	return _boss.global_position if _has_boss() else Vector2.ZERO


func _resolve_player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(player_group) as Node2D


func _resolve_director() -> MiniBossDirector:
	if _director != null and is_instance_valid(_director):
		return _director
	_director = get_node_or_null(director_path) as MiniBossDirector
	if _director == null:
		_director = MiniBossDirector.get_active(self)
	return _director


func _resolve_slash() -> KnifeSlash:
	if not _has_boss():
		return null
	return _boss.get_node_or_null(knife_slash_path) as KnifeSlash


func _resolve_pivot() -> LookAtTarget:
	if not _has_boss():
		return null
	return _boss.get_node_or_null(aim_pivot_path) as LookAtTarget


func _find_health(enemy: Node) -> Health:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null
