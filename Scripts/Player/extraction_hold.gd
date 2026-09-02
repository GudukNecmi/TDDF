class_name ExtractionHold
extends Node
## Pins the player exactly where Extraction found them - the third answer to
## [method Player.get_speed_multiplier], beside [PlayerDeathSequence] and
## [WorldMapHorse], and built the same way both of those are: this only ever
## answers [method get_speed_multiplier], and [member Player.speed_modifier_paths]
## is what actually stops the body.
##
## [b]Only [WorldMapExtractionService] ever calls [method set_frozen].[/b]
## Rule 8 of the Extraction phase is "do not allow the player to continue
## moving on the World Map after extraction begins", and this is the one
## place that rule is kept - the instant an active Extraction is reached,
## the service freezes this and the player cannot walk another step for the
## rest of the run, through the result screen and the ride home alike.
## Nothing here decides when that moment is.

var _frozen: bool = false


## 1 whenever nothing has frozen the player yet, so this can sit on the
## player for the whole game with no effect until Extraction actually
## begins.
func get_speed_multiplier() -> float:
	return 0.0 if _frozen else 1.0


func is_frozen() -> bool:
	return _frozen


func set_frozen(value: bool) -> void:
	_frozen = value
