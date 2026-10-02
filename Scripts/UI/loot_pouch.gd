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
## [b]Opening is one tween in four beats.[/b] [method open] works the cord loose
## ([member untie]), loosens the mouth ([member open_amount]), gives the pouch a
## shake, then tips it over so it slumps flat on the table
## ([member flatten]) - and part way into that slump, at
## [member spill_at], is [signal burst]: the screen's cue to deal the rewards out
## of the mouth ([method get_spill_point]). Every duration and size of that is
## an export.
##
## [b]It stays.[/b] Once open the pouch is left lying in the middle of the table
## as an empty, flattened cloth with its cord beside it, for as long as the
## table is up; it only closes again on [method reset], for the next bundle. Open,
## it lets the mouse through to the loot around it.
##
## It is a flat [Button] with no lettering, so the game's own pointer shows its hover art over it -
## see [method GameCursor._apply_hover].

## The pouch is spilling: the rewards should fly out now.
signal burst
## The opening has finished and the pouch is lying open.
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

@export_group("Shape/Lying Open")
## How wide the emptied cloth lies, as a multiple of the belly's width.
@export_range(0.5, 2.5, 0.01) var flat_width: float = 1.3:
	set(value):
		flat_width = value
		queue_redraw()
## How tall the emptied cloth lies, as a fraction of the control's height.
@export_range(0.1, 1.0, 0.01) var flat_height: float = 0.42:
	set(value):
		flat_height = value
		queue_redraw()
## Where the cloth's middle lies, as a fraction of the control's height.
@export_range(0.0, 1.0, 0.01) var flat_centre: float = 0.74:
	set(value):
		flat_centre = value
		queue_redraw()
## How big the open mouth is on the lying cloth, as a fraction of the cloth.
@export_range(0.1, 0.95, 0.01) var flat_mouth: float = 0.62:
	set(value):
		flat_mouth = value
		queue_redraw()
## How far the loose cord trails out across the table, as a multiple of the
## cloth's half width.
@export_range(0.0, 3.0, 0.01) var cord_trail: float = 1.45:
	set(value):
		cord_trail = value
		queue_redraw()
## Shows the opened state in the editor, for tuning the shapes above.
@export var preview_open: bool = false:
	set(value):
		preview_open = value
		if Engine.is_editor_hint():
			untie = 1.0 if value else 0.0
			open_amount = untie
			flatten = untie

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
## The inside of the cloth, seen through the open mouth.
@export var lining_color: Color = Color(0.03, 0.005, 0.01, 1):
	set(value):
		lining_color = value
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
## The cord being worked loose: how long it takes, how many tugs, and how far
## each tug leans the pouch, in degrees.
@export var untie_time: float = 0.6
@export_range(1, 12) var untie_tugs: int = 3
@export var untie_tug_degrees: float = 4.0
## The tug's squash at its hardest.
@export var untie_tug_squash: Vector2 = Vector2(1.05, 0.95)
## The mouth loosening once the cord is off.
@export var loosen_time: float = 0.3
@export var loosen_puff: Vector2 = Vector2(1.06, 1.08)
## The shake before it tips: how long, how many swings, how far each leans.
@export var shake_time: float = 0.3
@export_range(1, 16) var shake_swings: int = 4
@export var shake_degrees: float = 6.0
## Tipping over and slumping flat: how long, and its easing.
@export var flatten_time: float = 0.42
@export var flatten_transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var flatten_ease: Tween.EaseType = Tween.EASE_IN_OUT
## How far into the slump the rewards pour out, 0..1.
@export_range(0.0, 1.0, 0.01) var spill_at: float = 0.4
## The little bounce as the cloth lands flat.
@export var settle_time: float = 0.4
@export var settle_squash: Vector2 = Vector2(1.06, 0.9)
## The glow at the moment of the spill, and the ring and sparks thrown out by it.
@export var burst_glow: float = 1.8
@export var burst_time: float = 0.55
@export var burst_radius: float = 150.0
@export_range(0, 64) var burst_sparks: int = 12
## The glow left in the open pouch.
@export var open_glow: float = 0.7

## 0 tied .. 1 the cord is off.
var untie: float = 0.0:
	set(value):
		untie = value
		queue_redraw()
## 0 closed .. 1 open - how far the neck has loosened.
var open_amount: float = 0.0:
	set(value):
		open_amount = value
		queue_redraw()
## 0 standing .. 1 lying flat and empty on the table.
var flatten: float = 0.0:
	set(value):
		flatten = value
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	untie = 0.0
	open_amount = 0.0
	flatten = 0.0
	glow = 0.0
	burst_progress = -1.0
	scale = Vector2.ONE
	rotation = 0.0


## Where the rewards pour out from right now - the middle of the mouth - in
## global coordinates.
func get_spill_point() -> Vector2:
	return get_global_transform() * _mouth_centre(size.x, size.y)


## Plays the opening; [signal burst] fires at the spill and [signal opened] at
## the end. [param instant] skips straight to lying open, both signals still
## firing.
func open(instant: bool = false) -> void:
	if _opening or _open:
		return
	_opening = true
	disabled = true
	_kill(_hover_tween)
	if instant:
		scale = Vector2.ONE
		rotation = 0.0
		untie = 1.0
		open_amount = 1.0
		flatten = 1.0
		glow = open_glow
		_on_burst()
		_on_opened()
		return

	_open_tween = create_tween()
	# 1. The cord is worked loose, a tug at a time.
	var tugs := maxi(untie_tugs, 1)
	var tug_time := maxf(untie_time, 0.001) / float(tugs)
	_open_tween.tween_property(self, "untie", 1.0, maxf(untie_time, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tugging := create_tween()
	_open_tween.parallel().tween_subtween(tugging)
	for tug: int in tugs:
		var lean := untie_tug_degrees * (1.0 if tug % 2 == 0 else -1.0)
		tugging.tween_property(self, "rotation", deg_to_rad(lean), tug_time * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tugging.parallel().tween_property(self, "scale", untie_tug_squash, tug_time * 0.4)
		tugging.tween_property(self, "rotation", 0.0, tug_time * 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tugging.parallel().tween_property(self, "scale", Vector2.ONE, tug_time * 0.6)
	# 2. The mouth loosens.
	_open_tween.tween_property(self, "open_amount", 1.0, maxf(loosen_time, 0.001)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(self, "scale", loosen_puff, maxf(loosen_time, 0.001))
	_open_tween.parallel().tween_property(self, "glow", 0.5, maxf(loosen_time, 0.001))
	# 3. A shake as it is upended.
	var swings := maxi(shake_swings, 1)
	var swing_time := maxf(shake_time, 0.001) / float(swings + 1)
	for swing: int in swings:
		var lean := shake_degrees * (1.0 if swing % 2 == 0 else -1.0) \
			* (1.0 - float(swing) / float(swings + 1))
		_open_tween.tween_property(self, "rotation", deg_to_rad(lean), swing_time)
		_open_tween.parallel().tween_property(self, "glow",
			0.5 + float(swing + 1) / float(swings) * 0.5, swing_time)
	# 4. It slumps flat and the contents pour out part way through.
	var slump := maxf(flatten_time, 0.001)
	_open_tween.tween_property(self, "flatten", 1.0, slump) \
		.set_trans(flatten_transition).set_ease(flatten_ease)
	_open_tween.parallel().tween_property(self, "rotation", 0.0, slump)
	_open_tween.parallel().tween_property(self, "scale", Vector2.ONE, slump)
	_open_tween.parallel().tween_property(self, "glow", burst_glow, slump)
	_open_tween.parallel().tween_callback(_on_burst).set_delay(slump * clampf(spill_at, 0.0, 1.0))
	# 5. The cloth lands and settles.
	_open_tween.tween_property(self, "scale", settle_squash, maxf(settle_time, 0.001) * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "scale", Vector2.ONE, maxf(settle_time, 0.001) * 0.7) \
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
	# Lying open it is part of the table: the loot around it takes the mouse.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


# --- Shape ------------------------------------------------------------------------

## The sack's measurements for the current [member flatten] and
## [member open_amount], in the control's own space: [code]neck_y[/code],
## [code]neck_half[/code], [code]belly_half[/code], [code]belly_y[/code],
## [code]bottom[/code].
func _measure(w: float, h: float) -> Dictionary:
	var f := clampf(flatten, 0.0, 1.0)
	var flat_half_w := w * belly_width * 0.5 * flat_width
	var flat_half_h := h * flat_height * 0.5
	var cy := h * flat_centre
	var loosened := w * neck_width * 0.5 * (1.0 + 0.35 * open_amount)
	return {
		&"neck_y": lerpf(h * neck_height, cy - flat_half_h * 0.85, f),
		&"neck_half": lerpf(loosened, flat_half_w * 0.78, f),
		&"belly_half": lerpf(w * belly_width * 0.5, flat_half_w, f),
		&"belly_y": lerpf(h * 0.62, cy, f),
		&"bottom": lerpf(h * 0.92, cy + flat_half_h, f),
		&"flat_half_w": flat_half_w,
		&"flat_half_h": flat_half_h,
		&"cy": cy,
	}


func _mouth_centre(w: float, h: float) -> Vector2:
	var m := _measure(w, h)
	var standing := float(m[&"neck_y"]) - h * ruffle_height * 0.4
	return Vector2(w * 0.5, lerpf(standing, float(m[&"cy"]) - float(m[&"flat_half_h"]) * 0.1,
		clampf(flatten, 0.0, 1.0)))


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var f := clampf(flatten, 0.0, 1.0)
	var breath := 1.0
	if not _open and not _opening:
		breath += sin(_time * TAU * breath_speed) * breath_amount
	var base := Vector2(w * 0.5, h * 0.92)
	draw_set_transform(base, 0.0, Vector2(1.0 / breath, breath))
	var o := -base

	var seam := idle_glow + sin(_time * TAU * breath_speed * 1.3) * idle_glow_pulse + glow
	var hot := glow_color
	hot.a = clampf(seam * 0.5, 0.0, 1.0)

	var m := _measure(w, h)
	var neck_y: float = m[&"neck_y"]
	var neck_half: float = m[&"neck_half"]
	var belly_half: float = m[&"belly_half"]
	var belly_y: float = m[&"belly_y"]
	var bottom: float = m[&"bottom"]
	var flat_half_w: float = m[&"flat_half_w"]
	var flat_half_h: float = m[&"flat_half_h"]

	# Ground shadow and the aura behind it.
	_draw_ellipse(o + Vector2(w * 0.5, lerpf(h * 0.93, bottom, f)),
		Vector2(lerpf(w * 0.42, flat_half_w * 1.05, f), lerpf(h * 0.06, flat_half_h * 0.45, f)),
		shadow_color)
	for ring: int in 4:
		var aura := glow_color
		aura.a = clampf(seam * 0.07 * float(4 - ring) / 4.0, 0.0, 1.0)
		_draw_ellipse(o + Vector2(w * 0.5, lerpf(h * 0.6, belly_y, f)),
			Vector2(w, lerpf(h, flat_half_h * 2.4, f)) * (0.5 + ring * 0.08), aura)

	# The cloth.
	var body := _sack_outline(o, w, neck_y, neck_half, belly_half, belly_y, bottom)
	draw_colored_polygon(body, body_color)
	_draw_ellipse(o + Vector2(w * 0.54, lerpf(h * 0.78, bottom - flat_half_h * 0.35, f)),
		Vector2(belly_half * 0.9, lerpf(h * 0.12, flat_half_h * 0.3, f)), shade_color)
	_draw_ellipse(o + Vector2(w * 0.5 - belly_half * 0.35, lerpf(h * 0.52, belly_y - flat_half_h * 0.4,
		f)), Vector2(belly_half * 0.34, lerpf(h * 0.14, flat_half_h * 0.2, f)), highlight_color)
	draw_polyline(_closed(body), shade_color, 3.0, true)

	# Ember seams and the sigil fade as the cloth goes flat.
	var standing := 1.0 - f
	if standing > 0.0:
		var seam_color := hot
		seam_color.a *= standing
		for i: int in 3:
			var x := w * (0.36 + 0.14 * i)
			draw_polyline(PackedVector2Array([
				o + Vector2(x, neck_y + h * 0.1),
				o + Vector2(x + w * 0.03, h * 0.5),
				o + Vector2(x - w * 0.02, h * 0.68),
				o + Vector2(x + w * 0.01, h * 0.84)]), seam_color, 2.0, true)
		var coin := o + Vector2(w * 0.5, h * 0.62)
		var coin_r := w * 0.11
		draw_circle(coin, coin_r, Color(shade_color, standing))
		var rim := hot.lerp(cord_color, 0.3)
		rim.a *= standing
		draw_arc(coin, coin_r, 0.0, TAU, 32, rim, 3.0, true)
		var mark := hot
		mark.a = clampf(seam * 0.8, 0.0, 1.0) * standing
		draw_colored_polygon(PackedVector2Array([
			coin + Vector2(-coin_r * 0.55, -coin_r * 0.55),
			coin + Vector2(-coin_r * 0.2, -coin_r * 0.1),
			coin + Vector2(0.0, coin_r * 0.6),
			coin + Vector2(coin_r * 0.2, -coin_r * 0.1),
			coin + Vector2(coin_r * 0.55, -coin_r * 0.55),
			coin + Vector2(0.0, -coin_r * 0.2)]), mark)

	# The mouth: a slit while standing, the whole emptied opening lying flat.
	var mouth := o + _mouth_centre(w, h)
	if open_amount > 0.0:
		var mouth_radii := Vector2(
			lerpf(neck_half * (0.8 + open_amount * 0.7), flat_half_w * flat_mouth, f),
			lerpf(h * 0.035 * (0.4 + open_amount), flat_half_h * flat_mouth, f))
		if standing > 0.0:
			var beam := glow_color
			beam.a = clampf(0.3 * open_amount * (0.6 + glow * 0.4), 0.0, 1.0) * standing
			draw_colored_polygon(PackedVector2Array([
				mouth + Vector2(-neck_half * 0.9, 0.0),
				mouth + Vector2(-neck_half * 2.2, -h * 0.8 * open_amount),
				mouth + Vector2(neck_half * 2.2, -h * 0.8 * open_amount),
				mouth + Vector2(neck_half * 0.9, 0.0)]), beam)
		# The rolled lip of cloth round the opening, then the dark inside.
		_draw_ellipse(mouth, mouth_radii * Vector2(1.14, 1.3), body_color.lightened(0.12))
		_draw_ellipse(mouth, mouth_radii, lining_color.lerp(shade_color, standing))
		var inner := glow_color
		var pulse := 0.85 + 0.15 * sin(_time * TAU * breath_speed)
		inner.a = clampf(open_amount * lerpf(1.0, 0.45 * pulse * (0.6 + glow * 0.5), f), 0.0, 1.0)
		_draw_ellipse(mouth + Vector2(0.0, mouth_radii.y * 0.12 * f), mouth_radii * 0.78, inner)
		var deep := lining_color
		deep.a = f * 0.85
		_draw_ellipse(mouth + Vector2(0.0, mouth_radii.y * 0.18), mouth_radii * 0.5, deep)
		# The front lip, over the bottom of the opening.
		if f > 0.0:
			var lip := body_color.lightened(0.05)
			lip.a = f
			_draw_ellipse_arc(mouth, mouth_radii * Vector2(1.06, 1.12), 0.12, PI - 0.12, lip,
				maxf(mouth_radii.y * 0.3, 2.0))
			_draw_ellipse_arc(mouth, mouth_radii * Vector2(0.96, 1.02), 0.35, PI - 0.35,
				Color(highlight_color, highlight_color.a * f), 2.0)
			# Folds in the slumped cloth.
			for side: float in [-1.0, 1.0]:
				var fold := o + Vector2(w * 0.5 + side * flat_half_w * 0.86, belly_y)
				draw_line(fold, fold + Vector2(-side * flat_half_w * 0.18, flat_half_h * 0.45),
					Color(shade_color, f), 2.0, true)

	# The ruffled top, standing only - it splays as the mouth opens.
	var splay := open_amount
	var top := neck_y - h * ruffle_height
	if standing > 0.0:
		var ruffle_color := Color(body_color, standing)
		var ruffle := PackedVector2Array([
			o + Vector2(w * 0.5 - neck_half, neck_y),
			o + Vector2(w * 0.5 - neck_half * (1.3 + splay * 1.1), top + h * 0.02 * splay),
			o + Vector2(w * 0.5 - neck_half * 0.45 * (1.0 + splay), top - h * 0.02),
			o + Vector2(w * 0.5, top + h * 0.03),
			o + Vector2(w * 0.5 + neck_half * 0.45 * (1.0 + splay), top - h * 0.02),
			o + Vector2(w * 0.5 + neck_half * (1.3 + splay * 1.1), top + h * 0.02 * splay),
			o + Vector2(w * 0.5 + neck_half, neck_y)])
		if splay > 0.0:
			draw_colored_polygon(PackedVector2Array([ruffle[0], ruffle[1], ruffle[2]]), ruffle_color)
			draw_colored_polygon(PackedVector2Array([ruffle[4], ruffle[5], ruffle[6]]), ruffle_color)
		else:
			draw_colored_polygon(ruffle, ruffle_color)
			draw_polyline(ruffle, Color(shade_color, standing), 2.0, true)

	# Horns: up off the ruffle while standing, lying out flat at the cloth's
	# shoulders once it is down.
	var horn := h * horn_length
	for side: float in [-1.0, 1.0]:
		var root := o + Vector2(w * 0.5 + side * lerpf(neck_half * (1.05 + splay * 0.9),
			flat_half_w * 0.92, f), lerpf(top + h * 0.05, neck_y + flat_half_h * 0.2, f))
		var turn := side * f * deg_to_rad(70.0)
		var points := PackedVector2Array()
		for corner: Vector2 in [Vector2(-side * horn * 0.15, 0.0), Vector2(side * horn * 0.05,
				-horn * 0.55), Vector2(side * horn * 0.45, -horn), Vector2(side * horn * 0.22,
				-horn * 0.5), Vector2(side * horn * 0.2, 0.0)]:
			points.append(root + corner.rotated(turn))
		draw_colored_polygon(points, horn_color)

	_draw_cord(o, w, h, neck_y, neck_half, flat_half_w, flat_half_h, f)

	# The burst: a ring and sparks thrown out from the mouth.
	if burst_progress >= 0.0 and burst_progress <= 1.0:
		var fade := 1.0 - burst_progress
		var ring_color := glow_color
		ring_color.a = fade
		var r := burst_radius * burst_progress
		draw_arc(mouth, r, 0.0, TAU, 48, ring_color, 6.0 * fade + 1.0, true)
		for spark: int in burst_sparks:
			var angle := TAU * float(spark) / float(maxi(burst_sparks, 1)) + 0.3
			var dir := Vector2(cos(angle), sin(angle) * 0.6)
			draw_line(mouth + dir * r * 0.6, mouth + dir * r * 0.9, ring_color, 3.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The drawstring: tied round the neck, worked loose as [member untie] rises, and
## lying slack across the table beside the emptied cloth once it is down.
func _draw_cord(o: Vector2, w: float, h: float, neck_y: float, neck_half: float,
		flat_half_w: float, flat_half_h: float, f: float) -> void:
	var u := clampf(untie, 0.0, 1.0)
	var standing := 1.0 - f
	if standing > 0.0:
		var tied := Color(cord_color, standing)
		# The band round the neck sags as it loosens.
		var sag := h * 0.045 * u
		var band := PackedVector2Array()
		for i: int in 9:
			var t := float(i) / 8.0
			band.append(o + Vector2(w * 0.5 - neck_half * 1.1 + neck_half * 2.2 * t,
				neck_y + sag * sin(t * PI)))
		draw_polyline(band, tied, lerpf(5.0, 3.5, u), true)
		# The knot loosens and its two ends swing longer and freer.
		var knot := o + Vector2(w * 0.5 + neck_half * 0.5, neck_y + sag * 0.7)
		draw_circle(knot, lerpf(6.0, 3.0, u), tied)
		var swing := sin(_time * 9.0) * 0.35 * u * (1.0 - u * 0.5)
		for end: int in 2:
			var reach := Vector2(w * (0.05 + 0.06 * end), h * (0.12 - 0.04 * end)) * (1.0 + u * 0.9)
			draw_line(knot, knot + reach.rotated(swing * (1.0 if end == 0 else -0.7)), tied,
				3.0, true)
	if f > 0.0:
		# Slack on the table: out of the cloth's right shoulder in a lazy curve.
		var lying := Color(cord_color, f)
		var start := o + Vector2(w * 0.5 + flat_half_w * 0.55, neck_y + flat_half_h * 0.3)
		var length := flat_half_w * cord_trail * f
		var trail := PackedVector2Array()
		for i: int in 13:
			var t := float(i) / 12.0
			trail.append(start + Vector2(length * t, flat_half_h * 0.9 * t + sin(t * TAU * 1.2)
				* flat_half_h * 0.22))
		draw_polyline(trail, lying, 3.5, true)
		draw_circle(trail[trail.size() - 1], 3.0, lying)


func _sack_outline(o: Vector2, w: float, neck_y: float, neck_half: float, belly_half: float,
		belly_y: float, bottom: float) -> PackedVector2Array:
	var cx := w * 0.5
	var depth := bottom - neck_y
	var curve := Curve2D.new()
	curve.add_point(o + Vector2(cx - neck_half, neck_y))
	curve.add_point(o + Vector2(cx - belly_half, belly_y),
		Vector2(0.0, -depth * 0.32), Vector2(0.0, depth * 0.3))
	curve.add_point(o + Vector2(cx, bottom),
		Vector2(-belly_half * 0.7, 0.0), Vector2(belly_half * 0.7, 0.0))
	curve.add_point(o + Vector2(cx + belly_half, belly_y),
		Vector2(0.0, depth * 0.3), Vector2(0.0, -depth * 0.32))
	curve.add_point(o + Vector2(cx + neck_half, neck_y))
	# The top edge of the cloth, bowed up a little once it is lying open.
	var lip := depth * 0.18 * clampf(flatten, 0.0, 1.0)
	curve.add_point(o + Vector2(cx, neck_y - lip),
		Vector2(neck_half * 0.6, 0.0), Vector2(-neck_half * 0.6, 0.0))
	return curve.tessellate(5, 3.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


## Part of an ellipse's rim, from angle [param from] to [param to] (0 is right,
## PI / 2 the bottom).
func _draw_ellipse_arc(centre: Vector2, radii: Vector2, from: float, to: float, color: Color,
		width: float) -> void:
	if color.a <= 0.0 or radii.x <= 0.0 or radii.y <= 0.0:
		return
	var points := PackedVector2Array()
	for i: int in 25:
		var angle := lerpf(from, to, float(i) / 24.0)
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)


func _draw_ellipse(centre: Vector2, radii: Vector2, color: Color) -> void:
	if color.a <= 0.0 or radii.x <= 0.0 or radii.y <= 0.0:
		return
	var points := PackedVector2Array()
	for i: int in 32:
		var angle := TAU * float(i) / 32.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
