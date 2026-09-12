class_name HorseRig
extends Node2D
## One horse, animated from its own parts - the player's mount and every bandit
## group's riders, running the same code and the same clock.
##
## [b]There is one horse animation system and this is it.[/b] The player's horse
## and a bandit's horse are two scenes of the same rig with different artwork in
## them; nothing anywhere asks which of the two it is holding. See
## [code]Scenes/World/Horses/Horse.tscn[/code], which owns the skeleton and the
## whole of [member parts], and the inherited scenes beside it, which override
## six textures and nothing else. [b]Adding a horse is a new inherited scene,
## not a new script[/b] - and a horse built from different pieces, with two
## front legs or a saddle that swings, is entries added to [member parts] in
## that scene rather than a line added here. This file knows about a phase, a
## blend and an array; it has never heard of a head, a leg or a tail.
##
## [b]Speed is measured, never asked for.[/b] How fast this rig is travelling is
## the ground it actually covered since the last physics tick - so the same rig
## gallops under a [CharacterBody2D] the player is steering, under a formation
## box a [WorldBandit] is sliding along a route, or under anything else that
## moves, with nothing wired up and no notion of whose horse it is. The physics
## tick is not an incidental choice: it is the clock every one of those carriers
## actually moves on, and reading the travel anywhere else is what
## [method _physics_process] explains at length. It is the principle
## [WorldBanditGallopDirector] already sounds a gallop by, applied to the
## picture: a horse standing still because it arrived, because it is blocked or
## because an encounter froze it stops moving its legs for the one reason and by
## the one measurement.
##
## [b]The stride has one clock, and it is spun up rather than switched on.[/b]
## The measured speed says what stride rate the horse [i]should[/i] be running
## at - see [method _target_cycles_per_second] - and [member _rate] is walked
## toward that at a fixed rate. There is no moment at which a cycle is started
## or stopped: the phase turns continuously and only its speed changes, which is
## what makes the gallop loop seamlessly however long it is held, and what makes
## every one of the three transitions below a change of pace rather than a
## change of animation.
##
## [b]The three transitions are timed separately, because they are asked for
## separately.[/b] Setting off from a standstill takes
## [member ramp_up_duration] to reach [member cycles_per_second_at_walk] -
## the deliberate, unhurried spin-up a horse getting under way has. Easing
## between two rates the horse is still moving at - a sprint let go of, so the
## gallop falls back to the normal rate rather than to nothing - takes
## [member ease_down_duration]. And settling from whatever the horse was
## running at into the idle animation, once it has genuinely stopped, takes
## [member stop_settle_duration] and always exactly that, however fast it was
## going when it stopped: see [method _rate_step_per_second]. A horse pulling up
## out of a full sprint reaches idle in the same half second as one pulling up
## out of an amble, because the step is measured from the rate the settle began
## at rather than from a fixed span.
##
## [b]The picture keeps its own timing; the sound keeps [GallopRamp].[/b] The
## two used to be read off the same eased number, but the gallop is now animated
## at its own authored rate - see [member cycles_per_second_at_walk] - which the
## hoofbeats deliberately do not follow. [WorldMapHorseGallop] and
## [WorldBanditGallopDirector] still run the ramp they always did, and nothing
## in this file touches a voice.
##
## [b]Off the World Map it does not run at all.[/b] A hidden rig is skipped
## entirely - see [method _process] - so the horse a mounted player is not
## currently on, and every bandit group the fog has not revealed, cost a
## visibility test per frame and nothing else.

## Group every rig joins, so a debug readout or a later system can find the
## horses in play without a [NodePath] to any of them.
const GROUP := &"horse_rig"

## Every part of this horse and how it moves - see [HorsePartMotion]. The whole
## of the animation: an empty array is a horse that stands perfectly still, and
## a longer one is a horse with more pieces, not a horse this script has been
## taught about.
@export var parts: Array[HorsePartMotion] = []
## The node the whole body's bounce and pitch are written to - the parent every
## part hangs off, so the horse rises, falls and tips as one piece and each part
## still swings about its own joint underneath. Kept off this node itself
## because this node's own movement is what the speed is measured from.
@export var pivot_path: NodePath = ^"Rig"

@export_group("Gait")
## The speed ordinary movement is, in pixels per second - where the stride rate
## reaches [member cycles_per_second_at_walk] and the pose is fully galloping.
## Movement slower than this animates proportionally slower, which is what lets
## the same rig read correctly under a bandit group ambling along its route.
@export var walk_speed: float = 220.0
## The speed a full sprint is, in pixels per second - where the stride rate
## reaches [method get_sprint_cycles_per_second]. The player reaches it holding
## Shift; a group closing on the player reaches it by moving that fast, so
## neither of them needs this file to know what Shift is.
@export var run_speed: float = 420.0
## Strides per second at [member walk_speed] - the normal animation speed
## everything else here is measured against.
@export var cycles_per_second_at_walk: float = 3.2
## How many times the normal rate a full sprint gallops at - see
## [method get_sprint_cycles_per_second], which is what
## [member run_speed] actually reaches.
##
## [b]A multiple rather than a second authored rate.[/b] "A sprint is one and a
## half times the normal gallop" is the rule, so it is written here as one, and
## retuning [member cycles_per_second_at_walk] carries the sprint with it
## instead of quietly breaking the relationship between two numbers that only
## happened to agree.
@export_range(1.0, 3.0, 0.05) var sprint_cycles_multiplier: float = 1.5
## Cycles per second of the standing horse's own breathing, handed over to the
## gallop as that takes hold rather than added on top of it - see
## [method _advance]. The gallop itself still winds up from a standstill; this
## is only what is left turning underneath it once it has wound back down.
@export var idle_cycles_per_second: float = 0.6
## How long the gallop takes to wind up from a standstill to
## [member cycles_per_second_at_walk], in seconds. Movement worth less than the
## full rate arrives proportionally sooner, because this is a rate rather than a
## countdown - see [method _advance].
@export var ramp_up_duration: float = 1.0
## How long it takes to ease back to a [i]lower rate the horse is still moving
## at[/i], in seconds - letting go of a sprint, so the gallop drops back to the
## normal rate. Measured the same way [member ramp_up_duration] is, over the
## whole span up to [member cycles_per_second_at_walk], so letting go of a
## sprint gives back the half second that taking it up cost.
##
## Settling to a standstill is not this: see [member stop_settle_duration].
@export var ease_down_duration: float = 1.0
## How long the horse takes to settle from whatever it was running at into the
## idle animation once it has stopped moving, in seconds.
##
## Always exactly this long, from a full sprint as much as from an amble - see
## [method _rate_step_per_second] - so a horse pulling up is in its idle
## animation within a known half second rather than after a wind-down that runs
## longer the faster it was going. The stride keeps turning the whole way: this
## is the pace of the settle, never a cut.
@export var stop_settle_duration: float = 0.5
## The most ground a single frame is allowed to count as travel, as a multiple
## of [member run_speed]. A scene change, a teleport or a formation rebuilt
## under a rider moves it further in one frame than any gallop could, and this
## is what stops that from being read as a burst of speed.
@export var maximum_measured_speed_scale: float = 2.0

@export_group("Body")
## How far the whole horse rises and falls over a stride, in the rig's own
## source pixels - written to [member pivot_path].
@export var bounce_pixels: float = 60.0
## How many times the body rises per stride. 1 is the single suspension of a
## gallop; 2 answers on both beats.
@export_range(1, 4) var bounce_harmonic: int = 1
## How far the whole horse tips forward and back over a stride, in degrees.
@export var pitch_degrees: float = 2.0
## Where in the stride the body reaches the top of its rise, in turns.
@export_range(0.0, 1.0) var bounce_phase_offset: float = 0.0

@export_group("Footing")
## Whether the rig stands its artwork on its own origin, rather than hanging it
## from the saddle.
##
## [b]A horse is drawn round its saddle and its origin is that saddle[/b] - which
## is what lets it turn round underneath a rider without moving them - so the
## artwork reaches well below the point the rig node is actually at. Everything in
## the World Map that asks where a thing is standing reads a node's own position:
## the map is y-sorted, so a horse whose origin is its saddle is sorted a body's
## height behind where its hooves are and disappears behind scenery it is standing
## in front of; and a shadow is thrown from the same line, so it would leave from
## the saddle rather than from the ground.
##
## With this on the pivot is lowered by however far the artwork hangs - see
## [method get_saddle_height] - so the picture is unchanged in shape and the rig's
## origin is the line its hooves stand on. Whoever is riding it is lifted by the
## same number and stays in the saddle - see [WorldMapHorse].
@export var stands_on_own_origin: bool = true
## The saddle height written out by hand, in world pixels, instead of measured off
## the artwork. Anything at or below zero measures - see
## [method get_saddle_height] - which is what every horse should use.
@export var saddle_height_override: float = 0.0

@export_group("Facing")
## Whether the artwork is drawn facing left, which every horse in the project is
## so far. The rig mirrors itself about its own origin - the saddle - so the
## rider it is under never moves when the horse turns round.
@export var art_faces_left: bool = true
## How far the horse must actually travel sideways in a frame, in pixels, before
## it turns round. Stops a horse held on the spot from flickering between the
## two facings.
@export var facing_deadzone: float = 0.35

## -1 when the horse is travelling left, +1 when it is travelling right.
var facing: float = -1.0

var _pivot: Node2D
var _nodes: Array[Node2D] = []
var _rest_positions: PackedVector2Array = PackedVector2Array()
var _rest_rotations: PackedFloat32Array = PackedFloat32Array()
var _pivot_rest_position := Vector2.ZERO
var _pivot_rest_rotation: float = 0.0
var _base_scale_x: float = 1.0
## The stride clock, in radians. One and the same for every part; where a part
## sits in it is [member HorsePartMotion.phase_offset] and nothing else.
var _phase: float = 0.0
## Strides per second the horse is actually turning at right now - the one
## eased number the stride clock and the pose blend are both read off. See the
## class doc.
var _rate: float = 0.0
## The stride rate the current settle-to-idle began at, held for as long as that
## settle lasts so it is paced against where it started rather than against a
## fixed span - see [method _rate_step_per_second]. Zero whenever the horse is
## not settling, which is what arms the next one.
var _settle_from_rate: float = 0.0
var _last_position := Vector2.ZERO
var _has_last_position: bool = false
## The speed the last physics tick measured, held between them so every drawn
## frame in the gap winds the stride toward the same number. See
## [method _physics_process].
## How far the artwork hangs below the rig's own origin, in world pixels, and
## whether that has been worked out yet - see [method get_saddle_height]. Measured
## once, from the pose the rig was authored in, because it is a property of the
## drawing rather than of the moment.
var _saddle_height: float = 0.0
var _measured_saddle: bool = false
var _measured_speed: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_pivot = get_node_or_null(pivot_path) as Node2D
	if _pivot != null:
		_pivot_rest_position = _pivot.position
		_pivot_rest_rotation = _pivot.rotation
	_stand_on_origin()
	_base_scale_x = absf(scale.x)
	if _base_scale_x <= 0.0:
		_base_scale_x = 1.0

	for motion: HorsePartMotion in parts:
		var node: Node2D = null
		if motion != null:
			node = get_node_or_null(motion.part_path) as Node2D
		_nodes.append(node)
		_rest_positions.append(Vector2.ZERO if node == null else node.position)
		_rest_rotations.append(0.0 if node == null else node.rotation)

	# Face the way the artwork was drawn until something has actually moved, so
	# a horse built and shown in the same frame is not mirrored on a measurement
	# it has not taken yet.
	facing = -1.0 if art_faces_left else 1.0
	_apply_facing()


## How far this rig's artwork hangs below its own origin, in world pixels - the
## distance from the saddle down to the line the hooves stand on.
##
## [b]Measured off the drawing, never authored.[/b] A horse with longer legs, a
## different rig or a different scale answers a different number without anything
## being typed in, which is the whole point: nothing here knows what a hoof is, only
## how far down the picture reaches. Taken once, from the pose the scene was
## authored in, so an animation lifting a leg cannot change where the horse is
## standing.
func get_saddle_height() -> float:
	if saddle_height_override > 0.0:
		return saddle_height_override
	if not _measured_saddle:
		_measured_saddle = true
		_saddle_height = maxf(_lowest_art(self, -INF) - global_position.y, 0.0)
	return _saddle_height


## Lowers the pivot by the saddle height, so the picture stays exactly where it was
## drawn while the rig's own origin becomes the ground the horse is standing on -
## see [member stands_on_own_origin].
##
## Written into the pivot's rest pose rather than onto the node, so the bounce and
## the pitch go on being measured from where the body actually sits, and so the
## rig's own position stays free for whatever is carrying it.
func _stand_on_origin() -> void:
	if not stands_on_own_origin or _pivot == null:
		return
	var drop := get_saddle_height()
	if drop <= 0.0:
		return
	# The pivot is inside the rig's own scale, so a world measurement has to be
	# brought back into it - a horse drawn at a tenth of its source size hangs a
	# tenth as far in the world as it does in its own pixels.
	var vertical := absf(global_scale.y)
	if vertical <= 0.0001:
		return
	_pivot_rest_position.y -= drop / vertical
	_pivot.position = _pivot_rest_position


## The lowest point any artwork under [param node] reaches, in world pixels.
static func _lowest_art(node: Node, lowest: float) -> float:
	var sprite := node as Sprite2D
	if sprite != null and sprite.texture != null:
		for corner: Vector2 in SpriteBounds.global_corners(sprite):
			lowest = maxf(lowest, corner.y)
	for child: Node in node.get_children():
		lowest = _lowest_art(child, lowest)
	return lowest


## Measures the ground covered, on the clock the ground is actually covered on.
##
## [b]The travel has to be read where the travel happens.[/b] Everything that
## carries a horse moves in physics: the player is a [CharacterBody2D] calling
## [method CharacterBody2D.move_and_slide], and a [WorldBandit] steps along its
## route in its own [method Node._physics_process]. So between two physics ticks
## the carrier's position does not change at all, however many frames are drawn
## in the gap - and this project draws a great many, with
## [code]physics_interpolation[/code] on and no frame cap. Sampling once a drawn
## frame therefore reads a stream of zeroes broken by single-tick jumps, and
## those jumps divided by a short render delta come out far above any real gallop
## and are thrown away by [member maximum_measured_speed_scale] as teleports.
## The horse then winds itself down while it is still running - which is exactly
## the gallop that stopped after a while.
##
## Sampled here instead, one physics tick's travel is divided by one physics
## tick, which is the speed the carrier is genuinely moving at and nothing else.
## The pose is still built every drawn frame - see [method _process] - so none of
## the smoothness is lost.
func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		# A rig that comes back into view must not read the ground it covered
		# while it was hidden as one tick of travel, and must set off from a
		# standstill rather than resume the gallop it was cut off mid-stride.
		_has_last_position = false
		_measured_speed = 0.0
		_rate = 0.0
		_settle_from_rate = 0.0
		return

	_measured_speed = _measure_speed(delta)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_advance(_measured_speed, delta)


## One frame of the horse: winds the stride rate toward whatever the measured
## speed is worth, turns the stride clock at it, and poses the body and every
## part against it.
##
## [b]The blend and the stride rate are the same number read twice.[/b] There is
## no "standing" animation and no "galloping" animation to cross-fade between:
## every part swings between its [member HorsePartMotion.idle_swing_degrees] and
## its [member HorsePartMotion.swing_degrees] by how far [member _rate] has
## wound up, on a clock turning at that same rate. So a horse pulling up slows
## its legs and shortens its stride together, which is what settling actually
## looks like, and never snaps out of a pose.
##
## [b]The wind-up is a rate, not a countdown.[/b] The step is a fraction of the
## whole span from a standstill to [member cycles_per_second_at_walk] rather
## than of the gap still to close, so setting off takes
## [member ramp_up_duration] to reach the normal rate whatever it is passing
## through - never a spring that crawls as it arrives. Reaching a sprint takes
## proportionally longer for the same reason, and a gentle drift reaches its own
## lower rate proportionally sooner. Settling to a standstill is the one
## transition paced differently, and [method _rate_step_per_second] says why.
func _advance(measured_speed: float, delta: float) -> void:
	var target := _target_cycles_per_second(measured_speed)
	_rate = move_toward(_rate, target, _rate_step_per_second(target) * delta)

	var span := maxf(cycles_per_second_at_walk, 0.0001)
	var blend := clampf(_rate / span, 0.0, 1.0)
	# The standing horse's own breathing, handed over to the gallop as that
	# takes hold rather than added on top of it - so the clock never stops
	# turning, and a horse at a full gallop is turning at exactly
	# [member cycles_per_second_at_walk] with nothing else mixed in.
	var cycles := _rate + idle_cycles_per_second * (1.0 - blend)
	_phase = fmod(_phase + cycles * TAU * delta, TAU)

	_pose_body(blend)
	for i in _nodes.size():
		_pose_part(i, blend)


## How many strides per second [member _rate] is allowed to move by in one
## second, easing toward [param target] - the whole of the rig's timing.
##
## [b]Moving toward any moving pace is a fixed rate.[/b] Setting off and easing
## a sprint back down are both a step of the whole span up to
## [member cycles_per_second_at_walk] over their own duration, so setting off
## takes [member ramp_up_duration] to reach the normal rate and letting go of a
## sprint takes [member ease_down_duration] to give back the same ground - the
## climb and the fall between two moving rates are symmetrical, and neither
## depends on where in the range it happens to be.
##
## [b]Settling to a standstill is measured from where it started instead.[/b]
## A step of the fixed span would take half again as long to fall out of a
## sprint as out of an amble, which is exactly the wind-down that leaves a horse
## still visibly galloping after it has stopped. So the rate the settle began at
## is latched the moment the target reaches zero and the step is that over
## [member stop_settle_duration], which lands the stride on idle in
## [member stop_settle_duration] flat from any speed. The latch is cleared the
## instant the horse is asked to move again, so a settle interrupted halfway
## winds straight back up rather than finishing on a stale number.
func _rate_step_per_second(target: float) -> float:
	if target > 0.0:
		_settle_from_rate = 0.0
		var duration := ramp_up_duration if target > _rate else ease_down_duration
		return maxf(cycles_per_second_at_walk, 0.0001) / maxf(duration, 0.0001)

	if _settle_from_rate <= 0.0:
		_settle_from_rate = maxf(_rate, 0.0001)
	return _settle_from_rate / maxf(stop_settle_duration, 0.0001)


## How fast this rig is travelling right now - the ground it actually covered
## since the last physics tick. See the class doc on why it is measured rather
## than read off whatever is carrying it.
##
## A tick that covers more ground than any gallop could - a scene change, a
## teleport, a formation rebuilt under a rider - holds the last real reading
## rather than reporting a standstill, so a single jump can never be the thing
## that stops a running horse's legs.
func _measure_speed(delta: float) -> float:
	var here := global_position
	if not _has_last_position or delta <= 0.0:
		_has_last_position = true
		_last_position = here
		return 0.0

	var travelled := here - _last_position
	_last_position = here

	if absf(travelled.x) > facing_deadzone:
		facing = signf(travelled.x)
		_apply_facing()

	var speed := travelled.length() / delta
	var ceiling := maxf(run_speed, walk_speed) * maxf(maximum_measured_speed_scale, 0.0)
	if ceiling > 0.0 and speed > ceiling:
		return _measured_speed
	return speed


## How fast the gallop is actually turning right now, in strides per second -
## zero standing still, [member cycles_per_second_at_walk] under ordinary
## movement and [method get_sprint_cycles_per_second] at a sprint, with the wind-up
## and wind-down between them already applied. For a debug readout, and for
## anything that has to know how far along the horse is rather than guess.
func get_cycles_per_second() -> float:
	return _rate


## Strides per second at [member run_speed] and beyond - the normal rate taken
## [member sprint_cycles_multiplier] times over. Derived rather than authored,
## so a sprint is one and a half times the normal gallop by construction; see
## [member sprint_cycles_multiplier].
func get_sprint_cycles_per_second() -> float:
	return maxf(cycles_per_second_at_walk, 0.0) * maxf(sprint_cycles_multiplier, 0.0)


## The stride rate this much travel is worth - nothing at a standstill,
## [member cycles_per_second_at_walk] at [member walk_speed], and climbing to
## [method get_sprint_cycles_per_second] as the horse closes on
## [member run_speed]. What [method _advance] winds toward, never what it plays
## immediately.
##
## [b]Read off the travel itself, not off a state.[/b] The player holding Shift
## is a horse actually moving at [member run_speed] and a bandit group running
## the player down is a group actually moving that fast, so both reach the
## sprint rate through the one measurement and neither the player's input nor a
## group's behaviour is ever consulted here.
func _target_cycles_per_second(measured_speed: float) -> float:
	var walk := maxf(walk_speed, 0.0001)
	if measured_speed <= walk:
		return cycles_per_second_at_walk * clampf(measured_speed / walk, 0.0, 1.0)
	if run_speed <= walk_speed:
		return cycles_per_second_at_walk
	var t := clampf((measured_speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)
	return lerpf(cycles_per_second_at_walk, get_sprint_cycles_per_second(), t)


## The whole horse rising, falling and tipping as one piece, written to
## [member pivot_path] so every part still swings about its own joint under it.
func _pose_body(blend: float) -> void:
	if _pivot == null:
		return
	var angle := _phase * float(bounce_harmonic) + bounce_phase_offset * TAU
	_pivot.position = _pivot_rest_position + Vector2(0.0, -bounce_pixels * blend * (0.5 - 0.5 * cos(angle)))
	_pivot.rotation = _pivot_rest_rotation + deg_to_rad(pitch_degrees) * blend * sin(angle)


## Where one entry of [member parts] puts its node this frame: turned about its
## own joint by its swing, carried by its bias as the gallop blends in, and
## shifted on the small oval [member HorsePartMotion.lift_pixels] and
## [member HorsePartMotion.reach_pixels] describe.
func _pose_part(index: int, blend: float) -> void:
	var node := _nodes[index]
	if node == null:
		return
	var motion: HorsePartMotion = parts[index]
	if motion == null:
		return

	var angle := _phase * float(motion.harmonic) + motion.phase_offset * TAU
	var wave := sin(angle)

	var swing := deg_to_rad(lerpf(motion.idle_swing_degrees, motion.swing_degrees, blend))
	node.rotation = _rest_rotations[index] + swing * wave + deg_to_rad(motion.swing_bias_degrees) * blend

	var lift := lerpf(motion.idle_lift_pixels, motion.lift_pixels, blend)
	node.position = _rest_positions[index] + Vector2(motion.reach_pixels * blend * cos(angle), -lift * wave)


## Mirrors the horse about its own origin. The origin is the saddle - see
## [code]Horse.tscn[/code] - so turning round never moves the rider sitting on
## it, and writes only [member Node2D.scale], so nothing here fights the
## rotations [method _pose_part] is writing underneath.
func _apply_facing() -> void:
	var art_forward := -1.0 if art_faces_left else 1.0
	scale.x = _base_scale_x * facing * art_forward
