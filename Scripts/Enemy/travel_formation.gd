class_name TravelFormation
extends Resource
## One shape a group of enemies stands in when it forms up across the road.
##
## [b]It is a shape, not a name.[/b] A wide line, a V, a dense knot, three
## staggered ranks, two bodies with a gap between them and a broad arc closing
## round the player are not six pieces of code - they are six settings of the same
## six numbers, which is why this is a resource and not an enum. Adding a seventh
## is saving a [code].tres[/code] and dropping it into
## [member TravelWaveDirector.formations]; there is no name, branch or threshold in
## any script that a new one would have to be added to.
##
## Every measurement here is a [i]multiplier[/i] on what the director says a
## formation is worth right now - see [member TravelWaveDirector.formation_width]
## and [member TravelWaveDirector.formation_depth] - rather than a distance in
## pixels. That is what lets the road widen its walls as the player closes on the
## cart without every formation having to be re-authored: the shape stays the shape
## and only the scale of it moves.
##
## The frame a formation is built in is the road itself: [b]forward[/b] is the
## direction from the player to the horse cart, and [b]sideways[/b] is across it.
## So a formation never has to know which way the player is walking - it is always
## drawn across their route, and pointing the route somewhere else re-aims it.

## What this shape is, for reading an inspector array at a glance. Nothing
## branches on it.
@export var formation_name: StringName = &"line"
## How often this shape is picked relative to the others in the director's list.
## 0 leaves it in the array but never chooses it, which is how a shape is turned
## off without losing its settings.
@export var weight: float = 1.0
## Share of a wave's enemies a group in this shape asks for, relative to the other
## groups of the same wave. A dense knot worth twice a thin line is 2.0 here.
@export var share: float = 1.0

@export_group("Shape")
## Ranks the group is drawn up in, one behind the other. 1 is a single line;
## three is the staggered wall, which is the same line repeated with
## [member row_depth] and [member row_stagger] between the copies.
@export var rows: int = 1
## Gap between one rank and the next, in pixels along the route - so rank two
## stands this much further from the player than rank one.
##
## [b]It is depth, and depth is what stops a wall being one dodge.[/b] A single
## line can be run round the end of; ranks behind it cannot, because the ground
## the player wins by rounding the first is the ground the second is standing on.
@export var row_depth: float = 0.0
## How far a rank is shifted sideways relative to the one in front of it, as a
## fraction of the gap between two neighbours in a rank. 0.5 puts each enemy of
## the second rank behind the hole in the first, which is what closes a line that
## would otherwise be walked straight through.
@export var row_stagger: float = 0.5

@export_group("Size")
## How wide this shape is drawn, as a multiple of the director's current
## formation width. Above 1 is a broad screen; below 1 is a knot.
@export var width_scale: float = 1.0
## How deep the bow of this shape is, as a multiple of the director's current
## formation depth. Only does anything when [member curvature] is not 0.
@export var depth_scale: float = 1.0
## How the line bows, from -1 to 1.
##
##   * [b]0[/b] - straight across the route.
##   * [b]Positive[/b] - the middle stands nearest the player and the ends trail
##     back: a V with its point turned towards them, which funnels the player
##     outwards into the wings rather than through the centre.
##   * [b]Negative[/b] - the ends stand nearest and the middle hangs back: an arc
##     bending round the player, which is the formation that partially closes on
##     them instead of merely blocking.
@export_range(-1.0, 1.0, 0.01) var curvature: float = 0.0
## Fraction of the width left empty down the middle, from 0 to 1. Above 0 splits
## the shape into two bodies with a gap between them - a mouth the player can be
## tempted into rather than a wall they must break.
@export_range(0.0, 0.95, 0.01) var centre_gap: float = 0.0

@export_group("Scatter")
## How far each enemy is nudged off its slot at random: x across the route, y
## along it. Keeps a formation from reading as a drawn grid without letting it
## lose its shape.
@export var jitter := Vector2(60.0, 55.0)


## Where the enemies of a group [param count] strong stand, in the road's own
## frame: x across the route, y along it, with positive y further from the player.
##
## Returned as plain offsets rather than as world points, so the director owns
## where the group is anchored, how the route is pointing and every clamp that
## keeps a spawn off the cart and inside the map - and this resource owns only the
## shape. Handing back world positions would put half of that here, in a file that
## is copied five times.
func build_offsets(count: int, width: float, depth: float) -> PackedVector2Array:
	var offsets := PackedVector2Array()
	if count <= 0:
		return offsets

	var rank_count := maxi(rows, 1)
	var span := maxf(width * width_scale, 0.0)
	var bow := depth * depth_scale

	for rank in rank_count:
		var in_rank := _rank_size(count, rank_count, rank)
		if in_rank <= 0:
			continue

		# Neighbour spacing is measured from the rank actually being drawn, so a
		# thin back rank spreads across the same frontage as a thick front one
		# instead of huddling at the middle of it.
		var spacing := span / float(maxi(in_rank - 1, 1))
		var stagger := 0.0 if rank % 2 == 0 else row_stagger * spacing

		for i in in_rank:
			# -1 at the left wing, +1 at the right, 0 at the centre.
			var t := 0.0 if in_rank == 1 else float(i) / float(in_rank - 1) * 2.0 - 1.0
			offsets.append(Vector2(
				_across(t, span) + stagger,
				_along(t, bow) + row_depth * float(rank) + randf_range(-jitter.y, jitter.y)))

	return offsets


## How far across the route a slot sits. The centre gap is opened by pushing the
## whole line outwards from the middle rather than by dropping the slots nearest
## it, so a split formation keeps every enemy the wave paid for.
func _across(t: float, span: float) -> float:
	var spread := t
	if centre_gap > 0.0:
		spread = signf(t) * lerpf(centre_gap, 1.0, absf(t))
	return spread * span * 0.5 + randf_range(-jitter.x, jitter.x)


## How far along the route a slot sits, before its rank is added. The bow is
## measured from the wings inwards, so the ends of the line are the fixed points
## and only the middle travels - which keeps a curved formation across the same
## frontage as a straight one of the same width.
func _along(t: float, bow: float) -> float:
	if is_zero_approx(curvature) or is_zero_approx(bow):
		return 0.0
	return -curvature * bow * (1.0 - absf(t))


## How many of [param count] fall to rank [param rank]. The remainder is dealt to
## the front ranks first, so an odd wave thickens the line the player meets rather
## than the one behind it.
func _rank_size(count: int, rank_count: int, rank: int) -> int:
	var base := count / rank_count
	var spare := count % rank_count
	return base + (1 if rank < spare else 0)
