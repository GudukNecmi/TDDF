extends Node
## Wires every one of the game's combat-ending final kills to the one
## [KillCam] - "reuse the same logic for every combat type" kept literal: one
## companion, listening to the signals each fight already emits for its own
## reasons, rather than a Kill Cam call written into three different fights.
##
## [b]Three sources, one call.[/b]
##   * [signal AmbushWaveDirector.last_attacker_defeated] - the World Map's
##     own bandit contacts and bounty-camp fights (both fought through
##     [WorldMapCombatBridge]), a road ambush, and a Trouble Danger: every
##     one of them is this same director, so wiring it once covers all four
##     without any of them being named here.
##   * [signal BossDefeat.boss_defeated] - a Mini Boss's own beaten moment,
##     read for its beaten [Node2D] through [method MiniBossDirector.get_boss],
##     since the signal itself only carries the contract and its reward.
##   * The plain Arena round - [WaveManager] never tracks a death at all, so
##     this follows every enemy [EnemySpawner] builds itself (see
##     [signal EnemySpawner.spawned]) and asks, on each one's own
##     [signal Health.died], whether the field it leaves behind is both empty
##     and genuinely finished: [method WaveManager.is_collection_phase] true,
##     so nothing more is coming. Without that second half, an ordinary lull
##     between two waves - the ground clear for a moment before the next one
##     streams in - would read as a final kill and fire a Kill Cam over a
##     round that has not ended at all.
##
## Nothing about the game deciding a fight is over lives here. This only ever
## listens for the moment a fight already says is its last one and turns it
## into [method KillCam.trigger].

@export var kill_cam_path: NodePath = ^"../KillCam"
@export var ambush_path: NodePath = ^"../AmbushDirector"
@export var boss_defeat_path: NodePath = ^"../BossDefeat"
@export var boss_director_path: NodePath = ^"../MiniBossDirector"
@export var spawner_path: NodePath = ^"../EnemySpawner"
@export var wave_manager_path: NodePath = ^"../WaveManager"
## Group every living enemy joins - the same group every director here
## already reads its own field off.
@export var enemy_group: StringName = &"enemies"

var _kill_cam: KillCam
var _wave_manager: WaveManager
var _boss_director: MiniBossDirector
## Guards the Arena-round path against firing twice for one collection
## phase: the group can read empty on more than one death in a row once the
## last few enemies go down together, and only the first of them is the
## final kill.
var _arena_kill_reported: bool = false


func _ready() -> void:
	_kill_cam = get_node_or_null(kill_cam_path) as KillCam
	if _kill_cam == null:
		_kill_cam = KillCam.get_active(self)

	_wire_ambush()
	_wire_boss()
	_wire_wave_manager()


func _wire_ambush() -> void:
	var ambush := get_node_or_null(ambush_path) as AmbushWaveDirector
	if ambush == null:
		ambush = AmbushWaveDirector.get_active(self)
	if ambush == null:
		return
	ambush.last_attacker_defeated.connect(_on_ambush_final_kill)


func _on_ambush_final_kill(enemy: Node2D) -> void:
	_trigger(enemy)


func _wire_boss() -> void:
	var defeat := get_node_or_null(boss_defeat_path) as BossDefeat
	if defeat == null:
		defeat = BossDefeat.get_active(self)
	if defeat == null:
		return

	_boss_director = get_node_or_null(boss_director_path) as MiniBossDirector
	if _boss_director == null:
		_boss_director = MiniBossDirector.get_active(self)

	defeat.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated(_bounty: Bounty, _reward: int) -> void:
	var boss: Node2D = null
	if _boss_director != null and is_instance_valid(_boss_director):
		boss = _boss_director.get_boss()
	_trigger(boss)


## Watched rather than told: [WaveManager] itself never learns whether an
## enemy it spawned is alive or dead, so this is what stands in for the
## "final kill" [WaveManager] does not have a signal for.
func _wire_wave_manager() -> void:
	var spawner := get_node_or_null(spawner_path) as EnemySpawner
	_wave_manager = get_node_or_null(wave_manager_path) as WaveManager
	if spawner == null or _wave_manager == null:
		return

	spawner.spawned.connect(_on_enemy_spawned)
	_wave_manager.run_started.connect(_on_arena_round_started)


func _on_arena_round_started() -> void:
	_arena_kill_reported = false


func _on_enemy_spawned(enemy: Node2D) -> void:
	var health := _find_health(enemy)
	if health == null:
		return
	health.died.connect(_on_arena_enemy_died.bind(enemy), CONNECT_ONE_SHOT)


func _on_arena_enemy_died(enemy: Node2D) -> void:
	if _arena_kill_reported or _wave_manager == null or not is_instance_valid(_wave_manager):
		return
	# Only once spawning has genuinely stopped - see the class doc - so a
	# quiet moment between two waves is never mistaken for the round's own
	# last man.
	if not _wave_manager.is_collection_phase():
		return
	if not get_tree().get_nodes_in_group(enemy_group).is_empty():
		return

	_arena_kill_reported = true
	_trigger(enemy)


func _trigger(subject: Node2D) -> void:
	if _kill_cam != null and is_instance_valid(_kill_cam):
		_kill_cam.trigger(subject)


func _find_health(node: Node) -> Health:
	for child: Node in node.find_children("*", "Health", true, false):
		var health := child as Health
		if health != null:
			return health
	return null
