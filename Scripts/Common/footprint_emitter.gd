class_name FootprintEmitter
extends Node
## Leaves tracks behind a character that is walking. Dropped onto the player and
## onto every enemy; the only thing that differs between them is the numbers.
##
## [b]Where a print goes is measured, never assumed.[/b] The emitter is given the
## character's feet - the same leg sprites [LegAnimator] is already swinging -
## and each print is stamped at the lowest point of whichever foot is taking the
## step, worked out from that sprite's live global transform and the opaque part
## of its artwork (see [SpriteBounds]). So the print lands under the toe that is
## actually down: mid-stride, lifted, rotated, squashed by the idle breath, or
## mirrored by a [FacingFlip]. Replacing the walk animation moves the prints with
## it and nothing here has to be told that it changed. There is no offset from
## the character's centre anywhere in this file, because a centre is exactly the
## thing that stops being right when the animation changes.
##
## [b]When a print goes down is a distance, not a timer.[/b] One print per
## [member step_distance] of ground covered means the spacing on the floor is the
## same whether the character is sprinting or creeping, and a character that has
## been slowed leaves closer-spaced prints in time without leaving them closer
## together in space. The feet are used in turn, so the tracks alternate.
##
## The field itself is found by group, so an enemy spawned in the middle of a run
## starts leaving prints with no wiring at all - and a map with no
## [FootprintField] simply has no footprints, with nothing here failing.

## Character being followed. Anything with a `velocity` works; with none, the
## emitter measures how far its own owner has moved instead.
@export var body_path: NodePath = ^".."
## The feet, used in turn. Normally the two leg sprites. Anything that is not a
## sprite falls back to its own origin, so a bare marker works as a foot too.
@export var foot_paths: Array[NodePath] = []
## Whether prints are left at all. Off is how a character that should leave none
## - something that hovers, something already dead - is switched off in the
## inspector rather than by removing the node.
@export var enabled: bool = true

@export_group("Stride")
## Ground covered between one print and the next, in pixels. This is the spacing
## of the tracks on the floor.
@export var step_distance: float = 26.0
## How fast the character has to be going before it leaves any prints at all, in
## pixels per second. Keeps a character being shoved about while standing still
## from writing all over the floor.
@export var minimum_speed: float = 24.0

@export_group("Look")
## Size of this character's prints relative to the field's own size. A heavier
## thing leaves a bigger mark without a second set of look settings existing.
@export var print_scale: float = 1.0
## Whether prints are turned to face the way the character is going. Round prints
## do not need it; it is here for artwork that is not round.
@export var align_to_travel: bool = false

@onready var _body: Node2D = get_node_or_null(body_path) as Node2D

var _feet: Array[Node2D] = []
var _field: FootprintField
var _travelled: float = 0.0
var _foot: int = 0
var _previous_position: Vector2


func _ready() -> void:
	for path: NodePath in foot_paths:
		var foot := get_node_or_null(path) as Node2D
		if foot != null:
			_feet.append(foot)

	if _body != null:
		_previous_position = _body.global_position

	# Nothing to stamp with and nothing to stamp for are both "do nothing", and
	# both are cheaper to decide once here than on every frame.
	set_physics_process(_body != null and not _feet.is_empty())


func _physics_process(delta: float) -> void:
	var moved := _body.global_position - _previous_position
	_previous_position = _body.global_position

	if not enabled or delta <= 0.0:
		return

	var travel := _travel(moved, delta)
	if travel.length() < minimum_speed:
		return

	# Measured from how far the body has genuinely moved rather than from its
	# intended speed, so walking into a wall or into a cactus does not lay down a
	# track the character never made.
	_travelled += moved.length()
	var step := maxf(step_distance, 1.0)
	while _travelled >= step:
		_travelled -= step
		_stamp(travel)


## The direction and speed to judge the stride by: the body's own `velocity`
## where it has one, and otherwise how far it actually moved this frame.
func _travel(moved: Vector2, delta: float) -> Vector2:
	if _body != null and "velocity" in _body:
		return _body.get(&"velocity") as Vector2
	return moved / delta


func _stamp(travel: Vector2) -> void:
	var field := _get_field()
	if field == null:
		return

	var foot := _feet[_foot % _feet.size()]
	_foot += 1
	if not is_instance_valid(foot):
		return

	var angle := 0.0
	if align_to_travel and not travel.is_zero_approx():
		angle = travel.angle()

	field.add_print(SpriteBounds.lowest_point(foot), angle, print_scale)


## Looked up lazily and re-looked-up if it goes away, the same way [BloodField]
## and [CameraController] are found - the field may enter the tree after this
## character does, and an enemy spawned mid-run arrives long after both.
func _get_field() -> FootprintField:
	if _field == null or not is_instance_valid(_field):
		_field = FootprintField.get_active(self)
	return _field
