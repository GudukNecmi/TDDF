class_name RunMapGenerator
extends Resource
## Lays out a run map: where its points sit, which of them are joined, and how
## many day cycles each road costs.
##
## [b]Every number here is a map's own.[/b] The generator is a resource dropped
## onto a run map scene rather than a script with the desert's shape written into
## it, so a second region is a second [code].tres[/code] with wider rows, longer
## roads or more branching and nothing in this file to edit. See
## [member RunMapDirector.generator].
##
## [b]How long a road is, is measured - not counted.[/b] The brief's rule is the
## whole of [method day_cycles_for]: positions are generated [i]around[/i] the
## authored target distances in [member band_distances], the real geometric
## distance between two joined points is then measured, and the road is put in the
## nearest band. A distance that is not within [member band_tolerance] of any band
## is refused outright rather than rounded into one - which is what stops two
## three-day roads from being wildly different lengths while still letting a
## three-day road be meaningfully longer than a two-day one. Where refusing would
## leave a point stranded, the point is [i]moved[/i] until its distance lands on a
## band exactly (see [method _snap_to_band]), rather than the band being stretched
## to fit it.
##
## [b]How many bands there are is data too.[/b] A road's cost is its band's index
## plus one, so [member band_distances] holding three entries is what makes one,
## two and three day cycles the only costs; a fourth entry is a four-day road with
## no code change anywhere.
##
## [b]What is at each point is dealt out here too.[/b] The layout is only half
## of a run map: the other half is which of the twelve kinds of place each point
## turns out to be, and that is [method _assign_kinds], run once over the
## finished graph as the last thing [method generate] does. It is driven by
## [member site_plans] - one [RunMapSitePlan] per kind, carrying its own
## guaranteed count, its share of the weighted fill and how much room it wants
## around it - so the distribution is authored in the inspector beside the
## layout numbers rather than written into this file. A map is a different size
## every run as well as a different shape; see [member min_total_sites].
##
## [b]The rows are a scaffold, not a ladder.[/b] Points are laid out in rows
## running south to north so the map has a direction, but every row is shifted,
## jittered and differently populated, roads are made sideways and two rows at a
## time as well as forward, and the graph handed back is undirected - so a route
## may run northeast, northwest or briefly back on itself wherever the layout
## happened to allow it. Nothing downstream reads a row as permission to move.

@export_group("How big")
## Fewest and most points a run map may hold, counting the start's and the
## boss's. [b]A total is rolled inside this band for every run[/b] and the rows
## are then sized to add up to it, so two runs of the same region are not the
## same map at a different seed - one is a dense forty-eight-point sprawl and
## the next a spare thirty-six.
@export var min_total_sites: int = 35
@export var max_total_sites: int = 50
## Fewest and most rows the map is laid out in, counting the start's and the
## boss's - the length of a run. Rolled per run like the total, and then
## reconciled with it: a row count that could not hold the total within
## [member min_row_sites] and [member max_row_sites] is moved until it can.
@export var min_row_count: int = 10
@export var max_row_count: int = 13
## Fewest points in a row between the start and the boss.
@export var min_row_sites: int = 3
## Most points in a row. This is what makes the map wide.
@export var max_row_sites: int = 5

@export_group("Road length")
## The target distance of a road costing one day cycle, two, three, and so on -
## in map pixels, shortest first, one entry per cost. [b]This array is the whole
## of the travel-length system[/b]: see the class notes.
@export var band_distances: PackedFloat32Array = PackedFloat32Array([340.0, 590.0, 840.0])
## How far from a band's target distance a road may measure and still be counted
## as that band, as a fraction of the target. A road outside every band is
## refused. 0.16 means a three-day road is always within ±16% of every other
## three-day road on the map.
@export_range(0.0, 0.5, 0.01) var band_tolerance: float = 0.16

@export_group("Layout")
## How much of the chosen band's distance a row gap takes up vertically, as a
## range. Kept below 1 so that the sideways offset between two points has room to
## make up the rest of the distance without pushing it out of the band - which is
## what "generate positions around those target distances" means in practice.
@export var row_gap_fraction := Vector2(0.82, 0.96)
## How far apart the points in one row are laid out, before jitter.
@export var column_spacing: float = 300.0
## How far a point may wander sideways from its column.
@export var column_jitter: float = 90.0
## How far a whole row may slide east or west. What stops the map reading as a
## grid.
@export var row_shift_jitter: float = 170.0
## How far a point may wander north or south of its own row's line. What stops
## the rows from being perfectly aligned.
@export var row_tilt_jitter: float = 110.0

@export_group("Branching")
## Fewest roads a point sends on to the next row.
@export var min_forward_links: int = 1
## Most roads a point sends on to the next row - the widest branch the map can
## offer.
@export var max_forward_links: int = 4
## The chance of taking one more forward road than the last, rolled repeatedly up
## to [member max_forward_links]. Higher is a busier, less linear map.
@export_range(0.0, 1.0, 0.01) var extra_forward_chance: float = 0.55
## The chance of joining two neighbouring points in the same row - a sideways
## move, and a way for two routes to meet again without either going north.
@export_range(0.0, 1.0, 0.01) var sideways_link_chance: float = 0.3
## The chance of joining a point to one two rows ahead, where the distance allows
## it - a long road that skips a row.
@export_range(0.0, 1.0, 0.01) var skip_link_chance: float = 0.22
## Most roads any one point may have, counting every direction. A cap on how
## tangled a junction can get.
@export var max_links_per_site: int = 5

@export_group("Fog")
## Whether the boss at the northern end is known from the moment the map opens.
##
## On, and it is the one landmark the fog does not cover: the run is a ride
## towards a boss the player can see waiting at the top of the map, and every
## other point between here and there is an unknown one. Off, the boss is fogged
## like everything else and the map's far end is simply the last unknown point.
@export var boss_known_from_the_start: bool = true

@export_group("What is where")
## Every kind of place this map deals out, one [RunMapSitePlan] each. [b]This
## array is the whole of the node distribution[/b] - see [method _assign_kinds]
## and the class notes. Left empty every point stays
## [constant RunMapSite.KIND_UNKNOWN], which is what a map opened for layout
## tuning wants.
@export var site_plans: Array[RunMapSitePlan] = []
## How far apart two points sharing a [member RunMapSitePlan.spacing_group]
## prefer to sit, in map pixels. Neither beside each other nor at opposite ends
## of the map: this is the middle the placement aims for.
@export var spacing_target: float = 1600.0
## How far either side of [member spacing_target] counts as right, as a fraction
## of it. Inside the band a placement is not penalised at all; outside it, the
## penalty grows with the distance from the band - so "a moderate distance" is a
## band with slack rather than one number to hit.
@export_range(0.0, 1.0, 0.01) var spacing_tolerance: float = 0.35
## The distance under which two points of the same spacing group count as
## directly beside each other, whatever the band says. Below this the placement
## is penalised heavily rather than refused, so a map too small to honour the
## spacing still gets everything it promised.
@export var spacing_minimum: float = 820.0
## The largest share of a map's points that may be places wanting room around
## them - the high-value ones and anything in a spacing band. [b]It is what
## keeps the spacing honourable on a small map[/b]: a thirty-five point map is
## no wider than a fifty point one, so filling both with the same number of
## markets and saloons would leave the smaller one with nowhere to put them
## that is not beside something else. Guaranteed counts are never refused by
## this - only the weighted fill above them - so a small map has fewer extra
## services rather than fewer than it promised.
@export_range(0.05, 1.0, 0.01) var max_special_share: float = 0.32
## How many times over the finished map the spacing is repaired by trading a
## badly placed special point with an ordinary one - see
## [method _repair_spacing]. 0 leaves the map exactly as the placement pass laid
## it out; each round only ever improves it and stops early once nothing can be
## improved, so a higher number costs nothing on a map that is already right.
@export_range(0, 12, 1) var repair_rounds: int = 4

## How close two high-value points have to be to count as the same little corner
## of the map - see [member RunMapSitePlan.is_special].
@export var cluster_radius: float = 950.0
## How many high-value points may sit inside one [member cluster_radius] before
## another one there is penalised. What stops the market, the saloon and the
## treasure from all landing in the same pocket.
@export var max_specials_per_cluster: int = 2
## How hard the two rules above push. The placement is always a preference and
## never a refusal - there is always a best spot - but a rule worth more than
## [member placement_slack] is in practice absolute wherever the map has room
## to honour it.
@export var spacing_penalty: float = 150.0
@export var crowding_penalty: float = 1200.0
## How much worse than the best available spot a point may score and still be
## picked. [b]This is what stops two runs of the same map shape from laying out
## their markets identically[/b]: every spot the spacing rules are equally happy
## with is drawn from at random, rather than the single best being taken every
## time. Kept below [member spacing_penalty], so a spot that breaks a rule is
## never drawn while one that keeps it exists. 0 is strictly the best spot every
## time.
@export var placement_slack: float = 40.0

@export_group("Generation")
## How many whole maps to try before handing back the best of a bad lot. A map is
## rejected when the boss cannot be reached from the start.
@export var attempts: int = 24


## Makes a map. [param map_seed] of 0 asks for a random one, which is what a real
## run does; any other value makes exactly the same map every time, which is what
## a smoke check and a bug report want.
func generate(map_seed: int = 0) -> RunMapGraph:
	var rng := RandomNumberGenerator.new()
	if map_seed == 0:
		rng.randomize()
		map_seed = int(rng.seed)
	rng.seed = map_seed

	var last: RunMapGraph = null
	for attempt: int in range(maxi(attempts, 1)):
		var graph := _lay_out(rng)
		last = graph
		if _is_playable(graph):
			graph.seed = map_seed
			_prune_unreachable(graph)
			_assign_kinds(graph, rng)
			return graph

	# Every attempt failed to join the start to the boss, which means the numbers
	# authored on this resource cannot make a map - too tight a tolerance against
	# too wide a row gap, most likely. The last attempt is handed back anyway so
	# the map screen has something to draw and the warning says which knob to turn.
	push_warning("RunMapGenerator: no attempt joined the start to the boss - "
		+ "check band_distances against row_gap_fraction and band_tolerance.")
	if last != null:
		last.seed = map_seed
		_assign_kinds(last, rng)
	return last


## How many day cycles a road of [param distance] costs: the index of the nearest
## band plus one, or 0 for a distance that is not within [member band_tolerance]
## of any band at all - which every caller reads as "do not make this road".
##
## [b]This is the one place a length becomes a duration[/b], so the map screen,
## the travel itself and any later system that wants to price a road all read the
## same answer rather than each rounding the distance their own way.
func day_cycles_for(distance: float) -> int:
	var best := -1
	var best_error := INF
	for index: int in range(band_distances.size()):
		var band := band_distances[index]
		if band <= 0.0:
			continue
		var error := absf(distance / band - 1.0)
		if error < best_error:
			best_error = error
			best = index
	if best < 0 or best_error > band_tolerance:
		return 0
	return best + 1


## The target distance a road of [param distance] is closest to, whether or not
## it is close enough to be allowed. What [method _snap_to_band] moves a point
## onto.
func nearest_band(distance: float) -> float:
	var best := 0.0
	var best_error := INF
	for band: float in band_distances:
		if band <= 0.0:
			continue
		var error := absf(distance / band - 1.0)
		if error < best_error:
			best_error = error
			best = band
	return best


# --- Laying one map out ---------------------------------------------------------

func _lay_out(rng: RandomNumberGenerator) -> RunMapGraph:
	var graph := RunMapGraph.new()
	var rows := _place_sites(graph, rng)

	for row: int in range(rows.size() - 1):
		_link_forward(graph, rows[row], rows[row + 1], rng)
		_repair_inbound(graph, rows[row], rows[row + 1], rng)
		_sort_row_by_x(graph, rows[row + 1])

	for row: int in range(rows.size()):
		_link_sideways(graph, rows[row], rng)
		if row + 2 < rows.size():
			_link_skipping(graph, rows[row], rows[row + 2], rng)

	_remeasure(graph)
	graph.rebuild_index()
	graph.current_id = graph.start_id
	graph.move_to(graph.start_id)
	if boss_known_from_the_start:
		graph.reveal(graph.boss_id)
	return graph


## How many points each row of one map gets, start's and boss's rows included.
##
## [b]The total is rolled first and the rows are then made to add up to it.[/b]
## A run map is not always the same size - see [member min_total_sites] - so the
## row count and the total are rolled independently and then reconciled: the row
## count is nudged until it is one that could hold the total at all, the interior
## rows start at [member min_row_sites] each, and the points left over are handed
## out one at a time to rows chosen at random. That last part is what makes the
## rows unevenly populated, which is what keeps the map from reading as a grid.
func _plan_rows(rng: RandomNumberGenerator) -> PackedInt32Array:
	var low := maxi(min_row_sites, 1)
	var high := maxi(max_row_sites, low)

	var rows := rng.randi_range(
		maxi(min_row_count, 3), maxi(max_row_count, maxi(min_row_count, 3)))
	var wanted := rng.randi_range(
		maxi(min_total_sites, 3), maxi(max_total_sites, maxi(min_total_sites, 3)))

	# The start's row and the boss's hold one point each, so only the rows
	# between them take a share of what is left.
	var interior_rows := maxi(rows - 2, 1)
	var interior := wanted - 2
	# A row count that cannot hold the total is moved rather than the total being
	# clipped, so the size band is honoured and the length of the run gives way.
	while interior > interior_rows * high and interior_rows < 64:
		interior_rows += 1
	while interior < interior_rows * low and interior_rows > 1:
		interior_rows -= 1
	interior = clampi(interior, interior_rows * low, interior_rows * high)

	var sizes := PackedInt32Array()
	sizes.append(1)
	for _row: int in range(interior_rows):
		sizes.append(low)
	sizes.append(1)

	var spare := interior - interior_rows * low
	var room := PackedInt32Array()
	for index: int in range(1, interior_rows + 1):
		room.append(index)
	while spare > 0 and not room.is_empty():
		var pick := rng.randi_range(0, room.size() - 1)
		var row_index := room[pick]
		sizes[row_index] += 1
		spare -= 1
		if sizes[row_index] >= high:
			room.remove_at(pick)
	return sizes


## Every point on the map, row by row, with the start alone at the south end and
## the boss alone at the north.
func _place_sites(graph: RunMapGraph, rng: RandomNumberGenerator) -> Array:
	var rows: Array = []
	var sizes := _plan_rows(rng)
	var total := sizes.size()
	var y := 0.0
	var previous_centre := 0.0

	for row: int in range(total):
		var count := maxi(sizes[row], 1)

		if row > 0:
			var band := band_distances[rng.randi_range(0, maxi(band_distances.size() - 1, 0))]
			y -= band * rng.randf_range(row_gap_fraction.x, row_gap_fraction.y)

		var span := float(count - 1) * column_spacing
		var centre := previous_centre + rng.randf_range(-row_shift_jitter, row_shift_jitter)
		if row == 0 or row == total - 1:
			# The start and the boss sit on the line the map as a whole runs along,
			# so the run reads as beginning at the bottom and ending at the top
			# rather than off to one side.
			centre = previous_centre
		previous_centre = centre

		var ids := PackedInt32Array()
		for index: int in range(count):
			var at := Vector2(
				centre - span * 0.5 + float(index) * column_spacing
					+ rng.randf_range(-column_jitter, column_jitter),
				y + rng.randf_range(-row_tilt_jitter, row_tilt_jitter))
			if count == 1:
				at.x = centre
			var kind := RunMapSite.KIND_UNKNOWN
			if row == 0:
				kind = RunMapSite.KIND_START
			elif row == total - 1:
				kind = RunMapSite.KIND_BOSS
			ids.append(graph.add_site(RunMapSite.make(-1, at, row, kind)))
		rows.append(ids)

	graph.start_id = rows[0][0]
	graph.boss_id = rows[rows.size() - 1][0]
	return rows


## Roads from every point in one row on to the next. Each point takes at least
## [member min_forward_links] and rolls for more; the nearest allowed partner is
## always taken, and the rest are picked at random from those left, so branches
## fan out irregularly instead of always going to the two nearest.
func _link_forward(graph: RunMapGraph, from_row: PackedInt32Array,
		to_row: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for a: int in from_row:
		var allowed := _allowed_partners(graph, a, to_row)
		if allowed.is_empty():
			# Nothing in the next row is a legal distance away. Rather than leave
			# this point with nowhere to go, the nearest one is moved onto a band -
			# preferring one nothing has reached yet, since moving a point changes
			# the length of every road already made to it.
			var nearest := _nearest_unreached_in(graph, a, to_row)
			if nearest < 0:
				nearest = _nearest_in(graph, a, to_row)
			if nearest < 0:
				continue
			_snap_to_band(graph, a, nearest)
			allowed = _allowed_partners(graph, a, to_row)
			if allowed.is_empty():
				continue

		var wanted := clampi(min_forward_links, 1, maxi(max_forward_links, 1))
		while wanted < max_forward_links and rng.randf() < extra_forward_chance:
			wanted += 1
		wanted = mini(wanted, allowed.size())

		_join(graph, a, allowed[0])
		allowed.remove_at(0)
		for _step: int in range(wanted - 1):
			if allowed.is_empty():
				break
			var pick := rng.randi_range(0, allowed.size() - 1)
			_join(graph, a, allowed[pick])
			allowed.remove_at(pick)


## Any point in the next row that nothing reached is joined to the nearest point
## behind it, moving it onto a band first so the road is a legal length. This is
## what guarantees the map has no dead row and no unreachable point.
func _repair_inbound(graph: RunMapGraph, from_row: PackedInt32Array,
		to_row: PackedInt32Array, _rng: RandomNumberGenerator) -> void:
	for b: int in to_row:
		if _has_link_into(graph, b, from_row):
			continue
		var a := _nearest_in(graph, b, from_row)
		if a < 0:
			continue
		if day_cycles_for(_distance(graph, a, b)) <= 0:
			_snap_to_band(graph, a, b)
		_join(graph, a, b)


## Roads between neighbouring points in the same row: the map's sideways moves,
## and the cheapest way for two routes to meet again.
func _link_sideways(graph: RunMapGraph, row: PackedInt32Array,
		rng: RandomNumberGenerator) -> void:
	for index: int in range(row.size() - 1):
		if rng.randf() >= sideways_link_chance:
			continue
		_join(graph, row[index], row[index + 1])


## Roads that skip a whole row, where two points happen to sit a legal distance
## apart. What keeps the map from reading as a sequence of rows.
func _link_skipping(graph: RunMapGraph, from_row: PackedInt32Array,
		to_row: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for a: int in from_row:
		for b: int in to_row:
			if rng.randf() >= skip_link_chance:
				continue
			_join(graph, a, b)


## Adds one road, if it is a legal length and neither end is already full. The
## single gate every road in the map passes through, so no caller can make one
## that breaks the distance rule or the junction cap.
func _join(graph: RunMapGraph, a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0:
		return false
	if graph.has_link(a, b):
		return false
	if _degree(graph, a) >= max_links_per_site or _degree(graph, b) >= max_links_per_site:
		return false
	var distance := _distance(graph, a, b)
	var cycles := day_cycles_for(distance)
	if cycles <= 0:
		return false
	return graph.add_link(RunMapLink.make(a, b, distance, cycles))


## Moves [param b] along the line from [param a] until the two are exactly the
## nearest band's distance apart. [b]The positions are generated around the
## target distances, so this is the generator correcting its own layout rather
## than a duration being fudged to fit a length.[/b]
func _snap_to_band(graph: RunMapGraph, a: int, b: int) -> void:
	var from := graph.get_site(a)
	var to := graph.get_site(b)
	if from == null or to == null:
		return
	var offset := to.position - from.position
	if offset.length() < 1.0:
		offset = Vector2(0.0, -1.0)
	var band := nearest_band(offset.length())
	if band <= 0.0:
		return
	to.position = from.position + offset.normalized() * band


## Measures every road once more, now that nothing is moving, re-buckets it from
## what it actually turned out to be, and throws away any that no longer lands
## near a band.
##
## [b]This is the brief's "measure, assign, reject" step, and it has to come
## last.[/b] Repairing a stranded point moves it - see [method _snap_to_band] -
## and moving a point changes the length of every road already made to it, so no
## cost worked out while the layout was still settling can be trusted. Running
## the measurement again at the end is what guarantees that the number of days a
## road is priced at is the number its final geometry earns, and that the spread
## inside one band is never wider than [member band_tolerance] allows. A road
## that lost its band entirely is refused rather than stretched to fit; whether
## that leaves the map playable is [method _is_playable]'s question, and an
## attempt that fails it is thrown away and laid out again.
func _remeasure(graph: RunMapGraph) -> void:
	var kept: Array[RunMapLink] = []
	for link: RunMapLink in graph.links:
		link.distance = _distance(graph, link.from_id, link.to_id)
		link.day_cycles = day_cycles_for(link.distance)
		if link.day_cycles > 0:
			kept.append(link)
	graph.links = kept
	graph.rebuild_index()


func _allowed_partners(graph: RunMapGraph, a: int, row: PackedInt32Array) -> Array[int]:
	var scored: Array = []
	for b: int in row:
		var distance := _distance(graph, a, b)
		if day_cycles_for(distance) <= 0:
			continue
		scored.append([distance, b])
	scored.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var ids: Array[int] = []
	for entry: Array in scored:
		ids.append(entry[1])
	return ids


func _nearest_in(graph: RunMapGraph, a: int, row: PackedInt32Array) -> int:
	var best := -1
	var best_distance := INF
	for b: int in row:
		if b == a:
			continue
		var distance := _distance(graph, a, b)
		if distance < best_distance:
			best_distance = distance
			best = b
	return best


## The nearest point in [param row] that no road touches yet, or -1 when every
## one of them has already been reached. Moving such a point cannot invalidate a
## road, since it has none.
func _nearest_unreached_in(graph: RunMapGraph, a: int, row: PackedInt32Array) -> int:
	var best := -1
	var best_distance := INF
	for b: int in row:
		if b == a or _degree(graph, b) > 0:
			continue
		var distance := _distance(graph, a, b)
		if distance < best_distance:
			best_distance = distance
			best = b
	return best


func _has_link_into(graph: RunMapGraph, site_id: int, row: PackedInt32Array) -> bool:
	for a: int in row:
		if graph.has_link(a, site_id):
			return true
	return false


func _degree(graph: RunMapGraph, site_id: int) -> int:
	return graph.links_of(site_id).size()


func _distance(graph: RunMapGraph, a: int, b: int) -> float:
	var from := graph.get_site(a)
	var to := graph.get_site(b)
	if from == null or to == null:
		return INF
	return from.position.distance_to(to.position)


func _sort_row_by_x(graph: RunMapGraph, row: PackedInt32Array) -> void:
	var ids: Array[int] = []
	for site_id: int in row:
		ids.append(site_id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		return graph.get_site(a).position.x < graph.get_site(b).position.x)
	for index: int in range(ids.size()):
		row[index] = ids[index]


func _is_playable(graph: RunMapGraph) -> bool:
	if graph == null or graph.start_id < 0 or graph.boss_id < 0:
		return false
	return graph.reachable_from(graph.start_id).has(graph.boss_id)


## Throws away anything the start cannot reach, so the map never draws a point
## the player could never stand on. Ids are rewritten, since a site's id is its
## index in [member RunMapGraph.sites].
func _prune_unreachable(graph: RunMapGraph) -> void:
	var reachable := graph.reachable_from(graph.start_id)
	if reachable.size() == graph.sites.size():
		return

	var kept: Array[RunMapSite] = []
	var remap := {}
	for site: RunMapSite in graph.sites:
		if not reachable.has(site.id):
			continue
		remap[site.id] = kept.size()
		site.id = kept.size()
		kept.append(site)

	var links: Array[RunMapLink] = []
	for link: RunMapLink in graph.links:
		if not remap.has(link.from_id) or not remap.has(link.to_id):
			continue
		link.from_id = remap[link.from_id]
		link.to_id = remap[link.to_id]
		links.append(link)

	graph.sites = kept
	graph.links = links
	graph.start_id = remap.get(graph.start_id, 0)
	graph.boss_id = remap.get(graph.boss_id, kept.size() - 1)
	graph.current_id = remap.get(graph.current_id, graph.start_id)
	graph.rebuild_index()


# --- What is at each point ------------------------------------------------------

## Deals the map's kinds of place out over the points that were laid out.
##
## [b]This is the node distribution, and it runs on the finished graph.[/b] It
## is the last thing [method generate] does, after the layout has settled and
## anything unreachable has been thrown away, so a promised count is a count of
## points the player can actually stand on rather than of points that were made.
## It is deliberately not a second pass over a second map: the same
## [RunMapGraph] the roads were measured on is the one written into here.
##
## The order is what makes the rules hold. The northernmost point is claimed
## first - the final boss is a position, not a draw. Then every promise is
## collected: the exact counts a run must have, then each plan's
## [member RunMapSitePlan.min_count]. Whatever the map has left over is filled by
## weight. Finally the places that want room around them are laid down before
## the common ones, so the market and the saloon choose from an empty map and
## the bandits fill in around them rather than the other way about - and
## [method _repair_spacing] then trades any that still ended up badly placed
## with an ordinary point that does not mind where it stands.
func _assign_kinds(graph: RunMapGraph, rng: RandomNumberGenerator) -> void:
	if graph == null or site_plans.is_empty():
		return

	var north := _north_plan()
	if north != null and graph.boss_id >= 0:
		graph.get_site(graph.boss_id).kind = north.kind

	var free: Array[int] = []
	for site: RunMapSite in graph.sites:
		if site.id == graph.start_id or site.id == graph.boss_id:
			continue
		free.append(site.id)

	# Where each spacing group's points have ended up, and every high-value point
	# wherever its group, so each placement is scored against what is already down.
	var groups: Dictionary = {}
	var specials: Array[RunMapSite] = []
	# Which plan ended up on which point, for the repair pass below to re-score.
	var placed: Dictionary = {}

	for plan: RunMapSitePlan in _plan_demands(free.size(), rng):
		if free.is_empty():
			break
		var chosen := _pick_site_for(plan, free, graph, rng, groups, specials)
		if chosen < 0:
			continue
		free.erase(chosen)
		var site := graph.get_site(chosen)
		site.kind = plan.kind
		if not plan.spacing_group.is_empty():
			var peers: Array = groups.get(plan.spacing_group, [])
			peers.append(site)
			groups[plan.spacing_group] = peers
		if plan.is_special:
			specials.append(site)
		placed[chosen] = plan

	_repair_spacing(graph, placed, rng)


## Which plan claims each point, in the order they are placed - promises first,
## then the weighted fill, then reordered so the places that want room go down
## before the ones that do not care.
func _plan_demands(capacity: int, rng: RandomNumberGenerator) -> Array[RunMapSitePlan]:
	var counts: Dictionary = {}
	var demands: Array[RunMapSitePlan] = []

	# An exact count is a promise the map keeps whatever else it has to give up,
	# so these are collected first and are the last thing a small map drops.
	for plan: RunMapSitePlan in site_plans:
		if plan == null or plan.claims_northernmost or plan.exact_count < 0:
			continue
		for _one: int in range(maxi(plan.exact_count, 0)):
			demands.append(plan)
		counts[plan.kind] = maxi(plan.exact_count, 0)

	for plan: RunMapSitePlan in site_plans:
		if plan == null or plan.claims_northernmost or plan.exact_count >= 0:
			continue
		for _one: int in range(maxi(plan.min_count, 0)):
			demands.append(plan)
		counts[plan.kind] = maxi(plan.min_count, 0)

	# How many more places wanting room this map has space for, over and above
	# the ones it promised - see [member max_special_share].
	var roomy := 0
	for plan: RunMapSitePlan in demands:
		if _wants_room(plan):
			roomy += 1
	var roomy_cap := int(floor(float(capacity) * clampf(max_special_share, 0.0, 1.0)))

	while demands.size() < capacity:
		var plan := _weighted_plan(rng, counts, roomy >= roomy_cap)
		if plan == null:
			break
		demands.append(plan)
		counts[plan.kind] = int(counts.get(plan.kind, 0)) + 1
		if _wants_room(plan):
			roomy += 1

	if demands.size() > capacity:
		demands.resize(maxi(capacity, 0))

	# Whoever is fussiest goes down first, because the map fills up: the last few
	# points placed have no choice left at all, so anything with a rule to keep
	# has to choose while there is still somewhere to choose from. Places wanting
	# room around them are fussiest, then anything held to one stretch of the
	# map, and the rest take what is left.
	var wants_room: Array[RunMapSitePlan] = []
	var banded: Array[RunMapSitePlan] = []
	var fillers: Array[RunMapSitePlan] = []
	for plan: RunMapSitePlan in demands:
		if _wants_room(plan):
			wants_room.append(plan)
		elif plan.row_band.x > 0.0 or plan.row_band.y < 1.0:
			banded.append(plan)
		else:
			fillers.append(plan)
	# Shuffled, so which kind gets first refusal of the roomiest corner is not
	# the order the plans happen to sit in the inspector.
	_shuffle(wants_room, rng)
	_shuffle(banded, rng)

	var ordered: Array[RunMapSitePlan] = []
	ordered.append_array(wants_room)
	ordered.append_array(banded)
	ordered.append_array(fillers)
	return ordered


## The point this plan takes, out of the ones still free. A plan that wants no
## room takes one at random; one that does scores every candidate by the spacing
## rules and then picks at random from the best few - see
## [member placement_slack].
func _pick_site_for(plan: RunMapSitePlan, free: Array[int], graph: RunMapGraph,
		rng: RandomNumberGenerator, groups: Dictionary,
		specials: Array[RunMapSite]) -> int:
	var candidates := _within_row_band(plan, free, graph)
	if candidates.is_empty():
		candidates = free
	if candidates.is_empty():
		return -1

	if not _wants_room(plan):
		return candidates[rng.randi_range(0, candidates.size() - 1)]

	var scored: Array = []
	var best := -INF
	for site_id: int in candidates:
		var score := _placement_score(graph.get_site(site_id), plan, groups, specials)
		best = maxf(best, score)
		scored.append([score, site_id])

	# Every spot the rules are equally happy with, drawn from at random. Taking
	# the single best every time would lay the same map out the same way twice;
	# taking the best few in score order would quietly favour whichever point the
	# generator happened to make first among equals.
	var shortlist: Array[int] = []
	var floor_score := best - maxf(placement_slack, 0.0)
	for entry: Array in scored:
		if entry[0] >= floor_score:
			shortlist.append(entry[1])
	if shortlist.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	return shortlist[rng.randi_range(0, shortlist.size() - 1)]


## How good a spot [param site] is for [param plan]. 0 is a spot nothing objects
## to; every rule only ever subtracts, so there is always a best candidate and a
## map too small to honour the spacing still gets everything it promised.
func _placement_score(site: RunMapSite, plan: RunMapSitePlan, groups: Dictionary,
		specials: Array[RunMapSite]) -> float:
	var nearest := INF
	if not plan.spacing_group.is_empty():
		var peers: Array = groups.get(plan.spacing_group, [])
		for peer: RunMapSite in peers:
			nearest = minf(nearest, site.position.distance_to(peer.position))

	var near := 0
	if plan.is_special:
		for other: RunMapSite in specials:
			if site.position.distance_to(other.position) <= maxf(cluster_radius, 1.0):
				near += 1

	return _score_from(nearest, near, plan)


## The spacing rules themselves, as arithmetic: how far the nearest point of
## this plan's own band is - INF for none - and how many high-value points share
## its little corner of the map. 0 is a spot nothing objects to; every rule only
## ever subtracts, so there is always a best candidate and a map too small to
## honour the spacing still gets everything it promised.
func _score_from(nearest: float, near: int, plan: RunMapSitePlan) -> float:
	var score := 0.0

	if nearest < INF:
		# A band with slack, not a distance to hit: inside it nothing is taken
		# off, and outside it the penalty grows with how far out it is - in both
		# directions, which is what keeps two of a kind from being pushed to
		# opposite ends of the map as readily as from touching.
		var error := absf(nearest / maxf(spacing_target, 1.0) - 1.0)
		score -= maxf(error - spacing_tolerance, 0.0) * spacing_penalty
		if nearest < spacing_minimum:
			score -= crowding_penalty * (1.0 - nearest / maxf(spacing_minimum, 1.0))

	if plan.is_special:
		# A gentle push away from every high-value point already down, and a hard
		# one once this corner of the map has had its share of them.
		score -= float(near) * spacing_penalty
		if near >= maxi(max_specials_per_cluster, 1):
			score -= crowding_penalty * float(near - maxi(max_specials_per_cluster, 1) + 1)

	return score


## The free points lying in [param plan]'s own stretch of the map. Empty when
## none do, which every caller reads as "ignore the band" - a promise the map
## made is kept even on a map with no room for it where it would have liked.
func _within_row_band(plan: RunMapSitePlan, free: Array[int],
		graph: RunMapGraph) -> Array[int]:
	var low := minf(plan.row_band.x, plan.row_band.y)
	var high := maxf(plan.row_band.x, plan.row_band.y)
	if low <= 0.0 and high >= 1.0:
		return free

	var last_row := 0
	for site: RunMapSite in graph.sites:
		last_row = maxi(last_row, site.row)
	if last_row <= 0:
		return free

	var kept: Array[int] = []
	for site_id: int in free:
		var along := float(graph.get_site(site_id).row) / float(last_row)
		if along >= low - 0.001 and along <= high + 0.001:
			kept.append(site_id)
	return kept


## One plan drawn by weight, out of those that have not yet hit their cap. Null
## when every plan is capped or none has a weight, which leaves the rest of the
## map as unknown points rather than over-filling it.
func _weighted_plan(rng: RandomNumberGenerator, counts: Dictionary,
		no_more_room: bool = false) -> RunMapSitePlan:
	var total := 0.0
	for plan: RunMapSitePlan in site_plans:
		total += _fill_weight(plan, counts, no_more_room)
	if total <= 0.0:
		return null

	var roll := rng.randf() * total
	for plan: RunMapSitePlan in site_plans:
		var weight := _fill_weight(plan, counts, no_more_room)
		if weight <= 0.0:
			continue
		roll -= weight
		if roll <= 0.0:
			return plan
	return null


func _fill_weight(plan: RunMapSitePlan, counts: Dictionary,
		no_more_room: bool = false) -> float:
	if plan == null or plan.claims_northernmost or plan.exact_count >= 0:
		return 0.0
	if no_more_room and _wants_room(plan):
		return 0.0
	if plan.weight <= 0.0:
		return 0.0
	if plan.max_count >= 0 and int(counts.get(plan.kind, 0)) >= plan.max_count:
		return 0.0
	return plan.weight


## Whether this kind is one the spacing rules have anything to say about - it
## shares a distance band with something, or it is high-value enough to be kept
## out of a cluster. These are placed before the common kinds, so they choose
## from an empty map.
func _wants_room(plan: RunMapSitePlan) -> bool:
	return plan != null and (plan.is_special or not plan.spacing_group.is_empty())


func _north_plan() -> RunMapSitePlan:
	for plan: RunMapSitePlan in site_plans:
		if plan != null and plan.claims_northernmost:
			return plan
	return null


## Shuffled through the map's own generator rather than [method Array.shuffle],
## which reads the global one - so a map made from a given seed is the same map
## every time, spacing order included.
func _shuffle(plans: Array[RunMapSitePlan], rng: RandomNumberGenerator) -> void:
	for index: int in range(plans.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := plans[index]
		plans[index] = plans[swap]
		plans[swap] = held


## Trades badly placed special points with ordinary ones until none of them is
## somewhere the spacing rules object to.
##
## [b]Laying the map out in one pass cannot get this right on its own.[/b] Each
## point is placed into the best spot left at the time, so an early market that
## chose well can leave a late sheriff outpost with nowhere good - and by then
## the market is already down. This is the pass that fixes that: every place
## wanting room is scored where it actually ended up, and any that is unhappy is
## offered every ordinary point on the map in exchange. An ordinary point - a
## bandit group, a camp, an event - has no spacing rules of its own, so the
## trade costs nothing and is taken whenever it is an improvement.
##
## Only strict improvements are made and only a fixed number of rounds are run,
## so this always terminates and can never make the map worse than the pass that
## laid it out.
func _repair_spacing(graph: RunMapGraph, placed: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var roomy: Array[int] = []
	var plain: Array[int] = []
	for site_id: int in placed:
		if _wants_room(placed[site_id]):
			roomy.append(site_id)
		else:
			plain.append(site_id)
	if roomy.is_empty() or plain.is_empty():
		return

	for _round: int in range(maxi(repair_rounds, 0)):
		var traded := 0
		# Shuffled each round so the same unhappy point is not always the one
		# given first refusal of the map's spare room.
		_shuffle_ids(roomy, rng)

		for index: int in range(roomy.size()):
			var here := roomy[index]
			var plan: RunMapSitePlan = placed[here]
			var now := _score_at(graph.get_site(here).position, plan, placed, graph, here)
			if now >= 0.0:
				continue

			var best_gain := 0.0
			var best_swap := -1
			for other: int in plain:
				# Both halves of the trade have to be somewhere they are allowed:
				# this one in the ordinary point's stretch of the map, and the
				# ordinary point in this one's.
				if not _in_row_band(plan, graph.get_site(other), graph):
					continue
				if not _in_row_band(placed[other], graph.get_site(here), graph):
					continue
				var there := _score_at(
					graph.get_site(other).position, plan, placed, graph, here)
				if there - now > best_gain:
					best_gain = there - now
					best_swap = other
			if best_swap < 0:
				continue

			# The ordinary point takes this one's place and vice versa. Nothing
			# else on the map moves, so every other point's score is unchanged
			# except by these two, which is what the next round re-measures.
			var other_plan: RunMapSitePlan = placed[best_swap]
			graph.get_site(here).kind = other_plan.kind
			graph.get_site(best_swap).kind = plan.kind
			placed[here] = other_plan
			placed[best_swap] = plan
			roomy[index] = best_swap
			plain[plain.find(best_swap)] = here
			traded += 1

		if traded == 0:
			return


## What the spacing rules make of [param plan] standing at [param at], measured
## against every other point already on the map rather than only those laid
## down before it - which is what makes this usable by [method _repair_spacing]
## as well as by the placement itself. [param skip_id] is the point being moved,
## excluded so a point is never scored against itself.
func _score_at(at: Vector2, plan: RunMapSitePlan, placed: Dictionary,
		graph: RunMapGraph, skip_id: int) -> float:
	var nearest := INF
	var near := 0
	for other_id: int in placed:
		if other_id == skip_id:
			continue
		var other_plan: RunMapSitePlan = placed[other_id]
		var distance := at.distance_to(graph.get_site(other_id).position)
		if not plan.spacing_group.is_empty() \
				and other_plan.spacing_group == plan.spacing_group:
			nearest = minf(nearest, distance)
		if plan.is_special and other_plan.is_special \
				and distance <= maxf(cluster_radius, 1.0):
			near += 1
	return _score_from(nearest, near, plan)


## Whether [param site] lies in [param plan]'s own stretch of the map - the same
## reading [method _within_row_band] takes, for one site rather than a list.
func _in_row_band(plan: RunMapSitePlan, site: RunMapSite, graph: RunMapGraph) -> bool:
	var low := minf(plan.row_band.x, plan.row_band.y)
	var high := maxf(plan.row_band.x, plan.row_band.y)
	if low <= 0.0 and high >= 1.0:
		return true
	var last_row := 0
	for other: RunMapSite in graph.sites:
		last_row = maxi(last_row, other.row)
	if last_row <= 0:
		return true
	var along := float(site.row) / float(last_row)
	return along >= low - 0.001 and along <= high + 0.001


## Shuffled through the map's own generator, for the same reason
## [method _shuffle] is.
func _shuffle_ids(ids: Array[int], rng: RandomNumberGenerator) -> void:
	for index: int in range(ids.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := ids[index]
		ids[index] = ids[swap]
		ids[swap] = held
