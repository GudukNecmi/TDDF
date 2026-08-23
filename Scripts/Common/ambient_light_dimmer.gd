class_name AmbientLightDimmer
extends Node
## Turns a light down as the place it is standing in gets brighter.
##
## The player carries a lamp. In the base, which is a dark hole under the ground,
## that lamp is most of what they can see by. In an open desert at noon it is a
## white hole burned in the middle of the screen - the ambient light is already
## near full, and a light *adds* on top of it, so there is nothing left for it to
## add and everything under it clips.
##
## Rather than pick one energy that is wrong in one of those places, or wire every
## map to every lamp, the lamp reads the room: the world's ambient
## [CanvasModulate] is the one node that already says how dark a place is - it is
## what [WorldZone] blends when the player crosses into the base - so its
## brightness is what the lamp is scaled against. A daylit map turns every lamp
## on it off by being daylit, and the base brings them back by being dark, with
## neither map holding a setting about the other's lamps.
##
## Because it follows the same value the zones blend, the lamp comes up over the
## seconds the base is closing in rather than snapping on at the doorway.
##
## Only the light's [member Light2D.energy] is touched, and only ever downwards
## from what it was authored with, so nothing else about the light - its colour,
## its texture, its size - is decided here.

## Light being dimmed. Defaults to this component's parent.
@export var light_path: NodePath = ^".."
## Group the world's ambient [CanvasModulate] is found in - the same one the
## zones write to.
@export var ambient_group: StringName = &"ambient_modulate"
## Whether the dimming happens at all. Off pins the light to its authored energy.
@export var enabled: bool = true

@export_group("Response")
## Ambient brightness at or below which the light burns at full strength. The
## base sits far below this.
@export_range(0.0, 1.0) var dark_brightness: float = 0.35
## Ambient brightness at or above which the light is off entirely. A daylit map
## sits above this.
@export_range(0.0, 1.0) var bright_brightness: float = 0.8
## Fraction of its energy the light keeps even in full daylight. A little above 0
## leaves a warm pool under the character rather than nothing.
@export_range(0.0, 1.0) var daylight_energy: float = 0.0
## How quickly the light crosses between the two. Slow, so walking into the base
## is a lamp coming up rather than a switch.
@export var response: float = 2.5

@onready var _light: Light2D = get_node_or_null(light_path) as Light2D

var _base_energy: float = 1.0
var _amount: float = -1.0
var _ambient: CanvasModulate


func _ready() -> void:
	if _light == null:
		set_process(false)
		return
	_base_energy = _light.energy


func _process(delta: float) -> void:
	if not enabled:
		return

	var goal := _energy_fraction()
	# Snapped on the first frame, so a light does not visibly fade in from the
	# wrong strength as the map loads.
	if _amount < 0.0:
		_amount = goal
	else:
		_amount = lerpf(_amount, goal, 1.0 - exp(-maxf(response, 0.01) * delta))

	_light.energy = _get_base_energy() * _amount
	_light.enabled = _light.energy > 0.001


## What the light burns at when nothing is dimming it.
##
## Asked of the light every frame where it can answer - [CharacterLight] does -
## rather than being the value captured on ready, so turning a light's authored
## strength down in the inspector takes effect while the game is running instead
## of being overwritten a frame later by the number this node started with. A
## plain [Light2D] has no such answer and falls back to what it was authored at.
func _get_base_energy() -> float:
	if _light != null and _light.has_method(&"get_base_energy"):
		return _light.call(&"get_base_energy")
	return _base_energy


## Where the room's brightness falls between the two thresholds, as the fraction
## of its energy the light should be burning at.
func _energy_fraction() -> float:
	var ambient := _get_ambient()
	if ambient == null:
		return 1.0

	var brightness := _luminance(ambient.color)
	var span := maxf(bright_brightness - dark_brightness, 0.0001)
	var lit := clampf((brightness - dark_brightness) / span, 0.0, 1.0)
	return lerpf(1.0, daylight_energy, lit)


## Perceptual weighting rather than a plain average, so a warm daylight and a
## cold one of the same apparent brightness dim a lamp by the same amount.
func _luminance(colour: Color) -> float:
	return colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722


## Looked up lazily and re-looked-up if it goes away, the same way [BloodField]
## and [CameraController] are found.
func _get_ambient() -> CanvasModulate:
	if _ambient == null or not is_instance_valid(_ambient):
		_ambient = get_tree().get_first_node_in_group(ambient_group) as CanvasModulate
	return _ambient
