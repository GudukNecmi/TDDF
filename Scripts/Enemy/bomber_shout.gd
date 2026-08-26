class_name BomberShout
extends Node
## What a bomber shouts as it lights itself and starts to run.
##
## [b]It is the same bubble everybody else in the game speaks in.[/b] The line goes
## up through [SpeechBubble] - the component a man begging for his life and a man
## screaming his brother's name already use - so nothing about how a bubble looks,
## follows, points or fades is written twice. See [EnemySurrender] and [EnemyEnrage]
## for the other two callers.
##
## [b]It listens; it never drives.[/b] The whole component hangs off
## [signal BomberAttack.committed] and does nothing but put words in the air. The
## decision, the charge, the fuse and the blast are made and run entirely without
## it, so a bomber whose bubble is switched off - an empty [member bubble_scene],
## an empty [member shouts], a lost roll - attacks in exactly the same way as one
## that shouts. That is deliberate: speech must never be able to change a fight.
##
## [b]One roll, at the moment of commitment.[/b] [member shout_chance] is rolled a
## single time as the charge begins, not per frame and not per bubble, so half of
## all charges are silent and the other half say one thing - one roll per attack,
## which is the rule every other chance-driven effect in the game follows.

## Emitted when a bomber actually says something, with the line it said, for
## anything that wants to react to it.
signal shouted(line: String)

## The attack this listens to. Its [signal BomberAttack.committed] is the moment
## the bomber has decided, lit itself and started to run.
@export var attack_path: NodePath = ^"../Attack"
## Who the bubble hangs over and follows. The bomber itself.
@export var subject_path: NodePath = ^".."

@export_group("The bubble")
## The bubble scene. Left empty the bomber charges in silence, which is a bomber
## with its voice switched off rather than a broken one.
@export var bubble_scene: PackedScene
## Chance that a charge is shouted at all, rolled once as it begins.
@export_range(0.0, 1.0, 0.01) var shout_chance: float = 0.5
## What it might shout, drawn at random.
##
## [b]A list rather than anything written into the code[/b], so adding a line is
## adding a line in the Inspector - there is no name, index or count anywhere in
## this file for a new one to have to be added to.
@export var shouts: PackedStringArray = []
## Where the bubble hangs relative to the bomber's origin at its feet.
@export var bubble_offset := Vector2(50.0, -100.0)
## How large the bubble is drawn. [b]Small.[/b] This is a man yelling as he runs
## past, not a sign - and the charge itself has to stay the readable thing on
## screen.
@export var bubble_scale: float = 0.36
## How long it stays up before it fades on its own, in seconds. Kept under the
## fuse, so the line is gone by the time the blast arrives rather than being
## snatched away by it.
@export var bubble_hold: float = 1.7
## How long it then takes to fade.
@export var bubble_fade: float = 0.35

@onready var _attack: Node = get_node_or_null(attack_path)

var _bubble: SpeechBubble
var _spoken: bool = false


func _ready() -> void:
	if _attack != null and _attack.has_signal(&"committed"):
		_attack.committed.connect(_on_committed)


## The one roll. [param at] is where the bomber is running, which is not this
## component's business - it is taken only because the signal carries it.
func _on_committed(_at: Vector2) -> void:
	if _spoken:
		return
	_spoken = true
	if randf() >= shout_chance:
		return
	say(shouts[randi() % shouts.size()] if not shouts.is_empty() else "")


## Puts a line up, whatever the roll said. Public so a test - or anything else that
## wants a bomber to say something - can ask for it without reproducing any of the
## above.
##
## The bubble is added to the running scene rather than to the bomber, so it keeps
## hanging in the air while the bomber is knocked about, killed or blown up
## underneath it, exactly as an enraged man's does.
func say(line: String) -> void:
	if bubble_scene == null or line.is_empty() or not is_inside_tree():
		return

	var subject := get_node_or_null(subject_path) as Node2D
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
	_bubble = bubble
	shouted.emit(line)

	if bubble_hold > 0.0:
		var timer := get_tree().create_timer(bubble_hold, true, false, true)
		timer.timeout.connect(_fade_bubble.bind(bubble_fade))


## Takes it down. Safe to call twice, and safe on a bomber that never spoke - the
## bubble refuses a second dismissal itself.
func _fade_bubble(fade: float) -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.dismiss(fade)
	_bubble = null
