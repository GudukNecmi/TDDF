class_name ExtractionResultScreen
extends Control
## The receipt for one Extraction, raised over the World Map the instant
## [WorldMapExtractionService] has already settled it.
##
## [b]It reports; it never decides.[/b] Every figure it prints is read
## straight off the [ExtractionSettlement] handed to [method show_settlement] -
## by the time this is open, the Blood has already moved and every bounty
## has already been judged, exactly as rule 6 of the Extraction phase asks:
## Extraction itself is instant, with no secondary confirmation, and this
## screen is the report of something that already happened rather than a
## gate in front of it. That is also why - unlike [CashOutScreen], its
## closest relative in this project - there is no Escape key here and no
## way to back out: there is nothing left uncommitted to back out of.
##
## [b]Styled from the scene, like the rest of this project's menus.[/b] Every
## line it prints is an inspector field, and it shares [CashOutScreen]'s own
## panel, blur and button art rather than inventing a second look for
## leaving a run.

## Emitted once RETURN TO BASE is pressed - [WorldMapExtractionService]
## listens for this to actually start the journey home.
signal continued

## Group the screen joins, so a debug readout can find it without a path.
const GROUP := &"extraction_result_screen"

@export var pauses_game: bool = true

@export_group("Nodes")
@export var player_blood_label_path: NodePath = ^"Panel/Body/Rows/PlayerBlood"
@export var horse_blood_label_path: NodePath = ^"Panel/Body/Rows/HorseBlood"
@export var depot_blood_label_path: NodePath = ^"Panel/Body/Rows/DepotBlood"
@export var completed_label_path: NodePath = ^"Panel/Body/Rows/Completed"
@export var incomplete_label_path: NodePath = ^"Panel/Body/Rows/Incomplete"
@export var final_label_path: NodePath = ^"Panel/Body/Earned"
@export var continue_button_path: NodePath = ^"Panel/Body/Footer/ContinueButton"
@export var hint_label_path: NodePath = ^"Panel/Body/Footer/Hint"

@export_group("Wording")
@export var title_text: String = "EXTRACTED"
@export var player_blood_format: String = "PLAYER BLOOD  %d"
## Rule 14 asks for a Horse Blood line and a Depot Blood line. This project
## keeps one wallet for both - see [ExtractionSettlement]'s own class doc -
## so both lines are printed from the identical figure rather than one of
## them being invented.
@export var horse_blood_format: String = "HORSE BLOOD  %d"
@export var depot_blood_format: String = "DEPOT BLOOD  %d"
@export var completed_format: String = "BOUNTIES COMPLETED  %d   (+%d BLOOD)"
@export var incomplete_format: String = "BOUNTIES INCOMPLETE  %d   (-%d BLOOD)"
@export var final_format: String = "FINAL BLOOD  +%d"
@export var final_empty_text: String = "FINAL BLOOD  0"
@export var continue_text: String = "RETURN TO BASE"
@export var hint_text: String = "THE RUN IS OVER"

@onready var _player_blood_label: Label = get_node_or_null(player_blood_label_path) as Label
@onready var _horse_blood_label: Label = get_node_or_null(horse_blood_label_path) as Label
@onready var _depot_blood_label: Label = get_node_or_null(depot_blood_label_path) as Label
@onready var _completed_label: Label = get_node_or_null(completed_label_path) as Label
@onready var _incomplete_label: Label = get_node_or_null(incomplete_label_path) as Label
@onready var _final_label: Label = get_node_or_null(final_label_path) as Label
@onready var _continue_button: Button = get_node_or_null(continue_button_path) as Button
@onready var _hint_label: Label = get_node_or_null(hint_label_path) as Label

var _continued: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()

	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue_pressed)
	if _hint_label != null:
		_hint_label.text = hint_text


static func get_active(from_node: Node) -> ExtractionResultScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as ExtractionResultScreen


func is_open() -> bool:
	return visible


## Raises the screen already showing [param settlement]'s figures. Called
## once by [WorldMapExtractionService], the instant after it has finished
## settling the run - never before, and never a second time for the same
## Extraction.
func show_settlement(settlement: ExtractionSettlement) -> void:
	if settlement == null:
		return

	_continued = false
	_refresh(settlement)
	show()
	_drop_focus()
	if pauses_game:
		get_tree().paused = true


func _refresh(settlement: ExtractionSettlement) -> void:
	if _player_blood_label != null:
		_player_blood_label.text = player_blood_format % settlement.player_blood
	if _horse_blood_label != null:
		_horse_blood_label.text = horse_blood_format % settlement.horse_blood
	if _depot_blood_label != null:
		_depot_blood_label.text = depot_blood_format % settlement.horse_blood
	if _completed_label != null:
		_completed_label.text = completed_format % [
			settlement.completed_bounties.size(), settlement.bounty_reward_total]
	if _incomplete_label != null:
		_incomplete_label.text = incomplete_format % [
			settlement.incomplete_bounties.size(), settlement.bounty_penalty_total]
	if _final_label != null:
		_final_label.text = (
			final_empty_text if settlement.final_blood <= 0
			else final_format % settlement.final_blood)
	if _continue_button != null:
		_continue_button.text = continue_text


func _on_continue_pressed() -> void:
	if _continued:
		return
	_continued = true

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false

	continued.emit()


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
