extends Label
## Development-only readout for Phase 3B-3B1 validation: what the player is
## carrying, what the horse is holding safe from a death, how much room the
## horse still has, and what the last Blood Depot deposit actually moved.
##
## Not the real HUD - final UI for the horse's own storage is later work, per
## rule 10 of this phase, which keeps the ordinary carried-blood display
## exactly as it already reads. This exists only so the foundation can be
## checked by eye while it is being built, the same purpose every other node
## under [code]Scripts/Dev/[/code] serves, and it is gated onto the World Map
## the identical way: by asking the World Map's own [WorldZone] whether the
## player is inside it, never a mechanism of its own.

@export var carried_wallet_path: NodePath = ^"/root/Blood"
@export var horse_blood_path: NodePath = ^"/root/HorseBlood"
## The World Map's own [WorldZone], asked whether the player is inside it so
## this never draws over anywhere else in the game - see rule 10, which keeps
## this off the Base HUD entirely.
@export var zone_id: StringName = &"world_map"

@onready var _wallet: BloodWallet = get_node_or_null(carried_wallet_path) as BloodWallet
@onready var _horse: HorseBloodStorage = get_node_or_null(horse_blood_path) as HorseBloodStorage


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	var carried := 0 if _wallet == null else _wallet.get_total()
	if _horse == null:
		text = "PLAYER BLOOD: %d  |  HORSE: -" % carried
		return

	text = "PLAYER BLOOD: %d  |  HORSE %d / %d  |  LAST DEPOSIT %d" % [
		carried, _horse.get_total(), _horse.get_capacity(), _horse.get_last_deposit_amount()]
