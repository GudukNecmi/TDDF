class_name WeaponHeft
extends Node
## The weight of what the player is doing with their weapon, slowing their walk -
## a HELL CHAMBER charge being held. One more answer to
## [method Player.get_speed_multiplier], built like [TerrainSlow]: this only ever
## answers [method get_speed_multiplier], and [member Player.speed_modifier_paths]
## is what actually slows the body.
##
## [b]It owns no numbers.[/b] A weapon hands in the multiplier it wants through
## [method set_heft] and takes it back with 1 - see [member Shotgun.heft_receiver_path]
## - so how much a charge slows the player is tuned on the weapon's own Legendary.
## Each source is kept apart, so two things weighing the player down never
## overwrite each other; nothing ever writes the player's speed, so nothing here
## can leave them permanently slower.

## Multiplier per source, keyed by the source's instance id so a weapon freed
## mid-charge cannot leave its slowdown behind.
var _sources: Dictionary[int, float] = {}


## Holds the walk to [param multiplier] of its speed on [param source]'s account.
## 1 or above takes the source's slowdown away again.
func set_heft(source: Object, multiplier: float) -> void:
	if source == null:
		return
	if multiplier >= 1.0:
		_sources.erase(source.get_instance_id())
	else:
		_sources[source.get_instance_id()] = clampf(multiplier, 0.0, 1.0)


## The slowest any live source holds the walk to, 1 with none.
func get_speed_multiplier() -> float:
	var slowest := 1.0
	for id: int in _sources.keys():
		if instance_from_id(id) == null:
			_sources.erase(id)
			continue
		slowest = minf(slowest, _sources[id])
	return slowest
