class_name RoundScaling
extends Node
## How much harder each round is than the one before it.
##
## The whole difficulty curve is three numbers and one rule:
## [code]next = current x (1 + growth)[/code], compounded off the round number.
## Round 3's enemies are not "round 1's numbers with a special case" - they are
## round 1's numbers multiplied twice, so the curve is continuous at any round and
## a retune takes effect everywhere at once rather than from now on.
##
## [b]The round is no longer what makes an enemy strong.[/b] How tough and how hard
## hitting an enemy is comes from the part of the desert it is standing in - see
## [member DangerDirector.region_health_multiplier] - and from the player's own
## level, so [member health_growth] and [member damage_growth] are authored at 1.0
## and the round contributes nothing to either. The machinery is deliberately kept
## rather than deleted: the growths are the one place a round curve would be turned
## back on, and everything below [member extra_health_multiplier] is what the travel
## road and a Danger lay their own difficulty on with, which is still in use.
##
## Nothing about difficulty lives on the enemy. The scene holds an enemy's *base*
## stats - what it is worth at round 1 - and [method apply_to] multiplies them on
## the instance as it is spawned, before it enters the tree, so its own
## [method Node._ready] sees the scaled numbers and no component downstream needs
## to know that scaling exists. That is also why the enemy scene can be retuned
## freely: it is still the round-1 baseline whatever this is set to.
##
## The three growths are deliberately separate exports rather than one
## difficulty dial, because they are not the same question - a round that doubles
## the crowd is a different fight from one that doubles the toughness - and a
## future upgrade that softens one of them should not touch the others.

## The persistent round counter - the [code]RunProgress[/code] autoload. Left
## unresolved every round is the first one, so a world opened on its own plays at
## the baseline.
@export var progress_path: NodePath = ^"/root/RunProgress"

@export_group("Growth per round")
## Enemy maximum health, as a multiplier on the previous round. 1.12 would be +12%.
##
## [b]1.0 - the round does not make enemies tougher.[/b] Strength is the region's
## and the player's level's business now; this is left as the dial that would put a
## round curve back rather than as a curve that is running.
@export var health_growth: float = 1.0
## Enemy damage, as a multiplier on the previous round. Retired for the same reason
## and in the same way as the one above.
@export var damage_growth: float = 1.0
## How many enemies a round asks for, as a multiplier on the previous round.
## 1.06 is +6%. [WaveManager] reads this rather than owning a count of its own.
@export var spawn_growth: float = 1.06

@export_group("Extra difficulty")
## A flat multiplier laid on top of the round curve, for a place that is simply
## harder than an ordinary arena.
##
## [b]1.0 - the default - changes nothing[/b], which is what every arena round
## uses, so the curve above is still the whole of an ordinary round's difficulty.
## The travel map is what these are for: a journey is fought through enemies that
## are tougher than the round the player left, and how much tougher is one number
## on that map's own scene rather than a second scaling system - see
## [member TravelMap.enemy_health_multiplier], which is where the travel numbers
## are authored and from which they are pushed here as the road is built.
##
## They multiply rather than replace, so a hard place stays hard *relative to* the
## round the player has reached instead of flattening the campaign curve.
@export var extra_health_multiplier: float = 1.0
## The same, for how hard the enemies hit.
@export var extra_damage_multiplier: float = 1.0
## The same, for how many of them a wave asks for.
@export var extra_spawn_multiplier: float = 1.0

@export_group("Targets")
## Component on the enemy whose ceiling is raised. Looked up by name on the
## instance, so an enemy that keeps its health somewhere else is simply left at
## its base stats rather than erroring.
@export var health_node_name: StringName = &"Health"
## Property on the enemy itself that carries its damage.
@export var damage_property: StringName = &"contact_damage"

@onready var _progress: RoundCounter = get_node_or_null(progress_path) as RoundCounter


## The round being played. 1 when there is no counter to ask.
func get_round() -> int:
	return 1 if _progress == null else _progress.get_round()


## Rounds of growth already banked - 0 on the first round, which is the exponent
## every multiplier below is raised to.
func get_rounds_elapsed() -> int:
	return 0 if _progress == null else _progress.get_rounds_elapsed()


func get_health_multiplier() -> float:
	return _compound(health_growth) * maxf(extra_health_multiplier, 0.0)


func get_damage_multiplier() -> float:
	return _compound(damage_growth) * maxf(extra_damage_multiplier, 0.0)


func get_spawn_multiplier() -> float:
	return _compound(spawn_growth) * maxf(extra_spawn_multiplier, 0.0)


## Lays a flat multiplier over the round curve. For a place that is harder than
## an ordinary arena to state how much harder it is without owning a scaling
## system of its own; passing 1.0 for all three puts the curve back to the
## ordinary round.
func set_extra_multipliers(health: float, damage: float, spawn: float) -> void:
	extra_health_multiplier = maxf(health, 0.0)
	extra_damage_multiplier = maxf(damage, 0.0)
	extra_spawn_multiplier = maxf(spawn, 0.0)


## Scales one freshly built enemy. Call it on the instance *before* adding it to
## the tree: the health pool fills itself from its ceiling on ready, so raising
## the ceiling afterwards would leave the enemy spawning already wounded.
##
## Safe to call on anything - an enemy missing either target is left at its base
## stats rather than treated as an error - so a new enemy type costs nothing here.
func apply_to(enemy: Node) -> void:
	if enemy == null:
		return

	var health := enemy.get_node_or_null(NodePath(health_node_name)) as Health
	if health != null:
		# Through the pool rather than onto the field, so the number the enemy scene
		# was authored with survives the multiplication and a boss built afterwards
		# can still be measured against it.
		health.scale_max_health(get_health_multiplier())

	if damage_property in enemy:
		var base: float = enemy.get(damage_property)
		enemy.set(damage_property, base * get_damage_multiplier())


## [param growth] compounded over the rounds already played. A growth of 1 - or
## the first round - leaves everything at its base value.
func _compound(growth: float) -> float:
	var rounds := get_rounds_elapsed()
	if rounds <= 0:
		return 1.0
	return pow(maxf(growth, 0.01), float(rounds))
