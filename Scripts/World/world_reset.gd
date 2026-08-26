class_name WorldReset
extends Node
## Puts the desert back to how it was found, without the scene being rebuilt
## around it.
##
## [b]It is the scene reload, done in place.[/b] Setting out on a run, riding to a
## region and starting the next round all rebuild the World scene - see
## [method SceneTree.reload_current_scene] - and everything the player is carrying
## survives that because it lives in autoloads. Looking for trouble cannot do the
## same: the search itself, the horse being away and the Danger about to open are
## all state held [i]in[/i] the world, and reloading would throw them away with the
## corpses. So this is the other half of that pair - the same clean world, reached
## by emptying it rather than by building a new one.
##
## [b]It owns no list of what the game contains.[/b] What is swept away is named in
## the inspector as classes and groups, so a later kind of litter is cleared by
## adding its class to [member cleared_classes] rather than by a line being written
## here, and a thing that must survive a reset is added to [member kept_groups]
## rather than being special-cased. That is what lets the same node be asked for a
## reset by the road and by the search alike without either of them knowing what a
## desert is made of.
##
## [b]The scenery is re-rolled rather than moved.[/b] The props are laid out again
## by the map's own [PropScatter] - see [method PropScatter.rescatter] - so the
## region's own prop pools, the hour's own scenery and the map's own density are all
## exactly the ones that were authored, and only the arrangement is new. Nothing
## about the region, the ground under it or what is written down about the run is
## touched: a reset changes what is standing in the desert, never what the desert
## is.

## Emitted once a reset has been made, with how many things were taken away and
## how many props were laid out again.
signal world_reset(cleared: int, scattered: int)

## Group this joins, so anything that wants a clean world can find it without a
## path across the scene.
const GROUP := &"world_reset"

## Whether a reset does anything at all. Off makes every caller's request a quiet
## no-op, which is what a harness looking at a journey without its world moving
## wants.
@export var enabled: bool = true

@export_group("What is swept away")
## Classes whose every instance is taken off the map. These are things that are
## their own scene root - a knife in flight, a piece broken off something, a crate
## dropped in - so the node found is the node freed.
@export var cleared_classes: Array[StringName] = [
	&"Projectile", &"DeathDebris", &"KickedBone", &"AmmoCrate",
]
## Groups whose every member is taken off the map, the member itself being what is
## freed. [code]enemies[/code] is the living crowd, and that group is on the body.
@export var cleared_groups: Array[StringName] = [&"enemies"]
## Groups that are joined by a [i]component[/i] hung on a body rather than by the
## body itself - [EnemySurrender] joins [code]surrendered_enemy[/code] on the man
## who gave up - so what is freed is the node's parent, which is the host every one
## of those components already treats as the thing it belongs to.
@export var cleared_host_groups: Array[StringName] = [&"surrendered_enemy"]
## Groups nothing in them is ever freed, whatever else matched.
##
## [b]This is the whole of the protection.[/b] The player is here because a sweep
## that could reach them would be a crash rather than a reset, and
## [code]test_spawned[/code] is here because the test map is not the desert and a
## developer's enemies must not be tidied away by the game's own housekeeping - the
## same exemption [ZoneEnemyGuard] and [RunEndDefeat] already make.
@export var kept_groups: Array[StringName] = [&"player", &"test_spawned"]
## Fields that are emptied rather than freed - the blood decals and the footprints,
## which are single [MultiMeshInstance2D]s holding thousands of marks rather than
## nodes. Anything with a [code]clear_all[/code] method may be listed.
@export var cleared_fields: Array[NodePath] = [
	^"../Arena/BloodField", ^"../Arena/Footprints",
]

@export_group("The scenery")
## Whether the map's props are laid out again, so the new area does not read as the
## one that was just left.
@export var rescatters_props: bool = true
## The map's own scatter. Left unresolved - or pointed at nothing - the props are
## left standing where they are and only the litter is swept.
@export var scatter_path: NodePath = ^"../Arena/PropScatter"
## Whether the ground the player is standing on is the circle the new arrangement is
## kept clear of, rather than the middle of the map the round started from.
##
## On, because a reset is made with the player already standing in the desert -
## halfway through a search, or on the road - and a cactus rolled onto the spot they
## are stood on would be scenery placed inside them.
@export var keeps_the_player_clear: bool = true
## Group the player is found in, so this node is not wired to them.
@export var player_group: StringName = &"player"


func _enter_tree() -> void:
	add_to_group(GROUP)


## The reset the rest of the world should talk to. Null means this world has none,
## which every caller reads as "there is nothing to clean up here" and carries on.
static func get_active(from_node: Node) -> WorldReset:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldReset


## Empties the world and lays its scenery out again. Returns how many things were
## taken away.
##
## Safe to ask for at any moment and from anywhere: it frees through
## [method Node.queue_free] rather than immediately, so it can be called from inside
## a physics callback, and it is idempotent - a second reset on an already clean
## world clears nothing and simply re-rolls the props.
func reset() -> int:
	if not enabled or not is_inside_tree():
		return 0

	var doomed: Dictionary = {}
	for class_named: StringName in cleared_classes:
		_gather_class(class_named, doomed)
	for group: StringName in cleared_groups:
		_gather_group(group, doomed, false)
	for group: StringName in cleared_host_groups:
		_gather_group(group, doomed, true)

	for id: int in doomed:
		var node: Node = doomed[id]
		if is_instance_valid(node):
			node.queue_free()

	_clear_fields()
	var scattered := _rescatter()

	world_reset.emit(doomed.size(), scattered)
	return doomed.size()


## Everything of one class, gathered from the running scene rather than from this
## node, because litter is added to the scene root as it is made - see
## [method ThrowableWeapon.throw] - and is nobody's child in particular.
func _gather_class(class_named: StringName, into: Dictionary) -> void:
	if class_named == &"":
		return
	var from := get_tree().current_scene
	if from == null:
		return
	for node: Node in from.find_children("*", String(class_named), true, false):
		_mark(node, into)


func _gather_group(group: StringName, into: Dictionary, by_host: bool) -> void:
	if group == &"":
		return
	for node: Node in get_tree().get_nodes_in_group(group):
		_mark(node.get_parent() if by_host else node, into)


## Adds [param node] to the list unless it is something a reset must never touch.
##
## Kept by identity in a dictionary rather than in an array, so a thing matched by
## both a class and a group - or by a component and by its own body - is freed once.
func _mark(node: Node, into: Dictionary) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	# Nothing this node hangs off may be swept away by it, which rules out the world
	# itself and every container between the two.
	if node == self or node.is_ancestor_of(self):
		return
	if _is_kept(node):
		return
	into[node.get_instance_id()] = node


## Whether [param node] or anything it is part of is exempt. Asked of its ancestors
## too, so an exemption on a body covers the components hanging off it - a knife
## lying under a test-spawned man is as exempt as the man.
func _is_kept(node: Node) -> bool:
	var walked := node
	while walked != null:
		for group: StringName in kept_groups:
			if group != &"" and walked.is_in_group(group):
				return true
		walked = walked.get_parent()
	return false


func _clear_fields() -> void:
	for path: NodePath in cleared_fields:
		if path.is_empty():
			continue
		var field := get_node_or_null(path)
		if field != null and field.has_method(&"clear_all"):
			field.call(&"clear_all")


## Lays the scenery out again, keeping the ground the player is standing on clear.
## Returns how many props were placed, or 0 when this world has no scatter to ask.
func _rescatter() -> int:
	if not rescatters_props:
		return 0
	var scatter := get_node_or_null(scatter_path) as PropScatter
	if scatter == null:
		return 0

	var around := Vector2.INF
	if keeps_the_player_clear:
		var player := get_tree().get_first_node_in_group(player_group) as Node2D
		if player != null:
			around = player.global_position
	return scatter.rescatter(around)
