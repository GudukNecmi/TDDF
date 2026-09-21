class_name RunMapTravel
extends Node
## Riding one road: the piece steps along it while the world clock steps through
## the day cycles the road costs.
##
## [b]A ride is a small number of visible beats, not a glide.[/b] One beat is one
## day cycle: the clock sweeps exactly one period - 60° of the authored six -
## while the piece covers exactly one equal share of the road, and then both sit
## still for a moment before the next. A one-day road is one beat, a three-day
## road is three identical ones, so how far the player has come and how much of
## the day they have spent are the same picture and cannot disagree.
##
## [b]The moving half and the still half are separate numbers on purpose.[/b]
## [member step_duration] is how fast a tick is ridden and
## [member step_hold] is how long the world is left standing at the hour it just
## reached, so the ride can be sped up without the beats running into each other -
## which is exactly what halving the step alone does. The ride is quick and the
## pause at the end of it is a whole second, which is what makes each hour
## arrived at register as its own moment. Neither changes how many
## ticks a road costs: that is the road, measured once by
## [method RunMapGenerator.day_cycles_for].
##
## [b]The clock is swept, not jumped.[/b] The degrees are handed to
## [method WorldTimeManager.advance_degrees] a frame at a time across the moving
## part of the beat, so the dial's hand can be watched turning through its 60°;
## what makes each beat land exactly on a period boundary is that the beat's size
## is asked of [method WorldTimeManager.degrees_until_next_period] before it
## starts and the last frame of the sweep spends whatever is left rather than
## another slice. That exactness is what the day-stage lighting depends on - see
## [member WorldTimeManager.advances_in_real_time].
##
## [b]It drives the map; it does not own it.[/b] The piece is moved by asking
## [method RunMapView.place_token_on], and what happens on arrival - a node's own
## event, once there are any - belongs to [RunMapDirector], which is what listens
## for [signal travel_finished].

## Emitted as the ride begins, before the first beat.
signal travel_started(link: RunMapLink, from_id: int, to_id: int)
## Emitted at the end of each beat, with how many of the road's day cycles have
## now been spent and how many it costs in total. For a readout counting them
## off; nothing is required to listen.
signal day_cycle_spent(spent: int, total: int)
## Emitted once the piece has arrived and the last beat's stillness is over.
signal travel_finished(site_id: int)

## Where the world clock is asked.
@export var world_clock_path: NodePath = ^"/root/WorldClock"

@export_group("Pacing")
## How long the moving part of one beat takes, in seconds - the piece sliding
## its share of the road and the clock sweeping its 60° together.
@export var step_duration: float = 0.36
## How long the piece and the clock stand still at the end of each beat, in
## seconds. What makes the beats read as separate steps rather than as one
## continuous slide, and it is a whole second: the pause is the beat, so it is
## held at its own authored length whatever the ride itself is sped up to.
@export var step_hold: float = 1.0
## How long the map waits after the final beat before the arrival is announced.
@export var arrival_hold: float = 0.35

enum Phase { IDLE, STEPPING, HOLDING, ARRIVING }

var _view: RunMapView
var _link: RunMapLink
var _from_id: int = -1
var _to_id: int = -1
var _total: int = 1
var _spent: int = 0
var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
## How many degrees this beat has to sweep, asked of the clock as the beat opens
## so the beat ends exactly on a period boundary whatever rounding came before.
var _beat_degrees: float = 0.0
## How many of them it has already spent, so each frame hands over the
## difference rather than a share that would drift.
var _beat_swept: float = 0.0
var _clock: Node


func _ready() -> void:
	set_physics_process(false)
	_clock = get_node_or_null(world_clock_path)


func is_travelling() -> bool:
	return _phase != Phase.IDLE


## Sets out along [param link] from [param from_id]. Answers false for a ride
## already under way or a road that is not there, so a second click during a
## ride cannot start a second one.
func begin(view: RunMapView, link: RunMapLink, from_id: int) -> bool:
	if is_travelling() or view == null or link == null:
		return false
	_view = view
	_link = link
	_from_id = from_id
	_to_id = link.other_end(from_id)
	if _to_id < 0:
		return false

	_total = maxi(link.day_cycles, 1)
	_spent = 0
	_view.place_token_on(_link, _from_id, 0.0)
	travel_started.emit(_link, _from_id, _to_id)
	_open_beat()
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.STEPPING:
			_advance_step()
		Phase.HOLDING:
			if _elapsed >= maxf(step_hold, 0.0):
				_open_beat()
		Phase.ARRIVING:
			if _elapsed >= maxf(arrival_hold, 0.0):
				_finish()
		_:
			set_physics_process(false)


## One beat's movement: the clock through one whole period, the piece through
## one equal share of the road, eased so the step arrives rather than stops.
func _advance_step() -> void:
	var t := 1.0 if step_duration <= 0.0 else clampf(_elapsed / step_duration, 0.0, 1.0)

	var wanted := _beat_degrees * t
	if _clock != null and _clock.has_method(&"advance_degrees"):
		_clock.call(&"advance_degrees", wanted - _beat_swept)
	_beat_swept = wanted

	var eased := smoothstep(0.0, 1.0, t)
	_view.place_token_on(
		_link, _from_id, (float(_spent) + eased) / float(_total))

	if t < 1.0:
		return

	# The sweep's fractions add up to the beat's 60° only as exactly as floating
	# point allows, and a beat that ends a hair short of its boundary leaves the
	# world in the hour it was meant to have left - so the landing is made exact
	# rather than accumulated.
	if _clock != null and _clock.has_method(&"snap_to_period_start"):
		_clock.call(&"snap_to_period_start")

	_spent += 1
	day_cycle_spent.emit(_spent, _total)
	_elapsed = 0.0
	_phase = Phase.ARRIVING if _spent >= _total else Phase.HOLDING


## Opens the next beat, asking the clock how far it is to the next period so the
## sweep lands exactly on it.
func _open_beat() -> void:
	_elapsed = 0.0
	_beat_swept = 0.0
	_beat_degrees = 0.0
	if _clock != null and _clock.has_method(&"degrees_until_next_period"):
		_beat_degrees = _clock.call(&"degrees_until_next_period")
	_phase = Phase.STEPPING


func _finish() -> void:
	set_physics_process(false)
	_phase = Phase.IDLE
	var arrived := _to_id
	_view.place_token_at(arrived)
	_view = null
	_link = null
	_from_id = -1
	_to_id = -1
	travel_finished.emit(arrived)
