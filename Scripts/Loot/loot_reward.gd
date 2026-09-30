class_name LootReward
extends Resource
## One reward in a [LootBundle]: what its card says, how it looks, and what
## taking it does.
##
## [b]The Loot Screen knows only this class.[/b] It deals one card per reward,
## asks it for its lettering, and on a click calls [method activate] - never
## anything about what the reward is. A new kind of reward (a charm, a gem, a
## question-mark card) is a subclass overriding [method _activate] and, if it
## wants, the lettering methods, plus a [LootRewardLook] for how it is drawn.
##
## [b]Resolving may take a while.[/b] [method activate] may hand off to another
## screen and come back later - see [LootRewardUpgrade] - so the outcome is two
## signals rather than a return value: [signal activation_finished] every time an
## activation ends, and [signal settled] once, the moment the reward is done
## with. The screen holds every other card still while one reward is busy.

## The reward is done with - taken, claimed or used up. Emitted once.
signal settled
## An activation has ended, whether or not it settled the reward.
signal activation_finished

## How the reward is drawn - see [LootRewardLook].
@export var look: LootRewardLook
## The card's main line. Empty falls back to [member LootRewardLook.label].
@export var title: String = ""
## The card's smaller lines.
@export_multiline var detail: String = ""
## How many - shown through [member LootRewardLook.amount_format] when above one.
@export var amount: int = 1
## Whether the Loot Screen may be left while this is still unclaimed. A reward
## the old flow made the player take (the weapon upgrade) is required; loot the
## old Horse Cart let the player ride away from is not.
@export var required: bool = false
## Shown on the card once the reward is done with.
@export var resolved_text: String = "TAKEN"

var _resolved: bool = false
var _busy: bool = false
## Why the last activation could not settle the reward, shown on the card until
## the next one. Empty when there is nothing to say.
var _refusal: String = ""


func get_title() -> String:
	if not title.is_empty():
		return title
	return look.label if look != null else ""


## The kind's heading - the look's label, or empty when the title already is it.
func get_heading() -> String:
	if look == null or look.label == get_title():
		return ""
	return look.label


func get_detail() -> String:
	return detail


func get_amount() -> int:
	return amount


func get_amount_text() -> String:
	var shown := get_amount()
	if shown <= 1:
		return ""
	var format := look.amount_format if look != null else "x%d"
	return format % shown


## A short line under the card: why it cannot be taken, or that it has been.
func get_status_text() -> String:
	if _resolved:
		return resolved_text
	return _refusal


func is_resolved() -> bool:
	return _resolved


func is_busy() -> bool:
	return _busy


## Whether this reward still has to be dealt with before the screen can close.
func blocks_leaving() -> bool:
	return required and not _resolved


## Whether a click would do anything right now.
func can_activate(_context: LootContext) -> bool:
	return not _resolved and not _busy


## What a click on the card does. Ends in [signal activation_finished], now or
## later, and in [signal settled] when it resolved the reward.
func activate(context: LootContext) -> void:
	if not can_activate(context):
		return
	_busy = true
	_refusal = ""
	_activate(context)


## Marks the reward done with, without activating it - for a reward that has
## already happened by the time it is shown (a bounty paid on the kill).
func mark_resolved() -> void:
	if _resolved:
		return
	_resolved = true
	settled.emit()
	emit_changed()


## Override: do the reward's work, then call [method _finish]. The default simply
## settles, which is a reward whose whole effect is being seen.
func _activate(_context: LootContext) -> void:
	_finish(true)


## Ends an activation. [param resolved] settles the reward; otherwise
## [param refusal] is shown on the card as the reason it did not.
func _finish(resolved: bool, refusal: String = "") -> void:
	_busy = false
	_refusal = "" if resolved else refusal
	activation_finished.emit()
	if resolved:
		mark_resolved()
	else:
		emit_changed()
