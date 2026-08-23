class_name WeaponRack
extends Node2D
## The weapon table beside the base's pit: walk up to it, press E, and pick what
## you are carrying out.
##
## [b]It stands where the player lands.[/b] The base drops them at the pit's own
## spawn point, so the table is a short walk from it - close enough to be seen on
## the first frame of a new game, far enough that its prompt is not already up
## when they arrive. Where exactly is the node's position in [code]Base.tscn[/code]
## and how close counts is [member interaction_radius]; neither is in this file,
## so moving the table is dragging it in the editor. Its artwork is likewise the
## scene's - see [code]Scenes/Base/WeaponTable.tscn[/code], which is nothing but
## the base's own pipe pieces stood up as a stand with the roster's three guns
## laid on it - and it carries no collision, so the table can be walked through
## rather than fenced around.
##
## [b]It is [WantedBoard] with a different screen behind it[/b], and deliberately
## the same shape: the player is found by group rather than by path, the reach test
## is a circle around this node rather than an area to author, the prompt is
## [i]told[/i] on the crossing rather than asked every frame, and the key is taken
## in [method Node._unhandled_input] and marked handled so the press that opens the
## rack cannot also reach the shotgun standing behind it.
##
## [b]Choosing a weapon used to happen on the way out.[/b] [RunPortal] asked for it
## at the mouth of the pit, before the map, every single time - so a new game began
## by being handed a menu rather than by standing in the base. That question now
## lives here, at a place in the world the player walks to when they want it. The
## screen is the same [WeaponSelectMenu] it always was, found by group and opened
## unchanged; nothing about how weapons are chosen, stored or carried has moved.
##
## [b]Picking a gun is not setting out.[/b] The table changes what the player is
## carrying and hands the base straight back to them - see
## [member starts_run_after_choosing], which the base authors [i]off[/i]. Preparing
## and leaving are two separate acts in the base: the player kits themselves out at
## the stations, and the run begins only when they walk to the pit and choose to
## start one. Nothing about a station may set out on their behalf.

## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when they actually open the rack.
signal used

## Group every rack joins, so anything can find it without being wired to it.
const GROUP := &"weapon_rack"

## How close the player has to stand for the prompt to appear and the key to work,
## in pixels. Generous on purpose, exactly as the board's is - "at the rack" has to
## mean somewhere the player can casually walk to, not a pixel they have to find.
@export var interaction_radius: float = 190.0
## Only bodies in this group can use it.
@export var body_group: StringName = &"player"
## Key that opens it.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, so the circle can sit at the front of whatever
## this is hung on rather than at the middle of the artwork.
@export var reach_offset := Vector2(0.0, 60.0)
## Whether confirming a weapon carries straight on into setting out - the map
## question, and then the run.
##
## [b]Off, and the base's own table is authored off too.[/b] A station in the base
## prepares the player and leaves them standing in the base; setting out is a
## separate decision made at the pit. On is kept for a rack that is genuinely the
## way out of somewhere, which nothing in the game currently is.
@export var starts_run_after_choosing: bool = false
## Whether the gun that was picked is put in the player's hands there and then,
## rather than waiting for the world to be rebuilt.
##
## [b]On, because the table has to actually change the weapon.[/b] Choosing writes
## the answer to [RunSessionState] and [WeaponMount] reads it when it builds - which
## was enough while picking a gun was the first step of leaving, because the world
## was rebuilt a moment later. A table the player walks away from has no rebuild
## coming, so without this they would stand in the base still holding the old gun
## until their next run.
##
## It is [method WeaponMount.rebuild], the mount's own public swap, rather than
## anything about weapons written here - so what gets built, from which catalogue
## entry, is decided in exactly the one place it always was.
@export var swaps_weapon_immediately: bool = true

@export_group("Nodes")
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _in_reach: bool = false
var _menu: WeaponSelectMenu


func _ready() -> void:
	add_to_group(GROUP)
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## The rack the rest of the scene should talk to. Null means this world has none,
## which every caller reads as "there is nowhere to change weapons".
static func get_active(from_node: Node) -> WeaponRack:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WeaponRack


## Whether [param body] is standing close enough to reach the rack.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Opens the rack. Ignored unless the player is actually standing at it, so nothing
## can be triggered from across the base.
func use() -> void:
	if not _in_reach:
		return

	used.emit()
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	var menu := _get_menu()
	if menu == null:
		return

	if not menu.weapon_chosen.is_connected(_on_weapon_chosen):
		menu.weapon_chosen.connect(_on_weapon_chosen)
	menu.open()


## A weapon was picked. Which weapon that is is [WeaponSelectMenu]'s answer and has
## already been written to the run; this puts it in the player's hands and then
## stops.
##
## Backing out of the screen deliberately does nothing at all - nothing is swapped
## and nothing is put back - because changing your mind about a gun before choosing
## one is not a choice.
func _on_weapon_chosen(_weapon_id: StringName) -> void:
	_swap_weapon()

	if not starts_run_after_choosing:
		return

	var portal := RunPortal.get_active(self)
	if portal != null:
		portal.start_run()


## Hands the player the gun they just picked, through the mount's own rebuild - and
## makes it ready, which is the same call every world build makes so a weapon
## changed at the table is carried in the state a weapon is always carried in.
##
## A world with no mount changes nothing rather than erroring, exactly as it does
## everywhere else the mount is asked for.
func _swap_weapon() -> void:
	if not swaps_weapon_immediately:
		return

	var mount := WeaponMount.get_active(self)
	if mount == null:
		return

	mount.rebuild()
	var weapon := mount.get_weapon()
	if weapon != null:
		weapon.reload_to_ready()


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame and anything else that wants to react to the player
## arriving can hang off the signals instead of repeating the distance test.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	if _in_reach:
		player_entered.emit()
	else:
		player_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	get_viewport().set_input_as_handled()


## Looked up lazily and re-looked-up if it goes away, the same way [WantedBoard]
## finds its own screen.
func _get_menu() -> WeaponSelectMenu:
	if _menu == null or not is_instance_valid(_menu):
		_menu = WeaponSelectMenu.get_active(self)
	return _menu
