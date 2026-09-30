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
## Emitted once per shot, [b]after[/b] [signal fired], while a [ShotExplosion] is
## active - the shot's pellets are explosive. Never per pellet.
signal explosive_shot
## Emitted once per shot, [b]after[/b] [signal fired], when a [BlackPowder] shot
## leaves its smoke, with the cloud it left.
signal smoke_released(cloud: Node2D)
## Emitted as a HELL CHAMBER shot leaves on release, [b]before[/b] [signal fired],
## with the charge it spent, 0..1, and whether that was MAX. A tap sends 0.
signal chamber_released(charge: float, maxed: bool)
## Emitted once as a held HELL CHAMBER charge reaches MAX.
signal chamber_maxed
## Emitted once per MAX HELL CHAMBER shot - never per round - as its secondary
## volley bursts out, with where from and how many rounds it released.
signal chamber_volley(at: Vector2, rounds: int)
## Emitted once per BLOOD REAPER execution - never per round - as its volley leaves
## the man who came apart, with where and how many rounds it released.
signal reaped(at: Vector2, rounds: int)
## Emitted once per ONE BIG SHELL shot, [b]after[/b] [signal fired], with the shell
## that left.
signal big_shell_fired(shell: CannonShell)
## Emitted once per landing of a ONE BIG SHELL shell - see [signal CannonShell.struck].
signal big_shell_struck(at: Vector2, direction: Vector2, centrality: float, killed: bool)

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
## Where, under the node the weapon follows, a shot fired from inside BLACK POWDER's
## smoke is reported as a sound - see [PlayerStealth]. A holder without it is never
## heard.
@export var stealth_receiver_path: NodePath = ^"Stealth"
## Where, under the node the weapon follows, a HELL CHAMBER charge's slowdown of the
## walk is handed - see [WeaponHeft]. A holder without it walks at full speed.
@export var heft_receiver_path: NodePath = ^"WeaponHeft"

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
## The ONE BIG SHELL shell the shot being fired released, if it was one - set by
## [method _spawn_pellets], announced by [method _try_fire].
var _last_shell: CannonShell
## Whether the last cycle was fanned, so the shot that follows is a fanned shot.
var _fanned: bool = false
## Rapid-fire heat, 0..1 - see [FanHammer]. Only ever above 0 while one is active.
var _fan_heat: float = 0.0
var _since_fan_shot: float = 0.0
## Bumped whenever a pending held-trigger shot must be dropped.
var _hammer_serial: int = 0
## Seconds until the next shot leaves BLACK POWDER's smoke. 0 is ready, and it is
## always 0 while no [BlackPowder] is active.
var _powder_cooldown: float = 0.0
## HELL CHAMBER's charge, 0..1 - its own, never the pump's [member _charge]. Only
## ever above 0 while a [HellChamber] is active and the trigger is held on a ready
## gun.
var _chamber: float = 0.0
## Whether the trigger is being held for a HELL CHAMBER charge.
var _chamber_held: bool = false
## Set when the game pauses under a held charge, so a trigger let go of while
## paused - clicking through the developer panel - cancels rather than fires.
var _chamber_interrupted: bool = false
## The walk multiplier last handed to the holder's [WeaponHeft], so it is only
## written when it moves.
var _heft_sent: float = 1.0


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
		# HELL CHAMBER: the press only starts the charge - the release fires.
		if _hell_chamber() != null:
			_press_chamber()
		else:
			_try_fire()
	elif event.is_action_released(&"fire"):
		if _hell_chamber() != null:
			_release_chamber()
	elif event.is_action_pressed(&"pump"):
		if _fan_hammer() != null and Input.is_action_pressed(&"fire"):
			_fan_pump()
		else:
			_fanned = false
			_try_pump()


## Heat drains and the aim loosens back up once the fanning stops. With no
## [FanHammer] active the weapon is put straight back to itself.
func _process(delta: float) -> void:
	if _powder_cooldown > 0.0:
		_powder_cooldown = maxf(_powder_cooldown - delta, 0.0)
	_advance_chamber(delta)
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
	_cancel_chamber()


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
	var chamber := _hell_chamber()
	var chamber_spent := _chamber if chamber != null else 0.0
	var fan := _fan_hammer() if _fanned else null
	_fanned = false
	# Read before the charge is spent, so a charged shot's pellets are counted.
	var recoil_pellets := get_pellet_count()
	# The aim the pellets leave along, before a fanned shot throws it.
	var aim := Vector2.from_angle(global_rotation)
	# The shot's one block and one critical roll - the pellets are armed from them,
	# and a MAX HELL CHAMBER volley re-fires exactly them.
	var shot_stats := _shot_stats()
	var explosive := shot_stats != null and shot_stats.shot_explosion != null
	_last_shell = null
	var critical := _spawn_pellets(shot_stats)
	var shell := _last_shell
	var volley_from := _muzzle.global_position if _muzzle != null else global_position
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
	if chamber != null:
		chamber_released.emit(chamber_spent, chamber.is_max(chamber_spent))
	fired.emit()
	if explosive:
		explosive_shot.emit()
	if shell != null:
		big_shell_fired.emit(shell)
	_kick_holder(aim, recoil_pellets)
	_burn_black_powder(aim)
	if chamber != null and shot_stats != null and chamber.releases_volley(chamber_spent):
		_queue_chamber_volley(shot_stats, critical,
			volley_from + aim * chamber.max_volley_offset, chamber.max_volley_delay)
	_set_charge(0)
	# Spent with the shot, like the pump's charge: the next one starts from nothing.
	_chamber = 0.0
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
##
## [param stats] is the block the shot is armed from - [method _shot_stats] when
## left null. Returns the shot's critical roll, so anything re-firing the same shot
## re-fires it with the same roll.
func _spawn_pellets(stats: WeaponStats = null) -> bool:
	# The charged block when charge is banked, so damage, range and spread all come
	# out of the ordinary stat code with the charge already in them.
	if stats == null:
		stats = _shot_stats()
	# One roll for the whole blast - a critical shotgun shot is every pellet of it.
	var critical := roll_critical()
	if projectile_scene == null or _muzzle == null:
		return critical
	var container := get_tree().current_scene
	if container == null:
		return critical

	# ONE BIG SHELL: the whole shot is one round, straight down the barrel - no cone,
	# however many pellets or however little accuracy the block carries. It is still
	# released through [method _release_pellet] from the same block, so it carries
	# everything the pellets would have.
	var cannon: OneBigShell = null if stats == null else stats.one_big_shell
	if cannon != null and cannon.shell_scene != null:
		_last_shell = _release_pellet(container, stats, critical, _muzzle.global_position,
			global_rotation, false, null, null, cannon) as CannonShell
		return critical

	var pattern: ShotPattern = null if stats == null else stats.shot_pattern
	var half_spread := deg_to_rad(spread_angle_degrees * (1.0 if stats == null else stats.spread_scale())) * 0.5
	for i in _pellets_for(stats):
		var heading := global_rotation + randf_range(-half_spread, half_spread)
		if pattern != null:
			heading = pattern.heading(global_rotation, half_spread)
		_release_pellet(container, stats, critical, _muzzle.global_position, heading)
		# Speed is not set here on purpose: it falls off with distance now, and
		# lives with the rest of the pellet's range profile so one value governs
		# damage, speed, colour, glow and light together.
	return critical


## Arms one round from [param stats] and puts it into [param container] at
## [param at], heading [param angle] - what every round the weapon releases goes
## through, the shot's and a BLOOD REAPER volley's alike, so both carry everything
## the block carries. [param reaped] dresses it as a volley round.
##
## [param shot] is the block of the shot this round belongs to, before any
## BLOOD REAPER scaling - the one an execution by it reproduces. Left null it is
## [param stats] itself, which is what an ordinary shot's round is.
##
## [param volley] dresses it as a round of a MAX HELL CHAMBER volley - on top of
## everything it inherited, never instead of it.
##
## [param cannon] makes it ONE BIG SHELL's shell rather than a pellet: its own
## scene, armed and prepared by every part exactly as a pellet is, then made the
## shell on top - see [method OneBigShell.prepare].
func _release_pellet(container: Node, stats: WeaponStats, critical: bool, at: Vector2,
		angle: float, reaped: bool = false, shot: WeaponStats = null,
		volley: HellChamber = null, cannon: OneBigShell = null) -> Projectile:
	var scene := projectile_scene if cannon == null or cannon.shell_scene == null else cannon.shell_scene
	var pellet: Projectile = scene.instantiate()
	arm_projectile(pellet, critical, stats)
	var pattern: ShotPattern = null if stats == null else stats.shot_pattern
	# DEVIL'S BREATH rides beside any pattern rather than replacing it: the pellets
	# fly however they were going to and explode on top - see [ShotExplosion].
	var explosion: ShotExplosion = null if stats == null else stats.shot_explosion
	# HELL CHAMBER's shockwave rides on the same pellets beside both - see
	# [HellChamber]. Its look only dresses a pellet nothing else has coloured.
	var shockwave: ShotExplosion = null if stats == null else stats.shot_shockwave
	# BLOOD REAPER: the round's kills are executions, reported back here.
	var reaper: BloodReaper = null if stats == null else stats.blood_reaper
	if pattern != null:
		pattern.prepare(pellet)
	if explosion != null:
		explosion.prepare(pellet, pattern != null)
	if shockwave != null:
		shockwave.prepare(pellet, pattern != null or explosion != null)
	if volley != null:
		volley.prepare_volley(pellet, pattern != null or explosion != null)
	if reaper != null:
		# The round carries the shot it left with, so an execution fires that shot's
		# volley - its BLOOD PUMP and HELL CHAMBER charge included - and not whatever
		# the weapon happens to hold by the time the man comes apart.
		pellet.set_execution_handler(_on_execution.bind(stats if shot == null else shot, critical))
		if reaped:
			reaper.prepare(pellet)
	if cannon != null:
		# Last, so it builds on whatever speed the other parts gave the round.
		cannon.prepare(pellet, _pellets_for(stats))
		if pellet is CannonShell:
			(pellet as CannonShell).struck.connect(big_shell_struck.emit)
	container.add_child(pellet)
	pellet.global_position = at
	pellet.global_rotation = angle
	var size := 1.0 if stats == null else stats.size_scale()
	if pattern != null:
		pattern.attach_trail(pellet, container, size)
	if explosion != null:
		explosion.attach_trail(pellet, container, size)
	if shockwave != null:
		shockwave.attach_trail(pellet, container, size)
	if reaper != null and reaped:
		reaper.attach_trail(pellet, container, size)
	if volley != null:
		volley.attach_volley_trail(pellet, container, size)
	if cannon != null:
		cannon.attach_trail(pellet, container, size)
	return pellet


# --- Blood reaper ----------------------------------------------------------------

## A round of this weapon executed somebody - see [BloodReaper]. Reached from inside
## a landing, which can be the physics server's own overlap callback, so the volley
## is released once that is over. [param shot] and [param critical] are the fired
## shot the executing round belonged to - bound onto it by [method _release_pellet].
func _on_execution(at: Vector2, executed: Node, shot: WeaponStats, critical: bool) -> void:
	_reap.call_deferred(at, executed, shot, critical)


## BLOOD REAPER's volley from an execution at [param at]: one round per pellet
## [param shot] fired, armed from that very block - every upgrade, BLOOD PUMP and
## HELL CHAMBER charge and Legendary it left the muzzle with, and its critical roll -
## at the reaper's power. Nothing is re-read from the weapon's idle state, so a
## charge already spent by the time the man comes apart is still in the volley.
## A chained volley reproduces the same shot again, so every link is at the
## reaper's power of the original rather than compounding. Each goes for its own
## enemy, nearest first, never [param executed]; with fewer enemies than rounds the
## rest go round the nearest again, and with none the volley bursts outwards.
func _reap(at: Vector2, executed: Node, shot: WeaponStats, critical: bool) -> void:
	# The Legendary switched off since the shot left ends it here, as it always has;
	# the reaper's own power is read now, so the panel's figure is the one used.
	var live := get_stats()
	var reaper: BloodReaper = null if live == null else live.blood_reaper
	if reaper == null or shot == null or projectile_scene == null or not is_inside_tree():
		return
	var container := get_tree().current_scene
	if container == null:
		return
	var stats := reaper.reaper_stats(shot)
	var rounds := maxi(pellet_count + shot.pellet_bonus(), 1)
	var exclude: Array = []
	if executed != null and is_instance_valid(executed):
		exclude.append(executed)
	var targets := EnemyTargeting.nearest_many(self, at, rounds, reaper.target_radius, exclude)
	var offset := randf() * TAU
	for i in rounds:
		var target: Node2D = null if targets.is_empty() else targets[i % targets.size()]
		var heading := offset + TAU * float(i) / float(rounds)
		if target != null:
			heading = (target.global_position - at).angle()
		var pellet := _release_pellet(container, stats, critical, at, heading, true, shot)
		if target != null:
			pellet.redirect_to(target)
	reaped.emit(at, rounds)


## Pellets one shot really releases: the authored [member pellet_count] plus the
## weapon's pellet count upgrades. Never fewer than one.
func get_pellet_count() -> int:
	return _pellets_for(_shot_stats())


## Whether the next shot leaves as ONE BIG SHELL's single shell rather than
## pellets. [method get_pellet_count] still answers what the block carries - the
## shell's damage and everything else counting pellets reads it.
func fires_one_big_shell() -> bool:
	var stats := get_stats()
	return stats != null and stats.one_big_shell != null and stats.one_big_shell.shell_scene != null


## Pellets a shot armed from [param stats] releases.
func _pellets_for(stats: WeaponStats) -> int:
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
	# HELL CHAMBER folds in on top of whatever else the shot carries, so it enhances
	# the same pellets rather than replacing them.
	if stats.hell_chamber != null and _chamber > 0.0:
		stats = stats.hell_chamber.charged_stats(stats, _chamber)
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


# --- Black powder ----------------------------------------------------------------

## BLACK POWDER, once per shot: a shot fired from hiding is heard, and a shot fired
## once the cooldown has run out leaves the smoke - see [BlackPowder]. The sound is
## reported first, so the shot that makes a fresh cloud is never one fired from it.
## Any other shot is an ordinary shot and leaves the wait as it was.
func _burn_black_powder(aim: Vector2) -> void:
	var powder := _black_powder()
	if powder == null or _target == null:
		return
	var stealth := _target.get_node_or_null(stealth_receiver_path)
	if stealth != null and stealth.has_method(&"report_noise"):
		stealth.call(&"report_noise", _target.global_position, powder.hearing_radius)
	if _powder_cooldown > 0.0:
		return
	var cloud := powder.release(get_tree().current_scene,
		powder.smoke_point(_target.global_position, aim))
	if cloud == null:
		return
	_powder_cooldown = maxf(powder.cooldown, 0.0)
	smoke_released.emit(cloud)


func _black_powder() -> BlackPowder:
	var stats := get_stats()
	return null if stats == null else stats.black_powder


## Seconds until the next shot leaves smoke, 0 when it will - and always 0 while no
## [BlackPowder] is active.
func get_black_powder_cooldown() -> float:
	return _powder_cooldown if _black_powder() != null else 0.0


## The readout in the HUD's corner - see [CooldownReadout]. Empty while no
## [BlackPowder] is active.
func get_cooldown_label() -> String:
	var powder := _black_powder()
	return "" if powder == null else powder.label_for(_powder_cooldown)


## Whether the readout should be drawn as ready.
func is_cooldown_ready() -> bool:
	return _black_powder() != null and _powder_cooldown <= 0.0


# --- Hell chamber ----------------------------------------------------------------

func _hell_chamber() -> HellChamber:
	var stats := get_stats()
	return null if stats == null else stats.hell_chamber


## HELL CHAMBER's charge, 0..1 - always 0 while no [HellChamber] is active.
func get_chamber_charge() -> float:
	return _chamber


## Whether the trigger is held on a HELL CHAMBER charge right now.
func is_chamber_charging() -> bool:
	return _chamber_held and _state == State.READY and _hell_chamber() != null


## Drops the charge without firing. The developer panel's reset - the trigger, if
## still held, builds it again from nothing.
func reset_chamber_charge() -> void:
	_chamber = 0.0
	_send_heft(1.0)


## The trigger pressed with HELL CHAMBER on: nothing fires, the charge starts. A
## press the gun cannot answer - action open, nothing left - clicks exactly as an
## ordinary refused trigger does, and is still held, so closing the action with the
## trigger down starts the charge.
func _press_chamber() -> void:
	_chamber_held = true
	_chamber_interrupted = false
	_chamber = 0.0
	if not is_ready_to_fire():
		dry_fired.emit()


## The trigger let go: the shot leaves at once with whatever charge was built. A
## release with nothing ready to fire only lets the trigger go.
func _release_chamber() -> void:
	if not _chamber_held:
		return
	_chamber_held = false
	_chamber_interrupted = false
	# The press already clicked for an empty gun, so the release does not again.
	if _state == State.READY and has_ammo():
		_try_fire()
	_chamber = 0.0
	_send_heft(1.0)


## Everything a charge holds, let go without a shot: the charge, the held trigger
## and the slowdown. What turning the Legendary off and every interruption does.
func _cancel_chamber() -> void:
	_chamber = 0.0
	_chamber_held = false
	_chamber_interrupted = false
	_send_heft(1.0)


## Builds the charge while the trigger is held on a ready gun, and keeps the
## holder's walk slowed to match. A release the weapon never heard - the trigger
## let go while the game was paused, holstered or in a zone that silences it - is
## noticed here: a paused or silenced one cancels, any other fires, so a shot is
## never left hanging on a trigger nobody is holding.
func _advance_chamber(delta: float) -> void:
	var chamber := _hell_chamber()
	if chamber == null:
		if _chamber_held or _chamber > 0.0 or _heft_sent < 1.0:
			_cancel_chamber()
		return
	if not _chamber_held:
		return
	var silenced := _holster > 0.0 or _fire_blocked_by_zone()
	if not Input.is_action_pressed(&"fire"):
		if _chamber_interrupted or silenced:
			_cancel_chamber()
		else:
			_release_chamber()
		return
	_chamber_interrupted = false
	if silenced:
		_chamber = 0.0
	elif _state == State.READY and has_ammo():
		var was_max := chamber.is_max(_chamber)
		_chamber = minf(_chamber + chamber.charge_step(delta), 1.0)
		if not was_max and chamber.is_max(_chamber):
			chamber_maxed.emit()
	_send_heft(chamber.move_speed_multiplier(_chamber))


## Schedules the MAX volley of the shot armed from [param shot] for
## [param delay] seconds from now - paused with the tree, like the fan's hammer.
func _queue_chamber_volley(shot: WeaponStats, critical: bool, at: Vector2, delay: float) -> void:
	if delay <= 0.0:
		_chamber_volley(shot, critical, at)
		return
	get_tree().create_timer(delay, false).timeout.connect(
		_chamber_volley.bind(shot, critical, at))


## HELL CHAMBER's MAX volley from [param at]: the shot armed from [param shot] -
## the very block the MAX shot left with, and its [param critical] roll - released
## again as a ring of one round per pellet that shot fired, at the chamber's volley
## power. Every round goes through [method _release_pellet] exactly as the shot's
## own did, so every upgrade, charge and Legendary the shot carried rides the volley
## with nothing here naming any of them. The ring's headings are the one thing of
## the shot's own not reused; an active [ShotPattern] still shapes each around its
## slot, as it shapes the shot's around the aim.
func _chamber_volley(shot: WeaponStats, critical: bool, at: Vector2) -> void:
	# Switched off since the shot left ends it here, as a BLOOD REAPER volley does;
	# the power is read now, so the Inspector's figure is the one used.
	var chamber := _hell_chamber()
	if chamber == null or shot == null or projectile_scene == null or not is_inside_tree():
		return
	var container := get_tree().current_scene
	if container == null:
		return
	var stats := chamber.volley_stats(shot)
	var pattern: ShotPattern = stats.shot_pattern
	var rounds := _pellets_for(shot)
	var jitter := deg_to_rad(maxf(chamber.max_volley_jitter_degrees, 0.0))
	var offset := randf() * TAU
	for i in rounds:
		var slot := offset + TAU * float(i) / float(rounds)
		var heading := slot + randf_range(-jitter, jitter)
		if pattern != null:
			heading = pattern.heading(slot, jitter)
		_release_pellet(container, stats, critical, at, heading, false, shot, chamber)
	chamber.release_ring(container, at, stats.power_scale)
	chamber_volley.emit(at, rounds)


## Hands the holder's [WeaponHeft] the walk multiplier, only when it moves.
func _send_heft(multiplier: float) -> void:
	if is_equal_approx(multiplier, _heft_sent):
		return
	_heft_sent = multiplier
	if _target == null:
		return
	var receiver := _target.get_node_or_null(heft_receiver_path)
	if receiver != null and receiver.has_method(&"set_heft"):
		receiver.call(&"set_heft", self, multiplier)


## A charge held as the game pauses is marked, so a trigger released while paused
## is not taken for a shot when play resumes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _chamber_held:
		_chamber_interrupted = true
	elif what == NOTIFICATION_EXIT_TREE:
		_cancel_chamber()


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
	# With HELL CHAMBER on the held trigger charges the closed action instead, and
	# letting go fires it - the fan still works the whole cycle in one press.
	if _hell_chamber() != null:
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
## A HELL CHAMBER charge being held is shown in preference to banked pump charge.
func get_charge_ratio() -> float:
	if _chamber > 0.0:
		return _chamber
	var most := get_max_pump_charge()
	return 0.0 if most <= 0 else clampf(float(_charge) / float(most), 0.0, 1.0)


## The readout over the ammunition - see [SpinMultiplier]. Empty with nothing banked.
func get_stage_label() -> String:
	var chamber := _hell_chamber()
	if chamber != null and _chamber > 0.0:
		return chamber.label_for(_chamber)
	var charge := _pump_charge()
	return "" if charge == null else charge.label_for(_charge)


func get_stage_label_scale() -> float:
	var chamber := _hell_chamber()
	if chamber != null and _chamber > 0.0:
		return chamber.label_scale_for(_chamber)
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
	# BLACK POWDER switched off takes its wait and its smoke with it, so nobody is
	# left hiding in a cloud the Legendary no longer makes.
	if _black_powder() == null:
		_powder_cooldown = 0.0
		if is_inside_tree():
			BlackPowderSmoke.dissolve_all(get_tree())
	# HELL CHAMBER switched off drops the charge, the slowdown and the held trigger
	# at once, so the very next press is an ordinary shot.
	if _hell_chamber() == null:
		_cancel_chamber()


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
	# A HELL CHAMBER charge only lives on a closed, loaded action: working the pump
	# or firing lets it go. The trigger stays held, so it builds again from nothing
	# once the action is closed.
	if _state != State.READY:
		_chamber = 0.0
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
