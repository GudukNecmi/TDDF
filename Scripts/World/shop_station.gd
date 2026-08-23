class_name ShopStation
extends Node2D
## A place in the base where an upgrade will later be sold.
##
## This milestone deliberately stops here. The station marks a spot, knows its own
## [member shop_id], and reports when the player is standing at it - and that is
## all it does. There is no stock, no price, no purchase and no reference to
## [BloodBank] anywhere in this file, so whatever the upgrade system turns out to
## be can be hung off [signal player_entered] and [method is_player_present]
## without this having guessed at its shape first.
##
## Like [BloodField] and [CameraController] it is found by group rather than by
## path, so a future shop UI can reach every station in the base without being
## wired to any of them.

## Emitted as the player steps into range of this station.
signal player_entered
## Emitted as they leave.
signal player_exited

## Group every station joins, for [method get_all] and [method get_by_id].
const GROUP := &"shop_station"

## What this shop is. The handle a future upgrade list will be keyed by; it is
## never shown to the player.
@export var shop_id: StringName = &"shop"
## Human-readable name, for a future sign or prompt.
@export var display_name: String = "Shop"
## Region the player has to be standing in to be "at" this station. A separate
## node from the art on purpose - the counter you walk up to is rarely the same
## shape as the building it is in.
@export var area_path: NodePath = ^"InteractArea"
## Only bodies in this group count as a customer.
@export var body_group: StringName = &"player"

var _present: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	var area := get_node_or_null(area_path) as Area2D
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)


## Every station in the base, in no particular order.
static func get_all(from_node: Node) -> Array[Node]:
	if from_node == null or not from_node.is_inside_tree():
		return []
	return from_node.get_tree().get_nodes_in_group(GROUP)


## The station with [param wanted], or null when the base has none.
static func get_by_id(from_node: Node, wanted: StringName) -> ShopStation:
	for node: Node in get_all(from_node):
		var station := node as ShopStation
		if station != null and station.shop_id == wanted:
			return station
	return null


## True while the player is standing at this station.
func is_player_present() -> bool:
	return _present > 0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(body_group):
		return
	_present += 1
	if _present == 1:
		player_entered.emit()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(body_group):
		return
	_present = maxi(_present - 1, 0)
	if _present == 0:
		player_exited.emit()
