class_name LeverActionRifle
extends CarriedWeapon
## The lever action rifle: one precise round at a time, and a reload the player
## performs with their hand rather than waits out.
##
## Carrying, aiming, swaying and holstering are [CarriedWeapon]'s, shared with
## every other weapon. What is here is only what makes this rifle itself.
##
## [b]The rhythm.[/b] Two states, and every shot passes through both of them:
##
## [codeblock]
##   READY --fire--> LEVER_DOWN --Space--> READY
##     |                  ^                  |
##     |                  |                  |
##     +---320 degrees of mouse around the player---+
##            (also empties the magazine onto the floor;
##             the Space that follows loads a full seven)
## [/codeblock]
##
## [b]Every shot drops the lever.[/b] Firing leaves the rifle unable to fire, and
## Space is what works it back up - so the weapon's beat is click, space, click,
## space, and a player who forgets gets a dry click instead of a shot. That is the
## whole feel of the weapon, and the reason it is a rifle rather than a faster
## shotgun: each round is a decision the hand has to follow through.
##
## The 320 degree gesture is the *other* thing the lever does, and it is a
## different act: the player winds the cursor a full turn around their character -
## see [MouseOrbit], which is what makes that a real circular gesture rather than
## a mouse flick - and [b]every unfired round still in the magazine is thrown on
## the ground[/b]. The Space that follows loads a fresh seven instead of merely
## working the action. Cycling at 5 of 7 therefore discards those 5, which is what
## makes reloading early a decision rather than a habit.
##
## Both endings of the lever look the same and both are cleared by the same key.
## What tells them apart is [member _reloading], set only by the gesture - so the
## rifle knows whether the Space it is about to be given means "work the action"
## or "load it".
##
## There is deliberately no automatic reload and no timer anywhere in this file.
## An empty rifle simply cannot fire, and stays that way until the player performs
## the gesture and presses the reload key - so running dry is something they have
## to answer, not something that answers itself.
##
## What the player *sees* is two moving pieces. The body swaps to
## [member hammer_texture] for a heartbeat as the shot leaves - the hammer
## dropping, a look and not a state - and the lever swings down and back on its
## own pivot. Everything cosmetic beyond that (the blast, the sounds, the camera,
## the rounds hitting the ground) is [LeverActionFeedback]'s, hung off the signals
## below.

## Emitted when a shot actually leaves the barrel.
signal fired
## Emitted when the trigger is pulled and nothing comes out, for any reason: the
## lever is down, or the magazine is empty. The player hears the same click either
## way, so this does not say which.
signal dry_fired
## Emitted as the lever drops and the action opens, carrying how many live rounds
## were thrown away with it - 0 when the rifle was already empty. The rounds that
## hit the ground hang off this count.
signal lever_opened(rounds_ejected: int)
## Emitted as the lever is driven home, carrying how many rounds went in - a full
## magazine after a reload gesture, and 0 when the lever was only being worked
## between shots.
signal lever_closed(rounds_loaded: int)
## Emitted as the shot itself drops the lever. Deliberately separate from
## [signal lever_opened]: nothing is ejected and nothing is announced, because the
## shot's own report is what the player hears at that moment.
signal lever_dropped
## Emitted continuously while the reload gesture is being performed, so a tension
## effect can follow it round. Ends at 0 when a gesture is abandoned.
signal reload_progress(degrees: float, ratio: float)

enum State {
	## Loaded or empty, action closed - the only state a shot can leave from.
	READY,
	## Lever down, action open. Firing is refused until it is closed again.
	LEVER_DOWN,
}

const STATE_NAMES := {
	State.READY: "Ready",
	State.LEVER_DOWN: "LeverDown",
}

@export_group("Look")
## Sprite whose texture is swapped as the hammer falls. One sprite for the whole
## body, so it can only ever look like one thing at a time.
@export var body_sprite_path: NodePath = ^"Art/Body"
## The rifle as it is carried, and what it returns to after every shot.
@export var default_texture: Texture2D
## Shown for a heartbeat as the shot leaves: the hammer back off the breech.
##
## It is a *look* and not a state - the rifle is ready to fire again the instant
## the shot has gone, so nothing about what the player may do next depends on this
## picture being up or down.
@export var hammer_texture: Texture2D
## How long that picture is held, in seconds. Deliberately tiny: it should read as
## the hammer striking, not as an animation the player has to wait through.
@export var hammer_time: float = 0.05

@export_group("Lever")
## The node the lever swings on.
##
## [b]It is the pivot, not the picture.[/b] This node is rotated, so wherever it
## sits is the pin the lever turns about - which is why the artwork hangs off it
## as a child with its own offset rather than being rotated directly. Moving the
## pivot node in the editor moves the hinge, and the lever is drawn swinging from
## wherever it was left; nothing in this file writes to either, so the whole of
## the lever's placement is inspector work on the scene.
@export var lever_pivot_path: NodePath = ^"Art/LeverPivot"
## How far the lever swings when the action is opened, in degrees. Positive turns
## it clockwise, which with the rifle drawn pointing right drops the lever
## downwards.
@export var lever_down_degrees: float = 45.0
## How long the drop takes. Fast: the lever is thrown, not eased.
@export var lever_down_duration: float = 0.08
## How long it takes to come back. Faster still - this is the rifle snapping shut
## on a fresh magazine.
@export var lever_return_duration: float = 0.06

@export_group("Magazine")
## How many rounds the tube under the barrel holds.
##
## [b]This is the magazine, and it is not the ammunition.[/b] What the player is
## carrying is the reserve behind [WeaponAmmo] - forty-five rifle rounds in a
## pouch - and this is how many of them are in the rifle at once. The two are
## deliberately separate numbers: the reserve is what runs out over a round, and
## this is what runs out between reloads, and raising either has nothing to do
## with the other.
##
## The reserve is spent as the shot leaves rather than as the magazine is filled,
## so loading is free and firing is what costs - which means the magazine can never
## hold rounds the player does not actually have.
@export var magazine_size: int = 7

@export_group("Reload gesture")
## The [MouseOrbit] watching for the circle the player draws around themselves.
## How far round they must get, how wide the circle must be and what disqualifies
## a flick are all its own inspector fields.
@export var orbit_path: NodePath = ^"Orbit"
## Action that loads the rifle once the lever is down. Space, shared with the
## shotgun's pump, so one key means "work the action" whatever is in the player's
## hands.
@export var reload_action: StringName = &"pump"
## How many rounds a reload puts in. 0 fills the magazine to whatever its capacity
## currently is, which is what keeps a future capacity upgrade working without
## this being touched.
@export var reload_rounds: int = 0

@export_group("Shot")
## Marker the round leaves from.
##
## It lives inside the weapon's mirrored rig rather than beside it, so it tracks
## the barrel as drawn - see [HeldItemFlip].
@export var muzzle_path: NodePath = ^"MuzzleRig/Muzzle"
## Bullet scene spawned on each shot.
@export var projectile_scene: PackedScene
## Rounds released per shot. One - this is a rifle, and the single precise shot is
## the point of it.
@export var shots_per_pull: int = 1
## Cone the shot is spread across, in degrees. 0 is dead straight, which is what a
## rifle should be.
@export var spread_angle_degrees: float = 0.0

@onready var _body: Sprite2D = get_node_or_null(body_sprite_path) as Sprite2D
@onready var _lever: Node2D = get_node_or_null(lever_pivot_path) as Node2D
@onready var _muzzle: Marker2D = get_node_or_null(muzzle_path) as Marker2D
@onready var _orbit: MouseOrbit = get_node_or_null(orbit_path) as MouseOrbit

var _state: State = State.READY
var _lever_rest_rotation: float = 0.0
var _lever_tween: Tween
var _hammer_flash: bool = false
## Whether the lever went down for a reload rather than for a shot. It is the only
## thing that decides whether the next press of the reload key loads rounds or
## merely works the action.
var _reloading: bool = false
## Rounds in the tube. Never above [member magazine_size], and never above what the
## reserve is actually carrying - see [method _fill_magazine].
var _in_magazine: int = 0


func _ready() -> void:
	if _lever != null:
		# Captured once, so every swing is measured from and returned to the
		# authored rest angle and a hammered reload cannot walk the lever round.
		_lever_rest_rotation = _lever.rotation

	if _orbit != null:
		_orbit.completed.connect(_on_orbit_completed)
		_orbit.progress_changed.connect(_on_orbit_progress)
		_orbit.cancelled.connect(_on_orbit_cancelled)

	_apply_look()
	super._ready()
	# Loaded from whatever the player is carrying rather than assumed full: the
	# reserve survives a run, so a rifle picked back up with four rounds left in the
	# pouch comes back with four in the tube.
	_fill_magazine()

	# The circle is drawn around the *character*, not around the weapon. The
	# weapon trails and sways behind them, so using it as the centre would let the
	# player's own movement turn the angle; the body they are standing on is the
	# only still point. The target is whatever this weapon was told to follow, so
	# nothing here needs a path into a scene it was not authored in.
	if _orbit != null and _target != null:
		_orbit.set_pivot(_target)


## The gesture is only watched while the rifle is actually in the player's hands.
## It is deliberately watched in [b]both[/b] states: a rifle whose lever is down
## from the shot that emptied it is exactly when a player wants to reload, and
## making them work the action first only to open it again would be a keypress
## that means nothing. Stowed, it is switched off, so circling the mouse in the
## base banks nothing to be spent later.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _orbit != null:
		var wanted := _holster <= 0.0
		if _orbit.active != wanted:
			_orbit.active = wanted


func _weapon_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_try_fire()
	elif event.is_action_pressed(reload_action):
		_try_load()


func get_state() -> State:
	return _state


func is_lever_down() -> bool:
	return _state == State.LEVER_DOWN


## One trigger pull, one round - and the lever drops behind it.
##
## Both refusals - the lever being down and the magazine being empty - are
## announced the same way and change nothing: no state moves and nothing is
## spawned. The round is spent before the bullet exists and only a spend that went
## through lets the shot happen, so the count can never go below zero and a
## refused shot can never fire for free.
##
## The order at the end matters. The hammer is shown *after* the state has moved
## to LEVER_DOWN, because that state change is what swings the lever - and the
## hammer has to be the picture on top of it. [method _apply_look] reads the flash
## rather than being overwritten by it, so the two coexist for the tenth of a
## second the hammer is up.
func _try_fire() -> void:
	if _state != State.READY:
		dry_fired.emit()
		return
	# An empty tube clicks exactly as an empty pouch does. Both are checked, because
	# they are genuinely different: the rifle can be out of rounds in the magazine
	# while the player still has plenty to reload with.
	if _in_magazine <= 0:
		dry_fired.emit()
		return
	if not spend_ammo():
		dry_fired.emit()
		return

	_in_magazine -= 1
	_spawn_bullet()
	# Working the action is part of the shot, not a consequence of it: the rifle is
	# unable to fire again from the instant the round leaves.
	_set_state(State.LEVER_DOWN)
	_swing_lever(true)
	_show_hammer()
	fired.emit()
	lever_dropped.emit()


## The gesture came all the way round. The action opens, and everything unfired
## still in the magazine is thrown out with it.
##
## The ejection is counted here rather than by whatever draws the rounds, because
## the magazine is the only thing that knows what was in it - the feedback is
## handed the number and throws that many. An already empty rifle opens exactly
## the same way and ejects nothing.
## It is accepted from either state. With the lever already down from a shot the
## action is simply left open and the magazine emptied - which is exactly what a
## player who has just fired their last round is asking for.
func _on_orbit_completed(_clockwise: bool) -> void:
	# What hits the floor is what was in the tube, not everything the player is
	# carrying - and it is charged to the reserve here, because those rounds were
	# never spent by a shot and are genuinely gone.
	var ejected := _in_magazine
	_in_magazine = 0
	if ejected > 0 and _ammo != null:
		_ammo.discard_rounds(ejected)

	# The flag, not the state, is what makes the next Space load rounds rather than
	# merely work the action.
	_reloading = true
	_set_state(State.LEVER_DOWN)
	_swing_lever(true)
	lever_opened.emit(ejected)


func _on_orbit_progress(degrees: float, ratio: float) -> void:
	reload_progress.emit(degrees, ratio)


func _on_orbit_cancelled() -> void:
	reload_progress.emit(0.0, 0.0)


## Drives the lever home and makes the rifle fireable again.
##
## [b]What it costs depends on why the lever was down[/b], and that is the only
## difference between the two:
##
##   * After a shot it is just the action being worked. Nothing is loaded - the
##     magazine still holds whatever the shot left in it.
##   * After the reload gesture it loads a full magazine, because the gesture threw
##     the old one away.
##
## Pressing the key with the lever already up does nothing at all. [b]It can never
## fire[/b] - there is no path from here to a shot - so a player mashing space
## between rounds is only ever readying the weapon.
func _try_load() -> void:
	if _state != State.LEVER_DOWN:
		return

	var loaded := 0
	if _reloading:
		loaded = _fill_magazine(reload_rounds)

	_reloading = false
	_set_state(State.READY)
	_swing_lever(false)
	lever_closed.emit(loaded)


## How many rounds are in the tube, for a readout.
func get_magazine_count() -> int:
	return _in_magazine


func get_magazine_size() -> int:
	return maxi(magazine_size, 0)


## Puts rounds in the tube and returns how many went in. [param rounds] of 0 or
## less fills it, which is what a reload asks for.
##
## [b]Nothing is taken from the reserve here.[/b] A round is charged as it is fired,
## so the magazine is a claim on ammunition the player already has rather than a
## second pile of it - which is why filling is capped by what the reserve holds as
## well as by the tube. Without that cap a player with two rounds left could load
## seven and fire five they never had.
func _fill_magazine(rounds: int = 0) -> int:
	var carried := magazine_size if _ammo == null else _ammo.get_current()
	var room := maxi(get_magazine_size() - _in_magazine, 0)
	var wanted := room if rounds <= 0 else mini(rounds, room)
	var loaded := mini(wanted, maxi(carried - _in_magazine, 0))
	if loaded <= 0:
		return 0

	_in_magazine += loaded
	return loaded


## Back to a rifle that can be fired: lever up, tube filled from whatever the
## player is carrying. Called as a round begins - see
## [method CarriedWeapon.reload_to_ready].
func reload_to_ready() -> void:
	_reloading = false
	_in_magazine = 0
	_fill_magazine()
	if _state != State.READY:
		_set_state(State.READY)
		_swing_lever(false)


## Puts the hammer artwork up and takes it down again [member hammer_time] later.
##
## It survives the lever dropping, which happens in the same instant the shot
## leaves - the flash is a *look* laid over whatever state the rifle is in, not a
## state of its own, so the picture and the mechanism never fight over the sprite.
## The timer is what ends it, and it always ends: nothing else writes the hammer
## texture, so it can only ever be up for the length of one shot.
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


## One round, straight down the barrel. Added to the running scene rather than to
## the rifle, so it keeps flying straight while the weapon keeps turning.
func _spawn_bullet() -> void:
	if projectile_scene == null or _muzzle == null:
		return
	var container := get_tree().current_scene
	if container == null:
		return

	var half_spread := deg_to_rad(spread_angle_degrees) * 0.5
	for i in maxi(shots_per_pull, 1):
		var bullet: Projectile = projectile_scene.instantiate()
		container.add_child(bullet)
		bullet.global_position = _muzzle.global_position
		bullet.global_rotation = global_rotation + randf_range(-half_spread, half_spread)
		# Speed, damage, colour and range all come from the bullet's own profile,
		# so the weapon decides where the shot starts and the profile decides
		# everything it does afterwards.


## The hammer flash is deliberately [b]not[/b] cancelled here. Firing moves the
## state on the same frame it shows the hammer, so clearing it would mean the
## picture never appeared at all.
func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	_apply_look()
	# A gesture half-finished when the state changed belongs to the state it was
	# started in, so it never carries over into the next one.
	if _orbit != null:
		_orbit.reset()
	print(STATE_NAMES[_state])


## The one place the rifle's picture is decided, driven off the flash rather than
## written at each transition - so however the state moves under it, the body
## shows the hammer for exactly as long as the flash is up and the default at
## every other moment.
##
## Unlike the shotgun there is no open-action artwork: what opens is the lever,
## and the lever is its own sprite.
func _apply_look() -> void:
	if _body == null:
		return

	var wanted := hammer_texture if _hammer_flash else default_texture
	if wanted != null:
		_body.texture = wanted


## Swings the lever to wherever the state says it belongs. Retargeted rather than
## restarted, so a reload begun mid-swing hands the movement over instead of
## snapping the lever back to begin again.
func _swing_lever(down: bool) -> void:
	if _lever == null:
		return

	var goal := _lever_rest_rotation + (deg_to_rad(lever_down_degrees) if down else 0.0)
	var duration := lever_down_duration if down else lever_return_duration

	if _lever_tween != null and _lever_tween.is_running():
		_lever_tween.kill()

	if duration <= 0.0:
		_lever.rotation = goal
		return

	_lever_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lever_tween.tween_property(_lever, "rotation", goal, duration)
