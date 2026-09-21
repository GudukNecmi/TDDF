extends SceneTree
## Headless check of the run map's node distribution: how big a map is, what is
## on it, and where those things ended up.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/run_map_distribution_smoke.gd
## [/codeblock]
##
## [b]It measures a sample of whole runs, not one.[/b] Almost everything the
## distribution promises is a statement about runs in general - "a different
## number of points each time", "bandit camps less common than bandit groups",
## "a market and a saloon are not beside each other" - so a single map cannot
## confirm or deny any of it. [constant RUNS] maps are generated from the map's
## own authored [RunMapGenerator], every per-map rule is checked on each of
## them, and the rules about variety are checked across the sample.

const GENERATOR := "res://Resources/RunMap/dust_camp_run_map.tres"
## How many whole runs to lay out. Enough for the spread to mean something
## without the check taking longer than it is worth.
const RUNS := 60

var _failures: int = 0


func _initialize() -> void:
	var generator: RunMapGenerator = load(GENERATOR)
	if generator == null:
		print("[FAIL] the dust camp generator would not load")
		quit(1)
		return
	_ok(not generator.site_plans.is_empty(), "the generator has a node distribution")

	var graphs: Array[RunMapGraph] = []
	for run: int in range(RUNS):
		# A seed per run rather than 0, so a failure can be reproduced exactly.
		graphs.append(generator.generate(100000 + run))

	print("--- how big a map is ---")
	_check_size(generator, graphs)

	print("--- what is on it ---")
	_check_counts(generator, graphs)

	print("--- no two runs are the same ---")
	_check_variety(graphs)

	print("--- where the special points ended up ---")
	_check_spacing(generator, graphs)

	print("--- the map is still a map ---")
	_check_shape(graphs)

	print("")
	if _failures == 0:
		print("[PASS] run map distribution: every check passed")
	else:
		print("[FAIL] run map distribution: %d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


## Every map is inside the authored size band, and the band is actually used
## rather than every run coming out the same size.
func _check_size(generator: RunMapGenerator, graphs: Array[RunMapGraph]) -> void:
	var smallest := 99999
	var largest := -1
	var sizes := {}
	for graph: RunMapGraph in graphs:
		var count := graph.sites.size()
		smallest = mini(smallest, count)
		largest = maxi(largest, count)
		sizes[count] = true
	_ok(smallest >= generator.min_total_sites and largest <= generator.max_total_sites,
		"every map holds %d to %d points"
			% [generator.min_total_sites, generator.max_total_sites],
		"%d..%d" % [smallest, largest])
	_ok(sizes.size() >= 6, "maps are not all the same size",
		"%d different sizes over %d runs, %d..%d"
			% [sizes.size(), graphs.size(), smallest, largest])
	print("       %d..%d points, %d different sizes" % [smallest, largest, sizes.size()])


## Every promise each plan makes is kept on every map, and the kinds that are
## meant to be common are common.
func _check_counts(generator: RunMapGenerator, graphs: Array[RunMapGraph]) -> void:
	var unknown := 0
	var broken_exact := 0
	var broken_min := 0
	var broken_max := 0
	var totals := {}
	var missing := {}

	for graph: RunMapGraph in graphs:
		var counted := _count_kinds(graph)
		for kind: StringName in counted:
			totals[kind] = int(totals.get(kind, 0)) + int(counted[kind])
		unknown += int(counted.get(RunMapSite.KIND_UNKNOWN, 0))

		for plan: RunMapSitePlan in generator.site_plans:
			var have := int(counted.get(plan.kind, 0))
			if plan.exact_count >= 0:
				if have != plan.exact_count:
					broken_exact += 1
				continue
			if have < plan.min_count:
				broken_min += 1
			if plan.max_count >= 0 and have > plan.max_count:
				broken_max += 1
			if have <= 0:
				missing[plan.kind] = int(missing.get(plan.kind, 0)) + 1

	# Nothing landed in a stretch of the map its own plan rules out.
	var out_of_band := 0
	for graph: RunMapGraph in graphs:
		var last_row := 0
		for site: RunMapSite in graph.sites:
			last_row = maxi(last_row, site.row)
		for site: RunMapSite in graph.sites:
			for plan: RunMapSitePlan in generator.site_plans:
				if plan.kind != site.kind or plan.claims_northernmost:
					continue
				var along := float(site.row) / maxf(float(last_row), 1.0)
				if along < minf(plan.row_band.x, plan.row_band.y) - 0.001 \
						or along > maxf(plan.row_band.x, plan.row_band.y) + 0.001:
					out_of_band += 1
	_ok(out_of_band == 0, "no kind landed in a stretch of the map it is kept out of",
		"%d did" % out_of_band)

	_ok(unknown == 0, "no map leaves a point unclaimed",
		"%d unknown points over %d runs" % [unknown, graphs.size()])
	_ok(broken_exact == 0, "an exact count is exact on every map",
		"%d broken" % broken_exact)
	_ok(broken_min == 0, "every guaranteed minimum is met on every map",
		"%d short" % broken_min)
	_ok(broken_max == 0, "no kind ever exceeds its cap", "%d over" % broken_max)

	# The named shape of the distribution, stated as the brief states it.
	var group := int(totals.get(&"bandit_group", 0))
	var camp := int(totals.get(&"bandit_camp", 0))
	var event := int(totals.get(&"event", 0))
	var points := 0
	for graph: RunMapGraph in graphs:
		points += graph.sites.size()
	_ok(camp < group, "a bandit camp is less common than a bandit group",
		"%d camps against %d groups" % [camp, group])
	_ok(float(group) / float(points) > 0.15, "bandit groups are common",
		"%.0f%% of all points" % (100.0 * float(group) / float(points)))
	_ok(float(event) / float(points) > 0.10, "events are common",
		"%.0f%% of all points" % (100.0 * float(event) / float(points)))

	for plan: RunMapSitePlan in generator.site_plans:
		var absent := int(missing.get(plan.kind, 0))
		print("       %-16s %4d over %d runs, absent from %d"
			% [plan.kind, int(totals.get(plan.kind, 0)), graphs.size(), absent])


## The same generator twice is two different maps - what stops every run from
## feeling identical.
func _check_variety(graphs: Array[RunMapGraph]) -> void:
	var shapes := {}
	for graph: RunMapGraph in graphs:
		var line := ""
		for site: RunMapSite in graph.sites:
			line += String(site.kind).substr(0, 2)
		shapes[line] = true
	_ok(shapes.size() == graphs.size(), "no two runs deal the same map out",
		"%d different over %d runs" % [shapes.size(), graphs.size()])


## The spacing rules: the final boss is the northernmost point, no two points
## of one spacing group are on top of each other, and the high-value points are
## not all in one pocket of the map.
func _check_spacing(generator: RunMapGenerator, graphs: Array[RunMapGraph]) -> void:
	var north_broken := 0
	var too_close := 0
	var clustered := 0
	var pairs := 0
	var nearest_total := 0.0
	var nearest_worst := INF
	var nearest_furthest := 0.0
	var in_band := 0

	var north := _north_kind(generator)
	var specials := _special_kinds(generator)
	var groups := _spacing_groups(generator)
	var inner := generator.spacing_target * (1.0 - generator.spacing_tolerance)
	var outer := generator.spacing_target * (1.0 + generator.spacing_tolerance)

	for graph: RunMapGraph in graphs:
		# Exactly one final boss, and nothing further north than it.
		var boss: RunMapSite = null
		var found := 0
		for site: RunMapSite in graph.sites:
			if site.kind == north:
				boss = site
				found += 1
		if found != 1:
			north_broken += 1
		elif boss != null:
			for site: RunMapSite in graph.sites:
				if site.position.y < boss.position.y - 1.0:
					north_broken += 1
					break

		# Two points of one spacing group are never beside each other, and the
		# nearest pair of each group is measured against the authored band.
		for group_name: StringName in groups:
			var members: Array[RunMapSite] = []
			for site: RunMapSite in graph.sites:
				if groups[group_name].has(site.kind):
					members.append(site)
			for a: int in range(members.size()):
				var nearest := INF
				for b: int in range(members.size()):
					if a == b:
						continue
					nearest = minf(nearest,
						members[a].position.distance_to(members[b].position))
				if nearest == INF:
					continue
				pairs += 1
				nearest_total += nearest
				nearest_worst = minf(nearest_worst, nearest)
				nearest_furthest = maxf(nearest_furthest, nearest)
				if nearest < generator.spacing_minimum:
					too_close += 1
				if nearest >= inner and nearest <= outer:
					in_band += 1

		# No little corner of the map holds more than its share of the
		# high-value points.
		var high: Array[RunMapSite] = []
		for site: RunMapSite in graph.sites:
			if specials.has(site.kind):
				high.append(site)
		for a: int in range(high.size()):
			var near := 0
			for b: int in range(high.size()):
				if a == b:
					continue
				if high[a].position.distance_to(high[b].position) \
						<= generator.cluster_radius:
					near += 1
			if near > generator.max_specials_per_cluster:
				clustered += 1

	_ok(north_broken == 0, "every map has exactly one final boss, at its northern end",
		"%d broken" % north_broken)
	_ok(too_close == 0, "no two points of one kind are side by side",
		"%d closer than %.0f px" % [too_close, generator.spacing_minimum])
	_ok(clustered == 0, "no pocket of the map holds more than %d high-value points"
			% generator.max_specials_per_cluster, "%d crowded" % clustered)
	if pairs > 0:
		_ok(nearest_furthest < generator.spacing_target * 4.0,
			"nor are they pushed to opposite ends of the map",
			"the furthest nearest-neighbour is %.0f px against a %.0f px target"
				% [nearest_furthest, generator.spacing_target])
		print("       nearest same-group neighbour: %.0f px average, %.0f..%.0f, "
			% [nearest_total / float(pairs), nearest_worst, nearest_furthest]
			+ "%.0f%% inside the %.0f-%.0f band"
			% [100.0 * float(in_band) / float(pairs), inner, outer])


## The distribution did not break the graph it was dealt onto: the start is
## still the start, every point is still reachable, and the roads still cost
## what they measure.
func _check_shape(graphs: Array[RunMapGraph]) -> void:
	var unreachable := 0
	var bad_start := 0
	var priceless := 0
	var branches := 0
	var branch_points := 0
	for graph: RunMapGraph in graphs:
		if graph.get_site(graph.start_id).kind != RunMapSite.KIND_START:
			bad_start += 1
		unreachable += graph.sites.size() \
			- graph.reachable_from(graph.start_id).size()
		for link: RunMapLink in graph.links:
			if link.day_cycles <= 0:
				priceless += 1
		for site: RunMapSite in graph.sites:
			var out := graph.neighbours_of(site.id).size()
			if out > 1:
				branches += out
				branch_points += 1
	_ok(bad_start == 0, "the start is still the start", "%d broken" % bad_start)
	_ok(unreachable == 0, "every point is still reachable",
		"%d stranded" % unreachable)
	_ok(priceless == 0, "every road still costs whole day cycles",
		"%d unpriced" % priceless)
	_ok(branch_points > 0, "the map still branches",
		"%.1f roads out of a junction on average"
			% (float(branches) / maxf(float(branch_points), 1.0)))


func _count_kinds(graph: RunMapGraph) -> Dictionary:
	var counted := {}
	for site: RunMapSite in graph.sites:
		counted[site.kind] = int(counted.get(site.kind, 0)) + 1
	return counted


func _north_kind(generator: RunMapGenerator) -> StringName:
	for plan: RunMapSitePlan in generator.site_plans:
		if plan != null and plan.claims_northernmost:
			return plan.kind
	return RunMapSite.KIND_BOSS


func _special_kinds(generator: RunMapGenerator) -> Dictionary:
	var kinds := {}
	for plan: RunMapSitePlan in generator.site_plans:
		if plan != null and plan.is_special and not plan.claims_northernmost:
			kinds[plan.kind] = true
	return kinds


## Which kinds share each spacing band, as the generator's own plans name them.
func _spacing_groups(generator: RunMapGenerator) -> Dictionary:
	var groups := {}
	for plan: RunMapSitePlan in generator.site_plans:
		if plan == null or plan.spacing_group.is_empty():
			continue
		var kinds: Dictionary = groups.get(plan.spacing_group, {})
		kinds[plan.kind] = true
		groups[plan.spacing_group] = kinds
	return groups


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if condition:
		print("[ok]   %s" % what)
		return
	_failures += 1
	print("[FAIL] %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
