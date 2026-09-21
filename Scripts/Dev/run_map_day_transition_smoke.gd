extends SceneTree
## Headless check of a run map ride: how fast a day-cycle tick is spent, how the
## world's darkness moves across it, and what the sun is doing while it does.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_day_transition_smoke.gd
## [/codeblock]
##
## [b]It watches a real ride frame by frame.[/b] The whole of the question is
## what the world looks like [i]during[/i] a tick rather than at either end of
## one, so this samples the ambient [CanvasModulate], the world clock and the
## sun every frame of a real three-day road and then measures the recording:
##
##   * the darkness moves in many small steps rather than one jump, and at
##     every one of them is exactly the blend of the two authored [DayStage]
##     colours the clock's own degree asks for - never lagging, overshooting
##     or left on the hour just departed;
##   * the sun never stands between two authored [SunStage]s - its rake is one
##     of the six exactly, at every sample;
##   * each tick lands on a period boundary, leaving the darkness exactly the
##     hour's own authored colour and the sun exactly that hour's own stage;
##   * a tick takes about as long as the map's own [RunMapTravel] is authored
##     to take.

const MAP_SCENE := "res://Scenes/World/Regions/DustCampRunMap.tscn"

var _failures: int = 0
## One sample per frame of the ride: the clock's degree and period, the colour
## the world was actually painted, and what the sun was doing.
var _samples: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var session: Node = root.get_node_or_null(^"RunSession")
	if session != null:
		session.call(&"begin", &"desert")
		session.call(&"choose_region", &"A")

	change_scene_to_file(MAP_SCENE)
	for _frame: int in range(8):
		await process_frame

	var director := _find("RunMapDirector") as RunMapDirector
	var view := _find("RunMapView") as RunMapView
	var travel := _find("RunMapTravel") as RunMapTravel
	var day := _find("DayCycleDirector") as DayCycleDirector
	var sun := _find("SunController") as SunController
	var clock: Node = root.get_node_or_null(^"WorldClock")
	var ambient := root.get_tree().get_first_node_in_group(&"ambient_modulate") \
		as CanvasModulate
	_ok(director != null and view != null and travel != null, "the run map opened")
	_ok(day != null and sun != null and ambient != null and clock != null,
		"it has a day cycle, a sun, a darkness and a world clock")
	if director == null or view == null or travel == null or day == null \
			or sun == null or ambient == null or clock == null:
		_finish()
		return

	print("--- before the ride ---")
	_ok(day.world_time_blends, "the darkness is allowed to flow between two hours")
	_ok(not sun.world_time_blends, "the sun is not - it steps between them")
	_check_at_rest(day, sun, ambient, clock, "standing still")

	# The longest road out of here, so the recording covers more than one tick.
	var link := _longest_road(director.get_graph())
	_ok(link != null, "there is a road to ride")
	if link == null:
		_finish()
		return
	var to_id := link.other_end(director.get_graph().current_id)
	print("--- riding a %d-day road ---" % link.day_cycles)

	var began := Time.get_ticks_msec()
	view.site_chosen.emit(to_id, link)
	var frames := 0
	while travel.is_travelling() and frames < 4000:
		frames += 1
		_samples.append({
			&"degree": float(clock.call(&"get_world_degree")),
			&"period": int(clock.call(&"get_time_period_index")),
			&"progress": float(clock.call(&"get_period_progress")),
			&"colour": ambient.color,
			&"sun_stage": sun.get_stage_index(),
			&"rake": sun.get_state().length_ratio,
			&"direction": sun.get_state().direction,
		})
		await process_frame
	var took := float(Time.get_ticks_msec() - began) / 1000.0

	print("--- how long it took ---")
	_check_pacing(travel, link, took)

	print("--- how the darkness moved ---")
	_check_darkness(day)

	print("--- what the sun did while it moved ---")
	_check_sun(sun)

	print("--- where it left things ---")
	_check_at_rest(day, sun, ambient, clock, "at the end of the ride")

	_finish()


## The world's darkness is exactly one authored [DayStage] colour, and the sun
## is exactly that same hour's authored [SunStage]. What must be true whenever
## the map is not mid-tick.
func _check_at_rest(day: DayCycleDirector, sun: SunController,
		ambient: CanvasModulate, clock: Node, when: String) -> void:
	var index := posmod(int(clock.call(&"get_time_period_index")), day.stages.size())
	var progress := float(clock.call(&"get_period_progress"))
	_ok(is_zero_approx(progress),
		"%s, the clock is exactly on a period boundary" % when,
		"%.4f into it" % progress)
	_ok(ambient.color.is_equal_approx(day.stages[index].ambient_colour),
		"%s, the darkness is this hour's own authored colour" % when,
		"%s against %s" % [ambient.color, day.stages[index].ambient_colour])
	_ok(sun.get_stage_index() == index,
		"%s, the sun is standing at this same hour" % when,
		"sun at %d, clock at %d" % [sun.get_stage_index(), index])
	_ok(is_equal_approx(sun.get_state().length_ratio,
			sun.stages[index].get_length_ratio()),
		"%s, the shadows are this hour's own authored length" % when,
		"%.3f against %.3f" % [sun.get_state().length_ratio,
			sun.stages[index].get_length_ratio()])


## A tick is the map's own authored step plus its authored hold, and the road's
## cost is unchanged by either.
func _check_pacing(travel: RunMapTravel, link: RunMapLink, took: float) -> void:
	# The pause is what separates one tick from the next, so there are one fewer
	# of them than there are ticks: the last beat ends in the arrival rather than
	# in a wait for a beat that is not coming - see
	# [method RunMapTravel._advance_step], which goes straight to ARRIVING on the
	# final tick.
	var holds := maxi(link.day_cycles - 1, 0)
	var expected := travel.step_duration * float(link.day_cycles) \
		+ travel.step_hold * float(holds) + travel.arrival_hold
	print("       %d ticks of %.2fs, %d pauses of %.2fs, plus %.2fs at the end"
		% [link.day_cycles, travel.step_duration, holds, travel.step_hold,
			travel.arrival_hold])
	_ok(absf(took - expected) < 0.45,
		"the ride took about as long as the map is authored to take",
		"%.2fs against %.2fs" % [took, expected])
	# The tick count is the road's, measured once by the generator, and nothing
	# about the pacing is allowed to change it.
	var crossings := 0
	for index: int in range(1, _samples.size()):
		if _samples[index][&"period"] != _samples[index - 1][&"period"]:
			crossings += 1
	_ok(crossings == link.day_cycles,
		"the ride crossed exactly as many hours as the road costs",
		"%d crossings on a %d-day road" % [crossings, link.day_cycles])


## The darkness flowed rather than jumping, and was never anything other than
## the colour this instant's clock reading implies.
##
## [b]The exactness check is the real one.[/b] How far the colour moves between
## two rendered frames is frame pacing - headless runs physics in bursts - so
## what is measured instead is that at every single sample the colour is
## [i]exactly[/i] the blend the clock's own degree asks for. A darkness that
## lagged, overshot, ran a tween of its own or was left on the hour just
## departed would fail this however smooth it looked.
func _check_darkness(day: DayCycleDirector) -> void:
	var distinct := {}
	var wrong := 0
	var worst := 0.0
	var biggest_step := 0.0
	var count := day.stages.size()

	for index: int in range(_samples.size()):
		var sample := _samples[index]
		distinct[sample[&"colour"]] = true
		if index > 0:
			biggest_step = maxf(biggest_step,
				_colour_gap(sample[&"colour"], _samples[index - 1][&"colour"]))

		var from_colour := day.stages[posmod(sample[&"period"], count)].ambient_colour
		var to_colour := day.stages[posmod(sample[&"period"] + 1, count)].ambient_colour
		var off := _colour_gap(
			sample[&"colour"], from_colour.lerp(to_colour, float(sample[&"progress"])))
		if index > 0:
			# [signal SceneTree.process_frame] fires before the nodes' own
			# [method Node._process], so a sample reads the clock as it stands
			# this frame against the colour that was painted from last frame's
			# reading. Either is the clock's honest answer; a darkness that
			# lagged further, overshot, or ran a tween of its own would match
			# neither.
			var was := _samples[index - 1]
			var was_from := day.stages[posmod(was[&"period"], count)].ambient_colour
			var was_to := day.stages[posmod(was[&"period"] + 1, count)].ambient_colour
			off = minf(off, _colour_gap(sample[&"colour"],
				was_from.lerp(was_to, float(was[&"progress"]))))
		worst = maxf(worst, off)
		if off > 0.004:
			wrong += 1

	_ok(distinct.size() > 12, "the darkness moved in many small steps, not one jump",
		"%d different colours over %d frames" % [distinct.size(), _samples.size()])
	_ok(wrong == 0,
		"at every frame it was exactly the colour the clock asks for",
		"%d frames were not, worst off by %.4f" % [wrong, worst])
	print("       %d colours over %d frames; never off the clock by more than %.5f"
		% [distinct.size(), _samples.size(), worst])
	print("       (the largest gap between two rendered frames was %.4f, which is "
		% biggest_step + "frame pacing rather than the blend)")


## The sun stepped. At no point was it standing between two authored hours -
## which is what "do not interpolate into a stale shadow state" asks for.
func _check_sun(sun: SunController) -> void:
	var off_stage := 0
	var seen := {}
	for sample: Dictionary in _samples:
		seen[sample[&"sun_stage"]] = true
		var matched := false
		for stage: SunStage in sun.stages:
			if is_equal_approx(float(sample[&"rake"]), stage.get_length_ratio()) \
					and sample[&"direction"].is_equal_approx(stage.get_direction()):
				matched = true
				break
		if not matched:
			off_stage += 1
	_ok(off_stage == 0,
		"the shadows were one of the six authored hours at every single frame",
		"%d frames were between two" % off_stage)
	_ok(seen.size() > 1, "the sun did move through the ride's hours",
		"%d hours seen" % seen.size())
	print("       the sun stood at %d authored hours across the ride" % seen.size())



func _colour_gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## The road out of here costing the most day cycles, so the recording covers
## more than one tick and the hand-over between two of them can be measured.
func _longest_road(graph: RunMapGraph) -> RunMapLink:
	var best: RunMapLink = null
	for link: RunMapLink in graph.links_of(graph.current_id):
		if best == null or link.day_cycles > best.day_cycles:
			best = link
	return best


func _finish() -> void:
	print("")
	if _failures == 0:
		print("[PASS] run map day transition: every check passed")
	else:
		print("[FAIL] run map day transition: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _find(wanted: String) -> Node:
	return _search(root, wanted)


func _search(node: Node, wanted: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == wanted:
		return node
	for child: Node in node.get_children():
		var found := _search(child, wanted)
		if found != null:
			return found
	return null
