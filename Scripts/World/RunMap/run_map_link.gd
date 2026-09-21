class_name RunMapLink
extends RefCounted
## One road between two points on a run map, and how long riding it takes.
##
## [b]The length is measured, not counted.[/b] A link's [member day_cycles] is
## worked out from [member distance] - the real geometric distance between the two
## sites - against the map's authored distance bands, never from how many rows the
## two sites are apart. See [method RunMapGenerator.day_cycles_for]: a link whose
## measured distance does not land near any band is refused outright rather than
## rounded into one, which is what keeps two three-day roads roughly the same
## length as each other.
##
## [b]It is undirected.[/b] [member from_id] and [member to_id] are the order the
## generator happened to make it in and mean nothing else - the piece may ride it
## either way, which is what lets a generated graph allow backward and sideward
## moves wherever it happens to have made them.

## One end of the road.
var from_id: int = -1
## The other end.
var to_id: int = -1
## How far apart the two sites actually are, in map pixels.
var distance: float = 0.0
## How many day cycles riding it costs - 1, 2 or 3, whichever band
## [member distance] landed in.
var day_cycles: int = 1


static func make(a: int, b: int, measured: float, cycles: int) -> RunMapLink:
	var link := RunMapLink.new()
	link.from_id = a
	link.to_id = b
	link.distance = measured
	link.day_cycles = cycles
	return link


## Whether this road touches [param site_id] at either end.
func touches(site_id: int) -> bool:
	return from_id == site_id or to_id == site_id


## The end of the road that is not [param site_id], or -1 when the road does not
## touch it at all.
func other_end(site_id: int) -> int:
	if from_id == site_id:
		return to_id
	if to_id == site_id:
		return from_id
	return -1


## Whether this is the same road as one between [param a] and [param b], in
## either direction.
func joins(a: int, b: int) -> bool:
	return (from_id == a and to_id == b) or (from_id == b and to_id == a)


func to_dict() -> Dictionary:
	return {
		&"from": from_id,
		&"to": to_id,
		&"distance": distance,
		&"day_cycles": day_cycles,
	}


static func from_dict(data: Dictionary) -> RunMapLink:
	var link := RunMapLink.new()
	link.from_id = int(data.get(&"from", -1))
	link.to_id = int(data.get(&"to", -1))
	link.distance = float(data.get(&"distance", 0.0))
	link.day_cycles = int(data.get(&"day_cycles", 1))
	return link
