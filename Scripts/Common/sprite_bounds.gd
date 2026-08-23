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
