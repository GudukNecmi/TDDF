class_name ThrownWeapon
extends Projectile
## A knife or a bone in the air: an ordinary shot that breaks where it stops.
##
## [b]It extends [Projectile] on purpose.[/b] A thrown knife is not a special kind
## of effect, it is a shot - it flies straight along its own +X, it is swept rather
## than merely overlapped so it cannot pass through a body at speed, it hands its
## damage to whatever [Hitbox] it lands on and that hitbox applies its own
## multiplier, so a thrown knife can land a headshot exactly as a bullet can. How
## hard it hits, how fast it travels and how far it reaches all come from its own
## [ProjectileProfile], which is the one place in the game any of those three
## numbers live. Nothing about damage is worked out in this file.
##
## What is added is the ending. A round is spent and disappears; a knife is spent
## and [i]breaks[/i] - see [BreakProfile], which cuts its own picture into pieces and
## hands them to the same [DeathDebris] every other bit of wreckage in the game uses.
##
## [b]Both ways a flight can end come through one test.[/b] Landing on somebody and
## running out of range are different paths inside [Projectile] and neither is a
## signal, but both finish by queueing the round for deletion - so asking after the
## fact whether that has happened catches the pair of them, and there is no ending
## that can quietly leave an unbroken knife lying in the air.

## Emitted as it comes apart, carrying the pieces. Fires for both endings a
## throw can have - landing on somebody or running out of range - so anything
## that only cares that it broke, whichever way, can hang off this alone.
signal broke(pieces: Array)
## The narrower half of [signal broke]: fires only when this throw comes apart
## on its own, having reached the end of its range without ever landing on
## anybody - never when it broke because it hit something. [ThrowableAudio] is
## what this exists for: a throw that lands already has [signal Projectile.landed]
## to hang a break sound off, and playing one again here as well would double
## it up - see the class doc's own note on why the two endings are told apart.
signal broke_without_hit(pieces: Array)

## How it breaks. Left unset it simply disappears, which is what any ordinary round
## does.
@export var break_profile: BreakProfile
## The picture, which is what gets cut up. It is named [code]Sprite2D[/code] because
## that is the child [Projectile] already tints across the flight - so a profile
## with white ends leaves the artwork exactly as drawn.
@export var art_path: NodePath = ^"Sprite2D"
## How fast the picture turns over in flight, in degrees per second.
##
## 0 flies it dead straight, which is right for a knife: it leaves point first and
## it should arrive point first. A bone has no point and reads better tumbling.
@export var tumble_degrees: float = 0.0

@onready var _art: Sprite2D = get_node_or_null(art_path) as Sprite2D

var _broken: bool = false


## Dresses this in the artwork it was thrown with, so the knife in the air is the
## knife that was in the hand. Called by [ThrowableWeapon] as it lets go.
func adopt_texture(texture: Texture2D) -> void:
	if _art == null:
		_art = get_node_or_null(art_path) as Sprite2D
	if _art != null and texture != null:
		_art.texture = texture


func _physics_process(delta: float) -> void:
	# The whole of the flight, the sweep, the damage and the retiring are the
	# projectile's, unchanged.
	super._physics_process(delta)

	if _art != null and is_instance_valid(_art) and not is_zero_approx(tumble_degrees):
		_art.rotation += deg_to_rad(tumble_degrees) * delta

	# Asked after the step rather than hooked into either ending: landing on a body
	# and reaching the end of the range both queue this for deletion, so one test
	# covers both and neither has to announce itself.
	if not _broken and is_queued_for_deletion():
		_break_apart()


## Cuts it up where it stopped. The pieces are parented to the running scene rather
## than to this, because this is about to be freed and they are meant to outlive it.
func _break_apart() -> void:
	_broken = true
	if break_profile == null or _art == null or not is_instance_valid(_art):
		return

	var container := get_tree().current_scene if is_inside_tree() else null
	if container == null:
		return

	# Thrown out along the way it was travelling, so the pieces visibly break away
	# from the flight rather than dropping straight down out of it.
	var pieces := break_profile.shatter(_art, container, transform.x)
	broke.emit(pieces)
	# [member Projectile._spent] is only ever set by a landing - see
	# [method Projectile._land] and [method Projectile._retire] - never by
	# reaching the end of the range, which frees this outright without touching
	# it. So a throw that is not spent when it comes apart is one that broke on
	# its own, and this is the one moment worth a break sound of its own.
	if not _spent:
		broke_without_hit.emit(pieces)
