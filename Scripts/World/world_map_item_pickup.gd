class_name WorldMapItemPickup
extends Node2D
## Something lying on the World Map the player can walk up to, press E, and
## take into the [RunInventory] - a bounty poster, a treasure map, a found
## loot item, a stray box of ammunition. Rule 29 of the run inventory phase's
## "generic behaviour" made a node: discovered, approached, interacted with,
## offered to [method RunInventory.can_add_item] and [method RunInventory.add_item],
## and left lying there if it does not fit.
##
## [b]It is [GroundPickup] and [LootGem] with the run inventory behind the key
## instead of a weapon or nothing at all[/b] - deliberately the same shape:
## the player found by group, the reach a circle around this node, the prompt
## told on the crossing rather than asked every frame, the edge drawn only
## while the player is close enough to actually take it, and the key taken in
## [method Node._unhandled_input] and marked handled so the press that takes
## an item can never also reach whatever is standing behind it.
##
## [b]Partial pickups shrink the pile; they never empty it for nothing.[/b]
## [method RunInventory.add_item] can hand back less than was offered - a
## stack topped up short of the whole amount, because the row ran out of
## slots to open a new one in - and this node's own [member amount] is cut by
## exactly what was actually taken. What is left keeps standing here, in
## reach, offering itself again the next time the player has room; only once
## every last unit has gone does the node free itself. This is rule 12's "the
## item remains in the world" and rule 3's "no ammo should disappear" applied
## to a physical pile rather than a shop.
##
## [b]This is also the drop seam rule 33 asks for.[/b] Discarding a slot from
## the inventory panel builds one of these at the player's feet with the
## discarded stack's own identity and count rather than inventing a second
## kind of dropped-item node - see [method RunInventoryPanel._discard_selected].

## Emitted as some or all of the pile is actually taken, with how much.
signal collected(item_id: StringName, amount: int)
## Emitted once per interaction attempt that took nothing at all - the row was
## already full of everything else. Never spammed per frame; see
## [signal RunInventory.pickup_rejected], which this simply relays.
signal rejected(item_id: StringName)

## Group every World Map item pickup joins, so a spawner or a debug script can
## find them all without being wired to any one of them.
const GROUP := &"world_map_item_pickup"

## The identity stacks are matched on - the same [member RunItemStack.item_id]
## a shop purchase or another pickup of the same thing would use. An
## ammunition pickup should share the real [AmmoType]'s id, so it stacks with
## ammunition bought at the trader rather than starting a rival pile.
@export var item_id: StringName = &"loot"
@export var display_name: String = "ITEM"
## How many units this pile is carrying. Reduced as some are taken; the node
## frees itself once this reaches zero.
@export var amount: int = 1
## The most one inventory slot of this item can hold - 1 for anything that
## does not stack. Left at 1 for a loot item; set to
## [method RunInventory.get_ammo_max_stack]'s answer for an ammunition pile
## built by script.
@export var max_count: int = 1
## Presentation-only grouping label, read by the inventory UI and nothing
## else - "loot", "ammo", "treasure_map", "bounty_poster".
@export var category: StringName = &"loot"
@export var icon: Texture2D

@export_group("Reach")
## How close the player has to stand, in pixels. The same reach a knife on
## the floor offers.
@export var interaction_radius: float = 95.0
## Only bodies in this group can take it.
@export var body_group: StringName = &"player"
## Key that takes it - the project's own interact action.
@export var interact_action: StringName = &"interact"
@export var reach_offset := Vector2.ZERO

@export_group("Nodes")
## The prompt shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"
## The picture outlined while in reach. Left empty, the first [Sprite2D] child
## is used - the same fallback [GroundPickup] uses.
@export var art_source_path: NodePath

@export_group("The edge")
@export var outlines_in_reach: bool = true
@export var outline_shader: Shader
@export var outline_width: float = 1.5
@export var outline_color := Color(1.0, 0.85, 0.25, 1.0)

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false
var _taken: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if outline_shader == null:
		outline_shader = load("res://Shaders/hit_flash.gdshader") as Shader
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## Builds a pickup standing for [param stack] at [param world_position], added
## as a child of [param parent]. What a discard from the inventory panel uses -
## see the class doc - and available to anything else that wants to spill a
## stack onto the map without touching [RunInventory] itself.
static func spawn_for_stack(stack: RunItemStack, parent: Node, world_position: Vector2) -> WorldMapItemPickup:
	if stack == null or parent == null:
		return null

	var pickup := WorldMapItemPickup.new()
	pickup.item_id = stack.item_id
	pickup.display_name = stack.display_name
	pickup.amount = stack.count
	pickup.max_count = stack.max_count
	pickup.category = stack.category
	pickup.icon = stack.icon

	parent.add_child(pickup)
	pickup.global_position = world_position
	return pickup


func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


func is_taken() -> bool:
	return _taken


## Takes as much of the pile as the run inventory has room for. Returns
## whether anything at all was taken.
func use() -> bool:
	if _taken or not _in_reach or amount <= 0:
		return false

	var inventory := RunInventory.get_active(self)
	if inventory == null:
		return false

	var taken := inventory.add_item(item_id, display_name, amount, max_count, category, icon)
	if taken <= 0:
		rejected.emit(item_id)
		return false

	amount -= taken
	collected.emit(item_id, taken)
	if amount > 0:
		# Some is left - the pile stays standing, still in reach, so the player
		# can come back for the rest the moment they have room.
		return true

	_taken = true
	set_process(false)
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	_show_edge(false)
	queue_free()
	return true


func _process(_delta: float) -> void:
	_watch_player()


func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := not _taken and is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	_show_edge(_in_reach)


func _show_edge(shown: bool) -> void:
	if not outlines_in_reach:
		return
	SpriteOutline.set_outlined(_art_source(), shown, outline_shader, outline_width, outline_color)


func _art_source() -> Sprite2D:
	if not art_source_path.is_empty():
		return get_node_or_null(art_source_path) as Sprite2D
	for node: Node in find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite != null:
			return sprite
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _taken or not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	# Marked handled whether it was taken in full, in part, or refused, so a
	# press aimed at an item is never also a shot or another interaction.
	get_viewport().set_input_as_handled()
