class_name BomberFuse
extends Node2D
## The three seconds between a bomber lighting itself and going off, and the two
## sparks burning on its sides while it does.
##
## [b]Nothing stops it once it is lit.[/b] The countdown is a scene tree timer, so
## it is not the bomber's to cancel: killing the bomber after it has committed
## buys the player a corpse on the floor and three seconds, not a defused bomb.
## Killing it [i]before[/i] it commits is an ordinary Bandit death and this
## component never wakes up at all - which is the whole of the difference between
## the two deaths the brief asks for, and it is one flag.
##
## [b]The fuse outlives the body.[/b] On a death after ignition it lifts itself
## out of the enemy and into the running scene, keeping its world position and
## carrying its sparks with it, because the corpse is about to be frozen, faded
## and freed by [DeathFade] and the fuse is supposed to survive all three. The
## corpse is held on the ground for the rest of the countdown at the same time -
## see [method _hold_the_corpse] - so the body is still lying there when it goes.
##
## [b]The sparks are built from an array, not authored.[/b] One sprite per point
## in [member ignition_points], cycling [member ignite_textures] in order and
## offset from side to side so the two are never on the same frame. A fifth frame
## is dropping a PNG into the array; a third fuse is dropping a [Vector2] into the
## other one. Nothing in this file names either.
##
## The explosion itself is not here. It is [Explosion], a scene of its own, so the
## same blast can later be hung on a barrel, a keg or a stick of dynamite the
## player throws without a bomber being involved.

## Emitted as the fuse is lit.
signal ignited
## Emitted as it goes off, at the point it went off at.
signal detonated(at: Vector2)

## Group a fuse joins for exactly as long as it is burning.
##
## [b]This is how everybody else in the arena finds out.[/b] A lit bomber is a
## place that is about to become dangerous, and every reaction to it - a man
## running, a man walking round it, another bomber going off in sympathy - starts
## by asking the tree who is in this group. Nothing is wired to a bomber and
## nothing has to be told when one dies: an unlit fuse is not in it, and a spent
## one has already left. See [method get_threats].
const THREAT_GROUP := &"blast_threats"

## Seconds from ignition to detonation. It runs on the scene tree, so a death, a
## freeze or a fade cannot shorten or stop it.
@export var fuse_seconds: float = 3.0
## The blast. Left unset the fuse burns down and the bomber simply dies, which is
## a bomber with its explosion switched off rather than a broken one.
@export var explosion_scene: PackedScene

@export_group("Sparks")
## The ignition frames, cycled in order. Any number of them.
@export var ignite_textures: Array[Texture2D] = []
## The artwork the sparks are pinned to - the node the dynamite is drawn on, not the
## body's origin.
##
## [b]This is what keeps them on the ends of the ropes.[/b] The sparks are children
## of it, so every single thing that moves the artwork moves them with it: the hop,
## the tilt into the drift, the roll through a hop, the squash of the idle, and the
## body going down when the bomber is killed. Hung on the fuse instead - which is
## where they were - they sit at fixed offsets from the body's origin and are left
## behind by all of it, which is the bug of the two fires burning in mid-air over a
## corpse that has fallen out from under them.
##
## The fuse itself still lifts out of the corpse when the bomber dies, because the
## countdown, the burning sound and the point the blast happens at all have to
## survive the body - see [method _detach]. The sparks deliberately do not go with
## it: their whole job is to be on the body, and the body is held on the ground for
## the rest of the countdown anyway - see [method _hold_the_corpse] - so it is still
## there underneath them right up to the moment it goes.
##
## Left unresolved they fall back to the fuse, which is the old behaviour rather
## than a broken one.
@export var spark_parent_path: NodePath = ^"../Visual"
## Where the sparks sit on that artwork, in its own local space - one per fuse. The
## concept has two, one on each side.
@export var ignition_points: Array[Vector2] = [
	Vector2(-17.4, -35.1),
	Vector2(15.4, -35.1),
]
## Seconds one frame is held. Short: this is a fuse catching, not a slow burn.
@export var frame_seconds: float = 0.055
## How far the second fuse is pushed through the cycle relative to the first, as a
## fraction of one frame's worth of the whole loop - which is what makes the two
## sides alternate rather than flash together. Applied per point in turn, so a
## third fuse lands a third of the way round on its own.
@export_range(0.0, 1.0) var side_offset: float = 0.5
## What a spark is drawn at.
@export var ignite_scale: float = 0.13
## Colour the sparks are drawn in. Above 1 on a channel burns brighter than the
## artwork, which is what keeps a fuse readable against a lit background.
@export var ignite_modulate := Color(1.35, 1.1, 0.85)
## Drawing order for the sparks, so they sit over the body rather than inside it.
@export var ignite_z_index: int = 3

@export_group("Sound")
## The fuse burning, a voice of this node's own.
##
## [b]It is a child of the fuse on purpose.[/b] Everything that makes the
## countdown survive a death makes the sound survive it too: the fuse lifts itself
## out of the corpse - see [method _detach] - and its voice goes with it, still
## playing, still at the point on the ground the body is lying on. So a bomber shot
## after it has lit itself is heard burning down on the sand exactly as long as it
## is seen burning down.
##
## Left unresolved the fuse is silent, which is a bomber with its sound switched
## off rather than a broken one.
@export var fuse_sound_path: NodePath = ^"FuseSound"
## Whether the burn is started again each time the recording runs out. On, so a
## [member fuse_seconds] longer than the recording is covered by it rather than
## going quiet half way down.
@export var fuse_sound_loops: bool = true

@export_group("The threat")
## How far the blast this fuse is holding will actually reach, in pixels.
##
## [b]It is not authored here.[/b] Below 0 - the default - the figure is read off
## [member explosion_scene]'s own [member Explosion.damage_radius] the first time
## anything asks, and cached against that scene for the rest of the run, so the
## radius everybody avoids is by construction the radius that hurts. Retuning the
## blast retunes the panic, the detour and the chain with it, and there is no
## second number anywhere to keep in step.
##
## A value of 0 or more overrides that, for a fuse whose danger is deliberately not
## the same size as its damage.
@export var threat_radius: float = -1.0

@export_group("The corpse")
## The pool watched for the death that must not put the fuse out.
@export var health_path: NodePath = ^"../Health"
## The fade held off while a lit corpse waits to go off. Left unresolved the fuse
## still detonates on time; the body simply fades out from under it first.
@export var death_fade_path: NodePath = ^"../DeathFade"
## How long after the blast the body is given before it is freed. Kept at 0
## because the brief is explicit that the body disappears the instant it goes.
@export var corpse_linger: float = 0.0

@onready var _health: Health = get_node_or_null(health_path) as Health

## Blast radius by explosion scene, read once per scene and shared by every fuse
## carrying it - so a hundred bombers cost one instantiation between them.
static var _radius_by_scene: Dictionary = {}

var _lit: bool = false
var _spent: bool = false
var _sparks: Array[Sprite2D] = []
var _frame: float = 0.0
## The body this fuse came off, held once the fuse has been lifted out of it so
## the blast can take it with it.
var _corpse: Node
## When the countdown ends, on the scene tree's own clock, so a fuse that has been
## reparented and frozen and thawed still knows how much of itself is left.
var _due_at: float = 0.0


func _ready() -> void:
	# The sparks are not built until the fuse is lit: an unlit bomber must look
	# exactly like an unlit bomber, and most of them die that way.
	if _health != null:
		_health.died.connect(_on_died)


## Lights it. The countdown starts now and cannot be stopped; calling this twice
## does nothing the second time.
func ignite() -> void:
	if _lit or _spent:
		return
	_lit = true
	_due_at = _now() + maxf(fuse_seconds, 0.0)

	add_to_group(THREAT_GROUP)
	_build_sparks()
	_burn()
	_start_burning_sound()
	ignited.emit()

	# On the scene tree rather than on this node, and set to run while the tree is
	# paused, for the same reason every other transition in the game is: a fuse lit
	# on the frame a menu opens must still finish.
	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(maxf(fuse_seconds, 0.0), true, false, true)
	timer.timeout.connect(detonate)


## Whether this bomber has lit itself. The one flag that tells the two deaths
## apart: false is an ordinary Bandit death, true is a corpse with a countdown on
## it.
func is_lit() -> bool:
	return _lit


func has_detonated() -> bool:
	return _spent


## Seconds left on the fuse. 0 once it is out or before it is lit.
func get_time_left() -> float:
	if not _lit or _spent:
		return 0.0
	return maxf(_due_at - _now(), 0.0)


## Goes off, now. Called by the countdown, and called early by [BomberAttack] when
## a lit bomber reaches the player - which is the whole of "do not wait for another
## timer once the charge arrives".
func detonate() -> void:
	if _spent:
		return
	_spent = true

	var at := global_position
	# Out of the group before anything else, so the chain this blast is about to
	# set off cannot find its own source still listed as a live threat.
	if is_in_group(THREAT_GROUP):
		remove_from_group(THREAT_GROUP)
	_clear_sparks()
	_stop_burning_sound()
	_blast(at)
	detonated.emit(at)
	_take_the_body_away()
	queue_free()


## Sets this bomber off because something else has already gone off on top of it.
##
## [b]A chain does not start a countdown - it skips one.[/b] A bomber caught in a
## blast goes with it, on that frame, whatever it was doing a moment earlier:
## walking, already running, already burning, or standing there having decided
## nothing. Waiting out its own three seconds would turn a chain into a queue.
##
## An unlit bomber is lit silently here rather than through [method ignite],
## because everything ignition starts - the sparks, the burn, the scream - would
## have exactly one frame to exist before this took it away again.
##
## Everything past that point is the ordinary detonation, so a chained bomber is
## worth the same [Explosion]: the same damage, boom, gore, blood, mark, smoke and
## camera, and the same chain again out of it to whatever this one lands on.
func chain_detonate() -> void:
	if _spent:
		return
	if not _lit:
		_lit = true
		_due_at = _now()
	detonate()


## How far this fuse's blast reaches, in pixels - the ring every reaction to it is
## measured against. See [member threat_radius].
func get_threat_radius() -> float:
	if threat_radius >= 0.0:
		return threat_radius
	if explosion_scene == null:
		return 0.0

	var key := explosion_scene.resource_path
	if key.is_empty():
		key = str(explosion_scene.get_instance_id())
	if _radius_by_scene.has(key):
		return float(_radius_by_scene[key])

	# Read off the scene rather than named as a type, so the fuse depends on the
	# blast's file and the blast on the fuse's without the two forming a cycle.
	var measured := 0.0
	var sample := explosion_scene.instantiate()
	if sample != null:
		var reach: Variant = sample.get(&"damage_radius")
		if reach != null:
			measured = maxf(float(reach), 0.0)
		sample.free()
	_radius_by_scene[key] = measured
	return measured


## The body this fuse is burning on - the bomber while it is alive, and the corpse
## once the fuse has been lifted clear of one.
func get_body() -> Node2D:
	if _corpse != null and is_instance_valid(_corpse):
		return _corpse as Node2D
	return get_parent() as Node2D


## Every fuse burning in the world right now. Empty on all but a handful of frames
## in a run, which is why every caller is free to ask for it outright.
static func get_threats(from_node: Node) -> Array[BomberFuse]:
	var found: Array[BomberFuse] = []
	if from_node == null or not from_node.is_inside_tree():
		return found
	for node: Node in from_node.get_tree().get_nodes_in_group(THREAT_GROUP):
		var fuse := node as BomberFuse
		if fuse != null and is_instance_valid(fuse) and not fuse.has_detonated():
			found.append(fuse)
	return found


## The death that does not put it out.
##
## [b]Order matters here, and the scene is what guarantees it.[/b] This node sits
## above [DeathFade] among the enemy's children, so its own [method Node._ready]
## runs first, so it is connected to [signal Health.died] first, so this runs
## before the fade has read its own timings - which is what lets the corpse be
## held below. Moving it under the fade would leave the body fading out on time
## and the blast going off over an empty patch of sand.
func _on_died() -> void:
	if not _lit or _spent:
		return
	_hold_the_corpse()
	# Deferred because a death very often arrives from inside the physics server's
	# own overlap callback, where moving a node between parents is refused.
	_detach.call_deferred()


## Keeps the body on the ground until the blast takes it. The fade is not switched
## off - the corpse still tints, still fades and still frees itself - it is only
## told to wait, so nothing about how a body disappears is written twice.
func _hold_the_corpse() -> void:
	var fade := get_node_or_null(death_fade_path) as DeathFade
	if fade == null:
		return
	fade.hold_time = maxf(get_time_left() + corpse_linger, 0.0)


## Lifts the fuse out of the corpse and into the running scene, at exactly the world
## position it had, so the countdown, the burning sound and the point the blast
## happens at all survive the body being frozen and freed.
##
## The sparks are not carried with it. They belong to the artwork - see
## [member spark_parent_path] - and the body they are on is held down for the rest of
## the countdown, so they stay on the ends of the ropes on the fallen bomber instead
## of hanging in the air where it was standing when it was shot.
func _detach() -> void:
	if _spent or not is_inside_tree():
		return
	var container := get_tree().current_scene
	if container == null or get_parent() == container:
		return

	var voice := get_node_or_null(fuse_sound_path) as AudioStreamPlayer2D
	var heard_up_to := voice.get_playback_position() if voice != null else 0.0

	_corpse = get_parent()
	reparent(container, true)
	reset_physics_interpolation()

	# A node taken out of the tree has its playback stopped, and a reparent is a
	# removal and an addition. The burn is picked up again from exactly where it
	# left off, so the one thing the player is listening for during those three
	# seconds does not cut out on the frame the bomber is shot.
	if _lit and not _spent and voice != null and not voice.playing:
		voice.play(heard_up_to)


## Builds one spark per ignition point, on the artwork rather than on the fuse - see
## [member spark_parent_path] - so they are carried by the body wherever it goes and
## whatever happens to it.
##
## They are still held here by reference, so the frame cycle and the clear-up below
## reach them exactly as they did when they were children of this node. Nothing else
## in the file has to know where they ended up.
func _build_sparks() -> void:
	if ignite_textures.is_empty():
		return

	var host := _spark_parent()
	for i: int in ignition_points.size():
		var spark := Sprite2D.new()
		spark.name = "Spark%d" % i
		spark.position = ignition_points[i]
		spark.scale = Vector2.ONE * ignite_scale
		spark.z_index = ignite_z_index
		spark.modulate = ignite_modulate
		spark.texture = ignite_textures[0]
		host.add_child(spark)
		_sparks.append(spark)


## The node the sparks hang on, falling back to the fuse itself so an unresolved
## path is a fuse that behaves as it used to rather than one that never lights.
func _spark_parent() -> Node2D:
	var host := get_node_or_null(spark_parent_path) as Node2D
	return host if host != null else self


## The cycle. One tween on this node rather than a process callback, because
## [DeathFade] stops every component on a corpse and a tween is not a component -
## it keeps running, which is exactly what a fuse burning on a dead body needs.
func _burn() -> void:
	if _sparks.is_empty() or ignite_textures.is_empty() or frame_seconds <= 0.0:
		return

	var tween := create_tween().set_loops()
	tween.tween_callback(_next_frame).set_delay(frame_seconds)


## Each side is offset round the loop by [member side_offset] of a frame per side,
## so the two fuses are never lit on the same picture and the pair reads as one
## thing catching rather than two lamps blinking.
func _next_frame() -> void:
	_frame += 1.0
	var frames := ignite_textures.size()
	for i: int in _sparks.size():
		var spark := _sparks[i]
		if spark == null or not is_instance_valid(spark):
			continue
		var step := _frame + float(i) * side_offset * float(frames)
		spark.texture = ignite_textures[int(step) % frames]


## Starts the burn, and keeps it going. The recording is roughly the length of the
## fuse, so the loop below is insurance rather than the normal case - but a fuse
## that has been lengthened in the Inspector must not fall silent half way down.
func _start_burning_sound() -> void:
	var voice := get_node_or_null(fuse_sound_path) as AudioStreamPlayer2D
	if voice == null:
		return
	if fuse_sound_loops and not voice.finished.is_connected(_repeat_burning_sound):
		voice.finished.connect(_repeat_burning_sound)
	voice.play()


## Only ever while it is still burning, so the last repeat cannot outlive the
## blast that ends it.
func _repeat_burning_sound() -> void:
	if not _lit or _spent:
		return
	var voice := get_node_or_null(fuse_sound_path) as AudioStreamPlayer2D
	if voice != null:
		voice.play()


## Silence, at the instant it goes off - the blast's own sound takes over from
## here, and a fuse still hissing underneath it would read as a second bomber.
func _stop_burning_sound() -> void:
	var voice := get_node_or_null(fuse_sound_path) as AudioStreamPlayer2D
	if voice == null:
		return
	if voice.finished.is_connected(_repeat_burning_sound):
		voice.finished.disconnect(_repeat_burning_sound)
	voice.stop()


func _clear_sparks() -> void:
	for spark: Sprite2D in _sparks:
		if spark != null and is_instance_valid(spark):
			spark.queue_free()
	_sparks.clear()


## Puts the blast in the running scene rather than under the bomber, because the
## bomber is about to be freed and everything the explosion throws - gore, blood,
## smoke - has to outlive it.
func _blast(at: Vector2) -> void:
	if explosion_scene == null or not is_inside_tree():
		return
	var container := get_tree().current_scene
	if container == null:
		return

	var blast := explosion_scene.instantiate() as Node2D
	if blast == null:
		return

	container.add_child(blast)
	blast.global_position = at
	blast.reset_physics_interpolation()

	# The body this came off is spared its own blast, because the blast is already
	# taking it - see [method _take_the_body_away]. Without this the bomber is torn
	# apart by itself an instant before it is removed, which plays a second death on
	# top of the explosion that replaced it.
	if blast.has_method(&"spare"):
		blast.call(&"spare", get_body())
	if blast.has_method(&"play"):
		blast.call(&"play")


## The body goes with the blast, whether it was still walking or already lying
## there. Freed rather than killed: a bomber that reached the player has already
## paid out whatever its death was worth, and one that is already a corpse must
## not die twice.
func _take_the_body_away() -> void:
	var body := _corpse if _corpse != null else get_parent()
	if body != null and is_instance_valid(body) and body != get_tree().current_scene:
		body.queue_free()
	_corpse = null


func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001
