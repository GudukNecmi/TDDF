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

@onready var _head_pop: EnemyHeadPop = get_node_or_null(head_pop_path) as EnemyHeadPop
@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _surrendered: bool = false
var _in_reach: bool = false
## Whether the interaction has been spent. Set only by [method consume], never by
## [method use] itself, so a press that turned out to be worth nothing does not use
## the man up.
var _used: bool = false


func _ready() -> void:
	# Nothing to watch until there is somebody to walk up to.
	set_process(false)
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	if _health != null:
		_health.died.connect(_on_died)


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
	if drops_weapon and _head_pop != null:
		_head_pop.drop_knife()
	if stops_aiming:
		_stop_aiming(host)
	_fall(host)

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

	for path: NodePath in fall_paths:
		var piece := get_node_or_null(path) as Node2D
		if piece == null:
			continue

		# Read rather than assumed, so a piece the artist has already offset or
		# angled is turned from where it actually is.
		var rest := piece.position
		var landing := fall_pivot + (rest - fall_pivot).rotated(angle) + fall_offset

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


func _process(_delta: float) -> void:
	_watch_player()


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
	if _used or not _surrendered or body == null or not body.is_in_group(body_group):
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
