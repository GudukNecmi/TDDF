class_name KillCam
extends Node
## The one place a combat-ending final kill gets its moment: a brief lock-on
## to the man who just died, a beat of weight under it, and the Win stinger
## fired the instant it begins - reused identically whatever put the last
## enemy down.
##
## [b]It builds nothing new to look through.[/b] The lock-on is
## [method CameraController.follow] - the exact cinematic layer a coin
## already borrows and a death already borrows for its own crawl-in - held
## for [member hold_time] and then released the same way any other
## cinematic hands the view back. The weight under it is [HitStop], the
## world's own existing impact-freeze, asked for a longer beat than a single
## hit ever needs. Neither is a system built for this; both are the existing
## ones, asked politely.
##
## [b]The lock is on the head, not the man.[/b] [method trigger] is handed
## whichever [Node2D] a director calls its own "enemy" - the whole body - and
## looks up its own [code]HeadAim/Head[/code] child, the same node every
## enemy already carries for aiming and appearance (see [EnemyHeadPop],
## [BanditAppearance], [MiniBossAppearance]), rather than following the body
## itself. Anything built without one simply falls back to the body, which is
## the whole of how this behaved before there was a head to reach for.
##
## [b]The push-in is [member CameraController.zoom_multiplier], the same knob
## a place turns to set its own resting view[/b] - not a new effect, and not
## one of the impulse channels, because this has to *hold* at 3x for the
## whole beat rather than punch and settle back on its own. [method trigger]
## saves whatever the arena was resting at and writes the push in
## immediately - see [method CameraController.set_zoom_multiplier] - so the
## zoom is already the close shot on the very same frame the killing hit is
## confirmed, not something the camera is still easing towards when the head
## comes off. [method _release] eases the multiplier back to the saved value
## alongside the ordinary follow release, so a fight fought inside an arena
## already zoomed out is handed back exactly that view rather than to 1.
##
## [b]One instance, every combat.[/b] World Map bandit contact, a bounty
## camp, a Base round and a Mini Boss all call the same [method trigger] on
## whichever [Node2D] they just watched die - see the callers wired to
## [signal AmbushWaveDirector.last_attacker_defeated],
## [signal WaveManager]-driven arena completion and
## [signal BossDefeat.boss_defeated]. Nothing here knows which of the three
## asked, and nothing about the Win sound or the lock-on differs between
## them - see [StingerBoard]'s own doc on why a set, not a branch, is what
## keeps that true.
##
## [b]It cannot be asked twice for the same moment.[/b] [method trigger]
## refuses while [method is_active], so a director whose own bookkeeping
## fires more than once for the same field emptying - the ordinary
## surrender-then-shot double count every ambush already guards against
## itself - can never double the camera or the Win sound on top of it.
##
## [b]The hold is mandatory, not a suggestion.[/b] [member hold_time] is three
## full seconds by default and nothing in this file shortens or skips it for
## any caller - the World Map's own combat bridge waits out [signal ended]
## before it so much as starts winding a won fight down, which is what keeps
## a bandit contact, a bounty camp's boss and an Arena round's own last man
## all reading as the same held beat rather than three different lengths of
## pause. See [method WorldMapCombatBridge._on_combat_cleared].

## Group this joins, so anything can find the one Kill Cam in the world
## without a path across a scene it is not a child of - the same convention
## [TravelLetterbox] and [WorldMapCombatBridge] already use.
const GROUP := &"kill_cam"

## Emitted once the mandatory hold is fully over and the camera has been
## handed back - not on [method trigger] itself, which is the moment the
## camera locks on rather than the moment it lets go. Anything that must wait
## for the whole beat to finish before winding a fight down listens here
## instead of timing a wait of its own - see
## [method WorldMapCombatBridge._on_combat_cleared].
signal ended

@export_group("Nodes")
## The shared cinematic cues board - see [StingerBoard]. Optional: a world
## with none simply plays the lock-on and the hit stop with no Win sound
## under it.
@export var stinger_path: NodePath = ^"../RunHUD/StingerBoard"
## Name [method StingerBoard.play_variant] is asked for the instant the lock-on
## begins.
@export var win_variant: StringName = &"win"
## How much slower the Win sound plays for this cinematic beat than
## [StingerBoard]'s own ordinary pick would give it - 0.25 is "75% slower",
## the dramatic weight the hold asks for. Multiplies whatever pitch
## [method SoundBank._spread_pitch] already rolled for this playback, so the
## existing per-play variation still lives underneath it rather than being
## overwritten - the random selection and the no-repeat rule are untouched,
## only how fast the pick plays.
@export_range(0.05, 1.0) var win_pitch_scale: float = 0.25

@export_group("Lock-on")
## How long the camera stays on the fallen enemy before it is handed back.
## [b]Mandatory - see the class doc.[/b] Three seconds, the same beat for
## every combat type this is triggered from.
@export var hold_time: float = 3.0
## How hard the camera locks on - see [member CameraController.follow_lock_speed].
## Below 0 uses the camera's own default.
@export var lock_speed: float = -1.0
## How gently the camera comes home once the hold is over. Below 0 uses the
## camera's own default.
@export var release_speed: float = -1.0
## How close the camera pushes in on the locked head, as a
## [member CameraController.zoom_multiplier] - 3.0 is the "3x" push
## [WorldMapInteractionCamera]'s own decision framing already uses elsewhere,
## and the same number this asks for.
@export var head_zoom_multiplier: float = 3.0

@export_group("Weight")
## Whether a hit stop is asked for as the moment lands, on top of the lock-on.
@export var uses_hit_stop: bool = true
## How long the world holds still for, in real seconds - see [HitStop]. Kept
## well inside [member HitStop.max_duration]'s own safety ceiling.
@export var hit_stop_time: float = 0.09

var _active: bool = false
var _timer: SceneTreeTimer
## Whether this trigger pushed the zoom in, and therefore owes a restore on
## release - set alongside the follow so [method _release] never restores a
## multiplier it never actually changed.
var _zoomed: bool = false
## What the arena was resting at before the push-in, so [method _release]
## hands the view back to the place's own zoom rather than to 1.
var _zoom_multiplier_saved: float = 1.0


## The Kill Cam in this world, or null when it has none - which every caller
## reads as "the moment is not going to get a camera for it, but the fight
## still ends exactly as it already does".
static func get_active(from_node: Node) -> KillCam:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as KillCam


func _enter_tree() -> void:
	add_to_group(GROUP)


func is_active() -> bool:
	return _active


## Plays the moment out over [param subject] - the enemy whose death just
## ended the fight. Null or an already-freed subject still plays the Win
## sound and the hit stop; it is only the camera lock-on that has nothing to
## look at.
func trigger(subject: Node2D = null) -> void:
	if _active:
		return
	_active = true

	_play_win()
	if uses_hit_stop:
		HitStop.request(self, hit_stop_time)

	var camera := CameraController.get_active(self)
	var target := _resolve_head(subject)
	_zoomed = false
	if camera != null and target != null and is_instance_valid(target):
		camera.follow(target, lock_speed)
		# Immediate, not eased - see the class doc. This has to be the shot on
		# the very frame the kill is confirmed, not one the camera is still
		# crossing towards a few frames later.
		_zoom_multiplier_saved = camera.get_zoom_multiplier()
		camera.set_zoom_multiplier(head_zoom_multiplier, true)
		_zoomed = true

	var seconds := maxf(hold_time, 0.0)
	if seconds <= 0.0:
		_release(camera)
		return

	# Real time and process-always: several of this Kill Cam's own callers -
	# a boss falling, the player's own death sequence running alongside a
	# routed field - already hold the tree in slow motion or paused menus at
	# the moment a final kill can land, and the hold must not stretch or
	# freeze with them.
	_timer = get_tree().create_timer(seconds, true, false, true)
	_timer.timeout.connect(_on_hold_finished.bind(camera))


func _on_hold_finished(camera: CameraController) -> void:
	_release(camera)


func _release(camera: CameraController) -> void:
	if camera != null and is_instance_valid(camera):
		if camera.get_follow_subject() != null:
			camera.release_follow(release_speed)
		if _zoomed:
			camera.set_zoom_multiplier(_zoom_multiplier_saved)
	_zoomed = false
	_active = false
	ended.emit()


## The subject's own head, if it has one. [code]HeadAim/Head[/code] is the
## same child every enemy already carries for aiming and appearance - see the
## class doc - so this is a lookup, not a new convention. Falls back to the
## subject itself for anything built without one, or for a null/freed
## subject, which is exactly how [method trigger] framed it before there was
## a head to reach for.
func _resolve_head(subject: Node2D) -> Node2D:
	if subject == null or not is_instance_valid(subject):
		return subject
	var head := subject.get_node_or_null(^"HeadAim/Head") as Node2D
	return head if head != null else subject


func _play_win() -> void:
	var stinger := _resolve_stinger()
	if stinger == null:
		return
	var voice := stinger.play_variant(win_variant)
	if voice != null:
		voice.pitch_scale *= win_pitch_scale


func _resolve_stinger() -> StingerBoard:
	var named := get_node_or_null(stinger_path) as StingerBoard
	return named if named != null else StingerBoard.get_active(self)
