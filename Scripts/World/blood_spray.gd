class_name BloodSpray
extends MultiMeshInstance2D
## Blood in the air on its way *out* of a body, before it has landed.
##
## Killing something used to stamp its blood straight onto the floor, which read
## as the blood having always been there. This is the missing half second: the
## shot arrives, the blood is thrown out the far side of the body along the way
## the damage was travelling, it arcs, and only where each piece comes down does a
## stain appear.
##
## What lands is not a copy or a decoration - it is the real thing. Every piece
## that touches the ground is offered to [BloodMagnet], which lies it on the floor
## for a moment and then draws it to the player; anything the magnet will not take
## - there is none in this world, or it is full - is handed to [BloodField]
## instead and becomes an ordinary permanent stain, exactly as it did before.
## Blood is therefore never lost to a busy frame, and a world with neither node
## simply stains the floor immediately as it always did.
##
## Like [BloodField] and [BloodStream] it is one [MultiMesh]: every piece in the
## air is an instance, so a whole wave's worth of deaths costs a single draw call
## and owns no nodes, no physics and no particle systems. Motion is integrated in
## flat parallel arrays with swap-removal, so a piece landing never shuffles the
## others.
##
## The arc is the same cheat [Casing] and [DeathDebris] use: gravity pulls the
## piece down the screen and it lands on a ground line a short drop below where it
## started. The game has no third axis - the drop is what stands in for one - and
## [member max_air_time] guarantees that a piece thrown at any angle still comes
## down rather than sailing off the map.
##
## This node must be [member CanvasItem.top_level]: instance transforms are
## written in world space.

## Emitted once per frame in which pieces landed, with how many did.
signal blood_landed(count: int)

## Group used by [method get_active], so [BloodEmitter] can find the spray without
## a NodePath across the scene.
const GROUP := &"blood_spray"

## Most pieces that can be in the air at once. A ceiling on both the memory and
## the per-frame integration cost; beyond it a launch stains the floor directly
## rather than being dropped, so blood is never lost to a full spray.
@export var capacity: int = 512:
	set(value):
		capacity = maxi(value, 1)
		if is_node_ready():
			_rebuild()

@export_group("Blast")
## Speed a piece is thrown at, along the blast. The range is what gives the spray
## a leading edge instead of moving as one wall.
@export var burst_force := Vector2(260.0, 620.0)
## Multiplier on the sideways component of that throw - how far *along* the hit
## the blood is driven.
@export var horizontal_force: float = 1.0
## Upward kick added on top, so the spray rises before it falls rather than
## sliding along the floor. Rolled per piece.
@export var vertical_force := Vector2(120.0, 320.0)
## Total angle the spray covers, in degrees, centred on the blast.
@export var spread_degrees: float = 54.0
## How much of the throw follows the hit. 1 sends it all out the far side; 0
## sprays evenly in every direction, which is what an unattributed death gets.
@export_range(0.0, 1.0) var directional_influence: float = 1.0

@export_group("Flight")
## Downward pull while airborne.
@export var gravity: float = 1100.0
## Drag on the piece's own speed, per second.
@export var drag: float = 1.1
## How long a piece may stay in the air before it is put down wherever it is. The
## guarantee that blood always lands and is always collectable.
@export var max_air_time: float = 0.75
## How far below its launch point a piece's ground is. This is what makes the
## flight an arc that ends rather than a straight line.
@export var landing_drop := Vector2(18.0, 54.0)
## How fast a piece tumbles while airborne, in radians per second.
@export var spin_speed := Vector2(-14.0, 14.0)

@export_group("Look")
## How much brighter blood is while it is still in the air. Fresh blood catches
## the light; the stain it leaves is the field's ordinary colour.
@export var airborne_brightness: float = 1.35
## Size in the air as a fraction of the size it lands at, so a piece settles into
## its stain rather than popping into it.
@export var airborne_scale: float = 0.75

var _multimesh: MultiMesh
var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _scales := PackedVector2Array()
var _colours := PackedColorArray()
var _rotations := PackedFloat32Array()
var _spins := PackedFloat32Array()
var _ages := PackedFloat32Array()
var _grounds := PackedFloat32Array()
var _count: int = 0

var _field: BloodField
var _magnet: BloodMagnet


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	# Every instance transform here is written by hand each frame, in world space.
	# Physics interpolation is on project-wide, and left on it would try to
	# interpolate those writes from the previous physics tick.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rebuild()


## The spray the rest of the scene should talk to. Null means this world has none,
## which every caller treats as "blood lands where it was spilled".
static func get_active(from_node: Node) -> BloodSpray:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BloodSpray


func get_in_flight_count() -> int:
	return _count


## Throws [param count] pieces out of [param at] along [param direction] - the way
## the killing damage was travelling, so the blood leaves out the far side of the
## body rather than back at whoever fired.
##
## Returns how many were actually launched. Anything that could not be - the spray
## already full - is stained onto the floor immediately instead, so the number of
## specks a kill is worth never depends on how busy the arena is.
func launch(at: Vector2, count: int, direction: Vector2 = Vector2.ZERO) -> int:
	var field := _get_field()
	if field == null:
		return 0
	_adopt_texture(field)

	var wanted := maxi(count, 0)
	var launched := 0
	for i: int in wanted:
		if _count >= capacity:
			# Never dropped: blood that has nowhere to fly still has to end up on
			# the floor, or a busy frame would quietly cost the player currency.
			field.add_speck_at(at)
			continue
		_add_piece(field, at, direction)
		launched += 1

	return launched


## Puts everything still in the air down where it is. Used when a spray is torn
## down mid-flight, so nothing is stranded.
func land_all() -> void:
	var field := _get_field()
	if field != null:
		for i: int in _count:
			field.add_speck_at(_positions[i])

	_count = 0
	if _multimesh != null:
		_multimesh.visible_instance_count = 0


func _add_piece(field: BloodField, at: Vector2, direction: Vector2) -> void:
	var index := _count

	# The aim is blended towards random rather than branched on, so
	# `directional_influence` is a real dial: at 1 the whole spray follows the hit,
	# at 0 it is a symmetrical burst, and the values between are a lean.
	var aim := Vector2.RIGHT.rotated(randf() * TAU)
	if not direction.is_zero_approx():
		var half := deg_to_rad(spread_degrees) * 0.5
		var aimed := direction.normalized().rotated(randf_range(-half, half))
		aim = aim.lerp(aimed, directional_influence).normalized()

	var speed := randf_range(burst_force.x, burst_force.y)
	var velocity := Vector2(aim.x * speed * horizontal_force, aim.y * speed)
	velocity.y -= randf_range(vertical_force.x, vertical_force.y)

	var speck := field.make_speck(at)
	_positions[index] = at
	_velocities[index] = velocity
	_scales[index] = speck.scale
	_colours[index] = speck.colour
	_rotations[index] = speck.rotation
	_spins[index] = randf_range(spin_speed.x, spin_speed.y)
	_ages[index] = 0.0
	_grounds[index] = at.y + randf_range(landing_drop.x, landing_drop.y)

	_count += 1
	_multimesh.visible_instance_count = _count
	_write_instance(index)


func _process(delta: float) -> void:
	if _count <= 0 or delta <= 0.0:
		return

	var field := _get_field()
	var landed := 0
	# Walked backwards so the swap-removal can only ever move a piece into a slot
	# this pass has already integrated.
	var i := _count - 1
	while i >= 0:
		if _advance(i, delta):
			_settle(field, i)
			_remove_at(i)
			landed += 1
		i -= 1

	if landed > 0:
		blood_landed.emit(landed)


## Integrates one piece. Returns true when it has come down and should become a
## permanent stain.
##
## A piece lands when it falls back past its ground line - it must be travelling
## downwards, so the rise out of the body is never mistaken for a landing - or
## when its air time runs out, whichever comes first. The second is the guarantee:
## whatever angle it was thrown at, it is on the floor and collectable within
## [member max_air_time].
func _advance(index: int, delta: float) -> bool:
	var age := _ages[index] + delta
	var speed := _velocities[index]
	speed.y += gravity * delta
	speed *= exp(-drag * delta)

	var at := _positions[index] + speed * delta

	_positions[index] = at
	_velocities[index] = speed
	_ages[index] = age
	_rotations[index] += _spins[index] * delta

	if age >= max_air_time:
		return true
	if speed.y > 0.0 and at.y >= _grounds[index]:
		_positions[index] = Vector2(at.x, _grounds[index])
		return true

	_write_instance(index)
	return false


## Hands one piece over at the instant it stops being in the air.
##
## The magnet gets first refusal, and it is handed the piece itself - the very
## colour, size and turn that was flying - rather than a position for something
## else to roll a fresh speck at. That is what makes the landing invisible: the
## same speck simply stops moving and lies there. Only blood the magnet will not
## take falls through to the floor, where the field rolls its own look as it
## always has.
func _settle(field: BloodField, index: int) -> void:
	var magnet := _get_magnet()
	if magnet != null and magnet.absorb(_read_piece(index)):
		return
	if field != null:
		field.add_speck_at(_positions[index])


func _read_piece(index: int) -> BloodField.Speck:
	var speck := BloodField.Speck.new()
	speck.position = _positions[index]
	speck.rotation = _rotations[index]
	speck.scale = _scales[index]
	speck.colour = _colours[index]
	return speck


## Brighter and slightly smaller than the stain it will become, so blood in the
## air is visibly *blood in the air* and settling into the floor is a change the
## player can see.
func _write_instance(index: int) -> void:
	var colour := _colours[index]
	var lit := Color(
		colour.r * airborne_brightness,
		colour.g * airborne_brightness,
		colour.b * airborne_brightness,
		colour.a)
	_multimesh.set_instance_transform_2d(index, Transform2D(
		_rotations[index], _scales[index] * airborne_scale, 0.0, _positions[index]))
	_multimesh.set_instance_color(index, lit)


## Swap-removal, matching [BloodField] and [BloodStream]: the last live piece
## fills the hole, so landing one is O(1) and no other piece's index moves.
func _remove_at(index: int) -> void:
	var last := _count - 1
	if index != last:
		_positions[index] = _positions[last]
		_velocities[index] = _velocities[last]
		_scales[index] = _scales[last]
		_colours[index] = _colours[last]
		_rotations[index] = _rotations[last]
		_spins[index] = _spins[last]
		_ages[index] = _ages[last]
		_grounds[index] = _grounds[last]
		_multimesh.set_instance_transform_2d(index, _multimesh.get_instance_transform_2d(last))
		_multimesh.set_instance_color(index, _multimesh.get_instance_color(last))

	_count = last
	_multimesh.visible_instance_count = _count


## Borrows the field's generated speck texture, so blood in the air is stamped
## with exactly the same art as blood on the floor and neither owns a second copy.
func _adopt_texture(field: BloodField) -> void:
	if texture == null and field != null:
		texture = field.texture


## Looked up lazily and re-looked-up if it goes away, the same way the base's pool
## finds it.
func _get_field() -> BloodField:
	if _field == null or not is_instance_valid(_field):
		_field = BloodField.get_active(self)
	return _field


## The same, for the player's pull. It lives on the player and this lives in the
## arena, so neither is guaranteed to have entered the tree before the other.
func _get_magnet() -> BloodMagnet:
	if _magnet == null or not is_instance_valid(_magnet):
		_magnet = BloodMagnet.get_active(self)
	return _magnet


func _rebuild() -> void:
	_positions.resize(capacity)
	_velocities.resize(capacity)
	_scales.resize(capacity)
	_colours.resize(capacity)
	_rotations.resize(capacity)
	_spins.resize(capacity)
	_ages.resize(capacity)
	_grounds.resize(capacity)
	_count = mini(_count, capacity)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = capacity
	_multimesh.visible_instance_count = _count
	multimesh = _multimesh
