class_name WantedBoard
extends Node2D
## The board of posters standing in the base: walk up to it, press E, and the
## contracts on offer come up.
##
## It is the same shape as [ArenaPortal]'s half of an interaction, and for the
## same reasons. The player is found by group rather than by path, the reach test
## is a circle around this node rather than an area to author, the prompt is
## *told* on the crossing rather than asked every frame, and the key is taken in
## [method Node._unhandled_input] and marked handled so the press that opens the
## board cannot also reach the shotgun standing behind it.
##
## The board decides nothing about what it shows. It reports that the player is
## close, shows them the E, and raises whatever [WantedBoardMenu] the world has -
## found by group, because this lives inside the base's own scene and the menu
## lives on the HUD. A world with no menu still lights up and simply opens
## nothing, so the base is never broken by the HUD being rebuilt.

## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when they actually open the board.
signal used

## Group every board joins, so anything can find it without being wired to it.
const GROUP := &"wanted_board"

## How close the player has to stand for the prompt to appear and the key to
## work, in pixels. Generous on purpose - "at the board" has to mean somewhere
## the player can casually walk to, not a pixel they have to find.
@export var interaction_radius: float = 190.0
## Only bodies in this group can use it.
@export var body_group: StringName = &"player"
## Key that opens it.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, so the circle can sit at the front of the
## board rather than at the middle of the artwork.
@export var reach_offset := Vector2(0.0, 60.0)

@export_group("Nodes")
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false
var _menu: WantedBoardMenu


func _ready() -> void:
	add_to_group(GROUP)
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## The board the rest of the scene should talk to. Null means this world has
## none, which every caller reads as "there is nowhere to take a contract".
static func get_active(from_node: Node) -> WantedBoard:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WantedBoard


## Whether [param body] is standing close enough to read the board.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Opens the board. Ignored unless the player is actually standing at it, so
## nothing can be triggered from across the base.
func use() -> void:
	if not _in_reach:
		return

	used.emit()
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	var menu := _get_menu()
	if menu != null:
		menu.open()


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame and anything else that wants to react to the player
## arriving can hang off the signals instead of repeating the distance test.
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
	if not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	get_viewport().set_input_as_handled()


## Looked up lazily and re-looked-up if it goes away, the same way [RunPortal]
## finds the map selection.
func _get_menu() -> WantedBoardMenu:
	if _menu == null or not is_instance_valid(_menu):
		_menu = WantedBoardMenu.get_active(self)
	return _menu
