class_name WorldMapWantedBoardMenu
extends Control
## The screen [WorldMapWantedBoard] raises: exactly one [WantedPoster], for
## exactly one contract - "only one local wanted target" - rather than
## [WantedBoardMenu]'s whole row of five.
##
## [b]It reads the identical board [WantedBoardMenu] does.[/b] Both ask
## [BountyLedger] - the [code]Bounties[/code] autoload - for
## [method BountyLedger.get_board]; this only ever shows the first contract
## still hanging on it rather than every one, and hands TAKE to
## [method BountyLedger.accept] exactly the way the base's own board does -
## the same authority, the same lock-on-acceptance rule, the same knowledge
## categories printed on the sheet. No second bounty system and no second
## board exist anywhere in this file.

signal opened
signal closed
signal bounty_taken(bounty: Bounty)

## Group this joins, so [WorldMapWantedBoard] can find it by group the way
## the base board finds [WantedBoardMenu].
const GROUP := &"world_map_wanted_board_menu"

@export var poster_scene: PackedScene
@export var ledger_name: StringName = &"Bounties"
## Off, unlike the base's own board: reading one poster standing out in the
## open should not stop [WorldClock] or the World Map's own roaming groups,
## the way stepping into the base's paused wanted board already does.
@export var pauses_game: bool = false
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
@export var poster_container_path: NodePath = ^"Panel/Body/PosterSlot"
@export var empty_label_path: NodePath = ^"Panel/Body/EmptyLabel"
@export var close_button_path: NodePath = ^"Panel/Body/CloseButton"

@export_group("Wording")
@export var empty_text: String = "NO CONTRACTS ARE POSTED HERE"

@onready var _slot: Container = get_node_or_null(poster_container_path) as Container
@onready var _empty_label: Label = get_node_or_null(empty_label_path) as Label
@onready var _close_button: Button = get_node_or_null(close_button_path) as Button

var _ledger: BountyLedger
var _poster: WantedPoster


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	if _close_button != null:
		_close_button.pressed.connect(close)

	var ledger := _get_ledger()
	if ledger != null and not ledger.board_changed.is_connected(_rebuild):
		ledger.board_changed.connect(_rebuild)


static func get_active(from_node: Node) -> WorldMapWantedBoardMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapWantedBoardMenu


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return

	_rebuild()
	show()
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


func close() -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


## One sheet, for the first contract still on the board - torn down and
## rebuilt exactly as [method WantedBoardMenu._rebuild] does its whole row,
## just for a single slot.
func _rebuild() -> void:
	if _slot == null:
		return

	for child: Node in _slot.get_children():
		_slot.remove_child(child)
		child.queue_free()
	_poster = null

	var bounty := _find_local_bounty()
	if _empty_label != null:
		_empty_label.visible = bounty == null

	var ledger := _get_ledger()
	if bounty == null or ledger == null or poster_scene == null:
		return

	var settings := ledger.get_settings()
	var poster := poster_scene.instantiate() as WantedPoster
	if poster == null:
		return

	_slot.add_child(poster)
	poster.set_bounty(bounty, settings.knowledge_categories, bounty.get_rarity(settings))
	poster.set_acceptable(ledger.has_free_slot())
	poster.accept_requested.connect(_on_accept_requested)
	_poster = poster


## The one bounty this board offers - the first contract still hanging on
## [BountyLedger]'s own board, exactly as it is generated and priced there.
## Null when the board has nothing on it, which every caller here reads as
## "the board is bare".
func _find_local_bounty() -> Bounty:
	var ledger := _get_ledger()
	if ledger == null:
		return null
	for bounty: Bounty in ledger.get_board():
		if bounty != null:
			return bounty
	return null


func _on_accept_requested(poster: WantedPoster) -> void:
	var ledger := _get_ledger()
	if ledger == null or poster == null:
		return

	var bounty := poster.get_bounty()
	if ledger.accept(bounty):
		bounty_taken.emit(bounty)
		close()
	else:
		_rebuild()


func _get_ledger() -> BountyLedger:
	if _ledger == null or not is_instance_valid(_ledger):
		_ledger = get_node_or_null(NodePath("/root/%s" % ledger_name)) as BountyLedger
	return _ledger


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
