class_name RunMapGraph
extends RefCounted
## A whole run map: every point on it, every road between them, and where the
## player's piece is standing.
##
## [b]It is the run's progression, and it is data.[/b] The desert used to be
## ridden across freely and the map was the world; a run is now a walk through
## this graph - the piece stands on a site, the player picks one of the sites it
## is joined to, the ride is paid for in day cycles and the piece is somewhere
## else. Nothing about that needs a scene, so none of it is in one: the map scene
## draws this and writes choices back into it, and the graph itself lives in
## [WorldMapState]'s own between-scenes memory so a node event changing scene
## cannot lose the run. See [method to_dict].
##
## [b]Roads are undirected and the graph is not a ladder.[/b] [member sites] carry
## a row only because the generator lays them out in rows; movement reads
## [member links] alone, so a road the generator happened to make sideways or
## back down the map is a move the player may take. Riding north is what the
## shape of the graph encourages, not what a rule here enforces.

## Every point on the map, in the order the generator made them. A site's
## [member RunMapSite.id] is its index here, so [method get_site] is a lookup
## rather than a search.
var sites: Array[RunMapSite] = []
## Every road on the map.
var links: Array[RunMapLink] = []
## Which site the run opens on.
var start_id: int = -1
## Which site ends it - the boss, at the northern end.
var boss_id: int = -1
## Where the player's piece is standing now.
var current_id: int = -1
## The seed the generator was given, kept so a map can be made again exactly.
var seed: int = 0

## Roads by the site they touch, built once by [method rebuild_index] and read by
## everything that asks what a site is joined to.
var _by_site: Dictionary = {}


func is_empty() -> bool:
	return sites.is_empty()


## The site with this id, or null for an id no site has.
func get_site(site_id: int) -> RunMapSite:
	if site_id < 0 or site_id >= sites.size():
		return null
	return sites[site_id]


## Where the piece is standing, or null before the run has been placed.
func get_current_site() -> RunMapSite:
	return get_site(current_id)


## Every road touching [param site_id].
func links_of(site_id: int) -> Array[RunMapLink]:
	var found: Array[RunMapLink] = []
	var indices: PackedInt32Array = _by_site.get(site_id, PackedInt32Array())
	for index: int in indices:
		found.append(links[index])
	return found


## Every site [param site_id] is joined to, in the order their roads were made.
func neighbours_of(site_id: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	for link: RunMapLink in links_of(site_id):
		found.append(link.other_end(site_id))
	return found


## The road between two sites, or null when there is none.
func find_link(a: int, b: int) -> RunMapLink:
	for link: RunMapLink in links_of(a):
		if link.joins(a, b):
			return link
	return null


## Whether a road already joins these two, in either direction.
func has_link(a: int, b: int) -> bool:
	return find_link(a, b) != null


## Adds a road and keeps the index in step. Refuses a duplicate and refuses a
## road from a site to itself, so a caller never has to check first.
func add_link(link: RunMapLink) -> bool:
	if link == null or link.from_id == link.to_id:
		return false
	if has_link(link.from_id, link.to_id):
		return false
	var index := links.size()
	links.append(link)
	_note(link.from_id, index)
	_note(link.to_id, index)
	return true


## Adds a point and answers its id.
func add_site(site: RunMapSite) -> int:
	site.id = sites.size()
	sites.append(site)
	return site.id


## Rebuilds the site-to-roads index from [member links]. Called after the graph is
## read back from a dictionary, and by the generator after it has finished pruning.
func rebuild_index() -> void:
	_by_site.clear()
	for index: int in range(links.size()):
		_note(links[index].from_id, index)
		_note(links[index].to_id, index)


## Every site that can be reached from [param origin] by any sequence of roads.
func reachable_from(origin: int) -> PackedInt32Array:
	var seen := {}
	var order := PackedInt32Array()
	var queue: Array[int] = [origin]
	seen[origin] = true
	while not queue.is_empty():
		var at: int = queue.pop_front()
		order.append(at)
		for next: int in neighbours_of(at):
			if seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return order


## The smallest rectangle holding every point, for a camera to frame the map by.
func bounds() -> Rect2:
	if sites.is_empty():
		return Rect2()
	var box := Rect2(sites[0].position, Vector2.ZERO)
	for site: RunMapSite in sites:
		box = box.expand(site.position)
	return box


## Moves the piece, marking where it now stands as seen. [b]This is the one place
## a site becomes revealed[/b], so a later Scout that reveals without riding there
## adds a second caller rather than a second rule.
func move_to(site_id: int) -> bool:
	var site := get_site(site_id)
	if site == null:
		return false
	current_id = site_id
	site.visited = true
	site.revealed = true
	return true


## Marks a site as learned without the piece going there - what a scout, a
## rumour or a map bought in a market would call.
func reveal(site_id: int) -> bool:
	var site := get_site(site_id)
	if site == null or site.revealed:
		return false
	site.revealed = true
	return true


func _note(site_id: int, link_index: int) -> void:
	var indices: PackedInt32Array = _by_site.get(site_id, PackedInt32Array())
	indices.append(link_index)
	_by_site[site_id] = indices


# --- Surviving a scene change ---------------------------------------------------

## The whole graph as plain data, for [WorldMapState] to hold between scenes.
func to_dict() -> Dictionary:
	var site_data: Array[Dictionary] = []
	for site: RunMapSite in sites:
		site_data.append(site.to_dict())
	var link_data: Array[Dictionary] = []
	for link: RunMapLink in links:
		link_data.append(link.to_dict())
	return {
		&"sites": site_data,
		&"links": link_data,
		&"start": start_id,
		&"boss": boss_id,
		&"current": current_id,
		&"seed": seed,
	}


## Reads a graph back out of [method to_dict]. Answers null for anything that is
## not one, which every caller reads as "there is no map yet, generate one".
static func from_dict(data: Dictionary) -> RunMapGraph:
	if data.is_empty() or not data.has(&"sites"):
		return null
	var graph := RunMapGraph.new()
	for entry: Dictionary in data.get(&"sites", []):
		graph.sites.append(RunMapSite.from_dict(entry))
	for entry: Dictionary in data.get(&"links", []):
		graph.links.append(RunMapLink.from_dict(entry))
	graph.start_id = int(data.get(&"start", -1))
	graph.boss_id = int(data.get(&"boss", -1))
	graph.current_id = int(data.get(&"current", -1))
	graph.seed = int(data.get(&"seed", 0))
	graph.rebuild_index()
	return graph
