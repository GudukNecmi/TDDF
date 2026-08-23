class_name MiniBossAppearance
extends Node
## Dresses one mini boss out of a [MiniBossWardrobe]: the head, the body, the
## weapon and the boots that belong to the outlaw on the poster.
##
## [b]It replaces artwork and nothing else.[/b] The boss keeps every component the
## ordinary enemy has - its chase, its head and knife pivots, its idle squash, its
## leg animator, its hit flash, its footprints, its hitboxes - so it idles, walks,
## aims, swings, flashes, bleeds and goes down through exactly the same code an
## Enemy1 does. There is no second movement system and no second animation system
## anywhere in this, which is the whole point: a mini boss is an Enemy1 in different
## clothes.
##
## [b]The same outlaw is always the same man.[/b] Which parts are worn is not rolled
## here - it is derived from [member look_key], the identity of the bounty's target,
## by [method MiniBossWardrobe.indices_for]. So the combination is fixed the moment
## the contract exists rather than the moment a body is built, cannot drift between
## one encounter and the next, and survives the world being torn down and rebuilt
## without anything having to be saved. Meeting the same outlaw twice before the
## contract is closed shows the same head, body and weapon both times.
##
## [b]And it goes down as one man.[/b] Because it only writes textures, offsets and
## scales onto the sprites already in the scene, everything that moves those sprites
## afterwards keeps working untouched - the head is carried through
## [method EnemySurrender._fall] on the same shared pivot as the body, so a beaten
## boss falls with his head on his neck, and the parts cannot separate during idle,
## movement, an attack, a hit, the fall or the corpse lying there afterwards. The
## only thing that ever leaves the man is the weapon he throws down as he gives up,
## which is the same weapon he was carrying and is meant to leave.
##
## It is added to the boss by [method MiniBossDirector._build_boss], the same way
## [MiniBoss] is, so an enemy without one is simply an enemy.

## The parts to dress out of. Left unset the boss keeps the artwork the enemy scene
## shipped with, which is a visible "no wardrobe was configured".
@export var wardrobe: MiniBossWardrobe
## Whose look this is. The bounty target's [member BountyTarget.target_id] where
## there is one, so two contracts on the same outlaw show the same man, falling back
## to the contract's own id - see [method MiniBossDirector.look_key_for], which is the
## same key [MiniBossPortrait] prints the wanted poster from.
##
## An empty key still dresses the boss, and still does it the same way every time;
## it simply means every nameless boss is the same nameless boss.
@export var look_key: StringName = &""

@export_group("Targets")
## The sprites each kind of part is drawn on. They are the enemy scene's own nodes,
## named the same way [Enemy1Appearance] names them.
@export var head_path: NodePath = ^"../HeadAim/Head"
@export var body_path: NodePath = ^"../Visual/Body"
@export var weapon_path: NodePath = ^"../KnifeAim/KnifeHand/Knife"
@export var left_leg_path: NodePath = ^"../Visual/Legs/LeftLeg"
@export var right_leg_path: NodePath = ^"../Visual/Legs/RightLeg"

@export_group("Head rig")
## The pivot that aims the head. It mirrors the head sprite to face the player, and
## measured how wide that sprite was when the enemy was built - so it is told again
## after a head of a different size has been put on. See
## [method LookAtTarget.refresh_flip_base].
@export var head_pivot_path: NodePath = ^"../HeadAim"

@export_group("Weapon rig")
## The pivot that aims the weapon, told which way this set's blades point so it
## still aims them at the player. See
## [member MiniBossWardrobe.weapon_art_angle_degrees].
@export var weapon_pivot_path: NodePath = ^"../KnifeAim"
## The swing, told the same thing so a hit lands the blade rather than the handle.
@export var weapon_slash_path: NodePath = ^"../KnifeAim/KnifeSlash"

## Where each sprite was authored, captured before anything is written to it - so
## re-applying with retuned numbers measures the shift from the scene rather than
## from whatever this wrote last time.
var _rest_offsets: Dictionary = {}
var _rest_scales: Dictionary = {}


func _ready() -> void:
	apply()


## The appearance component on [param enemy], or null when it has none. For a
## readout or a test holding a body and asking what it is wearing.
static func find_on(enemy: Node) -> MiniBossAppearance:
	if enemy == null:
		return null
	for node: Node in enemy.find_children("*", "MiniBossAppearance", true, false):
		var found := node as MiniBossAppearance
		if found != null:
			return found
	return null


## Which head, body and weapon this boss is wearing, as indices into the
## wardrobe's arrays. All -1 without a wardrobe.
func get_indices() -> Vector3i:
	if wardrobe == null:
		return Vector3i(-1, -1, -1)
	return wardrobe.indices_for(look_key)


## Puts the parts on. Returns whether there was a wardrobe to dress out of.
##
## Public and re-callable on purpose, for the same reason
## [method MiniBoss.apply_outline] is: every number it reads is an inspector value,
## so retuning one and calling this again takes effect without the boss being
## rebuilt.
func apply() -> bool:
	if wardrobe == null:
		return false

	var worn := wardrobe.parts_for(look_key)
	_dress(head_path, worn[0],
		wardrobe.head_offset_shift, wardrobe.head_scale_multiplier)
	_dress(body_path, worn[1],
		wardrobe.body_offset_shift, wardrobe.body_scale_multiplier)
	_dress(weapon_path, worn[2],
		wardrobe.weapon_offset_shift, wardrobe.weapon_scale_multiplier)
	_dress(left_leg_path, wardrobe.left_leg_texture, Vector2.ZERO, 1.0)
	_dress(right_leg_path, wardrobe.right_leg_texture, Vector2.ZERO, 1.0)
	_remeasure_the_head_rig()
	_aim_the_weapon_rig()
	return true


## One sprite: the part, and where on the rig it is drawn.
##
## A null texture leaves the sprite's own artwork alone rather than blanking it, so
## a wardrobe with one of its three sets empty dresses the parts it has and leaves
## the rest as the scene drew them. The placement is still applied either way -
## whoever shifted a slot meant that slot, whichever texture ends up in it.
func _dress(path: NodePath, texture: Texture2D, shift: Vector2, magnify: float) -> void:
	var sprite := get_node_or_null(path) as Sprite2D
	if sprite == null:
		return

	_remember(sprite)
	if texture != null:
		sprite.texture = texture

	var id := sprite.get_instance_id()
	var rest_offset: Vector2 = _rest_offsets[id]
	var rest_scale: Vector2 = _rest_scales[id]
	sprite.offset = rest_offset + shift
	sprite.scale = rest_scale * maxf(magnify, 0.0001)


func _remember(sprite: Sprite2D) -> void:
	var id := sprite.get_instance_id()
	if _rest_offsets.has(id):
		return
	_rest_offsets[id] = sprite.offset
	_rest_scales[id] = sprite.scale


## Tells the head's pivot how wide the head it is now mirroring actually is.
##
## Without this the pivot would keep writing back the width it measured when the
## enemy was built, so a head scaled by [member MiniBossWardrobe.head_scale_multiplier]
## would end up stretched - taller but not wider - the instant the boss looked at
## anybody. A wardrobe leaving the head at the size the scene draws it is unaffected
## either way.
func _remeasure_the_head_rig() -> void:
	var pivot := get_node_or_null(head_pivot_path) as LookAtTarget
	if pivot != null:
		pivot.refresh_flip_base()


## Tells the knife rig which way this set's blades are drawn.
##
## Both halves are written because both of them ask the question: the pivot turns
## the weapon so its art points at the player, and the swing works out the rotation
## that would put the blade on them. Leaving either one on the Enemy1 number would
## have the boss aiming a blade that is drawn ninety degrees away from where the rig
## thinks it is - the handle pointing at the player, and a swing that misses with a
## weapon that visibly passed straight through them.
func _aim_the_weapon_rig() -> void:
	var pivot := get_node_or_null(weapon_pivot_path) as LookAtTarget
	if pivot != null:
		pivot.rest_angle_degrees = wardrobe.weapon_art_angle_degrees

	var slash := get_node_or_null(weapon_slash_path) as KnifeSlash
	if slash != null:
		slash.blade_angle_degrees = wardrobe.weapon_art_angle_degrees


func _to_string() -> String:
	var parts := get_indices()
	return "<MiniBossAppearance %s  head %d  body %d  weapon %d>" % [
		String(look_key), parts.x, parts.y, parts.z,
	]
