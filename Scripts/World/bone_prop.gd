class_name BoneProp
extends Node2D
## Bones lying in the sand. Still until somebody runs over them, and every so
## often one goes flying.
##
## It owns nothing that the other props do not already have: the shiver is a
## [PropSway] knock and the noticing is a [PropTouch] with its
## [member PropTouch.minimum_speed] set, which is what makes "moves quickly
## across" a thing the area decides rather than something checked here. This
## script is only the part that is particular to bones - the roll of the dice,
## and the bone that comes off the player's boot when it comes up.
##
## The kicked bone is a separate scene rather than this node being thrown,
## because the two are different things: this is a rib or a skull half-buried in
## the sand and it stays where it is, while what the boot sends skittering is a
## loose bone that leaves from the player's foot and lies wherever it stops. See
## [KickedBone].
##
## Everything about how often and how hard is an inspector value, and the kick
## can be switched off entirely by setting [member kick_chance] to 0, which
## leaves a bone that only ever shivers.

## Emitted when a kick actually comes off, with the bone that was spawned.
signal kicked(bone: KickedBone)

## The area that notices somebody running over this. Its
## [member PropTouch.minimum_speed] is what "quickly" means.
@export var touch_path: NodePath = ^"Touch"
## The shiver. Its [member PropSway.knock_degrees] is the few degrees the bone
## rocks through, and its damping is how fast it settles.
@export var sway_path: NodePath = ^"Sway"

@export_group("Kick")
## Chance a qualifying touch sends a bone flying, 0 to 1.
@export_range(0.0, 1.0) var kick_chance: float = 0.2
## The bone that is kicked loose. Left empty, the prop only ever shivers.
@export var kicked_bone_scene: PackedScene
## Where kicked bones are parented. Left unresolved, they are parented to this
## prop's own parent, so they land in whatever container the scenery lives in and
## the world scene stays tidy.
@export var kicked_container_path: NodePath
## Shortest gap between two kicks off the same bone, in seconds. Without it,
## pacing back and forth over one bone is a bone fountain.
@export var kick_cooldown: float = 3.0
## Whether this prop hides itself when its bone is kicked away. Off - the default
## - leaves the half-buried bones in the sand where they are and treats the kick
## as a loose one coming off the pile.
@export var hide_on_kick: bool = false

@export_group("Kick force")
## Where the bone leaves from, relative to the *player's* position: a little
## below their origin puts it at boot height rather than at their waist. Their
## origin is already at their feet, so this is small.
@export var launch_offset := Vector2(0.0, -4.0)
## Speed the kick is judged against. A body moving at this speed kicks with
## power 1; slower kicks are proportionally softer.
@export var reference_speed: float = 220.0
## Range the kick's power is held to, so a very fast body cannot fire a bone
## across the whole map and a barely-qualifying one still sends it somewhere.
@export var power_range := Vector2(0.7, 1.35)

@onready var _touch: PropTouch = get_node_or_null(touch_path) as PropTouch
@onready var _sway: PropSway = get_node_or_null(sway_path) as PropSway

var _cooldown: float = 0.0


func _ready() -> void:
	if _touch != null:
		_touch.touched.connect(_on_touched)
	set_process(false)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown <= 0.0:
		set_process(false)


## Every qualifying touch shivers the bone; only some of them kick it. The area
## has already decided the body was moving fast enough to count, so there is no
## second speed test here.
func _on_touched(body: Node2D, direction: Vector2, speed: float) -> void:
	if _sway != null:
		_sway.nudge(1.0, 1.0 if direction.x >= 0.0 else -1.0)

	if _cooldown > 0.0 or kick_chance <= 0.0 or randf() >= kick_chance:
		return

	_kick(body, direction, speed)


func _kick(body: Node2D, direction: Vector2, speed: float) -> void:
	if kicked_bone_scene == null or body == null:
		return

	var bone := kicked_bone_scene.instantiate() as KickedBone
	if bone == null:
		return

	var container := get_node_or_null(kicked_container_path)
	if container == null:
		container = get_parent()
	if container == null:
		bone.queue_free()
		return

	# Sized by the map exactly as the bones it came off were - see [PropScale] - so
	# a kicked bone matches the pile it was kicked out of instead of arriving at
	# whatever size its own scene happens to be authored at.
	PropScale.apply_to(bone, self)

	container.add_child(bone)
	# From the player's own feet, so it reads as their boot catching it rather
	# than as a bone launching itself out of the sand a stride behind them.
	bone.launch(body.global_position + launch_offset, direction, _power(speed))

	_cooldown = maxf(kick_cooldown, 0.0)
	set_process(_cooldown > 0.0)

	if hide_on_kick:
		visible = false
		if _touch != null:
			_touch.set_deferred(&"monitoring", false)

	kicked.emit(bone)


func _power(speed: float) -> float:
	if reference_speed <= 0.0:
		return 1.0
	return clampf(speed / reference_speed, power_range.x, power_range.y)
