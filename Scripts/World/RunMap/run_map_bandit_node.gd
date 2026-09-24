class_name RunMapBanditNode
extends Node
## The run map's bandit points: how many men are waiting at each, and what
## happens when the piece arrives on one.
##
## [b]It is the first listener on [signal RunMapDirector.site_reached].[/b] That
## signal is the seam the run map was built with - "each node event will be a
## listener on that signal that opens its own scene and comes back, not a branch
## added to that file" - and this is the first of them. Nothing about riding,
## generating or drawing the map is touched here: this node answers arrivals and
## writes the point down once it has been dealt with.
##
## [b]Which points are bandit points is not decided here.[/b] That is the
## generator's node distribution - an array of [RunMapSitePlan] on the map's own
## [RunMapGenerator], which deals every kind of place out over the finished
## graph. This node simply answers whichever handles its [member encounters]
## name, so a map with no bandit points on it wires this node up and it never
## fires.
##
## [b]The encounter itself is not written here either.[/b] Arriving on a bandit
## point hands it to [method WorldMapCombatBridge.try_begin_site_encounter] -
## the same class, the same three authored decision screens, the same four
## answers and the same arena an ordinary bandit contact on a free-roam map has
## always gone through. This node decides only [i]how many[/i] men are on a
## point.
##
## [b]How many is rolled from the map's own seed, not stored.[/b] A point's
## count comes out of a generator seeded from the graph's seed and the point's
## id - see [method enemy_count_for] - so it is the same number every time it is
## asked for, survives the arena being built and torn down without being written
## anywhere, and needs nothing added to [RunMapSite] to hold it. The player is
## never shown it: the screen is asked with no count at all.

## Emitted the instant a bandit point's question has been answered, with the
## point and the answer. For a readout or a smoke check; the point has already
## been written down as dealt with by the time this fires.
signal bandit_resolved(site: RunMapSite, outcome: StringName)

@export_group("Wiring")
@export var director_path: NodePath = ^"../RunMapDirector"
@export var view_path: NodePath = ^"../RunMapView"
## The encounter bridge this hands an arrival to. Optional: a map with none
## simply arrives on a bandit point and does nothing, which is what a run map
## opened on its own for tuning should do.
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"

@export_group("Which points are bandits")
## Every kind of bandit point this map has, one [RunMapBanditEncounter] each.
## [b]Adding a third size of bandit point is a [code].tres[/code] here[/b] - no
## threshold, branch or count in this file names one. The desert has two: a
## group of twenty to forty, and a camp of forty to eighty.
@export var encounters: Array[RunMapBanditEncounter] = []

var _director: RunMapDirector
var _view: RunMapView
var _bridge: WorldMapCombatBridge
## The point whose question is currently up, so the answer can be written back
## onto the right one. Null whenever no question is being asked.
var _asking: RunMapSite
## Which entry that point was answered by, so the right cleared handle is
## written onto it.
var _asking_encounter: RunMapBanditEncounter


func _ready() -> void:
	_director = get_node_or_null(director_path) as RunMapDirector
	_view = get_node_or_null(view_path) as RunMapView
	if _director != null and not _director.site_reached.is_connected(_on_site_reached):
		_director.site_reached.connect(_on_site_reached)


## The entry answering points of [param kind], or null for a handle no entry
## names - which every caller reads as "not a bandit point".
func encounter_for(kind: StringName) -> RunMapBanditEncounter:
	for entry: RunMapBanditEncounter in encounters:
		if entry != null and entry.kind == kind:
			return entry
	return null


## How many men are waiting at [param site], on the map [param graph]. The same
## answer every time for the same point on the same map, since the roll is
## seeded from the two of them rather than kept anywhere - see the class doc.
## 0 for a point no entry answers.
func enemy_count_for(graph: RunMapGraph, site: RunMapSite) -> int:
	if graph == null or site == null:
		return 0
	var entry := encounter_for(site.kind)
	if entry == null:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graph.seed, site.id, &"bandit"])
	return rng.randi_range(
		mini(entry.min_enemies, entry.max_enemies),
		maxi(entry.min_enemies, entry.max_enemies))


# --- Arriving on one ------------------------------------------------------------

func _on_site_reached(site: RunMapSite) -> void:
	if site == null or _asking != null:
		return
	var entry := encounter_for(site.kind)
	if entry == null:
		return
	var bridge := _resolve_bridge()
	if bridge == null:
		return

	var graph := _director.get_graph() if _director != null else null
	var region := _director.region_id if _director != null else &""
	_asking = site
	_asking_encounter = entry
	if not bridge.site_encounter_answered.is_connected(_on_answered):
		bridge.site_encounter_answered.connect(_on_answered, CONNECT_ONE_SHOT)
	if bridge.try_begin_site_encounter(
			region, enemy_count_for(graph, site), entry.active_enemies, site.kind):
		return

	# Refused - something else is already running - so the point is left exactly
	# as it was found and will ask again the next time the piece stands on it.
	_asking = null
	_asking_encounter = null
	if bridge.site_encounter_answered.is_connected(_on_answered):
		bridge.site_encounter_answered.disconnect(_on_answered)


## The answer, whichever of the four it was. The point is written down as dealt
## with before anything else happens, because a FIGHT answer is already on its
## way to the arena and the map is about to be freed - see
## [signal WorldMapCombatBridge.site_encounter_answered].
func _on_answered(outcome: StringName) -> void:
	var site := _asking
	var entry := _asking_encounter
	_asking = null
	_asking_encounter = null
	if site == null:
		return

	if entry != null and not entry.cleared_kind.is_empty():
		site.kind = entry.cleared_kind
	if _director != null:
		_director.store_graph()
	if _view != null:
		_view.refresh()
	bandit_resolved.emit(site, outcome)


func _resolve_bridge() -> WorldMapCombatBridge:
	if _bridge != null and is_instance_valid(_bridge):
		return _bridge
	_bridge = get_node_or_null(bridge_path) as WorldMapCombatBridge
	if _bridge == null:
		_bridge = WorldMapCombatBridge.get_active(self)
	return _bridge
