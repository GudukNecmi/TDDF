@tool
class_name CharmDefinition
extends Resource
## One kind of Charm - a worn trinket the player carries through a run, held by
## the [code]Charms[/code] autoload ([RunCharmHolder]).
##
## [b]A Charm is not a Card.[/b] Cards come out of the mystery [code]?[/code]
## selection and land on the weapon; a Charm comes straight out of the Loot
## Screen's pouch and is worn by the player. Nothing here touches a weapon.
##
## [b]Placeholder art, drawn in code.[/b] Until the real artwork exists every
## Charm is the same faceted crystal, told apart only by [member color] - see
## [method draw_crystal], which the Loot Screen's table and the HUD both use so
## the two always look alike.

## The stacking identity: two Charms with the same id are the same Charm. Never
## shown.
@export var id: StringName = &""
## The Charm's name, as shown on the table and in the HUD.
@export var display_name: String = ""
## What it does, in one line.
@export_multiline var description: String = ""
## The crystal's colour.
@export var color: Color = Color(0.8, 0.3, 0.9, 1)


## Draws the placeholder crystal - a faceted diamond with a bright crown and a
## darker pavilion - on [param canvas], centred on [param centre] and
## [param radius] tall from centre to tip.
static func draw_crystal(canvas: CanvasItem, centre: Vector2, radius: float,
		tint: Color, glow: float = 0.0) -> void:
	if canvas == null or radius <= 0.0:
		return
	var w := radius * 0.78
	var crown := radius * 0.32
	var top := centre + Vector2(0.0, -radius)
	var bottom := centre + Vector2(0.0, radius)
	var left := centre + Vector2(-w, -crown * 0.2)
	var right := centre + Vector2(w, -crown * 0.2)
	var table_l := centre + Vector2(-w * 0.45, -radius * 0.62)
	var table_r := centre + Vector2(w * 0.45, -radius * 0.62)

	if glow > 0.0:
		var halo := tint
		for ring: int in 3:
			halo.a = clampf(glow * 0.12 * float(3 - ring), 0.0, 1.0)
			canvas.draw_circle(centre, radius * (1.05 + 0.18 * ring), halo)

	var dark := tint.darkened(0.55)
	var mid := tint.darkened(0.15)
	var light := tint.lightened(0.45)
	# Pavilion - the lower point, in two shaded halves.
	canvas.draw_colored_polygon(PackedVector2Array([left, centre + Vector2(0.0, -crown * 0.2),
		bottom]), dark)
	canvas.draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, -crown * 0.2), right,
		bottom]), mid)
	# Crown - the upper cut.
	canvas.draw_colored_polygon(PackedVector2Array([left, table_l, table_r, right]), tint)
	canvas.draw_colored_polygon(PackedVector2Array([table_l, top, table_r]), light)
	# Facet lines and outline.
	var edge := tint.darkened(0.7)
	canvas.draw_polyline(PackedVector2Array([table_l, top, table_r, right, bottom, left, table_l,
		table_r]), edge, maxf(radius * 0.06, 1.0), true)
	canvas.draw_line(left, right, edge, maxf(radius * 0.04, 1.0), true)
	canvas.draw_line(table_l, bottom, Color(edge, 0.5), maxf(radius * 0.03, 1.0), true)
	canvas.draw_line(table_r, bottom, Color(edge, 0.5), maxf(radius * 0.03, 1.0), true)
	# A glint.
	var glint := Color(1, 1, 1, 0.75)
	canvas.draw_line(table_l + Vector2(w * 0.12, radius * 0.06),
		table_l + Vector2(w * 0.3, radius * 0.06), glint, maxf(radius * 0.05, 1.0), true)
