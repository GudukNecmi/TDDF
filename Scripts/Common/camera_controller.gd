class_name CameraController
extends Camera2D
## Central place for camera feedback. Other systems ask for effects here rather
## than touching the camera themselves.
##
## Everything is applied on top of the camera's resting transform:
##   * shake writes [member Camera2D.offset], never `position`, so following,
##     smoothing and the limits keep working untouched
##   * rotation and zoom are stored as offsets from the base captured on ready
## Every effect is driven back to the base, and an idle settle pass runs on top
## of that, so the camera can never be left shaken, rotated or zoomed.
##
## [b]Channels.[/b] Rotation and zoom are not one value each but a set of named
## layers that are summed. Every caller names the channel it is writing to -
## [code]&"damage"[/code] for the hit reaction, [code]&"weapon"[/code] for the
## shotgun - and retriggering only ever restarts its own channel. That is what
## stops two systems fighting over the camera: a shot fired during the hit zoom
## adds its punch on top of that zoom instead of replacing it, and the hit zoom
## still runs its full hold and its full return.
##
## Where they disagree, the louder one wins by degree rather than outright: while
## a higher-priority channel is running, lower-priority ones are scaled by
## [member low_priority_scale], so the shot is still felt but the damage reaction
## is what the frame is about. Nothing is ever switched off.
##
## [b]Following something other than the player.[/b] The camera hangs off the
## player and rests at its authored [member Node2D.position], which is what
## "normal gameplay view" means. [method follow] hands it something else to centre
## on for a while - a coin in mid-air is the one today - and [method release_follow]
## gives it back. That is a *position* offset written on top of the resting spot,
## so the zoom channels, the shake and the limits all keep working through it and
## the camera can never be left stranded: releasing eases it home and nothing else
## touches `position`.
##
## [b]The weapon's own view.[/b] A weapon may lean the camera and pull it in - see
## [WeaponCamera] - through [method set_weapon_offset] and
## [method set_weapon_zoom]. That is the quietest layer here and the only one that
## can be silenced: while something louder owns the view - a lock-on for a finale,
## a boss, a coin in flight - the weapon's contribution is eased to nothing, and
## eased back in once the view is handed back. A cinematic is therefore never
## fought, the weapon's framing returns by itself afterwards, and nothing has to
## remember to switch it off.
##
## The four layers, loudest first:
##   [codeblock]
##   1  cinematic      follow() / release_follow()
##   2  temporary      shake, rotation and zoom impulses
##   3  weapon         set_weapon_offset() / set_weapon_zoom()
##   4  player-follow   the camera's own resting transform
##   [/codeblock]

const GROUP := &"camera_controller"

## Channel a caller that names none writes to.
const DEFAULT_CHANNEL := &"default"

## How sharply a shake dies away. Higher decays faster at the end.
@export var shake_falloff: float = 3.0
## Safety net pulling any leftover rotation or zoom back to the base. This is the
## recovery speed every effect settles home at once its own steps have run out.
@export var settle_speed: float = 14.0
## Time an impulse is given to come home when its steps do not end at zero.
@export var return_time: float = 0.18

@export_group("Resting zoom")
## Multiplier on the camera's authored zoom, with every impulse still riding on
## top of it. This is the knob a *place* turns - the base is closer in than the
## arena, a death crawls in on the body - as opposed to the impulses, which are
## events and always come home to whatever this is set to.
##
## Above 1 is closer: 1.3 is 30% closer than the authored zoom.
@export var zoom_multiplier: float = 1.0
## How quickly the camera crosses to a new multiplier. Low on purpose - this is a
## view settling into a place, not a punch.
@export var zoom_multiplier_speed: float = 3.0

@export_group("Layering")
## How much of a lower-priority channel still shows through while a
## higher-priority one is running. 1 lets everything through at full strength, 0
## mutes the quieter channels entirely for as long as the loud one lasts.
##
## The point of the middle ground is that neither effect is ever cancelled: the
## shot is still felt during a hit reaction, just not at the cost of it.
@export_range(0.0, 1.0) var low_priority_scale: float = 0.55
## Ceiling on the summed extra zoom, as a fraction, so several channels punching
## at once can never drive the view somewhere unreadable.
@export var max_zoom_offset: float = 1.2
## Ceiling on the summed rotation, in degrees.
@export var max_rotation_degrees: float = 20.0

@export_group("Target follow")
## How quickly the camera crosses onto a subject handed to [method follow], in the
## usual exponential-smoothing units. Higher locks on harder; this is the default
## a caller that names no speed of its own gets.
@export var follow_lock_speed: float = 11.0
## How quickly it comes back to the player once it is released. This is the
## "return timing" of every lock-on: lower drifts home, higher snaps back.
@export var follow_release_speed: float = 9.0
## Whether the camera's own [member Camera2D.position_smoothing_enabled] is
## switched off while it is locked on.
##
## On by default, and the reason is that two smoothings in series read as lag
## rather than as weight: the follow below is already eased, and leaving the
## camera's built-in smoothing on top of it means a fast-moving subject is never
## actually centred. It is put back exactly as it was on release.
@export var follow_disables_smoothing: bool = true

@export_group("Weapon layer")
## How quickly the weapon's own offset and zoom are silenced when something louder
## takes the view, and brought back when it is given up, in the usual
## exponential-smoothing units.
##
## Low on purpose: a weapon's framing appearing or disappearing should never be a
## cut, and a boss introduction taking the screen must not be preceded by a lurch.
@export var weapon_layer_speed: float = 4.0
## Whether a lock-on silences the weapon layer at all. Off leaves the weapon's lean
## and zoom running through cinematics, for measuring what they do.
@export var cinematic_silences_weapon: bool = true

var _base_zoom: Vector2 = Vector2.ONE
var _zoom_multiplier: float = 1.0
var _base_rotation: float = 0.0

var _shake_strength: float = 0.0
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

var _rotation_layers: Dictionary = {}
var _zoom_layers: Dictionary = {}
var _rotation_offset: float = 0.0
var _zoom_offset: float = 0.0

## The camera's authored resting spot on the player, captured on ready. Every
## follow is an offset from this, and releasing drives the offset back to nothing.
var _rest_position: Vector2 = Vector2.ZERO
var _follow_subject: Node2D
var _follow_speed: float = 0.0
var _follow_offset: Vector2 = Vector2.ZERO
var _smoothing_was_enabled: bool = false

## What the weapon in the player's hands is asking for, and how much of it is
## currently being let through. The scale is what makes this the layer a cinematic
## can silence.
var _weapon_offset: Vector2 = Vector2.ZERO
var _weapon_zoom: float = 1.0
var _weapon_scale: float = 1.0


## One value animated through a list of steps. Each step is
## Vector2(target_value, seconds_to_reach_it).
class Impulse:
	var steps: Array[Vector2] = []
	var index: int = 0
	var elapsed: float = 0.0
	var from: float = 0.0
	var value: float = 0.0
	var active: bool = false

	## Always restarts from where the value is right now, so retriggering
	## blends instead of stacking.
	func start(new_steps: Array[Vector2], current: float) -> void:
		steps = new_steps
		index = 0
		elapsed = 0.0
		from = current
		value = current
		active = not steps.is_empty()

	func advance(delta: float) -> float:
		if not active:
			return value

		elapsed += delta
		var step := steps[index]
		var duration := maxf(step.y, 0.0001)
		var t := clampf(elapsed / duration, 0.0, 1.0)
		value = lerpf(from, step.x, smoothstep(0.0, 1.0, t))

		if t >= 1.0:
			value = step.x
			from = step.x
			elapsed = 0.0
			index += 1
			if index >= steps.size():
				active = false
		return value


## One named channel: its own impulse, and how loudly it speaks relative to the
## others running at the same time.
class Layer:
	var impulse := Impulse.new()
	var priority: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	_base_zoom = zoom
	_base_rotation = rotation
	_rest_position = position
	_zoom_multiplier = maxf(zoom_multiplier, 0.01)


## Convenience lookup, so any system can reach the camera without being wired
## to it: `CameraController.get_active(self)`.
static func get_active(from_node: Node) -> CameraController:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as CameraController


## The patch of world this camera is currently showing, in world pixels.
##
## [b]The one answer to "is that on screen".[/b] Anything placing something the
## player has to be able to see - a crate dropped into a fight, a marker, a piece of
## debris thrown in from off the edge - reads it here rather than working the zoom
## and the viewport out again, so a change to either is felt everywhere at once.
##
## Measured from where the camera is actually looking rather than from its node
## position, so a shake, a drag or a smoothed follow does not make it lie.
func get_visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size
	var shown := Vector2(size.x / maxf(zoom.x, 0.001), size.y / maxf(zoom.y, 0.001))
	return Rect2(get_screen_center_position() - shown * 0.5, shown)


## A knock that decays to nothing. Retriggering keeps the stronger of the two
## rather than adding, so rapid fire cannot build up an endless shake - and,
## because it is a max rather than an overwrite, a light shake arriving during a
## heavy one can never cut the heavy one short either.
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time_left = maxf(_shake_time_left, duration)


## Steps are Vector2(target_degrees, seconds). A final return to zero is added
## automatically, so the camera always ends level.
##
## [param channel] names the layer this belongs to and [param priority] says how
## loudly it speaks against the others. Two callers on different channels are
## summed; the same caller retriggering restarts only its own channel.
func rotation_impulse(
	steps: Array[Vector2],
	channel: StringName = DEFAULT_CHANNEL,
	priority: int = 0
) -> void:
	_start_layer(_rotation_layers, channel, priority, steps)


## Steps are Vector2(extra_zoom_fraction, seconds); 0.05 is a 5% zoom in.
func zoom_impulse(
	steps: Array[Vector2],
	channel: StringName = DEFAULT_CHANNEL,
	priority: int = 0
) -> void:
	_start_layer(_zoom_layers, channel, priority, steps)


## Out and straight back - the common case.
func rotation_kick(
	degrees: float,
	out_time: float,
	back_time: float,
	channel: StringName = DEFAULT_CHANNEL,
	priority: int = 0
) -> void:
	rotation_impulse(
		[Vector2(degrees, out_time), Vector2(0.0, back_time)], channel, priority)


func zoom_kick(
	amount: float,
	out_time: float,
	back_time: float,
	channel: StringName = DEFAULT_CHANNEL,
	priority: int = 0
) -> void:
	zoom_impulse(
		[Vector2(amount, out_time), Vector2(0.0, back_time)], channel, priority)


## Sets where the camera rests. It eases there over
## [member zoom_multiplier_speed] rather than cutting, and impulses keep working
## on top of it throughout, so a place can change the view without anything that
## punches the camera having to know it happened.
##
## [param immediate] skips the ease, for a transition that has already hidden the
## cut - an arrival, a scene rebuild.
func set_zoom_multiplier(value: float, immediate: bool = false) -> void:
	zoom_multiplier = maxf(value, 0.01)
	if immediate:
		_zoom_multiplier = zoom_multiplier


func get_zoom_multiplier() -> float:
	return zoom_multiplier


## How large the visible rectangle would be, in world pixels, at
## [param multiplier] times the authored zoom.
##
## [b]Asked of the camera rather than worked out by the caller[/b] because the
## authored zoom is captured here on ready and the live [member Camera2D.zoom] is
## whatever the impulses and the easing have made of it this frame - so a caller
## measuring the screen off `zoom` would get an answer that changes while it is
## being used. This is the size a *place* can rely on, which is what a fixed-screen
## arena has to be built from. See [BossArena].
func get_view_size_at(multiplier: float) -> Vector2:
	var factor := _base_zoom * maxf(multiplier, 0.01)
	return get_viewport_rect().size / Vector2(maxf(factor.x, 0.01), maxf(factor.y, 0.01))


## Centres the camera on [param subject] until it is released.
##
## [param speed] overrides [member follow_lock_speed] for this lock-on, so an
## effect that wants a harder or a softer grab than the camera's default can say
## so without the camera being retuned for everything else. Below 0 uses the
## default.
##
## Handing it a subject while it is already following another simply crosses to
## the new one - there is no stack, because two things cannot both be the middle
## of the screen. A subject that leaves the tree releases the camera by itself, so
## nothing that locks on has to remember to let go if its subject dies first.
func follow(subject: Node2D, speed: float = -1.0) -> void:
	if subject == null or not is_instance_valid(subject):
		release_follow(speed)
		return

	if _follow_subject == null and follow_disables_smoothing:
		# Captured on the way in rather than assumed, so a camera authored without
		# smoothing is handed back without it.
		_smoothing_was_enabled = position_smoothing_enabled
		position_smoothing_enabled = false

	_follow_subject = subject
	_follow_speed = speed if speed > 0.0 else follow_lock_speed


## Gives the view back to the player. The camera eases home from wherever it had
## got to rather than cutting, so a release lands as a move back rather than as a
## jump - [param speed] below 0 uses [member follow_release_speed].
func release_follow(speed: float = -1.0) -> void:
	if _follow_subject != null and follow_disables_smoothing:
		position_smoothing_enabled = _smoothing_was_enabled

	_follow_subject = null
	_follow_speed = speed if speed > 0.0 else follow_release_speed


## What the camera is centred on, or null when it is resting on the player. Read
## by anything that needs to know whether its own lock-on is still the one in
## force.
func get_follow_subject() -> Node2D:
	return _follow_subject


## Leans the camera away from the player by [param lean] world pixels, for as
## long as the weapon in their hands wants it.
##
## [b]Held rather than impulsed, and it is the caller's to keep current.[/b] A lean
## that follows the cursor changes every frame, so this is written continuously by
## whoever owns it and is never animated here. Handing it
## [constant Vector2.ZERO] - which is what a weapon does on its way out - puts the
## camera straight back on the player.
##
## It is applied on top of the resting spot exactly as a lock-on is, so the limits,
## the smoothing and every impulse keep working through it untouched.
func set_weapon_offset(lean: Vector2) -> void:
	_weapon_offset = lean


## Pulls the view in - or lets it out - by [param multiplier] for as long as the
## weapon wants it. Above 1 is closer; 1 is the view the place already had.
##
## [b]It multiplies the resting zoom rather than replacing it.[/b] Where the camera
## rests is the *place's* business - see [member zoom_multiplier] - so a weapon that
## frames 15% closer stays 15% closer inside a boss arena that has already pulled
## the view out, instead of the two overwriting one another.
func set_weapon_zoom(multiplier: float) -> void:
	_weapon_zoom = maxf(multiplier, 0.01)


## Puts the weapon layer back to nothing. What a weapon calls as it leaves the
## player's hands, so a weapon that is put away can never leave the camera leaning.
func clear_weapon_modifiers() -> void:
	_weapon_offset = Vector2.ZERO
	_weapon_zoom = 1.0


## How much of the weapon layer is currently getting through: 1 is all of it, 0 is
## a cinematic holding the view. For a readout, and for a test.
func get_weapon_layer_scale() -> float:
	return _weapon_scale


func _physics_process(delta: float) -> void:
	_advance_weapon_layer(delta)
	_advance_follow(delta)
	_advance_shake(delta)
	_rotation_offset = clampf(
		_advance_layers(_rotation_layers, delta),
		-absf(max_rotation_degrees),
		absf(max_rotation_degrees))
	_zoom_offset = clampf(
		_advance_layers(_zoom_layers, delta),
		-absf(max_zoom_offset),
		absf(max_zoom_offset))
	_zoom_multiplier = lerpf(
		_zoom_multiplier,
		maxf(zoom_multiplier, 0.01),
		1.0 - exp(-maxf(zoom_multiplier_speed, 0.01) * delta))

	offset = _shake_offset
	rotation = _base_rotation + deg_to_rad(_rotation_offset)
	# The weapon's zoom rides on the resting one and is faded in and out by its own
	# scale, so a cinematic taking the view returns the framing to whatever the
	# place asked for rather than to 1.
	zoom = _base_zoom \
		* _zoom_multiplier \
		* lerpf(1.0, _weapon_zoom, _weapon_scale) \
		* (1.0 + _zoom_offset)
	# Written here rather than in the follow, so the weapon's lean is applied on
	# every frame including the ones where nothing is being followed.
	position = _rest_position + _follow_offset + _weapon_offset * _weapon_scale


## Eases the weapon layer down while something louder owns the view and back up
## once it is released. One value scales both the lean and the zoom, so the two can
## never be let through by different amounts.
func _advance_weapon_layer(delta: float) -> void:
	var wanted := 1.0
	if cinematic_silences_weapon and _follow_subject != null:
		wanted = 0.0
	_weapon_scale = lerpf(
		_weapon_scale, wanted, 1.0 - exp(-maxf(weapon_layer_speed, 0.01) * delta))


## Starts - or restarts - one named channel, leaving every other channel exactly
## where it was. A channel picks up from whatever value it was already holding,
## so retriggering blends rather than snapping.
func _start_layer(
	layers: Dictionary,
	channel: StringName,
	priority: int,
	steps: Array[Vector2]
) -> void:
	var layer := layers.get(channel) as Layer
	if layer == null:
		layer = Layer.new()
		layers[channel] = layer

	layer.priority = priority
	layer.impulse.start(_ending_at_zero(steps), layer.impulse.value)


## Advances every channel and returns what they add up to this frame.
##
## Channels quieter than the loudest one currently running are scaled rather than
## dropped, which is the whole of the prioritisation: the effects coexist, and
## priority only decides which of them the frame is mostly about. A channel whose
## impulse has finished keeps settling home under [member settle_speed] and is
## then dropped, so the set stays as small as the effects actually in flight.
func _advance_layers(layers: Dictionary, delta: float) -> float:
	if layers.is_empty():
		return 0.0

	var loudest := -2147483648
	for key: StringName in layers:
		var layer := layers[key] as Layer
		if layer.impulse.active:
			loudest = maxi(loudest, layer.priority)

	var total := 0.0
	var finished: Array[StringName] = []
	for key: StringName in layers:
		var layer := layers[key] as Layer
		var value := 0.0

		if layer.impulse.active:
			value = layer.impulse.advance(delta)
		else:
			value = lerpf(layer.impulse.value, 0.0, 1.0 - exp(-settle_speed * delta))
			if absf(value) < 0.0001:
				value = 0.0
				finished.append(key)
			layer.impulse.value = value

		if layer.priority < loudest:
			value *= low_priority_scale
		total += value

	for key: StringName in finished:
		layers.erase(key)

	return total


## Eases the camera onto whatever it is following, and home again once it is not.
##
## [b]It runs on the real clock, not the scaled one.[/b] Every lock-on in the game
## so far happens on an impact - a freeze frame and a slow motion are exactly what
## is playing while the camera is meant to be crossing onto its subject - and a
## camera eased with a time scale of a fiftieth simply does not move. Un-scaling
## the step means the move takes the same fraction of a second whatever the world
## is doing, which is what makes the lock-on read as the camera reacting rather
## than as part of the slowdown. The step is capped so a long freeze cannot turn
## one frame into a cut.
func _advance_follow(delta: float) -> void:
	if _follow_subject != null and not is_instance_valid(_follow_subject):
		release_follow()

	# Nothing to do at all in the ordinary case: no subject, and already home.
	if _follow_subject == null and _follow_offset.is_zero_approx():
		return

	var step := minf(delta / maxf(Engine.time_scale, 0.0001), 1.0 / 30.0)
	var goal := Vector2.ZERO
	if _follow_subject != null:
		var anchor := get_parent() as Node2D
		var origin := anchor.global_position if anchor != null else Vector2.ZERO
		goal = _follow_subject.global_position - origin - _rest_position

	_follow_offset = _follow_offset.lerp(goal, 1.0 - exp(-maxf(_follow_speed, 0.01) * step))
	if _follow_subject == null and _follow_offset.length_squared() < 0.01:
		_follow_offset = Vector2.ZERO


func _advance_shake(delta: float) -> void:
	if _shake_time_left <= 0.0:
		_shake_strength = 0.0
		# Cleared too, otherwise a finished long shake would stretch the falloff
		# of the next short one and swallow it almost entirely.
		_shake_duration = 0.0
		_shake_offset = Vector2.ZERO
		return

	_shake_time_left -= delta
	var t := clampf(_shake_time_left / maxf(_shake_duration, 0.0001), 0.0, 1.0)
	var amplitude := _shake_strength * pow(t, shake_falloff)
	_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude


func _ending_at_zero(steps: Array[Vector2]) -> Array[Vector2]:
	var result := steps.duplicate()
	if result.is_empty() or not is_zero_approx(result[result.size() - 1].x):
		result.append(Vector2(0.0, return_time))
	return result
