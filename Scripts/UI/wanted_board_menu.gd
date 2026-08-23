class_name WantedBoardMenu
extends Control
## The wanted board itself, opened by pressing E at the board in the base.
##
## The posters are generated from whatever [BountyLedger] has pinned up rather
## than authored as five entries, exactly the way [MapSelectMenu] builds its list
## from a [MapCatalog] - so "the board carries five" is a number in
## [BountySettings] and not a row of nodes here. Nothing in this file names an
## outlaw, a map or a price.
##
## It is found by group rather than by path. The board that opens it lives inside
## [code]Base.tscn[/code] and this lives on the HUD, so there is no sensible path
## between them; the base's pit and the map selection already talk to each other
## this way.
##
## Taking a contract is asked for, not done here. The poster reports the press,
## this passes it to the ledger, and the ledger decides - it is the thing that
## knows how many slots are free and it is where the reward gets locked. If it
## says no, nothing happens but the board redrawing.

## Emitted as the board goes up.
signal opened
## Emitted when it is closed, so whatever opened it can put itself back.
signal closed
## Emitted when a contract is actually taken.
signal bounty_taken(bounty: Bounty)

## Group the menu joins, so the base's board can find it without a path across
## the scene.
const GROUP := &"wanted_board_menu"

## One sheet of paper. Instanced once per poster on the board.
@export var poster_scene: PackedScene
## Autoload holding the contracts. Named rather than referenced so the menu still
## builds in a project where the ledger has not been registered - it simply shows
## an empty board.
@export var ledger_name: StringName = &"Bounties"
## Freezes the world while the board is up, the same way the pause, upgrade and
## map menus do.
@export var pauses_game: bool = true
## Key that closes it.
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
## Container the posters are built into. A horizontal box.
@export var list_path: NodePath = ^"Panel/Body/Posters"
## Readout of how many contracts are held.
@export var slots_label_path: NodePath = ^"Panel/Body/Header/Slots"
## Line along the bottom.
@export var hint_label_path: NodePath = ^"Panel/Body/Hint"

@export_group("Empty slots")
## Whether a slot with nothing dealt into it is drawn as a bare patch of board.
## Off closes the row up, which hides the fact that the board was thin this week.
@export var show_empty_slots: bool = true
## How wide a bare slot is drawn, so the row keeps the shape it would have had.
@export var empty_slot_size := Vector2(190.0, 300.0)
## What a bare slot says, if anything.
@export var empty_slot_text: String = "NO PAPER"
@export var empty_slot_colour := Color(0.34, 0.2, 0.18, 1.0)
@export var empty_slot_font_size: int = 16

@export_group("Wording")
## How the slot count is written. Held and total are substituted in, in that
## order.
@export var slots_format: String = "CONTRACTS  %d / %d"
## The line along the bottom while there is room for more.
@export var hint_text: String = "THE LESS THE POSTER KNOWS, THE MORE IT PAYS"
## What it says instead once every slot is taken.
@export var full_hint_text: String = "NO CONTRACT SLOTS LEFT"
## What it says when there is nothing pinned up at all.
@export var empty_hint_text: String = "THE BOARD IS BARE"

@onready var _list: Container = get_node_or_null(list_path) as Container
@onready var _slots: Label = get_node_or_null(slots_label_path) as Label
@onready var _hint: Label = get_node_or_null(hint_label_path) as Label

var _ledger: BountyLedger
var _posters: Array[WantedPoster] = []


func _ready() -> void:
	add_to_group(GROUP)
	hide()

	var ledger := _get_ledger()
	if ledger != null and not ledger.board_changed.is_connected(_rebuild):
		ledger.board_changed.connect(_rebuild)


## The board the base should open. Null means this world has none, which the
## board in the base reads as "there is nothing to show yet".
static func get_active(from_node: Node) -> WantedBoardMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WantedBoardMenu


func is_open() -> bool:
	return visible


## Raises the board. Called by the board in the base rather than by a key, so it
## cannot be opened from anywhere the player is not standing.
##
## The posters are rebuilt on the way up rather than once at startup, because
## what is pinned up changes between visits - a contract taken, a board
## refreshed - and this is the moment the player is about to look at it.
func open() -> void:
	if visible:
		return

	_rebuild()
	show()
	# Deliberately unfocused, for the same reason the pause, upgrade and map
	# menus are: the accept key is bound to gameplay too, and a focused button
	# would swallow it.
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


## One sheet per contract on the board, torn down and rebuilt rather than
## patched. Five posters is cheap enough that keeping nodes and contracts in step
## is not worth the bookkeeping it would take.
func _rebuild() -> void:
	if _list == null:
		return

	# Every child, not only the posters: a bare slot is a node too, and clearing
	# just the sheets left one more empty patch on the board every time it was
	# redrawn.
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_posters.clear()

	var ledger := _get_ledger()
	if ledger != null and poster_scene != null:
		var settings := ledger.get_settings()
		var categories := settings.knowledge_categories
		# One entry per slot, and a slot with nothing dealt into it is a bare patch
		# of board rather than a poster shuffled along - so the row keeps its shape
		# and the player can see that the week was thin.
		for bounty: Bounty in ledger.get_board():
			if bounty == null:
				if show_empty_slots:
					_list.add_child(_build_empty_slot())
				continue
			var poster := poster_scene.instantiate() as WantedPoster
			if poster == null:
				continue
			_list.add_child(poster)
			poster.set_bounty(bounty, categories, bounty.get_rarity(settings))
			poster.accept_requested.connect(_on_accept_requested)
			_posters.append(poster)

	_refresh_state()


## A slot nobody pinned anything to: the shape of a poster, and the board showing
## through where one would have been.
func _build_empty_slot() -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = empty_slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if empty_slot_text.is_empty():
		return slot

	var label := Label.new()
	label.text = empty_slot_text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", empty_slot_colour)
	label.add_theme_font_size_override(&"font_size", empty_slot_font_size)
	slot.add_child(label)
	return slot


## The one place the board's own readouts are written, so the slot count, the
## hint and whether the buttons are live cannot disagree with each other.
func _refresh_state() -> void:
	var ledger := _get_ledger()
	var free := ledger != null and ledger.has_free_slot()

	if _slots != null:
		if ledger == null:
			_slots.text = slots_format % [0, 0]
		else:
			_slots.text = slots_format % [ledger.get_used_slots(), ledger.get_active_slots()]

	if _hint != null:
		if _posters.is_empty():
			_hint.text = empty_hint_text
		elif free:
			_hint.text = hint_text
		else:
			_hint.text = full_hint_text

	for poster: WantedPoster in _posters:
		if is_instance_valid(poster):
			poster.set_acceptable(free)


## The poster asked; the ledger answers. A refused request still redraws, so a
## board whose last slot was filled elsewhere goes grey rather than staying
## pressable.
func _on_accept_requested(poster: WantedPoster) -> void:
	var ledger := _get_ledger()
	if ledger == null or poster == null:
		return

	var bounty := poster.get_bounty()
	if ledger.accept(bounty):
		bounty_taken.emit(bounty)
	else:
		_refresh_state()


## Looked up lazily and re-looked-up if it goes away, the same way the rest of
## the game finds its shared nodes. A project without the autoload gets null,
## which every caller here reads as "there are no contracts".
func _get_ledger() -> BountyLedger:
	if _ledger == null or not is_instance_valid(_ledger):
		_ledger = get_node_or_null(NodePath("/root/%s" % ledger_name)) as BountyLedger
	return _ledger


func _drop_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
