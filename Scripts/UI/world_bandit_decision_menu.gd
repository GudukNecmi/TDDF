class_name WorldBanditDecisionMenu
extends Control
## The short bandit-contact screen: one line from the bandits, and one to
## three replies back - built the plain way [TravelEventMenu] already is,
## a name and a set of buttons wearing the same styleboxes every menu in
## the game wears, rather than a stretched copy of that screen. It is its
## own screen because [DangerDirector]'s own CONTINUE/STOP question needs
## [TravelEventMenu] fixed at exactly two buttons, and STRONGER, EQUAL and
## WEAKER do not all want the same number.
##
## [b]It decides nothing.[/b] Handed a [WorldBanditDecisionTier] by
## [WorldMapCombatBridge], it picks one bandit line at random off
## [method WorldBanditDecisionTier.pick_line], shows exactly as many
## buttons as [member WorldBanditDecisionTier.choices] carries, and reports
## which [member WorldBanditDecisionChoice.outcome] was pressed - see
## [signal answered]. What paying, taking, walking away or fighting actually
## does is entirely [WorldMapCombatBridge]'s.

signal answered(outcome: StringName)

const GROUP := &"world_bandit_decision_menu"

## Whether the world is frozen while the question is up - the same as every
## other menu built this way.
@export var pauses_game: bool = true

@export_group("Nodes")
@export var line_label_path: NodePath = ^"Panel/Body/Line"
## One path per button this screen can ever show, in the order
## [member WorldBanditDecisionTier.choices] is read. A tier with fewer
## choices than there are paths simply hides the rest.
@export var button_paths: Array[NodePath] = [
	^"Panel/Body/Buttons/Choice1",
	^"Panel/Body/Buttons/Choice2",
	^"Panel/Body/Buttons/Choice3",
]

@onready var _line: Label = get_node_or_null(line_label_path) as Label

var _buttons: Array[Button] = []
## True from the moment a button is pressed, so a second press - or a second
## signal from a button double-clicked before the screen hides - cannot
## answer twice.
var _answered: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	for path: NodePath in button_paths:
		var button := get_node_or_null(path) as Button
		var index := _buttons.size()
		_buttons.append(button)
		if button != null:
			button.pressed.connect(_on_button_pressed.bind(index))


## The screen the bridge should raise, or null when this world has none -
## which [WorldMapCombatBridge] reads as "there is nowhere to ask, so a
## contact goes straight to the fight it always used to".
static func get_active(from_node: Node) -> WorldBanditDecisionMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldBanditDecisionMenu


func is_open() -> bool:
	return visible


## Puts the question up. Does nothing on a null tier or a screen already
## showing, exactly as [method TravelEventMenu.ask_choice] refuses a second
## call while one is already up.
func ask(tier: WorldBanditDecisionTier) -> void:
	if tier == null or visible:
		return

	_answered = false
	if _line != null:
		_line.text = tier.pick_line()

	for i in _buttons.size():
		var button := _buttons[i]
		if button == null:
			continue
		if i < tier.choices.size():
			var choice := tier.choices[i]
			button.text = choice.label if choice != null else ""
			button.set_meta(&"outcome", &"fight" if choice == null else choice.outcome)
			button.visible = true
		else:
			button.visible = false

	show()
	_drop_focus()
	if pauses_game:
		get_tree().paused = true


## Takes the question back down without answering it - what
## [WorldMapCombatBridge] calls if a contact it opened this for turns out
## not to be able to start after all, the same way it already cancels a
## loading transition it cannot follow through on.
func close() -> void:
	if not visible:
		return
	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false


func _on_button_pressed(index: int) -> void:
	if _answered or index < 0 or index >= _buttons.size():
		return
	var button := _buttons[index]
	if button == null:
		return

	_answered = true
	var outcome := button.get_meta(&"outcome", &"fight") as StringName
	close()
	answered.emit(outcome)


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
