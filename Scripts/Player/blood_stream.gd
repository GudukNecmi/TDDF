class_name BloodStream
extends MultiMeshInstance2D
## Blood that has left the floor and is flowing to whatever is pulling it in.
##
## Specks are handed over one at a time - by [BloodMagnet] when a death's blood
## has settled, or by [BloodPool] when it is banked - and this node owns them
## until they reach the target, at which point they are dropped and counted.
##
## Like the field it is one [MultiMesh]: every speck in flight is an instance, so
## a few hundred of them cost a single draw call and own no nodes, no physics and
## no particle systems. Motion is integrated in flat parallel arrays with
## swap-removal, so a speck arriving never shuffles the others.
##
## [b]The motion is a liquid, not a swarm.[/b] A speck travels along the straight
## line to the target and nothing else: there is no flick, no orbit and no
## per-speck route. What makes it read as blood rather than as a bead on a wire is
## that the line is only where the speck is *carried* - it is drawn a little to
## one side of it, on a slow sine that eases in at launch and tightens back to
## nothing as the target is approached. The swing is bounded twice over, by
## [member wave_strength] and then hard by [member max_deviation], so a speck can
## never wander off the path however it was rolled.
##
## Two waves are used, one across the path and a slower one along it, at a
## deliberately non-integer frequency ratio so the pair never repeats in lockstep
## and the flow never reads as a mechanical wobble. Everything that varies per
## speck - phase, frequency, amplitude, speed - varies within a narrow band: the
## point is a shoal moving together, not a scatter.
##
## The heading is *steered* towards the target rather than recomputed, so a target
## that walks away is followed on a curve instead of being snapped to. The same
## easing is what keeps the motion continuous when the player changes direction.
##
## A speck may also be handed over with a hold: it lies exactly where it was
## picked up, drawn with its own floor colour and rotation - indistinguishable
## from blood on the ground - glows, and only then sets off. See
## [method add_speck].
##
## This node must be [member CanvasItem.top_level]: instance transforms are
## written in world space, so any transform inherited from the player would drag
## the whole flow around with them.

## Emitted once per frame in which specks reached the target, with how many did.
## The stream itself keeps no score - what a speck is worth is the caller's
## business.
signal specks_arrived(count: int)

## Most specks that can be in the flow at once. Callers ask for the free slot
## count before handing more over, so this is a hard ceiling on both the memory
## and the per-frame integration cost.
@export var capacity: int = 512:
	set(value):
		capacity = maxi(value, 1)
		if is_node_ready():
			_rebuild()

@export_group("Flow")
## Speed a speck sets off at, in pixels per second. Low: blood should be seen to
## be taken hold of rather than fired.
@export var initial_speed: float = 45.0
## How hard it is drawn in, in pixels per second squared. This is the pull.
@export var acceleration: float = 640.0
## Ceiling on the speed, so a speck crossing a long room arrives quickly without
## ever moving faster than the eye can follow it as a liquid.
@export var max_speed: float = 520.0
## Per-speck multiplier on both the acceleration and the ceiling, so specks that
## set off together do not arrive in one block. Deliberately a narrow band - a
## wide one is what makes a flow read as a scatter.
@export var speed_variation := Vector2(0.85, 1.18)
## How quickly the heading turns towards the target, per second. This is the
## movement smoothing: low values make a speck curve lazily after a target that
## walked away, high values make it correct almost immediately. It is never a
## snap at any value.
@export var steer_response: float = 8.0
## Total angle, in degrees, a speck may set off at either side of the straight
## line. Small on purpose: it stops the flow leaving in perfect parallel without
## making any speck take a route of its own.
@export var launch_spread_degrees: float = 14.0
## How close to the target a speck has to get to be collected, in pixels.
@export var collection_distance: float = 16.0
## Hard ceiling on how long a speck may stay in the flow. One somehow still out
## here is collected anyway, so blood can never be stranded mid-flight.
@export var max_flight_time: float = 3.0

@export_group("Wave")
## How far the speck swings to the side of the straight path, in pixels, at full
## amplitude. This is the whole of the "liquid" - keep it small relative to the
## distances involved.
@export var wave_strength: float = 11.0
## How fast that swing oscillates, in radians per second, rolled per speck. Slow
## and narrow: a wide band would put neighbouring specks badly out of step and
## turn the flow back into a swarm.
@export var wave_frequency := Vector2(1.5, 2.6)
## Per-speck multiplier on the amplitude, so the flow has thick and thin strands
## rather than one uniform ribbon.
@export var wave_variation := Vector2(0.7, 1.3)
## Hard ceiling on how far a speck may ever sit from its path, in pixels. X is
## across the path, Y along it. This is a guarantee rather than a tuning value:
## whatever the waves are set to, nothing can deviate further than this.
@export var max_deviation := Vector2(16.0, 9.0)
## How long the swing takes to reach full amplitude after launch, in seconds, so
## blood leaves the ground smoothly instead of jinking on its first frame.
@export var wave_ease_in: float = 0.18
## The second wave, along the path rather than across it, as a fraction of the
## first. It is what makes the flow surge and ease rather than travel at one
## rate.
@export_range(0.0, 1.0) var along_wave_strength: float = 0.45
## Frequency of that second wave relative to the first. Deliberately not a whole
## number - a whole one would make the two waves repeat together and the motion
## would read as a machine.
@export var along_wave_ratio: float = 0.63
## Distance from the target at which the swing is at full amplitude, in pixels.
## Inside it the wave tightens smoothly to nothing, so the closer blood gets the
## more focused and controlled it looks, and it arrives on the straight line.
@export var focus_distance: float = 90.0

@export_group("Blood piece")
## The artwork every piece in this stream is stamped with.
##
## Left empty, the stream borrows the arena's - see [method adopt_texture_from] -
## so all blood matches without a second copy of the art existing. Set it to
## dress this stream differently from the floor.
##
## Something must fill it one way or the other: a [MultiMesh] with no texture
## draws its quads bare, which reads on screen as plain squares.
@export var piece_texture: Texture2D:
	set(value):
		piece_texture = value
		if piece_texture != null:
			texture = piece_texture
## Multiplied into every piece's own colour rather than replacing it, so the
## variation [BloodField] rolls per speck survives. White leaves blood exactly the
## colour it was spilled; a darker or bluer tint shifts the whole stream without
## touching the field's palette.
@export var piece_tint := Color(1, 1, 1, 1)
## Multiplied into every piece's own size. 1 draws blood at exactly the size it
## was spilled at; this is the dial for making collected blood read bigger or
## smaller than the stains it came from, without touching [BloodField].
@export_range(0.05, 6.0) var piece_scale: float = 1.0

@export_group("Look")
## Distance from the target at which a speck starts shrinking, so it dwindles
## into the player instead of popping out of existence at full size.
@export var shrink_distance: float = 40.0
## Size at the moment of collection, as a fraction of the speck's own size.
@export_range(0.0, 1.0) var shrink_to: float = 0.25
## Turns each speck to face the way it is travelling. Blood specks are irregular
## ellipses, so this alone is most of what separates a flowing liquid from
## tumbling debris.
@export var align_to_flow: bool = true
## How quickly it turns to face that way, per second.
@export var align_response: float = 12.0
## How much a speck stretches along its travel at full speed, as a fraction. The
## across-path axis is pinched by half as much, so the speck is drawn out rather
## than simply enlarged.
@export_range(0.0, 2.0) var flow_stretch: float = 0.35

@export_group("Glow")
## Colour a speck is tinted towards as it is taken hold of. Multiplied into the
## speck's own colour rather than replacing it, so dark blood glows dark red and
## bright blood glows bright.
@export var glow_colour := Color(1.0, 0.28, 0.3)
## How much brighter it goes at the peak of that glow.
@export var glow_brightness: float = 2.6
## How long the glow takes to fade once the speck is moving, in seconds. The glow
## peaks exactly as the speck sets off, so this is the tail it carries away.
@export var glow_trail_time: float = 0.22

@export_group("Travel fade")
## What a speck's colour is multiplied down to by the end of its flight, so blood
## dims as it is drained on the way in.
@export_range(0.0, 1.0) var darken_to: float = 0.55
## How long that darkening takes, rolled per speck, so a flow arrives as a spread
## of shades rather than one uniform tone.
@export var darken_time := Vector2(0.4, 0.9)

var _multimesh: MultiMesh
var _positions := PackedVector2Array()
var _headings := PackedVector2Array()
var _scales := PackedVector2Array()
var _colours := PackedColorArray()
var _rotations := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _speed_scales := PackedFloat32Array()
var _ages := PackedFloat32Array()
var _flight_starts := PackedFloat32Array()
var _glow_times := PackedFloat32Array()
var _phases := PackedFloat32Array()
var _phases_along := PackedFloat32Array()
var _wave_rates := PackedFloat32Array()
var _wave_sizes := PackedFloat32Array()
var _launch_offsets := PackedFloat32Array()
var _fade_times := PackedFloat32Array()
var _count: int = 0
var _flowing: int = 0

var _target := Vector2.ZERO
var _has_target: bool = false


func _ready() -> void:
	top_level = true
	# Every instance transform here is written by hand each frame, in world
	# space, from `_process`. Physics interpolation is on project-wide, and left
	# on it would try to interpolate those writes from the previous physics tick
	# - which both warns and fights the motion this script is already smoothing.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if piece_texture != null:
		texture = piece_texture
	_rebuild()


## Where the specks are being drawn to, in global coordinates. Set every frame by
## the caller. Until it has been, nothing moves - specks simply hang where they
## were picked up rather than flying at the origin.
func set_target(global_point: Vector2) -> void:
	_target = global_point
	_has_target = true


## Borrows the field's speck texture, so blood in the flow is stamped with
## exactly the same art as blood on the floor and neither owns a second copy of
## it. A stream with its own [member piece_texture] is already dressed and keeps
## what it was given.
func adopt_texture_from(field: BloodField) -> void:
	if texture == null and field != null:
		texture = field.texture


## Every speck this node currently owns, including any still lying still.
func get_in_flight_count() -> int:
	return _count


## Only the specks actually moving - those past their hold. This is what anything
## reacting to blood being drawn in should follow, so a batch waiting on the
## ground is silent.
func get_flowing_count() -> int:
	return _flowing


## How many more specks may be handed over right now. Callers ask before they
## take blood from anywhere, so a speck is never lifted only to be dropped for
## want of a slot.
func get_free_slots() -> int:
	return maxi(capacity - _count, 0)


## Takes ownership of one speck. Returns false only when the stream is full.
##
## [param hold_time] leaves it lying exactly where it is, drawn with its own
## colour, rotation and size - which is to say indistinguishable from blood on
## the floor - before anything happens to it. [param glow_time] is the flare that
## follows, still without moving; the speck sets off the instant that flare
## peaks. Both default to 0, so a caller that wants blood to leave immediately
## simply does not pass them.
func add_speck(
	speck: BloodField.Speck, hold_time: float = 0.0, glow_time: float = 0.0
) -> bool:
	if _count >= capacity:
		return false

	var index := _count
	var glow := maxf(glow_time, 0.0)
	_positions[index] = speck.position
	# Left at zero and resolved on the first moving frame, from the target as it
	# is *then* - a speck held on the ground for a moment must set off towards
	# where the player has walked to, not towards where they were standing.
	_headings[index] = Vector2.ZERO
	_scales[index] = speck.scale
	_colours[index] = speck.colour
	_rotations[index] = speck.rotation
	_speeds[index] = initial_speed
	_speed_scales[index] = randf_range(speed_variation.x, speed_variation.y)
	_ages[index] = 0.0
	_flight_starts[index] = maxf(hold_time, 0.0) + glow
	_glow_times[index] = glow
	_phases[index] = randf() * TAU
	_phases_along[index] = randf() * TAU
	_wave_rates[index] = randf_range(wave_frequency.x, wave_frequency.y)
	_wave_sizes[index] = randf_range(wave_variation.x, wave_variation.y)
	# Signed per speck, so half the flow leans one way off the line and half the
	# other rather than the whole batch bending together.
	_launch_offsets[index] = deg_to_rad(
		randf_range(-launch_spread_degrees, launch_spread_degrees) * 0.5)
	_fade_times[index] = randf_range(darken_time.x, darken_time.y)

	_count += 1
	_multimesh.visible_instance_count = _count
	# Written immediately, so the speck is already on screen on the very frame it
	# is handed over rather than appearing one frame late.
	_write_instance(index, speck.position, speck.rotation, _piece_size(index),
		_tint(index, 0.0))
	return true


## Drops everything in the flow without counting it. Used when a stream is
## abandoned rather than finished.
func clear_all() -> void:
	_count = 0
	_flowing = 0
	if _multimesh != null:
		_multimesh.visible_instance_count = 0


func _process(delta: float) -> void:
	if _count <= 0 or delta <= 0.0:
		return

	var arrived := 0
	var flowing := 0
	# Walked backwards so the swap-removal can only ever move a speck into a slot
	# this pass has already integrated.
	var i := _count - 1
	while i >= 0:
		if _ages[i] >= _flight_starts[i]:
			flowing += 1
		if _advance(i, delta):
			_remove_at(i)
			arrived += 1
		i -= 1

	_flowing = maxi(flowing - arrived, 0)
	if arrived > 0:
		specks_arrived.emit(arrived)


## Integrates one speck. Returns true when it reached the target and should be
## counted.
func _advance(index: int, delta: float) -> bool:
	var age := _ages[index] + delta
	_ages[index] = age

	var flight_start := _flight_starts[index]
	if age < flight_start:
		# Lying still. Only the colour changes, so the speck reads as ordinary
		# blood on the ground right up until the glow takes it.
		_write_instance(index, _positions[index], _rotations[index],
			_piece_size(index), _tint(index, age))
		return false

	var flight_age := age - flight_start
	if flight_age >= max_flight_time:
		return true

	# Nothing to flow towards yet: the speck simply waits where it is rather than
	# setting off at the origin. Callers set a target every frame, so this only
	# ever covers the first frame of a stream's life.
	if not _has_target:
		return false

	var carrier := _positions[index]
	var to_target := _target - carrier
	var distance := to_target.length()
	if distance <= maxf(collection_distance, 0.0001):
		return true

	var desired := to_target / distance
	var heading := _headings[index]
	if heading.is_zero_approx():
		# First moving frame: set off along the line, leaning by this speck's own
		# small offset so the flow is not a perfectly parallel column.
		heading = desired.rotated(_launch_offsets[index])
	else:
		# Eased rather than recomputed, so a target that walked away is followed
		# on a curve. This is the whole of the movement smoothing.
		heading = heading.lerp(desired, 1.0 - exp(-steer_response * delta))
		heading = desired if heading.is_zero_approx() else heading.normalized()

	var scaling := _speed_scales[index]
	var speed := minf(
		_speeds[index] + acceleration * scaling * delta, max_speed * scaling)
	carrier += heading * speed * delta

	_positions[index] = carrier
	_headings[index] = heading
	_speeds[index] = speed

	_write_instance(index, _drawn_position(index, carrier, heading, flight_age, distance),
		_flow_rotation(index, heading, delta), _flow_scale(index, speed, distance),
		_tint(index, age))
	return false


## Where the speck is *drawn*, which is a small offset from where it is being
## carried.
##
## Keeping the two apart is what bounds the motion: the carrier only ever travels
## the straight line, and the waves are a displacement around it that is clamped
## outright. Nothing here can accumulate, so a speck cannot drift off course
## however long it has been travelling.
func _drawn_position(
	index: int, carrier: Vector2, heading: Vector2, flight_age: float, distance: float
) -> Vector2:
	# Full amplitude out in the open, tightening to nothing as the target is
	# approached - the closer blood gets, the more controlled it looks.
	var focus := clampf(distance / maxf(focus_distance, 0.0001), 0.0, 1.0)
	# Eased in from launch, so blood leaves the ground smoothly.
	var swell := clampf(flight_age / maxf(wave_ease_in, 0.0001), 0.0, 1.0)
	var amount := wave_strength * _wave_sizes[index] * focus * swell
	var rate := _wave_rates[index]

	var across := clampf(
		sin(flight_age * rate + _phases[index]) * amount,
		-max_deviation.x, max_deviation.x)
	var along := clampf(
		sin(flight_age * rate * along_wave_ratio + _phases_along[index])
			* amount * along_wave_strength,
		-max_deviation.y, max_deviation.y)

	return carrier + heading.orthogonal() * across + heading * along


## Turns the speck to face the way it is going. Eased, so it settles into the
## flow over the first moments rather than snapping square to it.
func _flow_rotation(index: int, heading: Vector2, delta: float) -> float:
	if not align_to_flow:
		return _rotations[index]
	var turned := lerp_angle(
		_rotations[index], heading.angle(), 1.0 - exp(-align_response * delta))
	_rotations[index] = turned
	return turned


## The size a piece is drawn at before anything about its flight is taken into
## account: what it was spilled at, scaled by the Inspector's [member piece_scale].
##
## Read every frame rather than baked in when the speck was handed over, so
## dragging the slider with the game running re-sizes blood already in the air.
func _piece_size(index: int) -> Vector2:
	return _scales[index] * piece_scale


## Drawn out along the travel and pinched across it as it speeds up, then
## dwindling into the target over the last stretch.
func _flow_scale(index: int, speed: float, distance: float) -> Vector2:
	var size := _piece_size(index)
	if max_speed > 0.0 and flow_stretch > 0.0:
		var fraction := clampf(speed / max_speed, 0.0, 1.0)
		size = Vector2(
			size.x * (1.0 + flow_stretch * fraction),
			size.y * (1.0 - flow_stretch * fraction * 0.5))
	var closeness := 1.0 if shrink_distance <= 0.0 \
		else clampf(distance / shrink_distance, 0.0, 1.0)
	return size * lerpf(shrink_to, 1.0, closeness)


## A speck's colour at [param age]: the glow that takes hold of it, then a steady
## drain towards [member darken_to] as it travels.
##
## [member _colours] always holds the speck's original floor colour and is never
## written over, so the tint is recomputed from the untouched original every
## frame - it cannot accumulate, and a speck cannot end up darker or brighter
## than the curve says however long it has been out. Alpha is left alone, so a
## darkening speck never dissolves into the floor behind it.
func _tint(index: int, age: float) -> Color:
	var base := _colours[index]
	var glow := _glow_amount(index, age)

	var flight_age := maxf(age - _flight_starts[index], 0.0)
	var fade_time := _fade_times[index]
	var drain := 1.0 if fade_time <= 0.0 else lerpf(
		1.0, darken_to, clampf(flight_age / fade_time, 0.0, 1.0))

	# Multiplied into the speck's own colour rather than replacing it, so dark
	# blood glows dark and bright blood glows bright.
	var mix := Color.WHITE
	var lit := drain
	if glow > 0.0:
		mix = Color.WHITE.lerp(glow_colour, glow)
		lit *= lerpf(1.0, glow_brightness, glow)

	# The Inspector's tint rides on the very end, over the glow and the drain
	# alike, so it shifts the whole stream without flattening either curve.
	return Color(
		base.r * mix.r * lit * piece_tint.r,
		base.g * mix.g * lit * piece_tint.g,
		base.b * mix.b * lit * piece_tint.b,
		base.a * piece_tint.a)


## The glow curve: up over the speck's glow window while it is still lying there,
## peaking at exactly the moment it sets off, then away over
## [member glow_trail_time] as it travels. One curve across the boundary, so the
## flare and the launch are the same event rather than two.
func _glow_amount(index: int, age: float) -> float:
	var glow_time := _glow_times[index]
	if glow_time <= 0.0:
		return 0.0

	var sets_off := _flight_starts[index]
	var begins := sets_off - glow_time
	if age <= begins:
		return 0.0
	if age < sets_off:
		return smoothstep(0.0, 1.0, (age - begins) / glow_time)

	var trail := maxf(glow_trail_time, 0.0001)
	return 1.0 - smoothstep(0.0, 1.0, (age - sets_off) / trail)


func _write_instance(
	index: int, at: Vector2, spin: float, size: Vector2, colour: Color
) -> void:
	_multimesh.set_instance_transform_2d(index, Transform2D(spin, size, 0.0, at))
	_multimesh.set_instance_color(index, colour)


## Swap-removal, matching [BloodField]: the last live speck fills the hole, so
## collecting one is O(1) and no other speck's index moves.
func _remove_at(index: int) -> void:
	var last := _count - 1
	if index != last:
		_positions[index] = _positions[last]
		_headings[index] = _headings[last]
		_scales[index] = _scales[last]
		_colours[index] = _colours[last]
		_rotations[index] = _rotations[last]
		_speeds[index] = _speeds[last]
		_speed_scales[index] = _speed_scales[last]
		_ages[index] = _ages[last]
		_flight_starts[index] = _flight_starts[last]
		_glow_times[index] = _glow_times[last]
		_phases[index] = _phases[last]
		_phases_along[index] = _phases_along[last]
		_wave_rates[index] = _wave_rates[last]
		_wave_sizes[index] = _wave_sizes[last]
		_launch_offsets[index] = _launch_offsets[last]
		_fade_times[index] = _fade_times[last]
		_multimesh.set_instance_transform_2d(index, _multimesh.get_instance_transform_2d(last))
		_multimesh.set_instance_color(index, _multimesh.get_instance_color(last))

	_count = last
	_multimesh.visible_instance_count = _count


func _rebuild() -> void:
	_positions.resize(capacity)
	_headings.resize(capacity)
	_scales.resize(capacity)
	_colours.resize(capacity)
	_rotations.resize(capacity)
	_speeds.resize(capacity)
	_speed_scales.resize(capacity)
	_ages.resize(capacity)
	_flight_starts.resize(capacity)
	_glow_times.resize(capacity)
	_phases.resize(capacity)
	_phases_along.resize(capacity)
	_wave_rates.resize(capacity)
	_wave_sizes.resize(capacity)
	_launch_offsets.resize(capacity)
	_fade_times.resize(capacity)
	_count = mini(_count, capacity)
	_flowing = mini(_flowing, _count)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = capacity
	_multimesh.visible_instance_count = _count
	multimesh = _multimesh
