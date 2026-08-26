class_name TravelDirector
extends Node
## The journey, from the camp's TRAVEL button to standing in the region that was
## marked on the map.
##
## [b]A journey is a state, not a place.[/b] It used to be a road: a nineteen
## thousand pixel map instanced into the world, crossed on foot against enemies,
## with a cart at the far end that raised the travel screen. That is gone. Riding
## out now happens where the player is standing, in three steps this node owns and
## nothing else knows about:
##
##   [codeblock]
##   request()  ->  the horse is sent for  ->  the travel screen  ->  arrival
##   [/codeblock]
##
##   * [b]Travel requested.[/b] [CampMenu] presses TRAVEL and calls
##     [method request]. Where the player is going is already on
##     [RunSessionState] - marking it on the regional map is what put it there -
##     so all this does is take the journey out of the camp's hands.
##   * [b]The horse arrives.[/b] A state of its own, held for
##     [member horse_arrival_time], announced by [signal horse_requested] and
##     [signal horse_arrived]. [b]It has no visuals yet and does not want any
##     written here[/b] - it is the window the horse and cart animation will play
##     in, and the two signals are what that animation will be hung off, so
##     adding it later is a listener rather than a change to this flow.
##   * [b]The travel screen.[/b] [TravelMenu] is raised, showing where the player
##     is, where they are going and what hour it is. Backing out of it puts the
##     journey back and hands the camp its own screen again - see
##     [method cancel] - so nothing about pressing TRAVEL is a commitment.
##   * [b]The road.[/b] Confirming fades to black and the journey is made a day at
##     a time, each day taking [member day_time] and rolled against
##     [member travel_events] part way through it - so the player rides, is told
##     what the day held, and only then lives with it. See [method _next_day].
##     Most days pass with the cart crossing the black, and the rest stop the road:
##     an ambush, which is already happening, or a gang, which asks first. A fight
##     is the ordinary game in the world the player was already standing in, with
##     the world's own enemies and [b]no round and no clock[/b] - the arena's
##     [WaveManager] is never started by any of this - so when the last of them
##     goes down the black comes back and the journey carries on from the next day
##     with the health, ammunition and blood the fight left behind.
##   * [b]The stop.[/b] Every day ends standing still: the travel screen stays up,
##     and over it go the camp's own actions - heal, shells, a change of gun - and
##     CONTINUE TRAVEL. See [method _day_over] and [TravelDayMenu]. A day that held
##     an ambush is stood at with the horse halted where the trouble stopped it,
##     which is the only visible difference between the two kinds of day.
##   * [b]Hurrying.[/b] The road can be ridden at speed - see
##     [method _set_hurrying] - which turns the game's own [member Engine.time_scale]
##     up and rides straight through the stops until the player asks it to stop or a
##     day turns out to hold something.
##   * [b]Arrival.[/b] Once the days run out, the marked destination becomes the
##     region through [method RunSessionState.complete_travel] and the world is
##     rebuilt around it. What comes back is an ordinary round in the region the
##     player rode to, with the health, blood and ammunition the road left them.
##
## [b]It owns no state of its own that the session already answers.[/b] Whether a
## journey is under way is [method RunSessionState.is_travelling], begun by
## [method RunSessionState.begin_travel] and ended by either
## [method RunSessionState.complete_travel] or
## [method RunSessionState.abandon_travel] - the same three calls the road used,
## doing the same three jobs. What this adds is the order they happen in and the
## screen between them.
##
## The world is frozen for the whole journey. The camp froze it on the way in and
## the travel screen takes that over as it opens, so the gap in between - the horse
## arriving - is a paused world rather than one the player can walk around in, and
## every timer here is a process-always one so it still ticks through it.

## Emitted the moment TRAVEL is pressed and the horse is sent for. The screen is
## not up yet; this is the start of the arrival window.
signal horse_requested(region_id: StringName)
## Emitted when the horse has arrived, immediately before the travel screen is
## raised. [b]This is the seam the horse animation ends on.[/b]
signal horse_arrived(region_id: StringName)
## Emitted as the travel screen goes up.
signal screen_opened(region_id: StringName)
## Emitted when the player backs out of the travel screen. The destination stays
## marked, so the camp still offers the ride.
signal travel_cancelled()
## Emitted as the player rides off, with how many day stages the journey takes.
## The world has not been rebuilt yet.
signal departed(days: int)

## Group the director joins, so anything can find it without a path.
const GROUP := &"travel_director"

## Which step of the journey we are on. Read with [method get_state]; the horse
## animation, a travel cost and an ambush roll are all things a later milestone
## hangs off these rather than off a flag of its own.
enum State {
	## Nobody is travelling.
	IDLE,
	## TRAVEL has been pressed and the horse is on its way.
	HORSE_ARRIVING,
	## The travel screen is up and the player is deciding.
	AT_SCREEN,
	## The ride has been confirmed and the world is on its way to being rebuilt.
	DEPARTING,
	## The journey is being made: days are being spent one at a time, each one
	## rolling for something to happen.
	ON_THE_ROAD,
	## A day rolled something. The road is held while it is dealt with - a choice
	## being answered, or a fight being had.
	IN_EVENT,
	## A day is over and the player is standing at it: the travel screen is up with
	## the camp's own actions on it, waiting on CONTINUE TRAVEL.
	AT_DAY_STOP,
}

## The run's own state - the [code]RunSession[/code] autoload. Where the
## destination is read from and where the journey is begun, abandoned and
## completed.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Nodes")
## The travel screen this raises once the horse is here.
@export var menu_path: NodePath = ^"../RunHUD/TravelMenu"
## The picture shown over the black while the ride is made. Optional - without one
## the screen simply stays black for the same length of time.
@export var loading_path: NodePath = ^"../RunHUD/TravelLoading"
## The screen that asks whether to ride past a gang. Optional - a world without one
## rides past everything that would have asked.
@export var event_menu_path: NodePath = ^"../RunHUD/TravelEventMenu"
## The stop at the end of a day: the camp's own actions, and CONTINUE TRAVEL. See
## [TravelDayMenu].
##
## Optional. A world without one rides day after day without stopping, which is the
## journey exactly as it was before there was anywhere to stop - so a missing screen
## can never be the reason a ride strands.
@export var day_menu_path: NodePath = ^"../RunHUD/TravelDayMenu"
## The world's own spawner, which builds every enemy a travel event puts on the
## road. [b]There is no travel enemy[/b] - an ambush is the game's ordinary enemy,
## made by the thing that already makes them.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## The ambush system - see [AmbushWaveDirector] - which runs the fight for any
## event authored with [member TravelEvent.uses_ambush_wave].
##
## Optional. A world without one runs an ambush as the plain encounter below, so
## this can never be the reason a journey stalls; and the arena's own
## [WaveManager] is not involved either way, which is what keeps a fight on the
## road from ever becoming a sixty-second round.
@export var ambush_path: NodePath = ^"../AmbushDirector"

@export_group("On the road")
## What can happen on a day of travel, and how likely each is.
##
## [b]The whole of the event system's tuning.[/b] One [TravelEvent] per outcome -
## the game ships with nothing, an ambush and a gang - each carrying its own
## weight and its own number of enemies. The chances are here rather than on the
## travel screen on purpose: how dangerous the road is is a fact about the road,
## not about the menu the player set out from, and a second travel screen would
## otherwise need its own copy of it.
##
## An empty array, or one whose weights are all zero, is a road where nothing ever
## happens - which is exactly the journey as it was before events existed.
@export var travel_events: Array[TravelEvent] = []
## How long one day of the ride lasts, in seconds.
##
## [b]A journey is meant to be ridden, not skipped.[/b] The whole ride used to be
## one short wait divided between its days, which made a four-day journey a hitch
## between two worlds; a day is now a length of its own and the ride is as long as
## the days it takes. See [method _day_time].
@export var day_time: float = 5.0
## How far into a day the roll is made, in seconds - the moment the player finds
## out what this day held.
##
## Deliberately about half way. The first half is the ride, the second is living
## with the answer: an ambush is announced and then arrives, rather than the screen
## cutting to a fight the player was given no beat to see coming. Held to the
## length of a day, so a roll time longer than the day itself simply lands at the
## end of it.
@export var event_roll_time: float = 2.5
## What a day with no event at all is reported as - a road authored with no events,
## or one whose weights are all zero. Every authored event says this for itself; see
## [member TravelEvent.result_text].
@export var quiet_result_text: String = "NOTHING HAPPENED."
@export var quiet_result_colour := Color(0.5, 0.36, 0.34)
## How long the player is left looking at the last of an event's enemies going down
## before the road picks up again, in seconds.
@export var encounter_end_delay: float = 1.2
## How long the screen takes to clear as a fight begins, and to go black again as it
## ends.
@export var encounter_fade_time: float = 0.6
## Group every enemy joins, used to clear the road of anything left standing when a
## journey ends. The world's own group, not one of travel's.
@export var enemy_group: StringName = &"enemies"
## Group the player's own [Health] is found by, so the road can be put back if they
## are killed on it - see [method _on_player_died]. The world's own group, the same
## one [DangerDirector] and [SleepDirector] follow the player's death through.
@export var health_group: StringName = &"player_health"

@export_group("Stopping for the day")
## Whether the road stops at the end of every day it spends.
##
## [b]On, and it is what makes a journey something the player travels rather than
## watches.[/b] Each day ends with the travel screen still up and the camp's own
## actions on it - heal, shells, a change of gun - and the ride only picks up when
## CONTINUE TRAVEL is pressed. It stops after the last day too, so a player who came
## out of an ambush on the final leg can patch themselves up before riding into the
## region rather than arriving in whatever state the fight left them.
##
## Off rides day after day without asking, which is the journey exactly as it was
## before there was anywhere to stop.
@export var stops_each_day: bool = true
## How long the road is left standing before the stop is raised, in seconds, so the
## last of the day is seen to finish rather than being cut off by a panel.
@export var day_stop_delay: float = 0.35

@export_group("Fast travel")
## Whether the road can be ridden at speed at all.
@export var allows_fast_travel: bool = true
## The key that turns it on, and turns it off again. Held to the journey - see
## [method _unhandled_input] - so it is dead everywhere else in the game.
@export var fast_travel_action: StringName = &"fast_travel"
## What the game's speed is set to while it is on.
##
## [b]It is the game's own speed and not a second one.[/b] It goes to
## [member Engine.time_scale] - the same dial the hit stop, the coin's slow motion
## and the death sequence already turn - so the cart, the day's own timers and
## everything else on screen speed up together rather than the ride being separately
## shortened behind a screen still playing at its ordinary pace.
@export var fast_travel_speed: float = 1.5
## What the corner of the travel screen says while the road can be hurried.
@export var fast_travel_hint: String = "SHIFT to Fast Travel ;)"
## What it says once it is on, so pressing the key again reads as something that can
## be undone. Empty leaves the first hint standing.
@export var fast_travel_on_hint: String = "FAST TRAVEL  -  SHIFT to slow down"
## Whether the road drops back to its ordinary speed the moment a day turns out to
## hold something.
##
## [b]On, and deliberately.[/b] What is being hurried is the riding, not the
## fighting: a gang that has to be answered or an ambush that has to be fought is
## exactly the thing the player was going to want to slow down for, so the road slows
## itself rather than putting them into a fight at half again the speed. Riding on
## afterwards is one more press of the key.
@export var events_stop_fast_travel: bool = true

@export_group("The horse")
## How long the horse takes to arrive, in seconds, from TRAVEL being pressed to
## the travel screen going up.
##
## [b]Zero on purpose, for now.[/b] There is nothing to look at during the wait
## yet - the horse has no artwork and the world is frozen behind the camp - so a
## delay here would be a blank pause rather than an arrival. The state and both
## its signals still happen, in order, on the frame TRAVEL is pressed; this is the
## one number to raise once there is a horse to watch walking in.
@export var horse_arrival_time: float = 0.0

@export_group("Leaving")
## Whether the world is actually rebuilt on arrival. Off makes the journey report
## itself and change nothing, which is what a test harness wants.
@export var reload_scene: bool = true
## Whether the world is put back to how it was found as the ride begins, behind the
## black, before a single day of the journey is spent.
##
## On, and it is not made redundant by [member reload_scene]. A journey is not one
## cut to somewhere else: its days are rolled against [member travel_events] and an
## ambush is fought [i]in this world[/i], around the player, before the arrival ever
## rebuilds anything - so without this the road's fights are had among the corpses,
## the dropped knives and the tracks of the region the player is leaving. It is
## [WorldReset]'s doing rather than this node's, the same request looking for
## trouble makes on its own walk; a world with no reset in it rides out exactly as it
## did.
@export var rebuilds_the_world: bool = true
## Gap between the player confirming and the fade starting, so the press is seen
## to land.
@export var start_delay: float = 0.15
## How long the screen takes to go black.
@export var fade_out_time: float = 0.9
## How long the screen takes to clear on the far side. It is carried across the
## rebuild by [ScreenFade] itself.
@export var fade_in_time: float = 1.0
## Whether the soundtrack is handed to the arena track as the journey starts - the
## player is arriving in a region to fight in, not going home.
@export var drive_music: bool = true

var _session: Node
var _menu: Node
var _state: State = State.IDLE
## How many day stages the journey being made is, and how many of them have been
## spent. The day is the unit an event is rolled against - see [method _next_day].
var _days_total: int = 0
var _days_done: int = 0
## How many of the current event's enemies are still standing. The fight is over
## when it reaches zero, which is the only thing that ends an event.
var _enemies_left: int = 0
## Whether the road is being hurried. Held here rather than on the screen because it
## survives the screen going up and coming down again - that is the whole of what
## "continue automatically through the following days" means.
var _hurrying: bool = false
## The player's pool while a ride is being made, so the road can be put back if they
## are killed on it. Held rather than looked up each time for the same reason
## [AmbushWaveDirector] holds it: the connection has to be droppable again.
var _player_health: Health


## Joined here rather than in [method Node._ready] so the director is findable,
## and has already found the session, whatever order the world's nodes happen to
## sit in.
func _enter_tree() -> void:
	add_to_group(GROUP)
	_session = get_node_or_null(session_path)


## A world is only ever built between journeys, never during one - the whole ride
## happens inside the world the camp was in - so a session still claiming to be
## travelling as a world comes up is a journey that was interrupted rather than
## finished: a quit, a reload, a crash part way through.
##
## Left standing it would be a dead TRAVEL button, because
## [method RunSessionState.begin_travel] refuses to begin a journey that is
## already under way. So it is put back here. The destination is untouched, which
## means the camp comes up still offering the ride.
func _ready() -> void:
	if _state == State.IDLE and _session_says_travelling():
		_abandon_on_session()


## Nothing is left hurried behind us: a world torn down mid-journey - a death on the
## road, a reload - would otherwise hand whatever comes next a game still running at
## half again its speed.
func _exit_tree() -> void:
	_set_hurrying(false)
	_drop_player_death()


## The director the world should talk to. Null means this world has none, which
## [CampMenu] reads as "there is no way to ride out from here".
static func get_active(from_node: Node) -> TravelDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelDirector


## Which step of the journey is being played out.
func get_state() -> State:
	return _state


## Whether a journey is under way at all - anything but [constant State.IDLE].
func is_journey_under_way() -> bool:
	return _state != State.IDLE


## Where the journey is headed, asked of the session so there is no second copy of
## the destination anywhere in the travel flow.
func get_destination() -> StringName:
	if _session == null or not _session.has_method(&"get_destination_region"):
		return &""
	return _session.call(&"get_destination_region")


# --- Setting out --------------------------------------------------------------

## Sends for the horse, and reports whether the journey was actually begun.
##
## Called by [CampMenu] when TRAVEL is pressed. A false answer is not an error to
## hide - no destination marked, a journey already under way, or no screen to
## raise - and nothing is changed on the way out, so the camp is left exactly as it
## was rather than hidden behind a journey that never started.
func request() -> bool:
	if _state != State.IDLE:
		return false
	if _session == null or not _session.has_method(&"begin_travel"):
		return false

	# Asked for before anything is committed to. A world with no travel screen
	# would send for a horse and then have nothing to show the player.
	_menu = get_node_or_null(menu_path)
	if _menu == null or not _menu.has_method(&"open"):
		push_warning("TravelDirector: no travel screen to raise.")
		return false

	if not _session.call(&"begin_travel"):
		return false

	_state = State.HORSE_ARRIVING
	_wire_menu()
	horse_requested.emit(get_destination())

	if horse_arrival_time <= 0.0:
		_on_horse_arrived()
		return true

	# Process-always and in real time, so the arrival still lands through the
	# freeze the camp left the world in.
	var timer := get_tree().create_timer(horse_arrival_time, true, false, true)
	timer.timeout.connect(_on_horse_arrived)
	return true


## The horse is here. Nothing about it exists to be shown yet - see
## [member horse_arrival_time] - so this announces the arrival and raises the
## screen in the same breath.
func _on_horse_arrived() -> void:
	if _state != State.HORSE_ARRIVING or not is_inside_tree():
		return

	var region := get_destination()
	horse_arrived.emit(region)

	_state = State.AT_SCREEN
	_menu.call(&"open")
	screen_opened.emit(region)


## Puts the journey back without having made it. The destination stays marked -
## backing out of the screen is changing your mind about riding now, not about
## where you were going - so the camp comes back still offering TRAVEL.
## Only while the player is still deciding. Once the ride has been paid for and
## begun there is no backing out of it, and a journey part way along the road
## certainly cannot be put back by a screen closing.
func cancel() -> void:
	if _state != State.HORSE_ARRIVING and _state != State.AT_SCREEN:
		return

	_state = State.IDLE
	_abandon_on_session()
	travel_cancelled.emit()


func _wire_menu() -> void:
	if _menu == null:
		return
	if _menu.has_signal(&"travel_confirmed") \
			and not _menu.is_connected(&"travel_confirmed", _on_travel_confirmed):
		_menu.connect(&"travel_confirmed", _on_travel_confirmed)
	# Backing out. The screen reports a confirmation by hiding rather than closing,
	# so this only ever fires on a journey the player thought better of.
	if _menu.has_signal(&"closed") and not _menu.is_connected(&"closed", cancel):
		_menu.connect(&"closed", cancel)


func _session_says_travelling() -> bool:
	if _session == null or not _session.has_method(&"is_travelling"):
		return false
	return _session.call(&"is_travelling")


func _abandon_on_session() -> void:
	if _session != null and _session.has_method(&"abandon_travel"):
		_session.call(&"abandon_travel")


# --- Riding off ---------------------------------------------------------------

## The whole of a journey, from the player confirming to the world being rebuilt
## around the region they were heading for.
##
## [param days] is how many day stages the ride takes, as the screen reported it.
## [b]It is zero for now[/b] - the travel screen does not offer a duration yet -
## and zero is spent exactly as any other number is, through
## [method RunSessionState.complete_travel], which moves the clock by nothing and
## still makes the arrival. So there is no branch here for "the milestone without
## durations", and turning them on later changes nothing in this file.
func _on_travel_confirmed(days: int) -> void:
	if _state == State.DEPARTING:
		return
	_state = State.DEPARTING

	# Handed back before anything else, because a transition started from a frozen
	# tree would come back frozen - the same order the camp leaves in.
	get_tree().paused = false
	_hand_music_over()
	departed.emit(days)

	if not reload_scene:
		_state = State.IDLE
		return

	# Real time and process-always, so the transition still lands whatever else has
	# touched the tree's pause state or the time scale by the time it fires.
	var timer := get_tree().create_timer(maxf(start_delay, 0.0), true, false, true)
	timer.timeout.connect(_fade_out.bind(days))


func _hand_music_over() -> void:
	if not drive_music:
		return
	var music := MusicDirector.get_active(self)
	if music != null:
		music.switch_to_arena(fade_out_time)


func _fade_out(days: int) -> void:
	if not is_inside_tree():
		return

	var fade := ScreenFade.get_active(self)
	if fade == null:
		# Nothing to hide the change behind. The journey still happens - the player
		# simply sees the cut - which is how every other transition in the game
		# degrades when there is no fade in the scene.
		_ride(days)
		return

	fade.fade_out(fade_out_time, _ride.bind(days))


## The journey itself, made a day at a time behind the black.
##
## [b]A journey is no longer one wait.[/b] Each of its days is rolled against
## [member travel_events] and can stop the road - see [method _next_day] - so this
## only sets the count going; what finishes it is running out of days.
func _ride(days: int) -> void:
	if not is_inside_tree():
		return

	_days_total = maxi(days, 0)
	_days_done = 0
	_state = State.ON_THE_ROAD
	# Before the first day is rolled, so an ambush on the very first one is fought in a
	# world that has already been put back rather than in the one being left.
	if rebuilds_the_world:
		_rebuild_the_world()
	# Followed from the moment the ride actually begins, because from here on the road
	# can put the player in front of somebody who can kill them.
	_follow_player_death()
	_next_day()


## Hands the world back empty for the road to be ridden through.
##
## [b]Nothing about what a clean world is lives here.[/b] The one call is
## [method WorldReset.reset], the same request looking for trouble makes on its walk
## - see [method DangerDirector._rebuild_the_world] - so there is one answer to "put
## this world back" in the project and both are asking it.
func _rebuild_the_world() -> void:
	var reset := WorldReset.get_active(self)
	if reset != null:
		reset.reset()


## One day of the journey, ridden in three beats: the road, the roll, and whatever
## was rolled.
##
## [codeblock]
##   0s            event_roll_time            day_time
##   |-- riding ---------|-- the word over the black --|-- act on it
## [/codeblock]
##
## [b]A day is a length of time, not an instant.[/b] The roll used to be made on
## the frame the day began and acted on in the same breath, which meant a journey
## either flicked past or cut straight into a fight. It is now made part way
## through - see [method _roll_for_the_day] - announced, and only then acted on, so
## every day of every ride costs the same [member day_time] whatever it turns out
## to hold.
##
## The days are counted here rather than by the thing that spends them, because an
## event holds the road without spending a day twice - the count moves once, at the
## top, and the event that follows resumes from wherever it left off.
func _next_day() -> void:
	if not is_inside_tree():
		return
	if _days_done >= _days_total:
		_finish_ride()
		return

	_days_done += 1
	_show_loading()

	var wait := clampf(event_roll_time, 0.0, _day_time())
	if wait <= 0.0:
		_roll_for_the_day()
		return

	# Process-always, so the day still passes through the freeze the ride is being
	# made behind - but [b]not[/b] out of the game's time scale, which is what lets
	# fast travel shorten it. The cart crossing the black is paced off the same scale,
	# so the two stay in step whatever speed the road is being ridden at.
	var timer := get_tree().create_timer(wait, true, false, false)
	timer.timeout.connect(_roll_for_the_day)


## Part way through a day: what happened is decided, and the player is told.
##
## [b]Deciding and acting are deliberately apart.[/b] The word goes up here and the
## rest of the day is spent reading it; what it costs is [method _act_on], which is
## the same call whether the answer was nothing at all or an ambush - so there is
## one place a day ends and the notification is never something a branch could skip.
func _roll_for_the_day() -> void:
	if not is_inside_tree() or _state != State.ON_THE_ROAD:
		return

	var event := _roll_event()
	_show_result(event)

	# A day that holds something pulls the horse up where it stands, about the middle
	# of the screen, and leaves it there for the fight to be fought and the day screen
	# afterwards to put back. A quiet day carries on across and off the far side.
	if _holds_something(event):
		_halt_loading()
		if events_stop_fast_travel:
			_set_hurrying(false)

	var rest := maxf(_day_time() - clampf(event_roll_time, 0.0, _day_time()), 0.0)
	if rest <= 0.0:
		_act_on(event)
		return

	var timer := get_tree().create_timer(rest, true, false, false)
	timer.timeout.connect(_act_on.bind(event))


## The day is over and whatever it held is paid for: nothing, a question, or a
## fight. A null event - a road with nothing authored on it - is a quiet day, which
## is the journey exactly as it was before there were events to roll.
func _act_on(event: TravelEvent) -> void:
	if not is_inside_tree() or _state != State.ON_THE_ROAD:
		return

	if not _holds_something(event):
		_day_over()
		return

	if event.offers_choice:
		_ask_about(event)
		return

	_begin_encounter(event)


## Whether a rolled day is one the road has to stop for. A null event - a road with
## nothing authored on it - and one authored as quiet with nothing to answer are the
## same quiet day, and there is one place that is decided.
func _holds_something(event: TravelEvent) -> bool:
	if event == null:
		return false
	return event.offers_choice or not event.is_quiet()


## How long one day of the ride lasts. Every day is the same length - see
## [member day_time] - so a four-day journey takes four times as long as a one-day
## one rather than the two being squeezed into the same wait.
##
## [b]It is a length in game time, not in the player's.[/b] Fast travel turns the
## game's own speed up, and every timer a day is made of runs against that speed, so
## a hurried day is this many seconds divided by [member fast_travel_speed] without
## anything here having to know about it.
func _day_time() -> float:
	return maxf(day_time, 0.05)


# --- Stopping for the day ------------------------------------------------------

## The end of a day, however it went: the road stands still and the player is offered
## the camp's own actions and CONTINUE TRAVEL.
##
## [b]It is the same stop after a quiet day and after a fight.[/b] What differs is
## only what the screen behind it is showing - a horse that carried on across, or one
## halted about the middle where the ambush stopped it - and that difference was made
## when the day was rolled rather than here. So there is one place a day ends, and
## the actions on offer cannot depend on how it went.
func _day_over() -> void:
	if not is_inside_tree():
		return

	_state = State.ON_THE_ROAD
	if not stops_each_day or _hurrying:
		_ride_on()
		return

	var menu := _resolve_day_menu()
	if menu == null:
		# Nowhere to stop. The road carries on rather than standing still at a screen
		# the player was never given.
		_ride_on()
		return

	_state = State.AT_DAY_STOP
	_halt_loading()
	# Put back whatever the fight concealed, so a day that held an ambush is stood at
	# with the horse where it pulled up rather than behind a bare panel.
	_reveal_loading()

	var timer := get_tree().create_timer(maxf(day_stop_delay, 0.0), true, false, true)
	timer.timeout.connect(_raise_day_stop.bind(menu))


func _raise_day_stop(menu: TravelDayMenu) -> void:
	if not is_inside_tree() or _state != State.AT_DAY_STOP or menu == null:
		return
	if not menu.continued.is_connected(_on_day_continued):
		menu.continued.connect(_on_day_continued, CONNECT_ONE_SHOT)
	menu.open()


func _on_day_continued() -> void:
	if _state != State.AT_DAY_STOP:
		return
	_ride_on()


## On with the journey from wherever it was left. [method _next_day] answers both
## "another day" and "there are none left", so there is one place a ride runs out and
## this never has to know which of the two it is asking for.
func _ride_on() -> void:
	_state = State.ON_THE_ROAD
	# The rest of the ride is made behind the black, so the world goes back to being
	# frozen - a guarantee rather than a change, because the stop never handed it back.
	get_tree().paused = true
	_next_day()


func _close_day_stop() -> void:
	var menu := _resolve_day_menu()
	if menu != null:
		menu.close()


func _resolve_day_menu() -> TravelDayMenu:
	var named := get_node_or_null(day_menu_path) as TravelDayMenu
	return named if named != null else TravelDayMenu.get_active(self)


# --- Fast travel ---------------------------------------------------------------

## Whether the road is being hurried.
func is_fast_travelling() -> bool:
	return _hurrying


## The key, held to the journey.
##
## [b]It is only listened for on the road[/b] - while a day is being ridden, and
## while the player is standing at the stop between two - so the same key is dead in
## the arena, in the camp and in every menu, and nothing else in the game has to know
## it exists. Turning it on at a stop is also the press of CONTINUE TRAVEL, which is
## what makes one key both "go faster" and "stop asking me".
func _unhandled_input(event: InputEvent) -> void:
	if not allows_fast_travel or fast_travel_action == &"":
		return
	if _state != State.ON_THE_ROAD and _state != State.AT_DAY_STOP:
		return
	if not event.is_action_pressed(fast_travel_action):
		return

	get_viewport().set_input_as_handled()
	var was_at_a_stop := _state == State.AT_DAY_STOP
	_set_hurrying(not _hurrying)

	if _hurrying and was_at_a_stop:
		_close_day_stop()
		_ride_on()


## Turns the road's speed up and down.
##
## [b]The speed is the game's own.[/b] Nothing here counts a second clock or shortens
## a day by hand: [member Engine.time_scale] is turned up and the day's timers, the
## cart crossing the black and everything else on screen follow it together. Putting
## it back is setting it to one, which is where every other thing that turns that dial
## leaves it.
func _set_hurrying(on: bool) -> void:
	var wanted := on and allows_fast_travel
	if _hurrying == wanted:
		return

	_hurrying = wanted
	Engine.time_scale = maxf(fast_travel_speed, 0.05) if _hurrying else 1.0
	_write_hint()


## Which event this day turns out to be.
##
## A weighted pick over [member travel_events]. [b]Nothing has to add up to
## anything[/b]: the weights are totalled and the roll is taken against that total,
## so a road whose events are authored as 60/25/15 and one authored as 6/2.5/1.5
## behave identically, and switching an event off is setting its weight to zero
## rather than rebalancing the others.
##
## Null - no events, or every weight zero - is a quiet day, which is the journey
## exactly as it was before there were events to roll.
func _roll_event() -> TravelEvent:
	var total := 0.0
	for event: TravelEvent in travel_events:
		if event != null:
			total += event.get_weight()
	if total <= 0.0:
		return null

	var roll := randf() * total
	for event: TravelEvent in travel_events:
		if event == null:
			continue
		roll -= event.get_weight()
		if roll <= 0.0:
			return event

	# Only reachable on floating-point crumbs at the very top of the range.
	for index: int in range(travel_events.size() - 1, -1, -1):
		var event := travel_events[index]
		if event != null and event.get_weight() > 0.0:
			return event
	return null


func _show_loading() -> void:
	var loading := get_node_or_null(loading_path)
	if loading == null or not loading.has_method(&"play"):
		return
	loading.call(&"play", get_destination(), _days_total, _day_time())
	# Written after the crossing has begun, because raising the screen clears its
	# corner - a hint belongs to the ride that offered it.
	_write_hint()


## Pulls the horse up where it stands, leaving the screen exactly as it is.
func _halt_loading() -> void:
	var loading := get_node_or_null(loading_path)
	if loading != null and loading.has_method(&"halt"):
		loading.call(&"halt")


## Takes the screen off for a fight, remembering where the horse had got to.
func _conceal_loading() -> void:
	var loading := get_node_or_null(loading_path)
	if loading != null and loading.has_method(&"conceal"):
		loading.call(&"conceal")


## Puts it back exactly there.
func _reveal_loading() -> void:
	var loading := get_node_or_null(loading_path)
	if loading != null and loading.has_method(&"reveal"):
		loading.call(&"reveal")


## What the corner of the travel screen says about hurrying, written from the one
## place that knows whether the road is being hurried.
func _write_hint() -> void:
	var loading := get_node_or_null(loading_path)
	if loading == null or not loading.has_method(&"show_hint"):
		return
	if not allows_fast_travel:
		loading.call(&"clear_hint")
		return

	var text := fast_travel_hint
	if _hurrying and not fast_travel_on_hint.is_empty():
		text = fast_travel_on_hint
	loading.call(&"show_hint", text)


## Says what the day turned out to be, over the cart still crossing the black.
##
## The wording and the colour are the event's own - see
## [member TravelEvent.result_text] - so "NOTHING HAPPENED." and "AMBUSH!" are two
## [code].tres[/code] files rather than two strings here, and a fourth event
## announces itself without this function being touched. A road with nothing
## authored on it still reports its quiet day, through
## [member quiet_result_text].
func _show_result(event: TravelEvent) -> void:
	var loading := get_node_or_null(loading_path)
	if loading == null or not loading.has_method(&"show_result"):
		return

	if event == null:
		loading.call(&"show_result", quiet_result_text, quiet_result_colour)
		return
	loading.call(&"show_result", event.get_result_text(), event.result_colour)


# --- Events on the road -------------------------------------------------------

## A gang: the road stops and the player is asked. A world with no screen to ask on
## rides past, which is the same answer as IGNORE and never strands the journey.
func _ask_about(event: TravelEvent) -> void:
	_state = State.IN_EVENT
	_conceal_loading()

	var screen := TravelEventMenu.get_active(self)
	if screen == null:
		_resume_road()
		return

	# One shot, and connected fresh each time: the answer belongs to this event, so
	# the binding is made here and dropped the moment it is given.
	screen.answered.connect(_on_event_answered.bind(event), CONNECT_ONE_SHOT)
	screen.ask(event)


func _on_event_answered(fight: bool, event: TravelEvent) -> void:
	if fight:
		_begin_encounter(event)
	else:
		_resume_road()


## A fight on the road.
##
## [b]It is the ordinary game, in the world the player was already standing in.[/b]
## The black is cleared, the world is handed back, and the enemies are built by the
## world's own [EnemySpawner]. There is no travel map, no travel enemy and no
## timer - and in particular no [WaveManager]: a fight on the road never starts a
## round, so what ends it is the last of them going down and nothing else.
##
## Which of two fights it is is the event's own answer:
##
##   * [b]An ambush[/b] - [member TravelEvent.uses_ambush_wave] - is handed to
##     [AmbushWaveDirector], which opens with men already standing in front of the
##     player and keeps them coming for about twenty seconds, as many as the
##     country is worth. See [method _begin_ambush].
##   * [b]Anything else[/b] is the plain encounter the road has always had:
##     [member TravelEvent.enemy_count] enemies placed off the edges of the view.
##     That is the gang, and none of the ambush machinery touches it.
func _begin_encounter(event: TravelEvent) -> void:
	_state = State.IN_EVENT
	_conceal_loading()

	if event.uses_ambush_wave and _begin_ambush():
		return

	var spawned := _spawn_encounter(event)
	if spawned <= 0:
		# Nothing to fight - no spawner, or an event authored with no enemies. The
		# road picks up rather than waiting on a fight that will never end.
		_resume_road()
		return

	_open_the_field()


## Hands the fight to the ambush system, and reports whether it took it.
##
## [b]The refusal matters more than the acceptance.[/b] A world with no ambush
## system, or one that has nothing to build enemies with, answers false here and
## the caller runs the plain encounter instead - so an ambush is never the reason a
## journey is left staring at a cleared screen with nothing on it. That is why the
## question is asked through [method AmbushWaveDirector.can_begin] before the world
## is handed back rather than after.
func _begin_ambush() -> bool:
	var director := get_node_or_null(ambush_path) as AmbushWaveDirector
	if director == null:
		director = AmbushWaveDirector.get_active(self)
	if director == null or not director.can_begin():
		return false

	if not director.cleared.is_connected(_on_ambush_cleared):
		director.cleared.connect(_on_ambush_cleared, CONNECT_ONE_SHOT)

	# Handed back first, so the opening group is placed into a world that is already
	# running and is revealed by the fade rather than appearing in front of the
	# player after it.
	_open_the_field()
	if director.begin(_destination_region()) > 0:
		return true

	# Nothing was built after all. The connection is dropped and the caller falls
	# through to the plain encounter, which will hand the field back again harmlessly.
	if director.cleared.is_connected(_on_ambush_cleared):
		director.cleared.disconnect(_on_ambush_cleared)
	return false


## The last of an ambush is down. The same beat and the same ending a plain
## encounter gets - see [method _on_encounter_death] - so how the fight was run
## makes no difference to how the road picks up.
func _on_ambush_cleared() -> void:
	if _state != State.IN_EVENT:
		return
	var timer := get_tree().create_timer(maxf(encounter_end_delay, 0.0), true, false, true)
	timer.timeout.connect(_end_encounter)


## Stops the ambush system putting anything more out, without reporting a fight
## that was never finished. Called whenever the road leaves an event behind it,
## however it left.
func _stop_ambush() -> void:
	var director := get_node_or_null(ambush_path) as AmbushWaveDirector
	if director == null:
		director = AmbushWaveDirector.get_active(self)
	if director == null:
		return
	if director.cleared.is_connected(_on_ambush_cleared):
		director.cleared.disconnect(_on_ambush_cleared)
	director.stop()


## The world handed back and the black cleared, which is the same two things
## however the fight about to happen is being run.
func _open_the_field() -> void:
	get_tree().paused = false
	var fade := ScreenFade.get_active(self)
	if fade != null:
		fade.fade_in(maxf(encounter_fade_time, 0.0))


## The part of the map the ride is heading into, which is what an ambush's size is
## read from. Null - a map that has not been divided up, or a journey with nowhere
## named at the end of it - is read as the quietest country there is.
func _destination_region() -> MapRegion:
	if _session == null or not _session.has_method(&"get_map"):
		return null
	var map := _session.call(&"get_map") as MapDefinition
	return null if map == null else map.find_region(get_destination())


## Builds the event's enemies and reports how many are actually standing.
##
## Each one is followed by its own death rather than by counting the group, so
## anything else that happens to be alive in the world - the enemy the scene was
## authored with, something left over from the round - is neither waited on nor
## cleared.
func _spawn_encounter(event: TravelEvent) -> int:
	var spawner := get_node_or_null(spawner_path) as EnemySpawner
	if spawner == null:
		push_warning("TravelDirector: no spawner to build a travel event with.")
		return 0

	_enemies_left = 0
	spawner.begin_batch()
	for index: int in range(maxi(event.enemy_count, 0)):
		var enemy := spawner.spawn()
		if enemy == null:
			continue
		var health := _find_health(enemy)
		if health == null:
			continue
		_enemies_left += 1
		health.died.connect(_on_encounter_death, CONNECT_ONE_SHOT)
	return _enemies_left


## The player's own health is deliberately not looked at here. Dying on the road is
## the player's death sequence exactly as it is in the arena, and it carries them
## home; what the road does about it is [method _on_player_died], which follows that
## same pool by group rather than by walking a body's children.
func _find_health(enemy: Node) -> Health:
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


func _on_encounter_death() -> void:
	if _state != State.IN_EVENT:
		return

	_enemies_left -= 1
	if _enemies_left > 0:
		return

	# A beat to watch the last one go down before the black comes back.
	var timer := get_tree().create_timer(maxf(encounter_end_delay, 0.0), true, false, true)
	timer.timeout.connect(_end_encounter)


## The fight is over. Back to black, and on with the journey from the next day -
## [b]the same journey[/b]: nothing about where the player is going, how many days
## are left or what they are carrying is touched here.
func _end_encounter() -> void:
	if not is_inside_tree() or _state != State.IN_EVENT:
		return

	var fade := ScreenFade.get_active(self)
	if fade == null:
		_resume_road()
		return
	fade.fade_out(maxf(encounter_fade_time, 0.0), _resume_road)


## [b]A death on the road ends the road.[/b] Dying is the player's own death sequence
## exactly as it is in the arena and it carries them home to the base - so without
## this the journey is left standing in every one of its parts: the ambush going on
## placing men around a body that is no longer there, the black or the day's stop
## still up over a player being put back together several thousand pixels away, the
## game still running at fast travel's speed, and the session still claiming somebody
## is on the road - which is a dead TRAVEL button for the rest of the game, because
## [method RunSessionState.begin_travel] refuses a journey that is already under way.
##
## [b]Nothing here is new machinery.[/b] Each line is the same call the road already
## makes when it leaves that part of itself behind - the ambush stopped as
## [method _resume_road] stops it, the dial handed back as [method _arrive] hands it
## back, the ride taken off the screen through the presentation's own
## [method TravelLoading.stop], and the journey put back through
## [method RunSessionState.abandon_travel], which is exactly what backing out of the
## travel screen does.
##
## [signal travel_cancelled] is deliberately [i]not[/i] emitted. That signal means the
## player changed their mind and is standing at the waggon again - [CampMenu] puts its
## own panel back up on it - and a man being carried home dead is not standing
## anywhere. The destination is left marked, so the ride is still there to be taken
## when the next run reaches this region.
func _on_player_died() -> void:
	if _state == State.IDLE:
		return

	# Put back first, so nothing below can be read as a journey still under way - the
	# travel screen closing calls [method cancel], which is a no-op once this is IDLE.
	_state = State.IDLE
	_drop_player_death()

	_release_ambush()
	_set_hurrying(false)
	_close_day_stop()
	_close_travel_screen()
	_stop_loading()
	get_tree().paused = false
	_abandon_on_session()


## The road stops listening for the end of a fight it will never see, and leaves the
## ambush itself alone.
##
## [b]It is deliberately not [method _stop_ambush].[/b] The ambush has its own answer to
## the player going down - the men still standing break and run, see
## [method AmbushWaveDirector._on_player_died] - and stopping it here would take that
## answer away, because [method AmbushWaveDirector.stop] drops the very death watch that
## would have played it. Whichever of the two handlers the signal reaches first, the
## field empties.
##
## Dropping [signal AmbushWaveDirector.cleared] matters just as much: the men leaving
## will report the ambush cleared, and the road must not read that as a fight it
## survived and pick itself back up around a player who is no longer there.
func _release_ambush() -> void:
	var director := get_node_or_null(ambush_path) as AmbushWaveDirector
	if director == null:
		director = AmbushWaveDirector.get_active(self)
	if director != null and director.cleared.is_connected(_on_ambush_cleared):
		director.cleared.disconnect(_on_ambush_cleared)


## The travel screen taken down, if one is still up. It reports a confirmation by
## hiding rather than closing, so on most of the road there is nothing to do here.
func _close_travel_screen() -> void:
	if _menu != null and is_instance_valid(_menu) and _menu.has_method(&"close"):
		_menu.call(&"close")


## The ride itself taken off the screen, through the presentation's own way back.
func _stop_loading() -> void:
	var loading := get_node_or_null(loading_path)
	if loading != null and loading.has_method(&"stop"):
		loading.call(&"stop")


func _follow_player_death() -> void:
	_drop_player_death()
	_player_health = get_tree().get_first_node_in_group(health_group) as Health
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their death -
## they are revived into the same [Health] - so a connection left behind would still be
## listening at the journey after next.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


## Back onto the road after an event, however it ended. The world is frozen again,
## because the rest of the journey is made behind the black.
##
## The ambush system is stopped on the way past rather than trusted to have
## finished: a fight the player walked out of - riding past a gang, an event that
## could not be built - must not leave anything still placing enemies behind the
## black.
func _resume_road() -> void:
	if not is_inside_tree():
		return

	_stop_ambush()
	get_tree().paused = true
	_state = State.ON_THE_ROAD
	# The day the event happened on is over, so the road stops at the same screen a
	# quiet day stops at - with the horse still standing where the trouble stopped it.
	_day_over()


## Every day has been spent and nothing is left on the road. The clock is moved and
## the destination reached by exactly the call that always made the arrival.
##
## [b]The days are spent once, here, at the end.[/b] An event holds the road up but
## does not cost a day of its own and does not touch the hour, so a four-day journey
## with an ambush on it advances the clock by four exactly as a quiet one does -
## there is no second place a day can be counted.
func _finish_ride() -> void:
	_state = State.DEPARTING
	_arrive(_days_total)


## Arriving. The session is what turns the marked destination into the region and
## spends the days on the clock - see [method RunSessionState.complete_travel] -
## and the world is then rebuilt around both answers, opening black and clearing
## itself so nothing is seen being taken apart.
##
## Everything the player is carrying comes through untouched, for the reason it
## always has: blood, ammunition, contracts and what is known about them are all
## autoloads, and a rebuild does not touch those - so the health, blood and
## ammunition an ambush left the player with are what they arrive holding.
func _arrive(days: int) -> void:
	if not is_inside_tree():
		return

	# The ride is over, so the game goes back to its ordinary speed before anything
	# is rebuilt around it, and the road stops listening for a death it can no longer
	# be the one to put back.
	_set_hurrying(false)
	_drop_player_death()

	if _session != null and _session.has_method(&"complete_travel"):
		_session.call(&"complete_travel", days)

	# The arrival itself has happened by here - the clock has moved and the region
	# has changed. Only the rebuild is optional, so a harness with
	# [member reload_scene] off sees the whole journey take effect without its world
	# being pulled out from under it.
	if not reload_scene:
		_state = State.IDLE
		get_tree().paused = false
		return

	ScreenFade.request_fade_in_after_reload(fade_in_time)
	get_tree().paused = false
	get_tree().reload_current_scene()
