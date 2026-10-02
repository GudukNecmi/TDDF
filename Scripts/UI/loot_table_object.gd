class_name LootTableObject
extends LootRewardCard
## A reward lying on the Loot Screen's table as a physical thing - a Charm, a heap
## of Gems, a whisky bottle, a flask of Blood - rather than as a card.
##
## [b]To the screen it is just another card.[/b] It is dealt, placed, locked and
## activated exactly like [LootRewardCard], which it extends; only how it looks
## and moves is its own. Its picture is the reward's [LootObjectArt]
## ([method LootReward.get_art]), so a new kind of physical loot is new art, not
## a change here.
##
## [b]Hover is the physical-object hover, not the card tilt.[/b] Under the mouse
## it lifts a little, grows a little and leans a little, all eased, and a small
## tooltip with the reward's own lettering shows over it. Landing is a short hop
## and squash ([method land]); being collected lifts it off the table and fades
## it out, after which it no longer takes the mouse - it can never be taken twice
## (the reward refuses a second activation anyway). A reward that was already
## done with when it was dealt (a bounty paid on the kill) stays on the table,
## dimmed, with its status in the tooltip.

@export_group("Hover")
## How far it lifts under the mouse, in pixels.
@export var hover_lift: float = 7.0
## How far it leans under the mouse, in degrees.
@export var hover_tilt_degrees: float = 4.0
@export var hover_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var hover_ease: Tween.EaseType = Tween.EASE_OUT
## The soft light under it while hovered.
@export var hover_glow: float = 0.35

@export_group("Resting")
## The most it is turned as it comes to rest, either way, in degrees.
@export var rest_tilt_degrees: float = 9.0

@export_group("Landing")
## The hop it makes as it lands, in pixels, and how long the settle takes.
@export var land_hop: float = 9.0
@export var land_time: float = 0.34
## The squash at the moment it touches down.
@export var land_squash: Vector2 = Vector2(1.14, 0.86)
@export var land_transition: Tween.TransitionType = Tween.TRANS_BOUNCE
@export var land_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("Collecting")
## How long being taken lasts, how far it rises and how big it grows meanwhile.
@export var collect_time: float = 0.35
@export var collect_rise: float = 36.0
@export var collect_scale: float = 1.3
@export var collect_transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var collect_ease: Tween.EaseType = Tween.EASE_OUT
## How a reward already done with when dealt is drawn.
@export var spent_alpha: float = 0.45

@export_group("Tooltip")
## The gap between the object and its tooltip, in pixels.
@export var tooltip_gap: float = 6.0
## Below this distance from the top of the screen the tooltip opens underneath.
@export var tooltip_flip_margin: float = 24.0

@export_group("Wiring")
@export var tooltip_path: NodePath = ^"Tooltip"
@export var tip_heading_path: NodePath = ^"Tooltip/Body/Heading"
@export var tip_title_path: NodePath = ^"Tooltip/Body/Title"
@export var tip_detail_path: NodePath = ^"Tooltip/Body/Detail"
@export var tip_status_path: NodePath = ^"Tooltip/Body/Status"

@onready var _tooltip: Control = get_node_or_null(tooltip_path) as Control
@onready var _tip_heading: Label = get_node_or_null(tip_heading_path) as Label
@onready var _tip_title: Label = get_node_or_null(tip_title_path) as Label
@onready var _tip_detail: Label = get_node_or_null(tip_detail_path) as Label
@onready var _tip_status: Label = get_node_or_null(tip_status_path) as Label

## 0 .. 1 how far into its hover pose it is.
var hover_amount: float = 0.0:
	set(value):
		hover_amount = value
		queue_redraw()
## The landing hop's height above the rest spot, in pixels.
var hop: float = 0.0:
	set(value):
		hop = value
		queue_redraw()
## The landing squash.
var squash: Vector2 = Vector2.ONE:
	set(value):
		squash = value
		queue_redraw()
## 0 .. 1 how far through being collected it is.
var collect_amount: float = 0.0:
	set(value):
		collect_amount = value
		queue_redraw()

var _time: float = 0.0
var _rest_tilt: float = 0.0
var _lean: float = 1.0
var _hovered: bool = false
var _collecting: bool = false
var _spent_when_dealt: bool = false
var _object_tween: Tween
var _land_tween: Tween


func _ready() -> void:
	super._ready()
	clip_contents = false
	if _tooltip != null:
		_tooltip.visible = false
		_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for node: Node in _tooltip.find_children("*", "Control", true, false):
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func bind(reward: LootReward) -> void:
	_spent_when_dealt = reward != null and reward.is_resolved()
	_lean = 1.0 if randf() < 0.5 else -1.0
	super.bind(reward)


## Whether it has been taken off the table.
func is_collected() -> bool:
	return _collecting


func refresh() -> void:
	super.refresh()
	if _reward == null or not is_inside_tree():
		return
	# The card's tint for locked and spent is not this object's - it is drawn here.
	modulate = Color.WHITE
	self_modulate.a = spent_alpha if _spent_when_dealt else self_modulate.a
	_set_tip(_tip_heading, _reward.get_heading())
	var title_line := _reward.get_title()
	var amount_text := _reward.get_amount_text()
	if not amount_text.is_empty():
		title_line += "  " + amount_text
	_set_tip(_tip_title, title_line)
	_set_tip(_tip_detail, _reward.get_detail())
	_set_tip(_tip_status, _reward.get_status_text())
	if _reward.look != null:
		if _tip_heading != null:
			_tip_heading.add_theme_color_override(&"font_color", _reward.get_tint())
		if _tip_status != null:
			_tip_status.add_theme_color_override(&"font_color", _reward.look.accent_color)
	if _reward.is_resolved() and not _spent_when_dealt and not _collecting:
		_collect()
	_place_tooltip()


## Plays the touch-down: a squash, a small hop and a settle into its resting lean.
func land() -> void:
	_rest_tilt = deg_to_rad(randf_range(-rest_tilt_degrees, rest_tilt_degrees))
	if _land_tween != null and _land_tween.is_valid():
		_land_tween.kill()
	var time := maxf(land_time, 0.001)
	squash = land_squash
	_land_tween = create_tween().set_parallel(true)
	_land_tween.tween_property(self, "squash", Vector2.ONE, time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var hop_tween := create_tween()
	hop_tween.tween_property(self, "hop", land_hop, time * 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(self, "hop", 0.0, time * 0.65) \
		.set_trans(land_transition).set_ease(land_ease)


func _collect() -> void:
	_collecting = true
	_hovered = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tooltip != null:
		_tooltip.visible = false
	if _object_tween != null and _object_tween.is_valid():
		_object_tween.kill()
	_object_tween = create_tween()
	_object_tween.tween_property(self, "collect_amount", 1.0, maxf(collect_time, 0.001)) \
		.set_trans(collect_transition).set_ease(collect_ease)
	_object_tween.parallel().tween_property(self, "self_modulate:a", 0.0,
		maxf(collect_time, 0.001))
	_object_tween.tween_callback(hide)


func _on_hover(inside: bool) -> void:
	if _collecting:
		return
	_hovered = inside
	z_index = 10 if inside else 0
	if _tooltip != null:
		_place_tooltip()
		_tooltip.visible = inside
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "hover_amount", 1.0 if inside else 0.0,
		maxf(hover_time, 0.001)).set_trans(hover_transition).set_ease(hover_ease)


func _place_tooltip() -> void:
	if _tooltip == null:
		return
	_tooltip.reset_size()
	var tip := _tooltip.get_combined_minimum_size()
	_tooltip.size = tip
	var above := global_position.y - tip.y - tooltip_gap > tooltip_flip_margin
	var y := -tip.y - tooltip_gap - hover_lift if above else size.y + tooltip_gap
	_tooltip.position = Vector2((size.x - tip.x) * 0.5, y)


func _set_tip(label: Label, value: String) -> void:
	if label == null:
		return
	label.text = value
	label.visible = not value.is_empty()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if _reward == null:
		return
	var centre := size * 0.5
	if hover_amount > 0.0 and hover_glow > 0.0:
		var glow := _reward.get_tint()
		glow.a = hover_glow * hover_amount
		LootObjectArt.draw_shadow(self, centre + Vector2(0.0, size.y * 0.38),
			Vector2(size.x * 0.42, size.y * 0.12), glow)
	var lift := hover_lift * hover_amount + hop + collect_rise * collect_amount
	var grow := 1.0 + (hover_scale - 1.0) * hover_amount + (collect_scale - 1.0) * collect_amount
	var lean := _rest_tilt * (1.0 - hover_amount) \
		+ deg_to_rad(hover_tilt_degrees) * _lean * hover_amount
	draw_set_transform(centre - Vector2(0.0, lift), lean, squash * grow)
	var rect := Rect2(-centre, size)
	var art := _reward.get_art()
	if art != null:
		art.draw(self, rect, _reward, _time)
	else:
		CharmDefinition.draw_crystal(self, Vector2.ZERO, size.y * 0.32, _reward.get_tint())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
