class_name GroundPickup
extends Node2D
## Something lying in the sand the player can walk up to and take: a knife an
## enemy dropped, a bone kicked out of a pile.
##
## [b]It is a component, not an object.[/b] It carries no artwork, no collision and
## no physics of its own - it is dropped in as a child of whatever is already lying
## there, and the thing it is hung on goes on being exactly what it was. That is
## what lets the desert's existing bone be made collectable by adding a node to its
## scene rather than by a second kind of bone coming into existence, and it is why
## a dropped knife can be an ordinary piece of [DeathDebris] that happens to have
## this on it.
##
## [b]It is [WeaponRack] with a thing on the floor instead of a table[/b], and
## deliberately the same shape: the player is found by group rather than by path,
## the reach test is a circle around this node rather than an area to author, the
## prompt is [i]told[/i] on the crossing rather than asked every frame, and the key
## is taken in [method Node._unhandled_input] and marked handled - so the press that
## picks the knife up cannot also reach the weapon standing behind it, and two items
## lying on top of each other cannot both be taken by one press.
##
## [b]What it hands over is a scene, and the handing over is the mount's.[/b] See
## [method WeaponMount.carry_temporary]: the weapon the player chose is put away by
## the same holster every zone change uses, the scene named here is built in its
## place, and throwing that gives the first one back. There is no inventory here, no
## slot, and no second answer to what the player is holding.

## Emitted as the player takes it, carrying the weapon that was built. Sent just
## before the item leaves the world.
signal taken(weapon: CarriedWeapon)

## The weapon built into the player's hands when this is taken.
@export var weapon_scene: PackedScene
## How long the weapon already in the player's hands takes to reach the belt, in
## seconds. Short: picking something up off the floor is not a draw.
@export var switch_time: float = 0.1

@export_group("Reach")
## How close the player has to stand for the prompt to appear and the key to work,
## in pixels. Tighter than a station's, because this is a thing on the ground the
## player walks over rather than somewhere they walk to.
@export var interaction_radius: float = 95.0
## Only bodies in this group can take it.
@export var body_group: StringName = &"player"
## Key that takes it - the project's own interact action, so a knife is picked up
## with whatever every other interaction in the game is opened with.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, relative to this node.
@export var reach_offset := Vector2.ZERO
## A method on the thing this is hung on that answers true while it is still
## travelling. While it does, the item cannot be taken - so a bone still skittering
## across the sand is not plucked out of the air.
##
## Left empty, or named on a host that has no such method, the item can be taken the
## moment it exists. That is the right answer for a knife, which is worth picking up
## the instant it leaves the hand.
@export var moving_method: StringName = &"is_flying"

@export_group("Nodes")
## The prompt shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"
## The picture the built weapon takes its own artwork from, so a knife the player
## picks up is the knife they were looking at rather than a stand-in for it.
##
## Left empty the first sprite on the host is used, which is what every item here is
## - one picture lying on the ground.
@export var art_source_path: NodePath
## Whether the thing this is hung on is removed as the item is taken. On, because
## the item [i]is[/i] the host: the knife on the floor is gone the instant it is in
## the player's hand. Off removes only this component, for a host that has other
## reasons to exist.
@export var frees_host: bool = true

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false
## True from the instant the item has been handed over. It is what makes a second
## press - or a second frame of the same press - unable to hand out a second weapon.
var _taken: bool = false


func _ready() -> void:
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## Whether [param body] is standing close enough to take this.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) \
		<= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Whether this has already been picked up.
func is_taken() -> bool:
	return _taken


## Takes the item. Ignored unless the player is actually standing over it, and
## ignored for good once it has been taken. Returns whether it was.
func use() -> bool:
	if _taken or not _in_reach or weapon_scene == null:
		return false

	var mount := WeaponMount.get_active(self)
	if mount == null:
		return false

	# Spent before anything else happens, so nothing that follows - a signal, a
	# second press arriving in the same frame - can hand the same item out twice.
	_taken = true
	set_process(false)
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	var weapon := mount.carry_temporary(weapon_scene, switch_time)
	_dress(weapon)
	taken.emit(weapon)

	# Gone from the world on the same frame it is in the hand, so there is never a
	# moment where the knife is both lying there and being carried.
	if frees_host:
		var host := get_parent()
		if host != null:
			host.queue_free()
			return true
	queue_free()
	return true


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame and anything else that wants to react to the player
## standing over this can hang off the reach instead of repeating the test.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := not _taken and _is_settled() and is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)


## Whether the thing this is hung on has finished moving. Asked of the host by name
## rather than by type, so a host that has no such notion - a piece of debris that
## is simply lying there - is settled by definition.
func _is_settled() -> bool:
	if moving_method == &"":
		return true
	var host := get_parent()
	if host == null or not host.has_method(moving_method):
		return true
	return not bool(host.call(moving_method))


## Hands the built weapon the picture off the floor, when it is a weapon that takes
## one. Guarded on the method rather than on the type, so a weapon that has nothing
## to dress simply keeps its own artwork.
func _dress(weapon: CarriedWeapon) -> void:
	if weapon == null or not weapon.has_method(&"adopt_texture"):
		return

	var art := _art_source()
	if art != null and art.texture != null:
		weapon.call(&"adopt_texture", art.texture)


func _art_source() -> Sprite2D:
	if not art_source_path.is_empty():
		return get_node_or_null(art_source_path) as Sprite2D

	var host := get_parent()
	if host == null:
		return null
	for node: Node in host.find_children("*", "Sprite2D", false, false):
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
		# Marked handled so one press takes one item: two knives lying together
		# offer two prompts, and the press reaches only the first of them.
		get_viewport().set_input_as_handled()
