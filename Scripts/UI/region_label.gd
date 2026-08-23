class_name RegionLabel
extends Label
## Says where the player is: the name of the part of the map they are standing in.
##
## [b]It replaced the round number on the HUD.[/b] Which round is being fought stopped
## being the useful thing to know once a run became a map with places on it - the
## player rides between regions, looks for trouble in them and takes contracts that
## name them - so the line under the hour says where they are instead of how many
## rounds they have played. The count itself is not lost: it still drives the day
## cycle and the wave scaling, and is still readable off [RoundCounter] by anything
## that wants it.
##
## It keeps no copy of the place. The name comes from the [MapRegion] resource for
## whichever region [RunSessionState] says the run is in, which is the same file the
## camp's readout, the region screen and a wanted poster all print - so the HUD can
## never name the place differently from the screen the player picked it on.
##
## It follows the session rather than polling it, so a region that changes without
## the world being rebuilt is written the moment it happens.
##
## Everything about how it [i]looks[/i] - where it sits, its size, its colour, its
## outline - is left on the node, so it is retuned in the inspector alongside the
## rest of the HUD instead of here.

## The run's own state - the [code]RunSession[/code] autoload. Asked which map is
## being played and which part of it.
@export var session_path: NodePath = ^"/root/RunSession"
## How the place is written. The name is substituted in, so a HUD that wants it
## framed - "- %s -" - is an inspector value rather than an edit here.
@export var format: String = "%s"
## Whether the region's own letter is used when it has been given no place name.
##
## On: a region authored with a name reads "DUSTY MESA", and one that has only ever
## been "C" still reads "C" rather than leaving a gap in the corner of the screen.
@export var falls_back_to_label: bool = true
## What is written when there is no run at all - standing about in the base, or a
## world opened straight from the editor. Empty leaves the line blank, which is what
## the base wants.
@export var no_region_text: String = ""

@export_group("Pulse")
## How much larger the label gets when the place changes. Arriving somewhere new is
## worth marking, which is the same reason the round number used to pulse.
@export var pulse_scale: float = 1.35
@export var pulse_out_time: float = 0.12
@export var pulse_back_time: float = 0.28

var _session: Node
var _pulse_tween: Tween


func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)

	_session = get_node_or_null(session_path)
	if _session != null and _session.has_signal(&"region_chosen") \
			and not _session.is_connected(&"region_chosen", _on_region_chosen):
		_session.connect(&"region_chosen", _on_region_chosen)

	_refresh()


## Scaled around its own middle rather than its top-left corner, so a pulse grows
## the label in place instead of shoving it sideways.
func _centre_pivot() -> void:
	pivot_offset = size * 0.5


func _on_region_chosen(_region_id: StringName) -> void:
	_refresh()
	_play_pulse()


## What the corner of the screen says. Public so anything that moves the run without
## rebuilding the world can push the change.
func refresh() -> void:
	_refresh()


func _refresh() -> void:
	var place := _current_place()
	text = no_region_text if place.is_empty() else format % place


## The place's own name, taken from the region resource. The letter is only used as a
## fallback, because the line is meant to say where the player is rather than which
## patch of the map it is - see [method MapRegion.get_place_name].
func _current_place() -> String:
	if _session == null or not _session.has_method(&"get_region"):
		return ""
	var region := _session.call(&"get_region") as MapRegion
	if region == null:
		return ""

	var place := region.get_place_name()
	if place.is_empty() and falls_back_to_label:
		place = region.get_label()
	return place


## Restarts from the resting scale every time, so a pulse interrupted by another
## cannot stack or leave the label permanently enlarged.
func _play_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	scale = Vector2.ONE
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_out_time) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_back_time) \
		.set_ease(Tween.EASE_IN)
