class_name RevolverSpin
extends Node
## The gunslinger's twirl: what the revolver does when the cursor is drawn in onto
## the player, and the shot that earns.
##
## [b]It is one gesture with two readings.[/b] Bringing the cursor in close is not
## aiming at anything - there is nothing to hit at arm's length - so the weapon
## takes it as the player fanning it and starts turning on the trigger guard. Hold
## it there and the twirl climbs through [member stages]: each rung is worth more
## damage, kicks the camera once as it lands, spins the weapon visibly harder, drives
## the spin loop up a step and puts its own figure up on the readout.
##
## [b]The rungs are a list, not a ladder written down here.[/b] Nothing in this
## script knows what "two times" is: it walks [member stages] in order and asks each
## [SpinStage] what it is worth. A fourth rung is an entry in the inspector.
##
## [b]The gesture is not entered by accident.[/b] A cursor swept across the player
## mid-fight passes through the zone constantly, and a weapon that started twirling
## every time would take the player's shot away from them. So the zone has to be held
## for [member spin_entry_delay] before anything at all happens - until then the
## revolver is simply aiming, and a cursor that leaves inside that window banked
## nothing.
##
## [b]What is wound up survives the spin stopping.[/b] The twirl is not a buff: it is
## one shot. Reaching a rung and then taking the cursor back out leaves that rung
## armed for [member charge_hold_time], which is the window the player has to actually
## take the shot. Firing spends it outright and the next round is ordinary; letting
## the window run out spends it on nothing. Either way the revolver is never left
## permanently stronger than it was.
##
## [b]The exact centre is not a direction.[/b] A cursor sitting on the player has no
## angle worth reading - a pixel of jitter swings it right round - so the [i]aim[/i]
## is held still inside [member centre_deadzone] and the weapon stays out on the
## boundary rather than being dragged through the character. The twirl itself carries
## on: crossing the middle is a positional correction and nothing else, so the stage,
## the multiplier, the speed and the sound all come out the far side untouched. That
## hold is [member CarriedWeapon.aim_deadzone], one level down, which is why a cursor
## dragged straight through the player resolves onto the correct hand in a single
## frame instead of orbiting.
##
## [b]Which way it turns is which side it is on.[/b] A revolver held out to the
## player's left turns to the right and one held to their right turns to the left,
## which is the way a hand actually fans one. The side is read off the hand the weapon
## is being carried in rather than off where it has drifted to, so it flips in the
## same frame the aim does and the weapon never has to travel back through the
## character to find its new direction.
##
## [b]The spin turns the muzzle, and the muzzle is what fires.[/b] The artwork and
## the muzzle rig are turned together as one, and the revolver spawns its round
## along the muzzle's own heading rather than along the weapon's aim - so a shot
## taken mid-twirl genuinely leaves in the direction the barrel was pointing at that
## instant. Nothing is corrected back towards the cursor.
##
## The reload borrows the same rig for its own turn - see [member reload_spin_turns]
## - but only while the weapon is not already twirling. Mid-spin a round goes in
## without the twirl being interrupted, reset or spun a second time on top of itself,
## and without the charge, the speed or the sound moving at all.
##
## Nothing here is wired to the sight or the readout. It joins [member charge_group]
## and answers [code]get_charge_ratio()[/code] and [code]get_stage_label()[/code];
## [Crosshair] and [SpinMultiplier] ask whatever is in that group and know about no
## weapon in particular.

## Emitted as the twirl reaches a new rung, or drops off them entirely.
## [param index] is -1 and [param stage] null once the charge is let go.
signal stage_changed(index: int, stage: SpinStage)
## Emitted when the weapon stops turning with a rung still banked - the instant the
## firing window opens. [param seconds] is how long the player has.
signal charge_armed(seconds: float)

## Group anything with a charge joins, so the sight and the readout can find it
## without being wired to a weapon. Read by [member Crosshair.charge_group].
@export var charge_group: StringName = &"weapon_charge"

@export_group("The spin zone")
## How close the cursor must be to the player, in world pixels, for the weapon to
## start twirling.
##
## [b]This is "the mouse is near the player" as a number.[/b] It wants to be
## comfortably inside the distance a player aims at - close enough that nobody draws
## the cursor in this far by accident while shooting, far enough that they do not
## have to land it on a pixel.
@export var spin_radius: float = 80.0
## Extra distance the cursor must travel back out before the twirl stops, in pixels.
## Purely a dead zone: without it a cursor resting exactly on the boundary starts and
## stops the spin every frame.
@export var spin_release_margin: float = 18.0
## How long the cursor must stay inside the zone before the twirl begins, in seconds.
##
## [b]This is the guard against entering the gesture by accident.[/b] A cursor swept
## across the player during a fight is inside the zone for a few frames at a time, and
## without this the revolver would drop into a twirl - and take the player's shot with
## it - every time they aimed past themselves. Below this the weapon is aiming
## normally in every respect: no spin, no sound, no charge, no reload change. Leaving
## the zone cancels it outright, so the delay has to be [i]held[/i] rather than
## accumulated across passes.
##
## It only ever governs entering. Once the twirl is running it is not consulted
## again, so nothing inside the gesture can restart it.
@export var spin_entry_delay: float = 0.2
## How close to the player the cursor may come before the aim is held still, in
## pixels.
##
## [b]This is the guard against the middle.[/b] The angle from the player to a cursor
## a pixel away from them is noise, and a weapon obeying it would swing wildly for no
## input at all. Inside this the weapon stops being carried any further in and simply
## holds where it is, out on this boundary - it is the [i]aim[/i] that is frozen, not
## the twirl, so the weapon carries on spinning exactly as it was and crossing the
## middle costs the player nothing. The hold itself is
## [member CarriedWeapon.aim_deadzone]; this is the same radius as the spin knows it.
@export var centre_deadzone: float = 10.0
## How far back out of the centre the cursor must travel before the aim follows it
## again, in pixels. The same flicker guard as [member spin_release_margin], at the
## other end.
@export var centre_release_margin: float = 8.0
## Whether the player is asked where they are at all. Off measures from the weapon's
## own position instead, which is what a weapon in a scene with no player has.
@export var measure_from_player: bool = true
## Group the player is found in.
@export var player_group: StringName = &"player"

@export_group("The twirl")
## How fast it turns while it is being spun and nothing has been wound up yet, in
## degrees per second. Every rung of [member stages] is a multiple of this, so the
## whole ladder is retuned by this one field.
@export var spin_speed_degrees: float = 1440.0
## How quickly the turn spins up, and how quickly it reverses as the weapon crosses
## to the player's other side, in the usual exponential-smoothing units.
@export var spin_ease_speed: float = 14.0
## How quickly the weapon stops turning and settles back onto its aim once the cursor
## leaves the zone, in the same units. Deliberately well above
## [member spin_ease_speed]: winding up is a gesture and should be felt, but coming
## out of it must not leave the player waiting to shoot - especially now that what
## they are coming out of it to do is spend the charge before it expires.
@export var return_speed: float = 26.0
## How far out to one side the weapon must be held, in pixels, before it counts as
## having changed hands. A dead zone against a weapon carried straight up or down
## reversing its turn every frame.
@export var side_switch_margin: float = 6.0
## Art and rig turned by the twirl. Both, and together: the picture and the muzzle
## must be one object or the weapon would fire out of a barrel that is not where it
## is drawn.
@export var spin_paths: Array[NodePath] = [^"../Art", ^"../MuzzleRig"]

@export_group("Winding up")
## The rungs the twirl climbs, in ascending [member SpinStage.hold_time] order. Each
## one carries its own damage, its own speed, its own camera kick, its own playback
## speed for the loop and its own figure for the readout - see [SpinStage].
##
## Empty is a revolver whose twirl is worth nothing, which is a perfectly good
## revolver: it still spins, it simply never earns.
@export var stages: Array[SpinStage] = []

@export_group("The charged shot")
## How long a rung stays armed after the weapon has stopped turning, in seconds.
##
## [b]This is what makes the twirl a shot rather than a buff.[/b] The player winds
## the weapon up, takes the cursor back out onto what they are actually aiming at,
## and has this long to pull the trigger. Fire inside it and that one round carries
## the multiplier; miss it and the charge is gone and the revolver is ordinary again.
## 0 requires the shot to be taken mid-twirl.
@export var charge_hold_time: float = 1.0
## Whether a shot taken on a rung is announced as a critical, so the figure that
## comes off it is written as one.
@export var mark_as_critical: bool = true
## What such a shot's camera shake is multiplied by against an ordinary round's.
##
## Read off the weapon's own feedback rather than written down as a strength, so a
## revolver whose shot is retuned later keeps its charged shot exactly this much
## heavier without this being touched. See [member feedback_path].
@export var fire_shake_multiplier: float = 2.0

@export_group("Sound")
## The spin loop. A [LoopingSound], so it is steered by level rather than started and
## stopped: how quickly it comes up and how quickly it fades away when the player
## returns to normal aiming are that node's own
## [member LoopingSound.fade_in_speed] and [member LoopingSound.fade_out_speed].
@export var spin_sound_path: NodePath = ^"../SpinLoop"
## What the loop is played back at the moment the twirl begins, before any rung has
## been reached. Each rung states its own pitch outright - see
## [member SpinStage.audio_pitch].
@export var spin_audio_base_pitch: float = 1.0
## Whether firing cuts the loop dead rather than fading it.
##
## [b]On, and the two endings are deliberately different.[/b] A shot is an event and
## the report has to be the only thing heard at that instant, so the twirl is cut off
## underneath it. Letting the charge go without firing is not an event - the weapon is
## settling back down - so that one fades.
@export var spin_audio_cut_on_fire: bool = true

@export_group("Reload")
## How many whole turns a round going in spins the weapon. One, which is the 360
## degrees the reload is drawn as.
@export var reload_spin_turns: float = 1.0
## How long that turn takes, in seconds.
@export var reload_spin_time: float = 0.15
## Whether a round going in also turns the weapon while it is already twirling.
##
## [b]Off, deliberately.[/b] Mid-twirl the revolver is already turning in the player's
## hand, so a second 360 laid on top of it would fight the spin, reset the pose and
## read as an animation rather than as a reload. The rounds simply go in while it
## spins, and nothing about the charge, the speed or the sound moves. Outside the
## gesture - which includes the [member spin_entry_delay] window, where the weapon is
## still aiming normally - the reload turns the weapon exactly as it always did.
@export var reload_spins_while_spinning: bool = false

@export_group("Nodes")
## The weapon this belongs to. Defaults to this node's parent.
@export var weapon_path: NodePath = ^".."
## The weapon's feedback, read for the shake an ordinary shot makes so a charged one
## can be a multiple of it rather than a second number.
@export var feedback_path: NodePath = ^"../Feedback"

@onready var _weapon: Revolver = get_node_or_null(weapon_path) as Revolver
@onready var _feedback: RevolverFeedback = get_node_or_null(feedback_path) as RevolverFeedback
@onready var _loop: LoopingSound = get_node_or_null(spin_sound_path) as LoopingSound

var _rig: Array[Node2D] = []
## Where the twirl has got to, in radians, relative to the weapon's aim.
var _angle: float = 0.0
## What the twirl is turning at right now, in degrees per second - eased towards
## whatever the current rung wants, so it never changes speed or direction in one
## frame.
var _rate: float = 0.0
## Whether the cursor is inside the zone at all, centre included.
var _in_zone: bool = false
## How long it has been in there without a break. What the entry delay is measured
## against.
var _zone_time: float = 0.0
## Whether the cursor is close enough to the player for its angle to be meaningless.
var _in_centre: bool = false
var _spinning: bool = false
var _was_spinning: bool = false
## Which side of the player the weapon is held on: -1 left, +1 right. The turn goes
## the other way.
var _side: float = 1.0
## Seconds of unbroken spin banked towards the next rung.
var _wound: float = 0.0
## Which rung is held, or -1 for none.
var _stage: int = -1
## What is left of the window the banked rung may still be spent in, in seconds.
var _hold_left: float = 0.0
## The reload turn, counted down in seconds.
var _reload_left: float = 0.0
## Whether the loop is currently being asked for, so starting and ending a spin
## session are each done once rather than every frame.
var _audio_on: bool = false
var _pitch: float = 1.0
var _pitch_goal: float = 1.0
## How fast the pitch is sliding, in playback-speed units per second. 0 is settled.
var _pitch_rate: float = 0.0
var _camera: CameraController
var _player: Node2D


func _ready() -> void:
	add_to_group(charge_group)

	for path: NodePath in spin_paths:
		var node := get_node_or_null(path) as Node2D
		if node != null:
			_rig.append(node)

	_pitch = spin_audio_base_pitch
	_pitch_goal = spin_audio_base_pitch

	if _weapon == null:
		return
	# Connected by name, so a weapon that does not announce one of these simply gets
	# nothing for it rather than erroring.
	if _weapon.has_signal(&"bullet_spawned"):
		_weapon.bullet_spawned.connect(_on_bullet_spawned)
	if _weapon.has_signal(&"chamber_loaded"):
		_weapon.chamber_loaded.connect(_on_chamber_loaded)


## How far the wind-up has got towards its last rung: 0 is the weapon at rest, 1 is
## fully wound. What the sight crosses its colour on - and it deliberately holds
## through the firing window, so the sight stays charged for exactly as long as the
## shot is still worth taking.
func get_charge_ratio() -> float:
	var full := _full_time()
	if full <= 0.0:
		return 1.0 if _stage >= 0 else 0.0
	return clampf(_wound / full, 0.0, 1.0)


## The rung being held, or null while the twirl has not earned one yet.
func get_stage() -> SpinStage:
	if _stage < 0 or _stage >= stages.size():
		return null
	return stages[_stage]


## Which rung is held, counting from 0, or -1 for none.
func get_stage_index() -> int:
	return _stage


## What a shot taken right now multiplies its damage by. 1 is an ordinary round.
func get_damage_multiplier() -> float:
	var stage := get_stage()
	return maxf(stage.damage_multiplier, 0.0) if stage != null else 1.0


## What the readout should be showing, or an empty string for nothing. Asked for by
## [SpinMultiplier], which knows about no weapon.
func get_stage_label() -> String:
	var stage := get_stage()
	return stage.label if stage != null else ""


## How large that text should be drawn, against the readout's own base size.
func get_stage_label_scale() -> float:
	var stage := get_stage()
	return maxf(stage.label_scale, 0.01) if stage != null else 1.0


## Whether the weapon is currently being twirled.
func is_spinning() -> bool:
	return _spinning


## Whether the cursor is inside the zone, the entry delay and the still centre
## included.
func is_in_zone() -> bool:
	return _in_zone


## Whether the cursor is close enough in that the aim is being held.
func is_in_centre() -> bool:
	return _in_centre


## Whether a rung is banked and waiting to be spent on a shot that has not been taken
## yet - the weapon no longer turning, the multiplier still live.
func is_charge_armed() -> bool:
	return _stage >= 0 and not _spinning


## What is left of that window, in seconds. 0 when the weapon is still turning or
## there is nothing banked.
func get_hold_left() -> float:
	return _hold_left


## Which way the twirl turns from the hand the weapon is in: +1 clockwise on screen,
## -1 anticlockwise.
func get_spin_direction() -> float:
	return -_side


## Which side of the player the weapon is being carried on: -1 left, +1 right.
func get_side() -> float:
	return _side


## How far round the twirl is, in radians, on top of the weapon's aim.
func get_spin_angle() -> float:
	return _angle


## What the twirl is turning at, in degrees per second. Signed.
func get_spin_rate() -> float:
	return _rate


## What the spin loop is being played back at right now.
func get_audio_pitch() -> float:
	return _pitch


func _process(delta: float) -> void:
	if _weapon == null:
		return

	_advance_zone(delta)
	_advance_side()
	_advance_reload(delta)
	_advance_turn(delta)
	_advance_stages(delta)
	_advance_audio(delta)
	_apply_rig()


## Decides whether the weapon should be twirling at all, and whether the cursor is
## too close in for its angle to be worth anything.
##
## A stowed weapon never twirls - it is in the belt, and a cursor happening to rest
## on the player while it is away must not bank a charge for when it comes back.
func _advance_zone(delta: float) -> void:
	if _weapon.is_stowed():
		_in_zone = false
		_zone_time = 0.0
		_in_centre = false
		_spinning = false
		return

	var reach := _weapon.get_global_mouse_position().distance_to(_origin())

	# Two thresholds at each end rather than one, so a cursor resting on either
	# boundary cannot start and stop the twirl on alternate frames.
	_in_zone = reach <= maxf(spin_radius + (spin_release_margin if _in_zone else 0.0), 0.0)
	var centre := centre_deadzone + (centre_release_margin if _in_centre else 0.0)
	_in_centre = reach < maxf(centre, 0.0)

	# Counted rather than timed, and thrown away outright the moment the cursor is
	# out: the delay is a hold, so two quick passes through the zone never add up to
	# one deliberate one.
	_zone_time = _zone_time + delta if _in_zone else 0.0
	_spinning = _in_zone and _zone_time >= maxf(spin_entry_delay, 0.0)


## Which side of the player the weapon is standing on.
##
## [b]Read off the hand rather than off where the weapon has got to.[/b] The weapon
## is carried out at arm's length by [member CarriedWeapon.hand_offset] and trails
## after the player on a spring, so its actual position lags the aim by a good
## fraction of a second - long enough that a cursor thrown across the character would
## leave the twirl turning the old way while the weapon was already on the new side.
## The hand direction is the aim, so it flips in the same frame the aim resolves and
## the weapon never has to travel back through the character to find its direction.
func _advance_side() -> void:
	var dx := _weapon.get_hand_direction().x
	if is_zero_approx(dx):
		dx = _weapon.global_position.x - _origin().x
	if absf(dx) < maxf(side_switch_margin, 0.0):
		return
	_side = signf(dx)


func _advance_reload(delta: float) -> void:
	if _reload_left > 0.0:
		_reload_left = maxf(_reload_left - delta, 0.0)


## Eases the turn rate towards whatever the twirl and the reload between them want,
## so the weapon spins up, changes rung and reverses as movements rather than as
## assignments.
func _advance_turn(delta: float) -> void:
	var wanted := _wanted_rate()

	if is_zero_approx(wanted):
		# Winding down. The rate is brought to nothing and the angle pulled home at
		# the same time, so the weapon decelerates onto its aim rather than either
		# snapping to it or coasting a further turn to reach it.
		var settle := 1.0 - exp(-maxf(return_speed, 0.01) * delta)
		_rate = lerpf(_rate, 0.0, settle)
		_angle = wrapf(_angle + deg_to_rad(_rate) * delta, -PI, PI)
		_angle = lerp_angle(_angle, 0.0, settle)
		if absf(_angle) < 0.004 and absf(_rate) < 1.0:
			_angle = 0.0
			_rate = 0.0
		return

	_rate = lerpf(_rate, wanted, 1.0 - exp(-maxf(spin_ease_speed, 0.01) * delta))
	_angle = wrapf(_angle + deg_to_rad(_rate) * delta, -PI, PI)


## How fast the weapon wants to be turning, signed by which side it is on.
func _wanted_rate() -> float:
	var rate := 0.0
	if _spinning:
		rate = spin_speed_degrees * _speed_multiplier() * get_spin_direction()

	if _reload_left > 0.0 and reload_spin_time > 0.0:
		# The reload's turn is a fixed number of degrees in a fixed time, so it is
		# whatever rate delivers that - and the faster of the two wins, which is what
		# stops a reload from being slowed by a twirl already running.
		var reload_rate := reload_spin_turns * 360.0 / reload_spin_time * get_spin_direction()
		if absf(reload_rate) > absf(rate):
			rate = reload_rate

	return rate


## What the rung being held multiplies the base speed by. 1 below the first rung.
func _speed_multiplier() -> float:
	var stage := get_stage()
	return maxf(stage.spin_speed_multiplier, 0.0) if stage != null else 1.0


## Climbs the rungs while the twirl runs, and runs the window down once it stops.
##
## [b]Stopping is not cancelling.[/b] What the player wound up is theirs for
## [member charge_hold_time] afterwards, which is the whole point of the gesture: the
## twirl happens near the character and the shot is taken somewhere else, so the two
## cannot be required to be the same instant. What does cancel it is spending it - see
## [method _on_bullet_spawned] - or letting the window run out.
func _advance_stages(delta: float) -> void:
	if _spinning:
		_hold_left = 0.0
		_was_spinning = true
		_wound += delta
		# One rung at a time, so every transition is announced and none is skipped
		# even on a frame long enough to cross two of them.
		while _stage + 1 < stages.size():
			var next: SpinStage = stages[_stage + 1]
			if next == null or _wound < next.hold_time:
				break
			_stage += 1
			_enter_stage(next)
		return

	if _was_spinning:
		# The instant the weapon stops turning. Anything banked is armed here and
		# nowhere else, so the window is opened exactly once per gesture.
		_was_spinning = false
		if _stage >= 0:
			_hold_left = maxf(charge_hold_time, 0.0)
			charge_armed.emit(_hold_left)
		else:
			_wound = 0.0

	if _stage < 0:
		_wound = 0.0
		return

	# The wind-up itself is kept while the window runs, so a player who dips out of
	# the zone and comes straight back carries on climbing from where they were rather
	# than starting the ladder again.
	_hold_left = maxf(_hold_left - delta, 0.0)
	if _hold_left <= 0.0:
		_reset_charge()


## One rung reached. The camera is kicked here and only here - the rung being held
## is not a reason to keep shaking, so what the player feels is the moment it landed.
func _enter_stage(stage: SpinStage) -> void:
	var camera := _get_camera()
	if camera != null and stage.shake_strength > 0.0:
		camera.shake(stage.shake_strength, maxf(stage.shake_duration, 0.0001))
	_aim_pitch(stage.audio_pitch, stage.audio_pitch_time)
	stage_changed.emit(_stage, stage)


func _reset_charge() -> void:
	_wound = 0.0
	_hold_left = 0.0
	if _stage < 0:
		return
	_stage = -1
	stage_changed.emit(-1, null)


## How long the whole ladder takes to climb, which is what the sight's colour is
## measured against.
func _full_time() -> float:
	var full := 0.0
	for stage: SpinStage in stages:
		if stage != null:
			full = maxf(full, stage.hold_time)
	return full


## Steers the loop and slides its playback speed onto whatever rung is being held.
##
## The two ways a spin can end are deliberately not the same sound. Firing cuts it -
## see [member spin_audio_cut_on_fire] - and simply stopping asks for silence and lets
## the [LoopingSound] fade at its own rate. Nothing here restarts the loop for a side
## change or a reload, because neither of those ends the spin session.
func _advance_audio(delta: float) -> void:
	if _loop == null:
		return

	if _spinning:
		if not _audio_on:
			# A new session, so it starts from the base speed however fast the last one
			# ended.
			_audio_on = true
			_pitch = spin_audio_base_pitch
			_pitch_goal = spin_audio_base_pitch
			_pitch_rate = 0.0
		_loop.set_level(1.0)
	elif _audio_on:
		_audio_on = false
		_loop.set_level(0.0)

	if _pitch_rate > 0.0:
		_pitch = move_toward(_pitch, _pitch_goal, _pitch_rate * delta)
		if is_equal_approx(_pitch, _pitch_goal):
			_pitch_rate = 0.0
	else:
		_pitch = _pitch_goal

	_loop.pitch_scale = maxf(_pitch, 0.01)


## Starts the loop sliding onto [param goal] over [param seconds]. A time of nothing
## is a step, which is what a rung with no glide asked for.
func _aim_pitch(goal: float, seconds: float) -> void:
	_pitch_goal = goal
	if seconds <= 0.0:
		_pitch = goal
		_pitch_rate = 0.0
		return
	_pitch_rate = absf(goal - _pitch) / seconds


## Cuts the loop dead and puts the pitch back where a fresh spin would start.
func _silence_audio() -> void:
	if _loop == null:
		return
	_audio_on = false
	_pitch = spin_audio_base_pitch
	_pitch_goal = spin_audio_base_pitch
	_pitch_rate = 0.0
	_loop.pitch_scale = maxf(spin_audio_base_pitch, 0.01)
	_loop.silence_now()


## Writes the turn onto the art and the rig together. Rotation only - the mirror
## that keeps the weapon upright writes `scale.y` on these same nodes and the two
## must not fight.
func _apply_rig() -> void:
	for node: Node2D in _rig:
		if is_instance_valid(node):
			node.rotation = _angle


## The revolver has just put a round in the air. If a rung is banked - whether the
## weapon is still turning or the player wound it up and came back out to take the
## shot - this is the shot it was for.
##
## The round is empowered rather than replaced, so it is the weapon's ordinary bullet
## with its ordinary profile and its ordinary falloff - only harder.
func _on_bullet_spawned(bullet: Projectile) -> void:
	var stage := get_stage()
	if stage == null or bullet == null:
		return

	bullet.empower(maxf(stage.damage_multiplier, 0.0), mark_as_critical)

	var camera := _get_camera()
	if camera != null and _feedback != null:
		camera.shake(
			_feedback.fire_shake_strength * maxf(fire_shake_multiplier, 0.0),
			_feedback.fire_shake_duration)

	if spin_audio_cut_on_fire:
		_silence_audio()

	# Spent the instant it is used, and only the charge is spent: a weapon still being
	# twirled carries on turning at its base speed and starts winding the ladder again
	# from nothing.
	_reset_charge()


## A round has gone in. One whole turn of the same rig the twirl uses - unless the
## weapon is already twirling, where a second revolution laid on top of it would read
## as an animation interrupting the gesture.
func _on_chamber_loaded(_chamber: int) -> void:
	if _spinning and not reload_spins_while_spinning:
		return
	if reload_spin_time <= 0.0 or is_zero_approx(reload_spin_turns):
		return
	_reload_left = reload_spin_time


## What the zone is measured from: the player, so the twirl is about where the
## character is rather than about where their weapon has drifted to.
func _origin() -> Vector2:
	if measure_from_player:
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group(player_group) as Node2D
		if _player != null:
			return _player.global_position
	return _weapon.global_position


func _get_camera() -> CameraController:
	if _camera == null or not is_instance_valid(_camera):
		_camera = CameraController.get_active(self)
	return _camera
