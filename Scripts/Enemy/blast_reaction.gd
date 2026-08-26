class_name BlastReaction
extends Node
## How somebody who is not the bomber behaves while a bomber is burning.
##
## [b]One component, two reactions, and the difference between them is a
## checkbox.[/b] An ordinary man panics: he turns and runs, faster than he walks,
## with his knife down and something to say about it, until he is far enough away
## to stop caring. Another bomber does not - it has business of its own and keeps
## to it - but it will not walk through the place that is about to go off either,
## so it takes the long way round. Both of those are the same two pieces of
## arithmetic pointed at the same ring, which is why they are not two files. See
## [member panics].
##
## [b]It is temporary, and it is temporary by construction.[/b] Nothing here takes
## a man out of the fight: the retreat is not [EnemyEscape] - which is permanent,
## drops his knife and eventually deletes him - it is [method Enemy.begin_charge]
## pointed away from the danger, which is the same walk the game already has at a
## different destination and a different pace, and [method Enemy.end_charge] gives
## it straight back. The knife comes back the same way. A man who has run from a
## blast is, a second later, an ordinary man walking at the player again.
##
## [b]He runs from a bomber exactly once.[/b] The moment he is outside the ring he
## ran out of, that ring stops being something he is afraid of and becomes something
## he cannot walk through - see [member locks_after_escape]. He gets his knife, his
## pace and his objective back immediately and goes after the player again; what he
## cannot do is take a line that crosses the circle, so he walks the outside edge of
## it round towards them instead. That is what stops the out-and-back-in loop the
## naive version has, where the ordinary chase drives a man who has just escaped
## straight back through the thing he escaped. The wall is dropped on the frame the
## fuse goes off.
##
## [b]Nothing is wired to a bomber.[/b] The threats are read out of
## [constant BomberFuse.THREAT_GROUP] - a fuse is in it for exactly as long as it is
## burning - so a corpse lying on the ground with a countdown on it is reacted to
## exactly as a bomber running at the player is, and a fuse that has gone off, or
## was never lit at all, is never seen by this.
##
## [b]The ring is not authored here.[/b] Every distance is a multiple of that
## fuse's own blast radius - see [method BomberFuse.get_threat_radius] - so retuning
## the explosion retunes what men do about it, and there is no second figure
## anywhere to keep in step.
##
## Bosses are excluded outright. See [member ignores_bosses].

## Emitted as this man starts running from [param threat].
signal panicked(threat: BomberFuse)
## Emitted as he stops and goes back to work.
signal calmed
## Emitted once he has got clear of [param threat] and its ring has become a place
## he will not walk into again.
signal locked_out(threat: BomberFuse)
## Emitted when he says something about it, with the line.
signal shouted(line: String)

## The body this drives. Its [method Enemy.begin_charge] is the retreat and its
## [method Enemy.set_attacks_enabled] is the knife going down.
@export var enemy_path: NodePath = ^".."
## How often the world is looked at for burning fuses, in seconds. It is a group
## lookup that finds nothing on all but a handful of frames in a run, so this is
## politeness rather than necessity.
@export var check_interval: float = 0.12

@export_group("Panic")
## Whether this man runs from a lit bomber at all.
##
## On for an ordinary Enemy1, which is the whole of the reaction the brief asks
## for. [b]Off for a bomber[/b], which keeps its objective and only routes around
## the danger - see [member safety_radius_scale]. Off is not immunity: a bomber
## standing in another one's blast is caught by it exactly as anybody else is.
@export var panics: bool = true
## How far away he has to get before he stops running, as a multiple of the blast's
## own radius.
@export var panic_radius_scale: float = 2.2
## What running multiplies his walk by.
@export var panic_speed_multiplier: float = 1.4
## How far ahead the retreat is aimed, in pixels. It is re-aimed every frame, so
## this only has to be far enough that he is always running at somewhere rather
## than arriving.
@export var run_distance: float = 480.0
## How far off straight-back the retreat is aimed, in degrees either way, rolled
## once as he starts running.
##
## [b]Rolled once per bomber rather than per frame.[/b] A crowd all running on the
## exact radial line leaves in a star, which reads as one animation played several
## times; a man given his own angle at the moment he turns leaves in his own
## direction and keeps it. 0 runs straight back, which is what it did before.
@export_range(0.0, 89.0) var escape_spread_degrees: float = 45.0
## Whether his knife goes down while he runs. On: a man sprinting away from
## dynamite is not stopping to stab anybody, and it is handed straight back
## afterwards.
@export var suppresses_attack: bool = true
## Whether he is stopped from giving up while he runs.
##
## [b]A man running from a blast must not surrender in the middle of it.[/b] It is
## done by holding [member EnemySurrender.gives_up_on_its_own] down for the length
## of the panic and putting it back exactly as it was, so nothing about how
## surrendering works is touched and a man who was never going to give up anyway is
## unaffected.
@export var suppresses_surrender: bool = true

@export_group("The wall")
## Whether getting clear of a bomber turns its ring into somewhere he will not walk
## back into for as long as it is burning.
##
## [b]This is what stops him bouncing.[/b] Without it a man leaves the ring, the
## ordinary chase points him at the player again, the player is on the far side of
## the bomber, and he walks straight back in and panics a second time - out, in,
## out, in, for the whole three seconds. With it he escapes exactly once, and from
## that moment the circle is a wall rather than a thing to be afraid of: he keeps
## his knife, keeps his speed, keeps going after the player, and simply cannot pass
## through it. It is removed the instant the fuse goes off, because a spent fuse is
## not a threat and there is nothing left to walk around.
@export var locks_after_escape: bool = true
## The ring he is held outside of once he is locked out, as a multiple of the
## blast's own radius.
##
## Below 0 - the default - uses [member panic_radius_scale], so the circle he is
## kept out of is by construction the circle he ran out of and there is no second
## figure to keep in step with it.
@export var lock_radius_scale: float = -1.0
## How far outside the ring the wall starts to turn him, in pixels. A little, so he
## grazes the edge of it rather than jittering on the line itself.
@export var wall_margin: float = 10.0
## How hard he is walked back out if he ends up inside the ring anyway - shouldered
## in by the crowd, or knocked in - as a fraction of his walk at the centre.
@export var wall_push: float = 1.6

@export_group("Detour")
## The ring nobody walks into while a fuse is burning inside it, as a multiple of
## the blast's radius.
##
## [b]This is the avoidance, and both kinds of man use it.[/b] For a bomber it is
## the whole reaction - it keeps its objective and bends its path round the edge of
## the danger. For a panicking man it is what stops him walking back through the
## body he just ran away from once he has calmed down.
@export var safety_radius_scale: float = 1.3
## How hard the path is bent at the very edge of the ring. Higher goes further out
## of its way.
@export var detour_strength: float = 1.7
## How much of the bend is straight outwards rather than round the side. A little,
## so a man pressed right up against the danger backs off it as well as walking
## round it; mostly round the side, because backing straight off is standing still.
@export_range(0.0, 2.0) var detour_outward: float = 0.45
## Whether the detour keeps applying once the panic is over.
##
## On, and it should be: the brief's own case - a man must not try to walk through
## a lying bomber - happens on the way [i]back[/i] as much as on the way out. It
## still ends at the explosion, because a spent fuse is not a threat.
@export var detours_while_calm: bool = true
## Steering this one wraps, asked first and handed the result. This is how a bomber
## keeps its wobble: [BomberSway] bends the walk, and then the detour bends whatever
## the sway decided. Left unset the enemy's own chase is bent directly.
@export var inner_steering_path: NodePath

@export_group("Getting stuck")
## How slowly he has to be actually moving to count as caught on something, in
## pixels per second.
@export var stuck_speed: float = 20.0
## How long he has to be that slow before the retreat is turned. The world has no
## navigation mesh - the men walk at things and slide off them - so a man running
## into a wagon is unwedged by aiming him somewhere else rather than by planning a
## route around it.
@export var stuck_time: float = 0.3
## How far the retreat is turned each time that happens, in degrees, signed at
## random.
@export var stuck_turn_degrees: float = 65.0
## How quickly the turn unwinds once he is moving again, in degrees per second, so
## he ends up running straight away from the blast rather than off at whatever
## angle got him free.
@export var stuck_unwind_degrees: float = 90.0

@export_group("Speech")
## The bubble. The same one everybody in the game speaks in - see [SpeechBubble] -
## so nothing about how a line looks, follows, points or fades is written twice.
## Left unset he runs silently.
@export var bubble_scene: PackedScene
## What he might shout. A list, so adding one is adding one in the Inspector.
@export var lines: PackedStringArray = []
## Chance he says anything at all about a given bomber, rolled once as he starts
## running - one roll per threat, which is the rule every other chance-driven
## effect in the game follows.
@export_range(0.0, 1.0, 0.01) var speech_chance: float = 1.0
## Where the bubble hangs relative to his origin at his feet.
@export var bubble_offset := Vector2(46.0, -96.0)
## How large it is drawn. Small: this is a man yelling as he runs.
@export var bubble_scale: float = 0.34
## How long it stays up, and how long it then takes to fade.
@export var bubble_hold: float = 1.3
@export var bubble_fade: float = 0.3

@export_group("Exclusions")
## Whether a mini boss is left out of all of this.
##
## [b]On, and the brief is explicit about it.[/b] A boss does not flee, does not
## stop fighting, does not shout and does not take the speed. He is found by
## [method MiniBoss.find_on] rather than by a flag set here, so a boss built out of
## an ordinary enemy at spawn time - which is how every boss in the game is built -
## is excluded without the spawner knowing this component exists.
@export var ignores_bosses: bool = true

@onready var _enemy: Node = get_node_or_null(enemy_path)
@onready var _inner: Node = get_node_or_null(inner_steering_path)

var _threats: Array[BomberFuse] = []
var _threat: BomberFuse
var _panicking: bool = false
var _since_check: float = 0.0
var _turn: float = 0.0
## The angle his retreat is offset by, rolled once as he turns to run so a crowd
## does not leave in a star.
var _escape_turn: float = 0.0
## Rings he has already got clear of, by fuse instance id, mapped to the way round
## he committed to going - 0 until the wall first bites and he picks a side.
##
## [b]A man in here is finished being afraid of that bomber.[/b] He no longer panics
## about it, no longer runs from it and no longer says anything about it; the ring is
## simply somewhere his walk cannot go. Entries are dropped as their fuses go off.
var _locked: Dictionary = {}
## Fuses he has actually run from, so a ring can only become a wall after it has
## been escaped rather than the moment it is noticed.
var _ran_from: Dictionary = {}
var _stuck_for: float = 0.0
var _last_seen_at := Vector2.ZERO
var _last_seen: bool = false
## Threats this man has already had his say about, by instance id, so one bomber is
## worth one line however long he runs from it.
var _spoken_about: Dictionary = {}
## What his surrender was set to before the panic took it away.
var _surrender_was: bool = true
var _surrender_held: bool = false


func _physics_process(delta: float) -> void:
	_since_check += delta
	if _since_check >= maxf(check_interval, 0.01):
		_since_check = 0.0
		_look_around()
	else:
		# On every frame between looks, in case the one he is running from went off
		# during one of them.
		_forget_the_dead()
	if _panicking:
		_run(delta)


## Whether this man is running from a bomber right now.
func is_panicking() -> bool:
	return _panicking


## The bomber he is running from, or null.
func get_threat() -> BomberFuse:
	return _threat


## Whether this man has already got clear of [param threat] and is now simply walled
## out of it. Public so the state can be read - or asserted - without waiting to see
## which way he walks.
func is_locked_out_of(threat: BomberFuse) -> bool:
	return threat != null and is_instance_valid(threat) \
		and _locked.has(threat.get_instance_id())


## How many rings this man is currently walled out of.
func get_locked_out_count() -> int:
	return _locked.size()


## The walk, bent round anything that is about to go off.
##
## [b]It is the enemy's one steering hook and nothing else[/b] - see
## [member Enemy.steering_path]. Whatever was going to be walked in comes in,
## whatever should be walked in goes out, and everything after that point - the
## separation from the crowd, the knockback, the world's slow motion - is untouched.
## A wrapped component is asked first, so a bomber's wobble happens and then the
## detour bends the result rather than replacing it.
func steer(chase: Vector2, delta: float) -> Vector2:
	var walk := chase
	if _inner != null and _inner.has_method(&"steer"):
		walk = _inner.steer(chase, delta)

	_forget_the_dead()
	if _threats.is_empty():
		return walk

	var host := _enemy as Node2D
	if host == null:
		return walk
	var from := host.global_position

	# The soft detour is only for a ring he has not been locked out of yet, and only
	# while he is not already running from one: bending a retreat sideways is what
	# would make him circle the thing instead of leaving it.
	if not _panicking and detours_while_calm:
		walk = _bend(walk, from)

	# The wall is applied last and applies always, because it is the one thing that
	# has to hold whatever else he is doing.
	return _keep_out(walk, from)


## Holds [param walk] outside every ring this man has already escaped.
##
## [b]It is a wall, not a fear.[/b] Whatever he wanted to do is kept exactly as it
## was except for the part of it that pointed into the circle, which is taken off -
## so a man whose player is on the far side of a burning bomber walks the edge of
## the circle round towards them instead of either crossing it or turning back. He
## is not slowed, he is not disarmed and he is not sent anywhere; he is only refused
## one direction, which is what makes this the temporary obstacle the brief asks for
## rather than a second retreat.
##
## The way round is picked the first time the wall actually bites and then kept, so
## he commits to going one way round rather than dithering at the front of it.
func _keep_out(walk: Vector2, from: Vector2) -> Vector2:
	if _locked.is_empty():
		return walk

	var kept := walk
	for fuse: BomberFuse in _threats:
		if not is_instance_valid(fuse) or fuse.has_detonated():
			continue
		var id := fuse.get_instance_id()
		if not _locked.has(id):
			continue
		var ring := _wall_ring(fuse)
		if ring <= 0.0:
			continue

		var to_centre := fuse.global_position - from
		var gap := to_centre.length()
		if gap > ring + maxf(wall_margin, 0.0) or gap <= 0.001:
			continue

		var out := -to_centre / gap
		# The part of the walk that goes into the circle, removed. What is left is the
		# part along the edge, which is the path round it.
		var inward := kept.dot(out)
		if inward < 0.0:
			kept -= out * inward

		# Facing dead centre leaves nothing along the edge to keep, so he is given the
		# side he committed to - and commits now if this is the first time.
		if kept.is_zero_approx():
			var side := float(_locked[id])
			if is_zero_approx(side):
				side = 1.0 if randf() < 0.5 else -1.0
				_locked[id] = side
			kept = Vector2(-out.y, out.x) * side
		elif is_zero_approx(float(_locked[id])):
			_locked[id] = 1.0 if Vector2(-out.y, out.x).dot(kept) >= 0.0 else -1.0

		# Inside it despite all of that - shouldered in by the crowd, or locked out
		# while pressed against it - and he is walked back out as well as along.
		if gap < ring:
			kept += out * maxf(wall_push, 0.0) * clampf(1.0 - gap / ring, 0.0, 1.0)

		if not kept.is_zero_approx():
			kept = kept.normalized()
	return kept


## The ring a locked-out man is held outside of, for [param fuse].
func _wall_ring(fuse: BomberFuse) -> float:
	var scale := lock_radius_scale if lock_radius_scale >= 0.0 else panic_radius_scale
	return fuse.get_threat_radius() * maxf(scale, 0.0)


## Turns every ring this man has run from and is now outside of into a wall.
##
## [b]It is what ends the panic for good rather than for a moment.[/b] Leaving the
## circle is the last time he is allowed to be afraid of that bomber: from here he
## is an ordinary man again in every respect except that one direction is closed to
## him, so there is no state left that could send him running a second time.
func _lock_what_he_has_cleared() -> void:
	if not locks_after_escape or _ran_from.is_empty():
		return
	var host := _enemy as Node2D
	if host == null:
		return

	for fuse: BomberFuse in _threats:
		if not is_instance_valid(fuse) or fuse.has_detonated():
			continue
		var id := fuse.get_instance_id()
		if _locked.has(id) or not _ran_from.has(id):
			continue
		var ring := _wall_ring(fuse)
		if ring <= 0.0 or host.global_position.distance_to(fuse.global_position) <= ring:
			continue

		# 0 rather than a side: which way round he goes is not known until his walk
		# next meets the wall, and picking it here would be picking it blind.
		_locked[id] = 0.0
		locked_out.emit(fuse)


## Puts a line up. Public so a test - or anything else - can ask for one without
## reproducing the panic. The bubble goes into the running scene rather than onto
## the man, so it keeps hanging in the air while he is shot, knocked about or blown
## up underneath it, exactly as every other bubble in the game does.
func say(line: String) -> void:
	if bubble_scene == null or line.is_empty() or not is_inside_tree():
		return
	var subject := _enemy as Node2D
	if subject == null:
		return

	var keeper: Node = get_tree().current_scene
	if keeper == null:
		keeper = subject.get_parent()
	if keeper == null:
		return

	var bubble := bubble_scene.instantiate() as SpeechBubble
	if bubble == null:
		return

	bubble.head_offset = bubble_offset
	bubble.bubble_scale = bubble_scale
	keeper.add_child(bubble)
	bubble.global_position = subject.global_position + bubble_offset
	bubble.set_subject(subject)
	bubble.show_bubble(line)
	shouted.emit(line)

	if bubble_hold > 0.0:
		var timer := get_tree().create_timer(bubble_hold, true, false, true)
		timer.timeout.connect(_fade.bind(bubble, bubble_fade))


## Drops anything from the cache that has gone since the cache was taken.
##
## [b]The cache is always a frame or two out of date, by construction.[/b] The
## world is looked at once every [member check_interval] and the walk is steered
## every single frame, and a fuse frees itself on the instant it goes off - so
## between one look and the next an entry can turn into a freed instance, and a
## bomber shot on its way in leaves one behind the moment its blast arrives.
##
## Nothing in here may touch one of those, so they are cleared out at the top of
## both readers rather than guarded at each use. A man whose threat has gone stops
## avoiding it on that frame and walks normally again, which is the correct answer
## anyway: there is nothing left to walk around.
##
## [b]It only forgets.[/b] Nothing about the bomber itself is reached into - a fuse
## already burning keeps its countdown, its sound and its blast whatever this
## decides, because that countdown is a scene tree timer that belongs to the fuse
## and not to anybody watching it.
func _forget_the_dead() -> void:
	var live: Array[BomberFuse] = []
	for i: int in _threats.size():
		var entry: Variant = _threats[i]
		if not is_instance_valid(entry):
			continue
		var fuse := entry as BomberFuse
		if fuse != null and not fuse.has_detonated():
			live.append(fuse)

	if live.size() != _threats.size():
		_threats = live

	# A wall only exists while the fuse inside it is burning. Dropping the book
	# entry here is the whole of "once the bomber explodes, remove the temporary
	# forbidden area" - the ring is gone on the frame the blast happens and the man
	# is walking normally again on the next one.
	_forget_the_gone(live)

	if _threat == null:
		return
	if is_instance_valid(_threat) and not _threat.has_detonated():
		return

	# The one he was running from is gone. He is put back to work here rather than
	# waiting for the next look, so there is never a frame on which he is running
	# from nothing.
	_threat = null
	if _panicking:
		_stop()


## Drops every locked ring and every memory of running whose fuse is no longer among
## [param live].
##
## Keyed by instance id rather than by the fuse itself, so nothing in either book is
## ever a reference to something that has been freed - which is why this can be a
## comparison against the live list rather than a validity check on a held pointer.
func _forget_the_gone(live: Array[BomberFuse]) -> void:
	if _locked.is_empty() and _ran_from.is_empty():
		return

	var still_burning: Dictionary = {}
	for fuse: BomberFuse in live:
		still_burning[fuse.get_instance_id()] = true

	for id: int in _locked.keys():
		if not still_burning.has(id):
			_locked.erase(id)
	for id: int in _ran_from.keys():
		if not still_burning.has(id):
			_ran_from.erase(id)


## One look at the world: who is burning, and whether that changes anything.
func _look_around() -> void:
	_threats = _threats_worth_minding()
	_lock_what_he_has_cleared()

	if not panics or _is_a_boss():
		if _panicking:
			_stop()
		return

	var nearest := _nearest_threat(panic_radius_scale)
	if nearest == null:
		if _panicking:
			_stop()
		return

	_threat = nearest
	if not _panicking:
		_start(nearest)


## Every fuse burning in the world except this man's own, which he is standing on
## top of and can do nothing about.
func _threats_worth_minding() -> Array[BomberFuse]:
	var kept: Array[BomberFuse] = []
	for fuse: BomberFuse in BomberFuse.get_threats(self):
		if _enemy != null and fuse.get_body() == _enemy:
			continue
		kept.append(fuse)
	return kept


## The closest fuse whose ring this man is inside, measuring the ring at
## [param scale] times that fuse's own blast radius.
func _nearest_threat(scale: float) -> BomberFuse:
	var host := _enemy as Node2D
	if host == null:
		return null

	var closest: BomberFuse = null
	var closest_gap := INF
	for fuse: BomberFuse in _threats:
		if not is_instance_valid(fuse) or fuse.has_detonated():
			continue
		# A ring he has already got out of is a wall now, not something to run from.
		# This is the line that makes the escape happen exactly once.
		if _locked.has(fuse.get_instance_id()):
			continue
		var ring := fuse.get_threat_radius() * maxf(scale, 0.0)
		if ring <= 0.0:
			continue
		var gap := host.global_position.distance_to(fuse.global_position)
		if gap > ring or gap >= closest_gap:
			continue
		closest = fuse
		closest_gap = gap
	return closest


func _start(threat: BomberFuse) -> void:
	_panicking = true
	_turn = 0.0
	_stuck_for = 0.0
	_last_seen = false
	_escape_turn = deg_to_rad(randf_range(-escape_spread_degrees, escape_spread_degrees))
	if threat != null and is_instance_valid(threat):
		_ran_from[threat.get_instance_id()] = true

	if suppresses_attack and _enemy != null and _enemy.has_method(&"set_attacks_enabled"):
		_enemy.call(&"set_attacks_enabled", false)
	_hold_surrender()
	_maybe_speak(threat)
	panicked.emit(threat)


## Everything the panic took is given back here, and only here, so there is one
## place to read to know that nothing is left switched off.
func _stop() -> void:
	if not _panicking:
		return
	_panicking = false
	_threat = null
	_turn = 0.0

	if _enemy != null and _enemy.has_method(&"end_charge"):
		_enemy.call(&"end_charge")
	if suppresses_attack and _enemy != null and _enemy.has_method(&"set_attacks_enabled"):
		_enemy.call(&"set_attacks_enabled", true)
	_release_surrender()
	calmed.emit()


## One frame of running. The destination is recomputed rather than remembered,
## because the thing he is running from can be a bomber that is still moving.
func _run(delta: float) -> void:
	var host := _enemy as Node2D
	if host == null or _threat == null or not is_instance_valid(_threat) \
			or _threat.has_detonated():
		_stop()
		return
	if not _enemy.has_method(&"begin_charge"):
		return

	var away := (host.global_position - _threat.global_position).normalized()
	if away.is_zero_approx():
		away = Vector2.RIGHT.rotated(randf() * TAU)

	_watch_for_wedging(host, delta)
	var heading := away.rotated(_escape_turn + _turn)
	_enemy.call(&"begin_charge",
		host.global_position + heading * maxf(run_distance, 1.0),
		maxf(panic_speed_multiplier, 0.0))


## The world has no navigation mesh, so a man who has run into a wagon is unwedged
## rather than routed: if he has barely moved for a moment, the retreat is turned by
## a random amount and he tries that instead. The turn unwinds again as soon as he is
## moving, so he comes back to running straight away from the blast.
func _watch_for_wedging(host: Node2D, delta: float) -> void:
	var here := host.global_position
	if not _last_seen:
		_last_seen = true
		_last_seen_at = here
		return

	var moved := here.distance_to(_last_seen_at)
	_last_seen_at = here

	if moved < maxf(stuck_speed, 0.0) * delta:
		_stuck_for += delta
		if _stuck_for >= maxf(stuck_time, 0.05):
			_stuck_for = 0.0
			var side := 1.0 if randf() < 0.5 else -1.0
			_turn += deg_to_rad(stuck_turn_degrees) * side
		return

	_stuck_for = 0.0
	_turn = move_toward(_turn, 0.0, deg_to_rad(stuck_unwind_degrees) * delta)


## Bends [param walk] round every ring this man is standing inside.
##
## Mostly sideways rather than straight back: walking round the edge of the danger
## keeps him going where he was going, where backing straight off is standing still.
## The side is chosen to match the way he was already heading, so he takes the
## shorter way round rather than crossing the front of it.
func _bend(walk: Vector2, from: Vector2) -> Vector2:
	var bent := walk
	for fuse: BomberFuse in _threats:
		# Guarded again here as well as at the top of the frame, so this can never
		# reach a freed fuse however it came to be holding one.
		if not is_instance_valid(fuse) or fuse.has_detonated():
			continue
		# A locked ring is held by the wall instead, which is hard where this is soft.
		if _locked.has(fuse.get_instance_id()):
			continue
		var ring := fuse.get_threat_radius() * maxf(safety_radius_scale, 0.0)
		if ring <= 0.0:
			continue
		var to_threat := fuse.global_position - from
		var gap := to_threat.length()
		if gap > ring or gap <= 0.001:
			continue

		var away := -to_threat / gap
		var tangent := Vector2(-away.y, away.x)
		if away.cross(bent) < 0.0:
			tangent = -tangent

		var closeness := clampf(1.0 - gap / ring, 0.0, 1.0)
		var pushed := bent + (tangent + away * detour_outward) * detour_strength * closeness
		if not pushed.is_zero_approx():
			bent = pushed.normalized()
	return bent


## One roll, once per bomber. A man who has already had his say about this one runs
## the rest of the way in silence rather than shouting every time it comes back into
## range.
func _maybe_speak(threat: BomberFuse) -> void:
	if threat == null or lines.is_empty() or bubble_scene == null:
		return
	var id := threat.get_instance_id()
	if _spoken_about.has(id):
		return
	_spoken_about[id] = true
	if randf() >= speech_chance:
		return
	say(lines[randi() % lines.size()])


func _hold_surrender() -> void:
	if not suppresses_surrender or _surrender_held:
		return
	var give_up := _find_surrender()
	if give_up == null:
		return
	_surrender_was = give_up.gives_up_on_its_own
	give_up.gives_up_on_its_own = false
	_surrender_held = true


func _release_surrender() -> void:
	if not _surrender_held:
		return
	_surrender_held = false
	var give_up := _find_surrender()
	if give_up != null:
		give_up.gives_up_on_its_own = _surrender_was


func _find_surrender() -> EnemySurrender:
	if _enemy == null:
		return null
	for node: Node in _enemy.find_children("*", "EnemySurrender", true, false):
		var give_up := node as EnemySurrender
		if give_up != null:
			return give_up
	return null


## Whether this man is the one on the poster. Asked each time rather than once at
## start-up, because the component that makes him a boss is added to an ordinary
## enemy after it has been built.
func _is_a_boss() -> bool:
	return ignores_bosses and _enemy != null and MiniBoss.find_on(_enemy) != null


func _fade(bubble: SpeechBubble, fade: float) -> void:
	if bubble != null and is_instance_valid(bubble):
		bubble.dismiss(fade)
