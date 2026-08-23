class_name BreakProfile
extends Resource
## How a thing comes apart when it breaks: into how many pieces, where the cut
## falls across its artwork, and how hard the pieces are thrown from it.
##
## [b]The pieces are the object's own picture, cut up.[/b] Nothing here holds any
## artwork of its own. The sprite that broke is copied once per piece and each copy
## is given a slice of the same texture through [member Sprite2D.region_rect], so a
## knife breaks into the blade and the handle it was actually drawn with - and one
## of ten knife variants breaks into pieces of [i]that[/i] variant, with no set of
## piece textures to author for each and none to keep in step when a new one is
## dropped in.
##
## [b]What happens to a piece afterwards is not here either.[/b] Each one is handed
## to a [DeathDebris] - the same component a severed head and a dropped knife have
## always used - so a piece is thrown, falls, bounces, rolls and fades by exactly
## the code that already did all of that, and there is no second notion of debris
## in the game.
##
## This resource is therefore only the numbers, which is what lets a knife and a
## bone break differently by being pointed at different [code].tres[/code] files
## rather than by anything in code knowing which of them broke.

## How many pieces the artwork is cut into.
@export var piece_count: int = 2
## Whether the cut runs across the picture's width, which splits a knife into its
## blade and its handle and a bone into its two ends. Off cuts across its height
## instead, for artwork drawn upright.
@export var split_across_width: bool = true
## Colour the pieces are left in. Slightly drained, so a piece lying on the floor
## does not look fresher than the thing it came off. White leaves the artwork
## exactly as it was drawn.
@export var piece_tint := Color(0.86, 0.74, 0.72)

@export_group("Throw")
## How hard the pieces are thrown apart, in pixels per second. They leave along the
## break in alternating directions, so two pieces genuinely separate rather than
## travelling together.
@export var sideways_speed: float = 190.0
## How hard they are thrown upwards as they come apart. This is what makes a break
## read as the thing bursting rather than as it sliding into halves.
@export var lift_force: float = 170.0
## The piece spread: how much the two throws above are randomised, as a fraction of
## themselves. 0 throws every piece identically, which reads as a mechanism rather
## than as something breaking.
@export_range(0.0, 2.0) var spread: float = 0.45
## How far below the break the ground is, in pixels - rolled per piece. Short, in
## keeping with how the rest of the game fakes height.
@export var drop_range := Vector2(18.0, 38.0)

@export_group("Ground")
## Downward pull on a piece still in the air.
@export var gravity: float = 1500.0
## How much of its speed a bounce keeps.
@export_range(0.0, 1.0) var bounce: float = 0.4
## How quickly the roll bleeds off once a piece is down. Higher stops it sooner.
@export var ground_friction: float = 2.2
## How long a piece lies still before it starts to fade.
@export var settle_time: float = 0.7
## How long the fade itself takes. Together with the settle above this is the whole
## of how long broken pieces are left on the ground. 0 leaves them there for good.
@export var fade_time: float = 1.2

## Where each texture's drawn pixels sit on its sheet, worked out once and shared by
## every profile in the process. See [method _used_rect].
static var _used_rects: Dictionary = {}


## Breaks [param source] into [member piece_count] pieces, parented to
## [param container] and thrown out along [param along]. Returns the carriers, for
## anything that wants to watch them.
##
## The source sprite is only ever read, never taken or freed, so whoever called
## this still owns the thing that broke and decides what becomes of it.
func shatter(
	source: Sprite2D,
	container: Node,
	along: Vector2 = Vector2.RIGHT
) -> Array[DeathDebris]:
	var made: Array[DeathDebris] = []
	if source == null or not is_instance_valid(source) or container == null:
		return made
	if source.texture == null:
		return made

	# Read once, before any piece exists: every piece is placed against where the
	# whole thing was standing at the instant it broke.
	var drawn := _drawn_rect(source)
	var full := _cut_rect(source, drawn)
	var at := source.global_position
	var turn := source.global_rotation
	var size := source.global_scale

	var side := signf(along.x)
	if is_zero_approx(side):
		side = 1.0 if randf() < 0.5 else -1.0

	for index: int in maxi(piece_count, 1):
		var carrier := DeathDebris.new()
		carrier.gravity = gravity
		carrier.bounce = bounce
		carrier.ground_friction = ground_friction
		carrier.settle_time = settle_time
		carrier.fade_time = fade_time

		container.add_child(carrier)
		# Named after it is in the tree, so the name survives rather than being
		# replaced by the generated one a node built in code otherwise gets.
		carrier.name = "BrokenPiece"
		carrier.global_position = at

		# The carrier is what turns and travels; the piece keeps the drawing offset
		# and scale it had on the whole object, so it spins about where it broke
		# rather than about the corner of its texture.
		var piece := _cut(source, drawn, full, index)
		carrier.add_child(piece)
		piece.rotation = turn
		piece.scale = size
		piece.modulate = piece_tint
		carrier.reset_physics_interpolation()

		# Alternating, so the pieces leave in different directions. Two halves thrown
		# the same way is a thing sliding; two thrown apart is a thing breaking.
		var lean := 1.0 if index % 2 == 0 else -1.0
		carrier.launch(
			Vector2(
				side * lean * sideways_speed * (1.0 + randf_range(-spread, spread)),
				-lift_force * (1.0 + randf_range(-spread, spread))),
			randf_range(minf(drop_range.x, drop_range.y), maxf(drop_range.x, drop_range.y)))
		made.append(carrier)

	return made


## The part of the texture the whole object is currently drawing - the region when
## it is drawing one, and otherwise the whole sheet. Every piece's placement is
## measured against this, because this is what the sprite's offset already refers to.
func _drawn_rect(source: Sprite2D) -> Rect2:
	if source.region_enabled and source.region_rect.size.x > 0.0 \
			and source.region_rect.size.y > 0.0:
		return source.region_rect
	return Rect2(Vector2.ZERO, source.texture.get_size())


## The part that is actually cut up, which is the part with something drawn on it.
##
## [b]It is not the sheet.[/b] Held artwork in this project is drawn small on a large
## square canvas - the enemy's knife is a few hundred pixels of blade in the corner of
## a 1000 by 1000 sheet - so cutting the sheet in half hands out one piece with the
## whole knife on it and one piece of empty air. Cutting the drawn pixels instead is
## what makes two halves two halves, and it needs no measurement authored per texture:
## it is asked of the image, so all ten knife variants and the bone answer for
## themselves.
func _cut_rect(source: Sprite2D, drawn: Rect2) -> Rect2:
	if source.region_enabled:
		return drawn
	var used := _used_rect(source.texture)
	# Guarded rather than trusted: a texture that reports nothing usable is cut as a
	# whole, which is the old behaviour and never worse than not breaking at all.
	if used.size.x <= 0.0 or used.size.y <= 0.0:
		return drawn
	return used


## Where the drawn pixels of [param texture] actually sit on its sheet.
##
## Cached for the process, because reading it costs an image fetch and a scan of
## every pixel - once per texture is nothing, once per broken knife in a firefight
## would be felt.
static func _used_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	var key := texture.get_rid()
	if _used_rects.has(key):
		return _used_rects[key]

	var found := Rect2()
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		found = Rect2(image.get_used_rect())
	_used_rects[key] = found
	return found


## One slice of the whole picture, drawn where that slice sat inside it.
##
## [b]The offset is the whole of the trick.[/b] A sprite showing a region draws it
## at the sprite's own origin, so every piece would otherwise be stacked in the same
## place - the blade drawn over the handle. Shifting the offset by how far into the
## picture the cut was puts each slice back where it belongs, which is what makes
## the pieces look like a thing coming apart on the frame it breaks.
func _cut(source: Sprite2D, drawn: Rect2, full: Rect2, index: int) -> Sprite2D:
	var count := maxi(piece_count, 1)
	var region := full
	if split_across_width:
		region.size.x = full.size.x / float(count)
		region.position.x = full.position.x + region.size.x * float(index)
	else:
		region.size.y = full.size.y / float(count)
		region.position.y = full.position.y + region.size.y * float(index)

	var piece := Sprite2D.new()
	piece.texture = source.texture
	piece.centered = source.centered
	piece.flip_h = source.flip_h
	piece.flip_v = source.flip_v
	piece.region_enabled = true
	piece.region_rect = region

	# Measured against what the sprite was drawing, not against what was cut: the
	# offset already refers to the corner of the drawn rect, so that is the point
	# every slice has to be placed relative to.
	var shift := region.position - drawn.position
	# A sprite drawn from its corner only has to be pushed in by the cut. One drawn
	# from its middle has to have the two middles lined up as well, since the slice
	# is smaller than the picture it came out of.
	if source.centered:
		shift += (region.size - drawn.size) * 0.5
	piece.offset = source.offset + shift
	return piece
