class_name MiniBossWardrobe
extends Resource
## Every part a mini boss can be built out of, and the rule that decides which of
## them a particular outlaw wears.
##
## [b]It is a wardrobe, not a character.[/b] A mini boss is still the game's
## ordinary [code]Enemy.tscn[/code] with ordinary AI - see [MiniBoss] - and this
## changes nothing about how one moves, aims, swings, bleeds or goes down. All it
## carries is artwork and where on the enemy's existing rig each piece is drawn,
## which is why a boss dressed out of it idles, walks and attacks exactly like an
## Enemy1: it [i]is[/i] one, wearing different clothes.
##
## [b]The combination is derived rather than rolled.[/b] Nothing here remembers
## anything and nothing is written back into a save. [method indices_for] seeds a
## generator with the outlaw's own identity and draws the three parts from it, so
## asking twice always gives the same answer and asking a year later still does -
## which is exactly the property the brief asks for, "every time Bounty A's boss
## appears it must use exactly that combination", without a rolled result having to
## be stored anywhere or kept in step with the ledger. It also means the wanted
## poster can be handed the same key later and print the same man with nothing
## wired between the two.
##
## The parts are inspector arrays, so a twenty-first head is dropping a PNG into
## [member head_textures] - there is no index, threshold or name anywhere in this
## file that a new part would have to be added to. Adding one does re-deal the
## whole cast, because the draw is over however many entries there are; that is
## what [member variation_salt] is for when the cast is what wants changing and
## the parts do not.
##
## Only [member Sprite2D.texture], [member Sprite2D.offset] and
## [member Sprite2D.scale] are ever written from here, by [MiniBossAppearance] -
## plus the two numbers that tell the knife rig which way this art's blade points.
## Nothing touches a hitbox, a pivot's position or the enemy's collision shape, so
## the parts stay interchangeable and a boss is never a different shape to fight
## than the man the player is looking at.

## Heads one is drawn per outlaw.
@export var head_textures: Array[Texture2D] = []
## Bodies one is drawn per outlaw.
@export var body_textures: Array[Texture2D] = []
## Weapons one is drawn per outlaw.
@export var weapon_textures: Array[Texture2D] = []

@export_group("Legs")
## The boots every boss in this set wears. Deliberately not part of the draw - the
## legs are the one pair of parts an enemy does not vary, the same way
## [Enemy1Appearance] leaves them out - but they are still replaced, so a boss is
## not a MiniBoss1 body standing on Enemy1 legs.
##
## Left empty the enemy keeps the legs its scene shipped with.
@export var left_leg_texture: Texture2D
@export var right_leg_texture: Texture2D

@export_group("Selection")
## Turned to re-deal every outlaw in the game without touching the parts.
##
## The draw is a function of the outlaw's identity and this number and nothing
## else, so changing it changes every boss's combination at once and changing it
## back brings all of them back. It is the dial for "I do not like what this
## roster came out as"; it is not a difficulty or a rarity, and nothing reads it
## but the draw.
@export var variation_salt: int = 0

@export_group("Head placement")
## Added to the head sprite's authored [member Sprite2D.offset], in source texture
## pixels.
##
## [b]Zero is correct while this set is drawn on the Enemy1 rig[/b], which it is:
## the MiniBoss1 heads and bodies sit on the same thousand-pixel canvas, in the
## same place on it, as the faces and bodies the enemy scene was built around - so
## swapping the texture cannot move anything and the head cannot come off the neck.
## The shift exists for a future set that is not drawn that way, so re-anchoring it
## is an inspector value rather than a second appearance component.
@export var head_offset_shift := Vector2.ZERO
## What the head sprite's authored scale is multiplied by. 1 leaves it exactly as
## the scene draws it.
@export var head_scale_multiplier: float = 1.0

@export_group("Body placement")
@export var body_offset_shift := Vector2.ZERO
@export var body_scale_multiplier: float = 1.0

@export_group("Weapon placement")
## Added to the weapon sprite's authored offset, in source texture pixels.
##
## [b]This one is not zero and cannot be.[/b] The Enemy1 knife is a small blade
## drawn lying on its side; the MiniBoss1 weapons are long ones drawn standing
## upright on a narrower canvas, so the pixel the sprite turns about - its origin,
## which is where the hand is - is somewhere else entirely on the art. The shift is
## what puts it back on the grip, about a third of the way up the blade, which is
## where the enemy's own knife is held.
@export var weapon_offset_shift := Vector2.ZERO
## What the weapon sprite's authored scale is multiplied by.
##
## Below 1 for a set drawn larger than the enemy's own knife, which MiniBoss1 is -
## its blades are a little over twice the length of an Enemy1 knife on the same
## canvas, and a boss is already scaled up by its rung on top of that.
@export var weapon_scale_multiplier: float = 1.0
## Which way this set's blades point in their own art, in degrees, at zero
## rotation.
##
## It is written to both halves of the knife rig the enemy already has -
## [member LookAtTarget.rest_angle_degrees] on the pivot, so the weapon is aimed at
## the player, and [member KnifeSlash.blade_angle_degrees], so a swing lands the
## blade on them - which is the whole of how differently-oriented weapon art is
## supported. [b]The sprite's own rotation is deliberately not used for this[/b]:
## [KnifeSlash] writes that every physics frame for the idle sway and the swing
## arc, so a static angle parked there would be wiped on the first frame.
##
## The default is the angle the Enemy1 knife is drawn at, so a wardrobe that has
## not been told otherwise writes the enemy scene's own number back and changes
## nothing.
@export var weapon_art_angle_degrees: float = -158.4


## Whether this wardrobe can dress anybody at all. A set with no heads, bodies or
## weapons authored is not an error - the boss simply keeps the artwork its scene
## shipped with, which is a visible "nothing was configured" rather than an
## invisible one.
func is_empty() -> bool:
	return head_textures.is_empty() and body_textures.is_empty() \
		and weapon_textures.is_empty()


## The head, body and weapon [param key] wears, as indices into the three arrays.
## A component with nothing in it comes back as -1, which every reader takes as
## "leave that part alone".
##
## [b]The same key always gives the same answer.[/b] The generator is seeded from
## the key and thrown away, so this is a pure function of the identity, the arrays'
## sizes and [member variation_salt] - there is no shared state, no order
## dependence and nothing to reset between runs. The three draws happen in a fixed
## order for the same reason: heads and bodies and weapons have to keep their
## meaning when a part is added to only one of them.
func indices_for(key: StringName) -> Vector3i:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(key)
	return Vector3i(
		_draw(rng, head_textures.size()),
		_draw(rng, body_textures.size()),
		_draw(rng, weapon_textures.size()),
	)


## The head, body and weapon [param key] wears, in that order, as three entries -
## any of which is null when that set is empty.
##
## The one call [MiniBossAppearance] dresses out of, so a boss is drawn from a
## single draw rather than from three that each have to agree.
func parts_for(key: StringName) -> Array[Texture2D]:
	var parts := indices_for(key)
	var worn: Array[Texture2D] = []
	worn.append(_at(head_textures, parts.x))
	worn.append(_at(body_textures, parts.y))
	worn.append(_at(weapon_textures, parts.z))
	return worn


## The head [param key] wears, or null when there are none to draw from.
func head_for(key: StringName) -> Texture2D:
	return _at(head_textures, indices_for(key).x)


## The body [param key] wears.
func body_for(key: StringName) -> Texture2D:
	return _at(body_textures, indices_for(key).y)


## The weapon [param key] carries.
func weapon_for(key: StringName) -> Texture2D:
	return _at(weapon_textures, indices_for(key).z)


## The seed [param key] draws with. Public so a test can prove two callers agree
## without reaching into the draw itself.
func seed_for(key: StringName) -> int:
	return hash(String(key)) + variation_salt


## One draw, or -1 from an empty set. Every part is drawn whatever the sizes are,
## so a set with no weapons in it still leaves the head and body deciding the same
## way they would have.
func _draw(rng: RandomNumberGenerator, count: int) -> int:
	var index := rng.randi_range(0, maxi(count, 1) - 1)
	return -1 if count <= 0 else index


func _at(textures: Array[Texture2D], index: int) -> Texture2D:
	if index < 0 or index >= textures.size():
		return null
	return textures[index]


func _to_string() -> String:
	return "<MiniBossWardrobe %d heads  %d bodies  %d weapons  salt %d>" % [
		head_textures.size(), body_textures.size(), weapon_textures.size(), variation_salt,
	]
