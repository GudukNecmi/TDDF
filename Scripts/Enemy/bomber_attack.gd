class_name BomberAttack
extends Node
## When a bomber stops wandering and commits.
##
## [b]Getting close is permission to decide, not the decision.[/b] The bomber
## wobbles towards the player under [BomberSway] until it is inside
## [member Bomber_Attack_Circle], and only then does it start rolling - once every
## [member decision_interval], never per frame - on whether to charge. A roll it
## loses costs it nothing: it keeps wandering and rolls again a moment later.
##
## [b]What the roll is worth is how crowded the player already is.[/b] The number
## of other enemies standing inside [member nearby_enemy_radius] of the player is
## looked up and read straight out of [member attack_chance_by_nearby] - alone the
## bomber always commits, with one man already on the player it usually holds off,
## and with four it always goes. That is what stops a wave of bombers all rushing
## at once while making a crowded fight genuinely dangerous.
##
## The crowd does one more thing: it lets the bomber commit from further out, by
## [member attack_circle_per_nearby_enemy] per man. A player being swarmed is
## charged from across the room; a player fighting one man has to let the bomber
## get close first.
##
## [b]The charge itself is not written here.[/b] Committing calls
## [method Enemy.begin_charge] - the same run at a place the boss attack uses - so
## the bomber keeps its separation, its knockback and the world's slow motion for
## nothing, and there is no second mover anywhere in this. Lighting the fuse is
## [BomberFuse]'s, and the explosion is [Explosion]'s.
##
## [b]It never reconsiders.[/b] Once committed the crowd is not looked at again,
## so a bomber cannot be talked out of its attack by another enemy wandering off.

## Emitted the moment this bomber commits, with the point it is running at.
signal committed(at: Vector2)
## Emitted as it arrives on the player with the fuse already lit.
signal reached_target

## The enemy this drives. Its chase target is the player, so nothing here has to
## be wired to them.
@export var enemy_path: NodePath = ^".."
## The fuse lit on commitment. Left unset the bomber charges and never goes off,
## which is a bomber with its explosion switched off rather than a broken one.
@export var fuse_path: NodePath = ^"../Fuse"
## The sway switched off by the charge. Read-only here - the sway asks the enemy
## whether it is charging - and named only so the pair is visible in one place.
@export var sway_path: NodePath = ^"../Sway"

@export_group("Bomber attack circle")
## [b]Bomber_Attack_Circle.[/b] The ring around the player inside which this
## bomber will consider committing, in pixels. Outside it the bomber only ever
## wanders; inside it, it starts rolling.
##
## It is the whole of "close enough to commit" - there is no second distance
## anywhere in the attack - so widening this is how a bomber is made braver.
@export var Bomber_Attack_Circle: float = 240.0
## How much the circle grows per other enemy already on the player, in pixels.
## This is "the more crowded the player is, the further out a bomber will start
## its run from". 0 makes the circle a fixed size whatever the fight looks like.
@export var attack_circle_per_nearby_enemy: float = 90.0
## Ceiling on the grown circle, in pixels, so a huge pile-up cannot have bombers
## committing from off screen.
@export var max_attack_circle: float = 700.0

@export_group("The crowd")
## How close another enemy has to be to the player to count as already on them,
## in pixels. This is the player's immediate combat area.
@export var nearby_enemy_radius: float = 150.0
## Group the enemies are counted in.
@export var enemy_group: StringName = &"enemies"
## Chance of committing, by how many other enemies are on the player: index 0 is
## alone, index 1 is one man, and so on. A count past the end of the list uses the
## last entry, which is why "4 or more" needs no special case.
##
## The brief's table exactly: alone it always goes, and every man on the player
## adds a quarter.
@export var attack_chance_by_nearby: Array[float] = [1.0, 0.25, 0.5, 0.75, 1.0]

@export_group("Deciding")
## Seconds between rolls while inside the circle. The reason this is not a
## per-frame roll: at sixty rolls a second even a one-in-four chance is a
## certainty within a heartbeat.
@export var decision_interval: float = 0.6
## A first roll cannot happen until this many seconds after the bomber spawns, so
## one that walks in already next to the player still reads as approaching first.
@export var arming_delay: float = 0.5

@export_group("The charge")
## What the charge multiplies the bomber's walk by. Above 1 is the run.
@export var charge_speed_multiplier: float = 1.45
## How close to the player counts as reaching them, in pixels. Arriving here with
## a lit fuse detonates immediately rather than waiting the rest of it out.
@export var detonate_radius: float = 46.0
## How close to the recorded point counts as arriving at it.
@export var arrival_radius: float = 28.0
## Whether reaching the recorded point with the player no longer on it re-aims at
## wherever they are now.
##
## [b]It is not reconsidering the attack.[/b] The decision is made and the fuse is
## lit either way; this only stops a committed bomber standing on an empty patch
## of sand waiting to go off. Off, it runs at the spot it was given and detonates
## there, which is the purer reading of "record the position and run at it".
@export var retarget_on_arrival: bool = true

@onready var _enemy: Node = get_node_or_null(enemy_path)
@onready var _fuse: BomberFuse = get_node_or_null(fuse_path) as BomberFuse

var _committed: bool = false
var _decision_timer: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	_decision_timer = maxf(decision_interval, 0.0)


func _physics_process(delta: float) -> void:
	var player := _get_player()
	if player == null or _enemy == null:
		return

	if _committed:
		_run_at(player)
		return

	_age += delta
	_consider(delta, player)


## Whether this bomber has already made up its mind.
func is_committed() -> bool:
	return _committed


## The circle this bomber is currently deciding inside, in pixels - the authored
## one plus whatever the crowd around the player has added to it.
func get_effective_attack_circle() -> float:
	var grown := Bomber_Attack_Circle \
		+ attack_circle_per_nearby_enemy * float(count_nearby_enemies())
	return minf(grown, maxf(max_attack_circle, Bomber_Attack_Circle))


## Other enemies standing inside [member nearby_enemy_radius] of the player.
## Bombers included - a bomber on the player is a body on the player - but never
## this one, and never anything already dead.
func count_nearby_enemies() -> int:
	var player := _get_player()
	if player == null or not is_inside_tree():
		return 0

	var host := _enemy as Node2D
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(enemy_group):
		var other := node as Node2D
		if other == null or other == host or not is_instance_valid(other):
			continue
		if _is_out_of_the_fight(other):
			continue
		if other.global_position.distance_to(player.global_position) <= nearby_enemy_radius:
			count += 1
	return count


## The chance a roll would be won with [param nearby] men already on the player.
## Public because it is the table, not a detail: a test can assert the brief's
## numbers without waiting for a bomber to roll them.
func get_attack_chance(nearby: int) -> float:
	if attack_chance_by_nearby.is_empty():
		return 1.0
	var index := clampi(nearby, 0, attack_chance_by_nearby.size() - 1)
	return clampf(attack_chance_by_nearby[index], 0.0, 1.0)


## Commits, now, whatever the distance and whatever the crowd. The fuse is lit and
## the run begins on the same frame.
##
## Public and guarded, so a scripted test - or a future weapon that sets one off -
## can trigger the attack without reproducing the decision, and so a second call
## can never restart a charge that is already under way.
func commit(at: Vector2) -> void:
	if _committed:
		return
	_committed = true

	if _fuse != null:
		_fuse.ignite()
	if _enemy != null and _enemy.has_method(&"begin_charge"):
		_enemy.begin_charge(at, maxf(charge_speed_multiplier, 0.0))
	committed.emit(at)


## One decision beat. Distance is checked every frame - it is free - but the roll
## itself only happens when the timer comes round, so being inside the circle for
## a second is one or two chances rather than sixty.
func _consider(delta: float, player: Node2D) -> void:
	_decision_timer -= delta
	if _decision_timer > 0.0:
		return
	_decision_timer = maxf(decision_interval, 0.05)

	if _age < arming_delay:
		return

	var host := _enemy as Node2D
	if host == null:
		return
	if host.global_position.distance_to(player.global_position) > get_effective_attack_circle():
		return

	if randf() < get_attack_chance(count_nearby_enemies()):
		commit(player.global_position)


## A committed bomber, on its way in. Nothing about the crowd is read here - the
## decision has been made - and the only two things that can happen are arriving
## on the player, which sets it off, and arriving on an empty spot, which re-aims.
func _run_at(player: Node2D) -> void:
	var host := _enemy as Node2D
	if host == null:
		return

	if host.global_position.distance_to(player.global_position) <= detonate_radius:
		reached_target.emit()
		if _fuse != null:
			_fuse.detonate()
		return

	if not retarget_on_arrival or not _enemy.has_method(&"get_charge_point"):
		return
	if host.global_position.distance_to(_enemy.get_charge_point()) <= arrival_radius:
		_enemy.begin_charge(player.global_position, maxf(charge_speed_multiplier, 0.0))


## A man who has given up, run away or been knocked out of the fight is not
## pressure on the player, so he does not make a bomber braver. Asked by method
## rather than by type, so an enemy carrying none of those components counts as
## fighting - which every ordinary one does.
func _is_out_of_the_fight(other: Node2D) -> bool:
	if other.has_method(&"is_fleeing") and other.is_fleeing():
		return true
	for node: Node in other.find_children("*", "EnemyDefeat", true, false):
		var defeat := node as EnemyDefeat
		if defeat != null and defeat.is_defeated():
			return true
	return false


func _get_player() -> Node2D:
	if _enemy == null or not _enemy.has_method(&"get_chase_target"):
		return null
	return _enemy.get_chase_target() as Node2D


