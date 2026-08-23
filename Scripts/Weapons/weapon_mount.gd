class_name WeaponMount
extends Node2D
## Builds whichever weapon the player chose into the world, and is the one place
## anything else asks what they are holding.
##
## Before this existed the shotgun was a node sitting in the world scene, which
## meant the world knew which weapon the game had. Now the world holds a mount and
## the mount holds a roster: it reads the weapon id off [RunSessionState], looks it
## up in the [WeaponCatalog], and instances that weapon's scene as its own child.
## [b]Adding a weapon therefore touches no scene and no script[/b] - it is an entry
## in the catalogue, and this builds it like any other.
##
## The weapon is built as a child of the mount but keeps following the player by
## itself, exactly as it always did: [member target_path] is handed to it on the
## way in, so a weapon still trails and aims on its own terms rather than being
## parented to the body it follows.
##
## Anything that needs the live weapon - the loadout that stows it, a HUD that
## reads its magazine - finds it through this rather than by path, because a path
## would have to name a weapon. [method get_weapon] is that lookup, and it answers
## null in a world where the player is carrying nothing.

## Emitted once the weapon has been built, so anything holding on to it can pick
## up the new one after a rebuild.
signal weapon_built(weapon: CarriedWeapon)

## Group the mount joins, so the player's loadout can find it without a path
## across the scene.
const GROUP := &"weapon_mount"

## The roster. The same resource the selection screen offers from, so the two
## cannot disagree about which weapons exist.
@export var catalog: WeaponCatalog
## What the built weapon trails after - the player. Handed to the weapon as it is
## built, so the weapon itself needs no path into a scene it was not authored in.
@export var target_path: NodePath
## Which weapon to build when the session has none chosen and the catalogue offers
## no default either. Optional, and only a safety net.
@export var fallback_scene: PackedScene
## Where the chosen weapon id is read from.
@export var session_path: NodePath = ^"/root/RunSession"

@onready var _session: RunSessionState = get_node_or_null(session_path) as RunSessionState

var _weapon: CarriedWeapon
## What the player picked up off the ground, while they are carrying it. Null the
## rest of the time, which is nearly always.
var _temporary: CarriedWeapon
## The weapon they chose, put away at the belt while a temporary one is in their
## hands. It is kept in the tree rather than freed, so its magazine, its half-worked
## action and its ammunition are all exactly as they were left when it comes back.
var _stowed: CarriedWeapon


func _ready() -> void:
	add_to_group(GROUP)
	_build()


## The mount the rest of the scene should talk to. Null means this world has none,
## which callers read as "the player is holding whatever was authored into the
## scene".
static func get_active(from_node: Node) -> WeaponMount:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WeaponMount


## The weapon currently in the player's hands, or null if none was built.
func get_weapon() -> CarriedWeapon:
	return _weapon if is_instance_valid(_weapon) else null


## The roster entry that was built, for anything wanting the weapon's name or its
## ammunition without reaching into the weapon itself.
func get_definition() -> WeaponDefinition:
	if catalog == null:
		return null
	return catalog.find(_chosen_id())


## Tears down whatever is being carried and builds the chosen weapon in its place.
## Called once on the way up; calling it again is what a future weapon swap in the
## camp would use.
func rebuild() -> void:
	if is_instance_valid(_temporary):
		_temporary.queue_free()
	if is_instance_valid(_stowed):
		_stowed.queue_free()
	if is_instance_valid(_weapon):
		_weapon.queue_free()
	_temporary = null
	_stowed = null
	_weapon = null
	_build()


## Puts something the player picked up off the ground in their hands, and puts what
## they were carrying away at the belt.
##
## [b]It is a swap, not a slot.[/b] Nothing is stored anywhere and nothing about the
## player's chosen weapon changes: that weapon is stowed by its own
## [method CarriedWeapon.stow] - the same holster walking into the base uses - and
## kept in the tree with its magazine untouched, so [method drop_temporary] hands
## back the weapon that was put down rather than a fresh copy of it. There is
## therefore no second inventory and no second answer to what the player is holding:
## [method get_weapon] answers the throwable while it is out, and the chosen weapon
## again the moment it is gone.
##
## Picking up a second throwable while one is already in the hand replaces it, which
## is the ordinary rule everywhere else: there is only ever one weapon in the hand.
##
## [param switch_time] is how long the outgoing weapon takes to reach the belt.
## Returns the weapon that was built, or null when there was nothing to build.
func carry_temporary(scene: PackedScene, switch_time: float = 0.1) -> CarriedWeapon:
	if scene == null:
		return null

	var built := scene.instantiate() as CarriedWeapon
	if built == null:
		push_warning("WeaponMount: the picked-up scene is not a CarriedWeapon.")
		return null

	if is_instance_valid(_temporary):
		# Already carrying one. The one in the hand is dropped for the new one and the
		# chosen weapon stays where it is - at the belt - so swapping a bone for a
		# knife cannot draw and re-holster the revolver in between.
		_temporary.queue_free()
	elif is_instance_valid(_weapon):
		_stowed = _weapon
		_stowed.stow(maxf(switch_time, 0.0))

	built.target_path = _resolved_target()
	add_child(built)

	_temporary = built
	_weapon = built
	weapon_built.emit(_weapon)
	return built


## Takes the picked-up weapon away and gives the player theirs back. Called as a
## throwable is spent; harmless when there is none.
##
## The weapon that comes back is drawn rather than simply appearing, unless whoever
## owns the player's loadout has decided they should be empty-handed - which is why
## the signal goes out first and the draw is only played if the weapon was left out.
## The base disarms the player, and coming back from a throw must not re-arm them.
func drop_temporary(switch_time: float = 0.1) -> void:
	if not is_instance_valid(_temporary):
		return

	_temporary.queue_free()
	_temporary = null

	_weapon = _stowed if is_instance_valid(_stowed) else null
	_stowed = null
	weapon_built.emit(_weapon)

	if _weapon != null and is_instance_valid(_weapon) and not _weapon.is_stowed():
		# Put back at the belt and drawn from there, so the weapon comes up out of the
		# holster rather than reappearing at arm's length on one frame.
		_weapon.stow(0.0)
		_weapon.unstow(maxf(switch_time, 0.0))


## Whether the player is carrying something they picked up rather than the weapon
## they chose.
func is_carrying_temporary() -> bool:
	return is_instance_valid(_temporary)


## Which weapon the session says to build, falling back to the roster's own first
## unlocked entry. [b]No weapon is named here[/b] - the fallback is a question
## asked of the catalogue, so the shotgun is not written down as "the default" in
## a second place.
func _chosen_id() -> StringName:
	if _session != null:
		var chosen := _session.get_weapon_id()
		if chosen != &"":
			return chosen
	if catalog != null:
		var fallback := catalog.get_default()
		if fallback != null:
			return fallback.weapon_id
	return &""


func _build() -> void:
	var scene := _scene_for(_chosen_id())
	if scene == null:
		push_warning("WeaponMount has nothing to build - the player will be empty-handed.")
		return

	var built := scene.instantiate() as CarriedWeapon
	if built == null:
		push_warning("WeaponMount: the chosen weapon scene is not a CarriedWeapon.")
		return

	# Set before the weapon enters the tree, so its own _ready finds the target
	# already there and it starts in place at the player's hip rather than sliding
	# in from the world origin.
	#
	# The scale is deliberately not touched: how large a weapon is carried is a
	# fact about that weapon's artwork, so it is authored in the weapon's own
	# scene rather than imposed here on all of them.
	built.target_path = _resolved_target()
	add_child(built)

	_weapon = built
	weapon_built.emit(_weapon)


func _scene_for(weapon_id: StringName) -> PackedScene:
	if catalog != null:
		var definition := catalog.find(weapon_id)
		if definition != null and definition.scene != null:
			return definition.scene
	return fallback_scene


## The weapon is handed an absolute path to the target rather than the mount's own
## relative one, because the two nodes sit in different branches of the world and
## a relative path would be read from the weapon's position in the tree.
func _resolved_target() -> NodePath:
	if target_path.is_empty():
		return NodePath()
	var target := get_node_or_null(target_path)
	return target.get_path() if target != null else NodePath()
