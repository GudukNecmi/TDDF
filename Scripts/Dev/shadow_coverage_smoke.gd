class_name ShadowCoverageSmoke
extends Node2D
## A short smoke test over the whole shadow-casting cast list, after the second
## wiring pass took the architecture from seven representatives to every object
## that should be dropping a shadow on the Desert floor.
##
## It loads the real Desert - [code]World.tscn[/code], with its own
## [SunController] - and drops one of everything into it: enemies, a bomber,
## every weapon the player can carry, the regional props, the wagon and the
## chests. Each is asked three questions and no more: is there a caster, is its
## shadow actually drawn, and is there exactly one of it.
##
## It also asks the opposite question of the objects that must stay shadowless -
## the lizard, the ground pickups, the loot - because "everything has a shadow" is
## only half of the wiring being right.
##
## [b]It is a smoke test, not a gameplay test.[/b] Nothing here plays the game or
## judges how anything looks.

## Scenes that must each end up with exactly one live shadow, as
## [code]{name: PackedScene}[/code].
@export var shadowed_scenes: Dictionary[StringName, PackedScene] = {}
## Scenes that must carry no shadow at all.
@export var shadowless_scenes: Dictionary[StringName, PackedScene] = {}
## The Desert itself.
@export var world_scene: PackedScene
## Objects inside the Desert that are expected to have a caster already, by path.
@export var world_shadowed: Dictionary[StringName, NodePath] = {}
## How long the spawned objects are given to finish appearing before they are
## asked for their shadows.
@export var settle_seconds: float = 2.5
@export var quit_when_done: bool = true

var _failures: int = 0
var _world: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = world_scene.instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	print("")
	print("shadow coverage: %s (%d failure(s))" % [
		"OK" if _failures == 0 else "BROKEN", _failures])
	if quit_when_done:
		get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	var arena := _world.get_node_or_null(^"Arena") as Node2D
	var director := SunController.get_active(self)
	_check("Desert loads with its sun",
		arena != null and director != null,
		"arena %s, sun %s" % [arena, director])
	if arena == null or director == null:
		return

	# Already standing in the map.
	for label: StringName in world_shadowed:
		var node := _world.get_node_or_null(world_shadowed[label]) as Node2D
		_check("%s is in the Desert" % label, node != null,
			"nothing at %s" % world_shadowed[label])
		if node != null:
			_expect_shadows(label, node)

	# Dropped in, one of each.
	var spawned: Dictionary[StringName, Node2D] = {}
	for label: StringName in shadowed_scenes:
		var node := _spawn(shadowed_scenes[label], arena)
		_check("%s instantiates" % label, node != null, "the scene gave nothing")
		if node != null:
			spawned[label] = node
	# Long enough for anything that arrives rather than simply existing to have
	# arrived - the camp waggon grows in from nothing over a couple of seconds, and a
	# thing that is not drawn yet correctly casts nothing.
	await get_tree().create_timer(settle_seconds, true, false, true).timeout

	for label: StringName in spawned:
		_expect_shadows(label, spawned[label])

	# And the things that must stay bare.
	for label: StringName in shadowless_scenes:
		var node := _spawn(shadowless_scenes[label], arena)
		if node == null:
			_check("%s instantiates" % label, false, "the scene gave nothing")
			continue
		await get_tree().process_frame
		_check("%s casts no shadow" % label, _casters_under(node).is_empty(),
			"it has %d caster(s)" % _casters_under(node).size())


## Every caster under one object: present, drawn, and not doubled up with another
## caster on the same artwork.
func _expect_shadows(label: StringName, node: Node2D) -> void:
	var casters := _casters_under(node)
	if casters.is_empty():
		_check("%s casts a shadow" % label, false, "no ShadowCaster anywhere on it")
		return

	var drawn := 0
	var sources: Array[Sprite2D] = []
	var doubled := false
	for caster: ShadowCaster in casters:
		caster.update_shadow()
		var shadow := caster.get_shadow_item()
		if _is_drawn(shadow):
			drawn += 1
		# A caster owns nothing but, at most, the one shadow group it had to make
		# for itself, and no two casters on the same object share a source - which
		# is what a duplicate shadow would look like.
		if caster.get_children().size() > 1:
			doubled = true
		var source := caster.get_source_sprite()
		if source != null and sources.has(source):
			doubled = true
		elif source != null:
			sources.append(source)

	_check("%s casts a shadow" % label, drawn == casters.size(),
		"%d of its %d caster(s) drawn" % [drawn, casters.size()])
	_check("%s casts no duplicate shadow" % label, not doubled,
		"%d caster(s) over %d source sprite(s)" % [casters.size(), sources.size()])


func _casters_under(node: Node) -> Array[ShadowCaster]:
	var found: Array[ShadowCaster] = []
	var caster := node as ShadowCaster
	if caster != null:
		found.append(caster)
	for child: Node in node.get_children():
		found.append_array(_casters_under(child))
	return found


func _spawn(scene: PackedScene, parent: Node) -> Node2D:
	if scene == null:
		return null
	var node := scene.instantiate() as Node2D
	if node == null:
		return null
	parent.add_child(node)
	node.global_position = Vector2(randf_range(-400.0, 400.0), randf_range(-200.0, 200.0))
	# Anything that arrives rather than simply existing is told to arrive - the camp
	# waggon is drawn at nothing until it opens, and nothing correctly casts nothing.
	if node.has_method(&"open"):
		node.call(&"open")
	return node


func _check(what: String, passed: bool, detail: String = "") -> void:
	if passed:
		print("PASS  %s" % what)
		return
	_failures += 1
	print("FAIL  %s%s" % [what, "" if detail.is_empty() else "  -  " + detail])


## Whether a shadow mesh is actually putting something on the floor: it is shown,
## it has artwork to be the silhouette of, and geometry was built for it this
## frame. Alpha lives in the vertex colours now, so a modulate cannot be asked.
func _is_drawn(item: ShadowShape) -> bool:
	return item != null and item.visible and item.has_shape()
