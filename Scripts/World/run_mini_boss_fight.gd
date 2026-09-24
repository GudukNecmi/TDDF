class_name RunMiniBossFight
extends Node
## A run map bounty boss point, fought: the man walks in among his men, a dozen of
## them are kept on the field for as long as he stands, and when he is down the
## player decides what is done with him before riding on.
##
## [b]It is the sequencer and nothing else.[/b] Every part of what happens here
## already existed and none of it is reimplemented:
##
##   [codeblock]
##   his men        ->  he arrives  ->  introduction  ->  the fight               ->  he falls    ->  his fate            ->  home
##   AmbushWaveDirector  MiniBossDirector  BossArena    BossCharge, BossSwordStorm   BossDefeat     WorldBanditDecisionMenu  WorldMapCombatBridge
##   [/codeblock]
##
## The crowd is the same [AmbushWaveDirector] fight every bandit point opens,
## placed by [method WorldMapCombatBridge._open_staged_fight] before this node
## hears anything - held at its count and made endless here through
## [method AmbushWaveDirector.sustain], so every man who goes down is replaced by
## one walking in from just off the screen. The man is built by
## [MiniBossDirector] at one of its own authored [MiniBossTier] rungs, out of the
## world's own [EnemySpawner]. His attacks are [BossCharge] and [BossSwordStorm],
## and the ending - the caught last blow, the fall, the name struck through, the
## camera coming home - is [BossDefeat], which arms itself off
## [signal MiniBossDirector.fight_started] and breaks the crowd as he goes down.
##
## [b]He arrives with his men, not after them.[/b] They are stood still while he
## lands and the introduction plays, and let go with him as the fight starts -
## see [method MiniBossDirector.register_support], which is how the director
## already releases the men standing with a boss. The bridge's ending is held
## from the first frame - see [method WorldMapCombatBridge.hold_the_ending] -
## because the field is never empty while he stands, and clearing it is not a
## win anyway.
##
## [b]His fate is the player's.[/b] Once [BossDefeat] has handed the arena back,
## [member fate_tier] is put up on the same [WorldBanditDecisionMenu] a bandit
## contact is answered on. The answer is written into the [BountyLedger] - see
## [method BountyLedger.record_fate] - as story the run carries, and only then is
## the ride home let go.
##
## [b]He is a contract, and he is paid for.[/b] Every boss on a run map is one of
## the bounties the player rode out carrying - see [RunMapBountyBossNode] - and
## the contract is all that is carried across the scene change. Which rung he is
## built at, how much health he has, what he is called and whose face he wears
## are all read back off it here, through the one adapter that already reads a
## contract, so [BossDefeat] pays the reward and strikes the name out exactly as
## it does for a boss found any other way.

## Emitted as the man starts walking in.
signal boss_arriving(at: Vector2)
## Emitted once he is standing in the arena and the introduction has begun.
signal boss_arrived(boss: Node2D)
## Emitted when his fate has been decided, with the answer and whether he died of it.
signal fate_decided(fate: StringName, killed: bool)
## Emitted when the encounter is over and the way back to the run map is asked
## for, whether or not he was beaten.
signal encounter_finished(victory: bool)

@export_group("Wiring")
## The encounter bridge whose staged fight this takes over the ending of.
@export var bridge_path: NodePath = ^"../WorldMapCombatBridge"
## The crowd director whose men stand with him.
@export var ambush_path: NodePath = ^"../AmbushDirector"
## The boss system that builds him. [b]There is no run map boss[/b] - he is the
## same man, at the same rungs, as a bounty target.
@export var director_path: NodePath = ^"../MiniBossDirector"
## The ending, watched for the moment the camera comes home.
@export var defeat_path: NodePath = ^"../BossDefeat"
## The contract ledger - the [code]Bounties[/code] autoload. The man is read back
## off it by the id the fight was staged with, and his fate is written into it.
@export var ledger_path: NodePath = ^"/root/Bounties"
## Group every living enemy joins - his men, stood still for his entrance.
@export var enemy_group: StringName = &"enemies"

@export_group("How he arrives")
## How long after the fight opens he walks in, in seconds. A beat so the loading
## screen has cleared and the player has seen his men before he lands.
@export var arrival_delay: float = 1.1
## Whether his men stand still while he lands and is introduced, and are let go
## with him as the fight starts. Off, they come at the player from the first frame.
@export var crowd_waits_for_him: bool = true
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

@export_group("His fate")
## The question put to the player once he is down: the line and the answers, each
## a [BountyBossFateChoice] carrying what it does. Left empty, the ride home follows
## the fall exactly as it did before there was a question.
@export var fate_tier: WorldBanditDecisionTier
## The screen it is asked on. Looked up by group when the path finds nothing - the
## run HUD carries one.
@export var decision_menu_path: NodePath = ^"../RunHUD/WorldBanditDecisionMenu"
## How long the arena is held after the answer before the ride home, in seconds,
## so a shot's blood lands and a bound man's fall is seen.
@export var fate_settle_time: float = 0.9
## The voices an answer's own [member BountyBossFateChoice.sounds] are played
## through, relative to this node.
@export var fate_sound_bank_path: NodePath = ^"FateSounds"
## The gun's own voices, relative to the weapon in the player's hands.
@export var weapon_sound_bank_path: NodePath = ^"Sounds"
## Which of those is its firing sound.
@export var weapon_fire_sound: StringName = &"blast"

var _bridge: WorldMapCombatBridge
var _ambush: AmbushWaveDirector
var _director: MiniBossDirector
var _defeat: BossDefeat
## Who is coming, from the moment the fight opens. Null whenever this node has
## no encounter of its own, which is every fight but a bounty boss point's.
var _boss: MiniBossBrief
## Set once he has been built, so nothing can bring in a second man.
var _arrived: bool = false
## His men held still for his entrance, released by the director with him.
var _held_crowd: Array[Node2D] = []


func _ready() -> void:
	var bridge := _resolve_bridge()
	if bridge == null:
		return
	if not bridge.mini_boss_encounter_started.is_connected(_on_encounter_started):
		bridge.mini_boss_encounter_started.connect(_on_encounter_started)


## Who this fight is against, or null when it is not one of these.
func get_boss_brief() -> MiniBossBrief:
	return _boss


## Whether the man himself is in the arena yet.
func has_arrived() -> bool:
	return _arrived


# --- The fight opens ------------------------------------------------------------

func _on_encounter_started(boss: MiniBossBrief, _support_count: int) -> void:
	var bridge := _resolve_bridge()
	if bridge == null or boss == null:
		return

	_boss = boss
	_arrived = false

	# Taken before the first man is shot: the field is kept full for as long as he
	# stands, and clearing it is never what ends this fight.
	bridge.hold_the_ending(self)

	var ambush := _resolve_ambush()
	if ambush != null:
		ambush.sustain()
	if crowd_waits_for_him:
		_hold_the_crowd()

	if _resolve_director() == null:
		# No boss system in this arena - the player would be left fighting an
		# endless crowd with no way out. The fight is ended as the win it is.
		_finish(true)
		return
	_after(arrival_delay, _bring_him_in)


## His men stand where they were put until he is introduced.
func _hold_the_crowd() -> void:
	_held_crowd.clear()
	for node: Node in get_tree().get_nodes_in_group(enemy_group):
		var man := node as Node2D
		if man == null or not man.has_method(&"set_passive"):
			continue
		man.call(&"set_passive", true)
		_held_crowd.append(man)


# --- He arrives -----------------------------------------------------------------

## Stands him up, shakes the ground he lands on, and hands the camera to the
## introduction the project already plays over a boss.
func _bring_him_in() -> void:
	var director := _resolve_director()
	if _boss == null or _arrived or director == null:
		return

	# A run map boss point is a contract, so the man is derived from the contract
	# here rather than carried across the scene change as a set of numbers: the
	# rung he is built at, the health he carries, his name and his face all come
	# off the paper through the one adapter that already reads one - see
	# [method MiniBossBrief.from_bounty]. A brief naming a contract the ledger no
	# longer holds is left exactly as it arrived rather than blanked.
	var contract := _find_contract(_boss.contract_id)
	if contract != null:
		var derived := MiniBossBrief.from_bounty(contract, director)
		if derived != null:
			_boss = derived

	var tier := director.find_tier(_boss.known)
	if tier == null:
		push_warning("RunMiniBossFight: no MiniBossTier authored for knowledge %d."
			% _boss.known)
		_finish(true)
		return

	# No men built with him: his are the crowd already standing there. Announced to
	# nobody, because "HE IS NEARBY" is for a man being looked for and this one has
	# arrived.
	if director.place_encounter(_boss, tier, 0, Vector2.INF, false) <= 0:
		push_warning("RunMiniBossFight: the boss could not be placed.")
		_finish(true)
		return

	_arrived = true
	# Handed to the director as his men, so the fight starting lets them go with
	# him - the director's own release, not a second one.
	for index: int in range(_held_crowd.size()):
		if is_instance_valid(_held_crowd[index]):
			director.register_support(_held_crowd[index])
	_held_crowd.clear()

	var body := director.get_boss()
	var at := body.global_position if body != null else Vector2.ZERO
	boss_arriving.emit(at)
	_land(at, body)

	# The ending arms itself off the fight starting - see [BossDefeat] - so it is
	# connected before the introduction, which is what starts the fight.
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


# --- His fate -------------------------------------------------------------------

## He is down and the camera is back on the player - [BossDefeat] has run its
## whole ending. What is done with him is asked now; the way home waits on it.
func _on_arena_released() -> void:
	var menu := _resolve_menu()
	if fate_tier == null or fate_tier.choices.is_empty() or menu == null:
		_finish(true)
		return

	# Shot where he lay before the question could be put: there is nobody left to
	# decide over, and he is written down as killed by the answer that kills.
	var defeat := _resolve_defeat()
	if defeat != null and defeat.is_corpse_killed():
		var killing := _killing_choice()
		_settle(killing.outcome if killing != null else &"killed", true)
		return

	if not menu.answered.is_connected(_on_fate_answered):
		menu.answered.connect(_on_fate_answered, CONNECT_ONE_SHOT)
	menu.ask(fate_tier)


func _on_fate_answered(outcome: StringName) -> void:
	var choice := _choice_for(outcome)
	var kills := choice != null and choice.kills

	if choice != null:
		if choice.fires_weapon:
			_fire_the_gun()
		_play_choice_sounds(choice)
	if kills:
		_finish_him()
	_settle(outcome, kills)


## Writes the answer down and lets the ride home go after a beat.
func _settle(outcome: StringName, killed: bool) -> void:
	var contract_id: StringName = _boss.contract_id if _boss != null else &""
	var ledger := get_node_or_null(ledger_path) as BountyLedger
	if ledger != null and not contract_id.is_empty():
		ledger.record_fate(contract_id, outcome, killed)
	fate_decided.emit(outcome, killed)
	_after(maxf(fate_settle_time, 0.0), _finish.bind(true))


## The body on the ground finished off, through [BossDefeat]'s own corpse kill -
## the X over his eyes, the drained colour and the blood.
func _finish_him() -> void:
	var defeat := _resolve_defeat()
	if defeat != null:
		defeat.finish_off()


## The gun in the player's hands going off - its own firing sound, off its own bank.
func _fire_the_gun() -> void:
	var mount := WeaponMount.get_active(self)
	var weapon: Node = mount.get_weapon() if mount != null else null
	if weapon == null:
		return
	var bank := weapon.get_node_or_null(weapon_sound_bank_path) as SoundBank
	if bank != null and bank.has_sound(weapon_fire_sound):
		bank.play(weapon_fire_sound)


func _play_choice_sounds(choice: BountyBossFateChoice) -> void:
	var bank := get_node_or_null(fate_sound_bank_path) as SoundBank
	if bank == null:
		return
	for stream: AudioStream in choice.sounds:
		if stream != null:
			bank.play_stream(stream)


func _choice_for(outcome: StringName) -> BountyBossFateChoice:
	if fate_tier == null:
		return null
	for choice: WorldBanditDecisionChoice in fate_tier.choices:
		if choice != null and choice.outcome == outcome:
			return choice as BountyBossFateChoice
	return null


func _killing_choice() -> BountyBossFateChoice:
	if fate_tier == null:
		return null
	for choice: WorldBanditDecisionChoice in fate_tier.choices:
		var fate := choice as BountyBossFateChoice
		if fate != null and fate.kills:
			return fate
	return null


func _finish(victory: bool) -> void:
	var bridge := _resolve_bridge()
	_boss = null
	_arrived = false
	_held_crowd.clear()
	encounter_finished.emit(victory)
	if bridge != null:
		bridge.let_the_ending_go()


# --- Looking things up -----------------------------------------------------------

## The contract [param contract_id] names, or null for a brief that carries none.
## The ledger is the [code]Bounties[/code] autoload, which survives the scene
## change the fight was staged through - which is exactly why only the id is
## carried across it.
func _find_contract(contract_id: StringName) -> Bounty:
	if contract_id.is_empty():
		return null
	var ledger := get_node_or_null(ledger_path) as BountyLedger
	return null if ledger == null else ledger.find_active(contract_id)


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


func _resolve_menu() -> WorldBanditDecisionMenu:
	var named := get_node_or_null(decision_menu_path) as WorldBanditDecisionMenu
	return named if named != null else WorldBanditDecisionMenu.get_active(self)
