class_name EnemySurrender
extends Node
## An enemy that has given up: weapon on the floor, face down, still breathing, and
## something the player can walk up to and press E on.
##
## [b]It is the third ending an enemy can have[/b], alongside dying and getting
## away, and it is the only one the enemy survives. Three things reach it, and none of
## them is written down here - the component only knows how to give up, not when:
##
##   * an encounter finishing, where one of the enemies still standing sometimes
##     drops rather than runs - see [RunEndDefeat];
##   * a shot going off next to it, which sometimes breaks an enemy's nerve in the
##     middle of a fight - see [GunshotSurrender];
##   * the shot that finishes a mini boss, which puts a man down who would never have
##     gone down by himself - see [BossDefeat] and [member gives_up_on_its_own]. That
##     is the one caller that passes [code]forced[/code].
##
## What actually happens is assembled out of parts the enemy already has rather than
## reimplemented. The weapon is thrown down by [method EnemyHeadPop.drop_knife], the
## same call a retreat uses and a death uses; the chase and the knife stop by
## switching off the host's physics, the same way [EnemyDefeat] stops a body; and
## the aim pivots are simply stopped where they are, so the head stays wherever it
## was looking as its owner goes down instead of tracking the player from the floor.
##
## [b]It goes down as one man.[/b] An enemy is drawn as separate pieces hanging off
## separate pivots - the body turns about its feet, the head about its neck - and
## turning each of them about its own origin is what a death does, because a death
## is precisely the head coming off. A surrender is the opposite event and has to
## look it, so the pieces are swung about [b]one shared pivot[/b] instead: each is
## rotated by the same angle and carried along the arc that rotation traces around
## [member fall_pivot], which is exactly what a rigid body does. The head therefore
## stays on the neck through the whole fall without the artwork being reassembled or
## the [CharacterBody2D] itself - and its collision shape with it - being turned.
##
## [b]A retreat that surrenders stops retreating.[/b] An enemy already running can
## have its nerve broken by a shot beside it, and if its [EnemyEscape] were left
## supervising it, the man on the floor would be removed two seconds after the
## camera lost sight of him. He must not be: he is the player's to talk to or to
## shoot, and nothing else may take him. See [member stops_escape].
##
## [b]It stays alive and stays killable.[/b] Nothing here touches [Health] and
## nothing takes its hitboxes off their layer, so a player who shoots a man who has
## given up gets an ordinary death and [BloodEmitter] spills the ordinary blood.
## That is a decision the player is being offered, and it costs no code to offer it.
##
## What it does stop being is an [i]opponent[/i]. It leaves the [code]enemies[/code]
## group, which is the single move that makes every search in the game - a bouncing
## bullet, a thrown coin, the guard that clears the base - stop finding it, and it is
## lifted out of the container the live enemies are kept in. That second half matters
## as much as the first: the camp, the music and the round portal all wait for that
## container to empty before the round can end, and a man lying on the floor waiting
## to be spoken to is not a reason to hold a round open forever. See
## [member holding_path].
##
## The interaction is the same shape as [WantedBoard]'s and for the same reasons: the
## player is found by group rather than by path, the reach is a circle around this
## enemy rather than an area to author, the prompt is *told* on the crossing rather
## than asked every frame, and the key is taken in [method Node._unhandled_input] and
## marked handled so the press cannot also reach whatever is standing behind it.
##
## [b]What pressing E is worth is still not decided here.[/b] This reports that it
## happened through [signal used] and nothing else; what the man actually tells the
## player is [SurrenderKnowledge]'s business, hung off that signal. The one thing
## this does own is that it can only be worth it [i]once[/i] - see
## [method consume], which whatever paid out calls back to spend the enemy, so an
## interaction that found nothing to give leaves him standing there to be asked
## again rather than being used up for nothing.

## Emitted the moment the enemy gives up, before it has finished falling. Anything
## counting live opponents should stop counting this one here.
signal surrendered
## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when the player actually interacts with it.
signal used
## Emitted once the interaction has been spent and cannot be had again.
signal consumed

## Group every surrendered enemy joins, so anything can find them without being
## wired to any one of them.
const GROUP := &"surrendered_enemy"

## The enemy's own knife-thrower, borrowed to put the weapon on the floor. Optional -
## an enemy without one simply gives up empty-handed.
@export var head_pop_path: NodePath = ^"../HeadPop"
## Whether the weapon is thrown down as the enemy gives up.
@export var drops_weapon: bool = true
## The enemy's health, watched only so a surrendered enemy that is then shot takes
## its prompt down with it rather than leaving an E floating over a corpse.
@export var health_path: NodePath = ^"../Health"
## Whether this man's nerve can go on its own.
##
## [b]On for every ordinary enemy, and off for a mini boss.[/b] Both of the things
## that make somebody give up ask through [method surrender] without knowing who they
## are asking - a shot going off beside him, an encounter ending - so this is how a
## man who is not allowed to fold refuses them both without either of them being
## taught that bosses exist. See [method MiniBossDirector._strip_giving_up], which
## turns it off on the boss it builds.
##
## It is deliberately not the same thing as having no [EnemySurrender] at all, which
## is what the boss used to have: the man on the poster still has to be able to end up
## on the floor - that is what being beaten looks like - he simply cannot decide it
## for himself. [method surrender] can still be asked outright with
## [code]forced[/code], which is what [BossDefeat] does when the last shot lands.
@export var gives_up_on_its_own: bool = true

@export_group("Going down")
## The artwork that goes down. [b]All of it moves as one piece[/b] - every entry is
## turned by the same angle and swung around the same [member fall_pivot] - so the
## list is "which parts of this enemy are the enemy", and an enemy drawn out of more
## pieces goes down in one by having them all named here.
@export var fall_paths: Array[NodePath] = [^"../Visual", ^"../HeadAim"]
## The point the whole figure turns about, relative to the enemy's origin at its
## feet. Up is negative, so this is knee height: the legs fold under and the rest of
## the man comes over the top of them, which is what dropping to your knees looks
## like. At the feet he would topple like a plank; at the neck only his head would
## move.
@export var fall_pivot := Vector2(0.0, -14.0)
## How far over he goes, in degrees. Signed at runtime, so he falls away from
## whoever he gave up to rather than always to the same side.
##
## Well short of flat on purpose - this is a man on his knees with his head down,
## not a corpse. He has to stay legible as somebody the player can still walk up to.
@export var fall_degrees: float = 46.0
## How long the fall takes.
@export var fall_time: float = 0.55
## How far the whole figure slumps as it goes down, on top of the rotation. Applied
## to every piece equally, which is what keeps it a slump rather than a shear.
@export var fall_offset := Vector2(0.0, 6.0)
## Whether the head and knife pivots stop tracking as the enemy drops. On - a man
## on the floor who is still following the player with his eyes reads as alive in
## the wrong way, and the rotation the fall writes would be overwritten every frame
## by the tracking anyway.
@export var stops_aiming: bool = true

@export_group("Leaving the fight")
## Whether an enemy that was already running away has its retreat called off as it
## gives up - see [method EnemyEscape.cancel].
##
## [b]On, and it is what keeps a surrendered enemy in the world.[/b] A retreat
## removes itself once it has been off the screen for a couple of seconds, which is
## right for a man who got away and wrong for a man on the floor: he stays until the
## player talks to him or kills him. Off leaves both components running on the same
## enemy, and the retreat would win.
@export var stops_escape: bool = true
## Whether the enemy leaves [member enemy_group] as it gives up.
@export var leaves_enemy_group: bool = true
## The group the live enemies are found by.
@export var enemy_group: StringName = &"enemies"
## Where the body is moved to once it is out of the fight. Left empty it goes to the
## running scene, which is right for every world in the game.
##
## [b]It has to leave wherever the live enemies are kept.[/b] The round portal, the
## camp and the soundtrack all read "the arena is clear" off that container being
## empty, so a surrendered enemy left sitting in it would hold the end of the round
## open until the player killed the man who had already given up.
@export var holding_path: NodePath
## Whether it is moved at all. Off leaves it exactly where it was parented, which is
## only right in a scene that keeps no such container.
@export var leaves_enemy_container: bool = true

@export_group("Interaction")
## How close the player has to stand for the prompt to appear and the key to work,
## in pixels.
@export var interaction_radius: float = 120.0
## Only bodies in this group can interact.
@export var body_group: StringName = &"player"
## Key that interacts with it.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, relative to the enemy's origin at its feet.
@export var reach_offset := Vector2.ZERO
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"../Prompt"

@export_group("What he says")
## The bubble he speaks in. Left empty he gives up in silence, which is exactly
## what he did before there was one.
@export var bubble_scene: PackedScene
## What he says as he goes down.
@export var surrender_line: String = "DON'T SHOOT, I SURRENDER"
## What he says when the player actually talks to him.
##
## [b]It is what he says however the conversation went.[/b] Whether he had anything
## worth telling them is [SurrenderKnowledge]'s business and is reported separately;
## this is the man himself, thanking them for the one thing he actually got out of
## the meeting, and about to get up and go.
@export var talked_line: String = "Thank you for sparing my life!"
## Where the bubble hangs relative to his origin at his feet. Lower than a standing
## man's, because he is on his knees.
@export var bubble_offset := Vector2(52.0, -74.0)
## How quickly the first bubble goes when he is talked to, so the second can take
## its place.
@export var bubble_swap_fade: float = 0.18
## How quickly whatever he is saying goes as he gets up and runs.
@export var bubble_leave_fade: float = 0.3
## Whether the line he was thanked with stays up while he runs.
##
## [b]On, and it is why he is thanked at all.[/b] The last thing the player sees of
## a man they spared is him getting up and going with the thanks still hanging over
## him, which is a different ending from a bubble that blinks out the moment he
## moves. It is taken down the ordinary way when he is gone - by [method _on_died]
## if he is shot on his way out, and by this component being freed with him when he
## makes it off the screen.
@export var keeps_bubble_while_fleeing: bool = true

@export_group("Being wounded")
## Whether a hit he survives makes him swear.
##
## [b]It is speech and nothing else, and that is the whole point of it.[/b] It used
## to be the same words a man says on his knees - so an enemy who was merely shot
## and kept coming announced that he was surrendering while running at the player
## with a knife. Being hit and giving up are now two separate things that happen to
## be raised by the same event: this one only ever puts a bubble up, and the other
## is [MoraleDirector]'s roll - see [method _ask_morale]. A man who curses is still
## standing, still armed, still in [member enemy_group] and still counted.
##
## What being shot and living actually does to an enemy - the white flash, the
## shove, the moment of being slowed - is [HitReaction]'s and is not touched, read
## or duplicated by any of this.
@export var speaks_when_wounded: bool = true
## How often a hit he survives gets a curse out of him, as a fraction of 1.
##
## Rolled once per hit rather than per pellet - see [member wounded_repeat_guard],
## which closes the window before the roll is made, so a shotgun blast is one blast
## rather than eight chances at a bubble.
@export_range(0.0, 1.0, 0.01) var wounded_curse_chance: float = 0.30
## What he might say, one picked at random. An array rather than a list of cases, so
## another line is dropped in here and nothing else is touched.
@export var wounded_curse_lines: Array[String] = [
	"F*ing demon!",
	"That f**** devil!",
	"You little s*!",
	"Damn son of a b**!",
	"What the f*?!",
	"Oh, s*!",
	"Holy s*!",
	"Goddamn it!",
	"F* this!",
	"Run, you b****!",
]
## Whether being hit also asks [MoraleDirector] whether his nerve held.
##
## [b]It is the separate roll, and it is the only one that can put him down.[/b] The
## odds are the director's - see [method MoraleDirector.get_wounded_surrender_chance]
## - and what happens if it lands is [method surrender], the real thing, on the
## floor and out of the fight. Off leaves being shot a purely spoken reaction.
@export var wounded_asks_morale: bool = true
## Where that bubble hangs, relative to his origin at his feet. Higher than the
## kneeling one - he is still on his feet when he says it.
@export var wounded_bubble_offset := Vector2(52.0, -104.0)
## How long it stays up before fading, in seconds.
@export var wounded_bubble_hold: float = 1.6
## How long it takes to fade at the end of that.
@export var wounded_bubble_fade: float = 0.4
## The least time between two wounded reactions, in seconds.
##
## [b]It is what makes one attack one event.[/b] A shotgun puts eight pellets into a
## man and each of them reports its own damage; the window is closed before either
## roll is made, so the blast is worth exactly one curse roll and, through
## [member MoraleDirector.repeat_guard], exactly one surrender roll.
@export var wounded_repeat_guard: float = 1.4

@export_group("Getting up again")
## Whether a man who has given up eventually gets up and runs.
##
## [b]On, and it is what stops him being a permanent fixture.[/b] He is not an
## opponent while he is down and nothing waits on him - but he cannot lie in the
## sand forever either, so both of the ways the player can leave him end with him on
## his feet and running. Off leaves him lying there until he is shot, which is what
## he did before this existed.
@export var gets_up: bool = true
## How long after being talked to he waits before getting up, in seconds. Long
## enough for his last line to be read.
@export var stand_after_talking: float = 2.0
## How long the player has to stay away from him before he risks getting up, in
## seconds. The clock only runs while they are out of [member interaction_radius]
## and is put back to the start the moment they come near again, so a player
## standing over him deciding what to do never has him bolt out from under them.
@export var stand_after_alone: float = 10.0
## How long he takes to get back onto his feet, in seconds - the fall played
## backwards.
@export var stand_time: float = 0.45
## Whether he rejoins [member enemy_group] as he gets up.
##
## [b]Off.[/b] He stopped being an opponent when he went down and getting up to run
## away does not make him one again - a man with his hands empty sprinting for the
## horizon is not somebody the encounter is waiting on. Everything that hunts by
## that group therefore keeps ignoring him right through his exit.
@export var rejoins_enemy_group: bool = false

@onready var _head_pop: EnemyHeadPop = get_node_or_null(head_pop_path) as EnemyHeadPop
@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _surrendered: bool = false
var _in_reach: bool = false
## Whether the interaction has been spent. Set only by [method consume], never by
## [method use] itself, so a press that turned out to be worth nothing does not use
## the man up.
var _used: bool = false
## Whether he is on his way back to his feet. One way only - once he is getting up
## nothing puts him back down.
var _standing_up: bool = false
## How long the player has been away from him, in seconds. Reset to zero every time
## they come near, so this is "time since they were last beside him" rather than
## time since he went down.
var _alone: float = 0.0
## The bubble he is currently speaking in, if any.
var _bubble: SpeechBubble
## Where each piece of him was before he fell, so the fall can be played backwards
## exactly rather than guessed at. Filled in by [method _fall].
var _fall_rest: Dictionary = {}
## When he last cried out at being shot, in seconds since the game started. See
## [member wounded_repeat_guard].
var _last_cry: float = -1000.0
## Whether the player actually talked to him, and so whether the bubble he is
## wearing is the thank-you. It is the one bubble that outlives the man's exit.
var _thanked: bool = false


func _ready() -> void:
	# Nothing to watch until there is somebody to walk up to.
	set_process(false)
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	if _health != null:
		_health.died.connect(_on_died)
		_health.damaged.connect(_on_damaged)
	# Listened to rather than acted on inside [method use], so that what he says and
	# what he is worth stay separate: [SurrenderKnowledge] hangs off the same signal
	# and neither of them knows about the other.
	used.connect(_on_talked_to)


## Every enemy currently lying on the floor, in no particular order.
static func get_all(from_node: Node) -> Array[Node]:
	if from_node == null or not from_node.is_inside_tree():
		return []
	return from_node.get_tree().get_nodes_in_group(GROUP)


## The give-up component on [param enemy], or null when it has none.
##
## Found by type rather than by a fixed child name - the same lookup [RunEndDefeat]
## already makes for an enemy's escape and its defeat - so whatever decides that
## somebody should give up needs to know nothing about how an enemy is put together,
## and an enemy built without one is simply never picked.
static func find_on(enemy: Node) -> EnemySurrender:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "EnemySurrender", true, false):
		var found := node as EnemySurrender
		if found != null:
			return found
	return null


func has_surrendered() -> bool:
	return _surrendered


func is_player_in_reach() -> bool:
	return _in_reach


## Whether the interaction has already been spent.
func is_used() -> bool:
	return _used


## Makes this enemy give up. Returns whether it actually did - an enemy that has
## already surrendered, or one that has been taken out of the tree, does nothing.
##
## Guarded, so two things asking at once - a shot going off as the round ends -
## cannot drop the same man twice.
##
## [param forced] puts the man down whether or not he would ever have given up by
## himself - see [member gives_up_on_its_own]. Every ordinary caller leaves it alone
## and asks politely; it is for the one case where going down is not a decision the
## man made, which is a mini boss taking the shot that finishes him.
func surrender(forced: bool = false) -> bool:
	if _surrendered or not is_inside_tree():
		return false
	if not gives_up_on_its_own and not forced:
		return false

	var host := get_parent()
	if host == null:
		return false
	if _health != null and not _health.is_alive():
		return false

	_surrendered = true
	add_to_group(GROUP)

	if stops_escape:
		_stop_escaping(host)
	_stop_fighting(host)
	_lock_out_hostility(host)
	if drops_weapon and _head_pop != null:
		_head_pop.drop_knife()
	if stops_aiming:
		_stop_aiming(host)
	_fall(host)
	_say(surrender_line)

	_alone = 0.0
	set_process(true)
	surrendered.emit()
	return true


## Interacts with the surrendered enemy. Ignored unless the player is actually
## standing at it, so nothing can be triggered from across the arena, and ignored
## once it has been spent. Returns whether the interaction was offered at all.
##
## [b]It reports and does nothing else.[/b] What a man who has given up is worth is
## [SurrenderKnowledge]'s business, hung off [signal used]; whether that turned out
## to be anything is reported back through [method consume].
func use() -> bool:
	if _used or not _surrendered or not _in_reach:
		return false
	used.emit()
	return true


## Spends the interaction: this enemy has nothing further to offer and the prompt
## over the player's head goes down for good.
##
## [b]It is called back rather than assumed.[/b] Whatever listens to
## [signal used] is the only thing that knows whether the player actually got
## anything - a man who can only tell you what you already knew has not been spent -
## so this is deliberately not done inside [method use]. It is the whole of "pressing
## E twice cannot pay twice", and being idempotent is what makes two listeners
## calling it harmless.
##
## The enemy itself is left exactly where it is. It is still alive, still killable
## and still worth its blood, because being out of things to say is not being dead.
func consume() -> bool:
	if _used:
		return false
	_used = true

	set_process(false)
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	consumed.emit()
	return true


## The chase, the swing and the walk, all switched off by the same move
## [EnemyDefeat] uses. Everything cosmetic is left running on purpose: this is a man
## who has stopped fighting, not a frozen frame, and he is still breathing.
func _stop_fighting(host: Node) -> void:
	if leaves_enemy_group and host.is_in_group(enemy_group):
		host.remove_from_group(enemy_group)

	host.set_physics_process(false)
	if host is CharacterBody2D:
		(host as CharacterBody2D).velocity = Vector2.ZERO

	_leave_the_enemy_container(host)


## Lifts the body out of whatever container the live enemies are kept in.
##
## Deferred because a surrender very often arrives from inside the physics server's
## own callback - a shot going off beside the enemy - and moving a node between
## parents while the tree is being flushed is not allowed there. The global
## transform is kept, so the body does not move a pixel on the frame it changes
## hands.
func _leave_the_enemy_container(host: Node) -> void:
	if not leaves_enemy_container:
		return

	var keeper := get_node_or_null(holding_path)
	if keeper == null:
		keeper = get_tree().current_scene
	if keeper == null or host.get_parent() == keeper:
		return

	host.reparent.call_deferred(keeper, true)


## Makes the surrender authoritative: this man can never again cost the player a
## point of damage, for the rest of the encounter, whatever else happens to him.
##
## [b]The bug this closes.[/b] [method _stop_fighting] switches the host's whole
## [method Node._physics_process] off, which is what stops his knife the instant
## he goes down - but [method stand_up] switches it back on again so he can run,
## and the ordinary chase-and-swing code in [Enemy] does not know a surrender
## ever happened. [method Enemy.begin_flight]'s own turn to face away is asked
## for on a delay - see [member EnemyEscape.escape]'s [code]delay[/code] - so for
## the length of that delay a man getting up off the floor was, for a moment, an
## ordinary enemy again: not yet fleeing, attacks never told to stay off, and
## close enough to the player he had just been talked to by to land a swing on
## them before he ever turned to run.
##
## [method Enemy.lock_attacks_disabled] is the fix: it is not merely switched
## off, it is switched off *and refused to be switched back on* by anything, for
## good - see that method's own doc. So the window above no longer matters: his
## knife is off before he ever stands, before [EnemyEscape] gets a chance to turn
## him, and nothing that follows can hand it back to him.
func _lock_out_hostility(host: Node) -> void:
	if host.has_method(&"lock_attacks_disabled"):
		host.call(&"lock_attacks_disabled")


## Calls off a retreat this enemy had already begun, so the man on the floor is not
## also a man being counted out of the arena.
##
## Found by type for the same reason every other component here is, and asked
## unconditionally: an enemy that never ran simply has a retreat that never started,
## and calling it off costs nothing.
func _stop_escaping(host: Node) -> void:
	for node: Node in host.find_children("*", "EnemyEscape", true, false):
		var escape := node as EnemyEscape
		if escape != null:
			escape.cancel()


## The aim pivots are stopped rather than retargeted, so the head keeps whatever
## angle it had at the moment its owner gave up and the fall is free to write over
## it. Found by type for the same reason every other component here is: an enemy
## that aims with different parts still goes down properly.
func _stop_aiming(host: Node) -> void:
	for node: Node in host.find_children("*", "LookAtTarget", true, false):
		node.set_physics_process(false)


## Brings the whole man down onto his knees, away from whoever he gave up to.
##
## [b]Every piece is given the same turn about the same point.[/b] A piece is not
## only rotated in place - it is also carried to where that rotation puts it,
## [code]pivot + (rest - pivot).rotated(angle)[/code], which is the definition of a
## rigid turn and the reason the head arrives at the end of the fall still sitting on
## the neck. Rotating each piece about its own origin instead, which is what a death
## does, leaves the body swinging out from the feet while the head spins on the spot
## where the neck used to be - and the head visibly comes off, which is exactly the
## wrong thing for the one ending the enemy survives.
##
## It is still one tween per piece rather than one rotation on the host, because
## turning the [CharacterBody2D] would take its collision shape round with it and a
## kneeling man should still stand where he stood.
func _fall(host: Node) -> void:
	var side := _fall_side(host)
	var angle := deg_to_rad(fall_degrees) * side
	var duration := maxf(fall_time, 0.0001)

	_fall_rest.clear()
	for path: NodePath in fall_paths:
		var piece := get_node_or_null(path) as Node2D
		if piece == null:
			continue

		# Read rather than assumed, so a piece the artist has already offset or
		# angled is turned from where it actually is.
		var rest := piece.position
		var landing := fall_pivot + (rest - fall_pivot).rotated(angle) + fall_offset
		# Kept so the fall can be played backwards to the pixel if he gets up again -
		# see [method stand_up]. Stored against the piece rather than against the
		# path, so a man whose parts have been rearranged still stands up straight.
		_fall_rest[piece.get_instance_id()] = {"position": rest, "rotation": piece.rotation}

		var tween := piece.create_tween().set_parallel(true)
		tween.tween_property(piece, "rotation", piece.rotation + angle,
			duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(piece, "position", landing,
			duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Which way it goes over: away from whatever it was chasing, and a random side when
## there is nothing to measure against, so a row of surrenders does not all fall
## identically.
func _fall_side(host: Node) -> float:
	var body := host as Node2D
	if body != null and host.has_method(&"get_chase_target"):
		var target := host.call(&"get_chase_target") as Node2D
		if target != null and is_instance_valid(target):
			var away := body.global_position.x - target.global_position.x
			if not is_zero_approx(away):
				return signf(away)
	return 1.0 if randf() < 0.5 else -1.0


func _process(delta: float) -> void:
	_watch_player()
	_count_time_alone(delta)


# --- Talking -------------------------------------------------------------------

## Puts a line up over him, replacing whatever he was saying.
##
## The bubble is added to the running scene rather than to the man, so it hangs in
## the air at a steady angle while he falls, while he is shot at, and for a moment
## after he has gone. See [SpeechBubble], which is the same component the enraged
## use - nothing about how a line is drawn is written twice.
func _say(line: String) -> void:
	if bubble_scene == null or line.is_empty():
		return

	var host := get_parent() as Node2D
	if host == null:
		return

	_drop_bubble(bubble_swap_fade)

	var bubble := bubble_scene.instantiate() as SpeechBubble
	if bubble == null:
		return

	bubble.head_offset = bubble_offset
	var keeper: Node = get_tree().current_scene
	if keeper == null:
		keeper = host.get_parent()
	if keeper == null:
		return

	keeper.add_child(bubble)
	bubble.global_position = host.global_position + bubble_offset
	bubble.set_subject(host)
	bubble.show_bubble(line)
	_bubble = bubble


## Fades whatever he is saying. Safe to call on a man who was never given a bubble
## and on one whose bubble is already leaving.
func _drop_bubble(fade: float) -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.dismiss(fade)
	_bubble = null


## A shot landed and he is still standing.
##
## [b]Two separate reactions, and neither of them implies the other.[/b] One hit
## raises one wounded event, and that event asks two independent questions: whether
## his nerve went, which is [MoraleDirector]'s roll on the wounded curve, and
## whether he swore about it, which is this component's roll and is speech alone. A
## man who folds actually goes down - on his knees, weapon dropped, out of
## [member enemy_group] - and a man who does not is an ordinary enemy who happens to
## have said something.
##
## The nerve is asked first only so that the two bubbles cannot fight over the same
## man: somebody in the act of surrendering is already saying so, and a curse laid
## over the top of it would replace the more important line. The roll itself is made
## either way.
##
## [b]It is additive.[/b] Nothing about the existing wounded behaviour is replaced,
## suppressed or read here - [HitReaction] flashes him white, shoves him and slows
## him exactly as it always has, and this never learns whether it did. A man already
## on the floor is left alone.
func _on_damaged(_amount: float, _hit_direction: Vector2) -> void:
	if _surrendered or _standing_up:
		return
	if _health == null or not _health.is_alive():
		return

	# Closed before either roll, so a shotgun's worth of pellets is one wounded event
	# with one roll of each in it rather than eight of both.
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_cry < wounded_repeat_guard:
		return
	_last_cry = now

	if _ask_morale():
		return
	_curse()


## Puts his nerve to [MoraleDirector] as a wounded man. Returns whether he actually
## went down, which is the only thing this component treats as having happened.
##
## [b]The odds are not written here and neither is the outcome.[/b] How likely a
## wounded man is to fold is [method MoraleDirector.get_wounded_surrender_chance],
## and folding is [method surrender] - the same call a near miss and a nearby death
## already make, on the same component, to the same effect. This adds a third event
## to a system that already existed rather than a second way of giving up.
func _ask_morale() -> bool:
	if not wounded_asks_morale:
		return false

	var host := get_parent() as Node2D
	if host == null:
		return false
	var director := MoraleDirector.get_active(self)
	if director == null:
		return false

	director.check(host, MoraleDirector.Source.WOUNDED)
	# Read off the state rather than off the return, so "he surrendered" means he is
	# on the floor and nothing else can be mistaken for it.
	return _surrendered


## Swears, sometimes. Speech and nothing else: no state is set, no group is left and
## nothing is told about it.
func _curse() -> void:
	if not speaks_when_wounded or wounded_curse_lines.is_empty():
		return
	if randf() >= clampf(wounded_curse_chance, 0.0, 1.0):
		return

	var kept := bubble_offset
	bubble_offset = wounded_bubble_offset
	_say(wounded_curse_lines.pick_random())
	bubble_offset = kept

	if _bubble == null or wounded_bubble_hold <= 0.0:
		return
	# Timed on the tree rather than on the bubble, so a man who then gives up or dies
	# simply has a second, shorter fade land on a bubble that has already gone.
	var wait := get_tree().create_timer(wounded_bubble_hold, true, false, true)
	wait.timeout.connect(_drop_bubble.bind(wounded_bubble_fade))


# --- Getting up again ----------------------------------------------------------

## The player pressed E on him. He answers, and then he goes.
##
## The two seconds are the line being read, not a cooldown - see
## [member stand_after_talking]. The timer runs on the tree rather than on this
## node so it is unaffected by [method consume] switching this node's processing
## off underneath it, which is exactly what happens when he turned out to have
## something worth telling them.
func _on_talked_to() -> void:
	if not gets_up or _standing_up:
		return

	_thanked = true
	_say(talked_line)
	# Nothing further is offered while he is on his way out, so the E over the
	# player's head goes down now rather than when he actually moves.
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	if stand_after_talking <= 0.0:
		stand_up()
		return
	var wait := get_tree().create_timer(stand_after_talking, true, false, true)
	wait.timeout.connect(stand_up)


## Counts how long the player has stayed away, and eventually lets him go.
##
## Reset rather than paused while they are near, so a player who walks up, thinks
## about it and walks off again gives him the full window from the moment they
## left - which is what makes "if the player does not interact and moves away" mean
## what it says.
func _count_time_alone(delta: float) -> void:
	if not gets_up or _standing_up or not _surrendered or stand_after_alone <= 0.0:
		return

	if _in_reach:
		_alone = 0.0
		return

	_alone += delta
	if _alone >= stand_after_alone:
		stand_up()


## Gets him back onto his feet and sends him running.
##
## [b]The retreat is the ordinary retreat.[/b] Everything about running away -
## dropping what he is carrying, turning his back, the speed, leaving once he is off
## the screen - is [EnemyEscape]'s and is not repeated here. All this does is undo
## the three things surrendering did to him: it plays the fall backwards, gives him
## his physics back, and lifts the refusal his own surrender put on that retreat -
## see [method EnemyEscape.reinstate].
##
## He is deliberately [i]not[/i] made an opponent again. See
## [member rejoins_enemy_group].
func stand_up() -> bool:
	if _standing_up or not _surrendered or not is_inside_tree():
		return false
	if _health != null and not _health.is_alive():
		return false

	var host := get_parent()
	if host == null:
		return false

	_standing_up = true
	set_process(false)
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	# Spent as he leaves, so the frame between him standing and him being out of
	# reach cannot be used to talk to a man who is already running.
	_used = true
	if is_in_group(GROUP):
		remove_from_group(GROUP)
	# The thanks go with him. Everything else he might have been saying is taken down
	# as he gets up, but the line he was given for being spared is the last thing the
	# player is meant to see of him, so it stays over his head while he runs and is
	# taken away with him - see [member keeps_bubble_while_fleeing].
	if not (_thanked and keeps_bubble_while_fleeing):
		_drop_bubble(bubble_leave_fade)

	_rise()
	_start_running(host)
	return true


## Whether he is on his feet or on his way there.
func is_standing_up() -> bool:
	return _standing_up


## The fall, played backwards to exactly where each piece started - see
## [method _fall], which recorded it. Eased out rather than in, because getting up
## is effortful at the start and quick at the end, which is the opposite shape to
## falling over.
func _rise() -> void:
	var duration := maxf(stand_time, 0.0001)
	for path: NodePath in fall_paths:
		var piece := get_node_or_null(path) as Node2D
		if piece == null:
			continue

		var rest: Dictionary = _fall_rest.get(piece.get_instance_id(), {})
		if rest.is_empty():
			continue

		var tween := piece.create_tween().set_parallel(true)
		tween.tween_property(piece, "rotation", float(rest["rotation"]),
			duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "position", rest["position"] as Vector2,
			duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Hands him back to the retreat, once he is upright.
##
## The walk is switched on with the rise rather than after it, so he is already
## moving as he comes up instead of standing still and then setting off - and the
## aim pivots are given back their processing so he can look where he is going.
func _start_running(host: Node) -> void:
	host.set_physics_process(true)
	if rejoins_enemy_group and not host.is_in_group(enemy_group):
		host.add_to_group(enemy_group)

	for node: Node in host.find_children("*", "LookAtTarget", true, false):
		node.set_physics_process(true)

	for node: Node in host.find_children("*", "EnemyEscape", true, false):
		var escape := node as EnemyEscape
		if escape == null:
			continue
		escape.reinstate()
		escape.escape(stand_time)


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame and anything else that wants to react to the player
## arriving can hang off the signals instead of repeating the distance test.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := _is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	if _in_reach:
		player_entered.emit()
	else:
		player_exited.emit()


func _is_in_reach(body: Node2D) -> bool:
	if _used or _standing_up or not _surrendered:
		return false
	if body == null or not body.is_in_group(body_group):
		return false

	var host := get_parent() as Node2D
	if host == null:
		return false
	return (host.global_position + reach_offset).distance_to(body.global_position) \
		<= interaction_radius


## Shooting a man who has given up is allowed, and this is the only thing that has
## to happen when it does: the E over the player's head goes away.
##
## The death itself needs nothing from here - [DeathFade] freezes and frees the body
## exactly as it does any other, and [BloodEmitter] pays out exactly as it does any
## other, because neither of them was ever told this enemy was different.
func _on_died() -> void:
	set_process(false)
	# Spent rather than merely closed, so nothing can interact with a corpse on the
	# frame between the shot landing and the body being taken away.
	_used = true
	_in_reach = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	if is_in_group(GROUP):
		remove_from_group(GROUP)
	# Given a moment to go rather than snatched off on the frame of the shot, for the
	# same reason an enraged man's is - see [member EnemyEnrage.death_bubble_fade].
	_drop_bubble(bubble_leave_fade)


func _unhandled_input(event: InputEvent) -> void:
	if not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	# Marked handled only when this enemy actually took the press, so a man who has
	# already been talked to does not swallow the key on behalf of whatever else the
	# player happens to be standing in front of.
	if use():
		get_viewport().set_input_as_handled()


## The bubble he is wearing goes with him.
##
## [b]Only when he is actually gone.[/b] A man who gets away is freed by
## [EnemyEscape] once he is off the screen, and this component is freed with him -
## at which point a line kept for his exit, see [member keeps_bubble_while_fleeing],
## has nobody left to hang over. Taken on the notification rather than in
## [method Node._exit_tree] because leaving the tree is also what a surrender does
## to him on the frame he is lifted out of the enemy container, and that must not
## take his line away. Being shot on the way out is [method _on_died]'s, which
## already fades it.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.dismiss(bubble_leave_fade)
	_bubble = null
