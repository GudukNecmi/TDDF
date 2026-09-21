extends SceneTree
## Headless check that an Arena prop's shadow grows out of the ground it is
## standing on rather than swinging about somewhere inside the picture.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/arena_shadow_pivot_smoke.gd
## [/codeblock]
##
## [b]The measurement is the prop's own ground contact, at every hour.[/b] Where a
## prop meets the floor is a patch of ground, and a patch of ground does not move
## when the sun does. So this takes the corners of the artwork's bottom edge -
## bottom left and bottom right, the two ends of the contact line - asks the
## projection where each of them ends up, and requires the answer to be the corner
## itself. A shadow pivoting about the middle of the picture, or slid back down its
## own length by a fraction of its reach, fails that at the first hour that is not
## noon.
##
## It is asked of a tall prop and a short one through the same code path, because
## the fault it is guarding against grows with the size of the thing - a bone's
## shadow barely moves and a tent's comes off the tent - and a fix that only helps
## tents is exactly what a special case would look like.

const ARENA_SCENE := "res://Scenes/World/Arenas/DustCampArena.tscn"
## How far a corner of the ground contact may land from where it is drawn, in world
## pixels. A shadow's own geometry is cut to about a pixel, so this is that and no
## slack for a pivot.
const CONTACT_TOLERANCE := 1.0

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(ARENA_SCENE)
	for _frame: int in range(30):
		await process_frame
		await physics_frame

	var sun := _find_sun()
	_ok(sun != null, "the arena has a sun")
	if sun == null:
		_finish()
		return

	# The two arena props that are placed by play rather than scattered. Dropped in
	# here so the measurement covers every kind of thing the arena stands on the
	# floor, not only the scenery the region happened to scatter.
	_add_placed_props()
	for _frame: int in range(4):
		await process_frame

	var props := _find_props()
	_ok(not props.is_empty(), "the arena scattered props to look at",
		"%d found" % props.size())
	print("       looking at %d props" % props.size())

	# A prop that has authored no footprint is projected as the upright card it
	# always was, so it would keep the very fault this is about. Scenery is
	# expected to have one; a figure is not, and is no part of this.
	var bare := _scenery_without_footing()
	_ok(bare.is_empty(), "every piece of arena scenery authored its ground contact",
		"without one: %s" % ", ".join(bare))

	# A tall one and a short one, so the same code path is answering for both.
	var tallest := _by_height(props, true)
	var shortest := _by_height(props, false)
	if tallest != null:
		print("       tallest is %s, %.0f px of artwork"
			% [_prop_name(tallest), _art_height(tallest)])
	if shortest != null:
		print("       shortest is %s, %.0f px of artwork"
			% [_prop_name(shortest), _art_height(shortest)])

	for hour: int in range(6):
		sun.call(&"snap_to_stage", hour)
		for _frame: int in range(3):
			await process_frame
		print("--- hour %d, light along %s ---"
			% [hour, sun.call(&"get_state").direction])
		_check_contact_fixed(props, hour)

	_finish()


## Every prop's ground contact lands exactly where the artwork draws it.
func _check_contact_fixed(props: Array[ShadowCaster], hour: int) -> void:
	var worst := 0.0
	var worst_prop := ""
	var drifted := 0
	for caster: ShadowCaster in props:
		var group := caster.get_group()
		if group == null:
			continue
		var sprite := caster.get_source_sprite()
		if sprite == null or sprite.texture == null:
			continue
		var box := SpriteBounds.world_box(sprite, sprite.global_transform)
		if box.size == Vector2.ZERO:
			continue
		# The two ends of the line the prop stands on. Left first: it is the corner
		# the brief names, and the one a pivot in the middle of the picture moves
		# furthest.
		for corner: Vector2 in [Vector2(box.position.x, box.end.y),
				Vector2(box.end.x, box.end.y)]:
			var off := group.project_world(corner).distance_to(corner)
			if off > worst:
				worst = off
				worst_prop = _prop_name(caster)
			if off > CONTACT_TOLERANCE:
				drifted += 1
	_ok(drifted == 0,
		"hour %d: every prop's ground contact stayed where it is drawn" % hour,
		"%d corners moved, worst %.1f px on %s" % [drifted, worst, worst_prop])
	print("       worst corner drift %.2f px (%s)"
		% [worst, worst_prop if not worst_prop.is_empty() else "none"])


func _find_sun() -> Node:
	return root.get_tree().get_first_node_in_group(&"sun")


## Every scattered prop that casts a shadow and has authored the patch of floor it
## is standing on. A prop that has authored none is projected as the upright card
## it always was and is no part of this question.
func _find_props() -> Array[ShadowCaster]:
	var found: Array[ShadowCaster] = []
	_collect(root, found)
	return found


func _collect(node: Node, into: Array[ShadowCaster]) -> void:
	var caster := node as ShadowCaster
	if caster != null and caster.get_ground_contact().y > 0.0:
		into.append(caster)
	for child: Node in node.get_children():
		_collect(child, into)


func _by_height(props: Array[ShadowCaster], tallest: bool) -> ShadowCaster:
	var best: ShadowCaster = null
	var best_height := -INF if tallest else INF
	for caster: ShadowCaster in props:
		var height := _art_height(caster)
		if (tallest and height > best_height) or (not tallest and height < best_height):
			best_height = height
			best = caster
	return best


func _art_height(caster: ShadowCaster) -> float:
	var sprite := caster.get_source_sprite()
	if sprite == null:
		return 0.0
	return SpriteBounds.world_box(sprite, sprite.global_transform).size.y


func _prop_name(caster: ShadowCaster) -> String:
	var owner_node := caster.get_parent()
	return owner_node.name if owner_node != null else caster.name


func _finish() -> void:
	print("")
	if _failures == 0:
		print("[PASS] arena shadow pivot: every check passed")
	else:
		print("[FAIL] arena shadow pivot: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## Scenery that casts a shadow but has authored no patch of floor, by name and
## once each. These are the props a footing-anchored map cannot help, so the check
## above is what says the fix reaches all of them rather than only the tents.
func _scenery_without_footing() -> Array[String]:
	var names: Dictionary = {}
	_collect_bare(root, names)
	var out: Array[String] = []
	for name: String in names:
		out.append(name)
	out.sort()
	return out


func _collect_bare(node: Node, into: Dictionary) -> void:
	var caster := node as ShadowCaster
	if caster != null and caster.get_ground_contact().y <= 0.0:
		var owner_node := caster.get_parent()
		# Only scenery. A figure, its weapon and anything it is carrying are placed
		# by the older path on purpose and are not what this is measuring.
		if owner_node != null and (owner_node.is_in_group(&"desert_prop")
				or owner_node.is_in_group(&"region_prop")):
			into[String(owner_node.name)] = true
	for child: Node in node.get_children():
		_collect_bare(child, into)


## Puts one of each hand-placed arena prop on the floor, so they are measured
## alongside the scattered scenery.
func _add_placed_props() -> void:
	var arena := root.get_tree().get_first_node_in_group(&"region_ground")
	var parent: Node = arena.get_parent() if arena != null else root.current_scene
	var at := Vector2(-900.0, 600.0)
	for path: String in ["res://Scenes/World/AmmoCrate.tscn",
			"res://Scenes/World/RewardChest.tscn"]:
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate() as Node2D
		node.global_position = at
		parent.add_child(node)
		at += Vector2(420.0, 0.0)
