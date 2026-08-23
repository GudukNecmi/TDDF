class_name BloodField
extends MultiMeshInstance2D
## Permanent blood decals on the arena floor, drawn as a single [MultiMesh].
##
## Every speck is one instance in one mesh, so the whole field - thousands of
## splatters - costs a single draw call and owns no nodes, no physics and no
## particle systems. Nothing here collides with anything: a [MultiMeshInstance2D]
## has no shape at all, so blood can never affect movement or pellets.
##
## Specks are never removed by time. They stay for the whole run and survive the
## player dying, because nothing in the run's lifecycle touches them - the field
## is only emptied when the World scene itself is rebuilt for a new run (see
## [RunEndScreen], which reloads the scene), or by an explicit [method clear_all].
##
## Storage is a plain flat array with swap-removal, so removing a speck is O(1)
## and never shuffles the rest. Positions are mirrored locally in
## [member _positions] rather than read back from the rendering server, so the
## area query in [method take_specks_near] walks contiguous memory.
##
## Find it from anywhere with [method get_active] rather than a NodePath, the
## same way [CameraController] is located.

## Group used by [method get_active] to find the field without a NodePath.
const GROUP := &"blood_field"

## How many specks can exist at once. One draw call regardless, but every
## instance still costs memory and a little GPU time, so this is the ceiling on
## how dirty the arena can get.
@export var capacity: int = 8000:
	set(value):
		capacity = maxi(value, 1)
		if is_node_ready():
			_rebuild()
## When the field is full, the oldest specks are recycled instead of new blood
## being dropped. Turn this off to simply stop accumulating at [member capacity].
@export var recycle_oldest_when_full: bool = true

@export_group("Splash")
## Specks dropped per enemy death. [BloodEmitter] can override this per enemy.
@export var specks_per_splash: int = 16
## How far specks scatter from the death point.
@export var splash_radius: float = 30.0
## Bias towards the centre of the splash. 1 spreads evenly across the disc,
## higher values clump the specks near the middle and throw a few stragglers out.
@export_range(0.5, 4.0) var splash_falloff: float = 1.7
## How far a splash is dragged along the direction it was given, as a fraction of
## each speck's own scatter distance. Only applies when the caller passes a
## direction; 0 leaves every splash a symmetrical disc.
@export var splash_direction_stretch: float = 1.0

@export_group("Speck look")
## Base size of one speck in pixels, before per-speck variation.
@export var speck_size := Vector2(9.0, 7.0)
## Fraction the size is randomly scaled by, per speck and per axis - the two axes
## vary independently, which is what turns round blobs into irregular smears.
@export_range(0.0, 0.95) var size_variation: float = 0.55
## Colours a speck is picked from at random.
@export var colours: PackedColorArray = PackedColorArray([
	Color(0.44, 0.03, 0.04),
	Color(0.32, 0.02, 0.03),
	Color(0.53, 0.06, 0.05),
	Color(0.24, 0.01, 0.02),
])
## Random opacity range for a speck. Overlapping specks build up, so individually
## translucent blood still reads as solid where kills pile up.
@export var alpha_range := Vector2(0.55, 0.92)
## Resolution of the generated soft-disc texture every speck is stamped with.
@export var texture_size: int = 32
## How hard the speck's edge is. 0 is a soft glow, 1 is a hard circle.
@export_range(0.0, 1.0) var edge_hardness: float = 0.72

var _multimesh: MultiMesh
var _positions := PackedVector2Array()
var _count: int = 0
var _recycle_cursor: int = 0


## One visual speck: a position, and the look it is drawn with. Plain data with no
## owner, which is what lets the same speck be thrown by [BloodSpray], lie on this
## floor, and then be flowed to the player by [BloodStream] without ever being
## rebuilt or copied into a different shape.
class Speck:
	var position: Vector2
	var rotation: float
	var scale: Vector2
	var colour: Color


func _ready() -> void:
	add_to_group(GROUP)
	# Specks never move once stamped, so there is nothing to interpolate. Leaving
	# project-wide physics interpolation on would only try to blend each new
	# speck in from wherever that instance slot last was, and warns whenever a
	# splash is added outside a physics frame.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if texture == null:
		texture = _build_speck_texture()
	_rebuild()


## The field the rest of the scene should talk to. Returns null when the world
## has none, which every caller treats as "blood is switched off".
static func get_active(from_node: Node) -> BloodField:
	return from_node.get_tree().get_first_node_in_group(GROUP) as BloodField


func get_speck_count() -> int:
	return _count


func is_full() -> bool:
	return _count >= capacity


## Drops a burst of specks around [param at]. [param count] below 0 uses
## [member specks_per_splash]. Returns how many were actually added.
##
## [param direction] is optional and need not be normalised: passing the way the
## killing blow was travelling smears the splash along it. Leaving it out gives
## the plain symmetrical disc, so callers that do not care are unaffected.
func add_splash(at: Vector2, count: int = -1, direction: Vector2 = Vector2.ZERO) -> int:
	var wanted := specks_per_splash if count < 0 else count
	var added := 0
	for i: int in maxi(wanted, 0):
		if _add_speck(at + _splash_offset(direction)):
			added += 1
	return added


## Stains the floor at exactly [param at], with none of [method add_splash]'s
## scatter. Returns false only when the field is full and recycling is off.
##
## This is what blood that has *travelled* lands with when nothing else claims it:
## [BloodSpray] throws pieces out of a body, arcs them through the air, and stamps
## each one here where it finally came down. The scatter belongs to the flight in
## that case, not to the stamping, so a second helping of it would only smear the
## landing points back into a disc and undo the throw.
##
## What lands is an ordinary speck in every other way - same look, same storage,
## same slot - so nothing downstream has to know it flew.
func add_speck_at(at: Vector2) -> bool:
	return _add_speck(at)


## Builds one speck with this field's own look - size, colour and opacity - but
## does NOT add it to the field and leaves no stain behind.
##
## It exists so blood that never came off this floor can still be drawn as the
## same blood: [BloodSpray] throws pieces built here out of a body, and the base's
## pool sends them between the player and the basin with [BloodStream]. Taking
## their appearance from here is what stops a second set of colour and size
## settings existing somewhere else and drifting.
func make_speck(at: Vector2) -> Speck:
	var speck := Speck.new()
	speck.position = at
	speck.rotation = randf() * TAU
	speck.scale = _random_speck_scale()
	speck.colour = _random_speck_colour()
	return speck


## One speck of a splash - this field's own look, scattered exactly the way
## [method add_splash] would have scattered it - built but [i]not[/i] added, and
## leaving no stain.
##
## It is what lets a caller spill a splash somewhere other than the floor without
## reimplementing the scatter. [BloodEmitter] uses it to hand a death's blood
## straight to [BloodMagnet] when the blood is not being thrown, so the shape of
## an unthrown splash is identical whether it stays on the ground or is drawn to
## the player.
func make_splash_speck(at: Vector2, direction: Vector2 = Vector2.ZERO) -> Speck:
	return make_speck(at + _splash_offset(direction))


## Removes up to [param max_count] specks lying within [param max_range] of
## [param origin] and returns them as [Speck] data. They are gone from the field
## the instant this returns, so the caller owns them and is responsible for
## drawing them from then on.
##
## Nothing in the game calls this: blood is claimed by [BloodMagnet] as it lands,
## before it ever becomes a stain, so what is in the field is the blood that has
## been left behind on purpose. It is kept because lifting settled blood off the
## floor is the obvious shape of a future upgrade, and because it is the only way
## anything can ever get a speck back out.
##
## Walked backwards, so the freshest blood is taken first and the swap-removal
## inside the loop can only ever move a speck into a slot already tested.
func take_specks_near(origin: Vector2, max_range: float, max_count: int) -> Array:
	var taken: Array = []
	if max_count <= 0 or _count <= 0:
		return taken

	var range_squared := max_range * max_range
	var i := _count - 1
	while i >= 0 and taken.size() < max_count:
		if (_positions[i] - origin).length_squared() <= range_squared:
			taken.append(_read_speck(i))
			_remove_at(i)
		i -= 1

	return taken


## Empties the field. Only used when a run is torn down in place; the normal
## "next run" path rebuilds the whole World scene instead.
func clear_all() -> void:
	_count = 0
	_recycle_cursor = 0
	if _multimesh != null:
		_multimesh.visible_instance_count = 0


func _rebuild() -> void:
	_positions.resize(capacity)
	_count = mini(_count, capacity)
	_recycle_cursor = 0

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = capacity
	_multimesh.visible_instance_count = _count
	multimesh = _multimesh


## Appends one speck, or recycles the oldest when the field is full. Returns
## false only when the field is full and recycling is switched off.
func _add_speck(at: Vector2) -> bool:
	var index := _count
	if index >= capacity:
		if not recycle_oldest_when_full:
			return false
		# _count == capacity here, so the cursor is a plain ring over the array.
		index = _recycle_cursor
		_recycle_cursor = (_recycle_cursor + 1) % capacity
	else:
		_count += 1
		_multimesh.visible_instance_count = _count

	_positions[index] = at
	_multimesh.set_instance_transform_2d(index, Transform2D(
		randf() * TAU, _random_speck_scale(), 0.0, at))
	_multimesh.set_instance_color(index, _random_speck_colour())
	return true


## Denser near the centre: raising a uniform 0..1 roll to a power above 1 pulls
## most samples inwards, so a splash has a solid core instead of reading as a
## uniformly speckled ring.
##
## The directional drag is scaled by that same distance rather than being a flat
## push, so the core stays put over the death point and only the stragglers get
## thrown downrange - which is what reads as a spray rather than a moved blob.
func _splash_offset(direction: Vector2 = Vector2.ZERO) -> Vector2:
	var distance := pow(randf(), splash_falloff) * splash_radius
	var offset := Vector2(distance, 0.0).rotated(randf() * TAU)
	if direction.is_zero_approx():
		return offset
	return offset + direction.normalized() * distance * splash_direction_stretch


func _random_speck_scale() -> Vector2:
	return Vector2(
		speck_size.x * (1.0 + randf_range(-size_variation, size_variation)),
		speck_size.y * (1.0 + randf_range(-size_variation, size_variation)))


func _random_speck_colour() -> Color:
	var base := Color(0.4, 0.03, 0.04)
	if not colours.is_empty():
		base = colours[randi() % colours.size()]
	base.a = randf_range(
		minf(alpha_range.x, alpha_range.y), maxf(alpha_range.x, alpha_range.y))
	return base


func _read_speck(index: int) -> Speck:
	var placement := _multimesh.get_instance_transform_2d(index)
	var speck := Speck.new()
	speck.position = _positions[index]
	speck.rotation = placement.get_rotation()
	speck.scale = placement.get_scale()
	speck.colour = _multimesh.get_instance_color(index)
	return speck


## Swap-removal: the last live speck is moved into the hole. O(1), and no other
## speck's index changes, which is why in-flight specks are handed out as copies
## rather than as indices into this array.
func _remove_at(index: int) -> void:
	var last := _count - 1
	if index != last:
		_multimesh.set_instance_transform_2d(index, _multimesh.get_instance_transform_2d(last))
		_multimesh.set_instance_color(index, _multimesh.get_instance_color(last))
		_positions[index] = _positions[last]

	_count = last
	_multimesh.visible_instance_count = _count
	_recycle_cursor = 0 if _count <= 0 else _recycle_cursor % _count


## A soft-edged disc, generated rather than shipped as art. Per-instance colour
## tints it, and the independent X/Y instance scale squashes it into a smear, so
## one texture covers every speck in the field.
func _build_speck_texture() -> Texture2D:
	var gradient := Gradient.new()
	var edge := clampf(edge_hardness, 0.0, 0.99)
	gradient.offsets = PackedFloat32Array([0.0, edge, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])

	var built := GradientTexture2D.new()
	built.gradient = gradient
	built.width = texture_size
	built.height = texture_size
	built.fill = GradientTexture2D.FILL_RADIAL
	built.fill_from = Vector2(0.5, 0.5)
	built.fill_to = Vector2(1.0, 0.5)
	return built
