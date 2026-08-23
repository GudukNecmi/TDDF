class_name SleepDirector
extends Node
## A night at the camp: the player lies down where they are standing and the desert
## goes on turning without them.
##
## [b]Nothing is rebuilt and nowhere is gone to.[/b] Sleeping used to be the round
## button wearing another name - it advanced the round counter and reloaded the world,
## which is why the hour moved. This does not: the player stays in the region they are
## already in, on the ground the map already drew, beside the waggon that is already
## standing there, and the only thing that changes is the time of day.
##
## [b]What changes is what the player is looking at.[/b] The night is played out on a
## screen of its own - [SleepMenu], the third of the game's full-screen presentations
## after the journey and the walk out to a Danger - showing the man lying down, the
## letters coming off him and the region's own ground behind them, with the map, the
## waggon and every piece of camp interface out of sight behind it. The world itself
## is untouched underneath, which is the whole reason a night broken into is fought at
## the exact spot the player lay down: taking the screen away [i]is[/i] the return to
## the camp.
##
## The night, and each step's owner:
##
##   [codeblock]
##   SLEEP  ->  lie down  ->  HOW LONG?  ->  segment, segment...  ->  awake
##   CampMenu   PlayerSleep    SleepMenu        this file           this file
##   [/codeblock]
##
##   * [b]Lying down.[/b] [PlayerSleep], on the player scene, which pins them through
##     the player's own speed seam and turns the body over the way a death does.
##     Nothing here knows what the player looks like.
##   * [b]How long.[/b] Up to [member max_segments] of the map's own hours, chosen on
##     [SleepMenu]. WAKE UP is on that screen from the first frame, so the choice can
##     always be abandoned.
##   * [b]Each segment.[/b] [member segment_time] real seconds, and then exactly one
##     stage on the run's clock - through [method RunSessionState.advance_days], which
##     is the same call a day of the road and a cleared Danger spend their hours with.
##     The world's darkness, the HUD's icon and the next card follow it without being
##     told, because [DayCycleDirector] is already listening to that clock. [b]A
##     segment is not a day and not a round[/b]: the round counter is deliberately
##     untouched.
##   * [b]What the night holds.[/b] One roll per segment against the same table of
##     [TravelEvent]s the road is ridden through - see [member sleep_events] - and
##     anything that is not a quiet day is an ambush, fought by [AmbushWaveDirector]:
##     the same fight, the same enemies, the same ending. Being jumped asleep is not a
##     question, so an event that would have offered the road a choice does not offer
##     one here.
##   * [b]The man on the poster.[/b] Between segments the boss system is asked whether
##     one of the player's contracts now points at this map, this region and this hour
##     - see [method MiniBossDirector.can_begin], which is the game's one answer to
##     "is he here". If it does, the night stops and the player is asked whether they
##     want to get up for him. Nothing about bounties, their hours or their difficulty
##     is decided here.
##
## [b]Every way out is the same way out.[/b] Waking early, sleeping the whole night,
## the four-segment limit, an ambush, a bounty and a death all end at
## [method _end_sleep]: the player gets up, the timers are made unreachable, the
## screen comes down and the time scale is put back. There is no path that leaves half
## a night standing.

## Emitted as the player lies down, before they have chosen how long for.
signal sleep_started()
## Emitted once a length has been picked, with how many segments it is.
signal duration_chosen(segments: int)
## Emitted as each segment finishes and the clock moves, with how many have been
## slept and how many were asked for.
signal segment_advanced(slept: int, wanted: int)
## Emitted when the night is stopped for a contract, before the player is asked.
signal bounty_found(bounty: Bounty)
## Emitted however the night ends, with why - one of the REASON constants - and how
## many segments were actually slept. [b]This is what a system putting the world back
## should listen to[/b], because it fires on every exit including a death.
signal sleep_ended(reason: StringName, slept: int)

## Group the director joins, so anything can find it without a path.
const GROUP := &"sleep_director"

## Why a night ended. Handed out with [signal sleep_ended] so a listener can tell the
## four apart without reading this file's state.
## The player pressed WAKE UP.
const REASON_WOKE := &"woke"
## The chosen number of segments was slept.
const REASON_SLEPT := &"slept"
## The most a night can hold was reached - see [member max_segments].
const REASON_LIMIT := &"limit"
## Something came out of the dark.
const REASON_AMBUSH := &"ambush"
## The player got up to go after a contract.
const REASON_BOUNTY := &"bounty"
## The player was killed. Nothing in an untroubled night can do this; it is here so a
## death arriving from anywhere cannot leave a sleeper on the ground.
const REASON_LOST := &"lost"

## Which step of the night is being played. One flag's worth of state per step, like
## every other director here.
enum State {
	## Nobody is asleep. Every ordinary moment.
	IDLE,
	## Lying down, picking how long for.
	CHOOSING,
	## Asleep, with a segment running.
	SLEEPING,
	## Stopped part way through and asking about a contract.
	ASKING,
	## Something has come out of the dark and the word is on the sleep screen, a beat
	## before the fight. [b]Nothing can be chosen from here[/b] - WAKE UP is refused,
	## because the night is already over and only the announcement is still running.
	ALARMED,
}

## The run's own state - the [code]RunSession[/code] autoload. Asked to spend the
## hours and asked which part of the map the night is happening in.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Nodes")
## The screen the length is picked on and WAKE UP lives on. Without one there is
## nowhere to choose or to wake, so SLEEP does nothing at all rather than putting the
## player down with no way up.
@export var menu_path: NodePath = ^"../RunHUD/SleepMenu"
## The two-button screen the contract question is asked on, borrowed from the road's
## gangs. Optional; a world with none simply never stops the night for a bounty.
@export var question_path: NodePath = ^"../RunHUD/TravelEventMenu"
## The HUD panel the character's own line is printed on at the end of a full night -
## the same one every piece of contract news already goes out on.
@export var notice_path: NodePath = ^"../RunHUD/KnowledgeNotice"
## The ambush system a disturbed night is fought through. [b]There is no sleep enemy
## and no second wave director.[/b]
@export var ambush_path: NodePath = ^"../AmbushDirector"
## The boss system, asked whether a contract points at this place and this hour, and
## handed the encounter when the player gets up for it.
@export var boss_path: NodePath = ^"../MiniBossDirector"
## The road, read for its own table of events when this node has none of its own -
## see [member sleep_events]. Nothing about a journey is touched.
@export var travel_path: NodePath = ^"../TravelDirector"
## The camp's panel, put back up when a night ends of its own accord - see
## [member reopens_camp].
@export var camp_menu_path: NodePath = ^"../RunHUD/CampMenu"
## Group the player's health is found in, so a death ends the night rather than
## leaving a body asleep on the floor.
@export var health_group: StringName = &"player_health"

@export_group("The night")
## How long one segment lasts, in real seconds.
##
## [b]Real seconds, not game ones[/b] - the wait is taken outside the time scale and
## outside the tree's pause, so a night is the same length whatever else has happened
## to the clock.
@export var segment_time: float = 5.0
## The most segments one night may hold. Four, and it is also the longest the player
## may ask for: the chooser is built from this number, so raising it is one field.
@export var max_segments: int = 4
## How many of the map's hours one segment costs. 1 is the next hour along, which is
## the rule as written - a segment is a stage, not a day.
@export var stages_per_segment: int = 1

@export_group("What the night holds")
## The table rolled once per segment. Left empty - which is the default - the road's
## own [member TravelDirector.travel_events] is used, so the country is exactly as
## dangerous asleep as it is on the way through it and there is one table to tune.
##
## Filling this in gives the night its own odds without touching the road.
@export var sleep_events: Array[TravelEvent] = []
## How likely a segment is to roll the table at all, as a fraction. 1 rolls every
## segment, which leaves the odds entirely to the weights on the events themselves;
## lower makes for quieter nights without any event being reweighted.
@export_range(0.0, 1.0, 0.01) var event_chance: float = 1.0
## Whether anything the table turns up actually wakes the player.
@export var events_wake_the_player: bool = true
## The word thrown up on the sleep screen when the night is broken into, held for
## [member ambush_hold] before the screen comes down on the fight.
##
## [b]It is announced on the screen and fought in the world.[/b] The player is told
## while they are still lying down and still looking at the night; only then is the
## screen taken away, and what is behind it is the camp they actually fell asleep at -
## the waggon, the region's own ground and everything else that was already standing
## there. Nothing is built and nowhere is gone to, which is why there is no sleep
## fight and no second map: see [method _spring_the_ambush].
@export var ambush_text: String = "AMBUSH"
@export var ambush_colour := Color(0.82, 0.1, 0.1)
## How long that word is left up before the night is handed back, in seconds.
@export var ambush_hold: float = 1.1

@export_group("Bounties")
## Whether the night watches for a contract's hour coming round.
@export var watches_bounties: bool = true
## Whether the same contract may stop the same night twice. Off - the default - a
## player who chose to sleep through a man is not asked about him again until they
## next lie down.
@export var asks_once_per_contract: bool = true

@export_group("Wording")
## The heading over the contract question. The name off the poster is substituted in.
@export var bounty_title_format: String = "%s"
## The line under it.
@export var bounty_description: String = "O ŞEREFSİZ ŞİMDİ BURADA."
## The button that goes back to sleep.
@export var bounty_stay_text: String = "UYUMAYA DEVAM ET"
## The button that gets up after him.
@export var bounty_leave_text: String = "ÇIK, O ŞEREFSİZE GÜNÜNÜ GÖSTER"
## What an outlaw with no name on his poster is called.
@export var unknown_target_name: String = "THE OUTLAW"
## What the character says when the night has run as long as a night can.
@export var limit_line: String = "Uykumu kaçırdı şerefsizler."
## Whether that line is printed at all.
@export var shows_limit_line: bool = true
## The word over it on the HUD's notice panel. That panel is shared - it is where
## every piece of contract news arrives - so the night says what it is rather than
## speaking under KNOWLEDGE. Empty leaves the panel's own heading standing.
@export var limit_line_heading: String = "SLEEP"

@export_group("Waking")
## Whether the camp's own panel is put back up when a night ends of its own accord -
## the player waking early, or the limit being reached.
##
## [b]It is never put up after a fight or a hunt.[/b] Those two end the night by
## handing the world back, and a panel over a fight that is already starting would be
## exactly the wrong thing.
@export var reopens_camp: bool = true
## Beat between the night ending and that panel arriving, in seconds, so the player is
## seen to get up first.
@export var camp_delay: float = 0.9
## The same beat on the night that ran its full length, where there is a line to read
## first.
##
## [b]It is longer because the camp panel is drawn over the top of everything.[/b] The
## character's line goes out on the HUD's own notice, and a camp put back up
## underneath it would simply hide it - so the line is given time to be read and the
## panel follows it. Held to the notice's own hold, near enough, rather than being
## tied to it: the two are tuned in their own inspectors.
@export var line_delay: float = 3.6
## Whether the time scale is written back to 1 on every way out. It is not changed
## anywhere in a night, so this is a guarantee rather than a repair - and it is what
## makes a night that ended under somebody else's slow motion still hand back a world
## running at its ordinary speed.
@export var restores_time_scale: bool = true

var _session: Node
var _state: State = State.IDLE
## How many segments the player asked for, and how many have actually passed.
var _wanted: int = 0
var _slept: int = 0
## Bumped on every change of state. Every timer a night is made of carries the value
## it was started under and does nothing if it no longer matches, which is the whole
## of "no old wake timer can trigger later" - a [SceneTreeTimer] cannot be cancelled,
## so it is made unreachable instead.
var _token: int = 0
## Contracts already asked about tonight - see [member asks_once_per_contract].
var _asked: Array[StringName] = []
## The player's own pool, followed only while somebody is asleep.
var _player_health: Health


func _enter_tree() -> void:
	add_to_group(GROUP)
	_session = get_node_or_null(session_path)


## The sleep system in this world, or null when it has none - which the camp reads as
## "there is nowhere to sleep here" and falls back to what SLEEP did before.
static func get_active(from_node: Node) -> SleepDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as SleepDirector


func get_state() -> State:
	return _state


## Whether the player is asleep - choosing, sleeping or being asked about a contract.
## [b]Read by [Camp][/b], which refuses to be used at all while it is true, so none of
## the camp's actions can be reached from inside a night.
func is_sleeping() -> bool:
	return _state != State.IDLE


## How many segments have passed tonight.
func get_segments_slept() -> int:
	return _slept


## How many were asked for. 0 before the length has been chosen.
func get_segments_wanted() -> int:
	return _wanted


## The most that may be asked for, which is what the chooser is built from.
func get_max_segments() -> int:
	return maxi(max_segments, 1)


# --- Lying down ------------------------------------------------------------------

## Puts the player down and raises the chooser. Reports whether the night began, so a
## caller can fall back on its own behaviour when it did not.
##
## A false answer is not an error to hide: a night already under way, no screen to
## choose on, or no sleeper to put down are all "this world cannot sleep", and nothing
## is changed on the way out.
func begin() -> bool:
	if _state != State.IDLE:
		return false

	var menu := _resolve_menu()
	var sleeper := PlayerSleep.get_active(self)
	if menu == null or sleeper == null:
		return false

	_state = State.CHOOSING
	_renew()
	_wanted = 0
	_slept = 0
	_asked.clear()
	_follow_player_death()

	sleeper.lie_down()
	menu.open_for(self)
	sleep_started.emit()
	return true


## Sets how long the night is to be and starts it. Held to [member max_segments], so
## the ceiling is enforced here rather than trusted to whoever is asking.
func choose_duration(segments: int) -> bool:
	if _state != State.CHOOSING:
		return false

	_wanted = clampi(segments, 1, get_max_segments())
	duration_chosen.emit(_wanted)
	_refresh_menu()
	_schedule_segment()
	return true


## WAKE UP. Ends the night on the spot [b]without spending another segment[/b] - the
## timer that was running is left to fire into nothing.
##
## A night already broken into is refused: the announcement is running, the fight is
## a beat away and there is no longer a night to get up from.
func wake_up() -> void:
	if _state == State.IDLE or _state == State.ALARMED:
		return
	_end_sleep(REASON_WOKE)


# --- The segments ------------------------------------------------------------------

## The wait, made unreachable rather than cancellable. Real time and process-always,
## so a night still passes through anything that freezes or slows the world.
func _schedule_segment() -> void:
	_state = State.SLEEPING
	var token := _renew()
	var timer := get_tree().create_timer(maxf(segment_time, 0.05), true, false, true)
	timer.timeout.connect(_on_segment_elapsed.bind(token))


## One segment is over: the clock moves, and then the night is asked whether it can
## carry on.
##
## The order is the point. The hour is spent first, so anything looking at the world
## after this - the roll below, the boss system's idea of what time it is - is looking
## at the hour the player has actually slept into.
func _on_segment_elapsed(token: int) -> void:
	if token != _token or _state != State.SLEEPING or not is_inside_tree():
		return

	_slept += 1
	_advance_the_day()
	segment_advanced.emit(_slept, _wanted)
	_refresh_menu()

	# A fight first and a question second: being jumped is not something the player
	# gets to weigh, and it ends the night either way.
	if _trouble_takes_the_night():
		return
	if _bounty_stops_the_night():
		return

	if _slept >= get_max_segments():
		_end_sleep(REASON_LIMIT)
		return
	if _slept >= _wanted:
		_end_sleep(REASON_SLEPT)
		return

	_schedule_segment()


## One hour of the map's own, spent through the run rather than written onto the
## clock here.
##
## [method RunSessionState.advance_days] asks the map how many stages it divides its
## day into and hands the answer to [DayClock], which is the one thing in the game
## that knows what time it is - so a slept segment moves the hour by exactly the
## arithmetic a ridden day and a cleared Danger move it by.
func _advance_the_day() -> void:
	if stages_per_segment <= 0:
		return
	if _session == null or not _session.has_method(&"advance_days"):
		return
	_session.call(&"advance_days", stages_per_segment)


# --- What the night held -----------------------------------------------------------

## Whether something came out of the dark, and was actually built.
##
## [b]The refusal matters more than the acceptance.[/b] A quiet roll, a world with no
## ambush system and an ambush that could not be built all answer false and the night
## carries on - so a fight can never be the reason a player is left lying on the
## ground with nothing happening.
func _trouble_takes_the_night() -> bool:
	if not events_wake_the_player:
		return false
	if event_chance < 1.0 and randf() > event_chance:
		return false

	var event := TravelEvent.roll(_event_table())
	if event == null or event.is_quiet():
		return false

	var director := _resolve_ambush()
	if director == null or not director.can_begin():
		return false

	# The word goes up on the screen the player is watching the night on, and the
	# night is not actually left until they have read it.
	_state = State.ALARMED
	var token := _renew()
	_announce_ambush()

	var timer := get_tree().create_timer(maxf(ambush_hold, 0.0), true, false, true)
	timer.timeout.connect(_spring_the_ambush.bind(token))
	return true


## The word itself, said on the sleep screen where the player is already looking.
## A world whose screen has nowhere to write it simply goes straight to the fight.
func _announce_ambush() -> void:
	var menu := _resolve_menu()
	if menu != null:
		menu.announce(ambush_text, ambush_colour)


## The screen comes down on the camp the player fell asleep at, and the ambush opens
## in it.
##
## [b]Nothing is built and nowhere is gone to.[/b] The night was never a place - the
## player has been lying at the waggon in their own region the whole time, with only
## a screen in front of them - so taking that screen away [i]is[/i] the return to the
## camp, and the fight happens at the exact spot they lay down in, on the map's own
## ground, beside the waggon that is already standing there.
##
## The night is ended before a man is placed, so the ambush opens around a player who
## is already on their feet and already in control. [b]It does not resume afterwards[/b]:
## the night is over as far as this node is concerned, and lying down again is the
## player walking back to the waggon and pressing SLEEP.
func _spring_the_ambush(token: int) -> void:
	if token != _token or _state != State.ALARMED or not is_inside_tree():
		return

	_end_sleep(REASON_AMBUSH)
	var director := _resolve_ambush()
	if director != null:
		director.begin(_current_region())


## The table rolled against: this node's own where it has one, and the road's
## otherwise, so there is one set of odds for the country rather than two.
func _event_table() -> Array[TravelEvent]:
	if not sleep_events.is_empty():
		return sleep_events
	var road := get_node_or_null(travel_path) as TravelDirector
	if road == null:
		road = TravelDirector.get_active(self)
	return [] if road == null else road.travel_events


## Whether one of the player's contracts has come round, and the player is being
## asked about it.
##
## [b]Nothing about bounties is decided here.[/b]
## [method MiniBossDirector.can_begin] is the game's one answer to "is the man on one
## of my posters in this map, this region and this hour, and can he be built" - it
## reads the ledger and reads the clock through [RunSessionState] - so the night stops
## for exactly the situations an ordinary round would have opened on him in.
func _bounty_stops_the_night() -> bool:
	if not watches_bounties:
		return false

	var boss := _resolve_boss()
	if boss == null or not boss.can_begin():
		return false

	var bounty := boss.find_contract()
	if bounty == null:
		return false
	if asks_once_per_contract and _asked.has(bounty.bounty_id):
		return false

	var screen := _resolve_question()
	if screen == null or screen.is_open():
		return false

	# Made unreachable before the question goes up, so the segment that was running
	# cannot land behind the screen.
	_state = State.ASKING
	_renew()
	_asked.append(bounty.bounty_id)
	# Paused rather than taken down: the man is still lying in his own region behind
	# the question, so continuing puts the controls back on a night that never left
	# the screen rather than raising a second one.
	_pause_menu()

	bounty_found.emit(bounty)
	screen.answered.connect(_on_bounty_answered, CONNECT_ONE_SHOT)
	screen.ask_choice(
		bounty_title_format % _poster_name(bounty),
		bounty_description,
		bounty_stay_text,
		bounty_leave_text)
	return true


## [param leave] is the right-hand button - getting up after him.
func _on_bounty_answered(leave: bool) -> void:
	if _state != State.ASKING:
		return

	if not leave:
		_resume_after_question()
		return

	_end_sleep(REASON_BOUNTY)
	# The existing encounter, asked for exactly as a world coming up on a boss day asks
	# for it: he is placed somewhere in this region, the player is told he is nearby and
	# the arrow points at him. The fight is still a walk away.
	var boss := _resolve_boss()
	if boss != null:
		boss.begin()


## Back to sleep from where the question stopped it - the segments already slept are
## kept, so continuing does not start the night again.
func _resume_after_question() -> void:
	var menu := _resolve_menu()
	if menu != null:
		menu.open_for(self)
	_refresh_menu()

	if _slept >= get_max_segments():
		_end_sleep(REASON_LIMIT)
		return
	if _slept >= _wanted:
		_end_sleep(REASON_SLEPT)
		return
	_schedule_segment()


# --- Waking --------------------------------------------------------------------------

## The one way out, whichever of the six it was.
##
## Everything a night owns is put back here and nowhere else: the timers are made
## unreachable, the player is stood up, the screen comes down, the death watch is
## dropped and the time scale is written back. A second call on an already-woken
## sleeper does nothing, so a death arriving on the same frame as a wake-up cannot
## unwind the night twice.
func _end_sleep(reason: StringName) -> void:
	if _state == State.IDLE:
		return

	_state = State.IDLE
	_renew()
	_drop_player_death()
	_hide_menu()

	var sleeper := PlayerSleep.get_active(self)
	if sleeper != null:
		sleeper.get_up()

	if restores_time_scale:
		Engine.time_scale = 1.0

	sleep_ended.emit(reason, _slept)

	var spoke := reason == REASON_LIMIT and shows_limit_line
	if spoke:
		_say(limit_line)
	# Only the two endings the player is standing still for. A fight and a hunt hand
	# the world back and must not be covered by a panel.
	if reopens_camp and (reason == REASON_WOKE or reason == REASON_SLEPT
			or reason == REASON_LIMIT):
		_raise_camp_later(line_delay if spoke else camp_delay)


## The camp put back up a beat later, so the player is seen to get up first. Carried
## on the same token as everything else, so a night that has started again in the
## meantime - or a world torn down - cannot be interrupted by it.
func _raise_camp_later(delay: float) -> void:
	var token := _token
	var timer := get_tree().create_timer(maxf(delay, 0.0), true, false, true)
	timer.timeout.connect(_raise_camp.bind(token))


func _raise_camp(token: int) -> void:
	if token != _token or _state != State.IDLE or not is_inside_tree():
		return
	var camp := _resolve_camp_menu()
	if camp != null and not camp.is_open():
		camp.open()


## [b]A death ends the night.[/b] Dying is the player's own death sequence and it
## carries them home, so without this the sleeper would be stood up in the middle of
## it and a wake timer would still be counting down over the body.
func _on_player_died() -> void:
	_end_sleep(REASON_LOST)


func _follow_player_death() -> void:
	_drop_player_death()
	_player_health = get_tree().get_first_node_in_group(health_group) as Health
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their death -
## they are revived into the same [Health] - so a connection left behind would still be
## listening at the night after next.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


# --- Looking things up -----------------------------------------------------------------

## Every timer started from now on carries this number, and every one started before it
## is now unreachable.
func _renew() -> int:
	_token += 1
	return _token


func _refresh_menu() -> void:
	var menu := _resolve_menu()
	if menu != null:
		menu.refresh()


func _hide_menu() -> void:
	var menu := _resolve_menu()
	if menu != null:
		menu.close()


## The controls off, the night still on screen. See [method SleepMenu.pause_for_question].
func _pause_menu() -> void:
	var menu := _resolve_menu()
	if menu != null:
		menu.pause_for_question()


## The character's own line, printed on the HUD panel every other piece of news goes
## out on rather than on a second one written for the night.
func _say(line: String) -> void:
	if line.is_empty():
		return
	var notice := get_node_or_null(notice_path)
	if notice == null or not notice.has_method(&"show_message"):
		return
	notice.call(&"show_message", line, limit_line_heading)


## What the poster calls him, falling back so a contract with no outlaw on it still
## produces a name rather than a gap.
func _poster_name(bounty: Bounty) -> String:
	if bounty == null or bounty.target == null or bounty.target.display_name.is_empty():
		return unknown_target_name
	return bounty.target.display_name


## The part of the map the night is happening in, asked of the session so there is no
## second copy of where the run currently is.
func _current_region() -> MapRegion:
	if _session == null or not _session.has_method(&"get_region"):
		return null
	return _session.call(&"get_region") as MapRegion


func _resolve_menu() -> SleepMenu:
	var named := get_node_or_null(menu_path) as SleepMenu
	return named if named != null else SleepMenu.get_active(self)


func _resolve_question() -> TravelEventMenu:
	var named := get_node_or_null(question_path) as TravelEventMenu
	return named if named != null else TravelEventMenu.get_active(self)


func _resolve_ambush() -> AmbushWaveDirector:
	var named := get_node_or_null(ambush_path) as AmbushWaveDirector
	return named if named != null else AmbushWaveDirector.get_active(self)


func _resolve_boss() -> MiniBossDirector:
	var named := get_node_or_null(boss_path) as MiniBossDirector
	return named if named != null else MiniBossDirector.get_active(self)


func _resolve_camp_menu() -> CampMenu:
	var named := get_node_or_null(camp_menu_path) as CampMenu
	return named if named != null else CampMenu.get_active(self)


## Nothing is left asleep behind us: a world torn down mid-night - a death, a reload -
## would otherwise hand the next one a player who cannot move.
func _exit_tree() -> void:
	if _state == State.IDLE:
		return
	_state = State.IDLE
	_renew()
	_drop_player_death()
	if restores_time_scale:
		Engine.time_scale = 1.0
