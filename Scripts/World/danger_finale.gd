class_name DangerFinale
extends Node
## The last man of a Danger, played out: his head comes off, the world drops to
## half speed, and the camera goes with the head while it rolls.
##
## [b]It is only ever the last one.[/b] Every other man in a Danger dies exactly as
## he always has - this listens for a death and, unless the ambush has nobody left
## standing and nobody left to come, does nothing at all. Which makes the whole
## effect free: no enemy is modified, no death is intercepted, and switching
## [member enabled] off returns the ending the search had before this existed.
##
## [b]And only in Trouble.[/b] The one thing that arms it is [DangerDirector] being
## in the middle of a fight, so an ambush on the road, an arena round and the mini
## boss are untouched - they share the same enemies, the same deaths and the same
## ambush director, and none of them comes through here.
##
## Nothing about the presentation is built here either. Each half is the system
## that already does it, asked:
##
##   [codeblock]
##   the head    EnemyHeadPop / DeathDebris   already thrown, already rolling
##   the speed   Engine.time_scale            the dial the hit stop and the
##                                            coin's slow motion already turn
##   the camera  CameraController.follow      the lock-on the struck coin uses
##   the question TravelEventMenu             the CONTINUE / STOP screen already asked
##   [/codeblock]
##
## The beat is: the head separates, the world halves, the camera crosses onto the
## head and pushes in, and [member decision_delay] seconds later the search's own
## question is asked over the top of it - the head still rolling behind the screen,
## because waiting for it to settle would put a hole in the middle of the ending.
## Answering restores everything.
##
## [b]The question does not stop the world, it lets it run down.[/b] Every other menu
## in the game freezes the tree on the frame it opens; this one is deliberately not
## allowed to - see [method _suppress_menu_pause] - because a screen that snapped the
## half-speed ending to a dead stop would throw away the one thing the presentation is
## for. Instead the scale slides from [member slow_scale] to [member freeze_scale]
## over [member freeze_time] real seconds, and only when it has run all the way out is
## the tree frozen behind it. The screen itself is unaffected throughout: the HUD runs
## on [constant Node.PROCESS_MODE_ALWAYS] and buttons answer to events rather than to
## the clock, so the two buttons are live for the whole of the slide and after it.
##
## [b]The world is always handed back.[/b] The speed and the camera are put back by
## every way out there is - the answer, the search ending under it, a death, the
## scene being torn down, and a deadline of last resort - so there is no path
## through this that can leave the game at half speed or the camera on a head.

## Emitted as the head comes off and the presentation takes over, with the piece
## now carrying it.
signal head_separated(head: DeathDebris)
## Emitted when the presentation has had its time and the search may ask its
## question. [b]It always fires[/b], including when the ending is abandoned part
## way through, so a caller waiting on it can never be left waiting.
signal presentation_finished()

## Group the finale joins, so anything can find it without a path.
const GROUP := &"danger_finale"

## Whether the last man is played out at all. Off, a Danger ends exactly as it did
## before this existed: the ambush clears and the question is asked after
## [member DangerDirector.end_delay].
@export var enabled: bool = true

@export_group("Nodes")
## The search this belongs to. What arms the whole thing: no search running means
## no last man, whatever else is being fought.
@export var danger_path: NodePath = ^"../DangerDirector"
## The ambush a Danger is fought through, asked the one question that matters -
## whether the man who just died was the last of it.
@export var ambush_path: NodePath = ^"../AmbushDirector"
## The world's spawner, listened to so every enemy built for a Danger is followed
## to its death. [b]Nothing is written to the enemies[/b] - see
## [method _on_enemy_spawned].
@export var spawner_path: NodePath = ^"../EnemySpawner"
## The CONTINUE / STOP screen, watched only so the world is put back on the frame
## the player answers. Optional; without one the ending is closed by the search
## itself.
@export var question_path: NodePath = ^"../RunHUD/TravelEventMenu"

@export_group("Timing")
## How long the presentation runs before the search is told it may ask its
## question, in [b]real[/b] seconds - so the three seconds are three seconds
## however slow the world has been made.
@export var decision_delay: float = 3.0
## How long a head is waited for after the last man goes down, in real seconds.
##
## The separation is deferred by a frame - see [method EnemyHeadPop._separate] - so
## the ending is claimed on the death and begun on the head, and this is the floor
## underneath that: a body that turns out to have no head to lose releases the
## search rather than leaving it waiting on a piece that is never coming.
@export var head_wait_time: float = 0.5
## Longest the presentation may hold the world, in real seconds, however the answer
## is arrived at. A guard rather than a tuning value - nothing should ever reach it
## - and what makes certain the game cannot be left at half speed by a question
## nobody answered.
@export var max_hold_time: float = 30.0

@export_group("The slow motion")
## What the world's speed drops to as the head comes off. 0.5 is half.
##
## [b]It is [member Engine.time_scale], not [WorldSlowdown].[/b] The subject of the
## shot is a rolling head, which is a [DeathDebris] rather than a character, and
## the slowdown that scales how fast men walk would leave it rolling at full speed
## through a world that had slowed around it. This is the same dial the hit stop
## and the coin's slow motion turn, asserted the same way - see
## [method _advance_slowdown].
@export_range(0.05, 1.0) var slow_scale: float = 0.5

@export_group("The decision")
## How long the world takes to run down once the question is up, in [b]real[/b]
## seconds - so ten seconds are ten seconds however slow the world has been made.
##
## [b]It is a slide, not a stop.[/b] The screen comes up over a world still moving at
## [member slow_scale], and that speed is walked down to nothing across this, so the
## player watches the ending settle while they decide instead of being cut off from it
## the instant the buttons appear. 0 goes straight to the standstill, which is the
## snap this exists to avoid.
@export var freeze_time: float = 10.0
## What the slide comes to rest at. 0 is a standstill.
@export_range(0.0, 1.0) var freeze_scale: float = 0.0
## Shape of the slide. 1 is even; above 1 holds the speed longer and drops it late,
## below 1 sheds it early and crawls the rest of the way.
@export_range(0.1, 4.0) var freeze_ease: float = 1.0
## Whether the tree is frozen outright once the slide has run all the way out.
##
## On, and it is what "and then it is held" means: a world at a time scale of zero is
## already still, and this puts it in the same state every other menu in the game puts
## it in, so nothing downstream has to know the difference. The screen itself is
## untouched by it - see the note at the top of this file.
@export var freezes_tree: bool = true
## How long the world takes to come back up to speed once the question is answered, in
## real seconds. Short, but not nothing: the answer restores the world rather than
## snapping it back, which is the same courtesy the slide showed on the way in.
@export var recover_time: float = 0.45

@export_group("The camera")
## Whether the camera crosses onto the head and follows it.
@export var follows_head: bool = true
## How hard it locks on. This is the camera's own [method CameraController.follow]
## speed for this one lock-on, so nothing about the camera is retuned for it.
@export var follow_speed: float = 9.0
## How quickly it comes home to the player afterwards.
@export var return_speed: float = 6.0
## How far it pushes in, as a fraction of the resting zoom: 1 is twice as close.
##
## [b]It is an impulse on a channel of its own[/b], which is what keeps it off
## everything else the camera is doing - a place's resting zoom, the shotgun's
## punch and the hit reaction all still work through it, and the push is removed by
## being driven back to nothing rather than by anything being overwritten.
@export var zoom_amount: float = 1.0
@export var zoom_in_time: float = 0.35
@export var zoom_out_time: float = 0.5
@export var zoom_channel: StringName = &"finale"
## How loudly the push speaks against the other channels running at the same time.
## High, because this is what the frame is about.
@export var zoom_priority: int = 20

@export_group("The head")
## Start of the name [EnemyHeadPop] gives the piece carrying the head, used to tell
## it from the knife thrown clear on the same blast. Matched on the start rather
## than in full because a second head already lying on the field makes the engine
## number the name.
@export var head_piece_name: StringName = &"SeveredHead"
## How long the head takes to fade once the presentation is over, in seconds. It is
## held for the whole of the ending - see [method _hold_head] - and this is what
## finally lets it go, so a search of ten Dangers does not end surrounded by ten
## preserved heads.
@export var head_fade_time: float = 0.9

var _playing: bool = false
## Whether the last man is down and his head is expected. The presentation is
## claimed here, a frame before it can actually begin, because the search asks
## whether it is being played out on the same frame the ambush clears.
var _waiting_for_head: bool = false
## Whether the search has already been released. Kept apart from
## [member _playing] because the question is asked while the presentation is still
## on screen, and the release must only ever happen once.
var _handed_over: bool = false
var _head: DeathDebris
var _head_pop: EnemyHeadPop
var _camera: CameraController
## Whether this node is the one currently holding the world's speed down, so it can
## only ever put back a scale it took.
var _slowing: bool = false
var _restore_scale: float = 1.0
## Whether the question is up and the world is running down towards its standstill.
var _freezing: bool = false
## Whether the slide has run all the way out and the world is being held still.
var _frozen: bool = false
## When the slide began, on the real clock.
var _freeze_started_msec: int = 0
## Whether this node is the one holding the tree frozen, so it can only ever hand back
## a pause it took.
var _paused_tree: bool = false
## Whether the question's own freeze has been taken off it for the length of the
## ending, and what it was set to before - so a road ambush asked on the same screen
## afterwards still stops the world the way it always did.
var _menu_pause_taken: bool = false
var _menu_pause_was: bool = true
var _recover: Tween
## When the presentation began, on the real clock - untouched by the very scale it
## is changing.
var _started_msec: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# Runs while the tree is paused, because the question pauses it - so the
	# deadline of last resort still counts down behind an unanswered screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	# Wired a frame late for the same reason the search wires the waggon that way:
	# there is no ordering of the world's children that guarantees the spawner and
	# the directors have readied before this one does.
	_wire.call_deferred()


## The finale in this world, or null when it has none - which every caller reads as
## "a Danger here ends the way it always did".
static func get_active(from_node: Node) -> DangerFinale:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as DangerFinale


## Whether the ending is being played out - the last man down, or his head already
## rolling. [b]Asked by [DangerDirector] on the frame a Danger clears[/b], to know
## whether to wait for this rather than asking its question on its own beat.
func is_playing_out() -> bool:
	return _playing or _waiting_for_head


## Whether the head is on screen and the world is slowed right now.
func is_playing() -> bool:
	return _playing


## The head being followed, or null. For a readout or a test.
func get_head() -> DeathDebris:
	return _head


## Whether the question is up and the world is running down behind it.
func is_freezing() -> bool:
	return _freezing


## Whether the slide has run all the way out and the world is being held still.
func is_frozen() -> bool:
	return _frozen


## How far through the run-down the world is, 0 to 1. 0 whenever the question is not
## up. For a readout or a test.
func get_freeze_progress() -> float:
	if not _freezing:
		return 0.0
	if freeze_time <= 0.0:
		return 1.0
	var spent := float(Time.get_ticks_msec() - _freeze_started_msec)
	return clampf(spent / (freeze_time * 1000.0), 0.0, 1.0)


## What the world's speed should be this frame: the held half speed while the ending
## plays, and the slide down to a standstill once the question is up.
##
## [b]It is worked out rather than stored[/b], for the reason the hold itself is
## asserted every frame - see [method _advance_slowdown] - so a hit stop that borrows
## the dial in the middle of the run-down hands it back to the right value rather than
## to wherever the slide happened to be when it took it.
func get_current_scale() -> float:
	var held := maxf(slow_scale, 0.0)
	if not _freezing:
		return held
	var along := pow(get_freeze_progress(), maxf(freeze_ease, 0.01))
	return lerpf(held, clampf(freeze_scale, 0.0, 1.0), along)


func _wire() -> void:
	if not is_inside_tree():
		return

	var danger := _resolve_danger()
	if danger != null and not danger.sequence_ended.is_connected(_on_sequence_ended):
		danger.sequence_ended.connect(_on_sequence_ended)

	var spawner := _resolve_spawner()
	if spawner != null and not spawner.spawned.is_connected(_on_enemy_spawned):
		spawner.spawned.connect(_on_enemy_spawned)


# --- Finding the last man ------------------------------------------------------

## Every enemy the world builds is followed to its death, and only followed: no
## property is written, no component is added and nothing about the body differs
## from one built for an arena round. Which of those deaths matters is decided
## afterwards, in [method _on_enemy_died].
func _on_enemy_spawned(enemy: Node2D) -> void:
	if not enabled or enemy == null:
		return
	if not _searching():
		return

	var health := _find_health(enemy)
	if health == null:
		return
	health.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)


## A man of a Danger is down. The ending is claimed only if he was the last of it:
## nobody else standing and nobody still owed.
##
## [b]The counts are read before the ambush has moved them.[/b] This is connected
## as the enemy is built and the ambush connects its own listener after that call
## returns, so on the frame of a death the man dying is still counted among the
## living - which is why the last of them is [code]alive == 1[/code] rather than
## none.
func _on_enemy_died(enemy: Node2D) -> void:
	if not enabled or _playing or _waiting_for_head:
		return
	if not _searching():
		return

	var danger := _resolve_danger()
	if danger == null or danger.get_state() != DangerDirector.State.FIGHTING:
		return

	var ambush := _resolve_ambush()
	if ambush == null or not ambush.is_running():
		return
	if ambush.get_enemies_owed() > 0 or ambush.get_enemies_alive() > 1:
		return

	var pop := _find_head_pop(enemy)
	if pop == null:
		# A body with nothing to lose. The Danger ends on its own beat, which is the
		# ending this had before there was a presentation.
		return

	_waiting_for_head = true
	# Cleared as the ending is claimed rather than as it begins, so that a claim
	# which never turns into a presentation - a body with no head, a search called
	# off between the two - still leaves the release owed exactly once.
	_handed_over = false
	_head_pop = pop
	pop.piece_separated.connect(_on_piece_separated)

	var guard := get_tree().create_timer(maxf(head_wait_time, 0.05), true, false, true)
	guard.timeout.connect(_on_head_missed)


## A piece has come off the last man. The knife comes off on the same blast and is
## ignored; the head is what the presentation is about.
func _on_piece_separated(piece: DeathDebris) -> void:
	if not _waiting_for_head or piece == null or not is_instance_valid(piece):
		return
	if head_piece_name != &"" and not String(piece.name).begins_with(String(head_piece_name)):
		return
	_begin(piece)


## The head never came. The search is released so it can ask its question on its
## own beat rather than waiting on a piece that is not coming.
func _on_head_missed() -> void:
	if not _waiting_for_head:
		return
	_stop_waiting()
	_release_search()


func _stop_waiting() -> void:
	_waiting_for_head = false
	if _head_pop != null and is_instance_valid(_head_pop) \
			and _head_pop.piece_separated.is_connected(_on_piece_separated):
		_head_pop.piece_separated.disconnect(_on_piece_separated)
	_head_pop = null


# --- The presentation ----------------------------------------------------------

## The head is off. Everything happens on this frame - the slowdown, the lock-on
## and the push - so the separation and the presentation are one event rather than
## a death followed by a camera move.
func _begin(head: DeathDebris) -> void:
	_stop_waiting()
	_playing = true
	_handed_over = false
	_freezing = false
	_frozen = false
	_head = head
	_started_msec = Time.get_ticks_msec()

	_hold_head()
	_take_camera()
	_take_speed()
	set_process(true)

	head_separated.emit(head)

	var timer := get_tree().create_timer(maxf(decision_delay, 0.0), true, false, true)
	timer.timeout.connect(_hand_over)


## Timed off the real clock rather than off [param _delta], which is already
## multiplied by the scale this is holding down - counting with that would make the
## deadline last twice as long as it says.
func _process(_delta: float) -> void:
	# The deadline guards the part of the ending nobody can end - the head rolling, the
	# camera on it - and stops counting the moment the question is up. From there an
	# unanswered screen is the player's own time, held exactly as every other menu in
	# the game holds the world, and a guard that tore the ending down underneath it
	# would hand the world back at full speed with the buttons still on screen.
	if not _handed_over and max_hold_time > 0.0 \
			and Time.get_ticks_msec() - _started_msec >= int(max_hold_time * 1000.0):
		_finish()
		return
	_advance_slowdown()
	_advance_freeze()


## Holds the world at [member slow_scale].
##
## [b]The scale is written every frame rather than once[/b], and for the reason the
## coin's slow motion writes it that way: [HitStop] owns the same dial for the
## length of a freeze and puts back the value it found on the way out, and the two
## are processed in whatever order the scene puts them in - so asserting it each
## frame is what makes the hand-over correct without either node knowing about the
## other. A stop still gets its freeze; this simply takes the dial back afterwards.
func _advance_slowdown() -> void:
	var stop := HitStop.get_active(self)
	if stop != null and stop.is_stopping():
		return

	_slowing = true
	Engine.time_scale = get_current_scale()


## The last step of the run-down: a world that has reached its standstill is held
## there properly, so the frozen half of the decision is the same freeze the rest of
## the game's menus use rather than a time scale of zero that nothing else knows
## about.
func _advance_freeze() -> void:
	if not _freezing or _frozen or not freezes_tree:
		return
	if get_freeze_progress() < 1.0:
		return

	_frozen = true
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	_paused_tree = true
	tree.paused = true


## The scale the world is put back to. Captured before anything is changed, and
## read as normal speed while a hit stop is running, so an ending that begins on
## the same frame as a freeze cannot restore the freeze.
func _take_speed() -> void:
	var stop := HitStop.get_active(self)
	if stop != null and stop.is_stopping():
		_restore_scale = 1.0
	else:
		_restore_scale = Engine.time_scale
	_advance_slowdown()


## The world handed back. [param smoothly] walks it up over [member recover_time]
## instead of writing the value, which is what an answer does; every other way out -
## a scene torn down, a search called off in the same frame - puts it back at once,
## because there is nobody left to watch it.
func _restore_speed(smoothly: bool = false) -> void:
	if not _slowing:
		return
	_slowing = false

	if _recover != null and _recover.is_running():
		_recover.kill()

	var from := Engine.time_scale
	if not smoothly or recover_time <= 0.0 or is_equal_approx(from, _restore_scale):
		Engine.time_scale = _restore_scale
		return

	# Ignores the very scale it is writing, which is the whole reason it can start from
	# a standstill at all, and runs from this node so it survives the tree being frozen
	# again by the walk to the next Danger.
	_recover = create_tween().set_ignore_time_scale(true)
	_recover.tween_method(_write_time_scale, from, _restore_scale, maxf(recover_time, 0.0001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _write_time_scale(value: float) -> void:
	Engine.time_scale = maxf(value, 0.0)


## The world put back at full speed on the spot, whatever the ending had left it at.
##
## [b]It is this node's own recovery finished early, not a second hand on the dial.[/b]
## [method _finish] walks the world back up over [member recover_time], which is right
## while the player is still looking at the last man - but the search sets off for the
## next Danger on the frame it is answered, and none of that recovery may be spent
## underneath the walk: the black closing over it, the man on foot, the hour turning
## over him and the fight the black lifts on would every one of them be drawn at
## whatever the run-down had reached. So the search asks for the rest of it here, on
## the frame the crossing is entered - see [method DangerDirector._walk_on].
##
## Full speed rather than the scale found on the way in, and deliberately: an ending
## that opened over somebody else's slow motion - the coin's, a hit stop's - captured
## that as the value to hand back, and giving it to the next Danger would leave it
## there for good, because the system it belonged to is long finished and has nothing
## left to take it off again.
func hand_back_speed() -> void:
	if _recover != null and _recover.is_running():
		_recover.kill()
	_slowing = false
	_restore_scale = 1.0
	Engine.time_scale = 1.0


## Centres the camera on the head and pushes in on it.
##
## The push is handed over as one long hold rather than a measured step, because
## what ends it is the player's answer rather than a duration - [method _finish]
## replaces the hold with the way out. The camera's resting spot, its limits and
## every other channel are untouched throughout.
func _take_camera() -> void:
	_camera = CameraController.get_active(self)
	if _camera == null:
		return

	if follows_head and _head != null and is_instance_valid(_head):
		_camera.follow(_head, follow_speed)

	if is_zero_approx(zoom_amount):
		return
	_camera.zoom_impulse([
		Vector2(zoom_amount, maxf(zoom_in_time, 0.0001)),
		Vector2(zoom_amount, maxf(max_hold_time, 0.0)),
	], zoom_channel, zoom_priority)


func _release_camera() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = null
		return
	_camera.release_follow(return_speed)
	if not is_zero_approx(zoom_amount):
		_camera.zoom_impulse(
			[Vector2(0.0, maxf(zoom_out_time, 0.0001))], zoom_channel, zoom_priority)
	_camera = null


## Keeps the head on the field for as long as the ending lasts.
##
## [b]It is the piece's own switch, not a second lifetime.[/b] A [DeathDebris] with
## no fade time lies where it stopped for good - see [member DeathDebris.fade_time]
## - so preserving the head is turning that off, and letting it go afterwards is
## [method _dismiss_head] fading it out by hand. Nothing about how any other piece
## of any other corpse leaves is touched.
func _hold_head() -> void:
	if _head == null or not is_instance_valid(_head):
		return
	_head.fade_time = 0.0


## Lets the preserved head go once the ending is over. Faded rather than freed on
## the spot, so the last thing the player saw does not blink out of the world, and
## driven from this node so that it still runs while the tree is paused behind the
## question.
func _dismiss_head() -> void:
	var head := _head
	_head = null
	if head == null or not is_instance_valid(head):
		return

	if head_fade_time <= 0.0:
		head.queue_free()
		return

	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(head, "modulate:a", 0.0, head_fade_time)
	tween.tween_callback(head.queue_free)


# --- Handing the world back ----------------------------------------------------

## The presentation has had its time. The search is told it may ask, and the world
## is left exactly as it is - slowed, and on the head - because the question is
## meant to come up over the ending rather than after it.
func _hand_over() -> void:
	if not _playing:
		return
	# In this order, and it matters: the question's own freeze is taken off it and the
	# run-down begun *before* the search is told it may ask, because the search asks on
	# the very next line and a screen still carrying its freeze would stop the world on
	# the frame it appeared.
	_suppress_menu_pause()
	_begin_freeze()
	_watch_for_the_answer()
	_release_search()


func _begin_freeze() -> void:
	if _freezing:
		return
	_freezing = true
	_frozen = false
	_freeze_started_msec = Time.get_ticks_msec()
	_advance_slowdown()


## The run-down abandoned and the world let go of, whether it got as far as the
## standstill or not.
func _end_freeze() -> void:
	_freezing = false
	_frozen = false
	if not _paused_tree:
		return
	_paused_tree = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false


## Takes the question's own freeze off it for the length of the ending.
##
## [b]It is the one thing here that reaches into another system[/b], and it is a
## borrow rather than a change: [member TravelEventMenu.pauses_game] is put back
## exactly as it was found in [method _finish], so a gang on the road asked on the
## same screen five minutes later still stops the world the instant it opens. The
## world is not left running either - this node holds it instead, and more carefully.
func _suppress_menu_pause() -> void:
	if _menu_pause_taken:
		return
	var screen := _resolve_question()
	if screen == null:
		return
	_menu_pause_taken = true
	_menu_pause_was = screen.pauses_game
	screen.pauses_game = false


func _restore_menu_pause() -> void:
	if not _menu_pause_taken:
		return
	_menu_pause_taken = false
	var screen := _resolve_question()
	if screen != null:
		screen.pauses_game = _menu_pause_was


## Everything back where it was found. Every way out of the ending comes through
## here, and it can only ever run once.
func _finish() -> void:
	if not _playing:
		return
	_playing = false
	set_process(false)

	_end_freeze()
	_restore_speed(true)
	_release_camera()
	_dismiss_head()
	_drop_the_answer()
	_restore_menu_pause()
	_release_search()


## Answering the question is what ends the ending. Watched rather than waited for,
## because a Danger at the top of the ladder is never asked at all - see
## [member DangerDirector.final_danger] - and that one is closed by the search
## ending under it instead.
func _watch_for_the_answer() -> void:
	var screen := _resolve_question()
	if screen != null and not screen.answered.is_connected(_on_answered):
		screen.answered.connect(_on_answered)


func _drop_the_answer() -> void:
	var screen := _resolve_question()
	if screen != null and screen.answered.is_connected(_on_answered):
		screen.answered.disconnect(_on_answered)


func _on_answered(_carry_on: bool) -> void:
	_finish()


## The search is over - stopped, finished, or the player killed under it. Whatever
## was still being held is put back, and a presentation that had not yet released
## the search releases it now.
func _on_sequence_ended(_dangers_cleared: int) -> void:
	var claimed := _playing or _waiting_for_head
	_stop_waiting()
	if _playing:
		_finish()
		return
	# Only an ending that was actually claimed owes the search anything. A search
	# that ended without one - every Danger before this milestone, a death mid-fight
	# - is left to close on its own beat.
	if claimed:
		_release_search()


## Says once, and only once, that the search may carry on.
func _release_search() -> void:
	if _handed_over:
		return
	_handed_over = true
	presentation_finished.emit()


## Nothing is left slowed behind us: a world torn down mid-ending - a death, a
## reload - would otherwise hand the next round a world at half speed, because the
## time scale is global state and outlives every scene.
func _exit_tree() -> void:
	_end_freeze()
	_restore_speed(false)
	_restore_menu_pause()


# --- Looking things up ---------------------------------------------------------

## Whether a search is running at all, which is the whole of "this is Trouble".
func _searching() -> bool:
	var danger := _resolve_danger()
	return danger != null and danger.is_running()


func _resolve_danger() -> DangerDirector:
	var named := get_node_or_null(danger_path) as DangerDirector
	return named if named != null else DangerDirector.get_active(self)


func _resolve_ambush() -> AmbushWaveDirector:
	var named := get_node_or_null(ambush_path) as AmbushWaveDirector
	return named if named != null else AmbushWaveDirector.get_active(self)


func _resolve_spawner() -> EnemySpawner:
	return get_node_or_null(spawner_path) as EnemySpawner


func _resolve_question() -> TravelEventMenu:
	var named := get_node_or_null(question_path) as TravelEventMenu
	return named if named != null else TravelEventMenu.get_active(self)


func _find_health(enemy: Node) -> Health:
	for node: Node in enemy.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


## Found by type rather than by a fixed child name, the same way the ambush finds
## an enemy's retreat: a body that keeps its components somewhere else still loses
## its head properly.
func _find_head_pop(enemy: Node) -> EnemyHeadPop:
	for node: Node in enemy.find_children("*", "EnemyHeadPop", true, false):
		var pop := node as EnemyHeadPop
		if pop != null:
			return pop
	return null
