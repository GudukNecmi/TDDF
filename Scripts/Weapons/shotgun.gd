class_name Shotgun
extends CarriedWeapon
## Shotgun handling: the fire / pump-back / pump-forward cycle.
##
## Carrying, aiming, swaying and holstering are not here - they are
## [CarriedWeapon], which every weapon shares. This file is only the shotgun's own
## mechanism, which is the whole of what makes it a shotgun rather than a rifle.
##
## [b]The cycle.[/b] Three states, and R is the only thing that moves between two
## of them:
##
## [codeblock]
##   READY --fire--> SPENT --R--> PUMP_BACK --R--> READY
##     |                            ^
##     +--------------R-------------+
## [/codeblock]
##
## Firing is only ever possible from READY, so the weapon cannot be fired while
## the action is open. Pumping from READY is deliberate rather than an oversight:
## working the action on a loaded gun throws the live round away and leaves the
## breech open, exactly as working it on a spent one does, so both go the same way
## and the player keeps the same two-press rhythm wherever they started from. The
## shell that leaves is announced by [signal pumped_back] and thrown by
## [ShotgunFeedback] - firing ejects nothing, because nothing has been worked out
## of the breech yet.
##
## The two do differ in what they cost, and only in that: a live round worked out
## of the breech is a round wasted, while a spent case was paid for by the shot
## that emptied it. See [method _try_pump].
##
## What the player *sees* is two things. The body is one sprite whose texture is
## swapped between [member ready_texture], [member pumped_texture] and a brief
## [member firing_texture], so the weapon can only ever look like one state at a
## time. Over it rides the fore-end - [member pump_texture] - the one piece that
## genuinely moves: it appears hauled back on the first R and is driven home again
## on the second. Every picture is an inspector field rather than a layout in this
## file.

## Emitted when a shot actually leaves the barrel.
signal fired
## Emitted when the trigger is pulled and no shot comes out, for [b]any[/b]
## reason: the action is open, the case in the breech has already been fired, or
## there is nothing left to fire. Nothing is spawned and no state moves, so this
## is purely the announcement that the press did nothing - it is what the dry
## click hangs off, and it deliberately does not say which refusal it was, since
## the player hears the same empty click either way.
signal dry_fired
## Emitted when a valid reload press racks the pump back - the stroke itself,
## whether or not anything was in the breech to come out of it. The sound and the
## camera shove hang off this, because the action is worked either way.
signal pumped_back
## Emitted when that stroke actually throws a shell out - a fired case or a live
## round. [b]The shell on the ground hangs off this rather than off
## [signal pumped_back][/b], so working the action on an empty breech still looks
## and sounds like working the action, and simply produces nothing to eject.
signal shell_ejected
## Emitted when a valid reload press drives the pump forward and rearms it.
signal pumped_forward

enum State {
	## Loaded, action closed, and the only state a shot can leave from.
	READY,
	## Fired. Still closed and still showing the loaded artwork - the empty case
	## is in the breech until the action is worked.
	SPENT,
	## Action open, no round chambered, and firing is refused.
	PUMP_BACK,
}

const STATE_NAMES := {
	State.READY: "Ready",
	State.SPENT: "Spent",
	State.PUMP_BACK: "PumpBack",
}

@export_group("Look")
## Sprite whose texture is swapped as the action is worked. One sprite for the
## whole weapon, so two states cannot be shown at once.
@export var body_sprite_path: NodePath = ^"Art/Body"
## Shown whenever there is a case in the breech and the action is closed - both
## READY and SPENT. The gun the player carries around.
@export var ready_texture: Texture2D
## Shown while the action is open: the breech showing, nothing chambered. Firing
## is refused for exactly as long as this is on screen.
@export var pumped_texture: Texture2D
## Shown for an instant as the shot leaves, then dropped back to
## [member ready_texture]. This is the weapon's own firing artwork - the barrel
## lit from the inside - as opposed to the burst thrown at the muzzle, which is
## [ShotgunFeedback]'s business.
@export var firing_texture: Texture2D
## How long that firing artwork is held. Short: it is the flash of the shot, and
## the weapon must be back to its ordinary self before the player has finished
## seeing it.
@export var firing_texture_time: float = 0.09

@export_group("Pump")
## The sliding fore-end, drawn over the body.
##
## A separate sprite rather than part of the body artwork, because it is the one
## piece of the weapon that *moves* independently: it is registered on the same
## canvas as the body frames, so at its resting position it lands exactly where
## the fore-end belongs, and racking it is a translation from there.
@export var pump_sprite_path: NodePath = ^"Art/Pump"
## Artwork of the fore-end itself.
##
## [b]It is a permanent part of the weapon and is never hidden.[/b] The fore-end
## is not a state the gun is in, it is a piece of the gun - so nothing in this
## file writes to its visibility, and there is deliberately no field here to turn
## it off. All the action does is slide it: back on the first R, home on the
## second, and it is on screen for every frame of both.
@export var pump_texture: Texture2D
## Where the fore-end sits while the action is open, relative to the resting
## position its artwork registers at. Negative X is back towards the stock.
@export var pump_back_offset := Vector2(-70.0, 0.0)
## How long the fore-end takes to travel each way. Short, so the action feels
## worked rather than eased.
@export var pump_back_duration: float = 0.07
@export var pump_forward_duration: float = 0.09

@export_group("Shot")
## Marker the pellets leave from.
##
## It lives inside the weapon's mirrored rig rather than beside it, so it tracks
## the barrel as drawn. Held-item art is mirrored once the aim crosses vertical -
## see [HeldItemFlip] - and the drawn barrel moves with it; a marker left outside
## that mirroring stays where the barrel *was* and everything aimed from it ends
## up off the gun.
@export var muzzle_path: NodePath = ^"MuzzleRig/Muzzle"
## Pellet scene spawned on each shot.
@export var projectile_scene: PackedScene
## Pellets released per shot.
@export var pellet_count: int = 6
## Total cone the pellets are randomly spread across, in degrees.
@export var spread_angle_degrees: float = 12.0
## How many rounds are lost when the action is worked on a *loaded* gun - the
## live shell thrown out of the breech. One for a weapon that chambers one round
## at a time; 0 makes ejecting free, for a weapon whose rounds are recovered.
##
## A spent case never costs anything whatever this is set to: the shot that
## emptied it already paid for it.
@export var rounds_lost_on_eject: int = 1

@onready var _body: Sprite2D = get_node_or_null(body_sprite_path) as Sprite2D
@onready var _pump: Sprite2D = get_node_or_null(pump_sprite_path) as Sprite2D
@onready var _muzzle: Marker2D = get_node_or_null(muzzle_path) as Marker2D

var _state: State = State.READY
var _pump_rest_position: Vector2
var _pump_tween: Tween
var _firing_flash: bool = false


func _ready() -> void:
	# Captured once. Every stroke is measured from and returned to this, so a
	# hammered R key cannot walk the fore-end off the end of the gun.
	if _pump != null:
		_pump_rest_position = _pump.position
		if pump_texture != null:
			_pump.texture = pump_texture
		# The one and only write to the fore-end's visibility in the whole file, and
		# it turns it on. Nothing after this point ever touches it again.
		_pump.visible = true
	_apply_look()
	super._ready()


func _weapon_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_try_fire()
	elif event.is_action_pressed(&"pump"):
		_try_pump()


## Breech closed on a live shell, fore-end home. A round should never begin with
## the action hanging open because of how the last one ended.
##
## The shotgun chambers straight out of the reserve, so there is no magazine here
## to fill - being READY is the whole of being loaded, and the shells themselves
## were resupplied before this was called.
func reload_to_ready() -> void:
	_set_state(State.READY)


## The ammunition check sits beside the state check and nowhere else: an empty
## gun is refused exactly as an open one is, leaving the state, the fore-end and
## the artwork untouched, so running dry never disturbs the pump rhythm. The
## shell is spent before the pellets exist, and only a spend that went through
## lets the shot happen - so the count cannot go below zero and a refused shot
## cannot fire for free.
##
## Both refusals announce themselves through [signal dry_fired] and are otherwise
## silent: no state moves, nothing is spawned, and the fore-end is left wherever
## the player put it. That is what lets the click be hung on a trigger pull that
## did nothing without any of the reasons for it having to be listed twice.
func _try_fire() -> void:
	if _state != State.READY:
		dry_fired.emit()
		return
	if not spend_ammo():
		dry_fired.emit()
		return
	print("Fire")
	_spawn_pellets()
	_set_state(State.SPENT)
	# After the state, so the flash sits on top of the artwork the new state just
	# chose rather than being wiped by it.
	_show_firing_texture()
	fired.emit()


## Puts the firing artwork up and takes it down again a moment later.
##
## The flash is deliberately a *look* and not a state: the weapon is already SPENT
## the instant the shot leaves, so nothing about firing, pumping or what the
## player is allowed to do next depends on this. Working the action during the
## flash simply cancels it - see [method _set_state].
func _show_firing_texture() -> void:
	if _body == null or firing_texture == null:
		return

	_firing_flash = true
	_body.texture = firing_texture
	var timer := get_tree().create_timer(maxf(firing_texture_time, 0.0001))
	timer.timeout.connect(_end_firing_texture)


func _end_firing_texture() -> void:
	if not _firing_flash:
		return
	_firing_flash = false
	_apply_look()


## Pellets leave the muzzle along the barrel, each nudged by a random angle
## inside the spread cone. They are added to the scene rather than to the
## shotgun, so they keep flying straight while the weapon keeps turning.
func _spawn_pellets() -> void:
	if projectile_scene == null or _muzzle == null:
		return
	var container := get_tree().current_scene
	if container == null:
		return

	var half_spread := deg_to_rad(spread_angle_degrees) * 0.5
	for i in pellet_count:
		var pellet: Projectile = projectile_scene.instantiate()
		container.add_child(pellet)
		pellet.global_position = _muzzle.global_position
		pellet.global_rotation = global_rotation + randf_range(-half_spread, half_spread)
		# Speed is not set here on purpose: it falls off with distance now, and
		# lives with the rest of the pellet's range profile so one value governs
		# damage, speed, colour, glow and light together.


## One reload press racks the action open, the next drives it shut and rearms it.
##
## Both closed states go the same way, which is the whole of what makes the
## two-press rhythm the same wherever it is started from: a spent gun has its
## empty case worked out, and a loaded one throws its live round away. Either way
## a shell leaves, the breech is left open, and the weapon cannot be fired until
## the second press has closed it again.
##
## [b]What it costs is the one thing the two do not share[/b], and it follows
## from what is actually in the breech rather than from the press:
##
##   * From SPENT the case has already been paid for - the shot that emptied it
##     spent the round - so working it out again is free. Charging here would bill
##     the player twice for one shell.
##   * From READY the round leaving is live and unfired, so it is gone: it costs
##     [member rounds_lost_on_eject]. This is the price of working the action on a
##     loaded gun, and it is why doing so is a decision rather than a free habit.
##
## An empty gun in READY has nothing chambered to lose, so the spend simply fails
## and the stroke is free - the count can never be driven below zero. Nothing
## about the state machine, the stroke or the shell that flies changes either way;
## this is accounting only.
func _try_pump() -> void:
	match _state:
		State.READY, State.SPENT:
			# Asked before the round is spent, because spending it is what would
			# make the breech look empty.
			var ejecting := _breech_holds_shell()
			if _state == State.READY and _ammo != null:
				_ammo.discard_rounds(rounds_lost_on_eject)
			_set_state(State.PUMP_BACK)
			pumped_back.emit()
			if ejecting:
				shell_ejected.emit()
		State.PUMP_BACK:
			_set_state(State.READY)
			pumped_forward.emit()


## Whether there is anything in the breech for the next stroke to throw out.
##
## Derived from the state and the count rather than tracked separately, so it
## cannot drift out of step with either:
##
##   * SPENT always holds a case. A shot has just been fired, and the empty is in
##     there until the action is worked - including the shot that emptied the
##     reserve, which is why running dry still leaves one last case to eject.
##   * READY holds a live round only while there are rounds to have chambered.
##     An empty gun has nothing in it, so the stroke produces no shell.
##
## A weapon with no [WeaponAmmo] at all is treated as always loaded, so a test
## scene with no magazine still ejects.
func _breech_holds_shell() -> bool:
	if _state == State.SPENT:
		return true
	return _ammo == null or not _ammo.is_empty()


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	# Any state change outranks the firing flash: working the action during it
	# must show the action, not a shot that has already happened.
	_firing_flash = false
	_apply_look()
	_slide_pump()
	print(STATE_NAMES[_state])


## The one place the weapon's picture is decided, driven off the state rather than
## set at each transition - so a state can only ever be shown as one thing, and
## a weapon left in a state it was put into by something else still looks right.
##
## A sprite with no textures configured is left with whatever it was authored
## with, so an unfinished weapon still draws.
func _apply_look() -> void:
	if _body == null:
		return

	var wanted := pumped_texture if _state == State.PUMP_BACK else ready_texture
	if wanted != null:
		_body.texture = wanted


## Runs the fore-end to wherever the current state says it belongs. Retargeted
## rather than restarted from scratch, so hammering R hands the stroke over
## mid-travel instead of snapping the fore-end back to begin again.
##
## Position is the only thing a stroke touches. The fore-end is on screen before
## it, during it and after it - see [member pump_texture].
func _slide_pump() -> void:
	if _pump == null:
		return

	var open := _state == State.PUMP_BACK
	var goal := _pump_rest_position + (pump_back_offset if open else Vector2.ZERO)
	var duration := pump_back_duration if open else pump_forward_duration

	if _pump_tween != null and _pump_tween.is_running():
		_pump_tween.kill()

	if duration <= 0.0:
		_pump.position = goal
		return

	_pump_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pump_tween.tween_property(_pump, "position", goal, duration)
