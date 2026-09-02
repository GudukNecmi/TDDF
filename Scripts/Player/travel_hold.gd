class_name TravelHold
extends Node
## Pins the player exactly where a Travel Portal found them, for as long as
## [WorldMapTravelService] is carrying them across the World Map - the
## reversible twin of [ExtractionHold], built the same way and for the same
## reason: this only ever answers [method get_speed_multiplier], and
## [member Player.speed_modifier_paths] is what actually stops the body.
##
## [b]Reversible, unlike [ExtractionHold].[/b] Extraction is a one-way rule -
## nothing ever calls [method ExtractionHold.set_frozen] back to [code]false[/code] -
## while a Travel Portal jump is a beat the player is meant to walk away from
## on the other side, so this is its own small component rather than a second
## purpose bolted onto Extraction's. Only [WorldMapTravelService] ever calls
## [method set_frozen] here, on both ends of a jump.
const GROUP := &"travel_hold"

var _frozen: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


## 1 whenever nothing has frozen the player yet, so this can sit on the
## player for the whole game with no effect until a Travel Portal jump
## actually begins.
func get_speed_multiplier() -> float:
	return 0.0 if _frozen else 1.0


func is_frozen() -> bool:
	return _frozen


func set_frozen(value: bool) -> void:
	_frozen = value
