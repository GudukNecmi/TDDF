class_name WorldMapWantedBoard
extends Node2D
## A second wanted board, standing out on the World Map rather than in the
## base: walk up to it, press E, and the one local contract it is carrying
## comes up.
##
## [b]The same shape as [WantedBoard], for the same reasons[/b] - see that
## class's own doc, which this repeats rather than inherits from: the player
## is found by group, the reach test is a circle around this node, the prompt
## is told on the crossing rather than asked every frame, and the key is
## taken in [method Node._unhandled_input] and marked handled so the press
## that reads the board cannot also fire the gun. It is its own script,
## rather than a second instance of [WantedBoard], purely because it opens a
## different screen - [WorldMapWantedBoardMenu], one poster instead of a
## whole row of five - not because a World Map board needs to behave any
## differently as an interaction.
##
## [b]It decides nothing about the contract itself.[/b] Exactly like the base
## board, it reports that the player is close, shows them the E, and raises
## whatever [WorldMapWantedBoardMenu] the world has - found by group, since
## this lives in [code]WorldMap.tscn[/code] and the menu lives on the HUD. A
## world with no menu still lights up and simply opens nothing.

signal player_entered
signal player_exited
signal used

## Group every World Map board joins.
const GROUP := &"world_map_wanted_board"

@export var interaction_radius: float = 190.0
@export var body_group: StringName = &"player"
@export var interact_action: StringName = &"interact"
@export var reach_offset := Vector2(0.0, 60.0)

@export_group("Nodes")
@export var prompt_path: NodePath = ^"Prompt"

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false
var _menu: WorldMapWantedBoardMenu


func _ready() -> void:
	add_to_group(GROUP)
	if _prompt != null:
		_prompt.set_prompt_visible(false)


static func get_active(from_node: Node) -> WorldMapWantedBoard:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapWantedBoard


func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


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


func _get_menu() -> WorldMapWantedBoardMenu:
	if _menu == null or not is_instance_valid(_menu):
		_menu = WorldMapWantedBoardMenu.get_active(self)
	return _menu
