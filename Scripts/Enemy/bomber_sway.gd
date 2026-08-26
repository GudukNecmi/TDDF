class_name BomberSway
extends Node
## The bomber's approach: it comes at the player, but it never comes at them in a
## straight line, and it hops the whole way in.
##
## [b]It is a steering component, not a second mover.[/b] [Enemy] walks, steers
## round the crowd, takes knockback and obeys the world's slow motion exactly as
## it does for every other enemy; this is handed the direction it was about to
## walk in through [member Enemy.steering_path] and hands back a bent one. Switch
## it off and the bomber is an ordinary enemy walking straight at the player.
##
## [b]The sway is measured off the line to the player, not off the world.[/b] The
## direction to the player is the forward axis and the drift is perpendicular to
## it, so the bomber slides to one side of that line and then to the other while
## still closing - which is why it never reads as a left/right pattern or as a
## clean orbit. A player who walks round it changes the axis and the wobble comes
## with them.
##
## Nothing here is rolled per frame. The drift is a sine whose rate and depth are
## dragged about by two slow [FastNoiseLite] fields, the same trick [Torch] uses
## for a flame that never repeats: the motion stays smooth and readable frame to
## frame while never settling into a rhythm the player can lead.
##
## [b]The hop and the sway share a clock.[/b] One hop is one half-swing - see
## [member hop_follows_sway] - so the thing takes off at one side of its line and
## lands at the other, and the bounce and the wobble read as one motion rather than
## as two that happen to be running at the same time.
##
## [b]The head is carried rather than welded.[/b] Everything the body does reaches it
## at a fraction of its strength and a fraction of a beat late - see
## [member head_hop_follow] and [member head_lag] - which is what stops a bomber
## bouncing as one rigid object. Only the pivot's position and the head sprite's
## rotation are written, and neither is owned by anything else on those nodes, so
## aiming, the flip, the soft follow and the idle squash are all untouched.

## Node lifted and tilted by the hop - the artwork, not the body. Only its
## [member Node2D.position] and [member Node2D.rotation] are written, and the
## shared idle animation drives [code]scale[/code], so the two never fight.
@export var visual_path: NodePath = ^"../Visual"
## The enemy this belongs to. Its [method Enemy.is_charging] is what ends the
## wobble: once the bomber has committed it runs straight, and the hop settles.
@export var enemy_path: NodePath = ^".."

@export_group("Sway")
## How far off the line to the player it drifts, as a fraction of its forward
## pull. 0 walks straight in; 1 spends as much effort sideways as forwards.
@export_range(0.0, 3.0) var sway_amount: float = 0.85
## Full left-right cycles per second at the middle of its wandering.
@export var sway_frequency: float = 0.55
## How much the noise drags the rate about, as a fraction. 0 is a metronome.
@export_range(0.0, 1.0) var sway_frequency_jitter: float = 0.45
## How much the noise drags the depth about, as a fraction, so some swings are
## barely there and the next one is a lurch.
@export_range(0.0, 1.0) var sway_amount_jitter: float = 0.55
## How much of its effort goes towards the player. Lower closes the distance more
## slowly and makes the wandering read as wider.
@export_range(0.0, 4.0) var forward_approach_strength: float = 1.0

@export_group("Hop")
## Whether one hop is one half of one sway, so the thing leaves the ground on one
## side of its line and lands on the other.
##
## [b]On, and this is what makes it read as a bounce rather than as a wobble with a
## bob on top.[/b] With the two on separate clocks - which is what this was - the
## lift and the drift drift in and out of phase, so about half the time the bomber
## is at the top of a hop while sliding straight and at the bottom of one while
## turning, and neither motion reads as causing the other. Tied together it takes
## off as the drift crosses its line, is airborne across the middle of the swing and
## lands at the far side of it - and the next hop goes back the other way, which is
## exactly "upon landing, bounce again toward the opposite side".
##
## Off falls back to [member hop_duration] and a clock of its own.
@export var hop_follows_sway: bool = true
## How high the artwork leaves the ground, in pixels. 0 slides instead.
@export var hop_height: float = 16.0
## Seconds one hop takes, from leaving the ground to landing. Only used when
## [member hop_follows_sway] is off - otherwise a hop is half a sway and how long it
## takes is [member sway_frequency]'s to decide.
@export var hop_duration: float = 0.42
## How much the hop's length varies from one to the next, as a fraction. Rolled as
## each hop lands, not per frame.
@export_range(0.0, 0.9) var hop_duration_variation: float = 0.25
## How far the body tips into the drift, in degrees.
@export var rotation_amount: float = 14.0
## How far the body rolls over the course of one hop, in degrees, on top of the tip
## above.
##
## [b]This is the rotation that belongs to the hop rather than to the lean.[/b] It
## is strongest in the middle of a hop, where the thing is highest and travelling
## sideways fastest, and unwinds to nothing as it lands - and because consecutive
## hops go to opposite sides it rolls one way and then the other. 0 leans without
## turning, which is what it did before.
@export var hop_rotation_degrees: float = 11.0
## How quickly the tilt follows the drift. Lower is heavier and lags further.
@export var rotation_follow: float = 7.0

@export_group("Head")
## The aim pivot the head hangs off. Only its [member Node2D.position] is written
## here, which is the one thing [LookAtTarget] never touches - that writes rotation
## and the flip - so the head still aims exactly as it did while being carried by
## the hop.
##
## Left unresolved the head simply does not follow, which is a bomber whose head is
## rigid rather than a broken one.
@export var head_path: NodePath = ^"../HeadAim"
## The head artwork itself, leaned by the body's own lean. Only its
## [member Node2D.rotation] is written, which [SoftFollow] on the same node never
## touches - that writes position - so the two do not fight.
@export var head_visual_path: NodePath = ^"../HeadAim/Head"
## How much of the body's hop the head takes, as a fraction of it.
##
## [b]Well under 1 on purpose.[/b] A head that rises exactly as far as the shoulders
## it is sitting on is welded to them, and reads as one rigid object being moved
## about. Taking a part of it and arriving late is what makes it read as a head on a
## neck. 0 leaves it where the scene put it.
@export_range(0.0, 1.0, 0.01) var head_hop_follow: float = 0.45
## How much of the body's sideways drift the head takes, in pixels at full drift.
## A few, so the head trails the lurch rather than swinging with it.
@export var head_sway_pixels: float = 5.0
## How much of the body's lean and roll the head takes, as a fraction.
@export_range(0.0, 1.0, 0.01) var head_lean_follow: float = 0.4
## How quickly the head catches up with where the body has put it, per second.
##
## [b]This is the whole of "flexible rather than rigid".[/b] The offset the body asks
## for is arrived at rather than snapped to, so the head is always a fraction of a
## beat behind the shoulders: it is still coming up as the body starts down and still
## going over as the body comes back. Higher is stiffer - very high is welded again -
## and lower is looser, to the point of sloshing.
@export var head_lag: float = 11.0

@export_group("Settling")
## How quickly the hop and the tilt come back to rest once the bomber has
## committed and is running straight. Higher snaps sooner.
@export var settle_speed: float = 9.0

@onready var _visual: Node2D = get_node_or_null(visual_path) as Node2D
@onready var _enemy: Node = get_node_or_null(enemy_path)

var _phase: float = 0.0
var _hop_time: float = 0.0
var _hop_length: float = 0.0
var _tilt: float = 0.0
var _rest: Vector2 = Vector2.ZERO
var _rest_taken: bool = false
var _drift: float = 0.0
## How far off the ground the artwork is right now, 0 to 1, so the roll can be at its
## strongest in the air and at nothing on the ground.
var _airborne: float = 0.0
var _head_rest := Vector2.ZERO
var _head_rest_taken: bool = false
## Where the head has actually got to, as against where the body is asking it to be.
## The lag lives in the gap between the two.
var _head_offset := Vector2.ZERO
var _head_lean: float = 0.0

var _rate_noise := FastNoiseLite.new()
var _depth_noise := FastNoiseLite.new()
var _noise_time: float = 0.0


func _ready() -> void:
	# Its own seed and its own starting point in the wave, so a group of bombers
	# arriving together never wobbles in unison - which would read as one object.
	_rate_noise.seed = randi()
	_depth_noise.seed = randi()
	_rate_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_depth_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_time = randf() * 1000.0
	_phase = randf() * TAU
	_hop_length = _roll_hop_length()
	_hop_time = randf() * _hop_length

	if _visual != null:
		_rest = _visual.position
		_rest_taken = true


## Bends [param chase] into the wobble and returns it. Called once a physics frame
## by [Enemy]; see [member Enemy.steering_path].
##
## A bomber that has committed gets its direction handed straight back, which is
## the whole of "stop the normal swaying behaviour when it charges" - the charge
## itself is [method Enemy.begin_charge] and belongs to [BomberAttack].
func steer(chase: Vector2, delta: float) -> Vector2:
	if _is_committed() or chase.is_zero_approx():
		_settle(delta)
		return chase

	_advance(delta)

	# The line to the player is the forward axis and the drift is square to it, so
	# the sideways motion is always relative to that line and never to the world.
	var forward := chase.normalized()
	var sideways := forward.orthogonal() * _drift
	var steer := forward * forward_approach_strength + sideways
	return chase if steer.is_zero_approx() else steer.normalized()


## How far off the line the bomber currently is, -1 to 1 before the depth is
## applied. Public so the hop, a shadow or a test can read the same number the
## walk is using rather than working it out again.
func get_drift() -> float:
	return _drift


## Advances the wobble by one frame and moves the artwork with it.
##
## Everything runs on the world's own slowed clock, so a bomber wobbling through
## a slowed moment hops at the speed of the scene around it rather than carrying
## on at full pace.
func _advance(delta: float) -> void:
	var step := delta * WorldSlowdown.get_multiplier(self)
	_noise_time += step

	var rate := sway_frequency * (1.0 + _signed_noise(_rate_noise, _noise_time * 0.35) \
		* sway_frequency_jitter)
	_phase += TAU * maxf(rate, 0.0) * step

	var depth := sway_amount * (1.0 + _signed_noise(_depth_noise, _noise_time * 0.5) \
		* sway_amount_jitter)
	_drift = sin(_phase) * maxf(depth, 0.0)

	_hop(step)
	_tip(step)
	_carry_the_head(step)


## One hop: up, over, down, and the next one to the other side.
##
## Tied to the sway - see [member hop_follows_sway] - the lift is the cosine of the
## same phase the drift is the sine of. It is therefore at nothing exactly where the
## drift is at its extremes, which are the two moments the thing is standing at one
## side of its line, and at its highest halfway between them where the drift is
## crossing that line at speed. One hop is one half-swing, it lands on the opposite
## side from the one it left, and the two can never fall out of step.
func _hop(step: float) -> void:
	var node := _resolve_visual()
	if node == null:
		return
	if hop_height <= 0.0:
		_airborne = 0.0
		node.position = _rest
		return

	if hop_follows_sway:
		_airborne = absf(cos(_phase))
	else:
		if hop_duration <= 0.0:
			_airborne = 0.0
			node.position = _rest
			return
		_hop_time += step
		while _hop_time >= _hop_length:
			_hop_time -= _hop_length
			_hop_length = _roll_hop_length()
		# The absolute of a sine, so the artwork rises off the ground and comes back
		# down to it rather than sinking below it every other beat - the same shape the
		# enemy's own standing-by hop uses.
		_airborne = absf(sin(_hop_time / _hop_length * PI))

	node.position = _rest - Vector2(0.0, _airborne * hop_height)


## The body tips into whichever way it is drifting, following rather than
## snapping, so a lurch to one side arrives as a lean and unwinds behind it - and on
## top of that lean it rolls through the hop itself.
##
## The roll takes its direction from which way the drift is travelling rather than
## from where the drift has got to, which is why it comes back the other way on the
## next hop: the cosine of the phase is positive across the swing one way and
## negative across the swing back. It is scaled by how far off the ground the artwork
## is, so it is at its strongest in the air and gone by the landing.
func _tip(step: float) -> void:
	var node := _resolve_visual()
	if node == null:
		return

	var wanted := deg_to_rad(rotation_amount) * clampf(_drift, -1.0, 1.0)
	_tilt = lerpf(_tilt, wanted, 1.0 - exp(-maxf(rotation_follow, 0.0) * step))
	node.rotation = _tilt + deg_to_rad(hop_rotation_degrees) * cos(_phase) * _airborne


## Back to standing upright on the ground. Used the moment the bomber commits, so
## the charge is visibly a different thing from the approach.
func _settle(delta: float) -> void:
	var node := _resolve_visual()
	if node == null:
		return

	var t := 1.0 - exp(-maxf(settle_speed, 0.0) * delta * WorldSlowdown.get_multiplier(self))
	_tilt = lerpf(_tilt, 0.0, t)
	_airborne = lerpf(_airborne, 0.0, t)
	node.rotation = _tilt
	node.position = node.position.lerp(_rest, t)
	_drift = lerpf(_drift, 0.0, t)
	_settle_the_head(t)


## The head carried by the body: a damped, smaller copy of the hop, the drift and the
## lean, always arriving slightly after the shoulders it belongs to.
##
## [b]It is driven from the numbers the body is already using[/b] - the same
## [member _airborne], [member _drift] and [member _tilt] the artwork is being moved
## by - rather than by watching the body and working them out again, so the head can
## never disagree with the body about what it is doing.
##
## [b]It writes only what nothing else owns.[/b] The pivot's position, which
## [LookAtTarget] never touches, and the head sprite's rotation, which [SoftFollow]
## never touches - so aiming, the flip, the soft follow and the idle's squash all
## carry on underneath this exactly as they did.
func _carry_the_head(step: float) -> void:
	var pivot := _resolve_head()
	if pivot == null:
		return

	var wanted := Vector2(
		_drift * head_sway_pixels,
		-_airborne * hop_height * head_hop_follow)
	var catch_up := 1.0 - exp(-maxf(head_lag, 0.0) * step)
	_head_offset = _head_offset.lerp(wanted, catch_up)
	pivot.position = _head_rest + _head_offset

	var art := _resolve_head_visual()
	if art == null:
		return
	# Taken off the artwork's own turn rather than recomputed, so the lean and the roll
	# through the hop both reach the head at one fraction of their strength.
	var body := _visual.rotation if _visual != null and is_instance_valid(_visual) else _tilt
	_head_lean = lerpf(_head_lean, body * head_lean_follow, catch_up)
	art.rotation = _head_lean


## The head put back where the scene had it, at the same pace everything else settles
## at - so a bomber standing still, or one that has committed and is running straight,
## has an ordinary head that only aims.
func _settle_the_head(t: float) -> void:
	var pivot := _resolve_head()
	if pivot != null:
		_head_offset = _head_offset.lerp(Vector2.ZERO, t)
		pivot.position = _head_rest + _head_offset

	var art := _resolve_head_visual()
	if art != null:
		_head_lean = lerpf(_head_lean, 0.0, t)
		art.rotation = _head_lean


## The aim pivot, with its resting place taken the first time it is found - so a head
## that has been popped off and reparented simply stops being carried rather than
## being written to wherever it has ended up.
func _resolve_head() -> Node2D:
	var pivot := get_node_or_null(head_path) as Node2D
	if pivot != null and not _head_rest_taken:
		_head_rest = pivot.position
		_head_rest_taken = true
	return pivot


func _resolve_head_visual() -> Node2D:
	return get_node_or_null(head_visual_path) as Node2D


func _roll_hop_length() -> float:
	var spread := clampf(hop_duration_variation, 0.0, 0.9)
	return maxf(hop_duration * (1.0 + randf_range(-spread, spread)), 0.05)


func _is_committed() -> bool:
	return _enemy != null and _enemy.has_method(&"is_charging") and _enemy.is_charging()


func _resolve_visual() -> Node2D:
	if _visual != null and is_instance_valid(_visual):
		return _visual

	_visual = get_node_or_null(visual_path) as Node2D
	if _visual != null and not _rest_taken:
		_rest = _visual.position
		_rest_taken = true
	return _visual


## [method FastNoiseLite.get_noise_1d] returns roughly -1..1 already; it is
## clamped rather than trusted so a tuning value can never be scaled past its
## stated range.
func _signed_noise(noise: FastNoiseLite, at: float) -> float:
	return clampf(noise.get_noise_1d(at), -1.0, 1.0)
