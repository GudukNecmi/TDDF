@tool
class_name LootArtBottle
extends LootObjectArt
## A drink on the table - a whisky glass, a whisky bottle, or a corked flask -
## drawn from its proportions and colours, every one an export.
##
## One script draws all of them: [member shape] picks the outline and the
## numbers below size it, so the 10%, 25% and 50% Health items and the Blood
## flask are four [code].tres[/code] of this rather than four drawings.

enum Shape {
	## A short, wide tumbler.
	GLASS,
	## A tall bottle with shoulders and a long neck.
	BOTTLE,
	## A round-bellied flask with a short neck.
	FLASK,
}

@export var shape: Shape = Shape.BOTTLE
## Height of the whole thing, as a fraction of the object's height.
@export_range(0.2, 1.0, 0.01) var height: float = 0.8
## Width of the body, as a fraction of the object's height.
@export_range(0.1, 1.0, 0.01) var width: float = 0.32
## Width of the neck, as a fraction of the body's width (bottle and flask).
@export_range(0.1, 1.0, 0.01) var neck_width: float = 0.34
## Length of the neck, as a fraction of the whole height (bottle and flask).
@export_range(0.0, 0.7, 0.01) var neck_length: float = 0.34
## How full it is, 0 empty .. 1 brim.
@export_range(0.0, 1.0, 0.01) var fill: float = 0.75

@export_group("Colours")
@export var glass_color: Color = Color(0.55, 0.42, 0.25, 0.55)
@export var liquid_color: Color = Color(0.78, 0.42, 0.1, 0.95)
@export var outline_color: Color = Color(0.12, 0.06, 0.03, 0.9)
@export var highlight_color: Color = Color(1, 0.95, 0.85, 0.55)
## The cork or cap. Clear hides it.
@export var cork_color: Color = Color(0.45, 0.3, 0.16, 1)
## A paper label round the body. Clear hides it.
@export var label_color: Color = Color(0.86, 0.8, 0.62, 1)
## A mark printed on the label - its own short text, e.g. "50". Empty prints none.
@export var label_text: String = ""
@export var label_text_color: Color = Color(0.3, 0.08, 0.05, 1)
## How the liquid catches the light.
@export var shimmer: float = 0.25
@export var shimmer_speed: float = 0.6


func draw(canvas: CanvasItem, rect: Rect2, _reward: LootReward, time: float) -> void:
	var h := rect.size.y * height
	var w := rect.size.y * width
	var base := Vector2(rect.get_center().x, rect.get_center().y + h * 0.5)
	draw_shadow(canvas, base + Vector2(0.0, h * 0.02), Vector2(w * 0.7, h * 0.07))
	var outline := _outline(base, w, h)
	canvas.draw_colored_polygon(outline, glass_color)

	# The liquid - the body clipped flat at the fill line.
	var top_y := base.y - h * _body_share() * fill
	var liquid := PackedVector2Array()
	for point: Vector2 in outline:
		liquid.append(Vector2(point.x, maxf(point.y, top_y)))
	var wet := liquid_color
	wet = wet.lightened(shimmer * 0.25 * (0.5 + 0.5 * sin(time * TAU * shimmer_speed)))
	if fill > 0.0:
		canvas.draw_colored_polygon(_dedupe(liquid), wet)
		var surface := liquid_color.lightened(0.3)
		surface.a = 0.8
		var half := _half_width_at(top_y, base, w, h)
		canvas.draw_line(Vector2(base.x - half, top_y), Vector2(base.x + half, top_y), surface, 2.0,
			true)

	if label_color.a > 0.0 and shape != Shape.GLASS:
		var label_rect := Rect2(base.x - w * 0.5, base.y - h * 0.48, w, h * 0.2)
		if shape == Shape.FLASK:
			label_rect = Rect2(base.x - w * 0.36, base.y - h * 0.3, w * 0.72, h * 0.14)
		canvas.draw_rect(label_rect, label_color)
		canvas.draw_rect(label_rect, outline_color, false, 1.0)
		if not label_text.is_empty():
			var font := ThemeDB.fallback_font
			var font_size := int(label_rect.size.y * 0.8)
			var text_width := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1,
				font_size).x
			canvas.draw_string(font, Vector2(label_rect.get_center().x - text_width * 0.5,
				label_rect.position.y + label_rect.size.y * 0.8), label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_text_color)

	var closed := outline.duplicate()
	closed.append(outline[0])
	canvas.draw_polyline(closed, outline_color, maxf(h * 0.025, 1.0), true)
	# A long glint down the left side.
	canvas.draw_line(base + Vector2(-w * 0.32, -h * 0.12), base + Vector2(-w * 0.32,
		-h * _body_share() * 0.85), highlight_color, maxf(w * 0.08, 1.0), true)

	if cork_color.a > 0.0 and shape != Shape.GLASS:
		var neck_half := w * neck_width * 0.5
		var cork := Rect2(base.x - neck_half * 1.05, base.y - h - h * 0.06, neck_half * 2.1, h * 0.09)
		canvas.draw_rect(cork, cork_color)
		canvas.draw_rect(cork, outline_color, false, 1.0)


## How much of the height is the body (the rest is neck).
func _body_share() -> float:
	return 1.0 if shape == Shape.GLASS else 1.0 - neck_length


func _outline(base: Vector2, w: float, h: float) -> PackedVector2Array:
	var half := w * 0.5
	var neck := w * neck_width * 0.5
	var body_top := base.y - h * _body_share()
	match shape:
		Shape.GLASS:
			return PackedVector2Array([
				Vector2(base.x - half * 0.86, base.y), Vector2(base.x + half * 0.86, base.y),
				Vector2(base.x + half, base.y - h), Vector2(base.x - half, base.y - h)])
		Shape.FLASK:
			var points := PackedVector2Array()
			var belly := Vector2(base.x, base.y - (base.y - body_top) * 0.5)
			var radius := Vector2(half, (base.y - body_top) * 0.5)
			var start := asin(clampf(neck / maxf(half, 0.001), 0.0, 1.0))
			for i: int in 25:
				# From just right of the neck, round the bottom, to just left of it.
				var angle := -PI * 0.5 + start + (TAU - 2.0 * start) * float(i) / 24.0
				points.append(belly + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
			points.append(Vector2(base.x - neck, base.y - h))
			points.append(Vector2(base.x + neck, base.y - h))
			return points
		_:
			var shoulder := body_top + h * 0.08
			return PackedVector2Array([
				Vector2(base.x - half, base.y), Vector2(base.x + half, base.y),
				Vector2(base.x + half, shoulder), Vector2(base.x + neck, body_top - h * 0.04),
				Vector2(base.x + neck, base.y - h), Vector2(base.x - neck, base.y - h),
				Vector2(base.x - neck, body_top - h * 0.04), Vector2(base.x - half, shoulder)])


func _half_width_at(y: float, base: Vector2, w: float, h: float) -> float:
	var outline := _outline(base, w, h)
	var widest := 0.0
	for i: int in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if (a.y - y) * (b.y - y) <= 0.0 and not is_equal_approx(a.y, b.y):
			var t := (y - a.y) / (b.y - a.y)
			widest = maxf(widest, absf(lerpf(a.x, b.x, t) - base.x))
	return widest


## Drops points the fill clamp stacked on top of one another, which would make
## an invalid polygon.
func _dedupe(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if result.is_empty() or not result[result.size() - 1].is_equal_approx(point):
			result.append(point)
	if result.size() > 1 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result
