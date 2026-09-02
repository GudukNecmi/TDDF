class_name WorldMapHorseStaminaHUD
extends Control
## The horse's stamina, bottom-left, for as long as the player is actually on
## the World Map - gated the identical way [code]world_map_clock.gd[/code]
## and [WorldMapOverlayMenu] already gate their own World-Map-only pieces, by
## asking the World Map's own [WorldZone] whether the player is inside it,
## rather than a new visibility mechanism of its own. That same check is what
## already keeps this off screen the instant a World Map bandit contact
## drops the player into the Arena - see [WorldMapCombatBridge] - with
## nothing here having to know combat exists at all.
##
## [b]It reads [WorldMapHorse], never owns a number of its own.[/b]
## [member current_stamina], [member get_max_stamina] and
## [method WorldMapHorse.get_base_max_stamina] are asked for every frame
## rather than pushed here through a signal, since a bar this cheap to redraw
## does not need one - see [method _process].
##
## [b]Three tiers, not one fill.[/b] The bar's own total width is always
## [method WorldMapHorse.get_base_max_stamina] - the ceiling a completely
## fresh horse has, which never itself shrinks - so the space
## [member WorldMapHorse.fatigue] has temporarily taken away from
## [method WorldMapHorse.get_max_stamina] stays on screen as a visibly darker
## band rather than the whole bar quietly resizing around it, exactly what
## rule 5 of the stamina HUD pass asks for. Left to right: the bright fill is
## [member WorldMapHorse.current_stamina] itself; the dim band past it, out to
## the current ceiling, is stamina that could still be regenerated or fed
## back; the near-black band past *that*, out to the original ceiling, is what
## fatigue has taken off the top and can only be shown again by the horse
## recovering from it.

## The [WorldMapHorse] this reads. Found by group when unset, the same lookup
## [code]world_map_destination.gd[/code] already uses, so this never has to be
## wired to the one player in the scene.
@export var horse_path: NodePath = NodePath("")
## The World Map's own [WorldZone], asked whether the player is inside it -
## false anywhere else, combat included, which is what keeps this from ever
## drawing over the Arena.
@export var zone_id: StringName = &"world_map"

@export_group("Style")
@export var bar_size := Vector2(220.0, 18.0)
@export var background_color := Color(0.02, 0.015, 0.02, 0.9)
@export var border_color := Color(0.06, 0.01, 0.01, 1.0)
## The bright band: [member WorldMapHorse.current_stamina] itself.
@export var fill_color := Color(0.85, 0.11, 0.11, 1.0)
## The dim band: ceiling not currently filled, but not fatigue-locked either.
@export var available_color := Color(0.32, 0.07, 0.06, 1.0)
## The near-black band: ceiling fatigue has taken off the top.
@export var locked_color := Color(0.05, 0.015, 0.02, 1.0)
@export var label_color := Color(0.72, 0.09, 0.1, 1.0)
@export var label_outline_color := Color(0.0, 0.0, 0.0, 1.0)
@export var label_font_size: int = 15

var _horse: WorldMapHorse
var _zone: WorldZone
var _label: Label


func _ready() -> void:
	custom_minimum_size = bar_size
	size = bar_size
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", label_color)
	_label.add_theme_color_override(&"font_outline_color", label_outline_color)
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.add_theme_font_size_override(&"font_size", label_font_size)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	hide()


func _process(_delta: float) -> void:
	if _horse == null or not is_instance_valid(_horse):
		_horse = _resolve_horse()
	if _zone == null or not is_instance_valid(_zone):
		_zone = WorldZone.get_by_id(self, zone_id)

	var on_world_map := _zone != null and _zone.is_player_inside()
	visible = on_world_map and _horse != null
	if not visible:
		return

	queue_redraw()
	_refresh_label()


func _draw() -> void:
	if _horse == null:
		return

	var base_max := maxf(_horse.get_base_max_stamina(), 0.0001)
	var current_max := clampf(_horse.get_max_stamina(), 0.0, base_max)
	var current := clampf(_horse.get_current_stamina(), 0.0, current_max)

	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, background_color, true)

	var locked_width := size.x * (1.0 - current_max / base_max)
	if locked_width > 0.0:
		var locked_rect := Rect2(Vector2(size.x - locked_width, 0.0), Vector2(locked_width, size.y))
		draw_rect(locked_rect, locked_color, true)

	var available_width := size.x * (current_max / base_max)
	if available_width > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(available_width, size.y)), available_color, true)

	var fill_width := size.x * (current / base_max)
	if fill_width > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(fill_width, size.y)), fill_color, true)

	draw_rect(rect, border_color, false, 2.0)


func _refresh_label() -> void:
	if _label == null or _horse == null:
		return
	var current := int(round(_horse.get_current_stamina()))
	var current_max := int(round(_horse.get_max_stamina()))
	_label.text = "%d / %d" % [current, current_max]


func _resolve_horse() -> WorldMapHorse:
	var named := get_node_or_null(horse_path) as WorldMapHorse
	return named if named != null else WorldMapHorse.get_active(self)
