class_name DayClock
extends Node
## Which hour of the day the session is up to.
##
## The class and the singleton are named apart on purpose, exactly as
## [BloodWallet] and [RoundCounter] are: a [code]class_name[/code] matching an
## autoload's name shadows it and refuses to compile. Reach the live one as
## [code]DayCycle[/code]; the type is [DayClock] where a reference has to be
## statically typed.
##
## Registered as an autoload for the same reason [RoundCounter] is: pressing NEXT
## ROUND rebuilds the World scene, and an autoload is the one thing in the tree
## that [method SceneTree.reload_current_scene] does not touch. Without one, every
## run would start at the same hour.
##
## [b]It owns one number, and it is not the hour.[/b] What it stores is where the
## session started - a single random offset, rolled once, the first time anybody
## asks. The hour itself is that offset plus how many rounds have been played, so
## "each completed run advances the time of day by one stage" is not something
## anybody has to remember to call: the round counter already moves once per
## completed run, and the day follows it for free. There is no way for the two to
## drift apart, and no second place a round can be counted.
##
## It holds no colours and no stage list either. How many stages there are, what
## they are called and what they look like is the map's business - see
## [DayCycleDirector] - so this takes the count as an argument and hands back an
## index into whatever the map happens to be carrying.

## Emitted when the hour is forced to a particular stage. The ordinary
## round-by-round advance emits nothing, because nothing is running when it
## happens - the world is rebuilt around the new hour.
signal stage_forced(stage_index: int)

## Which round counter the day follows. Left as the default it is the
## [code]RunProgress[/code] autoload; a session with none simply stays on its
## starting hour.
@export var round_counter_name: StringName = &"RunProgress"

## Where the session started, or -1 before it has been rolled. Rolled lazily
## rather than in [method _ready] so the roll is made against the map's real
## stage count instead of a guess about it.
var _start_offset: int = -1


## The stage a map with [param stage_count] hours should be showing now.
##
## Returns 0 for a map with no stages, which every caller reads as "this map has
## no day cycle".
func get_stage_index(stage_count: int) -> int:
	if stage_count <= 0:
		return 0
	return (get_start_offset(stage_count) + get_rounds_elapsed()) % stage_count


## The hour the session began at, rolled once and then held for the rest of it.
func get_start_offset(stage_count: int) -> int:
	if stage_count <= 0:
		return 0
	if _start_offset < 0:
		_start_offset = randi() % stage_count
	return _start_offset % stage_count


## Whether the session has settled on a starting hour yet. False only before the
## very first map has asked.
func has_started() -> bool:
	return _start_offset >= 0


## Forces the hour to [param stage_index] as of right now, by moving the start
## offset rather than the round count - so the rounds already played are left
## alone and the day carries on advancing normally from here.
##
## For a debug key, and for a later system that wants to say "this run happens at
## night". The change only shows once the world is next built.
func set_stage_index(stage_index: int, stage_count: int) -> void:
	if stage_count <= 0:
		return
	_start_offset = posmod(stage_index - get_rounds_elapsed(), stage_count)
	stage_forced.emit(stage_index)


## Moves the hour on by [param stages] against a map keeping [param stage_count]
## of them, wrapping round the end of the day.
##
## [b]This is what a journey does to the clock.[/b] A ride of four days is four
## stages, and it is spent here rather than by the traveller assigning an hour,
## for exactly the reason the round-by-round advance is not assigned either: there
## is one position in the day and it lives in this file. It goes through
## [method set_stage_index], so it moves the same start offset the ordinary
## advance moves and the day carries on running normally from wherever it lands -
## the rounds played are untouched, and a round taken after a journey advances the
## hour by one from the arrival rather than from where the day would have been.
##
## Negative values wind the day back, which nothing does yet but costs nothing to
## allow.
func advance_stages(stages: int, stage_count: int) -> void:
	if stages == 0 or stage_count <= 0:
		return
	set_stage_index(get_stage_index(stage_count) + stages, stage_count)


## Back to an unrolled session, so the next map to ask picks a fresh starting
## hour. For a new save or a debug reset; nothing in a run calls it.
func reset() -> void:
	_start_offset = -1


## How many rounds have been completed. Read off the round counter rather than
## counted here, so there is exactly one place in the game that knows.
func get_rounds_elapsed() -> int:
	var counter := get_node_or_null(NodePath("/root/%s" % round_counter_name))
	if counter == null or not counter.has_method(&"get_rounds_elapsed"):
		return 0
	return counter.call(&"get_rounds_elapsed")
