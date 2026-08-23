class_name PlayerDeathSequence
extends Node
## The player's last heart, and everything that follows it.
##
## One beat, played end to end: the world drops into slow motion, two X marks
## snap over the eyes, the body jumps, falls, and lies there while the camera
## crawls in on its face - and then it is carried home, put back together one
## heart at a time, and stood up again.
##
## The X marks are the enemies' own [code]DeadEyes[/code] artwork on the player's
## head, and the trip home is the player's own [Teleporter] with its snap and its
## silence: dying is meant to read as the same language the rest of the game is
## written in, so almost none of it is new. What is new is only the order and the
## timing.
##
## Nothing is switched off by force. Movement stops because this answers 0 to the
## player's own [method get_speed_multiplier] question - the same seam
## [TerrainSlow] slows them through - so the player script needs no idea that
## dying exists and the body can never be left permanently frozen by a sequence
## that ended badly. Keys are silenced the same way: the nodes listed in
## [member input_blocked_paths] simply stop being offered input, and are handed it
## back at the end.
##
## The slow motion is held rather than set. [PlayerDamageFeedback] freezes time
## on the same hit and restores it a moment later, so a single write here would
## be undone by that timer; instead the time scale is driven every frame off the
## real clock, which also lets it ease back to normal rather than snapping.

## Emitted as the killing hit lands and the world slows.
signal death_started
## Emitted as the body comes to rest on the ground.
signal lying_down
## Emitted as the hearts begin coming back.
signal revive_started
## Emitted once the player is standing and can move again.
signal revive_finished

enum State { IDLE, DYING, LYING, TRAVELLING, RESTORING, RISING }

## Health whose death starts all of this.
@export var health_path: NodePath = ^"../Health"
## The artwork that falls over. Its rest transform is captured on ready and
## everything here is measured from it, so the body always ends up back where it
## belongs however the sequence was interrupted.
@export var visual_path: NodePath = ^"../Visual"
## The X marks over the eyes. Authored hidden; being a child of the head sprite
## is what makes them lean and flip with it for free.
@export var dead_eyes_path: NodePath = ^"../Visual/Head/DeadEyes"
## The teleport that carries the body home. Unresolved, the sequence still runs
## and the player is simply put back together where they fell.
@export var teleporter_path: NodePath = ^"../Teleporter"
## Nodes whose input is switched off for the length of the sequence, so no key
## press can pull the player out of their own death - the teleport that would
## otherwise walk them out of it, and the weapon.
@export var input_blocked_paths: Array[NodePath] = [
	^"../Teleporter", ^"../../Shotgun"
]
## The weapon, put away as the player goes down. It is not parented to them, so
## without this it hangs in the air over the body while they lie there. It goes
## through the weapon's own [method Node2D.stow], the same call [PlayerLoadout]
## uses, so it comes back exactly as ready or as spent as it went away.
@export var shotgun_path: NodePath = ^"../../Shotgun"
## How long the weapon takes to disappear on the killing hit.
@export var weapon_stow_time: float = 0.35
## The component that owns what the player is holding. It is asked to take the
## weapon back over once the player is standing again, rather than this drawing
## the weapon itself - so a player revived in the base stays empty-handed and one
## revived in the arena is handed their shotgun.
@export var loadout_path: NodePath = ^"../PlayerLoadout"

@export_group("Slow motion")
## Time scale the whole world drops to on the killing hit. Everything is on the
## same clock, so the enemies still standing slow down with the player.
@export_range(0.02, 1.0) var death_time_scale: float = 0.25
## How long the world stays slowed, in real seconds - real, because a clock
## running on scaled time would slow down along with everything it was timing.
@export var slow_motion_time: float = 2.4
## How long the time scale takes to ease back to normal afterwards.
@export var slow_motion_recovery: float = 0.7

@export_group("Fall")
## Beat between the X marks landing and the body giving way, so the player is
## seen to die before they are seen to fall.
@export var stagger_time: float = 0.22
## How high the small jump goes, in pixels.
@export var jump_height: float = 26.0
@export var jump_up_time: float = 0.26
@export var fall_time: float = 0.38
## Angle the body ends up lying at, in degrees. Near a quarter turn, so it comes
## to rest on its side rather than face down.
@export var lie_rotation_degrees: float = 86.0
## Where the body settles relative to where it stood, once it is down.
@export var lie_offset := Vector2(4.0, 4.0)
## How long it lies in the arena before it is carried home.
@export var lie_hold_time: float = 2.0

@export_group("Camera")
## How far the camera pushes in on the face while the body lies there, as a
## multiplier on the camera's resting zoom.
@export var death_zoom_multiplier: float = 2.2
## How long that push takes. Long on purpose - it is a crawl, not a punch.
@export var death_zoom_time: float = 2.2
@export var shake_strength: float = 24.0
@export var shake_duration: float = 0.45

@export_group("Revival")
## Beat after arriving in the base before the first heart comes back.
@export var revive_lead_in: float = 1.0
## Gap between one heart being restored and the next.
@export var heart_restore_interval: float = 0.4
## Health put back per step. 1 is one heart at a time, which is what makes the
## revival read as counting back up however many hearts the player has.
@export var heart_restore_amount: float = 1.0
## Beat after the last heart lands before the body gets up.
@export var rise_delay: float = 0.45
## How high the small rise goes, in pixels.
@export var rise_height: float = 20.0
@export var rise_up_time: float = 0.24
@export var rise_down_time: float = 0.2

@export_group("Cost")
## Whether dying costs the player the blood they were carrying.
@export var lose_carried_blood: bool = true
## Whether it also costs them the streak that blood was going to be multiplied by.
##
## [b]On, and it is the other half of what a streak is.[/b] Every outlaw put down
## raises what the ride home pays and raises what dying costs by exactly the same
## amount - see [StreakCounter] - so a player three bosses deep is carrying a bet
## rather than a balance. Getting home is the only way to collect it.
@export var lose_streak: bool = true
## The run's streak - the [code]Streak[/code] autoload.
@export var streak_path: NodePath = ^"/root/Streak"
## The carried wallet emptied - the [code]Blood[/code] autoload. This is
## deliberately not the base's pool: [BloodBank] is a different wallet holding
## what the player already got home and banked, and nothing here can reach it, so
## a death can never touch it however this is retuned.
@export var carried_wallet_path: NodePath = ^"/root/Blood"

@export_group("Black out")
## Whether the trip home is hidden behind a fade to black. The teleport itself is
## unchanged either way - this only decides whether the player watches it happen.
@export var fade_through_teleport: bool = true
## How long the screen takes to go black, once the body has finished lying there.
## The teleport is not started until this has completed.
@export var fade_out_time: float = 1.0
## How long the screen takes to clear again on the far side. The body is still
## lying down as it does, so the player fades back in already home.
@export var fade_in_time: float = 1.0
## Whether the trip home is made without the teleport's finger snap. The snap is
## the player clicking their fingers to leave - a thing they choose to do - and a
## body being carried home has not chosen anything. The ordinary B teleport is
## untouched and still snaps.
@export var silent_teleport: bool = true

@export_group("Music")
## Whether the arena track winds down as the player dies and hands over to the
## base track while they are being put back together. The music itself is
## [MusicDirector]'s business - this only says when.
@export var drive_music: bool = true

@export_group("Screen blood")
## Whether the held final blood is washed away as the hearts come back. The
## screen is found by group, so the HUD and the player are not wired together.
@export var dissolve_blood_screen: bool = true

@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _visual: Node2D = get_node_or_null(visual_path) as Node2D
@onready var _eyes: CanvasItem = get_node_or_null(dead_eyes_path) as CanvasItem
@onready var _teleporter: Teleporter = get_node_or_null(teleporter_path) as Teleporter
@onready var _shotgun: Node2D = get_node_or_null(shotgun_path) as Node2D
@onready var _loadout: PlayerLoadout = get_node_or_null(loadout_path) as PlayerLoadout
@onready var _wallet: BloodWallet = get_node_or_null(carried_wallet_path) as BloodWallet
@onready var _streak: StreakCounter = get_node_or_null(streak_path) as StreakCounter

var _state: State = State.IDLE
var _visual_rest := Vector2.ZERO
var _visual_rest_rotation: float = 0.0
var _tween: Tween
var _camera_tween: Tween
var _slowing: bool = false
var _slow_started_ms: int = 0


func _ready() -> void:
	set_process(false)

	if _visual != null:
		_visual_rest = _visual.position
		_visual_rest_rotation = _visual.rotation
	if _eyes != null:
		_eyes.visible = false

	if _health != null:
		_health.died.connect(_on_died)
	if _teleporter != null:
		_teleporter.teleported.connect(_on_teleported)


## True from the killing hit until the player is standing again.
func is_busy() -> bool:
	return _state != State.IDLE


## The player's movement seam. 0 pins them where they are for the whole sequence,
## which is what stops them walking during the fall and during the healing.
func get_speed_multiplier() -> float:
	return 0.0 if is_busy() else 1.0


func _on_died() -> void:
	if _state != State.IDLE:
		return

	_state = State.DYING
	_show_eyes(true)
	_block_input(true)
	_stow_weapon()
	_spill_carried_blood()
	_start_slow_motion()
	_slow_music()
	_push_camera()
	death_started.emit()
	_play_fall()


## Everything the player was still carrying is lost with them - the blood in their
## hands, and the streak it would have been multiplied by.
##
## Only the carried wallet is emptied: what they banked in the base is a separate total
## this has no reference to, and what they stashed at a camp is a third, so getting
## blood out of your hands is what makes it safe. The streak goes with it because the
## two are the same wager - see [StreakCounter] - and nothing else in the game ever
## takes either of them away.
func _spill_carried_blood() -> void:
	if lose_carried_blood and _wallet != null:
		_wallet.reset()
	if lose_streak and _streak != null:
		_streak.reset()


## Up, over, and down. The turn is split across the two halves rather than run as
## one long parallel tween, so the body is already leaning as it leaves the ground
## and is fully over by the time it lands.
func _play_fall() -> void:
	if _visual == null:
		_on_landed()
		return

	_kill_tween()
	_tween = create_tween()
	if stagger_time > 0.0:
		_tween.tween_interval(stagger_time)

	var lie := deg_to_rad(lie_rotation_degrees)
	_tween.tween_property(_visual, "position", _visual_rest + Vector2(0.0, -jump_height),
		maxf(jump_up_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_visual, "rotation", lie * 0.35,
		maxf(jump_up_time, 0.0001)).set_trans(Tween.TRANS_SINE)

	_tween.chain().tween_property(_visual, "position", _visual_rest + lie_offset,
		maxf(fall_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_visual, "rotation", lie,
		maxf(fall_time, 0.0001)).set_trans(Tween.TRANS_SINE)

	_tween.chain().tween_callback(_on_landed)
	_tween.tween_interval(maxf(lie_hold_time, 0.0))
	_tween.tween_callback(_black_out)


func _on_landed() -> void:
	_state = State.LYING
	lying_down.emit()


## The screen is taken to black *before* anything moves, and the move is only
## started once it is fully black - so the teleport, the camera jumping across
## two thousand pixels of empty world, and the arrival are all things the player
## is told about rather than shown.
##
## With no fade in the scene the sequence still runs; the player simply sees the
## cut, which is exactly what happened before this existed.
func _black_out() -> void:
	_state = State.TRAVELLING
	_release_camera()

	var fade := ScreenFade.get_active(self) if fade_through_teleport else null
	if fade == null:
		_travel_home()
		return
	fade.fade_out(fade_out_time, _travel_home)


## The camera is handed back before the body moves, so whichever [WorldZone] the
## player lands in gets to say where the view rests from then on rather than
## fighting a death zoom that has not let go.
func _travel_home() -> void:
	if _teleporter == null:
		_begin_restore()
		return

	# The teleport was one of the nodes silenced above; it is asked directly
	# rather than through its key, so the player still cannot trigger it.
	_teleporter.teleport(silent_teleport)


func _on_teleported(_destination: TeleportDestination) -> void:
	if _state != State.TRAVELLING:
		return
	_begin_restore()


## The screen clears while the body is still on the ground, so the player fades
## back in already home and already being put back together, rather than fading
## in to a standing character with nothing to explain how they got there.
func _begin_restore() -> void:
	_state = State.RESTORING
	revive_started.emit()

	var fade := ScreenFade.get_active(self)
	if fade != null:
		fade.fade_in(fade_in_time)

	if drive_music:
		var music := MusicDirector.get_active(self)
		if music != null:
			music.hand_over_after_death()

	if dissolve_blood_screen:
		var blood := BloodScreen.get_active(self)
		if blood != null:
			blood.dissolve_final()

	_wait(maxf(revive_lead_in, 0.0), _restore_next_heart)


## One heart, then the next, on a timer rather than in a loop - the gap between
## them is the whole of the effect. It counts by asking the pool whether it is
## full rather than by counting hearts, so a player with seven of them is put
## back together exactly the same way as one with three.
func _restore_next_heart() -> void:
	if _state != State.RESTORING:
		return

	if _health == null:
		_rise()
		return

	_health.heal(maxf(heart_restore_amount, 0.01))
	if _health.is_full():
		_wait(maxf(rise_delay, 0.0), _rise)
		return

	_wait(maxf(heart_restore_interval, 0.01), _restore_next_heart)


## The X marks come off first, then the body picks itself up - in that order, so
## the player is seen to come back before they are seen to move.
func _rise() -> void:
	if _state == State.RISING:
		return
	_state = State.RISING
	_show_eyes(false)

	# Belt and braces: whatever the stepping worked out to, the player ends the
	# sequence at full health.
	if _health != null:
		_health.restore_full()

	if _visual == null:
		_finish()
		return

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_visual, "position", _visual_rest + Vector2(0.0, -rise_height),
		maxf(rise_up_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_visual, "rotation", _visual_rest_rotation,
		maxf(rise_up_time, 0.0001)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(_visual, "position", _visual_rest,
		maxf(rise_down_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish)


func _finish() -> void:
	_state = State.IDLE
	_block_input(false)
	if _visual != null:
		_visual.position = _visual_rest
		_visual.rotation = _visual_rest_rotation
	if _loadout != null:
		_loadout.refresh()
	revive_finished.emit()


## The weapon is not parented to the player, so left alone it hangs in the air
## over the body. It is asked to holster rather than hidden, so it keeps
## following, keeps its state, and comes back the way it went away.
func _stow_weapon() -> void:
	if _shotgun != null and _shotgun.has_method(&"stow"):
		_shotgun.call(&"stow", maxf(weapon_stow_time, 0.0))


## The arena track is asked to wind down on the killing hit. It is only the
## *pitch* here - the handover to the base track waits until the player is being
## put back together, so the two halves of the transition land on the two halves
## of the death rather than both at once.
func _slow_music() -> void:
	if not drive_music:
		return
	var music := MusicDirector.get_active(self)
	if music != null:
		music.slow_for_death()


func _show_eyes(shown: bool) -> void:
	if _eyes != null:
		_eyes.visible = shown


## Real time, because the sequence runs through a slowed and then a recovering
## clock, and process-always, so a menu opened part way through cannot strand the
## player lying on the ground forever.
func _wait(seconds: float, then: Callable) -> void:
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(then)


func _start_slow_motion() -> void:
	_slowing = true
	_slow_started_ms = Time.get_ticks_msec()
	set_process(true)


## Driven off the wall clock and rewritten every frame, so the damage feedback's
## own hit-stop - which restores the time scale a fraction of a second after the
## killing hit - cannot cut the slow motion short.
func _process(_delta: float) -> void:
	if not _slowing:
		return

	var elapsed := float(Time.get_ticks_msec() - _slow_started_ms) / 1000.0
	if elapsed < slow_motion_time:
		Engine.time_scale = death_time_scale
		return

	var back := clampf(
		(elapsed - slow_motion_time) / maxf(slow_motion_recovery, 0.0001), 0.0, 1.0)
	Engine.time_scale = lerpf(death_time_scale, 1.0, back)
	if back < 1.0:
		return

	Engine.time_scale = 1.0
	_slowing = false
	set_process(false)


## Tweened rather than set, so the crawl is this node's pacing and not the
## camera's - the camera's own ease then rides on top of it.
func _push_camera() -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	if shake_strength > 0.0:
		camera.shake(shake_strength, shake_duration)

	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(
		camera, "zoom_multiplier", death_zoom_multiplier, maxf(death_zoom_time, 0.0001))


func _release_camera() -> void:
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	var camera := CameraController.get_active(self)
	if camera != null:
		camera.set_zoom_multiplier(1.0)


func _block_input(blocked: bool) -> void:
	for path: NodePath in input_blocked_paths:
		var node := get_node_or_null(path)
		if node != null:
			node.set_process_unhandled_input(not blocked)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()


## Restored on the way out, so a scene rebuild part way through a death can never
## leave the next round running in slow motion or the next player unable to move.
func _exit_tree() -> void:
	if _slowing:
		Engine.time_scale = 1.0
		_slowing = false
	_block_input(false)
