class_name RunMapSite
extends RefCounted
## One point on a run map: a place the player's piece can stand.
##
## [b]It is a fact, not a node.[/b] The run map is generated fresh for every run
## and has to survive the map scene being freed - a node event will change scene
## and the map has to come back exactly as it was - so the graph is plain data
## held by [WorldMapState] and the scene draws itself from it. See
## [method RunMapGraph.to_dict].
##
## [b]What a site [i]contains[/i] is not decided here.[/b] [member kind] names
## which of the map's authored [RunMapSiteKind] entries draws it, and which
## handle each site carries is dealt out by the generator's own node
## distribution - an array of [RunMapSitePlan] on the map's [RunMapGenerator],
## read once over the finished graph. Adding a kind of place is a
## [code].tres[/code] plan, a [code].tres[/code] kind for the art, and a
## listener on [signal RunMapDirector.site_reached] for what happens there;
## nothing in this file names a single kind of event. [constant KIND_UNKNOWN]
## survives as what a point the player has not learned is [i]drawn[/i] as - see
## [member RunMapView.fog_kind] - and as what a map with no plans at all leaves
## every point.

## The handle for a point whose contents the player has not learned. Every
## generated site starts as this.
const KIND_UNKNOWN := &"unknown"
## The handle for the point the run opens on, at the western end.
const KIND_START := &"start"
## The handle for the point the run ends at, at the eastern end.
const KIND_BOSS := &"boss"

## Which site this is, unique within one graph. Links name their two ends by this
## rather than by holding references, so the graph survives being written out to a
## dictionary and read back.
var id: int = -1
## Where the site sits on the map, in map pixels. East is +X, exactly as it is
## everywhere else in the game, so "progressing towards the boss" is progressing
## towards larger X.
var position: Vector2 = Vector2.ZERO
## Which generated row the site belongs to, counted from 0 at the start. Rows are
## a scaffold for generation and for reasoning about progress; they are
## deliberately [i]not[/i] a movement rule - see [member RunMapGraph.links], which
## are undirected.
var row: int = 0
## Which [RunMapSiteKind] draws it - see the constants above.
var kind: StringName = KIND_UNKNOWN
## Whether the player has learned what is here. A site that has not been revealed
## is drawn as an unknown point, but its existence and every connection into it
## are drawn regardless - that is the whole of the map's fog. See
## [member RunMapView.fog_hides_links].
var revealed: bool = false
## Whether the player's piece has ever stood here.
var visited: bool = false
## The contract this point stands for, or empty for a point that stands for none
## - which is every kind but the bounty boss.
##
## [b]It is written onto the point rather than counted up when the point is
## arrived on.[/b] A run map deals one bounty boss point per contract the player
## rode out carrying, and which point is which man has to be the same answer
## every time it is asked: the map is stored, the scene is torn down to fight and
## built again on the way back, and a contract closed out in between would shift
## any answer that was counted live. So the binding is made once, on a fresh
## graph, and travels with it - see [RunMapBountyBossNode].
var contract_id: StringName = &""


static func make(site_id: int, at: Vector2, site_row: int,
		site_kind: StringName = KIND_UNKNOWN) -> RunMapSite:
	var site := RunMapSite.new()
	site.id = site_id
	site.position = at
	site.row = site_row
	site.kind = site_kind
	return site


func to_dict() -> Dictionary:
	return {
		&"id": id,
		&"position": position,
		&"row": row,
		&"kind": kind,
		&"revealed": revealed,
		&"visited": visited,
		&"contract_id": contract_id,
	}


static func from_dict(data: Dictionary) -> RunMapSite:
	var site := RunMapSite.new()
	site.id = int(data.get(&"id", -1))
	site.position = data.get(&"position", Vector2.ZERO)
	site.row = int(data.get(&"row", 0))
	site.kind = data.get(&"kind", KIND_UNKNOWN)
	site.revealed = bool(data.get(&"revealed", false))
	site.visited = bool(data.get(&"visited", false))
	site.contract_id = data.get(&"contract_id", &"")
	return site
