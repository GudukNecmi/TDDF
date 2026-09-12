extends SceneTree
## Headless A/B check of the World Map's static shadow cache and its view cull.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_map_shadow_cache_smoke.gd
## [/codeblock]
##
## Builds the real Dust Camp World Map three times and turns the world clock by
## hand at a fixed rate, so every run covers exactly the same span of world time.
## The first run publishes every frame to every shadow on the map - the way the sun
## behaved before any of this existed; the second adds
## [member SunController.republish_threshold_degrees]; the third adds
## [member SunController.cull_static_rebuilds] as well, which is what the map is
## actually authored with.
##
## [b]What it is really checking is the last column.[/b] The saving is only worth
## anything if a shadow the player can see is still right, so every frame it walks
## the static groups that are genuinely on screen and measures how far their
## shadows lie from where the live sun says they should - the cull is only correct
## if that number stays inside the publish threshold no matter how much of the map
## is being skipped.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
## Frames of settling, so the staged prop spawner has finished putting the map out
## before anything is counted.
const SETTLE_FRAMES := 240
## Frames measured, at [constant STEP_SECONDS] each - 600 frames of a 0.25
## second-per-degree clock is 40 degrees of world time, most of a period.
const FRAMES := 600
const STEP_SECONDS := 1.0 / 60.0
## How far the player is walked each frame while the clock turns, so the view keeps
## moving and scenery is genuinely culled and handed back over the run.
const WALK := Vector2(9.0, 3.0)

var _emits: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var authored: Dictionary = await _authored()
	print("map authored with threshold %.2f deg, view cull %s, margin %.0f px" % [
		authored["threshold"], authored["cull"], authored["margin"]])

	var runs: Array[Dictionary] = []
	runs.append(await _measure("every frame ", 0.0, false))
	runs.append(await _measure("cached      ", authored["threshold"], false))
	runs.append(await _measure("cached+culled", authored["threshold"], authored["cull"]))

	print("")
	print("%-13s  %9s  %14s  %13s  %10s  %8s  %11s" % [
		"", "publishes", "groups rebuilt", "parts rebuilt", "measure us",
		"apply us", "seen drift"])
	for row: Dictionary in runs:
		print("%-13s  %9d  %14d  %13d  %10d  %8d  %8.4f deg" % [
			row["label"], row["emits"], row["groups"], row["parts"],
			row["measure"], row["apply"], row["drift"]])
		if row["drift"] > 1.0:
			print("               worst: %s" % row["worst"])

	var base: Dictionary = runs[0]
	var cached: Dictionary = runs[1]
	var culled: Dictionary = runs[2]
	print("")
	print("static groups on the map: %d, most on screen at once: %d" % [
		culled["tracked"], culled["seen"]])
	print("group rebuilds cut %.1fx by the cache, %.1fx by the cache and the cull" % [
		float(base["groups"]) / maxf(float(cached["groups"]), 1.0),
		float(base["groups"]) / maxf(float(culled["groups"]), 1.0)])
	print("shadow work per frame: %.2f ms -> %.2f ms -> %.2f ms" % [
		_ms_per_frame(base), _ms_per_frame(cached), _ms_per_frame(culled)])

	var ok := true
	if culled["groups"] >= cached["groups"]:
		push_error("FAIL: the cull did not reduce the rebuilds at all")
		ok = false
	if culled["seen"] <= 0:
		push_error("FAIL: no static shadow was ever on screen to check")
		ok = false
	# The whole promise of the cull: what the player can see is no more out of date
	# with the cull on than it was with the cull off.
	if culled["drift"] > authored["threshold"]:
		push_error("FAIL: a shadow on screen was %.4f deg stale, past the %.2f deg threshold" % [
			culled["drift"], authored["threshold"]])
		ok = false
	if culled["drift"] > cached["drift"] + 0.0001:
		push_error("FAIL: the cull made an on-screen shadow staler than the cache alone did")
		ok = false
	print("RESULT: %s" % ("ok" if ok else "failed"))
	quit(0 if ok else 1)


func _ms_per_frame(row: Dictionary) -> float:
	return (float(row["measure"]) + float(row["apply"])) / 1000.0 / float(FRAMES)


## Reads what the map is actually authored with, so the A runs can be given the old
## values and still be compared against it.
func _authored() -> Dictionary:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	var sun := _find_sun()
	var out := {
		"threshold": sun.republish_threshold_degrees,
		"cull": sun.cull_static_rebuilds,
		"margin": sun.static_rebuild_margin,
	}
	map.free()
	await process_frame
	return out


func _measure(label: String, threshold: float, cull: bool) -> Dictionary:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame
	for i: int in SETTLE_FRAMES:
		await process_frame

	var sun := _find_sun()
	sun.republish_threshold_degrees = threshold
	sun.cull_static_rebuilds = cull

	# Turned by hand at a fixed rate, so every run covers the same world time
	# whatever the headless frame rate happens to do.
	var clock: Node = root.get_node_or_null("WorldClock")
	clock.set_process(false)

	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	var groups := _static_groups()
	var drift: float = 0.0
	var worst: String = "-"
	var seen: int = 0

	_emits = 0
	sun.sun_updated.connect(_on_sun_updated)
	ShadowGroup.probe.fill(0.0)

	for i: int in FRAMES:
		clock.advance_seconds(STEP_SECONDS)
		if player != null:
			player.global_position += WALK
		await process_frame

		# Only what is genuinely on screen. A shadow the cull has put off is
		# supposed to be out of date - the test is that it is never out of date
		# while anybody can look at it.
		var on_screen := 0
		var view := sun.get_rebuild_view()
		for group: ShadowGroup in groups:
			if not is_instance_valid(group) or not group.is_visible_in_tree():
				continue
			var ground := group.get_ground_position()
			if view.size.x > 0.0 and not view.has_point(ground):
				continue
			on_screen += 1
			var want := sun.get_shadow_direction_at(ground)
			var got := group.get_shadow_direction()
			if want.is_zero_approx() or got.is_zero_approx():
				continue
			var off := absf(rad_to_deg(got.angle_to(want)))
			if off > drift:
				drift = off
				worst = "%s (%d parts, %s, %s)" % [
					group.get_parent().name, group.get_caster_count(),
					"processing" if group.is_processing() else "static",
					group.get_ground_position().round()]
		seen = maxi(seen, on_screen)

	sun.sun_updated.disconnect(_on_sun_updated)
	var result := {
		"label": label,
		"emits": _emits,
		"groups": int(ShadowGroup.probe[6]),
		"parts": int(ShadowGroup.probe[7]),
		"measure": int(ShadowGroup.probe[1]),
		"apply": int(ShadowGroup.probe[2]),
		"drift": drift,
		"seen": seen,
		"tracked": groups.size(),
		"worst": worst,
	}
	clock.set_process(true)
	map.free()
	await process_frame
	return result


func _on_sun_updated(_state: SunState) -> void:
	_emits += 1


func _find_sun() -> SunController:
	return root.get_tree().get_first_node_in_group(&"sun") as SunController


## Every shadow group on the map that has nothing dynamic in it - the ones that
## only ever repaint because the sun said so, which are what the cache is for.
func _static_groups() -> Array[ShadowGroup]:
	var found: Array[ShadowGroup] = []
	_collect(root, found)
	return found


func _collect(node: Node, into: Array[ShadowGroup]) -> void:
	var group := node as ShadowGroup
	if group != null and not group.is_processing() and group.get_caster_count() > 0:
		into.append(group)
	for child: Node in node.get_children():
		_collect(child, into)
