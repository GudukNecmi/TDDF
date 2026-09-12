class_name WorldBandit
extends Node2D
## One symbolic bandit GROUP moving on the World Map - never a crowd of
## combat enemies.
##
## [b]This is the whole of a group, not one member of it.[/b] A World Map
## bandit is a single lightweight [Node2D]: ten men and sixty men are the
## same node with a different [member group_strength], never twenty to sixty
## separately spawned [code]enemy.gd[/code] bodies walking in formation.
## [member group_strength] is stored and read this phase and converted into
## nothing - no enemy count, no wave, no fight - that conversion is later
## phases' work, done at the point a run actually begins against this group.
##
## [b]Everything it needs is asked for, never owned.[/b] Its speed comes from
## [member speed_profile] sampling [member group_strength]; whether the
## player is a threat or prey comes from comparing [member group_strength]
## against [WorldMapPlayerPower] through [member threat_profile]'s ratios;
## its current region comes from the same [WorldMapRegionZone] rectangles
## that already tell [WorldMapState] where the player is standing. No second
## region system, no second progression system and no second obstruction
## system exist anywhere in this file.
##
## [b]Decisions are throttled by distance; movement never is.[/b]
## [method _physics_process] moves this node toward [member target_position]
## every single frame, so a group's walk always looks smooth - but
## [method _ai_tick], which is what can change [member behavior_state] and
## [member target_position], only runs as often as [method _update_interval]
## says a group this far from the player is worth reconsidering. A far-off
## group still glides along its route at full visual smoothness; it simply
## does not re-check its eyesight sixty times a second to do it.

## The five things a group can be doing. Nothing beyond movement and
## detection is implemented against any of them yet - no combat, no
## interaction prompt, no joining another group. See the class doc.
##
## [b]DISENGAGE is the visible "giving up" beat.[/b] A chase that has run past
## [member give_up_distance] does not snap straight back to
## [constant PATROL] - it spends a moment in [constant DISENGAGE] first,
## slowing down and heading back toward its own route, so giving up on the
## player reads as something happening rather than a state flipping. See
## [method _enter_disengage].
enum BehaviorState { PATROL, INVESTIGATE, CHASE, FLEE, DISENGAGE }

## How often this group's whole simulation is stepped right now - a level of
## detail, never a second behaviour.
##
## [b]Neither level changes what a group does.[/b] [constant ACTIVE] and
## [constant DORMANT] run the identical [method _simulate] body, over the
## identical [enum BehaviorState] machine, along the identical route: the only
## difference is how often. [constant ACTIVE] steps it every physics frame,
## which is exactly what this class always did and what every group away from
## a [WorldBanditActivationDirector] still does. [constant DORMANT] steps it
## once every [member dormant_step_interval] instead, handing that whole
## interval in as the frame's [code]delta[/code], so a group far out on the
## map covers precisely the same ground along precisely the same route - in
## coarse hops rather than smooth ones, which is free, because at that
## distance it is outside [WorldMapFog]'s radius and nobody is looking at it.
##
## [b]Dormant is not stood down.[/b] A dormant group keeps its position, its
## route index, its strength and its behaviour, is still written into
## [WorldMapState] when its region is freed, and is still swept by
## [WorldMapCombatBridge] and [WorldMapAmbushDirector]. The flag that
## genuinely freezes a group and takes it out of play is [member active], and
## nothing here touches it.
enum ActivationLevel { DORMANT, ACTIVE }

## How much further than [member rider_horse_radius] a group that already has its
## horses is allowed to get before giving them up - see
## [method _within_rider_horse_range].
const RIDER_HORSE_KEEP_SCALE := 1.15

signal behavior_changed(state: BehaviorState)
## Emitted whenever [member activation_level] changes - a group waking as the
## player rides into range, or falling dormant once they have gone. Nothing
## currently listens beyond the development readout; the seam exists so
## anything that wants to know can ask rather than poll.
signal activation_changed(level: ActivationLevel)
## Emitted whenever [member region_id] changes - crossing from one
## [WorldMapRegionZone] into another, exactly the way the player's own
## crossing tells [WorldMapState] about it. Nothing currently listens; the
## seam exists for whatever later phase wants to react to a group crossing a
## border.
signal region_changed(new_region_id: StringName)

## Combat strength this group represents. Stored and compared this phase;
## turned into an actual fight - enemy count, wave count, individual
## strength, how long it lasts - only by later phases. See the class doc.
@export var group_strength: float = 20.0
## How close the player has to walk before this group counts as physically
## contacted. Read by [WorldMapCombatBridge], which watches every group in
## [constant "world_bandit"] for this distance and opens the fight - nothing
## about starting, running or ending combat lives in this file; see the
## bridge's own class doc for why.
@export var contact_radius: float = 70.0
## Maps [member group_strength] to a pixels-per-second speed. Shared between
## many bandits so retuning the curve moves every group at once; see
## [WorldBanditSpeedProfile].
@export var speed_profile: WorldBanditSpeedProfile
## The ratios this group flees or gives chase at, weighed against
## [WorldMapPlayerPower]. See [WorldBanditThreatProfile].
@export var threat_profile: WorldBanditThreatProfile
## The [WorldBanditRoute] this group patrols when it is not investigating,
## chasing or fleeing. A group with none simply holds its spawn position
## while in [constant BehaviorState.PATROL].
@export var current_route: NodePath
## How far this group can spot the player from, in pixels - the first of the
## two conditions detection needs. The second is line of sight; see
## [method _has_line_of_sight].
@export var detection_radius: float = 520.0
## How far the player has to get from a chasing group before
## [constant BehaviorState.CHASE] breaks off into [constant BehaviorState.DISENGAGE] -
## the group visibly slows and turns back toward its route, rather than
## snapping straight back to [constant BehaviorState.PATROL]. See
## [method _enter_disengage].
@export var give_up_distance: float = 900.0
## How far the player has to be, past [member give_up_distance], before a
## group already disengaging is considered fully gone and returns to
## [constant BehaviorState.PATROL]. Kept as its own, larger number rather than
## reusing [member give_up_distance] for both, so there is a real gap the
## player can see a group cross - still winding down, not yet back to an
## ordinary patrol.
@export var chase_break_distance: float = 1400.0
## The longest [constant BehaviorState.DISENGAGE] is ever allowed to run
## before resolving to [constant BehaviorState.PATROL] on its own, in
## seconds - so a group that peels off toward a route point already behind
## [member chase_break_distance] still eventually stands down instead of
## disengaging forever.
@export var disengage_duration: float = 6.0
## Physics layers a sightline can be blocked by - the World Map's own
## obstruction layers ("world" and "prop_solid"), never a second occlusion
## system of this class's own. See [method _has_line_of_sight].
@export_flags_2d_physics var vision_obstruction_mask: int = 33
## Group the player is found in, the same convention [WorldZone] and
## [WorldMapRegionZone] already read the player off.
@export var body_group: StringName = &"player"
## Whether this group does anything at all. Off freezes it exactly where it
## stands and stops every check below - the one flag a later phase can use to
## pull a group out of play (defeated, captured, not yet spawned) without
## removing the node.
@export var active: bool = true
## Whether this group is written down when its region's scene is freed and read
## back the next time that region is built.
##
## [b]This is what makes a region persist without staying loaded.[/b] Only one
## region exists at a time now, so a group the player rode away from is a freed
## node rather than a node standing quietly in another band of the same map. What
## it was doing - where it had got to along its route, how strong it was, whether
## it had already been beaten - is kept in [WorldMapState] instead, which a scene
## change does not touch.
##
## Off leaves a group standing exactly where its scene authored it on every
## build, which is what a map opened on its own for tuning wants.
@export var remembers_across_scenes: bool = true
## The [Sprite2D] scaled and tinted to hint at [member group_strength] - see
## [method _apply_visual]. Left unset, this group simply never adjusts its
## own artwork. Doubles as the formation's own leader box - box 0 - once
## [member people_per_box] gives this group more than one to show; see
## [method _rebuild_formation].
@export var icon_path: NodePath = ^"Icon"

@export_group("Territory")
## The camp, outpost or landmark this group belongs to. Left unset - and for
## every roaming patrol it should be - a group's home is simply wherever its
## scene authored it, which is what every group already fell back on before
## this existed.
##
## Read once, on the first tick that needs it, and only ever read: nothing
## here moves, claims or writes to the node it points at.
@export var home_path: NodePath
## How far from [member home_path] a group will let the player draw it before
## it breaks off and heads home - the edge of the ground this group considers
## its own.
##
## [b]This is the camp defence the World Map asks for, and it is one extra
## reason to give up rather than a second kind of chase.[/b] A garrison spots,
## closes and fights exactly as any other group does - see
## [method _on_player_spotted] - but where an untethered patrol only stops
## when the player has outrun it by [member give_up_distance], a garrison also
## stops the moment the player is off its ground, whether it is still on their
## heels or not. What that produces is the "driven out of their territory"
## read: the group harries the player to the boundary and turns back, instead
## of trailing them across the desert.
##
## Zero is untethered - no boundary, and the group behaves precisely as this
## class always has. Deliberately much larger than
## [member detection_radius]: the boundary is where a chase ends, never where
## one can begin.
@export var territory_radius: float = 0.0
## How long a group already chasing the player keeps at it after they reach
## safe ground - see [WorldMapSanctuary] - before giving up, in seconds. The
## visible beat of the group pulling up short at the edge of the Saloon or the
## Market rather than stopping dead on the line.
##
## What happens at the end of it is [method _enter_disengage] and nothing
## else: the same wind-down every other broken-off chase already runs.
@export var sanctuary_hold_duration: float = 2.0

@export_group("Navigation")
## Whether this group walks the map's navigation mesh instead of straight at
## whatever it is heading for.
##
## [b]It is Godot's navigation, asked once per decision - not an obstacle test
## every frame.[/b] Where the group wants to be is still decided by
## [method _ai_tick] exactly as it always was; all this changes is that the walk
## there follows a corridor [method NavigationServer2D.map_get_path] returned on
## a mesh baked as the map loaded - see [WorldMapNavigation] - so a group chasing
## the player round the far side of a mesa goes round it. Nothing in this file
## looks at a rock.
##
## A map with no navigation mesh in it answers no path, and every group on it
## steers straight at its target the way it always did. That is what keeps this
## an addition rather than a change: a region that has not been given a mesh
## behaves exactly as before.
@export var uses_navigation: bool = true
## How far the destination may move before the corridor is asked for again, in
## pixels. A chased player drifting a few paces does not justify a fresh path;
## one who has rounded a rock does.
@export var repath_distance: float = 260.0
## Floor on how often a fresh path may be asked for, in seconds, however far the
## destination has moved. Stops a group whose target jumps every frame from
## querying the navigation server every frame with it.
@export var repath_interval: float = 0.35
## How close the leader must come to a corner of its corridor before it starts
## turning toward the next one, in pixels. Smaller keeps the group tighter to
## the rock; larger rounds the turns off more.
@export var waypoint_radius: float = 120.0
## Whether the group is pulled back onto the navigation mesh when it somehow
## ends up off it - spawned inside a rock, or carried out by a scripted move.
## The backstop behind the corridor, not the way the walking normally works.
@export var clamps_to_navigation: bool = true
## How often that backstop is applied, in seconds.
@export var navigation_clamp_interval: float = 0.2
## Whether a group that has stopped getting anywhere takes itself out of it.
##
## [b]This is the corridor's own backstop, not a second way of moving.[/b] The
## walk is still the navigated corridor above; all this watches is whether the
## group is actually covering ground along it. A group that is not - one whose
## patrol point turned out to sit inside a rock, one pressed into the side of a
## mesa by a destination on the far side of it, one whose corridor was answered
## before the mesh finished baking - asks for a fresh corridor, and if that
## changes nothing, gives up on the destination it cannot reach and takes the
## next one instead. Off leaves the group pushing at the rock, which is what
## every group did before this existed.
@export var stall_recovery_enabled: bool = true
## How long a group is watched before its progress is judged, in seconds. Short
## enough that a group standing at a rock is noticed while the player is still
## looking at it; long enough that a group genuinely walking the long way round
## a mesa is never mistaken for a stuck one, since that group is covering ground
## the whole time.
@export var stall_window: float = 1.5
## How much of the ground a group should have covered in [member stall_window]
## it has to actually cover to count as moving, as a fraction of
## [method _effective_speed] times that window. Ground covered is measured
## corner to corner over the window rather than step by step, so a group sawing
## back and forth against a rock reads as the standing still it really is.
@export_range(0.0, 1.0, 0.01) var stall_progress_fraction: float = 0.35
## How many stalled windows in a row are answered with nothing but a fresh
## corridor before the group gives up on the destination itself. One fresh
## corridor covers the ordinary case - a path answered against a mesh that had
## not finished baking, or one left stale by a clamp - and anything past it is a
## destination that genuinely cannot be walked to.
@export var stall_repath_attempts: int = 2
## How far to the side a group steps when it has given up on reaching something
## it is not free to stop chasing, in pixels - a chase or a flight, where a
## patrol would simply take its next waypoint. The step alternates sides each
## time, so a group boxed in on one side of an obstacle tries the other.
@export var detour_distance: float = 700.0
## How long that sidestep is walked before the group heads for its real
## destination again, in seconds. Long enough to clear the corner of an
## obstacle, short enough that the group is never visibly walking away from
## what it wants.
@export var detour_duration: float = 2.0
## How close the leader has to come to a patrol waypoint to count as having
## reached it, in pixels.
##
## [b]A turning group cannot converge on a point tighter than its own turning
## circle.[/b] A sixty-strong group at [member min_turn_rate] describes a circle
## the better part of a hundred pixels across, so a waypoint tolerance smaller
## than that is one it orbits forever without ever arriving - which is exactly
## what a stuck patrol looks like. The tolerance actually used is this or that
## circle, whichever is larger; see [method _arrival_radius].
@export var waypoint_arrival_radius: float = 48.0
## How much room past its own turning circle a group is given to count as
## arrived. 1.0 is the circle exactly, which a group can ride round without ever
## crossing; anything above it is the margin that lets the arrival actually
## happen.
@export_range(1.0, 4.0, 0.05) var arrival_turn_margin: float = 1.4

@export_group("Formation")
## How many people one visual box stands for - "one visual red box represents
## 5 people". [method _rebuild_formation] always shows
## [code]ceil(group_strength / people_per_box)[/code] boxes: [member _icon]
## itself is the first of them, the leader, and every one past it is a plain
## trailing [Sprite2D] this class builds and frees on its own as
## [member group_strength] changes.
@export var people_per_box: int = 5
## How far back, rank to rank, one row of the formation sits behind the row in
## front of it, in pixels - see [method _update_formation_heading]. Depth
## only: two boxes in the same row never differ by this.
@export var box_spacing: float = 26.0
## How far apart, side to side, two boxes in the same row of the formation
## sit, in pixels - see [method _update_formation_heading]. What actually
## gives a group its width; [member box_spacing] alone would still be a
## single-file line.
@export var box_lateral_spacing: float = 28.0
## How many boxes wide the formation tries to be, before
## [member min_formation_width] and the group's own total box count clamp it -
## a curve in everything but name: [method _formation_width] samples
## [code]sqrt(total boxes)[/code] and scales it by this, so a formation grows
## wider only as fast as its own area does rather than in a straight line with
## its member count. Raise it for a formation that reads wide and shallow;
## lower it for one that reads narrow and deep.
@export var formation_width_factor: float = 1.3
## The narrowest a formation of two or more boxes is ever allowed to be - see
## [method _formation_width]. Below this a group would start reading as the
## single-file line this whole formation exists to avoid.
@export var min_formation_width: int = 2
## The most ground a rider may make up on its own place in the formation in one
## second, as a multiple of the speed the group itself is travelling at - see
## [method _update_formation_heading].
##
## [b]This is what stops the flanks orbiting the leader.[/b] A formation whose
## every box is written straight to its slot is a rigid block being spun about
## its front rider, and the further out to the side a rider sits the faster it
## is flung round: a three-rider group turning at [member max_turn_rate] threw
## its flankers sideways at nine times the speed the group itself was moving,
## which is the circular sweep the riders read as. Riders instead ride toward
## the place the formation wants them, at a speed of their own, so a group
## changing direction has its flanks swing wide and fall back into line the way
## riders actually do.
##
## [b]Kept at or below 1 on purpose.[/b] A rider closing its gap can then never
## out-travel the group it belongs to, so its own net movement always points the
## way the group is going - which is what keeps [HorseRig], who reads its facing
## off the ground it covers and nothing else, from turning a horse round to
## chase its own place in the line.
@export_range(0.0, 1.0, 0.05) var formation_catch_up_scale: float = 0.8
## How sharply a rider closes the last of that gap, in reciprocal seconds - the
## eased half of the same movement. Large is a rider that snaps the final few
## pixels shut, small is one that drifts in; the speed above is the ceiling on
## both, and is what the far half of the gap is covered at.
@export var formation_catch_up_response: float = 5.0
## The colour a trailing box is tinted at once it is [member darkest_at_box]
## boxes back or further - blended from [member _icon]'s own colour at
## [member group_strength] the nearer a box is to the front. "Boxes farther
## behind become progressively darker/redder."
@export var rear_box_color := Color(0.3, 0.04, 0.03, 1.0)
## How many boxes back [member rear_box_color] is fully reached. Past this,
## every further box simply repeats the same darkest tint, so a
## seventy-strong group's fourteen boxes never fade out to nothing rather
## than merely getting darker.
@export var darkest_at_box: int = 6
## The horse every rider this group shows is sitting on - one instance per box,
## the leader included, placed on that box and moving with it.
##
## [b]It is the player's own horse system, given to somebody else.[/b] The scene
## is a [HorseRig]: the same rig, the same [HorsePartMotion] array and the same
## [GallopRamp] the horse under the player runs on, so a bandit group's horses
## gallop the way the player's does because it is literally the same animation
## doing it, and nothing in this file decides how a horse moves. A rig measures
## the ground it covers on its own - see [HorseRig] - so a group standing still
## because it has arrived, because it is blocked or because an encounter has
## frozen it has horses standing still, and no state, speed or heading of this
## class is ever handed across.
##
## Every group rides the one bandit horse for now. Horse variety is a different
## scene of the same rig - see [code]Scenes/World/Horses/[/code] - so giving a
## group a different mount is changing this property and nothing else. Left
## unset, a group shows exactly the boxes it always did.
@export var rider_horse_scene: PackedScene = preload("res://Scenes/World/Horses/BanditHorse.tscn")
## How large a rider's horse is drawn, as the scale written onto the rig. The
## same size the horse under the player is drawn at, so a group riding past is
## made of horses the player can measure their own against rather than of
## miniatures.
@export var rider_horse_scale: float = 0.09
## How much further apart the formation lines its riders up once they are on
## horses - a multiplier on [member box_spacing] and
## [member box_lateral_spacing], and the only thing in this class that changes
## where a box sits.
##
## [b]The riders did not move; they grew.[/b] The two spacings were authored for
## boxes a few pixels across, and a horse at [member rider_horse_scale] is the
## better part of two hundred wide - so a block laid out on the old numbers would
## be one solid smear of overlapping horses rather than a group of riders. This
## is that same block measured in horses instead of in boxes; the grid, its
## width and its ranks are exactly what [method _update_formation_heading]
## always built. A group with no [member rider_horse_scene] is laid out on the
## bare spacings, unchanged.
@export var mounted_spacing_scale: float = 5.0
## Whether every rider this group shows is sorted into the World Map's own depth
## order by where it is actually standing, rather than the whole group being drawn
## at the one point its node happens to be at.
##
## [b]A formation is spread over a good deal of ground.[/b] Its riders stand rows
## apart, and the map is y-sorted - so with this off the flanker out in front and
## the one bringing up the rear are drawn at the same depth as the group's own
## node, and scenery between them cuts across the block or covers it outright. On,
## the group's own children take part in the sort themselves, so a rider in front
## of a tent is drawn in front of it and one behind it is hidden by it.
##
## [b]A horse and the rider on it are one entry in that order[/b], because they are
## at one and the same position - see [method _place_rider_horses] - so nothing can
## be drawn between them however the light or the scenery falls.
@export var sort_riders_by_depth: bool = true
## Whether the rider markers themselves are drawn into their horses' shadows - see
## [method _rebuild_rider_horses]. Off leaves a group's shadows the horses alone,
## which is what a map wanting the cheapest possible crowd would ask for.
@export var rider_marker_casts_shadow: bool = true

## How near the player a group has to be before its horses are built at all, in
## pixels - see [method _rebuild_rider_horses]. Matches
## [member WorldBanditGallopDirector.hearing_radius] on purpose: a group's
## horses appear at about the distance its gallop becomes audible, so it is
## never heard riding without being seen to. Zero or less builds every awake
## group's horses, which is what a small map for tuning wants.
@export var rider_horse_radius: float = 2600.0

@export_group("Update frequency")
## Groups within this many pixels of the player re-run their AI every frame.
@export var near_range: float = 900.0
## Groups within this many pixels (but past [member near_range]) re-run their
## AI a few times a second instead of every frame.
@export var medium_range: float = 2200.0
## Seconds between AI ticks for a group within [member medium_range].
@export var medium_update_interval: float = 0.25
## Seconds between AI ticks for a group past [member medium_range] entirely.
@export var far_update_interval: float = 0.75
## Seconds between the coarse steps a group takes while
## [member activation_level] is [constant ActivationLevel.DORMANT] - see that
## enum. The whole of [method _simulate] runs on this beat instead of every
## physics frame, with the elapsed interval handed in as the step's delta, so
## the group covers the same ground along the same route at a thirtieth of
## the cost.
##
## Kept at or above [member far_update_interval] by nothing but sense: a
## dormant group is by definition further from the player than
## [member medium_range], so its AI tick was already the slowest of the three
## tiers before this ever applied.
@export var dormant_step_interval: float = 0.5

@export_group("State Speed")
## What [member movement_speed] is multiplied by while
## [constant BehaviorState.PATROL] - a relaxed pace for ordinary roaming,
## never the group's full speed. See [method _effective_speed].
@export_range(0.0, 2.0, 0.01) var roam_speed_multiplier: float = 0.7
## What [member movement_speed] is multiplied by while
## [constant BehaviorState.INVESTIGATE] - a little brisker than an ordinary
## patrol, since the group has just lost sight of something worth a look.
@export_range(0.0, 2.0, 0.01) var investigate_speed_multiplier: float = 1.05
## What [member movement_speed] is multiplied by while
## [constant BehaviorState.DISENGAGE] - winding down out of a chase, slower
## than the chase itself but still moving with purpose back toward its route.
@export_range(0.0, 2.0, 0.01) var disengage_speed_multiplier: float = 0.65
## The slowest a group's turning is ever allowed to be, in turns per second,
## sampled at [member WorldBanditSpeedProfile.max_group_strength] - a
## sixty-strong group changing direction like something with real mass to it.
## See [method _effective_turn_rate].
@export_range(0.05, 4.0, 0.01) var min_turn_rate: float = 0.35
## The fastest a group's turning is ever allowed to be, in turns per second,
## sampled at [member WorldBanditSpeedProfile.min_group_strength] - a
## ten-strong group all but snapping onto a new heading.
@export_range(0.05, 4.0, 0.01) var max_turn_rate: float = 2.5

## The pixels-per-second this group is currently moving at - [member group_strength]
## already run through [member speed_profile]. Read rather than authored;
## recomputed in [method _ready] and whenever [member group_strength] changes
## at runtime through [method set_group_strength].
var movement_speed: float = 0.0
## The [WorldMapRegionZone.region]'s handle this group is currently standing
## in, or empty before the first AI tick has placed it. Read the same way
## [method WorldMapState.get_region_id] is.
var region_id: StringName = &""
## Index into [method WorldBanditRoute.get_points] of the waypoint this group
## is currently walking toward.
var current_route_index: int = 0
## What this group is doing right now. See [enum BehaviorState].
var behavior_state: BehaviorState = BehaviorState.PATROL
## How often this group is currently being simulated. See
## [enum ActivationLevel]. Written only through
## [method set_activation_level], and only ever by
## [WorldBanditActivationDirector]; a map with no director in it leaves every
## group at [constant ActivationLevel.ACTIVE] for its whole life, which is
## this class's original behaviour exactly.
var activation_level: ActivationLevel = ActivationLevel.ACTIVE
## Where [method _physics_process] is currently steering this group toward -
## the next patrol point, the player's last known position, or a point
## chosen away from them. Always in global space.
var target_position: Vector2 = Vector2.ZERO
## True exactly while [member behavior_state] is [constant BehaviorState.FLEE].
## Kept as its own flag rather than checked against [member behavior_state]
## everywhere, the same way [code]enemy.gd[/code] keeps its own
## [code]_fleeing[/code] beside its other movement flags.
var fleeing: bool = false
## True only while this group is one of a scripted World Map ambush's own
## attackers - see [WorldMapAmbushDirector] and [method begin_ambush]. Never
## set by anything in this file's own detection; a group notices the player
## and picks a side entirely on its own in [method _on_player_spotted], which
## never touches this flag. While it is true, [method _ai_tick]'s own CHASE
## branch tracks the player regardless of [member detection_radius] or line of
## sight, and never breaks off past [member chase_break_distance] - an ambush
## is a deliberate script, not something this group has to actually notice or
## keep noticing, and [WorldMapAmbushDirector] is the one authority that
## decides when the player has gotten away. See [method end_ambush].
var in_ambush: bool = false

@onready var _icon: Sprite2D = get_node_or_null(icon_path) as Sprite2D

var _route: WorldBanditRoute
var _route_direction: int = 1
var _player: Node2D
var _last_known_player_position: Vector2 = Vector2.ZERO
var _investigate_timer: float = 0.0
## Counts down while [member behavior_state] is [constant BehaviorState.DISENGAGE] -
## see [method _enter_disengage].
var _disengage_timer: float = 0.0
## Counts up while a chased player stands on safe ground, against
## [member sanctuary_hold_duration]. Reset the moment they step back off it,
## so a player crossing the corner of a sanctuary and riding on out does not
## bank progress toward being given up on.
var _sanctuary_timer: float = 0.0
## The node [member home_path] points at, resolved on first use and kept.
var _home: Node2D
## Where this group's ground is centred - see [method _home_position]. Falls
## back to wherever the scene authored the group, captured in
## [method _ready] before anything has moved it.
var _home_fallback := Vector2.ZERO
var _update_timer: float = 0.0
## Counts up toward [member dormant_step_interval] while this group is
## [constant ActivationLevel.DORMANT] - the whole of the extra bookkeeping
## being dormant costs.
var _dormant_timer: float = 0.0
## The direction this group is actually moving in right now, kept and turned
## toward [member target_position] at [method _effective_turn_rate] rather
## than recomputed from scratch every frame - see [method _move_along_heading].
## Also what [method _update_formation_heading] trails the formation off of,
## so the boxes always line up behind wherever the group is really walking,
## never where it merely wants to.
var _movement_heading := Vector2.RIGHT
## Every trailing box past [member _icon] itself - see [method _rebuild_formation].
## Empty for a group whose whole [member group_strength] fits in the leader
## alone.
var _formation_boxes: Array[Sprite2D] = []
## One horse per rider this group is showing - see [member rider_horse_scene].
## Index 0 is the leader's, riding on [member _icon] itself, and the rest follow
## [member _formation_boxes] in order. Empty for a group with no horse scene and
## for one that has fallen [constant ActivationLevel.DORMANT], which is what
## keeps a hundred-group map from carrying four hundred rigs it cannot show.
var _rider_horses: Array[HorseRig] = []
## Whether this group has been beaten. Kept so the record written as it leaves
## the tree says "gone" rather than "standing here", which is what stops it from
## being built again the next time this region is.
var _defeated: bool = false
## The corridor currently being walked - the corners
## [method NavigationServer2D.map_get_path] answered for the last destination
## asked about. Empty on a map with no navigation mesh, which is what
## [method _navigation_target] reads as "steer straight there".
var _path: PackedVector2Array = PackedVector2Array()
## Which corner of [member _path] the group is currently walking toward.
var _path_index: int = 0
## Where [member _path] was asked to reach, so a destination that has barely
## moved does not throw the corridor away - see [member repath_distance].
var _path_goal := Vector2.INF
## Seconds since the last path query, against [member repath_interval].
var _repath_timer: float = 0.0
## Seconds since the last clamp back onto the mesh, against
## [member navigation_clamp_interval].
var _clamp_timer: float = 0.0
## The navigation map this group walks, resolved lazily: a mesh baked in a
## region's own [method Node._ready] is not queryable until the server has
## synchronised, so this is asked for until it answers rather than once.
var _nav_map: RID = RID()

## Whether the last corridor asked for actually arrived at the destination it
## was asked about, rather than stopping short of it against a rock or on the
## near side of ground the mesh does not join up. False is what
## [method _step_patrol] reads as "this waypoint cannot be walked to, take the
## next one".
var _goal_reachable: bool = true
## Where the group stood at the start of the window [method _check_stall] is
## currently measuring, so the ground it covered is corner to corner over the
## whole window rather than the sum of a lot of small steps that cancel out.
var _stall_mark := Vector2.ZERO
## Seconds into the current stall window, against [member stall_window].
var _stall_timer: float = 0.0
## How many stalled windows have run back to back without the group covering
## ground in between - see [member stall_repath_attempts].
var _stall_count: int = 0
## Where a group that gave up on reaching its destination directly is currently
## stepping aside to, or [constant Vector2.INF] for a group walking normally.
## Never written to [member target_position]: the destination is unchanged and
## everything that reads it still sees the real one - this is only where the
## group is putting its feet on the way.
var _detour_point := Vector2.INF
## Seconds left of the current sidestep, against [member detour_duration].
var _detour_timer: float = 0.0
## Which way the next sidestep goes - flipped every time one is taken, so a
## group blocked on one side of an obstacle tries round the other.
var _detour_side: float = 1.0
## The destination [method _begin_destination] last started a walk to, so a
## group told to head for the same place again is not treated as one setting
## off afresh. [constant Vector2.INF] before any walk has been started.
var _destination_mark := Vector2.INF


func _ready() -> void:
	# Before any rider exists, so the very first formation is built into a group
	# already taking part in the map's depth order - see sort_riders_by_depth.
	y_sort_enabled = sort_riders_by_depth
	add_to_group(&"world_bandit")
	# Captured before anything has had a chance to move this group - a restored
	# record puts it back mid-patrol - so a group with no home node authored
	# still defends the ground it was placed on rather than wherever it had
	# wandered to when the region was last left.
	_home_fallback = global_position
	_stall_mark = global_position
	# Which region this group is standing in has to be known before anything is
	# read back, because that is what its record is filed under.
	_update_region()
	# Counted into this region's population before anything can take it out
	# again, so a region's total stays the number of groups its scene authors -
	# see [method BanditPopulationState.note_group]. A group about to remove
	# itself below still registers here: it is one of the region's own, it has
	# simply been beaten.
	_note_population()
	if _restore():
		# Beaten the last time this region was built. It does not come back.
		queue_free()
		return
	_route = get_node_or_null(current_route) as WorldBanditRoute
	movement_speed = _compute_speed()
	_apply_visual()
	target_position = global_position
	_movement_heading = Vector2.RIGHT if _route == null or _route.get_points().is_empty() \
		else global_position.direction_to(_route_point(_nearest_route_index()))
	if _movement_heading.is_zero_approx():
		_movement_heading = Vector2.RIGHT
	_enter_patrol()
	# Ticks once immediately rather than waiting out its first interval, so a
	# group spawned near the player is not silently blind for its first
	# fraction of a second on the map.
	_ai_tick(0.0)


## Decides only how often [method _simulate] runs - never what it does. An
## [constant ActivationLevel.ACTIVE] group steps it every physics frame, the
## way this class always has; a [constant ActivationLevel.DORMANT] one banks
## the frames up and spends them in a single coarse step every
## [member dormant_step_interval]. See [enum ActivationLevel].
func _physics_process(delta: float) -> void:
	if not active:
		return

	if activation_level == ActivationLevel.DORMANT:
		_dormant_timer += delta
		if _dormant_timer < dormant_step_interval:
			return
		var banked := _dormant_timer
		_dormant_timer = 0.0
		_simulate(banked)
		return

	_simulate(delta)


## One step of this group's whole simulation - its AI cadence, its walk, its
## hold to the navigation mesh, its fog visibility and its formation. Exactly
## the body [method _physics_process] used to be, unchanged and unreordered;
## all that moved is the decision of how often to call it.
##
## [param delta] is real elapsed time, whether that is one physics frame or a
## dormant group's whole banked [member dormant_step_interval] - every timer
## and every step below already scales off it, which is what lets the two
## rates produce the same route walked at the same speed.
func _simulate(delta: float) -> void:
	_update_fog_visibility()

	_repath_timer += delta
	_update_timer += delta
	var interval := _update_interval()
	if _update_timer >= interval:
		var elapsed := _update_timer
		_update_timer = 0.0
		_ai_tick(elapsed)

	_step_toward_target(delta)
	_hold_to_navigation(delta)
	_check_stall(delta)
	_update_formation_heading(delta)
	_rebuild_rider_horses()
	_place_rider_horses()


## Changes [member group_strength] and immediately recomputes
## [member movement_speed] to match - the one place strength is ever written
## to at runtime, so it can never drift out of step with the speed it should
## produce. Also rebuilds the visual formation - see [method _apply_visual] -
## so a group that grows or shrinks mid-run shows the right number of boxes
## from the very next frame.
func set_group_strength(strength: float) -> void:
	group_strength = maxf(strength, 0.0)
	movement_speed = _compute_speed()
	_apply_visual()


## Sets how often this group is simulated - what
## [WorldBanditActivationDirector] calls on each group as the player rides
## into and back out of range. See [enum ActivationLevel].
##
## [b]A group reacting to the player refuses to be put to sleep.[/b] Only a
## group actually on patrol, and not currently one of an ambush's attackers,
## can be dropped to [constant ActivationLevel.DORMANT] - see
## [method can_sleep]. A chase, an investigation, a flight or a disengage
## therefore always plays out at full rate, whatever the director asks for,
## and the group falls dormant only once its own existing rules -
## [member give_up_distance], [member chase_break_distance],
## [member disengage_duration], [WorldMapAmbushDirector]'s own escape
## distance - have returned it to [constant BehaviorState.PATROL] on their
## own. Nothing here ends a behaviour early or resets one.
##
## Waking is never refused: a dormant group asked to become
## [constant ActivationLevel.ACTIVE] always does, immediately, and takes its
## next step on the very next physics frame.
func set_activation_level(level: ActivationLevel) -> void:
	if level == activation_level:
		return
	if level == ActivationLevel.DORMANT and not can_sleep():
		return
	activation_level = level
	# Banked frames belong to the level that banked them. Clearing this on
	# both edges means a group that wakes mid-interval does not carry a
	# part-spent dormant step into full-rate simulation, and one that falls
	# dormant takes its first coarse step a whole interval later rather than
	# immediately.
	_dormant_timer = 0.0
	# A group falling asleep gives its horses up and one waking builds them
	# again - see [method _rebuild_rider_horses]. Only the artwork moves either
	# way; the group itself is simulated at exactly the rate this method just
	# chose, awake or not.
	_rebuild_rider_horses()
	_place_rider_horses()
	activation_changed.emit(level)


## Whether this group is currently doing something that has to keep running
## at full rate - see [method set_activation_level]. False for anything but
## an ordinary, unambushed patrol.
func can_sleep() -> bool:
	return behavior_state == BehaviorState.PATROL and not in_ambush


## Forces this group straight into CHASE, aimed at [param player_position],
## bypassing the ordinary sighting-and-ratio check [method _on_player_spotted]
## makes - what [WorldMapAmbushDirector] calls on each of the three groups it
## has chosen for a World Map ambush. A group already stood down - see
## [member active] - is left alone: nothing here reaches into a group that has
## been engaged, hidden or freed by [WorldMapCombatBridge].
func begin_ambush(player_position: Vector2) -> void:
	if not active:
		return
	in_ambush = true
	_last_known_player_position = player_position
	_enter_chase()


## Breaks this group off an ambush by hand, whatever it is currently doing -
## [WorldMapAmbushDirector]'s own escape distance decided the player got away,
## not this group's own [member chase_break_distance], which an ambushed
## chase ignores entirely (see [method _ai_tick]). Returns it to PATROL
## exactly the way giving up an ordinary chase already does - see
## [method _enter_patrol] - so it goes back to roaming its route rather than
## vanishing, and picks the player up again later only through its own
## ordinary detection. A group not currently ambushed is left alone.
func end_ambush() -> void:
	if not in_ambush:
		return
	_enter_patrol()


func _compute_speed() -> float:
	if speed_profile == null:
		return movement_speed
	return speed_profile.get_speed(group_strength)


## Grows and darkens [member _icon] a little with [member group_strength], so
## a sixty-strong group reads as heavier on the map than a ten-strong one at
## a glance - the "small visual indication of group strength" asked for,
## kept to exactly that: no second sprite, no per-member artwork beyond the
## formation [method _rebuild_formation] lines up behind it.
func _apply_visual() -> void:
	if _icon == null or speed_profile == null:
		return
	var span := maxf(speed_profile.max_group_strength - speed_profile.min_group_strength, 0.001)
	var t := clampf((group_strength - speed_profile.min_group_strength) / span, 0.0, 1.0)
	_icon.scale = Vector2.ONE * lerpf(0.7, 1.6, t)
	_icon.modulate = Color(0.55, 0.14, 0.08).lerp(Color(0.85, 0.05, 0.05), t)
	_rebuild_formation()


## Adds one more trailing box behind [member _icon] for every extra
## [member people_per_box] beyond the first, so the group always shows
## [code]ceil(group_strength / people_per_box)[/code] boxes in total -
## [member _icon] itself counted as the first, the leader. Only the count is
## decided here; where each box actually sits in the formation's own block is
## [method _update_formation_heading]'s. Only rebuilds when the count has
## actually changed; called on every [method _apply_visual], which is cheap to
## do since it does nothing at all the rest of the time.
##
## [b]Never a second AI.[/b] Every trailing box is a plain [Sprite2D] parented
## directly under this same [WorldBandit], sharing [member _icon]'s own
## texture. It moves, turns with the map and is hidden by fog because this one
## node already is - see [method _update_fog_visibility], which reads
## [member Node2D.visible] on this node and every child, including these -
## not because a box has any behaviour of its own.
func _rebuild_formation() -> void:
	if _icon == null:
		return
	var wanted := maxi(int(ceil(maxf(group_strength, 0.0) / maxf(float(people_per_box), 1.0))), 1) - 1
	while _formation_boxes.size() > wanted:
		var extra: Sprite2D = _formation_boxes.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	while _formation_boxes.size() < wanted:
		var box := Sprite2D.new()
		box.texture = _icon.texture
		box.rotation = _icon.rotation
		add_child(box)
		_formation_boxes.append(box)

	for i in _formation_boxes.size():
		var rank := i + 1
		var box := _formation_boxes[i]
		box.scale = _icon.scale
		var fade := 1.0 if darkest_at_box <= 0 else clampf(float(rank) / float(darkest_at_box), 0.0, 1.0)
		box.modulate = _icon.modulate.lerp(rear_box_color, fade)
	_update_formation_heading()


## Keeps one horse under every rider this group is showing - see
## [member rider_horse_scene] - and none at all while there is nobody near
## enough to see them.
##
## [b]Built by the same count the boxes are.[/b] The leader plus every trailing
## box is exactly [method get_visible_bandit_count], the symbolic formation
## rather than [member group_strength], so a thirty-five strong group rides
## seven horses at the default [member people_per_box] and a horse can never be
## built for a rider the formation is not drawing.
##
## [b]And only for a group near enough to be looked at.[/b] A hundred groups at
## seven riders each is seven hundred rigs a map would otherwise carry to show
## the four the player can actually see, so horses are built inside
## [member rider_horse_radius] and freed outright past it - never built at all
## while the region is being assembled, and never for a
## [constant ActivationLevel.DORMANT] group. Groups come into range one at a
## time as the player rides, which is what spreads the building out; nothing
## here keeps a timer of its own.
func _rebuild_rider_horses() -> void:
	var wanted := 0
	if rider_horse_scene != null and activation_level == ActivationLevel.ACTIVE \
			and _icon != null and _within_rider_horse_range():
		wanted = _formation_boxes.size() + 1

	while _rider_horses.size() > wanted:
		var extra: HorseRig = _rider_horses.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	while _rider_horses.size() < wanted:
		var horse := rider_horse_scene.instantiate() as HorseRig
		if horse == null:
			return
		# Scaled before it enters the tree, so the rig reads this as the size it
		# was authored at and mirrors itself against it when it turns round.
		horse.scale = Vector2.ONE * rider_horse_scale
		add_child(horse)
		_rider_horses.append(horse)
		_seat_rider_shadow(horse, _rider_horses.size() - 1)


## Draws the rider sitting on [param horse] into that horse's own shadow - see
## [member rider_marker_casts_shadow].
##
## [b]It is the shadow system doing it, not this file.[/b] What is added is one
## [ShadowCaster] pointed at the marker's artwork and standing on the horse, so the
## rider goes into the same silhouette the horse's own parts do and the pair throw
## one mark between them rather than two that darken each other where they overlap.
## Nothing here works out where a shadow goes, how long it is or which way it lies.
##
## The caster hangs off the horse, so a group that rides out of range and gives its
## horses up gives up their riders' shadows with them - see
## [method _rebuild_rider_horses].
func _seat_rider_shadow(horse: HorseRig, index: int) -> void:
	if not rider_marker_casts_shadow:
		return
	var marker := _rider_marker(index)
	if marker == null:
		return
	var caster := ShadowCaster.new()
	caster.name = "RiderShadow"
	# The marker is placed by the formation and so lives beside the horse rather
	# than under it; the path is worked out before the caster enters the tree,
	# because a caster resolves its artwork the moment it is ready.
	caster.source_sprite_path = NodePath("../%s" % horse.get_path_to(marker))
	# A rider is not standing anywhere - they are sitting on the horse - so the
	# point they are "standing on" is the horse's own, and the marker's artwork is
	# not allowed to pull the pair's footing down to wherever it happens to be
	# drawn.
	caster.auto_ground_anchor = false
	horse.add_child(caster)


## The marker the rider at [param index] is drawn as: the leader's own icon for the
## first, and one of the trailing boxes for the rest.
##
## It is the same order [method _place_rider_horses] seats the horses in, and the
## same order both lists are grown and shrunk in, so a rider's horse and a rider's
## marker are the same rider without either list having to be kept in step with the
## other.
func _rider_marker(index: int) -> Sprite2D:
	if index <= 0:
		return _icon
	if index - 1 >= _formation_boxes.size():
		return null
	return _formation_boxes[index - 1]


## Whether the player is close enough for this group's horses to be worth
## building - see [member rider_horse_radius]. True everywhere while that is
## zero or less, and true for a map with nobody on it, which is what leaves a
## region opened on its own for tuning showing its horses.
func _within_rider_horse_range() -> bool:
	if rider_horse_radius <= 0.0:
		return true
	var player := _get_player()
	if player == null:
		return true
	# Held a little further out once the horses exist, for exactly the reason
	# [member WorldBanditActivationDirector.sleep_radius] sits outside
	# [member WorldBanditActivationDirector.activate_radius]: a group drifting
	# along the boundary must not build and free its riders on alternate frames.
	var limit := rider_horse_radius
	if not _rider_horses.is_empty():
		limit *= RIDER_HORSE_KEEP_SCALE
	return global_position.distance_to(player.global_position) <= limit


## Sits every horse on the rider it belongs to, read straight off the same
## [member _icon] and [member _formation_boxes] positions
## [method _update_formation_heading] just wrote - never a second layout of this
## method's own, so a horse is wherever the formation actually put its rider
## this frame.
func _place_rider_horses() -> void:
	if _rider_horses.is_empty() or _icon == null:
		return
	_rider_horses[0].position = _icon.position
	for i in range(1, _rider_horses.size()):
		if i - 1 >= _formation_boxes.size():
			return
		var box := _formation_boxes[i - 1]
		if is_instance_valid(box):
			_rider_horses[i].position = box.position


## Keeps every trailing box lined up in a compact block behind wherever this
## group is actually heading right now, rather than a fixed direction - read
## straight off [member target_position] and [member Node2D.global_position],
## the same pair [method _step_toward_target] is already moving this node
## along, so no second notion of "which way is this group walking" exists
## anywhere in this file. Cheap and run every physics frame; box creation and
## destruction themselves only ever happen in [method _rebuild_formation].
##
## [b]A block, never a single-file line.[/b] [member _icon] - the leader - is
## the whole of row 0 on its own, always exactly at [member Node2D.position],
## so it reads as the one member out in front. Every other box fills a grid
## behind it, [method _formation_width] boxes to a row, centred left-to-right
## on the leader's own line of travel: box 1 starts row 1, the row directly
## behind the leader, box [code]width[/code] starts row 2, and so on. A row
## widens or narrows only [member box_lateral_spacing] apart and rows sit
## [member box_spacing] apart, so a ten-strong group's own single trailing box
## rides shoulder to shoulder with the leader rather than trailing it, and a
## seventy-strong group reads as a wide, shallow block instead of a long tail.
##
## [b]The block is where the riders are going, not where they are.[/b] Written
## straight onto the boxes, the grid above is a rigid shape pinned to the
## group's heading - so the moment that heading swings, every flanker is
## teleported round the arc to its new side and the group reads as a carousel
## with the leader for a spindle. Each rider instead moves toward its own place
## at a speed of its own - see [member formation_catch_up_scale] - which is what
## makes a turn read as riders swinging wide and closing back up, and what keeps
## a rider's own travel pointing the way the group is going, so the horse under
## it never turns round to go and fetch its slot.
##
## [param delta] is the frame the movement is measured against; the default
## places every rider exactly on its slot instead, which is what a formation
## that has just been rebuilt - new boxes standing at the group's own origin -
## needs so it never slides out from under the leader.
func _update_formation_heading(delta: float = -1.0) -> void:
	if _formation_boxes.is_empty():
		return

	# [member _movement_heading] - the group's own actual, turn-rate-limited
	# walking direction (see [method _move_along_heading]) - rather than a
	# second, instantly-snapping direction of this method's own: the
	# formation always trails behind wherever the group is really heading,
	# not wherever it merely wants to.
	var width := _formation_width()
	var right := _movement_heading.orthogonal()
	# Riders on horses need the room a horse takes up - see
	# [member mounted_spacing_scale]. Read off whether this group has a horse
	# scene at all rather than off whether its horses happen to be built right
	# now, so a group does not spread out as the player rides into range of it.
	var spread := mounted_spacing_scale if rider_horse_scene != null else 1.0
	# The ground a rider is allowed to make up this frame, measured against the
	# group's own pace so the whole formation slows and closes together - a
	# disengaging group's riders fall in at a disengaging group's speed. Below
	# zero is the snap the default asks for.
	var reach := -1.0
	if delta > 0.0:
		reach = maxf(_effective_speed(), 0.0) * maxf(formation_catch_up_scale, 0.0) * delta

	for i in _formation_boxes.size():
		var slot := i + 1
		var row := slot / width
		var col := slot % width
		var lateral := (float(col) - float(width - 1) * 0.5) * box_lateral_spacing * spread
		# +0.6 rather than a whole extra row keeps row 1 close enough behind
		# the leader to still read as one tight knot of riders, while still
		# leaving the leader clearly the front-most of the group.
		var depth := (float(row) - 1.0 + 0.6) * box_spacing * spread
		var place := _icon.position + right * lateral - _movement_heading * depth

		var box := _formation_boxes[i]
		if reach < 0.0:
			box.position = place
			continue
		var gap := place - box.position
		var distance := gap.length()
		if distance <= 0.01:
			continue
		# Eased close in and capped far out: the response term is what settles
		# a rider onto its place without a stop, and the reach above is what a
		# rider crossing the group to the far side of a turn is held to.
		var step := minf(distance * maxf(formation_catch_up_response, 0.0) * delta, reach)
		box.position += gap / distance * minf(step, distance)


## How many boxes wide the formation's own grid is, leader included - see the
## class doc on [method _update_formation_heading]. A curve rather than a
## ladder of size brackets: [code]sqrt(total)[/code] is how a compact block's
## own width naturally grows with its area, [member formation_width_factor]
## is the one dial that reshapes it, and the result is clamped so a two-box
## group is never asked to be wider than it has boxes to fill.
func _formation_width() -> int:
	var total := _formation_boxes.size() + 1
	if total <= 1:
		return 1
	var raw := int(round(sqrt(float(total)) * formation_width_factor))
	return clampi(raw, mini(maxi(min_formation_width, 1), total), total)


## How many riders this group actually shows - the leader plus every trailing
## box, which is [code]ceil(group_strength / people_per_box)[/code]. A
## thirty-five strong group at the default five people to a box shows seven.
##
## The symbolic representation, never the strength: anything that should scale
## with how big the group [i]looks[/i] rather than how big it is asks this. See
## [WorldBanditGallopDirector], which gives one gallop voice to each of them.
func get_visible_bandit_count() -> int:
	return _formation_boxes.size() + 1


## Where the first [param limit] of those riders are standing right now, in
## world space, the leader first and the formation's own order after it - so a
## caller placing something on each rider lands on the front of the block
## rather than scattered through it when it wants fewer than the group shows.
##
## Read off the same boxes [method _update_formation_heading] moves, never a
## second layout of this method's own, so a rider is wherever the formation
## actually put them this frame.
func get_visible_bandit_positions(limit: int) -> PackedVector2Array:
	var places := PackedVector2Array()
	if _icon == null or limit <= 0:
		return places
	places.append(_icon.global_position)
	for box in _formation_boxes:
		if places.size() >= limit:
			break
		if is_instance_valid(box):
			places.append(box.global_position)
	return places


## Seconds between AI ticks for a group this far from the player right now -
## every frame up close, tapering off with distance. See the class doc.
func _update_interval() -> float:
	var player := _get_player()
	if player == null:
		return far_update_interval
	var distance := global_position.distance_to(player.global_position)
	if distance <= near_range:
		return 0.0
	if distance <= medium_range:
		return medium_update_interval
	return far_update_interval


## Reconsiders this group's behaviour. [param elapsed] is how many seconds
## actually passed since the last tick - not a fixed step, since ticks
## themselves run at whatever cadence [method _update_interval] currently
## chooses - and is only ever used to count down [member _investigate_timer]
## at the real rate time is passing, however often this happens to be called.
func _ai_tick(elapsed: float) -> void:
	_update_region()

	var player := _get_player()
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)
	var can_see := distance <= detection_radius and _has_line_of_sight(player)
	# An ambush is a deliberate script, not something this group has to spot -
	# see [member in_ambush] - so a group ordered into one keeps tracking the
	# player's live position however far off or blocked the sightline actually
	# is, for as long as it is still in CHASE.
	var chase_can_see := can_see or in_ambush

	# The two reasons a pursuit ends that are about *where* the player has got
	# to rather than how far ahead of this group they are: they have reached
	# safe ground, or they are off this group's own territory. Both resolve
	# into the same wind-down every other broken-off chase already runs, and
	# neither ever applies to an ambush, whose break-off is
	# [WorldMapAmbushDirector]'s alone. See [method _should_break_off].
	if not in_ambush and _is_pursuing() and _should_break_off(player, elapsed):
		_enter_disengage()
		return

	match behavior_state:
		BehaviorState.PATROL:
			if can_see:
				_on_player_spotted(player)
		BehaviorState.INVESTIGATE:
			if can_see:
				_on_player_spotted(player)
			else:
				_investigate_timer -= elapsed
				if _investigate_timer <= 0.0:
					_enter_patrol()
		BehaviorState.CHASE:
			if chase_can_see:
				_last_known_player_position = player.global_position
				target_position = _last_known_player_position
			else:
				# Lost sight of them - go take a look at where they were last
				# seen rather than either giving up outright or steering
				# blindly at a position that is now stale. See section 16.
				_enter_investigate()
			# An ambushed group's own break-off distance is
			# [WorldMapAmbushDirector]'s to decide - see [method end_ambush] -
			# not this ordinary chase's own [member give_up_distance].
			if distance > give_up_distance and not in_ambush:
				_enter_disengage()
		BehaviorState.DISENGAGE:
			_disengage_timer -= elapsed
			if can_see and distance <= give_up_distance:
				# The player closed back in, or stepped back into sight, before
				# this group had actually finished winding down - resume
				# whatever a fresh sighting would normally decide, rather than
				# a chase it has already half broken off from.
				_on_player_spotted(player)
			elif distance > chase_break_distance or _disengage_timer <= 0.0:
				_enter_patrol()
		BehaviorState.FLEE:
			if distance > chase_break_distance:
				_enter_patrol()


## Whether this group is currently after the player at all - the only two
## states a boundary or a sanctuary has anything to end.
## [constant BehaviorState.PATROL] has no pursuit to break off,
## [constant BehaviorState.DISENGAGE] is already breaking one off, and
## [constant BehaviorState.FLEE] is the opposite problem entirely.
func _is_pursuing() -> bool:
	return behavior_state == BehaviorState.CHASE \
		or behavior_state == BehaviorState.INVESTIGATE


## Whether the player is somewhere this group will not go after them at all:
## on safe ground, or off this group's own territory.
##
## The same two facts [method _should_break_off] ends a chase on, asked
## without the two-second wait and without touching a timer, so the question
## can also be put before a chase is ever committed to - see
## [method _on_player_spotted]. A group with no territory, on a map with no
## sanctuaries, is never off limits anywhere.
func _player_is_off_limits(player: Node2D) -> bool:
	if territory_radius > 0.0 \
			and _home_position().distance_to(player.global_position) > territory_radius:
		return true
	return WorldMapSanctuary.contains(self, player.global_position)


## Whether this group should give up on the player now, for a reason about
## where they are standing rather than how far off they have got.
##
## Two, in order. Safe ground first: a player on it is waited out for
## [member sanctuary_hold_duration] before the group turns back, and the wait
## is dropped the moment they leave it again, so this is a group pulling up at
## the edge of the Saloon rather than one that stops the instant a boot
## crosses the line. Then the boundary: a group with a
## [member territory_radius] gives up as soon as the player is off its own
## ground, however close they still are.
##
## A group with no territory and a map with no sanctuaries answers false to
## both, which leaves [member give_up_distance] the only thing that ever ends
## a chase - exactly as this class behaved before either existed.
func _should_break_off(player: Node2D, elapsed: float) -> bool:
	if WorldMapSanctuary.contains(self, player.global_position):
		_sanctuary_timer += elapsed
		if _sanctuary_timer >= maxf(sanctuary_hold_duration, 0.0):
			return true
	else:
		_sanctuary_timer = 0.0

	if territory_radius <= 0.0:
		return false
	return _home_position().distance_to(player.global_position) > territory_radius


## The centre of the ground this group defends: the node
## [member home_path] names, or where the scene authored this group when it
## names none. Resolved lazily and kept, the same way [member _player] and
## [member _nav_map] already are, since a camp landmark may well enter the
## tree after its garrison does.
func _home_position() -> Vector2:
	if _home == null or not is_instance_valid(_home):
		_home = get_node_or_null(home_path) as Node2D
	return _home_fallback if _home == null else _home.global_position


## Weighs this group's strength against the player's and picks a side - flee
## or chase - the way section 12 of the design asks for: a ratio read from
## [member threat_profile], never a hardcoded branch on either strength. A
## roughly matched player commits this group to neither, which resolves back
## to [constant BehaviorState.PATROL] - a fresh sighting from patrol simply
## never becomes anything, and a sighting reacquired mid-[constant BehaviorState.INVESTIGATE]
## stands the group down rather than escalating it for free.
func _on_player_spotted(player: Node2D) -> void:
	_last_known_player_position = player.global_position

	var power := WorldMapPlayerPower.get_active(self)
	var player_power := power.player_power if power != null else 0.0
	var flee_ratio := threat_profile.flee_power_ratio if threat_profile != null else 1.6
	var chase_ratio := threat_profile.chase_power_ratio if threat_profile != null else 1.6

	if player_power >= group_strength * flee_ratio:
		_enter_flee(player.global_position)
	# A group never sets off after somebody it would give up on in the same
	# breath - see [method _player_is_off_limits]. Without this a garrison
	# harries the player to its own boundary, turns back, sees them still
	# standing there and sets off again, over and over. Fleeing is deliberately
	# left above it: a group outmatched by the player runs whether or not the
	# ground it is standing on is theirs to defend.
	elif group_strength >= player_power * chase_ratio \
			and not _player_is_off_limits(player):
		_enter_chase()
	else:
		_enter_patrol()


## Puts the group back on its route.
##
## [b]Re-entering patrol while already patrolling leaves the route alone.[/b]
## [method _on_player_spotted] calls this on every AI tick for a player this
## group is neither strong enough to chase nor weak enough to run from - and up
## close that is every single frame - so without this guard the route index is
## re-snapped to whatever waypoint the group happens to be nearest sixty times a
## second. That is a group walking away from a waypoint, being told each frame
## that the waypoint behind it is the nearest one, turning back to it, arriving,
## being pointed at the next one, and turning back again: it circles the spot it
## is standing on and never leaves. It also wipes the stall bookkeeping - see
## [method _begin_destination] - on every one of those frames, so the recovery
## that exists for exactly this can never see it either.
##
## A group that is genuinely arriving into patrol from somewhere else still
## resumes at its nearest leg, which is the whole point of
## [method _nearest_route_index]; a group that was already patrolling simply
## keeps walking to the waypoint it had.
func _enter_patrol() -> void:
	var was_patrolling := behavior_state == BehaviorState.PATROL
	_set_state(BehaviorState.PATROL)
	fleeing = false
	in_ambush = false
	if was_patrolling and _route != null and not _route.get_points().is_empty():
		return
	current_route_index = _nearest_route_index()
	target_position = _route_point(current_route_index)
	_begin_destination()


func _enter_investigate() -> void:
	_set_state(BehaviorState.INVESTIGATE)
	fleeing = false
	target_position = _last_known_player_position
	_investigate_timer = threat_profile.investigate_duration if threat_profile != null else 4.0
	_begin_destination()


func _enter_chase() -> void:
	_set_state(BehaviorState.CHASE)
	fleeing = false
	target_position = _last_known_player_position
	_begin_destination()


## The visible "giving up" beat between [constant BehaviorState.CHASE] and
## [constant BehaviorState.PATROL] - see [member give_up_distance] and the
## class doc's own note on [constant BehaviorState.DISENGAGE]. Heads back
## toward the nearest point on this group's own route, at
## [member disengage_speed_multiplier], rather than the player's last known
## position: a group giving up is going home, not still hunting.
func _enter_disengage() -> void:
	_set_state(BehaviorState.DISENGAGE)
	fleeing = false
	in_ambush = false
	_disengage_timer = disengage_duration
	current_route_index = _nearest_route_index()
	target_position = _route_point(current_route_index)
	_begin_destination()


## Picks a point on the opposite side of this group from the player and
## heads for it. Never teleports and never starts a fight - see the class
## doc - it is only ever a destination and the ordinary walk toward it.
##
## The point is put onto walkable ground before it is taken - see
## [method _walkable_point]. A frightened group picks its direction from where
## the player is standing and nothing else, so on a map with any rock in it
## some of those points land inside one; taken raw, the group walks into the
## rock face and stops there, which reads as a group too frightened to move.
func _enter_flee(player_position: Vector2) -> void:
	_set_state(BehaviorState.FLEE)
	fleeing = true
	in_ambush = false
	var away := global_position.direction_to(player_position) * -1.0
	if away.is_zero_approx():
		away = Vector2.from_angle(randf() * TAU)
	target_position = global_position + away * detection_radius * 2.0
	var map := _resolve_nav_map()
	if uses_navigation and map.is_valid():
		target_position = _walkable_point(map, target_position)
	_begin_destination()


## Wipes the bookkeeping the walk to the last destination left behind, so a
## group setting off for a new one is never judged on how it was getting on
## with the old one - see [method _check_stall] - and never still walking a
## corridor or a sidestep that belonged to it.
func _begin_destination() -> void:
	# Only when the destination has genuinely changed. A group watching a player
	# it is neither strong enough to chase nor weak enough to run from re-enters
	# patrol on every single AI tick - see [method _on_player_spotted] - and
	# wiping the bookkeeping that often would mean a group stuck in front of
	# that player is never once noticed to be stuck.
	if _destination_mark != Vector2.INF \
			and _destination_mark.distance_to(target_position) <= 1.0:
		return
	_destination_mark = target_position
	_detour_point = Vector2.INF
	_detour_timer = 0.0
	_goal_reachable = true
	_stall_mark = global_position
	_stall_timer = 0.0
	_stall_count = 0
	_clear_path()


func _set_state(state: BehaviorState) -> void:
	if state == behavior_state:
		return
	behavior_state = state
	# Anything but patrol is a reaction to the player, and a reaction is
	# always simulated at full rate - so a group that starts one wakes on the
	# spot rather than waiting for [WorldBanditActivationDirector]'s next
	# sweep to notice. This is what makes [method begin_ambush] safe to call
	# on a dormant group: [WorldMapAmbushDirector] orders the chase and the
	# group is at full rate the same frame.
	if state != BehaviorState.PATROL:
		set_activation_level(ActivationLevel.ACTIVE)
	behavior_changed.emit(state)


## One frame of walking toward [member target_position]. Runs every physics
## frame regardless of how often [method _ai_tick] itself runs, which is
## what keeps a group's movement smooth even while it is only reconsidering
## its decisions a few times a second.
##
## A group part way through a sidestep walks at that instead - see
## [method _begin_detour]. [member target_position] is untouched by it, so
## nothing that reads where this group is going ever sees the detour; only
## where it is putting its feet changes, and only until the sidestep runs out.
func _step_toward_target(delta: float) -> void:
	if _detour_point != Vector2.INF:
		_detour_timer -= delta
		if _detour_timer <= 0.0 \
				or global_position.distance_to(_detour_point) <= _arrival_radius():
			_end_detour()
		else:
			_move_along_heading(_detour_point, delta)
			return
	if behavior_state == BehaviorState.PATROL:
		_step_patrol(delta)
		return
	_move_along_heading(target_position, delta)


## Walking a route, and taking the next waypoint once this one is behind the
## group - either because it arrived, or because the corridor to it came back
## short and it never can. See [member _goal_reachable].
func _step_patrol(delta: float) -> void:
	if _route == null or _route.get_points().is_empty():
		return
	_move_along_heading(target_position, delta)
	var arrived := global_position.distance_to(target_position) <= _arrival_radius()
	# A waypoint the mesh cannot reach - one dropped inside a rock as the map
	# was authored, or on ground the walkable outline does not join to this
	# group's own - is skipped rather than pressed against. Without this the
	# group walks to the nearest edge of it and stands there for good, which is
	# a patrol that has silently stopped.
	if arrived or not _goal_reachable:
		_advance_route_index()
		target_position = _route_point(current_route_index)
		# Wiped rather than left standing: everything it holds describes the
		# waypoint just given up on, and the next one has not been asked about
		# yet.
		_begin_destination()


## Turns [member _movement_heading] toward [param target] at
## [method _effective_turn_rate] and steps [member Node2D.global_position]
## along it at [method _effective_speed] - never straight at the target the
## way a plain [method Vector2.move_toward] would. This is section 15's own
## "large groups take longer to change direction, small groups stay mobile":
## the turn rate is sampled off [member group_strength] the same way
## [member speed_profile] already samples speed, so nothing here invents a
## second notion of how heavy a group is.
func _move_along_heading(target: Vector2, delta: float) -> void:
	# Where the group is going is [param target]; where it steers this frame is
	# the next corner of the corridor to it. On a map with no navigation mesh
	# the two are the same value and nothing below changes.
	var steer := _navigation_target(target)
	var to_target := steer - global_position
	var distance := to_target.length()
	var speed := _effective_speed()
	if speed <= 0.0:
		return
	if distance > 0.5:
		var desired := to_target / distance
		var max_radians := _effective_turn_rate() * TAU * delta
		var turn := clampf(_movement_heading.angle_to(desired), -max_radians, max_radians)
		_movement_heading = _movement_heading.rotated(turn).normalized()
	global_position += _movement_heading * minf(speed * delta, distance)


# --- Walking the map's navigation mesh --------------------------------------

## The point to actually steer at this frame on the way to [param target]: the
## next corner of the navigated corridor to it, or - on a map with no navigation
## mesh - [param target] itself.
##
## The corridor is only re-asked for when the destination has genuinely moved -
## see [member repath_distance] - and never more often than
## [member repath_interval], so a group chasing a running player queries the
## navigation server a couple of times a second rather than sixty.
func _navigation_target(target: Vector2) -> Vector2:
	if not uses_navigation:
		return target
	var map := _resolve_nav_map()
	if not map.is_valid():
		return target

	var stale := _path.size() < 2 \
		or _path_index >= _path.size() \
		or _path_goal == Vector2.INF \
		or _path_goal.distance_to(target) > repath_distance
	if stale and _repath_timer >= repath_interval:
		_request_path(map, target)

	if _path_index >= _path.size():
		# No corridor to walk. Steering at the raw destination is what drives a
		# group into the side of whatever stands between it and there, so the
		# nearest walkable stand-in for it is steered at instead - which for a
		# destination out on open sand is the destination itself, and for one
		# inside a rock is the sand at that rock's edge.
		return _walkable_point(map, target)

	# Corners already arrived at are passed over here rather than on a timer, so
	# a group that covered two short legs in one frame does not spend the next
	# frame walking back to the first of them.
	while _path_index < _path.size() - 1 \
			and global_position.distance_to(_path[_path_index]) <= waypoint_radius:
		_path_index += 1
	return _path[_path_index]


## Asks the navigation server for a way from here to [param target] and starts
## walking it.
##
## Also settles [member _goal_reachable] for that destination. A corridor that
## stops short of what it was asked for is the mesh's own answer that there is
## no way to there from here - the destination sits inside a rock, inside a
## structure, or on ground the walkable outline never joined to this group's -
## and that answer is what lets a patrol take its next waypoint instead of
## pressing at this one forever. Fewer than two corners is read the same way.
func _request_path(map: RID, target: Vector2) -> void:
	_repath_timer = 0.0
	_path_goal = target
	_path = NavigationServer2D.map_get_path(map, global_position, target, true)
	_path_index = 0
	if _path.size() < 2:
		_path = PackedVector2Array()
		_goal_reachable = false
		return
	_goal_reachable = _path[_path.size() - 1].distance_to(target) <= _arrival_radius()
	# The first corner is where the group is already standing.
	if global_position.distance_to(_path[0]) <= waypoint_radius:
		_path_index = 1


## The nearest point on walkable ground to [param point] - [param point] itself
## whenever it already is on some.
func _walkable_point(map: RID, point: Vector2) -> Vector2:
	return NavigationServer2D.map_get_closest_point(map, point)


## Throws the current corridor away. The next call to
## [method _navigation_target] asks for a fresh one, at the earliest the
## ordinary [member repath_interval] allows.
func _clear_path() -> void:
	_path = PackedVector2Array()
	_path_index = 0
	_path_goal = Vector2.INF


## Throws the current corridor away and lets a fresh one be asked for on the
## very next frame rather than after another [member repath_interval] of walking
## on nothing. What a group that has just been moved, or has just been found not
## to be getting anywhere, needs: waiting the interval out is a third of a
## second of steering blind, which against a rock is a third of a second of
## pushing at it.
func _force_repath() -> void:
	_clear_path()
	_repath_timer = repath_interval


## Pulls the group back onto walkable ground when it is somehow off it. The
## corridor above is what normally keeps a group clear of the rock; this is the
## backstop for the cases the corridor never covered - a group authored a little
## too close to a cliff, or moved there by something other than its own walking.
func _hold_to_navigation(delta: float) -> void:
	if not uses_navigation or not clamps_to_navigation:
		return
	_clamp_timer += delta
	if _clamp_timer < navigation_clamp_interval:
		return
	_clamp_timer = 0.0

	var map := _resolve_nav_map()
	if not map.is_valid():
		return
	var closest := NavigationServer2D.map_get_closest_point(map, global_position)
	# On the mesh, the closest point on it is where the group already is; a
	# correction only ever has a length when the group is genuinely outside.
	if global_position.distance_to(closest) > 1.0:
		global_position = closest
		# The corridor was answered from where the group was, not from where it
		# has just been put, so it is asked for again at once. Left to the
		# ordinary interval this is the loop that reads as a group shivering
		# against a rock: steer into it, get pulled back out, steer into it
		# again, a third of a second at a time.
		_force_repath()


# --- Getting unstuck ---------------------------------------------------------

## How close the leader has to come to something to count as having reached it,
## in pixels - [member waypoint_arrival_radius], or the circle the group's own
## turning describes if that is wider.
##
## A group turns at [method _effective_turn_rate] and walks at
## [method _effective_speed], and between them those describe a circle it cannot
## steer inside of. Asking it to arrive within a tolerance tighter than that
## circle is asking for something it can only orbit - and a group riding round
## and round a waypoint it never reaches is one of the two ways a patrol
## silently stops.
func _arrival_radius() -> float:
	var turn := maxf(_effective_turn_rate() * TAU, 0.001)
	return maxf(waypoint_arrival_radius, _effective_speed() / turn * arrival_turn_margin)


## Watches whether the group is actually covering ground, and takes it out of it
## when it is not. See [member stall_recovery_enabled].
##
## Ground covered is measured from where the group stood when the window opened
## to where it stands as that window closes, so a group sawing back and forth
## against a rock - which travels a long way and gets nowhere - reads as the
## standing still it really is, while a group walking the long way round a mesa
## reads as the moving it really is.
func _check_stall(delta: float) -> void:
	if not stall_recovery_enabled:
		return
	var speed := _effective_speed()
	if speed <= 0.0:
		return

	_stall_timer += delta
	if _stall_timer < stall_window:
		return
	var window := _stall_timer
	_stall_timer = 0.0
	var covered := _stall_mark.distance_to(global_position)
	_stall_mark = global_position
	if covered >= speed * window * stall_progress_fraction:
		_stall_count = 0
		return

	_stall_count += 1
	if _stall_count < maxi(stall_repath_attempts, 1):
		# The cheap answer first, and the one that covers every ordinary cause:
		# a corridor answered against a mesh that had not finished baking, or
		# one left describing ground the group is no longer standing on.
		_force_repath()
		return
	_stall_count = 0
	_break_deadlock()


## What a group does about a destination it has proved it cannot walk to.
##
## A patrol has somewhere else to be: it takes the next waypoint on its route
## and leaves this one, which is the whole of the answer to a point authored
## inside a rock. Anything else - a chase, a flight, a walk back to its own
## ground - has no second destination to take, so it steps aside instead and
## comes at the same one again from a few hundred pixels along, which is what
## carries a group round the corner of the obstacle it was pressed against.
func _break_deadlock() -> void:
	if behavior_state == BehaviorState.PATROL and _route != null \
			and not _route.get_points().is_empty():
		_advance_route_index()
		target_position = _route_point(current_route_index)
		_begin_destination()
		_force_repath()
		return
	_begin_detour()


## Sends the group a few hundred pixels along the face of whatever is in its
## way, on walkable ground, before it heads for its real destination again.
##
## The side alternates every time, so a group that steps the wrong way out of a
## dead end tries the other way next time rather than the same way twice. The
## step is put onto walkable ground by the mesh itself - see
## [method _walkable_point] - so a sidestep is never a step into another rock.
func _begin_detour() -> void:
	var toward := global_position.direction_to(target_position)
	if toward.is_zero_approx():
		toward = _movement_heading
	var aside := toward.orthogonal() * _detour_side
	_detour_side = -_detour_side

	var point := global_position + (aside + toward * 0.35).normalized() * detour_distance
	var map := _resolve_nav_map()
	if map.is_valid():
		point = _walkable_point(map, point)
	# A sidestep that lands back on top of the group is no sidestep at all, and
	# would only spend [member detour_duration] going nowhere.
	if global_position.distance_to(point) <= _arrival_radius():
		_force_repath()
		return
	_detour_point = point
	_detour_timer = maxf(detour_duration, 0.0)
	_force_repath()


## Ends a sidestep and puts the group back onto its real destination.
func _end_detour() -> void:
	_detour_point = Vector2.INF
	_detour_timer = 0.0
	_goal_reachable = true
	_stall_mark = global_position
	_stall_timer = 0.0
	_force_repath()


## The navigation map this group walks, or an invalid [RID] on a map that has
## none. Resolved lazily and then kept: a mesh baked in [WorldMapNavigation]'s
## own [method Node._ready] is not queryable until the navigation server has
## synchronised, which is a frame or two after every node is ready.
func _resolve_nav_map() -> RID:
	if _nav_map.is_valid():
		return _nav_map
	if not is_inside_tree():
		return RID()
	var map: RID = get_world_2d().navigation_map
	if not map.is_valid() or NavigationServer2D.map_get_regions(map).is_empty():
		return RID()
	# A map that has not run an iteration yet refuses every query and complains
	# about it, so the mesh is only taken up once the server says it has one -
	# which is a frame or two after the region baked itself.
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return RID()
	_nav_map = map
	return _nav_map


## [member movement_speed] - [member speed_profile] sampled at
## [member group_strength], the group's own top speed - scaled by whichever
## of the [code]"State Speed"[/code] multipliers matches [member behavior_state]
## right now. [constant BehaviorState.CHASE] and [constant BehaviorState.FLEE]
## are left at the full, unmultiplied speed - "use the existing chase speed,
## but still obey group-size speed differences" is exactly what leaving
## [member movement_speed] alone already does, since that figure is the
## group-size curve's own answer.
func _effective_speed() -> float:
	var multiplier := 1.0
	match behavior_state:
		BehaviorState.PATROL:
			multiplier = roam_speed_multiplier
		BehaviorState.INVESTIGATE:
			multiplier = investigate_speed_multiplier
		BehaviorState.DISENGAGE:
			multiplier = disengage_speed_multiplier
	return movement_speed * multiplier


## This group's turning speed right now, in turns per second - a heavier,
## larger group turns slower, the same span [member speed_profile] already
## defines for speed, so retuning one curve's endpoints does not leave the
## other out of step with it.
func _effective_turn_rate() -> float:
	if speed_profile == null:
		return max_turn_rate
	var span := maxf(speed_profile.max_group_strength - speed_profile.min_group_strength, 0.001)
	var t := clampf((group_strength - speed_profile.min_group_strength) / span, 0.0, 1.0)
	return lerpf(max_turn_rate, min_turn_rate, t)


## Moves [member current_route_index] on to the next waypoint - wrapping
## straight back to the first point for a looping route, or reversing
## direction at either end for the default there-and-back one. See
## [member WorldBanditRoute.loop].
func _advance_route_index() -> void:
	var points := _route.get_points()
	if points.size() <= 1:
		return

	if _route.loop:
		current_route_index = (current_route_index + 1) % points.size()
		return

	current_route_index += _route_direction
	if current_route_index >= points.size():
		current_route_index = points.size() - 2
		_route_direction = -1
	elif current_route_index < 0:
		current_route_index = mini(1, points.size() - 1)
		_route_direction = 1


func _route_point(index: int) -> Vector2:
	if _route == null:
		return global_position
	var points := _route.get_points()
	if points.is_empty():
		return global_position
	return points[clampi(index, 0, points.size() - 1)]


## The route point this group should walk to next, given where it actually is:
## the nearest one it is not already standing on.
##
## The plain nearest point is what a group returning from a chase wants, so it
## resumes at whichever leg of its route it ended up beside instead of snapping
## back to wherever it started. But "nearest" alone hands back the waypoint
## under the group's own feet whenever it happens to have stopped on one, and a
## destination the group has already arrived at is a destination it can only
## circle: [method _move_along_heading] steers at it, the group's own turning
## circle is wider than the gap, and it orbits a point it is already at. So a
## point already within [method _arrival_radius] is treated as reached and
## passed over, exactly the way [method _step_patrol] would have passed over it.
##
## Every point being within reach - a group standing in the middle of a very
## short route - falls back to the plain nearest, since there is no further leg
## to prefer and walking to the nearest one is still the right answer.
func _nearest_route_index() -> int:
	if _route == null:
		return 0
	var points := _route.get_points()
	if points.is_empty():
		return 0
	var reach := _arrival_radius()
	var best_index := 0
	var best_distance := INF
	var nearest_index := 0
	var nearest_distance := INF
	for i in points.size():
		var distance := global_position.distance_to(points[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
		if distance > reach and distance < best_distance:
			best_distance = distance
			best_index = i
	return nearest_index if best_distance == INF else best_index


## True only when [param target] is both within [member detection_radius] and
## not behind a blocking rock or canyon wall - the World Map's own
## "prop_solid" obstruction layer, queried through Godot's ordinary 2D
## physics rather than a second occlusion system. See [member vision_obstruction_mask].
##
## [b]Shared with the World Map's own visual occlusion.[/b] [WorldMapOcclusion]
## exists so this exact raycast is also what decides whether a location or a
## bounty boss can be [i]seen[/i], not only whether it can see the player -
## see that class's own doc. This delegates to it when one is in the scene,
## and falls back to the original inline query - unchanged - for a World Map
## that has not added one, so nothing about this class's own behaviour moved.
##
## The target's own body is excluded from the query either way. Without that,
## a ray aimed exactly at the player's [CharacterBody2D] always reports a hit -
## the player themselves, standing right where the ray ends - which every
## unobstructed sightline would otherwise be mistaken for a blocked one.
func _has_line_of_sight(target: Node2D) -> bool:
	var exclude: Array[RID] = []
	if target is CollisionObject2D:
		exclude.append((target as CollisionObject2D).get_rid())

	var occlusion := WorldMapOcclusion.get_active(self)
	if occlusion != null:
		return occlusion.has_line_of_sight(global_position, target.global_position, exclude)

	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var params := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, vision_obstruction_mask)
	if not exclude.is_empty():
		params.exclude = exclude
	var result := space.intersect_ray(params)
	return result.is_empty()


## Hides this group's art the instant it is not [WorldMapFog]'s VISIBLE
## state - EXPLORED remembers the ground but not what is moving on it,
## per Phase 3B-2 - while [method _ai_tick] and [method _step_toward_target]
## keep running underneath exactly as before. A hidden group is never
## paused, only unseen; see the class doc on [member active] for the flag
## that actually freezes one. A World Map with no [WorldMapFog] in it
## leaves every group visible, so this never gates anything for a scene
## that hasn't added fog yet.
##
## [b]A rock or a canyon wall hides it too.[/b] Being inside the fog's
## VISIBLE radius is not the same as being seeable - see [WorldMapOcclusion] -
## so a group standing behind a blocking obstruction reads exactly as it
## would if the fog itself had never revealed it, and it becomes visible
## again the instant the player walks around whatever was in the way. A
## World Map with no [WorldMapOcclusion] in it leaves this exactly as fog
## alone already decided, so this never gates anything for a scene that
## hasn't added one yet.
func _update_fog_visibility() -> void:
	var fog := WorldMapFog.get_active(self)
	var fog_visible := true if fog == null else fog.get_state(global_position) == WorldMapFog.VisibilityState.VISIBLE
	if not fog_visible:
		visible = false
		return

	var occlusion := WorldMapOcclusion.get_active(self)
	visible = true if occlusion == null else occlusion.is_visible_from_player(global_position)


## Reads this group's current region off the same [WorldMapRegionZone]
## rectangles the player's own crossing already updates [WorldMapState]
## with - never a second region system. Leaves [member region_id] at its
## last known value outside every authored zone, the same fallback
## [WorldMapState] itself uses.
func _update_region() -> void:
	for node in get_tree().get_nodes_in_group(WorldMapRegionZone.GROUP):
		var zone := node as WorldMapRegionZone
		if zone == null or zone.region == null:
			continue
		if zone.get_world_area().has_point(global_position):
			if zone.region.region_id != region_id:
				region_id = zone.region.region_id
				region_changed.emit(region_id)
			return


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	return _player


## The name a debug readout shows for [member behavior_state].
func get_state_name() -> String:
	match behavior_state:
		BehaviorState.PATROL:
			return "PATROL"
		BehaviorState.INVESTIGATE:
			return "INVESTIGATE"
		BehaviorState.CHASE:
			return "CHASE"
		BehaviorState.FLEE:
			return "FLEE"
		BehaviorState.DISENGAGE:
			return "DISENGAGE"
	return "?"


## The name a debug readout shows for [member activation_level].
func get_activation_name() -> String:
	return "ACTIVE" if activation_level == ActivationLevel.ACTIVE else "DORMANT"


# --- Surviving the region's scene being freed --------------------------------

## Records this group as beaten, so it is not standing here again the next time
## this region is built.
##
## Called by [WorldMapCombatBridge] as it takes the fight to an arena, before the
## map is freed. It is written down rather than simply freed because freeing is
## all a scene change does anyway - what has to outlive it is the fact that this
## particular group is gone.
func mark_defeated() -> void:
	_defeated = true
	# Taken off the region's population as well as written down here. The record
	# below is what keeps this group gone for the rest of this run; the
	# population is what keeps it gone for every run after it - see
	# [BanditPopulationState].
	var population := _population()
	if population != null:
		population.record_defeat(region_id, name)
	_write_record()


## Whether this group has been beaten.
func is_defeated() -> bool:
	return _defeated


## The world's bandit population, or null when there is none to ask - a region
## opened on its own for tuning, or a group authored not to be remembered at
## all. Every caller reads null as "nothing is being kept", which leaves the
## region exactly as its scene authored it.
##
## [member remembers_across_scenes] gates this for the same reason it gates the
## record: a group that is not remembered is not part of a population that
## outlives the run either, so turning the flag off still leaves a map that
## plays the same way every time it is opened.
func _population() -> BanditPopulationState:
	if not remembers_across_scenes:
		return null
	return BanditPopulationState.get_active(self)


## Counts this group into its region's population. Called once, as the group is
## built, before anything can free it.
func _note_population() -> void:
	var population := _population()
	if population != null:
		population.note_group(region_id, name)


## Reads back what this group was doing the last time its region was built.
## Answers true when the record says it was beaten, which [method _ready] takes
## as "do not stand here at all".
##
## A group with no record has never been met and keeps every value its scene
## authored, which is what the first ride into a region shows.
func _restore() -> bool:
	if not remembers_across_scenes or region_id.is_empty():
		return false

	# The region's own population is asked first, and it is the answer that
	# outlives a run: a group beaten in an earlier run is gone from this region
	# for good, and there is no record of it here to say so, because the memory
	# below is meant to be thrown away when a run ends. See
	# [BanditPopulationState].
	var population := _population()
	if population != null and population.is_group_lost(region_id, name):
		_defeated = true
		return true

	var state := WorldMapState.get_active(self)
	if state == null:
		return false

	var record := state.recall(region_id, WorldMapState.KIND_BANDIT, name)
	if record.is_empty():
		return false
	if record.get("defeated", false):
		_defeated = true
		return true

	global_position = record.get("position", global_position)
	group_strength = record.get("group_strength", group_strength)
	current_route_index = record.get("route_index", current_route_index)
	_route_direction = record.get("route_direction", _route_direction)
	return false


## Writes down what this group is doing, so the next build of this region picks
## it up mid-patrol rather than back at the spot it was authored at.
##
## [b]Behaviour is deliberately not kept, and neither is [member active].[/b] A
## chase, an investigation or a flight is a reaction to a player who is no longer
## there - the map has been left - so a group is always found patrolling again,
## from wherever it had actually got to. Being stood down is the same kind of
## fact: a group is held still for the length of a journey out of the region, and
## coming back to find it still frozen would be remembering the transition rather
## than the world. Position and strength are what is worth keeping.
func _write_record() -> void:
	if not remembers_across_scenes or region_id.is_empty():
		return
	var state := WorldMapState.get_active(self)
	if state == null:
		return

	if _defeated:
		state.remember(region_id, WorldMapState.KIND_BANDIT, name, {"defeated": true})
		return

	state.remember(region_id, WorldMapState.KIND_BANDIT, name, {
		"position": global_position,
		"group_strength": group_strength,
		"route_index": current_route_index,
		"route_direction": _route_direction,
	})


func _exit_tree() -> void:
	_write_record()
