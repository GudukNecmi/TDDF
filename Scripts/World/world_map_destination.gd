class_name WorldMapDestination
extends TeleportDestination
## The World Map's own [TeleportDestination], extended only to mount and
## dismount the horse - see [WorldMapHorse] - on the two edges of the one
## journey [Teleporter] already makes: arriving here, and leaving for
## anywhere else.
##
## [b]It travels nobody itself[/b], exactly as every other destination in
## this game does not. It only listens for [signal Teleporter.teleported],
## which fires once a journey has actually landed somewhere, and reads which
## destination that was - mounting when it is this one and dismounting for
## every other, so a debug exit back to the base can never leave the player
## walking home at horse speed.

## Group the player's [WorldMapHorse] component is found in, so this can
## reach it without a path across two different scenes.
@export var horse_group: StringName = &"world_map_horse"
## Bodies this map cares about, for finding the one player.
@export var body_group: StringName = &"player"

var _teleporter: Teleporter


func _ready() -> void:
	super()
	# Deferred so this works whatever order the world's nodes happen to ready
	# in - the player's own Teleporter has to exist first.
	call_deferred(&"_follow_teleporter")


func _follow_teleporter() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node
	if body == null:
		return

	for node: Node in body.find_children("*", "Teleporter", true, false):
		_teleporter = node as Teleporter
		break

	if _teleporter != null and not _teleporter.teleported.is_connected(_on_teleported):
		_teleporter.teleported.connect(_on_teleported)


func _on_teleported(destination: TeleportDestination) -> void:
	var horse := _get_horse()
	if horse != null:
		horse.set_mounted(destination == self)


func _get_horse() -> WorldMapHorse:
	return get_tree().get_first_node_in_group(horse_group) as WorldMapHorse
