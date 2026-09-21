class_name RunMiniBossFight
extends Node
## A run map mini boss point, fought: the support group first, then the man.
##
## [b]It is the sequencer and nothing else.[/b] Every part of what happens here
## already existed and none of it is reimplemented:
##
##   [codeblock]
##   support group   ->  cleared  ->  he arrives  ->  introduction  ->  the fight  ->  he falls  ->  home
##   AmbushWaveDirector   this file   MiniBossDirector   BossArena      BossPhases    BossDefeat   WorldMapCombatBridge
##   [/codeblock]
##
## The crowd is the same [AmbushWaveDirector] fight every bandit point opens,
## placed by [method WorldMapCombatBridge._open_staged_fight] before this node
## hears anything. The man is built by [MiniBossDirector] at one of its own
## authored [MiniBossTier] rungs, out of the world's own [EnemySpawner], and is
## therefore the ordinary enemy with the ordinary AI that a bounty boss is. The
## introduction is [method BossArena.play_intro], the fight's phases are
## [BossPhases] and the ending - the caught last blow, the fall, the name struck
## through, the camera coming home - is [BossDefeat], which arms itself off
## [signal MiniBossDirector.fight_started] without being told this fight is any
## different.
##
## [b]What is actually new is the order.[/b] A bounty boss stands in the region
## with his men round him and is walked up to. A run map mini boss point is an
## arrival: the piece lands on the point, the fight opens against his men, and he
## comes in over their bodies. So this node holds the bridge's ending shut while
## the first half plays - see [method WorldMapCombatBridge.hold_the_ending] -
## brings him in when the field clears, and hands the ending back when he is
## down. Clearing the crowd is the cue, never the way home.
##
## [b]He is not paid for yet.[/b] There is no contract behind a run map boss, so
## [BossDefeat] finds no bounty, pays nothing and closes nothing out - which is
## exactly what is wanted until this point has rewards of its own.

## Emitted as the support group is cleared and the man starts walking in.
signal boss_arriving(at: Vector2)
## Emitted once he is standing in the arena and the introduction has begun.
signal boss_arrived(boss: Node2D)
## Emitted when the encounter is over and the way back to the run map is asked
## for, whether or not he was beaten.
signal encounter_finished(victory: bool)

@export_group("Wiring")
## The encounter bridge whose staged fight this takes over the second half of.
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"
## The crowd director whose clearing brings the man in.
@export var ambush_path: NodePath = ^"../AmbushDirector"
## The boss system that builds him. [b]There is no run map boss[/b] - he is the
## same man, at the same rungs, as a bounty target.
@export var director_path: NodePath = ^"../MiniBossDirector"
## The ending, watched for the moment the camera comes home.
@export var defeat_path: NodePath = ^"../BossDefeat"

@export_group("How he arrives")
## How long the arena is left empty between the last of his men going down and
## him walking in, in seconds. The beat that makes his entrance an entrance.
@export var arrival_delay: float = 1.1
## How hard the camera is shaken as he lands, in pixels, through the same
## [method CameraController.shake] channel every other impulse in the game uses -
## so a shake already running is deepened rather than replaced.
@export var arrival_shake: float = 13.0
## How long that shake lasts, in seconds.
@export var arrival_shake_time: float = 0.45
## How long the world is held still as he lands, in seconds, through the world's
## own [HitStop]. 0 turns the freeze off and leaves the shake.
@export var arrival_hit_stop: float = 0.12
## The burst thrown up where he lands. Any scene works; one with a
## [OneShotParticles] on it is played, anything else simply appears and is left
## to look after itself. Left empty, he arrives with the shake alone.
@export var arrival_effect: PackedScene
## How far up the effect is placed from the point he is standing on, in pixels.
## Negative is up the screen, which is where dust off a pair of boots goes.
@export var arrival_effect_offset := Vector2(0.0, -20.0)
## How much larger the burst is than the scene was authored at. A man landing
## throws up more than a shot does.
@export var arrival_effect_scale: float = 2.2

var _bridge: WorldMapCombatBridge
var _ambush: AmbushWaveDirector
var _director: MiniBossDirector
var _defeat: BossDefeat
## Who is coming, from the moment the fight opens. Null whenever this node has
## no encounter of its own, which is every fight but a mini boss point's.
var _boss: MiniBossBrief
## Set once he has been built, so a second clearing cannot bring in a second man.
var _arrived: bool = false


func _ready() -> void:
	var bridge := _resolve_bridge()
	if bridge == null:
		return
	if not bridge.mini_boss_encounter_started.is_connected(_on_encounter_started):
		bridge.mini_boss_encounter_started.connect(_on_encounter_started)


## Who this fight is against, or null when it is not one of these.
func get_boss_brief() -> MiniBossBrief:
	return _boss


## Whether the man himself is in the arena yet. False for the whole of the first
## half.
func has_arrived() -> bool:
	return _arrived


# --- The first half -------------------------------------------------------------

func _on_encounter_started(boss: MiniBossBrief, _support_count: int) -> void:
	var bridge := _resolve_bridge()
	var ambush := _resolve_ambush()
	if bridge == null or ambush == null or boss == null:
		return

	_boss = boss
	_arrived = false

	# Taken before the first man is shot, so there is no window in which a quick
	# clearing would send the player home without ever meeting the boss.
	bridge.hold_the_ending(self)

	if not ambush.cleared.is_connected(_on_support_cleared):
		ambush.cleared.connect(_on_support_cleared, CONNECT_ONE_SHOT)


## His men are down. The arena is left empty for a beat and then he walks in.
func _on_support_cleared() -> void:
	if _boss == null or _arrived:
		return
	if _resolve_director() == null:
		# No boss system in this arena - which would leave the player standing in
		# an empty arena with no way out. The fight is ended as the win it is.
		_finish(true)
		return
	_after(arrival_delay, _bring_him_in)


# --- The second half ------------------------------------------------------------

## Stands him up, shakes the ground he lands on, and hands the camera to the
## introduction the project already plays over a mini boss.
func _bring_him_in() -> void:
	var director := _resolve_director()
	if _boss == null or _arrived or director == null:
		return

	var tier := director.find_tier(_boss.known)
	if tier == null:
		push_warning("RunMiniBossFight: no MiniBossTier authored for knowledge %d."
			% _boss.known)
		_finish(true)
		return

	# No men with him: his were the ones the player has just finished. Announced to
	# nobody, because "HE IS NEARBY" is for a man being looked for and this one has
	# arrived.
	if director.place_encounter(_boss, tier, 0, Vector2.INF, false) <= 0:
		push_warning("RunMiniBossFight: the boss could not be placed.")
		_finish(true)
		return

	_arrived = true
	var body := director.get_boss()
	var at := body.global_position if body != null else Vector2.ZERO
	boss_arriving.emit(at)
	_land(at, body)

	# The ending arms itself off this - see [BossDefeat] - so it is connected
	# before the introduction, which is what starts the fight when it finishes.
	var defeat := _resolve_defeat()
	if defeat != null and not defeat.arena_released.is_connected(_on_arena_released):
		defeat.arena_released.connect(_on_arena_released, CONNECT_ONE_SHOT)

	director.introduce_now()
	boss_arrived.emit(body)


## The weight of him hitting the ground: the world stops for an instant, the
## camera is shaken and the sand goes up.
##
## [b]Every part of this is a system the arena already has.[/b] The freeze is the
## world's own [HitStop], the shake is [method CameraController.shake] - the same
## channel a shotgun and a boss's own footfalls use, so an impulse already running
## is deepened rather than overwritten - and the burst is an ordinary scene placed
## and played. Nothing here is a new effect.
func _land(at: Vector2, body: Node2D) -> void:
	if arrival_hit_stop > 0.0:
		var freeze := HitStop.get_active(self)
		if freeze != null:
			freeze.stop(arrival_hit_stop)

	var camera := CameraController.get_active(self)
	if camera != null and arrival_shake > 0.0:
		camera.shake(arrival_shake, maxf(arrival_shake_time, 0.0))

	if arrival_effect == null:
		return
	var burst := arrival_effect.instantiate() as Node2D
	if burst == null:
		return
	# Stood in the world beside him rather than parented to him - see
	# [OneShotParticles], whose whole doc is about that: a burst dragged around by
	# what set it off is a burst that follows him as he walks out of it.
	var into: Node = body.get_parent() if body != null else self
	into.add_child(burst)
	burst.global_position = at + arrival_effect_offset
	burst.scale = Vector2.ONE * maxf(arrival_effect_scale, 0.01)
	if burst.has_method(&"play"):
		burst.call(&"play")


## He is down and the camera is back on the player - [BossDefeat] has run its
## whole ending. The way home is the bridge's, exactly as it is for every other
## fight.
func _on_arena_released() -> void:
	_finish(true)


func _finish(victory: bool) -> void:
	var bridge := _resolve_bridge()
	_boss = null
	_arrived = false
	encounter_finished.emit(victory)
	if bridge != null:
		bridge.let_the_ending_go()


# --- Looking things up -----------------------------------------------------------

## Runs [param step] after [param seconds], or now when there is nothing to wait
## for. A scene tree timer rather than a held [Timer], since each of these fires
## once in the life of an encounter.
func _after(seconds: float, step: Callable) -> void:
	if seconds <= 0.0:
		step.call()
		return
	get_tree().create_timer(seconds).timeout.connect(step, CONNECT_ONE_SHOT)


func _resolve_bridge() -> WorldMapCombatBridge:
	if _bridge == null or not is_instance_valid(_bridge):
		_bridge = get_node_or_null(bridge_path) as WorldMapCombatBridge
		if _bridge == null:
			_bridge = WorldMapCombatBridge.get_active(self)
	return _bridge


func _resolve_ambush() -> AmbushWaveDirector:
	if _ambush == null or not is_instance_valid(_ambush):
		_ambush = get_node_or_null(ambush_path) as AmbushWaveDirector
	return _ambush


func _resolve_director() -> MiniBossDirector:
	if _director == null or not is_instance_valid(_director):
		_director = get_node_or_null(director_path) as MiniBossDirector
		if _director == null:
			_director = MiniBossDirector.get_active(self)
	return _director


func _resolve_defeat() -> BossDefeat:
	if _defeat == null or not is_instance_valid(_defeat):
		_defeat = get_node_or_null(defeat_path) as BossDefeat
		if _defeat == null:
			_defeat = BossDefeat.get_active(self)
	return _defeat
