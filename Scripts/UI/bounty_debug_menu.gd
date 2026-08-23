class_name BountyDebugMenu
extends Control
## The bounty knowledge readout: every contract the game is holding, what each
## one knows, and what each one is worth, behind one key.
##
## [b]This is a development tool, not the player's bounty screen.[/b] It shows
## things the player is not meant to see - the answers behind the question marks,
## and a button that hands over a piece of information for nothing - because the
## whole point of it is checking that the knowledge system does what it says:
## that revealing a line turns up the answer that was always there, that the
## count follows the lines, and above all [b]that the reward does not move[/b].
## Reveal a piece and watch the price stay where it was. The player-facing
## bounties screen is a later milestone and is not this.
##
## It reads and writes nothing of its own. Every line comes off [Bounty], every
## reveal goes through [method BountyLedger.reveal] - the same door a mini boss
## will hand its information over through - so what this panel demonstrates is
## the real system rather than a debug copy of it. If the panel is right, the
## game is right.
##
## The rows are generated from whatever the ledger is holding and from whichever
## knowledge categories [BountySettings] lists, so a fourth kind of information
## appears here with nothing in this file to change. What is authored is the
## shell it fills: the panel, the title and the scrolling body are nodes in the
## HUD scene with their own styling, exactly as [DevSettingsMenu]'s are.

## Emitted as the panel is raised and dropped.
signal opened
signal closed

## Key that opens the panel. Development only, and deliberately its own action so
## it can be unbound in one place.
@export var open_action: StringName = &"bounty_debug"
## Key that closes it again, shared with the pause menu so Escape means "back"
## wherever the player is.
@export var close_action: StringName = &"pause_menu"
## Autoload holding the contracts. Named rather than referenced so the panel
## still builds in a project where the ledger has not been registered - it simply
## reports that there is none.
@export var ledger_name: StringName = &"Bounties"
## Freezes the world while the panel is up, the same way the pause, upgrade and
## board menus do.
@export var pauses_game: bool = true

@export_group("Nodes")
## Container the generated rows are put in. A vertical box inside the scroller.
@export var rows_path: NodePath = ^"Panel/Body/Scroll/Rows"
## Line in the header reporting the totals.
@export var summary_label_path: NodePath = ^"Panel/Body/Header/Summary"

@export_group("Contents")
## Whether the posters still pinned to the board are listed as well as the
## contracts the player has taken. On, because knowledge and price are worth
## watching before a contract is accepted as well as after.
@export var show_board: bool = true
## Whether an unknown line shows the answer behind it, in brackets.
##
## [b]On is the useful setting and the reason this panel exists.[/b] Seeing that
## the region was always C, before anything revealed it, is what proves revealing
## turns a flag on rather than deciding an answer late. Off leaves the panel
## reading the way the player's screen will.
@export var show_hidden_answers: bool = true
## Whether each unknown line gets a button that reveals it. The debug stand-in
## for a mini boss giving up what it knew.
@export var show_reveal_buttons: bool = true

@export_group("Rows")
## Colour and size of a section heading.
@export var section_color := Color(0.85, 0.11, 0.11)
@export var section_font_size: int = 26
## Colour and size of a contract's own line.
@export var bounty_color := Color(0.72, 0.09, 0.1)
@export var bounty_font_size: int = 20
## Colour and size of a knowledge line.
@export var label_color := Color(0.6, 0.42, 0.4)
@export var row_font_size: int = 17
## Colour a line is written in once it is known.
@export var known_color := Color(0.86, 0.78, 0.72)
## Colour of a line that is still a question mark, so an unknown reads as unknown
## at a glance down the list.
@export var unknown_color := Color(0.5, 0.33, 0.32)
## How wide the category column is, in pixels, so the answers line up.
@export var category_width: float = 120.0
## How wide the answer column is, in pixels.
@export var value_width: float = 260.0
## Gap above a heading, so the sections read as separate blocks.
@export var section_spacing: float = 18.0
## Indent of a knowledge line under the contract it belongs to.
@export var row_indent: float = 24.0

@export_group("Buttons")
## Colour the reveal buttons are lettered in.
@export var button_font_color := Color(0.84, 0.76, 0.73)
## The look of a reveal button, so the panel's buttons are the game's buttons
## rather than default Godot ones. Dropped in from the HUD scene, where the same
## styles the other menus use already live; left empty the buttons fall back to
## the theme.
@export var button_normal_style: StyleBox
@export var button_hover_style: StyleBox
@export var button_pressed_style: StyleBox
## Padding inside a reveal button, sideways and down. The styles are shared with
## the menus the player actually uses, whose buttons are half a screen wide and
## padded to match - a list thirty rows long wants them tighter, and this is that
## without a second set of styles to keep in step.
@export var button_padding := Vector2(18.0, 2.0)

@export_group("Wording")
## How the header totals are written: posters, contracts held, contract slots.
@export var summary_format: String = "BOARD %d   TAKEN %d / %d"
@export var taken_heading: String = "TAKEN CONTRACTS"
@export var board_heading: String = "ON THE BOARD"
## How a contract's own line is written: name, knowledge, most it could know,
## reward.
@export var bounty_format: String = "%s   KNOWLEDGE %d / %d   REWARD %d BLOOD"
## Appended to a contract whose price is frozen.
@export var locked_text: String = "   [LOCKED]"
## Appended to one that has not been taken and could still be repriced.
@export var unlocked_text: String = "   [NOT YET LOCKED]"
## Appended to a contract that has been closed out.
@export var completed_text: String = "   [COMPLETED]"
## What a known line is marked with.
@export var known_text: String = "KNOWN"
## What an unknown one is marked with.
@export var unknown_text: String = "UNKNOWN"
## What the button on an unknown line reads.
@export var reveal_text: String = "REVEAL"
## What the button reads once there is nothing left to reveal on that line.
@export var revealed_text: String = "KNOWN"
## Button that fills a whole contract in at once.
@export var reveal_all_text: String = "REVEAL ALL"
## Shown when there are no contracts of that kind.
@export var empty_text: String = "NONE"
## Shown when the ledger autoload is not registered at all.
@export var no_ledger_text: String = "NO BOUNTY LEDGER IS LOADED"

@onready var _rows: Container = get_node_or_null(rows_path) as Container
@onready var _summary: Label = get_node_or_null(summary_label_path) as Label

var _ledger: BountyLedger
## Padded-down copies of the shared button styles, made once and handed to every
## button rather than duplicated per row.
var _tightened: Dictionary = {}


func _ready() -> void:
	hide()

	var ledger := _get_ledger()
	if ledger == null:
		return
	# Rebuilt on the ledger's own signals rather than on a timer, so a piece of
	# information revealed by something else while the panel is up - a debug key,
	# or one day a boss - shows up here without anything having to remember to
	# tell it.
	if not ledger.board_changed.is_connected(_on_ledger_changed):
		ledger.board_changed.connect(_on_ledger_changed)
	if not ledger.knowledge_revealed.is_connected(_on_knowledge_revealed):
		ledger.knowledge_revealed.connect(_on_knowledge_revealed)
	if not ledger.bounty_completed.is_connected(_on_bounty_changed):
		ledger.bounty_completed.connect(_on_bounty_changed)


## F3 from anywhere, Escape while it is up. The press is marked handled either
## way, so the key that closes this cannot also reach the pause menu behind it or
## the game underneath.
func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(open_action):
		return

	if event.is_action_pressed(open_action):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return

	if visible and event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Raises the panel, rebuilt from what the ledger is holding right now.
func open() -> void:
	if visible:
		return

	_rebuild()
	show()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


func close() -> void:
	if not visible:
		return

	hide()
	# Released at the viewport rather than button by button, so a row added later
	# is covered without being listed - a focused button would otherwise keep
	# eating the keys once play resumed.
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


## Throws the rows away and builds them again. Called on every open and on every
## change, because five posters times three lines is cheap enough that keeping
## rows and contracts in step is not worth the bookkeeping it would take.
func _rebuild() -> void:
	if _rows == null:
		return

	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var ledger := _get_ledger()
	if ledger == null:
		_set_summary("")
		_add_heading(no_ledger_text)
		return

	var board := ledger.get_board()
	_set_summary(summary_format % [board.size(), ledger.get_used_slots(), ledger.get_active_slots()])

	var categories := ledger.get_settings().knowledge_categories
	_add_section(taken_heading, ledger.get_active(), categories)
	if show_board:
		_add_section(board_heading, board, categories)


## One block: a heading, then every contract in it.
func _add_section(
	heading: String, bounties: Array[Bounty], categories: Array[BountyKnowledgeCategory]
) -> void:
	_add_heading(heading)

	var listed := 0
	for bounty: Bounty in bounties:
		if bounty == null:
			continue
		_add_bounty(bounty, categories)
		listed += 1

	if listed == 0:
		_add_note(empty_text)


## One contract: its own line, then one line per piece of information it could
## carry.
func _add_bounty(bounty: Bounty, categories: Array[BountyKnowledgeCategory]) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)

	var who := "NO TARGET" if bounty.target == null else bounty.target.display_name
	var text := bounty_format % [
		who,
		bounty.get_knowledge_count(),
		bounty.get_max_knowledge(),
		bounty.reward,
	]
	text += locked_text if bounty.is_reward_locked() else unlocked_text
	if bounty.completed:
		text += completed_text

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", bounty_color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_font_size_override(&"font_size", bounty_font_size)
	header.add_child(label)

	if show_reveal_buttons and not bounty.is_fully_known():
		var all_button := _build_button(reveal_all_text)
		all_button.pressed.connect(_on_reveal_all_pressed.bind(bounty))
		header.add_child(all_button)

	_rows.add_child(header)

	# Driven by the categories rather than by the bounty's own lines so the panel
	# shows a category a contract somehow has no line for as missing, instead of
	# quietly leaving it out.
	for category: BountyKnowledgeCategory in categories:
		if category != null:
			_rows.add_child(_build_fact_row(bounty, category))


## One piece of information: what kind it is, what it says, whether it is known,
## and a button to learn it.
func _build_fact_row(bounty: Bounty, category: BountyKnowledgeCategory) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(row_indent, 0.0)
	row.add_child(spacer)

	var known := bounty.is_known(category.category_id)
	var fact := bounty.get_fact(category.category_id)

	var name_label := Label.new()
	name_label.text = category.display_name
	name_label.custom_minimum_size = Vector2(category_width, 0.0)
	name_label.add_theme_color_override(&"font_color", label_color)
	name_label.add_theme_font_size_override(&"font_size", row_font_size)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = _fact_value_text(fact, category)
	value_label.custom_minimum_size = Vector2(value_width, 0.0)
	value_label.add_theme_color_override(&"font_color", known_color if known else unknown_color)
	value_label.add_theme_font_size_override(&"font_size", row_font_size)
	row.add_child(value_label)

	var state_label := Label.new()
	state_label.text = known_text if known else unknown_text
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.add_theme_color_override(&"font_color", known_color if known else unknown_color)
	state_label.add_theme_font_size_override(&"font_size", row_font_size)
	row.add_child(state_label)

	if show_reveal_buttons:
		var button := _build_button(revealed_text if known else reveal_text)
		button.disabled = known or fact == null
		button.pressed.connect(_on_reveal_pressed.bind(bounty, category.category_id))
		row.add_child(button)

	return row


## A button in the game's own dress. The styles come from the scene rather than
## from colours written in here, which is the same arrangement the rest of the
## HUD uses.
func _build_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", row_font_size)
	button.add_theme_color_override(&"font_color", button_font_color)
	button.add_theme_color_override(&"font_hover_color", button_font_color.lightened(0.2))
	button.add_theme_color_override(&"font_focus_color", button_font_color.lightened(0.2))
	var normal := _tighten(button_normal_style)
	if normal != null:
		button.add_theme_stylebox_override(&"normal", normal)
		button.add_theme_stylebox_override(&"focus", normal)
		button.add_theme_stylebox_override(&"disabled", normal)
	var hover := _tighten(button_hover_style)
	if hover != null:
		button.add_theme_stylebox_override(&"hover", hover)
	var pressed := _tighten(button_pressed_style)
	if pressed != null:
		button.add_theme_stylebox_override(&"pressed", pressed)
	return button


## A copy of [param style] padded for a list rather than for a menu, made once
## per style. [b]Copied rather than edited[/b] - the style itself belongs to the
## HUD scene and is shared with the menus the player uses, and repadding it here
## would repad those too.
func _tighten(style: StyleBox) -> StyleBox:
	if style == null:
		return null
	if _tightened.has(style):
		return _tightened[style]

	var copy := style.duplicate() as StyleBox
	copy.content_margin_left = button_padding.x
	copy.content_margin_right = button_padding.x
	copy.content_margin_top = button_padding.y
	copy.content_margin_bottom = button_padding.y
	_tightened[style] = copy
	return copy


## What the answer column reads. An unknown line shows the category's own
## question mark, with the answer behind it in brackets when the panel is set to
## give it away.
func _fact_value_text(fact: BountyFact, category: BountyKnowledgeCategory) -> String:
	if fact == null:
		return "%s  (NO LINE)" % category.unknown_text
	if fact.known or not show_hidden_answers:
		return fact.get_text(category.unknown_text)
	return fact.describe(category.unknown_text)


## Learns one piece [i]through the ledger[/i], deliberately, rather than by
## writing to the bounty here. It is the same call a later system will make, so
## pressing this button exercises the real path - signals, poster redraw and all.
func _on_reveal_pressed(bounty: Bounty, category_id: StringName) -> void:
	var ledger := _get_ledger()
	if ledger != null:
		ledger.reveal(bounty.bounty_id, category_id)


func _on_reveal_all_pressed(bounty: Bounty) -> void:
	var ledger := _get_ledger()
	if ledger != null:
		ledger.reveal_all(bounty.bounty_id)


func _on_knowledge_revealed(_bounty: Bounty, _category_id: StringName) -> void:
	_on_ledger_changed()


func _on_bounty_changed(_bounty: Bounty) -> void:
	_on_ledger_changed()


## Only redrawn while the panel is actually up. A board refreshed during play
## rebuilds nothing until somebody looks.
func _on_ledger_changed() -> void:
	if visible:
		_rebuild()


func _add_heading(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, section_spacing)
	_rows.add_child(spacer)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", section_color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_font_size_override(&"font_size", section_font_size)
	_rows.add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", label_color)
	label.add_theme_font_size_override(&"font_size", row_font_size)
	_rows.add_child(label)


func _set_summary(text: String) -> void:
	if _summary != null:
		_summary.text = text


## Looked up lazily and re-looked-up if it goes away, the same way the rest of
## the game finds its shared nodes. A project without the autoload gets null,
## which the panel reads as "there are no contracts to show".
func _get_ledger() -> BountyLedger:
	if _ledger == null or not is_instance_valid(_ledger):
		_ledger = get_node_or_null(NodePath("/root/%s" % ledger_name)) as BountyLedger
	return _ledger
