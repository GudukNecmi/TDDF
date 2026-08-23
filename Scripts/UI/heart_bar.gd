class_name HeartBar
extends HBoxContainer
## The player's health, drawn as one heart per point.
##
## The row is generated from [member Health.max_health] rather than authored, so
## the number of hearts is never written down anywhere: three today, and whatever
## an upgrade raises the ceiling to tomorrow, without a line changing here. The
## row is rebuilt whenever the maximum moves, which is why buying health is
## already a solved problem rather than a thing to come back and fix.
##
## It counts nothing itself. Every heart is read straight off the pool through
## [signal Health.health_changed], so the display cannot drift from the real
## health however it was lost or put back - a hit, a heal, a revival restoring
## one heart at a time, or the ceiling being raised.
##
## The health it follows is found by group rather than by a path into another
## branch of the scene, the same way [CameraController] and [ScreenFlash] are, so
## the HUD is not wired to the player.

## Health this mirrors. Found by group, so nothing is wired up.
@export var health_group: StringName = &"player_health"
## Artwork for a heart the player still has.
@export var full_texture: Texture2D
## Artwork for one they have lost. Left unset, lost hearts are simply hidden.
@export var empty_texture: Texture2D
## Size one heart is drawn at.
@export var heart_size := Vector2(46.0, 46.0)

@export_group("Reaction")
## How far a heart is punched out as it is lost, as a fraction.
@export var lose_pulse_scale: float = 1.5
@export var lose_pulse_out_time: float = 0.07
@export var lose_pulse_back_time: float = 0.22
## How far a heart pops as it comes back, as a fraction. Used by the revival,
## where the hearts return one at a time and each one wants to be seen.
@export var gain_pulse_scale: float = 1.7
@export var gain_pulse_out_time: float = 0.12
@export var gain_pulse_back_time: float = 0.26

var _health: Health
var _hearts: Array[TextureRect] = []
var _shown: int = -1


func _ready() -> void:
	_bind_health()


## The health may enter the tree after the HUD does, so it is looked for until it
## turns up rather than once on ready. Once bound this stops running.
func _process(_delta: float) -> void:
	if _health == null or not is_instance_valid(_health):
		_bind_health()


func _bind_health() -> void:
	_health = get_tree().get_first_node_in_group(health_group) as Health
	if _health == null:
		return

	_health.health_changed.connect(_on_health_changed)
	_rebuild(int(round(_health.get_max())))
	_refresh(int(round(_health.get_current())))
	set_process(false)


func _on_health_changed(current: float, maximum: float) -> void:
	_rebuild(int(round(maximum)))
	_refresh(int(round(current)))


## Rebuilt only when the count actually changes, so an ordinary hit updates the
## hearts that are already there instead of throwing the row away and building a
## new one - which would kill every animation mid-beat.
func _rebuild(count: int) -> void:
	count = maxi(count, 0)
	if count == _hearts.size():
		return

	for heart: TextureRect in _hearts:
		heart.queue_free()
	_hearts.clear()
	_shown = -1

	for i in count:
		var heart := TextureRect.new()
		heart.custom_minimum_size = heart_size
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart.pivot_offset = heart_size * 0.5
		heart.texture = full_texture
		add_child(heart)
		_hearts.append(heart)


## Every heart is set from the count each time, so the row cannot end up out of
## step; the animation is the only thing that depends on which way it moved.
func _refresh(current: int) -> void:
	current = clampi(current, 0, _hearts.size())
	var previous := _shown
	_shown = current

	for i in _hearts.size():
		var heart := _hearts[i]
		var held := i < current
		heart.texture = full_texture if held else empty_texture
		# A row with no empty artwork hides its lost hearts rather than leaving
		# holes with nothing drawn in them.
		heart.visible = held or empty_texture != null

	if previous < 0 or previous == current:
		return

	# Only the hearts that actually changed are animated, and the outermost of
	# them is the one that reads - a heart lost is the last one you had.
	if current < previous:
		_pulse(current, lose_pulse_scale, lose_pulse_out_time, lose_pulse_back_time)
	else:
		_pulse(current - 1, gain_pulse_scale, gain_pulse_out_time, gain_pulse_back_time)


## Restarts from the resting scale every time, so hearts arriving in quick
## succession cannot stack their pops or leave one permanently enlarged.
func _pulse(index: int, amount: float, out_time: float, back_time: float) -> void:
	if index < 0 or index >= _hearts.size():
		return

	var heart := _hearts[index]
	heart.scale = Vector2.ONE
	var tween := heart.create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(heart, "scale", Vector2.ONE * amount, out_time).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart, "scale", Vector2.ONE, back_time).set_ease(Tween.EASE_IN)
