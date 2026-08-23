class_name PropTouch
extends Area2D
## The part of a prop that notices somebody walking into it.
##
## One area, and three things a prop can ask it for, each switched on by an
## inspector value rather than by which prop it is:
##
##   * [b]a knock[/b] - it nudges a [PropSway] in the direction the body was
##     travelling, so scenery reacts to being brushed past. Cacti lean, bushes
##     rustle, bones shiver, and the difference is [member knock_strength] here
##     and the knock settings on the sway.
##   * [b]a slow[/b] - while a qualifying body is inside it, the prop registers
##     itself with the player's [TerrainSlow] at [member speed_multiplier]. 1
##     leaves the player's speed alone, which is what a bush and a bone want.
##   * [b]a signal[/b] - [signal touched] carries the body, the direction it was
##     going and how fast, which is what a bone hangs its kick off.
##
## [member minimum_speed] is what makes "moves quickly across" a thing a prop can
## ask for: a bone only reacts to somebody running over it, and standing on one
## does nothing.
##
## The area is deliberately a little larger than whatever the prop collides with,
## so a cactus that stops the player dead still registers the contact.

## Emitted each time a qualifying body is registered as touching this prop, at
## most once per [member retrigger_interval]. [param direction] is normalised and
## is the way the body was travelling.
signal touched(body: Node2D, direction: Vector2, speed: float)

## Only bodies in this group count. Enemies walk through the same scenery without
## setting any of it off, which keeps a wave of them from strobing a whole field.
@export var body_group: StringName = &"player"
## Speed the body must be doing for a touch to register, in pixels per second. 0
## counts standing still as touching, which is what a cactus wants; a bone wants
## this set well up, so only running over it does anything.
@export var minimum_speed: float = 0.0
## Shortest gap between two touches being reported for the same body, in seconds.
## Without it, walking along a prop reports on every physics frame.
@export var retrigger_interval: float = 0.45

@export_group("Knock")
## [PropSway] knocked when this is touched. Left unresolved, nothing is knocked
## and the area is purely a sensor.
@export var sway_path: NodePath = ^"../Sway"
## Strength passed to [method PropSway.nudge]. 1 is the sway's authored knock.
@export var knock_strength: float = 1.0

@export_group("Slow")
## What the player's speed is multiplied by while they are inside this. 1 is no
## slow at all, and is the default - only a prop that should hold somebody up
## sets it. 0.8 is "20% slower".
@export_range(0.05, 1.0) var speed_multiplier: float = 1.0

@onready var _sway: PropSway = get_node_or_null(sway_path) as PropSway

var _bodies: Array[Node2D] = []
var _cooldown: float = 0.0
var _slow: TerrainSlow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Nothing is inside yet, so there is nothing to measure. A field of props that
	# nobody is near costs no frame time at all.
	set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group(body_group):
		return
	if _bodies.has(body):
		return

	_bodies.append(body)
	_apply_slow(true)
	# Reacts on contact rather than after the interval, so the first touch is
	# immediate and only a *continued* one is rationed.
	_cooldown = 0.0
	set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
	if _bodies.is_empty():
		_apply_slow(false)
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return

	for body: Node2D in _bodies:
		if not is_instance_valid(body):
			continue
		var velocity := _velocity_of(body)
		var speed := velocity.length()
		if speed < minimum_speed:
			continue

		var direction := velocity / speed if speed > 0.0 else Vector2.ZERO
		_knock(direction)
		touched.emit(body, direction, speed)
		_cooldown = retrigger_interval
		return

	# Bodies can be freed inside the area - an enemy dying against a cactus - and
	# `body_exited` is not always delivered for them, so the list is swept here.
	_prune()


## Leans the prop the way the body was going, so being walked into from the left
## pushes it right. A body standing still leans it whichever way it was authored
## to, rather than not at all.
func _knock(direction: Vector2) -> void:
	if _sway == null or knock_strength <= 0.0:
		return
	_sway.nudge(knock_strength, 1.0 if direction.x >= 0.0 else -1.0)


func _apply_slow(inside: bool) -> void:
	if speed_multiplier >= 1.0:
		return

	if _slow == null or not is_instance_valid(_slow):
		_slow = TerrainSlow.get_active(self)
	if _slow == null:
		return

	if inside:
		_slow.add_source(self, speed_multiplier)
	else:
		_slow.remove_source(self)


## Reads `velocity` where the body has one - every character in the game is a
## [CharacterBody2D] - so no position history has to be kept per prop.
func _velocity_of(body: Node2D) -> Vector2:
	if "velocity" in body:
		return body.get(&"velocity") as Vector2
	return Vector2.ZERO


func _prune() -> void:
	var live: Array[Node2D] = []
	for body: Node2D in _bodies:
		if is_instance_valid(body):
			live.append(body)
	if live.size() == _bodies.size():
		return

	_bodies = live
	if _bodies.is_empty():
		_apply_slow(false)
		set_physics_process(false)


## A prop removed while the player is standing in it must not take its slow with
## it, so the registration is dropped on the way out of the tree as well.
func _exit_tree() -> void:
	_apply_slow(false)
