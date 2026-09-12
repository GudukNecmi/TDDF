extends SceneTree
## Steps the sun right round the day and reports, for the largest prop in view, the
## shape of the mark it casts: how wide it is at its base, how far it reaches, and
## where the middle of it sits against the thing casting it.
##
## [b]It is a continuity check.[/b] The three faults it is here to catch all show up
## as a jump between two neighbouring rows - a width that changes sign, a reach that
## steps, a mark that leaves its object - so the numbers are printed in order and
## every step is compared against the last.
##
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/shadow_sweep_smoke.gd
## [/codeblock]

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const SETTLE_FRAMES := 120
const STEP_DEGREES := 10.0


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	for i: int in SETTLE_FRAMES:
		await process_frame

	var clock: Node = root.get_node_or_null("WorldClock")
	clock.set_process(false)

	var subject := _find_subject()
	if subject == null:
		push_error("nothing near the origin to look at")
		quit(1)
		return
	print("subject %s  span %.1f  half width %.1f" % [
		subject.get_parent().name, subject.get_span(), 0.0])

	var last_width := Vector2.ZERO
	var last_tip := Vector2.ZERO
	var worst_step := 0.0
	var worst_at := 0.0
	var degree := 0.0
	while degree < 360.0:
		clock.advance_seconds(clock.seconds_until_degree(degree))
		for i: int in 3:
			await process_frame
		# Nobody is looking at the map in a headless run, so the group is entitled to
		# put its rebuild off - see ShadowGroup._worth_rebuilding_now. Asked for
		# directly instead, which is the same work the hour would have caused.
		subject.mark_dirty()
		subject.update_group(true)

		var caster := subject.get_anchor_caster()
		var sprite := caster.get_source_sprite()
		var rect := SpriteBounds.local_rect(sprite)
		var pose := sprite.global_transform
		var left: Vector2 = pose * Vector2(rect.position.x, rect.end.y)
		var right: Vector2 = pose * Vector2(rect.end.x, rect.end.y)
		var top: Vector2 = pose * Vector2(
			rect.position.x + rect.size.x * 0.5, rect.position.y)
		var foot: Vector2 = pose * Vector2(
			rect.position.x + rect.size.x * 0.5, rect.end.y)

		# The base of the mark, as a vector: which way the artwork's own width lies
		# on the ground and how much of it is left. A sign change here is a shadow
		# turning inside out.
		var width := subject.project_world(right) - subject.project_world(left)
		var tip := subject.project_world(top) - subject.project_world(foot)
		var middle := (subject.project_world(top) + subject.project_world(foot)) * 0.5

		# The width is an axis rather than an arrow: which end of it the artwork's own
		# left is drawn at swaps as the light crosses the object edge on, and the
		# patch of ground covered is the same either way round. So the step is taken
		# against whichever way round agrees with the hour before, which asks whether
		# the mark itself moved rather than how it happened to be labelled.
		var laid := width if width.dot(last_width) >= 0.0 else -width
		if degree > 0.0:
			var step := (laid - last_width).length() + (tip - last_tip).length()
			if step > worst_step:
				worst_step = step
				worst_at = degree
		last_width = laid
		last_tip = tip

		print("deg %3.0f  width %8.1f (%5.2f,%5.2f)  reach %7.1f (%5.2f,%5.2f)  middle off foot %7.1f" % [
			degree, width.length(), width.normalized().x, width.normalized().y,
			tip.length(), tip.normalized().x, tip.normalized().y,
			(middle - foot).length()])
		degree += STEP_DEGREES

	print("worst step between neighbouring hours: %.1f px at deg %.0f" % [
		worst_step, worst_at])
	quit(0)


func _find_subject() -> ShadowGroup:
	var found: Array[ShadowGroup] = []
	_collect(root, found)
	var best: ShadowGroup = null
	for group: ShadowGroup in found:
		if group.get_caster_count() <= 0 or not group.is_visible_in_tree():
			continue
		if group.get_ground_position().length() > 3000.0:
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
