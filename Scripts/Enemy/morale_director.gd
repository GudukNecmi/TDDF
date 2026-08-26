class_name MoraleDirector
extends Node
## Whether a man's nerve holds, and what happens when it does not.
##
## [b]It is one node in the world rather than anything on the enemy.[/b] The same
## reason [GunshotSurrender] is one node: an enemy's job is to fight, and "how
## frightening is this fight" is a fact about the fight rather than about any man
## in it. Every roll in the game goes through [method check], so the odds exist in
## exactly one place and switching the whole system off is switching off one node.
##
## [b]It is event-driven, never polled.[/b] Nothing here runs per frame. Morale is
## asked about only when something has actually happened to ask about:
##
##   [codeblock]
##   a shot goes off beside him   GunshotSurrender -> check(enemy, NEAR_MISS)
##   the man next to him dies     this file        -> check(each neighbour, ALLY_DIED)
##   [/codeblock]
##
## Both are one-shot events and each is worth exactly one roll. The near miss is
## already guarded against double-rolling a shotgun blast - see
## [GunshotSurrender], where one trigger pull is one roll however many pellets it
## puts in the air - and a death can only happen once, so a continuous event
## cannot re-roll itself here. [method check] refuses a man it has already asked
## about within [member repeat_guard] anyway, which is what makes a second event
## landing on the same instant harmless.
##
## [b]Everybody rolls, and everybody is scored on the whole encounter.[/b] The odds
## are drawn from what the fight still owes the player - the men on the field plus
## the men still to walk in - rather than from how many happen to be on screen; see
## [method get_encounter_enemy_count]. That is what stops an ambush of thirty, which
## arrives a handful at a time, from reading as a fight of four and breaking men in
## its opening seconds. Nobody is asked at all until the encounter is down to
## [member surrender_activates_at], and below that a lone survivor is the most
## likely to fold, without "the last one" being a case anywhere in the code.
##
## [b]Nothing about the outcomes is built here.[/b] Giving up is
## [method EnemySurrender.surrender] and going berserk is
## [method EnemyEnrage.enrage]; this only decides which of them, if either,
## happens. An enemy carrying neither component simply never reacts.

## Emitted when a check actually broke somebody, with the enemy that gave up.
signal surrendered(enemy: Node2D, source: Source)
## Emitted when a check sent somebody berserk instead.
signal enraged(enemy: Node2D, source: Source)

## Group this node joins so anything can find it without being wired to it.
const GROUP := &"morale_director"

## What prompted a check. Reported alongside both outcomes so a listener - a sound,
## a statistic - can tell a man who folded under fire from one who folded watching
## his friend die, without either caller having to say so twice.
enum Source {
	## Something else asked, and did not say why.
	UNKNOWN,
	## A shot went off close enough to be fired at him.
	NEAR_MISS,
	## Somebody near him was killed.
	ALLY_DIED,
	## He was shot and lived. The one continuous-looking event of the three, and the
	## only one raised by the man himself rather than by something that happened
	## beside him - see [method EnemySurrender._on_damaged], which raises it once per
	## hit that does not kill him.
	WOUNDED,
}

@export var enabled: bool = true
## Group the living enemies are counted in. The same one every other search reads,
## so a man who has given up or run is already not in it and is already not counted
## as somebody still fighting.
@export var enemy_group: StringName = &"enemies"
## The spawner whose new enemies are followed to their deaths. Left empty it is
## found by class, which is what every other reader of it does.
@export var spawner_path: NodePath = ^"../EnemySpawner"

@export_group("Surrender chance")
## The encounter total at and above which nobody folds at all.
##
## [b]It is the whole formula.[/b] The chance is
## [code](ceiling - total) percent[/code], clamped into
## [code]0 .. ceiling[/code] - so at 10 it reads exactly as intended: ten men or
## more still owed and nobody gives up, nine men and it is 1%, two men and it is
## 8%, and the last man the encounter has left is the most likely of all to fold.
## Raising this raises both the ceiling and the maximum together, which is what
## keeps the two ends of the curve from having to be tuned against each other.
@export var count_ceiling: int = 10
##
## The last man alive is a count of 1, which the formula alone would make
## [code]ceiling - 1[/code] = 9%. He is the intended maximum instead - see
## [member lone_enemy_takes_the_maximum] - so the stated ceiling of 10% is a number
## somebody can actually reach rather than one the count convention quietly keeps
## a percent short of.
@export var max_chance_percent: float = 10.0
## Whether the last man standing is given [member max_chance_percent] outright
## rather than what the formula gives him.
##
## On. Off leaves the curve pure and tops out at 9%.
@export var lone_enemy_takes_the_maximum: bool = true
## Whether a man who has gone berserk is still counted as somebody fighting.
##
## On, and he emphatically is - see [EnemyEnrage]. He is the most active enemy on
## the field, and leaving him out would make the field read as emptier than it is
## and quietly raise everybody else's chance of folding.
@export var counts_enraged: bool = true
## The encounter total at or below which anybody can fold at all.
##
## [b]It is the whole of "not yet".[/b] Below this every curve is scored as normal;
## above it every curve is flatly zero, whatever the men currently on screen happen
## to number. A search that will put thirty men on the road is not a fight anybody
## is losing yet, and morale has no business being asked about until it has been
## worn down to something a man could reasonably fold in front of.
##
## Raising it above [member count_ceiling] changes nothing the ten-man curve does,
## because that curve already pays nothing at a count that high. It exists for the
## curves that reach further up - and so that "when does surrender switch on" is one
## number in the inspector rather than a property of whichever formula is being read.
@export var surrender_activates_at: int = 20
## Whether every curve is scored on the whole encounter rather than on the men who
## happen to be standing next to the player.
##
## [b]On, and it is the difference between eighteen men and three.[/b] An ambush of
## eighteen arrives a handful at a time, so the field is nearly always thin however
## large the fight actually is - and scoring on what is visible would make the first
## shot of a huge encounter as frightening as the last shot of a small one. The
## number asked for is what the encounter still owes the player: everybody on the
## field plus everybody still to walk in. It falls as they are killed, give up or
## run, so the curves steepen as the fight is actually won rather than as men queue
## up off-screen.
##
## Off scores every curve on the live count instead.
@export var counts_the_encounter: bool = true
## The encounter whose books are read. Left unresolved - a wave with no ambush
## running, a scene that keeps no director - the live count is used instead, so
## this can never leave a man unscored.
@export var ambush_director_path: NodePath = ^"../AmbushWaveDirector"

@export_group("Wounded surrender chance")
## How likely a man who has been shot and is still standing is to fold, as a
## percentage.
##
## [b]It is a flat rarity, not a curve.[/b] A shot that went past you and a friend
## dying beside you are things that happen [i]near[/i] a man, and how many of them
## are left is what makes those frightening; being hit is something that happens
## [i]to[/i] him, and it is the hit itself that breaks him rather than the state of
## the fight around it. So this is one number rather than a slope, and it is still
## held off entirely until the encounter is down to
## [member surrender_activates_at].
@export var wounded_chance_percent: float = 3.0

@export_group("Enrage chance")
## How often a check sends a man berserk instead of breaking him, as a percentage.
##
## [b]Rolled first and separately.[/b] It is a flat rarity rather than anything
## drawn from the count: a man watching his friend die and losing his temper is not
## more likely because the field is thin. See [method check] for the order.
@export var enrage_chance_percent: float = 1.0
## Whether going berserk is on the table at all. Off leaves the surrender roll as
## the only outcome, which is what the game had before this existed.
@export var enrage_enabled: bool = true
## Whether being hit can send a man berserk as well as break him.
##
## [b]Off.[/b] Losing your temper in this game is something you do watching what
## happens to somebody else - see [constant Source.ALLY_DIED], which is where the
## 1% belongs and where it is untouched. A wounded man has exactly two possible
## reactions and both of them are his own: he folds, or he keeps coming.
@export var wounded_can_enrage: bool = false

@export_group("A nearby death")
## Whether a man being killed asks the men around him how they feel about it.
@export var checks_on_ally_death: bool = true
## How close somebody has to be to be shaken by a death, in pixels. Nearby, not
## everyone in the arena: this is the man who was standing next to him.
@export var ally_radius: float = 320.0
## How many of the neighbours are asked, nearest first. A cap rather than a rule -
## it stops one death in a packed crowd making a dozen rolls at once, which would
## turn a stated 1% into better than one in five that somebody goes berserk.
@export var max_neighbours: int = 4

@export_group("Guards")
## How long one enemy is left alone after being asked, in seconds.
##
## Insurance rather than the rule. The events themselves are already one-shot, so
## this only ever swallows a second event landing on the same instant as the first
## - two men dying to one shotgun blast, a blast that both kills and passes close.
@export var repeat_guard: float = 0.25

var _spawner: EnemySpawner
var _ambush: AmbushWaveDirector
## When each enemy was last asked, by instance id. Entries are dropped as their
## enemy leaves, so this cannot grow across a long run.
var _asked: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_bind_spawner()


## The one in the running scene, for anything that needs to ask without being wired
## to it.
static func get_active(from_node: Node) -> MoraleDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as MoraleDirector


## Whether anybody's nerve can be asked about at all right now.
##
## [b]It is a fact about the encounter, not about the man.[/b] Above
## [member surrender_activates_at] every curve reads zero - see
## [method get_chance_for] - so the whole of "the fight is still too big for
## anybody to be folding" is one test in one place rather than a floor written into
## each formula.
func is_surrender_active(total: int = -1) -> bool:
	var count := total if total >= 0 else get_encounter_enemy_count()
	return count > 0 and count <= maxi(surrender_activates_at, 0)


## How likely a check is to break one man right now, as a fraction of 1.
##
## [param active] below 0 counts the encounter - see
## [method get_encounter_enemy_count]. Handed one instead, a caller can ask what
## the odds would be at a given size, which is what a test does.
func get_surrender_chance(active: int = -1) -> float:
	var count := active if active >= 0 else get_encounter_enemy_count()
	if count <= 0 or not is_surrender_active(count):
		return 0.0

	var percent := float(count_ceiling - count)
	if lone_enemy_takes_the_maximum and count <= 1:
		percent = max_chance_percent
	return clampf(percent, 0.0, max_chance_percent) / 100.0


## How many men every curve is measured against: the encounter's own total when
## there is an encounter, and the live field when there is not.
##
## [b]Nothing is counted here.[/b] Both numbers already exist and are already
## authoritative - see [method AmbushWaveDirector.get_enemies_alive] and
## [method AmbushWaveDirector.get_enemies_owed], which are the same books the fight's
## own ending is settled from - so this only chooses between them. A second tally
## kept alongside them would be a second thing to be wrong.
func get_encounter_enemy_count() -> int:
	if not counts_the_encounter:
		return get_active_enemy_count()

	var ambush := _resolve_ambush()
	if ambush == null or not ambush.is_running():
		return get_active_enemy_count()
	return ambush.get_enemies_alive() + ambush.get_enemies_owed()


## The encounter in this world, by path first and by group after - the same order
## every other lookup in this file uses.
func _resolve_ambush() -> AmbushWaveDirector:
	if _ambush != null and is_instance_valid(_ambush):
		return _ambush
	_ambush = get_node_or_null(ambush_director_path) as AmbushWaveDirector
	if _ambush == null and is_inside_tree():
		_ambush = get_tree().get_first_node_in_group(
			AmbushWaveDirector.GROUP) as AmbushWaveDirector
	return _ambush


## How likely a man who has just been hit and lived is to fold, as a fraction of 1.
##
## The flat rarity on [member wounded_chance_percent], held off entirely until the
## encounter is down to [member surrender_activates_at] - so the first shot of a
## thirty-man search breaks nobody, and the same shot late in the same search is
## worth its stated three percent.
##
## Asked of the whole encounter rather than of the men currently on screen - see
## [method get_encounter_enemy_count].
func get_wounded_surrender_chance(active: int = -1) -> float:
	var count := active if active >= 0 else get_encounter_enemy_count()
	if count <= 0 or not is_surrender_active(count):
		return 0.0
	return clampf(wounded_chance_percent, 0.0, 100.0) / 100.0


## The curve [param source] is asked on. One place, so every caller of
## [method check] is scored by the same rule and adding a fourth kind of event is
## adding a line here.
func get_chance_for(source: Source) -> float:
	if source == Source.WOUNDED:
		return get_wounded_surrender_chance()
	return get_surrender_chance()


## Whether [param source] is allowed to send a man berserk at all.
func _can_enrage(source: Source) -> bool:
	return source != Source.WOUNDED or wounded_can_enrage


## How likely a check is to send one man berserk, as a fraction of 1.
func get_enrage_chance() -> float:
	if not enrage_enabled:
		return 0.0
	return clampf(enrage_chance_percent, 0.0, 100.0) / 100.0


## How many men are still fighting: everybody in [member enemy_group] who is alive
## and is not already running away.
##
## The group is already most of the answer - a man who has given up leaves it as he
## goes down, and a corpse fails [method EnemyTargeting.is_valid] - so the only
## thing left to take out is a retreat, which stays in the group on purpose so that
## a shot already in the air can still land on it.
func get_active_enemy_count() -> int:
	if not is_inside_tree():
		return 0

	var count := 0
	for node: Node in get_tree().get_nodes_in_group(enemy_group):
		var enemy := node as Node2D
		if enemy == null or not EnemyTargeting.is_valid(enemy):
			continue
		if enemy.has_method(&"is_fleeing") and enemy.call(&"is_fleeing"):
			continue
		if not counts_enraged and EnemyEnrage.is_enraged(enemy):
			continue
		count += 1
	return count


## Asks one man how he feels about what just happened, and applies the answer.
##
## Returns whether anything came of it.
##
## [b]The rare outcome is rolled first.[/b] Berserk and broken are mutually
## exclusive endings for the same man, so one of them has to be asked before the
## other; asking the 1% first is what keeps it a true 1% rather than 1% of whatever
## the surrender roll happened to leave over.
##
## [b]A man who is already something is not asked at all.[/b] Down, running,
## berserk, dead or not yet in the world - see [method _can_be_asked]. That guard
## is the whole of "do not roll a second state onto somebody who already has one".
func check(enemy: Node2D, source: Source = Source.UNKNOWN) -> bool:
	if not enabled or not _can_be_asked(enemy):
		return false

	_asked[enemy.get_instance_id()] = _now()

	if _can_enrage(source) and randf() < get_enrage_chance() and _enrage(enemy):
		enraged.emit(enemy, source)
		return true

	if randf() >= get_chance_for(source):
		return false
	if not _break(enemy):
		return false

	surrendered.emit(enemy, source)
	return true


## Asks everybody standing near [param around] how they feel, nearest first.
## Returns how many of them reacted.
##
## The dead man himself is excluded, which he already is by being dead, and the cap
## is applied to who is asked rather than to who reacts - so a death in a crowd is
## one event with a fixed number of rolls in it however thick the crowd is.
func check_around(around: Vector2, source: Source = Source.ALLY_DIED,
		exclude: Array = []) -> int:
	if not enabled:
		return 0

	var reacted := 0
	for enemy: Node2D in EnemyTargeting.nearest_many(
			self, around, maxi(max_neighbours, 0), ally_radius, exclude):
		if check(enemy, source):
			reacted += 1
	return reacted


## Whether this man is in a state to be asked anything.
##
## Surrendered, enraged, fleeing, dead or already asked this instant - any of them
## and the answer is no. It is deliberately one list in one place: every caller
## gets the same refusal, and adding a future state that should not be overwritten
## is adding a line here rather than a check in each of them.
func _can_be_asked(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	if not EnemyTargeting.is_valid(enemy):
		return false

	if enemy.has_method(&"is_fleeing") and enemy.call(&"is_fleeing"):
		return false
	if EnemyEnrage.is_enraged(enemy):
		return false

	var surrender := EnemySurrender.find_on(enemy)
	if surrender != null and surrender.has_surrendered():
		return false

	var last: float = _asked.get(enemy.get_instance_id(), -1.0)
	return last < 0.0 or _now() - last >= repeat_guard


## Puts one man on the floor. The component refuses a man who has already gone
## down or already died, which is what keeps a shot landing on the same frame from
## being overruled.
func _break(enemy: Node2D) -> bool:
	var surrender := EnemySurrender.find_on(enemy)
	return surrender != null and surrender.surrender()


## Sends one man berserk. An enemy carrying no [EnemyEnrage] simply cannot, which
## leaves the surrender roll to be made as normal.
func _enrage(enemy: Node2D) -> bool:
	var component := EnemyEnrage.find_on(enemy)
	return component != null and component.enrage()


## Follows every enemy the world builds to its death, so a death anywhere can shake
## whoever was standing near it.
##
## Hung off the spawner rather than off a group scan for the same reason
## [DangerFinale] does it: the spawner is the one place enemies are made, so one
## connection covers an arena round, a road ambush, a Danger and a boss's support
## without any of them being named.
func _bind_spawner() -> void:
	if not checks_on_ally_death:
		return

	_spawner = get_node_or_null(spawner_path) as EnemySpawner
	if _spawner == null:
		_spawner = _find_spawner()
	if _spawner == null or _spawner.spawned.is_connected(_on_enemy_spawned):
		return
	_spawner.spawned.connect(_on_enemy_spawned)


## The world's spawner, when the exported path did not find it - a scene that keeps
## it somewhere else still gets its deaths noticed.
func _find_spawner() -> EnemySpawner:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node: Node in scene.find_children("*", "EnemySpawner", true, false):
		var spawner := node as EnemySpawner
		if spawner != null:
			return spawner
	return null


func _on_enemy_spawned(enemy: Node2D) -> void:
	if enemy == null or not checks_on_ally_death:
		return

	var health := _find_health(enemy)
	if health == null:
		return
	health.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)


## One man is down, and the men around him have seen it.
##
## Deferred by a frame on purpose: the death has to have finished landing before
## the neighbours are counted, or the man dying would still be in the group and the
## field would read as one larger than it is - which is exactly one percent of
## everybody's chance to fold.
func _on_enemy_died(enemy: Node2D) -> void:
	if not enabled or not checks_on_ally_death:
		return
	if enemy == null or not is_instance_valid(enemy):
		return

	_asked.erase(enemy.get_instance_id())
	_check_around_deferred.call_deferred(enemy.global_position, enemy)


func _check_around_deferred(around: Vector2, dead: Node2D) -> void:
	var skip: Array = []
	if dead != null and is_instance_valid(dead):
		skip.append(dead)
	check_around(around, Source.ALLY_DIED, skip)


func _find_health(enemy: Node) -> Health:
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


## Wall-clock seconds, unaffected by the tree being paused or the world being run
## in slow motion - the guard is about two events arriving together, which is a
## fact about the frame rather than about game time.
func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
