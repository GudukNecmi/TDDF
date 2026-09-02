class_name CombatLootTable
extends Resource
## Every tunable number behind what a bandit fight hands over - see
## [CombatLootGenerator], which is the only thing that ever reads this, and
## [CombatLoot], the container it fills.
##
## [b]One resource, so the whole reward ladder is retunable without a line of
## code changing[/b] - the same promise [TroubleRewardTier] and [BountySettings]
## already make for their own systems. Every chance and every quantity below is
## sampled against [b]battle size[/b]: the World Map encounter's own, uncapped
## [member WorldBandit.group_strength], read once as the fight opened - see
## [member WorldBanditEncounter.group_strength] - and never the smaller number
## of bodies [WorldMapCombatBridge] actually spawned into the Arena. A group
## that reads "60 strong" on the map is a 60-person loot roll even though only
## a fraction of that crowd was ever fought.
##
## [b]Chances are authored as a handful of (battle size, chance) points[/b]
## rather than a formula, because every curve this pass was asked for was
## handed over as a short list of exact points - "10 -> 5%, 20 -> 15%, 30 ->
## 25%" - and a designer retuning one number should edit one point rather than
## reverse-engineer an exponent. [method _sample_points] is the one place that
## turns a list of points into a value for a battle size that may fall between
## them, before or after every one of them, or past the last of them - see its
## own doc for the two ways a curve is allowed to behave past its last point.

# --- Gems --------------------------------------------------------------------

@export_group("Gems")
## The colours a Gem drop can come out as - see [CombatLootGemColor]. One is
## picked at random, uniformly, on every successful roll.
@export var gem_colors: Array[CombatLootGemColor] = []
## (battle size, drop chance) - "10-person battle -> 30%, gradually increase
## with battle size, 70+ -> 100%". Flat past both ends: a battle smaller than
## the first point still rolls at the first point's chance, and 70+ is
## deliberately a ceiling rather than a launching point for more.
@export var gem_chance_points: Array[Vector2] = [Vector2(10.0, 0.30), Vector2(70.0, 1.0)]
## The most a Gem stack this table ever opens can hold. Generous on purpose - a
## single fight is never meant to be the thing that opens a second stack of the
## same colour.
@export var gem_stack_max: int = 99

@export_group("Gems/Quantity")
## How many Gems one successful roll hands over, at minimum and at maximum -
## "quantity is 1-5".
@export var gem_quantity_min: int = 1
@export var gem_quantity_max: int = 5
## How strongly the roll leans toward [member gem_quantity_max] rather than
## sitting flat across the range, at the low and the high end of the battle
## sizes below - 0 is a plain uniform roll, and every step above it pulls the
## distribution toward the top of the range. See [method roll_gem_quantity].
@export var gem_quantity_bias_low: float = 0.0
@export var gem_quantity_bias_high: float = 3.0
## The battle sizes [member gem_quantity_bias_low] and [member gem_quantity_bias_high]
## are anchored at, reusing the same two readings [member gem_chance_points]
## already names so a designer is never tuning the same "small fight / big
## fight" idea against two different pairs of numbers.
@export var gem_quantity_reference_low_strength: float = 10.0
@export var gem_quantity_reference_high_strength: float = 70.0

# --- Hearts --------------------------------------------------------------

@export_group("Hearts")
## (battle size, drop chance) - "10 -> 1%, 30 -> 6%, 50 -> 12%, 70 -> 25%".
## Flat past both ends, exactly like the Gem curve - rule 5's own "70+ should
## not exceed the intended cap" is what a flat top means.
@export var heart_chance_points: Array[Vector2] = [
	Vector2(10.0, 0.01), Vector2(30.0, 0.06), Vector2(50.0, 0.12), Vector2(70.0, 0.25),
]
## How many Hearts one successful roll hands over below
## [member heart_quantity_bonus_strength], and the ceiling a bonus Heart above
## it is clamped to. Conservative on purpose - rule 5's own "keep it
## conservative" - a bonus of one Heart for the very largest fights and nothing
## cleverer.
@export var heart_quantity_base: int = 1
@export var heart_quantity_bonus_strength: float = 60.0
@export var heart_quantity_max: int = 2

# --- Ammunition ------------------------------------------------------------

@export_group("Ammunition")
## The weapons a fight can hand rounds for - see [CombatLootAmmoEntry]. One is
## picked at random, uniformly, on every successful roll.
@export var ammo_entries: Array[CombatLootAmmoEntry] = []
## (battle size, per-roll success chance) - "10 -> 60%, 20 -> 65%, 30 -> 70%".
## [b]Extrapolated[/b] past the last point rather than flattened, at the same
## slope the last two points already describe - "continue increasing with
## battle size" - and then held under [member ammo_chance_cap] so the roll can
## never reach a certain 100%, which combined with
## [member max_ammo_rolls_per_encounter] is what keeps "the roll repeats until
## it fails" a promise that always eventually pays off.
@export var ammo_chance_points: Array[Vector2] = [
	Vector2(10.0, 0.60), Vector2(20.0, 0.65), Vector2(30.0, 0.70),
]
@export_range(0.0, 1.0) var ammo_chance_cap: float = 0.95
## Hard ceiling on how many times the roll may repeat for one encounter, purely
## as a safety rail under [member ammo_chance_cap] - at a 95% cap the expected
## run is twenty-odd rolls, so this is never meant to be the number that
## actually stops one.
@export var max_ammo_rolls_per_encounter: int = 200
## (battle size, magazine multiplier) - the step ladder behind "Lever Action:
## 7/14/21", "Revolver: 6/12/18" and "Shotgun: 6/12/18": below the first point
## every roll pays one magazine, and each point crossed steps the multiplier up
## to its own value. [b]Never extrapolated past the last point[/b] - "larger
## battles may generate larger quantities" names three steps and stops there,
## unlike the chance curve above, so a battle past the last point simply keeps
## paying at the last step rather than growing without a ceiling.
@export var ammo_quantity_multiplier_points: Array[Vector2] = [
	Vector2(10.0, 1.0), Vector2(30.0, 2.0), Vector2(50.0, 3.0),
]
## What one Combat Loot ammo stack can ever hold, as a multiple of the weapon's
## own [member CombatLootAmmoEntry.base_magazine] - "Maximum ammo per inventory
## slot: base_magazine x10", which is Revolver 60, Shotgun 60, Lever Action 70.
@export var ammo_stack_multiplier: int = 10

# --- Boss Information ------------------------------------------------------

@export_group("Boss Information")
## What one Boss Information drop is called on the right side of the Horse
## Cart, before it is claimed - see [method HorseCartScreen._on_boss_info_stack_pressed].
@export var boss_info_display_name: String = "BOUNTY LEAD"
## The battle sizes that open another possible information slot - "10+ -> 1
## possible slot, 20+ -> 2 possible slots, 30+ -> 3 possible slots", read as a
## count of how many of these a battle's size has reached rather than as a
## lookup table, so a fourth point added later opens a fourth slot with nothing
## else here to change.
@export var boss_info_slot_thresholds: Array[float] = [10.0, 20.0, 30.0]
## The hard ceiling on slots however many thresholds a battle clears - "never
## exceed 3".
@export var max_boss_info_slots: int = 3
## (battle size, per-slot chance) - "10 -> 5%, 20 -> 15%, 30 -> 25%". Extrapolated
## past the last point at the same +10-per-10-strength slope named there -
## "continue the same scaling between higher 10-person steps" - and capped
## under [member boss_info_chance_cap] for the same reason the ammo roll is.
## Every open slot rolls this chance independently, so a three-slot battle can
## drop 0, 1, 2 or 3 pieces of information rather than one roll deciding all of
## them at once.
@export var boss_info_chance_points: Array[Vector2] = [
	Vector2(10.0, 0.05), Vector2(20.0, 0.15), Vector2(30.0, 0.25),
]
@export_range(0.0, 1.0) var boss_info_chance_cap: float = 0.95


# --- Sampling ---------------------------------------------------------------

func sample_gem_chance(strength: float) -> float:
	return _sample_points(gem_chance_points, strength, false, 1.0)


func sample_heart_chance(strength: float) -> float:
	return _sample_points(heart_chance_points, strength, false, 1.0)


func sample_ammo_chance(strength: float) -> float:
	return _sample_points(ammo_chance_points, strength, true, ammo_chance_cap)


func sample_boss_info_chance(strength: float) -> float:
	return _sample_points(boss_info_chance_points, strength, true, boss_info_chance_cap)


## The magazine multiplier one successful ammo roll is paid at, for this battle
## size - see [member ammo_quantity_multiplier_points]. Never below 1.0: a roll
## that succeeded always hands over at least one full magazine.
func sample_ammo_quantity_multiplier(strength: float) -> float:
	var multiplier := 1.0
	var sorted := ammo_quantity_multiplier_points.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for point: Vector2 in sorted:
		if strength >= point.x:
			multiplier = point.y
	return maxf(multiplier, 1.0)


## How many Boss Information slots this battle size has opened, thresholds
## crossed counted up and held under [member max_boss_info_slots].
func get_boss_info_slots(strength: float) -> int:
	var slots := 0
	for threshold: float in boss_info_slot_thresholds:
		if strength >= threshold:
			slots += 1
	return clampi(slots, 0, maxi(max_boss_info_slots, 0))


## One successful Gem roll's quantity, between [member gem_quantity_min] and
## [member gem_quantity_max] - "larger encounters should tend toward higher
## quantities" rather than a hard step, so the lean itself is what battle size
## drives: [code]pow(randf(), 1 / (1 + bias))[/code] is a uniform roll at
## bias 0 and climbs toward the top of the range as the bias this battle size
## earns rises, without ever making a small fight's five impossible or a big
## fight's one common.
func roll_gem_quantity(strength: float) -> int:
	var span := gem_quantity_reference_high_strength - gem_quantity_reference_low_strength
	var t := 0.0
	if span > 0.0001:
		t = clampf((strength - gem_quantity_reference_low_strength) / span, 0.0, 1.0)
	var bias := lerpf(gem_quantity_bias_low, gem_quantity_bias_high, t)
	var exponent := 1.0 / (1.0 + maxf(bias, 0.0))
	var roll := pow(randf(), exponent)
	var qty_span := maxi(gem_quantity_max - gem_quantity_min, 0)
	return gem_quantity_min + int(round(roll * float(qty_span)))


## One successful Heart roll's quantity - conservative by design, see
## [member heart_quantity_base]'s own doc.
func roll_heart_quantity(strength: float) -> int:
	var qty := heart_quantity_base
	if strength >= heart_quantity_bonus_strength:
		qty += 1
	return clampi(qty, 1, maxi(heart_quantity_max, heart_quantity_base))


## One [CombatLootAmmoEntry] at random, uniformly, or null when none are
## authored.
func pick_ammo_entry() -> CombatLootAmmoEntry:
	if ammo_entries.is_empty():
		return null
	return ammo_entries[randi() % ammo_entries.size()]


## One [CombatLootGemColor] at random, uniformly, or null when none are
## authored.
func pick_gem_color() -> CombatLootGemColor:
	if gem_colors.is_empty():
		return null
	return gem_colors[randi() % gem_colors.size()]


## Turns a list of (battle size, value) points into a value for [param x],
## which may land before the first point, after the last, or between two of
## them.
##
## [b]Before the first point, and between any two, it is a straight line[/b] -
## every curve this table samples was handed over as points to land on exactly,
## with nothing steeper or gentler implied between them.
##
## [b]Past the last point, [param extrapolate] decides.[/b] Off, the curve is
## flat from there on - the shape "70+ -> 100%" and "should not exceed the
## intended cap" both ask for. On, the line keeps the slope of the last segment
## rather than levelling off - "continue increasing with battle size" - held
## under [param hard_cap] so an extrapolated chance can never reach a certain
## thing.
static func _sample_points(
	points: Array[Vector2], x: float, extrapolate: bool, hard_cap: float
) -> float:
	if points.is_empty():
		return 0.0

	var sorted := points.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var first: Vector2 = sorted[0]
	if x <= first.x:
		return clampf(first.y, 0.0, hard_cap)

	var last: Vector2 = sorted[sorted.size() - 1]
	if x >= last.x:
		if not extrapolate or sorted.size() < 2:
			return clampf(last.y, 0.0, hard_cap)
		var prev: Vector2 = sorted[sorted.size() - 2]
		var span := last.x - prev.x
		if span <= 0.0001:
			return clampf(last.y, 0.0, hard_cap)
		var slope := (last.y - prev.y) / span
		return clampf(last.y + slope * (x - last.x), 0.0, hard_cap)

	for i in range(sorted.size() - 1):
		var a: Vector2 = sorted[i]
		var b: Vector2 = sorted[i + 1]
		if x >= a.x and x <= b.x:
			var t := 0.0 if b.x - a.x <= 0.0001 else (x - a.x) / (b.x - a.x)
			return clampf(lerpf(a.y, b.y, t), 0.0, hard_cap)

	return clampf(last.y, 0.0, hard_cap)
