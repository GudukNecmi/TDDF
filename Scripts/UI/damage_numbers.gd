class_name DamageNumbers
extends Node2D
## The place damage figures are asked for.
##
## One of these sits in the world and every [Hitbox] that lands a hit calls
## [method pop] on it. Found by group rather than wired up, exactly as
## [BloodField], [ScreenFlash] and [CameraController] are, so a hitbox needs no
## path to it and a world without one simply shows no numbers - nothing about
## damage itself goes through here.
##
## It owns the scene the figures are built from and the ceiling on how many can be
## on screen at once, and that is all: what one figure *does* is entirely
## [DamageNumber]'s business, so the look and the motion are retuned on that scene
## without this file being involved.

## Group used by [method get_active].
const GROUP := &"damage_numbers"

## Whether numbers are shown at all. Off is a clean way to play without them.
@export var enabled: bool = true
## Scene one figure is built from. Unset shows nothing.
@export var number_scene: PackedScene
## Most figures on screen at once. A shotgun landing six pellets on three bodies
## can put a lot of text up in one frame, and beyond this the oldest is retired
## early rather than the newest being dropped - the hit that just landed is always
## the one worth reading.
@export var max_alive: int = 48
## Hits smaller than this are not worth a number. 0 shows every hit.
@export var minimum_damage: float = 0.0

var _alive: Array[DamageNumber] = []


func _ready() -> void:
	add_to_group(GROUP)


## The spawner the rest of the scene should talk to. Null means this world shows
## no damage numbers, which every caller treats as "say nothing".
static func get_active(from_node: Node) -> DamageNumbers:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as DamageNumbers


func get_alive_count() -> int:
	return _alive.size()


## Throws one figure up at [param at], in world coordinates.
##
## [param critical] is passed straight through to the figure, which owns what a
## critical one looks like. Nothing about the distinction is decided here.
func pop(amount: float, at: Vector2, critical: bool = false) -> void:
	if not enabled or number_scene == null or amount < minimum_damage:
		return

	_retire_dead()
	while _alive.size() >= maxi(max_alive, 1):
		var oldest := _alive.pop_front() as DamageNumber
		if is_instance_valid(oldest):
			oldest.queue_free()

	var number := number_scene.instantiate() as DamageNumber
	if number == null:
		return

	add_child(number)
	number.global_position = at
	number.reset_physics_interpolation()
	number.show_damage(amount, critical)
	_alive.append(number)


## Figures free themselves at the end of their own tween, so the list is swept
## rather than kept in step by them - which keeps [DamageNumber] independent of
## whatever spawned it.
func _retire_dead() -> void:
	var living: Array[DamageNumber] = []
	for number: DamageNumber in _alive:
		if is_instance_valid(number):
			living.append(number)
	_alive = living
