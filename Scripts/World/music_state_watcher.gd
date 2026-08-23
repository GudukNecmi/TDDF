class_name MusicStateWatcher
extends Node
## Says which piece of music the game is in, by watching what the world is
## already doing.
##
## [MusicStateBoard] knows how to hand one state over to another and nothing about
## when to; this is the other half. It is the one place the answer "the player is
## at home / on the road / at a camp / asleep / looking for trouble" is worked out,
## so no gameplay system has to carry a line about music.
##
## [b]It watches rather than being told.[/b] Every hook here is a signal the game
## already emitted for its own reasons - the camp menu going up and coming down,
## the search for trouble beginning and ending, the round the player sleeps into -
## so nothing about the camp, the road or a Danger was changed to make the music
## work, and a system that stops emitting one of them simply stops changing the
## music rather than breaking it.
##
## [b]The world's own state is worked out on ready[/b], not remembered, which is
## what carries the soundtrack across a rebuild: setting out, sleeping, riding a
## journey to its end and going home all tear the world down, and the world that
## comes back asks [method _world_state] what it is and asks the board for it. The
## board is an autoload holding the same five playbacks it held a moment ago, so
## asking for the state that is already playing changes nothing and the song does
## not so much as blink. See [method MusicStateBoard.enter].

## The run's own state - the [code]RunSession[/code] autoload. Whether a map is
## chosen is what tells home from away.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Watched")
## The camp's panel. Raised is [member camp_state]; dropped is whatever the world
## is otherwise. Optional, like everything here.
@export var camp_menu_path: NodePath = ^"../RunHUD/CampMenu"
## The search for trouble. Optional; without one, trouble is simply never a state
## this world can be in.
@export var danger_path: NodePath = ^"../DangerDirector"
## The night at the camp. Optional, like everything here; without one, sleeping is
## never a state this world can be in.
@export var sleep_path: NodePath = ^"../SleepDirector"

@export_group("States")
## Home, with no run under way.
@export var base_state: StringName = &"base"
## A run: the road, the region, the fights on both. [b]The default state of a world
## with a map chosen[/b] - a travel day screen, an ambush, an arrival and an
## ordinary round are all this one state, which is what keeps the road's music
## running unbroken through all of them.
@export var travel_state: StringName = &"travel"
## Standing at a camp with its panel up.
@export var camp_state: StringName = &"camp"
## The night the player sleeps through when they take the camp's SLEEP.
##
## It is entered as the player lies down and left as they get up, however they were
## got up - waking early, sleeping the night out, an ambush or a contract. Its
## position is kept like every other state's, so the next night picks the same track
## up where this one left it, and the segments passing inside one night change
## nothing: the state is already the state, and asking for it again does nothing at
## all. See [method MusicStateBoard.enter].
@export var sleep_state: StringName = &"sleep"
## Out looking for trouble, from the first walk to the last Danger.
@export var trouble_state: StringName = &"trouble"

@export_group("Behaviour")
## Whether the world announces its own state as it is built. Off leaves whatever
## was playing playing, which is what a scene opened on its own for a test wants.
@export var claims_world_on_ready: bool = true
## States a freshly built world will [b]not[/b] take the soundtrack away from.
##
## [b]The night is the reason this exists.[/b] Sleeping at a camp rebuilds the world
## a second or so after the press, and without this the sleep music would be faded
## in and faded straight back out again - a state with a remembered position that
## was never on long enough for the position to mean anything. Held instead, the
## night plays on into the new day and ends where a night should: at the camp panel
## going up, at a ride being confirmed, or at a search for trouble - all of which
## are states asked for by something the player did.
##
## Emptying it makes every rebuild claim the soundtrack, which is the behaviour
## every other state already has.
@export var held_states: Array[StringName] = [&"sleep"]

var _session: Node
var _board: MusicStateBoard
var _camp_menu: Node
var _danger: DangerDirector
var _sleep: SleepDirector


func _ready() -> void:
	_session = get_node_or_null(session_path)
	_board = MusicStateBoard.get_active(self)
	if _board == null:
		# No soundtrack in this build. Every hook below is skipped and the game plays
		# in silence rather than erroring, exactly as a world with no music director
		# always has.
		return

	_watch_camp()
	_watch_trouble()
	_watch_sleep()

	if claims_world_on_ready and not held_states.has(_board.get_target()):
		_board.enter(_world_state())


## What this world is, asked of the world rather than remembered across the
## rebuild. Trouble is asked first because a search survives the panel that started
## it: the camp's menu is closed on the way into a Danger, and the closing must not
## be read as going back to the road.
##
## [b]The night is asked before either, and for exactly the same reason.[/b] The
## camp's panel comes down as the player lies down, and that closing must not be read
## as going back to the road - so a world that is asleep answers the night whoever is
## asking and whatever else has just happened.
func _world_state() -> StringName:
	if _sleep != null and is_instance_valid(_sleep) and _sleep.is_sleeping():
		return sleep_state
	if _danger != null and is_instance_valid(_danger) and _danger.is_running():
		return trouble_state
	if _session != null and _session.has_method(&"is_running") and _session.call(&"is_running"):
		return travel_state
	return base_state


func _watch_camp() -> void:
	_camp_menu = get_node_or_null(camp_menu_path)
	if _camp_menu == null:
		_camp_menu = get_tree().get_first_node_in_group(&"camp_menu")
	if _camp_menu == null:
		return

	if _camp_menu.has_signal(&"opened"):
		_camp_menu.connect(&"opened", _on_camp_opened)
	if _camp_menu.has_signal(&"closed"):
		_camp_menu.connect(&"closed", _on_camp_closed)
	# Sleeping rebuilds the world, so this is the last thing heard before the screen
	# goes dark and the first thing heard on the other side of it.
	if _camp_menu.has_signal(&"next_round_started"):
		_camp_menu.connect(&"next_round_started", _on_slept)


func _watch_trouble() -> void:
	_danger = get_node_or_null(danger_path) as DangerDirector
	if _danger == null:
		_danger = get_tree().get_first_node_in_group(DangerDirector.GROUP) as DangerDirector
	if _danger == null:
		return

	_danger.sequence_started.connect(_on_trouble_started)
	_danger.sequence_ended.connect(_on_trouble_ended)


## The night, watched exactly as the search for trouble is: two signals the sleep
## system already emits for its own reasons, so nothing about sleeping was changed to
## make the music work.
func _watch_sleep() -> void:
	_sleep = get_node_or_null(sleep_path) as SleepDirector
	if _sleep == null:
		_sleep = SleepDirector.get_active(self)
	if _sleep == null:
		return

	_sleep.sleep_started.connect(_on_sleep_started)
	_sleep.sleep_ended.connect(_on_sleep_ended)


func _on_sleep_started() -> void:
	_board.enter(sleep_state)


## Getting up is not itself a state - it is the world being handed back - so what
## follows it is whatever the world turns out to be. The director has already put its
## own state back by the time this arrives, so [method _world_state] answers the road
## rather than the night that has just ended; an ambush or a hunt begun on the same
## beat is that same road state, which is what keeps the music running unbroken into
## the fight.
func _on_sleep_ended(_reason: StringName, _slept: int) -> void:
	_board.enter(_world_state())


func _on_camp_opened() -> void:
	_board.enter(camp_state)


## The panel coming down is not itself a state - it is the world being handed back -
## so what follows it is whatever the world turns out to be. That is what makes
## closing the camp on the way into a Danger keep the trouble music rather than
## dropping back to the road for a moment first.
func _on_camp_closed() -> void:
	_board.enter(_world_state())


func _on_slept(_round_number: int) -> void:
	_board.enter(sleep_state)


func _on_trouble_started() -> void:
	_board.enter(trouble_state)


## A search ends with the player standing in the world they were already in, so the
## soundtrack goes back to that world rather than to anywhere new. The director has
## already put its own state back by the time this arrives, so
## [method _world_state] answers the road rather than the trouble that has just
## finished.
func _on_trouble_ended(_dangers_cleared: int) -> void:
	_board.enter(_world_state())
