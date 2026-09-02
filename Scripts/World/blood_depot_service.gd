class_name BloodDepotService
extends Node
## Where a Blood Depot interaction actually moves blood - the "later system...
## listening on [signal WorldMapLocation.location_interacted]" that class's own
## doc describes, rather than a second interaction architecture of its own.
##
## [b]One script for all four depots, per rule 17 of this phase.[/b] It never
## learns which depot the player used - it only asks each
## [WorldMapLocation] in [const GROUP] whether
## [method WorldMapLocation.get_location_type] is
## [constant MapLocation.LocationType.BLOOD_DEPOT] and, for every one that is,
## connects the same handler to its [signal WorldMapLocation.location_interacted].
## A fifth depot dropped into the scene needs nothing added here - it is found
## on [method _ready] exactly like the first four - and no depot's id is ever
## read or branched on.
##
## [b]It moves blood; it does not decide how much.[/b] The actual transfer,
## capped to the horse's remaining room, is
## [method HorseBloodStorage.deposit_from] - the whole of what this node does
## is call it once per interaction and report the result, so the transfer
## itself has exactly one implementation regardless of how many places end up
## triggering it.
##
## [b]No polling, no timer of its own.[/b] [WorldMapLocationDirector] already
## decides proximity and already turns one key press into exactly one
## [method WorldMapLocation.try_interact] call - see rule 16 - so a deposit
## triggered by [signal WorldMapLocation.location_interacted] is already a
## single transaction per press with nothing extra to guard here.

## Emitted after a deposit is attempted, whether or not anything actually
## moved - a debug readout or a future confirmation beat can follow this
## rather than polling [HorseBloodStorage] every frame.
signal deposit_attempted(location: WorldMapLocation, moved: int, horse_total: int)

## The carried wallet a deposit draws from - the [code]Blood[/code] autoload.
@export var carried_wallet_path: NodePath = ^"/root/Blood"
## The protected run storage a deposit fills - the [code]HorseBlood[/code]
## autoload.
@export var horse_blood_path: NodePath = ^"/root/HorseBlood"

@onready var _wallet: BloodWallet = get_node_or_null(carried_wallet_path) as BloodWallet
@onready var _horse: HorseBloodStorage = get_node_or_null(horse_blood_path) as HorseBloodStorage


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location == null:
			continue
		if location.get_location_type() != MapLocation.LocationType.BLOOD_DEPOT:
			continue
		location.location_interacted.connect(_on_depot_interacted.bind(location))


func _on_depot_interacted(location: WorldMapLocation) -> void:
	if _wallet == null or _horse == null:
		return

	var moved := _horse.deposit_from(_wallet)
	deposit_attempted.emit(location, moved, _horse.get_total())
