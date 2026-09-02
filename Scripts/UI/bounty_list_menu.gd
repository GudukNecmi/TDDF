class_name BountyListMenu
extends Control
## The contracts the player is carrying, on a key, wherever they are standing.
##
## TAB anywhere - in the arena, in the base, on the way to the camp - and this is
## what comes up: the same contracts the camp shows, printed by the same
## [BountyEntry], so what a bounty says never depends on which screen is asking.
## Nothing on it can be spent and nothing revealed; the one thing the player can do
## here is give a contract up.
##
## [b]Giving one up does not put a poster back.[/b] The slot the contract came off
## was emptied when it was taken and is only ever dealt into again on the next ride
## home - see [method BountyLedger.cancel] and [method BountyLedger.refill_board].
## That is deliberate: dropping a contract is losing it, not exchanging it.
##
## It deliberately does not pause the world. Reading what you are carrying is a
## glance at your own pocket, not a decision, and the run's clock is not stopped
## for it - unlike the camp, which is a place the player has stopped at.

## Emitted as the list is raised and dropped.
signal opened
signal closed
## Emitted when a contract is actually given up.
signal bounty_cancelled(bounty: Bounty)

## Group the list joins, so anything can raise it without a path.
const GROUP := &"bounty_list_menu"

## Key that opens and closes it.
@export var open_action: StringName = &"bounty_list"
## Key that closes it while it is up, shared with the pause menu so Escape means
## "back" wherever the player is.
@export var close_action: StringName = &"pause_menu"
## The contracts - the [code]Bounties[/code] autoload.
@export var ledger_path: NodePath = ^"/root/Bounties"
## The World Map's own [WorldZone]. TAB opens [WorldMapOverlayMenu] there
## instead - a multi-panel screen with its own BOUNTIES tab reading the same
## [BountyLedger] through the run inventory's posters - so this same key is
## suppressed rather than fighting it for the press. Everywhere else in the
## game - the arena, the base, the road - TAB still opens this exactly as it
## always has.
@export var suppressed_zone_id: StringName = &"world_map"
## Whether the world is frozen while it is up. [b]Off[/b] - see the class notes.
@export var pauses_game: bool = false

@export_group("Nodes")
## The grid the ordinary contracts are built into - two across, so four fill it as
## two over two.
@export var rows_path: NodePath = ^"Panel/Body/Split/Rows"
## The tall slot down the right, which one contract has to itself - see
## [member feature_max_starting_knowledge].
@export var feature_path: NodePath = ^"Panel/Body/Split/Feature"
@export var title_label_path: NodePath = ^"Panel/Body/Header/Title"
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"

@export_group("Layout")
## How many contracts the grid holds before the rest go to the tall slot. Four is
## two rows of the grid's two columns.
@export var grid_capacity: int = 4
## A contract whose rung starts the player off knowing this much or less is the one
## given the tall slot down the right.
##
## [b]Zero, which is the legendary rung[/b] - the contract you are told nothing
## about is the one worth the most room. It is written as a number rather than as a
## rarity's name so that nothing here knows what the rungs are called; a rarity is
## a [code].tres[/code] file and this keeps working when a fifth one is added. See
## [member BountyRarity.knowledge_count].
@export var feature_max_starting_knowledge: int = 0

@export_group("Rows")
@export var entry_name_font_size: int = 24
@export var entry_line_font_size: int = 16
@export var entry_name_colour := Color(0.16, 0.06, 0.05)
@export var entry_label_colour := Color(0.5, 0.36, 0.34)
@export var entry_known_colour := Color(0.2, 0.08, 0.06)
@export var entry_unknown_colour := Color(0.42, 0.3, 0.24)
## Whether each row offers a button to give the contract up.
@export var allow_cancel: bool = true
@export var cancel_text: String = "GIVE UP"
## Styleboxes the give-up buttons wear, so they are the game's buttons.
@export var button_normal: StyleBox
@export var button_hover: StyleBox
@export var button_pressed: StyleBox

@export_group("Wording")
## How the heading is written: how many contracts are held, and how many may be.
@export var title_format: String = "CONTRACTS  %d / %d"
## What is shown when none are held.
@export var empty_text: String = "NO CONTRACTS TAKEN"
## What the footer says.
@export var status_text: String = "GIVING A CONTRACT UP DOES NOT PUT THE POSTER BACK"

@onready var _rows: Container = get_node_or_null(rows_path) as Container
@onready var _feature: Container = get_node_or_null(feature_path) as Container
@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _status: Label = get_node_or_null(status_label_path) as Label

var _ledger: BountyLedger


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_ledger = get_node_or_null(ledger_path) as BountyLedger
	if _ledger != null:
		# Rebuilt on the ledger's own signals, so a contract taken at the board or a
		# line revealed by something else shows here without anything being told.
		_ledger.board_changed.connect(_on_ledger_changed)
		_ledger.knowledge_revealed.connect(_on_knowledge_revealed)


## The list anything should raise. Null means this world has none.
static func get_active(from_node: Node) -> BountyListMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BountyListMenu


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return

	_build()
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


## TAB from anywhere, Escape while it is up. The press is marked handled either
## way, so the key cannot also reach whatever is standing behind the list.
func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(open_action):
		return
	if not visible and _on_suppressed_zone():
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


## Every contract on one screen: the ordinary ones two across in the grid, and the
## one worth the most room down the right.
##
## [b]Nothing is scrolled and nothing is left off.[/b] The grid takes
## [member grid_capacity] and the tall slot takes one, which is exactly the
## contracts the ledger will let the player hold - see
## [method BountyLedger.get_active_slots].
func _build() -> void:
	if _rows == null:
		return

	for child: Node in _rows.get_children():
		child.queue_free()
	if _feature != null:
		for child: Node in _feature.get_children():
			child.queue_free()

	if _status != null:
		_status.text = status_text
	if _ledger == null:
		return

	var held := _ledger.get_outstanding()
	if _title != null:
		_title.text = title_format % [_ledger.get_used_slots(), _ledger.get_active_slots()]

	if held.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.add_theme_color_override(&"font_color", entry_label_colour)
		empty.add_theme_font_size_override(&"font_size", entry_line_font_size)
		_rows.add_child(empty)
		return

	var settings := _ledger.get_settings()
	var categories := settings.knowledge_categories

	var featured := _pick_featured(held, settings)
	if _feature != null:
		_feature.visible = featured != null
		if featured != null:
			_feature.add_child(_build_entry(featured, settings, categories))

	for bounty: Bounty in held:
		if bounty == featured:
			continue
		_rows.add_child(_build_entry(bounty, settings, categories))


## Which contract gets the tall slot.
##
## The one the player has been told least about - the legendary rung, whose
## [member BountyRarity.knowledge_count] starts at zero. [b]Only ever one[/b]: a
## second legendary takes an ordinary slot in the grid, which is what keeps the
## shape of the screen the same however the rolls come out.
##
## With no such contract held, the slot goes to whatever the grid cannot fit, so
## five ordinary contracts still all appear rather than one being dropped. Null
## means the grid holds everything and the right-hand slot is taken off the screen.
func _pick_featured(held: Array[Bounty], settings: BountySettings) -> Bounty:
	for bounty: Bounty in held:
		var rarity := bounty.get_rarity(settings)
		if rarity != null and rarity.knowledge_count <= feature_max_starting_knowledge:
			return bounty

	# Nothing rare enough to earn the room, so it is only used if it is needed.
	if held.size() > maxi(grid_capacity, 0):
		return held[held.size() - 1]
	return null


## One card, through the shared [BountyEntry] so a contract reads the same here as
## it does beside the camp's map. Told to fill whatever cell it lands in, which is
## what lets the same card be a quarter of the grid or the whole right-hand column.
func _build_entry(
	bounty: Bounty,
	settings: BountySettings,
	categories: Array[BountyKnowledgeCategory]
) -> BountyEntry:
	var entry := BountyEntry.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entry.name_colour = entry_name_colour
	entry.label_colour = entry_label_colour
	entry.known_colour = entry_known_colour
	entry.unknown_colour = entry_unknown_colour
	entry.name_font_size = entry_name_font_size
	entry.line_font_size = entry_line_font_size
	entry.show_cancel = allow_cancel
	entry.cancel_text = cancel_text
	entry.button_normal = button_normal
	entry.button_hover = button_hover
	entry.button_pressed = button_pressed
	entry.cancel_requested.connect(_on_cancel_requested)
	entry.configure(bounty, settings, categories)
	return entry


## The row asks; the ledger decides. It is the thing that knows what the player is
## holding, and it is where the rule about the empty slot lives.
func _on_cancel_requested(bounty: Bounty) -> void:
	if _ledger == null or bounty == null:
		return
	if _ledger.cancel(bounty.bounty_id):
		bounty_cancelled.emit(bounty)
	_build()


func _on_ledger_changed() -> void:
	if visible:
		_build()


func _on_knowledge_revealed(_bounty: Bounty, _category_id: StringName) -> void:
	_on_ledger_changed()


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


## Whether the player is standing in [member suppressed_zone_id] right now -
## the World Map, where [WorldMapOverlayMenu] answers TAB instead. Asked
## fresh each press rather than cached, the same way every other zone check in
## the project is.
func _on_suppressed_zone() -> bool:
	if suppressed_zone_id == &"":
		return false
	var zone := WorldZone.get_by_id(self, suppressed_zone_id)
	return zone != null and zone.is_player_inside()
