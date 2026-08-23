class_name DamageNumber
extends Node2D
## One damage figure, thrown up off a body that has just been hit.
##
## It is drawn in the world rather than on the HUD, for the same reason
## [InteractionPrompt] is: the answer to "how hard did that land" belongs where
## the player is already looking, and being in world space means it shrinks and
## grows with the camera instead of floating at a fixed screen size over a zoomed
## view.
##
## The whole of its life is one tween: it pops up to full size, arcs upwards while
## drifting to one side, and fades out on the way. It owns nothing and is owned by
## nothing - it is parented to the running scene and frees itself at the end - so
## a screenful of them is a screenful of independent labels and a body dying
## underneath one does not take it with it.
##
## It is [member CanvasItem.top_level] so that a hit landing on a body that is
## already tipping over does not drag the number down with the corpse.

## Text the amount is written into. Whole numbers, because a shotgun pellet
## landing for "43.7" reads as a spreadsheet rather than a hit.
@export var format: String = "%d"

@export_group("Motion")
## How far it travels upwards over its life, in pixels.
@export var rise: float = 46.0
## How far to either side it may drift, picked per number. Together with the
## scatter below this is what stops a shotgun's worth of pellets - six hits on one
## body inside a single frame - stacking into one illegible blob.
@export var drift: float = 34.0
## Where it starts, relative to the hit. Up and slightly off, so the figure is not
## sitting on top of the blood it is describing.
@export var spawn_offset := Vector2(0.0, -12.0)
## How far the spawn point itself is scattered, in pixels, on both axes.
@export var spawn_scatter := Vector2(26.0, 18.0)
## How long the whole thing lasts.
@export var lifetime: float = 0.72
## How much of that is spent still fully opaque before the fade begins, as a
## fraction. The number has to be readable before it starts leaving.
@export_range(0.0, 1.0) var hold_fraction: float = 0.35

@export_group("Pop")
## Size it lands at.
@export var end_scale: float = 1.0
## Size it appears at, as a fraction of that. Under 1 it grows into place, over 1
## it punches down into it - which is what makes a hit read as an impact.
@export var pop_scale: float = 1.55
## How long that settle takes.
@export var pop_time: float = 0.12

@export_group("Look")
## Colour an ordinary hit is written in.
@export var normal_colour := Color(0.92, 0.83, 0.8, 1.0)
## Colour a hit above [member critical_damage] is written in - the arena's own
## red, so a heavy hit reads as one at a glance.
@export var critical_colour := Color(0.95, 0.16, 0.14, 1.0)
## What counts as heavy. Below 0 turns the distinction off and every number is
## written in [member normal_colour].
@export var critical_damage: float = 120.0
## How much larger a heavy hit is drawn, as a fraction.
@export var critical_scale: float = 1.3
## Node the text is written to. Optional in the sense that a scene without one
## simply plays the motion and shows nothing.
@export var label_path: NodePath = ^"Label"

@onready var _label: Label = get_node_or_null(label_path) as Label


func _ready() -> void:
	top_level = true


## Writes the figure and starts it moving. Called after the number has been
## placed, since everything here is measured from where it is standing.
##
## [param amount] is what actually landed, after the hitbox's own multiplier - so
## a headshot shows the headshot's number rather than the pellet's.
##
## [param critical] is the attack saying it was a critical hit outright, rather
## than the figure working it out from how big it is. Both routes end in the same
## look, which is the point: there is one critical hit, and a shot that was
## empowered before it landed reads as one even when its number happens to fall
## short of [member critical_damage].
func show_damage(amount: float, critical: bool = false) -> void:
	var heavy := critical or (critical_damage >= 0.0 and amount >= critical_damage)

	if _label != null:
		_label.text = format % int(round(amount))
		_label.modulate = critical_colour if heavy else normal_colour

	var final_scale := end_scale * (critical_scale if heavy else 1.0)
	var sideways := randf_range(-drift, drift)

	position += spawn_offset + Vector2(
		randf_range(-spawn_scatter.x, spawn_scatter.x),
		randf_range(-spawn_scatter.y, spawn_scatter.y))

	scale = Vector2.ONE * final_scale * pop_scale
	modulate.a = 1.0

	var seconds := maxf(lifetime, 0.0001)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * final_scale, maxf(pop_time, 0.0001)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Eased out so the figure leaps off the body and then coasts, rather than
	# sliding up the screen at a constant rate.
	tween.tween_property(self, "position", position + Vector2(sideways, -rise), seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, seconds * (1.0 - hold_fraction)) \
		.set_delay(seconds * hold_fraction)
	tween.chain().tween_callback(queue_free)
