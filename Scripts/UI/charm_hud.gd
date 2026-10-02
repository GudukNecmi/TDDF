class_name CharmHud
extends Control
## The Charms the player is wearing, as a row of little crystals in the HUD's
## bottom-left corner, above the blood.
##
## [b]It only reads.[/b] What is worn is the [code]Charms[/code] autoload's
## ([RunCharmHolder]); this redraws on [signal RunCharmHolder.charms_changed] -
## one crystal per different Charm, in its own colour, with a count beside it
## once it is worn more than once. Nothing worn draws nothing.

## The Charm authority.
@export var holder_path: NodePath = ^"/root/Charms"
## One crystal's height from centre to tip, in pixels.
@export var crystal_radius: float = 13.0
## The room each Charm takes along the row, in pixels.
@export var spacing: float = 40.0
## A soft glow round each crystal.
@export var glow: float = 0.5
## How a count above one is written: [code]%d[/code] is the count.
@export var count_format: String = "x%d"
@export var count_font: Font
@export var count_font_size: int = 13
@export var count_color: Color = Color(0.93, 0.88, 0.8, 1)
@export var count_outline_color: Color = Color(0, 0, 0, 1)
@export var count_outline_size: int = 4

var _holder: RunCharmHolder


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder = get_node_or_null(holder_path) as RunCharmHolder
	if _holder != null:
		_holder.charms_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if _holder == null:
		return
	var font := count_font if count_font != null else get_theme_default_font()
	var x := crystal_radius
	var y := size.y * 0.5
	for charm: CharmDefinition in _holder.get_kinds():
		CharmDefinition.draw_crystal(self, Vector2(x, y), crystal_radius, charm.color, glow)
		var count := _holder.get_count(charm)
		if count > 1 and font != null:
			var at := Vector2(x + crystal_radius * 0.55, y + crystal_radius)
			var text := count_format % count
			if count_outline_size > 0:
				draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_font_size,
					count_outline_size, count_outline_color)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_font_size, count_color)
		x += spacing
