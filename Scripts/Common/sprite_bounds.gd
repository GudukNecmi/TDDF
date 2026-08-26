class_name SpriteBounds
extends RefCounted
## Where a sprite's *artwork* actually is, as opposed to where its texture is.
##
## Every character and prop in the game is drawn from a texture with a good deal
## of empty space around the drawing - the props are all 206x273 with the plant
## somewhere in the middle of it, the legs are a fraction of their own canvas. Any
## system that has to meet the artwork on the ground - a footprint under a foot, a
## cactus standing on its base, a shadow sized to what casts it - needs the opaque
## part and not the canvas, or it is measuring padding.
##
## [method used_rect] is the whole trick: [method Image.get_used_rect] does the
## scan in engine code, and the answer is cached per texture, so a hundred cacti
## sharing five textures pay for five scans between them and nothing after that.
##
## Nothing here reads a hardcoded number about any particular piece of art, which
## is the point - swapping the walk animation, or dropping a new cactus into an
## inspector array, moves the measurements with it.

## Opaque rect per texture, keyed by the texture's own instance id. Static, so it
## is shared by every caller in the game and survives individual props coming and
## going.
static var _used_rects: Dictionary = {}


## The opaque part of [param texture], in texture pixels. Falls back to the whole
## texture when it cannot be read - a texture with no image behind it, or one that
## is empty - so callers never have to handle a failure.
static func used_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	var key := texture.get_instance_id()
	if _used_rects.has(key):
		return _used_rects[key]

	var size := Vector2(texture.get_size())
	var rect := Rect2(Vector2.ZERO, size)

	var image := texture.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)

	_used_rects[key] = rect
	return rect


## The opaque part of [param sprite]'s artwork in the sprite's own local space -
## that is, with [member Sprite2D.offset] and [member Sprite2D.centered] taken
## into account but before the node's own scale and rotation.
static func local_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()

	var rect := used_rect(sprite.texture)
	var origin := sprite.offset
	if sprite.centered:
		origin -= Vector2(sprite.texture.get_size()) * 0.5
	return Rect2(origin + rect.position, rect.size)


## The four corners of that rect in world space, in the node's current pose. The
## caller gets corners rather than a bounding box because a rotated leg's lowest
## corner is its toe, and a box around it would be somewhere in the air beside it.
static func global_corners(sprite: Sprite2D) -> PackedVector2Array:
	var rect := local_rect(sprite)
	var transform := sprite.global_transform
	return PackedVector2Array([
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y),
	])


## How high and how low [param sprite]'s opaque artwork reaches in world space when
## it is standing in [param pose], as (highest y, lowest y).
##
## The same measurement [method global_corners] would give, taken without building
## an array and against a pose handed in rather than read off the node - which is
## what lets a caller that has already taken a part's transform for the frame ask
## again for nothing. Every shadow in the world asks this every time it moves, so it
## is deliberately allocation-free.
static func world_band(sprite: Sprite2D, pose: Transform2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	var rect := local_rect(sprite)
	var a := pose * rect.position
	var b := pose * Vector2(rect.end.x, rect.position.y)
	var c := pose * rect.end
	var d := pose * Vector2(rect.position.x, rect.end.y)
	return Vector2(
		minf(minf(a.y, b.y), minf(c.y, d.y)),
		maxf(maxf(a.y, b.y), maxf(c.y, d.y)))


## The lowest point of [param node]'s artwork in world space - the part of it
## currently touching the ground.
##
## This is what a footprint is stamped at. It is measured from the sprite's live
## global transform every time it is asked for, so a leg that is mid-stride, lifted,
## rotated, squashed by the idle breath or mirrored by a [FacingFlip] answers with
## wherever its toe genuinely is. Changing the walk animation changes this by
## itself; nothing here has to be told.
##
## Anything that is not a sprite with a texture - a bare pivot [Node2D] - falls
## back to its own origin, so a foot marker still works as a foot.
static func lowest_point(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO

	var sprite := node as Sprite2D
	if sprite == null or sprite.texture == null:
		return node.global_position

	var corners := global_corners(sprite)
	var lowest := corners[0]
	for i: int in range(1, corners.size()):
		if corners[i].y > lowest.y:
			lowest = corners[i]
	return lowest


## The middle of the bottom edge of the artwork, in the sprite's own local space.
## This is where a prop meets the ground, and so what a prop's node origin should
## sit on - see [PropArt], which uses it to place any artwork on its own base
## without a number per picture.
static func local_footing(sprite: Sprite2D) -> Vector2:
	var rect := local_rect(sprite)
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)


## The texture [param sprite] actually samples, with an [AtlasTexture] resolved to
## the sheet behind it.
##
## Anything drawing a sprite's artwork with its own geometry rather than with a
## [Sprite2D] - a shadow's projected mesh - needs the real texture and its own UVs,
## because an atlas region is applied by the sprite and not by the texture.
static func source_texture(sprite: Sprite2D) -> Texture2D:
	if sprite == null or sprite.texture == null:
		return null
	var atlas := sprite.texture as AtlasTexture
	if atlas != null and atlas.atlas != null:
		return atlas.atlas
	return sprite.texture


## The patch of [method source_texture] that [param sprite] is showing right now,
## in texture pixels: its atlas region or its own region, cut down to the frame it
## is on. Everything a sheet-animated or atlased sprite does to pick its picture,
## answered as one rectangle.
static func frame_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()

	var atlas := sprite.texture as AtlasTexture
	var rect: Rect2
	if sprite.region_enabled:
		rect = sprite.region_rect
		if atlas != null and atlas.atlas != null:
			rect.position += atlas.region.position
	elif atlas != null and atlas.atlas != null:
		rect = atlas.region
	else:
		rect = Rect2(Vector2.ZERO, Vector2(sprite.texture.get_size()))

	var columns := maxi(sprite.hframes, 1)
	var rows := maxi(sprite.vframes, 1)
	if columns > 1 or rows > 1:
		var cell := Vector2(rect.size.x / float(columns), rect.size.y / float(rows))
		var frame := clampi(sprite.frame, 0, columns * rows - 1)
		var column := frame % columns
		# Exact: the remainder has already been taken off, so there is nothing to lose.
		@warning_ignore("integer_division")
		var row := (frame - column) / columns
		rect = Rect2(
			rect.position + Vector2(float(column) * cell.x, float(row) * cell.y), cell)
	return rect


## Where that frame is drawn in the sprite's own local space, with
## [member Sprite2D.offset] and [member Sprite2D.centered] taken into account. The
## quad a [Sprite2D] would put the picture on, for anything that has to put it
## somewhere else.
static func frame_draw_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var size := frame_rect(sprite).size
	var origin := sprite.offset
	if sprite.centered:
		origin -= size * 0.5
	return Rect2(origin, size)
