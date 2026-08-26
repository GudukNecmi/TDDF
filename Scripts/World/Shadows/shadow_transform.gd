class_name ShadowTransform
extends RefCounted
## Where one part of a shadow goes and what it looks like, this frame. The answer
## [ShadowCaster] records after its group has placed it.
##
## It is a plain bag of numbers on purpose. The projection maths is a pure function
## of the object's ground position and the sun - see [ShadowGroup] - and this is
## where one part of it landed, so a result can be tested, printed, or later fed to
## a shader or a mesh instead of a [Sprite2D] without any of the projection being
## rewritten.
##
## Everything here is already in world space and already has the part's own
## multipliers folded in. A renderer - see [ShadowGroup] - only has to write it onto
## a node.

## Where the caster is standing on the arena floor. Passed straight through, so
## anything reading the result can tell where the shadow's owner actually is rather
## than only where its shadow ended up.
var ground_position := Vector2.ZERO
## How far the caster's visual was above that ground position when this was worked
## out, in world pixels. Also passed through - see
## [method ShadowCaster.get_visual_height].
var visual_height: float = 0.0

## Where the shadow's own origin goes, in world space. Already includes the walk
## away from the feet that height causes.
var position := Vector2.ZERO
## Offset of [member position] from [member ground_position]. The airborne walk, on
## its own, for anything that wants it without the absolute answer.
var offset := Vector2.ZERO
## Unit vector the shadow lies along, away from the sun. [b]A function of the sun
## and the ground position, and of nothing else[/b] - see
## [method SunState.shadow_direction_at].
var direction := Vector2.DOWN
## How long the shadow is, in world pixels.
var length: float = 0.0
## The silhouette's own rotation, in radians - the source's own, mirroring
## included. [b]It is not where the shadow points.[/b]
## Which way a shadow lies is [member direction] and nothing else; this only turns
## the shape being cast, the way a spinning revolver's silhouette turns while its
## shadow still rakes away from the same sun.
var rotation: float = 0.0
## The silhouette's own scale, as a multiple of the source artwork's drawn size.
## Negative x is a mirrored silhouette - which mirrors the shape and, again, moves
## nothing about where the shadow is projected.
var scale := Vector2.ONE
## The 2x2 the shadow is actually drawn with: the silhouette's pose above, laid down
## onto the ground along [member direction]. Its origin is unused -
## [member position] is where it goes.
##
## This is the composition the whole fix rests on. The pose can be anything the
## source is doing; the projection that follows it is the sun's and only the sun's,
## so no rotation, mirror or scale of the source can redirect a shadow.
var basis := Transform2D.IDENTITY
## Colour and alpha this part would be on its own - the map's shadow colour, with
## every multiplier folded in. A readout; a group in union mode draws
## [member local_opacity] instead and fades the finished silhouette once.
var modulate := Color(0, 0, 0, 0)
## The part of that alpha which belongs to this piece alone - its own multiplier,
## its share of the source's fade and the height falloff - without the hour's
## opacity.
##
## [b]This is what a combined shadow is drawn with.[/b] Every part of one object
## goes down opaque and the hour's opacity is applied once to the composite, which
## is exactly what stops a head and a body from darkening each other where they
## overlap.
var local_opacity: float = 0.0
## The hour's own opacity, on its own - what a group applies to the composite.
var day_opacity: float = 0.0
## Edge softness for the shared shadow material, 0 to 1.
var softness: float = 0.0
## How much the far tip fades out, 0 to 1.
var fade: float = 0.0
## Whether this part should be drawn at all. False when it has been faded to nothing
## or scaled to nothing, so a renderer can hide rather than draw a no-op - which is
## the whole of what "night is five percent visible" costs.
var visible: bool = false


## Writes this result onto a [Sprite2D], for anything driving one directly rather
## than through a [ShadowGroup].
##
## The sprite is expected to sit in world space, so the caster's parent cannot
## rotate or scale the answer a second time.
func apply_to_sprite(sprite: Sprite2D) -> void:
	if sprite == null:
		return
	sprite.visible = visible
	if not visible:
		return
	# Written as one basis rather than as position, rotation and scale in turn. The
	# projection is a shear - the artwork's up axis lies along the light while its
	# across axis stays across - and a shear is not a rotation and a scale, so there
	# is nothing here to decompose it into.
	sprite.global_transform = Transform2D(basis.x, basis.y, position)
	sprite.self_modulate = modulate


func _to_string() -> String:
	return "<ShadowTransform ground %s  height %.1f  len %.1f  a %.2f>" % [
		ground_position, visual_height, length, modulate.a]
