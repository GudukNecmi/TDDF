class_name SunController
extends Node2D
## The map's sun. One node per world, and the single source of truth for where the
## light comes from, what colour it is, and where every shadow in the game falls.
##
## [b]There is one sun and everything is lit by it.[/b] That is the whole point of
## this node. Before it, each [Sprite2D] threw a shadow of its own from its own
## local position and its own rotation, so a character turning to face left turned
## their shadow round with them, a spinning weapon swung its shadow about, and a
## head that had come off cast a second shadow inside its own body's. None of that
## is possible now: a caster contributes a silhouette and a place to stand, and
## this node decides where the light puts it.
##
## [b]It is not a day cycle and must never become one.[/b] Which hour it is belongs
## to [DayClock] - the session's position - and to [DayCycleDirector] - the map's
## list of stages and what they are called. This node asks the existing director
## which stage is being played and looks up the [SunStage] at that index. Adding a
## seventh hour is adding a stage there and a sun here; there is no second list of
## stage names anywhere and nothing here decides what time it is.
##
## [b]The sun travels.[/b] The stage itself changes in one step - a round ends, or
## a Trouble is cleared and [method DayClock.advance_stages] moves it - but the sun
## crosses the sky over the seconds after it, and because every shadow is derived
## from where it is now, every shadow in the world swings and lengthens together
## without being told anything.
##
## [b]It holds the light but does not own the ambience.[/b] Each stage carries the
## colour of the light and what lamps should scale their energy by, and both are
## readable here - see [method get_light_color] and [method get_light_energy]. The
## world's [CanvasModulate] still belongs to [DayCycleDirector], the vignette is
## its own and [AmbientLightDimmer] still reads the room for the player's lamp;
## this is a place for lighting to ask from, not a second lighting system. Lamps
## that want the hour opt in by joining [member light_group].

## How the sun's rays are treated.
enum ProjectionMode {
	## The sun is a place. Rays fan out from it, so shadows across the map lean
	## very slightly away from wherever it is standing and an object walking past
	## underneath it sees its shadow swing. How pronounced that is is
	## [member SunStage.sun_distance] - a far sun is almost parallel.
	SUN_POSITIONAL,
	## The sun is infinitely far away and the rays are parallel, so every shadow on
	## the map lies along exactly the same world direction. Cheaper to reason about
	## and completely uniform.
	SUN_DIRECTIONAL,
}

## Emitted when the sun has been sent to a new hour, with the stage it is
## travelling to. Once per change, at the start of the journey.
signal sun_stage_changed(state: SunState, stage_index: int)
## Emitted every time the live sun moves - each frame while it is crossing, and
## once when it settles. Static casters hang off this so they repaint while the
## day turns and cost nothing while it does not.
signal sun_updated(state: SunState)

## Group this joins, so a shadow can find the sun without a path across the scene -
## and so something spawned into the world halfway through a round finds it just as
## easily as something that was there when the map loaded.
const GROUP := &"sun"

## Where the sun stands at each hour, in the same order as
## [member DayCycleDirector.stages]. The desert's six run dawn, morning, noon,
## evening, twilight, night. An empty array leaves the map unlit, which every
## caster reads as "do not draw".
@export var stages: Array[SunStage] = []
## How long the sun takes to travel from one hour to the next, in seconds. A stage
## can ask for its own with [member SunStage.transition_duration].
@export_range(0.0, 20.0, 0.05) var transition_duration: float = 1.6
## Pins the sun to one hour whatever the day cycle says. -1 - the default - follows
## it properly. Any other value is an index into [member stages], for looking at
## one hour while tuning it.
@export var stage_override: int = -1
## Whether the rays fan out from the sun's own place or run parallel - see
## [enum ProjectionMode].
@export var projection_mode: ProjectionMode = ProjectionMode.SUN_POSITIONAL:
	set(value):
		projection_mode = value
		if is_node_ready():
			_publish()

@export_group("Ground plane")
## The point the sun's distance and direction are measured around. Left unset the
## sun is anchored to this node's own position, which is what puts it over the
## middle of the arena when the node is placed there.
@export var sun_anchor_path: NodePath
## How far above its ground position the world's floor is taken to be, in world
## pixels, added to every object's measured height. Normally 0 - it is here so a
## map drawn with a raised floor can be corrected in one place instead of in every
## caster.
@export_range(-512.0, 512.0, 1.0) var ground_plane_height: float = 0.0

@export_group("Day cycle")
## The map's [DayCycleDirector], found by group when left unresolved. This is the
## only thing here that knows what time it is, and it is asked rather than copied.
@export var day_cycle_path: NodePath
## Group the map's day cycle is found in when [member day_cycle_path] is empty.
@export var day_cycle_group: StringName = &"day_cycle"

@export_group("Lighting")
## Whether lamps that have opted in are scaled by the hour's own energy.
##
## Off by default on purpose: the world already has [DayCycleDirector] writing the
## ambient colour, [WorldZone] blending it and [AmbientLightDimmer] reading the
## room, and a second system writing the same lights would fight all three. Turning
## it on is how a map hands the hour to lamps that want it, and only to those.
@export var apply_light_energy: bool = false
## Group a [Light2D] joins to be scaled by the hour. Its authored energy is
## remembered the first time it is seen, so the hour multiplies what the artist set
## rather than compounding on itself.
@export var light_group: StringName = &"sun_lit"

## The blended stage the sun is standing at. Written in place, never replaced.
var _live := SunStage.new()
## Where the blend is coming from - a snapshot of the live stage as the hour
## changed, so an hour forced part way through a journey eases out of where the sun
## actually is rather than snapping back.
var _from := SunStage.new()
var _to: SunStage
## The one live sun in the world. Every caster holds this reference.
var _state := SunState.new()
var _stage_index: int = -1
var _elapsed: float = 0.0
var _duration: float = 0.0
## Authored energy of each opted-in lamp, so the hour scales the artist's number.
var _light_energies: Dictionary = {}


## Joined here rather than in [method Node._ready] for the same reason
## [DayCycleDirector] does it: every node's [method Node._enter_tree] runs before
## any node's [method Node._ready], so a caster readying anywhere in the map finds
## the sun whatever order the scene happens to be built in.
func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_process(false)
	_follow_day_cycle()
	_snap_to_current_stage()


func _process(delta: float) -> void:
	_elapsed += delta
	var t := 1.0 if _duration <= 0.0 else clampf(_elapsed / _duration, 0.0, 1.0)
	# Eased so the sun arrives rather than stops.
	SunStage.blend(_from, _to, smoothstep(0.0, 1.0, t), _live)
	_publish()
	if t >= 1.0:
		set_process(false)


## The map's sun, found by group. Null means this map has none, which every caster
## reads as "no shadows here" rather than as a failure - so a scene opened on its
## own still runs.
static func get_active(from_node: Node) -> SunController:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as SunController


## The live sun every caster reads. [b]The same object every time[/b] - hold the
## reference and read it whenever, rather than asking again each frame.
func get_state() -> SunState:
	return _state


## Whether this map has a sun authored at all.
func has_stages() -> bool:
	return not stages.is_empty()


## Which hour the sun is standing at, as an index into [member stages]. -1 when the
## map has none.
func get_stage_index() -> int:
	return _stage_index


## Whether the sun is currently crossing between two hours.
func is_travelling() -> bool:
	return is_processing()


## Where the sun is right now, as an (x, y, height) point in world space.
func get_sun_point() -> Vector3:
	return _state.get_sun_point()


## Where a point at [param ground_position], [param visual_height] above the floor,
## throws its shadow. The one projection in the game - see
## [method SunState.project].
func project(ground_position: Vector2, visual_height: float) -> Vector2:
	return _state.project(ground_position, visual_height + ground_plane_height)


## Which way a shadow lies at [param ground_position], in world space.
func get_shadow_direction_at(ground_position: Vector2) -> Vector2:
	return _state.shadow_direction_at(ground_position)


## The colour of the light right now, for lighting rather than for shadows.
func get_light_color() -> Color:
	return _state.light_color


## What a lamp, torch or muzzle flash should multiply its authored energy by right
## now. The seam meant for the existing lights to read, so the hour reaches them
## through the same sun the shadows come from instead of a second set of numbers.
func get_light_energy() -> float:
	return _state.light_energy


## How strongly [method get_light_color] should apply, 0 to 1.
func get_ambient_intensity() -> float:
	return _state.ambient_intensity


## Asks the day cycle again and sends the sun to whatever it now says. Public so a
## debug key or a system that forces an hour can push the change without the world
## being rebuilt around it.
func refresh() -> void:
	var index := _resolve_stage_index()
	if index == _stage_index:
		return
	_begin_transition(index)


## Sends the sun to [param stage_index] over [param duration] seconds, ignoring
## what the day cycle says. For a debug panel stepping through the hours; ordinary
## play never calls it.
func force_stage(stage_index: int, duration: float = -1.0) -> void:
	if stages.is_empty():
		return
	_begin_transition(posmod(stage_index, stages.size()), duration)


## Puts the sun straight at the current hour with no journey at all. What the map
## does as it loads: the world is being built, so there is nowhere for the sun to
## have come from.
func snap_to_stage(stage_index: int) -> void:
	if stages.is_empty():
		return
	_stage_index = posmod(stage_index, stages.size())
	_to = stages[_stage_index]
	if _to == null:
		return
	_live.copy_from(_to)
	_from.copy_from(_to)
	set_process(false)
	_read_state()
	sun_stage_changed.emit(_state, _stage_index)
	_publish()


## Where the sun's distance and direction are measured from.
func get_sun_anchor() -> Vector2:
	if not sun_anchor_path.is_empty():
		var node := get_node_or_null(sun_anchor_path) as Node2D
		if node != null:
			return node.global_position
	return global_position


func _begin_transition(stage_index: int, duration: float = -1.0) -> void:
	if stages.is_empty():
		return
	var index := posmod(stage_index, stages.size())
	var target := stages[index]
	if target == null:
		return

	_stage_index = index
	# From wherever the sun genuinely is, not from the last settled hour, so an hour
	# forced part way through a journey eases out of where the world already looks.
	_from.copy_from(_live)
	_to = target
	_elapsed = 0.0
	_duration = duration
	if _duration < 0.0:
		_duration = target.transition_duration
	if _duration < 0.0:
		_duration = transition_duration

	_read_state()
	sun_stage_changed.emit(_state, _stage_index)
	if _duration <= 0.0:
		_live.copy_from(_to)
		_publish()
		set_process(false)
		return
	set_process(true)


func _snap_to_current_stage() -> void:
	if stages.is_empty():
		_stage_index = -1
		return
	snap_to_stage(_resolve_stage_index())


## Rewrites the one live state from the blended stage and the map's anchor, then
## tells the world it moved. Everything reading the sun sees the same object, so
## there is nothing to keep in step.
func _publish() -> void:
	_read_state()
	_apply_lights()
	sun_updated.emit(_state)


func _read_state() -> void:
	_state.read_from(
		_live, get_sun_anchor(), projection_mode == ProjectionMode.SUN_DIRECTIONAL)


## Which hour is being played, asked of the map's existing day cycle. The override
## wins, then the day cycle, then the first stage - so a scene with no day cycle in
## it at all still shows something.
func _resolve_stage_index() -> int:
	if stages.is_empty():
		return -1
	if stage_override >= 0:
		return stage_override % stages.size()

	var cycle := _resolve_day_cycle()
	if cycle == null or not cycle.has_method(&"get_stage_index"):
		return 0
	return posmod(cycle.call(&"get_stage_index"), stages.size())


## Hangs the sun off the day cycle's own announcement, so nothing that moves the
## hour has to know this node exists. [signal DayCycleDirector.stage_applied] is
## emitted as the map loads and again on every refresh, which is every way the hour
## is ever moved.
func _follow_day_cycle() -> void:
	var cycle := _resolve_day_cycle()
	if cycle == null or not cycle.has_signal(&"stage_applied"):
		return
	if not cycle.is_connected(&"stage_applied", _on_stage_applied):
		cycle.connect(&"stage_applied", _on_stage_applied)


func _on_stage_applied(_stage: Resource, _stage_index: int) -> void:
	refresh()


func _resolve_day_cycle() -> Node:
	if not day_cycle_path.is_empty():
		var node := get_node_or_null(day_cycle_path)
		if node != null:
			return node
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(day_cycle_group)


## Scales the energy of every lamp that opted in. Off unless a map asks for it -
## see [member apply_light_energy] - and it multiplies the authored energy rather
## than replacing it, so a torch stays brighter than a candle at every hour.
func _apply_lights() -> void:
	if not apply_light_energy or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(light_group):
		var light := node as Light2D
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _light_energies.has(id):
			_light_energies[id] = light.energy
		light.energy = float(_light_energies[id]) * _state.light_energy
