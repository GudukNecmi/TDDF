class_name SpeechBubble
extends Node2D
## A small black-and-red bubble with a line of red text in it, floating beside
## somebody's head.
##
## [b]It is one component for every line anybody in the game says.[/b] A man
## begging not to be shot, a man who has run out of things to tell you and a man
## screaming his brother's name are the same object with different text in it -
## see [EnemySurrender] and [EnemyEnrage], which are its two callers today. Nothing
## about who is talking is written down here.
##
## It knows nothing about its speaker except where they are. The subject is handed
## in - [method set_subject] - and followed rather than parented to, which is what
## lets it keep hanging in the air at a steady angle while the man underneath it
## falls to his knees, is knocked about by a shotgun, or dies and fades out.
##
## Three deliberate pieces of motion, all of them small:
##
##   * [b]It follows softly.[/b] The bubble eases towards where the head is rather
##     than being written to it - see [member follow_softness] - so it trails a
##     running man slightly instead of being welded to him. That is the whole
##     difference between a label and something that reads as spoken.
##   * [b]It points at its speaker.[/b] A tail is drawn beneath the panel, angled
##     towards the subject rather than always straight down, so a bubble that has
##     drifted off to one side still visibly belongs to the man under it.
##   * [b]It shakes.[/b] A couple of pixels of noise - see [member shake_amount] -
##     which is what stops a bubble on a still corpse looking like part of the HUD.
##
## The palette is the game's own: near-black red-brown fill, a bright red border,
## red text with a dark outline behind it, in the western face the rest of the
## interface uses. It is authored in the scene rather than here, so restyling it is
## the Inspector's business - see [code]Scenes/UI/SpeechBubble.tscn[/code].

## Emitted once the bubble has finished fading out and taken itself away.
signal finished

## The node the bubble hangs over. Usually left empty and handed in at runtime by
## whoever is speaking.
@export var subject_path: NodePath
## Where the bubble sits relative to the subject's origin - at the feet on every
## character in the game, so this is up and off to one side, beside the head.
@export var head_offset := Vector2(46.0, -96.0)
## Overall size. Small on purpose: this is somebody talking, not a sign.
@export var bubble_scale: float = 0.5

@export_group("Following")
## How quickly the bubble catches up with the head, per second. Low is loose and
## trailing; high is glued on. [b]It must not be glued on[/b] - the softness is
## what makes it read as floating beside the man rather than as being part of him.
@export var follow_softness: float = 9.0
## Whether the bubble snaps to the subject on the frame it appears rather than
## flying in from wherever it was built. On - a bubble that visibly slides across
## the arena to reach its speaker is not the effect.
@export var snaps_on_show: bool = true

@export_group("Shake")
## How far the bubble trembles from its resting spot, in pixels. Subtle.
@export var shake_amount: float = 1.6
## How fast it trembles.
@export var shake_speed: float = 17.0

@export_group("Timing")
## How long it fades in over.
@export var fade_in_time: float = 0.14
## The default fade for [method dismiss], for a caller that does not name one.
@export var fade_out_time: float = 0.35
## How much larger it pops as it arrives, as a fraction of its size.
@export var pop_scale: float = 0.4
## Whether the bubble frees itself once it has faded out. On for every bubble that
## is spawned for one line, which is all of them today.
@export var frees_itself: bool = true

@export_group("Parts")
## The panel and label, so a differently built bubble can be pointed at its own
## pieces without this script naming any node.
@export var label_path: NodePath = ^"Panel/Label"
## The tail that points at the speaker. Optional.
@export var tail_path: NodePath = ^"Tail"
## The whole of the artwork, moved by the shake so the node's own position stays
## the clean followed one.
@export var body_path: NodePath = ^"."

var _subject: Node2D
var _label: Label
var _panel: Control
var _tail: Node2D
var _body: Node2D
var _time: float = 0.0
## Where the bubble is heading, before the shake is added on top.
var _rest: Vector2 = Vector2.ZERO
var _placed: bool = false
var _leaving: bool = false
var _tween: Tween


func _ready() -> void:
	top_level = true
	_let_the_mouse_through()
	_label = get_node_or_null(label_path) as Label
	_panel = _label.get_parent() as Control if _label != null else null
	_tail = get_node_or_null(tail_path) as Node2D
	_body = get_node_or_null(body_path) as Node2D
	if _body == null:
		_body = self

	if _subject == null:
		_subject = get_node_or_null(subject_path) as Node2D

	modulate.a = 0.0
	scale = Vector2.ONE * bubble_scale


## Makes every [Control] in the bubble invisible to the mouse.
##
## [b]A bubble is something somebody said, not something to click on.[/b] The panel
## it is drawn in is a [Control], and a [Control] left on its default
## [constant Control.MOUSE_FILTER_STOP] swallows the click that lands on it - so a
## man shouting from in front of the player was, until this, a small piece of cover
## the player could not shoot through. Nothing in the game ever wants a bubble
## clicked, so the whole of it is set to
## [constant Control.MOUSE_FILTER_IGNORE] and the shot goes to the game underneath.
##
## Done here rather than only in the scene so that [i]every[/i] bubble is safe -
## including one built from a differently authored scene, and one whose panel was
## added later by somebody who did not know to set it.
func _let_the_mouse_through(from: Node = self) -> void:
	var control := from as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in from.get_children():
		_let_the_mouse_through(child)


## Who the bubble belongs to. Safe to call before or after it is in the tree, so a
## caller can build it, aim it and fill it in in any order.
func set_subject(subject: Node2D) -> void:
	_subject = subject
	_placed = false


## What it says. Called on its own to change the line inside a bubble already up -
## which is exactly what pressing E on a man who has surrendered does - so the
## panel stays where it is and only the words change.
func say(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	# Deferred, because the label's minimum size is not recomputed until the text
	# change has been processed - asking now would fit the panel round the old line.
	_fit_panel.call_deferred()


## Sizes the panel round whatever it is holding.
##
## [b]It has to be asked for.[/b] A [Control] that is not inside a container is
## never resized by anybody: it keeps whatever size it was authored at, which for a
## panel meant to wrap a line of text is no size at all. Growing in both directions
## from an anchor at the origin is what then centres it on this node, so the bubble
## sits square over its speaker whatever it says.
func _fit_panel() -> void:
	if _panel == null:
		return
	var wanted := _panel.get_combined_minimum_size()
	if _panel.size.is_equal_approx(wanted):
		return
	_panel.size = wanted
	# Written rather than left to the anchors, because growing both ways only
	# recentres a control the layout has actually been asked to redo.
	_panel.position = -wanted * 0.5


## Puts the bubble up. [param text] is optional; left empty whatever the scene or
## the last [method say] put there is kept.
func show_bubble(text: String = "") -> void:
	if not text.is_empty():
		say(text)

	_leaving = false
	visible = true
	if _tween != null and _tween.is_running():
		_tween.kill()

	if snaps_on_show:
		_follow(1.0, true)

	scale = Vector2.ONE * bubble_scale * (1.0 + pop_scale)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_time)
	_tween.tween_property(self, "scale", Vector2.ONE * bubble_scale, fade_in_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Takes the bubble down over [param fade] seconds, or over
## [member fade_out_time] when none is named.
##
## [b]Never instant, and that is the point.[/b] The one caller with a reason to
## remove a bubble abruptly is a man being shot mid-sentence - see
## [EnemyEnrage] - and snapping it off on the frame of the kill reads as a bug
## rather than as an ending. It is given a second to go instead.
func dismiss(fade: float = -1.0) -> void:
	if _leaving:
		return
	_leaving = true

	if _tween != null and _tween.is_running():
		_tween.kill()

	var time := fade if fade >= 0.0 else fade_out_time
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, maxf(time, 0.0))
	_tween.tween_callback(_finish)


## Whether the bubble is on its way out.
func is_leaving() -> bool:
	return _leaving


func _finish() -> void:
	finished.emit()
	if frees_itself:
		queue_free()
		return
	visible = false


## The follow, the tail and the shake, in that order - the tail is aimed from
## where the bubble has actually got to, and the shake is laid over the top of
## both so it never feeds back into either.
func _process(delta: float) -> void:
	_time += delta
	# Cheap, and it self-heals: a font that finished loading late, or a theme that
	# changed, leaves the panel the wrong size for exactly one frame.
	_fit_panel()
	_follow(delta, false)
	_aim_tail()
	_shake()


## Eases the resting spot towards the head. [param immediate] places it outright,
## for the frame the bubble appears on.
func _follow(delta: float, immediate: bool) -> void:
	if _subject == null or not is_instance_valid(_subject):
		return

	var goal := _subject.global_position + head_offset
	if immediate or not _placed:
		_rest = goal
		_placed = true
	else:
		_rest = _rest.lerp(goal, 1.0 - exp(-maxf(follow_softness, 0.0) * delta))


## Turns the tail towards the speaker, so a bubble trailing behind a running man
## still points back at him. Left alone when there is nobody to point at.
func _aim_tail() -> void:
	if _tail == null or _subject == null or not is_instance_valid(_subject):
		return
	# Measured from the resting spot rather than from the shaken one, so the tail
	# does not jitter independently of the panel it hangs off.
	_tail.global_rotation = _rest.direction_to(_subject.global_position).angle() \
		- deg_to_rad(90.0)


## Two out-of-step sine waves rather than random noise, so the tremble is even and
## does not occasionally sit still.
func _shake() -> void:
	if shake_amount <= 0.0:
		global_position = _rest
		return

	var wobble := Vector2(
		sin(_time * shake_speed),
		sin(_time * shake_speed * 1.37 + 1.1)) * shake_amount
	global_position = _rest + wobble
