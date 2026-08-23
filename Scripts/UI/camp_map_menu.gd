class_name CampMapMenu
extends Control
## The map spread out by the fire: where the player is, where they could go, and
## which of their contracts are anywhere near.
##
## [b]The map is the map's own.[/b] The picture comes from
## [member MapDefinition.region_map_texture] and every patch on it is placed at its
## own [member MapRegion.map_position], so a second map is a texture and a handful
## of [code].tres[/code] files - nothing here names the desert, counts five regions
## or knows where any of them are.
##
## [b]Choosing somewhere does not move anybody.[/b] Pressing a patch marks it on
## [RunSessionState] as where the player intends to go, which is what turns the
## camp's leaving button from NEXT ROUND into TRAVEL - see
## [method RunSessionState.has_travel_pending]. Pressing the patch they are already
## standing in puts it back. The ride itself is the next milestone; this only ever
## writes down the intention.
##
## [b]The contracts are shown, never touched.[/b] The list down the side and the
## markers on the map are drawn from [BountyLedger]'s accepted contracts through
## the shared [BountyEntry], so what is printed is the same in the camp as under
## TAB. A marker only appears when the contract's map is the one on the table
## [i]and[/i] its region has actually been learned - an outlaw nobody has placed
## yet is on the list with a question mark and nowhere on the map, which is the
## whole point of the knowledge system.

## Emitted when the player marks somewhere on the map.
signal destination_chosen(region_id: StringName)
signal opened
signal closed

## Group the screen joins, so the camp can find it without a path across the HUD.
const GROUP := &"camp_map_menu"

## Where the current map, the current region and the destination are read and
## written - the [code]RunSession[/code] autoload.
@export var session_path: NodePath = ^"/root/RunSession"
## The contracts - the [code]Bounties[/code] autoload.
@export var ledger_path: NodePath = ^"/root/Bounties"
## Freezes the world while the screen is up, the same way every other menu does.
@export var pauses_game: bool = true
## Key that backs out to the camp.
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
## The control the map is drawn into. Everything on the map is positioned as a
## fraction of this, so the whole thing scales with the panel.
@export var map_path: NodePath = ^"Panel/Body/Split/Map"
## The picture itself, filled with the current map's texture.
@export var map_texture_path: NodePath = ^"Panel/Body/Split/Map/Picture"
## Container the contract rows are built into.
@export var bounty_list_path: NodePath = ^"Panel/Body/Split/Bounties/Scroll/Rows"
@export var title_label_path: NodePath = ^"Panel/Body/Header/Title"
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"

@export_group("Regions")
## Styleboxes a region patch wears.
@export var region_normal: StyleBox
@export var region_hover: StyleBox
@export var region_selected: StyleBox
@export var region_disabled: StyleBox
## What the patch the player is standing in wears, so where they are reads at a
## glance without them reading a letter.
@export var region_here: StyleBox
@export var region_font_size: int = 34
## How large the place's own name is drawn under its letter - see
## [method MapRegion.get_place_name]. Smaller than the letter on purpose: the
## letter is what the player picks by and the name is what it means.
@export var region_name_font_size: int = 15
@export var region_font_colour := Color(0.9, 0.84, 0.78)
## Colour the region the player is standing in is lettered in.
@export var region_here_colour := Color(1.0, 0.86, 0.42)
## Colour the region they have marked is lettered in.
@export var region_selected_colour := Color(1.0, 0.5, 0.35)
@export var region_locked_colour := Color(0.45, 0.35, 0.3)
## What is written under a region's letter while the player is standing in it.
@export var here_text: String = "YOU ARE HERE"
## What is written under the one they have marked.
@export var destination_text: String = "HEADING HERE"

@export_group("Markers")
## The picture pinned on a region an outlaw is known to be in.
@export var marker_texture: Texture2D
## How large it is drawn, in pixels.
@export var marker_size := Vector2(46.0, 46.0)
## Where it sits relative to the middle of its region, as a fraction of the region
## patch - so two contracts in the same region can be nudged apart.
@export var marker_offset := Vector2(0.0, -0.28)
## How far each further contract in the same region is stepped along, again as a
## fraction of the patch.
@export var marker_step := Vector2(0.34, 0.0)
## What the hover card says when the hour is not known.
@export var marker_unknown_time: String = "?"
@export var marker_card_font_size: int = 18
@export var marker_icon_size := Vector2(34.0, 34.0)

@export_group("Bounty list")
@export var list_title: String = "CONTRACTS"
## What the list says when the player is holding none.
@export var list_empty_text: String = "NO CONTRACTS TAKEN"
@export var entry_name_font_size: int = 22
@export var entry_line_font_size: int = 15
@export var entry_name_colour := Color(0.86, 0.78, 0.72)
@export var entry_label_colour := Color(0.5, 0.36, 0.34)
@export var entry_known_colour := Color(0.84, 0.76, 0.73)
@export var entry_unknown_colour := Color(0.45, 0.3, 0.3)

@export_group("Wording")
## The heading. The map's name is substituted in.
@export var title_format: String = "%s  -  THE COUNTRY"
@export var title_fallback: String = "THE COUNTRY"
## What the footer says while the player is staying put.
@export var status_here_format: String = "CAMPED IN REGION %s"
## What it says once somewhere else has been marked.
@export var status_heading_format: String = "MARKED FOR REGION %s  -  THE CAMP WILL OFFER THE RIDE"

@onready var _map: Control = get_node_or_null(map_path) as Control
@onready var _picture: TextureRect = get_node_or_null(map_texture_path) as TextureRect
@onready var _rows: Container = get_node_or_null(bounty_list_path) as Container
@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _status: Label = get_node_or_null(status_label_path) as Label

var _session: Node
var _ledger: BountyLedger
## The card shown while the cursor is over a marker. One card, moved and rewritten,
## rather than one per contract.
var _hover_card: PanelContainer
var _region_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_session = get_node_or_null(session_path)
	_ledger = get_node_or_null(ledger_path) as BountyLedger


## The screen the camp should open. Null means this world has none.
static func get_active(from_node: Node) -> CampMapMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as CampMapMenu


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
	_hide_card()
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


## Everything on the screen, rebuilt from the map and the ledger. Called on every
## open because where the player is, what they know and what they are holding have
## all moved since the last look.
func _build() -> void:
	_build_map()
	_build_list()
	_refresh_status()


func _current_map() -> MapDefinition:
	if _session == null or not _session.has_method(&"get_map"):
		return null
	return _session.call(&"get_map") as MapDefinition


func _here() -> StringName:
	if _session == null or not _session.has_method(&"get_region_id"):
		return &""
	return _session.call(&"get_region_id")


func _destination() -> StringName:
	if _session == null or not _session.has_method(&"get_destination_region"):
		return _here()
	return _session.call(&"get_destination_region")


## The picture, one patch per region, and a marker for every contract that has been
## placed on this map.
func _build_map() -> void:
	if _map == null:
		return

	for child: Node in _map.get_children():
		if child != _picture:
			child.queue_free()
	_region_buttons.clear()
	_hover_card = null

	var map := _current_map()
	if _title != null:
		_title.text = title_fallback if map == null else title_format % map.display_name
	if _picture != null:
		_picture.texture = null if map == null else map.region_map_texture
	if map == null:
		return

	var here := _here()
	var destination := _destination()
	for region: MapRegion in map.regions:
		if region == null:
			continue
		var patch := _build_region(region, region.region_id == here, region.region_id == destination)
		_region_buttons[region.region_id] = patch
		_map.add_child(patch)

	_build_markers(map)
	# Built last so the card is drawn over every patch and every marker.
	_hover_card = _build_hover_card()
	_map.add_child(_hover_card)


## One region: a patch of the map the player can press, anchored where the region
## itself says it belongs.
func _build_region(region: MapRegion, here: bool, chosen: bool) -> Button:
	var patch := Button.new()
	patch.focus_mode = Control.FOCUS_NONE
	patch.disabled = not region.unlocked
	patch.mouse_filter = Control.MOUSE_FILTER_STOP
	_anchor(patch, region.map_position, region.map_size)

	var box := VBoxContainer.new()
	box.name = "Text"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var letter := Label.new()
	letter.text = region.get_label()
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override(&"font_size", region_font_size)
	var colour := region_font_colour
	if not region.unlocked:
		colour = region_locked_colour
	elif here:
		colour = region_here_colour
	elif chosen:
		colour = region_selected_colour
	letter.add_theme_color_override(&"font_color", colour)
	box.add_child(letter)

	# What the place is actually called, under its letter. Read off the region's own
	# resource - see [method MapRegion.get_place_name] - so nothing here knows the
	# desert has a Broken Mesa in it, and a region with no name authored simply shows
	# its letter as it always did.
	var place := region.get_place_name()
	if not place.is_empty():
		var name_label := Label.new()
		name_label.text = place
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override(&"font_size", region_name_font_size)
		name_label.add_theme_color_override(&"font_color", colour)
		box.add_child(name_label)

	var note := ""
	if here:
		note = here_text
	elif chosen:
		note = destination_text
	if not note.is_empty():
		var caption := Label.new()
		caption.text = note
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override(&"font_size", maxi(region_font_size - 20, 10))
		caption.add_theme_color_override(&"font_color", colour)
		box.add_child(caption)

	patch.add_child(box)
	_style_patch(patch, here, chosen)

	if region.unlocked:
		patch.pressed.connect(_on_region_pressed.bind(region))
	return patch


func _style_patch(patch: Button, here: bool, chosen: bool) -> void:
	var resting := region_normal
	if here and region_here != null:
		resting = region_here
	elif chosen and region_selected != null:
		resting = region_selected
	if resting != null:
		patch.add_theme_stylebox_override(&"normal", resting)
	if region_hover != null:
		patch.add_theme_stylebox_override(&"hover", region_hover if not (here or chosen) else resting)
	if region_selected != null:
		patch.add_theme_stylebox_override(&"pressed", region_selected)
	if region_disabled != null:
		patch.add_theme_stylebox_override(&"disabled", region_disabled)


## A marker for every contract whose outlaw has been placed: on this map, and in a
## region the player has actually learned. Everything else stays off the map.
func _build_markers(map: MapDefinition) -> void:
	if _ledger == null or marker_texture == null:
		return

	var used: Dictionary[StringName, int] = {}
	for bounty: Bounty in _ledger.get_outstanding():
		if bounty == null:
			continue
		# The map line has to be known and has to be this map. A contract on the
		# forest is not drawn on the desert even once its region is known, because
		# the letter would mean somewhere else.
		if not bounty.is_known(Bounty.CATEGORY_MAP):
			continue
		if bounty.get_fact_value(Bounty.CATEGORY_MAP) != map.map_id:
			continue
		if not bounty.is_known(Bounty.CATEGORY_REGION):
			continue

		var region_id := bounty.get_fact_value(Bounty.CATEGORY_REGION)
		var region := map.find_region(region_id)
		if region == null:
			continue

		var index: int = used.get(region_id, 0)
		used[region_id] = index + 1
		_map.add_child(_build_marker(bounty, region, index))


func _build_marker(bounty: Bounty, region: MapRegion, index: int) -> Control:
	var marker := TextureRect.new()
	marker.texture = marker_texture
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	marker.custom_minimum_size = marker_size

	# Placed against its region's patch rather than against the map, so nudging a
	# region on the map takes its outlaws with it.
	var offset := marker_offset + marker_step * float(index)
	var centre := region.map_position + Vector2(
		region.map_size.x * offset.x, region.map_size.y * offset.y)
	marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	marker.anchor_left = centre.x
	marker.anchor_top = centre.y
	marker.anchor_right = centre.x
	marker.anchor_bottom = centre.y
	marker.offset_left = -marker_size.x * 0.5
	marker.offset_top = -marker_size.y * 0.5
	marker.offset_right = marker_size.x * 0.5
	marker.offset_bottom = marker_size.y * 0.5

	marker.mouse_entered.connect(_on_marker_hovered.bind(bounty, marker))
	marker.mouse_exited.connect(_hide_card)
	return marker


## The card that appears over a marker: who it is, and what hour he is known to be
## about at - or a question mark, because the hour is its own piece of knowledge
## and having found the region does not give it away.
func _build_hover_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "HoverCard"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 10

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.02, 0.02, 0.92)
	box.border_color = Color(0.42, 0.055, 0.06, 1.0)
	box.set_border_width_all(2)
	box.set_content_margin_all(8.0)
	card.add_theme_stylebox_override(&"panel", box)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 8)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = marker_icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text := Label.new()
	text.name = "Text"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override(&"font_size", marker_card_font_size)
	row.add_child(text)

	return card


func _on_marker_hovered(bounty: Bounty, marker: Control) -> void:
	if _hover_card == null or bounty == null:
		return

	var icon := _hover_card.get_node_or_null(^"Row/Icon") as TextureRect
	var text := _hover_card.get_node_or_null(^"Row/Text") as Label
	var stage := _find_stage(bounty)
	var known := bounty.is_known(Bounty.CATEGORY_TIME)

	if icon != null:
		# The hour's own picture, the same one the HUD and the round intro show -
		# and nothing at all while the hour is still a question.
		icon.texture = stage.icon if known and stage != null else null
		icon.visible = icon.texture != null

	if text != null:
		var who := "NO NAME" if bounty.target == null else bounty.target.display_name
		var when := marker_unknown_time
		if known:
			when = stage.display_name if stage != null else String(
				bounty.get_fact_value(Bounty.CATEGORY_TIME))
		text.text = "%s\n%s" % [who, when]
		if known and stage != null:
			text.add_theme_color_override(&"font_color", stage.icon_colour)
		else:
			text.add_theme_color_override(&"font_color", Color(0.6, 0.42, 0.4))

	_hover_card.visible = true
	_hover_card.reset_size()
	# Pinned just above the marker it belongs to, in the map's own space.
	_hover_card.position = marker.position + Vector2(
		marker.size.x * 0.5 - _hover_card.size.x * 0.5, -_hover_card.size.y - 6.0)


## The [DayStage] a contract's hour points at, found on the map it belongs to so
## the icon is that map's own picture of that hour.
func _find_stage(bounty: Bounty) -> DayStage:
	var map := _current_map()
	if map == null:
		return null
	return map.find_day_stage(bounty.get_fact_value(Bounty.CATEGORY_TIME))


func _hide_card() -> void:
	if _hover_card != null:
		_hover_card.visible = false


## The contracts down the side, built through the shared row so the camp and the
## TAB list cannot print a contract differently.
func _build_list() -> void:
	if _rows == null:
		return

	for child: Node in _rows.get_children():
		child.queue_free()

	if _ledger == null:
		return

	var settings := _ledger.get_settings()
	var categories := settings.knowledge_categories
	var held := _ledger.get_outstanding()
	if held.is_empty():
		var empty := Label.new()
		empty.text = list_empty_text
		empty.add_theme_color_override(&"font_color", entry_label_colour)
		empty.add_theme_font_size_override(&"font_size", entry_line_font_size)
		_rows.add_child(empty)
		return

	for bounty: Bounty in held:
		var entry := BountyEntry.new()
		entry.name_colour = entry_name_colour
		entry.label_colour = entry_label_colour
		entry.known_colour = entry_known_colour
		entry.unknown_colour = entry_unknown_colour
		entry.name_font_size = entry_name_font_size
		entry.line_font_size = entry_line_font_size
		_rows.add_child(entry)
		entry.configure(bounty, settings, categories)


## Marks somewhere. Nothing moves - see the class notes - and pressing the region
## the player is already in puts the intention back to staying put.
func _on_region_pressed(region: MapRegion) -> void:
	if _session == null or not _session.has_method(&"set_destination_region"):
		return

	_session.call(&"set_destination_region", region.region_id)
	_build_map()
	_refresh_status()
	destination_chosen.emit(region.region_id)


func _refresh_status() -> void:
	if _status == null:
		return

	var here := _here()
	var destination := _destination()
	if destination == here or destination == &"":
		_status.text = status_here_format % _label_for(here)
	else:
		_status.text = status_heading_format % _label_for(destination)


func _label_for(region_id: StringName) -> String:
	var map := _current_map()
	if map != null:
		var region := map.find_region(region_id)
		if region != null:
			return region.get_full_label()
	return String(region_id)


## Anchors [param control] over the map at a normalised position and size, so
## everything on the map moves and scales with the picture.
func _anchor(control: Control, centre: Vector2, extent: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = centre.x - extent.x * 0.5
	control.anchor_top = centre.y - extent.y * 0.5
	control.anchor_right = centre.x + extent.x * 0.5
	control.anchor_bottom = centre.y + extent.y * 0.5
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
