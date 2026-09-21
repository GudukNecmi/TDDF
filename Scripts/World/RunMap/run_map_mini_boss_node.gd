class_name RunMapMiniBossNode
extends Node
## The run map's mini boss points: who is waiting at each, and what happens when
## the piece arrives on one.
##
## [b]It is the second listener on [signal RunMapDirector.site_reached], and it
## is built exactly like the first.[/b] [RunMapBanditNode] answers bandit points
## the same way: it hears an arrival, decides what that point is worth, hands the
## encounter to [WorldMapCombatBridge] and writes the point down as dealt with.
## Nothing about riding, generating or drawing the map is touched by either, and
## neither knows the other exists - which is the whole point of the arrival being
## a signal rather than a branch in [RunMapDirector].
##
## [b]What happens after the scene change is not written here.[/b] Arriving on a
## mini boss point hands it to
## [method WorldMapCombatBridge.try_begin_mini_boss_encounter], which stages the
## same record every other encounter stages and goes to the same arena. There the
## fight opens with the support group, and [RunMiniBossFight] brings the man in
## once they are down. This node's whole job is deciding [i]who[/i] is on a point
## and [i]how many[/i] men are in front of him.
##
## [b]Both are rolled from the map's own seed, not stored.[/b] A point's support
## count comes out of a generator seeded from the graph's seed and the point's id
## - see [method support_count_for] - so it is the same number every time it is
## asked for, survives the arena being built and torn down, and needs nothing
## added to [RunMapSite] to hold it. The man's look is keyed off the point in the
## same way, so every mini boss point on a map is a different outlaw and the same
## point is always the same one.

## Emitted the instant a mini boss point's fight has been committed to, with the
## point and the man. For a readout or a smoke check; the point has already been
## written down as dealt with by the time this fires.
signal mini_boss_committed(site: RunMapSite, boss: MiniBossBrief)

@export_group("Wiring")
@export var director_path: NodePath = ^"../RunMapDirector"
@export var view_path: NodePath = ^"../RunMapView"
## The encounter bridge this hands an arrival to. Optional: a map with none
## simply arrives on a mini boss point and does nothing, which is what a run map
## opened on its own for tuning should do.
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"

@export_group("Which points are mini bosses")
## Every kind of mini boss point this map has, one [RunMapMiniBossEncounter]
## each. [b]Adding a harder mini boss point is a [code].tres[/code] here[/b] - no
## threshold, branch or count in this file names one.
@export var encounters: Array[RunMapMiniBossEncounter] = []

var _director: RunMapDirector
var _view: RunMapView
var _bridge: WorldMapCombatBridge


func _ready() -> void:
	_director = get_node_or_null(director_path) as RunMapDirector
	_view = get_node_or_null(view_path) as RunMapView
	if _director != null and not _director.site_reached.is_connected(_on_site_reached):
		_director.site_reached.connect(_on_site_reached)


## The entry answering points of [param kind], or null for a handle no entry
## names - which every caller reads as "not a mini boss point".
func encounter_for(kind: StringName) -> RunMapMiniBossEncounter:
	for entry: RunMapMiniBossEncounter in encounters:
		if entry != null and entry.kind == kind:
			return entry
	return null


## How many men stand in front of the boss at [param site], on the map
## [param graph]. The same answer every time for the same point on the same map,
## since the roll is seeded from the two of them rather than kept anywhere.
## 0 for a point no entry answers.
func support_count_for(graph: RunMapGraph, site: RunMapSite) -> int:
	if graph == null or site == null:
		return 0
	var entry := encounter_for(site.kind)
	if entry == null:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graph.seed, site.id, &"mini_boss"])
	return rng.randi_range(
		mini(entry.min_support, entry.max_support),
		maxi(entry.min_support, entry.max_support))


## Who is waiting at [param site] - see [MiniBossBrief]. Null for a point no
## entry answers.
##
## [b]The contract id is deliberately empty.[/b] There is no poster behind a run
## map boss, so there is nothing for [BossDefeat] to close out and nothing for it
## to pay - which is exactly what is wanted until this point has rewards of its
## own.
func boss_for(graph: RunMapGraph, site: RunMapSite) -> MiniBossBrief:
	var entry := encounter_for(site.kind if site != null else &"")
	if entry == null:
		return null
	var brief := MiniBossBrief.new()
	brief.display_name = entry.display_name
	brief.health_multiplier = entry.boss_health_multiplier
	brief.known = entry.boss_knowledge
	brief.look_key = entry.look_key
	if brief.look_key.is_empty():
		# Keyed off the point, so the same point always produces the same man and
		# two points on one map produce two different ones - the same job
		# [method MiniBossDirector.look_key_for] does off a target id.
		brief.look_key = StringName("run_map_boss_%d_%d"
			% [graph.seed if graph != null else 0, site.id])
	return brief


# --- Arriving on one ------------------------------------------------------------

func _on_site_reached(site: RunMapSite) -> void:
	if site == null:
		return
	var entry := encounter_for(site.kind)
	if entry == null:
		return
	var bridge := _resolve_bridge()
	if bridge == null:
		return

	var graph := _director.get_graph() if _director != null else null
	var region := _director.region_id if _director != null else &""
	# Everything the point is worth is read off it while it still reads as a mini
	# boss point. It is renamed a line later, and both of these answer by the
	# point's own handle - see [method encounter_for] - so asking afterwards would
	# be asking a point that is no longer one.
	var boss := boss_for(graph, site)
	var support := support_count_for(graph, site)
	if boss == null:
		return

	# Written down before the bridge is asked, because a mini boss point asks no
	# question: the call below changes scene, and the map is freed with it. See
	# [RunMapBanditNode._on_answered], which writes its point down for the same
	# reason at the one moment it can.
	if not entry.cleared_kind.is_empty():
		site.kind = entry.cleared_kind
	if _director != null:
		_director.store_graph()
	if _view != null:
		_view.refresh()

	if bridge.try_begin_mini_boss_encounter(region, support, boss):
		mini_boss_committed.emit(site, boss)
		return

	# Refused - something else is already running - so the point is put back
	# exactly as it was found and will ask again the next time the piece stands
	# on it.
	site.kind = entry.kind
	if _director != null:
		_director.store_graph()
	if _view != null:
		_view.refresh()


func _resolve_bridge() -> WorldMapCombatBridge:
	if _bridge != null and is_instance_valid(_bridge):
		return _bridge
	_bridge = get_node_or_null(bridge_path) as WorldMapCombatBridge
	if _bridge == null:
		_bridge = WorldMapCombatBridge.get_active(self)
	return _bridge
