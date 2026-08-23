class_name RunEndDefeat
extends Node
## Clears the arena when the run's clock runs out, by sending what is still standing
## home rather than deleting it - or killing it.
##
## [WaveManager] deliberately touches nothing of its own when the clock stops - it
## only stops spawning - so this is where "and then the enemies go" lives. Keeping
## the two apart means the manager stays a spawner and the ending can be retimed,
## restaged or switched off without it knowing.
##
## [b]They run away; they do not die.[/b] Every enemy is asked to play its own
## ending through [EnemyEscape] - knife on the floor, untouchable, gone over the
## horizon - and this only decides who and when. That is deliberate: an enemy the
## player never beat should not be played out as though they had, and a death that
## the player did not cause has no business producing a body, a kill or a drop of
## blood.
##
## [b]Not all of them run.[/b] An encounter ending is also the moment somebody's
## nerve can go instead, so before anybody is sent anywhere one roll is made against
## [member surrender_chance] and, if it lands, [member surrender_count] of them are
## picked out to give up rather than escape - see [EnemySurrender]. It is a roll for
## the encounter and not a roll per enemy, which is what makes "half the time, one of
## them surrenders" true regardless of whether four were left standing or forty.
##
## [EnemyDefeat] is still the fallback for an enemy carrying no escape of its own,
## so nothing built differently is left standing in an arena that has finished. It
## is not the ordinary path any more.
##
## The [member stagger] is what turns a whole arena's worth of enemies into a ripple
## across the field rather than one synchronised blink, and it is applied per enemy
## so no timer is kept here.

## Emitted once every enemy has been told, not once they have all gone.
signal cleared(count: int)
## Emitted for each enemy that gave up rather than ran.
signal surrendered(enemy: Node)

## Run whose clock this follows.
@export var wave_manager_path: NodePath = ^"../WaveManager"
## Group the enemies are found by.
@export var enemy_group: StringName = &"enemies"
## Pause before the first one goes, so the clock hitting zero registers first.
@export var lead_in: float = 0.35
## Gap between one enemy and the next.
@export var stagger: float = 0.07
## Ceiling on the total spread, however many enemies are alive. Without it a
## packed arena would take an unreasonably long time to clear at a fixed gap.
@export var max_spread: float = 2.2

@export_group("Surrender")
## How often an encounter ends with somebody giving up rather than everybody
## running. One roll for the whole encounter, made once, before anybody is told
## anything.
@export_range(0.0, 1.0, 0.01) var surrender_chance: float = 0.5
## How many of them give up when that roll lands. More than there are enemies simply
## means all of them.
@export var surrender_count: int = 1

@onready var _manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager

var _fired: bool = false


func _ready() -> void:
	if _manager != null:
		_manager.run_finished.connect(_on_run_finished)


## Sends every enemy currently alive home. Safe to call directly - a debug key, or a
## future "end the run now" - and guarded so it only ever happens once per run.
func clear_arena() -> void:
	if _fired:
		return
	_fired = true

	var enemies := get_tree().get_nodes_in_group(enemy_group)
	# Decided before anybody is told anything, so who gives up is drawn from
	# everybody who was still standing rather than from whoever happened to be left
	# once the ripple had started.
	var giving_up := _pick_surrenders(enemies)

	# Squeezed rather than truncated, so a crowded arena clears in the same window
	# a sparse one does and the last enemy is never left standing for a minute.
	var gap := stagger
	if max_spread > 0.0 and enemies.size() > 1:
		gap = minf(stagger, max_spread / float(enemies.size() - 1))

	var told := 0
	for enemy: Node in enemies:
		if giving_up.has(enemy) and _give_up(enemy):
			told += 1
			continue
		if _send_home(enemy, lead_in + gap * float(told)):
			told += 1

	cleared.emit(told)


## Which of [param enemies] give up rather than run.
##
## The roll comes first and covers the whole encounter; only once it has landed is
## anybody drawn. An enemy carrying no [EnemySurrender] is dropped from the draw
## rather than wasting it, so a mixed field cannot quietly turn a successful roll
## into nothing happening.
func _pick_surrenders(enemies: Array) -> Array[Node]:
	var chosen: Array[Node] = []
	if surrender_count <= 0 or enemies.is_empty():
		return chosen
	if randf() >= surrender_chance:
		return chosen

	var pool := enemies.duplicate()
	pool.shuffle()
	for enemy: Node in pool:
		if chosen.size() >= surrender_count:
			break
		if EnemySurrender.find_on(enemy) != null:
			chosen.append(enemy)
	return chosen


## Puts one enemy on the floor. Returns whether it actually went down - the
## component refuses an enemy that has already given up or already died, which is
## what keeps a shot landing on the same frame from being overruled.
func _give_up(enemy: Node) -> bool:
	var surrender := EnemySurrender.find_on(enemy)
	if surrender == null or not surrender.surrender():
		return false
	surrendered.emit(enemy)
	return true


## One enemy's ending, and which of the two it gets. Returns whether it was told
## anything at all.
##
## The escape is preferred wherever there is one; the defeat is what an enemy built
## without one still gets, so nothing can be left standing in a finished arena.
func _send_home(enemy: Node, delay: float) -> bool:
	var escape := _find_escape(enemy)
	if escape != null:
		if escape.is_escaping():
			return false
		escape.escape(delay)
		return true

	var defeat := _find_defeat(enemy)
	if defeat == null or defeat.is_defeated():
		return false
	defeat.defeat(delay)
	return true


## Found by type rather than by a fixed child name, for the same reason the defeat
## is: an enemy that keeps its components somewhere else still ends properly.
func _find_escape(enemy: Node) -> EnemyEscape:
	for node: Node in enemy.find_children("*", "EnemyEscape", true, false):
		var escape := node as EnemyEscape
		if escape != null:
			return escape
	return null


func _on_run_finished() -> void:
	clear_arena()


## Found by type rather than by a fixed child name, so an enemy that keeps its
## defeat component somewhere else still ends properly.
func _find_defeat(enemy: Node) -> EnemyDefeat:
	for node: Node in enemy.find_children("*", "EnemyDefeat", true, false):
		var defeat := node as EnemyDefeat
		if defeat != null:
			return defeat
	return null
