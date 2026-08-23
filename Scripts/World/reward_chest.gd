class_name RewardChest
extends Node2D
## The chest that comes down out of the sky when a search for trouble is over:
## walk up to it, press E, and take what is in it.
##
## [b]It is [AmmoCrate] with a different thing behind the key.[/b] The interaction is
## deliberately the same shape as every other one in the game - the player is found
## by group, the reach is a circle round this node, the prompt is [i]told[/i] on the
## crossing rather than asked every frame, and the key is taken in
## [method Node._unhandled_input] and marked handled so the press that opens a chest
## cannot also fire the gun.
##
## [b]The arrival is the point of it.[/b] The chest is dropped from above the top of
## the view, falls under gravity's own acceleration, and lands: the camera is shaken
## through the shake the whole game already uses - see [method CameraController.shake]
## - and the chest bounces once and settles. Nothing about that is decided here
## beyond timing; how hard the shake is and how high the bounce goes are inspector
## fields.
##
## [b]What is in it is handed to it, not decided by it.[/b]
## [method set_reward] is called by [TroubleRewardDirector] with the blood and the
## number of items the tier worked out, so this file has no idea what a Danger is
## worth. The blood goes straight into the player's carried wallet - never into the
## base's pool - and the items are instanced as whatever [member item_scene] is, so
## when there is a real item system the chest reaches it by having that scene
## dropped into one inspector field.
##
## It cannot be taken twice, and it is not on a timer: an uncollected chest stands
## in the desert for as long as the player leaves it.

## Emitted as the chest touches the ground - the same frame the camera is shaken.
signal landed
## Emitted once, when the chest is actually taken.
signal collected(blood: int, items: int)

## Group every chest joins, so a director can find one without holding a reference
## across a rebuild.
const GROUP := &"reward_chest"

## The wallet the blood is paid into - the [code]Blood[/code] autoload, which is the
## blood in the player's hands. [b]Deliberately not the bank[/b]: what a search paid
## has to be carried home like everything else, and can be lost like everything else.
@export var wallet_path: NodePath = ^"/root/Blood"

@export_group("The fall")
## How far above its landing spot the chest starts, in pixels. Comfortably more than
## half a screen, so it enters from above the visible area whatever the camera is
## doing.
@export var fall_height: float = 1200.0
## How long the fall takes, in seconds.
@export var fall_time: float = 0.85
## How long the chest waits after being dropped before it starts falling, so a
## caller can put it down and let the player look up.
@export var fall_delay: float = 0.0

@export_group("The landing")
## How hard the camera is shaken as it hits, and for how long. The world's own
## shake, the same one a death and a shotgun use.
@export var landing_shake: float = 34.0
@export var landing_shake_time: float = 0.5
## How high the chest bounces back up after it lands, in pixels, and how long the
## bounce takes each way. Small: it is a heavy box, not a ball.
@export var bounce_height: float = 46.0
@export var bounce_up_time: float = 0.16
@export var bounce_down_time: float = 0.22
## How far the chest squashes as it lands, as a fraction. 0 leaves it rigid.
@export_range(0.0, 0.6, 0.01) var landing_squash: float = 0.22

@export_group("Reaching it")
## How close the player has to stand, in pixels. Generous, exactly as the crates and
## the base's stations are.
@export var interaction_radius: float = 170.0
## Only bodies in this group can take it.
@export var body_group: StringName = &"player"
## Key that takes it - the project's own interact action, so a chest is opened with
## whatever every other interaction in the game is opened with.
@export var interact_action: StringName = &"interact"

@export_group("Nodes")
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"
## The artwork, dropped and then faded as the chest is taken.
@export var art_path: NodePath = ^"Art"
## The chest sprite itself, swapped to [member open_texture] as it is taken.
@export var sprite_path: NodePath = ^"Art/Chest"
## What the chest looks like once it has been opened. Optional - without one the
## chest simply fades as it is.
@export var open_texture: Texture2D

@export_group("The items")
## What one item in the chest is. Instanced into the chest's own parent as it is
## opened, so the player collects each of them with the same key they opened the
## chest with.
##
## [b]This is the seam a real item system arrives through.[/b] There is no inventory
## in this game yet, so what a chest's items are is whatever scene is dropped here -
## the ammunition crate, to begin with - and nothing in this file knows or cares.
@export var item_scene: PackedScene
## How far from the chest the items are scattered, in pixels: the nearest and the
## furthest.
@export var item_spread := Vector2(90.0, 180.0)

@export_group("Taken")
## How long the chest fades out over once it has been taken, in seconds, and how far
## it lifts as it goes - the same acknowledgement a crate gives.
@export var collect_fade: float = 0.45
@export var collect_lift: float = 30.0

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D

## What this particular chest is carrying, handed to it by whoever dropped it.
var _blood: int = 0
var _items: int = 0

var _in_reach: bool = false
var _landed: bool = false
var _taken: bool = false
var _art_rest := Vector2.ZERO
var _tween: Tween


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	if _art != null:
		_art_rest = _art.position


## What this chest is worth. Called before [method drop] by whoever built it; a
## chest nobody tells is simply empty and refuses to be taken.
func set_reward(blood: int, items: int) -> void:
	_blood = maxi(blood, 0)
	_items = maxi(items, 0)


func get_blood() -> int:
	return _blood


func get_items() -> int:
	return _items


func is_landed() -> bool:
	return _landed


func is_taken() -> bool:
	return _taken


## Sends it down. The node is already standing where it will land - so the reach
## circle and the prompt are in the right place from the first frame - and it is the
## artwork that falls into it.
func drop() -> void:
	if _art == null:
		_land()
		return

	_art.position = _art_rest - Vector2(0.0, maxf(fall_height, 0.0))
	_art.visible = true

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	if fall_delay > 0.0:
		_tween.tween_interval(fall_delay)
	# Eased in rather than linear: a falling thing accelerates, and the whole reason
	# the landing reads as an impact is that it is quickest at the bottom.
	_tween.tween_property(_art, "position", _art_rest, maxf(fall_time, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_land)


## It hits: the ground shakes, the chest squashes, bounces once and settles. From
## the same frame it can be picked up.
func _land() -> void:
	if _landed:
		return
	_landed = true

	var camera := CameraController.get_active(self)
	if camera != null and landing_shake > 0.0:
		camera.shake(landing_shake, maxf(landing_shake_time, 0.0))

	landed.emit()

	if _art == null:
		return

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()

	if landing_squash > 0.0:
		# Squashed on the frame of impact and let go again, so the weight is carried by
		# the artwork rather than by the camera alone.
		_art.scale = Vector2(1.0 + landing_squash, 1.0 - landing_squash)
		_tween.tween_property(_art, "scale", Vector2.ONE, maxf(bounce_up_time, 0.0001)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween = _tween.parallel()

	_tween.tween_property(_art, "position", _art_rest - Vector2(0.0, maxf(bounce_height, 0.0)),
		maxf(bounce_up_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(_art, "position", _art_rest,
		maxf(bounce_down_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Whether [param body] is standing close enough to open the chest.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return global_position.distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Takes the chest, and reports whether there was anything to take.
##
## Guarded three ways, which between them are the whole of "it cannot be collected
## twice": it must have landed, the player must be at it, and it must not already
## have been taken.
func use() -> bool:
	if _taken or not _landed or not _in_reach:
		return false

	_taken = true
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	# Left the group as it is taken rather than when it finishes fading, so nothing
	# counts a chest that is already spent as still standing.
	remove_from_group(GROUP)
	set_process(false)

	_pay_blood()
	var placed := _place_items()

	collected.emit(_blood, placed)
	_play_taken()
	return true


## Straight into the player's hands. [b]Never into the base's pool[/b] - what a
## search paid is carried, and carried blood is what a death takes away.
func _pay_blood() -> void:
	if _blood <= 0:
		return
	var wallet := get_node_or_null(wallet_path) as BloodWallet
	if wallet != null:
		wallet.add(_blood)


## Puts the chest's items out around it and reports how many were actually built. A
## chest with nothing authored to give quietly gives nothing.
func _place_items() -> int:
	if _items <= 0 or item_scene == null:
		return 0

	var container := get_parent()
	if container == null:
		return 0

	var placed := 0
	for index: int in range(_items):
		var item := item_scene.instantiate() as Node2D
		if item == null:
			continue
		# Spread round the chest rather than dropped on it, so three of them are three
		# things to walk to instead of one pile.
		var angle := TAU * (float(index) + randf() * 0.6) / float(maxi(_items, 1))
		var reach := randf_range(minf(item_spread.x, item_spread.y), maxf(item_spread.x, item_spread.y))
		container.add_child(item)
		item.global_position = global_position + Vector2.RIGHT.rotated(angle) * reach
		item.reset_physics_interpolation()
		placed += 1
	return placed


## The chest going: opened, lifted and faded, then freed. Nothing waits on it - the
## blood is already paid and the items are already standing - so a world torn down
## mid-fade loses nothing.
func _play_taken() -> void:
	if _sprite != null and open_texture != null:
		_sprite.texture = open_texture

	if _art == null or collect_fade <= 0.0:
		queue_free()
		return

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_art, "modulate:a", 0.0, collect_fade)
	if collect_lift > 0.0:
		_tween.tween_property(_art, "position", _art_rest - Vector2(0.0, collect_lift),
			collect_fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame.
func _watch_player() -> void:
	if _taken or not _landed:
		return

	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)


func _unhandled_input(event: InputEvent) -> void:
	if _taken or not _landed or not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	# Marked handled whether it was taken or refused, so a press aimed at the chest is
	# never also a shot.
	get_viewport().set_input_as_handled()
