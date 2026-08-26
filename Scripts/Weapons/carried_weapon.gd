class_name CarriedWeapon
extends Node2D
## Everything every weapon in the player's hands does regardless of what kind of
## weapon it is: trailing after them, aiming at the cursor, swaying with their
## movement, and going away to the belt when they are disarmed.
##
## [b]This is the half of a weapon that is not about firing.[/b] A weapon extends
## it and adds only its own mechanism - the shotgun its pump cycle, the rifle its
## lever - so the carry, the aim and the holster exist once and behave identically
## for every weapon, and a third weapon added later inherits all of it without a
## line being copied.
##
## The weapon is independent from the player - it is not parented to it, it only
## follows a target node. The art points along +X, so aiming is just a rotation
## towards the cursor. Keeping the artwork the right way up once the aim crosses
## vertical is not done here: that is [HeldItemFlip], a child node pointed at the
## weapon's art, so every held item rights itself the same way.
##
## Ammunition is here too, because "how many rounds are left" is not a property of
## any one mechanism: the subclass asks [method has_ammo] before it fires and
## [method spend_ammo] as the shot leaves, and the counting, the capacity and the
## price all live behind [WeaponAmmo]. A weapon with no magazine node fires
## freely, so a test scene without one still works.
##
## What a subclass overrides is [method _weapon_input] - and only that. Input is
## already gated on the weapon being in the player's hands before it arrives, so
## no subclass has to remember to check.

## Node the weapon trails behind.
@export var target_path: NodePath
## Resting spot relative to the target.
##
## Sits between the character's waist and their chest, which is where a weapon
## carried at the hip belongs - high enough to read as held, low enough to stay
## off the face. It is measured from the target's own origin, at their feet, so
## up is negative.
@export var follow_offset := Vector2(0, -25)
## Where the weapon is held relative to the character, measured along the *aim*
## rather than along the world.
##
## [b]This is the attachment point, and it orbits.[/b] [member follow_offset] is a
## fixed spot on the character - their chest - and a weapon resting there alone sits
## on top of them and merely spins in place as they aim. This offset is turned with
## the aim before it is added, so +X is "out in front of the muzzle direction" and
## +Y is "to the weapon's right": the weapon is pushed out to arm's length and
## carried around the character as the aim sweeps, which is what a held weapon
## actually does.
##
## [constant Vector2.ZERO] leaves the weapon exactly on [member follow_offset],
## which is what every weapon did before this field existed - so a weapon that
## wants the old behaviour simply says nothing.
@export var hand_offset := Vector2.ZERO
## Higher follows tighter, lower trails further behind. This is the weight of the
## weapon: it is meant to visibly swing after the player when they set off rather
## than being welded to their hip, but not to be left trailing across the arena
## behind them.
@export var follow_speed: float = 13.0

@export_group("Trail")
## How far the weapon is allowed to fall behind its resting spot before it starts
## pulling harder, in pixels.
##
## This is the leash, and it is the field that decides how flexible the weapon
## feels. Inside this distance it drifts along at [member follow_speed]; beyond it
## the pull is blended up towards [member catch_up_speed], so the weapon has give
## over a short distance and is hauled back hard past it. Raising it makes the
## weapon looser and lets the player get further clear; lowering it pins the
## weapon closer to them.
##
## 0 removes the leash and leaves the plain smoothing.
@export var trail_distance: float = 16.0
## How hard the weapon pulls once it is a full [member trail_distance] beyond the
## leash. Well above [member follow_speed], so the catch-up is a real haul rather
## than a slightly quicker drift.
@export var catch_up_speed: float = 34.0

@export_group("Aim")
## The muzzle the aim is worked out through, so the round leaves along a line that
## passes *through* the cursor rather than merely parallel to it.
##
## [b]This is the difference between the sight being decorative and being true.[/b]
## A weapon's barrel does not come out of the middle of the weapon: the revolver's
## muzzle sits some way above the point the weapon is carried by. Pointing the
## weapon's own origin at the cursor therefore sends the round down a line offset
## sideways by exactly that much, and the shot passes beside the crosshair rather
## than through it - which is the "the sight is slightly off" the player sees.
##
## Given a muzzle, the aim is solved for instead: the weapon is turned to whatever
## angle puts the *muzzle's* line on the cursor, so the middle of the sight and the
## path of the round are the same claim. Left empty, the aim is the plain one and
## nothing about the weapon changes.
@export var aim_muzzle_path: NodePath
## The radius of the circle the middle of the character is walled off by, in pixels,
## measured from the carry anchor - the character's own position plus
## [member follow_offset].
##
## [b]It is one circle doing two jobs, because it is one idea: the middle is not a
## place the weapon may be.[/b] The weapon is carried out at arm's length, so a cursor
## drawn in onto the character is *behind* it: the aim reads as a half turn, the weapon
## swings round to it, and being carried with it the weapon takes the cursor round to
## its far side again - it orbits, for no input at all, and cuts straight through the
## character on every pass.
##
## So the cursor may come inside this circle and the weapon may not. The cursor
## crossing in captures the direction it was last seen in, projects that onto the
## boundary, and the aim is locked onto that point until the cursor leaves again -
## further movement inside is not read at all, so nothing the player does in there can
## turn the weapon inwards. The weapon's own position is held outside the same circle
## as a hard floor (see [method _orbit_towards]), so neither the follow spring, the
## sway nor a half-turn of the aim can carry it into the character: it travels
## [i]around[/i] them instead. The moment the cursor is back out the lock is dropped
## and the weapon is resolved onto the correct side at once rather than swinging round
## to find it.
##
## It wants to sit inside the reach the weapon is carried at
## ([member hand_offset]'s length) so the wall is only ever felt in passing rather
## than fighting the resting pose. 0 leaves the aim ungoverned and the weapon
## unwalled, which is every weapon that is not held out to one side.
@export var aim_deadzone: float = 0.0

@export_group("Ammo")
## The [WeaponAmmo] this weapon draws rounds from.
##
## The weapon owns no count of its own: how many rounds there are, how many fit
## and what a box costs all live behind that node, in an [AmmoType] resource and
## a reserve kept by the [code]Ammo[/code] locker. All a weapon does is refuse to
## fire when it is dry and spend a round when it does - which is the whole of the
## connection between a gun and its ammunition, and why the same wiring works for
## every weapon.
##
## Left unset - or pointed at nothing - the weapon fires without consuming
## anything, so a test scene with no magazine still works.
@export var ammo_path: NodePath = ^"Ammo"

@export_group("Holster")
## Where the weapon sits, relative to the target, once it is fully stowed - the
## belt. It shrinks into this rather than being teleported away.
@export var holster_offset := Vector2(0, -16)
## Size it shrinks to on the way in, as a fraction of its normal scale.
@export_range(0.0, 1.0) var holster_scale: float = 0.2

@export_group("Feel")
## How far a change in the player's velocity throws the weapon, in seconds.
@export var sway_strength: float = 0.012
## Ceiling on that throw, so a direction change can only ever nudge it.
@export var max_sway: float = 7.0
## How quickly the sway settles back to nothing.
@export var sway_recovery: float = 14.0
## How quickly the weapon's angle catches up to the cursor. Lower = looser.
@export var rotation_speed: float = 26.0

@onready var _target: Node2D = get_node_or_null(target_path) as Node2D
@onready var _ammo: WeaponAmmo = get_node_or_null(ammo_path) as WeaponAmmo
@onready var _aim_muzzle: Node2D = get_node_or_null(aim_muzzle_path) as Node2D

## Whether the aim is currently locked because the cursor is on the character.
var _aim_held: bool = false
## The direction the aim is locked to while it is, as a unit vector out from the carry
## anchor. [constant Vector2.ZERO] while the cursor is being followed normally.
var _aim_lock: Vector2 = Vector2.ZERO
## The last direction the cursor was seen in while it was still outside the boundary.
## This is what gets captured the frame it crosses in - the direction it came from,
## rather than whatever noise it has decayed to now that it is on top of the character.
var _last_aim_direction: Vector2 = Vector2.RIGHT
var _previous_target_position: Vector2
var _previous_target_velocity: Vector2
var _sway: Vector2 = Vector2.ZERO
var _holster: float = 0.0
var _holster_tween: Tween
var _base_scale: Vector2


func _ready() -> void:
	_base_scale = scale
	# Start already in place, otherwise the weapon visibly slides in from the origin.
	if _target != null:
		global_position = _target.global_position + follow_offset + hand_offset.rotated(rotation)
		_previous_target_position = _target.global_position
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_follow_target(delta)
	_aim_at_mouse(delta)
	_apply_holster()


## Blocked while the weapon is on its way to the belt or already there, so it
## cannot be fired or worked out of the player's hand. This gates *input* only -
## no state is changed, so the weapon comes back out exactly as it went away,
## with any half-finished action still half-finished.
func _unhandled_input(event: InputEvent) -> void:
	if _holster > 0.0:
		return
	_weapon_input(event)


## What this weapon does with a press. The one thing a subclass has to write, and
## it is only ever reached while the weapon is actually in the player's hands.
func _weapon_input(_event: InputEvent) -> void:
	pass


## Puts the weapon away over [param duration] seconds. It keeps following the
## player and keeps aiming the whole time; only where it rests and how big it is
## change, so there is no jump when it comes back.
func stow(duration: float) -> void:
	_tween_holster(1.0, duration)


## Brings it back out. The resting offset and scale it returns to are the same
## exported values it always used, so it lands exactly where it was before.
func unstow(duration: float) -> void:
	_tween_holster(0.0, duration)


func is_stowed() -> bool:
	return _holster >= 1.0


## Puts the weapon into the state it should start a round in: action closed,
## magazine filled from whatever the player is carrying, nothing half-worked.
##
## [b]It is deliberately a request rather than a rule.[/b] What "ready" means is
## different for every mechanism - a closed breech, a lever up, a full cylinder -
## so each weapon answers for itself and the base class does nothing, which is the
## right answer for a weapon that is simply always ready. Whoever starts a round
## calls this on whatever is in the player's hands without knowing which weapon it
## got.
##
## It is only ever called between rounds, never during one, so it can fill a
## magazine without that being a way to reload for free.
func reload_to_ready() -> void:
	pass


## The magazine this weapon feeds from, for anything that wants to watch or
## resupply it.
func get_ammo() -> WeaponAmmo:
	return _ammo


## Who this weapon is currently part of - the character carrying it.
##
## A weapon in a hand is not a separate object standing on the floor next to
## somebody: it is part of the figure, and its silhouette belongs in that figure's
## one shadow rather than beside it. This is the weapon saying so, and it is the
## whole of what the shadow system needs to know - see
## [member ShadowCaster.group_owner_method]. A weapon that has been thrown, dropped
## or left lying in the sand is a [ThrownWeapon] or a pickup and does not answer
## this at all, so it casts a shadow of its own again without a line of code
## anywhere knowing what a weapon is.
func get_shadow_group_owner() -> Node:
	return _target


## Where the weapon is being held relative to the character, in world pixels - the
## hand, turned by the aim.
##
## [b]It is the aim's answer to "which side am I on", not the weapon's.[/b] The
## weapon itself trails after the player on a spring and sways with their movement,
## so its actual position lags the aim by a good fraction of a second. Anything that
## has to react to the player crossing over - which way a twirl turns, which hand the
## weapon is in - wants this instead, because it resolves in the same frame the aim
## does. [constant Vector2.ZERO] for a weapon carried on the character rather than
## out at arm's length.
func get_hand_direction() -> Vector2:
	return hand_offset.rotated(rotation)


## Whether there is enough left for one more shot. A weapon with no magazine node
## is always able to fire.
func has_ammo() -> bool:
	return _ammo == null or _ammo.can_fire()


## Spends one shot's worth and reports whether it went through. The reserve
## refuses a spend it cannot cover in full, so a weapon that checks this can
## never fire a shot it did not pay for, and the count can never go below zero.
func spend_ammo() -> bool:
	return _ammo == null or _ammo.consume()


## One value drives the whole holster: the follow offset, the scale and the
## visibility are all read from it, so reversing part way through is just
## retargeting the tween - there is no separate "going in" and "coming out"
## motion to get out of step.
func _tween_holster(goal: float, duration: float) -> void:
	if _holster_tween != null and _holster_tween.is_running():
		_holster_tween.kill()

	if duration <= 0.0:
		_holster = goal
		return

	_holster_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_holster_tween.tween_property(self, "_holster", goal, duration)


## Applied every frame rather than tweened directly onto `scale` and `visible`,
## because the follow code writes the position anyway - keeping all three read
## from the same blend is what stops them drifting apart.
func _apply_holster() -> void:
	scale = _base_scale * lerpf(1.0, holster_scale, _holster)
	# Hidden only once it is fully in the belt, so it disappears at its smallest
	# rather than winking out mid-shrink.
	visible = _holster < 1.0


## Frame-rate independent smoothing, so the trail feels the same at any FPS.
func _follow_target(delta: float) -> void:
	if _target == null or delta <= 0.0:
		return
	var anchor := _carry_anchor()
	# Turned by the weapon's own aim, and folded away as it holsters so the weapon
	# comes back in to the belt rather than being stowed out at arm's length.
	var goal := anchor + hand_offset.rotated(rotation) * (1.0 - _holster)
	goal += _update_sway(delta)
	var speed := _follow_speed_for(global_position.distance_to(goal))
	global_position = _orbit_towards(anchor, goal, 1.0 - exp(-speed * delta))


## The point the weapon is carried around: the character, at the height a weapon is
## held at rather than at their feet where their own origin is.
##
## Everything about the middle is measured from here - the boundary the cursor is
## walled out of, the floor the weapon's own distance is held above, and the circle
## [member hand_offset] swings it around. They have to share an origin or they are
## three different circles and the weapon can satisfy all of them while still standing
## on the character.
##
## It slides towards the belt as the weapon holsters, so the weapon is carried in by
## the same follow it always used instead of being moved by a second, competing system.
func _carry_anchor() -> Vector2:
	if _target == null:
		return global_position
	return _target.global_position + follow_offset.lerp(holster_offset, _holster)


## One frame of the follow: [param weight] of the way from where the weapon is to
## [param goal], taken around the character rather than through them.
##
## [b]The step is made in the anchor's own polar frame, and that is the whole trick.[/b]
## Interpolating the position straight would draw a line from here to there, and when
## the aim has just flipped to the player's other side that line goes through the
## middle of the character - which is the weapon being dragged across their body every
## time the cursor crosses over. Moving the distance and the heading separately instead
## means the weapon covers that same half turn by travelling round the outside, and the
## distance is floored at the boundary radius on the way, so the follow spring, the
## sway and the leash can pull the weapon anywhere they like except inwards.
##
## Over the small angles of ordinary aiming the two are the same motion, so nothing
## about how the weapon trails and settles changes - and a weapon with no boundary at
## all is interpolated straight, exactly as it always was.
func _orbit_towards(anchor: Vector2, goal: Vector2, weight: float) -> Vector2:
	# Folded away with the holster like the hand is, so the weapon can come all the way
	# in to the belt rather than being held off the character by its own wall.
	var radius := maxf(aim_deadzone, 0.0) * (1.0 - _holster)
	if radius <= 0.0:
		return global_position.lerp(goal, weight)

	var from := global_position - anchor
	var to := goal - anchor
	# A heading is meaningless at the anchor itself, so a degenerate end borrows the
	# other's rather than snapping the weapon to angle zero on its way past.
	var from_heading := to.angle() if from.is_zero_approx() else from.angle()
	var to_heading := from_heading if to.is_zero_approx() else to.angle()

	var reach := lerpf(from.length(), to.length(), weight)
	var heading := lerp_angle(from_heading, to_heading, weight)
	return anchor + Vector2.from_angle(heading) * maxf(reach, radius)


## How hard the weapon is pulled towards its resting spot from [param distance]
## away.
##
## One smoothing rate for the whole leash rather than a hard clamp on the
## distance: a clamp would drag the weapon along at arm's length the moment the
## player outran it, which reads as a rod rather than as weight. Blending the rate
## instead means the weapon genuinely falls behind on the way out and genuinely
## hauls itself back in, and the transition between the two is never visible.
func _follow_speed_for(distance: float) -> float:
	if trail_distance <= 0.0:
		return follow_speed
	# Full catch-up at one leash length past the leash, so the pull comes on
	# gradually across a distance rather than switching at a threshold.
	var beyond := clampf((distance - trail_distance) / trail_distance, 0.0, 1.0)
	return lerpf(follow_speed, maxf(catch_up_speed, follow_speed), beyond)


## Kicks the weapon whenever the player's velocity changes - starting, stopping
## and turning - then lets that kick decay back to nothing.
func _update_sway(delta: float) -> Vector2:
	var target_velocity := (_target.global_position - _previous_target_position) / delta
	_previous_target_position = _target.global_position

	var velocity_change := target_velocity - _previous_target_velocity
	_previous_target_velocity = target_velocity

	_sway = (_sway - velocity_change * sway_strength).limit_length(max_sway)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-sway_recovery * delta))
	return _sway


## Eased rather than snapped, so the weapon carries a little rotational inertia -
## except coming out of the dead zone, which is resolved at once because there is no
## previous aim worth easing from.
func _aim_at_mouse(delta: float) -> void:
	var anchor := _carry_anchor()
	var mouse := get_global_mouse_position()
	var locked := _update_aim_lock(mouse - anchor)

	var wanted: float
	if locked:
		# Aimed at the captured point on the boundary rather than at the cursor, and
		# taken from the anchor rather than from the weapon: the point is inside the
		# weapon's own reach, so a vector from the weapon to it would run backwards
		# through the character and turn the weapon inwards - the very orbit the
		# boundary exists to stop. From the anchor it is simply the direction the
		# player was last pointing, and it does not move while they are inside.
		wanted = _aim_angle(_aim_lock * maxf(aim_deadzone, 0.0))
	else:
		var to_mouse := mouse - _aim_origin(anchor, mouse)
		if to_mouse.is_zero_approx():
			return
		wanted = _aim_angle(to_mouse)

	if _aim_held and not locked:
		# The cursor may have crossed clean over the character while the aim was locked,
		# so the angle it was left at means nothing about where it should be now.
		# Assigned rather than eased: the weapon lands on the correct hand immediately
		# instead of sweeping a half turn to get there. The weapon's own body still has
		# to travel, and it goes round the outside - see [method _orbit_towards].
		_aim_held = false
		rotation = wanted
		return

	_aim_held = locked
	rotation = lerp_angle(rotation, wanted, 1.0 - exp(-rotation_speed * delta))


## Takes the lock on or off for this frame, given where the cursor is relative to the
## carry anchor, and answers whether the aim is locked.
##
## [b]What is captured is the direction the cursor came in from, not the one it has
## now.[/b] A cursor can be thrown from well outside to dead on the character in a
## single frame, and the direction of a cursor sitting on the anchor is noise - a pixel
## of jitter swings it right round. So the last direction it was seen in while it was
## still outside is what gets kept, and that is what the boundary point is projected
## along.
func _update_aim_lock(to_cursor: Vector2) -> bool:
	if aim_deadzone <= 0.0 or _target == null or to_cursor.length() >= aim_deadzone:
		_aim_lock = Vector2.ZERO
		if not to_cursor.is_zero_approx():
			_last_aim_direction = to_cursor.normalized()
		return false

	# Only ever set on the crossing frame. Every frame after it the cursor is ignored
	# outright, which is what makes the lock a lock rather than a clamp that still
	# tracks.
	if _aim_lock == Vector2.ZERO:
		_aim_lock = _last_aim_direction
	return true


## Which point the aim is worked out from - the weapon itself, normally.
##
## [b]A weapon cannot aim at something behind it.[/b] The weapon is carried out at
## arm's length, so a cursor nearer the character than the weapon is sits between the
## two: the vector from the weapon to it points back at the character, the aim reads as
## a half turn, and the weapon swings round - taking the cursor to its far side and
## starting again. Once the cursor is inside the reach the weapon is held at, the
## character is used as the origin instead. From there every cursor is genuinely out in
## front, so the aim is the direction the player is pointing and there is no way for it
## to invert.
##
## Outside that reach - which is all ordinary aiming - the weapon's own position is
## used exactly as before, because that is what makes the muzzle's line true (see
## [method _aim_angle]).
func _aim_origin(anchor: Vector2, mouse: Vector2) -> Vector2:
	if mouse.distance_to(anchor) < global_position.distance_to(anchor):
		return anchor
	return global_position


## Where the weapon must point for its muzzle to be looking at a cursor
## [param to_mouse] away from the weapon's own origin.
##
## [b]It is a right-angled triangle, solved rather than approximated.[/b] The muzzle
## sits a fixed distance off to one side of the weapon's centre line, and that
## distance rides round with the weapon as it turns - so the angle wanted is the
## angle to the cursor less the angle that sideways offset subtends at this range.
## Close in that correction is large and far out it vanishes, which is exactly how a
## real offset sight behaves.
##
## A cursor closer than the offset itself has no solution - the muzzle cannot be
## brought onto a point it is already beside - so the plain aim is used there, which
## is inside the dead zone anyway.
func _aim_angle(to_mouse: Vector2) -> float:
	var angle := to_mouse.angle()
	if _aim_muzzle == null:
		return angle

	var lateral := _muzzle_rest_offset().y
	var reach := to_mouse.length()
	if reach <= absf(lateral):
		return angle
	return angle - asin(lateral / reach)


## How far the muzzle sits from the weapon's own origin, in world pixels, measured in
## the weapon's own frame with every rotation between the two taken out.
##
## [b]The rotations have to go.[/b] The muzzle rig is turned bodily by the twirl (see
## [RevolverSpin]), so reading the muzzle's actual position would have the aim
## chasing a barrel that is swinging round - the offset the aim needs is the rig at
## rest. Scales are kept, because the mirror that rights the artwork
## ([HeldItemFlip]) writes one, and it is precisely what moves the muzzle to the
## other side of the centre line when the weapon is aimed left.
func _muzzle_rest_offset() -> Vector2:
	var offset := Vector2.ZERO
	var node: Node2D = _aim_muzzle
	while node != null and node != self:
		offset = node.position + offset * node.scale
		node = node.get_parent() as Node2D
	return offset * global_scale
