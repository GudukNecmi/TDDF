class_name MusicStateWatcher
extends Node
## Says which piece of music the game is in, by watching what the world is
## already doing.
##
## [MusicStateBoard] knows how to hand one state over to another and nothing about
## when to; this is the other half. Today that means one answer: "the player is at
## home / on the road" - everything else the soundtrack can be in (a bandit
## decision, combat, a bounty boss) is entered directly by whatever put the player
## there - see [WorldMapCombatBridge] - the same way [RunPortal] hands the road's
## own state over as it opens the World Map, so no gameplay system has to carry a
## line about music.
##
## [b]The world's own state is worked out on ready[/b], not remembered, which is
## what carries the soundtrack across a rebuild: setting out, an ambush ending and
## going home all tear the world down, and the world that comes back asks
## [method _world_state] what it is and asks the board for it. The board is an
## autoload holding whatever it was playing a moment ago, so asking for the state
## that is already playing changes nothing and the song does not so much as blink.
## See [method MusicStateBoard.enter].
##
## The camp, search-for-trouble and sleep states this once also watched belonged
## to the old Travel/Trouble/Camp ladder, which no longer exists; watching for
## them was removed along with it rather than left pointing at nothing.

## The run's own state - the [code]RunSession[/code] autoload. Whether a map is
## chosen is what tells home from away.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("States")
## Home, with no run under way.
@export var base_state: StringName = &"base"
## A run: the road, the region, the fight on it. [b]The default state of a world
## with a map chosen.[/b]
@export var travel_state: StringName = &"travel"

@export_group("Behaviour")
## Whether the world announces its own state as it is built. Off leaves whatever
## was playing playing, which is what a scene opened on its own for a test wants.
@export var claims_world_on_ready: bool = true
## States a freshly built world will [b]not[/b] take the soundtrack away from.
## Empty leaves nothing held, so every rebuild claims the soundtrack.
@export var held_states: Array[StringName] = []

var _session: Node
var _board: MusicStateBoard


func _ready() -> void:
	_session = get_node_or_null(session_path)
	_board = MusicStateBoard.get_active(self)
	if _board == null:
		# No soundtrack in this build. Nothing below is reached and the game plays
		# in silence rather than erroring, exactly as a world with no music director
		# always has.
		return

	if claims_world_on_ready and not held_states.has(_board.get_target()):
		_board.enter(_world_state())


## What this world is, asked of the world rather than remembered across the
## rebuild: whether the run's own session has a map chosen.
func _world_state() -> StringName:
	if _session != null and _session.has_method(&"is_running") and _session.call(&"is_running"):
		return travel_state
	return base_state
