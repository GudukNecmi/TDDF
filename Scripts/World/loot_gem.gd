class_name LootGem
extends Node2D
## A coloured stone thrown out of a reward chest, lying in the sand until the player
## walks over it and presses E.
##
## [b]It is [GroundPickup] with nothing behind the key.[/b] The interaction is
## deliberately the same shape as every other one in the game - the player is found
## by group, the reach is a circle round this node, the prompt is [i]told[/i] on the
## crossing rather than asked every frame, the edge is [SpriteOutline]'s, and the key
## is taken in [method Node._unhandled_input] and marked handled so the press that
## takes a stone cannot also fire the gun. What it is not is a weapon: there is no
## mount to hand it to and no slot to put it in, so taking one is picking it up and
## nothing else.
##
## [b]It is a placeholder, and it is built to be thrown away.[/b] There is no
## inventory in this game yet and nothing here pretends there is: a stone is
## collected, [signal collected] is emitted, and it is gone. When there are real
## items the chest reaches them by having a different scene dropped into
## [member RewardChest.item_scene], and this file is deleted rather than untangled.
##
## [b]What it looks like is an array, not a branch.[/b] [member faces] is drawn from
## at random, so a fifth colour of stone is a PNG dropped into the inspector with no
## name, threshold or case anywhere in the code.

## Emitted as it is taken, just before it leaves the world.
signal collected

## Group every loose stone joins, so a cleanup - or a test - can find them all
## without holding a reference to any.
const GROUP := &"loot_gem"

## The stones this one might be. One is drawn at random as it enters the world;
## left empty the artwork already on the sprite is kept.
@export var faces: Array[Texture2D] = []

@export_group("The burst")
## How far it is thrown from the chest, in pixels: the nearest and the furthest.
## Close on purpose - the loot should read as a handful spilled at the player's feet
## rather than as a hunt.
@export var burst_distance := Vector2(70.0, 165.0)
## How long the flight takes, in seconds.
@export var burst_time: float = 0.5
## How high it arcs on the way, in pixels.
@export var burst_height: float = 110.0
## How many turns it makes in the air. The stone spins; where it comes to rest is
## wherever the spin left it.
@export var burst_spin: float = 1.25
## How far it settles from where it first touched down, as a fraction of the throw -
## the little skid a thrown thing makes. 0 lands it dead.
@export_range(0.0, 0.5, 0.01) var burst_skid: float = 0.08

@export_group("Reaching it")
## How close the player has to stand for the prompt and the key to work, in pixels.
## The same reach a knife on the floor offers.
@export var interaction_radius: float = 95.0
## Only bodies in this group can take it.
@export var body_group: StringName = &"player"
## Key that takes it - the project's own interact action, so a stone is picked up
## with whatever every other interaction in the game is opened with.
@export var interact_action: StringName = &"interact"

@export_group("The edge")
## Whether a stone within reach is outlined.
@export var outlines_in_reach: bool = true
## The shader the edge is drawn with - the game's own, see [SpriteOutline].
@export var outline_shader: Shader
## How thick the edge is, in source texture pixels. Very thin: it says "this one"
## rather than drawing attention to itself.
@export var outline_width: float = 1.5
## What colour the edge is.
@export var outline_color := Color(1.0, 0.13, 0.1, 1.0)

@export_group("Taken")
## How long it fades over as it is taken, and how far it lifts as it goes.
@export var collect_fade: float = 0.3
@export var collect_lift: float = 26.0

@export_group("Nodes")
## The picture. Everything that moves in the burst moves this rather than the node,
## so the reach circle is standing on the landing spot from the first frame.
@export var art_path: NodePath = ^"Art"
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false
var _flying: bool = false
var _taken: bool = false
var _rest := Vector2.ZERO
var _tween: Tween


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	if _art != null:
		_rest = _art.position
	_wear_a_face()


## Draws which stone this is. A scene with nothing authored keeps whatever picture
## its sprite was saved with, so the placeholder is never a blank.
func _wear_a_face() -> void:
	if faces.is_empty():
		return
	var sprite := _sprite()
	if sprite == null:
		return
	var face := faces[randi() % faces.size()]
	if face != null:
		sprite.texture = face


## Throws it out of the chest and lands it [param distance] pixels away along
## [param heading], arcing and spinning on the way.
##
## [b]The node is put where it will land before anything moves.[/b] It is the picture
## that flies - the same way the chest itself falls - so the stone can be walked to
## the instant it settles and the reach circle was never somewhere else.
func burst(heading: float, distance: float = -1.0) -> void:
	var reach := distance
	if reach < 0.0:
		reach = randf_range(
			minf(burst_distance.x, burst_distance.y), maxf(burst_distance.x, burst_distance.y))

	var landing := Vector2.RIGHT.rotated(heading) * reach
	position += landing
	reset_physics_interpolation()

	if _art == null:
		return

	# The picture starts back at the chest and is carried across to the stone's own
	# origin, which is what makes the throw read as coming out of the box.
	_art.position = _rest - landing
	_flying = true

	var seconds := maxf(burst_time, 0.0001)
	var from_y := _rest.y - landing.y
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	# Across at a steady rate and up-and-down on its own curve: together they are the
	# arc, without a second idea of gravity being written here.
	_tween.tween_property(_art, "position:x", _rest.x, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_lift_art.bind(from_y, _rest.y), 0.0, 1.0, seconds)
	if burst_spin != 0.0:
		_tween.tween_property(_art, "rotation", TAU * burst_spin, seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_settle.bind(landing))


## Where the picture is on the way over: the straight line between the two heights,
## with the arc lifted off it.
func _lift_art(t: float, from_y: float, to_y: float) -> void:
	if _art == null or not is_instance_valid(_art):
		return
	_art.position.y = lerpf(from_y, to_y, t) - sin(t * PI) * maxf(burst_height, 0.0)


## It has come down. The little skid afterwards is the whole of the landing - there
## is no bounce, because a stone this size does not.
func _settle(landing: Vector2) -> void:
	_flying = false
	if _art == null or burst_skid <= 0.0:
		return

	var skid := landing * burst_skid
	position += skid
	_art.position = _rest - skid
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_art, "position", _rest, maxf(burst_time * 0.35, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Whether it is still in the air. Named as [GroundPickup] names it, so anything that
## already refuses to hand over a thing still travelling refuses this one too.
func is_flying() -> bool:
	return _flying


func is_taken() -> bool:
	return _taken


func is_player_in_reach() -> bool:
	return _in_reach


## Whether [param body] is standing close enough to take this.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return global_position.distance_to(body.global_position) <= interaction_radius


## Takes it. Ignored unless the player is standing over it, and ignored for good once
## it has been taken. Returns whether it was.
##
## There is nowhere for it to go yet - see the class documentation - so what
## "collecting" means here is the stone leaving the world and saying so.
func use() -> bool:
	if _taken or not _in_reach:
		return false

	_taken = true
	set_process(false)
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	_show_edge(false)

	collected.emit()
	_play_taken()
	return true


func _play_taken() -> void:
	if _art == null or collect_fade <= 0.0:
		queue_free()
		return

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_art, "modulate:a", 0.0, collect_fade)
	if collect_lift > 0.0:
		_tween.tween_property(_art, "position", _art.position - Vector2(0.0, collect_lift),
			collect_fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	_watch_player()


## The prompt and the edge are told rather than asked, and only on the crossing, so
## neither is rewritten every frame.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := not _taken and not _flying and is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	_show_edge(_in_reach)


func _show_edge(shown: bool) -> void:
	if not outlines_in_reach:
		return
	SpriteOutline.set_outlined(_sprite(), shown, outline_shader, outline_width, outline_color)


func _sprite() -> Sprite2D:
	if _art == null:
		return null
	var self_sprite := _art as Sprite2D
	if self_sprite != null:
		return self_sprite
	for node: Node in _art.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite != null:
			return sprite
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _taken or not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	if use():
		# Marked handled so one press takes one stone: two lying together offer two
		# prompts, and the press reaches only the first of them.
		get_viewport().set_input_as_handled()
