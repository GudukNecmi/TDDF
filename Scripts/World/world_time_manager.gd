class_name WorldTimeManager
extends Node
## The World Map's own continuous clock: one authoritative world day and one
## authoritative position within it, advancing in real time.
##
## [b]It is not a second [DayClock].[/b] [DayClock] - the [code]DayCycle[/code]
## autoload - owns a completely different question: which of the map's
## discrete hours the base and the arena are showing, moved once per completed
## round, once per day of travel or once per slept segment - see
## [method DayClock.advance_stages]. Nothing here reads or writes that number,
## and [DayClock] reads or writes nothing here, so the two can never
## double-advance one another: one moves in event-driven stage jumps, the
## other in real seconds, and neither knows the other exists. This node exists
## because the World Map needs a clock that turns continuously, which the old
## one was never built to do.
##
## [b][SunController] and [DayCycleDirector] are the two other systems wired to
## read it[/b], so the sky, every shadow on it, and the world's own ambient
## darkness all turn in real time together, on a smooth blend between the same
## six anchors each already read - [SunStage] for the sun, [DayStage] for the
## darkness. The old Travel/Sleep flow's HUD readout still moves in round-sized
## jumps through [DayClock], since a journey or a slept segment is still spent
## in whole stages rather than continuous degrees - but [DayCycleDirector] now
## re-derives which of its own stages that readout names from this clock's
## current period too (see [member DayCycleDirector.follow_world_time]), so the
## name on screen and the darkness it is standing in can no longer disagree.
##
## [b]It is registered as an autoload[/b], for the same reason [DayClock] is:
## the World Map is a permanent sibling of the base and the arena in one
## persistent scene, never rebuilt or reloaded on its own, so nothing about
## entering it, leaving it, or the world being rebuilt for a round is allowed
## to reset or pause this clock.

## The six periods a day is divided into, in the order they are played - the
## same order [member SunController.stages] and [DayCycleDirector]'s own six
## desert hours are already authored in, so a period index already lines up
## with a stage index wherever the two are meant to agree.
enum TimePeriod { DAWN, MORNING, NOON, EVENING, TWILIGHT, NIGHT }

## Emitted every time the continuous degree moves - which is to say, most
## frames. For a clock hand or anything else meant to read every tick rather
## than poll for it.
signal degree_changed(degree: float)
## Emitted once, the frame the logical period changes - crossing 60°, 120°
## and so on. The sky itself does not snap here - see [SunController] - this
## is only the label changing.
signal period_changed(period: TimePeriod, period_index: int)
## Emitted once, the frame the day rolls over.
signal day_changed(day: int)

## How many real seconds one degree of world time takes to pass. The whole of
## the game's pacing rule - "15 real seconds moves the world 60 degrees, so a
## full 360° day takes 90 real seconds and each of the six periods lasts 15
## real seconds" - is this one number. Every other system that turns real time
## into world time (period progress, [SunController]'s blend,
## [WorldBountyBoss] schedules, [WorldMapCombatBridge]'s combat-time catch-up)
## reads it through [method advance_seconds] or [method seconds_until_degree]
## rather than assuming a rate of its own, so changing this one export is the
## whole of changing the game's pacing.
@export var seconds_per_degree: float = 0.25
## How many degrees make a full day. 360, one for each of the six 60° periods
## below.
@export var degrees_per_day: float = 360.0
## Which world day the clock is showing when it first reads. 1, not 0, so a
## debug readout's first day is not off by one.
@export var start_day: int = 1
## Which degree the clock starts at. 0 is the first instant of Dawn.
@export var start_degree: float = 0.0
## Where each of the six periods begins, in ascending degrees. Config-driven
## rather than six numbers written into [method get_time_period]: re-lengthening
## a period, or moving where one begins, is editing this array - in the same
## order as [enum TimePeriod].
@export var period_boundaries: PackedFloat32Array = PackedFloat32Array(
	[0.0, 60.0, 120.0, 180.0, 240.0, 300.0])
## What each period is called, for a debug readout - in the same order as
## [enum TimePeriod] and [member period_boundaries].
@export var period_names: Array[StringName] = [
	&"DAWN", &"MORNING", &"NOON", &"EVENING", &"TWILIGHT", &"NIGHT"]

var _day: int = 1
var _degree: float = 0.0
var _period: TimePeriod = TimePeriod.DAWN
## Whether a fight in the Arena currently owns this clock - see
## [method freeze_for_combat]. While true, [method Node._process] has already
## been stopped by the caller, and [member _degree] itself has been moved to
## the frozen combat value rather than merely held.
var _combat_frozen: bool = false
## Where the clock actually stood the instant combat opened, so
## [method unfreeze_after_combat] can pick the real day back up rather than
## resuming from the artificial degree combat borrowed for its lighting.
var _pre_combat_degree: float = 0.0


func _ready() -> void:
	_day = start_day
	_degree = fposmod(start_degree, maxf(degrees_per_day, 1.0))
	_period = _period_for_degree(_degree)


func _process(delta: float) -> void:
	advance_seconds(delta)


## The world day the clock is currently showing. Starts at [member start_day]
## and rises by one every time [member degrees_per_day] is crossed going
## forward.
func get_world_day() -> int:
	return _day


## Where the clock stands in the current day, in degrees - continuous rather
## than stepped, and the one number [SunController] and a clock face both
## derive their picture from.
func get_world_degree() -> float:
	return _degree


## Which of the six periods [method get_world_degree] currently falls in.
func get_time_period() -> TimePeriod:
	return _period


## [method get_time_period] as a plain int, for anything that would rather
## index an array - a stage list, a colour table - than import the enum.
func get_time_period_index() -> int:
	return int(_period)


## What the current period is called - see [member period_names].
func get_time_period_name() -> StringName:
	var index := int(_period)
	if index >= 0 and index < period_names.size():
		return period_names[index]
	return &""


## How far through the current period the clock is: 0 at its first degree, 1
## at its last. What a clock hand or [SunController]'s continuous blend reads
## to ease between one period's anchor and the next's.
func get_period_progress() -> float:
	var index := int(_period)
	var length := _period_length(index)
	if length <= 0.0:
		return 0.0
	var into := fposmod(_degree - _boundary(index), degrees_per_day)
	return clampf(into / length, 0.0, 1.0)


## Moves the clock on by [param seconds] of real time, at
## [member seconds_per_degree]. What [method Node._process] calls every
## frame; public so a debug tool or a later "skip ahead" action can ask for
## the same advance by hand.
func advance_seconds(seconds: float) -> void:
	if seconds == 0.0 or seconds_per_degree <= 0.0:
		return
	_advance_degrees(seconds / seconds_per_degree)


## Moves the clock on by [param ticks] whole degrees directly, bypassing
## [member seconds_per_degree]. For a gameplay system that wants to spend
## world time in the same whole-degree units the period boundaries are
## authored in, rather than translate it through seconds first.
func advance_ticks(ticks: int) -> void:
	if ticks == 0:
		return
	_advance_degrees(float(ticks))


## How many real seconds until the clock reaches [param target_degree], going
## forward. For a debug readout, or a later system that wants to say "dawn in
## three minutes".
func seconds_until_degree(target_degree: float) -> float:
	if seconds_per_degree <= 0.0 or degrees_per_day <= 0.0:
		return 0.0
	var target := fposmod(target_degree, degrees_per_day)
	var remaining := fposmod(target - _degree, degrees_per_day)
	return remaining * seconds_per_degree


## How many real seconds until [param period] begins.
func seconds_until_period(period: TimePeriod) -> float:
	return seconds_until_degree(_boundary(int(period)))


func _advance_degrees(amount: float) -> void:
	if is_zero_approx(amount) or degrees_per_day <= 0.0:
		return

	var old_period := _period
	_degree += amount
	while _degree >= degrees_per_day:
		_degree -= degrees_per_day
		_day += 1
		day_changed.emit(_day)
	while _degree < 0.0:
		_degree += degrees_per_day
		_day -= 1
		day_changed.emit(_day)

	degree_changed.emit(_degree)
	_period = _period_for_degree(_degree)
	if _period != old_period:
		period_changed.emit(_period, int(_period))


## The greatest boundary at or before [param degree] - the period it falls
## in.
func _period_for_degree(degree: float) -> TimePeriod:
	var found := 0
	for index: int in range(period_boundaries.size()):
		if degree >= period_boundaries[index]:
			found = index
	return found as TimePeriod


## The exact middle degree of period [param period_index] - the current one when
## left at -1. What a fight in the Arena locks its lighting to for the whole of
## its length, rather than whatever degree the World Map clock happened to be
## sitting at the instant the player was caught - see [method freeze_for_combat].
##
## Read from [member period_boundaries] and [method _period_length] exactly as
## authored, so re-lengthening a period moves its middle with it and nothing
## here keeps a second copy of where one begins.
func get_period_middle_degree(period_index: int = -1) -> float:
	var index := period_index if period_index >= 0 else int(_period)
	var start := _boundary(index)
	var length := _period_length(index)
	return fposmod(start + length * 0.5, maxf(degrees_per_day, 1.0))


## Whether a fight currently owns this clock - see [method freeze_for_combat].
func is_combat_frozen() -> bool:
	return _combat_frozen


## Locks the clock to the exact middle degree of the current World Map segment,
## for [SunController] and every shadow reading it to freeze on for the whole of
## a fight - see the class doc's own note on why the sun and this clock are the
## same freeze.
##
## [b]The real day is not lost, only set aside.[/b] The degree the clock
## actually stood at is kept in [member _pre_combat_degree] and is what
## [method unfreeze_after_combat] resumes from, so a fight fought a few degrees
## into Dawn still leaves the World Map a few degrees into Dawn once it is over -
## the borrowed middle-of-segment degree is a lighting fiction for the length of
## the fight and never becomes the World Map's own place in the day.
##
## Idempotent: called again while already frozen, it does nothing and returns
## the degree already in force, so a caller does not have to track whether it
## has already asked.
##
## The caller still has to stop [method Node._process] itself - this only moves
## the degree the clock reports while that hold is in place, exactly as it did
## before combat ever froze it, so nothing here duplicates that switch.
func freeze_for_combat() -> float:
	if _combat_frozen:
		return _degree
	_combat_frozen = true
	_pre_combat_degree = _degree
	_degree = get_period_middle_degree()
	_period = _period_for_degree(_degree)
	degree_changed.emit(_degree)
	return _degree


## Gives the real day back and advances it by [param advance_degrees] in one
## step - see the class doc's own "Immediately apply the resulting degree
## increase... Do not create a delayed timer or gradual transition for this
## progression."
##
## [b]It resumes from where the fight actually started, not from the frozen
## middle degree combat was lit by.[/b] The two are different numbers on
## purpose - see [method freeze_for_combat] - so a fight that opened five
## degrees into Twilight and is worth seventeen more leaves the World Map at
## twenty-two degrees into Twilight, never at "the segment's middle plus
## seventeen".
##
## Safe to call when nothing is frozen - the caller's own
## [method Node.set_process] is asked for either way, so this alone is what a
## fight that was cancelled before it ever placed anybody still has to call to
## hand the clock back.
func unfreeze_after_combat(advance_degrees: float = 0.0) -> void:
	if _combat_frozen:
		_combat_frozen = false
		_degree = _pre_combat_degree
	if not is_zero_approx(advance_degrees):
		_advance_degrees(advance_degrees)
	else:
		_period = _period_for_degree(_degree)
		degree_changed.emit(_degree)


func _boundary(index: int) -> float:
	if period_boundaries.is_empty():
		return 0.0
	return period_boundaries[clampi(index, 0, period_boundaries.size() - 1)]


## How many degrees period [param index] spans, wrapping the last period
## round to [member degrees_per_day] rather than to the first boundary again -
## so Night's length is measured against midnight, not against Dawn's own
## start.
func _period_length(index: int) -> float:
	var count := period_boundaries.size()
	if count <= 0:
		return degrees_per_day
	var start := _boundary(index)
	var next := degrees_per_day
	if index + 1 < count:
		next = _boundary(index + 1)
	if next <= start:
		next += degrees_per_day
	return next - start
