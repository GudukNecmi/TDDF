class_name ShotgunFeedback
extends Node
## Sound and camera reaction for the shotgun.
##
## The weapon itself only announces what happened - `fired`, `pumped_back`,
## `shell_ejected`, `pumped_forward` - and everything cosmetic lives here. That keeps the fire
## and pump state machine pure gameplay, and lets this whole layer be muted by
## disabling one node.
##
## Which signal a piece of feedback hangs off is not arbitrary, it is what the
## weapon is doing:
##
##   * [b]Firing[/b] is the blast, the muzzle light, the screen flash and the
##     kick. No shell - nothing has been worked out of the breech yet.
##   * [b]A trigger pull that fires nothing[/b] is a click and the faintest tick
##     of the camera, whatever the reason the shot was refused.
##   * [b]Racking the action open[/b] is its sound and its camera shove, and it
##     happens on every valid press because the mechanism is worked either way.
##   * [b]A shell leaving[/b] is the one on the ground, whether the round that
##     left was a fired case or a live one being ejected. One shell per press,
##     because one round was in there - and none at all when the breech was
##     empty, which is the whole reason it is a separate announcement.
##   * [b]Driving it shut[/b] is the reload, and carries only its sound and its
##     camera shove.
##
## Camera effects are requested from the shared [CameraController], which
## applies them on top of its own resting transform and always drives them back
## to it. This node never writes to the camera itself, so however fast the
## signals arrive the camera cannot be left rotated, zoomed or offset.
##
## Rotation is signed the same way as [member Node2D.rotation]: positive turns
## the camera clockwise ("right"), negative turns it anticlockwise ("left").

## Node whose shotgun signals are listened to. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the sound effects are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Camera feedback")
## Master strength for every camera effect below - the shot's shake, turn and
## zoom, and both halves of the pump.
##
## It multiplies the *amplitudes* only, never the durations, so turning it up
## makes the weapon hit harder rather than making the camera sluggish. Each
## individual value underneath is still its own inspector field, so this is the
## one dial for "more of all of it" and those are the dials for shaping the feel.
@export var camera_feedback_scale: float = 1.0
## Layer on [CameraController] the weapon writes to.
##
## Deliberately not the one [PlayerDamageFeedback] uses: channels are summed and
## only ever restart themselves, so firing while the player is being hit adds the
## shot's punch to the hit's zoom instead of wiping it out.
@export var camera_channel: StringName = &"weapon"
## How loudly the weapon speaks against the other channels. Below the damage
## reaction's, so being hit stays the louder of the two - see
## [member CameraController.low_priority_scale].
@export var camera_priority: int = 0

@export_group("Fire")
@export var fire_sound: StringName = &"blast"
## Peak shake offset in pixels. The controller's falloff makes this decay
## sharply, so it reads as a single hard knock rather than a wobble.
@export var fire_shake_strength: float = 24.0
## Kept very short on purpose - the camera must snap back, not drift.
@export var fire_shake_duration: float = 0.09
## Optional zoom punch on firing, as a fraction. 0 disables it.
@export var fire_zoom: float = -0.06
@export var fire_zoom_out_time: float = 0.03
@export var fire_zoom_back_time: float = 0.12
## Turn thrown into the shot, in degrees. Positive is clockwise.
##
## Firing carried no rotation of its own before, so this ships at 0 and the shot
## is exactly the shake-and-zoom it always was. It is here because the camera can
## take a turn on the shot as readily as on the pump, and this is the field to
## dial one in with.
@export var fire_rotation_degrees: float = 0.0
@export var fire_rotation_out_time: float = 0.04
@export var fire_rotation_return_time: float = 0.14

@export_group("Muzzle")
## Spark burst played at the muzzle on every shot.
##
## The scene holds the burst for a weapon at exactly the reference stats below,
## and is deliberately restrained: it is what a shotgun with no upgrades on it
## looks like, and everything above that is arrived at by scaling rather than by
## authoring a second scene.
@export var muzzle_flash_scene: PackedScene
## Marker the burst is placed and aimed from. Inside the weapon's mirrored rig, so
## it tracks the barrel as drawn at any aim.
@export var muzzle_path: NodePath = ^"../MuzzleRig/Muzzle"
## Light punched at the muzzle on every shot, which is what makes a blast throw
## real light across a dark arena rather than only being a bright sprite.
## Optional - without one the muzzle simply stops lighting the room.
@export var muzzle_light_path: NodePath = ^"../MuzzleRig/MuzzleLight"
## Energy the muzzle light snaps to when fired. It is driven straight back to 0,
## so the light only exists for the instant of the shot.
@export var muzzle_light_energy: float = 4.2
## How long that light takes to die away. Very short - a blast, not a lamp.
@export var muzzle_light_time: float = 0.11

@export_group("Muzzle scaling")
## The pellet's stat sheet, read for its damage. It is the *same resource* the
## pellets themselves use, so an upgrade that makes the shotgun hit harder makes
## the muzzle burst bigger in the same edit, with nothing here to keep in step.
## Unresolved, damage simply stops influencing the burst.
@export var projectile_profile: ProjectileProfile
## The stats the burst in [member muzzle_flash_scene] was authored for. Scaling is
## measured against these, so a weapon sitting at exactly these numbers produces
## exactly the authored burst and only an upgrade ever changes it.
@export var reference_damage: float = 88.0
@export var reference_spread_degrees: float = 12.0
@export var reference_pellet_count: int = 6
## How hard each stat pushes the burst, as an exponent on its own ratio. 0 makes
## that stat irrelevant, 1 makes the burst exactly proportional to it, and
## between the two softens the response - which is usually what a doubled stat
## wants, since twice the damage should not mean twice the fireball.
@export_range(0.0, 2.0) var damage_influence: float = 0.55
@export_range(0.0, 2.0) var spread_influence: float = 1.0
@export_range(0.0, 2.0) var pellet_count_influence: float = 0.85
## Ceilings, so a very late-game weapon still fires a burst rather than filling
## the screen. Every scaled value is clamped to its authored value times this.
@export var max_scale_factor: float = 4.0

@export_group("Screen flash")
## Fires the shared full-screen flash on every shot. This is the whole room being
## lit by the blast, as opposed to the muzzle light, which lights the world
## geometry. Turn it off to keep the muzzle light without the screen flash.
##
## The flash itself is found by group, so nothing has to be wired up.
@export var screen_flash_enabled: bool = true
@export var screen_flash_colour := Color(1.0, 0.96, 0.78)
## Alpha at its brightest. Bright, but on screen for only a frame or two.
@export_range(0.0, 1.0) var screen_flash_peak: float = 0.5
## Held at full strength for this long. 0 gives the sharpest, most blast-like
## result and is the default.
@export var screen_flash_hold: float = 0.0
@export var screen_flash_fade: float = 0.07

@export_group("Muzzle blast")
## The blast sprite shown at the muzzle on every shot: the flash of burning
## powder leaving the barrel.
##
## It is a child of the weapon rather than something spawned into the world, so it
## rides the muzzle's own transform and is always exactly on the barrel and
## exactly along the aim, however fast the player is turning. Optional - without
## one the weapon simply keeps the particle burst and the light.
##
## It hangs off the muzzle marker, and the marker lives inside the weapon's
## [code]MuzzleRig[/code] - a pivot the weapon's [HeldItemFlip] mirrors alongside
## the gun's artwork. That is what makes the blast follow the barrel.
##
## Aiming left turns the weapon past vertical, and the art is mirrored on Y to
## keep the gun upright. Combined with the turn, that is a *horizontal* mirror of
## the whole weapon in world space - so the drawn barrel ends up somewhere a
## marker outside the mirroring does not follow it to, and the blast used to hang
## 17 pixels off a gun only 36 pixels tall, pointing across it. Mirroring the rig
## puts the marker back on the barrel and mirrors the burst the same way the gun
## is mirrored, so blast and muzzle read as one drawing at every aim.
@export var blast_path: NodePath = ^"../MuzzleRig/Muzzle/Blast"
## How long the blast is held at full strength before it starts to go.
@export var blast_hold: float = 0.22
## How long it takes to fade out afterwards. The blast's whole life on screen is
## this plus [member blast_hold], and it must always end - a shot may never leave
## anything behind at the muzzle.
@export var blast_fade: float = 0.07
## Where the blast sits, relative to wherever its sprite was placed in the scene.
## Along the barrel is +X, so raising this pushes the burst further out in front
## of the muzzle whatever direction the weapon is pointing.
@export var blast_offset := Vector2.ZERO
## Size the blast starts at, as a fraction of the sprite's authored scale, and the
## size it swells to as it dies. Growing as it fades is what makes it read as
## expanding gas rather than a picture being turned down.
@export var blast_start_scale: float = 0.82
@export var blast_end_scale: float = 1.25

@export_group("Recoil")
## Art node kicked backwards on firing. Only the artwork moves - the muzzle and
## the weapon body itself stay put, so pellet origin and aim are untouched.
@export var art_path: NodePath = ^"../Art"
## Kick distance in the art's own local pixels, along -X, which is straight back
## down the barrel whatever the weapon's rotation is.
@export var recoil_distance: float = 165.0
## How long the art takes to travel most of the way home. The quick half of the
## return, so the weapon is seen to be shoved back and immediately fight it.
@export var recoil_return_time: float = 0.11
## How much of the kick the art is still carrying when that quick return ends, as
## a fraction. The remainder is walked off slowly by the settle below.
##
## Splitting the return in two is what makes a bigger kick still feel heavy: one
## eased slide from the full distance reads as a spring however far it travels,
## while a hard snap most of the way followed by a slow last inch reads as
## something with mass being brought back under control.
@export_range(0.0, 1.0) var recoil_settle_fraction: float = 0.34
## How long that last part takes. Longer than the snap - it is the weight
## settling, not the recoil itself.
@export var recoil_settle_time: float = 0.19

@export_group("Dry fire")
## Click of a trigger pull that produced no shot - an open action, a case already
## fired, or nothing left to fire. The weapon does not say which, because the
## player hears the same click for all of them.
@export var dry_fire_sound: StringName = &"dry_fire"
## Peak shake offset of the click, in pixels.
##
## [b]Deliberately tiny.[/b] A shot shakes the camera by
## [member fire_shake_strength] - two dozen pixels of hard knock - and this is a
## hammer falling on nothing, so it is a tick at the edge of noticing rather than
## a hit. It is meant to be felt only as confirmation that the trigger was
## actually pulled; if it can be seen as a shake, it is too strong.
@export var dry_fire_shake_strength: float = 1.3
## How long that tick lasts. Shorter than every other shake here, because there
## is no weight behind it to carry on.
@export var dry_fire_shake_duration: float = 0.06

@export_group("Casings")
## Shell thrown out when the action is worked.
@export var casing_scene: PackedScene
## How many shells one pump ejects. One, because one round was in the breech.
@export var casing_count: int = 1
## How far around the weapon the shells first appear.
@export var casing_spread: float = 10.0

@export_group("Pump back (first R)")
@export var pump_back_sound: StringName = &"pump_back"
## Small turn to the right as the pump is racked back.
@export var pump_back_degrees: float = 4.0
@export var pump_back_out_time: float = 0.05
@export var pump_back_return_time: float = 0.14
@export var pump_back_zoom: float = 0.02
@export var pump_back_zoom_out_time: float = 0.05
@export var pump_back_zoom_back_time: float = 0.16
## Shake on racking the pump back. 0 leaves the rack a turn and a zoom, which is
## what it always was.
@export var pump_back_shake_strength: float = 0.0
@export var pump_back_shake_duration: float = 0.08

@export_group("Pump forward (second R)")
@export var pump_forward_sound: StringName = &"pump_forward"
## Turn to the left as the pump is driven forward.
@export var pump_forward_degrees: float = -8.0
@export var pump_forward_out_time: float = 0.05
## Partway back towards level, so the return reads as two distinct motions -
## the shove, then the settle - instead of one soft glide.
@export var pump_forward_settle_degrees: float = -4.0
@export var pump_forward_settle_time: float = 0.07
@export var pump_forward_return_time: float = 0.16
@export var pump_forward_zoom: float = 0.05
@export var pump_forward_zoom_out_time: float = 0.05
@export var pump_forward_zoom_back_time: float = 0.18
## Shake on driving the pump home. 0 leaves the shove a turn and a zoom, which is
## what it always was.
@export var pump_forward_shake_strength: float = 0.0
@export var pump_forward_shake_duration: float = 0.1

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _muzzle: Node2D = get_node_or_null(muzzle_path) as Node2D
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _muzzle_light: PointLight2D = get_node_or_null(muzzle_light_path) as PointLight2D
@onready var _blast: CanvasItem = get_node_or_null(blast_path) as CanvasItem

var _screen_flash: ScreenFlash
var _camera: CameraController
var _art_rest_position := Vector2.ZERO
var _blast_rest_scale := Vector2.ONE
var _blast_rest_position := Vector2.ZERO
var _recoil_tween: Tween
var _muzzle_light_tween: Tween
var _blast_tween: Tween


func _ready() -> void:
	# Captured once. Every recoil is measured from and returned to this, so a
	# burst of shots can never walk the artwork away from where it belongs.
	if _art != null:
		_art_rest_position = _art.position

	# The blast is authored at the size it should be at its peak and starts the
	# game hidden, so it exists only for the instants it is fired.
	if _blast != null:
		var blast_node := _blast as Node2D
		if blast_node != null:
			_blast_rest_scale = blast_node.scale
			# The authored position is the base and the exported offset is measured
			# from it, so nudging the burst in the inspector never loses where the
			# sprite was originally placed on the barrel.
			_blast_rest_position = blast_node.position
		_blast.visible = false
		_blast.modulate.a = 0.0

	if _source == null:
		return
	_listen(&"fired", _on_fired)
	_listen(&"dry_fired", _on_dry_fired)
	_listen(&"pumped_back", _on_pumped_back)
	_listen(&"shell_ejected", _on_shell_ejected)
	_listen(&"pumped_forward", _on_pumped_forward)


## The shot itself: blast, light, flash and kick. Deliberately no shell - the
## empty case is still in the breech until the action is worked, and it is
## [method _on_shell_ejected] that throws it.
func _on_fired() -> void:
	_play(fire_sound)
	_flash_blast()
	_spawn_muzzle_flash()
	_punch_muzzle_light()
	_punch_screen_flash()
	_kick_recoil()

	var camera := _get_camera()
	if camera == null:
		return
	camera.shake(_scaled(fire_shake_strength), fire_shake_duration)
	if not is_zero_approx(fire_zoom):
		camera.zoom_kick(
			_scaled(fire_zoom), fire_zoom_out_time, fire_zoom_back_time,
			camera_channel, camera_priority)
	if not is_zero_approx(fire_rotation_degrees):
		camera.rotation_kick(
			_scaled(fire_rotation_degrees), fire_rotation_out_time,
			fire_rotation_return_time, camera_channel, camera_priority)


## A trigger pull that produced nothing: the click, and the faintest tick of the
## camera under it.
##
## It is the only piece of feedback here that answers an input rather than an
## event - the weapon did nothing, and this is what tells the player it heard
## them anyway. Deliberately nothing else: no flash, no light, no recoil, and
## above all no shell, because nothing left the gun. It never asks *why* the shot
## was refused, so an open action, a spent case and an empty magazine all sound
## the same, which is what they would.
func _on_dry_fired() -> void:
	_play(dry_fire_sound)

	if dry_fire_shake_strength <= 0.0:
		return
	var camera := _get_camera()
	if camera == null:
		return
	camera.shake(_scaled(dry_fire_shake_strength), dry_fire_shake_duration)


## One place [member camera_feedback_scale] is applied, so no camera value can be
## left out of it and none can be scaled twice.
func _scaled(amount: float) -> float:
	return amount * camera_feedback_scale


## The burst and the shells are added to the running scene rather than to the
## weapon. The shotgun sits at 0.2 scale and turns constantly, so parenting to it
## would shrink them and drag the shells along after they had been thrown.
##
## The blast is the deliberate exception - it *must* stay on the barrel for the
## frames it exists, so it is a child and is shown rather than spawned.
func _spawn_muzzle_flash() -> void:
	var container := _effect_container()
	if muzzle_flash_scene == null or _muzzle == null or container == null:
		return

	var flash := muzzle_flash_scene.instantiate() as Node2D
	if flash == null:
		return

	container.add_child(flash)
	flash.global_position = _muzzle.global_position
	# Aimed down the barrel, so the spray always leaves the way the shot went.
	flash.global_rotation = _muzzle.global_rotation
	flash.reset_physics_interpolation()

	# Scaled before emission begins, because a one-shot burst reads its counts and
	# sizes when it starts - changing them afterwards would only affect the next
	# shot, which is not the one being fired.
	_scale_burst(flash as CPUParticles2D)

	# Started only now that it is standing on the muzzle. These bursts emit in
	# global particle space, so whatever transform the node has the instant
	# emission begins is where the particles are stamped - starting on ready
	# left every flash at the world origin.
	if flash.has_method(&"play"):
		flash.play()
	elif flash is CPUParticles2D:
		(flash as CPUParticles2D).emitting = true


## Grows the burst to match the weapon that fired it.
##
## The three stats do three different jobs and are kept apart on purpose: damage
## drives how *big and fast* the sparks are, spread drives how *wide* they go,
## and the pellet count drives how *many* there are. That mapping is the whole
## point - it is what makes an upgraded shotgun look upgraded without a single new
## particle scene, and what stops a future upgrade needing this rewritten. Adding
## a fourth stat later is another ratio and another multiply.
##
## Everything is measured as a ratio against the reference stats and applied to
## the values the burst was authored with, so a weapon at the reference numbers
## comes out untouched and there is no second copy of the base burst here.
func _scale_burst(flash: CPUParticles2D) -> void:
	if flash == null:
		return

	var damage := _shaped_ratio(_current_damage(), reference_damage, damage_influence)
	var spread := _shaped_ratio(
		_current_spread_degrees(), reference_spread_degrees, spread_influence)
	var pellets := _shaped_ratio(
		float(_current_pellet_count()), float(reference_pellet_count), pellet_count_influence)

	flash.amount = maxi(int(round(float(flash.amount) * pellets)), 1)

	flash.scale_amount_min *= damage
	flash.scale_amount_max *= damage
	flash.initial_velocity_min *= damage
	flash.initial_velocity_max *= damage

	# Clamped rather than scaled past a half turn: a cone wider than this stops
	# reading as a muzzle blast and starts reading as an explosion.
	flash.spread = minf(flash.spread * spread, 180.0)


## Damage at the muzzle, straight off the pellet's own profile. The reference
## value is returned when there is no profile, so an unwired weapon simply fires
## its authored burst.
func _current_damage() -> float:
	if projectile_profile == null:
		return reference_damage
	return projectile_profile.damage_near


## Read off the weapon by property name rather than by a typed reference, so the
## feedback keeps working against anything that announces the same signals - and
## a weapon that does not carry the stat falls back to the reference rather than
## erroring.
func _current_spread_degrees() -> float:
	if _source != null and "spread_angle_degrees" in _source:
		return _source.get(&"spread_angle_degrees")
	return reference_spread_degrees


func _current_pellet_count() -> int:
	if _source != null and "pellet_count" in _source:
		return _source.get(&"pellet_count")
	return reference_pellet_count


## One stat's contribution: its ratio against the reference, bent by the
## influence exponent and capped. An influence of 0 always returns 1, which is
## how a stat is switched off without removing it.
func _shaped_ratio(current: float, reference: float, influence: float) -> float:
	if influence <= 0.0 or reference <= 0.0 or current <= 0.0:
		return 1.0
	var ratio := pow(current / reference, influence)
	return clampf(ratio, 1.0 / maxf(max_scale_factor, 1.0), maxf(max_scale_factor, 1.0))


## Snapped to full energy and eased straight back to nothing. Snapping rather
## than tweening the rise is what makes it read as a blast; the light is always
## driven back to 0, so however fast the shots come it cannot be left glowing.
func _punch_muzzle_light() -> void:
	if _muzzle_light == null:
		return

	if _muzzle_light_tween != null and _muzzle_light_tween.is_running():
		_muzzle_light_tween.kill()

	_muzzle_light.energy = muzzle_light_energy
	_muzzle_light.enabled = true
	_muzzle_light_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_muzzle_light_tween.tween_property(_muzzle_light, "energy", 0.0, muzzle_light_time)


func _punch_screen_flash() -> void:
	if not screen_flash_enabled:
		return
	var flash := _get_screen_flash()
	if flash == null:
		return
	flash.flash(screen_flash_colour, screen_flash_peak, screen_flash_hold, screen_flash_fade)


## Looked up lazily and re-looked-up if it goes away, exactly like the camera -
## the HUD that owns it may enter the tree after the weapon does.
func _get_screen_flash() -> ScreenFlash:
	if _screen_flash == null or not is_instance_valid(_screen_flash):
		_screen_flash = ScreenFlash.get_active(self)
	return _screen_flash


func _spawn_casings() -> void:
	var container := _effect_container()
	var origin := _source as Node2D
	if casing_scene == null or origin == null or container == null:
		return

	var facing := Vector2.RIGHT.rotated(origin.global_rotation)
	for i in maxi(casing_count, 0):
		var casing := casing_scene.instantiate() as Node2D
		if casing == null:
			continue

		container.add_child(casing)
		casing.global_position = origin.global_position + Vector2(
			randf_range(-casing_spread, casing_spread),
			randf_range(-casing_spread, casing_spread)
		)
		casing.reset_physics_interpolation()
		if casing.has_method(&"launch"):
			casing.launch(facing)


## Snapped straight back, then brought home in two stages. Snapping rather than
## tweening the outward half is what makes it read as a jolt instead of a nudge.
##
## The two stages are the weight. The first covers most of the distance quickly -
## the weapon fighting the shove - and the second walks the last fraction off
## slowly, so the gun is visibly still recovering after the bang has finished. One
## eased slide would read as a spring however far it was thrown.
##
## The kick is a translation of the art node only: it never touches `rotation`,
## never touches the weapon's follow offset, and always retargets the rest
## position captured on ready, so rapid fire cannot stack it or leave the art
## displaced. Because -X is the art's own local axis it points back down the
## barrel at any weapon rotation.
func _kick_recoil() -> void:
	if _art == null:
		return

	if _recoil_tween != null and _recoil_tween.is_running():
		_recoil_tween.kill()

	var kick := Vector2(-recoil_distance, 0.0)
	_art.position = _art_rest_position + kick

	_recoil_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(
		_art, "position",
		_art_rest_position + kick * clampf(recoil_settle_fraction, 0.0, 1.0),
		maxf(recoil_return_time, 0.0001))
	# The last stage always lands exactly on the rest position, so however the
	# fractions above are tuned the artwork cannot be left displaced.
	_recoil_tween.tween_property(
		_art, "position", _art_rest_position, maxf(recoil_settle_time, 0.0001)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The blast at the muzzle: on at once, off almost as fast, and swelling as it
## goes so it reads as gas leaving the barrel.
##
## Shown rather than spawned. It is a child of the muzzle, so it needs no position
## or rotation of its own to be given - it is already on the barrel and already
## along the aim, and it stays there for the frames it exists even if the player
## is turning hard. It is always driven back to invisible, so however fast the
## shots come there is nothing left behind.
func _flash_blast() -> void:
	if _blast == null:
		return

	if _blast_tween != null and _blast_tween.is_running():
		_blast_tween.kill()

	var blast_node := _blast as Node2D
	if blast_node != null:
		blast_node.scale = _blast_rest_scale * blast_start_scale
		blast_node.position = _blast_rest_position + blast_offset
	_blast.modulate.a = 1.0
	_blast.visible = true

	_blast_tween = create_tween().set_parallel(true)
	var fade := maxf(blast_fade, 0.0001)
	_blast_tween.tween_property(_blast, "modulate:a", 0.0, fade) \
		.set_delay(maxf(blast_hold, 0.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if blast_node != null:
		_blast_tween.tween_property(
			blast_node, "scale", _blast_rest_scale * blast_end_scale,
			maxf(blast_hold, 0.0) + fade
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blast_tween.chain().tween_callback(_hide_blast)


## Hidden outright at the end rather than only left transparent, so a weapon
## sitting idle is not drawing a fully faded sprite every frame.
func _hide_blast() -> void:
	if _blast == null:
		return
	_blast.visible = false
	_blast.modulate.a = 0.0


func _effect_container() -> Node:
	return get_tree().current_scene


## Racking the action open: its sound and its camera shove. The mechanism is
## worked whether or not there was anything in the breech, so this half is
## unconditional and the shell is not thrown here - see [method _on_shell_ejected].
func _on_pumped_back() -> void:
	_play(pump_back_sound)

	var camera := _get_camera()
	if camera == null:
		return
	camera.rotation_kick(
		_scaled(pump_back_degrees), pump_back_out_time, pump_back_return_time,
		camera_channel, camera_priority)
	if not is_zero_approx(pump_back_zoom):
		camera.zoom_kick(
			_scaled(pump_back_zoom), pump_back_zoom_out_time, pump_back_zoom_back_time,
			camera_channel, camera_priority)
	if pump_back_shake_strength > 0.0:
		camera.shake(_scaled(pump_back_shake_strength), pump_back_shake_duration)


## A shell actually leaving the breech is what puts one on the ground, whether
## the round that left was a fired case or a live one thrown away. The weapon
## decides whether there was one - a stroke worked on an empty breech never
## reaches this - so nothing here has to know how much ammunition is left.
func _on_shell_ejected() -> void:
	_spawn_casings()


## Out to the full angle, back part of the way, then exactly level again - the
## last step is what guarantees the camera ends on its default rotation.
func _on_pumped_forward() -> void:
	_play(pump_forward_sound)

	var camera := _get_camera()
	if camera == null:
		return
	camera.rotation_impulse([
		Vector2(_scaled(pump_forward_degrees), pump_forward_out_time),
		Vector2(_scaled(pump_forward_settle_degrees), pump_forward_settle_time),
		Vector2(0.0, pump_forward_return_time),
	], camera_channel, camera_priority)
	if not is_zero_approx(pump_forward_zoom):
		camera.zoom_kick(
			_scaled(pump_forward_zoom), pump_forward_zoom_out_time,
			pump_forward_zoom_back_time, camera_channel, camera_priority
		)
	if pump_forward_shake_strength > 0.0:
		camera.shake(_scaled(pump_forward_shake_strength), pump_forward_shake_duration)


func _play(sound_name: StringName) -> void:
	if _sounds != null:
		_sounds.play(sound_name)


## Connected by name rather than directly, so swapping the source node for
## anything that emits the same signals just works, and a source that emits
## none of them is simply silent instead of an error.
func _listen(signal_name: StringName, handler: Callable) -> void:
	if not _source.has_signal(signal_name):
		return
	if _source.is_connected(signal_name, handler):
		return
	_source.connect(signal_name, handler)


## Looked up lazily and re-looked-up if the camera goes away, since the camera
## lives on the player and may enter the tree after this node does.
func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
