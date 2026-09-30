class_name CooldownReadout
extends Label
## A weapon ability's wait, shown in the HUD's corner - BLACK POWDER's seconds until
## the next smoke shot, then READY.
##
## [b]It is not wired to a weapon.[/b] Like [SpinMultiplier] it asks whatever is in
## [member source_group] for [code]get_cooldown_label()[/code] and
## [code]is_cooldown_ready()[/code] and draws what it is handed, so the wording lives
## on the ability's own resource and a weapon with no such ability leaves this blank.
## Where it sits is the scene's business; how it looks is the ordinary HUD styling.

## Group the carried weapon joins - the same group the sight and the spin readout
## read from.
@export var source_group: StringName = &"weapon_charge"
## Colour while waiting, and once ready.
@export var waiting_color := Color(0.55, 0.16, 0.15)
@export var ready_color := Color(0.95, 0.2, 0.14)
## How much larger it lands as it turns ready, settling back at [member grow_speed].
@export var ready_pop_scale: float = 1.25
@export var grow_speed: float = 14.0
## How quickly it fades in and out.
@export var fade_speed: float = 14.0

var _shown: float = 0.0
var _was_ready: bool = false
var _source: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""
	visible = false
	modulate.a = 0.0
	# Grown from the corner of the screen, so the pop reaches in rather than off it.
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))
	pivot_offset = Vector2(0.0, size.y)


func _process(delta: float) -> void:
	var source := _get_source()
	var label := ""
	if source != null and source.has_method(&"get_cooldown_label"):
		label = source.call(&"get_cooldown_label") as String
	var up := not label.is_empty()
	var ready := up and source.has_method(&"is_cooldown_ready") \
		and bool(source.call(&"is_cooldown_ready"))

	if up:
		text = label
		add_theme_color_override(&"font_color", ready_color if ready else waiting_color)
		if ready and not _was_ready:
			scale = Vector2.ONE * maxf(ready_pop_scale, 0.0)
	_was_ready = ready
	scale = scale.lerp(Vector2.ONE, 1.0 - exp(-maxf(grow_speed, 0.01) * delta))

	_shown = lerpf(_shown, 1.0 if up else 0.0, 1.0 - exp(-maxf(fade_speed, 0.01) * delta))
	visible = _shown > 0.01
	modulate.a = _shown


func _get_source() -> Node:
	if _source == null or not is_instance_valid(_source):
		_source = get_tree().get_first_node_in_group(source_group)
	return _source
