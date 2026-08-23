class_name ZoneEnemyGuard
extends Node
## Keeps the safe places safe.
##
## The base is not a separate scene - it is the other end of the same world - so
## "there are no enemies in the base" is not something the level layout can
## promise on its own. This is where it is promised instead.
##
## It guards on two fronts, and both matter:
##
##   * The moment the player crosses into a [WorldZone] marked
##     [member WorldZone.bars_enemies], spawning stops and everything still
##     standing is finished off. That is what makes arriving home after a death
##     an ending rather than a chase that follows you in.
##   * Every frame after that, any enemy that has somehow got inside a barred
##     zone is finished off too. That is the permanent half: it holds however an
##     enemy got there, including ones that have not been invented yet.
##
## Nothing is deleted. Enemies are asked to play their own ending through their
## own [EnemyDefeat], exactly as the run's clock running out asks them - so the
## blood they were worth still lands on the floor and the death still looks like
## a death. The only thing this decides is *who* and *when*, which is why it can
## sit in the world as one node rather than being wired into the enemy.

## Emitted when a zone has been cleared, with how many were told to go.
signal zone_cleared(count: int)

## Run whose spawning is stopped. Optional - without it the guard still clears
## what is alive, it simply cannot stop more arriving.
@export var wave_manager_path: NodePath = ^"../WaveManager"
## Group the enemies are found by.
@export var enemy_group: StringName = &"enemies"
## Body whose position arms the guard.
@export var body_group: StringName = &"player"

@export_group("Clearing")
## Whether the player entering a barred zone stops the run's spawning outright.
## On, because a base that is safe until the next wave arrives is not safe.
@export var stop_spawning: bool = true
## Whether the player entering a barred zone also finishes off what is already
## alive somewhere else. Off leaves the arena's enemies standing while the player
## is away, which is what a "step out and come back" trip would want.
@export var clear_on_entry: bool = true
## Pause before the first one goes, so the crossing registers first.
@export var lead_in: float = 0.2
## Gap between one enemy and the next, so a full arena goes out as a ripple.
@export var stagger: float = 0.05
## Ceiling on the total spread, however many are alive.
@export var max_spread: float = 1.6

@onready var _manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager

var _armed: bool = false


func _process(_delta: float) -> void:
	var zone := _barred_zone_holding_player()
	var inside := zone != null

	if inside and not _armed:
		_armed = true
		_arm()
	elif not inside and _armed:
		_armed = false

	# Runs whether or not the player is in one: an enemy that wandered into a
	# barred zone is removed from it even if nobody is standing there.
	_sweep_barred_zones()


## True while the player is somewhere enemies are not allowed.
func is_armed() -> bool:
	return _armed


func _barred_zone_holding_player() -> WorldZone:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var zone := WorldZone.get_zone_for(self, body)
	return zone if zone != null and zone.bars_enemies else null


## Stops the run and clears the field. Both are guarded by the caller, so
## crossing back and forth cannot re-run the clear on an arena that has already
## been emptied - there is simply nothing left to tell.
func _arm() -> void:
	if stop_spawning and _manager != null:
		_manager.stop()
	if clear_on_entry:
		_clear(get_tree().get_nodes_in_group(enemy_group))


## Anything standing inside a barred zone, whoever is watching. This is the part
## that holds permanently: an enemy that reaches the base is defeated the frame
## it arrives rather than being left to wander around it.
func _sweep_barred_zones() -> void:
	var zones := get_tree().get_nodes_in_group(WorldZone.GROUP)
	if zones.is_empty():
		return

	var trespassers: Array[Node] = []
	for enemy: Node in get_tree().get_nodes_in_group(enemy_group):
		var body := enemy as Node2D
		if body == null:
			continue
		for node: Node in zones:
			var zone := node as WorldZone
			if zone != null and zone.bars_enemies \
					and zone.get_world_region().has_point(body.global_position):
				trespassers.append(enemy)
				break

	if not trespassers.is_empty():
		_clear(trespassers)


## Squeezed rather than truncated, so a crowded field clears in the same window a
## sparse one does. Anything already playing its own ending is skipped by
## [EnemyDefeat] itself, so this can be called every frame without stacking.
func _clear(enemies: Array) -> void:
	var gap := stagger
	if max_spread > 0.0 and enemies.size() > 1:
		gap = minf(stagger, max_spread / float(enemies.size() - 1))

	var told := 0
	for enemy: Node in enemies:
		var defeat := _find_defeat(enemy)
		if defeat == null or defeat.is_defeated():
			continue
		defeat.defeat(lead_in + gap * float(told))
		told += 1

	if told > 0:
		zone_cleared.emit(told)


## Found by type rather than by a fixed child name, so an enemy that keeps its
## defeat component somewhere else still ends properly.
func _find_defeat(enemy: Node) -> EnemyDefeat:
	for node: Node in enemy.find_children("*", "EnemyDefeat", true, false):
		var defeat := node as EnemyDefeat
		if defeat != null:
			return defeat
	return null
