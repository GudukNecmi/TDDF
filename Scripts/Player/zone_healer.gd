class_name ZoneHealer
extends Node
## Patches the player up when they walk somewhere safe.
##
## Coming home from a run should cost nothing: the base is where the player is
## whole again, so arriving in a [WorldZone] whose [member WorldZone.heals_player]
## is set fills their [Health] back to the top.
##
## It heals only the living. A player carried into the base by
## [PlayerDeathSequence] arrives with an empty pool, and their hearts are meant to
## come back one at a time while they lie on the ground - so a corpse is left
## alone here and the death sequence keeps the whole of that beat to itself. The
## check is [method Health.is_alive] rather than a flag either side has to
## remember to set, which means neither component knows the other exists.
##
## The heal lands once per arrival, on the crossing, so standing in the base does
## not top the player up every frame and a heal is never spent on a pool that is
## already full.

## Emitted when the zone actually put something back, with how much.
signal healed(amount: float)

## Health filled up. Defaults to the player's own.
@export var health_path: NodePath = ^"../Health"
## Body whose position picks the zone. Defaults to the player.
@export var body_path: NodePath = ^".."

@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _body: Node2D = get_node_or_null(body_path) as Node2D

var _in_safe_zone: bool = false


## The starting zone is recorded without healing: a run that begins in the arena
## has nothing to put back, and one that somehow began in the base would be at
## full health anyway.
func _ready() -> void:
	_in_safe_zone = _is_in_safe_zone()


func _process(_delta: float) -> void:
	var safe := _is_in_safe_zone()
	if safe == _in_safe_zone:
		return

	_in_safe_zone = safe
	if safe:
		_heal()


func _is_in_safe_zone() -> bool:
	var zone := WorldZone.get_zone_for(self, _body)
	return zone != null and zone.heals_player


func _heal() -> void:
	if _health == null or not _health.is_alive():
		return

	var restored := _health.restore_full()
	if restored > 0.0:
		healed.emit(restored)
