class_name PlayerStealth
extends Node
## What the enemies know about a player hidden in BLACK POWDER's smoke - see
## [BlackPowder] and [BlackPowderSmoke].
##
## [b]It is the one place that knowledge lives.[/b] While the player stands in a
## cloud, every enemy has lost sight of them and is sent - through the enemy's own
## [code]begin_investigation()[/code], the same walk it always takes pointed at a
## place - to what it last knew: where the player was last actually seen, or where it
## last heard a shot. The enemies do not freeze and are never moved; they walk there,
## look round, and are handed straight back to the ordinary chase the frame the
## player is visible again. Nothing here runs a second AI.
##
## [b]Close up the smoke does not hide anybody.[/b] An enemy within
## [member BlackPowder.close_detection_radius] of the hidden player makes them out and
## chases the real player as usual, and remembers where it last made them out if they
## slip away. Enemies further off learn nothing from it.
##
## [b]The marks show the player exactly what the enemies know[/b], because they are
## left by the same lines that change it:
##
##   * [b]white[/b] - where the enemies last saw the player, left as they vanish into
##     the smoke and held there, not following the player, until they are seen again;
##   * [b]yellow[/b] - where a nearby enemy is making out the hidden player, left every
##     [member BlackPowder.detection_mark_interval] seconds for as long as one does;
##   * [b]red[/b] - where a shot was fired from inside the smoke, handed to every
##     enemy that heard it - see [method report_noise].
##
## The numbers come from the [BlackPowder] of the cloud the player is hiding in, so
## the Legendary is tuned in one place; the colours are here.

## Emitted as the player vanishes into the smoke and as they are seen again.
signal hidden_changed(hidden: bool)
## Emitted as a shot fired from hiding is heard, with where it was fired from and how
## many enemies heard it.
signal noise_made(point: Vector2, listeners: int)
## Emitted each time a yellow mark is left, with where the player was made out.
signal detected(point: Vector2)

## The body that hides.
@export var body_path: NodePath = ^".."
## The artwork a mark is taken from - never the body, so what is left behind is the
## drawing alone.
@export var visual_path: NodePath = ^"../Visual"
## Group every enemy is in. Only those that can investigate are steered.
@export var enemy_group: StringName = &"enemies"

@export_group("Marks")
## The flat see-through look every mark is drawn with.
@export var silhouette_shader: Shader
## Drawn above the smoke, so a mark inside it still reads.
@export var mark_z_index: int = 13
## Where the enemies last saw the player.
@export var last_seen_color := Color(1.0, 1.0, 1.0, 0.34)
## A nearby enemy making out the hidden player.
@export var detected_color := Color(1.0, 0.84, 0.2, 0.38)
## A shot heard from inside the smoke.
@export var noise_color := Color(1.0, 0.12, 0.08, 0.45)
## Seconds the white mark takes to appear and, once the player is seen again, to go.
@export var last_seen_fade_in: float = 0.15
@export var last_seen_fade_out: float = 0.35
## Seconds a yellow mark takes to fade away.
@export var detected_lifetime: float = 0.55
## Seconds a red mark takes to fade away. A newer shot clears the older one quickly.
@export var noise_lifetime: float = 1.4

@onready var _body: Node2D = get_node_or_null(body_path) as Node2D
@onready var _visual: Node2D = get_node_or_null(visual_path) as Node2D

var _hidden: bool = false
## The [BlackPowder] of the cloud the player is hiding in.
var _powder: BlackPowder
var _fallback := BlackPowder.new()
## Where the player stood the last frame they could be seen.
var _last_visible: Vector2 = Vector2.ZERO
## Where the enemies last saw them - the white mark.
var _last_seen: Vector2 = Vector2.ZERO
## Where each enemy believes the player is, for the ones that have learnt something
## since the player vanished. Everyone else goes on [member _last_seen].
var _interest: Dictionary = {}
## Where each enemy is walking right now - its belief, or a spot round it while it
## looks.
var _goal: Dictionary = {}
var _mark_timer: float = 0.0
var _white: Node2D
var _red: Node2D
var _materials: Dictionary = {}


func _ready() -> void:
	if _body != null:
		_last_visible = _body.global_position


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var cloud := _concealing_cloud()
	var hidden := cloud != null
	if hidden:
		var powder := cloud.get_powder()
		_powder = powder if powder != null else _fallback
	if hidden and not _hidden:
		_hide()
	elif not hidden and _hidden:
		_reveal()
	if not hidden:
		_last_visible = _body.global_position
		return
	_update_enemies(delta)


func _exit_tree() -> void:
	if _hidden:
		_reveal()


## Whether the player is hidden in the smoke right now.
func is_hidden() -> bool:
	return _hidden


## Where the enemies last saw the player. Meaningless while they are not hidden.
func get_last_seen() -> Vector2:
	return _last_seen


## Where [param enemy] believes the hidden player is.
func get_belief(enemy: Node) -> Vector2:
	return _interest.get(enemy, _last_seen)


## A shot fired from [param point] while the player is hidden: a red mark there, and
## every enemy within [param radius] of it - every enemy in the fight when it is below
## 0 - goes to look at it. The player's own position is not given away; only the
## sound's. Does nothing while the player can be seen. Returns how many heard it.
func report_noise(point: Vector2, radius: float = -1.0) -> int:
	if not _hidden:
		return 0
	if _red != null and is_instance_valid(_red):
		_fade_out(_red, 0.12)
	_red = _spawn_mark(noise_color, point)
	_fade_out(_red, noise_lifetime)

	var heard := 0
	for enemy: Node2D in _investigators():
		if radius >= 0.0 and enemy.global_position.distance_to(point) > radius:
			continue
		_interest[enemy] = point
		_goal.erase(enemy)
		heard += 1
	noise_made.emit(point, heard)
	return heard


# --- Hiding ----------------------------------------------------------------------

func _hide() -> void:
	_hidden = true
	_last_seen = _last_visible
	_interest.clear()
	_goal.clear()
	_mark_timer = 0.0
	if _white != null and is_instance_valid(_white):
		_white.queue_free()
	_white = _spawn_mark(last_seen_color, _last_seen)
	if _white != null:
		_white.modulate.a = 0.0
		_white.create_tween().tween_property(_white, "modulate:a", 1.0,
			maxf(last_seen_fade_in, 0.001))
	hidden_changed.emit(true)


## Seen again: every enemy is back on the real player this frame, and the white mark
## goes - nobody is guessing any more.
func _reveal() -> void:
	_hidden = false
	if is_inside_tree():
		for enemy: Node2D in _investigators(true):
			enemy.call(&"end_investigation")
	_interest.clear()
	_goal.clear()
	if _white != null and is_instance_valid(_white):
		_fade_out(_white, last_seen_fade_out)
	_white = null
	hidden_changed.emit(false)


func _update_enemies(delta: float) -> void:
	var here := _body.global_position
	var powder := _powder
	var detecting := false
	for enemy: Node2D in _investigators():
		if enemy.global_position.distance_to(here) <= maxf(powder.close_detection_radius, 0.0):
			# Close enough to make the hidden player out: the ordinary chase, and it
			# remembers this spot if they slip away again.
			detecting = true
			_interest[enemy] = here
			_goal.erase(enemy)
			enemy.call(&"end_investigation")
			continue
		var belief: Vector2 = _interest.get(enemy, _last_seen)
		var goal: Vector2 = _goal.get(enemy, belief)
		if enemy.global_position.distance_to(goal) <= maxf(powder.arrive_distance, 1.0):
			# Got there and found nobody: look round the place, never further off it
			# than the search radius.
			goal = belief + Vector2.from_angle(randf() * TAU) \
				* sqrt(randf()) * maxf(powder.search_radius, 0.0)
		_goal[enemy] = goal
		enemy.call(&"begin_investigation", goal, powder.investigate_speed_multiplier)

	if not detecting:
		_mark_timer = 0.0
		return
	_mark_timer -= delta
	if _mark_timer > 0.0:
		return
	_mark_timer = maxf(powder.detection_mark_interval, 0.02)
	var mark := _spawn_mark(detected_color, here)
	_fade_out(mark, detected_lifetime)
	detected.emit(here)


## Every enemy that can be sent somewhere and is taking part in the fight. A man
## running home or standing by is let go of, so nothing here ever holds one. With
## [param everyone] the ones taking no part are listed too, to be let go of.
func _investigators(everyone: bool = false) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group(enemy_group):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method(&"begin_investigation"):
			continue
		if not everyone and _sitting_out(enemy):
			enemy.call(&"end_investigation")
			continue
		found.append(enemy)
	return found


func _sitting_out(enemy: Node2D) -> bool:
	if enemy.has_method(&"is_fleeing") and enemy.call(&"is_fleeing"):
		return true
	return enemy.has_method(&"is_passive") and enemy.call(&"is_passive")


func _concealing_cloud() -> BlackPowderSmoke:
	var point := _body.global_position
	for node: Node in get_tree().get_nodes_in_group(BlackPowderSmoke.GROUP):
		var cloud := node as BlackPowderSmoke
		if cloud != null and cloud.conceals_point(point):
			return cloud
	return null


# --- Marks -----------------------------------------------------------------------

## A flat copy of the player's artwork as it looks now, set down at [param point].
func _spawn_mark(color: Color, point: Vector2) -> Node2D:
	var container := get_tree().current_scene
	if _visual == null or container == null:
		return null
	var mark := SpriteSnapshot.take(_visual, container, _material_for(color))
	if mark == null:
		return null
	mark.name = "StealthMark"
	mark.z_index = mark_z_index
	mark.global_position += point - _body.global_position
	return mark


func _fade_out(mark: Node2D, time: float) -> void:
	if mark == null or not is_instance_valid(mark):
		return
	var tween := mark.create_tween()
	tween.tween_property(mark, "modulate:a", 0.0, maxf(time, 0.01))
	tween.tween_callback(mark.queue_free)


func _material_for(color: Color) -> Material:
	if silhouette_shader == null:
		return null
	if _materials.has(color):
		return _materials[color]
	var material := ShaderMaterial.new()
	material.shader = silhouette_shader
	material.set_shader_parameter(&"tint", color)
	_materials[color] = material
	return material
