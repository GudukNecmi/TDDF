class_name DayCycleDirector
extends Node
## The map's own clock face: which of its hours is being played, and what that
## does to it.
##
## The split of work is the same one the map already uses for its shadows. The
## session's *position* in the day is a single number that has to survive the
## world being rebuilt between rounds, so it lives in the [code]DayCycle[/code]
## autoload. Everything about what an hour actually looks like - how many there
## are, what they are called, their colours, their own scenery - lives here, in
## the map's own scene, as an inspector array of [DayStage] resources. A second
## map is another director with another array, and neither map holds a setting
## about the other.
##
## Applying a stage is deliberately one line of effect: the world's ambient
## [CanvasModulate] is set to the stage's colour. That is the only thing an hour
## currently changes, and the lighting system underneath it is untouched.
##
## [b]This node is the single authority on what time of day it is.[/b] The hour's
## name, its icon and the world's darkness are three views of one answer, and all
## three are read from here: [DayStageDisplay] for the HUD and the next-round
## button, [RoundIntro] for the title card, and [WorldZone] for the colour it
## blends the base's own gloom away from. Nothing keeps a second copy of the hour
## and nothing else decides what colour "outside" is, so the readout and the
## darkness cannot come apart - which is exactly what used to happen when the
## base's zone captured whatever colour it happened to find on the
## [CanvasModulate] and then held the world to it for the rest of the visit.
##
## The map's *position* in the day still lives in the [code]DayCycle[/code]
## autoload, because it has to survive the world being rebuilt between rounds.
## What that position means - which stage, what colour, what picture - is decided
## here, once, and handed out.
##
## [b]The hooks for later.[/b] A stage can carry scenery of its own, and two
## routes are already wired for it:
##
##   * [member DayStage.extra_scatter_layers] are handed to the map's
##     [PropScatter], which strews them about exactly as it does the shared
##     cacti and bushes. This is what "add birds to dawn" will be - a bird prop
##     scene, a [ScatterLayer] holding it, dropped into the dawn stage's array.
##   * [member DayStage.extra_scenes] are instanced once each into
##     [member extras_container_path], for something there is only one of.
##
## Both are empty on every stage until there is art for them, so the desert is
## currently the same set of props at every hour, as it should be.
##
## The stage is resolved lazily and cached, so anything that asks - the scatter,
## in its own [method Node._ready] - gets the same answer whatever order the map's
## nodes happen to ready in.

## Emitted once the hour has been applied, with the stage that was chosen.
signal stage_applied(stage: DayStage, stage_index: int)

## Group this joins, so the scatter and anything else can find the map's clock
## without a path across the scene.
const GROUP := &"day_cycle"

## The map's hours, in the order they are played. The desert's six run dawn,
## morning, noon, evening, twilight, night, and the cycle wraps back to the
## first. An empty array leaves the map with no day cycle at all and changes
## nothing about it.
@export var stages: Array[DayStage] = []
## Pins the map to one hour whatever the session is up to. -1 - the default -
## follows the day cycle properly. Any other value is an index into
## [member stages], for looking at one hour while tuning it.
@export var stage_override: int = -1
## The session's clock - the [code]DayCycle[/code] autoload - followed so an hour
## moved [i]during[/i] a round shows without the world being rebuilt.
##
## [b]It matters because the day no longer only moves between rounds.[/b] Clearing a
## Trouble Danger advances the clock by a stage - see [DangerDirector] - and the
## player is standing in the world while it happens, so the darkness and the HUD
## would otherwise be showing the hour before it until the next rebuild. Left
## unresolved the map simply keeps the hour it was built at, which is what it did
## before anything moved the clock mid-round.
@export var clock_path: NodePath = ^"/root/DayCycle"

@export_group("World time")
## The continuous clock this map prefers, when it can be found - the same
## [code]WorldClock[/code] autoload [SunController] already follows. A fixed
## path rather than a group, because an autoload has exactly one address and
## it never moves. Left empty, or pointing at nothing that answers
## [method WorldTimeManager.get_time_period_index], this falls back to
## [member clock_path] above exactly as it always did.
@export var world_time_path: NodePath = ^"/root/WorldClock"
## Whether the continuous clock is actually followed when it is found. Off
## keeps this map on the old round-based [code]DayCycle[/code] behaviour even
## with the autoload present - for a scene that wants to prove the old path
## still works.
##
## On - the default - is what makes the world's darkness, [SunController]'s
## sun and every shadow on it read the identical hour continuously: the ambient
## colour is no longer only written once as the map loads or once a round is
## won, it is re-blended every frame between the same two authored
## [member DayStage.ambient_colour] neighbours [SunController] is already
## blending its own [SunStage] pair between - see [method get_world_time_ambient_colour],
## the shared formula both now read.
@export var follow_world_time: bool = true

@export_group("Ambient")
## Whether the stage's colour is written to the world's ambient light at all.
@export var apply_ambient: bool = true
## Group the world's ambient [CanvasModulate] is found in - the same one
## [WorldZone] blends and [AmbientLightDimmer] reads.
@export var ambient_group: StringName = &"ambient_modulate"

@export_group("Stage scenery")
## Node the stage's [member DayStage.extra_scenes] are parented to. Left
## unresolved they are parented to this node, which keeps the map tidy but does
## not sort them with the scenery - point it at the props container for anything
## that should.
@export var extras_container_path: NodePath

var _stage: DayStage
var _stage_index: int = -1
var _resolved: bool = false
## The [WorldTimeManager] this map is following, or null when none was found -
## resolved once, in [method _ready], the same node [SunController] resolves
## it by, and it never moves once the game is running.
var _world_time: Node
## Whether something outside this class currently owns the ambient
## [CanvasModulate] outright - see [method apply_ambient_color]. While true,
## [method _apply_ambient] writes nothing, so a stage change the session's
## clock announces in the meantime - [method DayClock.advance_stages] mid-fight,
## say - cannot silently paint over a colour a caller pushed on purpose.
## [method get_stage] and everything built on it are untouched by this and go
## on reading the session's real hour throughout; only this class's own one
## write to the [CanvasModulate] is ever held back.
var _ambient_overridden: bool = false


## Joined here rather than in [method Node._ready] because the scatter asks for
## the hour's scenery from its own `_ready`, and every node's `_enter_tree` runs
## before any node's `_ready` - so the clock is findable whatever order the map's
## nodes happen to sit in.
func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_world_time = _resolve_world_time()
	_follow_clock()
	_follow_world_time_signal()
	apply()
	_spawn_extra_scenes()
	stage_applied.emit(get_stage(), get_stage_index())
	set_process(_follows_world_time())


## Re-blends the ambient colour every frame while [method _follows_world_time]
## is true - see [member follow_world_time]'s own doc for why a single write
## as the map loads is no longer enough once the hour turns continuously
## rather than only between rounds.
func _process(_delta: float) -> void:
	_apply_ambient()


## Writes the hour to the world's ambient light. Called as the map loads, and
## public so anything that forces a stage can push the change without the world
## being rebuilt around it.
func apply() -> void:
	_apply_ambient()


## Writes [param color] straight to the world's ambient [CanvasModulate],
## bypassing [method get_stage] entirely - for a caller that has already
## worked out a colour finer-grained than a single stage, such as
## [WorldMapCombatBridge] blending between two adjacent [member stages]' own
## [member DayStage.ambient_colour] by how far a continuous clock has turned
## between them. The authored colours are still the only colours involved;
## this only skips *which one* of them [method get_stage] would have picked.
##
## Reads [member ambient_group] and respects [member apply_ambient] exactly as
## [method apply] does, so this is the same one write target every other path
## in this class already uses rather than a second ambient system - and a map
## with ambient turned off stays untouched by this too.
##
## Also marks [member _ambient_overridden], so the colour just written holds
## until [method release_ambient_override] is called even if the session's own
## clock announces an hour change in between - see that member's own doc.
func apply_ambient_color(color: Color) -> void:
	_ambient_overridden = true
	if not apply_ambient:
		return
	var ambient := get_tree().get_first_node_in_group(ambient_group) as CanvasModulate
	if ambient == null:
		return
	ambient.color = color


## Gives the ambient [CanvasModulate] back to this class's own hour. Lifts
## [member _ambient_overridden] only - a caller that wants the colour actually
## repainted right away still has to ask [method apply] or [method refresh]
## for it afterwards, which [method WorldMapCombatBridge._restore_combat_ambient]
## always does.
func release_ambient_override() -> void:
	_ambient_overridden = false


## Whether [method apply_ambient_color] currently owns the ambient
## [CanvasModulate]. Public so another writer of the same one node - today
## only [WorldZone], which blends its own colour onto it as the player crosses
## in and out - can ask before it paints over a colour a caller pushed on
## purpose, the same reason [method _apply_ambient] itself checks this first.
func is_ambient_overridden() -> bool:
	return _ambient_overridden


## Where [param clock] currently sits between two neighbouring [member stages]
## of this map's own authored colours - the same continuous read
## [SunController] already takes of the matching [SunStage] pair. Nothing here
## invents a colour: [member stages] is read exactly as authored and only the
## two neighbours [param clock] currently sits between are ever touched.
##
## Public so every caller that wants the World Map's actual hour rather than
## the discrete one [method get_stage] snaps to reads the identical formula
## instead of keeping a second copy of it - today that is
## [method WorldMapCombatBridge._match_combat_ambient_to_world_time], which
## freezes this once for a fight's length, and [WorldZone], which writes it
## fresh every frame the World Map's own zone is stood in.
##
## [param fallback] is handed back untouched when this map has no stages, or
## [param clock] cannot answer [method WorldTimeManager.get_time_period_index] -
## a map or a clock that is not there yet leaves the caller with whatever
## colour it already had rather than a guess.
func get_world_time_ambient_colour(clock: Node, fallback: Color = Color.WHITE) -> Color:
	if clock == null or not clock.has_method(&"get_time_period_index") or stages.is_empty():
		return fallback

	var count := stages.size()
	var index := posmod(int(clock.call(&"get_time_period_index")), count)
	var next_index := posmod(index + 1, count)
	var from_stage := stages[index]
	var to_stage := stages[next_index]
	if from_stage == null or to_stage == null:
		return fallback

	var progress := 0.0
	if clock.has_method(&"get_period_progress"):
		progress = clampf(clock.call(&"get_period_progress"), 0.0, 1.0)
	return from_stage.ambient_colour.lerp(to_stage.ambient_colour, progress)


## Asks the clock again, and pushes whatever it now says.
##
## [b]The cached answer is thrown away and worked out afresh[/b] - see
## [method _resolve] - so everything that reads the hour through this node moves
## together: the ambient light here, the icon and the word on the HUD through
## [signal stage_applied], and the next card that names the hour.
##
## [b]The stage's scenery is deliberately not built again.[/b] It is instanced once,
## as the map loads, and a refresh that repeated it would strew a second set of dawn
## birds across the desert every time the clock moved. What an hour looks like in
## props is settled when the world is built; what it looks like in light is not.
func refresh() -> void:
	_resolved = false
	_stage = null
	_stage_index = -1
	apply()
	stage_applied.emit(get_stage(), get_stage_index())


## The map's clock, found by group. Null means this map has no day cycle, which
## every caller reads as "there is nothing extra to add".
static func get_active(from_node: Node) -> DayCycleDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as DayCycleDirector


## Which hour is being played, as an index into [member stages]. -1 when the map
## has no stages at all.
func get_stage_index() -> int:
	_resolve()
	return _stage_index


## The hour being played, or null when the map has no stages.
func get_stage() -> DayStage:
	_resolve()
	return _stage


## What this hour is called, for a readout or a debug print.
func get_stage_name() -> StringName:
	var stage := get_stage()
	return &"" if stage == null else stage.stage_name


## The stage [param offset] hours along from the one being played, wrapping round
## the end of the day exactly as the cycle itself does.
##
## 0 is the hour now - so everything can be read through this one call - and 1 is
## the hour the *next* round will be played at, which is what the NEXT ROUND
## button shows. Because it wraps through [member stages] in order, "twilight is
## followed by night" is the order of the inspector array and not a rule written
## anywhere in code.
##
## Null when the map has no stages, which every caller reads as "no day cycle".
func get_stage_at_offset(offset: int) -> DayStage:
	_resolve()
	if stages.is_empty() or _stage_index < 0:
		return null
	return stages[posmod(_stage_index + offset, stages.size())]


## Colour the world's unlit darkness is at this hour. [b]The authoritative answer
## to "how dark is it".[/b]
##
## [WorldZone] blends away from this rather than from whatever colour it happened
## to find on the [CanvasModulate], so the base's gloom is always measured against
## the hour the HUD is showing. [param fallback] is returned by a map with no day
## cycle, so a world without one keeps whatever darkness it was authored with.
func get_ambient_colour(fallback: Color = Color.WHITE) -> Color:
	if _follows_world_time():
		return get_world_time_ambient_colour(_world_time, fallback)
	var stage := get_stage()
	return fallback if stage == null else stage.ambient_colour


## The scattered scenery this hour adds to the map's shared set. Empty for every
## stage until one is given some - see [member DayStage.extra_scatter_layers].
##
## Read by [PropScatter] as it lays the map out, so stage scenery is placed by
## exactly the same code, with the same spacing and clearings, as the cacti.
func get_extra_scatter_layers() -> Array[ScatterLayer]:
	var stage := get_stage()
	if stage == null:
		return []
	return stage.extra_scatter_layers


## Decided once and remembered. Everything else here reads the answer, so the
## hour cannot come out differently for two nodes in the same map.
func _resolve() -> void:
	if _resolved:
		return
	_resolved = true

	if stages.is_empty():
		_stage_index = -1
		_stage = null
		return

	if stage_override >= 0:
		_stage_index = stage_override % stages.size()
	else:
		_stage_index = _get_clock_stage_index()

	_stage = stages[_stage_index]


## Asked of the session's clock, which is the only thing that survives the world
## being rebuilt between rounds. A project without the autoload stays on the first
## stage rather than failing, so the map still opens on its own.
func _get_clock_stage_index() -> int:
	if _follows_world_time():
		return posmod(int(_world_time.call(&"get_time_period_index")), stages.size())
	var clock := _resolve_clock()
	if clock == null or not clock.has_method(&"get_stage_index"):
		return 0
	return clampi(clock.call(&"get_stage_index", stages.size()), 0, stages.size() - 1)


## Hangs the map off the clock's own announcement, so nothing that moves the hour
## has to know this node exists. [method DayClock.advance_stages] and
## [method DayClock.set_stage_index] both go through it, which is every way the hour
## is ever moved.
func _follow_clock() -> void:
	var clock := _resolve_clock()
	if clock == null or not clock.has_signal(&"stage_forced"):
		return
	if not clock.is_connected(&"stage_forced", _on_stage_forced):
		clock.connect(&"stage_forced", _on_stage_forced)


func _on_stage_forced(_stage_index: int) -> void:
	refresh()


func _resolve_clock() -> Node:
	return get_node_or_null(clock_path)


## Whether this map should be reading [WorldTimeManager] right now rather than
## the round-based [code]DayCycle[/code] clock: a continuous clock was
## actually found, following it is switched on, and [member stage_override] is
## not pinning the map to one hour by hand - the same three conditions
## [method SunController._follows_world_time] checks, so the ambient colour
## and the sun agree on which clock is authoritative at every instant, and a
## stage pinned for tuning stays pinned rather than drifting with the clock.
func _follows_world_time() -> bool:
	return _world_time != null and follow_world_time and stage_override < 0 \
			and not stages.is_empty()


func _resolve_world_time() -> Node:
	if world_time_path.is_empty():
		return null
	var node := get_node_or_null(world_time_path)
	if node == null or not node.has_method(&"get_time_period_index"):
		return null
	return node


## Hangs the map off the continuous clock's own announcement, so the HUD's
## name label and icon - both only refreshed on [signal stage_applied] - move
## with every period the world clock crosses rather than waiting for a round
## to end. [method DayClock]'s own [signal DayClock.stage_forced] is still
## followed too - see [method _follow_clock] - so a map with the continuous
## clock switched off keeps refreshing exactly as it always did.
func _follow_world_time_signal() -> void:
	if _world_time == null or not _world_time.has_signal(&"period_changed"):
		return
	if not _world_time.is_connected(&"period_changed", _on_world_time_period_changed):
		_world_time.connect(&"period_changed", _on_world_time_period_changed)


func _on_world_time_period_changed(_period: int, _period_index: int) -> void:
	refresh()


## The one thing an hour currently changes. Written once as the map loads when
## [member follow_world_time] is off - so the base's own darkness blend still
## owns the ambient light from the moment the player walks into it - or every
## frame, continuously blended between two authored neighbours, when it is on.
func _apply_ambient() -> void:
	if not apply_ambient or _ambient_overridden:
		return
	var ambient := get_tree().get_first_node_in_group(ambient_group) as CanvasModulate
	if ambient == null:
		return

	if _follows_world_time():
		ambient.color = get_world_time_ambient_colour(_world_time, ambient.color)
		return

	var stage := get_stage()
	if stage == null:
		return
	ambient.color = stage.ambient_colour


func _spawn_extra_scenes() -> void:
	var stage := get_stage()
	if stage == null or stage.extra_scenes.is_empty():
		return

	var container := get_node_or_null(extras_container_path)
	if container == null:
		container = self

	for scene: PackedScene in stage.extra_scenes:
		if scene == null:
			continue
		var instance := scene.instantiate()
		if instance != null:
			container.add_child(instance)
