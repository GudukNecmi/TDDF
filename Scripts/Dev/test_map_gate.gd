class_name TestMapGate
extends Node2D
## The door between the desert and the test map, and the same door in reverse.
##
## [b]It travels nothing itself.[/b] Pressing E hands the trip to the player's own
## [Teleporter] with a destination named on this node - so the snap, the silence, the
## camera closing in, the arrival point and the camera limits are all the one journey
## the game already has, and there is no second way of moving the player anywhere in
## the project. A gate is therefore a [TeleportDestination]'s id written on a node in
## the editor, and putting a door somewhere new is dragging one of these into a scene.
##
## [b]It goes quietly.[/b] The trip is asked for silently, which in [Teleporter] means
## two things: no finger snap, and the soundtrack is left alone. The snap is the
## player's own B gesture and this is not it; and a developer stepping out to a test
## map has not left the fight, so handing the music over to the base track and back
## again would be a crossfade nobody asked for.
##
## [b]It can never start a run.[/b] The B key is contextual - pressed in the base's
## pit it sets out instead of teleporting - so the trip is asked for with that branch
## refused. A door is a door wherever it is standing.
##
## [b]One gate can also answer a key from anywhere.[/b] See
## [member shortcut_action]: the developer's gate in the world is given one, and the
## press runs the identical journey rather than a shortcut of its own. It is the
## same door, reached without the walk.
##
## It is [WeaponRack] with a journey behind it rather than a screen, and deliberately
## the same shape: the player is found by group, the reach test is a circle around
## this node, the prompt is told on the crossing, and the key is taken in
## [method Node._unhandled_input] and marked handled.

## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when the gate is actually used and the journey began.
signal used

## Which [TeleportDestination] this door leads to.
@export var destination_id: StringName = &"test_map"
## How close the player has to stand for the prompt to appear and the key to work,
## in pixels.
@export var interaction_radius: float = 170.0
## Only bodies in this group can use it.
@export var body_group: StringName = &"player"
## Key that opens it.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, relative to this node.
@export var reach_offset := Vector2.ZERO
## A key that takes the same journey from anywhere on the map, without walking to
## the door first.
##
## [b]Empty on every gate the player is meant to find[/b] - including the test map's
## own way back - so a door is ordinarily somewhere you have to stand. It is filled
## in on the developer's gate alone, and it is the whole of the shortcut: the press
## goes through [method travel], which is the same call the E key makes, so the
## journey, the arrival point and the camera limits are the one the door already
## had. Nothing about a run, a ride, a camp or anything written down is touched by
## it, for the same reason walking through the door does not touch them.
@export var shortcut_action: StringName = &""

@export_group("Nodes")
## The prompt shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false


func _ready() -> void:
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## Whether [param body] is standing close enough to use the gate.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Sends the player through. Ignored unless they are actually standing at it.
## Returns whether a journey began - false when there is no teleporter to ask, or
## when one was already under way.
func use() -> bool:
	if not _in_reach:
		return false
	return travel()


## The journey itself, with the doorstep taken out of it.
##
## Split off from [method use] so the developer's [member shortcut_action] can make
## the trip from across the map without a second copy of it existing: the key and
## the door are the same three lines, and retuning one retunes the other. Public
## because a scripted test that wants to be somewhere else has the same need and
## should not have to walk.
func travel() -> bool:
	var teleporter := _find_teleporter()
	if teleporter == null:
		return false

	# Silent, and with the contextual run-portal branch refused. See this class's
	# own notes for why both.
	if not teleporter.teleport(true, false, destination_id):
		return false

	if _prompt != null:
		_prompt.set_prompt_visible(false)
	used.emit()
	return true


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	if _in_reach:
		player_entered.emit()
	else:
		player_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Asked before the reach test, because the whole point of it is that there is no
	# reach test. Only a press that actually travelled is marked handled, so a key
	# that found nothing to travel to leaves the event for whatever else wants it.
	if shortcut_action != &"" and event.is_action_pressed(shortcut_action):
		if travel():
			get_viewport().set_input_as_handled()
		return

	if not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	get_viewport().set_input_as_handled()


## The player's own teleporter, found on the body rather than by a path across the
## scene - the same way every other system that reaches into the player finds a
## component on it.
func _find_teleporter() -> Teleporter:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	if body == null:
		return null
	for node: Node in body.find_children("*", "Teleporter", true, false):
		var teleporter := node as Teleporter
		if teleporter != null:
			return teleporter
	return null
