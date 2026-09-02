class_name RunInventoryToast
extends Label
## "INVENTORY FULL", flashed over the World Map itself whenever a pickup on
## the ground finds no room - [signal RunInventory.pickup_rejected] - so the
## feedback rule 12 and rule 30 of the run inventory phase ask for is visible
## even while [WorldMapOverlayMenu] is closed, which is the ordinary case
## while walking the map.
##
## Fires once per rejected pickup, never once per frame - it only ever reacts
## to the signal, which [RunInventory] itself already guarantees is emitted
## once per attempt rather than per unit.

@export var inventory_group: StringName = &"run_inventory"
@export var zone_id: StringName = &"world_map"
@export var message: String = "INVENTORY FULL"
@export var display_time: float = 1.4
@export var fade_time: float = 0.35

var _inventory: RunInventory
var _timer: SceneTreeTimer
var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	text = message


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	if zone == null or not zone.is_player_inside():
		return
	if _inventory == null or not is_instance_valid(_inventory):
		_inventory = RunInventory.get_active(self)
		if _inventory != null and not _inventory.pickup_rejected.is_connected(_on_pickup_rejected):
			_inventory.pickup_rejected.connect(_on_pickup_rejected)


func _on_pickup_rejected(_item_id: StringName) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(display_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
