class_name HealthCarry
extends Node
## Carries the player's wounds from one round into the next.
##
## Drop it beside a [Health] and that pool stops being reset by the world being
## rebuilt: what it was at is remembered in the [code]Vitals[/code] autoload
## ([RunVitals]) and given back to the pool that comes up in the new world. It is
## deliberately a component rather than something written into [Health] itself,
## because [Health] is the same script every enemy uses and none of them should
## remember anything.
##
## [b]Only during a run.[/b] A player built in the base is left at full health, so
## walking home is always walking home whole and the carry can never strand the
## player at a sliver of a heart with no way to top up. Which of the two a world is
## is [RunSessionState]'s answer - the same one [WorldBoot] builds the world from -
## so there is no second idea here of what a run is.
##
## Nothing here decides when the memory should be dropped. A run beginning and a
## run ending both clear it, at the two places those things happen, so this only
## ever reads and writes.

## The pool this follows. Defaults to a sibling.
@export var health_path: NodePath = ^"../Health"
## The autoload the pool is remembered in.
@export var vitals_path: NodePath = ^"/root/Vitals"
## The run, asked whether this world is one. A world with no session - one opened
## on its own in the editor - carries nothing and behaves exactly as it did before
## this component existed.
@export var session_path: NodePath = ^"/root/RunSession"
## Whether a remembered pool is given back at all. Off records but never restores,
## which is what a debug run wanting fresh health every round would use.
@export var restore_on_ready: bool = true
## Smallest pool the player can be given back, so a round cannot begin with a
## sliver of a heart that a single hit would end. 0 hands back exactly what was
## carried, however little that is.
@export var minimum_carried_health: float = 0.5

@onready var _health: Health = get_node_or_null(health_path) as Health

var _vitals: RunVitals


func _ready() -> void:
	_vitals = get_node_or_null(vitals_path) as RunVitals
	if _health == null or _vitals == null:
		return

	if restore_on_ready and _is_running() and _vitals.has_carried():
		# Written straight into the pool rather than damaged down to it: the player
		# is not being hurt, they are being handed back the health they already had,
		# and going through a hit would fire the flash, the blood and the reaction.
		_health.set_current(maxf(_vitals.get_carried(), minimum_carried_health))

	# Followed rather than polled, so the memory is right after a hit, a heal
	# bought at the camp, or a revival putting the hearts back one at a time.
	_health.health_changed.connect(_on_health_changed)
	_remember()


func _on_health_changed(_current: float, _maximum: float) -> void:
	_remember()


## Only a run's wounds are worth keeping. In the base the pool is left alone, so
## the memory cannot be overwritten by a player standing about at home.
func _remember() -> void:
	if _vitals == null or _health == null or not _is_running():
		return
	_vitals.carry(_health.get_current())


func _is_running() -> bool:
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"is_running"):
		return false
	return session.call(&"is_running")
