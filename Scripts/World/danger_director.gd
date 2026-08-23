class_name DangerDirector
extends Node
## Looking for trouble, and what looking for it costs: one Danger after another,
## each already happening by the time the screen clears.
##
## [b]A Danger is not a place.[/b] Nothing is instanced and nothing is rebuilt - the
## fight happens in the map the player was already standing in, which is now the
## size of the mini boss's arena, with the camera following them normally and the
## walls where they have always been. What separates one Danger from the next is a
## few seconds of black with a cart crossing it, and that is the whole of the
## journey.
##
## The loop, and each step's owner:
##
##   [codeblock]
##   TROUBLE  ->  the walk  ->  DANGER n  ->  three in four down  ->  CONTINUE / STOP
##     Camp      TravelLoading  AmbushWaveDirector    this file       TravelEventMenu
##   [/codeblock]
##
##   * [b]Setting out.[/b] The waggon's own search state is what starts this - see
##     [method Camp.begin_trouble_search] - so pressing TROUBLE in the camp is
##     unchanged and this hangs off the signal that state has always emitted.
##   * [b]The walk.[/b] [member transition_time] seconds of the same crossing over
##     the same black a day of travel is ridden behind, with the next Danger's
##     number written on it - [b]on foot, with no horse in it[/b], because looking
##     for trouble is what sent the animal away. In its last beat the encounter
##     announces itself as [member found_text], exactly where a day of the road says
##     "AMBUSH!". The world is frozen behind all of it and the encounter is opened
##     [i]before[/i] the black clears, so the men are already standing there on the
##     first frame the player can see.
##   * [b]The card.[/b] As the black lifts, the run's own opening card names where
##     and when this is - the map, the place, the hour and the clock - over a world
##     in slow motion, which is the round intro asked to play again rather than a
##     second card written for trouble. See [method _play_location_card].
##   * [b]The fight.[/b] Handed whole to [AmbushWaveDirector], which is the fight
##     the road already has: an opening group placed in view, the rest arriving just
##     off the edge of the screen, built by the world's own [EnemySpawner]. There is
##     no Danger enemy and no Danger AI - all this decides is how many and how tough.
##   * [b]The ending.[/b] Every man has to be killed. Trouble is the one encounter with
##     no breaking point in it - [member rout_fraction] is 0, which is the ambush's own
##     rout asked for and turned off, see [method AmbushWaveDirector.begin_with] - so
##     the Danger is over when the last of them goes down rather than when enough of
##     them have. Clearing one costs an hour - see [method _owe_the_day] - so a long
##     search is paid for on the same clock a day of riding is, and the hour turns over
##     on the dial in the middle of the next walk rather than the instant it is owed.
##   * [b]The decision.[/b] CONTINUE or STOP, asked on the two-button screen the road
##     already asks gangs with. CONTINUE walks on to the next Danger; STOP leaves the
##     player standing in the world with the waggon still in its search state, which
##     is exactly where they were before this milestone existed.
##
## [b]How hard a Danger is comes from two places and neither is a threshold here.[/b]
## Where the player is standing is read as [method MapRegion.get_difficulty], the
## same 0-to-1 fraction an ambush on the road is sized from, so region A is the
## quietest trouble there is and the map's deepest corner is the worst; and how deep
## into this search they have gone is the Danger number, compounded off it. Both
## reach the enemies through numbers that already exist -
## [member RoundScaling.extra_health_multiplier] for how tough they are, and a count
## handed to the ambush for how many - so there is no second difficulty curve
## anywhere in this file and the campaign's own round scaling is still underneath
## every one of them.
##
## [b]What this milestone deliberately does not do:[/b] there is no chest, no
## reward, no horse arriving and no ride back to the camp. STOP ends the sequence
## and hands the world back, and the way home is the waggon exactly as it already
## was.

## Emitted as the player sets out and the first walk begins.
signal sequence_started()
## Emitted as a Danger opens, with its number and how many enemies it is worth.
signal danger_started(number: int, enemy_count: int)
## Emitted when a Danger is over - the rest having broken and got away - and before
## the player is asked what they want to do about it.
signal danger_cleared(number: int)
## Emitted as the search stops, with how many Dangers were cleared in it. This one
## fires however it ended, [b]including a death[/b], so it is what a system putting
## the world back should listen to.
signal sequence_ended(dangers_cleared: int)
## Emitted only when a search is [b]finished[/b] rather than merely ended: the player
## chose STOP, or the last Danger was cleared. [param highest_danger] is the deepest
## one actually beaten.
##
## [b]A death is not a finish[/b] and never emits this - which is what stops a reward
## being owed for a search the player did not walk away from. See [TroubleRewardDirector].
signal search_finished(dangers_cleared: int, highest_danger: int)

## Group the director joins, so anything can find it without a path.
const GROUP := &"danger_director"

## Which step of the search is being played out. One flag's worth of state per step,
## like every other director here: each is entered once, in order, and the only
## thing any of them is asked is which one is current.
enum State {
	## Nobody is out looking. Every ordinary round.
	IDLE,
	## The black is up and the walk to the next Danger is being made.
	WALKING,
	## A Danger is being fought.
	FIGHTING,
	## It is over and the player is being asked whether they want more.
	DECIDING,
}

## The run's own state - the [code]RunSession[/code] autoload. Asked which part of
## the map the player is standing in, which is half of how hard a Danger is.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Nodes")
## The ambush system every Danger is fought through. [b]There is no Danger enemy and
## no second wave director[/b] - see [AmbushWaveDirector]. Left unresolved, TROUBLE
## puts the waggon into its search state and nothing else happens, which is the game
## exactly as it was before this existed.
@export var ambush_path: NodePath = ^"../AmbushDirector"
## The cart crossing the black, borrowed from travel for the walk between Dangers.
## Optional - without one the walk is the same length of plain black.
@export var loading_path: NodePath = ^"../RunHUD/TravelLoading"
## The two-button screen CONTINUE / STOP is asked on, borrowed from the road's gangs.
## Optional, but a world without one cannot ask - so the search stops after its first
## Danger rather than looping on a question nobody was given.
@export var question_path: NodePath = ^"../RunHUD/TravelEventMenu"
## The card that says where and when the player is - the map's own title, the place,
## the hour and the clock - raised as each Danger opens.
##
## [b]It is the run's opening card asked to play again[/b], not a second one written
## for trouble: every line on it is already read from the map, the region and the day
## cycle, so a Danger names its place and its hour by exactly the arithmetic an
## ordinary round does. Optional; a world without one simply opens the fight.
@export var intro_path: NodePath = ^"../RunHUD/RoundIntro"
## The round's own difficulty curve, which is where a Danger's extra toughness is
## laid on. Optional; without one the enemies are whatever the round makes them.
@export var scaling_path: NodePath = ^"../RoundScaling"
## The ending played out over the last man of a Danger - see [DangerFinale]. Purely
## optional: a world without one clears a Danger on [member end_delay] exactly as it
## did before the presentation existed, and one that has it hands the beat over so the
## question comes up over the head rather than after a timer of this node's own.
@export var finale_path: NodePath = ^"../DangerFinale"
## Group the player's health is found in, so a death out here ends the search rather
## than leaving it asking questions over a body.
@export var health_group: StringName = &"player_health"
## Group every living enemy joins, walked when the field is cleared between Dangers.
@export var enemy_group: StringName = &"enemies"

@export_group("The walk between")
## How long the walk to the next Danger lasts, in seconds.
@export var transition_time: float = 3.0
## Gap between the decision landing and the screen starting to go black, so the
## press is seen.
@export var start_delay: float = 0.15
## How long the screen takes to go black as the player walks off.
@export var fade_out_time: float = 0.6
## How long it takes to clear on the far side. The Danger is already under way
## behind it.
@export var fade_in_time: float = 0.6
## How long the player is left watching the last of them run off before they are
## asked whether they want another, in seconds.
@export var end_delay: float = 1.2
## How long before the walk ends the encounter's title is thrown up, in seconds.
##
## The last beat of the walk is what it is for: the player is told trouble has been
## found and then the black lifts on it, rather than the title and the fight arriving
## in the same frame. Held to the length of the walk, so a reveal longer than the walk
## itself simply lands at the start of it.
@export var title_reveal_time: float = 1.1
## Whether anybody still running from the last Danger is taken off the field during
## the walk.
##
## On. They are removed behind the black, where nobody can see it happen, and only
## ever men who have [i]already given up[/i] - see [EnemyEscape] - so nothing that
## is still fighting is ever taken away from the player. Off leaves them there, and
## the next Danger opens with the previous one's stragglers still wandering off.
@export var clears_stragglers: bool = true

@export_group("Wording")
## The heading over the cart while the player is walking.
@export var transition_title: String = "LOOKING FOR TROUBLE"
## The line under it. The number of the Danger being walked towards is substituted
## in.
@export var transition_subtitle_format: String = "DANGER %d"
## The heading on the CONTINUE / STOP question. The number just cleared is
## substituted in.
@export var question_title_format: String = "DANGER %d CLEARED"
## The question itself, under the heading. Empty leaves the screen as its two buttons
## alone.
@export var question_description: String = "BELANI ARAMAYA DEVAM EDECEK MİSİN?"
## What the two buttons say.
@export var continue_text: String = "CONTINUE"
@export var stop_text: String = "STOP"
## The large title thrown up at the end of the walk, in the last beat before the black
## lifts on the fight.
##
## [b]It is the ambush's own announcement asked for other words.[/b] A day of the road
## that turns out to hold an ambush says "AMBUSH!" in exactly this place, in exactly
## this way - see [method TravelLoading.show_result] - so trouble being found reads as
## the same kind of news rather than as a second style of encounter title.
@export var found_text: String = "TROUBLE FOUND"
@export var found_colour := Color(0.82, 0.1, 0.1)

@export_group("The card")
## Whether the card naming the place and the hour is played as a Danger opens.
@export var shows_location_card: bool = true
## Whether everything that walks drops into slow motion while it is on screen.
##
## On, and for the reason the round's own opening card does it - see
## [WorldBoot]: the fight is already happening behind the card, so without this the
## player is being knifed while reading where they are. It is the world's own
## [WorldSlowdown], the same multiplier the round intro uses, so nothing here decides
## how slow "slow" is.
@export var slows_for_card: bool = true

@export_group("The day")
## Whether clearing a Danger moves the time of day on.
##
## [b]A Danger is not a day.[/b] Riding a day of the road spends a stage on the clock
## and so does sleeping at the camp, and going out looking for trouble has to cost
## something on the same scale or a player could search all night for nothing. So one
## cleared Danger is one stage - morning to noon - rather than a day of its own.
@export var advances_day_stage: bool = true
## How many stages one cleared Danger is worth. 1 is the next hour along.
@export var day_stages_per_danger: int = 1
## The circle turned over the walk while the hour moves - see [DayTransitionDial].
##
## [b]It is what decides when the clock actually moves.[/b] An hour owed by a cleared
## Danger is not spent as it is cleared: it is held until the player is walking to the
## next one and spent on the beat the dial says its halves have swapped, so the change
## the game makes and the change the player watches are one event. Optional; a world
## with no dial spends the hour as the walk begins, which is the clock exactly as it
## moved before there was anything to watch it move on.
@export var day_dial_path: NodePath = ^"../RunHUD/DayTransitionDial"

@export_group("How many")
## Enemies in the [i]whole[/i] of Danger 1, in a region of danger 0 - a map's way in.
##
## [b]This is the total, not the opening group.[/b] A Danger is an ambush: some of it
## is standing there when the screen clears and the rest keeps arriving afterwards,
## and this is both of those added together. Everything else about how many is read
## off it - the region multiplies it and each further Danger compounds on it - so
## retuning how big trouble is starts here rather than in a table.
@export var base_enemy_count: int = 10
## How many of that total are already standing round the player when a Danger opens.
##
## [b]This is what makes it an ambush rather than a wave[/b] - they are placed in
## view, at medium range, and walk at the player from the first frame. It is
## [i]part[/i] of [member base_enemy_count] rather than something on top of it: the
## remainder is owed and arrives in groups from just off the edge of the screen, the
## same way the rest of a road ambush does.
##
## It is the same number at Danger 1 and at Danger 10 on purpose: what gets worse is
## how many more come afterwards, not how many are on top of the player the instant
## the black clears. Below zero rolls the ambush's own
## [member AmbushWaveDirector.opening_count] instead.
@export var opening_count: int = 4
## Fewest enemies that must still be owed after the opening group has been placed.
##
## [b]It is what keeps a Danger a fight rather than a tableau.[/b] Without it, a base
## count tuned down to the size of the opening would produce an encounter that is over
## the moment the men standing there are dead, with nothing arriving behind them - so
## the total is lifted to the opening plus this before anything else is applied.
## [member max_enemy_count], being an explicit ceiling, still overrides it.
@export var least_arrivals: int = 1
## Most enemies one Danger may be worth. [b]0 - the default - is no ceiling[/b],
## which is what the growth below wants; it is kept so a Danger deep in a hard region
## can be capped later without the growth being flattened to do it.
@export var max_enemy_count: int = 0
## How much of a Danger has to be killed before the rest give up and run, as a
## fraction of its total.
##
## [b]0 is the rule as written, and it means nobody runs: a Danger is fought to the last
## man.[/b] Trouble is the explicit exception to the 75% breaking point every other
## encounter uses - an arena round, a road ambush and a gang all stop spawning and let
## the remainder flee once three in four are down, and a Danger does not. It is left as
## an export, and as the fraction rather than a switch, so the exception is visible next
## to the rule it is an exception to.
##
## Handed to the ambush for this encounter alone - see
## [method AmbushWaveDirector.begin_with] - so the same director still routs the
## ambushes on the road at whatever they are set to.
@export_range(0.0, 1.0, 0.01) var rout_fraction: float = 0.0

@export_group("Danger scaling - the region")
## What the map's deadliest corner multiplies a Danger's enemy count by. The way in
## multiplies by 1, and everything between is read off the region's own
## [member MapRegion.difficulty] - so region A is the quietest trouble and E the
## worst, and a sixth region is a number on a [code].tres[/code] file rather than a
## branch here.
@export var region_count_multiplier: float = 2.5
## The same, for how much health those enemies have.
@export var region_health_multiplier: float = 1.8
## The same, for how hard they hit. 1.0 - the default - leaves damage alone, which
## is the rule as written: trouble deeper in the map means more of them and tougher
## ones.
@export var region_damage_multiplier: float = 1.0

@export_group("Danger scaling - the number")
## What each further Danger in the same search multiplies the enemy count by,
## compounded. 1.18 is "a fifth again every time".
##
## Deliberately gentler than the toughness growth beside it. A third again each
## Danger compounded to a crowd a search could not be fought through by Danger 6 or
## 7, so the crowd grows slowly and the men in it grow faster - a deep Danger is a
## harder fight rather than a longer one. It is still growth: turning it off is
## setting this to 1.0.
@export var count_growth: float = 1.18
## The same, for their health.
@export var health_growth: float = 1.15
## The same, for their damage. 1.0 leaves it alone.
@export var damage_growth: float = 1.0
## Whether the Danger number starts again at 1 each time the player sets out looking
## for trouble.
##
## On: a search is a run of Dangers and getting harder is what going deeper into
## [i]this[/i] one means. Off makes the number a property of the whole run instead,
## so a player who stops at Danger 4 and sets out again later picks up at 5.
@export var resets_each_search: bool = true
## The last Danger a search can hold. Clearing it ends the search on the spot -
## [b]no CONTINUE / STOP is asked[/b], because there is nothing left to continue
## into - and the reward is dropped for it exactly as a STOP would have been.
##
## 0 is no ceiling, which is the endless search this had before there was a top of
## the ladder.
@export var final_danger: int = 10

var _session: Node
var _state: State = State.IDLE
## Whether a search is being run at all. Separate from the state because a search
## exists across the walks, the fights and the questions alike.
var _running: bool = false
## Which Danger the player is on. Advanced as one opens, so it is the number of the
## fight actually in front of them.
var _danger: int = 0
## How many have been cleared since the player set out, for the report at the end.
var _cleared: int = 0
## The deepest Danger actually beaten in this search, which is what the reward is
## worth. Kept apart from [member _danger] because that one is the fight in front of
## the player - including the one they died in - and apart from [member _cleared]
## because a search that carries its number between outings clears fewer than it
## reaches.
var _highest_cleared: int = 0
## Whether the search ended because the player was killed. A death ends a search but
## does not finish it, and nothing is owed for one.
var _died: bool = false
## The player's own pool, followed only while a search is running - a death out here
## carries them home, and the search must not still be asking questions afterwards.
var _player_health: Health
## What the round's extra multipliers were before a Danger laid its own on top, so
## the world is handed back exactly as it was found.
var _saved_health: float = 1.0
var _saved_damage: float = 1.0
var _saved_spawn: float = 1.0
## Whether this node is the one currently holding the world in slow motion, so it can
## only ever release a slowdown it asked for.
var _slowed: bool = false
## Hours a cleared Danger has cost but which have not been put on the clock yet. Held
## rather than spent so the change lands in the middle of the walk, where the player
## can see it happen - see [method _turn_the_day].
var _day_owed: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)
	_session = get_node_or_null(session_path)


## Wired a frame late on purpose: the waggon joins its group in its own
## [method Node._ready], and there is no ordering of the world's children that
## guarantees that has happened before this one runs.
func _ready() -> void:
	_wire_camp.call_deferred()


## The danger system in this world, or null when it has none - which every caller
## reads as "there is no trouble to be found here".
static func get_active(from_node: Node) -> DangerDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as DangerDirector


func get_state() -> State:
	return _state


## Whether the player is out looking for trouble - walking, fighting or deciding.
func is_running() -> bool:
	return _running


## Which Danger is being fought, or was last fought. 0 before the first one opens.
func get_danger_number() -> int:
	return _danger


## How many Dangers have been cleared since the player set out.
func get_dangers_cleared() -> int:
	return _cleared


## The deepest Danger actually beaten in this search - which is what a reward is
## worth, rather than how many were fought.
func get_highest_cleared() -> int:
	return _highest_cleared


func _wire_camp() -> void:
	if not is_inside_tree():
		return
	var camp := Camp.get_active_camp(self)
	if camp == null:
		return
	if not camp.trouble_search_started.is_connected(_on_search_started):
		camp.trouble_search_started.connect(_on_search_started)
	# The search being called off out from under a Danger - the horse sent for at the
	# waggon mid-fight - has to take the encounter with it, or the world would be left
	# with an ambush still putting men out for a search that is over.
	if not camp.trouble_search_ended.is_connected(_on_search_ended):
		camp.trouble_search_ended.connect(_on_search_ended)


func _on_search_started() -> void:
	begin_sequence()


func _on_search_ended() -> void:
	_end_sequence()


# --- Setting out ---------------------------------------------------------------

## Sets the player walking towards their first Danger, and reports whether the
## search actually began.
##
## A false answer is not an error to hide - a search already under way, or a world
## with nothing to fight through - and nothing is changed on the way out, so the
## waggon's own search state is left exactly as [Camp] set it.
func begin_sequence() -> bool:
	if _running or _state != State.IDLE:
		return false
	if _resolve_ambush() == null:
		return false

	_running = true
	if resets_each_search:
		_danger = 0
	_cleared = 0
	_highest_cleared = 0
	_died = false
	_day_owed = 0
	_remember_scaling()
	_follow_player_death()

	sequence_started.emit()
	_walk_on()
	return true


## The walk out to the next Danger. Entered from setting out and from CONTINUE
## alike, so both are the same few seconds and there is one place the encounter is
## prepared.
func _walk_on() -> void:
	_state = State.WALKING
	# Full speed first, before a frame of the crossing is drawn. An ending played out
	# over the last man's head hands the world back gently, and none of that recovery
	# may be spent under the walk: the black closing over it, the man on foot, the hour
	# turning over him and the fight the black lifts on would every one of them be
	# drawn at whatever the run-down had reached. It is asked for here rather than a
	# beat later, at the dial, because the fade is part of the crossing too. See
	# [method DangerFinale.hand_back_speed] - that same recovery finished early, not a
	# second thing writing the same dial. A world with no ending has nothing to ask and
	# walks on exactly as it did.
	var finale := _resolve_finale()
	if finale != null:
		finale.hand_back_speed()
	# Real time and process-always, so the beat still lands whatever the tree's pause
	# state is - the camp is still freezing the world on the frame TROUBLE is pressed.
	var timer := get_tree().create_timer(maxf(start_delay, 0.0), true, false, true)
	timer.timeout.connect(_fade_to_the_walk)


func _fade_to_the_walk() -> void:
	if not is_inside_tree() or _state != State.WALKING:
		return

	var fade := ScreenFade.get_active(self)
	if fade == null:
		# Nothing to hide the walk behind. It still happens - the player simply sees
		# the cut - which is how every other transition here degrades.
		_walk()
		return
	fade.fade_out(maxf(fade_out_time, 0.0), _walk)


## The walk itself, made behind the black with the world frozen.
func _walk() -> void:
	if not is_inside_tree() or _state != State.WALKING:
		return

	get_tree().paused = true
	if clears_stragglers:
		_clear_stragglers()
	_show_walk()

	var wait := maxf(transition_time, 0.0)
	# Raised over the same crossing and paced against the same length, so the hour turns
	# over exactly as the man on foot walks through the middle of the screen.
	_turn_the_day(wait)
	if wait <= 0.0:
		_announce_trouble()
		_open_danger()
		return

	# The title lands in the last beat of the walk rather than at the end of it, so
	# the player reads it and then the black lifts on what it was announcing.
	var reveal := clampf(wait - maxf(title_reveal_time, 0.0), 0.0, wait)
	if reveal <= 0.0:
		_announce_trouble()
	else:
		var herald := get_tree().create_timer(reveal, true, false, true)
		herald.timeout.connect(_announce_trouble)

	var timer := get_tree().create_timer(wait, true, false, true)
	timer.timeout.connect(_open_danger)


## Trouble has been found, said over the same black the walk is being made behind.
func _announce_trouble() -> void:
	if not is_inside_tree() or _state != State.WALKING:
		return
	var loading := get_node_or_null(loading_path)
	if loading == null or not loading.has_method(&"show_result"):
		return
	loading.call(&"show_result", found_text, found_colour)


## The next Danger, opened [i]before[/i] the screen clears.
##
## The order is the whole point and is the same one the road opens an ambush in: the
## world is handed back and the fade started first, and only then are the men placed
## - so the opening group is put into a world that is already running, around a
## player the camera is already on, and is revealed by the black lifting rather than
## appearing in front of somebody who was looking at an empty map.
func _open_danger() -> void:
	if not is_inside_tree() or _state != State.WALKING:
		return

	var director := _resolve_ambush()
	if director == null:
		_end_sequence()
		return

	_danger += 1
	# Laid on before anything is built: the spawner scales an enemy on the way into
	# the world, while its health pool can still be raised.
	_apply_scaling()

	if not director.cleared.is_connected(_on_danger_cleared):
		director.cleared.connect(_on_danger_cleared, CONNECT_ONE_SHOT)

	_state = State.FIGHTING
	_hide_walk()
	get_tree().paused = false
	var fade := ScreenFade.get_active(self)
	if fade != null:
		fade.fade_in(maxf(fade_in_time, 0.0))

	var placed := director.begin_with(get_enemy_count(), opening_count, rout_fraction)
	if placed <= 0:
		# Nothing was built. The search stops rather than leaving the player standing
		# in a cleared world waiting for a fight that will never arrive.
		if director.cleared.is_connected(_on_danger_cleared):
			director.cleared.disconnect(_on_danger_cleared)
		_end_sequence()
		return

	danger_started.emit(_danger, placed)
	# Raised after the men are placed, so the card is read over a fight that is already
	# happening rather than over an empty map that then fills up behind it.
	_play_location_card()


## The last of them is off the field. A beat to watch them go, and then the question.
func _on_danger_cleared() -> void:
	if _state != State.FIGHTING:
		return

	_cleared += 1
	_highest_cleared = maxi(_highest_cleared, _danger)
	# Owed here and spent in the middle of the walk that follows - see
	# [method _turn_the_day] - so the hour turns over where the player is watching it
	# rather than under an ending that is still being played out. A search that stops
	# instead of walking on pays it in [method _end_sequence], so clearing a Danger
	# costs the same hour whichever way the question is answered.
	_owe_the_day()
	danger_cleared.emit(_danger)

	# The top of the ladder answers the question for the player: there is no deeper
	# Danger to walk to, so the search finishes on the same beat it would have been
	# asked on, and the reward is owed exactly as a STOP would have owed it.
	var next: Callable = _ask_what_next
	if final_danger > 0 and _danger >= final_danger:
		next = _end_sequence

	# Whose beat this is. An ending being played out over the last man's head owns the
	# pause between the clearing and what follows, so this node's own wait is not spent
	# as well: it would either cut the presentation short or run on after it. The
	# hand-over arrives however that ending closes - answered, timed out, or torn down
	# by a death - so neither branch can be left waiting on it.
	var finale := _resolve_finale()
	if finale != null and finale.is_playing_out():
		finale.presentation_finished.connect(next, CONNECT_ONE_SHOT)
		return

	var timer := get_tree().create_timer(maxf(end_delay, 0.0), true, false, true)
	timer.timeout.connect(next)


## CONTINUE or STOP, asked on the screen the road already asks gangs with.
func _ask_what_next() -> void:
	if not is_inside_tree() or _state != State.FIGHTING:
		return
	_state = State.DECIDING

	var screen := _resolve_question()
	if screen == null:
		# Nowhere to ask. The search stops, which is the safer of the two answers to
		# make on the player's behalf.
		_end_sequence()
		return

	screen.answered.connect(_on_answered, CONNECT_ONE_SHOT)
	screen.ask_choice(
		question_title_format % _danger, question_description, stop_text, continue_text)


func _on_answered(carry_on: bool) -> void:
	if _state != State.DECIDING:
		return
	if carry_on:
		_walk_on()
		return
	_end_sequence()


## The search is over for now.
##
## [b]The waggon is deliberately left in its search state.[/b] Stopping is putting
## the guns away where you are standing, not going home: the horse is still away and
## the way back is still the player calling it, which is exactly the state STOP
## returns them to. There is no chest, no reward and no ride here - those are the
## next milestone's.
func _end_sequence() -> void:
	if not _running:
		return

	_running = false
	_state = State.IDLE
	_stop_ambush()
	_restore_scaling()
	_drop_player_death()
	_hide_walk()
	# Any hour still owed is paid here without a dial to turn: a search that stopped, or
	# one that cleared the last Danger, never walks anywhere for the change to be shown
	# over, and clearing a Danger has to cost the same hour either way.
	_spend_the_day()
	# Released here as well as when the card finishes, because a search called off
	# while one is still on screen - a death, the horse being sent for - would
	# otherwise leave the world walking at three quarters speed.
	_set_slowed(false)
	get_tree().paused = false

	sequence_ended.emit(_cleared)
	# The second announcement is the one that owes something. It is deliberately not
	# the same signal: putting the world back has to happen however a search ended,
	# and being paid must not.
	if not _died and _cleared > 0:
		search_finished.emit(_cleared, _highest_cleared)


func _stop_ambush() -> void:
	var director := _resolve_ambush()
	if director == null:
		return
	if director.cleared.is_connected(_on_danger_cleared):
		director.cleared.disconnect(_on_danger_cleared)
	director.stop()


# --- How hard it is ------------------------------------------------------------

## How dangerous the part of the map the player is standing in is, 0 to 1. A run
## with no map or no region - a world opened on its own in the editor - is read as
## the quietest country there is rather than as an error.
func get_region_difficulty() -> float:
	var region := _current_region()
	return 0.0 if region == null else region.get_difficulty()


## How many enemies the Danger about to open is worth [i]in total[/i]: the base count,
## multiplied by where the player is and compounded by how deep into the search they
## have gone.
##
## [b]The opening group comes out of this number rather than being added to it[/b], so
## whatever is left over is owed and keeps arriving while the fight is going on - see
## [method AmbushWaveDirector.begin_with]. The floor below is what guarantees there is
## always something left over to arrive.
##
## Read for the Danger [i]being opened[/i], so it is safe to ask before
## [member _danger] has been advanced only in the sense that it answers for the one
## before it - every caller here asks after.
func get_enemy_count() -> int:
	var size := float(maxi(base_enemy_count, 1)) \
		* _region_scale(region_count_multiplier) \
		* _danger_scale(count_growth)

	var count := maxi(int(round(size)), 1)
	count = maxi(count, maxi(opening_count, 0) + maxi(least_arrivals, 0))
	if max_enemy_count > 0:
		count = mini(count, max_enemy_count)
	return count


## What a Danger's enemies have their health multiplied by, on top of whatever the
## round they are being fought in already makes them.
func get_health_multiplier() -> float:
	return _region_scale(region_health_multiplier) * _danger_scale(health_growth)


## The same, for how hard they hit.
func get_damage_multiplier() -> float:
	return _region_scale(region_damage_multiplier) * _danger_scale(damage_growth)


## What [param deepest] is worth where the player is standing: 1 at a map's way in,
## the whole of it at its deadliest corner, and read between the two on the way.
func _region_scale(deepest: float) -> float:
	return lerpf(1.0, maxf(deepest, 0.0), get_region_difficulty())


## [param growth] compounded over the Dangers already survived in this search, so
## Danger 1 is the base value and each one after it is the last multiplied again.
func _danger_scale(growth: float) -> float:
	var steps := maxi(_danger - 1, 0)
	return 1.0 if steps <= 0 else pow(maxf(growth, 0.01), float(steps))


## Lays this Danger's toughness over the round's own curve.
##
## [b]It is the existing scaling, not a second one.[/b] [RoundScaling] already has a
## pair of multipliers for a place that is simply harder than an ordinary arena -
## the travel map uses them for the same reason - and the spawner already applies
## them to every enemy it builds, so a Danger's enemies are the round's enemies with
## one more multiplier on them and nothing anywhere gains a second difficulty curve.
##
## The spawn multiplier is deliberately left alone: how many a Danger is worth is
## decided here and handed to the ambush directly, and moving that number as well
## would be counting the same growth twice.
func _apply_scaling() -> void:
	var scaling := _resolve_scaling()
	if scaling == null:
		return
	scaling.set_extra_multipliers(
		_saved_health * get_health_multiplier(),
		_saved_damage * get_damage_multiplier(),
		_saved_spawn)


func _remember_scaling() -> void:
	var scaling := _resolve_scaling()
	if scaling == null:
		return
	_saved_health = scaling.extra_health_multiplier
	_saved_damage = scaling.extra_damage_multiplier
	_saved_spawn = scaling.extra_spawn_multiplier


## Puts the round's curve back exactly as it was found, so an ordinary round fought
## after a search is an ordinary round.
func _restore_scaling() -> void:
	var scaling := _resolve_scaling()
	if scaling == null:
		return
	scaling.set_extra_multipliers(_saved_health, _saved_damage, _saved_spawn)


# --- The field -----------------------------------------------------------------

## Takes anybody still running from the last Danger off the field, behind the black.
##
## [b]Only men who have already given up.[/b] A retreat is a man leaving of his own
## accord and the walk is the player leaving too, so the two simply happen at once;
## anything still fighting is left exactly where it is, because taking a live enemy
## away from a player who could still shoot it would be taking their blood with it.
func _clear_stragglers() -> void:
	for enemy: Node in get_tree().get_nodes_in_group(enemy_group):
		var escape := _find_escape(enemy)
		if escape != null and escape.is_escaping():
			enemy.queue_free()


func _find_escape(enemy: Node) -> EnemyEscape:
	for node: Node in enemy.find_children("*", "EnemyEscape", true, false):
		var escape := node as EnemyEscape
		if escape != null:
			return escape
	return null


## [b]A death out here ends the search.[/b] Dying is the player's own death sequence
## exactly as it is in the arena and it carries them home - so without this the
## ambush would go on placing men around a body, and the CONTINUE / STOP question
## would come up over a world that is already being rebuilt.
func _on_player_died() -> void:
	# Noted before the search is unwound, because it is what tells an ending apart
	# from a finish - see [signal search_finished]. Dying out here pays nothing.
	_died = true
	_end_sequence()


func _follow_player_death() -> void:
	_drop_player_death()
	_player_health = get_tree().get_first_node_in_group(health_group) as Health
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their death
## - they are revived into the same [Health] - so a connection left behind would
## still be listening at the search after next.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


# --- The screens ---------------------------------------------------------------

## The walk, played on the road's own screen with the player on foot.
##
## [b]The last argument is the whole of "there is no horse in this transition".[/b]
## Looking for trouble sends the animal away - see [method Camp.begin_trouble_search] -
## so the crossing shows the man himself walking rather than the waggon a day of the
## road is ridden in. Which picture that is is [member TravelLoading.walking_texture],
## on the screen's own node, so nothing about how the walk looks lives here.
func _show_walk() -> void:
	var loading := get_node_or_null(loading_path)
	if loading == null or not loading.has_method(&"play_titled"):
		return
	loading.call(&"play_titled", transition_title,
		transition_subtitle_format % (_danger + 1), maxf(transition_time, 0.0), true)


func _hide_walk() -> void:
	var loading := get_node_or_null(loading_path)
	if loading != null and loading.has_method(&"stop"):
		loading.call(&"stop")

	# The dial belongs to the crossing, so it goes when the crossing does. A walk cut
	# short before the halves swapped has its promise taken back as well, or the hour it
	# was going to spend would land in the middle of the next walk instead.
	var dial := _resolve_day_dial()
	if dial == null:
		return
	if dial.turned.is_connected(_spend_the_day):
		dial.turned.disconnect(_spend_the_day)
	dial.stop()


## The card naming the map, the place, the hour and the clock, over the fight that has
## just opened.
##
## [b]Nothing here decides what it says.[/b] Every line on it is read by [RoundIntro]
## from the same three places an ordinary round reads them - the map catalogue, the
## region the session is in, and the map's own [DayCycleDirector] - so a Danger's card
## and a round's card cannot disagree, and moving the clock is all a cleared Danger has
## to do for the next one to be announced at the next hour.
func _play_location_card() -> void:
	if not shows_location_card:
		return

	var intro := get_node_or_null(intro_path)
	if intro == null or not intro.has_method(&"play"):
		return

	# Only slowed for when the card can say when it is done. One that cannot is played
	# over a world at full speed rather than leaving it slowed with nothing coming to
	# release it - the same rule [WorldBoot] plays the round's own card under.
	if slows_for_card and intro.has_signal(&"finished"):
		_set_slowed(true)
		if not intro.is_connected(&"finished", _on_card_finished):
			intro.connect(&"finished", _on_card_finished, CONNECT_ONE_SHOT)

	intro.call(&"play")


func _on_card_finished() -> void:
	_set_slowed(false)


## The slow motion itself, guarded on its own flag so this can only ever release a
## slowdown it asked for.
func _set_slowed(slowed: bool) -> void:
	if slowed == _slowed:
		return
	var slowdown := WorldSlowdown.get_active(self)
	if slowdown == null:
		return
	_slowed = slowed
	slowdown.set_slowed(slowed)


## Nothing is left slowed behind us: a world torn down while a card is up - a death, a
## reload - would otherwise hand the next round a crawling player.
func _exit_tree() -> void:
	_set_slowed(false)


# --- The clock -------------------------------------------------------------------

## What a cleared Danger costs on the clock, put aside rather than paid.
##
## The hour is owed from the moment the last man goes down and settled later, because
## where it is settled is the whole of what the player sees: under the ending being
## played out over that man's head it would be a colour change nobody was looking at,
## and in the middle of the walk it is the thing the walk is about.
func _owe_the_day() -> void:
	if not advances_day_stage or day_stages_per_danger <= 0:
		return
	_day_owed += day_stages_per_danger


## The hour moving, over the walk being made towards the next Danger.
##
## [b]The clock is not touched here.[/b] The dial is raised over the same crossing and
## paced against the same length, and the hour is spent on the beat it reports its
## halves have swapped - see [signal DayTransitionDial.turned] - so the number changing
## and the picture changing are one event rather than two that have to be kept in step.
## A world with no dial pays it immediately, which is where the hour used to be spent
## anyway.
##
## [b]The dial is raised over every walk, including the one into the first Danger.[/b]
## That walk costs nothing - the player has only just set out - and it is still played
## in full, hour now against hour next, so the transition looks the same every time it
## is entered instead of being missing the first time and appearing afterwards. What
## the second face shows there is a look ahead at what a cleared Danger will buy, not
## an hour that has been spent: [method _spend_the_day] pays out only what
## [method _owe_the_day] has actually put aside, so the clock still moves for the first
## time on the walk after the first Danger is cleared.
func _turn_the_day(duration: float) -> void:
	var dial := _resolve_day_dial()
	if dial == null:
		_spend_the_day()
		return

	if not dial.turned.is_connected(_spend_the_day):
		dial.turned.connect(_spend_the_day, CONNECT_ONE_SHOT)
	dial.play(duration)


## Whatever hours are owed, put on the clock. Safe to call when none are, which is
## what makes it callable from both the dial and the end of a search without either
## having to know whether the other got there first.
func _spend_the_day() -> void:
	if _day_owed <= 0:
		return
	var stages := _day_owed
	_day_owed = 0
	_advance_the_day(stages)


## [param stages] hours, actually spent.
##
## [b]It spends the run's own days rather than a Danger clock of its own.[/b]
## [method RunSessionState.advance_days] is what a journey already moves the hour
## with: it asks the map how many stages a day is divided into and hands the answer to
## [DayClock], which is the one thing in the game that knows what time it is. So one
## cleared Danger goes through exactly the arithmetic one day of the road does, and
## the darkness, the HUD's icon and the next card follow it without being told.
func _advance_the_day(stages: int) -> void:
	if stages <= 0:
		return
	if _session == null or not _session.has_method(&"advance_days"):
		return
	_session.call(&"advance_days", stages)


# --- Looking things up ---------------------------------------------------------

func _resolve_ambush() -> AmbushWaveDirector:
	var named := get_node_or_null(ambush_path) as AmbushWaveDirector
	return named if named != null else AmbushWaveDirector.get_active(self)


func _resolve_question() -> TravelEventMenu:
	var named := get_node_or_null(question_path) as TravelEventMenu
	return named if named != null else TravelEventMenu.get_active(self)


func _resolve_scaling() -> RoundScaling:
	return get_node_or_null(scaling_path) as RoundScaling


## The ending, or null when this world has none - which every caller reads as "a Danger
## here clears the way it always did".
func _resolve_finale() -> DangerFinale:
	var named := get_node_or_null(finale_path) as DangerFinale
	return named if named != null else DangerFinale.get_active(self)


## The dial the hour is turned over on, or null when this world has none - which every
## caller reads as "the clock moves without being watched".
func _resolve_day_dial() -> DayTransitionDial:
	var named := get_node_or_null(day_dial_path) as DayTransitionDial
	return named if named != null else DayTransitionDial.get_active(self)


## The part of the map the player is standing in, asked of the session so there is
## no second copy of where the run currently is.
func _current_region() -> MapRegion:
	if _session == null or not _session.has_method(&"get_map"):
		return null
	var map := _session.call(&"get_map") as MapDefinition
	if map == null:
		return null
	return map.find_region(_session.call(&"get_region_id"))
