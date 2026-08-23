class_name Health
extends Node
## A simple hit-point pool. Drop it into any character that should be
## destroyable; hitboxes report damage here rather than killing directly.

signal died
## Emitted on every change to the pool, whatever moved it - damage, healing, or
## the ceiling itself being raised by an upgrade. A UI should follow this rather
## than the individual events, so it cannot miss one and cannot drift.
signal health_changed(current: float, maximum: float)
## Emitted only when health is restored, with what was actually put back. A
## restore that finds the pool already full changes nothing and stays silent.
signal healed(amount: float, current: float)
## Emitted on every hit that lands, before any death is processed.
## [param hit_direction] is the direction the damage was travelling, so a
## reaction can push away from it. It is [constant Vector2.ZERO] when whatever
## dealt the damage did not say.
signal damaged(amount: float, hit_direction: Vector2)
## Emitted when an invulnerability window opens and closes. Only ever fires when
## [member invulnerable_seconds] is above 0.
signal invulnerability_changed(invulnerable: bool)

@export var max_health: float = 100.0
## Frees the node this component is parented to when the pool runs out. Turn it
## off for anything that needs to play a death out before disappearing - see
## [DeathFade], which then owns the freeing.
@export var free_owner_on_death: bool = true
## Grace period after a hit lands, in seconds, during which further damage is
## ignored outright: no health lost, no [signal damaged], and so no reaction,
## sound or blood either.
##
## 0 disables it entirely, which is the default and what every enemy uses - so
## a shotgun's worth of pellets all land as they always did. It exists for the
## player, where one contact must cost exactly one heart.
@export var invulnerable_seconds: float = 0.0

var _current: float
var _invulnerable_left: float = 0.0
var _removed: bool = false
## The ceiling the character was authored with, captured the first time anything
## moves it. Below 0 while nothing has, which reads as "the ceiling is still the
## authored one".
##
## [b]It is what lets a later system build off the base rather than off whatever the
## last multiplier left behind.[/b] A mini boss's pool is its rung times the enemy
## scene's own number - see [method MiniBossDirector.get_boss_health_multiplier] -
## and the spawner has already laid the world's extra difficulty on the same
## instance by then, so without this the boss would silently carry a multiplier it
## is not supposed to have.
var _authored_max_health: float = -1.0


func _ready() -> void:
	_current = max_health
	set_physics_process(invulnerable_seconds > 0.0)


func _physics_process(delta: float) -> void:
	if _invulnerable_left <= 0.0:
		return

	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _invulnerable_left <= 0.0:
		invulnerability_changed.emit(false)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Seconds of grace left, for a flicker or a UI readout to follow.
func get_invulnerable_time_left() -> float:
	return _invulnerable_left


func get_current() -> float:
	return _current


func get_max() -> float:
	return max_health


## The ceiling the scene was authored with, whatever has been laid on top of it
## since. The live ceiling for a pool nothing has scaled, so it is always safe to
## build from.
func get_authored_max_health() -> float:
	return max_health if _authored_max_health < 0.0 else _authored_max_health


## Multiplies the ceiling, remembering the authored one first.
##
## What a difficulty curve raises a pool with - see [method RoundScaling.apply_to] -
## rather than writing [member max_health] directly, so the number the character was
## built with is still askable afterwards.
func scale_max_health(multiplier: float, fill: bool = false) -> void:
	set_max_health(max_health * maxf(multiplier, 0.0), fill)


func is_alive() -> bool:
	return _current > 0.0


func is_full() -> bool:
	return _current >= max_health


## Puts [param amount] back, up to the ceiling, and returns what actually went
## in. It deliberately works from an empty pool as well as a partial one: a
## revival is healing a corpse, and routing it through the same call means the UI
## following [signal health_changed] needs no idea that a death happened.
func heal(amount: float = 1.0) -> float:
	if amount <= 0.0:
		return 0.0

	var before := _current
	_current = minf(_current + amount, max_health)
	var restored := _current - before
	if restored <= 0.0:
		return 0.0

	# A pool brought back from empty is a live character again, so whatever ended
	# the last one stops being the answer. This is what keeps the player's revival
	# from carrying a stale verdict into their next death.
	if _current > 0.0:
		_removed = false

	healed.emit(restored, _current)
	health_changed.emit(_current, max_health)
	return restored


## Fills the pool and returns what that took. Safe to call on a pool that is
## already full, where it does nothing.
func restore_full() -> float:
	return heal(max_health - _current)


## Forces the pool to [param value], clamped to the ceiling, and announces it.
##
## [b]Not a hit and not a heal.[/b] Neither [signal damaged] nor [signal healed]
## is emitted, so nothing reacts: no flash, no blood, no knockback, no death. That
## is the point of it - this is for putting a pool back where it already was, not
## for changing it during play. Ordinary play only ever goes through
## [method take_damage] and [method heal]; this is what a carried pool is restored
## through when the world is rebuilt around a player mid-run, exactly as
## [method AmmoReserve.set_current] is for their ammunition.
func set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_health)
	if is_equal_approx(clamped, _current):
		return
	_current = clamped
	if _current > 0.0:
		_removed = false
	health_changed.emit(_current, max_health)


## Moves the ceiling, for an upgrade that buys the player another heart.
##
## [param fill] decides what happens to the pool underneath: true takes them to
## the new maximum, which is what buying health should feel like, false leaves
## what they had and only clamps it if the ceiling came down. Either way the
## change is announced, so a UI built from the maximum rebuilds itself.
func set_max_health(value: float, fill: bool = true) -> void:
	# Captured before the ceiling moves, at the single point every mover funnels
	# through, so no caller has to remember to record it.
	if _authored_max_health < 0.0:
		_authored_max_health = max_health
	max_health = maxf(value, 0.0)
	_current = max_health if fill else minf(_current, max_health)
	health_changed.emit(_current, max_health)


## [param hit_direction] is optional, so anything that damaged this before still
## calls it exactly the same way.
##
## A hit arriving inside the grace window is dropped here, at the single point
## every damage source already funnels through, rather than each source having to
## know about invulnerability.
func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if _current <= 0.0 or is_invulnerable():
		return

	if invulnerable_seconds > 0.0:
		_invulnerable_left = invulnerable_seconds
		invulnerability_changed.emit(true)

	_current = maxf(_current - amount, 0.0)
	# Announced before the hit is, so anything reading the pool from inside a
	# [signal damaged] handler - the screen blood picking which stage to play -
	# already sees what is left rather than what there was.
	health_changed.emit(_current, max_health)
	damaged.emit(amount, hit_direction)
	if _current > 0.0:
		return

	died.emit()
	if free_owner_on_death:
		var host := get_parent()
		if host != null:
			host.queue_free()


## Empties the pool now, through the normal death path - so [signal damaged],
## [signal died], the blood drop and the death fade all still happen exactly as
## they would from a killing shot.
##
## Any open grace window is dropped first: this is the game deciding the character
## is finished, not a hit that could be shrugged off. Used by the run's clock
## running out, which defeats whatever is still standing rather than deleting it.
func kill(hit_direction: Vector2 = Vector2.ZERO) -> void:
	if _current <= 0.0:
		return
	_invulnerable_left = 0.0
	take_damage(_current, hit_direction)


## Takes the character off the board rather than killing it.
##
## Mechanically this [i]is[/i] [method kill]: the same signals fire, in the same
## order, carrying the same values, so the death plays out identically - the same
## X marks, the same beat, the same smoke, the same fade and the same freeing.
## Nothing is switched off and nothing has to be re-timed.
##
## The single difference is that the death is marked, and anything that cares can
## ask [method was_removed] which of the two it was. That is deliberately the only
## mechanism: rather than each system being told to keep quiet, the systems that
## should not answer a removal check for themselves, so adding another one later
## costs nothing here.
##
## This is what the run's clock running out uses. Those enemies are not beaten by
## the player - they are cleared off the field - so they are worth nothing, and
## [BloodEmitter] reads exactly this to decide not to spill for them.
func remove(hit_direction: Vector2 = Vector2.ZERO) -> void:
	if _current <= 0.0:
		return
	# Set before the pool is emptied, so it is already true by the time
	# [signal damaged] and [signal died] reach their listeners and every one of
	# them sees the same answer.
	_removed = true
	kill(hit_direction)


## Whether the death this pool has just been through was a removal rather than a
## kill. False for a character that is alive, and false for one killed normally.
func was_removed() -> bool:
	return _removed
