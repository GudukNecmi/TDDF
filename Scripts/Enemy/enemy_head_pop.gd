class_name EnemyHeadPop
extends Node
## Takes an enemy apart when it dies: the head comes off, the knife is thrown
## clear, and what is left tips over.
##
## The old death was a body that stopped and faded. This is what makes it read as
## something happening to a thing with weight - each piece separates, is thrown
## along the direction the killing blow was travelling, lands, and rolls to a stop
## while the body goes down behind it.
##
## The pieces are *reparented* rather than copied. The sprites that were on the
## enemy are lifted out, keeping their world transforms, and handed to
## [DeathDebris] nodes that own them from then on - so they are the same artwork
## the player was looking at a frame earlier, at the same size and the same
## variant, with nothing to keep in step. They have to leave the enemy because it
## is about to be frozen, faded and freed by [DeathFade], and they are supposed to
## outlive all three.
##
## The whole scene is meant to clear at once, so the pieces and the corpse are
## given the same lifetime: [member settle_time] and [member fade_time] here are
## the same numbers as [DeathFade]'s hold and fade on the enemy itself, and head,
## knife and body go together.
##
## The X marks are not this node's business. [EnemyDefeat] snaps them over the
## eyes on its own beat, and because they are a child of the head sprite they are
## carried along by the reparenting for free - so a rolling head keeps its dead
## eyes without either component knowing about the other.
##
## Everything here is decoration and it never touches the enemy's movement, its
## attack or its health. Switching this node off returns the old death exactly.

## Emitted for each piece as it comes off, with the node now carrying it.
signal piece_separated(piece: DeathDebris)

## Health whose death this reacts to.
@export var health_path: NodePath = ^"../Health"
## The head's own hitbox, watched so a death can tell whether the killing shot
## actually hit the head.
##
## Any hit this region reports is by definition a headshot - which is the whole of
## how the two deaths are told apart, and why nothing here has to inspect damage
## figures or multipliers. Left unset, every death uses the ordinary forces, which
## is exactly the behaviour this had before headshots were distinguished.
@export var head_hitbox_path: NodePath = ^"../HeadHitbox"
## The head artwork lifted off the body. Its children come with it, which is what
## carries the dead eyes along.
@export var head_path: NodePath = ^"../HeadAim/Head"
## The knife, thrown clear on the same blast. Optional - an enemy that carries
## nothing simply loses its head.
@export var knife_path: NodePath = ^"../KnifeAim/KnifeHand/Knife"
## The rest of the body, tipped over as the head leaves. Optional.
@export var body_path: NodePath = ^"../Visual"

@export_group("Separation")
## How hard the head is thrown upwards as it comes off. This is the "pop" - it is
## what makes the head leave rather than drop.
@export var separation_force: float = 260.0
@export var separation_force_variation: float = 0.35
## How hard it is thrown sideways along the direction the killing blow was
## travelling, so a shot from the left sends the head to the right.
@export var horizontal_force: float = 190.0
@export var horizontal_force_variation: float = 0.4
## Sideways speed given to a death with no recorded direction - a hit that said
## nothing, or the run's clock calling time. Signed at random, so those deaths do
## not all throw the head the same way.
@export var undirected_horizontal_force: float = 110.0
## How far below the separation point the ground is. Short, in keeping with how
## the rest of the game fakes height.
@export var drop_min: float = 26.0
@export var drop_max: float = 46.0

@export_group("Flight")
## Downward pull. Higher brings the head down sooner and keeps it close.
@export var gravity: float = 1500.0
## How much speed a bounce keeps.
@export_range(0.0, 1.0) var bounce: float = 0.42
## How quickly the roll bleeds off. Higher stops the head sooner, which is the
## main dial for "the head must not travel excessively far".
@export var ground_friction: float = 2.6
## How long a piece lies there before it fades, and how long that takes. Match
## these to [DeathFade]'s hold and fade on the same enemy and the head, the knife
## and the body all disappear together.
@export var settle_time: float = 0.7
@export var fade_time: float = 1.2
## Colour a piece is left in once it is off. Slightly drained, so a head lying on
## the floor does not look fresher than the body it came from. White leaves the
## artwork exactly as drawn.
@export var head_tint := Color(0.86, 0.74, 0.72)
## How long a piece keeps the white of the blow that took it off, in seconds.
##
## The head is lit by [HitReaction] like everything else, and used to be wiped
## clean on the frame it separated - which is a frame before anything is drawn, so
## the shot that took the head off was the one shot that never flashed. Holding it
## briefly is what makes a headshot land: the head lights up, leaves, and cools on
## its way out.
##
## 0 clears it the instant it comes off, which is what this did before.
@export var impact_flash_time: float = 0.09
## How long the white then takes to fade off the piece. Slightly longer than the
## hold, so it cools rather than snapping back - a head rolling across the floor
## must not still be glowing.
@export var impact_flash_fade: float = 0.14

@export_group("Headshot")
## Whether a kill that landed on the head throws it differently from a kill that
## landed on the body. Off, every death uses the ordinary forces above.
@export var headshot_separation: bool = true
## How hard a shot head is thrown upwards as it comes off. Above the ordinary
## [member separation_force]: the round did the work, so the head leaves rather
## than falls.
@export var headshot_force: float = 330.0
## How hard it is thrown along the way the round was travelling - a shot from the
## left sends it right.
##
## [b]It is a punch, not a launch.[/b] The head should cross a short distance and
## come down, so this is deliberately close to the ordinary figure; the difference
## the player reads is in how it leaves and how far it rolls, not in it sailing
## across the arena.
@export var headshot_horizontal_force: float = 240.0
## Spread on both of those, as a fraction, so no two heads leave identically.
@export var headshot_force_variation: float = 0.3
## Downward pull on a shot head. Higher than the ordinary one, which is what keeps
## the extra speed from turning into extra distance: it leaves faster and comes
## down sooner.
@export var headshot_gravity: float = 1750.0
## How much speed its bounce keeps.
@export_range(0.0, 1.0) var headshot_bounce: float = 0.34
## How quickly the roll bleeds off once it is down. This is the dial for how far a
## shot head rolls after landing - higher stops it sooner.
@export var headshot_ground_friction: float = 2.1
## How far below the separation point its ground is.
@export var headshot_drop_min: float = 30.0
@export var headshot_drop_max: float = 52.0

@export_group("Knife")
## How hard the knife is thrown up as it leaves the hand. Lighter than the head,
## so it goes further for less.
@export var knife_separation_force: float = 200.0
## How hard it is thrown along the blast.
@export var knife_horizontal_force: float = 240.0
@export var knife_force_variation: float = 0.45
## How far below its starting point the knife's ground is.
@export var knife_drop_min: float = 20.0
@export var knife_drop_max: float = 40.0
## How quickly it stops sliding. Lower than the head's, so a knife skitters
## further than a head rolls.
@export var knife_ground_friction: float = 1.8

@export_group("Knife drop")
## Chance a dropped knife lands whole and can be picked up, 0 to 1. The rest of the
## time it comes apart where it falls and is worth nothing.
##
## [b]It is rolled once, at the moment the knife leaves the hand[/b] - see
## [method drop_knife] - so what the player will find on the floor is settled before
## it has even landed, and a knife lying in the sand is never still deciding what it
## is.
@export_range(0.0, 1.0) var knife_intact_chance: float = 0.4
## The pickup hung on a knife that landed whole, which is what makes it collectable.
## Left unset an intact knife simply lies there as scenery.
@export var knife_pickup_scene: PackedScene
## How a knife that landed broken comes apart. Left unset a broken knife is removed
## without pieces.
@export var knife_break: BreakProfile

@export_group("Body")
## Whether the body is tipped over as the head leaves.
@export var tip_body: bool = true
## Angle the body falls to, in degrees. Signed to match the way the head went.
@export var tip_degrees: float = 74.0
@export var tip_time: float = 0.34
## How far the body slumps as it goes down.
@export var tip_offset := Vector2(0.0, 4.0)

@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _head: Node2D = get_node_or_null(head_path) as Node2D
@onready var _knife: Node2D = get_node_or_null(knife_path) as Node2D
@onready var _body: Node2D = get_node_or_null(body_path) as Node2D
@onready var _head_hitbox: Hitbox = get_node_or_null(head_hitbox_path) as Hitbox

var _last_hit_direction := Vector2.ZERO
## Set as the head's own hitbox reports a hit, and read by the damage that follows
## it an instant later. The pair is exact because a hitbox announces itself and
## then applies its damage in the same call.
var _head_hit_pending: bool = false
## Whether the last hit to land was on the head. The hit that lands last is the
## hit that killed, so this is what the death reads.
var _last_hit_was_head: bool = false
var _popped: bool = false
## Whether this enemy's knife has already been let go of. A man can die during his
## own retreat, or be shot as he lies there having given up, so two of the three
## ways a knife is dropped can very easily both fire on the same body - and only one
## of them may put a knife on the floor.
var _knife_dropped: bool = false


func _ready() -> void:
	if _head_hitbox != null:
		_head_hitbox.hit_landed.connect(_on_head_hit)
	if _health == null:
		return
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


## The head's region was struck. Only noted here - the damage that follows in the
## same call is what decides whether it mattered.
func _on_head_hit(_damage: float, _hit_direction: Vector2, _hit_position: Vector2) -> void:
	_head_hit_pending = true


## [signal Health.died] carries no direction of its own and no notion of where it
## was hit, so both are remembered as each hit lands - the hit that lands last is
## the one that killed.
func _on_damaged(_amount: float, hit_direction: Vector2) -> void:
	if not hit_direction.is_zero_approx():
		_last_hit_direction = hit_direction.normalized()
	# Consumed rather than merely read: the flag belongs to this one hit, so a body
	# shot landing after a head shot must not inherit it.
	_last_hit_was_head = _head_hit_pending
	_head_hit_pending = false


## Calls this death off before it happens, for a killer that is presenting the body
## some other way.
##
## [b]It is the same guard a second death signal already runs into[/b], set from
## outside instead of from in here - so nothing about the sequence is switched off
## conditionally and there is no second path through this file. An explosion is the
## one caller today: a man caught in a blast is torn into [Explosion]'s gore where
## he stood, and a head and a knife arriving out of the same body a frame later
## would be that death played twice.
##
## Has no effect once the head is already off, and none at all on an enemy nothing
## calls it on - which is every ordinary death.
func suppress() -> void:
	_popped = true


func _on_died() -> void:
	# Guarded because a second death signal, however it arrived, must not tear a
	# second head off a body that no longer has one.
	if _popped:
		return
	_popped = true

	var aim := _throw_direction()
	_tip_body(aim)
	_separate(aim)


## The same blast, applied to a lighter object: the knife is thrown along the way
## the head went so the whole death reads as one impact, but with its own forces
## so it skitters rather than rolls.
func _knife_throw(head_throw: float) -> float:
	var side := 1.0 if head_throw >= 0.0 else -1.0
	return side * knife_horizontal_force


## The way the damage was travelling, or a random side when nothing said. Only
## the sign of the horizontal component is used - the head is thrown along the
## ground, not into the screen - so a hit from any angle still sends it the way
## the shot was going.
func _throw_direction() -> float:
	if _last_hit_direction.is_zero_approx() or is_zero_approx(_last_hit_direction.x):
		return (1.0 if randf() < 0.5 else -1.0) * undirected_horizontal_force
	return _last_hit_direction.x * horizontal_force


## Reparenting is deferred because a death very often arrives from inside the
## physics server's own overlap callback, and moving a node between parents while
## the tree is being flushed is not allowed there.
func _separate(horizontal: float) -> void:
	if not is_inside_tree():
		return
	_do_separate.call_deferred(horizontal)


## A head that was shot off is thrown by its own set of forces; everything else -
## the knife, the body going down, a death from anything but a headshot - is
## untouched by this and behaves exactly as it always did.
func _do_separate(horizontal: float) -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	if container == null:
		return

	if _is_headshot():
		var punch := signf(horizontal) * headshot_horizontal_force
		if is_zero_approx(punch):
			punch = headshot_horizontal_force
		_throw(container, _head, "SeveredHead",
			headshot_force, headshot_force_variation,
			punch, headshot_force_variation,
			headshot_gravity, headshot_bounce, headshot_ground_friction,
			headshot_drop_min, headshot_drop_max)
	else:
		_throw(container, _head, "SeveredHead",
			separation_force, separation_force_variation,
			horizontal, horizontal_force_variation,
			gravity, bounce, ground_friction, drop_min, drop_max)

	# The knife goes through the drop below rather than being thrown here, so a knife
	# that comes off a corpse is decided by exactly the roll a knife thrown down by a
	# man giving up or running away is - one drop, written in one place.
	drop_knife(_knife_throw(horizontal))


## Lets go of the enemy's knife. [b]This is the whole of the knife drop, and every
## way of losing one comes through here[/b] - the man dies, the man gives up, the
## man turns and runs. Each of those calls this and nothing else, so the roll below,
## the throw and what is left on the floor exist exactly once and cannot drift apart
## between the three.
##
## [b]The roll is made here, now.[/b] Which of the two things the player is going to
## find is decided at the instant the knife leaves the hand rather than when it
## lands, so nothing about a knife lying in the sand is still being worked out and
## nothing is rolled twice for one drop.
##
## Either way it is the same throw a death always performed: the knife is lifted
## out, handed to a [DeathDebris] and left on the floor by exactly the code that
## already did it - see [method _throw] - so a dropped knife lands and skitters
## identically however it was lost.
##
## [param horizontal] is which way it is thrown, in pixels per second, and is
## signed - negative throws it left. 0 picks a side at random, which is right for a
## knife nobody knocked out of a hand.
##
## Returns whether there was one to drop, and it can only ever be done once.
func drop_knife(horizontal: float = 0.0) -> bool:
	if _knife_dropped or not is_inside_tree():
		return false
	if _knife == null or not is_instance_valid(_knife):
		return false
	_knife_dropped = true

	var sideways := horizontal
	if is_zero_approx(sideways):
		sideways = _knife_throw(1.0 if randf() < 0.5 else -1.0)

	# Deferred for the same reason a death's is: this can be reached from inside a
	# physics callback, where reparenting is refused. The answer travels with it, so
	# the roll stays on the frame the knife was let go of.
	_drop_knife_now.call_deferred(sideways, randf() < knife_intact_chance)
	return true


func _drop_knife_now(sideways: float, intact: bool) -> void:
	var container := get_tree().current_scene if is_inside_tree() else null
	var knife := _knife
	# Given up before either path runs, so nothing can reach for it afterwards.
	_knife = null
	if container == null or knife == null or not is_instance_valid(knife):
		return

	# A dropped or thrown knife casts no shadow of its own - small ground props
	# are undecorated in this game - and cutting it loose here rather than
	# merely disabling it is what stops it: left in place, [ShadowCaster]
	# would find no group to join the instant this knife is reparented into
	# its own [DeathDebris] a few lines down and simply make one of its own -
	# see [method ShadowCaster.resolve_group] - which is exactly the shadow
	# this is meant to prevent from ever appearing.
	_strip_knife_shadow(knife)

	if not intact:
		_break_knife(container, knife, sideways)
		return

	var carrier := _throw(container, knife, "DroppedKnife",
		knife_separation_force, knife_force_variation,
		sideways, knife_force_variation,
		gravity, bounce, knife_ground_friction, knife_drop_min, knife_drop_max,
		false)
	if carrier == null:
		return

	# It is not wreckage - it is something to come back for - so it never settles
	# into a fade. It lies where it stopped until the player picks it up or the
	# round is rebuilt around it.
	carrier.settle_time = 0.0
	carrier.fade_time = 0.0
	if knife_pickup_scene != null:
		carrier.add_child(knife_pickup_scene.instantiate())


## Cuts loose whatever shadow the knife was casting while it was still in a
## hand, before it is ever reparented into a [DeathDebris] of its own.
##
## [b]It is freed rather than merely disabled[/b], because a disabled
## [ShadowCaster] still resolves a group for itself the moment it re-enters the
## tree under its new parent - and finding none to join there, since a lone
## knife on the ground stands under nothing but its own [DeathDebris], it would
## make one of its own regardless of whether it draws into it. Freeing it
## outright is what stops that group from ever being made at all, which is the
## whole of "do not generate a new shadow for the dropped knife".
func _strip_knife_shadow(knife: Node2D) -> void:
	for child: Node in knife.get_children():
		var caster := child as ShadowCaster
		if caster != null:
			knife.remove_child(caster)
			caster.queue_free()


## The knife hits the sand and comes apart. The pieces are its own artwork cut up
## and thrown by [BreakProfile], so a broken knife is made of the variant the enemy
## was actually carrying - and being pieces rather than a knife, there is nothing
## there to pick up.
func _break_knife(container: Node, knife: Node2D, sideways: float) -> void:
	var sprite := knife as Sprite2D
	if knife_break != null and sprite != null:
		knife_break.shatter(sprite, container, Vector2(sideways, 0.0))
	knife.queue_free()


## Whether this death was a shot to the head, and whether that is being treated
## differently at all.
func _is_headshot() -> bool:
	return headshot_separation and _last_hit_was_head


## Lifts one sprite out of the enemy and into the running scene, keeping exactly
## the world transform it had - so nothing jumps on the frame it comes off - and
## hands it to a [DeathDebris] that owns it from then on.
##
## One routine for every piece, because the only difference between a head, a
## knife and a head that was shot off is the numbers each is handed: a third piece
## later is another call, not another block of this.
##
## Returns the carrier, so a caller that wants to go on and do something with what
## it threw - hang a pickup on a knife that landed whole, leave it there for good -
## has it to hand without searching for it.
func _throw(
	container: Node,
	piece: Node2D,
	piece_name: String,
	lift_force: float,
	lift_variation: float,
	horizontal: float,
	horizontal_variation: float,
	piece_gravity: float,
	piece_bounce: float,
	friction: float,
	drop_low: float,
	drop_high: float,
	cools_hit_flash: bool = true
) -> DeathDebris:
	if piece == null or not is_instance_valid(piece):
		return null

	var carrier := DeathDebris.new()
	carrier.gravity = piece_gravity
	carrier.bounce = piece_bounce
	carrier.ground_friction = friction
	carrier.settle_time = settle_time
	carrier.fade_time = fade_time

	var at := piece.global_position
	var turn := piece.global_rotation
	var size := piece.global_scale

	container.add_child(carrier)
	# Named after it is in the tree, so the name survives rather than being
	# replaced by the generated one a node built in code otherwise gets.
	carrier.name = piece_name
	carrier.global_position = at

	piece.reparent(carrier, false)
	# The sprite keeps its own drawing offset and scale; the carrier is what turns
	# and travels, so the piece spins about where it left the body rather than
	# about the corner of its texture.
	piece.position = Vector2.ZERO
	piece.rotation = turn
	piece.scale = size
	piece.modulate = head_tint
	if cools_hit_flash:
		_cool_hit_flash(piece, carrier)
	else:
		_clear_hit_flash_immediately(piece)
	carrier.reset_physics_interpolation()

	var lift := -lift_force * (1.0 + randf_range(-lift_variation, lift_variation))
	var sideways := horizontal * (1.0 + randf_range(
		-horizontal_variation, horizontal_variation))
	carrier.launch(Vector2(sideways, lift), randf_range(drop_low, drop_high))

	piece_separated.emit(carrier)
	return carrier


## The killing blow lit the sprite white through [HitReaction]'s flash shader, and
## the component that eases that back off is frozen with the rest of the corpse a
## frame later - so the piece has to cool itself.
##
## [b]It is held before it is cleared[/b], which is the whole of what makes a
## headshot read as one: wiping it on the frame the head separates happens before
## anything has been drawn, so the shot that took the head off would be the only
## shot in the fight that never flashed. It still always ends at zero, so a head
## can never be left rolling across the floor as a white blob.
##
## The fade is driven by the carrier rather than the piece, because the carrier is
## what owns the piece from here on and outlives every part of the corpse.
##
## The material was already duplicated per character by [HitReaction], so writing
## to it reaches this enemy and no other.
func _cool_hit_flash(piece: Node2D, carrier: DeathDebris) -> void:
	var material := piece.material as ShaderMaterial
	if material == null:
		return

	if impact_flash_time <= 0.0 and impact_flash_fade <= 0.0:
		material.set_shader_parameter(&"flash", 0.0)
		return

	# Set rather than assumed: the piece must light up even when what killed the
	# enemy left no flash of its own to inherit.
	material.set_shader_parameter(&"flash", 1.0)
	var tween := carrier.create_tween()
	tween.tween_interval(maxf(impact_flash_time, 0.0))
	tween.tween_method(
		func(amount: float) -> void:
			material.set_shader_parameter(&"flash", amount),
		1.0, 0.0, maxf(impact_flash_fade, 0.0001))


## Wipes the killing blow's white off a piece outright, with no hold and no
## fade - [param cools_hit_flash] false's alternative to [method _cool_hit_flash].
##
## [b]For a piece that must never be seen wearing it at all.[/b] A dropped
## knife is a prop lying in the sand from the instant it lands, not a wound
## reading as an impact the way a severed head is, and it must always show its
## own normal colours - never the enemy's temporary white hit-flash, however
## the enemy happened to die or however recently it had been shot. Where
## [method _cool_hit_flash] deliberately forces the flash on before easing it
## off, this only ever takes it down.
func _clear_hit_flash_immediately(piece: Node2D) -> void:
	var material := piece.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"flash", 0.0)


## The body falls the same way the head went, so the two read as one event rather
## than two things that happened to coincide.
func _tip_body(horizontal: float) -> void:
	if not tip_body or _body == null:
		return

	var side := 1.0 if horizontal >= 0.0 else -1.0
	var rest := _body.position
	var tween := _body.create_tween().set_parallel(true)
	tween.tween_property(_body, "rotation", deg_to_rad(tip_degrees) * side,
		maxf(tip_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_body, "position", rest + tip_offset,
		maxf(tip_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
