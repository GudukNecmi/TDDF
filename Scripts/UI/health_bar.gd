class_name HealthBar
extends ProgressBar
## The player's health as one continuous bar - the default presentation.
##
## The bar runs over the fraction of the pool that is left, 0 to 1, rather than
## over points, so it is right for a pool of three or thirty and an upgrade that
## raises the ceiling needs nothing here. It is [HeartBar]'s twin: found by the
## same group, fed by the same [signal Health.health_changed], and holding no
## number of its own - so whatever moved the pool, a hit, a heal, a revival or a
## new ceiling, the bar can only ever show the real health.
##
## Which of the two is drawn is [RunVitals]' answer. This one belongs to
## [constant RunVitals.HealthDisplay.BAR]; a card switching the run to hearts hides
## it and shows the row, and neither loses track of the pool while hidden.

## Health this mirrors. Found by group, so nothing is wired up.
@export var health_group: StringName = &"player_health"
## Which presentation this bar belongs to. It is shown only while [RunVitals] is
## set to it, and follows the switch live.
@export var shown_for: RunVitals.HealthDisplay = RunVitals.HealthDisplay.BAR
## The autoload the presentation is read from. With none, the bar is always shown.
@export var vitals_path: NodePath = ^"/root/Vitals"
## A label the percentage is written into, relative to this bar. Left empty, the
## bar carries no number.
@export var percent_label_path: NodePath = ^"Percent"
## How the percentage is written; [code]%d[/code] is the whole percent.
@export var percent_format: String = "%d%%"

@export_group("Reaction")
## Seconds the fill takes to slide to a new value. 0 snaps. The number on the
## label is always the true one at once; only the fill is eased.
@export var slide_time: float = 0.25

@onready var _percent: Label = get_node_or_null(percent_label_path) as Label

var _health: Health
var _display_shown: bool = true
var _tween: Tween


func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	_bind_display()
	_bind_health()


## The health may enter the tree after the HUD does, so it is looked for until it
## turns up rather than once on ready. Once bound this stops running.
func _process(_delta: float) -> void:
	if _health == null or not is_instance_valid(_health):
		_bind_health()


func _bind_health() -> void:
	_health = get_tree().get_first_node_in_group(health_group) as Health
	_update_visibility()
	if _health == null:
		return

	_health.health_changed.connect(_on_health_changed)
	_show(_health.get_current(), _health.get_max(), false)
	set_process(false)


func _on_health_changed(current: float, maximum: float) -> void:
	_show(current, maximum, true)


func _show(current: float, maximum: float, animate: bool) -> void:
	var fraction := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	if _percent != null:
		_percent.text = percent_format % roundi(fraction * 100.0)

	if _tween != null:
		_tween.kill()
	if not animate or slide_time <= 0.0 or not is_inside_tree():
		value = fraction
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "value", fraction, slide_time)


func _bind_display() -> void:
	var vitals := get_node_or_null(vitals_path) as RunVitals
	if vitals == null:
		return
	vitals.display_changed.connect(_on_display_changed)
	_on_display_changed(vitals.get_display())


func _on_display_changed(display: RunVitals.HealthDisplay) -> void:
	_display_shown = display == shown_for
	_update_visibility()


## Shown only for its own presentation, and only once there is a pool to show - a
## HUD with no player behind it draws no bar rather than an empty one that would
## read as dead.
func _update_visibility() -> void:
	visible = _display_shown and _health != null and is_instance_valid(_health)
