class_name WorldMapCombatBridge
extends Node
## World Map encounter → existing Combat → World Map, and nothing in between.
##
## [b]This is the adapter, not a second combat system.[/b] It watches every
## [WorldBandit] for the player walking into it, and when one is reached it
## hands the fight whole to [AmbushWaveDirector] - the same director an
## ordinary road ambush and a Trouble Danger already fight through, built on
## the world's own [EnemySpawner] and its ordinary enemies. Nothing about how a
## fight is spawned, paced or ended is written here; this only decides *when*
## one starts, *how big* it is, and *where the player was standing* so they can
## be put back there.
##
## [b]The fight is held in the Arena[/b] - the same rectangle a round is
## already fought in, sitting quiet and unused for as long as the player is out
## on the World Map (nothing starts [WaveManager] for a World Map run - see
## [WorldBoot]). So there is no second map to build and no second
## [member EnemySpawner.arena_bounds] to swap in and out, unlike
## [BossEncounterMap]'s own dedicated ground: the player is simply set down in
## the Arena that was already there, exactly the way [DangerDirector] already
## fights a Danger wherever the player happens to be standing.
##
## [b]Group strength becomes an enemy count by the smallest reading there is[/b]
## - [member WorldBandit.group_strength] scaled by [member enemy_count_scale],
## rounded and clamped, is the number handed to [method AmbushWaveDirector.begin_with].
## [member enemy_count_scale] is the one and only place that conversion is
## tuned - a group's own [member WorldBandit.group_strength], its movement and
## the World Map's own bandit population are never touched by it, only how
## many enemies a contacted group turns into. No difficulty curve is invented
## here; the ambush's own opening group, arrival pacing and breaking point are
## all left at whatever this world already has them authored to.
##
## [b]What carries through untouched.[/b] The player is never rebuilt and
## nothing about them is read or written here beyond where they are standing
## and whether they are mounted - [RunInventory], carried Blood, [HorseBlood]
## and the run's own Streak are exactly as persistent through a fight as they
## already are through anything else that moves the player around the
## persistent world, because moving the player around the persistent world is
## all this does. [WorldMapHorse] is explicitly dismounted for the fight and
## remounted exactly as it was found - see [method _begin_encounter] - because
## nothing else stands between the World Map and here to do that the way
## [WorldMapDestination] does for an ordinary journey; every other flag on it
## is left alone.
##
## [b]World time freezes for the fight and catches up on the way out.[/b]
## [WorldClock] - the [WorldTimeManager] autoload - is simply asked to stop
## ticking ([method Node.set_process]) the moment combat opens, which is also
## what freezes [SunController] and every shadow reading it, since both already
## read nothing but that one clock. On a win, the seconds the fight actually
## took are handed to [method WorldTimeManager.advance_seconds] - the same
## conversion the World Map already turns real seconds into degrees with - and
## only then is the clock let run again. See [method _end_encounter].
##
## [b]The Combat Map's darkness is blended onto the same hour for the same
## reason.[/b] [SunController] and its shadows need nothing extra - they
## already read only [WorldTimeManager] and freeze the instant it does, on the
## exact same continuous blend between two [SunStage] anchors this borrows the
## pattern from - but [DayCycleDirector]'s own ambient tint reads the
## round-based [code]DayCycle[/code] clock instead, per that class's own doc.
## [method _match_combat_ambient_to_world_time] works out where [WorldClock]
## currently sits between two of [DayCycleDirector]'s own authored
## [member DayStage.ambient_colour] values - the same colours [DayCycleDirector]
## always shows, never a colour invented here - and pushes that blend straight
## through [method DayCycleDirector.apply_ambient_color] for the fight's
## length; [method _restore_combat_ambient] simply asks the map for its own
## colour back on every way out, so an ordinary Base round fought before or
## after is never touched by this at all.
##
## [b]The Arena is swept clean both as a fight opens and after a win.[/b]
## [WorldReset] - the same node "Looking for Trouble" already resets the
## world through without a scene rebuild - is asked for a reset the instant
## this starts and again once the player is back on the World Map, so the
## next encounter never opens onto last encounter's blood, brass and bodies
## whichever of the two sweeps actually catches them - see
## [method _reset_combat_instance]. World Map state is never in its sweep -
## see that class's own doc for what it touches and what it never does.
##
## [b]A won fight is not over the instant the last man falls.[/b] A final kill
## opens the world's own [KillCam] - see [method AmbushWaveDirector.last_attacker_defeated]
## and [signal KillCam.trigger] - and [method _on_combat_cleared] holds every bit of
## winding the fight down behind [signal KillCam.ended] rather than beginning the
## moment [signal AmbushWaveDirector.cleared] itself arrives: the music, the clock
## catching up, the player and the horse going back to the World Map, and
## [signal encounter_ended] itself - the signal [HorseCartScreen] opens on - all wait
## for the mandatory hold to finish. A fight that ends by routing rather than by a
## kill never opens a [KillCam] moment at all, so it is wound down exactly as soon as
## it always was; only an ending with a body to hold the camera on is held back. See
## [method _finish_combat_cleared].
##
## [b]The World Map is handed back at normal speed, always.[/b] The instant the
## hold is over and a win's own wind-down begins, [member Engine.time_scale] is
## set back to 1 outright - see [method _finish_combat_cleared] - so nothing an
## Arena fight did to it, on top of whatever [KillCam]'s own brief [HitStop] already
## put back on its own, can ever cross into the World Map. Nothing about ending on
## a death touches this: [PlayerDeathSequence] owns that slow motion on its own
## timeline and this never cuts it short.
##
## [b]What a win hands the player is not decided here.[/b] [method get_combat_loot]
## is a fresh, empty [CombatLoot] for every encounter, opened for
## [HorseCartScreen] to read once the fight is over - the container a later pass
## fills in, never this one. Nothing here rolls a gem, a heart, a round of ammunition
## or a boss's own knowledge; that is deliberately left for the loot-generation work
## still to come.
##
## [b]A death is not this node's ending to play.[/b] [AmbushWaveDirector]
## already breaks and empties itself on the player's own [signal Health.died],
## the same way every other fight in the game does, and
## [PlayerDeathSequence] already owns carrying a beaten player home - see its
## own class doc. This only follows the death long enough to tell the two
## endings apart when [signal AmbushWaveDirector.cleared] finally arrives: a
## win puts the player back on the World Map exactly where they were
## contacted; a death lets the existing flow decide where they end up and
## touches nothing about the World Map at all.
##
## [b]A bounty boss opens the identical fight through a second door.[/b]
## [method try_begin_boss_encounter] is [WorldBountyBossDirector]'s way in -
## see that class's own doc - and shares every piece of this machinery
## (camera, clock, horse, death-following, placement) with the bandit path
## above; the only things that differ are where the enemy count comes from
## and what happens to the thing that was contacted on a win. See
## [signal boss_encounter_started] and [signal boss_encounter_ended].
##
## [b]The whole hand-off happens behind [TravelLetterbox].[/b] Both entry
## points open its loading transition before anything about the player, the
## camera or the world is touched, and only reveal the Arena once the ambush
## has actually been placed - see [method _open_loading_transition] and
## [method _schedule_destination_reveal]. Nothing here builds a second
## presentation for the World Map's own cinematic bars: this is the one real
## transition the reusable letterbox controller is wired into today, and a
## world with none in it fights exactly as it did before that controller
## existed.

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
## The World Map's own root - everything a fight must never let show through:
## every [WorldBandit] and its formation, the fog, the hover tooltip, the
## wanted board. See [method _set_world_map_presentation_visible].
@export var world_map_path: NodePath = ^"../WorldMap"
## The World Map's own screen-space HUD - see [code]WorldMap.tscn[/code]'s own
## [code]UI[/code] [CanvasLayer]. Held apart from [member world_map_path]
## because a [CanvasLayer] draws on its own layer regardless of an ancestor
## [CanvasItem]'s own [member CanvasItem.visible] - hiding [member world_map_path]
## alone would leave the World Map's clock and minimap drawn straight over the
## Arena. See [method _set_world_map_presentation_visible].
@export var world_map_ui_path: NodePath = ^"../WorldMap/UI"

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
var _saved_world_position: Vector2 = Vector2.ZERO
var _saved_horse_mounted: bool = false
var _combat_start_msec: int = 0
var _died: bool = false
var _player_health: Health
var _camera_limits_saved: Vector4i = Vector4i.ZERO
var _camera_limits_taken: bool = false
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

func _begin_encounter(bandit: WorldBandit) -> void:
	var ambush := _resolve_ambush()
	var spawner := _resolve_spawner()
	var player := _resolve_player()
	if ambush == null or spawner == null or player == null or not ambush.can_begin():
		return

	_open_loading_transition()
	_start_combat_music()

	_running = true
	_died = false
	_encounter_kind = &"bandit"
	_bandit = bandit
	_loot = CombatLoot.new()
	_reset_combat_instance()
	# Marked engaged and hidden on the spot, so nothing else can reach this same
	# group while it is mid-transition and it reads as gone rather than as a
	# duplicate standing beside the fight it started.
	bandit.active = false
	bandit.visible = false
	# Every reinforcement gathered for this contact - see
	# [method _gather_reinforcements] - goes the same way: it is about to be
	# folded into the very same fight, not left standing on the World Map
	# beside a bandit that just vanished into one.
	for reinforcement: WorldBandit in _reinforcements:
		if reinforcement != null and is_instance_valid(reinforcement):
			reinforcement.active = false
			reinforcement.visible = false
	# The whole of the World Map's own presentation - every group's formation,
	# the fog, the hover tooltip, its own screen-space HUD - goes with it. See
	# [method _set_world_map_presentation_visible]: hiding the one contacted
	# bandit above is not enough on its own to keep the rest of the World Map
	# from showing straight through the fight that follows.
	_set_world_map_presentation_visible(false)

	_payload = WorldBanditEncounter.new()
	_payload.bandit = bandit
	# The reinforced total, not just this one contact's own - see section 16
	# and [method _combined_strength]. Read once here, before anything below
	# can free a reinforcement, so the payload and the enemy count it feeds
	# the Arena can never end up disagreeing about how big the fight was.
	var combined_strength := _combined_strength(bandit)
	_payload.group_strength = combined_strength
	_payload.region_id = bandit.region_id
	_payload.world_position = player.global_position
	_payload.encounter_type = &"bandit"

	_saved_world_position = player.global_position
	var horse := _resolve_horse()
	_saved_horse_mounted = horse != null and horse.is_mounted()
	if horse != null:
		horse.set_mounted(false)

	_take_camera_to_arena(spawner)
	_place(player, spawner.arena_bounds.get_center())

	var clock := _resolve_world_clock()
	if clock != null:
		if clock.has_method(&"get_world_day"):
			_payload.world_day = clock.call(&"get_world_day")
		if clock.has_method(&"get_world_degree"):
			_payload.world_degree = clock.call(&"get_world_degree")
		_freeze_world_clock(clock)
		_match_combat_ambient_to_world_time(clock)
	_combat_start_msec = Time.get_ticks_msec()
	_follow_player_death()

	var count := clampi(
		int(round(combined_strength * enemy_count_scale)),
		mini(min_enemy_count, max_enemy_count), max_enemy_count)
	_combat_enemy_count = count
	if not ambush.cleared.is_connected(_on_combat_cleared):
		ambush.cleared.connect(_on_combat_cleared, CONNECT_ONE_SHOT)

	var placed := ambush.begin_with(count)
	if placed <= 0:
		if ambush.cleared.is_connected(_on_combat_cleared):
			ambush.cleared.disconnect(_on_combat_cleared)
		_cancel_loading_transition()
		_abort_encounter()
		return

	_resupply_equipped_weapon()
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

	var ambush := _resolve_ambush()
	var spawner := _resolve_spawner()
	var player := _resolve_player()
	if ambush == null or spawner == null or player == null or not ambush.can_begin():
		return false

	_open_loading_transition()
	_start_boss_music()

	_running = true
	_died = false
	_encounter_kind = &"bounty_boss"
	_boss = boss
	_loot = CombatLoot.new()
	_reset_combat_instance()
	# Marked engaged and hidden on the spot, the same reason a contacted
	# [WorldBandit] is - see [method _begin_encounter] - so nothing else can
	# reach this same contract while it is mid-transition.
	boss.set_engaged(true)
	# The World Map's own presentation goes with it - see
	# [method _set_world_map_presentation_visible] and the identical call in
	# [method _begin_encounter].
	_set_world_map_presentation_visible(false)

	var bounty := boss.bounty
	var boss_payload := WorldBountyEncounter.new()
	boss_payload.bounty = bounty
	boss_payload.boss = boss
	boss_payload.region_id = boss.region_id
	boss_payload.camp_location_id = boss.camp.get_location_id() if boss.camp != null else &""
	boss_payload.world_position = player.global_position
	_boss_payload = boss_payload

	_saved_world_position = player.global_position
	var horse := _resolve_horse()
	_saved_horse_mounted = horse != null and horse.is_mounted()
	if horse != null:
		horse.set_mounted(false)

	_take_camera_to_arena(spawner)
	_place(player, spawner.arena_bounds.get_center())

	var clock := _resolve_world_clock()
	if clock != null:
		if clock.has_method(&"get_world_day"):
			boss_payload.world_day = clock.call(&"get_world_day")
		if clock.has_method(&"get_world_degree"):
			boss_payload.world_degree = clock.call(&"get_world_degree")
		_freeze_world_clock(clock)
		_match_combat_ambient_to_world_time(clock)
	_combat_start_msec = Time.get_ticks_msec()
	_follow_player_death()

	# The smallest adapter there is for a boss, too: [method Bounty.get_knowledge_ratio]'s
	# own doc already names it as what mini boss difficulty is meant to be
	# scaled off, read here through the exact min/max an ordinary [WorldBandit]
	# fight already clamps its own count to. No second curve, no boss-specific
	# numbers - rule 4's "use the smallest adapter possible", applied a second
	# time rather than reinvented.
	var ratio := bounty.get_knowledge_ratio()
	var count := clampi(
		int(round(lerpf(float(min_enemy_count), float(max_enemy_count), ratio))),
		mini(min_enemy_count, max_enemy_count), max_enemy_count)
	_combat_enemy_count = count

	if not ambush.cleared.is_connected(_on_combat_cleared):
		ambush.cleared.connect(_on_combat_cleared, CONNECT_ONE_SHOT)

	var placed := ambush.begin_with(count)
	if placed <= 0:
		if ambush.cleared.is_connected(_on_combat_cleared):
			ambush.cleared.disconnect(_on_combat_cleared)
		_cancel_loading_transition()
		_abort_encounter()
		return false

	_resupply_equipped_weapon()
	boss_encounter_started.emit(boss_payload)
	_schedule_destination_reveal()
	return true


## The one path back out that was never actually a fight - nothing could be
## spawned. Everything [method _begin_encounter] or [method try_begin_boss_encounter]
## touched is put back exactly as rule 12 of the World Map integration asks
## for a failed transition: whatever was contacted stands exactly as it was
## found rather than being spent for nothing.
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
	# Given back before the player is placed, same as every other path back to
	# the World Map here - see [method _set_world_map_presentation_visible].
	_set_world_map_presentation_visible(true)

	var player := _resolve_player()
	if player != null:
		_place(player, _saved_world_position)

	var horse := _resolve_horse()
	if horse != null:
		horse.set_mounted(_saved_horse_mounted)

	_give_camera_back()
	var clock := _resolve_world_clock()
	if clock != null:
		_unfreeze_world_clock(clock, 0.0)
	_restore_combat_ambient()
	_drop_player_death()

	_running = false
	_bandit = null
	_boss = null
	_payload = null
	_boss_payload = null


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
	_give_camera_back()

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
		if boss != null and is_instance_valid(boss):
			boss.mark_defeated()
			var ledger := _resolve_ledger()
			if ledger != null:
				ledger.complete(boss.get_bounty_id())
	elif bandit != null and is_instance_valid(bandit):
		bandit.queue_free()
	if kind != &"bounty_boss":
		_release_reinforcements(true)

	# The World Map's own presentation - every remaining group's formation,
	# the fog, its own screen-space HUD - is given back the instant there is
	# a World Map to give it back to. See [method _set_world_map_presentation_visible]
	# and the class doc's own note on why a death never reaches this line.
	_set_world_map_presentation_visible(true)

	var player := _resolve_player()
	if player != null:
		_place(player, _saved_world_position)

	if horse != null:
		horse.set_mounted(_saved_horse_mounted)

	# A bandit fight's own return framing: the player is already standing
	# exactly where they were contacted, so the camera starts the hand-back
	# already at the interaction's own zoom rather than climbing into it a
	# second time, and only the release - back to the World Map's ordinary
	# zoom - is the smooth beat. Bounty-boss returns are untouched: that
	# fight's own camera work is [BossDefeat]'s to own, not this one's.
	if kind == &"bandit":
		var cam := _resolve_interaction_camera()
		if cam != null:
			cam.snap_and_release()

	_reset_combat_instance()

	_running = false
	_bandit = null
	_boss = null
	_payload = null
	_boss_payload = null
	encounter_ended.emit(true)
	if kind == &"bounty_boss":
		boss_encounter_ended.emit(true)


# --- The ground the fight is measured against -------------------------------

## The camera clamped to the Arena for the fight, with what it was written down
## so it can be given back exactly - the same trade [BossEncounterMap] already
## makes for its own ground.
##
## [b]The zoom is snapped back to the Arena's own resting level here too, not
## just eased.[/b] A contact reaches this through [WorldMapInteractionCamera]'s
## own 3x decision push, and [method _on_decision_answered] only ever starts
## that zoom easing back out - it has not landed by the time this runs, same
## frame. [method EnemySpawner.get_view_rect] divides the viewport by whatever
## [member CameraController.zoom] actually is *right now* to decide how much of
## the Arena [AmbushWaveDirector]'s opening group is allowed to spread across -
## see [method AmbushWaveDirector._opening_point]. Left easing, that view reads
## as the decision screen's own tight 3x frame rather than the Arena's, and the
## whole opening group is clamped down into the sliver of ground that frame
## covers - a few dozen pixels around the player instead of
## [member AmbushWaveDirector.opening_distance] - which is what put enemies
## already touching the player the instant a fight opened. Snapping it here
## costs nothing to see: this is still behind [TravelLetterbox]'s own loading
## bars, exactly the "transition that has already hidden the cut" [method
## CameraController.set_zoom_multiplier]'s own [param immediate] is for.
func _take_camera_to_arena(spawner: EnemySpawner) -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	_camera_limits_saved = Vector4i(
		camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
	_camera_limits_taken = true
	camera.set_zoom_multiplier(1.0, true)
	_clamp_camera_to(camera, spawner.arena_bounds)


## Handed back without [method Camera2D.reset_smoothing] - deliberately, unlike
## every other transition in the project. Rule 10 of the integration asks for
## the World Map to re-centre smoothly rather than cut, so the camera is left
## to glide back to the player on its own ordinary follow instead of being
## snapped there.
func _give_camera_back() -> void:
	if not _camera_limits_taken:
		return
	_camera_limits_taken = false
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	camera.limit_left = _camera_limits_saved.x
	camera.limit_top = _camera_limits_saved.y
	camera.limit_right = _camera_limits_saved.z
	camera.limit_bottom = _camera_limits_saved.w


## Shows or hides the whole of the World Map's own presentation - every
## [WorldBandit] and the formation of boxes it builds for itself, the fog, the
## hover tooltip, the wanted board, the World Map's own clock and minimap -
## for the length of a fight held in the Arena.
##
## [b]This is the actual fix for the World Map leaking into combat[/b], not a
## patch on top of one bandit. [method _begin_encounter] and
## [method try_begin_boss_encounter] already mark the one bandit or boss
## contacted as hidden, but nothing before this ever told the *rest* of the
## World Map - every other patrolling group, the fog overlay, the hover
## tooltip a stray mouse position could still be aimed at - that a fight had
## started at all. The World Map is never removed from the tree for a fight -
## see [WorldMapCombatBridge]'s own class doc on the Arena being a rectangle
## in the same scene, not a second one loaded over it - so nothing about the
## World Map's own nodes stops rendering by itself; this is what actually
## asks them to.
##
## [b][member world_map_ui_path] is asked separately because a [CanvasLayer]
## is not a [CanvasItem].[/b] Everything under [member world_map_path] is an
## ordinary [Node2D], so hiding that one root already cascades to every
## [WorldBandit], its formation boxes and the hover tooltip beneath it - the
## same [member Node2D.visible] inheritance [method WorldBandit._update_fog_visibility]
## already relies on. [code]WorldMap.tscn[/code]'s own [code]UI[/code] node is
## a [CanvasLayer] instead, precisely so its clock and minimap draw in screen
## space regardless of the World Map's own camera - but that independence
## cuts both ways: a [CanvasLayer] draws on its own layer no matter what an
## ancestor [CanvasItem]'s [member CanvasItem.visible] says, so it has to be
## told separately or it would keep drawing straight over the Arena. Both
## paths are optional: a world missing either simply leaves that piece exactly
## as before, the same fallback every other resolved path in this file uses.
func _set_world_map_presentation_visible(shown: bool) -> void:
	var world_map := get_node_or_null(world_map_path) as CanvasItem
	if world_map != null:
		world_map.visible = shown
	var world_map_ui := get_node_or_null(world_map_ui_path) as CanvasLayer
	if world_map_ui != null:
		world_map_ui.visible = shown


## The same growing [Teleporter] and [BossEncounterMap] both do: a limit
## rectangle smaller than the screen is a request the camera cannot satisfy, so
## the Arena is widened around its own centre rather than leaving bars down the
## edges.
func _clamp_camera_to(camera: CameraController, area: Rect2) -> void:
	var view := camera.get_viewport_rect().size / camera.zoom
	var box := area
	if area.size.x < view.x or area.size.y < view.y:
		var size := Vector2(maxf(area.size.x, view.x), maxf(area.size.y, view.y))
		box = Rect2(area.get_center() - size * 0.5, size)

	camera.limit_left = int(box.position.x)
	camera.limit_top = int(box.position.y)
	camera.limit_right = int(box.end.x)
	camera.limit_bottom = int(box.end.y)
	camera.reset_smoothing()


func _place(body: Node2D, at: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.global_position = at
	body.reset_physics_interpolation()


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


## Puts the Arena back to how it was found - see [WorldReset]'s own doc for
## what this sweeps and what it never touches. Nothing here builds a second
## reset: this is the identical node "Looking for Trouble" already resets the
## world through without the scene being rebuilt around it, asked for the
## identical thing a second time.
##
## Called twice for the same fight, deliberately: once as a win hands the
## player back to the World Map, so the ground reads clean immediately rather
## than however long it takes the player to wander back near it, and once
## again as the [i]next[/i] encounter opens - rule 2's own "every time a
## World Map combat starts, the combat environment must begin clean" - which
## is what catches a death effect from the last kill that had not finished
## spawning its own debris in time for the first sweep. By the time another
## fight can start at all the player has had to walk there, which is far
## longer than any death effect takes to finish.
func _reset_combat_instance() -> void:
	var reset := WorldReset.get_active(self)
	if reset != null:
		reset.reset()


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
