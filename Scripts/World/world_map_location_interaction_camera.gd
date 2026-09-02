class_name WorldMapLocationInteractionCamera
extends Node
## Gives an ordinary World Map location - the market, the tavern, a normal
## camp, anything without a cinematic of its own yet - the same "walk up,
## the camera settles in on you" beat a bandit contact gets through
## [method WorldMapCombatBridge._open_decision]. See [WorldMapInteractionCamera]
## for the shared zoom itself; this only decides which
## [signal WorldMapLocation.location_interacted] firings ask for it.
##
## [b]Left alone: whatever already owns a location's own presentation.[/b] A
## bounty camp's own boss fight already opens behind [TravelLetterbox] - see
## [method WorldMapCombatBridge.try_begin_boss_encounter] - a Blood Depot's
## own deposit is instant with nothing to hold a camera on, and Extraction
## already has its own settlement and result screen with its own protected
## timing. [const SKIPPED_TYPES] is exactly those three, so nothing here can
## ever double up on a moment another system already owns, and nothing here
## can ever touch Extraction's own timing.
##
## [b]No menu exists yet for the types this does cover.[/b] The market and
## the tavern remain Phase 3A placeholders - a marker on the map and nothing
## behind it - so there is no "the screen closed" signal to release the zoom
## on. This holds the zoom for [member hold_seconds] and eases back out on
## its own, which is exactly "walk up to it, the camera settles on you, then
## it lets go" even with nothing behind the location yet, and needs no
## change the day a real screen is built there: that screen calling
## [method WorldMapInteractionCamera.zoom_out] itself the instant it opens
## simply pre-empts this timer, the same way
## [method WorldMapCombatBridge._on_decision_answered] already pre-empts it
## for the bandit decision.

## Location types already owned by a dedicated interaction service or a
## protected cinematic of their own - see the class doc.
const SKIPPED_TYPES: Array[MapLocation.LocationType] = [
	MapLocation.LocationType.BLOOD_DEPOT,
	MapLocation.LocationType.EXTRACTION,
	MapLocation.LocationType.BOUNTY_CAMP,
]

## How long the zoom is held before it eases back out on its own, for a
## location with no menu of its own to release it early.
@export var hold_seconds: float = 2.0
## Passed straight through to [method WorldMapInteractionCamera.zoom_in] /
## [method WorldMapInteractionCamera.zoom_out]. Below 0 uses that node's own
## defaults, which is what every call here leaves it at.
@export var zoom_seconds: float = -1.0
@export var zoom_multiplier: float = -1.0

var _camera: WorldMapInteractionCamera


func _ready() -> void:
	_camera = WorldMapInteractionCamera.get_active(self)
	for node: Node in get_tree().get_nodes_in_group(WorldMapLocation.GROUP):
		var location := node as WorldMapLocation
		if location == null or SKIPPED_TYPES.has(location.get_location_type()):
			continue
		location.location_interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = WorldMapInteractionCamera.get_active(self)
	if _camera == null:
		return

	_camera.zoom_in(zoom_seconds, zoom_multiplier)

	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(maxf(hold_seconds, 0.0), true, false, true)
	timer.timeout.connect(_release)


func _release() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.zoom_out(zoom_seconds)
