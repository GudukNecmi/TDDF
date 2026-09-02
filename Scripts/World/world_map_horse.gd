class_name WorldMapHorse
extends Node
## The horse: how fast it carries the player across the World Map, and how
## far it can be pushed before it needs to rest.
##
## It is written as one of the Player's own speed modifiers - see
## [member Player.speed_modifier_paths] - rather than as a second body that
## carries the player around, because that seam already exists for exactly
## this: [PlayerDeathSequence] and [TerrainSlow] both change how fast the
## player moves by answering [method get_speed_multiplier] and nothing else,
## so this is a third answer rather than a second way of moving anybody.
## [b]The player is not duplicated or replaced.[/b] They are still the one
## [CharacterBody2D] in [code]player.gd[/code], on foot, walking or running at
## whatever this component says.
##
## Off the World Map - the arena, the base, a search for trouble -
## [member player_on_horse] is simply never turned on, so
## [method get_speed_multiplier] answers 1 and nothing about ordinary play
## changes, and stamina neither drains nor recovers. Cart inventory and a
## permanent upgrade tree are still later-phase work and are deliberately not
## touched - see rule 18 of the stamina phase.
##
## [b]This is also the horse's own condition, not only its speed.[/b] Fatigue,
## stamina and food were the one thing this file's own doc used to say were
## "deliberately not touched" - they are what this class was always going to
## grow into, so they are added here rather than to a second authority. See
## rule 10 of the stamina phase: nothing about mounted state, stamina, fatigue
## or food lives in the player's own movement script, the World Map UI or any
## other component - it all sits here, and everything else only asks.
##
## [b]One update path, driven by the one call every physics frame already
## makes.[/b] [method get_speed_multiplier] is already asked once per physics
## frame by [member Player.speed_modifier_paths] - see [method Node.get_physics_process_delta_time]
## in [method _advance_condition] - so stamina and fatigue are advanced from
## inside that same call rather than a second [method Node._physics_process]
## racing it for the same state. See rule 15 of the stamina phase.
##
## [b]It survives a run exactly by being what it already was.[/b] This node is
## a child of the Player, and the Player is only ever rebuilt when a run
## begins or ends - never by walking across the World Map, crossing a region,
## or a Blood Depot deposit, all of which move the one player already in the
## tree. So the condition set here starts fresh at its configured values
## because a whole new [code]Player[/code] with a whole new [WorldMapHorse]
## is what a new run actually builds, and it survives everything short of
## that for the same reason [member player_on_horse] itself always has.

## Group this joins, so the World Map's own [TeleportDestination] can mount
## and dismount it without a path across two different scenes - see
## [code]world_map_destination.gd[/code] - and so a debug readout or a future
## system can find the one horse in play without a [NodePath] of its own.
const GROUP := &"world_map_horse"

## Whether the player is currently mounted. The World Map turns this on when
## the player arrives and it is otherwise off, so every place that is not the
## World Map plays exactly as it always did.
@export var player_on_horse: bool = false
## Speed while mounted and walking, in pixels per second.
@export var walk_speed: float = 220.0
## Speed while mounted and holding [member run_action], in pixels per second.
@export var run_speed: float = 420.0
## The key that swings between the two. Reuses the project's existing Shift
## binding rather than a new input action - [TravelDirector]'s fast travel
## already answers to it, and a second action bound to the same physical key
## would be indistinguishable from this one to the player.
@export var run_action: StringName = &"fast_travel"

@export_group("Stamina")
## Full stamina for a fresh horse - fatigue = 0. What [method get_max_stamina]
## answers before any fatigue has ever reduced it.
@export var base_max_stamina: float = 100.0
## How much stamina one second of sprinting costs.
@export var sprint_stamina_drain_per_second: float = 22.0
## How much stamina sprinting needs to keep going. Not merely "above zero": a
## horse this close to empty is refused a sprint - or has one cut short - a
## beat before the number would actually hit the floor, which is what keeps
## the cutoff feeling like the horse giving out rather than a counter
## clipping at zero.
@export var minimum_stamina_to_sprint: float = 4.0

@export_group("Regeneration")
## How long the horse must go without sprinting before [member current_stamina]
## starts climbing back on its own, in seconds. Held at zero for as long as
## Shift is actually producing a sprint - see [method _advance_condition] -
## and only counts down while it is not, so letting off the key for a moment
## and pressing it again keeps the delay from ever elapsing.
@export var stamina_regen_delay: float = 3.0
## How much [member current_stamina] climbs back per second once
## [member stamina_regen_delay] has actually elapsed. Never lets
## [member current_stamina] rise past [method get_max_stamina] - a fatigued
## horse regenerates only up to its own reduced ceiling, exactly the same
## clamp every other path onto [member current_stamina] already respects.
@export var stamina_regen_per_second: float = 12.0

@export_group("Fatigue")
## How much [member fatigue] rises per second of sprinting. Small on purpose -
## see rule 4 of the stamina phase: fatigue climbs from sustained running, not
## from one press of the key.
@export var fatigue_gain_per_second_while_sprinting: float = 0.05
## How much [member fatigue] falls per second the horse is not sprinting.
## Nothing here restores lost stamina - see [method _advance_condition] - this
## only lets the ceiling it can spend against climb back up on its own between
## sprints, the way a horse that is merely walking gradually catches its
## breath even before it is fed.
@export var fatigue_recovery_rate: float = 0.03
## The most tired the horse can become.
@export var max_fatigue: float = 1.0
## What fraction of [member base_max_stamina] the horse is left with at
## [member max_fatigue], when [member fatigue_max_stamina_curve] is unset.
@export_range(0.0, 1.0) var min_effective_stamina_fraction: float = 0.4
## Optional curve from fatigue ratio (0 fresh, 1 exhausted along the X axis) to
## how much of [member base_max_stamina] survives it (Y axis, 0 to 1) - the
## "Curve... rather than hardcoded if/else values" rule 4 of the stamina phase
## asks for. Left unset, [method get_max_stamina] falls back to a straight
## line between 1.0 and [member min_effective_stamina_fraction], which is
## every horse until one is authored.
@export var fatigue_max_stamina_curve: Curve

@export_group("Food")
## How much horse food a fresh horse is carrying.
@export var starting_horse_food: int = 3
## How much horse food the horse can carry at once.
@export var max_horse_food: int = 3
## How much stamina one feeding restores, added after the fatigue recovery
## below has already raised the ceiling it is clamped to - see
## [method _feed].
@export var food_stamina_restore: float = 60.0
## How much [member fatigue] one feeding clears. This, not a bigger stamina
## number, is what the player actually asked for: feeding the horse is meant
## to raise how much it can hold, not only refill what it already had - see
## rule 5 of the stamina phase and [method get_max_stamina].
@export var food_fatigue_recovery: float = 0.35
## How long an automatic feeding locks out the next one, in seconds - see
## rule 7 of the stamina phase, "avoid repeated consumption every frame". One
## press of Shift against an empty tank is one feeding, not one per physics
## tick until the number climbs back over the threshold.
@export var auto_feed_cooldown: float = 0.4

## Emitted whenever [method _feed] actually spends a food item, whether the
## player asked for it directly or Shift triggered it automatically. Carries
## nothing beyond the fact - the amounts are already on [member current_stamina]
## and [member fatigue] by the time this fires, so a debug readout just rereads
## those rather than being handed a second copy of them.
signal horse_fed

var current_stamina: float = 0.0
var fatigue: float = 0.0
var horse_food: int = 0

var _running: bool = false
var _feed_cooldown_left: float = 0.0
## Seconds since sprinting last actually happened - see [member stamina_regen_delay].
## Reset to zero every frame [member _running] is true, so regeneration is
## always exactly [member stamina_regen_delay] seconds behind the last real
## sprint rather than the last time Shift was merely held against an empty
## tank.
var _time_since_sprint: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# A fresh horse starts full and unfed nothing - fatigue at 0 means
	# [method get_max_stamina] is already [member base_max_stamina], and the
	# pouch is whatever it was authored to start with. See the class doc for
	# why nothing more than this is needed for a new run to start clean.
	current_stamina = get_max_stamina()
	horse_food = clampi(starting_horse_food, 0, maxi(max_horse_food, 0))


## The horse currently in play, found by group - the same lookup
## [code]world_map_destination.gd[/code] already uses, offered here as well so
## a debug readout or a future system needs no [NodePath] of its own to reach
## it. Null off the World Map, which every caller reads as "there is nothing
## to ask".
static func get_active(from_node: Node) -> WorldMapHorse:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapHorse


## What [member Player.speed] should be multiplied by, asked every physics
## frame through the seam every other modifier already uses. 1 whenever the
## player is not mounted, so this can sit on the player permanently with no
## effect anywhere the World Map has not turned it on.
##
## [b]This is also where the horse's condition is advanced.[/b] Not because
## the speed answer needs it - see [method _advance_condition] - but because
## this is the one call already made once a physics frame for every mounted
## player, and rule 15 of the stamina phase asks for one update path rather
## than a second [method Node._physics_process] ticking the same state beside
## it.
func get_speed_multiplier() -> float:
	if not player_on_horse:
		_running = false
		return 1.0

	_advance_condition(get_physics_process_delta_time())

	var base_speed := _base_speed()
	if base_speed <= 0.0:
		return 1.0

	var target := run_speed if _running else walk_speed
	return target / base_speed


## Whether the player is currently mounted.
func is_mounted() -> bool:
	return player_on_horse


## Mounts or dismounts. Called by the World Map's own destination on arrival
## and on the way out to anywhere else, so a debug exit can never leave the
## player running at horse speed somewhere that is not the World Map.
func set_mounted(mounted: bool) -> void:
	player_on_horse = mounted
	if not mounted:
		_running = false


## Whether the run key is currently held and actually doing something - for a
## HUD readout later. False while dismounted, even if the key is held, and
## false whenever there is not enough stamina to sprint on, whatever the key
## is doing.
func is_running() -> bool:
	return player_on_horse and _running


# --- Condition ------------------------------------------------------------

## How much stamina the horse can currently hold, [member fatigue] already
## folded in. [member current_stamina] is never allowed above this - see
## [method _advance_condition] - which is the whole of rule 5 of the stamina
## phase: a tired horse's ceiling is lower, not its current tank drained out
## from under it.
func get_max_stamina() -> float:
	return maxf(base_max_stamina, 0.0) * _fatigue_multiplier()


## What [member current_stamina] would be at a fresh horse - for a debug
## readout that wants to show the ceiling fatigue has not yet touched,
## alongside the one it actually has.
func get_base_max_stamina() -> float:
	return maxf(base_max_stamina, 0.0)


func get_current_stamina() -> float:
	return current_stamina


func get_fatigue() -> float:
	return fatigue


func get_horse_food() -> int:
	return horse_food


func get_max_horse_food() -> int:
	return maxi(max_horse_food, 0)


## Whether the horse has enough in the tank to sprint right now.
func can_sprint() -> bool:
	return current_stamina >= minimum_stamina_to_sprint


## Raises or lowers how much stamina a fresh horse holds - the seam a future
## Horse Stamina upgrade calls, the same way [method HorseBloodStorage.set_capacity]
## is the seam a Horse Blood upgrade calls. Nothing in this phase calls it; the
## horse simply starts at [member base_max_stamina] and stays there. See rule
## 18 of the stamina phase.
func set_base_max_stamina(value: float) -> void:
	base_max_stamina = maxf(value, 0.0)
	current_stamina = minf(current_stamina, get_max_stamina())


## Raises or lowers how much horse food the horse can carry - the same kind of
## seam, for a future Horse Food Capacity upgrade. Nothing in this phase calls
## it either.
func set_max_horse_food(value: int) -> void:
	max_horse_food = maxi(value, 0)
	horse_food = clampi(horse_food, 0, max_horse_food)


## Hands the horse [param amount] more food, for a safe developer method to
## give it something to eat - see rule 17 of the stamina phase's own live test.
## Clamped to [member max_horse_food], so a test cannot overfill the pouch.
func add_food(amount: int) -> void:
	horse_food = clampi(horse_food + amount, 0, get_max_horse_food())


## One physics frame of the horse's condition: decides whether Shift is
## actually producing a sprint right now, spends stamina and gains fatigue
## while it is, recovers fatigue while it is not, feeds the horse on the
## player's behalf if Shift is being asked of an empty tank - see [method _feed] -
## and regenerates stamina once it has been long enough since the last sprint.
##
## [b]Stamina regenerates, but only after a real rest.[/b] [member _time_since_sprint]
## resets to zero on every frame [member _running] is true and otherwise counts
## up; [member current_stamina] only ever climbs on its own once that has held
## past [member stamina_regen_delay], and never while [member _running] is
## true - sprinting and regenerating are mutually exclusive states, exactly
## like the drain and the regeneration rate they are each paced by. Walking
## unmounted-of-a-sprint costs nothing to begin with - see the drain branch
## below - so this is the only place [member current_stamina] rises without
## [method _feed] having spent food on it.
func _advance_condition(delta: float) -> void:
	if delta <= 0.0:
		return

	if _feed_cooldown_left > 0.0:
		_feed_cooldown_left = maxf(_feed_cooldown_left - delta, 0.0)

	var wants_to_sprint := Input.is_action_pressed(run_action)
	if wants_to_sprint and not can_sprint() and _feed_cooldown_left <= 0.0:
		_feed()

	_running = wants_to_sprint and can_sprint()

	if _running:
		current_stamina = maxf(current_stamina - sprint_stamina_drain_per_second * delta, 0.0)
		fatigue = minf(fatigue + fatigue_gain_per_second_while_sprinting * delta, maxf(max_fatigue, 0.0))
		_time_since_sprint = 0.0
	else:
		fatigue = maxf(fatigue - fatigue_recovery_rate * delta, 0.0)
		_time_since_sprint += delta
		if _time_since_sprint >= maxf(stamina_regen_delay, 0.0):
			current_stamina += stamina_regen_per_second * delta

	# The one clamp rule 5 of the stamina phase asks for: whatever fatigue just
	# did to the ceiling, the tank can never be left reading more than it -
	# also what keeps the regeneration above from ever overfilling it.
	current_stamina = clampf(current_stamina, 0.0, get_max_stamina())


## Spends one food item: fatigue drops first, which is what lets the stamina
## restored afterwards land against the *new*, higher ceiling rather than the
## one fatigue had pinned it under - exactly the order rule 5's own worked
## example walks through. Harmless when there is nothing to feed.
func _feed() -> void:
	if horse_food <= 0:
		return

	horse_food -= 1
	fatigue = maxf(fatigue - food_fatigue_recovery, 0.0)
	current_stamina = minf(current_stamina + food_stamina_restore, get_max_stamina())
	_feed_cooldown_left = maxf(auto_feed_cooldown, 0.0)
	horse_fed.emit()


## How much of [member base_max_stamina] survives the current [member fatigue] -
## 1.0 fresh, down to [member min_effective_stamina_fraction] at
## [member max_fatigue]. A [member fatigue_max_stamina_curve], if one is
## authored, answers this outright; otherwise it is the straight line rule 4
## of the stamina phase accepts as the default.
func _fatigue_multiplier() -> float:
	var ceiling := maxf(max_fatigue, 0.0001)
	var ratio := clampf(fatigue / ceiling, 0.0, 1.0)
	if fatigue_max_stamina_curve != null:
		return clampf(fatigue_max_stamina_curve.sample(ratio), 0.0, 1.0)
	return lerpf(1.0, clampf(min_effective_stamina_fraction, 0.0, 1.0), ratio)


## The player's own authored speed, asked rather than assumed, so this never
## has to know what [member Player.speed] is tuned to.
func _base_speed() -> float:
	var player := get_parent()
	if player == null:
		return 0.0
	var value: Variant = player.get(&"speed")
	return float(value) if value != null else 0.0
