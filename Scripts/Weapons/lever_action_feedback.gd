class_name LeverActionFeedback
extends Node
## Sound, camera, muzzle blast and dropped rounds for the lever action rifle.
##
## Built the same way [ShotgunFeedback] is, and for the same reason: the rifle
## only announces what happened - `fired`, `dry_fired`, `lever_opened`,
## `lever_closed`, `reload_progress` - and everything cosmetic lives here, so the
## weapon's state machine stays pure gameplay and this whole layer can be muted by
## disabling one node.
##
## Which signal a piece of feedback hangs off is what the rifle is doing:
##
##   * [b]Firing[/b] is the blast at the muzzle, its light and the shot's kick.
##     No round on the ground - a fired case is not ejected by this rifle, the
##     lever is.
##   * [b]Winding the reload gesture[/b] is the tension zoom, and only over the
##     last stretch of it. See [member zoom_start_degrees].
##   * [b]The lever dropping[/b] is its sound and the live rounds hitting the
##     ground - as many as the rifle says were in it.
##   * [b]The lever coming home[/b] is the reload sound and a small shove, the
##     rifle's answer to the shotgun's pump.
##
## Camera effects are requested from the shared [CameraController] on their own
## channel, exactly as the shotgun's are, so the rifle and a hit reaction arriving
## together are summed rather than one wiping the other out. This node never
## writes to the camera itself, so however fast the signals arrive the camera
## cannot be left shaken or zoomed.

## Node whose rifle signals are listened to. Defaults to this node's parent.
@export var source_path: NodePath = ^".."
## Bank the sound effects are played through.
@export var sound_bank_path: NodePath = ^"../Sounds"

@export_group("Camera")
## Master strength for every camera effect below. It multiplies amplitudes only,
## never durations, so turning it up makes the rifle hit harder rather than making
## the camera sluggish.
@export var camera_feedback_scale: float = 1.0
## Layer on [CameraController] the rifle writes to. Deliberately the same
## [code]weapon[/code] channel the shotgun uses - only one weapon is ever in the
## player's hands, so they can never fight, and both are quieter than the damage
## reaction for the same reason.
@export var camera_channel: StringName = &"weapon"
## How loudly the weapon speaks against the other channels.
@export var camera_priority: int = 0

@export_group("Fire")
@export var fire_sound: StringName = &"blast"
## How much louder the shot is played than the rest of the rifle's sounds, in
## decibels. The report should carry over everything else the weapon does - and
## over the arena around it, which is why it sits well above the lever's own
## noises rather than merely level with them.
@export var fire_volume_db: float = 15.0
## Peak shake offset of a shot, in pixels.
##
## Set against the shot the player already knows: this is three quarters of the
## shotgun's blast, so the rifle reads as a sharper, lighter weapon that still
## clearly hits. It is one number and it is tuned here - nothing reaches into the
## shotgun to derive it, so retuning one weapon never silently moves the other.
@export var fire_shake_strength: float = 18.0
## Kept very short, so the camera snaps back rather than drifting.
@export var fire_shake_duration: float = 0.07
## Small turn as the shot leaves, in degrees. Positive turns the camera clockwise.
@export var fire_rotation_degrees: float = 0.9
@export var fire_rotation_out_time: float = 0.04
@export var fire_rotation_return_time: float = 0.12
## Zoom punch on the shot, as a fraction. Positive pushes in.
@export var fire_zoom: float = 0.018
@export var fire_zoom_out_time: float = 0.04
@export var fire_zoom_back_time: float = 0.14

@export_group("Fire pitch")
## Pitch every shot starts at. 1 is the sound as recorded.
##
## [b]Each shot slides, and always the same way.[/b] The report begins at this
## pitch and falls across [member fire_pitch_slide_time], which is the report
## decaying rather than a pitch being picked - so a burst of shots never sounds
## like a machine repeating one sample, and never jumps.
@export var fire_pitch_base: float = 1.0
## Smallest and largest amount one shot falls by over the slide.
##
## The amount is drawn fresh for every shot inside this range, which is what stops
## two shots sounding identical - so the width of the range is how *varied* the
## weapon sounds and the size of the numbers is how far each report sags. Wide
## enough here that the drop is plainly audible on a single shot; pushed much
## further the rifle starts to warble rather than crack.
@export var fire_pitch_fall_min: float = 0.16
@export var fire_pitch_fall_max: float = 0.38
## How long the fall takes, in seconds. Matched to the length of the report, so
## the pitch is still moving for as long as the sound is audible.
@export var fire_pitch_slide_time: float = 1.0

@export_group("Dry fire")
## Click of a trigger pull that produced nothing - the lever down, or an empty
## magazine. The rifle does not say which, because the player hears the same click
## for both.
@export var dry_fire_sound: StringName = &"dry_fire"
@export var dry_fire_shake_strength: float = 1.3
@export var dry_fire_shake_duration: float = 0.06

@export_group("Muzzle blast")
## The burst sprite sitting on the barrel. A child of the muzzle rather than
## something spawned, so it is [b]exactly[/b] at the muzzle tip and turns with the
## weapon's aim for the whole time it is up, with no per-frame follow anywhere.
@export var blast_path: NodePath = ^"../MuzzleRig/Muzzle/Blast"
## How long it is held at full brightness before it starts to go.
@export var blast_hold: float = 0.03
## How long the fade itself takes. The blast's whole life is this plus the hold,
## and it must always end - a shot may never leave a burst on the barrel.
@export var blast_fade: float = 0.05
## Nudge from where the artwork is authored, in the muzzle's own space. +X is
## further down the barrel.
@export var blast_offset := Vector2.ZERO
## Size it appears at and grows to, as fractions of the authored scale.
@export var blast_start_scale: float = 0.75
@export var blast_end_scale: float = 1.05
## How much thinner the burst is drawn than it is wide, as a fraction of its
## authored height. Below 1 narrows it to a slit, which is what makes a rifle's
## blast read as a jet rather than as the shotgun's ball of fire.
@export_range(0.05, 1.0) var blast_thinness: float = 0.62
## Tint laid over the artwork - the rifle's yellow.
@export var blast_colour := Color(1.0, 0.86, 0.42)
## Brightness of that tint. Above 1 blows the burst out, which with an additive
## material is what reads as a glow.
@export var blast_glow: float = 1.35

@export_group("Muzzle light")
## Optional light punched on the barrel as the shot leaves.
@export var muzzle_light_path: NodePath = ^"../MuzzleRig/MuzzleLight"
@export var muzzle_light_energy: float = 0.85
@export var muzzle_light_time: float = 0.07

@export_group("Reload tension zoom")
## How far round the gesture has to be before the camera starts closing in, in
## degrees. Not the whole circle - the point is that the player feels the turn
## coming, so the view only starts moving once the gesture is clearly under way.
@export var zoom_start_degrees: float = 200.0
## How far round the zoom has reached its full amount, in degrees. 0 uses the
## gesture's own [member MouseOrbit.required_degrees], so the zoom and the turn
## land together however far the turn is set to.
@export var zoom_end_degrees: float = 0.0
## How far in the camera is by the time the gesture completes, as a fraction.
## Small on purpose: it is tension, not a scope.
@export var zoom_amount: float = 0.085
## How quickly the zoom follows the gesture round. Short, so it tracks the hand
## rather than lagging behind it.
@export var zoom_follow_time: float = 0.06
## How long the camera takes to let go once the gesture lands. 0 snaps it back in
## a single frame, which is the point: the tension releases the instant the lever
## drops.
@export var zoom_release_time: float = 0.0
## How long it takes to unwind when a gesture is abandoned rather than finished.
## Slower than the release, so giving up eases back instead of snapping.
@export var zoom_cancel_time: float = 0.18

@export_group("Lever down")
@export var lever_down_sound: StringName = &"lever_rotate"
@export var lever_down_shake_strength: float = 3.0
@export var lever_down_shake_duration: float = 0.07

@export_group("Lever home")
@export var lever_home_sound: StringName = &"lever_ready"
## The rifle's answer to the shotgun's pump, and the punctuation of its whole
## rhythm: the action slamming shut is the moment the weapon becomes dangerous
## again, so it hits hard enough to be felt rather than merely noticed. Still well
## under the shot's own knock - the reload should not out-punch the round.
@export var lever_home_shake_strength: float = 13.0
@export var lever_home_shake_duration: float = 0.12
@export var lever_home_rotation_degrees: float = -1.2
@export var lever_home_rotation_out_time: float = 0.05
@export var lever_home_rotation_return_time: float = 0.14

@export_group("Dropped rounds")
## The live round thrown on the ground when the action is opened. Its size, how
## hard it is thrown and how long it lies there are its own scene's inspector
## fields, so the rounds are retuned where they are drawn.
@export var round_scene: PackedScene
## How far around the weapon the rounds first appear, in pixels.
@export var round_spread: float = 9.0
## Ceiling on how many are actually drawn in one go, however many the rifle says
## were in it. A magazine is small, so this is only a guard against a future
## weapon with a hundred rounds carpeting the floor.
@export var max_rounds_drawn: int = 24

@onready var _source: Node = get_node_or_null(source_path)
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank
@onready var _blast: CanvasItem = get_node_or_null(blast_path) as CanvasItem
@onready var _muzzle_light: PointLight2D = get_node_or_null(muzzle_light_path) as PointLight2D

var _camera: CameraController
var _blast_rest_scale := Vector2.ONE
var _blast_rest_position := Vector2.ZERO
var _blast_tween: Tween
var _light_tween: Tween
## The pitch slide running on each voice, keyed by that voice's instance id, so a
## voice reused by a later shot has its old slide killed rather than blended.
var _pitch_tweens: Dictionary = {}
## Whether the tension zoom is currently holding the camera in, so it is only
## released by something that actually took hold of it.
var _zooming: bool = false


func _ready() -> void:
	if _blast != null:
		var blast_node := _blast as Node2D
		if blast_node != null:
			# The authored transform is the base and every exported value is
			# measured from it, so tuning the burst never loses where the sprite was
			# placed on the barrel.
			_blast_rest_scale = blast_node.scale
			_blast_rest_position = blast_node.position
		_blast.visible = false
		_blast.modulate.a = 0.0

	if _muzzle_light != null:
		_muzzle_light.energy = 0.0

	if _source == null:
		return
	_listen(&"fired", _on_fired)
	_listen(&"dry_fired", _on_dry_fired)
	_listen(&"lever_opened", _on_lever_opened)
	_listen(&"lever_closed", _on_lever_closed)
	_listen(&"reload_progress", _on_reload_progress)


## Connected by name rather than statically, so a weapon that does not have one of
## these signals simply gets no feedback for it instead of erroring.
func _listen(signal_name: StringName, handler: Callable) -> void:
	if _source.has_signal(signal_name) and not _source.is_connected(signal_name, handler):
		_source.connect(signal_name, handler)


## The shot: the blast, its light and the kick.
func _on_fired() -> void:
	_play_shot()
	_flash_blast()
	_punch_muzzle_light()

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


## A trigger pull that produced nothing. Deliberately nothing but the click and
## the faintest tick - no blast, no light, and no round, because nothing left the
## rifle.
func _on_dry_fired() -> void:
	_play(dry_fire_sound)

	if dry_fire_shake_strength <= 0.0:
		return
	var camera := _get_camera()
	if camera == null:
		return
	camera.shake(_scaled(dry_fire_shake_strength), dry_fire_shake_duration)


## The action opening: the lever's own sound, and the live rounds hitting the
## ground. How many is the rifle's business - this only draws them.
func _on_lever_opened(rounds_ejected: int) -> void:
	_release_zoom(zoom_release_time)
	_play(lever_down_sound)
	_spawn_rounds(rounds_ejected)

	if lever_down_shake_strength <= 0.0:
		return
	var camera := _get_camera()
	if camera != null:
		camera.shake(_scaled(lever_down_shake_strength), lever_down_shake_duration)


## The action shutting on a fresh magazine.
func _on_lever_closed(_rounds_loaded: int) -> void:
	_play(lever_home_sound)

	var camera := _get_camera()
	if camera == null:
		return
	if lever_home_shake_strength > 0.0:
		camera.shake(_scaled(lever_home_shake_strength), lever_home_shake_duration)
	if not is_zero_approx(lever_home_rotation_degrees):
		camera.rotation_kick(
			_scaled(lever_home_rotation_degrees), lever_home_rotation_out_time,
			lever_home_rotation_return_time, camera_channel, camera_priority)


## Follows the reload gesture round and closes the camera in over its last
## stretch.
##
## The zoom is re-aimed each time the gesture moves rather than played as a fixed
## animation, which is what makes it track the player's hand: wind slower and it
## comes in slower, stop and it stops. [param degrees] and [param ratio] together
## say how far round a full turn is without this having to know what a full turn
## was set to.
func _on_reload_progress(degrees: float, ratio: float) -> void:
	if is_zero_approx(zoom_amount):
		return

	# Abandoned, or reset after completing. Only unwind a zoom this actually took.
	if ratio <= 0.0:
		if _zooming:
			_release_zoom(zoom_cancel_time)
		return

	# Where the turn ends is taken from the gesture itself unless a fixed angle has
	# been set, so the two cannot disagree about what "all the way round" means.
	var full := degrees / maxf(ratio, 0.0001)
	var ends_at := zoom_end_degrees if zoom_end_degrees > 0.0 else full
	if degrees < zoom_start_degrees or ends_at <= zoom_start_degrees:
		if _zooming:
			_release_zoom(zoom_cancel_time)
		return

	var camera := _get_camera()
	if camera == null:
		return

	var tension := clampf(
		(degrees - zoom_start_degrees) / (ends_at - zoom_start_degrees), 0.0, 1.0)
	_zooming = true
	camera.zoom_impulse(
		[Vector2(_scaled(zoom_amount) * tension, maxf(zoom_follow_time, 0.0001))],
		camera_channel, camera_priority)


## Lets the camera back out over [param duration]; 0 is a single-frame snap, which
## is what landing the gesture uses.
func _release_zoom(duration: float) -> void:
	if not _zooming:
		return
	_zooming = false
	var camera := _get_camera()
	if camera == null:
		return
	camera.zoom_impulse([Vector2(0.0, maxf(duration, 0.0))], camera_channel, camera_priority)


## Throws [param count] live rounds clear of the weapon. They are added to the
## running scene rather than to the rifle, which turns constantly and is drawn at
## a fraction of its true size - parenting them to it would shrink them and drag
## them round after they had been thrown.
func _spawn_rounds(count: int) -> void:
	var container := get_tree().current_scene
	var origin := _source as Node2D
	if round_scene == null or origin == null or container == null:
		return

	var facing := Vector2.RIGHT.rotated(origin.global_rotation)
	for i in mini(maxi(count, 0), maxi(max_rounds_drawn, 0)):
		var round_node := round_scene.instantiate() as Node2D
		if round_node == null:
			continue

		container.add_child(round_node)
		round_node.global_position = origin.global_position + Vector2(
			randf_range(-round_spread, round_spread),
			randf_range(-round_spread, round_spread)
		)
		round_node.reset_physics_interpolation()
		if round_node.has_method(&"launch"):
			round_node.launch(facing)


## Puts the burst on the barrel and takes it off again.
##
## Everything about it is measured from the authored transform, and the whole
## thing always ends in [method _hide_blast], so however fast the player fires the
## burst can never be left on screen.
func _flash_blast() -> void:
	if _blast == null:
		return

	if _blast_tween != null and _blast_tween.is_running():
		_blast_tween.kill()

	var blast_node := _blast as Node2D
	if blast_node != null:
		# The thinness is applied to the height only, so narrowing the burst never
		# shortens its reach down the barrel.
		blast_node.scale = Vector2(
			_blast_rest_scale.x * blast_start_scale,
			_blast_rest_scale.y * blast_start_scale * blast_thinness)
		blast_node.position = _blast_rest_position + blast_offset

	var tint := blast_colour * blast_glow
	tint.a = 1.0
	_blast.modulate = tint
	_blast.visible = true

	_blast_tween = create_tween().set_parallel(true)
	var fade := maxf(blast_fade, 0.0001)
	_blast_tween.tween_property(_blast, "modulate:a", 0.0, fade) \
		.set_delay(maxf(blast_hold, 0.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if blast_node != null:
		_blast_tween.tween_property(
			blast_node, "scale",
			Vector2(
				_blast_rest_scale.x * blast_end_scale,
				_blast_rest_scale.y * blast_end_scale * blast_thinness),
			maxf(blast_hold, 0.0) + fade
		)
	_blast_tween.chain().tween_callback(_hide_blast)


func _hide_blast() -> void:
	if _blast == null:
		return
	_blast.visible = false
	_blast.modulate.a = 0.0


func _punch_muzzle_light() -> void:
	if _muzzle_light == null or muzzle_light_energy <= 0.0:
		return

	if _light_tween != null and _light_tween.is_running():
		_light_tween.kill()

	_muzzle_light.energy = muzzle_light_energy
	_light_tween = create_tween()
	_light_tween.tween_property(
		_muzzle_light, "energy", 0.0, maxf(muzzle_light_time, 0.0001))


## One place [member camera_feedback_scale] is applied, so no camera value can be
## left out of it and none can be scaled twice.
func _scaled(amount: float) -> float:
	return amount * camera_feedback_scale


func _play(sound_name: StringName) -> void:
	if _sounds != null:
		_sounds.play(sound_name)


## The report, louder than the rest of the weapon and with its pitch sliding down
## across the whole of it.
##
## The slide is a tween on the voice the bank handed back rather than a value
## picked when the sound starts, which is the difference between a shot that
## *decays* and a shot that is simply a different pitch each time. Each voice
## keeps its own tween, killed if that voice is stolen by a later shot, so two
## overlapping reports slide independently instead of fighting over one pitch.
func _play_shot() -> void:
	if _sounds == null:
		return

	var voice := _sounds.play(fire_sound, fire_volume_db)
	if voice == null:
		return

	var id := voice.get_instance_id()
	var running: Tween = _pitch_tweens.get(id)
	if running != null and running.is_running():
		running.kill()

	voice.pitch_scale = fire_pitch_base
	var fall := randf_range(
		minf(fire_pitch_fall_min, fire_pitch_fall_max),
		maxf(fire_pitch_fall_min, fire_pitch_fall_max))
	var tween := create_tween()
	tween.tween_property(voice, "pitch_scale", maxf(fire_pitch_base - fall, 0.05),
		maxf(fire_pitch_slide_time, 0.0001))
	_pitch_tweens[id] = tween


## Looked up once and kept, but re-found if it has gone - the world is rebuilt
## between rounds and the camera comes back as a different node.
func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
