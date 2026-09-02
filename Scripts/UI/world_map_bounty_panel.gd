class_name WorldMapBountyPanel
extends Control
## The BOUNTIES tab of [WorldMapOverlayMenu] - the foundation rule 28 of the
## run inventory phase asks for and nothing more: proof that a bounty poster
## taken onto the run lives in the same [RunInventory] every other item does,
## and can be read back out of it here.
##
## [b]No bounty gameplay lives here.[/b] This never accepts, tracks or
## completes a contract - it only lists whatever [RunItemStack] entries
## [RunInventory] is currently holding with
## [member RunItemStack.category] equal to [code]"bounty_poster"[/code],
## reading each one's [member RunItemStack.payload] back as the real [Bounty]
## it was added from - see [method RunInventory.add_bounty_poster] - so
## nothing here duplicates a name or a reward independently of the contract
## itself.

@export var inventory_group: StringName = &"run_inventory"
@export var poster_category: StringName = &"bounty_poster"
@export_group("Wording")
@export var title_text: String = "BOUNTY POSTERS"
@export var empty_text: String = "NO BOUNTY POSTERS CARRIED"
@export var reward_format: String = "%d BLOOD"
## How the second line reads: the region, then the status. Rule 23 of the
## bounty camps phase asks this panel for "at minimum: bounty name, region,
## status, reward" - the name and reward were already here; this line is the
## other two.
@export var detail_format: String = "REGION %s   %s"
## What an unrevealed region line prints - the same question mark
## [BountyEntry] and every wanted poster already print for a line the player
## has not learned yet.
@export var region_unknown_text: String = "?"
@export var active_status_text: String = "ACTIVE"
@export var completed_status_text: String = "COMPLETED"

var _inventory: RunInventory
var _rows: VBoxContainer


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
	_rebuild()


func refresh() -> void:
	_rebuild()


func _build_frame() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override(&"font_size", 26)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_rows)


func _rebuild() -> void:
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		child.queue_free()

	if _inventory == null:
		return

	var posters: Array[RunItemStack] = []
	for stack: RunItemStack in _inventory.get_slots():
		if stack != null and stack.category == poster_category:
			posters.append(stack)

	if posters.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.add_theme_color_override(&"font_color", Color(0.5, 0.36, 0.34))
		_rows.add_child(empty)
		return

	for stack: RunItemStack in posters:
		_rows.add_child(_build_row(stack))


func _build_row(stack: RunItemStack) -> Control:
	var row := PanelContainer.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 2)
	row.add_child(body)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override(&"separation", 12)
	body.add_child(heading)

	var bounty := stack.payload as Bounty

	var name_label := Label.new()
	name_label.text = stack.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)

	var reward_label := Label.new()
	reward_label.text = reward_format % (0 if bounty == null else bounty.reward)
	heading.add_child(reward_label)

	var detail_label := Label.new()
	detail_label.text = _describe(bounty)
	detail_label.add_theme_color_override(&"font_color", Color(0.5, 0.36, 0.34))
	body.add_child(detail_label)

	return row


## The region and status line for [param bounty] - rule 23's other two
## fields, read straight off the bounty itself rather than a second source.
## See [method Bounty.get_fact_text], which already returns the unrevealed
## question mark for a region line the player has not learned.
func _describe(bounty: Bounty) -> String:
	if bounty == null:
		return ""
	var region := bounty.get_fact_text(Bounty.CATEGORY_REGION, region_unknown_text)
	var status := completed_status_text if bounty.completed else active_status_text
	return detail_format % [region, status]


func _on_inventory_changed() -> void:
	_rebuild()
