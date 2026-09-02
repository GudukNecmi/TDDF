class_name ThrowableWeapon
extends CarriedWeapon
## A knife or a bone picked up off the ground: carried like any other weapon,
## thrown once, and gone.
##
## Carrying, aiming, swaying and holstering are [CarriedWeapon]'s, shared with every
## other weapon in the game - so a knife is held at arm's length, orbits the
## character as the aim sweeps, rights itself past vertical through [HeldItemFlip]
## and goes away to the belt in the base, without a line of any of that existing
## twice. What is here is only the throw.
##
## [b]One throw and it is spent.[/b] There is no ammunition, no reload and no second
## use: the fire key sends it, and the same press hands the player's own weapon back
## through [method WeaponMount.drop_temporary]. Nothing has to remember that a knife
## was ever picked up, because nothing was ever put anywhere - the chosen weapon was
## stowed and is now drawn again.
##
## [b]It leaves along the aim the weapon is already holding.[/b] The throw is taken
## from [member Node2D.global_rotation] and the muzzle's own position on the frame
## the key is pressed, with nothing brought round first, so a knife thrown mid-turn
## goes where the weapon was actually pointing rather than where it was about to be.
##
## Knife and bone are the same weapon with different fields filled in. What differs
## between them - the picture, what is thrown, how hard, how it breaks - is
## inspector work on the two scenes and on the resources they name, and adding a
## third throwable is a scene rather than a script.

## Emitted as it leaves the hand, carrying the thing that was thrown.
signal thrown(projectile: Projectile)

## What is actually sent through the air. It reads its damage, its speed and its
## range from its own [ProjectileProfile], exactly as every other shot in the game
## does, so nothing about how hard a knife hits is decided here.
@export var projectile_scene: PackedScene
## Where it leaves the hand from - the blade's point, out at the end of the reach.
##
## It lives inside the weapon's mirrored rig rather than beside it, so it tracks the
## artwork as drawn - see [HeldItemFlip]. Left unresolved the throw starts at the
## weapon's own origin, which is the hand.
@export var muzzle_path: NodePath = ^"MuzzleRig/Muzzle"
## The picture, which the thrown object takes with it - so the knife in the air is
## the knife that was in the hand, whichever of the enemy's ten it happened to be.
@export var art_sprite_path: NodePath = ^"Art/Body"
## How long the weapon that was put away takes to come back, in seconds. The same
## short switch the pickup used, so putting one away and taking it out again are
## the same move played in both directions.
@export var return_time: float = 0.1

@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D
@onready var _art: Sprite2D = get_node_or_null(art_sprite_path) as Sprite2D

## True from the instant the throw goes. The weapon is freed a moment later, so this
## only has to survive the rest of the frame - but a second press inside that frame
## must not send a second knife.
var _spent: bool = false


## [b]It is put in the hand already pointing.[/b] Every other weapon in the game is
## carried into the fight and has all the time in the world to ease onto the cursor,
## but this one can be picked up and thrown inside two frames - and a weapon that
## starts at zero and eases would send that throw along an aim that had barely
## turned. Landing on the aim is the same move [CarriedWeapon] already makes coming
## out of its dead zone; this only asks for it once, on the way in.
func _ready() -> void:
	super._ready()
	_aim_held = true


## Dresses this in the artwork of whatever was picked up off the ground. Called by
## [GroundPickup] the instant the weapon is built, before the first frame is drawn.
func adopt_texture(texture: Texture2D) -> void:
	if _art == null:
		_art = get_node_or_null(art_sprite_path) as Sprite2D
	if _art != null and texture != null:
		_art.texture = texture


## Whether the throw has already gone.
func is_spent() -> bool:
	return _spent


## A throwable is ready for exactly as long as it has not already left the
## hand - see [member CarriedWeapon.is_ready_to_fire]. There is no reload to
## wait on: the instant it is spent the weapon it replaced is already on its
## way back out, so this only matters for the single frame between the two.
func is_ready_to_fire() -> bool:
	return not _spent


func _weapon_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		throw()


## Sends it. Public so a future input other than the fire key - a boss scripted to
## disarm the player, a throw bound elsewhere - can spend it without reaching in.
## Returns whether anything left the hand.
func throw() -> bool:
	if _spent or projectile_scene == null:
		return false

	var container := get_tree().current_scene
	if container == null:
		return false
	_spent = true

	var flight := projectile_scene.instantiate() as Projectile
	if flight != null:
		# Added to the running scene rather than to the weapon, so it keeps flying
		# straight while the hand that threw it carries on turning - and so it
		# outlives the weapon, which is about to be freed.
		container.add_child(flight)
		flight.global_position = _muzzle.global_position if _muzzle != null \
			else global_position
		flight.global_rotation = global_rotation
		if _art != null and _art.texture != null and flight.has_method(&"adopt_texture"):
			flight.call(&"adopt_texture", _art.texture)
		flight.reset_physics_interpolation()
		thrown.emit(flight)

	# The player's own weapon comes back the way it went away. A world with no mount
	# has nowhere to hand it back to, so the throwable simply removes itself.
	var mount := WeaponMount.get_active(self)
	if mount != null:
		mount.drop_temporary(return_time)
		return true

	queue_free()
	return true
