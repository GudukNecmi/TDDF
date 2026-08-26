class_name HoverScale
extends Node
## Makes buttons grow a little under the mouse, and settle back when it leaves.
##
## [b]It is one node for a whole screen, not a script on every button.[/b] The
## buttons a menu offers are the menu's business - some of them are built at run
## time and none of them should have to carry a second script to be touchable - so
## this is pointed at whatever holds them and wires every [BaseButton] it finds
## underneath, however deep. A button added to that branch later is covered by
## calling [method rewire]; one that was never there is simply not scaled.
##
## The growth is a [Tween] on the control's own [member Node2D.scale], run against
## a pivot in the middle of it so a button widens from its centre rather than
## sliding to the right as it grows. Scale is deliberately the thing moved rather
## than the size: a container owns its children's size and would fight anything
## written there, while scale is the control's own and a container never touches
## it.
##
## Nothing here knows what any button does. It is only ever asked
## [signal Control.mouse_entered] and [signal Control.mouse_exited], so a button
## that opens a menu, starts a game or quits is the same button to this.

## What holds the buttons. Everything below it that is a [BaseButton] is wired,
## whatever it is nested inside. Left empty this node's own parent is used, which
## is what a menu with one column of choices wants.
@export var root_path: NodePath

## How much larger a button is drawn while the mouse is on it. 1 turns the whole
## thing off without it having to be removed.
@export var hover_scale: float = 1.06

## How long the growth takes, in seconds. Short - it is a response to the mouse
## arriving, and anything slower reads as the screen lagging rather than as the
## button answering.
@export var grow_time: float = 0.12

## How long settling back takes. Kept separate from [member grow_time] because
## leaving can afford to be gentler than arriving.
@export var settle_time: float = 0.16

## The curve the growth is drawn on.
@export var transition: Tween.TransitionType = Tween.TRANS_QUAD

## Whether a button that is disabled still grows. Off: a disabled button is not a
## choice, and answering the mouse would say that it is.
@export var scales_disabled_buttons: bool = false

## The tween each button is currently being moved by, so a mouse swept quickly
## across a row cannot leave two of them fighting over the same control.
var _tweens: Dictionary = {}


func _ready() -> void:
	rewire()


## Wires every button under [member root_path]. Safe to call again - a button
## already connected is left alone - so a menu that has just rebuilt its choices
## can ask for them to be covered without tracking what was there before.
func rewire() -> void:
	var root := get_node_or_null(root_path) if root_path != NodePath() else get_parent()
	if root == null:
		return
	_wire_below(root)


func _wire_below(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		_wire(button)
	for child: Node in node.get_children():
		_wire_below(child)


func _wire(button: BaseButton) -> void:
	# The pivot is set once, here, rather than every time the mouse arrives: a
	# container has already given the button its size by the time this runs, and
	# re-reading it on hover would catch a button mid-layout.
	button.pivot_offset = button.size * 0.5
	if not button.resized.is_connected(_recentre.bind(button)):
		button.resized.connect(_recentre.bind(button))
	if not button.mouse_entered.is_connected(_on_entered.bind(button)):
		button.mouse_entered.connect(_on_entered.bind(button))
	if not button.mouse_exited.is_connected(_on_exited.bind(button)):
		button.mouse_exited.connect(_on_exited.bind(button))


## Keeps the pivot in the middle of a button that has just been resized - which a
## container does on the first frame, and again whenever the window changes shape.
func _recentre(button: BaseButton) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _on_entered(button: BaseButton) -> void:
	if not scales_disabled_buttons and button.disabled:
		return
	_scale_to(button, maxf(hover_scale, 0.01), grow_time)


func _on_exited(button: BaseButton) -> void:
	_scale_to(button, 1.0, settle_time)


func _scale_to(button: BaseButton, wanted: float, seconds: float) -> void:
	if not is_instance_valid(button):
		return

	var running := _tweens.get(button) as Tween
	if running != null and running.is_valid():
		running.kill()

	if seconds <= 0.0:
		button.scale = Vector2(wanted, wanted)
		return

	# Process-always, because the screens this is used on are the ones that pause
	# the tree - a menu whose buttons stopped answering the mouse the moment it was
	# raised would be the only place in the game the pointer did nothing.
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(transition).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, ^"scale", Vector2(wanted, wanted), seconds)
	_tweens[button] = tween
