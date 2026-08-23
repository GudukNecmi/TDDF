class_name FootprintField
extends MultiMeshInstance2D
## Every footprint on the map, drawn as a single [MultiMesh].
##
## Built the same way [BloodField] is, and for the same reason: one print is one
## instance in one mesh, so a player and a screenful of enemies all leaving
## tracks cost a single draw call, own no nodes, and have no physics of any kind.
## A [MultiMeshInstance2D] has no shape at all, so footprints can never affect
## movement, block a pellet or be collided with.
##
## The one thing this does that blood does not is forget. Prints last
## [member lifetime] seconds and then go, which makes the storage simpler rather
## than harder: they expire in exactly the order they were made, so the field is
## a plain ring buffer over a fixed number of slots with an oldest and a newest,
## and expiring one is moving an index. Nothing is searched and nothing is
## shuffled.
##
## The per-frame cost is deliberately proportional to how many prints are
## *fading* rather than to how many exist. A print sits at full strength for most
## of its life and is only written to once it enters its last
## [member fade_time] seconds, so a hundred tracks on the ground are a handful of
## writes a frame.
##
## Find it with [method get_active] rather than a NodePath, the same way
## [BloodField] and [CameraController] are found - which is what lets an enemy
## spawned mid-run start leaving prints without being wired to anything.

## Group used by [method get_active].
const GROUP := &"footprint_field"

## How many prints can exist at once. One draw call regardless; this is the
## ceiling on memory and on how much ground can be covered before the oldest
## tracks start being recycled early.
@export var capacity: int = 1200:
	set(value):
		capacity = maxi(value, 1)
		if is_node_ready():
			_rebuild()
## Seconds a print stays on the ground before it is gone completely.
@export var lifetime: float = 4.0
## How much of the end of that life is spent fading out. The rest is spent at
## full strength. Larger than [member lifetime] simply means it fades the whole
## time.
@export var fade_time: float = 1.2

@export_group("Look")
## Colour of a print. Dark orange for the desert - a map with different ground
## sets this, the same way it sets its shadow colour.
@export var colour := Color(0.47, 0.20, 0.11)
## How dark a fresh print is.
@export_range(0.0, 1.0) var opacity: float = 0.5
## Size of one print in pixels, before per-print variation.
@export var print_size := Vector2(11.0, 9.0)
## Fraction the size is randomly scaled by, per print and per axis.
@export_range(0.0, 0.9) var size_variation: float = 0.18
## Resolution of the generated soft-disc texture every print is stamped with.
@export var texture_size: int = 32
## How hard a print's edge is. 0 is a smudge, 1 is a hard circle.
@export_range(0.0, 1.0) var edge_hardness: float = 0.55

var _multimesh: MultiMesh
## Age clock per slot, in seconds since the print was stamped. Only meaningful
## for the [member _count] slots from [member _oldest] onwards.
var _stamped_at := PackedFloat32Array()
var _oldest: int = 0
var _count: int = 0
## How many slots have ever been used, so an empty field draws nothing at all
## rather than a capacity's worth of degenerate quads.
var _high_water: int = 0
var _clock: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	# Prints never move once stamped, so there is nothing to interpolate - and
	# leaving project-wide physics interpolation on would try to blend each new
	# print in from wherever that instance slot last was.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if texture == null:
		texture = _build_print_texture()
	_rebuild()


## The field the rest of the world should talk to. Null means this map has no
## footprints, which every emitter reads as "do not bother".
static func get_active(from_node: Node) -> FootprintField:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as FootprintField


func get_print_count() -> int:
	return _count


## Stamps one print at [param at]. [param angle] turns it and
## [param size_multiplier] scales it, so a caller can make a running stride's
## prints larger than a walking one's without a second set of look settings here.
##
## Returns false only if the field has no capacity at all. A full field recycles
## its oldest print, which is right rather than a compromise: the oldest is the
## one closest to expiring anyway.
func add_print(at: Vector2, angle: float = 0.0, size_multiplier: float = 1.0) -> bool:
	if _multimesh == null or capacity <= 0:
		return false

	var slot := (_oldest + _count) % capacity
	if _count >= capacity:
		# Full: the newest print lands on the oldest slot and the ring's start
		# moves up one, so the count stays put and nothing is shuffled.
		_oldest = (_oldest + 1) % capacity
	else:
		_count += 1

	var print_scale := Vector2(
		print_size.x * (1.0 + randf_range(-size_variation, size_variation)),
		print_size.y * (1.0 + randf_range(-size_variation, size_variation))
	) * maxf(size_multiplier, 0.0)

	_stamped_at[slot] = _clock
	_multimesh.set_instance_transform_2d(slot, Transform2D(angle, print_scale, 0.0, at))
	_multimesh.set_instance_color(slot, _colour_at(0.0))

	if slot >= _high_water:
		_high_water = slot + 1
		_multimesh.visible_instance_count = _high_water
	return true


## Empties the field. Only needed when a map is torn down in place; the normal
## "next run" path rebuilds the whole World scene instead.
func clear_all() -> void:
	for i: int in _high_water:
		_hide_slot(i)
	_oldest = 0
	_count = 0


## Ages the ring from its oldest end. Two walks, both of which stop the moment
## they reach a print that is not old enough to care about - and since prints
## expire in the order they were made, everything past that point is younger
## still. The whole update is therefore proportional to how many prints are
## actually fading, not to how many are lying on the ground.
func _process(delta: float) -> void:
	if _count <= 0:
		return

	_clock += delta
	var life := maxf(lifetime, 0.01)
	var fade := clampf(fade_time, 0.0, life)
	var fade_starts := life - fade

	while _count > 0:
		var slot := _oldest
		var age := _clock - _stamped_at[slot]
		if age < life:
			break
		_hide_slot(slot)
		_oldest = (_oldest + 1) % capacity
		_count -= 1

	for i: int in _count:
		var slot := (_oldest + i) % capacity
		var age := _clock - _stamped_at[slot]
		if age < fade_starts:
			break
		_multimesh.set_instance_color(
			slot, _colour_at(clampf((age - fade_starts) / maxf(fade, 0.0001), 0.0, 1.0)))


## An expired print is scaled away to nothing as well as being made transparent,
## so its slot costs no fill rate at all while it waits to be reused.
func _hide_slot(slot: int) -> void:
	_multimesh.set_instance_transform_2d(slot, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
	_multimesh.set_instance_color(slot, Color(colour.r, colour.g, colour.b, 0.0))


func _colour_at(faded: float) -> Color:
	return Color(colour.r, colour.g, colour.b, opacity * (1.0 - faded))


func _rebuild() -> void:
	_stamped_at.resize(capacity)
	_oldest = 0
	_count = 0
	_high_water = 0

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = capacity
	_multimesh.visible_instance_count = 0
	multimesh = _multimesh


## A soft-edged disc, generated rather than shipped as art - the same one
## [BloodField] stamps its specks with. Per-instance colour tints it and the
## independent X/Y scale squashes it, so one texture covers every print.
func _build_print_texture() -> Texture2D:
	var gradient := Gradient.new()
	var edge := clampf(edge_hardness, 0.0, 0.99)
	gradient.offsets = PackedFloat32Array([0.0, edge, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])

	var built := GradientTexture2D.new()
	built.gradient = gradient
	built.width = maxi(texture_size, 1)
	built.height = maxi(texture_size, 1)
	built.fill = GradientTexture2D.FILL_RADIAL
	built.fill_from = Vector2(0.5, 0.5)
	built.fill_to = Vector2(1.0, 0.5)
	return built
