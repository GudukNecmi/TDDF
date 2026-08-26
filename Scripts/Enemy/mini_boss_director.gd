class_name MiniBossDirector
extends Node
## The man on the poster, and everything between the player finding out he is here
## and the fight starting.
##
## [b]Being in the right place at the right time is what summons him, and it is not
## the same thing as fighting him.[/b] A contract the player is holding says which
## map, which region and which hour - as much of that as they have actually found
## out - and when all three of those match where and when the run currently is, the
## boss is somewhere in this region. That is a discovery, not an encounter: the
## player is told he is nearby and then left to play, and the fight only begins when
## they have walked to him. Riding into the right region can never drop a boss fight
## on somebody who has not gone looking for it.
##
## The whole flow, and each step's owner:
##
##   [codeblock]
##   map+region+time match -> "HE IS NEARBY" -> arrow -> walked to -> carried away -> intro -> fight
##          this file          KnowledgeNotice  DestinationArrow  this file  BossEncounterMap  BossArena  this file
##   [/codeblock]
##
## [b]The fight is not held where the man is found.[/b] He waits in the region, the
## arrow points at him and the player walks to him there - but reaching him carries the
## whole encounter onto a map of its own; see [BossEncounterMap], which is a scene the
## bounty fight can be decorated in without the desert being touched. Nothing about the
## boss, the group, the rung, the contract or the reward is decided by that move, and a
## world without such a map fights him exactly where he stood.
##
## [b]It takes the round over, exactly as an arrival does.[/b] On a day the boss is
## found there is no wave and no arrival ambush - see
## [method WorldBoot._boss_takes_the_round] - because the encounter [i]is[/i] the
## round. The clock is never started, so nothing is on a timer and nothing arrives on
## its own; the only things in the arena are the ones put there below.
##
## [b]Nothing about an enemy is written here.[/b] The boss and its support group are
## the game's ordinary [code]Enemy.tscn[/code], built by the world's own
## [EnemySpawner] - which hands each one its chase target and the round's difficulty
## on the way in - so a boss fight is fought against ordinary enemies with ordinary
## AI, and there is no boss scene, no boss AI and no second difficulty curve. What
## makes one of them the boss is [MiniBoss] (a name and a red outline),
## [MiniBossTier] (how large, how tough) and [MiniBossAppearance] (whose head, body
## and weapon he is wearing), and all three are dropped onto an instance the spawner
## already built. The last of those is artwork only - see [method _dress_boss] - so a
## dressed boss still walks, aims, swings and goes down through the enemy's own
## components.
##
## [b]And it never touches the money.[/b] Difficulty is read from how much the
## contract knew when it was accepted - see [method get_accepted_knowledge] - and the
## reward is not consulted, not recalculated and not written. A contract taken blind
## produces the hardest boss and pays exactly what it locked in;
## [method Bounty.set_reward] would refuse anything else anyway, which is the point of
## reading rather than writing here.

## Emitted when the boss turns out to be in this region, with the contract and the
## name off its poster. The notice on the HUD is one listener; a sound is another.
signal boss_discovered(bounty: Bounty, display_name: String)
## Emitted once the boss and its support group are standing in the arena, with how
## many bodies that came to in total.
signal boss_placed(enemy_count: int)
## Emitted as the player reaches the boss and the introduction begins.
signal approach_completed
## Emitted the moment the fight actually starts - the introduction over, the arena
## locked and everybody released.
signal fight_started

## Group this node joins, so [WorldBoot] and a test can find it without a path.
const GROUP := &"mini_boss_director"

## Where the encounter has got to. Deliberately one flag's worth of state per step
## rather than a state machine object: each step is entered once, in order, and the
## only thing any of them is asked is which one is current.
enum Phase {
	## No boss in this region, or none looked for yet. Every ordinary round.
	NONE,
	## He is here and the player has been told. They are walking.
	APPROACHING,
	## The player reached him and the camera has him.
	INTRO,
	## The fight.
	FIGHTING,
}

## The run's own state, asked where and when this is - [method RunSessionState.get_map_id],
## [method RunSessionState.get_region_id] and [method RunSessionState.get_time_id].
@export var session_path: NodePath = ^"/root/RunSession"
## The ledger every contract lives in. A world without it simply never finds a boss.
@export var ledger_path: NodePath = ^"/root/Bounties"
## The world's own spawner, which builds the boss and every man standing with it.
## [b]There is no boss enemy[/b] - it is the game's ordinary enemy, made by the thing
## that already makes them.
@export var spawner_path: NodePath = ^"../EnemySpawner"
## The fixed-screen arena: the introduction's camera move and the lock that follows
## it. Left unresolved the fight still happens, in the open arena with a free camera,
## so a world without one is playable rather than broken.
@export var arena_path: NodePath = ^"../BossArena"
## The ground the fight is actually held on - see [BossEncounterMap]. The encounter is
## carried into it the moment the player reaches the man, and carried back out when the
## ending hands the world back.
##
## Left unresolved, or switched off on the map itself, the fight is held where he was
## found - which is exactly what a boss day was before there was a map for it - so a
## world without one is playable rather than broken.
@export var encounter_map_path: NodePath = ^"../BossEncounterMap"
## Group the player is found in, so this node is not wired to them.
@export var player_group: StringName = &"player"

@export_group("When he is here")
## Which pieces of the contract have to be both known and correct before the boss is
## in this region. All three by default, which is the rule as written: a contract
## missing any of them does not summon anybody.
##
## [b]Taking one out is how the requirement is relaxed[/b] - a game that wanted map
## and region to be enough drops the time entry here rather than editing this file.
## Adding a fourth needs more than an entry, though, and deliberately: a category can
## only be checked against something the run can be [i]asked[/i], and
## [method get_situation_value] is the list of questions [RunSessionState] can
## currently answer. A new kind of knowledge means a new question, not a new row.
@export var required_categories: Array[StringName] = [
	Bounty.CATEGORY_MAP,
	Bounty.CATEGORY_REGION,
	Bounty.CATEGORY_TIME,
]
## Whether a boss is looked for at all. Off leaves every round an ordinary round,
## for looking at a map without one turning up.
@export var enabled: bool = true

@export_group("Difficulty")
## The rungs, one per knowledge count. Looked up by
## [method get_accepted_knowledge]; a count with no rung authored produces no boss at
## all rather than a guess, so an incomplete table fails visibly instead of quietly
## spawning something arbitrary.
@export var tiers: Array[MiniBossTier] = []

@export_group("How much health he has")
## What the boss is worth against what he is made of: blood on the left, the
## multiple of an ordinary enemy's authored pool on the right, read in order and
## interpolated between.
##
## [b]The price on the poster is the difficulty.[/b] A contract that pays double is
## a man with double the reason to be feared, so nothing else has to be authored to
## keep the two in step and a retune of the economy retunes the fights with it. The
## player can read how hard a hunt will be off the board before taking it, which is
## the point.
##
## An array of points rather than a formula or a ladder of rungs, so bending the
## curve - or extending it past 2000 the day the desert stops being the whole game -
## is dragging a number in the inspector. Rewards below the first point and above
## the last are held to its multiplier rather than extrapolated, so the two ends of
## the curve are also the two ends of the range.
@export var boss_health_curve: Array[Vector2] = [
	Vector2(500.0, 50.0),
	Vector2(750.0, 60.0),
	Vector2(1000.0, 75.0),
	Vector2(1250.0, 90.0),
	Vector2(1500.0, 105.0),
	Vector2(1750.0, 125.0),
	Vector2(2000.0, 150.0),
]
## How much tougher the boss gets per level the player has gained, as a fraction.
## 0.05 is "five percent a level", so level 1 is the curve exactly and level 5 is a
## fifth again.
##
## [b]Mild on purpose.[/b] The reward is what decides the fight; this only keeps a
## cheap contract from becoming trivial to a player who has grown. Set to 0 the
## player's level stops mattering and the curve above is the whole of it.
@export var boss_health_per_level: float = 0.05
## The most an ordinary enemy's pool can ever be multiplied by, however rich the
## contract and however far the player has come. The top of the curve, restated as a
## ceiling so the level multiplier cannot carry a boss past it.
@export var boss_health_cap: float = 150.0
## The persistent counter the player's level is read from - the
## [code]RunProgress[/code] autoload. Left unresolved every boss is fought at level
## 1, which is what a world opened on its own plays at.
@export var progress_path: NodePath = ^"/root/RunProgress"

@export_group("Difficulty")
## What the boss's walk is multiplied by, for the rungs that do not override it.
## Above 1 is faster than an ordinary Enemy1, which is the whole of "faster than a
## normal enemy" - the base speed itself stays on the enemy scene where every other
## enemy reads it.
@export var boss_speed_multiplier: float = 1.35
## What one connecting swing of the boss costs the player, in hearts.
##
## It is a flat value rather than a multiplier because the brief states it as one -
## two hearts a hit, whatever rung the boss is on - and because the player's hearts
## are whole numbers. The round's damage curve has already been applied to the
## instance by the spawner, so this deliberately overwrites it: a boss hits for two
## hearts in round one and in round twenty.
@export var boss_contact_damage: float = 2.0
## What the boss's weapon is drawn at, as a multiple of the scale it already has.
##
## [b]A multiplier rather than a size[/b], and deliberately: the blade the boss is
## carrying may be the enemy scene's own or one out of the wardrobe, drawn at whatever
## scale that set authors - see [member MiniBossWardrobe.weapon_scale_multiplier] - so
## the only figure that means the same thing for every outlaw is how much larger his is
## than it would otherwise have been. The whole man is already scaled by his rung, so
## this is on top of that too: it is the weapon looking oversized in his hand, not the
## weapon looking the right size on a large man.
@export var boss_weapon_scale_multiplier: float = 1.2
## The weapon sprite it is applied to, relative to the boss. The same blade
## [member MiniBossAppearance.weapon_path] dresses, so a wardrobe and this agree on
## which sprite the weapon is.
@export var boss_weapon_path: NodePath = ^"KnifeAim/KnifeHand/Knife"

@export_group("The support group")
## How many ordinary enemies stand with the boss, for the rungs that do not override
## it.
@export var support_count: int = 5
## What their health pools are multiplied by. Above 1 is the "more HP than normal"
## the brief asks for, laid over the round's own curve rather than replacing it.
@export var support_health_multiplier: float = 2.0
## How far out from the boss they stand, in pixels, as a range rolled between - so
## the group is a loose ring round him rather than a circle drawn on the ground.
@export var support_ring := Vector2(150.0, 340.0)

@export_group("Where he waits")
## How far from the player the boss waits, as a fraction of the playable area's
## shorter side, rolled between the two.
##
## [b]A fraction rather than a distance in pixels[/b], because how far away "far away"
## is depends on the map. It used to be a flat 1400-2200 px, which was a walk across
## the arena those numbers were written for and is further than the whole of a smaller
## one - and a distance the area cannot offer is not refused, it is quietly clamped, so
## every roll ended in whichever corner the bearing pointed at. Measured against the
## shorter side so the roll means the same thing on a wide map as on a square one, and
## so even the far end of the range is a distance the area can actually deliver.
##
## [b]Nearby, and deliberately.[/b] The brief asks for the boss to be within the
## current region rather than far away: far enough that the arrow has something to do
## and the player has to go and find him, close enough that finding him is a walk.
@export var boss_distance_fraction := Vector2(0.35, 0.62)
## How many directions are tried before the roomiest is accepted. Only matters near
## an edge, where most bearings would put him outside the map.
@export var placement_attempts: int = 12

@export_group("Standing room")
## How far a body reaches from its own origin, in pixels, at the size the enemy scene
## is authored at.
##
## [b]It is what "fully inside the arena" is measured with.[/b] A position is only far
## enough off a wall if the body standing there is - so this is added to
## [member wall_clearance] before anybody is placed, and for the boss it is first
## multiplied by the size his rung is built at, which is the whole of "his full scaled
## body is clear of the wall" and the reason a 2.5x boss is held further out than a
## 1.5x one without a second number being authored for him.
@export var body_radius: float = 90.0
## Clear ground left between a body and the wall it is nearest, in pixels, on top of
## that body's own reach. Room to be knocked back into rather than a hair's breadth.
@export var wall_clearance: float = 60.0

@export_group("Reaching him")
## How close the player has to get before the introduction starts, in pixels.
##
## [b]It is the reach of the encounter, and nothing else.[/b] It does not touch the boss,
## how far he can swing, how large he is built or how big the fight's own ground is - it
## is only the circle round him that answers "the player has arrived". Two and a half
## times what it was, because a mark on a man standing in open desert was being walked
## straight past: the player could be on top of him before the circle caught them.
@export var trigger_radius: float = 750.0
## The marker dropped onto the boss - the bobbing X, and the one answer to whether
## he is on screen yet. The [DestinationArrow] on the HUD is pointed at the group on
## that scene's root; see [DestinationMarker].
@export var marker_scene: PackedScene

@export_group("Telling the player")
## The HUD's notice panel, which is what says he is nearby. Any node with a
## [code]show_message()[/code] works; left unresolved the boss still appears and the
## arrow still points, the player is simply not told in words.
@export var notice_path: NodePath = ^"../RunHUD/KnowledgeNotice"
## What the notice says. [code]{who}[/code] is the name off the poster.
@export var nearby_message: String = "{who} IS NEARBY."
## The card the name is shown on during the introduction. Shown and hidden by this
## node; everything about how it looks is on that node in the inspector.
@export var title_path: NodePath = ^"../RunHUD/BossIntroTitle"
## The label inside it, relative to the card.
@export var title_label_path: NodePath = ^"Card/Name"
## How long the card fades in and out over.
@export var title_fade_time: float = 0.4
## Whether the card comes down when the fight starts. Off leaves it up, for a
## screenshot.
@export var title_hides_on_fight: bool = true

@export_group("What he looks like")
## The parts a mini boss is dressed out of - see [MiniBossWardrobe].
##
## [b]It is the whole of "a mini boss does not look like an Enemy1".[/b] Left unset,
## the boss is built and fought exactly as before and simply wears the enemy scene's
## own artwork, so a world with no wardrobe authored is playable rather than broken.
##
## Which parts a given outlaw wears is not decided here and is not rolled per spawn:
## it is derived from his identity by the wardrobe itself, so the same contract
## always produces the same man. See [method look_key_for].
##
## It is also what the wanted board prints from - see [WantedPoster] - so the face on
## the poster and the man who walks out of the region are one set of parts, not two.
@export var wardrobe: MiniBossWardrobe

var _session: Node
var _phase: Phase = Phase.NONE
## The contract this encounter answers, held from the moment it is found so the same
## one is used throughout - the ledger is asked once rather than searched again at
## each step.
var _bounty: Bounty
var _tier: MiniBossTier
var _boss: Node2D
var _boss_component: MiniBoss
var _marker: DestinationMarker
## The support group, kept so it can be released in one pass. Bodies that have since
## died are skipped rather than removed, because a fight this short cannot accumulate
## enough of them to be worth tidying.
var _support: Array[Node2D] = []
var _player: Node2D
var _title: Control
var _title_tween: Tween


func _enter_tree() -> void:
	add_to_group(GROUP)
	_session = get_node_or_null(session_path)


func _ready() -> void:
	# Nothing to run until there is somebody to walk towards.
	set_process(false)


## The boss system in this world, or null when it has none - which [WorldBoot] reads
## as "there is no boss here" and starts an ordinary round.
static func get_active(from_node: Node) -> MiniBossDirector:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as MiniBossDirector


func get_phase() -> Phase:
	return _phase


## Whether a boss encounter has taken this round over - in any of its steps, from the
## player walking towards him to the fight itself.
func is_active() -> bool:
	return _phase != Phase.NONE


## The contract being hunted, or null when there is no boss in this region.
func get_bounty() -> Bounty:
	return _bounty


## The body, or null before it has been built.
func get_boss() -> Node2D:
	return _boss


## Adds [param enemy] to the support group this encounter is keeping track of.
##
## [b]Reinforcements are the same group as the men who were already standing there.[/b]
## [BossPhases] puts more of them in as the boss is worn down, and they come through
## here so that everything reading the support - a readout, a test, whatever ends the
## fight in a later milestone - sees one group rather than having to know that some of
## it arrived late.
func register_support(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy) or _support.has(enemy):
		return
	_support.append(enemy)


## How many of the support group are still standing. For a readout or a test; nothing
## in this milestone ends on it, because what a dead boss is worth is a later one.
func get_support_alive() -> int:
	prune_support()
	return _support.size()


## Drops the men who have already been killed out of the list.
##
## [b]A freed body cannot be read out of a typed array at all[/b], which is why this
## exists and why every pass over the support group goes through it first. Taking a
## [code]Node2D[/code] out of an [code]Array[Node2D][/code] whose object has since been
## freed fails the type check rather than coming back null - so a loop that merely
## tested [method @GlobalScope.is_instance_valid] inside its body never got as far as
## the test, and the error it raised abandoned whatever function it was in.
##
## That is not hypothetical: the support group stands round the boss while the player is
## still walking towards him, in plain sight and killable, so anybody who shoots one on
## the way in leaves a freed entry behind. It used to abandon [method _begin_fight]
## halfway - after the phase had been set and before [signal fight_started] was
## emitted - which armed neither [BossPhases] nor [BossDefeat] and left a boss who could
## not be beaten.
##
## Read by index on purpose, because indexing is the one way to reach an element without
## assigning it to a typed name first.
func prune_support() -> void:
	var standing: Array[Node2D] = []
	for index: int in range(_support.size()):
		if is_instance_valid(_support[index]):
			standing.append(_support[index])
	_support = standing


# --- Is he here? ---------------------------------------------------------------

## The contract whose known map, region and hour all match where and when this run
## currently is, or null when there is none.
##
## [b]Only contracts the player is actually holding are candidates[/b] - taken, and
## not yet closed out - and every required line has to be [i]known[/i] as well as
## correct. A contract whose region happens to be this one but who the player has
## learned nothing about is not a boss: the outlaw is out there either way, and
## walking into him by accident is not what this is for.
##
## The first match wins. Holding two contracts pointing at the same place and hour is
## rare enough not to be worth an order, and picking either of them is right.
func find_contract() -> Bounty:
	if not enabled:
		return null

	var ledger := _get_ledger()
	if ledger == null:
		return null

	for bounty: Bounty in ledger.get_outstanding():
		if matches_situation(bounty):
			return bounty
	return null


## Whether [param bounty] points at exactly where and when the run is.
func matches_situation(bounty: Bounty) -> bool:
	if bounty == null or not bounty.is_outstanding():
		return false
	if required_categories.is_empty():
		return false

	for category: StringName in required_categories:
		if not bounty.is_known(category):
			return false
		var wanted := get_situation_value(category)
		# An unanswerable question is not a match. A run with no map chosen, or a
		# category the session cannot be asked about, must not read as "the poster
		# and the world agree" just because both came back empty.
		if wanted == &"":
			return false
		if bounty.get_fact_value(category) != wanted:
			return false
	return true


## What the run's answer to [param category_id] is right now: which map, which part
## of it, which hour.
##
## [b]This is the list of questions the run can be asked[/b], and the reason
## [member required_categories] can lose an entry but not gain one. All three come
## from [RunSessionState], which is the single place where and when a run is happening
## is answered - the hour in particular is read off [DayClock] through it, so the boss
## is compared against the same number the world's darkness and the HUD's icon are
## drawn from and the three cannot disagree.
func get_situation_value(category_id: StringName) -> StringName:
	if _session == null:
		return &""

	match category_id:
		Bounty.CATEGORY_MAP:
			return _ask_session(&"get_map_id")
		Bounty.CATEGORY_REGION:
			return _ask_session(&"get_region_id")
		Bounty.CATEGORY_TIME:
			return _ask_session(&"get_time_id")
		_:
			return &""


## How much [param bounty] knew when it was accepted, which is what the rung is
## chosen by.
##
## [b]It is the remembered number, not the live count.[/b]
## [member Bounty.generated_knowledge] is written when the poster is dealt and never
## again, so it cannot move after the contract is taken - which is exactly the
## property the difficulty rule needs. Reading the live count instead would mean a
## piece of information learned mid-run silently weakened a boss the player was
## already walking towards, and would make the difficulty of one fight depend on when
## during it the player happened to talk to somebody.
func get_accepted_knowledge(bounty: Bounty) -> int:
	return 0 if bounty == null else bounty.get_generated_knowledge()


## The rung for [param known] pieces of knowledge, or null when the table has none.
##
## Null is not an error and is not substituted for: a knowledge count with no rung
## authored produces no boss, so an incomplete table shows up as a boss that never
## appears rather than as one whose size came from nowhere.
func find_tier(known: int) -> MiniBossTier:
	for tier: MiniBossTier in tiers:
		if tier != null and tier.matches(known):
			return tier
	return null


# --- How much health he has -----------------------------------------------------

## What [param reward] blood is worth as a multiple of an ordinary enemy's pool,
## read off [member boss_health_curve] and interpolated between its points.
##
## A curve with no points at all answers 1, which is a boss with an ordinary enemy's
## health - visibly wrong rather than arbitrarily hard, so an emptied inspector array
## shows up as a boss that dies in a shot instead of one whose numbers came from
## nowhere.
func get_reward_health_multiplier(reward: int) -> float:
	var points: Array[Vector2] = []
	for point: Vector2 in boss_health_curve:
		points.append(point)
	if points.is_empty():
		return 1.0

	var blood := float(reward)
	if blood <= points[0].x:
		return maxf(points[0].y, 0.01)

	for index: int in range(1, points.size()):
		var previous := points[index - 1]
		var current := points[index]
		if blood > current.x:
			continue
		var span := current.x - previous.x
		# Two points at the same price is a step rather than a division by zero.
		var along := 1.0 if span <= 0.0 else (blood - previous.x) / span
		return maxf(lerpf(previous.y, current.y, along), 0.01)

	return maxf(points[points.size() - 1].y, 0.01)


## What the player having grown multiplies the boss by:
## [code]1 + (level - 1) x boss_health_per_level[/code]. 1 at level 1, which is what
## the game plays at until there is a progression system to move it.
func get_level_health_multiplier() -> float:
	var progress := get_node_or_null(progress_path) as RoundCounter
	var level := 1 if progress == null else progress.get_player_level()
	return 1.0 + float(maxi(level, 1) - 1) * maxf(boss_health_per_level, 0.0)


## The whole of the boss's health, as a multiple of the pool the enemy scene was
## authored with: what the contract pays, multiplied by how far the player has come,
## held to [member boss_health_cap].
##
## [b]The cap is the promise.[/b] However rich a contract and however high a level,
## a mini boss is never worth more than the top of the curve - so the hardest fight
## in the desert stays a fight the game was tuned for.
func get_boss_health_multiplier(bounty: Bounty) -> float:
	if bounty == null:
		return 1.0
	var multiplier := get_reward_health_multiplier(bounty.reward) * get_level_health_multiplier()
	return clampf(multiplier, 0.01, maxf(boss_health_cap, 0.01))


# --- Putting him there ---------------------------------------------------------

## Whether a boss could be found and placed at all, asked before anything is built.
##
## Used by [WorldBoot] to decide whether this round is a boss round. It commits to
## nothing: the contract, the rung and the spawner are all checked, so a round that
## answers false here is started as an ordinary round with nothing to undo.
func can_begin() -> bool:
	if _phase != Phase.NONE or not enabled:
		return false
	var bounty := find_contract()
	if bounty == null:
		return false
	if find_tier(get_accepted_knowledge(bounty)) == null:
		push_warning("MiniBossDirector: no tier authored for knowledge %d - no boss."
			% get_accepted_knowledge(bounty))
		return false
	return _resolve_spawner() != null


## Finds the boss, tells the player, and stands him and his men in the region.
## Reports how many bodies that came to; [b]0 means nothing happened and nothing was
## changed[/b], which the caller reads as "this is an ordinary round".
##
## The introduction is not played here and neither is the fight started. All this
## does is put him on the map and point the arrow at him - the player has to walk
## there, which is the whole distinction between a boss being available and a boss
## being fought.
func begin() -> int:
	if _phase != Phase.NONE or not enabled:
		return 0

	var bounty := find_contract()
	if bounty == null:
		return 0

	var known := get_accepted_knowledge(bounty)
	var tier := find_tier(known)
	if tier == null:
		push_warning("MiniBossDirector: no tier authored for knowledge %d - no boss." % known)
		return 0

	var spawner := _resolve_spawner()
	if spawner == null:
		push_warning("MiniBossDirector: no spawner to build a boss with.")
		return 0

	# The spawner's own spacing memory is dropped, so this group is measured against
	# itself rather than against a fight in the world the player rode out of.
	spawner.begin_batch()

	var point := _pick_boss_position(spawner, tier)
	var boss := _build_boss(spawner, point, tier, bounty, known)
	if boss == null:
		return 0

	_bounty = bounty
	_tier = tier
	_boss = boss
	var wanted := tier.support_count if tier.support_count >= 0 else support_count
	var placed := 1 + _build_support(spawner, point, wanted)

	_attach_marker(boss)
	_announce(bounty)

	_phase = Phase.APPROACHING
	set_process(true)

	boss_placed.emit(placed)
	return placed


## Takes the encounter off the map: the boss, the men standing with him and the mark
## over his head are freed, and the director goes back to having found nobody - so
## [method begin] can be asked for a fresh one.
##
## [b]Nothing in play calls it.[/b] An encounter ends with a body lying in the sand and
## the way home opening, and that ending is [BossDefeat]'s. This exists so the same
## fight can be set up again without the world being rebuilt around it, which is what
## the developer panel's SPAWN / RESET does. It is deliberately a full teardown rather
## than a rewind: the boss is a spawned body, so the only honest way back to "there is
## no boss here" is to take it away.
##
## It does not stop [BossPhases] or disarm [BossDefeat] - each of those owns its own
## way back, and reaching into them from here would put the knowledge of how a fight is
## wound up in two places. A caller putting a fresh encounter up asks all three.
func reset_encounter() -> void:
	# The player comes home first, while there is still an encounter to come home from -
	# a teardown that left them standing on the bounty's own ground would strand them
	# there with nothing to fight and no way back.
	var map := _resolve_encounter_map()
	if map != null:
		map.leave()

	prune_support()
	for enemy: Node2D in _support:
		enemy.queue_free()
	_support.clear()

	# The mark and the appearance are children of the body, so they go with it.
	if _boss != null and is_instance_valid(_boss):
		_boss.queue_free()
	_boss = null
	_boss_component = null
	_marker = null
	_bounty = null
	_tier = null

	_hide_title()
	_phase = Phase.NONE
	set_process(false)


## Lets go of an encounter that is over, leaving the body exactly where it fell.
##
## [b]This is the other half of [method reset_encounter], and the two are not the
## same thing.[/b] A reset takes the fight off the map so another can be put up in its
## place, which means freeing the man. A close is the fight having been [i]won[/i]:
## the corpse is the whole point of the ending - it can be walked up to, spoken to and
## shot; see [BossDefeat] - so the body, the mark's own parent, is the one thing here
## that is not touched.
##
## What it does end is this director's hold on him. The mark comes down and leaves its
## group on the same call, so the X over his head and the arrow on the HUD go together
## and neither can be left pointing at a dead man - both are the marker's doing, which
## is why there is one call rather than two; see
## [method DestinationMarker.remove_marker]. The contract, the tier and the boss are
## then forgotten, which is what puts [method is_active] back to false, so a player who
## dies afterwards is not carried home from a fight that is already over and a later
## day can find a fresh contract.
##
## The title card is deliberately left alone: [BossDefeat] is showing the beaten man's
## name on that same card as this is called, and hiding it here would take the ending's
## own announcement off the screen halfway through.
func close_encounter() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.remove_marker()
	_marker = null

	# Forgotten rather than freed. Whoever is still standing has been sent home by
	# [method BossDefeat._stop_the_fight] and runs off under their own [EnemyEscape];
	# they are simply no longer an encounter's men, so the next one starts counting
	# from nobody.
	_support.clear()
	_boss = null
	_boss_component = null
	_bounty = null
	_tier = null
	_phase = Phase.NONE
	set_process(false)


## Where he waits: out at [member boss_distance_fraction] of the playable area from the
## player on some bearing, and always far enough inside it that the whole of his scaled
## body stands clear of the walls.
##
## [b]The playable area is the map's own, and it is asked for rather than assumed.[/b]
## [member EnemySpawner.arena_bounds] is the walls' inner faces - the same rectangle
## every other thing that puts a body down is held inside - so a map whose walls are
## moved takes the boss with it and there is no second idea of how big the arena is to
## drift out of step with the first.
##
## Several bearings are tried and the one needing the least clamping wins, because near
## an edge most directions would drag him back towards the player.
func _pick_boss_position(spawner: EnemySpawner, tier: MiniBossTier) -> Vector2:
	var origin := _player_position()
	var area := spawner.arena_bounds
	var room := _standing_room(area, _boss_clearance(tier))

	var span := minf(absf(area.size.x), absf(area.size.y))
	var low := span * minf(boss_distance_fraction.x, boss_distance_fraction.y)
	var high := span * maxf(boss_distance_fraction.x, boss_distance_fraction.y)

	# Started at the middle of the room rather than at the player, so the fallback below
	# is somewhere he can legally stand even if every bearing is refused.
	var best := room.get_center()
	var best_distance := origin.distance_to(best)
	for attempt: int in range(maxi(placement_attempts, 1)):
		var wanted := randf_range(low, high)
		var heading := Vector2.RIGHT.rotated(randf() * TAU)
		var point := (origin + heading * wanted).clamp(room.position, room.end)
		# Ranked on how far away he actually ended up once the map had its say, so a
		# player standing in a corner still gets a walk rather than a boss at their feet.
		var reached := origin.distance_to(point)
		if reached >= low:
			return point
		if reached > best_distance:
			best_distance = reached
			best = point

	return best


## The part of [param area] a body reaching [param clearance] from its origin can stand
## in with the whole of itself inside.
##
## [b]It collapses to the middle rather than to the whole area.[/b] An area with less
## room in it than the body needs used to fall back to the area itself, which is how a
## clearance meant to hold the boss well inside the walls turned into no clearance at
## all the moment the map was made smaller than it - and put him on the boundary line
## instead. A rectangle of no size at the centre is still something a point can be
## clamped against, and clamping to it can only ever produce the middle of the arena,
## which is the one place that is certainly not a wall.
func _standing_room(area: Rect2, clearance: float) -> Rect2:
	var room := area.grow(-maxf(clearance, 0.0))
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return Rect2(area.get_center(), Vector2.ZERO)
	return room


## How far the boss has to stay off a wall: his own reach at the size his rung is built
## at, plus the clear ground every body is given.
func _boss_clearance(tier: MiniBossTier) -> float:
	var size := 1.0 if tier == null else maxf(tier.scale_multiplier, 0.01)
	return maxf(body_radius, 0.0) * size + maxf(wall_clearance, 0.0)


## How far one of the men standing with him has to stay off a wall. They are built at
## the enemy scene's own size, so it is the same reach without the boss's multiplier.
func _support_clearance() -> float:
	return maxf(body_radius, 0.0) + maxf(wall_clearance, 0.0)


## One boss: an ordinary enemy, built by the ordinary spawner, then made into the man
## on the poster.
##
## The order of the three changes matters. The health ceiling is raised through
## [method Health.set_max_health] rather than by writing the field, because the
## spawner has already added the body to the tree and its pool has already filled
## itself from the old ceiling - assigning the field alone would leave the boss
## walking in at a fraction of its health.
##
## [b]It is built off the enemy scene's own number, not the one it arrived with.[/b]
## The spawner has already laid whatever difficulty the world is carrying onto the
## instance, and a boss is not supposed to be carrying it: what he is worth is the
## contract's price and the player's level and nothing else, so the pool is measured
## against [method Health.get_authored_max_health].
func _build_boss(
	spawner: EnemySpawner,
	point: Vector2,
	tier: MiniBossTier,
	bounty: Bounty,
	known: int
) -> Node2D:
	var boss := spawner.spawn_at(point)
	if boss == null:
		return null

	boss.scale = Vector2.ONE * maxf(tier.scale_multiplier, 0.01)

	var health := _find_health(boss)
	if health != null:
		# Filled to the new ceiling, so he arrives whole.
		health.set_max_health(
			health.get_authored_max_health() * get_boss_health_multiplier(bounty), true)

	var speed := tier.speed_multiplier if tier.speed_multiplier > 0.0 else boss_speed_multiplier
	if "speed" in boss:
		boss.speed = float(boss.speed) * maxf(speed, 0.01)
	if "contact_damage" in boss:
		boss.contact_damage = maxf(boss_contact_damage, 0.0)

	# A boss neither runs for the edge of the map nor throws his knife down on his own
	# account, and both of those are components on the ordinary enemy - so they are
	# refused on this one rather than being taught about bosses. Nothing else on the
	# body is touched.
	_strip_giving_up(boss)

	var component := MiniBoss.new()
	component.name = "MiniBoss"
	component.bounty_id = bounty.bounty_id
	component.target_name = _poster_name(bounty)
	component.accepted_knowledge = known
	boss.add_child(component)
	_boss_component = component

	_dress_boss(boss, bounty)
	# Deferred, so it lands on top of whatever the wardrobe scaled the weapon to rather
	# than being overwritten by it - see [method MiniBossAppearance.apply], which runs on
	# ready and writes the sprite's scale absolutely from the size it was authored at.
	_scale_boss_weapon.call_deferred(boss)

	# Held still from the frame he exists, so a player who happens to be facing his
	# way sees a man standing there rather than one already walking at them.
	if boss.has_method(&"set_passive"):
		boss.call(&"set_passive", true)

	return boss


## Puts the outlaw's own head, body, weapon and boots on the body that was just
## built.
##
## [b]It is artwork and nothing else.[/b] The component added here writes textures
## onto the sprites the enemy scene already has - see [MiniBossAppearance] - so the
## boss keeps the ordinary enemy's chase, aim, swing, idle, legs, flash and hitboxes,
## and a mini boss moves and animates like an Enemy1 because it is one.
##
## Nothing is rolled at this point. The look is derived from [method look_key_for], so
## a boss rebuilt for the same contract tomorrow is the same man - and a boss whose
## contract the player has met before is recognisably him.
func _dress_boss(boss: Node2D, bounty: Bounty) -> void:
	if wardrobe == null:
		return

	var look := MiniBossAppearance.new()
	look.name = "MiniBossAppearance"
	look.wardrobe = wardrobe
	look.look_key = look_key_for(bounty)
	boss.add_child(look)


## Makes the blade in the boss's hand bigger than the one every other man is carrying.
##
## [b]It is the sprite's own scale, multiplied.[/b] The blade is aimed, swung and drawn
## by the enemy's ordinary rig - see [KnifeSlash] - and all of that is measured off the
## sprite rather than off a number written down anywhere, so a larger weapon is a
## larger weapon everywhere at once: it is drawn bigger, it reaches further, and the
## arc it cuts is wider, with nothing else to keep in step.
##
## Applied once and only to the boss. A multiplier of 1 leaves the weapon exactly as the
## wardrobe or the enemy scene drew it.
func _scale_boss_weapon(boss: Node2D) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	if is_equal_approx(boss_weapon_scale_multiplier, 1.0):
		return

	var weapon := boss.get_node_or_null(boss_weapon_path) as Node2D
	if weapon == null:
		return
	weapon.scale *= maxf(boss_weapon_scale_multiplier, 0.01)


## What the look is drawn from: the outlaw himself where the contract names one, and
## the contract otherwise.
##
## [b]The man, not the paperwork.[/b] Keying off [member BountyTarget.target_id] means
## two posters on the same outlaw show the same face, which is the only answer that
## makes sense for a person - and it is the key a wanted poster can be handed later to
## print him without anything being wired between the poster and this file. A contract
## with no target on it falls back to its own id, so it is still consistent with
## itself.
##
## [b]Public because the poster is the later that was meant.[/b] [WantedPoster] asks
## this node for the key and for [member wardrobe] and prints the man out of the two,
## so the sheet and the body that walks out of the region are drawn from one answer
## rather than from two that have to agree.
func look_key_for(bounty: Bounty) -> StringName:
	if bounty == null:
		return &""
	if bounty.target != null and bounty.target.target_id != &"":
		return bounty.target.target_id
	return bounty.bounty_id


## Stands [param count] more men round the boss, wherever he is, and reports how many
## were actually built.
##
## [b]It is the group an encounter opens with, asked for again.[/b] Everything about
## them - who builds them, how tough they are, how they are spread and whether they are
## held still - is [method _build_support]'s, so a group put up by hand is the same
## group the encounter deals itself. Nothing in play calls it; it exists so a fight can
## be set up without the world being rebuilt round it, which is what the developer
## panel's SPAWN STARTING ENEMIES does.
##
## Men added once the fight is already under way are released rather than left standing
## - a passive body in a running fight would never move again.
func spawn_support_group(count: int, centre: Vector2 = Vector2.INF) -> int:
	var spawner := _resolve_spawner()
	if spawner == null:
		return 0

	var at := centre
	if at == Vector2.INF:
		at = _boss.global_position if _boss != null and is_instance_valid(_boss) \
			else _player_position()

	prune_support()
	var standing := _support.size()
	var built := _build_support(spawner, at, count)
	if _phase == Phase.FIGHTING:
		for index: int in range(standing, _support.size()):
			_release(_support[index])
	return built


## The men standing with him: ordinary enemies, tougher than usual, dealt round him in
## a ring so the group comes at the player from every side once it is released rather
## than clumping on one.
##
## [b]Every one of them is held inside the same playable area the boss is[/b], through
## the same [method _standing_room] - so a boss standing near a wall has his ring folded
## along it rather than half of his men left in it. The clamp used to be skipped
## outright whenever the inset collapsed the rectangle, which on a map smaller than the
## inset meant it was skipped every time.
func _build_support(spawner: EnemySpawner, centre: Vector2, count: int) -> int:
	var wanted := maxi(count, 0)
	if wanted <= 0:
		return 0

	var room := _standing_room(spawner.arena_bounds, _support_clearance())
	var arc := randf() * TAU
	var built := 0

	for index: int in range(wanted):
		var angle := arc + TAU * float(index) / float(wanted) + randf_range(-0.18, 0.18)
		var reach := randf_range(
			minf(support_ring.x, support_ring.y), maxf(support_ring.x, support_ring.y))
		var point := (centre + Vector2.RIGHT.rotated(angle) * reach).clamp(
			room.position, room.end)

		var enemy := spawner.spawn_at(point)
		if enemy == null:
			continue

		var health := _find_health(enemy)
		if health != null:
			health.set_max_health(
				health.max_health * maxf(support_health_multiplier, 0.01), true)
		if enemy.has_method(&"set_passive"):
			enemy.call(&"set_passive", true)

		_support.append(enemy)
		built += 1

	return built


## Drops the bobbing X onto the boss and points the HUD's arrow at it.
##
## Nothing is wired: the marker joins the group named on its own scene and the arrow
## on the HUD is following that group already, so a boss appearing is the arrow
## acquiring a target and a boss being reached is it losing one. See
## [DestinationMarker].
func _attach_marker(boss: Node2D) -> void:
	if marker_scene == null:
		return

	var marker := marker_scene.instantiate() as DestinationMarker
	if marker == null:
		push_warning("MiniBossDirector: marker scene is not a DestinationMarker.")
		return

	boss.add_child(marker)
	# Held at its authored size whatever the boss was scaled to, so the X over a
	# 2.5x boss is the same mark as the one over a 1.5x boss.
	marker.scale = Vector2.ONE / maxf(boss.scale.x, 0.01)
	_marker = marker


## Says he is nearby, through the HUD panel every other piece of contract news
## already goes out on.
func _announce(bounty: Bounty) -> void:
	var who := _poster_name(bounty)
	boss_discovered.emit(bounty, who)

	var notice := get_node_or_null(notice_path)
	if notice == null or not notice.has_method(&"show_message"):
		return
	notice.call(&"show_message", nearby_message.format({"who": who}))


# --- Walking there -------------------------------------------------------------

func _process(_delta: float) -> void:
	if _phase != Phase.APPROACHING:
		return

	# A boss that died before being reached - nothing can kill him yet, but a world
	# torn down around this leaves the same dangling reference - ends the approach
	# rather than leaving the arrow pointing at a corpse.
	if _boss == null or not is_instance_valid(_boss):
		_phase = Phase.NONE
		set_process(false)
		return

	var player := _resolve_player()
	if player == null:
		return
	if player.global_position.distance_to(_boss.global_position) > maxf(trigger_radius, 1.0):
		return

	_begin_intro()


## The player has arrived. The mark and the arrow come down together - both are the
## marker's doing, so there is no way to remove one and leave the other - the encounter
## is carried onto its own ground, and the camera is handed over.
func _begin_intro() -> void:
	_phase = Phase.INTRO
	set_process(false)

	if _marker != null and is_instance_valid(_marker):
		_marker.remove_marker()

	# Before the introduction, so the camera crosses onto a man who is already standing
	# on the ground the fight will be fought on rather than sliding there behind a card.
	_hold_the_fight_elsewhere()

	_show_title()
	approach_completed.emit()

	var arena := _resolve_arena()
	if arena == null or not arena.play_intro(_boss):
		# No arena, or an introduction that could not play. The fight still starts -
		# an introduction must never be the reason the encounter does not happen.
		_begin_fight()
		return

	arena.intro_finished.connect(_begin_fight, CONNECT_ONE_SHOT)


## The introduction is over: the arena is nailed down and everybody is let go.
##
## The order is deliberate. The camera and the walls are put in place [i]before[/i]
## anything is released, so there is never a frame in which ten men are walking at the
## player through a screen that has not finished becoming the arena.
func _begin_fight() -> void:
	if _phase == Phase.FIGHTING:
		return
	_phase = Phase.FIGHTING

	var arena := _resolve_arena()
	if arena != null and _boss != null and is_instance_valid(_boss):
		arena.lock(_boss)

	# Cleared of anybody shot on the way in before the list is walked - see
	# [method prune_support]. Nothing below may be allowed to fail, because
	# [signal fight_started] at the end of this is what arms the rest of the encounter.
	prune_support()
	_release(_boss)
	for enemy: Node2D in _support:
		_release(enemy)

	if title_hides_on_fight:
		_hide_title()

	fight_started.emit()


func _release(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method(&"set_passive"):
		enemy.call(&"set_passive", false)


## Carries the whole encounter onto the bounty's own ground - see [BossEncounterMap].
##
## [b]Nothing about the fight is decided by the move.[/b] The same boss, the same men,
## the same rung and the same contract are simply set down somewhere else; the map takes
## the camera and the spawner's playable rectangle over for the duration and hands both
## back when the ending releases the arena, which is also when the player is carried
## home. A world with no such map, or one switched off, holds the fight where the man was
## found and nothing here changes.
func _hold_the_fight_elsewhere() -> void:
	var map := _resolve_encounter_map()
	if map == null:
		return
	prune_support()
	map.enter(_boss, _support)


# --- The name on the screen ----------------------------------------------------

## Puts the name up. Everything about how it looks - the font, the red, the outline
## behind it - is on the card in the inspector; all this writes is the text and the
## fade, so restyling it never comes back here.
func _show_title() -> void:
	var card := _resolve_title()
	if card == null:
		return

	var label := card.get_node_or_null(title_label_path) as Label
	if label != null and _boss_component != null:
		label.text = _boss_component.get_display_name()

	if _title_tween != null and _title_tween.is_running():
		_title_tween.kill()

	card.modulate.a = 0.0
	card.visible = true
	_title_tween = create_tween()
	_title_tween.tween_property(card, "modulate:a", 1.0, maxf(title_fade_time, 0.0001))


func _hide_title() -> void:
	var card := _resolve_title()
	if card == null:
		return

	if _title_tween != null and _title_tween.is_running():
		_title_tween.kill()

	_title_tween = create_tween()
	_title_tween.tween_property(card, "modulate:a", 0.0, maxf(title_fade_time, 0.0001))
	_title_tween.tween_callback(card.hide)


func _resolve_title() -> Control:
	if _title == null or not is_instance_valid(_title):
		_title = get_node_or_null(title_path) as Control
	return _title


# --- Looking things up ---------------------------------------------------------

## What the poster calls him, falling back so a contract with no outlaw on it still
## produces a name to print rather than a gap.
func _poster_name(bounty: Bounty) -> String:
	if bounty == null or bounty.target == null or bounty.target.display_name.is_empty():
		return "THE OUTLAW"
	return bounty.target.display_name


## Stops one body deciding for itself that it has had enough.
##
## [b]Both are refused rather than freed.[/b] Each of them owns a flag for exactly
## this - [method EnemyEscape.cancel] and [member EnemySurrender.gives_up_on_its_own] -
## so a boss is a man who never runs and never folds, with nothing anywhere having to
## check whether it is the boss and none of the machinery they share with the death
## being torn out.
##
## The surrender in particular has to survive: going down on the floor is what being
## beaten looks like, and [BossDefeat] puts the boss there through this very component
## when the last shot lands - see [method EnemySurrender.surrender]. Freeing it here,
## which is what this used to do, would mean a second fall and a second E interaction
## existing for the boss alone.
func _strip_giving_up(boss: Node2D) -> void:
	for node: Node in boss.find_children("*", "EnemyEscape", true, false):
		var retreat := node as EnemyEscape
		if retreat != null:
			retreat.cancel()
	for node: Node in boss.find_children("*", "EnemySurrender", true, false):
		var surrender := node as EnemySurrender
		if surrender != null:
			surrender.gives_up_on_its_own = false
	# And he does not lose his temper either. A boss already has his own phases, his
	# own tint and his own speed, and letting [MoraleDirector] multiply any of them
	# because one of his men was shot would fight [BossPhases] over the same numbers.
	# Refused through the component's own door for the same reason the other two are.
	for node: Node in boss.find_children("*", "EnemyEnrage", true, false):
		var rage := node as EnemyEnrage
		if rage != null:
			rage.can_enrage = false


func _ask_session(method: StringName) -> StringName:
	if _session == null or not _session.has_method(method):
		return &""
	return StringName(_session.call(method))


func _get_ledger() -> BountyLedger:
	return get_node_or_null(ledger_path) as BountyLedger


func _resolve_spawner() -> EnemySpawner:
	return get_node_or_null(spawner_path) as EnemySpawner


func _resolve_arena() -> BossArena:
	var named := get_node_or_null(arena_path) as BossArena
	return named if named != null else BossArena.get_active(self)


func _resolve_encounter_map() -> BossEncounterMap:
	var named := get_node_or_null(encounter_map_path) as BossEncounterMap
	return named if named != null else BossEncounterMap.get_active(self)


## Looked up lazily and re-looked-up when it goes away, the same way every other
## system here finds the player.
func _resolve_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	return _player


func _player_position() -> Vector2:
	var player := _resolve_player()
	return Vector2.ZERO if player == null else player.global_position


func _find_health(enemy: Node) -> Health:
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null
