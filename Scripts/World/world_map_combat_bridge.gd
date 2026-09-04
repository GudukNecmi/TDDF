class_name WorldMapCombatBridge
extends Node
## World Map encounter -> the region's own Arena scene -> back to that same map,
## and nothing in between.
##
## [b]This is the adapter, not a second combat system.[/b] It watches every
## [WorldBandit] for the player walking into it, and when one is reached it hands
## the fight whole to [AmbushWaveDirector] - the same director an ordinary road
## ambush and a Trouble Danger already fight through, built on the world's own
## [EnemySpawner] and its ordinary enemies. Nothing about how a fight is spawned,
## paced or ended is written here; this only decides [i]when[/i] one starts,
## [i]how big[/i] it is, and [i]where on the map[/i] to put the player back.
##
## [b]One class, two scenes.[/b] The fight used to be held in a rectangle a few
## thousand pixels from the map in the same scene, so a bandit could simply be
## kept in a variable from the moment of contact until the moment the fight ended.
## Each region's arena is its own scene now, and the map is freed to build it, so
## the two halves of an encounter are two builds of this same node:
##
##   * [b]On the map[/b] - [method _begin_encounter] and
##     [method try_begin_boss_encounter] decide what the fight is: how many men,
##     in which region, at what hour, and the spot to come back to. That record
##     goes to [method WorldMapState.stage_combat] and [WorldRegionRouter] is
##     asked to change scene.
##   * [b]In the arena[/b] - [method _open_staged_fight], from this node's own
##     [method Node._ready], takes the same record back and opens the fight on it.
##     [method _finish_combat_cleared] ends it and asks the router for the way
##     home.
##
## It is one class rather than two because everything a fight is tuned by - the
## enemy count scale, the decision tiers, the combat time advance, the music
## states - is one set of numbers, and splitting the file would have split those
## across two Inspectors that could disagree.
##
## [b]Group strength becomes an enemy count by the smallest reading there is[/b]
## - [member WorldBandit.group_strength] scaled by [member enemy_count_scale],
## rounded and clamped, is the number handed to
## [method AmbushWaveDirector.begin_with]. [member enemy_count_scale] is the one
## and only place that conversion is tuned. No difficulty curve is invented here;
## the ambush's own opening group, arrival pacing and breaking point are all left
## at whatever the arena scene has them authored to.
##
## [b]Nothing is hidden, because nothing is left behind.[/b] Hiding the map's
## formations, its fog, its hover tooltip and its screen-space HUD behind a fight
## used to be this node's job, and had to be: the map was still in the tree,
## still simulating and still drawing straight through the arena. A scene change
## frees it, so there is nothing to hide and nothing to give back.
##
## [b]The arena is clean by construction.[/b] It used to be swept - twice, once
## as a fight opened and once after a win - because the same rectangle was fought
## in over and over and last fight's blood, brass and bodies were still lying in
## it. A fresh arena scene is built for every fight and thrown away at the end of
## it, so no corpse, dropped gun, casing, blood patch or scattered prop can reach
## the next one. Nothing clears the floor because nothing survives to be cleared.
##
## [b]What carries through.[/b] The player is rebuilt with each scene, so what
## survives a fight is what survives any scene change: the autoloads.
## [RunInventory], carried Blood, [HorseBlood], the run's own Streak, the
## ammunition locker and [WorldMapState]'s memory of every region are all
## untouched by this. [WorldMapHorse] is dismounted as a fight opens and the
## player is put back on it as the map opens again - see
## [method WorldMapTravelService._arrive].
##
## [b]World time freezes for the fight and is paid on the way out.[/b]
## [WorldClock] - the [WorldTimeManager] autoload - is stopped as the fight is
## staged and stopped again as the arena opens, since it is an autoload and would
## otherwise keep turning through the load. That is also what freezes
## [SunController] and every shadow reading it, so the combat shadow holds the
## angle the map was at. On a win the clock is handed back advanced by the fight's
## own size - see [member combat_time_advance_base] - never by how long it took in
## real seconds.
##
## [b]The Combat Map's darkness is blended onto the same hour for the same
## reason.[/b] [SunController] and its shadows need nothing extra - they already
## read only [WorldTimeManager] and freeze the instant it does - but
## [DayCycleDirector]'s own ambient tint reads the round-based [code]DayCycle[/code]
## clock instead. [method _match_combat_ambient_to_world_time] works out where
## [WorldClock] sits between two of [DayCycleDirector]'s own authored
## [member DayStage.ambient_colour] values - never a colour invented here - and
## pushes that blend through for the fight's length.
##
## [b]A won fight is not over the instant the last man falls.[/b] A final kill
## opens the world's own [KillCam], and [method _on_combat_cleared] holds the
## whole wind-down behind [signal KillCam.ended]: the music, the clock catching
## up, the ride home and [signal encounter_ended] itself all wait for the
## mandatory hold to finish. A fight that ends by routing rather than by a kill
## never opens a [KillCam] moment at all.
##
## [b]The map is handed back at normal speed, always.[/b] [member Engine.time_scale]
## is set back to 1 outright as a win's wind-down begins, so nothing an arena
## fight did to it can cross into the map.
##
## [b]What a win hands the player is not decided here.[/b] [method get_combat_loot]
## is a fresh, empty [CombatLoot] for every encounter, opened for [HorseCartScreen]
## to read once the fight is over.
##
## [b]A death is not this node's ending to play.[/b] [AmbushWaveDirector] already
## breaks and empties itself on the player's own [signal Health.died], and
## [PlayerDeathSequence] already owns carrying a beaten player home - which is
## itself a change of scene to the base now, since home is another scene. This
## only follows the death long enough to tell the two endings apart.
##
## [b]A bounty boss opens the identical fight through a second door.[/b]
## [method try_begin_boss_encounter] is [WorldBountyBossDirector]'s way in and
## shares every piece of this machinery with the bandit path above; the only
## things that differ are where the enemy count comes from and what happens to
## the thing that was contacted on a win. The boss node itself is freed with the
## map, so the contract is carried across as its bounty id and closed on the
## ledger from the arena - which is all the ledger ever needed.
##
## [b]The whole hand-off happens behind the loading curtain.[/b] Both entry points
## open [TravelLetterbox]'s loading transition before anything is touched, and the
## scene change itself goes through the same [LoadingCurtain] the title screen has
## always used. Nothing here builds a second presentation, and nothing here loads
## anything.

## Emitted as a fight opens, with what it was fought over.
signal encounter_started(payload: WorldBanditEncounter)
## Emitted as one ends, [param victory] true only when the ambush was actually
## cleared rather than broken by the player's own death.
signal encounter_ended(victory: bool)
## The bounty-boss twins of the two signals above - see
## [method try_begin_boss_encounter] and [WorldBountyEncounter]. Kept apart
## from the bandit pair rather than folded into one typed signal, since a
## [WorldBanditEncounter] and a [WorldBountyEncounter] are two different
## payload shapes and a listener for one should never have to branch on
## which it was handed.
signal boss_encounter_started(payload: WorldBountyEncounter)
signal boss_encounter_ended(victory: bool)

## Group this joins, so anything can find the one bridge in the world without a
## path across a scene it is not a child of.
const GROUP := &"world_map_combat_bridge"
## Group every [WorldBandit] joins, watched here rather than wired to any one
## of them so a group placed - or spawned - after this node is still found.
const BANDIT_GROUP := &"world_bandit"

@export var spawner_path: NodePath = ^"../EnemySpawner"
@export var ambush_path: NodePath = ^"../AmbushDirector"
@export var world_clock_path: NodePath = ^"/root/WorldClock"
## The ammo locker a fight's own opening resupplies the equipped weapon
## through - see [method _resupply_equipped_weapon]. Optional: a world with
## none opens the fight with whatever was already loaded, exactly as every
## encounter did before that resupply existed.
@export var locker_path: NodePath = ^"/root/Ammo"
## The contract ledger, asked only on a won boss encounter - see
## [method try_begin_boss_encounter]. A bandit fight never touches this.
@export var ledger_path: NodePath = ^"/root/Bounties"
## The shared cinematic bars - see [TravelLetterbox]. Optional: a world with
## none plays every encounter exactly as it did before that controller
## existed, just without anything hiding the position swap below behind a
## loading transition.
@export var letterbox_path: NodePath = ^"../RunHUD/TravelLetterbox"
@export var player_group: StringName = &"player"
@export var horse_group: StringName = &"world_map_horse"

@export_group("Sizing")
## [member WorldBandit.group_strength], scaled by [member enemy_count_scale]
## and rounded, is clamped between these two before it is handed to the
## ambush - the floor keeps a nearly-beaten group worth a fight, the ceiling
## keeps a growth curve nobody has authored yet from ever asking the spawner
## for an unplayable crowd.
@export var min_enemy_count: int = 1
@export var max_enemy_count: int = 60
## What [member WorldBandit.group_strength] is multiplied by before rounding
## into an enemy count - the whole of the "final combat count reads lighter"
## tuning knob, applied only at this one conversion. [member WorldBandit.group_strength]
## itself, bandit movement and the World Map's own bandit population are
## never scaled by this; a group that reads as "60 strong" on the map still
## reads that way, it simply now arrives as fewer bodies in the Arena.
@export var enemy_count_scale: float = 0.65
## How close another roaming, [constant WorldBandit.BehaviorState.CHASE]
## group has to be standing to a contact for it to join that encounter as a
## reinforcement - see [method _gather_reinforcements]. A nearby group that
## is only patrolling, investigating or already engaged is never pulled in:
## only a group that was itself actively chasing the player down joins the
## fight it catches up to.
@export var reinforcement_radius: float = 640.0
## What fraction of the equipped weapon's own maximum capacity a resupply may
## fill it to when the fight that is about to open is one of a World Map
## ambush's own three attackers - see [member WorldBandit.in_ambush] and
## [method _resupply_equipped_weapon]. Never touches an ordinary bandit
## contact or a bounty boss, whatever this is set to.
@export_range(0.0, 1.0, 0.01) var ambush_refill_cap_fraction: float = 0.6

@export_group("Presentation")
## How long the loading transition is held up in front of [TravelLetterbox]
## once the fight has actually been placed, before the Arena is revealed -
## long enough that the turning "Loading" word is seen rather than flashed,
## since the position swap and the ambush spawn it is covering are themselves
## instant. See [method _schedule_destination_reveal].
@export var combat_transition_hold_time: float = 0.6

@export_group("Decision")
## The short screen a bandit contact is put through before the fight - see
## [WorldBanditDecisionMenu]. Optional: a world with none skips straight to
## the fight, exactly as every encounter did before this screen existed. A
## bounty camp's own boss is never put through it - see
## [method try_begin_boss_encounter].
@export var decision_menu_path: NodePath = ^"../RunHUD/WorldBanditDecisionMenu"
## The shared cinematic zoom - see [WorldMapInteractionCamera]. Optional: a
## world with none opens the decision screen and ends a bandit fight exactly
## as both already did before that node existed, just with no zoom around
## either.
@export var interaction_camera_path: NodePath = ^"../WorldMapInteractionCamera"
## What is shown, and what each answer means - see
## [enum WorldBanditDecisionEvaluator.Tier] for how a contact is sorted into
## one of the three.
@export var stronger_tier: WorldBanditDecisionTier
@export var equal_tier: WorldBanditDecisionTier
@export var weaker_tier: WorldBanditDecisionTier
## What choosing to pay costs, and what choosing to take is worth, in Blood -
## the two peaceful answers that move the carried wallet. Walking away moves
## nothing.
@export var decision_pay_amount: int = 150
@export var decision_take_amount: int = 150
## The carried wallet a peaceful answer pays out of or into - the
## [code]Blood[/code] autoload, the same one every other run-scoped Blood
## change already reaches through.
@export var carried_wallet_path: NodePath = ^"/root/Blood"

@export_group("Music")
## The shared cinematic cues board - see [StingerBoard]. Optional: a world
## with none plays every cue silent.
@export var stinger_path: NodePath = ^"../RunHUD/StingerBoard"
## The central soundtrack - the [code]MusicStates[/code] autoload. Optional:
## a world with none plays in silence exactly as it did before any of this
## existed.
@export var music_states_path: NodePath = ^"/root/MusicStates"
@export var travel_state: StringName = &"travel"
@export var decision_state: StringName = &"decision"
@export var combat_state: StringName = &"combat"
@export var boss_state: StringName = &"boss"
## The three fight tracks a bandit fight or a bounty camp's own crowd picks
## between - randomly, never the same one twice running. A bounty camp's
## true boss fight is louder and more important than this - see
## [member boss_state] - and does not read from this array at all.
@export var fight_tracks: Array[AudioStream] = []

var _running: bool = false
var _bandit: WorldBandit
var _payload: WorldBanditEncounter
## Which kind of fight is currently running - [code]&"bandit"[/code] or
## [code]&"bounty_boss"[/code]. What [method _on_combat_cleared] branches the
## ending on, since [signal AmbushWaveDirector.cleared] itself carries no
## memory of which of the two opened it.
var _encounter_kind: StringName = &"bandit"
var _boss: WorldBountyBoss
var _boss_payload: WorldBountyEncounter
var _combat_start_msec: int = 0
var _died: bool = false
var _player_health: Health
## Whether this fight actually pushed a blended colour through
## [method DayCycleDirector.apply_ambient_color] - see
## [method _match_combat_ambient_to_world_time] - so [method _restore_combat_ambient]
## knows there is a normal hour to hand back rather than assuming one ran.
var _day_stage_forced: bool = false
## True from the moment a contact opens the decision screen until it is
## answered - the guard [method _process] reads instead of [member _running],
## since there is no fight and nothing about the player, the camera or the
## world has been touched yet.
var _deciding: bool = false
## The bandit currently being decided over. Held apart from [member _bandit],
## which is only ever written once a decision has actually resolved into a
## fight - see [method _begin_encounter].
var _decision_bandit: WorldBandit
## Other nearby, actively-chasing [WorldBandit] groups pulled into the
## contact currently being decided or fought over - see
## [method _gather_reinforcements]. Held apart from [member _bandit] because
## it is a group of them rather than the one thing everything else here is
## keyed on; never the primary contact itself.
var _reinforcements: Array[WorldBandit] = []
## Picks the next fight track without repeating the last one - see
## [member fight_tracks].
var _fight_track_picker: VariantPicker
## What the fight currently running has handed over so far - see [CombatLoot]
## and [method get_combat_loot]. A fresh, empty one from the moment an
## encounter opens, so [HorseCartScreen] never reads last fight's leftovers.
var _loot: CombatLoot = CombatLoot.new()
## How many enemies the fight currently running actually opened with - the
## same [code]count[/code] handed to [method AmbushWaveDirector.begin_with] -
## kept so [method _finish_combat_cleared] can work out the World Map's own
## time progression from the real size of the fight rather than from how long
## it happened to take. See [member combat_time_advance_base].
var _combat_enemy_count: int = 0
## The fight this scene was built for, taken from [WorldMapState] as the arena
## opens and kept for the whole of it - what it is a fight against, and where on
## the map to put the player back when it is over. Empty on a World Map scene,
## where the fight has not been staged yet, and on an arena opened on its own.
var _staged: Dictionary = {}
## Whether the player was on the horse when a fight was opened, so a departure
## that turns out to have nowhere to go puts them back on it.
var _horse_mounted_before: bool = false

@export_group("Combat time")
## Degrees the World Map clock advances the instant an ordinary fight ends,
## before anything is added for its size - see the class doc's own worked
## example: "Base combat progression: +4°".
@export var combat_time_advance_base: float = 4.0
## Extra degrees added per this many enemies the fight actually opened with -
## "+1 degree for every 10 enemies" is [member combat_time_advance_per_enemies]
## 1 over [member combat_time_advance_enemy_step] 10.
@export var combat_time_advance_per_enemies: float = 1.0
@export var combat_time_advance_enemy_step: int = 10
## Extra degrees added on top when the fight just cleared was a bounty camp's
## own boss - "+10 for a boss" in the same example.
@export var combat_time_advance_boss_bonus: float = 10.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# An arena scene is built for a fight that has already been decided on the
	# map it was picked up from. Deferred by one frame so the ambush director,
	# the spawner and the player are all up before the crowd is asked for.
	_open_staged_fight.call_deferred()


## The bridge in this world, or null when it has none - which every caller
## reads as "there is nowhere for a World Map encounter to go".
static func get_active(from_node: Node) -> WorldMapCombatBridge:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldMapCombatBridge


func is_running() -> bool:
	return _running


## Whether a contact is currently being put through the STRONGER / EQUAL /
## WEAKER screen - true from [method _open_decision] until it is answered.
## Public so [WorldMapAmbushDirector] can hold off rolling a fresh ambush
## while one is already being decided over, the same window
## [method _process] itself already guards new contacts against.
func is_deciding() -> bool:
	return _deciding


## What is being fought right now, or null between fights.
func get_encounter() -> WorldBanditEncounter:
	return _payload


## The bounty-boss twin of [method get_encounter].
func get_boss_encounter() -> WorldBountyEncounter:
	return _boss_payload


## The loot the fight currently running - or the one that just ended - has
## handed over, for [HorseCartScreen] to read and empty by hand as the player
## claims each stack. Never null: an encounter that has produced nothing yet
## still gets an empty [CombatLoot] rather than nothing to ask.
func get_combat_loot() -> CombatLoot:
	return _loot


## Watched every frame rather than on a signal from [WorldBandit] itself - see
## the class doc on why the detection stays here - but only while nothing is
## already being fought or decided over, so a crowd of groups near the player
## cannot start a second encounter out from under the first.
func _process(_delta: float) -> void:
	if _running or _deciding:
		return

	var player := _resolve_player()
	if player == null:
		return

	for node: Node in get_tree().get_nodes_in_group(BANDIT_GROUP):
		var bandit := node as WorldBandit
		if bandit == null or not bandit.active:
			continue
		if bandit.global_position.distance_to(player.global_position) <= bandit.contact_radius:
			_open_decision(bandit)
			return


# --- The decision, ahead of the fight ---------------------------------------

## Puts a contacted bandit through the STRONGER / EQUAL / WEAKER screen
## before anything about the fight itself opens - see
## [WorldBanditDecisionEvaluator] for how the reading is made and
## [WorldBanditDecisionMenu]'s own class doc for the screen this raises.
##
## [b]A world with no screen, or no tier authored for what the contact read
## as, skips straight to the fight[/b] - the exact encounter that existed
## before this screen did, so an unfinished decision setup can never leave a
## bandit contact doing nothing at all. The interaction zoom is skipped the
## same way: there is no screen for it to lead into.
##
## [b]The zoom leads the screen, rather than racing it.[/b] The cue and the
## music switch the instant contact is made - rule "the sound must trigger
## immediately on the input" - but [method WorldMapInteractionCamera.zoom_in]
## is asked for in the same breath and the screen itself only opens once
## that push has actually landed - see [method _reveal_decision_menu] - which
## is what "camera zooms to 3x, then the interaction UI opens" means in
## practice rather than the two happening in the same frame.
func _open_decision(bandit: WorldBandit) -> void:
	# Gathered once, up front, so both the tier this contact reads as and the
	# eventual fight it may become see the identical reinforcement roster -
	# see [method _gather_reinforcements] and section 16 of the design.
	_reinforcements = _gather_reinforcements(bandit)
	for reinforcement: WorldBandit in _reinforcements:
		reinforcement.active = false

	var menu := _resolve_decision_menu()
	var tier := _tier_for(bandit)
	if menu == null or tier == null:
		_begin_encounter(bandit)
		return

	_deciding = true
	_decision_bandit = bandit
	# Held still and silent for the length of the question, the same way a
	# fight already opening holds the group it is about to replace - but not
	# yet hidden, since the player is still looking at exactly who they are
	# talking to.
	bandit.active = false

	_play_cue(&"bandit_encounter")
	_switch_music(decision_state)

	if not menu.answered.is_connected(_on_decision_answered):
		menu.answered.connect(_on_decision_answered, CONNECT_ONE_SHOT)

	var cam := _resolve_interaction_camera()
	if cam == null:
		menu.ask(tier)
		return

	cam.zoom_in()
	var seconds := maxf(cam.default_zoom_seconds, 0.0)
	if seconds <= 0.0:
		menu.ask(tier)
		return
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(_reveal_decision_menu.bind(menu, tier, bandit))


## The other half of [method _open_decision]'s delayed reveal - only opens
## the screen if this is still the decision the zoom was pushed in for, the
## same guard [method MusicStateBoard._open_if_pending] already uses for a
## timer that can outlive what asked for it.
func _reveal_decision_menu(
		menu: WorldBanditDecisionMenu, tier: WorldBanditDecisionTier, bandit: WorldBandit
) -> void:
	if not _deciding or _decision_bandit != bandit:
		return
	menu.ask(tier)


func _tier_for(bandit: WorldBandit) -> WorldBanditDecisionTier:
	match WorldBanditDecisionEvaluator.evaluate(bandit, self, _combined_strength(bandit)):
		WorldBanditDecisionEvaluator.Tier.EQUAL:
			return equal_tier
		WorldBanditDecisionEvaluator.Tier.STRONGER:
			return stronger_tier
		_:
			return weaker_tier


## Every other roaming group actively [constant WorldBandit.BehaviorState.CHASE]-ing
## the player within [member reinforcement_radius] of [param bandit] - "the
## World Map should still support nearby bandit groups joining an encounter
## when appropriate," read literally: only a group already hunting the same
## player joins, never one merely patrolling nearby, and never one already
## spoken for by another contact or fight. Reuses the exact contact-scanning
## [method _process] already does over [constant BANDIT_GROUP] rather than a
## second nearby-group system - see the class doc's own note on rule 16.
func _gather_reinforcements(bandit: WorldBandit) -> Array[WorldBandit]:
	var found: Array[WorldBandit] = []
	if bandit == null:
		return found
	for node: Node in get_tree().get_nodes_in_group(BANDIT_GROUP):
		var other := node as WorldBandit
		if other == null or other == bandit or not other.active:
			continue
		if other.behavior_state != WorldBandit.BehaviorState.CHASE:
			continue
		if other.global_position.distance_to(bandit.global_position) <= reinforcement_radius:
			found.append(other)
	return found


## [param bandit]'s own [member WorldBandit.group_strength] plus every
## currently-gathered [member _reinforcements]' - the one number both the
## decision screen's tier and the fight's own enemy count are read from, so
## the two can never disagree about how big this encounter actually is.
func _combined_strength(bandit: WorldBandit) -> float:
	var total := 0.0 if bandit == null else bandit.group_strength
	for reinforcement: WorldBandit in _reinforcements:
		if reinforcement != null and is_instance_valid(reinforcement):
			total += reinforcement.group_strength
	return total


## Frees every gathered reinforcement alongside [param bandit] - see
## [method _resolve_decision_peacefully] and [method _finish_combat_cleared],
## the two endings a joined encounter can reach without ever entering the
## Arena's own enemy count. Clears [member _reinforcements] either way, so a
## stale roster from a resolved contact can never bleed into the next one.
func _release_reinforcements(free_them: bool) -> void:
	for reinforcement: WorldBandit in _reinforcements:
		if reinforcement == null or not is_instance_valid(reinforcement):
			continue
		if free_them:
			reinforcement.queue_free()
		else:
			reinforcement.active = true
	_reinforcements = []


## The player's own answer, the instant it is given - rule "the sound must
## trigger immediately on the input", kept literal: the result cue and the
## music both change on this call, never after the fight that may follow it
## has so much as begun loading.
func _on_decision_answered(outcome: StringName) -> void:
	var bandit := _decision_bandit
	_deciding = false
	_decision_bandit = null

	# Released the instant an answer lands, whichever of the four it is - a
	# FIGHT answer is about to vanish behind its own loading transition
	# anyway, so there is nothing lost in also asking for the ease back here
	# rather than branching it out of that one outcome.
	var cam := _resolve_interaction_camera()
	if cam != null:
		cam.zoom_out()

	match outcome:
		&"pay":
			_resolve_decision_peacefully(bandit, &"decision_paid", -decision_pay_amount)
		&"walk_away":
			_resolve_decision_peacefully(bandit, &"decision_walk", 0)
		&"take":
			_resolve_decision_peacefully(bandit, &"decision_taken", decision_take_amount)
		_:
			_resolve_decision_into_fight(bandit)


## PAY, WALK_AWAY or TAKE: nobody is fought. The contact simply ends, the
## carried wallet moves by [param blood_delta] if it is not zero, and the
## World Map's own music - Travel.WAV - is asked back at exactly the same
## instant the result cue plays, never waiting on the wallet or on the group
## actually leaving.
func _resolve_decision_peacefully(
		bandit: WorldBandit, cue: StringName, blood_delta: int) -> void:
	_play_cue(cue)
	_switch_music(travel_state)
	_settle_blood(blood_delta)

	if bandit != null and is_instance_valid(bandit):
		bandit.queue_free()
	_release_reinforcements(true)


func _settle_blood(blood_delta: int) -> void:
	if blood_delta == 0:
		return
	var wallet := get_node_or_null(carried_wallet_path) as BloodWallet
	if wallet == null:
		return
	if blood_delta > 0:
		wallet.add(blood_delta)
	else:
		wallet.spend(-blood_delta)


## FIGHT: the decision's own fight cue plays at once, and the ordinary
## encounter opens exactly as a contact always used to - see
## [method _begin_encounter].
func _resolve_decision_into_fight(bandit: WorldBandit) -> void:
	_play_cue(&"decision_fight")
	if bandit == null or not is_instance_valid(bandit):
		return
	# Given back before the fight's own opening asks for it again - see
	# [method _begin_encounter] - so nothing here has to know that method
	# also marks a bandit engaged.
	bandit.active = true
	_begin_encounter(bandit)


# --- Opening the fight -----------------------------------------------------

## Takes a contacted group off the map and into its region's arena.
##
## [b]The fight is another scene now, and that is the whole shape of this.[/b]
## The arena used to stand a few thousand pixels from the map in the same scene,
## so opening a fight meant hiding the map, carrying the camera and the player
## across to it and spawning the crowd - all in one function, all inside one
## tree. The arena is its own scene, so this half only decides what the fight
## [i]is[/i] - how many men, in which region, at what hour, and where on the map
## to come back to - writes it down through [method WorldMapState.stage_combat],
## and asks [WorldRegionRouter] to change scene. The other half of this same
## class picks it up on the far side; see [method _open_staged_fight].
##
## [b]Nothing is hidden, because nothing is left behind.[/b] Hiding the map's
## formations, fog and HUD behind the fight existed only because they were still
## drawing. The map is freed by the scene change, so there is nothing to hide and
## nothing to give back.
func _begin_encounter(bandit: WorldBandit) -> void:
	var player := _resolve_player()
	var router := WorldRegionRouter.get_active(self)
	if bandit == null or player == null or router == null:
		return

	var region_id := bandit.region_id
	if region_id.is_empty():
		region_id = router.get_current_region_id()
	if region_id.is_empty():
		push_warning("WorldMapCombatBridge: no region to open a fight in.")
		return

	_open_loading_transition()
	_start_combat_music()

	_running = true
	_died = false
	_encounter_kind = &"bandit"
	_bandit = bandit
	# Marked engaged and hidden on the spot, so nothing else can reach this same
	# group in the frames before the curtain is up.
	bandit.active = false
	bandit.visible = false

	# The reinforced total, not just this one contact's own - see section 16 and
	# [method _combined_strength]. Read before anything below can free a
	# reinforcement, so the payload and the enemy count can never disagree.
	var combined_strength := _combined_strength(bandit)

	var horse := _resolve_horse()
	var mounted := horse != null and horse.is_mounted()
	_horse_mounted_before = mounted
	if horse != null:
		horse.set_mounted(false)

	var world_day := 0
	var world_degree := 0.0
	var clock := _resolve_world_clock()
	if clock != null:
		if clock.has_method(&"get_world_day"):
			world_day = clock.call(&"get_world_day")
		if clock.has_method(&"get_world_degree"):
			world_degree = clock.call(&"get_world_degree")
		_freeze_world_clock(clock)

	var count := clampi(
		int(round(combined_strength * enemy_count_scale)),
		mini(min_enemy_count, max_enemy_count), max_enemy_count)

	var payload := {
		&"kind": &"bandit",
		&"group_strength": combined_strength,
		&"enemy_count": count,
		&"region_id": region_id,
		&"world_day": world_day,
		&"world_degree": world_degree,
		&"horse_mounted": mounted,
		&"return_region": region_id,
		&"return_position": player.global_position,
	}

	if not router.go_to_combat(region_id, payload):
		_unfreeze_world_clock(clock, 0.0)
		_cancel_loading_transition()
		_abort_encounter()
		return

	# Only once the journey has actually been accepted: every group folded into
	# this fight is gone from the map for good, and is written down as gone. The
	# map is freed either way, so what has to survive is the fact that these
	# groups are not standing here any more. A refused departure above leaves
	# them exactly as they were found.
	bandit.mark_defeated()
	for reinforcement: WorldBandit in _reinforcements:
		if reinforcement != null and is_instance_valid(reinforcement):
			reinforcement.mark_defeated()
	_reinforcements.clear()


## The far side of [method _begin_encounter]: the arena scene has been built and
## the fight it was built for is picked up here.
##
## Called from [method _ready], so an arena opened with nothing staged - one run
## on its own for tuning - simply does nothing and leaves the scene as authored.
func _open_staged_fight() -> void:
	var state := WorldMapState.get_active(self)
	if state == null or not state.has_staged_combat():
		return

	var ambush := _resolve_ambush()
	var player := _resolve_player()
	if ambush == null or player == null or not ambush.can_begin():
		return

	# Taken rather than read, so this fight can only ever be opened once.
	_staged = state.take_staged_combat()

	_running = true
	_died = false
	_encounter_kind = _staged.get(&"kind", &"bandit")
	_loot = CombatLoot.new()
	_combat_enemy_count = _staged.get(&"enemy_count", 0)
	_combat_start_msec = Time.get_ticks_msec()

	# The hour the fight was picked up at, held still for its whole length. The
	# clock is an autoload and would otherwise keep turning through the load, so
	# it is stopped again here - the map froze it as it left, and this is the
	# scene that owns it now.
	var clock := _resolve_world_clock()
	if clock != null:
		_freeze_world_clock(clock)
		_match_combat_ambient_to_world_time(clock)

	_follow_player_death()
	if not ambush.cleared.is_connected(_on_combat_cleared):
		ambush.cleared.connect(_on_combat_cleared, CONNECT_ONE_SHOT)

	var placed := ambush.begin_with(_combat_enemy_count)
	if placed <= 0:
		if ambush.cleared.is_connected(_on_combat_cleared):
			ambush.cleared.disconnect(_on_combat_cleared)
		_abort_encounter()
		return

	_resupply_equipped_weapon()

	if _encounter_kind == &"bounty_boss":
		_start_boss_music()
		_boss_payload = WorldBountyEncounter.new()
		_boss_payload.region_id = _staged.get(&"region_id", &"")
		_boss_payload.camp_location_id = _staged.get(&"camp_location_id", &"")
		_boss_payload.world_position = _staged.get(&"return_position", Vector2.ZERO)
		_boss_payload.world_day = _staged.get(&"world_day", 0)
		_boss_payload.world_degree = _staged.get(&"world_degree", 0.0)
		boss_encounter_started.emit(_boss_payload)
	else:
		_start_combat_music()

	# Rebuilt from the record rather than carried across, because what it used to
	# carry - the [WorldBandit] node itself - was freed with the map. Nothing
	# listening reads that field; both listeners read the group's strength.
	_payload = WorldBanditEncounter.new()
	_payload.group_strength = _staged.get(&"group_strength", 0.0)
	_payload.region_id = _staged.get(&"region_id", &"")
	_payload.world_position = _staged.get(&"return_position", Vector2.ZERO)
	_payload.encounter_type = _encounter_kind
	_payload.world_day = _staged.get(&"world_day", 0)
	_payload.world_degree = _staged.get(&"world_degree", 0.0)
	encounter_started.emit(_payload)
	_schedule_destination_reveal()


## Opens a fight against a bounty target's own presence on the World Map -
## the boss-camp twin of [method _begin_encounter], reached only through
## [WorldBountyBossDirector], which has already confirmed [param boss] is
## standing at its camp, inside its active window, before calling this. See
## rule 17 of the bounty camps phase: the same bridge, the same
## [AmbushWaveDirector] fight, a second entry point rather than a second
## combat system.
func try_begin_boss_encounter(boss: WorldBountyBoss) -> bool:
	if _running or boss == null or not is_instance_valid(boss) or boss.bounty == null:
		return false

	var player := _resolve_player()
	var router := WorldRegionRouter.get_active(self)
	if player == null or router == null:
		return false

	var region_id := boss.region_id
	if region_id.is_empty():
		region_id = router.get_current_region_id()
	if region_id.is_empty():
		return false

	_open_loading_transition()
	_start_boss_music()

	_running = true
	_died = false
	_encounter_kind = &"bounty_boss"
	_boss = boss
	# Marked engaged on the spot, the same reason a contacted [WorldBandit] is,
	# so nothing else can reach this same contract mid-transition.
	boss.set_engaged(true)

	var horse := _resolve_horse()
	var mounted := horse != null and horse.is_mounted()
	_horse_mounted_before = mounted
	if horse != null:
		horse.set_mounted(false)

	var world_day := 0
	var world_degree := 0.0
	var clock := _resolve_world_clock()
	if clock != null:
		if clock.has_method(&"get_world_day"):
			world_day = clock.call(&"get_world_day")
		if clock.has_method(&"get_world_degree"):
			world_degree = clock.call(&"get_world_degree")
		_freeze_world_clock(clock)

	# The smallest adapter there is for a boss: [method Bounty.get_knowledge_ratio]'s
	# own doc already names it as what mini boss difficulty is meant to be scaled
	# off, read here through the exact min/max an ordinary [WorldBandit] fight
	# already clamps its own count to. No second curve, no boss-specific numbers.
	var bounty := boss.bounty
	var ratio := bounty.get_knowledge_ratio()
	var count := clampi(
		int(round(lerpf(float(min_enemy_count), float(max_enemy_count), ratio))),
		mini(min_enemy_count, max_enemy_count), max_enemy_count)

	# The bounty is carried across as its id rather than as the boss node, which
	# is freed with the map. Completing the contract on a win is the ledger's
	# business and the ledger only ever needed the id.
	var payload := {
		&"kind": &"bounty_boss",
		&"group_strength": float(count),
		&"enemy_count": count,
		&"region_id": region_id,
		&"bounty_id": boss.get_bounty_id(),
		&"camp_location_id": boss.camp.get_location_id() if boss.camp != null else &"",
		&"world_day": world_day,
		&"world_degree": world_degree,
		&"horse_mounted": mounted,
		&"return_region": region_id,
		&"return_position": player.global_position,
	}

	if not router.go_to_combat(region_id, payload):
		_unfreeze_world_clock(clock, 0.0)
		_cancel_loading_transition()
		_abort_encounter()
		return false
	return true
	return true
## The one path back out that was never actually a fight - nothing could be
## spawned. Whatever was contacted stands exactly as it was found rather than
## being spent for nothing, as rule 12 of the World Map integration asks for a
## failed transition.
##
## It is reached from either side of the scene change: on the map, when there is
## no arena to go to, and in the arena, when the crowd could not be placed. On the
## map nothing has moved yet, so there is nothing to put back but the group and
## the music. In the arena there is no map left to stand back on, so the way out
## is the ordinary way back.
func _abort_encounter() -> void:
	# The combat or boss music this same call already started is asked back
	# off, since there is no fight underneath it after all.
	_switch_music(travel_state)

	if _bandit != null and is_instance_valid(_bandit):
		_bandit.active = true
		_bandit.visible = true
	for reinforcement: WorldBandit in _reinforcements:
		if reinforcement != null and is_instance_valid(reinforcement):
			reinforcement.active = true
			reinforcement.visible = true
	_reinforcements = []
	if _boss != null and is_instance_valid(_boss):
		_boss.set_engaged(false)

	var horse := _resolve_horse()
	if horse != null and _horse_mounted_before:
		horse.set_mounted(true)

	var clock := _resolve_world_clock()
	if clock != null:
		_unfreeze_world_clock(clock, 0.0)
	_restore_combat_ambient()
	_drop_player_death()

	var staged := _staged
	_staged = {}
	_running = false
	_bandit = null
	_boss = null
	_payload = null
	_boss_payload = null

	# In the arena there is no map underneath to stand back on, so the abort
	# leaves the same way a finished fight does.
	if not staged.is_empty():
		var router := WorldRegionRouter.get_active(self)
		if router != null:
			router.return_from_combat(staged)


# --- The cinematic presentation ----------------------------------------------

## Opens the shared [TravelLetterbox]'s loading transition the instant an
## encounter is accepted, before anything about the player, the camera or the
## world is touched - so the whole of the position swap and the ambush spawn
## that follow happen hidden behind bars and a turning "Loading" word rather
## than as a visible cut. A world with no letterbox in it fights exactly as it
## did before this existed.
func _open_loading_transition() -> void:
	var letterbox := _resolve_letterbox()
	if letterbox != null:
		letterbox.play_loading_transition()


## Reveals the Arena once the fight has actually been placed, held behind the
## bars for [member combat_transition_hold_time] first so the "Loading" word
## is seen rather than flashed - the same deliberate hold
## [member RunPortal.screen_time] gives its own departure screen over a swap
## that is, underneath, just as instant as this one.
func _schedule_destination_reveal() -> void:
	var letterbox := _resolve_letterbox()
	if letterbox == null:
		return
	var hold := maxf(combat_transition_hold_time, 0.0)
	if hold <= 0.0:
		letterbox.play_destination_reveal()
		return
	# Real time and process-always, so the reveal still lands whatever this
	# fight's own opening has done to the tree's pause state.
	var timer := get_tree().create_timer(hold, true, false, true)
	timer.timeout.connect(letterbox.play_destination_reveal)


## Takes the "Loading" word back down without revealing anything, for the one
## path that opens a transition and then finds there is no room in the Arena
## to actually place the fight - see the failure branches of
## [method _begin_encounter] and [method try_begin_boss_encounter]. Leaves the
## World Map's bars exactly as they already were, rather than stuck mid-reveal
## over a fight that never started.
func _cancel_loading_transition() -> void:
	var letterbox := _resolve_letterbox()
	if letterbox != null:
		letterbox.cancel_loading_transition()


func _resolve_letterbox() -> TravelLetterbox:
	return get_node_or_null(letterbox_path) as TravelLetterbox


# --- Music and cues -----------------------------------------------------------

## Starts a bandit fight's or a bounty camp's own crowd's music - one of
## [member fight_tracks], picked without repeating the last one, entered at
## once rather than crossfaded. Called in the same breath as
## [method _open_loading_transition], so the fight is never loading in
## silence.
func _start_combat_music() -> void:
	var board := _resolve_music_board()
	if board == null:
		return
	var track := _pick_fight_track()
	if track != null:
		board.set_state_track(combat_state, track)
	board.enter_immediate(combat_state)


## The louder twin of [method _start_combat_music] for a bounty camp's own
## boss - a single authored track rather than a picked one, since there is
## only the one, and a Boss Discovery cue alongside it. Called at the same
## point [method _start_combat_music] is, for the same reason.
func _start_boss_music() -> void:
	var board := _resolve_music_board()
	if board != null:
		board.enter_immediate(boss_state)
	_play_cue(&"boss_discovery")


func _pick_fight_track() -> AudioStream:
	if fight_tracks.is_empty():
		return null
	if _fight_track_picker == null or _fight_track_picker.size() != fight_tracks.size():
		_fight_track_picker = VariantPicker.new(fight_tracks.size(), 1.6, 0.0)
	var index := _fight_track_picker.pick()
	if index < 0 or index >= fight_tracks.size():
		return null
	return fight_tracks[index]


func _switch_music(state_id: StringName) -> void:
	var board := _resolve_music_board()
	if board != null:
		board.enter_immediate(state_id)


func _play_cue(set_name: StringName) -> void:
	var stinger := _resolve_stinger()
	if stinger != null:
		stinger.play_variant(set_name)


func _resolve_music_board() -> MusicStateBoard:
	var named := get_node_or_null(music_states_path) as MusicStateBoard
	return named if named != null else MusicStateBoard.get_active(self)


func _resolve_stinger() -> StingerBoard:
	var named := get_node_or_null(stinger_path) as StingerBoard
	return named if named != null else StingerBoard.get_active(self)


func _resolve_decision_menu() -> WorldBanditDecisionMenu:
	var named := get_node_or_null(decision_menu_path) as WorldBanditDecisionMenu
	return named if named != null else WorldBanditDecisionMenu.get_active(self)


func _resolve_interaction_camera() -> WorldMapInteractionCamera:
	var named := get_node_or_null(interaction_camera_path) as WorldMapInteractionCamera
	return named if named != null else WorldMapInteractionCamera.get_active(self)


func _resolve_locker() -> AmmoLocker:
	return get_node_or_null(locker_path) as AmmoLocker


## Tops the equipped weapon up from the Horse Inventory the instant a fight is
## actually going to happen - see [method AmmoLocker.resupply_equipped_from_inventory] -
## called only once [method AmbushWaveDirector.begin_with] has actually placed
## the fight, never earlier: an encounter that turns out to have no room in
## the Arena aborts through [method _abort_encounter] without ever reaching
## here, so a fight that never opened can never charge the player for one.
## Hearts are never part of this - only the one [AmmoType] the weapon in hand
## actually feeds on ever moves.
func _resupply_equipped_weapon() -> void:
	var locker := _resolve_locker()
	if locker == null:
		return
	var inventory := RunInventory.get_active(self)
	if inventory == null:
		return

	# An ambush's own three attackers are still carrying [member WorldBandit.in_ambush]
	# at this point - nothing between the contact and here ever clears it for
	# the group that actually caught the player - so this is the one place
	# that reads it, rather than [WorldMapAmbushDirector] having to reach into
	# a fight it never opens itself. See [method AmmoLocker.resupply_equipped_from_inventory_ambush].
	if _encounter_kind == &"bandit" and _bandit != null and is_instance_valid(_bandit) and _bandit.in_ambush:
		locker.resupply_equipped_from_inventory_ambush(inventory, ambush_refill_cap_fraction)
		return

	locker.resupply_equipped_from_inventory(inventory)


# --- Ending the fight --------------------------------------------------------

## The only ending an ambush has, win or lose alike - see
## [signal AmbushWaveDirector.cleared]. [member _died], set the instant the
## player's own [Health] reported them down, is what tells the two apart here.
##
## [b]Held back for as long as a [KillCam] moment the final kill just opened is
## still playing.[/b] [signal AmbushWaveDirector.last_attacker_defeated] and
## [signal AmbushWaveDirector.cleared] fire in the same breath - see that
## class's own doc - so by the time this runs, [KillCam.is_active] is already
## true whenever this ending was an actual kill rather than a rout or the
## player's own death. The winding-down itself never runs from here: it is
## [method _finish_combat_cleared], asked for at once when there is no hold to
## wait on and asked for again, once, the instant [signal KillCam.ended] says
## the mandatory beat is over.
func _on_combat_cleared() -> void:
	if not _running:
		return

	if not _died:
		var cam := KillCam.get_active(self)
		if cam != null and cam.is_active():
			if not cam.ended.is_connected(_finish_combat_cleared):
				cam.ended.connect(_finish_combat_cleared, CONNECT_ONE_SHOT)
			return

	_finish_combat_cleared()


## The actual wind-down of a cleared fight - see [method _on_combat_cleared],
## which is the only thing that ever calls this.
func _finish_combat_cleared() -> void:
	if not _running:
		return

	var died := _died
	var kind := _encounter_kind
	var bandit := _bandit
	var boss := _boss
	var horse := _resolve_horse()

	_drop_player_death()

	if died:
		# The existing death flow carries the player home from here - see
		# PlayerDeathSequence. The World Map is not put back: there is nothing
		# to return to yet, the run is over, and the next one rebuilds this
		# world from nothing. The clock is only let run again, never advanced -
		# rule 8 of the integration is about the fight the player walked away
		# from, and this one they did not.
		var clock := _resolve_world_clock()
		if clock != null:
			_unfreeze_world_clock(clock, 0.0)
		_restore_combat_ambient()
		if boss != null and is_instance_valid(boss):
			boss.set_engaged(false)
		_running = false
		_bandit = null
		_boss = null
		_payload = null
		_boss_payload = null
		encounter_ended.emit(false)
		if kind == &"bounty_boss":
			boss_encounter_ended.emit(false)
		return

	# A win. Whatever combat left the world's speed at - a [HitStop] the final
	# blow asked for, or anything else on the same dial - is handed back at
	# its own ordinary speed before a single other thing about the ending
	# runs, exactly the way the mandatory Kill Cam beat itself already
	# finished before this function was ever called. The World Map's own
	# slow motion is [WorldSlowdown], a character-only multiplier with
	# nothing to do with [member Engine.time_scale] - see that class's own
	# doc - so this can never fight it and there is nothing left over here
	# for a World Map that was never slowed in the first place. Arena
	# combat's own slow motion is deliberately never carried across this
	# seam: the World Map is handed back at normal speed on every win, full
	# stop.
	Engine.time_scale = 1.0

	# The World Map's own music is asked back first of all - Travel.WAV
	# resumes from exactly the position it was stowed at the instant combat
	# music opened, never restarted - and everything else about handing the
	# World Map back follows it exactly as it already did.
	_switch_music(travel_state)

	# The World Map time a cleared fight is worth - rule 4 of the brief, in
	# full: a flat base for having fought at all, a degree for every so many
	# enemies actually put in the Arena, and a flat bonus on top for a boss.
	# Nothing here reads how long the fight took in real seconds any more -
	# the progression is the fight's own size, applied the instant it ends,
	# never a gradual catch-up.
	var boss_bonus := combat_time_advance_boss_bonus if kind == &"bounty_boss" else 0.0
	var enemy_bonus := 0.0
	if combat_time_advance_enemy_step > 0:
		enemy_bonus = floorf(float(_combat_enemy_count) / float(combat_time_advance_enemy_step)) \
			* combat_time_advance_per_enemies
	var advance := maxf(combat_time_advance_base, 0.0) + enemy_bonus + boss_bonus

	var clock := _resolve_world_clock()
	if clock != null:
		_unfreeze_world_clock(clock, advance)
	_restore_combat_ambient()

	if kind == &"bounty_boss":
		# The boss node was freed with the map that opened this fight, so the
		# contract is closed by its id - which is all the ledger ever needed. The
		# camp is written down as taken so the man is not standing there again
		# the next time this region is built.
		var bounty_id: StringName = _staged.get(&"bounty_id", &"")
		if not bounty_id.is_empty():
			var ledger := _resolve_ledger()
			if ledger != null:
				ledger.complete(bounty_id)
		var state := WorldMapState.get_active(self)
		var camp_id: StringName = _staged.get(&"camp_location_id", &"")
		if state != null and not camp_id.is_empty():
			state.remember(
				_staged.get(&"region_id", &""), WorldMapState.KIND_LOCATION, camp_id,
				{"cleared": true})

	# Everything that was folded into this fight was written down as gone before
	# the map was freed - see [method _begin_encounter] - so there is no group
	# left standing to free and no reinforcement left to hand back.



	_running = false
	_bandit = null
	_boss = null
	_payload = null
	_boss_payload = null
	encounter_ended.emit(true)
	if kind == &"bounty_boss":
		boss_encounter_ended.emit(true)

	# Back to the map the fight was picked up from, standing where it was picked
	# up. The arena is freed by the change, which is what makes the next fight a
	# clean floor: no corpse, no dropped gun, no casing and no blood survive it.
	var router := WorldRegionRouter.get_active(self)
	if router != null:
		router.return_from_combat(_staged)
	_staged = {}


# --- Matching the Combat Map to the frozen World Map hour --------------------

## Blends [DayCycleDirector]'s ambient onto exactly where [param clock] -
## already resolved and about to be frozen by the caller - sits between two of
## the map's own authored [member DayStage.ambient_colour] values, the same
## continuous read [SunController] already takes of the matching [SunStage]
## pair - see [method WorldTimeManager.get_time_period_index] and
## [method WorldTimeManager.get_period_progress]. [SunController] needs no
## equivalent call of its own: it already reads nothing but [param clock] and
## freezes the same instant this fight does.
##
## Nothing here invents a colour - [member DayCycleDirector.stages] is read
## exactly as authored and only the two neighbours [param clock] currently
## sits between are ever touched - and nothing here keeps a second copy of
## either: [method DayCycleDirector.apply_ambient_color] is asked for the
## result the same way [method DayCycleDirector.apply] already asks for a
## single stage's own colour.
func _match_combat_ambient_to_world_time(clock: Node) -> void:
	if clock == null or not clock.has_method(&"get_time_period_index"):
		return
	var day := DayCycleDirector.get_active(self)
	if day == null or day.stages.is_empty():
		return

	_day_stage_forced = true
	day.apply_ambient_color(day.get_world_time_ambient_colour(clock))


## Gives [DayCycleDirector]'s ambient back to whatever hour it is actually
## meant to be showing. [method DayCycleDirector.release_ambient_override]
## lets its own [code]DayClock[/code] paint the [CanvasModulate] again - see
## that method's own doc for why it was held back for the fight's length in
## the first place - and [method DayCycleDirector.refresh] then asks the map
## for its own colour right away rather than waiting for that clock's next
## announcement. [member DayCycleDirector.stage_override] was never touched by
## this fight, so there is nothing saved to hand back beyond the override
## itself. Safe to call whether or not [method _match_combat_ambient_to_world_time]
## ever ran - an aborted encounter that never froze anything leaves this a
## no-op.
func _restore_combat_ambient() -> void:
	if not _day_stage_forced:
		return
	_day_stage_forced = false
	var day := DayCycleDirector.get_active(self)
	if day == null:
		return
	day.release_ambient_override()
	day.refresh()


# --- Following the player's own death ---------------------------------------

## Watched only for as long as it takes to tell the two endings apart in
## [method _on_combat_cleared] - not to act on the death itself, which
## [AmbushWaveDirector] and [PlayerDeathSequence] already do between them.
func _follow_player_death() -> void:
	_drop_player_death()
	var player := _resolve_player()
	if player == null:
		return
	_player_health = _find_health(player)
	if _player_health != null and not _player_health.died.is_connected(_on_player_died):
		_player_health.died.connect(_on_player_died)


## Dropped rather than left one-shot, because the player's pool outlives their
## death - they are revived into the same [Health] - so a connection left
## behind would still be listening at the next encounter.
func _drop_player_death() -> void:
	if _player_health != null and is_instance_valid(_player_health) \
			and _player_health.died.is_connected(_on_player_died):
		_player_health.died.disconnect(_on_player_died)
	_player_health = null


func _on_player_died() -> void:
	_died = true


func _find_health(body: Node) -> Health:
	for node: Node in body.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


# --- Looking things up -------------------------------------------------------

func _resolve_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D


func _resolve_ambush() -> AmbushWaveDirector:
	var named := get_node_or_null(ambush_path) as AmbushWaveDirector
	return named if named != null else AmbushWaveDirector.get_active(self)


func _resolve_spawner() -> EnemySpawner:
	return get_node_or_null(spawner_path) as EnemySpawner


func _resolve_horse() -> WorldMapHorse:
	return get_tree().get_first_node_in_group(horse_group) as WorldMapHorse


func _resolve_world_clock() -> Node:
	return get_node_or_null(world_clock_path)


## Stops [param clock] and locks it to the exact middle degree of whichever
## World Map segment the player was standing in - see
## [method WorldTimeManager.freeze_for_combat], which is what actually moves
## the degree; this only adds the fallback for a clock that predates it, so an
## older or a test clock still simply stops rather than erroring.
func _freeze_world_clock(clock: Node) -> void:
	if clock.has_method(&"freeze_for_combat"):
		clock.call(&"freeze_for_combat")
		return
	clock.set_process(false)


## The other half of [method _freeze_world_clock]: hands the clock back,
## advanced by [param degrees] from the real degree it was frozen at - see
## [method WorldTimeManager.unfreeze_after_combat]. [param degrees] of 0 is a
## fight that never happened, or a death, neither of which advance the World
## Map at all.
func _unfreeze_world_clock(clock: Node, degrees: float) -> void:
	if clock.has_method(&"unfreeze_after_combat"):
		clock.call(&"unfreeze_after_combat", degrees)
		return
	clock.set_process(true)


func _resolve_ledger() -> BountyLedger:
	return get_node_or_null(ledger_path) as BountyLedger
