extends SceneTree
## Looks at one World Map prop's shadow right round the day, brightly and close up,
## so the three correctness faults can be seen as well as measured.
##
## [codeblock]
## godot --path . --script res://Scripts/Dev/shadow_correctness_probe.gd
## [/codeblock]

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const SETTLE_FRAMES := 200
const OUT_DIR := "user://shadow_probe"
## How far from the map's origin the subject may stand. The staged spawner only
## puts scenery out near the viewer, so the choice is made among what is there.
const SEARCH_RADIUS := 3000.0

var _map: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_map = load(MAP_PATH).instantiate()
	root.add_child(_map)
	await process_frame
	await physics_frame
	for i: int in SETTLE_FRAMES:
		await process_frame

	var clock: Node = root.get_node_or_null("WorldClock")
	clock.set_process(false)

	# The world is lit for atmosphere, which is no use for looking at a shape.
	# Everything that darkens the picture is taken off, and nothing but the shadows
	# is left to see.
	_brighten()

	var subject := _find_subject()
	if subject == null:
		push_error("nothing standing near the origin to look at")
		quit(1)
		return
	var at := Vector2(-759.0, -4122.0)
	print("standing at %s next to %s" % [at, subject.get_parent().name])

	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	var camera := CameraController.get_active(_map)

	for degree: int in [0, 60, 90, 120, 180, 270]:
		await _look(clock, player, camera, at, subject, float(degree))

	quit(0)


func _brighten() -> void:
	for node: Node in root.get_tree().get_nodes_in_group(&"ambient_modulate"):
		var modulate := node as CanvasModulate
		if modulate != null:
			modulate.color = Color(1.0, 1.0, 1.0)
			modulate.set_process(false)
			modulate.set_process_mode(Node.PROCESS_MODE_DISABLED)
	for name: String in ["WorldMap/Fog", "WorldMap/FogOverlay"]:
		var node := _map.get_node_or_null(NodePath(name)) as CanvasItem
		if node != null:
			node.visible = false


func _look(clock: Node, player: Node2D, camera: Camera2D, at: Vector2,
		subject: ShadowGroup, degree: float) -> void:
	clock.advance_seconds(clock.seconds_until_degree(degree))
	for i: int in 10:
		if player != null:
			player.global_position = at
		await process_frame
		if camera != null:
			camera.global_position = at
			camera.reset_smoothing()
	await RenderingServer.frame_post_draw

	var sun := root.get_tree().get_first_node_in_group(&"sun") as SunController
	var state := sun.get_state()
	print("deg %3.0f  %-8s  dir %-24s rake %5.2f  anchor %.2f  reach %6.1f  top %6.1f" % [
		degree, state.stage_name, str(state.direction), state.length_ratio,
		state.shadow_length_anchor, subject.get_reach(),
		subject.get_reach() / maxf(subject.get_rake(), 0.0001)])
	_report_shapes(degree)

	var image := root.get_texture().get_image()
	print("      saved %s/deg_%03d.png (%d)" % [
		OUT_DIR, int(degree), image.save_png("%s/deg_%03d.png" % [OUT_DIR, int(degree)])])


## What every visible shadow near the origin is actually doing, as two numbers per
## prop averaged over the lot.
##
## [b]gap[/b] is where the shadow of the artwork's own contact point lands against
## where that point genuinely is. A shadow is attached when it is near zero; it is
## the whole of the second fault.
##
## [b]area[/b] is how much ground the finished silhouette covers, against how much
## the artwork itself covers. Near zero is a shadow that has collapsed onto a line -
## the streak, and the whole of the first and third faults.
func _report_shapes(_degree: float) -> void:
	var found: Array[ShadowGroup] = []
	_collect(root, found)
	var gap_worst: float = 0.0
	var gap_total: float = 0.0
	var area_worst: float = INF
	var area_total: float = 0.0
	var counted: int = 0
	var worst_name: String = "-"
	for group: ShadowGroup in found:
		if group.get_caster_count() <= 0 or not group.is_visible_in_tree():
			continue
		if group.get_ground_position().length() > SEARCH_RADIUS:
			continue
		var caster := group.get_anchor_caster()
		if caster == null:
			continue
		var sprite := caster.get_source_sprite()
		if sprite == null or sprite.texture == null:
			continue

		# Where the artwork meets the floor, and where its own shadow puts it. The
		# contact point is at height zero, so a correct projection leaves it exactly
		# where it is and only the authored pull moves it.
		var rect := SpriteBounds.local_rect(sprite)
		var pose := sprite.global_transform
		var contact: Vector2 = pose * Vector2(
			rect.position.x + rect.size.x * 0.5, rect.end.y)
		var gap := group.project_world(contact).distance_to(contact)
		gap_total += gap
		if gap > gap_worst:
			gap_worst = gap
			worst_name = str(group.get_parent().name)

		# The four corners of the artwork through the projection, against the four
		# corners as drawn. Area, so a shape squashed onto a line reads as zero
		# however long it still is.
		var corners := SpriteBounds.global_corners(sprite)
		var drawn := _area(corners[0], corners[1], corners[2], corners[3])
		var cast_area := _area(
			group.project_world(corners[0]), group.project_world(corners[1]),
			group.project_world(corners[2]), group.project_world(corners[3]))
		var ratio := cast_area / maxf(drawn, 0.001)
		area_total += ratio
		area_worst = minf(area_worst, ratio)
		counted += 1

	if counted == 0:
		return
	print("      %d props: gap mean %.1f worst %.1f (%s) | area mean %.2f worst %.2f" % [
		counted, gap_total / float(counted), gap_worst, worst_name,
		area_total / float(counted), area_worst])
	_report_biggest()


## The three biggest things in view, in full. A large prop is where a wrong ground
## line shows up, because the error is a height and a height is raked out by the
## hour into a displacement many times its own size.
func _report_biggest() -> void:
	var found: Array[ShadowGroup] = []
	_collect(root, found)
	var near: Array[ShadowGroup] = []
	for group: ShadowGroup in found:
		if group.get_caster_count() > 0 and group.is_visible_in_tree() \
				and group.get_ground_position().length() <= 9000.0:
			near.append(group)
	near.sort_custom(func(a: ShadowGroup, b: ShadowGroup) -> bool:
		return a.get_span() > b.get_span())

	for i: int in mini(5, near.size()):
		var group: ShadowGroup = near[i]
		var caster := group.get_anchor_caster()
		var sprite: Sprite2D = null if caster == null else caster.get_source_sprite()
		if sprite == null:
			continue
		# top = (base + span) * height_scale, and the rake is reach over top, so the
		# lift the group believes the object has can be read back out of the two.
		var top := group.get_reach() / maxf(group.get_rake(), 0.000001)
		var lift := top - group.get_span()
		var rect := SpriteBounds.local_rect(sprite)
		var pose := sprite.global_transform
		var contact: Vector2 = pose * Vector2(
			rect.position.x + rect.size.x * 0.5, rect.end.y)
		var ground := group.get_ground_position()
		print("        %-16s span %6.1f lift %7.1f reach %6.1f | ground %s art foot %s slide %s" % [
			str(_owner_name(group)), group.get_span(), lift, group.get_reach(),
			str(ground.round()), str(contact.round()),
			str((group.project_world(contact) - contact).round())])


func _owner_name(group: ShadowGroup) -> String:
	var node := group.get_parent()
	while node != null and node.name.begins_with("Shadow"):
		node = node.get_parent()
	return "-" if node == null else str(node.name)


func _area(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	return absf((b - a).cross(d - a)) * 0.5 + absf((b - c).cross(d - c)) * 0.5


## The tallest thing standing near the origin - whatever the scatter happened to
## put there. A tall prop shows a flip, a detached footing and a collapsed midday
## shape more plainly than a bone lying flat does.
func _find_subject() -> ShadowGroup:
	var found: Array[ShadowGroup] = []
	_collect(root, found)
	var best: ShadowGroup = null
	for group: ShadowGroup in found:
		if group.get_caster_count() <= 0 or not group.is_visible_in_tree():
			continue
		if group.get_ground_position().length() > SEARCH_RADIUS:
			continue
		if best == null or group.get_span() > best.get_span():
			best = group
	return best


func _collect(node: Node, into: Array[ShadowGroup]) -> void:
	var group := node as ShadowGroup
	if group != null:
		into.append(group)
	for child: Node in node.get_children():
		_collect(child, into)
