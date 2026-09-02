class_name BanditFormation
extends Node
## Keeps a crowd of Bandits from stacking into one blob on the player: each one
## claims a loose position somewhere around them and steers towards it instead
## of straight at their feet, so an attacking crowd reads as several men closing
## in from several sides rather than one shape converging on a point.
##
## [b]It is the enemy's one steering hook, exactly like every other reaction in
## the game.[/b] See [member Enemy.steering_path] - [method steer] receives the
## direction the ordinary chase was about to take and hands back the direction
## actually walked, so knockback, the crowd separation, the world's slow motion
## and every other part of [Enemy]'s movement are entirely untouched. It is
## meant to sit as the innermost link in the chain - see
## [member BlastReaction.inner_steering_path], which is asked first and then
## bent further for a burning fuse - so a man avoiding a bomb and finding his
## own side of the player at the same time needs nothing wired here at all.
##
## [b]A slot, not a formation.[/b] Nothing here draws a ring or hands out
## bearings on a clock face. Each bandit periodically rolls a fresh angle
## around the player - biased away from wherever the crowd is already
## thickest, with randomness on both the angle and the radius - so the shape a
## crowd makes is organic and different every time it is looked at rather than
## a mathematically even circle. See [method _pick_slot].
##
## [b]Cheap by construction, and that is the whole point.[/b] A bandit only
## works out a new slot once every [member reposition_interval] seconds,
## staggered per instance so a whole crowd never recomputes on the same frame;
## between times it simply steers at the same remembered point, which moves
## with the player for free because it is stored as an angle and a radius
## around them rather than as a fixed world position. "Is anywhere already
## claimed near here" is answered against a small shared registry - one entry
## per living bandit, pruned as they go - rather than a search over the whole
## crowd, so the cost of a slot does not grow with how many men are in it.
##
## [b]Attack pressure is deliberately not gated on the formation.[/b] The
## moment a bandit is within [member engage_radius] of the player it simply
## chases them directly, slot or no slot - which is what lets the man in front
## swing while the rest are still finding a side to come in from, rather than
## the whole crowd waiting on one man's position before anybody may close in.

## How far from the player a claimed slot sits, in pixels, before
## [member radius_spread] is rolled on top. The "surrounding radius" dial.
@export var surround_radius: float = 240.0
## How much a slot's own radius is allowed to vary from [member surround_radius],
## in pixels, rolled once per slot. What keeps the ring from reading as a ring.
@export var radius_spread: float = 120.0
## How often a bandit re-rolls its slot, in seconds. Low makes the crowd chase
## the player's movement more closely; high makes a slot feel more committed to.
## Staggered per instance with [member reposition_jitter] so a crowd never all
## recomputes on the same frame.
@export var reposition_interval: float = 1.4
## Fraction of [member reposition_interval] a bandit's own timer is jittered by,
## rolled once as it starts and once again every time it re-rolls.
@export_range(0.0, 1.0) var reposition_jitter: float = 0.35
## Once this close to the player, a bandit abandons its slot and simply attacks -
## the "attack pressure" the brief asks for, so the crowd's front rank is never
## held up waiting for the rest to find a side.
@export var engage_radius: float = 100.0
## How many candidate angles are rolled for a new slot, the best of which is
## kept - see [method _pick_slot]. Higher spreads a crowd more evenly for a
## little more cost; the search is still a handful of dot products against a
## small shared list, never a physics query.
@export_range(1, 12, 1) var slot_candidates: int = 5
## How far downstream a slot claim clears another one, in world pixels, before
## the candidate angle scoring skips a bandit entirely. Keeps the search cheap:
## a man three screens away tells the score nothing worth weighing.
@export var awareness_radius: float = 1400.0
## Blends how sharply a bandit turns onto its slot direction, in the same
## exponential-smoothing units used across the project. Lower reads as looser
## and more organic; higher snaps onto the new heading at once.
@export var turn_speed: float = 6.0
## Steering this one wraps, asked first and handed the result - the same
## composition [BlastReaction] itself offers through
## [member BlastReaction.inner_steering_path], for a bandit that has both.
## Left unset the ordinary chase direction is bent directly.
@export var inner_steering_path: NodePath

## Every living bandit's current slot angle, in radians, keyed by player
## instance id and then by bandit node. A registry rather than a per-bandit
## search: claiming a slot writes one entry here and releasing one erases it,
## so scoring a new candidate is a walk over however many bandits are actually
## minding the same player rather than a query over the whole enemy group.
static var _slots: Dictionary = {}

@onready var _enemy: Node = get_node_or_null(^"..")
@onready var _inner: Node = get_node_or_null(inner_steering_path)

var _player: Node2D
var _angle: float = 0.0
var _radius: float = 0.0
var _timer: float = 0.0
var _heading: Vector2 = Vector2.ZERO
var _has_heading: bool = false


func _ready() -> void:
	# Staggered from the first roll onward, so a whole ambush placed in one
	# breath does not all pick its first slot on the same frame either.
	_timer = reposition_interval * randf_range(0.0, maxf(reposition_jitter, 0.05))


func _exit_tree() -> void:
	_release_slot()


## The enemy's one steering hook - see [member Enemy.steering_path]. [param chase]
## is the direction the ordinary chase was about to walk in; what comes back is
## what is actually walked.
func steer(chase: Vector2, delta: float) -> Vector2:
	var walk := chase
	if _inner != null and _inner.has_method(&"steer"):
		walk = _inner.steer(chase, delta)

	var host := _enemy as Node2D
	if host == null:
		return walk

	_resolve_player()
	if _player == null or not is_instance_valid(_player):
		return walk

	var to_player := _player.global_position - host.global_position
	var distance := to_player.length()

	# Close enough to fight: the slot stops mattering and the man in front
	# simply attacks, exactly as an ordinary enemy would - see [member engage_radius].
	if distance <= engage_radius:
		_release_slot()
		return walk

	_timer -= delta
	if _timer <= 0.0 or not _has_heading:
		_pick_slot(host)
		_timer = reposition_interval * (1.0 + randf_range(-reposition_jitter, reposition_jitter))

	var target := _player.global_position + Vector2.RIGHT.rotated(_angle) * _radius
	var wanted := host.global_position.direction_to(target)
	if wanted.is_zero_approx():
		return walk

	# Eased rather than assigned, so a slot that has just changed is turned onto
	# smoothly instead of snapping the walk to a new heading outright - which is
	# most of what keeps the crowd reading as organic rather than mechanical.
	if not _has_heading:
		_heading = wanted
	else:
		_heading = _heading.slerp(wanted, 1.0 - exp(-maxf(turn_speed, 0.01) * delta))
	_has_heading = true
	return _heading


## Rolls a handful of candidate angles around the player and keeps the one
## furthest from every other bandit's own claimed angle - which is the whole of
## how the crowd spreads out rather than piling up on one side. Ties, and a
## bandit with nobody nearby to weigh against, fall back to a plain random
## angle, so a lone attacker is not held to a bearing that means nothing yet.
func _pick_slot(host: Node2D) -> void:
	var others := _nearby_claims(host)

	var best_angle := randf() * TAU
	var best_score := -INF
	for i: int in maxi(slot_candidates, 1):
		var angle := randf() * TAU
		var score := _score_angle(angle, others)
		if score > best_score:
			best_score = score
			best_angle = angle

	_angle = best_angle
	_radius = maxf(surround_radius + randf_range(-radius_spread, radius_spread), 40.0)
	_claim_slot()


## How good [param angle] is as a new slot: the smallest angular gap to any
## other claimed bearing, so the candidate that opens the widest gap in the
## crowd wins. A pinch of noise keeps two equally-open candidates from always
## resolving the same way.
func _score_angle(angle: float, others: Array[float]) -> float:
	if others.is_empty():
		return randf()

	var closest := TAU
	for taken: float in others:
		var gap := absf(wrapf(angle - taken, -PI, PI))
		closest = minf(closest, gap)
	return closest + randf_range(-0.05, 0.05)


## Every other bandit's claimed angle, for whichever player [param host] is
## actually chasing - pruned of anything that has died or wandered out of
## [member awareness_radius] along the way, so a stale claim from a man three
## screens away never dents the score.
func _nearby_claims(host: Node2D) -> Array[float]:
	var result: Array[float] = []
	if _player == null:
		return result

	var book: Dictionary = _slots.get(_player.get_instance_id(), {})
	if book.is_empty():
		return result

	var stale: Array = []
	for node: Node in book.keys():
		if node == self or not is_instance_valid(node):
			stale.append(node)
			continue
		var other := node as Node2D
		if other == null:
			continue
		if host.global_position.distance_to(other.global_position) > awareness_radius:
			continue
		result.append(float(book[node]))

	for node: Node in stale:
		book.erase(node)
	return result


func _claim_slot() -> void:
	if _player == null:
		return
	var id := _player.get_instance_id()
	var book: Dictionary = _slots.get(id, {})
	book[self] = _angle
	_slots[id] = book


func _release_slot() -> void:
	if _player == null:
		return
	var id := _player.get_instance_id()
	if not _slots.has(id):
		return
	var book: Dictionary = _slots[id]
	book.erase(self)
	if book.is_empty():
		_slots.erase(id)


## Found once and kept rather than asked of [Enemy] every frame: the chase
## target does not change for the life of an ordinary bandit, and re-resolving
## it here would be a second lookup for a fact [Enemy] already holds.
func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if _enemy != null and _enemy.has_method(&"get_chase_target"):
		_player = _enemy.call(&"get_chase_target") as Node2D
