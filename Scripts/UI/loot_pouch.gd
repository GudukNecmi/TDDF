@tool
class_name LootPouch
extends Button
## The devil's money pouch in the middle of the Loot Screen's table - clicked to
## spill the fight's rewards out around it.
##
## [b]Placeholder art, drawn in code.[/b] The sack, its gathered neck, the cord,
## the little horns, the ember seams and the sigil are all drawn by
## [method _draw] from the colours and proportions below, so the whole look is
## tuned in the Inspector (the script is a tool, so it is seen in the editor) and
## the final artwork can replace it later without touching the screen.
##
## [b]Opening is one tween with a beat in it.[/b] [method open] winds the pouch
## up, shakes it, pops it - that instant is [signal burst], which is the screen's
## cue to deal the cards - and lets it settle open. Every duration and size of
## that is an export.
##
## It is a flat [Button] with no lettering, so the game's own pointer shows its hover art over it -
## see [method GameCursor._apply_hover].

## The pouch has popped: the rewards should fly out now.
signal burst
## The opening has finished and the pouch is sitting open.
signal opened

@export_group("Shape")
## Width of the sack's belly, as a fraction of the control's width.
@export_range(0.1, 1.0, 0.01) var belly_width: float = 0.86:
	set(value):
		belly_width = value
		queue_redraw()
## Width of the gathered neck, as a fraction of the control's width.
@export_range(0.05, 1.0, 0.01) var neck_width: float = 0.3:
	set(value):
		neck_width = value
		queue_redraw()
## Height of the neck above the control's top, as a fraction of its height.
@export_range(0.0, 1.0, 0.01) var neck_height: float = 0.3:
	set(value):
		neck_height = value
		queue_redraw()
## How tall the ruffled top above the cord is, as a fraction of the height.
@export_range(0.0, 0.5, 0.01) var ruffle_height: float = 0.14:
	set(value):
		ruffle_height = value
		queue_redraw()
## Horn length, as a fraction of the height.
@export_range(0.0, 0.5, 0.01) var horn_length: float = 0.16:
	set(value):
		horn_length = value
		queue_redraw()

@export_group("Colours")
@export var body_color: Color = Color(0.13, 0.04, 0.05, 1):
	set(value):
		body_color = value
		queue_redraw()
@export var shade_color: Color = Color(0.05, 0.01, 0.02, 1):
	set(value):
		shade_color = value
		queue_redraw()
@export var highlight_color: Color = Color(0.42, 0.1, 0.09, 0.55):
	set(value):
		highlight_color = value
		queue_redraw()
@export var cord_color: Color = Color(0.62, 0.45, 0.18, 1):
	set(value):
		cord_color = value
		queue_redraw()
@export var horn_color: Color = Color(0.2, 0.06, 0.05, 1):
	set(value):
		horn_color = value
		queue_redraw()
## The ember seams, the sigil and the light inside.
@export var glow_color: Color = Color(1.0, 0.32, 0.08, 1):
	set(value):
		glow_color = value
		queue_redraw()
@export var shadow_color: Color = Color(0, 0, 0, 0.45):
	set(value):
		shadow_color = value
		queue_redraw()

@export_group("Idle")
## How much the pouch swells as it breathes, as a fraction of its size.
@export var breath_amount: float = 0.025
## Breaths per second.
@export var breath_speed: float = 0.8
## How strongly the seams glow at rest, and how much that pulses.
@export var idle_glow: float = 0.45
@export var idle_glow_pulse: float = 0.25
## How much bigger the pouch is drawn under the mouse.
@export var hover_scale: float = 1.06
@export var hover_time: float = 0.12

@export_group("Opening")
## The squash before the pop: how long, and how squashed.
@export var windup_time: float = 0.28
@export var windup_squash: Vector2 = Vector2(1.12, 0.84)
## The shake: how long, how many swings, how far each one leans in degrees.
@export var shake_time: float = 0.42
@export var shake_swings: int = 6
@export var shake_degrees: float = 7.0
## The pop itself: how long, and how big.
@export var pop_time: float = 0.14
@export var pop_scale: Vector2 = Vector2(1.18, 1.22)
## Settling back open.
@export var settle_time: float = 0.4
## The glow at the moment of the pop, and the ring and sparks thrown out by it.
@export var burst_glow: float = 2.2
@export var burst_time: float = 0.6
@export var burst_radius: float = 200.0
@export_range(0, 64) var burst_sparks: int = 16
## The glow left in the open pouch.
@export var open_glow: float = 1.0

## 0 closed .. 1 open - how far the neck has splayed.
var open_amount: float = 0.0:
	set(value):
		open_amount = value
		queue_redraw()
## Extra glow over the idle level.
var glow: float = 0.0:
	set(value):
		glow = value
		queue_redraw()
## 0 .. 1 progress of the burst ring; outside that range nothing is drawn.
var burst_progress: float = -1.0:
	set(value):
		burst_progress = value
		queue_redraw()

var _time: float = 0.0
var _opening: bool = false
var _open: bool = false
var _hover_tween: Tween
var _open_tween: Tween


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	_centre_pivot()
	resized.connect(_centre_pivot)
	if Engine.is_editor_hint():
		return
	# A press is only reported - whoever owns the pouch decides to [method open] it.
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func is_open() -> bool:
	return _open


func is_opening() -> bool:
	return _opening


## Puts the pouch back shut and whole, for a fresh bundle.
func reset() -> void:
	_kill(_open_tween)
	_kill(_hover_tween)
	_opening = false
	_open = false
	disabled = false
	open_amount = 0.0
	glow = 0.0
	burst_progress = -1.0
	scale = Vector2.ONE
	rotation = 0.0


## Plays the opening; [signal burst] fires at the pop and [signal opened] at the
## end. [param instant] skips straight to open, both signals still firing.
func open(instant: bool = false) -> void:
	if _opening or _open:
		return
	_opening = true
	disabled = true
	_kill(_hover_tween)
	if instant:
		scale = Vector2.ONE
		rotation = 0.0
		open_amount = 1.0
		glow = open_glow
		_on_burst()
		_on_opened()
		return

	_open_tween = create_tween()
	_open_tween.tween_property(self, "scale", windup_squash, maxf(windup_time, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var swings := maxi(shake_swings, 1)
	var swing_time := maxf(shake_time, 0.001) / float(swings + 1)
	for swing: int in swings:
		var lean := shake_degrees * (1.0 if swing % 2 == 0 else -1.0) \
			* (1.0 - float(swing) / float(swings + 1))
		_open_tween.tween_property(self, "rotation", deg_to_rad(lean), swing_time)
		_open_tween.parallel().tween_property(self, "glow",
			float(swing + 1) / float(swings) * 0.8, swing_time)
	_open_tween.tween_property(self, "rotation", 0.0, swing_time)
	_open_tween.tween_property(self, "scale", pop_scale, maxf(pop_time, 0.001)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(self, "open_amount", 1.0, maxf(pop_time, 0.001))
	_open_tween.parallel().tween_property(self, "glow", burst_glow, maxf(pop_time, 0.001))
	_open_tween.tween_callback(_on_burst)
	_open_tween.tween_property(self, "scale", Vector2.ONE, maxf(settle_time, 0.001)) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(self, "glow", open_glow, maxf(settle_time, 0.001))
	_open_tween.tween_callback(_on_opened)


func _on_burst() -> void:
	burst_progress = 0.0
	var ring := create_tween()
	ring.tween_property(self, "burst_progress", 1.0, maxf(burst_time, 0.001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring.tween_callback(func() -> void: burst_progress = -1.0)
	burst.emit()


func _on_opened() -> void:
	_opening = false
	_open = true
	opened.emit()


func _on_hover(inside: bool) -> void:
	if _opening or _open:
		return
	_kill(_hover_tween)
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (hover_scale if inside else 1.0),
		maxf(hover_time, 0.001))


func _centre_pivot() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y * 0.85)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var breath := 1.0
	if not _open and not _opening:
		breath += sin(_time * TAU * breath_speed) * breath_amount
	var base := Vector2(w * 0.5, h * 0.92)
	draw_set_transform(base, 0.0, Vector2(1.0 / breath, breath))
	var o := -base

	var seam := idle_glow + sin(_time * TAU * breath_speed * 1.3) * idle_glow_pulse + glow
	var hot := glow_color
	hot.a = clampf(seam * 0.5, 0.0, 1.0)

	# Ground shadow and the aura behind it.
	_draw_ellipse(o + Vector2(w * 0.5, h * 0.93), Vector2(w * 0.42, h * 0.06), shadow_color)
	for ring: int in 4:
		var aura := glow_color
		aura.a = clampf(seam * 0.07 * float(4 - ring) / 4.0, 0.0, 1.0)
		_draw_ellipse(o + Vector2(w * 0.5, h * 0.6), Vector2(w, h) * (0.5 + ring * 0.08), aura)

	var neck_y := h * neck_height
	var neck_half := w * neck_width * 0.5
	var belly_half := w * belly_width * 0.5

	# The sack.
	var body := _sack_outline(o, w, h, neck_y, neck_half, belly_half)
	draw_colored_polygon(body, body_color)
	# Shade across the bottom, highlight on the upper left.
	_draw_ellipse(o + Vector2(w * 0.54, h * 0.78), Vector2(belly_half * 0.9, h * 0.12), shade_color)
	_draw_ellipse(o + Vector2(w * 0.38, h * 0.52), Vector2(belly_half * 0.34, h * 0.14),
		highlight_color)
	draw_polyline(_closed(body), shade_color, 3.0, true)

	# Ember seams down the belly.
	for i: int in 3:
		var x := w * (0.36 + 0.14 * i)
		var seam_line := PackedVector2Array([
			o + Vector2(x, neck_y + h * 0.1),
			o + Vector2(x + w * 0.03, h * 0.5),
			o + Vector2(x - w * 0.02, h * 0.68),
			o + Vector2(x + w * 0.01, h * 0.84)])
		draw_polyline(seam_line, hot, 2.0, true)

	# The sigil: a coin with a horned mark.
	var coin := o + Vector2(w * 0.5, h * 0.62)
	var coin_r := w * 0.11
	draw_circle(coin, coin_r, shade_color)
	draw_arc(coin, coin_r, 0.0, TAU, 32, hot.lerp(cord_color, 0.3), 3.0, true)
	var mark := hot
	mark.a = clampf(seam * 0.8, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([
		coin + Vector2(-coin_r * 0.55, -coin_r * 0.55),
		coin + Vector2(-coin_r * 0.2, -coin_r * 0.1),
		coin + Vector2(0.0, coin_r * 0.6),
		coin + Vector2(coin_r * 0.2, -coin_r * 0.1),
		coin + Vector2(coin_r * 0.55, -coin_r * 0.55),
		coin + Vector2(0.0, -coin_r * 0.2)]), mark)

	# The open mouth and the light coming out of it.
	var mouth_centre := o + Vector2(w * 0.5, neck_y - h * ruffle_height * 0.4)
	if open_amount > 0.0:
		var beam := glow_color
		beam.a = clampf(0.35 * open_amount * (0.6 + glow * 0.4), 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([
			mouth_centre + Vector2(-neck_half * 0.9, 0.0),
			mouth_centre + Vector2(-neck_half * 2.4, -h * 0.9 * open_amount),
			mouth_centre + Vector2(neck_half * 2.4, -h * 0.9 * open_amount),
			mouth_centre + Vector2(neck_half * 0.9, 0.0)]), beam)
		_draw_ellipse(mouth_centre, Vector2(neck_half * (1.0 + open_amount * 0.9),
			h * 0.05 * (0.4 + open_amount)), shade_color)
		var inner := glow_color
		inner.a = clampf(open_amount, 0.0, 1.0)
		_draw_ellipse(mouth_centre, Vector2(neck_half * (0.8 + open_amount * 0.7),
			h * 0.035 * (0.4 + open_amount)), inner)

	# The ruffled top, splaying outward as the pouch opens.
	var splay := open_amount
	var top := neck_y - h * ruffle_height
	var ruffle := PackedVector2Array([
		o + Vector2(w * 0.5 - neck_half, neck_y),
		o + Vector2(w * 0.5 - neck_half * (1.3 + splay * 1.1), top + h * 0.02 * splay),
		o + Vector2(w * 0.5 - neck_half * 0.45 * (1.0 + splay), top - h * 0.02),
		o + Vector2(w * 0.5, top + h * 0.03),
		o + Vector2(w * 0.5 + neck_half * 0.45 * (1.0 + splay), top - h * 0.02),
		o + Vector2(w * 0.5 + neck_half * (1.3 + splay * 1.1), top + h * 0.02 * splay),
		o + Vector2(w * 0.5 + neck_half, neck_y)])
	if splay > 0.0:
		# Open, the middle of the ruffle is the mouth - only its two lips are drawn.
		draw_colored_polygon(PackedVector2Array([ruffle[0], ruffle[1], ruffle[2]]), body_color)
		draw_colored_polygon(PackedVector2Array([ruffle[4], ruffle[5], ruffle[6]]), body_color)
	else:
		draw_colored_polygon(ruffle, body_color)
		draw_polyline(ruffle, shade_color, 2.0, true)

	# Horns off the ruffle.
	var horn := h * horn_length
	for side: float in [-1.0, 1.0]:
		var root := o + Vector2(w * 0.5 + side * neck_half * (1.05 + splay * 0.9), top + h * 0.05)
		draw_colored_polygon(PackedVector2Array([
			root + Vector2(-side * horn * 0.15, 0.0),
			root + Vector2(side * horn * 0.05, -horn * 0.55),
			root + Vector2(side * horn * 0.45, -horn),
			root + Vector2(side * horn * 0.22, -horn * 0.5),
			root + Vector2(side * horn * 0.2, 0.0)]), horn_color)

	# The cord round the neck and its knot.
	var cord_y := neck_y
	draw_line(o + Vector2(w * 0.5 - neck_half * 1.1, cord_y),
		o + Vector2(w * 0.5 + neck_half * 1.1, cord_y), cord_color, 5.0, true)
	var knot := o + Vector2(w * 0.5 + neck_half * 0.5, cord_y)
	draw_circle(knot, 6.0, cord_color)
	draw_line(knot, knot + Vector2(w * 0.05, h * 0.12), cord_color, 3.0, true)
	draw_line(knot, knot + Vector2(w * 0.11, h * 0.08), cord_color, 3.0, true)

	# The burst: a ring and sparks thrown out from the mouth.
	if burst_progress >= 0.0 and burst_progress <= 1.0:
		var fade := 1.0 - burst_progress
		var ring_color := glow_color
		ring_color.a = fade
		var r := burst_radius * burst_progress
		draw_arc(mouth_centre, r, 0.0, TAU, 48, ring_color, 6.0 * fade + 1.0, true)
		for spark: int in burst_sparks:
			var angle := TAU * float(spark) / float(maxi(burst_sparks, 1)) + 0.3
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(mouth_centre + dir * r * 0.6, mouth_centre + dir * r * 0.9,
				ring_color, 3.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sack_outline(o: Vector2, w: float, h: float, neck_y: float,
		neck_half: float, belly_half: float) -> PackedVector2Array:
	var cx := w * 0.5
	var bottom := h * 0.92
	var curve := Curve2D.new()
	curve.add_point(o + Vector2(cx - neck_half, neck_y))
	curve.add_point(o + Vector2(cx - belly_half, h * 0.62),
		Vector2(0.0, -h * 0.2), Vector2(0.0, h * 0.18))
	curve.add_point(o + Vector2(cx, bottom),
		Vector2(-belly_half * 0.7, 0.0), Vector2(belly_half * 0.7, 0.0))
	curve.add_point(o + Vector2(cx + belly_half, h * 0.62),
		Vector2(0.0, h * 0.18), Vector2(0.0, -h * 0.2))
	curve.add_point(o + Vector2(cx + neck_half, neck_y))
	return curve.tessellate(5, 3.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


func _draw_ellipse(centre: Vector2, radii: Vector2, color: Color) -> void:
	if color.a <= 0.0 or radii.x <= 0.0 or radii.y <= 0.0:
		return
	var points := PackedVector2Array()
	for i: int in 32:
		var angle := TAU * float(i) / 32.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
