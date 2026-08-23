class_name SpinMultiplier
extends Label
## The figure the revolver's twirl has wound up to, shown over the ammunition.
##
## [b]It is the readout for a thing the player cannot otherwise count.[/b] The sight
## crossing towards red says the weapon is winding up; this says how far. It appears
## only once the twirl has actually earned something and it grows with each rung, so
## a fully wound revolver is unmistakable at a glance without a number having to be
## read.
##
## [b]It is not wired to the revolver.[/b] It asks whatever is in
## [member charge_group] for [code]get_stage_label()[/code] and
## [code]get_stage_label_scale()[/code] and draws whatever it is handed - so the text
## and the sizes live on the [SpinStage] resources beside the damage they belong to,
## and a weapon with no twirl simply leaves this blank forever. Firing, swapping
## weapons, leaving the spin zone and cancelling all put it away by the same route:
## the source stops naming a rung, so there is nothing to draw.
##
## Where it sits is the scene's business - it is anchored just above the ammunition
## in [code]RunHUD.tscn[/code] - and how it looks is the ordinary HUD styling. What is
## here is only when it is up and how large.

## Group a weapon's charge joins. The same group [Crosshair] reads its colour from,
## so one weapon drives both without either knowing about the other.
@export var charge_group: StringName = &"weapon_charge"
## Size the readout is drawn at before a rung's own scale is applied to it. The rungs
## are relative to this, so the whole ladder is resized by this one field.
@export var base_scale: float = 1.0
## How much larger than its resting size a rung lands at as it appears, so each new
## multiplier arrives with a kick rather than fading up.
@export var pop_scale: float = 1.3
## How quickly that kick settles, in the usual exponential-smoothing units.
@export var grow_speed: float = 16.0
## How quickly the readout fades in and out, in the same units.
@export var fade_speed: float = 18.0

## How far up it is: 0 away, 1 fully shown.
var _shown: float = 0.0
var _scale: float = 1.0
var _source: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""
	visible = false
	modulate.a = 0.0
	# Grown from the corner nearest the ammunition, so a larger figure reaches up and
	# away from the counter rather than sliding off the edge of the screen.
	resized.connect(_apply_pivot)
	_apply_pivot()


## Followed every frame rather than driven by a signal, so a weapon swapped out
## mid-spin takes its readout with it without anything having to be disconnected.
func _process(delta: float) -> void:
	var stage_text := _stage_text()
	var up := not stage_text.is_empty()

	if up and stage_text != text:
		text = stage_text
		_scale = _wanted_scale() * maxf(pop_scale, 0.0)

	_shown = lerpf(_shown, 1.0 if up else 0.0, 1.0 - exp(-maxf(fade_speed, 0.01) * delta))
	if up:
		_scale = lerpf(_scale, _wanted_scale(), 1.0 - exp(-maxf(grow_speed, 0.01) * delta))

	visible = _shown > 0.01
	modulate.a = _shown
	scale = Vector2.ONE * _scale


## What the weapon says it has wound up to, or an empty string for nothing.
func _stage_text() -> String:
	var source := _get_source()
	if source == null or not source.has_method(&"get_stage_label"):
		return ""
	return source.call(&"get_stage_label") as String


func _wanted_scale() -> float:
	var scaling := 1.0
	var source := _get_source()
	if source != null and source.has_method(&"get_stage_label_scale"):
		scaling = maxf(source.call(&"get_stage_label_scale") as float, 0.01)
	return maxf(base_scale, 0.01) * scaling


func _get_source() -> Node:
	if _source == null or not is_instance_valid(_source):
		_source = get_tree().get_first_node_in_group(charge_group)
	return _source


func _apply_pivot() -> void:
	pivot_offset = size
