class_name PropLizard
extends Node
## The chance that walking into a piece of scenery startles something out from
## under it.
##
## [b]It is a component on the prop, not a system that knows about props.[/b] A
## prop that can hide a lizard has one of these in it and a prop that cannot does
## not, so which scenery is lively is decided in the inspector - and the odds, the
## cooldown and the creature itself are all per-prop values, because a bush and a
## tent do not have to be equally likely to hold one.
##
## It hangs off the prop's existing [PropTouch] rather than watching for the player
## itself. That area is already the thing that knows the player has walked into
## this prop, already rations how often it says so, and already refuses to fire for
## an enemy - so a second sensor would be a second, disagreeing answer to a
## question the prop has already answered.
##
## [b]Two guards keep one long contact from being a stream of lizards.[/b] The
## touch is rationed to at most one roll per [member contact_cooldown], and -
## with [member one_roll_per_contact] on, which is the default - the prop will not
## roll again at all until the player has left it and come back. Standing in a
## cactus is therefore one wager, not one a second. [member max_active] is the
## third guard and belongs to the map rather than the prop: however many props are
## being brushed past, only so many lizards may be out at once.
##
## Where the lizard appears is the base of the prop, nudged *up* the screen by
## [member emerge_height] - which in a y-sorted world is behind it. See [Lizard].

## Emitted when a touch actually produced one, carrying the creature.
signal spawned(lizard: Lizard)

## Group every startled creature joins, so the cap below can be counted without
## anything being wired to anything.
const GROUP := &"lizard"

## What is startled out. Left empty the prop is simply never lively, which is what
## a prop that has not been given the scene yet should do rather than error.
@export var lizard_scene: PackedScene
## The chance one appears, per qualifying contact. 0.08 is the eight in a hundred
## the desert is meant to feel like: often enough to be a thing that happens, rare
## enough that it never stops being a surprise.
@export_range(0.0, 1.0, 0.01) var spawn_chance: float = 0.08

@export_group("Rationing")
## Shortest gap between two rolls on this prop, in seconds. Independent of
## [member PropTouch.retrigger_interval], which is tuned for the knock and the slow
## and is far too eager to be a spawn rate.
@export var contact_cooldown: float = 6.0
## Whether one unbroken contact may only ever roll once. On, so walking into a prop
## and staying there is a single wager; the player must leave it and come back for
## another. Off falls back to the cooldown alone.
@export var one_roll_per_contact: bool = true
## How many startled creatures may be out at once, across the whole map. A field of
## scenery brushed past at a run must not turn into a stampede.
@export var max_active: int = 3

@export_group("Where it appears")
## How far above the prop's own base it appears, in pixels.
##
## [b]This is the whole of "it starts hidden".[/b] A prop's origin is the middle of
## the bottom edge of its artwork and the container is y-sorted, so something a few
## pixels *above* that origin is drawn behind the prop. It then runs, its own
## position carries it down or across, and it comes out from behind the artwork by
## itself - there is no reveal to animate.
@export var emerge_height: float = 5.0
## How far to either side of the prop's middle it may appear, in pixels, so two
## lizards out of the same bush do not come out of the same pixel.
@export var emerge_spread: float = 6.0
## Whether the map's [PropScale] is applied to it, so it is drawn at the same size
## as the scenery it is hiding among. Off draws it at whatever its own scene was
## authored at.
@export var use_map_prop_scale: bool = true

@export_group("Nodes")
## The prop's touch sensor. Its [signal PropTouch.touched] is what this listens to.
@export var touch_path: NodePath = ^"../Touch"
## The prop this belongs to - what the lizard comes out from behind, and what it
## will not count as its own cover. Left unresolved, this node's parent.
@export var prop_path: NodePath = ^".."
## Where the creature is put. Left unresolved it joins the prop's own parent, which
## is the y-sorted scenery container the prop was scattered into - so it sorts
## against the props by construction.
@export var container_path: NodePath

@onready var _touch: PropTouch = get_node_or_null(touch_path) as PropTouch
@onready var _prop: Node2D = get_node_or_null(prop_path) as Node2D

var _cooldown: float = 0.0
var _rolled_this_contact: bool = false


func _ready() -> void:
	if _touch == null:
		return
	_touch.touched.connect(_on_touched)
	# The area's own exit, not the sensor's - leaving the prop is what re-arms the
	# wager, and [PropTouch] has no signal for it because nothing else needed one.
	_touch.body_exited.connect(_on_body_exited)
	set_process(false)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown <= 0.0:
		set_process(false)


## One wager, on one contact. Everything that can refuse it is checked before the
## dice are rolled, so a refusal costs nothing and the odds mean what they say.
func _on_touched(body: Node2D, _direction: Vector2, _speed: float) -> void:
	if lizard_scene == null or _prop == null or body == null:
		return
	if _cooldown > 0.0:
		return
	if one_roll_per_contact and _rolled_this_contact:
		return
	if max_active > 0 and get_tree().get_nodes_in_group(GROUP).size() >= max_active:
		return

	_rolled_this_contact = true
	_cooldown = maxf(contact_cooldown, 0.0)
	if _cooldown > 0.0:
		set_process(true)

	if randf() >= spawn_chance:
		return
	_spawn(body)


func _on_body_exited(_body: Node2D) -> void:
	_rolled_this_contact = false


## Puts one on the ground at the foot of the prop, already running.
func _spawn(from: Node2D) -> void:
	var container := get_node_or_null(container_path)
	if container == null:
		container = _prop.get_parent()
	if container == null:
		return

	var lizard := lizard_scene.instantiate() as Lizard
	if lizard == null:
		return

	lizard.add_to_group(GROUP)
	# The map's scenery scale, applied the same way the scatter applies it, so a
	# lizard is the size of the desert it is running through rather than the size of
	# its own PNG.
	if use_map_prop_scale:
		PropScale.apply_to(lizard, self)

	container.add_child(lizard)
	lizard.global_position = _prop.global_position + Vector2(
		randf_range(-emerge_spread, emerge_spread), -maxf(emerge_height, 0.0))
	# Told which way to run - and which prop not to hide behind - after it is in the
	# tree, so its own nodes are resolved and it is pointing away on its first frame.
	lizard.startle(from.global_position, _prop)
	spawned.emit(lizard)
