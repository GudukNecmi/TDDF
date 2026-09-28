class_name BossHealthBar
extends Control
## The bounty boss's health along the bottom of the screen, for as long as the
## fight with him lasts.
##
## [b]It holds no number of its own.[/b] The bar mirrors the boss's own [Health] -
## the one [MiniBossDirector] filled to the contract's ceiling when he was built -
## through [signal Health.health_changed], so it can only ever show the real pool.
##
## [b]It appears when the fight does.[/b] It is shown once
## [method MiniBossDirector.get_phase] reaches [constant MiniBossDirector.Phase.FIGHTING]
## and goes on [signal Health.died], or as soon as the boss or the fight is gone.
## Everything about where it sits and how it looks is this node's own layout and
## its children's theme overrides, set in the Inspector. It lives on [RunHUD]
## after [TravelLetterbox] so it is drawn over the bottom bar, never behind it.

## The fill, relative to this node. Its value runs 0 to 1 over the fraction left.
@export var bar_path: NodePath = ^"Bar"
## A label the boss's poster name is written into. Left empty, no name is shown.
@export var name_label_path: NodePath = ^"Name"
## Seconds the bar takes to fade in and out. 0 snaps.
@export var fade_time: float = 0.25

@onready var _bar: Range = get_node_or_null(bar_path) as Range
@onready var _name: Label = get_node_or_null(name_label_path) as Label

var _health: Health
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	if _bar != null:
		_bar.min_value = 0.0
		_bar.max_value = 1.0
		_bar.step = 0.0


## Looks for a fight to follow while there is none, and drops the one it has as
## soon as the boss or the fight is gone.
func _process(_delta: float) -> void:
	if _health != null:
		if not is_instance_valid(_health) or not _is_fighting():
			_unbind()
		return

	if not _is_fighting():
		return
	var director := MiniBossDirector.get_active(self)
	var boss := director.get_boss() if director != null else null
	var health := _find_health(boss)
	if health != null and health.is_alive():
		_bind(health, boss)


func _is_fighting() -> bool:
	var director := MiniBossDirector.get_active(self)
	return director != null and director.get_phase() == MiniBossDirector.Phase.FIGHTING


func _bind(health: Health, boss: Node) -> void:
	_health = health
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_unbind, CONNECT_ONE_SHOT)
	if _name != null:
		var marker := MiniBoss.find_on(boss)
		_name.text = marker.get_display_name() if marker != null else ""
	_on_health_changed(_health.get_current(), _health.get_max())
	_fade_to(true)


func _unbind() -> void:
	if _health != null and is_instance_valid(_health):
		if _health.health_changed.is_connected(_on_health_changed):
			_health.health_changed.disconnect(_on_health_changed)
		if _health.died.is_connected(_unbind):
			_health.died.disconnect(_unbind)
	_health = null
	_fade_to(false)


func _on_health_changed(current: float, maximum: float) -> void:
	if _bar != null:
		_bar.value = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func _fade_to(shown: bool) -> void:
	if _fade != null:
		_fade.kill()
	if shown:
		visible = true
	if fade_time <= 0.0 or not is_inside_tree():
		modulate.a = 1.0 if shown else 0.0
		visible = shown
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0 if shown else 0.0, fade_time)
	if not shown:
		_fade.tween_callback(hide)


func _find_health(boss: Node) -> Health:
	if boss == null or not is_instance_valid(boss):
		return null
	for node: Node in boss.find_children("*", "Health", true, false):
		return node as Health
	return null
