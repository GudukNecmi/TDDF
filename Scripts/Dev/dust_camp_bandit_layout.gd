extends SceneTree
## Derives Dust Camp's bandit placement from the map's own terrain and writes
## it back out as the scene text for [code]WorldMap/WorldBandits[/code].
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/dust_camp_bandit_layout.gd
## [/codeblock]
##
## [b]An authoring tool, not a runtime system.[/b] Nothing in the game loads
## this. It exists so a hundred groups are placed against the ground that is
## actually there - every position is snapped to a point [TerrainShape] itself
## calls clear, so no group is ever authored standing inside a rock or half
## through the map edge - and so the layout can be re-derived and re-read
## rather than being an opaque wall of hand-typed coordinates. It prints a
## fragment; splicing that into the scene is a separate, deliberate step.
##
## [b]The distribution it builds.[/b] Five garrison groups ring each of the
## five normal camps and six ring each of the three boss camps, on a shared
## looping route around their own camp, so a camp's groups patrol it together
## rather than standing on it. Chokepoints are found rather than guessed:
## every walkable sample whose [method TerrainShape.get_clearance] falls in
## the narrow band below is a genuine pinch in the rock, and the tightest
## well-separated ones get a group apiece. The map's existing road routes keep
## a patrol each, and the remainder ride wide sector loops placed in whichever
## quarters of the desert the rest of the layout left thinnest - which is what
## keeps the spread even instead of clumped around the camps.
##
## [b]The two safe places are subtracted first.[/b] No group, route point or
## sector loop is ever placed within [constant SANCTUARY_CLEARANCE] of the
## Saloon or the Market - including the map's own authored road points, which
## are pushed back out if they fall inside. See [WorldMapSanctuary], which is
## what makes the same two circles mean something at runtime.

const TERRAIN_PATH := "res://Resources/Maps/Desert/Regions/dust_camp_terrain.tres"
const OUT_PATH := "user://dust_camp_bandit_layout.txt"

## Node ids for the two branches this writes into, copied off the scene.
const ROUTES_PARENT_ID := 1594767623
const GROUPS_PARENT_ID := 1155586066
## Where generated unique_ids start. Well clear of every id already in the
## scene, and allocated in one run so nothing collides.
const ID_BASE := 810000000

## Open ground a group needs around it to be authored there at all - comfortably
## past the navigation agent radius, so every group starts on mesh it can walk.
const PLACE_MARGIN := 200.0
## How far no bandit content may come to the Saloon or the Market.
const SANCTUARY_CLEARANCE := 1700.0

## The clearance band that reads as "a narrow passage": tight enough to be a
## pinch between rock, wide enough that a group can actually walk it.
const CHOKE_MIN_CLEARANCE := 170.0
const CHOKE_MAX_CLEARANCE := 460.0

## The grid the roaming fill measures emptiness on - see [method _emit_sectors].
const FILL_COLUMNS := 4
const FILL_ROWS := 4

var _terrain: TerrainShape
var _next_id: int = ID_BASE
var _out: PackedStringArray = PackedStringArray()
var _route_index: int = 0
var _group_index: int = 0
var _placed: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()

## The two safe places, in map space. Kept as data here for the same reason
## they are kept as nodes in the scene: they are the one thing the whole
## layout is subtracted from.
var _sanctuaries: Array[Vector2] = [
	Vector2(-760, -4120),   # Saloon
	Vector2(7800, 1000),    # Market
]

## Normal bandit camps: five garrison groups apiece.
var _normal_camps: Array = [
	{"key": "Northwest", "pos": Vector2(-8840, -7160), "node": "normal_camp_01"},
	{"key": "Northeast", "pos": Vector2(6200, -4280), "node": "normal_camp_02"},
	{"key": "MiddleFlats", "pos": Vector2(1320, -2440), "node": "normal_camp_03"},
	{"key": "Southwest", "pos": Vector2(-3560, 2760), "node": "normal_camp_04"},
	{"key": "Southeast", "pos": Vector2(6040, 3320), "node": "normal_camp_05"},
]

## Boss camps: six garrison groups apiece, and stronger ones.
var _boss_camps: Array = [
	{"key": "NorthRidge", "pos": Vector2(-4280, -6920), "node": "bounty_camp_01"},
	{"key": "SouthReach", "pos": Vector2(7160, 6200), "node": "bounty_camp_02"},
	{"key": "DryWash", "pos": Vector2(-5480, 7160), "node": "bounty_camp_03"},
]

## The map's own authored roads, kept exactly as they were authored except
## where a point falls inside a sanctuary - see [method _push_out_of_sanctuary].
var _roads: Array = [
	{"name": "RouteA1", "points": [Vector2(-8840, -7160), Vector2(-4280, -6920), Vector2(-1960, -6600)]},
	{"name": "RouteA2", "points": [Vector2(6200, -4280), Vector2(4440, -5800), Vector2(7960, -3240)]},
	{"name": "RouteA3", "points": [Vector2(1320, -2440), Vector2(-200, -1160), Vector2(2680, 840)]},
	{"name": "RouteA4", "points": [Vector2(-3560, 2760), Vector2(-6680, 4600), Vector2(-1160, 6600)]},
	{"name": "RouteA5", "points": [Vector2(6040, 3320), Vector2(7800, 4280), Vector2(6040, 5240)]},
	{"name": "RouteA6", "points": [Vector2(-6760, 40), Vector2(-3000, -2600), Vector2(-5880, -1720)]},
	{"name": "RouteWestCanyonRoad", "points": [Vector2(-6760, 640), Vector2(-5280, 1680), Vector2(-3840, 2800)]},
	{"name": "RouteArenaRoad", "points": [Vector2(-5260, -1980), Vector2(-3300, -2840), Vector2(-1360, -3720)]},
	{"name": "RouteNorthwestRidgeRoad", "points": [Vector2(-8260, -6700), Vector2(-6400, -5500), Vector2(-4660, -6320)]},
	{"name": "RouteNorthRoad", "points": [Vector2(-3580, -6760), Vector2(-1360, -6480), Vector2(860, -6780)]},
	{"name": "RouteNortheastRoad", "points": [Vector2(2120, -6560), Vector2(3860, -5480), Vector2(5620, -4420)]},
	{"name": "RouteSaloonPass", "points": [Vector2(-520, -3800), Vector2(260, -3100), Vector2(1020, -2420)]},
	{"name": "RouteEastPortalRoad", "points": [Vector2(6420, -3660), Vector2(7160, -2020), Vector2(8160, -560)]},
	{"name": "RouteMarketRoad", "points": [Vector2(6300, 3260), Vector2(6760, 2240), Vector2(7560, 1380)]},
	{"name": "RouteEastNarrows", "points": [Vector2(1780, -3200), Vector2(5240, -2660), Vector2(7200, 340)]},
	{"name": "RouteSouthRoad", "points": [Vector2(-3260, 2080), Vector2(-460, 2800), Vector2(1180, 6180)]},
	{"name": "RouteSouthwestWashRoad", "points": [Vector2(-3920, 3360), Vector2(-5040, 5100), Vector2(-5200, 6900)]},
	{"name": "RouteSoutheastReachRoad", "points": [Vector2(2520, 6960), Vector2(4520, 6680), Vector2(6520, 6400)]},
]


func _initialize() -> void:
	_rng.seed = 20260907
	_terrain = load(TERRAIN_PATH) as TerrainShape
	if _terrain == null:
		print("could not load ", TERRAIN_PATH)
		quit(1)
		return

	_build()
	var text := "\n".join(_out)
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("wrote %d routes and %d groups to %s" % [
		_route_index, _group_index, ProjectSettings.globalize_path(OUT_PATH)])
	quit(0)


func _build() -> void:
	for camp: Dictionary in _normal_camps:
		_emit_camp(camp, 5, 820.0, 16.0, 3.0, 2600.0, "Camp")
	for camp: Dictionary in _boss_camps:
		_emit_camp(camp, 6, 1000.0, 34.0, 4.0, 3200.0, "BossCamp")

	_emit_chokepoints(12)
	_emit_roads()
	_emit_sectors(27)


# --- The four kinds of placement ---------------------------------------------


## One camp: a looping route ringing it, and [param count] groups spaced around
## that ring. They share the one route on purpose - a camp's groups working the
## same circuit from different points on it is what makes them read as one
## garrison rather than as [param count] unrelated patrols that happen to be
## near each other.
func _emit_camp(
		camp: Dictionary, count: int, ring: float, base_strength: float,
		strength_step: float, territory: float, prefix: String) -> void:
	var centre: Vector2 = camp["pos"]
	var key: String = camp["key"]
	var route_name := "Route%s%s" % [prefix, key]
	var points: Array[Vector2] = []
	for i in 6:
		var angle := TAU * float(i) / 6.0 + 0.4
		points.append(_snap(centre + Vector2.from_angle(angle) * ring))
	_emit_route(route_name, points, true)

	var home := "../../../Locations/RegionA/%s" % camp["node"]
	for i in count:
		var angle := TAU * float(i) / float(count)
		var spot := _snap(centre + Vector2.from_angle(angle) * (ring * 0.85))
		_emit_group("RegionA_%s%s_%d" % [prefix, key, i + 1], spot, route_name,
			base_strength + strength_step * float(i), territory, home)


## Narrow passages, found off the clearance grid rather than guessed at: every
## walkable sample whose open ground falls in the choke band is a candidate,
## the tightest are taken first, and each one taken excludes its neighbourhood
## so twelve separate passes are watched instead of twelve samples of one.
func _emit_chokepoints(count: int) -> void:
	var candidates: Array = []
	var x := -9600.0
	while x <= 9600.0:
		var y := -7600.0
		while y <= 7600.0:
			var point := Vector2(x, y)
			var clear := _terrain.get_clearance(point)
			if clear >= CHOKE_MIN_CLEARANCE and clear <= CHOKE_MAX_CLEARANCE \
					and _terrain.is_clear(point, PLACE_MARGIN) \
					and _sanctuary_distance(point) > SANCTUARY_CLEARANCE \
					and _camp_distance(point) > 2000.0:
				candidates.append({"pos": point, "clear": clear})
			y += 200.0
		x += 200.0

	candidates.sort_custom(func(a, b): return a["clear"] < b["clear"])

	var taken: Array[Vector2] = []
	var made := 0
	for entry: Dictionary in candidates:
		if made >= count:
			break
		var point: Vector2 = entry["pos"]
		var too_near := false
		for other: Vector2 in taken:
			if other.distance_to(point) < 2600.0:
				too_near = true
				break
		if too_near:
			continue
		taken.append(point)
		made += 1

		var axis := _open_axis(point)
		var route_name := "RouteChoke%02d" % made
		_emit_route(route_name, [
			_snap(point - axis * 620.0), point, _snap(point + axis * 620.0)], false)
		_emit_group("RegionA_Choke%02d" % made, point, route_name,
			18.0 + float(made % 5) * 3.0, 0.0, "")


## The map's own roads, one patrol apiece, kept where they were authored.
func _emit_roads() -> void:
	for road: Dictionary in _roads:
		var points: Array[Vector2] = []
		for raw: Vector2 in road["points"]:
			points.append(_snap(_push_out_of_sanctuary(raw)))
		var route_name: String = road["name"]
		_emit_route(route_name, points, false)
		var short_name := route_name.substr(5)
		_emit_group("RegionA_Road%s" % short_name, points[0], route_name,
			14.0 + float(_group_index % 7) * 3.0, 0.0, "")


## The remaining groups, as wide roaming loops placed wherever the rest of the
## layout actually left the desert thinnest.
##
## This is the pass that answers "do not leave large areas completely empty",
## and it answers it by measuring rather than by guessing. The map is cut into
## a [constant FILL_COLUMNS] by [constant FILL_ROWS] grid, every group already
## authored is counted into the cell it stands in, and then the whole of
## [param budget] is handed out one group at a time to whichever cell is
## currently emptiest - so the last group placed goes wherever the previous
## ninety-nine left the biggest hole. Cells that are mostly rock, or that are
## safe ground, are dropped before any of that; nothing is forced into a
## quarter of the map that has nowhere to stand.
##
## Each cell that draws groups gets one looping route, and its groups ride it
## from different points, exactly the way a camp garrison shares its ring.
func _emit_sectors(budget: int) -> void:
	var cells: Array = []
	for gx in FILL_COLUMNS:
		for gy in FILL_ROWS:
			var rect := Rect2(
				-10000.0 + 20000.0 * float(gx) / float(FILL_COLUMNS),
				-8000.0 + 16000.0 * float(gy) / float(FILL_ROWS),
				20000.0 / float(FILL_COLUMNS), 16000.0 / float(FILL_ROWS))
			var centre := rect.position + rect.size * 0.5
			var anchor := _snap(centre)
			# A cell whose nearest standable ground is most of a cell away is
			# rock, map edge or sanctuary - not somewhere a patrol belongs.
			if anchor.distance_to(centre) > rect.size.x * 0.45:
				continue
			var standing := 0
			for other: Vector2 in _placed:
				if rect.has_point(other):
					standing += 1
			cells.append({"pos": anchor, "count": standing, "extra": 0})

	if cells.is_empty():
		return

	for _i in budget:
		var thinnest: Dictionary = cells[0]
		for cell: Dictionary in cells:
			if cell["count"] + cell["extra"] < thinnest["count"] + thinnest["extra"]:
				thinnest = cell
		thinnest["extra"] = int(thinnest["extra"]) + 1

	var made := 0
	for cell: Dictionary in cells:
		var extra: int = cell["extra"]
		if extra <= 0:
			continue
		made += 1
		var centre: Vector2 = cell["pos"]
		var points: Array[Vector2] = []
		for p in 5:
			var angle := TAU * float(p) / 5.0 + float(made) * 0.3
			points.append(_snap(centre + Vector2.from_angle(angle) * 1500.0))
		var route_name := "RouteDesertLoop%02d" % made
		_emit_route(route_name, points, true)
		for g in extra:
			_emit_group("RegionA_Roam%02d_%d" % [made, g + 1],
				points[(g * 2) % points.size()], route_name,
				12.0 + float((made + g) % 6) * 3.0, 0.0, "")


# --- Emitting scene text ------------------------------------------------------


func _emit_route(route_name: String, points: Array[Vector2], loop: bool) -> void:
	_out.append("")
	_out.append('[node name="%s" type="Node2D" parent="WorldMap/WorldBandits/Routes" parent_id_path=PackedInt32Array(%d) index="%d" unique_id=%d]'
		% [route_name, ROUTES_PARENT_ID, _route_index, _take_id()])
	_out.append('script = ExtResource("10_route")')
	if loop:
		_out.append("loop = true")
	for i in points.size():
		_out.append("")
		_out.append('[node name="Point%d" type="Node2D" parent="WorldMap/WorldBandits/Routes/%s" index="%d" unique_id=%d]'
			% [i, route_name, i, _take_id()])
		_out.append("position = Vector2(%d, %d)" % [roundi(points[i].x), roundi(points[i].y)])
	_route_index += 1


func _emit_group(
		group_name: String, spot: Vector2, route_name: String, strength: float,
		territory: float, home: String) -> void:
	_placed.append(spot)
	_out.append("")
	_out.append('[node name="%s" type="Node2D" parent="WorldMap/WorldBandits/Groups" parent_id_path=PackedInt32Array(%d) index="%d" unique_id=%d]'
		% [group_name, GROUPS_PARENT_ID, _group_index, _take_id()])
	_out.append("position = Vector2(%d, %d)" % [roundi(spot.x), roundi(spot.y)])
	_out.append('script = ExtResource("11_bandit")')
	_out.append("group_strength = %.1f" % strength)
	_out.append('speed_profile = ExtResource("12_speed")')
	_out.append('threat_profile = ExtResource("13_threat")')
	_out.append('current_route = NodePath("../../Routes/%s")' % route_name)
	if territory > 0.0:
		_out.append("territory_radius = %.1f" % territory)
	if not home.is_empty():
		_out.append('home_path = NodePath("%s")' % home)

	_out.append("")
	_out.append('[node name="Glow" type="Sprite2D" parent="WorldMap/WorldBandits/Groups/%s" index="0" unique_id=%d]'
		% [group_name, _take_id()])
	_out.append("modulate = Color(0.9, 0.15, 0.1, 0.35)")
	_out.append("z_index = -1")
	_out.append("scale = Vector2(2.4, 2.4)")
	_out.append('texture = ExtResource("15_dot")')

	_out.append("")
	_out.append('[node name="Icon" type="Sprite2D" parent="WorldMap/WorldBandits/Groups/%s" index="1" unique_id=%d]'
		% [group_name, _take_id()])
	_out.append("modulate = Color(0.6, 0.14, 0.08, 1)")
	_out.append("rotation = 0.7853982")
	_out.append("scale = Vector2(0.85, 0.85)")
	_out.append('texture = ExtResource("16_solid")')
	_group_index += 1


func _take_id() -> int:
	_next_id += 137
	return _next_id


# --- Ground queries -----------------------------------------------------------


## The nearest point to [param point] that is clear ground outside both
## sanctuaries, searched outward in rings so the answer is always the closest
## acceptable spot rather than an arbitrary one. Falls back to the point
## itself when the whole neighbourhood is rock, which the caller sees as
## "authored where it was asked for".
func _snap(point: Vector2) -> Vector2:
	if _acceptable(point):
		return point
	var step := 120.0
	while step <= 2400.0:
		for i in 24:
			var angle := TAU * float(i) / 24.0
			var candidate := point + Vector2.from_angle(angle) * step
			if _acceptable(candidate):
				return candidate
		step += 120.0
	return point


func _acceptable(point: Vector2) -> bool:
	return _terrain.is_clear(point, PLACE_MARGIN) \
		and _sanctuary_distance(point) > SANCTUARY_CLEARANCE


## Pushes an authored road point straight out of a sanctuary it has strayed
## into, along the line away from that sanctuary's centre, so the road keeps
## its shape and simply stops short of the safe ground.
func _push_out_of_sanctuary(point: Vector2) -> Vector2:
	for centre: Vector2 in _sanctuaries:
		var offset := point - centre
		if offset.length() > SANCTUARY_CLEARANCE:
			continue
		var direction := offset.normalized() if not offset.is_zero_approx() \
			else Vector2.from_angle(_rng.randf() * TAU)
		return centre + direction * (SANCTUARY_CLEARANCE + 260.0)
	return point


func _sanctuary_distance(point: Vector2) -> float:
	var nearest := 1.0e12
	for centre: Vector2 in _sanctuaries:
		nearest = minf(nearest, centre.distance_to(point))
	return nearest


func _camp_distance(point: Vector2) -> float:
	var nearest := 1.0e12
	for camp: Dictionary in _normal_camps + _boss_camps:
		nearest = minf(nearest, (camp["pos"] as Vector2).distance_to(point))
	return nearest


## The direction a passage actually runs at [param point]: the axis along which
## the ground stays open furthest in both directions. What turns a single
## chokepoint sample into a short patrol leg through the pass rather than
## across it.
func _open_axis(point: Vector2) -> Vector2:
	var best := Vector2.RIGHT
	var best_reach := -1.0
	for i in 12:
		var angle := PI * float(i) / 12.0
		var axis := Vector2.from_angle(angle)
		var reach := minf(_reach(point, axis), _reach(point, -axis))
		if reach > best_reach:
			best_reach = reach
			best = axis
	return best


## How far the ground stays walkable from [param point] along [param axis],
## capped - only the comparison between axes matters.
func _reach(point: Vector2, axis: Vector2) -> float:
	var travelled := 0.0
	while travelled < 900.0:
		travelled += 100.0
		if not _terrain.is_walkable(point + axis * travelled):
			return travelled - 100.0
	return travelled
