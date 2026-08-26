class_name EnemyEnrage
extends Node
## A man who watched his friend die and lost his mind about it: twice the speed,
## five times the blood in him, no interest in flanking, and his friend's name in a
## bubble over his head.
##
## [b]It is the fourth ending an enemy can have[/b], alongside dying, getting away
## and giving up - and the only one that makes him more dangerous. Like the other
## three it does not decide when it happens: [MoraleDirector] rolls for it and
## calls [method enrage], and this only knows how to become it.
##
## [b]He stays an ordinary enemy.[/b] Nothing here replaces the chase, the swing,
## the separation, the hit reaction or the death - every one of them is the code
## that was already there, running on numbers this component has multiplied:
##
##   [codeblock]
##   speed        Enemy.speed                 x speed_multiplier
##   toughness    Health.scale_max_health     x health_multiplier
##   pursuit      Enemy.separation_strength   -> pursuit_separation
##   colour       HitReaction's own materials -> the tint uniform
##   [/codeblock]
##
## [b]The pursuit is the interesting one.[/b] An ordinary enemy steers away from
## the men it is shouldering past - see [method Enemy._separation_push] - which is
## what makes a crowd spread out and come at the player from several sides. An
## enraged man simply does not care: his separation is turned down to
## [member pursuit_separation], so he ploughs through his own people in a straight
## line at whoever killed his friend. That is one exported number rather than a
## second movement mode, so nothing about the ordinary walk is duplicated or put at
## risk.
##
## [b]The red is the boss's red.[/b] It is written onto the very materials
## [HitReaction] already duplicated for this character - see
## [method HitReaction.get_flash_materials] - through the same [code]tint[/code]
## uniform [method MiniBoss.apply_tint] uses for a boss in its last phase. So an
## enraged man still flashes white when he is shot, still fades when he dies, and
## the wash sits underneath both. Kept deliberately light: he has to read as
## angry, not as a different enemy.
##
## [b]And he is mourned.[/b] Being killed briefly takes the camera - see
## [member camera_focus_time] - and puts a tear under the X in his eye, on top of
## the ordinary death rather than instead of it. His bubble is not snatched away on
## the frame he dies; it is given [member death_bubble_fade] to go.

## Emitted the moment he goes berserk, before any of it has been applied.
signal enraged
## Emitted as an enraged man dies, for anything that wants to mark it.
signal enraged_death

## Group every enraged enemy joins, so anything can find them without being wired
## to any one of them.
const GROUP := &"enraged_enemy"

## Whether this man is capable of it at all. Off for anybody who must never go
## berserk - the same door [member EnemySurrender.gives_up_on_its_own] is for the
## other direction.
@export var can_enrage: bool = true
## The enemy's health, scaled as he goes and watched so his ending can be marked.
@export var health_path: NodePath = ^"../Health"

@export_group("What it does to him")
## What his walking speed is multiplied by.
@export var speed_multiplier: float = 2.0
## What his health pool is multiplied by.
##
## Filled as it is scaled, so a man who had already been shot twice comes back up
## to the full new pool rather than keeping his old fraction of it. He has stopped
## feeling it, which is the whole idea.
@export var health_multiplier: float = 5.0
## Whether the bigger pool is filled as it is applied.
@export var fills_health: bool = true
## What his steering-around-neighbours is turned down to - see
## [method Enemy._separation_push]. 0 is a straight line at the player through
## anybody in the way, which is what direct pursuit means.
@export var pursuit_separation: float = 0.0
## Whether the pursuit change is applied at all. Off leaves him fast and tough but
## still flanking with the rest of them.
@export var changes_pursuit: bool = true

@export_group("The red")
## Whether he is washed red.
@export var tints: bool = true
## How heavy the wash is, 0 to 1. [b]Subtle.[/b] This is a man in a temper, not a
## demon - anything much above a quarter stops reading as the same enemy.
@export_range(0.0, 1.0, 0.01) var tint_strength: float = 0.24
## The colour of the wash.
@export var tint_color := Color(1.0, 0.13, 0.1, 1.0)
## The [HitReaction] whose materials are written to. Its own duplicates are used
## rather than fresh ones, so the wash and the hit flash share one material each
## and cannot erase one another.
@export var hit_reaction_path: NodePath = ^"../HitReaction"
## Sprites tinted when there is no hit reaction to borrow from. The same five parts
## a man is drawn out of.
@export var tint_paths: Array[NodePath] = [
	^"../Visual/Body",
	^"../Visual/Legs/LeftLeg",
	^"../Visual/Legs/RightLeg",
	^"../HeadAim/Head",
	^"../KnifeAim/KnifeHand/Knife",
]

@export_group("What he shouts")
## The bubble. Left empty he goes berserk in silence.
@export var bubble_scene: PackedScene
## What he shouts, drawn at random.
##
## [b]A list rather than anything written into the code[/b], so adding another name
## is adding a line in the Inspector. They are names because that is what it is: a
## man screaming for somebody who is not going to answer.
@export var shouts: PackedStringArray = [
	"JOOOOHN!",
	"MAAAAAK!",
	"BILLYYY!",
	"NOOOO!",
	"AAAAARGH!",
]
## How long the bubble stays up before it fades on its own, in seconds.
@export var bubble_hold: float = 4.0
## How long it takes to fade at the end of that.
@export var bubble_fade: float = 0.5
## How long it is given to go when he is killed before it has finished. Never
## instant - a bubble snatched off on the frame of the kill reads as a bug.
@export var death_bubble_fade: float = 1.0
## Where the bubble hangs relative to his feet.
@export var bubble_offset := Vector2(52.0, -104.0)

@export_group("His ending")
## Whether the camera is briefly taken as he dies.
@export var focuses_camera: bool = true
## How long the camera stays on him, in seconds. Brief - this is a beat, not a
## cutscene, and the player is still being shot at.
@export var camera_focus_time: float = 0.45
## How quickly the camera crosses to him and back.
@export var camera_follow_speed: float = 13.0
## How far it pushes in while it is on him, as a fraction. 0 is no push.
@export var camera_zoom: float = 0.07
## The channel the push is filed under, so it layers with the rest of the camera
## rather than fighting whatever else is punching it.
@export var camera_zoom_channel: StringName = &"enraged_death"
## How loudly it argues for the camera against anything else asking at the same
## moment. Below the finale's, so the last man of a Danger still wins.
@export var camera_priority: int = 12
## The tear under his eye, shown only when an enraged man dies. Optional - an enemy
## drawn without one simply dies dry.
@export var tear_path: NodePath = ^"../HeadAim/Head/Tear"
## Whether the tear is shown at all.
@export var shows_tear: bool = true
## How long the tear takes to fade up, in seconds. Subtle: it should be noticed
## rather than announced.
@export var tear_fade: float = 0.35

@onready var _health: Health = get_node_or_null(health_path) as Health

var _enraged: bool = false
var _bubble: SpeechBubble
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	if _health != null:
		_health.died.connect(_on_died)


## The component on [param enemy], or null. Found by type rather than by a fixed
## child name, for the same reason every other component on an enemy is: a man who
## keeps his parts somewhere else still works.
static func find_on(enemy: Node) -> EnemyEnrage:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "EnemyEnrage", true, false):
		var found := node as EnemyEnrage
		if found != null:
			return found
	return null


## Whether [param enemy] has gone berserk. Asked by group rather than by finding
## the component, so it costs nothing to ask about a whole field of them.
static func is_enraged(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var component := find_on(enemy)
	return component != null and component.is_enraged_now()


func is_enraged_now() -> bool:
	return _enraged


## Sends this man berserk. Returns whether it took.
##
## Refused on a man who is already berserk, already dead or not in the world.
## Everything else that must not be overwritten - down, running - is refused a
## step earlier, in [method MoraleDirector._can_be_asked], because that is the one
## place the whole list of "already something" lives.
func enrage() -> bool:
	if _enraged or not can_enrage or not is_inside_tree():
		return false
	if _health != null and not _health.is_alive():
		return false

	var host := get_parent()
	if host == null:
		return false

	_enraged = true
	add_to_group(GROUP)
	enraged.emit()

	_make_him_fast(host)
	_make_him_tough()
	_make_him_direct(host)
	_make_him_red()
	_make_him_shout(host)
	return true


## The walk. Written as a multiple of whatever the enemy was authored at rather
## than as a fixed number, so a scaled-up enemy from a later round stays scaled up.
func _make_him_fast(host: Node) -> void:
	if host.get(&"speed") == null:
		return
	host.set(&"speed", float(host.get(&"speed")) * maxf(speed_multiplier, 0.0))


func _make_him_tough() -> void:
	if _health == null or health_multiplier <= 0.0:
		return
	_health.scale_max_health(health_multiplier, fills_health)


## Straight at the player, through his own people. One number on the enemy rather
## than a second way of moving - see the class documentation.
func _make_him_direct(host: Node) -> void:
	if not changes_pursuit or host.get(&"separation_strength") == null:
		return
	host.set(&"separation_strength", maxf(pursuit_separation, 0.0))


## The wash, laid onto the hit reaction's own materials so the flash still works
## over the top of it.
func _make_him_red() -> void:
	if not tints:
		return

	_collect_materials()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"tint_color", tint_color)
		material.set_shader_parameter(&"tint", clampf(tint_strength, 0.0, 1.0))


## The materials to write to: the hit reaction's own if there is one, and otherwise
## duplicates made here.
##
## The duplication in the fallback matters for the same reason it matters in
## [method HitReaction._collect_materials]: the sprites in a scene share one
## material resource, so writing a tint straight onto it would turn every enemy in
## the arena red rather than this one.
func _collect_materials() -> void:
	if not _materials.is_empty():
		return

	var reaction := get_node_or_null(hit_reaction_path) as HitReaction
	if reaction != null:
		var owned := reaction.get_flash_materials()
		if not owned.is_empty():
			_materials = owned
			return

	for path: NodePath in tint_paths:
		var node := get_node_or_null(path) as CanvasItem
		if node == null:
			continue
		var shared := node.material as ShaderMaterial
		if shared == null:
			continue
		var own := shared.duplicate() as ShaderMaterial
		node.material = own
		_materials.append(own)


## The bubble, put into the running scene rather than onto the man, so it keeps
## hanging in the air at a steady angle while he is knocked about, and survives him
## long enough to fade.
func _make_him_shout(host: Node) -> void:
	if bubble_scene == null or shouts.is_empty():
		return

	var body := host as Node2D
	if body == null:
		return

	var bubble := bubble_scene.instantiate() as SpeechBubble
	if bubble == null:
		return

	bubble.head_offset = bubble_offset
	var keeper: Node = get_tree().current_scene
	if keeper == null:
		keeper = body.get_parent()
	if keeper == null:
		return

	keeper.add_child(bubble)
	bubble.global_position = body.global_position + bubble_offset
	bubble.set_subject(body)
	bubble.show_bubble(shouts[randi() % shouts.size()])
	_bubble = bubble

	if bubble_hold > 0.0:
		var timer := get_tree().create_timer(bubble_hold, true, false, true)
		timer.timeout.connect(_fade_bubble.bind(bubble_fade))


## Takes the bubble down. Safe to call twice - the bubble refuses a second dismissal
## itself - which is what lets the timer and the death both ask without either
## having to know about the other.
func _fade_bubble(fade: float) -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	_bubble.dismiss(fade)


## An enraged man is down.
##
## [b]Nothing about the ordinary death is touched.[/b] [EnemyDefeat] still plays it,
## [EnemyHeadPop] still takes the head off, [BloodEmitter] still pays out and
## [DeathFade] still frees the body. This lays two things on top - a moment of the
## camera and a tear - and lets his bubble finish rather than snatching it away.
func _on_died() -> void:
	if not _enraged:
		return

	enraged_death.emit()
	_fade_bubble(death_bubble_fade)
	_show_tear()
	_take_the_camera()


## The tear, faded up beneath the X marks the ordinary death already put in his
## eyes. It is a sprite in the scene rather than anything drawn here, so what it
## looks like and where it sits are the Inspector's.
func _show_tear() -> void:
	if not shows_tear:
		return

	var tear := get_node_or_null(tear_path) as CanvasItem
	if tear == null:
		return

	tear.modulate.a = 0.0
	tear.visible = true
	# On the tear itself rather than on this node, so it survives a death that
	# freezes the components on the body.
	var tween := tear.create_tween()
	tween.tween_property(tear, "modulate:a", 1.0, maxf(tear_fade, 0.0))


## A moment of the camera, through the same lock-on the struck coin and the last
## man of a Danger already use, and handed straight back.
##
## The release is a plain timer rather than anything this node waits on, because
## this node is on a body that is about to be frozen and freed - and the camera
## must be given back whether or not the corpse is still there to give it.
func _take_the_camera() -> void:
	if not focuses_camera or camera_focus_time <= 0.0:
		return

	var camera := CameraController.get_active(self)
	var body := get_parent() as Node2D
	if camera == null or body == null:
		return
	# Something with a better claim already has it - the finale playing out the last
	# man of a Danger. It is not taken off them for one of a crowd.
	if camera.get_follow_subject() != null:
		return

	camera.follow(body, camera_follow_speed)
	if camera_zoom > 0.0:
		camera.zoom_kick(camera_zoom, camera_focus_time * 0.4,
			camera_focus_time * 0.6, camera_zoom_channel, camera_priority)

	var timer := get_tree().create_timer(camera_focus_time, true, false, true)
	timer.timeout.connect(_give_the_camera_back.bind(camera, body))


func _give_the_camera_back(camera: CameraController, body: Node2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	# Only if it is still ours. Anything that took it in the meantime keeps it.
	if camera.get_follow_subject() != body:
		return
	camera.release_follow(camera_follow_speed)
