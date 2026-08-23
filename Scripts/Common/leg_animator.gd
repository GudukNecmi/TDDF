class_name LegAnimator
extends Node
## Subtle leg motion for a character built from separate left and right leg
## sprites: a barely-there shift while standing, a small stride while walking.
##
## This is deliberately not an animation system. There is one phase counter and
## one blend, and the two legs read the same phase half a cycle apart - that is
## the whole thing. The breathing squash the character already has is untouched:
## the legs live under the same `Visual` node the [SquashIdle] animation scales,
## so they are carried by it for free and this only adds the stride on top.
##
## It writes `rotation` and `position` on the two leg nodes and nothing else, so
## a [FacingFlip] mirroring the pair on X never fights it.
##
## Each leg node must have its origin at the hip, with the artwork offset down
## from there, or the rotation swings the foot around the wrong point.
##
## Shared by the player and by enemies - the only difference between them is
## [member walk_reference_speed].

## Character whose velocity decides how much stride to blend in. Anything with a
## `velocity` works; with none set the legs simply idle.
@export var body_path: NodePath = ^".."
## Left leg pivot. Its origin must be the hip.
@export var left_leg_path: NodePath
## Right leg pivot.
@export var right_leg_path: NodePath

@export_group("Idle")
## Sway either way from rest while standing still, in degrees. Keep it tiny -
## this is a weight shift, not a fidget.
@export var idle_swing_degrees: float = 1.4
## Vertical drift while standing still, in pixels.
@export var idle_lift: float = 0.4
## Sway cycles per second while standing still. Slow, so it reads as breathing
## rather than as a stride played at the wrong speed.
@export var idle_cycles_per_second: float = 0.85

@export_group("Walk")
## Swing either way from rest at full stride, in degrees.
@export var walk_swing_degrees: float = 8.0
## How far a leg lifts on its forward half at full stride, in pixels.
@export var walk_lift: float = 1.5
## Speed at which the stride is fully blended in. Below it the walk is scaled
## down, so creeping along looks like creeping rather than marching.
@export var walk_reference_speed: float = 220.0
## Steps per second at full stride.
@export var walk_cycles_per_second: float = 2.4
## How quickly the legs blend between standing and walking.
@export var blend_speed: float = 9.0

@onready var _body: Node = get_node_or_null(body_path)
@onready var _left: Node2D = get_node_or_null(left_leg_path) as Node2D
@onready var _right: Node2D = get_node_or_null(right_leg_path) as Node2D

var _left_rest: Vector2
var _right_rest: Vector2
var _phase: float = 0.0
var _walking: float = 0.0


func _ready() -> void:
	if _left != null:
		_left_rest = _left.position
	if _right != null:
		_right_rest = _right.position


func _physics_process(delta: float) -> void:
	if _left == null and _right == null:
		return

	var goal := _speed_fraction()
	_walking = lerpf(_walking, goal, 1.0 - exp(-blend_speed * delta))

	# One phase for both legs, advancing faster the more stride is blended in, so
	# there is no moment where a walk cycle has to be started or stopped.
	var cycles := lerpf(idle_cycles_per_second, walk_cycles_per_second, _walking)
	_phase = fmod(_phase + cycles * TAU * delta, TAU)

	var swing := deg_to_rad(lerpf(idle_swing_degrees, walk_swing_degrees, _walking))
	var lift := lerpf(idle_lift, walk_lift, _walking)

	# Half a cycle apart: one leg is always forward while the other is back.
	_pose(_left, _left_rest, _phase, swing, lift)
	_pose(_right, _right_rest, _phase + PI, swing, lift)


## How much stride the character's current speed is worth, 0 to 1. Reads
## `velocity` off the body rather than requiring a [CharacterBody2D], so the same
## component works on anything that moves itself.
func _speed_fraction() -> float:
	if _body == null or walk_reference_speed <= 0.0 or not ("velocity" in _body):
		return 0.0
	var speed: float = (_body.get(&"velocity") as Vector2).length()
	return clampf(speed / walk_reference_speed, 0.0, 1.0)


## The leg swings about its hip and rises on the half of the cycle it is coming
## forward on, so the lift is always in step with the swing rather than being a
## second wobble on its own timing.
func _pose(leg: Node2D, rest: Vector2, phase: float, swing: float, lift: float) -> void:
	if leg == null:
		return
	leg.rotation = sin(phase) * swing
	leg.position = rest + Vector2(0.0, -lift * maxf(sin(phase), 0.0))
