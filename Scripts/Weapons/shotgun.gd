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
## Emitted whenever the banked pump charge moves - a cycle completed, a shot
## spending it, a reset. Only ever above 0 while a [PumpCharge] is active; see
## [method get_pump_charge]. Sent [b]before[/b] [signal pumped_forward] on the
## stroke that earned it, so feedback can be tuned to the new charge by the time
## the stroke's own sound plays.
signal pump_charge_changed(charge: int, max_charge: int)
## Emitted as a charged shot leaves, [b]before[/b] [signal fired], with the charge
## it spent. An uncharged shot sends nothing.
signal charge_released(charge: int)
## Emitted when one pump press runs the whole cycle with the trigger held - see
## [FanHammer]. Sent after [signal pumped_back] and [signal pumped_forward], which
## the stroke still announces as ever.
signal fan_pumped
## Emitted as a shot that followed a fanned cycle leaves, [b]before[/b]
## [signal fired], with the heat that shot leaves the weapon at, 0..1.
signal fanned_shot(heat: float)
## Emitted once per shot, [b]after[/b] [signal fired], while a [ShotRecoil] is
## active, with the velocity change the shot gave its holder and the holder it
## went to - see [method _kick_holder]. Never per pellet.
signal recoil_kicked(push: Vector2, holder: Node2D)

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
## Pellets released per shot before any upgrade - see [method get_pellet_count].
@export var pellet_count: int = 6
## Total cone the pellets are randomly spread across, in degrees, before any
## upgrade - see [method get_spread_degrees].
@export var spread_angle_degrees: float = 12.0
## How many rounds are lost when the action is worked on a *loaded* gun - the
## live shell thrown out of the breech. One for a weapon that chambers one round
## at a time; 0 makes ejecting free, for a weapon whose rounds are recovered.
##
## A spent case never costs anything whatever this is set to: the shot that
## emptied it already paid for it.
@export var rounds_lost_on_eject: int = 1
## Where, under the node the weapon follows, a [ShotRecoil]'s shove is handed -
## see [PlayerRecoil]. A holder without it is simply not pushed.
@export var recoil_receiver_path: NodePath = ^"Recoil"

@export_group("Charge")
## Group a weapon's charge joins, so the sight and the readout over the ammunition
## find it without being wired to a weapon - the same group the revolver's twirl
## joins. See [Crosshair] and [SpinMultiplier].
@export var charge_group: StringName = &"weapon_charge"

@onready var _body: Sprite2D = get_node_or_null(body_sprite_path) as Sprite2D
@onready var _pump: Sprite2D = get_node_or_null(pump_sprite_path) as Sprite2D
@onready var _muzzle: Marker2D = get_node_or_null(muzzle_path) as Marker2D

var _state: State = State.READY
var _pump_rest_position: Vector2
var _pump_tween: Tween
var _firing_flash: bool = false
## Full pump cycles banked into the next shot. Only ever above 0 while the weapon's
## stats carry a [PumpCharge].
var _charge: int = 0
## Whether the last cycle was fanned, so the shot that follows is a fanned shot.
var _fanned: bool = false
## Rapid-fire heat, 0..1 - see [FanHammer]. Only ever above 0 while one is active.
var _fan_heat: float = 0.0
var _since_fan_shot: float = 0.0
## Bumped whenever a pending held-trigger shot must be dropped.
var _hammer_serial: int = 0


func _ready() -> void:
	if not charge_group.is_empty():
		add_to_group(charge_group)
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
		if _fan_hammer() != null and Input.is_action_pressed(&"fire"):
			_fan_pump()
		else:
			_fanned = false
			_try_pump()


## Heat drains and the aim loosens back up once the fanning stops. With no
## [FanHammer] active the weapon is put straight back to itself.
func _process(delta: float) -> void:
	var fan := _fan_hammer()
	if fan == null:
		_fan_heat = 0.0
		aim_scale = 1.0
		return
	_since_fan_shot += delta
	_fan_heat = fan.cooled(_fan_heat, _since_fan_shot, delta)
	aim_scale = fan.aim_scale_at(_fan_heat)


## Breech closed on a live shell, fore-end home. A round should never begin with
## the action hanging open because of how the last one ended.
##
## The shotgun chambers straight out of the reserve, so there is no magazine here
## to fill - being READY is the whole of being loaded, and the shells themselves
## were resupplied before this was called.
func reload_to_ready() -> void:
	_set_state(State.READY)
	_set_charge(0)
	_fanned = false
	_fan_heat = 0.0
	_hammer_serial += 1


## Ready is READY and nothing else - the same test [method _try_fire] itself
## makes, so the crosshair can never show red while a pulled trigger would
## still only click. See [method CarriedWeapon.is_ready_to_fire].
func is_ready_to_fire() -> bool:
	return _state == State.READY and has_ammo()


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
	var released := _charge
	var fan := _fan_hammer() if _fanned else null
	_fanned = false
	# Read before the charge is spent, so a charged shot's pellets are counted.
	var recoil_pellets := get_pellet_count()
	# The aim the pellets leave along, before a fanned shot throws it.
	var aim := Vector2.from_angle(global_rotation)
	_spawn_pellets()
	_set_state(State.SPENT)
	# After the state, so the flash sits on top of the artwork the new state just
	# chose rather than being wiped by it.
	_show_firing_texture()
	if released > 0:
		charge_released.emit(released)
	# The charge is still banked while the shot is announced, so the muzzle burst
	# reads the charged spread off [method get_spread_degrees]; it is spent after.
	if fan != null:
		fanned_shot.emit(fan.heat_after_shot(_fan_heat))
	fired.emit()
	_kick_holder(aim, recoil_pellets)
	_set_charge(0)
	# Heat and the throw of the aim land after the shot, so they unsettle the next
	# one rather than this.
	if fan != null:
		_fan_heat = fan.heat_after_shot(_fan_heat)
		_since_fan_shot = 0.0
		rotation += deg_to_rad(randf_range(-1.0, 1.0) * fan.aim_kick_at(_fan_heat))


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
##
## An active Legendary's [ShotPattern] - Devil's Barrel - takes over where each
## pellet points, how it flies and what it trails; see [member WeaponStats.shot_pattern].
## A full BLOOD PUMP charge arms every pellet to pierce through the same
## [WeaponStats] block - see [member PumpCharge.max_charge_modifiers].
func _spawn_pellets() -> void:
	if projectile_scene == null or _muzzle == null:
		return
	var container := get_tree().current_scene
	if container == null:
		return

	# The charged block when charge is banked, so damage, range and spread all come
	# out of the ordinary stat code with the charge already in them.
	var stats := _shot_stats()
	var charged := stats != null and stats != get_stats()
	var pattern: ShotPattern = null if stats == null else stats.shot_pattern
	# DEVIL'S BREATH rides beside any pattern rather than replacing it: the pellets
	# fly however they were going to and explode on top - see [ShotExplosion].
	var explosion: ShotExplosion = null if stats == null else stats.shot_explosion
	var half_spread := deg_to_rad(get_spread_degrees()) * 0.5
	# One roll for the whole blast - a critical shotgun shot is every pellet of it.
	var critical := roll_critical()
	for i in get_pellet_count():
		var pellet: Projectile = projectile_scene.instantiate()
		arm_projectile(pellet, critical, stats if charged else null)
		if pattern != null:
			pattern.prepare(pellet)
		if explosion != null:
			explosion.prepare(pellet, pattern != null)
		container.add_child(pellet)
		pellet.global_position = _muzzle.global_position
		if pattern != null:
			pellet.global_rotation = pattern.heading(global_rotation, half_spread)
			pattern.attach_trail(pellet, container, stats.size_scale())
		else:
			pellet.global_rotation = global_rotation + randf_range(-half_spread, half_spread)
		if explosion != null:
			explosion.attach_trail(pellet, container, stats.size_scale())
		# Speed is not set here on purpose: it falls off with distance now, and
		# lives with the rest of the pellet's range profile so one value governs
		# damage, speed, colour, glow and light together.


## Pellets one shot really releases: the authored [member pellet_count] plus the
## weapon's pellet count upgrades. Never fewer than one.
func get_pellet_count() -> int:
	var stats := _shot_stats()
	var bonus := 0 if stats == null else stats.pellet_bonus()
	return maxi(pellet_count + bonus, 1)


## The cone one shot really uses: the authored [member spread_angle_degrees]
## tightened by the weapon's accuracy upgrades, then widened by any banked charge -
## see [method WeaponStats.spread_scale], which keeps accuracy from cancelling it.
func get_spread_degrees() -> float:
	var stats := _shot_stats()
	return spread_angle_degrees * (1.0 if stats == null else stats.spread_scale())


## The stats the next shot leaves with: the weapon's own block, or - with charge
## banked - a copy of it with the charge folded in. See [method PumpCharge.charged_stats].
##
## Rapid-fire heat widens it further the same way - see [method FanHammer.unsteady_stats].
func _shot_stats() -> WeaponStats:
	var stats := get_stats()
	if stats == null:
		return null
	if stats.pump_charge != null and _charge > 0:
		stats = stats.pump_charge.charged_stats(stats, _charge)
	if stats.fan_hammer != null and _fan_heat > 0.0:
		stats = stats.fan_hammer.unsteady_stats(stats, _fan_heat)
	return stats


# --- Recoil ----------------------------------------------------------------------

## RECOIL DEVIL: the shot throws whoever is holding the weapon straight back from
## the aim - see [ShotRecoil]. The shove is the holder's own [PlayerRecoil] to
## carry; this only works out how hard and which way, once per shot.
func _kick_holder(aim: Vector2, pellets: int) -> void:
	var stats := get_stats()
	var recoil: ShotRecoil = null if stats == null else stats.shot_recoil
	if recoil == null or _target == null:
		return
	var push := recoil.push_for(aim, pellets)
	var receiver := _target.get_node_or_null(recoil_receiver_path)
	if receiver != null and receiver.has_method(&"kick"):
		receiver.call(&"kick", push, recoil)
	recoil_kicked.emit(push, _target)


# --- Fan the hammer --------------------------------------------------------------

## Rapid-fire heat, 0..1, and always 0 while no [FanHammer] is active.
func get_fan_heat() -> float:
	return _fan_heat


func _fan_hammer() -> FanHammer:
	var stats := get_stats()
	return null if stats == null else stats.fan_hammer


## One press, the whole cycle: both strokes are worked through [method _try_pump]
## exactly as two presses would work them, so what a stroke costs, what it throws
## out and what charge it banks are unchanged. Then the held trigger drops the
## hammer - see [member FanHammer.held_trigger_fires].
func _fan_pump() -> void:
	var fan := _fan_hammer()
	if _state != State.PUMP_BACK:
		_try_pump()
	_try_pump()
	_fanned = true
	_slide_pump_cycle(fan)
	fan_pumped.emit()

	_hammer_serial += 1
	if not fan.held_trigger_fires:
		return
	if fan.hammer_delay <= 0.0:
		_drop_hammer(_hammer_serial)
	else:
		# Paused with the tree, so the developer panel cannot fire the weapon.
		get_tree().create_timer(fan.hammer_delay, false).timeout.connect(
			_drop_hammer.bind(_hammer_serial))


## The held trigger firing the freshly closed action - an ordinary trigger pull,
## so it spends a real shell or clicks dry like any other.
func _drop_hammer(serial: int) -> void:
	if serial != _hammer_serial or _state != State.READY or _fan_hammer() == null:
		return
	if not Input.is_action_pressed(&"fire") or _holster > 0.0 or _fire_blocked_by_zone():
		return
	_try_fire()


## The fore-end slammed back and home in one go, showing the open action for the
## back stroke. The state is already READY by now; this is only the picture.
func _slide_pump_cycle(fan: FanHammer) -> void:
	if _pump == null:
		return
	if _pump_tween != null and _pump_tween.is_running():
		_pump_tween.kill()
	if _body != null and pumped_texture != null and not _firing_flash:
		_body.texture = pumped_texture
	_pump_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pump_tween.tween_property(_pump, "position",
		_pump_rest_position + pump_back_offset, maxf(fan.stroke_back_time, 0.001))
	_pump_tween.tween_callback(_end_fan_stroke)
	_pump_tween.tween_property(_pump, "position",
		_pump_rest_position, maxf(fan.stroke_forward_time, 0.001))


func _end_fan_stroke() -> void:
	if not _firing_flash:
		_apply_look()


# --- Pump charge -----------------------------------------------------------------

## Full pump cycles banked into the next shot, 0 when nothing is - and always 0
## while no [PumpCharge] is active.
func get_pump_charge() -> int:
	return _charge


## Most that can be banked, or 0 while no [PumpCharge] is active.
func get_max_pump_charge() -> int:
	var charge := _pump_charge()
	return 0 if charge == null else maxi(charge.max_charges, 1)


## Drops whatever charge is banked without firing it. The developer panel's reset.
func reset_pump_charge() -> void:
	_set_charge(0)


## How full the charge is, 0..1. Read by [Crosshair] through [member charge_group].
func get_charge_ratio() -> float:
	var most := get_max_pump_charge()
	return 0.0 if most <= 0 else clampf(float(_charge) / float(most), 0.0, 1.0)


## The readout over the ammunition - see [SpinMultiplier]. Empty with nothing banked.
func get_stage_label() -> String:
	var charge := _pump_charge()
	return "" if charge == null else charge.label_for(_charge)


func get_stage_label_scale() -> float:
	var charge := _pump_charge()
	return 1.0 if charge == null else charge.label_scale_for(_charge)


func _pump_charge() -> PumpCharge:
	var stats := get_stats()
	return null if stats == null else stats.pump_charge


func _set_charge(value: int) -> void:
	var most := get_max_pump_charge()
	var clamped := clampi(value, 0, most)
	if clamped == _charge:
		return
	_charge = clamped
	pump_charge_changed.emit(_charge, most)


## The Legendary switched off takes its charge with it at once, so the shotgun is
## back to an ordinary pump the moment the panel says OFF.
func _on_stats_changed() -> void:
	super._on_stats_changed()
	_set_charge(_charge)


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
			# Working a loaded gun with a pump charge active is charging it, not
			# clearing it: the live round stays where it is and nothing is thrown.
			var charging := _state == State.READY and _charging_keeps_round()
			# Asked before the round is spent, because spending it is what would
			# make the breech look empty.
			var ejecting := not charging and _breech_holds_shell()
			if _state == State.READY and _ammo != null and not charging:
				_ammo.discard_rounds(rounds_lost_on_eject)
			_set_state(State.PUMP_BACK)
			pumped_back.emit()
			if ejecting:
				shell_ejected.emit()
		State.PUMP_BACK:
			_set_state(State.READY)
			# One full cycle, one charge - the reload after a shot included - and
			# announced before the stroke so its sound is already tuned to it.
			if _pump_charge() != null:
				_set_charge(_charge + 1)
			pumped_forward.emit()


func _charging_keeps_round() -> bool:
	var charge := _pump_charge()
	return charge != null and charge.charging_keeps_round


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
