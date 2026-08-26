extends CharacterBody2D
## Walks straight at the player at a constant speed. No pathfinding and no
## route planning - it just heads for the target every frame, and only steers
## around other enemies it is physically touching.
##
## Everything else it does is delegated to reusable components: [SquashIdle]
## for the breathing squash, [LookAtTarget] on the head and knife pivots, and
## [Health] plus [Hitbox] for taking damage.

## Movement speed in pixels per second.
@export var speed: float = 90.0
## Node to chase.
@export var target_path: NodePath

@export_group("Attack")
## Distance at which the knife swing plays, and at which it connects.
@export var slash_range: float = 44.0
## Seconds between repeat swings while still touching the player.
@export var slash_interval: float = 1.0
## Damage one connecting swing deals. 0 makes the swing cosmetic again, which is
## what it was before.
##
## How often this can actually cost the player anything is governed by their own
## [member Health.invulnerable_seconds], not by [member slash_interval] - the
## grace window drops the extra hits at the single point they funnel through.
@export var contact_damage: float = 1.0
## Name of the [Health] component on the chase target. Looked up on the target
## rather than wired by path, so the spawner needs no extra plumbing.
@export var target_health_name: StringName = &"Health"

@export_group("Separation")
## How hard an enemy steers away from one it is already touching, relative to
## its pull towards the player. High enough to slide out of a pile-up, low
## enough that the chase always wins. 0 disables it and leaves only the plain
## body collision.
@export var separation_strength: float = 0.7

@export_group("Steering")
## Optional component that bends the walk before it is taken.
##
## [b]It is one hook, not a second mover.[/b] Whatever is named here is asked once
## a frame - [code]steer(chase: Vector2, delta: float) -> Vector2[/code], with the
## direction this enemy was about to walk in - and whatever comes back is what it
## walks in. Everything after that point is untouched: the separation from the
## crowd, the hit reaction, the world's slow motion, the swing and the retreat are
## all the same code either way.
##
## Left unset - which is every ordinary Enemy1 - the chase is taken exactly as it
## was computed, so nothing about an enemy without one is changed by this being
## here. See [BomberSway], which is what a bomber's wobbling approach is made of.
@export var steering_path: NodePath

@export_group("Toughness")
## Whether this enemy's health is the figure its region states rather than the one
## its own scene was authored with.
##
## [b]On for an ordinary man, and that is the whole of regional health.[/b] The pool
## is written as the enemy is built - see [method RoundScaling.apply_to] - to
## [member MapRegion.enemy_base_health] for the part of the map being fought in, and
## nothing multiplies it afterwards.
##
## [b]Off for anything whose toughness is a property of the thing rather than of the
## place[/b] - the bomber, whose short pool is the point of it: it is meant to be
## killable before it reaches you, and a bomber that got tougher the deeper the
## player went would stop being that. An enemy switched off here keeps exactly what
## its scene says.
##
## Bosses do not read this at all. A boss's pool is built from its scene's authored
## figure and its bounty by [MiniBossDirector] and is untouched either way.
@export var uses_regional_health: bool = true

@export_group("Hit reaction")
## Optional [HitReaction] whose knockback and slow are folded into this enemy's
## movement. Left unset, the enemy simply moves as it always did.
@export var hit_reaction_path: NodePath = ^"HitReaction"

@export_group("Standing by")
## How high the hop rises while this enemy is standing by, in pixels. 0 leaves it
## perfectly still.
##
## Standing by is not a second kind of enemy and not an animation state - it is
## one flag, exactly as fleeing is, and for the same reason: the walk, the swing
## and the hop are all the same code either way and only whether they run
## differs. See [method set_passive], and [MiniBossDirector], which is what holds
## a boss and its support group still while the introduction plays.
@export var idle_hop_height: float = 5.0
## Hops per second.
@export var idle_hop_speed: float = 1.3
## How much the hop is knocked out of time from one enemy to the next, as a
## fraction of a hop. Without it a crowd standing by rises and falls in lockstep,
## which reads as one object rather than as ten men.
@export_range(0.0, 1.0) var idle_hop_spread: float = 1.0
## Node lifted by the hop. Its [member Node2D.position] is the only thing written,
## and the shared idle animation drives [code]scale[/code] rather than position,
## so the two do not fight.
@export var idle_hop_path: NodePath = ^"Visual"

@onready var _target: Node2D = get_node_or_null(target_path) as Node2D
## Looked up rather than required, because an enemy that carries no blade is a real
## thing now - a bomber's whole attack is the charge - and one must simply not swing
## rather than fail to load.
@onready var _knife_slash: KnifeSlash = get_node_or_null(^"KnifeAim/KnifeSlash") as KnifeSlash
@onready var _steering: Node = get_node_or_null(steering_path)
@onready var _hit_reaction: HitReaction = get_node_or_null(hit_reaction_path) as HitReaction

var _slash_cooldown: float = 0.0
var _target_health: Health
## True once this enemy has been sent home by the round's clock. It is the only
## thing that reverses the chase, and it is deliberately one flag rather than a
## second mover: the walk, the separation, the hit reaction and the world's slow
## motion are all the same code either way, and only the direction and the swing
## differ. See [EnemyEscape], which owns everything else about running away.
var _fleeing: bool = false
## What the walk is multiplied by while fleeing. Handed in rather than exported
## here, because how fast a retreat is belongs with the rest of the escape.
var _flee_multiplier: float = 1.0
## True while this enemy is charging a place rather than chasing a person. The third
## of the flags that change where the walk points, and deliberately the same shape as
## the two above it: the walk, the separation, the hit reaction, the swing and the
## world's slow motion are all the same code either way, and only the destination and
## the speed differ. See [BossCharge], which owns everything else about the attack.
var _charging: bool = false
var _charge_point: Vector2 = Vector2.ZERO
## What the walk is multiplied by while charging. Handed in rather than exported here,
## because how fast a charge runs belongs with the rest of the attack.
var _charge_multiplier: float = 1.0
## True while this enemy is standing by: present, breathing, and taking no part.
## The second of the two flags that reverse the chase, and deliberately the same
## shape as [member _fleeing] rather than a state machine.
var _passive: bool = false
## Whether this enemy may swing at all. The fourth of the flags, and deliberately
## the same shape as the three above it: it is read at one place, it switches
## nothing off and it leaves the walk, the separation, the knockback and the world's
## slow motion exactly as they were. See [BlastReaction], which holds a man's knife
## down while he is running from a lit bomber and gives it straight back afterwards.
var _attacks_enabled: bool = true
var _hop_time: float = 0.0
var _hop_node: Node2D
## The hop's resting spot, captured the first time it is needed, so releasing an
## enemy always puts its artwork back exactly where the scene had it.
var _hop_rest: Vector2 = Vector2.ZERO
var _hop_rest_taken: bool = false


func _ready() -> void:
	# Hand the chase target to every aim pivot, so head and knife track it too.
	for node: Node in find_children("*", "LookAtTarget", true, false):
		var aim := node as LookAtTarget
		if aim != null:
			aim.target = _target

	if _target != null:
		_target_health = _target.get_node_or_null(NodePath(target_health_name)) as Health


func _physics_process(delta: float) -> void:
	# Standing by is checked before the target is, so an enemy put on hold in a
	# world with nobody to chase still hops rather than freezing outright.
	if _passive:
		_stand_by(delta)
		return

	if _target == null:
		return

	# The one line the retreat changes. A fleeing enemy is the same walk pointed the
	# other way, which is why it keeps its separation, its knockback and the world's
	# slow motion without any of that being written twice.
	var chase := global_position.direction_to(_target.global_position)
	if _fleeing:
		chase = -chase
	elif _charging:
		# The other line that changes it. A charge is the same walk again, pointed at a
		# place rather than at a person - see [method begin_charge] - so it keeps the
		# separation, the knockback and the world's slow motion for nothing, and the
		# swing below is left running so a player standing in the way is still cut.
		chase = global_position.direction_to(_charge_point)

	# The one place a walk can be bent into something other than a straight line at
	# whatever it is heading for. Asked after the destination has been decided, so a
	# steering component sees the direction the enemy would otherwise have taken and
	# is free to hand it straight back.
	if _steering != null and _steering.has_method(&"steer"):
		chase = _steering.steer(chase, delta)

	# Blended before normalising, so shouldering a neighbour changes the
	# direction of travel but never the speed - the chase stays constant-speed.
	var steer := chase + _separation_push() * separation_strength
	if steer.is_zero_approx():
		steer = chase

	# The hit reaction only ever scales the speed and adds a shove on top; the
	# exported `speed` itself is never written to, so a hit can never leave the
	# enemy permanently faster or slower. The world's slow motion is folded in the
	# same way and for the same reason - it is a multiplier read per frame, so an
	# enemy can never be left crawling once it is switched off, and it is the same
	# number the player is moving at.
	var move_speed := speed * WorldSlowdown.get_multiplier(self) * _flee_multiplier * _charge_multiplier
	var knockback := Vector2.ZERO
	if _hit_reaction != null:
		move_speed *= _hit_reaction.get_speed_multiplier()
		knockback = _hit_reaction.get_knockback()

	velocity = steer.normalized() * move_speed + knockback
	move_and_slide()
	# An enemy running for the edge of the map does not stop to stab anybody, and it
	# no longer has a knife to do it with. Skipping the whole routine is also what
	# stops a retreat that happens to pass close to the player costing them a heart.
	if not _fleeing and _attacks_enabled:
		_update_slash_visual(delta)


## Turns this enemy round: it heads away from the player at
## [param speed_multiplier] times its own speed and stops attacking.
##
## [b]It is only the movement.[/b] Being untouchable, dropping the knife and
## eventually disappearing are [EnemyEscape]'s, which is what calls this - so an
## enemy without that component simply never flees, and nothing about an ordinary
## enemy's behaviour is changed by any of it being here.
func begin_flight(speed_multiplier: float = 2.0) -> void:
	_fleeing = true
	_flee_multiplier = maxf(speed_multiplier, 0.0)


## Whether this enemy is running for the edge of the map.
func is_fleeing() -> bool:
	return _fleeing


## Sends this enemy at [param point] instead of at the player, at
## [param speed_multiplier] times its own speed.
##
## [b]It is only the destination and the pace.[/b] Deciding when to charge, how long
## to wait first, when the destination has been reached and what to do on arrival are
## all [BossCharge]'s - so an enemy nothing ever charges with simply never charges, and
## nothing about an ordinary enemy's behaviour is changed by any of it being here.
##
## Safe to call again mid-charge, which is how the attack moves from its planted
## wind-up to its run without a second call shape: the same point at a new pace.
##
## Fleeing wins over it, deliberately. An enemy sent home by the round's clock is
## going home whatever else was asked of it.
func begin_charge(point: Vector2, speed_multiplier: float = 1.0) -> void:
	_charging = true
	_charge_point = point
	_charge_multiplier = maxf(speed_multiplier, 0.0)


## Puts this enemy back on the player at its ordinary speed. Safe when it was never
## charging, so an attack called off half way through has nothing to check first.
func end_charge() -> void:
	_charging = false
	_charge_multiplier = 1.0


## Stops this enemy swinging, or lets it swing again.
##
## [b]Temporary by construction.[/b] Nothing is disabled and nothing is re-timed -
## the swing routine is simply not asked for while this is off, and the cooldown is
## cleared so the first swing after it comes back is immediate rather than owing
## time to a cooldown that ran while the man was busy running. Whatever turned it
## off is responsible for turning it back on.
func set_attacks_enabled(enabled: bool) -> void:
	if enabled == _attacks_enabled:
		return
	_attacks_enabled = enabled
	if not enabled:
		_slash_cooldown = 0.0


## Whether this enemy is currently allowed to swing.
func attacks_enabled() -> bool:
	return _attacks_enabled


## Whether this enemy is running at a place rather than at the player.
func is_charging() -> bool:
	return _charging


## The place it is running at. Meaningless while it is not charging.
func get_charge_point() -> Vector2:
	return _charge_point


## Stands this enemy down, or puts it back to work.
##
## While it is standing by it does not walk, does not steer round its neighbours
## and does not swing - it only hops where it is. [b]Nothing else about it is
## switched off[/b]: it can still be shot, still bleeds, still flashes and still
## dies, because the whole of standing by is this one flag being read at the top of
## [method _physics_process]. That is what makes releasing a group of them a single
## call each with nothing to put back.
##
## It is deliberately not a pause and not a time scale. The scene it is used for -
## a boss introduction - has the camera crossing the arena and the artwork
## breathing while it happens, so freezing the tree would be wrong; and a slowdown
## would be [WorldSlowdown], which is a different thing that the whole world reads
## and which the player is included in.
func set_passive(passive: bool) -> void:
	if passive == _passive:
		return
	_passive = passive

	if passive:
		# Knocked out of time per enemy rather than per frame, so a crowd hops
		# raggedly and each one keeps its own rhythm for as long as it is held.
		_hop_time = randf() * clampf(idle_hop_spread, 0.0, 1.0)
		velocity = Vector2.ZERO
		return

	_rest_hop()


## Whether this enemy is standing by, taking no part in the fight.
func is_passive() -> bool:
	return _passive


## What this enemy is chasing - the player. For a component that needs to measure
## against them rather than look them up itself.
func get_chase_target() -> Node2D:
	return _target


## One frame of standing by: rooted where it is, and hopping.
##
## The body is still stepped with a zero velocity rather than left untouched, so
## the enemy keeps its footing on whatever it is standing on and any shove from a
## [HitReaction] still settles rather than being held mid-push.
##
## The hop runs on the world's own slowed clock, so a group standing by during a
## slowed intro breathes at the speed of the scene around it.
func _stand_by(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	var node := _resolve_hop_node()
	if node == null or idle_hop_height <= 0.0 or idle_hop_speed <= 0.0:
		return

	_hop_time += delta * WorldSlowdown.get_multiplier(self) * idle_hop_speed
	# The absolute of a sine, so the artwork rises off the ground and comes back
	# down to it rather than sinking below it every other beat.
	var lift := absf(sin(_hop_time * PI)) * idle_hop_height
	node.position = _hop_rest - Vector2(0.0, lift)


## Puts the hopped artwork back down where the scene authored it.
func _rest_hop() -> void:
	var node := _resolve_hop_node()
	if node != null and _hop_rest_taken:
		node.position = _hop_rest


## The hopped node, found once. Its resting position is captured on the same first
## look, before anything has been written to it.
func _resolve_hop_node() -> Node2D:
	if _hop_node != null and is_instance_valid(_hop_node):
		return _hop_node

	_hop_node = get_node_or_null(idle_hop_path) as Node2D
	if _hop_node != null and not _hop_rest_taken:
		_hop_rest = _hop_node.position
		_hop_rest_taken = true
	return _hop_node


## Sums the surface normals of the other enemies this one shouldered into on its
## last move, which points away from the crowd.
##
## It reuses the collisions [method CharacterBody2D.move_and_slide] already
## found, so a hundred enemies cost nothing extra - there is no neighbour search
## and no additional physics query.
func _separation_push() -> Vector2:
	var push := Vector2.ZERO
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group(&"enemies"):
			push += collision.get_normal()
	# Zero stays zero: normalising a zero vector is safe and means "no crowd".
	return push.normalized()


## Swings the moment contact is made, then once per [member slash_interval] for
## as long as contact lasts. Leaving range rearms it, so the next touch is
## again immediate. Never blocks movement.
##
## The damage rides along with the swing rather than living in its own hitbox, so
## what the player sees and what actually hurts them are the same event and can
## never drift apart.
func _update_slash_visual(delta: float) -> void:
	var in_range := global_position.distance_to(_target.global_position) <= slash_range
	if not in_range:
		_slash_cooldown = 0.0
		return

	if _slash_cooldown <= 0.0:
		if _knife_slash != null:
			_knife_slash.slash()
		_deal_contact_damage()
		_slash_cooldown = slash_interval
	else:
		_slash_cooldown -= delta


## Aimed damage: the direction is the way the swing travelled, so the target's
## knockback and blood spray both point away from this enemy.
func _deal_contact_damage() -> void:
	if _target_health == null or contact_damage <= 0.0:
		return
	_target_health.take_damage(
		contact_damage, global_position.direction_to(_target.global_position))
