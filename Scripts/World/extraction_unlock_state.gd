class_name ExtractionUnlockState
extends Node
## Which of the World Map's 13 Extraction points the player has permanently
## unlocked through Base progression - the data seam rule 2 of the
## Extraction phase asks for: [code]extraction_id[/code],
## [code]region_id[/code] and [code]unlocked[/code] are readable and
## writable here, with no upgrade UI built on top of them yet.
##
## [b]It is an autoload, the same reason [BountyLedger] and [BloodBank]
## are.[/b] Unlocking an extraction point is permanent progression, meant to
## survive [method SceneTree.reload_current_scene] - the moment a new run
## actually begins - so it cannot live on a node the World Map rebuilds.
##
## [b]Every extraction starts unlocked.[/b] There is no Base upgrade shop
## this phase to earn one through, and leaving every point locked by default
## would make the run - and this whole phase - impossible to finish. See
## [method set_unlocked], the seam a future Base upgrade purchase calls
## instead of this file's own default ever having to change.
##
## [b]It knows nothing about which extractions exist.[/b] The 13 physical
## points are [WorldMapLocation]s, exactly as every other location is - see
## [MapLocation.LocationType.EXTRACTION] - and [WorldMapExtractionService] is
## the one place that walks them and asks this whether each one is unlocked.
## Nothing here holds a roster of ids that could drift out of step with the
## World Map's own.

## Whether an id this has never been told about counts as unlocked. On, so a
## World Map with no purchases made yet - which is every run today - plays
## with all 13 already open.
@export var default_unlocked: bool = true

## Overrides on top of [member default_unlocked], one entry per id a future
## purchase (or a debug tool) has actually touched. An id never written here
## simply reads as the default.
var _unlocked: Dictionary = {}


## Whether [param extraction_id] can be chosen as an active extraction this
## run. Unknown ids answer [member default_unlocked], never false outright -
## a typo'd id should read as "not yet configured" rather than silently
## locking a real extraction point.
func is_unlocked(extraction_id: StringName) -> bool:
	if _unlocked.has(extraction_id):
		return _unlocked[extraction_id]
	return default_unlocked


## Locks or unlocks one extraction point for good. The seam a future Base
## upgrade purchase writes through - see [method HorseBloodStorage.set_capacity]
## for the identical shape on a different total. Nothing in this phase calls
## it; every extraction simply starts unlocked.
func set_unlocked(extraction_id: StringName, value: bool) -> void:
	if extraction_id == &"":
		return
	_unlocked[extraction_id] = value


## Every id this has an override for, for a developer readout.
func get_overridden_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in _unlocked.keys():
		ids.append(key as StringName)
	return ids
