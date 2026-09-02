class_name CombatAmmoBoxDirector
extends Node
## A bonus crate of ammunition for the heaviest World Map bandit fights - a
## battle 40 strong or more has a rising chance of dropping one, on top of
## whatever the arena's own ten-second supply already provides once combat
## has been under way for a while.
##
## [b]It is [CombatLootDirector]'s own shape, not a new system.[/b] That node
## already hangs off [signal WorldMapCombatBridge.encounter_started] to fill
## the fight's [CombatLoot] the instant it opens; this hangs off the
## identical signal to do the one other thing a heavy fight is owed - an
## actual crate on the ground, dropped through the same [AmmoCrateSpawner]
## and the same [AmmoCrate] every arena fight's own supply already uses (see
## [method AmmoCrateSpawner.spawn_crate_in], written for exactly this - "a
## fight that is not an arena lock still gets the same placing, the same
## ceiling, the same wiring and the same artwork"). No second ammo system, no
## second pickup, no second camera shake and no second placement rule exist
## anywhere in this file.
##
## [b]The crate is worth less than the arena's own supply, on purpose.[/b] An
## ordinary [AmmoCrate] is [member AmmoCrate.refill_fraction] 0.5 of the
## weapon's ceiling; this one is dropped with [member box_refill_fraction] -
## roughly a fifth, per the brief - set directly on the instance it spawns,
## so nothing about [AmmoCrate]'s own class or its scene's authored default
## has to change for every other crate in the game to stay exactly as
## generous as it always was.
##
## [b]Never overlaps the player, never floats off the ground.[/b] Both are
## already [method AmmoCrateSpawner.pick_position]'s own job -
## [member AmmoCrateSpawner.player_clearance] keeps distance from whoever is
## standing there and the point is always inside the fight's own arena
## rectangle - so this asks for a crate and nothing about where it lands.

@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"
@export var arena_spawner_path: NodePath = ^"../EnemySpawner"
@export var crate_spawner_path: NodePath = ^"../AmmoCrates"

@export_group("Chance")
## The smallest [member WorldBanditEncounter.group_strength] a fight has to be
## before a bonus crate is even considered - "spawn chance starts at 20% at
## 40 people".
@export var min_group_strength: float = 40.0
## The chance rolled at exactly [member min_group_strength].
@export_range(0.0, 1.0, 0.01) var base_chance: float = 0.2
## How large a fight has to be before the chance reaches [member max_chance] -
## "chance increases with battle size", read the same way
## [WorldMapCombatBridge] already lerps a region's own danger between two
## ends rather than a curve invented here.
@export var chance_at_max_strength: float = 80.0
@export_range(0.0, 1.0, 0.01) var max_chance: float = 0.85

@export_group("Reward")
## What fraction of the weapon's own maximum capacity this crate is worth -
## "approximately 20% of the relevant weapon ammo capacity".
@export_range(0.0, 1.0, 0.01) var box_refill_fraction: float = 0.2

var _bridge: WorldMapCombatBridge


func _ready() -> void:
	_bind_bridge.call_deferred()


func _process(_delta: float) -> void:
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()


func _bind_bridge() -> void:
	_bridge = get_node_or_null(bridge_path) as WorldMapCombatBridge
	if _bridge == null:
		_bridge = WorldMapCombatBridge.get_active(self)
	if _bridge == null:
		return
	if not _bridge.encounter_started.is_connected(_on_encounter_started):
		_bridge.encounter_started.connect(_on_encounter_started)


## The fight has opened. [param payload.group_strength] is the battle's true,
## uncapped size - the same field [CombatLootDirector] already reads for the
## identical reason - so there is nothing to gain waiting for it to end and
## every reason not to: a crate dropped once the fight is already under way
## reads as reinforcement arriving, not as a prize handed out at the door.
func _on_encounter_started(payload: WorldBanditEncounter) -> void:
	if payload == null or payload.group_strength < min_group_strength:
		return
	if randf() > _chance_for(payload.group_strength):
		return

	var spawner := _resolve_crate_spawner()
	var arena := _resolve_arena_bounds()
	if spawner == null or arena.size.x <= 0.0 or arena.size.y <= 0.0:
		return

	var crate := spawner.spawn_crate_in(arena) as AmmoCrate
	if crate != null:
		crate.refill_fraction = box_refill_fraction


func _chance_for(strength: float) -> float:
	if strength <= min_group_strength:
		return base_chance
	var span := maxf(chance_at_max_strength - min_group_strength, 0.001)
	var t := clampf((strength - min_group_strength) / span, 0.0, 1.0)
	return lerpf(base_chance, max_chance, t)


func _resolve_crate_spawner() -> AmmoCrateSpawner:
	var named := get_node_or_null(crate_spawner_path) as AmmoCrateSpawner
	return named if named != null else AmmoCrateSpawner.get_active(self)


func _resolve_arena_bounds() -> Rect2:
	var spawner := get_node_or_null(arena_spawner_path) as EnemySpawner
	return spawner.arena_bounds if spawner != null else Rect2()
