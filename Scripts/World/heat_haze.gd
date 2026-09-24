class_name HeatHaze
extends CanvasLayer
## The desert's heat shimmer, drawn only while the sun is overhead.
##
## [b]It asks the sun, not the clock.[/b] How strong it is comes straight from
## [method SunController.get_contact_shadow_weight] - the same answer that turns
## every shadow on the map into the soft oval under its object - so the air wavers
## exactly when the shadows say the sun is high, eases in and out with them, and no
## hour is named anywhere. A map with a different sky gets its haze from its own
## sun for free.
##
## [b]It sits between the world and the interface.[/b] The layer is above the world
## and below the HUD, so the ground ripples and the numbers the player reads do not;
## the film post process keeps its own layer above both and is not touched.
##
## [b]Hidden is free.[/b] The rect is switched off entirely whenever the sun is not
## asking for any haze, so every other hour pays nothing for it.

## The rect the haze shader is drawn on.
@export var effect_path: NodePath = ^"Effect"
## The map's [SunController], found by group when left unresolved.
@export var sun_path: NodePath
## Scales how strong the haze is against how overhead the sun is. 0 turns it off.
@export_range(0.0, 2.0, 0.01) var strength_scale: float = 1.0:
	set(value):
		strength_scale = value
		if is_node_ready():
			_apply()

var _sun: SunController
var _effect: CanvasItem
var _material: ShaderMaterial


func _ready() -> void:
	_effect = get_node_or_null(effect_path) as CanvasItem
	if _effect != null:
		_material = _effect.material as ShaderMaterial
		# Purely visual, so it can never take the player's aim or fire.
		var control := _effect as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun = _resolve_sun()
	if _sun != null and not _sun.sun_updated.is_connected(_on_sun_updated):
		_sun.sun_updated.connect(_on_sun_updated)
	_apply()


func _on_sun_updated(_state: SunState) -> void:
	_apply()


func _apply() -> void:
	if _effect == null:
		return
	var strength := 0.0
	if _sun != null and _sun.has_stages():
		strength = clampf(_sun.get_contact_shadow_weight() * strength_scale, 0.0, 1.0)
	_effect.visible = strength > 0.001
	if _material != null:
		_material.set_shader_parameter(&"strength", strength)


func _resolve_sun() -> SunController:
	if not sun_path.is_empty():
		var node := get_node_or_null(sun_path) as SunController
		if node != null:
			return node
	return SunController.get_active(self)
