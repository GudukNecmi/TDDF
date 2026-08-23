class_name Revolver
extends CarriedWeapon
## The revolver: six chambers, one round each, and a cylinder that turns under
## every shot.
##
## Carrying, aiming, swaying and holstering are [CarriedWeapon]'s, shared with
## every other weapon. What is here is the cylinder, the reloading, and the coin.
##
## [b]The chambers are the ammunition.[/b] Where the shotgun and the rifle carry a
## count, this carries a *ring*: six slots, each either loaded or empty, and one
## of them - always the same one, the top of the cylinder - is the chamber under
## the hammer. Firing empties that chamber and turns the cylinder one sixth of a
## turn, so the next slot comes up whether it has a round in it or not. That is
## why the weapon can be half loaded in a pattern rather than merely low: the
## count and the arrangement are different facts, and the player can see both.
##
## The count is still the ordinary [WeaponAmmo] reserve, kept exactly in step -
## one loaded chamber is one round - so the HUD readout, the camp and any future
## shop see a revolver the same way they see every other weapon.
##
## [b]Reloading is the player's job, never the weapon's.[/b] The revolver never
## feeds itself: a round only ever goes in because the player pressed
## [member reload_action], one round per press, and the weapon is dry for exactly
## as long as they leave it dry. Six presses is a full cylinder from empty, and what
## paces it is the player's hand: the weapon itself imposes nothing between a round
## going in and the next shot, so a round chambered mid-twirl can be fired the
## instant it lands. See [member reload_lock_time].
##
## The coin is the other half of the weapon and lives in [Coin]: this only decides
## when one is thrown and in which direction.

## Emitted when a shot leaves the barrel.
signal fired
## Emitted with the round itself, the instant it is in the world.
##
## [b]This is how a shot is made to be more than an ordinary shot without the
## weapon knowing what "more" is.[/b] The revolver spawns its round and announces
## it; whatever wants to empower that round - see [RevolverSpin] - does so here.
## Nothing about a charge, a critical or a multiplier is written down in this
## script.
signal bullet_spawned(bullet: Projectile)
## Emitted when the trigger is pulled and nothing happens - an empty chamber, or
## the moment after a reload.
signal dry_fired
## Emitted as the cylinder turns, carrying which chamber is now under the hammer.
signal cylinder_turned(top_chamber: int)
## Emitted whenever a chamber is loaded or emptied, so a display can rebuild.
## Carries the whole ring, loaded first at the top.
signal chambers_changed(chambers: Array[bool])
## Emitted as a round is fed into a chamber, however it was fed.
signal chamber_loaded(chamber: int)
## Emitted when a coin is thrown.
signal coin_thrown(coin: Coin)

@export_group("Look")
## Sprite whose texture is swapped as the hammer falls.
@export var body_sprite_path: NodePath = ^"Art/Body"
## The revolver as it is carried.
@export var default_texture: Texture2D
## Shown for a heartbeat as the shot leaves - the hammer back. A look, not a
## state: the weapon is ready to fire again the instant the shot has gone.
@export var hammer_texture: Texture2D
## How long that picture is held, in seconds.
@export var hammer_time: float = 0.07
## Where the artwork sits relative to the weapon's own origin, in weapon units.
##
## The four fields below are how the revolver is *held*, and they exist because
## the artwork is drawn on a square canvas pointing the wrong way rather than
## lying along the barrel like the long guns. They move the picture only - the
## muzzle, the aim and every mechanic are untouched by them, so the weapon can be
## repositioned in the hand without anything about how it shoots changing. Every
## one of them re-applies as it is set, so the revolver can be dragged into place
## in the inspector while the game is running.
##
## Where the weapon is held relative to the *player* is not here: that is
## [member CarriedWeapon.hand_offset], which is shared by every weapon.
@export var art_offset := Vector2(30.0, -10.0):
	set(value):
		art_offset = value
		_apply_art_transform()
## How far the artwork is turned, in degrees, to put the barrel along +X - which
## is the direction every held weapon aims down.
##
## The revolver is drawn barrel-left, so a half turn is what lines it up. That
## half turn also lands it upside down, which is what
## [member art_flip_x] is for - the two belong together and neither is correct
## alone.
@export var art_rotation_degrees: float = 180.0:
	set(value):
		art_rotation_degrees = value
		_apply_art_transform()
## Whether the artwork is turned a half turn about its own X axis - which, on a
## flat sprite, mirrors it top to bottom.
##
## [b]The axis matters.[/b] Turning the picture further around Z only points the
## barrel somewhere else; what is wrong once the barrel is along +X is that the
## grip is above the frame rather than below it, and that is an X-axis flip. With
## [member art_rotation_degrees] at 180 this is what puts the gun the right way up
## in the hand.
@export var art_flip_x: bool = true:
	set(value):
		art_flip_x = value
		_apply_art_transform()
## Size the artwork is drawn at, as a fraction of its texture.
@export var art_scale: float = 0.32:
	set(value):
		art_scale = value
		_apply_art_transform()

@export_group("Cylinder")
## How many chambers the cylinder holds. The ammunition's own capacity should
## match it; this is what decides how far the cylinder turns per shot.
@export var chamber_count: int = 6
## How long the cylinder takes to turn one chamber, in seconds. It is the display
## that turns - see [RevolverChambers] - and this is the number it is told.
@export var cylinder_turn_time: float = 0.12

@export_group("Shot")
## Marker the round leaves from.
@export var muzzle_path: NodePath = ^"MuzzleRig/Muzzle"
## Bullet scene spawned on each shot.
@export var projectile_scene: PackedScene
## Cone the shot is spread across, in degrees. 0 is dead straight.
@export var spread_angle_degrees: float = 0.0

@export_group("Reloading")
## Action that feeds a round. The only thing that ever loads this weapon.
@export var reload_action: StringName = &"pump"
## How long the weapon cannot fire for after a round goes in, in seconds.
##
## [b]0, deliberately: the revolver has no such pause.[/b] A gunslinger feeding a
## chamber mid-fan does not then wait to be allowed to shoot, and a lock here was
## being felt as the weapon refusing input the player had already given - worst of
## all mid-twirl, where the reload is meant to disappear into a gesture that is
## already running. The mechanism is kept rather than cut out so a weapon that wants
## a deliberate, heavy reload can have one by setting a number.
@export var reload_lock_time: float = 0.0

@export_group("Coin")
## Action that throws the coin.
@export var coin_action: StringName = &"coin_throw"
## The coin itself.
@export var coin_scene: PackedScene
## How far from the player the coin starts, in pixels.
@export var coin_spawn_offset: float = 18.0
## Whether the coin's direction is chosen at random rather than aimed. On, as the
## weapon intends: the throw is a wager, and where it goes is not the player's
## choice - hitting it is.
@export var coin_random_direction: bool = true

@onready var _body: Sprite2D = get_node_or_null(body_sprite_path) as Sprite2D
@onready var _muzzle: Marker2D = get_node_or_null(muzzle_path) as Marker2D

## One entry per chamber, true when it holds a round. Index 0 is the chamber under
## the hammer; the ring is rotated rather than an index being tracked, so "the top
## chamber" is always the same entry and nothing has to work out which slot is
## live.
var _chambers: Array[bool] = []
## How far the cylinder has turned in whole chambers, only so a display can follow
## it. The gameplay does not read it.
var _turned: int = 0
var _hammer_flash: bool = false
## Time left before the weapon may fire again after a round went in.
var _lock_left: float = 0.0


func _ready() -> void:
	_chambers.resize(maxi(chamber_count, 1))
	_apply_look()
	_apply_art_transform()
	super._ready()
	# Filled from the reserve rather than assumed full: the count survives a run,
	# so a revolver picked back up half empty comes back half empty, and the ring
	# is arranged to match it.
	_fill_from_reserve()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_advance_lock(delta)


func _weapon_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_try_fire()
	elif event.is_action_pressed(reload_action):
		_try_manual_reload()
	elif event.is_action_pressed(coin_action):
		_try_throw_coin()


## The ring as it stands, loaded first at the top. For a display, and for a test.
func get_chambers() -> Array[bool]:
	return _chambers.duplicate()


## Whether the chamber under the hammer has a round in it.
func is_top_loaded() -> bool:
	return not _chambers.is_empty() and _chambers[0]


## How many chambers have turned since the weapon was drawn. What a display turns
## by, so it and the weapon can never disagree about where the cylinder is.
func get_turn_count() -> int:
	return _turned


func is_locked() -> bool:
	return _lock_left > 0.0


## One trigger pull, one round out of the top chamber.
##
## Three things can refuse it, and they are deliberately the same refusal to the
## player: an empty chamber, the lock after a reload, and a magazine the reserve
## says is empty. All of them click.
func _try_fire() -> void:
	if is_locked() or not is_top_loaded() or not spend_ammo():
		dry_fired.emit()
		return

	_chambers[0] = false
	_spawn_bullet()
	_show_hammer()
	fired.emit()
	chambers_changed.emit(get_chambers())
	_turn_cylinder()


## Turns the cylinder one chamber, bringing the next slot under the hammer -
## loaded or not. Rotating the ring rather than moving a pointer is what keeps
## "the top chamber" a single fixed place in the array.
func _turn_cylinder() -> void:
	if _chambers.is_empty():
		return
	var front: bool = _chambers.pop_front()
	_chambers.push_back(front)
	_turned += 1
	cylinder_turned.emit(_turned)
	chambers_changed.emit(get_chambers())


## Feeds one round into [param chamber]. Returns whether it went in - a chamber
## that already holds one is left alone, which is what stops a reload from
## overfilling the weapon.
func _load_chamber(chamber: int) -> bool:
	if chamber < 0 or chamber >= _chambers.size() or _chambers[chamber]:
		return false

	# The cylinder is drawn from the pouch, not added to it. A chamber may only be
	# filled while the player is carrying a round that is not already sitting in
	# another chamber - which is what makes thirty rounds a supply that runs out
	# rather than six that reload themselves forever.
	#
	# Nothing is taken here: a round is charged as it is fired. Loading is therefore
	# free and the ring is a claim on ammunition the player already has, so the two
	# can never disagree about how many that is.
	if not _has_round_to_chamber():
		return false

	_chambers[chamber] = true
	_lock_left = maxf(reload_lock_time, 0.0)
	chamber_loaded.emit(chamber)
	chambers_changed.emit(get_chambers())
	return true


## Feeds the chamber that most needs it: the one under the hammer if it is empty,
## and otherwise the next empty one round the cylinder.
##
## [b]The order is the whole of the reloading rule.[/b] The top chamber is
## always filled first because it is the one that decides whether the weapon can
## fire at all - a revolver with five rounds behind the hammer is an empty
## revolver to the player holding it. Only once it is fed does the rest of the
## cylinder get anything, and then in ring order rather than at random, so a
## reload works its way round exactly as a hand would.
func _load_next_chamber() -> bool:
	for i in _chambers.size():
		if not _chambers[i]:
			return _load_chamber(i)
	return false


## One press, one round. There is no other way this weapon is ever loaded.
##
## Deliberately not rationed here: a press is a press, so a reload is exactly as
## fast as the player can work the key. Whatever pause a weapon wants between a round
## landing and the next shot is [member reload_lock_time]'s to impose, and the
## revolver asks for none.
func _try_manual_reload() -> void:
	if is_stowed():
		return
	_load_next_chamber()


func _advance_lock(delta: float) -> void:
	if _lock_left > 0.0:
		_lock_left = maxf(_lock_left - delta, 0.0)


## How many chambers hold a round. The cylinder's own count, as against the
## reserve's - the two are different facts and this is the one the weapon acts on.
func get_loaded_count() -> int:
	var loaded := 0
	for chamber: bool in _chambers:
		if chamber:
			loaded += 1
	return loaded


## Whether there is a round in the pouch that is not already in the cylinder.
##
## A weapon with no ammunition configured at all always has one, so a test scene
## with no magazine still reloads.
func _has_round_to_chamber() -> bool:
	var ammo := get_ammo()
	if ammo == null:
		return true
	return get_loaded_count() < ammo.get_current()


## A full cylinder and no reload part way through, drawn from whatever the player
## is carrying. Called as a round begins - see [method CarriedWeapon.reload_to_ready].
func reload_to_ready() -> void:
	_lock_left = 0.0
	_fill_from_reserve()


## Arranges the ring to match the count the reserve came back with, filling from
## the top so the weapon is immediately fireable.
func _fill_from_reserve() -> void:
	var rounds := 0
	var ammo := get_ammo()
	if ammo != null:
		rounds = ammo.get_current()
	else:
		rounds = _chambers.size()

	for i in _chambers.size():
		_chambers[i] = i < rounds
	chambers_changed.emit(get_chambers())


## One round, straight down the barrel and added to the running scene rather than
## to the weapon, so it keeps flying while the revolver keeps turning.
##
## [b]It leaves along the muzzle's own heading, not the weapon's aim.[/b] The two
## are the same thing while the revolver is being pointed at something, so this
## changes nothing about an ordinary shot - but they part company the moment the
## weapon is twirled (see [RevolverSpin]), and the honest answer to "where was the
## barrel pointing" is the barrel. A shot taken mid-spin therefore goes where the
## gun was actually looking rather than being quietly corrected back to the cursor.
func _spawn_bullet() -> void:
	if projectile_scene == null or _muzzle == null:
		return
	var container := get_tree().current_scene
	if container == null:
		return

	var bullet: Projectile = projectile_scene.instantiate()
	container.add_child(bullet)
	bullet.global_position = _muzzle.global_position
	var half_spread := deg_to_rad(spread_angle_degrees) * 0.5
	bullet.global_rotation = _muzzle.global_rotation + randf_range(-half_spread, half_spread)
	# Announced after it is placed and pointed, so anything empowering it is handed
	# a round that is already the shot it is going to be.
	bullet_spawned.emit(bullet)


## Throws a coin, if there is not one already in the air. One coin at a time is
## the whole of the rule - the mechanic is about the shot you take at it, and two
## coins would make that a scramble rather than a decision.
func _try_throw_coin() -> void:
	if coin_scene == null or _target == null:
		return
	if Coin.get_active(self) != null:
		return

	var container := get_tree().current_scene
	if container == null:
		return

	var direction := _coin_direction()
	var coin := coin_scene.instantiate() as Coin
	if coin == null:
		return

	container.add_child(coin)
	coin.global_position = _target.global_position + direction * coin_spawn_offset
	coin.throw(_target, direction)
	coin_thrown.emit(coin)


## Where the coin goes. Random by default: the throw is a wager and the player's
## skill is in hitting it, not in placing it.
func _coin_direction() -> Vector2:
	if coin_random_direction:
		return Vector2.RIGHT.rotated(randf() * TAU)
	var aim := get_global_mouse_position() - _target.global_position
	return aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT


## Puts the hammer artwork up and takes it down again. Driven through
## [method _apply_look] so the picture and anything else that writes the sprite
## can never fight over it.
func _show_hammer() -> void:
	if _body == null or hammer_texture == null:
		return

	_hammer_flash = true
	_apply_look()
	var timer := get_tree().create_timer(maxf(hammer_time, 0.0001))
	timer.timeout.connect(_end_hammer)


func _end_hammer() -> void:
	if not _hammer_flash:
		return
	_hammer_flash = false
	_apply_look()


func _apply_look() -> void:
	if _body == null:
		return
	var wanted := hammer_texture if _hammer_flash else default_texture
	if wanted != null:
		_body.texture = wanted


## Puts the artwork where the three inspector fields say it belongs.
##
## Applied from one place and re-applied whenever any of them changes, so the
## weapon can be dragged into position while the game is running and nothing has
## to be reloaded to see it.
func _apply_art_transform() -> void:
	if _body == null or not is_node_ready():
		return
	_body.position = art_offset
	_body.rotation = deg_to_rad(art_rotation_degrees)
	# A negative Y scale is the half turn about X. It is written into the sprite's
	# own scale rather than onto the Art pivot above it because that pivot's Y scale
	# belongs to [HeldItemFlip], which mirrors it every frame to keep the weapon
	# upright as the aim crosses vertical - the two would fight over one value.
	var flip := -1.0 if art_flip_x else 1.0
	_body.scale = Vector2(art_scale, art_scale * flip)
