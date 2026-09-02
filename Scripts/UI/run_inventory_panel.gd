class_name RunInventoryPanel
extends Control
## The INVENTORY tab of [WorldMapOverlayMenu]: the row of slots rule 23 of the
## run inventory phase asks for - occupied, empty, selected and stack quantity
## all readable at a glance - plus the one action rule 33 asks this phase to
## ship: select a slot, discard what is in it.
##
## Builds itself entirely from code, the same way [HeartBar] and
## [CampWeaponMenu] build their own rows, so the scene only has to carry one
## bare [Control] with this attached rather than a hand-authored grid of
## button nodes. Rebuilt on [signal RunInventory.inventory_changed] and
## [signal RunInventory.slots_changed] rather than polled, per rule 35 of the
## phase - a slot count moving from 6 to 7 draws a seventh button with nothing
## else changing.
##
## [b]Reads [RunInventory] directly and owns no state of its own beyond which
## slot is selected.[/b] There is no second count kept here to disagree with
## the real one.

## Emitted as a slot is discarded, with what was in it - for a status line, or
## a future confirmation sound.
signal item_discarded(item_id: StringName, amount: int)

@export var inventory_group: StringName = &"run_inventory"
@export_group("Layout")
@export var columns: int = 3
@export var slot_size := Vector2(150.0, 84.0)
@export var slot_gap: float = 10.0
@export_group("Wording")
@export var title_format: String = "INVENTORY  %d / %d"
@export var empty_slot_text: String = "-"
@export var discard_text: String = "DISCARD"
@export var full_status_text: String = "INVENTORY FULL"
@export var idle_status_text: String = "SELECT A SLOT TO DISCARD IT"

var _inventory: RunInventory
var _title: Label
var _grid: GridContainer
var _status: Label
var _discard_button: Button
var _slot_buttons: Array[Button] = []
var _selected_index: int = -1
var _status_reset: SceneTreeTimer


func _ready() -> void:
	_build_frame()
	_bind_inventory()


func _process(_delta: float) -> void:
	if _inventory == null or not is_instance_valid(_inventory):
		_bind_inventory()


func _bind_inventory() -> void:
	_inventory = get_tree().get_first_node_in_group(inventory_group) as RunInventory
	if _inventory == null:
		return
	if not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)
		_inventory.slots_changed.connect(_on_slots_changed)
		_inventory.pickup_rejected.connect(_on_pickup_rejected)
	_rebuild()


## Called by [WorldMapOverlayMenu] each time the tab is switched to, so the
## row is never stale by the time it is looked at.
func refresh() -> void:
	_rebuild()


func _build_frame() -> void:
	var root := VBoxContainer.new()
	root.name = "Layout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)

	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override(&"font_size", 26)
	root.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = maxi(columns, 1)
	_grid.add_theme_constant_override(&"h_separation", int(slot_gap))
	_grid.add_theme_constant_override(&"v_separation", int(slot_gap))
	scroll.add_child(_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 16)
	root.add_child(footer)

	_discard_button = Button.new()
	_discard_button.text = discard_text
	_discard_button.focus_mode = Control.FOCUS_NONE
	_discard_button.disabled = true
	_discard_button.pressed.connect(_discard_selected)
	footer.add_child(_discard_button)

	_status = Label.new()
	_status.text = idle_status_text
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)


func _rebuild() -> void:
	if _grid == null:
		return

	for child: Node in _grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	if _inventory == null:
		_title.text = title_format % [0, 0]
		return

	var slots := _inventory.get_slots()
	if _selected_index >= slots.size():
		_selected_index = -1

	_title.text = title_format % [_inventory.get_used_slots(), _inventory.get_max_slots()]

	for i in slots.size():
		var button := _build_slot_button(i, slots[i])
		_grid.add_child(button)
		_slot_buttons.append(button)

	_refresh_discard()


func _build_slot_button(index: int, stack: RunItemStack) -> Button:
	var button := Button.new()
	button.custom_minimum_size = slot_size
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_pressed = index == _selected_index
	button.clip_text = true
	button.text = stack.describe() if stack != null else empty_slot_text
	button.disabled = stack == null
	button.pressed.connect(_on_slot_pressed.bind(index))
	return button


func _on_slot_pressed(index: int) -> void:
	_selected_index = -1 if _selected_index == index else index
	for i in _slot_buttons.size():
		_slot_buttons[i].button_pressed = i == _selected_index
	_refresh_discard()


func _refresh_discard() -> void:
	if _discard_button == null:
		return
	var stack := _inventory.get_slot(_selected_index) if _inventory != null else null
	_discard_button.disabled = stack == null
	if not _has_temporary_status():
		_status.text = idle_status_text


## Discards the selected slot and drops it back onto the World Map at the
## player's own position - see [method WorldMapItemPickup.spawn_for_stack],
## the smallest clean drop seam rule 33 asks this phase to build rather than a
## second inventory system.
func _discard_selected() -> void:
	if _inventory == null or _selected_index < 0:
		return

	var removed := _inventory.remove_slot(_selected_index)
	_selected_index = -1
	if removed == null:
		return

	item_discarded.emit(removed.item_id, removed.count)
	_drop_on_world_map(removed)
	_rebuild()


func _drop_on_world_map(stack: RunItemStack) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var parent := get_tree().get_first_node_in_group(&"world_map_state") as Node
	if player == null:
		return
	var container: Node = parent.get_parent() if parent != null else null
	if container == null:
		container = get_tree().current_scene
	WorldMapItemPickup.spawn_for_stack(stack, container, player.global_position)


func _on_inventory_changed() -> void:
	_rebuild()


func _on_slots_changed(_max_slots: int) -> void:
	_rebuild()


func _on_pickup_rejected(_item_id: StringName) -> void:
	_flash_status(full_status_text)


func _flash_status(text: String) -> void:
	if _status == null:
		return
	_status.text = text
	_status_reset = get_tree().create_timer(1.2, true, false, true)
	_status_reset.timeout.connect(_clear_flash)


func _has_temporary_status() -> bool:
	return _status_reset != null and _status_reset.time_left > 0.0


func _clear_flash() -> void:
	if _status != null and not _has_temporary_status():
		_status.text = idle_status_text
