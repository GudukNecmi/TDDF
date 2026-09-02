extends Control
## The World Map's own clock face for Phase 2 validation: a compact 360° dial
## whose hand reads straight off [WorldTimeManager] every frame, so it turns
## exactly as smoothly as the world's own sun does and nothing here keeps a
## second copy of the time.
##
## Development-grade presentation, the same way
## [code]world_map_debug_readout.gd[/code] is - a real HUD, a minimap and fog
## of war are later-phase work; this exists only so Phase 2's continuous
## clock can be checked by eye. [b]It only shows itself on the World Map[/b],
## gated the same way and for the same reason that readout is: a
## [CanvasLayer] draws over the whole viewport regardless of where the camera
## is, and the World Map never leaves the tree.

## The World Map's own [WorldZone], asked whether the player is inside it so
## this never draws over anywhere else in the game.
@export var zone_id: StringName = &"world_map"
## The World Map's own continuous clock, asked rather than copied - the same
## autoload [SunController] and [WorldMapState] resolve it by.
@export var world_time_path: NodePath = ^"/root/WorldClock"

@export_group("Face")
## Radius of the dial, in pixels.
@export var radius: float = 40.0
## One colour per period, in [enum WorldTimeManager.TimePeriod] order - dawn
## through night - painted as the six wedges of the face. A visual anchor
## only: nothing here reads a [SunStage]'s own colours, so the face and the
## sky are free to be tuned apart.
@export var period_colors: Array[Color] = [
	Color(0.85, 0.55, 0.35), Color(0.95, 0.8, 0.4), Color(0.95, 0.92, 0.78),
	Color(0.85, 0.45, 0.3), Color(0.42, 0.32, 0.58), Color(0.08, 0.09, 0.2)]
## Colour of the hand and the centre pin.
@export var hand_color := Color(1.0, 0.9, 0.6)
## Colour of the ring drawn round the face's own edge.
@export var rim_color := Color(0.05, 0.03, 0.01)

## Text beside the dial. Optional - a face with neither still draws the hand
## and the six wedges, which is the whole of what the dial itself promises.
@export_group("Nodes")
@export var day_label_path: NodePath = ^"DayLabel"
@export var period_label_path: NodePath = ^"PeriodLabel"

## The clock read this frame, for [method _draw] - which cannot ask
## [WorldTimeManager] itself, since it only runs when [method queue_redraw]
## asks for it and the World Map's own degree has to be whatever it was at
## the moment that request was made.
var _degree: float = 0.0

var _world_time: Node
var _day_label: Label
var _period_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * radius * 2.0
	_world_time = get_node_or_null(world_time_path)
	_day_label = get_node_or_null(day_label_path) as Label
	_period_label = get_node_or_null(period_label_path) as Label


func _process(_delta: float) -> void:
	var zone := WorldZone.get_by_id(self, zone_id)
	visible = zone != null and zone.is_player_inside()
	if not visible:
		return

	if _world_time == null:
		_world_time = get_node_or_null(world_time_path)
	if _world_time == null:
		return

	_degree = _world_time.call(&"get_world_degree")
	queue_redraw()

	if _day_label != null:
		_day_label.text = "DAY %d" % int(_world_time.call(&"get_world_day"))
	if _period_label != null:
		_period_label.text = String(_world_time.call(&"get_time_period_name"))


## Six flat wedges, a rim, and a hand pointing at [member _degree] - drawn
## fresh every frame the clock is visible, which is cheap enough for one dial
## that there is nothing here worth caching.
func _draw() -> void:
	var center := Vector2(radius, radius)

	for index: int in range(period_colors.size()):
		# -90° so wedge 0 - Dawn - begins at the top of the face rather than at
		# the three-o'clock position [method Vector2.from_angle] would put it.
		var start_deg := 60.0 * float(index) - 90.0
		var points := PackedVector2Array([center])
		var steps := 8
		for step: int in range(steps + 1):
			var a := deg_to_rad(start_deg + 60.0 * float(step) / float(steps))
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_polygon(points, PackedColorArray([period_colors[index]]))

	draw_arc(center, radius, 0.0, TAU, 48, rim_color, 2.0, true)

	var hand_angle := deg_to_rad(_degree - 90.0)
	draw_line(center, center + Vector2(cos(hand_angle), sin(hand_angle)) * radius * 0.9,
		hand_color, 3.0, true)
	draw_circle(center, 3.0, hand_color)
