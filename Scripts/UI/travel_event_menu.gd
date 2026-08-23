class_name TravelEventMenu
extends Control
## The road stops and the player is asked: ride past, or take them on.
##
## [b]It decides nothing.[/b] It is handed a [TravelEvent], writes what that file
## says on it, and reports which button was pressed - see [signal answered]. What
## happens next, and whether an event asks at all, is [TravelDirector]'s.
##
## It is deliberately the plainest screen in the game: a name, a line, and two
## buttons wearing the styleboxes every other menu wears, dropped into the same
## HUD. There is no artwork for a gang yet and none is invented here.
##
## The world is already frozen when this comes up - the journey is being made
## behind black - so it takes the pause over the same way every other menu does and
## hands it back as it goes.

## Emitted once the player has answered. [param fight] is true for the button that
## takes them on.
signal answered(fight: bool)

## Group the screen joins, so the director can find it without a path across the
## HUD.
const GROUP := &"travel_event_menu"

## Freezes the world while the question is up.
@export var pauses_game: bool = true

@export_group("Nodes")
@export var title_label_path: NodePath = ^"Panel/Body/Title"
@export var description_label_path: NodePath = ^"Panel/Body/Description"
@export var ignore_button_path: NodePath = ^"Panel/Body/Buttons/IgnoreButton"
@export var fight_button_path: NodePath = ^"Panel/Body/Buttons/FightButton"

@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _description: Label = get_node_or_null(description_label_path) as Label
@onready var _ignore: Button = get_node_or_null(ignore_button_path) as Button
@onready var _fight: Button = get_node_or_null(fight_button_path) as Button

## True from the moment a button is pressed, so a second press cannot answer twice.
var _answered: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	if _ignore != null:
		_ignore.pressed.connect(_on_answer.bind(false))
	if _fight != null:
		_fight.pressed.connect(_on_answer.bind(true))


## The screen the director should raise. Null means this world has none, which it
## reads as "there is nobody to ask" and rides past.
static func get_active(from_node: Node) -> TravelEventMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelEventMenu


func is_open() -> bool:
	return visible


## Puts the question up, written from [param event]'s own file.
func ask(event: TravelEvent) -> void:
	if event == null:
		return
	ask_choice(event.get_label(), event.description, event.ignore_text, event.fight_text)


## The same question with its words handed over directly: a heading, a line under
## it, and the two buttons named.
##
## [b]It is [method ask] without the resource[/b], for a caller whose question is
## not an event on the road - CONTINUE or STOP after a Trouble Danger, which is
## [DangerDirector]'s. [signal answered] still reports which side was pressed, true
## for [param yes_text], so both callers read the answer the same way and there is
## one two-button screen in the game rather than two.
func ask_choice(title: String, description: String, no_text: String, yes_text: String) -> void:
	if visible:
		return

	_answered = false
	if _title != null:
		_title.text = title
	if _description != null:
		_description.text = description
		_description.visible = not description.is_empty()
	if _ignore != null:
		_ignore.text = no_text
	if _fight != null:
		_fight.text = yes_text

	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true


## The same screen with one button instead of two: something to read and one way
## out of it.
##
## [b]It is not a second screen.[/b] The end of a search for trouble has nothing to
## decide - the country is quiet and the only thing left is to go back - so rather
## than a notice panel of its own it is this one with the refusing button taken off.
## [signal answered] still fires, always true, so a caller reads it exactly as it
## reads a question.
##
## The button comes back for the next caller, in [method close], so a notice can
## never leave the road's gangs with one answer.
func ask_notice(title: String, description: String, button_text: String) -> void:
	if visible:
		return

	ask_choice(title, description, "", button_text)
	if _ignore != null:
		_ignore.visible = false


## Takes the question back down. Called as the answer is given, and safe to call on
## a screen that is already down.
func close() -> void:
	if not visible:
		return
	if _ignore != null:
		_ignore.visible = true
	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false


## [b]There is no way to back out.[/b] Escape is not handled and the screen has no
## close button, because riding past is already one of the two answers - a gang on
## the road is a question that has to be answered, not one that can be dismissed.
func _on_answer(fight: bool) -> void:
	if _answered:
		return
	_answered = true
	close()
	answered.emit(fight)


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
