class_name WorldMapOverlayMenu
extends Control
## TAB on the World Map: the multi-panel information screen rule 24 of the run
## inventory phase asks for - INVENTORY, BOUNTIES and MAP, switched between
## inside one shared frame rather than three unrelated full-screen systems.
##
## [b]World Map-only, and it says so through the same gate every other World
## Map HUD piece uses.[/b] Reusing the project's existing [code]bounty_list[/code]
## action - already bound to TAB - rather than adding a second key, per rule
## 34 of the phase ("prefer existing input actions... do not change the
## global input map unless absolutely necessary"). Elsewhere in the game TAB
## still opens [BountyListMenu] exactly as it always has - see that class's
## own new guard - so nothing about TAB changes anywhere but here.
##
## [b]M opens straight to the MAP tab - and is genuinely new, since nothing in
## the project used M before.[/b] It is gated to the World Map the identical
## way, so it is simply inert everywhere else rather than needing to be
## guarded by every other screen that might otherwise catch a stray M.
##
## [b]Pausing is deliberate here[/b], unlike [BountyListMenu]'s own "a glance
## at your own pocket, not a decision" - this is a screen the player stops to
## use, the same as every other menu in the game, and pausing is what stops
## the horse (rule 25's "pause/stop World Map movement") for free: physics
## simply does not run while the tree is paused, so nothing here has to know
## about sprinting or stamina to freeze it.
##
## [b]Suppressed the identical way while [HorseCartScreen] is open.[/b] Rule
## 11 of the World Map -> Combat integration pass asks that the World Map's
## own TAB/M never raise a duplicate screen over the post-combat supply
## screen; [HorseCartScreen] already swallows both presses itself while it is
## up, and [method _horse_cart_open] is the same guard kept here too, so
## nothing about the order the two are added to the tree can let one slip
## through underneath the other.

signal opened
signal closed

## Group this joins, so a debug script can find it without a path.
const GROUP := &"world_map_overlay_menu"

## TAB - opens and closes the whole panel, wherever it was left.
@export var open_action: StringName = &"bounty_list"
## M - opens straight to the MAP tab, or closes the panel if the MAP tab was
## already the one showing.
@export var map_action: StringName = &"open_world_map"
@export var close_action: StringName = &"pause_menu"
## The World Map's own [WorldZone] - the gate every other World Map HUD piece
## already uses.
@export var zone_id: StringName = &"world_map"
@export var pauses_game: bool = true

@export_group("Wording")
@export var inventory_tab_text: String = "INVENTORY"
@export var bounties_tab_text: String = "BOUNTIES"
@export var map_tab_text: String = "MAP"

enum Tab { INVENTORY, BOUNTIES, MAP }

var _tab_buttons: Dictionary[Tab, Button] = {}
var _panels: Dictionary[Tab, Control] = {}
var _current_tab: Tab = Tab.INVENTORY

var _inventory_panel: RunInventoryPanel
var _bounty_panel: WorldMapBountyPanel
var _map_panel: WorldMapMapPanel


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_build()


static func get_active(from_node: Node) -> WorldMapOverlayMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapOverlayMenu


func is_open() -> bool:
	return visible


func open(tab: Tab = Tab.INVENTORY) -> void:
	_show_tab(tab)
	if visible:
		return

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


func _process(_delta: float) -> void:
	# Left standing open across a teleport away from the World Map would leave
	# the player stuck looking at a screen about a place they are no longer
	# on - the same reason [WorldMapMinimap] and every [code]Scripts/Dev[/code]
	# readout re-check this every frame rather than once.
	if not visible:
		return
	var zone := WorldZone.get_by_id(self, zone_id)
	if zone == null or not zone.is_player_inside():
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not _on_world_map():
		return
	if _horse_cart_open():
		return

	if InputMap.has_action(open_action) and event.is_action_pressed(open_action):
		if visible:
			close()
		else:
			open(Tab.INVENTORY)
		get_viewport().set_input_as_handled()
		return

	if InputMap.has_action(map_action) and event.is_action_pressed(map_action):
		if visible and _current_tab == Tab.MAP:
			close()
		else:
			open(Tab.MAP)
		get_viewport().set_input_as_handled()
		return

	if visible and event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


func _on_world_map() -> bool:
	var zone := WorldZone.get_by_id(self, zone_id)
	return zone != null and zone.is_player_inside()


func _horse_cart_open() -> bool:
	var screen := HorseCartScreen.get_active(self)
	return screen != null and screen.is_open()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 120
	root.offset_top = 60
	root.offset_right = -120
	root.offset_bottom = -60
	root.add_theme_constant_override(&"separation", 12)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.02, 0.02, 0.86)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	move_child(backdrop, 0)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	root.add_child(tabs)

	_tab_buttons[Tab.INVENTORY] = _build_tab_button(tabs, inventory_tab_text, Tab.INVENTORY)
	_tab_buttons[Tab.BOUNTIES] = _build_tab_button(tabs, bounties_tab_text, Tab.BOUNTIES)
	_tab_buttons[Tab.MAP] = _build_tab_button(tabs, map_tab_text, Tab.MAP)

	var content := PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	_inventory_panel = RunInventoryPanel.new()
	content.add_child(_inventory_panel)
	_panels[Tab.INVENTORY] = _inventory_panel

	_bounty_panel = WorldMapBountyPanel.new()
	content.add_child(_bounty_panel)
	_panels[Tab.BOUNTIES] = _bounty_panel

	_map_panel = WorldMapMapPanel.new()
	content.add_child(_map_panel)
	_panels[Tab.MAP] = _map_panel

	_show_tab(Tab.INVENTORY)


func _build_tab_button(parent: Container, text: String, tab: Tab) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(180.0, 44.0)
	button.pressed.connect(_show_tab.bind(tab))
	parent.add_child(button)
	return button


func _show_tab(tab: Tab) -> void:
	_current_tab = tab
	for key: Tab in _panels:
		_panels[key].visible = key == tab
	for key: Tab in _tab_buttons:
		_tab_buttons[key].button_pressed = key == tab

	# Refreshed on the way in rather than kept live in the background, so a
	# tab nobody is looking at costs nothing to update - rule 35 of the phase.
	match tab:
		Tab.INVENTORY:
			if _inventory_panel != null:
				_inventory_panel.refresh()
		Tab.BOUNTIES:
			if _bounty_panel != null:
				_bounty_panel.refresh()
		Tab.MAP:
			if _map_panel != null:
				_map_panel.refresh()


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
