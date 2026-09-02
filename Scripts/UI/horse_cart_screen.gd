class_name HorseCartScreen
extends Control
## The Horse Cart / Post-Combat Supply screen: what a won World Map fight
## opens onto automatically, so whatever the fight cost and whatever it
## dropped can both be sorted out before the player rides on. See rule 3 of
## the World Map -> Combat integration pass.
##
## [b]Two sides, two different rows.[/b] The left column is the Horse
## Inventory itself - every occupied [RunInventory] slot, in slot order,
## exactly as the run is actually carrying it. The right column is
## [WorldMapCombatBridge.get_combat_loot] - what the fight that just ended
## handed over and nobody has claimed yet. The two are read from, never
## copied into a shape of their own: see [method _refresh_inventory] and
## [method _refresh_loot].
##
## [b]It owns no supply system of its own.[/b] On the left, an ammo click
## tops the equipped round's [AmmoReserve] up exactly the way [AmmoCrate]
## already does - see [method _use_ammo_stack] - and a Heart click calls
## [method Health.heal] with its own default of exactly one heart - see
## [method _use_heart_stack]. [RunInventory] is only ever asked to give up
## what was actually spent, through [method RunInventory.remove_item], so a
## click that could not be used - the reserve already full, the health pool
## already full - leaves the stack exactly as it was and the inventory
## untouched. Every other occupied slot - a weapon, a bounty poster, a
## treasure map, ordinary loot - is shown rather than spent; there is nothing
## yet for clicking one to do.
##
## [b]On the right, a click is a transfer, never a spend.[/b]
## [method _on_loot_stack_pressed] asks [method RunInventory.add_item] for
## room and only ever takes off [CombatLoot] however much of the stack
## actually found it - see [method CombatLoot.remove_from_stack]. A stack the
## Horse Inventory has no room for is never touched: it is left standing in
## the loot column exactly as it was, to be claimed the moment there is room,
## rather than destroyed for having arrived at a full row.
##
## [b]Boss Information is the one loot stack that never transfers.[/b] It is
## not a physical item the Horse Inventory has a slot for - see
## [method CombatLoot.add_boss_info] - so [method _on_boss_info_stack_pressed]
## hands it straight to [BountyLedger] the same way [SurrenderKnowledge]
## already does and removes it from [CombatLoot] on the spot, never touching
## [RunInventory] at all. A click that finds nothing left to learn - every
## outstanding contract already fully known - is refused the same way a full
## reserve or a full health pool already refuses an ammo or a Heart click.
##
## [b]Opens itself; nothing else has to remember to.[/b] It listens for
## [signal WorldMapCombatBridge.encounter_ended] and
## [signal WorldMapCombatBridge.boss_encounter_ended] and raises itself only
## on [param victory] true - a death is the existing death flow's ending to
## play, per rule 13, and this screen never appears for one. Both signals are
## themselves held back by [WorldMapCombatBridge] until the mandatory
## [KillCam] beat the final kill opened has finished playing - see
## [method WorldMapCombatBridge._on_combat_cleared] - so this screen is never
## the thing racing that camera moment for the player's attention.
##
## [b]Pausing is the same borrowed trick [TraderMenu] and [WorldMapOverlayMenu]
## already use.[/b] [member Node.process_mode] on [code]RunHUD[/code], this
## node's parent, is already [constant Node.PROCESS_MODE_ALWAYS], so this
## Control keeps taking input and redrawing while [member SceneTree.paused]
## stops [WorldBandit], [WorldTimeManager], the player and the horse for
## free - none of them do anything to stay paused, the same default every
## other menu in the project already rides on.
##
## [b]No manual shortcut opens this.[/b] Rule 10 asks that it never be opened
## by hand while a [WorldBandit] is chasing the player; the simplest way to
## keep that promise is to give it no hand-operated door at all - the only way
## in is a fight actually being won. [method _unhandled_input] only ever
## closes it and swallows the World Map's own TAB/M presses while it is open,
## per rule 11, so [WorldMapOverlayMenu] cannot raise a duplicate screen
## underneath it.
##
## [b]The Horse Inventory is a fixed 3x3 grid, never a scrolling list.[/b]
## [constant HORSE_GRID_SLOTS] cells are always built - see
## [method _refresh_inventory] - one per position in [constant HORSE_GRID_COLUMNS]
## x [constant HORSE_GRID_ROWS], whether or not [RunInventory] actually has a
## slot there: a slot within [method RunInventory.get_max_slots] but holding
## nothing draws as an empty cell, and a grid position beyond the inventory's
## own capacity draws as a dimmer, inert one - see
## [method _build_empty_inventory_slot]. Capacity itself is never touched by
## any of this: a run still carrying [RunInventory]'s authored six slots shows
## six live cells and three empty ones, never nine real slots. The Combat Loot
## column beside it is untouched - a fight can hand over more than nine stacks
## in a single win, so it keeps [method _build_column]'s own scrolling column.

signal opened
signal closed

## Group this joins, so [WorldMapOverlayMenu] can check whether it is open
## without a path across the scene.
const GROUP := &"horse_cart_screen"
## The Horse Inventory's own fixed grid shape - see the class doc. Never the
## Combat Loot column's own [member columns]/[member slot_size], which stay
## free to scroll past nine.
const HORSE_GRID_COLUMNS := 3
const HORSE_GRID_ROWS := 3
const HORSE_GRID_SLOTS := HORSE_GRID_COLUMNS * HORSE_GRID_ROWS

@export var close_action: StringName = &"pause_menu"
## World Map shortcuts swallowed rather than acted on while this is open, so
## TAB and M cannot raise [WorldMapOverlayMenu] underneath it - rule 11 of the
## integration pass.
@export var suppressed_actions: Array[StringName] = [&"bounty_list", &"open_world_map"]
@export var inventory_group: StringName = &"run_inventory"
@export var player_group: StringName = &"player"
@export var locker_path: NodePath = ^"/root/Ammo"
## The contract ledger a Boss Information stack is claimed through - see
## [method _on_boss_info_stack_pressed]. The same door [SurrenderKnowledge]
## already talks to a beaten man's knowledge through, so a lead handed over by
## a Combat Loot stack and one handed over by a man who gave up read as the
## identical kind of event to anything watching [BountyLedger].
@export var bounty_ledger_path: NodePath = ^"/root/Bounties"
@export var pauses_game: bool = true

@export_group("Layout")
@export var columns: int = 3
@export var slot_size := Vector2(200.0, 64.0)
@export var slot_gap: float = 10.0
## The Horse Inventory's own, smaller cell size - "slots do not need to be
## large" for a grid that is always exactly [constant HORSE_GRID_SLOTS] cells
## regardless of how much is actually carried. The Combat Loot column keeps
## [member slot_size] for its own, still-variable-length rows.
@export var inventory_slot_size := Vector2(132.0, 54.0)

@export_group("Wording")
@export var title_text: String = "HORSE CART"
@export var status_text: String = "CLICK A STACK TO SPEND IT BEFORE YOU RIDE ON"
@export var empty_text: String = "NOTHING TO RESUPPLY WITH"
@export var depart_text: String = "DEPART"
@export var full_ammo_suffix: String = "  —  FULL"
@export var full_heart_text: String = "HEART  —  AT FULL HEALTH"
@export var inventory_title_text: String = "HORSE INVENTORY"
@export var loot_title_text: String = "COMBAT LOOT"
@export var loot_empty_text: String = "NOTHING TAKEN FROM THE FIGHT"

var _inventory: RunInventory
var _locker: AmmoLocker
var _bridge: WorldMapCombatBridge
## What the fight this cart opened for handed over - see
## [method WorldMapCombatBridge.get_combat_loot]. Re-read every [method open],
## since a fresh fight means a fresh [CombatLoot].
var _loot: CombatLoot
var _title: Label
var _inventory_grid: GridContainer
var _loot_grid: GridContainer
var _status: Label


func _ready() -> void:
	add_to_group(GROUP)
	_locker = get_node_or_null(locker_path) as AmmoLocker
	_build()
	hide()
	_bind_bridge()


static func get_active(from_node: Node) -> HorseCartScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as HorseCartScreen


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_bind_inventory()
	_bind_loot()
	_refresh()
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
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()


## Swallows the World Map's TAB/M while this is open, so
## [WorldMapOverlayMenu] cannot also raise itself underneath it, and closes on
## the project's own back key - the same "Escape means back wherever the
## player is" every other menu already follows.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()
		return

	for action: StringName in suppressed_actions:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			return


func _bind_bridge() -> void:
	_bridge = WorldMapCombatBridge.get_active(self)
	if _bridge == null:
		return
	if not _bridge.encounter_ended.is_connected(_on_encounter_ended):
		_bridge.encounter_ended.connect(_on_encounter_ended)
	if not _bridge.boss_encounter_ended.is_connected(_on_encounter_ended):
		_bridge.boss_encounter_ended.connect(_on_encounter_ended)


## A death is not this screen's ending to play - see the class doc - so only
## a win raises it.
func _on_encounter_ended(victory: bool) -> void:
	if victory:
		open()


func _bind_inventory() -> void:
	_inventory = RunInventory.get_active(self)
	if _inventory != null and not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)


## The loot the fight that opened this cart handed over. Asked of the bridge
## rather than cached, since a fresh fight hands this a fresh [CombatLoot] -
## see [method WorldMapCombatBridge.get_combat_loot].
func _bind_loot() -> void:
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()
	_loot = null if _bridge == null else _bridge.get_combat_loot()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.02, 0.02, 0.86)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -460
	root.offset_top = -240
	root.offset_right = 460
	root.offset_bottom = 240
	root.add_theme_constant_override(&"separation", 12)
	add_child(root)

	_title = Label.new()
	_title.text = title_text
	_title.add_theme_font_size_override(&"font_size", 28)
	root.add_child(_title)

	var columns_box := HBoxContainer.new()
	columns_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_box.add_theme_constant_override(&"separation", 28)
	root.add_child(columns_box)

	_inventory_grid = _build_inventory_grid_column(columns_box, inventory_title_text)
	_loot_grid = _build_column(columns_box, loot_title_text)

	_status = Label.new()
	_status.text = status_text
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var depart := Button.new()
	depart.text = depart_text
	depart.focus_mode = Control.FOCUS_NONE
	depart.pressed.connect(close)
	root.add_child(depart)


## One side of the cart: a heading over a scrolling grid, built identically for
## the Horse Inventory and the Combat Loot columns so the two read as one
## screen rather than two different ones bolted together. Returns the grid, so
## the caller can keep filling it.
func _build_column(parent: Control, heading: String) -> GridContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 6)
	parent.add_child(column)

	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override(&"font_size", 18)
	column.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 260.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = maxi(columns, 1)
	grid.add_theme_constant_override(&"h_separation", int(slot_gap))
	grid.add_theme_constant_override(&"v_separation", int(slot_gap))
	scroll.add_child(grid)
	return grid


## The Horse Inventory's own column - a heading over a grid that is always
## exactly [constant HORSE_GRID_SLOTS] cells and never wrapped in a
## [ScrollContainer], per the class doc's "never a scrolling list". Built
## separately from [method _build_column] rather than parameterising it,
## since nothing about this column - no scrolling, a fixed cell count, its
## own smaller [member inventory_slot_size] - is shared with the Combat Loot
## column beside it.
func _build_inventory_grid_column(parent: Control, heading: String) -> GridContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 6)
	parent.add_child(column)

	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override(&"font_size", 18)
	column.add_child(label)

	var grid := GridContainer.new()
	grid.columns = HORSE_GRID_COLUMNS
	grid.add_theme_constant_override(&"h_separation", int(slot_gap))
	grid.add_theme_constant_override(&"v_separation", int(slot_gap))
	column.add_child(grid)
	return grid


## Rebuilds both grids from scratch - see [method _refresh_inventory] and
## [method _refresh_loot], which are what actually fill them.
func _refresh() -> void:
	if _title != null:
		_title.text = title_text
	_refresh_inventory()
	_refresh_loot()


## Rebuilds the left grid to exactly [constant HORSE_GRID_SLOTS] cells, one
## per position in the fixed 3x3 layout - see the class doc. A position inside
## [RunInventory]'s own capacity draws as either an occupied stack's button or
## an empty-but-real slot; a position beyond it draws as a dimmer, inert one
## that is not part of the inventory at all. This is what keeps a six-slot run
## reading as "six live slots, three empty cells" rather than the capacity
## itself ever appearing to have grown to nine - see
## [method _build_empty_inventory_slot].
##
## Every occupied slot is shown - this is the Horse Inventory itself, not only
## the two categories the screen once resupplied from - but only an ammo or a
## Heart stack is actually clickable; a weapon, a bounty poster, a treasure map
## or ordinary loot is shown and left alone, since nothing yet exists for
## clicking one to do.
func _refresh_inventory() -> void:
	if _inventory_grid == null:
		return
	for child: Node in _inventory_grid.get_children():
		child.queue_free()

	var real_slots := 0 if _inventory == null else _inventory.get_max_slots()
	var slots: Array[RunItemStack] = [] if _inventory == null else _inventory.get_slots()

	for i in HORSE_GRID_SLOTS:
		if i >= real_slots:
			_inventory_grid.add_child(_build_empty_inventory_slot(false))
			continue
		var stack: RunItemStack = slots[i] if i < slots.size() else null
		if stack == null:
			_inventory_grid.add_child(_build_empty_inventory_slot(true))
		else:
			_inventory_grid.add_child(_build_inventory_button(i, stack))


func _build_inventory_button(index: int, stack: RunItemStack) -> Button:
	var button := Button.new()
	button.custom_minimum_size = inventory_slot_size
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.tooltip_text = stack.describe()
	match stack.category:
		&"heart":
			button.text = _heart_button_text(stack)
			button.disabled = not _can_use_heart()
			button.pressed.connect(_on_stack_pressed.bind(index))
		&"ammo":
			button.text = _ammo_button_text(stack)
			button.disabled = not _can_use_ammo(stack)
			button.pressed.connect(_on_stack_pressed.bind(index))
		_:
			button.text = stack.describe()
			button.disabled = true
	return button


## One blank cell of the fixed grid. [param within_capacity] true is a real
## [RunInventory] slot that simply has nothing in it right now - shown at a
## light dim with [member empty_text] as its tooltip; false is a grid position
## past the inventory's own capacity, dimmed further and inert, so the two
## never read as the same thing at a glance despite neither being clickable.
func _build_empty_inventory_slot(within_capacity: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = inventory_slot_size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	if within_capacity:
		button.tooltip_text = empty_text
		button.modulate = Color(1.0, 1.0, 1.0, 0.6)
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 0.25)
	return button


# --- Combat loot -----------------------------------------------------------

## Rebuilds the right grid from [CombatLoot]'s current stacks, in the order
## they were added. Every stack is clickable - see [method _on_loot_stack_pressed] -
## and a stack the Horse Inventory has no room for is shown disabled rather
## than left out, so the player can see exactly what is still waiting to be
## claimed.
func _refresh_loot() -> void:
	if _loot_grid == null:
		return
	for child: Node in _loot_grid.get_children():
		child.queue_free()

	if _loot == null or _loot.is_empty():
		var empty := Label.new()
		empty.text = loot_empty_text
		_loot_grid.add_child(empty)
		return

	var stacks := _loot.get_stacks()
	for i in stacks.size():
		_loot_grid.add_child(_build_loot_button(i, stacks[i]))


func _build_loot_button(index: int, stack: RunItemStack) -> Button:
	var button := Button.new()
	button.custom_minimum_size = slot_size
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text = stack.describe()
	if stack.category == &"boss_info":
		button.disabled = not _can_reveal_boss_info()
		button.pressed.connect(_on_boss_info_stack_pressed.bind(index))
	else:
		button.disabled = not _can_take_loot(stack)
		button.pressed.connect(_on_loot_stack_pressed.bind(index))
	return button


## Whether at least one unit of [param stack] could be taken into the Horse
## Inventory right now - the same question [method RunInventory.can_add_item]
## already answers a shop with, asked here so a stack the row has no room for
## reads as disabled rather than inviting a click that can only do nothing.
func _can_take_loot(stack: RunItemStack) -> bool:
	return _inventory != null and _inventory.can_add_item(stack.item_id)


## Transfers as much of the stack at [param index] into the Horse Inventory as
## actually finds room, and only ever takes that much back off the loot -
## never the whole stack outright. A stack the row has no room for at all is
## left standing exactly as it was: nothing is destroyed, and the player is
## free to try again the moment something else frees a slot.
func _on_loot_stack_pressed(index: int) -> void:
	if _loot == null or _inventory == null:
		return
	var stacks := _loot.get_stacks()
	if index < 0 or index >= stacks.size():
		return

	var stack := stacks[index]
	var added := _inventory.add_item(
		stack.item_id, stack.display_name, stack.count, stack.max_count,
		stack.category, stack.icon, stack.payload)
	if added > 0:
		_loot.remove_from_stack(index, added)

	_refresh_loot()
	_refresh_inventory()


# --- Boss Information --------------------------------------------------------

func _resolve_ledger() -> BountyLedger:
	return get_node_or_null(bounty_ledger_path) as BountyLedger


## Who this lead could be about right now: a contract the player has taken,
## has not finished, and still has at least one question mark on - the exact
## candidacy [method SurrenderKnowledge._pick_bounty] already picks from, so a
## Combat Loot lead can never reveal something a man who gave up could not
## also have told the player.
func _pick_bounty_for_reveal(ledger: BountyLedger) -> Bounty:
	var pool: Array[Bounty] = []
	for bounty: Bounty in ledger.get_outstanding():
		if bounty != null and not bounty.is_fully_known():
			pool.append(bounty)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## Whether a Boss Information click could actually teach the player anything
## right now - the same live question [method _can_use_heart] and
## [method _can_use_ammo] already ask of their own categories, so a lead with
## nothing left to reveal reads disabled rather than inviting a click that can
## only do nothing.
func _can_reveal_boss_info() -> bool:
	var ledger := _resolve_ledger()
	return ledger != null and _pick_bounty_for_reveal(ledger) != null


## Fills in one line of one contract - picked fresh from live ledger state
## rather than decided back when the fight dropped this lead, so a lead earned
## in one fight and claimed after taking or finishing others always lands
## somewhere still worth knowing. Only ever removes the stack once something
## was actually learned: a click that could not teach anything leaves
## [CombatLoot] exactly as it was, per the class doc.
func _on_boss_info_stack_pressed(index: int) -> void:
	if _loot == null:
		return
	var ledger := _resolve_ledger()
	if ledger == null:
		return

	var bounty := _pick_bounty_for_reveal(ledger)
	if bounty == null:
		return
	var missing := bounty.get_unknown_categories()
	if missing.is_empty():
		return
	var category: StringName = missing[randi() % missing.size()]
	if not ledger.reveal(bounty.bounty_id, category):
		return

	_loot.remove_from_stack(index, 1)
	_refresh_loot()


# --- Ammunition --------------------------------------------------------------

func _ammo_type_for(stack: RunItemStack) -> AmmoType:
	return stack.payload as AmmoType


## The reserve [param stack]'s ammunition actually belongs to, created on
## first ask exactly the way [method AmmoLocker.get_reserve] always does - so
## a round the player is carrying but has never had loaded still resolves to
## a real reserve rather than [code]null[/code].
func _reserve_for(stack: RunItemStack) -> AmmoReserve:
	var type := _ammo_type_for(stack)
	if type == null or _locker == null:
		return null
	return _locker.get_reserve(type)


## How much one click of [param stack] would actually hand over: one weapon
## base-ammo capacity - [member AmmoType.max_ammo], read live off the
## resource rather than hardcoded per rule 4's "do not hardcode Revolver =
## 66" - or only what is left to fill, or only what the stack itself is
## carrying, whichever is smallest. 0 means the click would do nothing:
## refused rather than spending an inventory count on filling nothing, per
## rule 7's "already full -> clicking ammo does nothing".
func _ammo_click_amount(stack: RunItemStack) -> int:
	var type := _ammo_type_for(stack)
	var reserve := _reserve_for(stack)
	if type == null or reserve == null:
		return 0
	var chunk := maxi(type.max_ammo, 0)
	var room := maxi(reserve.get_max() - reserve.get_current(), 0)
	return clampi(mini(chunk, room), 0, stack.count)


func _can_use_ammo(stack: RunItemStack) -> bool:
	return _ammo_click_amount(stack) > 0


func _ammo_button_text(stack: RunItemStack) -> String:
	var reserve := _reserve_for(stack)
	if reserve != null and reserve.is_full():
		return stack.describe() + full_ammo_suffix
	return stack.describe()


## Tops the reserve up by [method _ammo_click_amount] and only then takes the
## same amount out of [param stack] - never the flat base capacity, so a
## weapon that needed only 20 of a 66-round chunk leaves the other 46 sitting
## in the stack exactly as rule 7's own worked example asks. Reserve capacity
## and chamber/cylinder rules are never touched here - see [method AmmoReserve.add] -
## the same seam [AmmoCrate] already refills the equipped weapon through.
func _use_ammo_stack(stack: RunItemStack) -> void:
	var amount := _ammo_click_amount(stack)
	if amount <= 0:
		return
	var reserve := _reserve_for(stack)
	if reserve == null:
		return
	var added := reserve.add(amount)
	if added > 0 and _inventory != null:
		_inventory.remove_item(stack.item_id, added)


# --- Hearts --------------------------------------------------------------

## The player's own [Health], found the identical way
## [method WorldMapCombatBridge._find_health] already does, so a component
## added anywhere under the player is still found.
func _find_health() -> Health:
	var player := get_tree().get_first_node_in_group(player_group) as Node
	if player == null:
		return null
	for node: Node in player.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


func _can_use_heart() -> bool:
	var health := _find_health()
	return health != null and not health.is_full()


func _heart_button_text(stack: RunItemStack) -> String:
	if not _can_use_heart():
		return full_heart_text
	return stack.describe()


## Heals through [method Health.heal]'s own default of exactly one heart, and
## only removes the Heart that was actually spent - [method Health.heal]
## already returns 0 and changes nothing on a full pool, so a click that
## could not help is never charged, per rule 4's "do not consume a Heart if
## the player's health cannot benefit from it".
func _use_heart_stack() -> void:
	var health := _find_health()
	if health == null:
		return
	var restored := health.heal(1.0)
	if restored > 0.0 and _inventory != null:
		_inventory.remove_item(&"heart", 1)


# --- Clicking ------------------------------------------------------------

func _on_stack_pressed(index: int) -> void:
	if _inventory == null:
		return
	var stack := _inventory.get_slot(index)
	if stack == null:
		return
	if stack.category == &"heart":
		_use_heart_stack()
	else:
		_use_ammo_stack(stack)
	_refresh_inventory()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_inventory()


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
