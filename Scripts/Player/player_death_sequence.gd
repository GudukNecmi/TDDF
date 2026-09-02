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
##
## [b]This is also where a run fails, and the two are the same event.[/b] Dying is the
## only way a run ends badly, so what the player themselves is carrying is put back
## here and nowhere else: the borrowed throwable given up, the weapon put away and
## silenced, the blood still flowing to them dropped before the purse is emptied, the
## streak lost with it, and the run itself ended on [RunSessionState] the moment the
## body is home.
##
## [b]What it does not do is tear the world down.[/b] The round, the road, the ambush,
## the search and the night each stand themselves down on the player's own
## [signal Health.died] - that is the pattern every one of them already follows - so
## there is no second teardown here that could disagree with theirs. The one exception
## is the bounty fight, and only because of its timing; see
## [method _close_the_encounter].

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
## otherwise walk them out of it.
##
## [b]The weapon is deliberately not in this list.[/b] It is built by [WeaponMount]
## rather than authored beside the player, so there is no path here that could name
## it; it is put away and silenced through the mount instead - see
## [method _stow_weapon] - exactly the way [PlayerSleep] does it.
@export var input_blocked_paths: Array[NodePath] = [^"../Teleporter"]
## The weapon put away, when there is no [WeaponMount] in the world to ask.
##
## The mount is the ordinary answer - it is what builds whichever weapon the player
## chose, so asking it is what makes this work for a weapon that did not exist when
## the player scene was authored. This path is only the fallback, for a test scene
## with a weapon dropped straight into it, and it is the same arrangement
## [member PlayerLoadout.weapon_path] uses for the same reason.
@export var weapon_path: NodePath = ^""
## How long the weapon takes to disappear on the killing hit.
@export var weapon_stow_time: float = 0.35
## Whether the trigger is silenced as well as the weapon being put away.
##
## [b]A stowed weapon is still listening.[/b] Holstering only changes where the
## weapon is drawn, so without this the player goes on firing while they are lying
## dead in the sand. It is handed back in [method _finish], so a sequence that ended
## badly can never leave the player holding a gun that will not fire.
@export var silences_weapon: bool = true
## Whether something the player picked up off the ground is given back as they go
## down, so their own weapon is what comes home with them.
##
## [b]A throwable is borrowed, not owned.[/b] [WeaponMount] puts the chosen weapon at
## the belt while a knife or a bone is in the hand and hands it back the moment the
## throw goes - so a death with one still in the hand arrives in the base carrying
## somebody else's knife, with the player's own weapon stowed behind it and nothing
## left to bring it out. The borrow is spent here through the mount's own
## [method WeaponMount.drop_temporary], which is the very call the throw makes.
@export var drops_temporary_weapon: bool = true
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
## Whether the blood still on its way to the player is dropped as the wallet is
## emptied.
##
## [b]Without it the emptying does not hold.[/b] Blood is banked the instant it
## reaches the player - see [method BloodMagnet._on_specks_arrived] - and the killing
## hit leaves a stream of it already lifting off the ground, the player's own spray
## among it. Every piece of that lands [i]after[/i] the wallet has been reset and is
## added to it, so a man killed in a crowd wakes up in the base with a purse he was
## meant to have lost. The pull is cleared through the magnet's own
## [method BloodMagnet.release_all], which exists for exactly this.
@export var releases_blood_in_flight: bool = true
## The horse's protected run storage - the [code]HorseBlood[/code] autoload.
## Told about the death, never emptied by it: see
## [method HorseBloodStorage.on_player_death], which is the single place that
## guarantees blood already moved onto the horse at a World Map Blood Depot is
## never touched by what happens here, however this file is retuned.
@export var horse_blood_path: NodePath = ^"/root/HorseBlood"

@export_group("The run")
## Whether dying ends the run on [RunSessionState].
##
## [b]It is the other half of coming home.[/b] The teleport carries the body back to
## the base, but the session is what says whether the player is out on a run at all -
## and left standing it leaves them at home in a world that still believes one is
## happening: the round still owed no resupply, the wounds of the run still
## remembered, the contracts never re-dealt. It is the same call the ride home makes -
## see [method CampMenu._ride_in] - so there is one answer to "the run is over"
## rather than two.
@export var ends_the_run: bool = true
## The run's own state - the [code]RunSession[/code] autoload.
@export var session_path: NodePath = ^"/root/RunSession"

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
@onready var _session: Node = get_node_or_null(session_path)
@onready var _loadout: PlayerLoadout = get_node_or_null(loadout_path) as PlayerLoadout
@onready var _wallet: BloodWallet = get_node_or_null(carried_wallet_path) as BloodWallet
@onready var _streak: StreakCounter = get_node_or_null(streak_path) as StreakCounter
@onready var _horse_blood: HorseBloodStorage = get_node_or_null(horse_blood_path) as HorseBloodStorage

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
	_hand_back_borrowed_weapon()
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
	# Dropped before the wallet is emptied, never after: a piece that reaches the
	# player is banked on the frame it arrives, so anything still in the air when the
	# reset happens would be added back on top of it.
	if releases_blood_in_flight:
		var magnet := BloodMagnet.get_active(self)
		if magnet != null:
			magnet.release_all()

	if lose_carried_blood and _wallet != null:
		_wallet.reset()
	if lose_streak and _streak != null:
		_streak.reset()

	# Reports rather than changes anything: the horse's own storage is a
	# separate wallet this never reaches into, so it is already safe by the
	# time this runs. See [method HorseBloodStorage.on_player_death].
	if _horse_blood != null:
		_horse_blood.on_player_death()


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
	_close_the_encounter()

	if _teleporter == null:
		_begin_restore()
		return

	# The teleport was one of the nodes silenced above; it is asked directly
	# rather than through its key, so the player still cannot trigger it.
	#
	# [b]The run portal is refused, and it has to be.[/b] The B key is contextual -
	# pressed while standing in the pit at the foot of the base it starts the next run
	# instead of travelling - and a body being carried home is standing wherever it
	# fell, which on a death in the base is the pit itself. Taken, that branch raises
	# the map screen over a corpse, never moves the body and never reports an arrival,
	# so the sequence waits at [constant State.TRAVELLING] for a signal that is never
	# coming and the player is left dead on a black screen for good. Carrying a body
	# home is not the player choosing to leave, so it is never a way to start a run.
	#
	# A teleport that could not be made - no destination, or one already under way -
	# answers false rather than stranding the sequence, and the player is simply put
	# back together where they fell.
	if not _teleporter.teleport(silent_teleport, false):
		_begin_restore()


func _on_teleported(_destination: TeleportDestination) -> void:
	if _state != State.TRAVELLING:
		return
	_begin_restore()


## The screen clears while the body is still on the ground, so the player fades
## back in already home and already being put back together, rather than fading
## in to a standing character with nothing to explain how they got there.
func _begin_restore() -> void:
	_state = State.RESTORING
	_end_the_run()
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
	_unsilence_weapon()
	if _visual != null:
		_visual.position = _visual_rest
		_visual.rotation = _visual_rest_rotation
	if _loadout != null:
		_loadout.refresh()
	revive_finished.emit()


## The bounty fight called off, if the player died in one.
##
## [b]It is here because of when, not because of what.[/b] Every other system stands
## itself down on the player's own [signal Health.died] - the round, the road, the
## ambush, the search, the night - but the boss encounter cannot: it is held on a map
## of its own several thousand pixels away, and unwinding it puts the bodies and the
## player back where they were found and hands the camera its old limits back. Done on
## the killing hit that is a body dragged across the desert in full view and a camera
## chasing it; done after the arrival it would overwrite the base's own limits with a
## rectangle in the middle of nowhere. The one moment it is neither is this one - the
## screen is fully black and the trip home has not started - so the death sequence is
## the only thing that can ask for it.
##
## [b]Nothing here is new machinery.[/b] It is the same three calls, in the same order,
## that winning the fight makes: the fixed screen handed back through
## [method BossArena.unlock], the fight forgotten through [method BossDefeat.reset],
## and the encounter taken off the map through
## [method MiniBossDirector.reset_encounter] - which carries everybody home itself. A
## world with none of them, which is every world that is not a boss day, does nothing.
##
## The contract is deliberately left standing on the board. Dying to the man does not
## complete his poster and does not tear it up; he is still wanted, and the next run
## can go after him again.
func _close_the_encounter() -> void:
	var director := MiniBossDirector.get_active(self)
	var arena := BossArena.get_active(self)

	# Asked before anything is touched, so an ordinary death - which is nearly all of
	# them - writes nothing at all. The arena is asked as well as the director, so a
	# world holding a locked screen with nobody running it is still handed back.
	var fighting := director != null and director.is_active()
	if not fighting and (arena == null or not arena.is_locked()):
		return

	# In the order winning the fight unwinds it: the screen first, because the camera
	# limits it hands back are the ones the encounter map is about to hand back its own
	# on top of - see [method BossDefeat._release_arena].
	if arena != null:
		arena.unlock()

	var defeat := BossDefeat.get_active(self)
	if defeat != null:
		defeat.reset()

	if fighting:
		director.reset_encounter()


## The run is over, and the session is told so at the moment the body is home.
##
## [b]It says nothing about where the player is standing[/b] - the teleport has
## already done that - only that they are no longer out on a run, which is what a
## world coming up next, a resupply and the wanted board all read. Ending a session
## that is already ended does nothing, so the ordinary ride home and a death arriving
## on top of one another cannot end the same run twice.
func _end_the_run() -> void:
	if not ends_the_run:
		return
	if _session != null and _session.has_method(&"end"):
		_session.call(&"end")


## Whatever is in the player's hands right now.
##
## Asked of the [WeaponMount] rather than held, because the weapon is built from the
## player's choice and can be replaced - a reference kept here would be stowing a
## weapon that had already been thrown away. Nothing here knows which weapon it is:
## this is the same lookup [PlayerLoadout] makes, so the two can never disagree about
## what is being put away.
func _get_weapon() -> Node2D:
	var mount := WeaponMount.get_active(self)
	if mount != null:
		var built := mount.get_weapon()
		if built != null:
			return built
	return get_node_or_null(weapon_path) as Node2D


## The knife or the bone the player picked up is given back before anything else
## happens, so the weapon that is put away below and carried home is their own.
##
## Nothing is reimplemented: the mount's own [method WeaponMount.drop_temporary] frees
## the borrowed weapon and brings the chosen one back out of the belt, which is
## exactly what spending the throw does. Harmless when nothing was borrowed.
func _hand_back_borrowed_weapon() -> void:
	if not drops_temporary_weapon:
		return
	var mount := WeaponMount.get_active(self)
	if mount != null and mount.is_carrying_temporary():
		mount.drop_temporary(0.0)


## The weapon is not parented to the player, so left alone it hangs in the air
## over the body. It is asked to holster rather than hidden, so it keeps
## following, keeps its state, and comes back the way it went away - and it is
## silenced as well as put away, because a stowed weapon is still listening for the
## trigger and a dead man does not fire.
func _stow_weapon() -> void:
	var weapon := _get_weapon()
	if weapon == null:
		return
	if weapon.has_method(&"stow"):
		weapon.call(&"stow", maxf(weapon_stow_time, 0.0))
	if silences_weapon:
		weapon.set_process_unhandled_input(false)


## The trigger handed back on the way out. Asked of the mount again rather than
## remembered, so a weapon swapped or rebuilt during the sequence is the one that
## gets it back - and it is deliberately separate from [PlayerLoadout], which decides
## only whether the weapon is [i]drawn[/i] and never whether it is listening.
func _unsilence_weapon() -> void:
	if not silences_weapon:
		return
	var weapon := _get_weapon()
	if weapon != null:
		weapon.set_process_unhandled_input(true)


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
	if camera == null:
		return
	camera.set_zoom_multiplier(1.0)
	# Anything the camera had been sent after is let go of before the body is moved.
	# A death can land in the middle of a presentation that borrowed the view - the
	# head [DangerFinale] follows out of the last man of a Danger - and a camera still
	# chasing a subject several thousand pixels away is a camera that never finds the
	# player again in the base.
	if camera.get_follow_subject() != null:
		camera.release_follow()


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
	_unsilence_weapon()
