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
## list of stages and what they are called; or, now, to [WorldTimeManager] - the
## [code]WorldClock[/code] autoload - which owns a continuous position in the same
## six hours. This node still only asks and looks up the [SunStage] at whichever
## index it is given; adding a seventh hour is adding a stage here and nowhere
## else, and there is no second list of stage names anywhere.
##
## [b]The sun travels.[/b] Following [WorldTimeManager] - the ordinary case, since
## it is a project-wide autoload - the sun's position is derived directly from the
## continuous degree every frame: see [method _update_from_world_time]. Failing
## that, it falls back to the way it always travelled: the stage changes in one
## step - a round ends, or a Trouble is cleared and [method DayClock.advance_stages]
## moves it - and the sun eases across the sky over [member transition_duration]
## seconds after it. Either way every shadow is derived from where the sun is now,
## so every shadow in the world swings and lengthens together without being told
## anything.
##
## [b]A caller that takes the sun by hand is never overridden.[/b]
## [method snap_to_stage] and [method force_stage] mark the sun manually driven the
## moment either is called - see [member _manual] - and from then on it holds
## exactly where it was put, following neither clock, until [method refresh] is
## called again. This is what lets a debug tool step through the hours one at a
## time without the World Map's own clock immediately overwriting the frame it
## just asked for.
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

## How far one of the sun's 0-to-1 shading values may drift before it counts as a
## change - see [method _look_moved_enough]. About one step of eight-bit colour,
## which is the finest difference any of them can actually paint.
const LOOK_SLACK := 0.004

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

@export_group("World time")
## The continuous clock this sun prefers, when it can be found - the
## [code]WorldClock[/code] autoload. A fixed path rather than a group, because an
## autoload has exactly one address and it never moves. Left empty, or pointing at
## nothing that answers [method WorldTimeManager.get_time_period_index], the sun
## falls back to [member day_cycle_path] below exactly as it always did.
@export var world_time_path: NodePath = ^"/root/WorldClock"
## Whether the continuous clock is actually followed when it is found. Off keeps
## this sun on the old day-cycle-driven behaviour even with the autoload present -
## for a scene that wants to prove the old path still works.
@export var follow_world_time: bool = true
## Whether the sun is blended continuously between the clock's current hour and
## the next, or set once to the hour the clock is in and held there.
##
## [b]Off, and the sun no longer moves while the world is being looked at.[/b]
## The run map spends time in whole day cycles rather than in real seconds - see
## [member WorldTimeManager.advances_in_real_time] - so a sun blending between
## two anchors would be blending across a gap nothing is crossing. Off, this sun
## snaps to the authored [SunStage] for whichever period the clock is in and
## re-snaps only when the clock crosses into the next one, which is exactly once
## per travel tick: the shadow length and colour an arrival is seen under are the
## hour's own authored ones, and they hold until the next road is taken.
##
## [b]Nothing about the authored hours changes with it.[/b] The same six
## [member stages] are read either way; this decides only whether the sun is
## allowed to stand between two of them.
##
## [b]The world's darkness is a separate switch.[/b] The run map has this off
## and [member DayCycleDirector.world_time_blends] on, so the colour eases from
## one authored hour into the next across a travel tick while the shadows step
## between them - see that member for why the two are deliberately not one.
@export var world_time_blends: bool = false

@export_group("Combat hold")
## Whether this sun is set once as the scene opens and then left alone for the
## whole of it. What an arena wants.
##
## [b]A fight borrows the hour it was picked up in; it does not live through
## one.[/b] The world clock is frozen for the duration of a fight - see
## [method WorldTimeManager.freeze_for_combat] - so the day stage read here is
## the one the player was standing in on the World Map the instant the fight
## started. It is read once, applied once, and neither clock is consulted again:
## no blend runs, [method Node._process] never starts, and the shadows a fight
## opens with are the shadows it ends with. Time is paid for afterwards, on the
## map, by the rules that already govern it.
@export var holds_for_combat: bool = false
## Whether the held sun rakes as long as its day stage ever does.
##
## The World Map's sun travels continuously across each stage, so an hour is not
## one shadow length but a span of them - short at one end, long at the other. On
## true, the fight keeps the stage's own authored direction and colour and takes
## the longest rake that stage reaches, which is what makes a held shadow read as
## a deliberate hour rather than as whichever instant the fight happened to
## begin on. On false, the stage is used exactly as authored.
@export var hold_uses_longest_shadow: bool = true

@export_group("Day cycle")
## The map's [DayCycleDirector], found by group when left unresolved. Only
## consulted when [member follow_world_time] is off, or no [WorldTimeManager] can
## be found.
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

@export_group("Shadow shape")
## Whether an object's height is read off the top of its artwork, rather than added
## up out of where its base sits and how tall it measures.
##
## [b]The two only disagree about artwork drawn below the ground line.[/b] A caster
## whose picture skirts a little under the point it is standing on - a prop with a
## flared base, a figure mid-stride - is standing [i]on[/i] the floor, not sunk
## beneath it, so the part of it below the line is projected where it is and is no
## part of how tall the thing is. Adding it in instead, which is what the sum does,
## stretches every such shadow by however far the artwork dips and shifts the length
## fade with it. The player's own artwork dips about twenty pixels, which at a
## raking hour is a shadow some fifth too long.
##
## Off by default, so a map that has not asked for it - the Arena and the Base - is
## measured exactly as it always was, and keeps the shadow lengths its scenes were
## authored against.
@export var measure_height_to_top: bool = false:
	set(value):
		measure_height_to_top = value
		if is_node_ready():
			_publish()
## Whether the things this map lights are treated as solid objects standing on the
## ground rather than as flat cards facing the camera.
##
## [b]This is what stops a shadow being squashed onto a line.[/b] A caster's
## artwork is a billboard: it is drawn upright, so its width is an extent across
## the screen and its height an extent straight up. Projected literally, such a
## card has no depth at all on the ground - and a card's shadow, cast by a light
## travelling along the very direction the card is wide, is a line. That is exactly
## what happens twice a day here: the authored sun swings right round the compass,
## its ground direction passes through horizontal, and every shadow on the map is
## squashed onto its own ground line - a bright streak covering a fifteenth of the
## area the artwork does.
##
## A billboard stands for something with a body, so turning this on gives the thing
## a footprint: an ellipse as wide as the artwork is and
## [member caster_depth_ratio] as deep, which is what the silhouette's own width is
## laid across. The mark narrows towards that depth as the light comes round to
## face the object edge on, instead of vanishing, and opens back out afterwards.
##
## [b]It is not a turn.[/b] The width is always taken on the side the camera calls
## right, so the object's own left stays on its left at every hour - see
## [method ShadowGroup._lay_across]. A footprint of depth 1 is the one case that
## does turn the silhouette right round with the sun, which is why it is not the
## default.
##
## Nothing else about the projection moves: where a point lands is still
## [method SunState.project] and nothing but, the light's direction and rake are
## still the authored ones, and the spread that makes a head land beyond a body is
## still worked out per point. Only which way the silhouette's width lies changes.
##
## Off by default, so a map that has not asked for it - an arena, most of all -
## keeps exactly the shadows it always had.
@export var solid_casters: bool = false:
	set(value):
		solid_casters = value
		if is_node_ready():
			_publish()
## How deep the body behind a caster's artwork is taken to be, as a fraction of how
## wide that artwork is drawn. Only read where [member solid_casters] is on.
##
## [b]It is the one number that says how far a shadow may narrow.[/b] The footprint
## is an ellipse as wide as the object and this much as deep, and the silhouette's
## width is laid across whichever way that ellipse presents to the light: the full
## width when the light runs down the screen or up it, and this fraction of it at
## the two hours the light runs straight across. 1 is a round footprint, which never
## narrows and so swings the whole silhouette round with the sun; 0 is the flat card
## again, which loses its shadow entirely at those two hours.
##
## Measured against the object rather than authored per prop, so a tent gets a
## tent's depth and a bone a bone's without anything being filled in anywhere.
@export_range(0.0, 1.0, 0.01) var caster_depth_ratio: float = 0.45:
	set(value):
		caster_depth_ratio = value
		if is_node_ready():
			_publish()
## The shortest a shadow is ever allowed to be, as a fraction of the width of
## whatever is casting it. 0 - the default - lets a shadow shorten to nothing.
##
## [b]A thing standing on the ground still covers some of it.[/b] When the sun is
## nearly overhead the rake goes to nothing and the projection has the whole of an
## object compressed into a few pixels along the light, which draws as a torn sliver
## rather than as a shadow. What is missing is the object's own footing: however
## high the sun climbs, a tent still sits on a tent-sized patch of sand.
##
## So the length is given a floor taken from the object itself - measured, never
## authored, so a bone gets a bone's pool and a tent a tent's - and the two are
## joined softly enough that neither end of it can be seen happening: a shadow far
## longer than its own footing is lengthened by a fraction of a percent, one at the
## floor is held there, and everything between slides from one to the other. As the
## pool takes over, the mark also settles under the object's feet rather than
## staying hung off one end of itself, and its edge softens towards
## [member pool_softness].
##
## Around 0.45 gives a pool a little under half as long as the object is wide,
## which with the object's own width across the light reads as the round patch of
## shade under a thing at midday.
@export_range(0.0, 2.0, 0.01) var minimum_shadow_ratio: float = 0.0:
	set(value):
		minimum_shadow_ratio = value
		if is_node_ready():
			_publish()
## Whether a cast shadow's near end sits on the point its caster is standing on,
## rather than being slid back down its own length by
## [member SunStage.shadow_length_anchor].
##
## [b]A footing is a place, not a fraction.[/b] Where an object meets the floor is
## where the sun puts that point, so a mark anchored there is anchored correctly at
## every hour and for every size of thing. The authored slide is a fraction of the
## object's [i]whole reach[/i] instead, so it walks a mark off its object in
## proportion to how big that object is - nothing on a bone, half a tent on a tent -
## which is what makes a large prop's shadow read as detached.
##
## [b]It replaces the slide; it does not remove the centring.[/b] What genuinely
## belongs under the feet is the pool - see [member minimum_shadow_ratio] - and that
## still arrives, derived from how much of the mark is pool rather than authored.
## A map with this on and no pool has every shadow starting at its object's feet.
##
## Off by default, and deliberately so. The authored stages carry a large slide at
## the short-shadow hours - a third of the length at noon - which is the older, cruder
## way of getting a midday shadow to sit under its object, and the Arena and the Base
## still rely on it because neither has a pool to put in its place. The six stage
## resources are shared by every scene, so there is no per-stage value to vary and
## this is the seam instead.
@export var anchor_shadows_on_footing: bool = false:
	set(value):
		anchor_shadows_on_footing = value
		if is_node_ready():
			_publish()
## Whether a shadow on this map is grown out of its caster's own ground-contact
## footprint - see [member ShadowCaster.ground_contact_path].
##
## [b]A prop is not a flat card standing on a line.[/b] The projection treats
## every pixel of a picture as standing upright at one depth, so the whole of a
## tent - its pegs as much as its ridge - is swung round by the light, and the
## mark's near end leaves the thing casting it. What actually happens is that the
## bottom of a prop [i]is lying on the ground[/i]: it covers a patch of floor, and
## that patch does not move at any hour of the day.
##
## With this on, the band of artwork standing on the caster's authored footprint is
## laid flat where it is drawn - fixed under the prop, and turned by nothing - and
## the rest of the picture is projected as a thing standing on the back of that
## patch. So a prop's mark is its own footing plus a rake growing out of it, at
## every hour, and no authored pull or slide is needed to hold the two together -
## see [method ShadowGroup._place], which drops both while a footprint is in play.
##
## Off by default, and it is the Base that still has it off: its props are authored
## against the older placement. The Arena has it on, because the older placement is
## what made an arena tent look as though its shadow had come unstuck from it - the
## authored slide walks a mark off its object by a fraction of that object's whole
## reach, so the taller the prop the worse it reads.
##
## It reaches a caster only through that caster's own authored footprint, which is
## what makes it the shared answer rather than a rule about tents: a prop that has
## authored one is anchored on it, and anything that has not - a figure, its weapon,
## anything it is carrying - is projected exactly as it always was, whatever this
## says.
@export var ground_contact_shadows: bool = false:
	set(value):
		ground_contact_shadows = value
		if is_node_ready():
			_publish()
## How soft a shadow's edge becomes once it is entirely the pool above - see
## [member minimum_shadow_ratio]. Only ever softens: a prop that authored a harder
## edge than this keeps it, because the blend takes whichever is softer.
##
## A midday pool is an ambient shadow rather than a cast one, and a hard-edged
## cut-out is what makes a very short shadow read as broken, so this is high.
@export_range(0.0, 1.0, 0.01) var pool_softness: float = 0.7:
	set(value):
		pool_softness = value
		if is_node_ready():
			_publish()

@export_group("Static shadow cache")
## How far the sun has to actually move before the world is told about it, in
## degrees, while it is being carried continuously by [WorldTimeManager].
##
## [b]A shadow that is standing still should be built once and kept.[/b] Scenery
## hangs off [signal sun_updated] rather than off the frame - see
## [method ShadowGroup._on_sun_updated] - and rebuilds its whole silhouette every
## time it arrives. That is exactly right when the signal means "the sun moved",
## and ruinous once the sun is driven by a continuous clock, because then it
## arrives sixty times a second and a field of props rebuilds sixty times a second
## for a fortieth of a degree of movement each time.
##
## [b]It holds back the announcement, never the sun.[/b] The one live [SunState]
## is still rewritten every single frame, so [method project],
## [method get_state] and [method get_shadow_direction_at] are exact at every
## instant, the [code]WorldClock[/code] still turns at its own rate, and a walking
## figure's shadow still follows the sun continuously - a moving group re-asks the
## live state itself, from [method ShadowGroup.update_group], and never waited on
## this signal for it. What is throttled is only the broadcast that makes the
## standing-still half of the map repaint.
##
## The threshold is read as a swing of the light, and the same figure bounds the
## sun's rake, its height and where it stands, because a relative change in any of
## those moves a shadow's tip by the same fraction of its own length as a swing of
## that many radians does. 0 publishes every frame - what the sun did before this
## existed, and what a map wanting the old behaviour back sets.
@export_range(0.0, 15.0, 0.05) var republish_threshold_degrees: float = 0.0
## Whether a static shadow standing nowhere near what the player can see is left
## exactly as it is until it comes back.
##
## [b]The threshold above cut how often the map repaints; this cuts how much of
## the map repaints.[/b] They are the same saving twice: a region is twenty
## thousand pixels across and the camera shows under three thousand of them, so a
## sun that announced itself to every shadow on the map was rebuilding some two
## thousand silhouettes to show about a hundred.
##
## [b]It defers the rebuild; it never cancels one.[/b] A shadow passed over keeps
## the debt - see [method ShadowGroup.mark_dirty] - and pays it the instant it
## matters again: the frame the map's own scenery cull hands the prop back, or the
## first announcement after it re-enters the view. Nothing is ever left showing a
## shadow it would not have shown, because a shadow nobody can see is the only
## thing that is ever skipped.
##
## Off by default, so a map that has not asked for it - an arena, most of all -
## behaves exactly as it always did.
@export var cull_static_rebuilds: bool = false
## How far outside what the camera is actually showing a static shadow still counts
## as worth rebuilding, in world pixels. The preload margin: scenery inside it is
## brought up to date before it can be seen, so nothing snaps into a new hour as it
## scrolls on. Each shadow adds its own length to this on top, since a shadow can
## reach the screen from an object that cannot.
@export_range(0.0, 8000.0, 10.0) var static_rebuild_margin: float = 600.0

## The blended stage the sun is standing at. Written in place, never replaced.
var _live := SunStage.new()
## Where the blend is coming from - a snapshot of the live stage as the hour
## changed, so an hour forced part way through a journey eases out of where the sun
## actually is rather than snapping back.
var _from := SunStage.new()
var _to: SunStage
## The one live sun in the world. Every caster holds this reference.
var _state := SunState.new()
## What the sun looked like the last time [signal sun_updated] went out - the thing
## [member republish_threshold_degrees] measures against. A copy, deliberately: the
## live state is written in place, so a reference to it would compare with itself.
var _published := SunState.new()
## Whether anything has been published yet at all. Until it has there is nothing to
## compare against and the first update always goes out.
var _has_published: bool = false
## The patch of world worth rebuilding a shadow in, and the frame it was measured
## on - see [method get_rebuild_view]. Cached because every shadow on the map asks
## the same question in the same frame and there is only one camera to answer it.
var _view_rect := Rect2()
var _view_frame: int = -1
var _stage_index: int = -1
var _elapsed: float = 0.0
var _duration: float = 0.0
## The [WorldTimeManager] this sun is following, or null when none was found.
## Resolved once, in [method _ready] - the same node the World Map's own systems
## resolve it by, and it never moves once the game is running.
var _world_time: Node
## Whether a caller took the sun by hand - see [method snap_to_stage] and
## [method force_stage] - and so neither clock should touch it until
## [method refresh] is called again.
var _manual: bool = false
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
	_world_time = _resolve_world_time()
	if holds_for_combat:
		hold_for_combat()
		return
	if _follows_world_time():
		_snap_to_world_time()
		_follow_world_time_signal()
		set_process(world_time_blends and not stages.is_empty())
		return
	_follow_day_cycle()
	_snap_to_current_stage()


func _process(delta: float) -> void:
	if not _manual and _follows_world_time():
		_update_from_world_time()
		return

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


## Whether the things this map lights have a body - see [member solid_casters].
## Asked by [ShadowGroup] rather than read from it, so the whole map is drawn one
## way and no object can be shaped differently from its neighbour.
func has_solid_casters() -> bool:
	return solid_casters


## How deep a caster's body is taken to be here, as a fraction of its own width -
## see [member caster_depth_ratio]. Zero where this map's casters are flat cards, so
## a map that never asked for bodies is projected exactly as it always was.
func get_caster_depth_ratio() -> float:
	if not solid_casters:
		return 0.0
	return clampf(caster_depth_ratio, 0.0, 1.0)


## Whether an object's height is read off the top of its artwork here - see
## [member measure_height_to_top]. Asked by [ShadowGroup] rather than read from it,
## so the whole map is measured one way.
func measures_height_to_top() -> bool:
	return measure_height_to_top


## Whether a cast shadow starts at its caster's own footing here - see
## [member anchor_shadows_on_footing]. False leaves the authored slide of
## [member SunStage.shadow_length_anchor] in place, which is what every map that has
## not asked for the footing still expects.
func anchors_shadows_on_footing() -> bool:
	return anchor_shadows_on_footing


## Whether a shadow here grows out of its caster's own ground-contact footprint -
## see [member ground_contact_shadows]. Asked by [ShadowGroup] rather than read
## from it, so the whole map is projected one way.
func grounds_shadows_on_contact() -> bool:
	return ground_contact_shadows


## The shortest a shadow may be here, as a fraction of its caster's own width -
## see [member minimum_shadow_ratio].
func get_minimum_shadow_ratio() -> float:
	return maxf(minimum_shadow_ratio, 0.0)


## How soft a shadow that is entirely pool is drawn - see [member pool_softness].
func get_pool_softness() -> float:
	return clampf(pool_softness, 0.0, 1.0)


## Whether shadows on this map may put off a rebuild while nobody can see them -
## see [member cull_static_rebuilds]. Asked by [ShadowGroup] rather than read from
## it, so the decision stays a property of the map and there is one answer for the
## whole of it.
func culls_static_rebuilds() -> bool:
	return cull_static_rebuilds


## The patch of world a shadow has to reach into to be worth rebuilding right now:
## what the camera is showing, grown by [member static_rebuild_margin].
##
## [b]Measured once a frame for the whole map.[/b] Every static shadow asks this
## the same frame the sun announces itself, and there is one camera to answer it,
## so the answer is worked out on the first ask and handed to the rest - two
## thousand callers cost one camera read.
##
## An empty rectangle means there is no camera to measure against, which every
## caller reads as "cull nothing" rather than as "cull everything" - so a scene
## opened without one, or a headless run, still builds every shadow it has.
func get_rebuild_view() -> Rect2:
	var frame := Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		_view_rect = _measure_view()
	return _view_rect


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


## Lets go of a manual hold - see [member _manual] - and sends the sun back to
## whichever clock it should be following: the continuous [WorldTimeManager] when
## one can be found and [member follow_world_time] is on, the day cycle otherwise.
## Public so a debug key or a system that forced an hour can hand the sun back
## without the world being rebuilt around it.
func refresh() -> void:
	# A held sun is not handed back to either clock - see
	# [member holds_for_combat]. Asked to refresh, it re-reads the frozen hour
	# and holds again rather than starting to travel through the fight.
	if holds_for_combat:
		hold_for_combat()
		return
	_manual = false
	if _follows_world_time():
		_snap_to_world_time()
		set_process(world_time_blends and not stages.is_empty())
		return

	var index := _resolve_stage_index()
	if index == _stage_index:
		return
	_begin_transition(index)


## Sends the sun to [param stage_index] over [param duration] seconds, ignoring
## whichever clock it was following - see [member _manual]. For a debug panel
## stepping through the hours; ordinary play never calls it.
func force_stage(stage_index: int, duration: float = -1.0) -> void:
	if stages.is_empty():
		return
	_manual = true
	_begin_transition(posmod(stage_index, stages.size()), duration)


## Puts the sun straight at [param stage_index] with no journey at all. What the
## map does as it loads: the world is being built, so there is nowhere for the sun
## to have come from.
##
## [param mark_manual] is what makes an outside caller's snap hold there until
## [method refresh] is asked for - see [member _manual]. The continuous clock's
## own bootstrap snap - see [method _snap_to_world_time] - is the one caller that
## passes false, since it is the clock placing the sun at its own answer rather
## than someone taking it away from the clock.
func snap_to_stage(stage_index: int, mark_manual: bool = true) -> void:
	if stages.is_empty():
		return
	if mark_manual:
		_manual = true
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


## Sets this sun once from the day stage the world clock is currently on and
## then stops it - see [member holds_for_combat]. Answers the stage index that
## was held, or -1 for a sun with no stages authored.
##
## Public so a fight opened some other way can hand its own sun the same
## treatment, and so a smoke check can ask for it and read back what it did.
func hold_for_combat() -> int:
	if stages.is_empty():
		_stage_index = -1
		return -1

	var index := 0
	if _world_time != null:
		index = _world_time_index()
	elif stage_override >= 0:
		index = stage_override % stages.size()

	var stage := stages[index]
	if stage == null:
		return -1

	_live.copy_from(stage)
	if hold_uses_longest_shadow:
		var next := stages[posmod(index + 1, stages.size())]
		if next != null:
			# The rake is the ratio of the sun's ground distance to its height,
			# so the longest one this stage reaches is applied by moving the sun
			# out along its own direction rather than by swapping in the other
			# stage - which would bring that hour's colour and light with it.
			var rake := maxf(stage.get_length_ratio(), next.get_length_ratio())
			_live.sun_distance = _live.sun_height * rake

	_from.copy_from(_live)
	_to = _live
	_stage_index = index
	# Nothing is allowed to move it afterwards: the manual hold refuses both
	# clocks, and the process callback that would run a blend never starts.
	_manual = true
	set_process(false)
	_read_state()
	sun_stage_changed.emit(_state, _stage_index)
	_publish()
	return _stage_index


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
##
## [b]Unconditional.[/b] Every caller of this is a thing that happened once - the
## map loading, an hour being forced, a fight taking its held hour, the projection
## mode being changed in the inspector - and none of them is worth measuring. Only
## the continuous clock's per-frame path weighs the movement first; see
## [method _update_from_world_time].
func _publish() -> void:
	_read_state()
	_broadcast()


## Hands the world the state exactly as it now stands: scales the lamps that opted
## in, remembers what went out so the next frame has something to measure against,
## and tells every shadow on the map to repaint.
func _broadcast() -> void:
	_apply_lights()
	_published.copy_from(_state)
	_has_published = true
	sun_updated.emit(_state)


## Whether the sun has moved far enough since the last broadcast to be worth
## telling the world about - the whole of [member republish_threshold_degrees].
##
## Every test is the same test written against a different quantity: how far the
## finished shadow would move if this were let through, as a fraction of its own
## length. A swing of the light of [param slack] radians moves a tip by that
## fraction directly; a relative change of the rake, of the sun's height, or of how
## far the sun stands across the ground moves it by the same amount.
func _shadow_moved_enough() -> bool:
	if not _has_published or republish_threshold_degrees <= 0.0:
		return true
	if _state.directional != _published.directional:
		return true

	var slack := deg_to_rad(republish_threshold_degrees)
	if absf(_published.direction.angle_to(_state.direction)) > slack:
		return true
	if absf(_state.length_ratio - _published.length_ratio) \
			> slack * maxf(absf(_published.length_ratio), 1.0):
		return true
	if absf(_state.height - _published.height) > slack * maxf(_published.height, 1.0):
		return true
	if not _state.directional:
		# Where the sun stands is what a fanned-out shadow leans away from, so a
		# step of it across the ground turns the light by that step over how far
		# away the sun is standing from the map.
		var away := _state.position.distance_to(get_sun_anchor())
		if _published.position.distance_to(_state.position) > slack * maxf(away, 1.0):
			return true

	return _look_moved_enough()


## Whether anything a shadow is coloured or shaded by has drifted far enough to be
## seen since the last broadcast.
##
## Kept apart from the geometry because none of it is an angle and none of it can
## share the geometry's threshold: these are the values the shadow material is
## built from, and the bound on them is simply "smaller than a step of eight-bit
## colour". It matters for a map whose hours move the light without moving the sun
## much - two stages authored from the same direction but a different darkness
## would otherwise sit on the earlier one's colour until the sun swung.
func _look_moved_enough() -> bool:
	return _drifted(_state.shadow_opacity, _published.shadow_opacity) \
		or _drifted(_state.shadow_softness, _published.shadow_softness) \
		or _drifted(_state.shadow_fade, _published.shadow_fade) \
		or _drifted(_state.shadow_width_scale, _published.shadow_width_scale) \
		or _drifted(_state.shadow_length_anchor, _published.shadow_length_anchor) \
		or _drifted(
			_state.shadow_height_opacity_falloff,
			_published.shadow_height_opacity_falloff) \
		or absf(_state.shadow_max_distance - _published.shadow_max_distance) > 1.0 \
		or _drifted_color(_state.shadow_color, _published.shadow_color) \
		or _drifted_color(_state.light_color, _published.light_color) \
		or _drifted(_state.light_energy, _published.light_energy) \
		or _drifted(_state.ambient_intensity, _published.ambient_intensity)


func _drifted(now: float, was: float) -> bool:
	return absf(now - was) > LOOK_SLACK


func _drifted_color(now: Color, was: Color) -> bool:
	return _drifted(now.r, was.r) or _drifted(now.g, was.g) or _drifted(now.b, was.b)


func _read_state() -> void:
	_state.read_from(
		_live, get_sun_anchor(), projection_mode == ProjectionMode.SUN_DIRECTIONAL)


## What the camera is showing, grown by the preload margin. Asked of
## [CameraController], which is already the one answer in the game to "is that on
## screen" and measures from where the camera is actually looking rather than from
## its node position, so a shake or a smoothed follow cannot make this lie. An
## empty rectangle when there is no camera at all - see [method get_rebuild_view].
func _measure_view() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var camera := CameraController.get_active(self)
	if camera == null:
		return Rect2()
	return camera.get_visible_world_rect().grow(maxf(static_rebuild_margin, 0.0))


## Whether this sun should be reading [WorldTimeManager] right now rather than the
## day cycle: a continuous clock was actually found, following it is switched on,
## and [member stage_override] is not pinning the sun to one hour by hand - the
## override wins over either clock, exactly as it always won over the day cycle
## alone.
func _follows_world_time() -> bool:
	return _world_time != null and follow_world_time and stage_override < 0


func _resolve_world_time() -> Node:
	if world_time_path.is_empty():
		return null
	var node := get_node_or_null(world_time_path)
	if node == null or not node.has_method(&"get_time_period_index"):
		return null
	return node


## The world clock's current period, as an index into [member stages] - clamped to
## however many stages are actually authored, so a sun with fewer than six of them
## still shows something rather than reading past the end of its own array.
func _world_time_index() -> int:
	return posmod(int(_world_time.call(&"get_time_period_index")), stages.size())


## Puts the sun straight at the world clock's current hour with no journey at all -
## what [method _ready] and [method refresh] do to hand the sun to the continuous
## clock. See [method snap_to_stage]'s own [code]mark_manual[/code]: this is the
## clock placing the sun at its own answer, not someone taking it away from the
## clock, so it must not itself count as a manual hold.
func _snap_to_world_time() -> void:
	if stages.is_empty():
		_stage_index = -1
		return
	snap_to_stage(_world_time_index(), false)


## Hangs a non-blending sun off the clock's own announcement, so the one thing
## that moves it is the clock crossing into a new period - which, with time
## spent in whole day cycles, is exactly once per travel tick. Connected whether
## or not blending is on, since [method Node._process] is the only path that
## would otherwise notice a period change and a blending sun already has one:
## the handler refuses to act while blending, rather than the connection being
## made conditionally and then going stale if [member world_time_blends] is
## changed at runtime.
func _follow_world_time_signal() -> void:
	if _world_time == null or not _world_time.has_signal(&"period_changed"):
		return
	if not _world_time.is_connected(&"period_changed", _on_world_time_period_changed):
		_world_time.connect(&"period_changed", _on_world_time_period_changed)


func _on_world_time_period_changed(_period: int, _period_index: int) -> void:
	if world_time_blends or _manual or not _follows_world_time():
		return
	_snap_to_world_time()


## Blends the sun directly between the world clock's current period and the next
## one, by how far through the current period the clock has turned - continuous
## by construction, since the blend reaches exactly the next anchor stage the same
## frame the clock's own period changes and starts from exactly this one's the
## frame after. There is no eased transition to run here and nothing to hold once
## it "arrives": the sun is always exactly as far along as the clock is.
func _update_from_world_time() -> void:
	if stages.is_empty():
		return

	var index := _world_time_index()
	var next_index := posmod(index + 1, stages.size())
	var progress: float = _world_time.call(&"get_period_progress")

	if index != _stage_index:
		_stage_index = index
		sun_stage_changed.emit(_state, _stage_index)

	SunStage.blend(stages[index], stages[next_index], clampf(progress, 0.0, 1.0), _live)
	# Read every frame, announced only when it moved. The live state is the sun as
	# it genuinely stands this instant, so nothing that asks the sun a question gets
	# a stale answer; what is weighed is only whether to make every static shadow on
	# the map rebuild itself over it. See [member republish_threshold_degrees].
	_read_state()
	if not _shadow_moved_enough():
		return
	_broadcast()


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
