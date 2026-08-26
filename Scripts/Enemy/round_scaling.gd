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
## [b]Health is not a curve at all any more - it is a figure the region states.[/b]
## An ordinary enemy is worth exactly [member MapRegion.enemy_base_health] for the
## part of the map it is standing in, written onto its pool as a value rather than
## multiplied into it, and there is no round growth, Danger growth, travel
## multiplier or player-level term anywhere in front of or behind that number. See
## [member health_from_region] and [method get_regional_base_health]: turning that
## flag off is the one way back to the old multiplied health, and it is off nowhere.
##
## [b]Damage and count are unaffected by any of that.[/b] They still run through the
## multipliers below exactly as they did, which is why the machinery is kept rather
## than deleted - a Danger and the travel road both still lay their difficulty on
## with [member extra_damage_multiplier] and [member extra_spawn_multiplier], while
## [member health_growth] and [member extra_health_multiplier] simply no longer
## reach anything.
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
## [b]It reaches nothing while [member health_from_region] is on, which it is.[/b]
## An ordinary enemy's pool is the region's figure and only the region's figure, so
## the round cannot make a man tougher whatever this is set to. It is kept, at 1.0,
## as the dial a round curve would be put back with rather than as one that runs.
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
##
## [b]The health one reaches nothing while [member health_from_region] is on.[/b] A
## Danger and the travel road both still write it, and it is still what would be
## read if regional health were switched off, but no enemy's pool is built from it.
@export var extra_health_multiplier: float = 1.0
## The same, for how hard the enemies hit.
@export var extra_damage_multiplier: float = 1.0
## The same, for how many of them a wave asks for.
@export var extra_spawn_multiplier: float = 1.0

@export_group("Regional health")
## Whether an ordinary enemy's health is the figure its region states, outright.
##
## [b]On, and this is the one source of truth the brief asks for.[/b] The pool is
## set to [member MapRegion.enemy_base_health] rather than multiplied by anything,
## so every health curve that used to sit in front of it - the round's, a Danger's,
## the travel road's - is bypassed in one place instead of being switched off in
## several, and no future multiplier can quietly reappear behind it either.
##
## Off restores exactly what this did before: the pool is multiplied by
## [method get_health_multiplier] and the region is not consulted.
@export var health_from_region: bool = true
## The autoload the current part of the map is asked of, so there is no second copy
## of where the run is.
@export var session_path: NodePath = ^"/root/RunSession"
## What an ordinary enemy is worth where there is no region to ask - a world opened
## on its own in the editor, or a map whose regions state no health.
##
## 0 leaves the enemy at whatever its own scene was authored with, which is the
## right answer for both: an enemy nobody has said anything about is worth what it
## was built as.
@export var fallback_base_health: float = 0.0
## Property on the enemy itself saying whether the regional figure applies to it.
##
## [b]This is how a type opts out without being named here.[/b] An enemy carrying
## this property set to false keeps its own authored pool - the bomber does, because
## what a bomber is worth is a property of the bomber rather than of the sand it is
## standing on - and an enemy without the property at all is treated as using the
## region, so nothing has to be added to a new ordinary enemy.
@export var regional_health_property: StringName = &"uses_regional_health"

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
		# Through the pool rather than onto the field either way, so the number the
		# enemy scene was authored with survives and a boss built afterwards can still
		# be measured against it - see [method Health.get_authored_max_health], which
		# is what [MiniBossDirector] builds a boss's own pool from.
		if health_from_region and _uses_regional_health(enemy):
			var base := get_regional_base_health()
			if base > 0.0:
				health.set_max_health(base, true)
		else:
			health.scale_max_health(get_health_multiplier())

	if damage_property in enemy:
		var base: float = enemy.get(damage_property)
		enemy.set(damage_property, base * get_damage_multiplier())


## What an ordinary enemy in the part of the map the run is currently in is worth, in
## hit points. 0 means nothing has said, and the enemy keeps its scene's own pool.
##
## [b]Read per enemy rather than cached.[/b] It is two property reads off a resource
## the session is already holding, and caching it would mean an enemy spawned after
## the player travelled somewhere else carrying the old region's toughness.
func get_regional_base_health() -> float:
	var region := get_region()
	if region != null:
		var stated := region.get_enemy_base_health()
		if stated > 0.0:
			return stated
	return maxf(fallback_base_health, 0.0)


## The part of the map the run is in, or null when there is no session to ask - a
## world opened on its own, which is read as "nobody has said" rather than as an
## error.
func get_region() -> MapRegion:
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"get_region"):
		return null
	return session.call(&"get_region") as MapRegion


## Whether [param enemy] takes the region's figure. An enemy that carries no opinion
## does, so an ordinary new enemy type needs nothing added to it.
func _uses_regional_health(enemy: Node) -> bool:
	if regional_health_property.is_empty() or not (regional_health_property in enemy):
		return true
	return bool(enemy.get(regional_health_property))


## [param growth] compounded over the rounds already played. A growth of 1 - or
## the first round - leaves everything at its base value.
func _compound(growth: float) -> float:
	var rounds := get_rounds_elapsed()
	if rounds <= 0:
		return 1.0
	return pow(maxf(growth, 0.01), float(rounds))
