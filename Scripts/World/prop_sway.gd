class_name PropSway
extends Node2D
## Makes a piece of scenery bend rather than stand there: a slow lean in the wind
## while nothing is happening, and a quick knock when something walks into it.
##
## It is one rotation on one node, and everything the prop draws hangs under it,
## so the pivot is the node's own origin - which [PropArt] has already placed on
## the plant's base. A cactus therefore bends at the ground rather than pivoting
## about its middle, with nothing here knowing which plant it is.
##
## The two motions are separate and simply add up:
##
##   * the [b]idle[/b] is a sine, and is what a bush does forever. Each prop is
##     given its own starting phase, so a field of them ripples instead of
##     breathing in unison. Setting [member idle_degrees] to 0 switches it off
##     entirely, which is what a cactus and a bone want - they are still until
##     they are touched.
##   * the [b]knock[/b] is a damped oscillation started by [method nudge]. Its
##     size is whatever the caller passes in, so the same component gives a cactus
##     a slow lean away from the player and a bone a fast 4-degree shiver, with
##     the difference living in the inspector on each prop.
##
## A prop with no idle stops processing the moment its knock has died away, so a
## few hundred of them across a map cost nothing while nobody is near them.

## Lean either way at rest, in degrees. 0 leaves the prop completely still until
## something touches it.
@export var idle_degrees: float = 0.0
## Idle sways per second. Slow reads as wind; fast reads as broken.
@export var idle_cycles_per_second: float = 0.32
## Spread of idle speed between individual props, as a fraction. Without a little
## of this a field of bushes visibly beats in and out of step with itself.
@export_range(0.0, 0.9) var idle_speed_variation: float = 0.25

@export_group("Knock")
## Peak lean of a knock at strength 1, in degrees. What a [PropTouch] passing 1
## is asking for.
@export var knock_degrees: float = 7.0
## Oscillations per second while a knock rings out. High is a shiver, low is a
## sway.
@export var knock_cycles_per_second: float = 2.6
## How quickly a knock dies away. Higher settles sooner.
@export var knock_damping: float = 4.5
## Ceiling on the whole angle, idle and knock together, so nothing can be driven
## over on its side however often it is walked into.
@export var max_degrees: float = 26.0

var _idle_phase: float = 0.0
var _idle_speed: float = 1.0
var _knock_amplitude: float = 0.0
var _knock_time: float = 0.0
var _knock_direction: float = 1.0
var _rest_rotation: float = 0.0


func _ready() -> void:
	_rest_rotation = rotation
	_idle_phase = randf() * TAU
	_idle_speed = 1.0 + randf_range(-idle_speed_variation, idle_speed_variation)
	set_process(_wants_process())


## Knocks the prop. [param strength] scales [member knock_degrees], so 1 is the
## authored knock and a caller can pass a fraction for a glancing touch.
## [param direction] is which way it leans first: positive is clockwise.
##
## Retriggering takes the stronger of the two rather than adding, so walking back
## and forth through a bush cannot wind it up - and, being a max, a light brush
## during a heavy knock can never cut the heavy one short either.
func nudge(strength: float = 1.0, direction: float = 1.0) -> void:
	var amplitude := absf(strength) * knock_degrees
	if amplitude <= _current_knock_size():
		return

	_knock_amplitude = amplitude
	_knock_time = 0.0
	_knock_direction = 1.0 if direction >= 0.0 else -1.0
	set_process(true)


func _process(delta: float) -> void:
	var angle := 0.0

	if idle_degrees != 0.0:
		_idle_phase += idle_cycles_per_second * _idle_speed * TAU * delta
		angle += sin(_idle_phase) * idle_degrees

	if _knock_amplitude > 0.0:
		_knock_time += delta
		angle += _knock_offset()
		if _current_knock_size() < 0.05:
			_knock_amplitude = 0.0

	rotation = _rest_rotation + deg_to_rad(clampf(angle, -max_degrees, max_degrees))

	if not _wants_process():
		set_process(false)


## A decaying sine, so the prop rocks past centre a couple of times on its way
## back to rest instead of easing back like a door.
func _knock_offset() -> float:
	return _current_knock_size() \
		* sin(_knock_time * knock_cycles_per_second * TAU) \
		* _knock_direction


func _current_knock_size() -> float:
	if _knock_amplitude <= 0.0:
		return 0.0
	return _knock_amplitude * exp(-maxf(knock_damping, 0.0) * _knock_time)


func _wants_process() -> bool:
	return idle_degrees != 0.0 or _knock_amplitude > 0.0
