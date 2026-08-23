class_name Hitbox
extends Area2D
## A damageable region on a character. Forwards incoming damage to a [Health]
## component, scaled by [member damage_multiplier] - that multiplier is the
## whole headshot mechanic.
##
## Several hitboxes can share one Health node, which is how a body hit and a
## head hit can hurt by different amounts.
##
## It is also where the damage figure comes from, because this is the one place
## that knows both what actually landed - after the multiplier, so a headshot
## reports the headshot's number - and where on the body it landed. [Health]
## knows the first but not the second, and whatever fired knows neither.

## Emitted as a hit lands on [b]this[/b] region, before the damage is applied.
##
## [Health] is told what landed but never where, because several hitboxes share
## one Health and it would have to be told twice over. This is how something that
## cares *which part* was hit finds out: it listens to the region it cares about,
## and any hit it reports is by definition a hit on that region. [EnemyHeadPop]
## uses it for exactly that - a head that was shot comes off differently from a
## head whose body was shot.
##
## It is emitted before the damage so a listener can note the hit even when that
## hit is the one that kills.
signal hit_landed(damage: float, hit_direction: Vector2, hit_position: Vector2)

## 1.0 for an ordinary body part, higher for weak spots.
@export var damage_multiplier: float = 1.0
## Health component that owns the hit points.
@export var health_path: NodePath = ^"../Health"

@export_group("Damage numbers")
## Whether a hit on this region throws a figure up. Off on a region that should
## take damage quietly.
@export var shows_damage_numbers: bool = true
## Nudge applied to where the figure appears, in world pixels. Up, so the number
## clears the blood coming out of the same hit.
@export var damage_number_offset := Vector2(0.0, -10.0)

@onready var _health: Health = get_node_or_null(health_path) as Health

var _numbers: DamageNumbers


## [param hit_direction] is passed straight through untouched - only the damage
## is scaled here. It stays optional so older callers are unaffected.
##
## [param hit_position] is where the blow actually landed, for whatever wants to
## draw something there. Left out, the hitbox's own position stands in, which is
## already the right part of the body - the head hitbox is at the head - so a
## caller that cannot say exactly where still gets a figure in a sensible place.
##
## [param critical] lets the *attack* declare itself a critical hit, for the cases
## the multiplier alone cannot express. The multiplier is still the mechanic - a
## headshot is a headshot because this hitbox scales it - and this only adds the
## other way a hit can be a big one: a shot that was empowered before it arrived,
## like the pair the coin sends out. It reads through to the damage figure exactly
## as a hit heavy enough to qualify on its own does, so there is one critical hit
## in the game and two ways of earning it.
func take_hit(
	damage: float,
	hit_direction: Vector2 = Vector2.ZERO,
	hit_position: Vector2 = Vector2.INF,
	critical: bool = false
) -> void:
	if _health == null:
		return

	var dealt := damage * damage_multiplier
	var at := hit_position if hit_position.is_finite() else global_position
	# Announced, like the number, *before* the damage lands - the damage can kill,
	# and killing can free this node inside the same call.
	hit_landed.emit(dealt, hit_direction, at)
	if shows_damage_numbers:
		_pop_number(dealt, at + damage_number_offset, critical)

	_health.take_damage(dealt, hit_direction)


## Looked up lazily and re-looked-up if it goes away, matching how every other
## cross-branch lookup in the project finds its counterpart.
func _pop_number(amount: float, at: Vector2, critical: bool) -> void:
	if _numbers == null or not is_instance_valid(_numbers):
		_numbers = DamageNumbers.get_active(self)
	if _numbers != null:
		_numbers.pop(amount, at, critical)
