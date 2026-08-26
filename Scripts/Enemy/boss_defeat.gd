class_name BossDefeat
extends Node
## The end of a mini boss fight: the shot that finishes him, the money, the fall, the
## name crossed off, and the body left lying in the sand.
##
## [b]The boss is beaten the instant the last shot lands, and he does not die of it.[/b]
## Those are two separate events here, and everything about the ending follows from
## keeping them apart:
##
##   [codeblock]
##   last shot  ->  reward paid, streak +1  ->  camera on him at 2.5x  ->  he falls
##              ->  name revealed  ->  name struck through
##              ->  camera home, fixed screen lifted, way to camp opened
##              ->  a corpse on the ground that can be talked to, or shot
##   [/codeblock]
##
## [b]Nothing is ever allowed to reach [signal Health.died].[/b] A death in this game
## means a body that freezes, fades and is freed - see [DeathFade] - and a mini boss
## must do none of those: the player is owed a corpse they can still walk up to, and
## owed it whether they talk to it first or shoot it first. So the lethal blow is caught
## in [method _on_boss_health_changed] and the pool is put back before
## [method Health.take_damage] reaches its own death check, which is the whole
## mechanism. Nothing about [Health] is changed to make that work, and no other
## character in the game behaves differently for it.
##
## [b]What the corpse is worth is paid at the fall, not at the kill.[/b] The contract's
## blood is handed over the moment the man goes down - it is the bounty, and the bounty
## is collected by beating him - and it is paid exactly once because the contract is
## closed out in the same breath; see [method _pay_reward]. Shooting the body
## afterwards is a separate, smaller thing worth [member corpse_blood], and the two can
## never be confused for one another because the reward is credited straight to the
## wallet while the corpse's blood is thrown on the ground to be collected.
##
## [b]And what he knows is about the other men.[/b] His own contract is closed out in
## the same breath as it is paid, so by the time there is a body to press E on it is no
## longer one of the outstanding contracts [SurrenderKnowledge] draws from - a beaten
## outlaw cannot tell the player where he himself was. What he is worth is two or three
## lines filled in on the posters they are still holding, which is what makes each boss
## a lead on the next; see [member knowledge_pieces_min].
##
## [b]The fall, the E and the knowledge are all the enemy's own.[/b] A beaten boss is
## put on the floor through [method EnemySurrender.surrender] - the same component that
## puts a man who has lost his nerve on the floor, with the same rigid fall, the same
## reach circle, the same prompt and the same [SurrenderKnowledge] behind the key - so
## there is exactly one "man on the ground you can press E on" in the game and this is
## not a second one. The boss reaches this point with that component intact and simply
## forbidden from acting on its own; see
## [member EnemySurrender.gives_up_on_its_own] and
## [method MiniBossDirector._strip_giving_up].
##
## [b]It ends the encounter but does not end the round.[/b] The support is sent home
## through its own [EnemyEscape], the fixed screen is handed back through
## [method BossArena.unlock], and the way out is the camp opening exactly as it does at
## the end of any other round - through its own public [method ArenaPortal.open]. The
## round's clock is not started, stopped or touched, because a boss day never had one.

## Emitted the instant the boss is beaten, with the contract and what it paid.
signal boss_defeated(bounty: Bounty, reward: int)
## Emitted when the blood is actually credited, with how much.
signal reward_granted(amount: int)
## Emitted as the boss reaches the ground.
signal boss_fallen
## Emitted as the line is drawn through the name.
signal name_struck
## Emitted once the camera is back on the player and the fixed screen is gone.
signal arena_released
## Emitted when the body itself is finally shot, with the blood it spilled.
signal corpse_killed(blood: int)

## Group this node joins, so a test or a readout can find it without a path.
const GROUP := &"boss_defeat"

## How far the ending has got.
enum Stage {
	## No fight, or one that has not started. Every ordinary round.
	WAITING,
	## The fight. The only stage in which a lethal hit means anything.
	FIGHTING,
	## Beaten and going down. Untouchable for [member invulnerable_seconds].
	FALLING,
	## On the ground and killable again.
	DOWN,
	## The body has been shot. Nothing further happens to it and it stays.
	KILLED,
}

## The boss system whose fight this ends. Its
## [signal MiniBossDirector.fight_started] is the only thing that arms this node, so
## nothing here can run in a round with no boss in it.
@export var director_path: NodePath = ^"../MiniBossDirector"
## The fixed screen, handed back once the name has been struck through.
@export var arena_path: NodePath = ^"../BossArena"
## The phase system, stopped so no further support is sent.
@export var phases_path: NodePath = ^"../BossPhases"
## The ledger the contract is closed out in.
@export var ledger_path: NodePath = ^"/root/Bounties"
## The player's carried blood, which the reward is paid into.
@export var wallet_path: NodePath = ^"/root/Blood"
## Group the player is found in, so this node is not wired to them.
@export var player_group: StringName = &"player"
## Group the living enemies are found in, which is who is sent home.
@export var enemy_group: StringName = &"enemies"

@export_group("The reward")
## Whether the contract's blood is actually paid. Off leaves the whole ending intact
## and pays nothing, for looking at the sequence without the money moving.
@export var grants_reward: bool = true
## Whether the contract is closed out as the reward is paid.
##
## [b]On, and it is what makes the reward once-only.[/b] The price was locked when the
## poster came down and is neither read for difficulty nor written here - see
## [method Bounty.set_reward], which refuses an accepted contract outright - so the only
## question is whether the same contract can pay twice. A closed contract is no longer
## outstanding, so it can never summon a second boss on a later day and can never be
## collected again.
@export var completes_contract: bool = true

@export_group("The streak")
## The run's streak - the [code]Streak[/code] autoload.
@export var streak_path: NodePath = ^"/root/Streak"
## Whether beating this man lengthens the streak.
##
## [b]On, and it happens here rather than when the body is finished off.[/b] The streak
## counts outlaws beaten, and the man is beaten by the shot that puts him on the ground -
## shooting the body afterwards is the same man a second time and must not count again,
## which it cannot, because this is only ever reached from [method _begin_defeat].
##
## Nothing is paid for it now, and deliberately: a streak is worth nothing at all until
## the ride home - see [CashOutScreen] - so the blood this fight drops is worth exactly
## what it says whatever the count stands at.
@export var extends_streak: bool = true

@export_group("Going down")
## How long the beaten boss cannot be hurt for, in seconds, while the fall plays.
##
## The brief's second of grace. It is not [member Health.invulnerable_seconds] - that is
## a per-hit window meant for the player - but the boss's hitboxes coming off their
## layer for a moment, which is the same move a retreat makes to become untouchable.
@export var invulnerable_seconds: float = 1.0
## How far over the boss goes, in degrees, written onto its own
## [member EnemySurrender.fall_degrees].
##
## Much further than a man on his knees: this one is not being spoken to on his way to a
## cell, he is finished, and he has to read as a body on the ground from a long way off.
@export var fall_degrees: float = 84.0
## How long the fall takes, in seconds.
@export var fall_time: float = 0.85
## Whether the beaten man's breathing stops with him.
##
## On. Every character in the game carries a squash-and-stretch idle that restarts
## itself the moment it is found stopped - see [SquashIdle] - so a body left with it
## running goes on quietly breathing in the sand for the rest of the round, and
## shooting it starts it again. Off leaves it running, which is what looking at the
## fall on its own wants.
@export var stills_the_idle: bool = true
## Whether the director is told the encounter is over as the man goes down.
##
## On. It is what takes the mark off his head and the arrow off the HUD the instant he
## is beaten, rather than leaving either aimed at a corpse; see
## [method MiniBossDirector.close_encounter], which leaves the body itself alone.
@export var closes_the_encounter: bool = true
## How close the player has to stand to talk to the body, in pixels. Wider than an
## ordinary man's, because a boss is drawn up to two and a half times the size and the
## reach is measured from the middle of the sand he is lying on.
@export var corpse_reach: float = 230.0

@export_group("The camera")
## How close the view pulls in on the falling boss, as a multiple of the camera's
## authored zoom.
@export var focus_zoom: float = 2.5
## How hard the camera grabs him, in the usual exponential-smoothing units. Quick - the
## final hit should be answered immediately - but eased, not cut.
@export var focus_camera_speed: float = 3.4
## How quickly the view crosses in to [member focus_zoom].
@export var focus_zoom_speed: float = 2.8
## How quickly it crosses back out afterwards.
@export var return_zoom_speed: float = 2.0
## How long the camera is given to come home before the fixed screen is lifted, in
## seconds. The walls and the camera limits go at the end of it, so the view is already
## back on the player when the arena stops being an arena.
@export var return_seconds: float = 1.0

@export_group("The name")
## The card the name is shown on. [b]The introduction's own card[/b] - the same node
## [MiniBossDirector] puts his name up on when the player first reaches him - so the man
## is announced and crossed off in the same lettering, and nothing about how either
## looks is written in a script.
@export var title_path: NodePath = ^"../RunHUD/BossIntroTitle"
## The label inside it, relative to the card.
@export var title_label_path: NodePath = ^"Card/Name"
## The line drawn through that label, relative to the card. Optional - without one the
## name simply fades instead of being struck.
@export var strike_path: NodePath = ^"Card/Name/Strike"
## How long the card fades in and out over.
@export var title_fade_time: float = 0.5
## How long the name takes to appear, letter by letter, in seconds.
##
## This is "reveal the name slowly": the label's own
## [member Label.visible_ratio] is driven from nothing to whole, so the reveal costs no
## second copy of the text and no animation.
@export var name_reveal_time: float = 1.6
## How long after the boss has reached the ground the line is drawn, in seconds.
@export var strike_delay: float = 2.0
## How long the line takes to be drawn across, in seconds.
@export var strike_time: float = 0.45
## How long the struck-out name is left up afterwards, in seconds, before the card goes
## and the camera comes home.
@export var title_hold_after_strike: float = 0.6
## How far past the ends of the text the line reaches, in pixels.
@export var strike_overhang: float = 26.0

@export_group("The sound")
## The voices the defeat is announced through - a [SoundBank] of this node's own,
## so it cannot be cut off by anything the world is doing and cannot reach the
## music.
@export var sound_bank_path: NodePath = ^"SoundBank"
## What is played [b]the instant the line is drawn through the name[/b], and at no
## other moment: not on the killing hit, which is the fall rather than the ending,
## and not when the body on the ground is finished off later. It is the full stop
## on the sentence the card is writing, so it is fired from the same line the strike
## is - see [method _strike_the_name].
##
## Empty, or a name the bank has no stream for, simply plays nothing.
@export var strike_sound: StringName = &"defeat"
## Level it is played at against the rest of that bank, in decibels.
@export var strike_sound_volume_db: float = 0.0

@export_group("The support")
## Whether the men still standing are sent home as the boss goes down.
@export var support_escapes: bool = true
## Pause before the first of them turns, so the boss falling registers first.
@export var escape_lead_in: float = 0.1
## Gap between one man turning and the next.
@export var escape_stagger: float = 0.08
## Ceiling on the total spread, however many are left standing.
@export var escape_max_spread: float = 1.2

@export_group("The corpse")
## The pool the body is left with once the fall is over, in hit points.
##
## [b]Absolute rather than a share of the boss's own pool[/b], and small on purpose.
## Finishing a body on the ground is an execution, not a second fight - a share of a
## fifteen-thousand-point boss would be another fight - so this is a couple of shells'
## worth whichever rung the man was on.
@export var corpse_health: float = 150.0
## How much blood the body spills when it is finally shot.
##
## Thrown on the ground to be collected, exactly as any other kill's blood is - see
## [BloodSpray] - so it is worth what it says to the player and reads the same as
## everything else they have picked up all round.
@export var corpse_blood: int = 50
## The fewest pieces of knowledge the body hands over when the player presses E.
##
## [b]Never about the contract he was.[/b] His own is closed out the instant he goes
## down - see [method _pay_reward] - and [SurrenderKnowledge] only ever talks about
## contracts that are still outstanding, so the man cannot tell the player what they
## have just finished finding out. What he is worth is the [i]other[/i] posters in the
## player's hands: two or three lines filled in on outlaws still out there, which is
## what makes beating one of them a lead on the next.
@export var knowledge_pieces_min: int = 2
## The most he hands over. Rolled between the two as the body lands, so a boss is worth
## two or three pieces rather than always the same number - and written onto his own
## [member SurrenderKnowledge.pieces], which is what actually hands them over.
##
## Neither number can produce a repeat or overrun a contract however they are tuned:
## each piece is drawn from what is still unknown at the moment it is given, and a man
## with nothing left to say stops rather than inventing.
@export var knowledge_pieces_max: int = 3
## The X marks over the eyes, relative to the boss's own body. Put up when the corpse is
## shot, so a body that has been finished off reads as finished rather than as one still
## waiting to be.
@export var corpse_eyes_path: NodePath = ^"HeadAim/Head/DeadEyes"
## How strongly the shot corpse is washed in [member corpse_tint_color].
##
## It is [method MiniBoss.apply_tint] - the same shader channel the enrage uses, on the
## same per-character materials - so the boss keeps its red outline and needs no second
## material and no new artwork to look like a corpse.
@export_range(0.0, 1.0, 0.01) var corpse_tint_strength: float = 0.5
## What that wash is. A dark, drained red, so a finished body is visibly not the man who
## was walking at the player a moment ago.
@export var corpse_tint_color := Color(0.36, 0.03, 0.04, 1.0)
## Offset from the boss's origin, which sits at its feet, to where its blood comes out.
@export var corpse_blood_offset := Vector2(0.0, -40.0)

@export_group("Afterwards")
## Whether the camp is opened once the fixed screen is gone.
##
## [b]On, and it is what lets a boss day end at all.[/b] The way out of an ordinary round
## opens when the run's clock reaches its collection phase, and a boss day never starts
## that clock - so the encounter being over is what opens it instead, through the
## portal's own public [method ArenaPortal.open]. Nothing about the round's clock, its
## waves or the camp itself is changed.
@export var opens_camp: bool = true
## Group the camp is found in.
@export var camp_group: StringName = &"camp"
## The mark dropped onto the camp, which is also what the HUD's arrow points at while the
## camp is off screen. The travel system's own marker - see [DestinationMarker] - so the
## way home is shown by exactly the arrow that shows the way to everything else.
@export var camp_marker_scene: PackedScene
## Group that marker joins, which the HUD's camp arrow is pointed at.
@export var camp_marker_group: StringName = &"camp_marker"

var _director: MiniBossDirector
var _arena: BossArena
var _phases: BossPhases
var _boss: Node2D
var _boss_health: Health
var _stage: Stage = Stage.WAITING
var _title: Control
var _title_tween: Tween
var _strike_tween: Tween
## Hitbox layers as they were before the boss was made untouchable, so they can be put
## back exactly. Keyed by the region itself.
var _layers: Dictionary = {}
## Whether the pool is being written to from inside a [signal Health.health_changed]
## handler, so the write this node makes cannot be read as another lethal hit.
var _restoring: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var director := _resolve_director()
	if director != null and not director.fight_started.is_connected(_on_fight_started):
		director.fight_started.connect(_on_fight_started)


## The defeat system in this world, or null when it has none.
static func get_active(from_node: Node) -> BossDefeat:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BossDefeat


func get_stage() -> Stage:
	return _stage


## Whether the boss has been beaten - at any point from the last shot onwards.
func is_defeated() -> bool:
	return _stage == Stage.FALLING or _stage == Stage.DOWN or _stage == Stage.KILLED


## Whether the boss can be hurt right now. False during the fall, and false again for
## good once the body has been shot.
func is_vulnerable() -> bool:
	return _stage == Stage.FIGHTING or _stage == Stage.DOWN


## Whether the body has been finished off.
func is_corpse_killed() -> bool:
	return _stage == Stage.KILLED


# --- Arming ---------------------------------------------------------------------

## The fight has begun. From here the boss's own pool is what this node watches, and the
## only thing it is watching for is the pool reaching nothing.
func _on_fight_started() -> void:
	if _stage != Stage.WAITING:
		return

	var director := _resolve_director()
	if director == null:
		return

	_boss = director.get_boss()
	if _boss == null or not is_instance_valid(_boss):
		return

	_boss_health = _find_health(_boss)
	if _boss_health == null:
		return
	if not _boss_health.health_changed.is_connected(_on_boss_health_changed):
		_boss_health.health_changed.connect(_on_boss_health_changed)

	_stage = Stage.FIGHTING


## Disarms the ending and lets go of the boss it was watching, so a fresh encounter can
## arm it again.
##
## [b]Nothing in play calls it.[/b] One world holds one boss fight, and this node is
## armed once by [signal MiniBossDirector.fight_started] and then run to its end. It
## exists so a fight can be set up again without the world being rebuilt round it - the
## guard at the top of [method _on_fight_started] refuses a second arming, which is
## right for play and is exactly what has to be lifted for a second setup.
##
## The body it was watching is not touched. Taking a corpse away is the director's, in
## [method MiniBossDirector.reset_encounter]; all this forgets is the fight.
func reset() -> void:
	if _boss_health != null and is_instance_valid(_boss_health) \
			and _boss_health.health_changed.is_connected(_on_boss_health_changed):
		_boss_health.health_changed.disconnect(_on_boss_health_changed)

	_boss = null
	_boss_health = null
	# The layers belonged to hitboxes on a body this node is letting go of - keeping them
	# would mean the next boss's shield was lifted onto numbers taken off the last one.
	_layers.clear()
	_restoring = false
	_stage = Stage.WAITING
	_hide_name()


## Every change to the boss's pool, and the one place a lethal one is caught.
##
## [b]The pool is put back from inside the signal, and that is deliberate.[/b]
## [method Health.take_damage] announces the change, announces the hit, and only then
## looks at what is left to decide whether the character died - so a listener that
## refills the pool during the announcement is read by that final check as a character
## who is still standing, and no death is emitted. The killing hit still flashes, still
## throws its figure and still sounds like a hit; it simply is not fatal.
##
## It is done here rather than by making the boss unkillable because the boss has to be
## killable: the pool running out is exactly how the fight is won, and later how the body
## on the ground is finished off. What must not happen is the [i]engine[/i] treating
## either of those as a death.
func _on_boss_health_changed(current: float, _maximum: float) -> void:
	if _restoring or current > 0.0:
		return

	match _stage:
		Stage.FIGHTING:
			_begin_defeat()
		Stage.FALLING:
			# Nothing should be able to hit him at all here - his hitboxes are off the
			# layer - so this is only insurance against damage that never came through
			# one, and it costs the corpse nothing.
			_set_health(corpse_health)
		Stage.DOWN:
			_kill_the_corpse()
		_:
			pass


# --- The ending -----------------------------------------------------------------

## The last shot has landed. Everything that happens at that instant happens here, in
## this order, and the rest of the sequence is timed off it.
func _begin_defeat() -> void:
	_stage = Stage.FALLING

	# First, before anything else can look at the pool: the body is not dying today.
	_set_health(corpse_health)
	_shield(true)

	var bounty := _pay_reward()
	_extend_the_streak()
	_drop_the_boss()
	_stop_the_fight()
	# After the contract has been read and the fight wound up, because both of those
	# ask the director for what it is about to forget.
	_close_the_encounter()
	_focus_camera()
	_show_name()

	_after(maxf(invulnerable_seconds, 0.0), _lift_the_shield)
	_after(maxf(fall_time, 0.0), _announce_fallen)
	_after(maxf(fall_time, 0.0) + maxf(strike_delay, 0.0), _strike_the_name)

	boss_defeated.emit(bounty, 0 if bounty == null else bounty.reward)


## The contract's blood, paid straight into the player's hands, and the contract closed
## out behind it.
##
## [b]The reward is read and never written.[/b] What it pays was fixed when the poster
## came down; this only moves it. Returns the contract, so the caller can announce it
## without asking the ledger twice.
func _pay_reward() -> Bounty:
	var director := _resolve_director()
	if director == null:
		return null
	var bounty := director.get_bounty()
	if bounty == null:
		return null

	var amount := bounty.reward
	if grants_reward and amount > 0:
		var wallet := get_node_or_null(wallet_path) as BloodWallet
		if wallet != null:
			wallet.add(amount)
			reward_granted.emit(amount)

	if completes_contract:
		var ledger := get_node_or_null(ledger_path) as BountyLedger
		if ledger != null:
			ledger.complete(bounty.bounty_id)

	return bounty


## One more outlaw on the run's tally.
##
## It is the whole of what beating a boss does to the streak: the count goes up by one
## and nothing else in the world changes, because what a streak is worth is decided at
## the base and nowhere else.
func _extend_the_streak() -> void:
	if not extends_streak:
		return
	var streak := get_node_or_null(streak_path) as StreakCounter
	if streak != null:
		streak.add(1)


## How many lines this body is worth, rolled as it lands.
##
## Rolled once per boss rather than per press, because it is a property of the man:
## whatever comes up is what he knows, and the interaction hands over that much or as
## much of it as there is anything left to say.
func _roll_knowledge_pieces() -> int:
	var fewest := maxi(knowledge_pieces_min, 0)
	var most := maxi(knowledge_pieces_max, fewest)
	return randi_range(fewest, most)


## Puts the man on the ground, through his own give-up component.
##
## The fall's shape, its timing and how close the player has to stand are all written
## onto that component from this node's own inspector values first, so a boss goes down
## further and further over than a man who merely surrendered, and is reachable from
## further away because he is so much larger - without either of those being a second
## fall or a second interaction.
func _drop_the_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return

	var surrender := EnemySurrender.find_on(_boss)
	if surrender == null:
		push_warning("BossDefeat: the boss has no EnemySurrender - it cannot fall.")
		return

	surrender.fall_degrees = fall_degrees
	surrender.fall_time = maxf(fall_time, 0.0001)
	surrender.interaction_radius = maxf(corpse_reach, 1.0)

	var knowledge := _find_knowledge(_boss)
	if knowledge != null:
		knowledge.pieces = _roll_knowledge_pieces()

	# Forced, because this man never gives up of his own accord - see
	# [member EnemySurrender.gives_up_on_its_own]. It is also what takes him out of the
	# enemies group and out of the container the live ones are kept in, which is how the
	# arena reads as clear with his body still lying in it.
	surrender.surrender(true)
	_still_the_idle()


## Stops the beaten man breathing, for good.
##
## [b]A corpse that is still doing its idle is a corpse that is still alive.[/b] The
## squash-and-stretch every character in the game carries is deliberately relentless -
## it restarts itself the moment it is found stopped, which is exactly right for
## anything on its feet - so the only honest way to end it is to tell it to stop
## rather than to stop it; see [method SquashIdle.lie_still], which is what makes it
## permanent and what makes shooting the body afterwards unable to start it again.
##
## Nothing else about the ending is touched. The fall is a tween on the body's own
## rotation and the fade, the blood and the loot are all their own components, so a
## still idle is a still idle and nothing more.
func _still_the_idle() -> void:
	if not stills_the_idle or _boss == null or not is_instance_valid(_boss):
		return
	for node: Node in _boss.find_children("*", "SquashIdle", true, false):
		var idle := node as SquashIdle
		if idle != null:
			idle.lie_still()


## Lets the director go, so nothing is left aimed at a man who has been beaten.
##
## See [method MiniBossDirector.close_encounter]: the mark over his head and the arrow
## on the HUD come down together and the encounter is forgotten, while the body itself
## is left lying exactly where it fell - which is the whole of what this ending is for.
func _close_the_encounter() -> void:
	if not closes_the_encounter:
		return
	var director := _resolve_director()
	if director != null:
		director.close_encounter()


## The fight is over: nothing more is sent, and everybody still standing goes home.
##
## They run rather than die, through the [EnemyEscape] every enemy already carries, so a
## man the player never beat is not played out as though they had. The stagger is this
## node's own rather than [RunEndDefeat]'s, because the round's clock has not run out -
## it never started - and the two endings should be tunable apart.
func _stop_the_fight() -> void:
	var phases := _resolve_phases()
	if phases != null:
		phases.stop()

	if not support_escapes:
		return

	var crowd := get_tree().get_nodes_in_group(enemy_group)
	var gap := escape_stagger
	if escape_max_spread > 0.0 and crowd.size() > 1:
		gap = minf(escape_stagger, escape_max_spread / float(crowd.size() - 1))

	var told := 0
	for enemy: Node in crowd:
		if enemy == _boss:
			continue
		var escape := _find_escape(enemy)
		if escape == null or escape.is_escaping() or escape.is_cancelled():
			continue
		escape.escape(escape_lead_in + gap * float(told))
		told += 1


## The camera crosses onto the boss and pulls right in on him for the fall.
##
## The fixed screen is left exactly as it is. Its limits are a box the size of one screen
## at the fight's zoom, and the view at [member focus_zoom] is a good deal smaller than
## that box - so the camera has room to move inside it and centre on the man without the
## lock being touched or lifted early.
func _focus_camera() -> void:
	var camera := _resolve_camera()
	if camera == null or _boss == null or not is_instance_valid(_boss):
		return

	camera.zoom_multiplier_speed = maxf(focus_zoom_speed, 0.01)
	camera.set_zoom_multiplier(focus_zoom)
	camera.follow(_boss, maxf(focus_camera_speed, 0.01))


func _announce_fallen() -> void:
	boss_fallen.emit()


## The shield comes off and the body becomes an ordinary target again - which is what
## makes finishing it off possible at all.
func _lift_the_shield() -> void:
	if _stage != Stage.FALLING:
		return
	_stage = Stage.DOWN
	_shield(false)


# --- The name -------------------------------------------------------------------

## The name up on the introduction's own card, revealed letter by letter.
func _show_name() -> void:
	var card := _resolve_title()
	if card == null:
		return

	var label := card.get_node_or_null(title_label_path) as Label
	if label != null:
		var component := MiniBoss.find_on(_boss)
		if component != null:
			label.text = component.get_display_name()
		label.visible_ratio = 0.0

	var strike := card.get_node_or_null(strike_path) as Control
	if strike != null:
		strike.visible = false

	if _title_tween != null and _title_tween.is_running():
		_title_tween.kill()

	card.modulate.a = 0.0
	card.visible = true
	_title_tween = create_tween().set_parallel(true)
	_title_tween.tween_property(card, "modulate:a", 1.0, maxf(title_fade_time, 0.0001))
	if label != null:
		_title_tween.tween_property(
			label, "visible_ratio", 1.0, maxf(name_reveal_time, 0.0001))


## The line through the name: sized to the lettering, then drawn across it.
##
## It is measured off the label's own font rather than given a width in the inspector, so
## a short name and a long one are each struck through exactly and neither leaves the
## line hanging in the air beside the text. Grown from its left edge rather than faded
## in, because the brief asks for the name to be [i]struck[/i] - it is a hand drawing a
## line, and a line that appears all at once does not read as one.
func _strike_the_name() -> void:
	var card := _resolve_title()
	if card == null:
		return

	var strike := card.get_node_or_null(strike_path) as Control
	var label := card.get_node_or_null(title_label_path) as Label
	if strike == null or label == null:
		_after(maxf(title_hold_after_strike, 0.0), _let_the_arena_go)
		return

	var width := minf(_text_width(label) + maxf(strike_overhang, 0.0) * 2.0, label.size.x)
	strike.size.x = maxf(width, 1.0)
	strike.position = Vector2(
		(label.size.x - strike.size.x) * 0.5,
		label.size.y * 0.5 - strike.size.y * 0.5)
	# Turned about its left edge, so it is drawn from one end of the name to the other
	# rather than growing out of the middle.
	strike.pivot_offset = Vector2.ZERO
	strike.scale = Vector2(0.0, 1.0)
	strike.visible = true

	if _strike_tween != null and _strike_tween.is_running():
		_strike_tween.kill()
	_strike_tween = create_tween()
	_strike_tween.tween_property(strike, "scale", Vector2.ONE, maxf(strike_time, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_play_strike_sound()
	name_struck.emit()
	_after(maxf(strike_time, 0.0) + maxf(title_hold_after_strike, 0.0), _let_the_arena_go)


## The one sound this whole presentation makes, on the one frame the line starts
## being drawn.
func _play_strike_sound() -> void:
	if strike_sound == &"":
		return
	var bank := get_node_or_null(sound_bank_path) as SoundBank
	if bank != null:
		bank.play(strike_sound, strike_sound_volume_db)


## How wide the label's text actually is, in pixels.
##
## Asked of the font the label is drawing with rather than of the label, because a label
## in a container is as wide as the container and says nothing about its lettering. A
## card with no font resolved falls back to the label's own width, which strikes through
## the whole line - too long, but never nothing.
func _text_width(label: Label) -> float:
	var font := label.get_theme_font(&"font")
	if font == null:
		return label.size.x
	var size := label.get_theme_font_size(&"font_size")
	return font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, 1)).x


func _hide_name() -> void:
	var card := _resolve_title()
	if card == null:
		return

	if _title_tween != null and _title_tween.is_running():
		_title_tween.kill()
	_title_tween = create_tween()
	_title_tween.tween_property(card, "modulate:a", 0.0, maxf(title_fade_time, 0.0001))
	_title_tween.tween_callback(card.hide)


# --- Giving the arena back ------------------------------------------------------

## The name is crossed off. The card goes, the camera starts home, and the view is taken
## back out to the fight's own zoom on the way.
func _let_the_arena_go() -> void:
	_hide_name()

	var camera := _resolve_camera()
	var arena := _resolve_arena()
	if camera != null:
		camera.release_follow()
		camera.zoom_multiplier_speed = maxf(return_zoom_speed, 0.01)
		# Back out to the arena's own 0.6x first rather than straight to an ordinary
		# view, so the return is one move: the camera crosses to the player at the zoom
		# the whole fight was played at, and only then does the arena stop existing.
		camera.set_zoom_multiplier(1.0 if arena == null else arena.fight_zoom)

	_after(maxf(return_seconds, 0.0), _release_arena)


## The fixed screen is handed back: the camera limits restored, the walls dropped, the
## leftover crates cleared and the ordinary view returned - all of it
## [method BossArena.unlock]'s, which was written for exactly this moment.
func _release_arena() -> void:
	var arena := _resolve_arena()
	if arena != null:
		arena.unlock()
	else:
		var camera := _resolve_camera()
		if camera != null:
			camera.set_zoom_multiplier(1.0)

	_open_the_way_home()
	arena_released.emit()


## The camp, and the arrow that points at it.
func _open_the_way_home() -> void:
	if not opens_camp:
		return

	var camp := get_tree().get_first_node_in_group(camp_group) as Node2D
	if camp == null:
		return

	var portal := camp as ArenaPortal
	if portal != null:
		# Guarded by the portal itself, so a camp that had already opened for some other
		# reason is not opened twice.
		portal.open()

	_mark_the_camp(camp)


## Drops the travel system's own mark onto the camp, which is all the HUD's arrow needs:
## it follows [member camp_marker_group], the mark shows itself while the camp is on
## screen and the arrow points from off it, and neither of them had to be told that a
## boss fight just ended.
func _mark_the_camp(camp: Node2D) -> void:
	if camp_marker_scene == null or camp_marker_group == &"":
		return
	if DestinationMarker.get_in_group(self, camp_marker_group) != null:
		return

	var marker := camp_marker_scene.instantiate() as DestinationMarker
	if marker == null:
		push_warning("BossDefeat: camp marker scene is not a DestinationMarker.")
		return

	# Written before it enters the tree, because joining the group is the first thing it
	# does once inside.
	marker.group = camp_marker_group
	camp.add_child(marker)


# --- The corpse -----------------------------------------------------------------

## The body has been shot. It stays exactly where it is.
##
## [b]This is a kill that produces no death.[/b] The blood, the X marks and the drained
## colour are the parts of a death worth having here; the freezing, the fade and the
## freeing are not, because the player may still have to walk up to this body and press E
## - the brief asks for both orders to work. So each of the three is done directly, each
## through the system that already owns it, and [signal Health.died] is never reached.
func _kill_the_corpse() -> void:
	_stage = Stage.KILLED

	# A sliver rather than nothing, so no later listener can read the pool as a body that
	# has yet to finish dying. Nothing can reduce it again: the hitboxes are off for good
	# from here.
	_set_health(1.0)
	_shield(true)

	_show_dead_eyes()
	_drain_the_colour()
	var spilled := _spill_blood(corpse_blood)
	corpse_killed.emit(spilled)


func _show_dead_eyes() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var eyes := _boss.get_node_or_null(corpse_eyes_path) as CanvasItem
	if eyes != null:
		eyes.visible = true


func _drain_the_colour() -> void:
	var component := MiniBoss.find_on(_boss)
	if component != null:
		component.apply_tint(corpse_tint_strength, corpse_tint_color)


## The body's blood, thrown out of it and collected exactly as every other kill's is.
## Returns how much was spilled.
##
## It goes through [BloodSpray] rather than through the boss's own [BloodEmitter],
## because that component answers a death this body never has - see
## [method _kill_the_corpse]. What lands is the same permanent speck worth the same 1 to
## the wallet, so the player cannot tell the two paths apart, and a world with no spray
## in it stains the floor instead of losing the blood.
func _spill_blood(count: int) -> int:
	var wanted := maxi(count, 0)
	if wanted <= 0 or _boss == null or not is_instance_valid(_boss):
		return 0

	var at := _boss.global_position + corpse_blood_offset
	var away := _away_from_player(_boss.global_position)

	var spray := BloodSpray.get_active(self)
	if spray != null:
		spray.launch(at, wanted, away)
		return wanted

	var field := BloodField.get_active(self)
	if field == null:
		return 0
	field.add_splash(at, wanted, away)
	return wanted


## Which way the blood leaves: on out through the far side of the body, away from
## whoever was shooting at it.
func _away_from_player(at: Vector2) -> Vector2:
	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null:
		return Vector2.ZERO
	var away := at - player.global_position
	return Vector2.ZERO if away.is_zero_approx() else away.normalized()


# --- Being hurt, and not being hurt ---------------------------------------------

## Takes the boss's damageable regions off their layer, or puts them back.
##
## The layer is what a shot in the air runs into, so clearing it is what makes the boss
## untouchable - the same move [method EnemyEscape._leave_the_fight] makes for the same
## reason. What each region was on is written down rather than assumed, so putting it
## back cannot quietly change what the boss was.
func _shield(on: bool) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return

	for node: Node in _boss.find_children("*", "Hitbox", true, false):
		var region := node as Area2D
		if region == null:
			continue
		if on:
			if not _layers.has(region):
				_layers[region] = region.collision_layer
			region.collision_layer = 0
			continue
		region.collision_layer = int(_layers.get(region, 2))


## The one place the boss's pool is written, with the guard that stops the write being
## mistaken for another lethal hit when it comes back round through
## [signal Health.health_changed].
func _set_health(value: float) -> void:
	if _boss_health == null or not is_instance_valid(_boss_health):
		return
	_restoring = true
	_boss_health.set_current(value)
	_restoring = false


# --- Looking things up ---------------------------------------------------------

## A step of the sequence, run on a scene timer rather than counted in
## [method Node._process], so this node has nothing to run between encounters.
##
## The timers ignore the world's time scale for the same reason the introduction's does:
## the ending is meant to take the same few seconds of the player's time whatever the
## arena around it is doing.
func _after(seconds: float, step: Callable) -> void:
	if seconds <= 0.0:
		step.call()
		return
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(step, CONNECT_ONE_SHOT)


func _resolve_director() -> MiniBossDirector:
	if _director == null or not is_instance_valid(_director):
		var named := get_node_or_null(director_path) as MiniBossDirector
		_director = named if named != null else MiniBossDirector.get_active(self)
	return _director


func _resolve_arena() -> BossArena:
	if _arena == null or not is_instance_valid(_arena):
		var named := get_node_or_null(arena_path) as BossArena
		_arena = named if named != null else BossArena.get_active(self)
	return _arena


func _resolve_phases() -> BossPhases:
	if _phases == null or not is_instance_valid(_phases):
		var named := get_node_or_null(phases_path) as BossPhases
		_phases = named if named != null else BossPhases.get_active(self)
	return _phases


func _resolve_camera() -> CameraController:
	return CameraController.get_active(self)


func _resolve_title() -> Control:
	if _title == null or not is_instance_valid(_title):
		_title = get_node_or_null(title_path) as Control
	return _title


func _find_health(body: Node) -> Health:
	if body == null:
		return null
	for node: Node in body.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


func _find_knowledge(body: Node) -> SurrenderKnowledge:
	if body == null:
		return null
	for node: Node in body.find_children("*", "SurrenderKnowledge", true, false):
		var knowledge := node as SurrenderKnowledge
		if knowledge != null:
			return knowledge
	return null


func _find_escape(enemy: Node) -> EnemyEscape:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "EnemyEscape", true, false):
		var escape := node as EnemyEscape
		if escape != null:
			return escape
	return null
