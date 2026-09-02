class_name HorseBloodStorage
extends BloodWallet
## The blood a Blood Depot has moved onto the horse - protected run storage,
## safe from the player's own death.
##
## This is the [i]fourth[/i] blood total the game keeps, and where it sits
## among the other three is the whole point:
##
##   * [code]Blood[/code] ([BloodWallet]) is CARRIED blood. What the collector's
##     hand picks up, and what a death spills - see
##     [method PlayerDeathSequence._spill_carried_blood].
##   * [code]BloodBank[/code] is STORED blood, banked in the base's pool for
##     good.
##   * [code]CampBlood[/code] is the old Camp system's own stash, untouched by
##     this - see the class doc on [CampBlood].
##   * [code]HorseBlood[/code] (this) is what the player has moved onto the
##     horse at a World Map Blood Depot. Out of their hands, so a death cannot
##     touch it, but not permanent either - a future Extraction system is what
##     finally settles it into [code]BloodBank[/code]. Nothing here does that
##     settlement yet.
##
## [b]It is declared [code]class_name[/code], unlike [BloodBank] and
## [CampBlood].[/b] Those two deliberately have none, because their autoload
## name is the useful reference and a matching [code]class_name[/code] would
## shadow it. This storage is reached by its own extra API - [method deposit_from],
## [method get_available_room], [method on_player_death] - from more than one
## script, so it is registered as the [code]HorseBlood[/code] autoload (a
## different name from this class, the same split [RunSessionState]/[code]RunSession[/code]
## and [StreakCounter]/[code]Streak[/code] already use) precisely so those callers
## can type a reference as [HorseBloodStorage] rather than the bare [BloodWallet]
## every other total is read through.
##
## [b]Run storage, not permanent storage.[/b] [BloodBank] and [CampBlood] are
## autoloads that are never reset by anything a run does, because what they hold
## is meant to survive forever. This is the opposite: it is an autoload only so
## it survives the scene rebuilds a World Map session goes through - moving
## between regions, later a combat transition - but [method _on_run_began]
## empties it the moment a genuinely new run is chosen, which is what stops
## blood left over from a finished run leaking into the next one. Ending the
## run that earned it - riding home, or dying - does [i]not[/i] clear it; only
## setting out on the next one does, which is what lets [method on_player_death]
## leave it standing.

## Emitted whenever [method on_player_death] runs, with the total that was left
## standing - not because anything here changed, but so a debug readout or a
## later UI beat can show that the horse's blood lived through the death
## without having to poll [method BloodWallet.get_total] itself.
signal survived_death(total: int)

## How much this storage will hold before a deposit starts leaving blood
## behind on the player. Deliberately configurable here rather than fixed in
## code, so a later Horse Capacity upgrade is a call to
## [method set_capacity] and nothing here has to change to allow it. No
## upgrade exists yet - this phase only creates the seam.
@export var horse_blood_capacity: int = 500
## The run's own state - the [code]RunSession[/code] autoload. Listened to
## rather than called: this asks nothing of [RunSessionState] and
## [RunSessionState] asks nothing of this, so neither has to know the other
## exists. See [method _on_run_began].
@export var session_path: NodePath = ^"/root/RunSession"

## What the most recent Blood Depot deposit actually moved, or 0 before the
## first one this run. Development-only - see
## [code]Scripts/Dev/horse_blood_debug_readout.gd[/code] - kept here rather
## than on the depot itself because a deposit's result belongs to the storage
## it landed in, not to whichever of the four physical depots the player
## happened to be standing at.
var _last_deposit_amount: int = 0


func _ready() -> void:
	var session := get_node_or_null(session_path)
	if session != null and session.has_signal(&"run_began"):
		session.connect(&"run_began", _on_run_began)


## How much more can be moved in before the capacity is reached.
func get_capacity() -> int:
	return maxi(horse_blood_capacity, 0)


## Raises or lowers the capacity - the seam a future Horse Capacity upgrade
## calls. Nothing in this phase calls it; the horse simply starts at
## [member horse_blood_capacity] and stays there.
func set_capacity(capacity: int) -> void:
	horse_blood_capacity = maxi(capacity, 0)


func get_available_room() -> int:
	return maxi(get_capacity() - get_total(), 0)


## How much of [param carried]'s current total a deposit would actually move
## right now - what they are carrying, or the room left before the capacity is
## reached, whichever is less. Read-only; nothing is moved by asking.
func get_depositable_amount(carried: BloodWallet) -> int:
	if carried == null:
		return 0
	return mini(carried.get_total(), get_available_room())


## Moves as much of [param carried]'s blood in as fits, and reports what
## actually moved. The single place a Blood Depot deposit happens - see
## [code]Scripts/World/blood_depot_service.gd[/code], which is the only
## caller.
##
## [b]The capping happens before the transfer, not during it.[/b] The room is
## worked out first and [method BloodWallet.transfer_to] is asked for exactly
## that amount, the same order [method CampMenu.deposit_blood] already uses
## for its own capacity - so nothing here duplicates
## [method BloodWallet.transfer_to]'s own conservation of blood, and blood the
## capacity will not hold is never asked for in the first place, which is what
## leaves it standing on the player rather than destroying it.
func deposit_from(carried: BloodWallet) -> int:
	var amount := get_depositable_amount(carried)
	if amount <= 0:
		_last_deposit_amount = 0
		return 0

	var moved := carried.transfer_to(self, amount)
	_last_deposit_amount = moved
	return moved


## What the last deposit moved, for the World Map debug readout.
func get_last_deposit_amount() -> int:
	return _last_deposit_amount


## The player's death cleanup asks this exactly once, on the killing hit -
## see [method PlayerDeathSequence._spill_carried_blood]. It touches nothing:
## what carried blood does on death is [PlayerDeathSequence]'s own decision,
## [BloodBank] is a different wallet this can never reach, and nothing here
## keeps a collected-blood history to corrupt. The whole of what this does is
## report, so the one rule this phase cares about most - horse blood survives
## a death - is something a caller can observe rather than only trust.
func on_player_death() -> void:
	survived_death.emit(get_total())


## A fresh run leaves nothing of the last one standing on the horse. Bound to
## [signal RunSessionState.run_began] rather than [code]run_ended[/code]
## deliberately: a run ends on both a death and a ride home, and horse blood
## must survive the first of those, so clearing on the end of a run would
## erase it on exactly the death it is meant to protect against. The next run
## beginning is the one moment that is never a death - see [method RunSessionState.begin] -
## which is what makes it the correct place to empty this.
func _on_run_began(_map_id: StringName) -> void:
	reset()
	_last_deposit_amount = 0
