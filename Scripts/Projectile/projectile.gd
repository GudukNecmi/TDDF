class_name Projectile
extends Area2D
## A single pellet. Flies straight along its own +X axis and retires itself once
## it has run out its [ProjectileProfile]'s effective range.
##
## It knows nothing about enemies - it just hands its damage to whatever
## [Hitbox] it runs into, and the hitbox decides what that is worth.
##
## A pellet lands exactly once and stops there. It moves in whole steps rather
## than continuously, and at 900px a step is wide enough to start one side of a
## body and end up the other side of it without the two shapes ever having
## overlapped on a frame the physics server looked at - so waiting to be told
## about an overlap is not enough, and a pellet that was never told simply flew on
## through. Each step is therefore swept first: the segment from where the pellet
## is to where it is about to be is traced, and the *nearest* hitbox along it
## stops it. Sweeping is also what makes "one pellet, one victim" true by
## construction, since a segment has a first thing on it however many are lined
## up behind. There is no piercing, and nothing here to configure it with.
##
## Everything that changes with distance - damage, speed, colour, glow and the
## light it casts - is read from ONE normalised number, [method get_progress],
## which is `travelled / profile.effective_range` clamped to 0..1. There is no
## second distance calculation anywhere in this script: each effect just asks
## the profile what it should look like at that one progression value. Changing
## the profile's range therefore moves all five together.

## Emitted as this pellet lands on a body, carrying the region it struck. Sent
## after the damage so a listener sees the hit that actually happened, and sent
## once per landing - so a bouncing round announces every body it works through.
##
## It exists because "the shot has arrived" is a moment other systems need and
## cannot otherwise see: the coin's camera lets go of the coin the instant the
## coin reaches its enemy, and freeing the projectile is a frame too late to be
## that instant.
signal landed(hitbox: Hitbox)

## Distance profile driving every distance-based effect on this pellet. Swap or
## duplicate this resource to retune the weapon's whole range behaviour at once.
@export var profile: ProjectileProfile
## How far the glow around the round reaches, in pixels - its radius on screen at
## the muzzle, before the profile fades it with distance.
##
## [b]It sizes the glow only, never the round.[/b] The sprite keeps whatever scale
## it was authored at, so this is the dial for how much light the shot throws
## without the bullet itself changing size. 0 leaves the glow sprite exactly as
## authored, which is what every projectile that does not set it does.
@export var glow_radius: float = 0.0
## How far the light the round casts on the ground reaches, in pixels.
##
## The companion to [member glow_radius] and deliberately a separate field: the
## glow is the halo *on* the round and belongs at its own size, while this is the
## round lighting the world around it and has to be larger to do anything at all.
## Tuning them together is what stops a bullet from reading as a floodlight with a
## dot in the middle. 0 leaves the light exactly as authored.
@export var light_radius: float = 0.0

@export_group("Seeking")
## How many enemies this can carry on to after the one it hits. 0 is a round that
## stops where it lands, which is every projectile in the game today.
##
## [b]This is the whole bounce system[/b], and it is deliberately on the
## projectile rather than on any one weapon: a bounce upgrade later raises this
## number on whatever it applies to - a revolver round, a coin, anything added
## afterwards - without a line of new code, because they all fly through here.
@export var bounce_count: int = 0
## How far a bounce will look for its next victim, in pixels. 0 searches the whole
## arena, which lets a bounce cross the map to find somebody.
@export var target_search_radius: float = 520.0
## How quickly a redirected projectile turns onto its target, in radians per
## second. 0 snaps it round the instant it is given one, which is what a bullet
## being deflected should do; a low value curves it in instead.
@export var seek_turn_speed: float = 0.0
## What becomes of this round when the enemy it was sent at dies before it gets
## there.
##
## Off - the default, and what every round did before this field existed - carries
## on the way it was going and expires at the end of its range. That is right for a
## bullet: it is a thing in flight, and the body it was aimed at falling over does
## not stop it.
##
## On retires it the instant its target stops being valid. That is right for the
## coin, which is not a thing in flight so much as an attack aimed at somebody: with
## one enemy on the field the coin and the round that struck it are sent at the same
## body, and if the round kills it first the coin has nothing left to arrive at.
## Left flying it would cross the arena at a corpse and hold the camera on itself
## the whole way.
@export var retire_on_lost_target: bool = false

@onready var _sprite: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D
@onready var _glow: Sprite2D = get_node_or_null(^"Glow") as Sprite2D
@onready var _light: PointLight2D = get_node_or_null(^"Light") as PointLight2D

var _travelled: float = 0.0
var _age: float = 0.0
var _spent: bool = false
var _glow_base_scale := Vector2.ONE
var _light_base_scale: float = 1.0
## Who this is flying at, once something has redirected it. Null is a projectile
## flying straight, which is every one of them until it is deflected or bounces.
var _target: Node2D
## Bounces still to come. Counted down from [member bounce_count] as each one is
## spent.
var _bounces_left: int = 0
## Everything already struck on this flight, so a bounce cannot go straight back
## into the enemy it just came out of.
var _struck: Array[Node] = []
## What this round's damage is multiplied by, on top of everything the profile
## says. 1 is an ordinary shot, which is every shot until something empowers it.
var _damage_scale: float = 1.0
## Whether this round's hits are announced as critical. Nothing here decides what
## a critical hit *is* - that is the hitbox's multiplier and the damage figure's
## own reading of it - this only carries the fact along with the shot.
var _critical: bool = false
## What this round's own step is multiplied by, to undo a world time scale it is
## meant to be exempt from. 1 is a round living in the same time as everything
## else, which is every round unless something has excused it.
var _time_compensation: float = 1.0
## What this round's flight speed is multiplied by, on top of everything its
## profile says. 1 is a round flying at exactly the speed it was authored at,
## which is every round unless something has hurried it along.
var _speed_scale: float = 1.0


func _ready() -> void:
	# A pellet is never left without a profile: without one there would be no
	# range at all and it really could fly forever.
	if profile == null:
		profile = ProjectileProfile.new()

	if _glow != null:
		# Sized before the base scale is captured, so everything the profile does to
		# the glow afterwards is measured against the radius that was asked for
		# rather than against the artwork's authored size.
		_apply_glow_radius()
		_glow_base_scale = _glow.scale
	if _light != null:
		# Sized before the base is captured, for the same reason the glow is: the
		# profile's fade is measured against the reach that was asked for.
		_apply_light_radius()
		_light_base_scale = _light.texture_scale

	_bounces_left = maxi(bounce_count, 0)
	area_entered.connect(_on_area_entered)
	_apply_progress()


func _physics_process(delta: float) -> void:
	# Undone before anything reads it, so a round exempted from a slowdown is
	# exempt from all of it at once - its flight, its steering and its lifetime.
	delta *= _time_compensation
	_steer(delta)
	var progress := get_progress()

	# Speed comes from the same progression as everything else, so the pellet
	# visibly loses steam exactly as its damage, colour and light fade.
	var step := profile.speed_at(progress) * _speed_scale * delta
	# transform.x is the node's own +X axis, already rotated.
	var to := global_position + transform.x * step

	# Checked before the move is committed, so a pellet that lands stops at the
	# body rather than a step past it.
	if _sweep_to(to):
		return

	global_position = to
	_travelled += step
	_age += delta
	_apply_progress()

	# Retired at the end of its range - the same range every effect is scaled
	# against. The age check is a belt-and-braces stop so nothing can persist.
	if _travelled >= profile.effective_range or _age >= profile.max_lifetime:
		queue_free()


## Scales the glow sprite so it is drawn [member glow_radius] pixels across from
## its centre, whatever the size of the texture behind it.
##
## Worked out from the texture rather than left as a scale factor, because the
## thing being tuned is how far the light reaches on screen - a number that means
## the same for any artwork, and can be read straight off the round it is meant to
## match.
func _apply_glow_radius() -> void:
	if glow_radius <= 0.0 or _glow.texture == null:
		return

	var size := _glow.texture.get_size()
	var widest := maxf(maxf(size.x, size.y), 1.0)
	_glow.scale = Vector2.ONE * (glow_radius * 2.0 / widest)


## Scales the light so it reaches [member light_radius] pixels from the round.
## Worked out from its texture the same way the glow is, so both fields are read
## in the units the player actually sees.
func _apply_light_radius() -> void:
	if light_radius <= 0.0 or _light.texture == null:
		return

	var size := _light.texture.get_size()
	var widest := maxf(maxf(size.x, size.y), 1.0)
	_light.texture_scale = light_radius * 2.0 / widest


## Sends this projectile at [param target] from wherever it is now.
##
## The one way anything outside redirects a shot - a coin splitting a bullet off
## towards an enemy, a bounce carrying on to the next one. It deliberately does
## not touch damage, range or speed: a deflected round is the same round, still
## reading everything from its own profile, just pointed somewhere else.
##
## [param keep_distance] false restarts the range from here, which is what makes a
## deflection a fresh flight rather than a round that expires halfway to its new
## target.
func redirect_to(target: Node2D, keep_distance: bool = false) -> void:
	_target = target
	if not keep_distance:
		_travelled = 0.0
		_age = 0.0

	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if not to_target.is_zero_approx():
			global_rotation = to_target.angle()


## Makes this round hit harder than it otherwise would, and optionally makes it
## land as a critical.
##
## [b]Deliberately a multiplier rather than a damage figure.[/b] Everything about
## how hard a round hits still comes from its own [ProjectileProfile] and still
## falls off over its own range, so an empowered shot is the same shot turned up -
## which means a profile retuned later, or a round empowered by something other
## than the coin, needs nothing here changed.
##
## [param critical] does not introduce a second notion of a critical hit. The
## hitbox's own multiplier remains the whole of the mechanic; this only marks the
## hit as one so the figure that comes off it is written the way a critical is
## written, and it stacks with a headshot rather than replacing it.
func empower(multiplier: float, critical: bool = false) -> void:
	_damage_scale = maxf(multiplier, 0.0)
	_critical = _critical or critical


## Makes this round fly faster - or slower - than its profile says, without
## touching anything else about it.
##
## [b]Deliberately a multiplier rather than a speed, and the companion to
## [method empower].[/b] The shape of the flight still comes from the profile and
## still eases off over the range, so a profile retuned later carries through here
## untouched. Range is unaffected either way: a hurried round covers exactly the
## same ground, it simply arrives sooner. 1 puts it back at its profile's speed.
func set_speed_scale(multiplier: float) -> void:
	_speed_scale = maxf(multiplier, 0.0)


## Excuses this round from a world time scale, so it flies at its ordinary speed
## while everything around it is slowed.
##
## [param world_scale] is the scale the rest of the world is running at - 0.5 for
## a half-speed world - and 1 puts the round back in step with everything else.
## Written as the world's scale rather than as a multiplier on purpose: the caller
## already knows how far it slowed the world down, and stating the same number
## twice is how the two drift apart.
func exempt_from_time_scale(world_scale: float) -> void:
	_time_compensation = 1.0 / maxf(world_scale, 0.0001)


## Whether this still has a bounce in it, for anything deciding what to do with a
## projectile it has caught.
func get_bounces_left() -> int:
	return _bounces_left


## Turns onto the target it was given. A projectile with no target flies dead
## straight, which is every projectile in the game until something redirects it -
## so this costs nothing for the ones that never seek.
func _steer(delta: float) -> void:
	if _target == null:
		return

	if not EnemyTargeting.is_valid(_target):
		# The target died on the way. The reference is dropped first and in every
		# case, so nothing downstream can be left holding a body that is already
		# gone - and no damage is dealt, because retiring and flying on both skip
		# the landing entirely.
		_target = null
		if retire_on_lost_target:
			# Spent here rather than on arrival: there is no arrival. The rest of
			# this frame's step is skipped too, since a spent round refuses to
			# sweep, so it stops exactly where the news reached it.
			_retire()
			return
		# Otherwise the shot carries on the way it was going rather than stopping
		# dead, which is both simpler and what a real one would do.
		return

	var wanted := (_target.global_position - global_position).angle()
	if seek_turn_speed <= 0.0:
		global_rotation = wanted
		return
	global_rotation = rotate_toward(global_rotation, wanted, seek_turn_speed * delta)


## The one shared distance progression: 0 at the muzzle, 1 at the end of the
## profile's effective range. Every distance-driven effect on this pellet is
## derived from this single value.
func get_progress() -> float:
	return profile.progress_for(_travelled)


## Damage this pellet would land right now, before the hitbox's own multiplier -
## so the headshot bonus still applies on top, at any distance, and on top of
## whatever [method empower] has done to it.
func get_current_damage() -> float:
	return profile.damage_at(get_progress()) * _damage_scale


## Whether this round's hits are announced as critical. Set by [method empower].
func is_critical() -> bool:
	return _critical


## Pushes the one progression value out to every visual at once. Called from a
## single place each frame so the pellet's look can never drift out of step with
## its damage or its speed.
func _apply_progress() -> void:
	var progress := get_progress()

	if _sprite != null:
		_sprite.modulate = profile.color_at(progress)

	if _glow != null:
		var glow_color := profile.color_at(progress)
		glow_color.a = clampf(profile.glow_at(progress), 0.0, 1.0)
		_glow.modulate = glow_color

	if _light != null:
		_light.color = profile.color_at(progress)
		_light.energy = profile.light_energy_at(progress)
		_light.texture_scale = _light_base_scale * profile.light_scale_at(progress)


## Traces this step and lands on the first hitbox along it. Returns true when the
## pellet is spent, in which case it has already been moved to the impact point
## and must not travel any further.
##
## The trace is a ray rather than the pellet's own shape swept along the segment:
## a pellet is four pixels across and a body is thirty, so the difference is not
## worth a shape cast, and [method PhysicsDirectSpaceState2D.intersect_ray]
## returns the nearest hit, which is precisely the "first thing in the way" this
## needs. Only areas are traced, on the pellet's own collision mask, so walls and
## bodies are as invisible to it as they always were.
func _sweep_to(to: Vector2) -> bool:
	if _spent:
		return true

	var query := PhysicsRayQueryParameters2D.create(global_position, to, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# A pellet released point-blank can begin its first step already inside the
	# body it was fired into; without this the ray would start past the surface
	# and report nothing.
	query.hit_from_inside = true
	# And having said the ray may start inside things, the one thing it always
	# starts inside is this projectile.
	#
	# [b]Without this a projectile on a layer its own mask contains is blind.[/b]
	# The struck coin is exactly that - it sits on the hitbox layer so a shot can
	# find it in the air, and it traces that same layer once it becomes a shot
	# itself - so its ray reported its own shape at zero distance every frame, the
	# nearest hit was always itself, and it never saw the enemy in front of it at
	# all. It only ever landed on the slower overlap path below, a frame or more
	# after it had already travelled into the body, which is what made a struck
	# coin appear to carry on through its target.
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider := hit.get("collider") as Node
	var contact := hit.get("position", to) as Vector2

	# Something in the way that is not a body to be damaged - the thrown coin is
	# the one today. It is offered the shot and decides for itself, and the answer
	# means "I took this": a deflector that refuses is passed straight through as
	# though it were not there, so a weapon it does not answer to is entirely
	# unaffected by it.
	#
	# What becomes of a taken shot is the deflector's business too. It may send it
	# somewhere - the coin splits it off at an enemy - and a shot that has been
	# given a target is still very much alive, so only one that was left without
	# one is retired here.
	if collider != null and collider.has_method(&"take_projectile_hit"):
		if collider.call(&"take_projectile_hit", self, contact):
			global_position = contact
			if _target == null:
				_retire()
			return true
		return false

	var hitbox := collider as Hitbox
	if hitbox == null:
		return false

	global_position = hit.get("position", to) as Vector2
	_land(hitbox)
	return true


## The area path is kept as well as the sweep, for the case the sweep cannot see:
## a hitbox that moves onto a pellet, rather than a pellet that moves onto a
## hitbox. Both funnel into [method _land], and [member _spent] is what makes a
## pellet caught by both still land exactly once.
func _on_area_entered(area: Area2D) -> void:
	var hitbox := area as Hitbox
	if hitbox != null:
		_land(hitbox)


## Spends the pellet on one hitbox. Everything that stops it happens here, so
## there is one answer to "what does a pellet do when it hits something" however
## the hit was noticed.
func _land(hitbox: Hitbox) -> void:
	# Overlapping hitboxes can both report in the same frame, and the sweep and
	# the area can both notice the same impact - a pellet must only ever land once,
	# on one victim.
	if _spent:
		return
	_spent = true

	# The direction of travel is handed over so the victim can react away from
	# the shot. The hitbox still applies its own multiplier to the damage - which
	# is the whole of the game's critical hits, and applies to anything that comes
	# through here whether it was fired, deflected or bounced.
	#
	# The pellet's own position is the impact point - the sweep already moved it
	# there - so the damage figure lands where the pellet did rather than at the
	# middle of whatever it hit.
	hitbox.take_hit(get_current_damage(), transform.x, global_position, _critical)
	landed.emit(hitbox)

	if _bounce_onward(hitbox):
		return

	_retire()


## Carries the shot on to the next enemy, if it has a bounce left and there is
## somebody to bounce to. Returns whether it did.
##
## The victim is remembered rather than merely skipped once, so a shot with
## several bounces works its way outwards through a crowd instead of ricocheting
## between the same two bodies.
func _bounce_onward(hitbox: Hitbox) -> bool:
	if _bounces_left <= 0:
		return false

	var victim := hitbox.owner if hitbox.owner != null else hitbox.get_parent()
	if victim != null and not _struck.has(victim):
		_struck.append(victim)

	var next := EnemyTargeting.nearest(
		self, global_position, target_search_radius, _struck)
	if next == null:
		return false

	_bounces_left -= 1
	# Un-spent deliberately: it is the same projectile continuing, so it keeps its
	# profile, its artwork and its remaining bounces rather than a new one being
	# spawned with all of that copied onto it.
	_spent = false
	redirect_to(next)
	return true


## Takes the projectile off the board.
##
## queue_free() only takes effect at the end of the frame, and drawing is a tick
## behind the physics, so a pellet left alone would still be seen crossing the
## body it just hit. Stopping and hiding it now is what makes it disappear on
## impact rather than a moment past it.
func _retire() -> void:
	_spent = true
	set_physics_process(false)
	# Deferred because this can be reached from inside the physics server's own
	# overlap callback, where changing an area's monitoring state is refused.
	set_deferred(&"monitoring", false)
	hide()
	queue_free()
