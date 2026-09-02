class_name LoadingCurtain
extends CanvasLayer
## The curtain a heavy scene change hides behind: up first, gone last.
##
## [b]The bug this exists to fix.[/b] Before this, STORY called
## [method SceneTree.change_scene_to_file] directly - the menu simply sat there,
## unresponsive, for however long Godot took to load and instantiate the whole of
## [code]World.tscn[/code], and only then did anything appear. This node inverts
## that order: it is shown, and given a frame to actually draw, [i]before[/i] the
## expensive part begins, so what the player sees the instant they press the
## button is the curtain going up, not the game hanging.
##
## [b]It is an autoload rather than a per-scene node[/b] - unlike [ScreenFade] and
## [TravelLoading], which are found by group and rely on both the scene being left
## and the scene arriving each carrying one of their own. A curtain that has to
## cover a scene which does not exist yet cannot be that scene's own child, so this
## is registered the way [code]RunSession[/code] and [code]MusicStates[/code] are -
## a permanent child of the tree's own root - and it is simply never torn down by
## whatever scene change it is covering.
##
## [b]The load is threaded, the cutover is not.[/b] [method ResourceLoader.load_threaded_request]
## does the actual reading and parsing of the scene file in the background, and
## this polls [method ResourceLoader.load_threaded_get_status] for real progress -
## never an invented number - while [member min_display_time] is held open by an
## ordinary real-time timer, the same [code]process_always[/code] shape
## [KillCam] and [MusicStateBoard] already use so it keeps counting down through
## whatever the tree is doing. Only once both are true - the resource is actually
## loaded [i]and[/i] the minimum has actually elapsed - does
## [method SceneTree.change_scene_to_packed] run, which is the one part of this
## Godot cannot do off the main thread; everything this class can front-load, it
## does.
##
## [b]The gate on gameplay is the tree's own pause, not a bespoke lock.[/b] The
## instant the new scene is current, this pauses the tree - the same blanket
## "nothing simulates" every other frozen-behind-a-menu moment in the game already
## means - and only unpauses once the curtain is about to lift. A player who cannot
## move, an enemy that cannot act and a clock that will not advance all fall out of
## that one flag rather than three separate guards.
##
## [b]It draws itself onto the existing film pass rather than bringing its own.[/b]
## [member CanvasLayer.layer] is deliberately below
## [code]FilmPostProcess[/code]'s own layer [code]3[/code] - see that class's own
## notes on why a layer, not a z-index, is what actually decides draw order here -
## so whichever [code]FilmPostProcess[/code] happens to be alive in the scene
## currently on screen (the title's own, and then the world's own the instant it
## exists) keeps compositing over this exactly as it does over everything else,
## and nothing here ever asks for a second pass of that shader.

## Group used by [method get_active], the same convention every other
## found-rather-than-wired system in the project already follows.
const GROUP := &"loading_screen"

## How long the curtain stays up at minimum, in seconds, however fast the real
## load turns out to be - see the class doc.
@export var min_display_time: float = 2.0
## How long the curtain takes to lift once both the load and the minimum are
## done.
@export var reveal_time: float = 0.35
## The bus a transition stinger handed to [method begin] plays through.
@export var stinger_bus: StringName = &"Game"

@export_group("Nodes")
@export var backdrop_path: NodePath = ^"Backdrop"
@export var caption_path: NodePath = ^"Center/Body/Caption"
@export var bar_path: NodePath = ^"Center/Body/Bar"
@export var stinger_player_path: NodePath = ^"Stinger"

@onready var _backdrop: Control = get_node_or_null(backdrop_path) as Control
@onready var _caption: Label = get_node_or_null(caption_path) as Label
@onready var _bar: ProgressBar = get_node_or_null(bar_path) as ProgressBar
@onready var _stinger: AudioStreamPlayer = get_node_or_null(stinger_player_path) as AudioStreamPlayer

var _scene_path: String = ""
var _loading: bool = false
var _resource_ready: bool = false
var _min_time_elapsed: bool = false
var _switched: bool = false
## Set only while a [method begin_transition] is running, rather than a real
## [method SceneTree.change_scene_to_packed] - see that method's own doc.
var _manual_ready: Callable


func _ready() -> void:
	add_to_group(GROUP)
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)


## The curtain any system should talk to. Null means this build has none, which a
## caller reads as "no cover is available" and is expected to fall back to an
## ordinary [method SceneTree.change_scene_to_file].
static func get_active(from_node: Node) -> LoadingCurtain:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as LoadingCurtain

func is_loading() -> bool:
	return _loading


## Raises the curtain and begins loading [param scene_path] in the background.
## [param caption] is written on the screen while it is up; [param stinger] plays
## once, immediately, through [member stinger_bus] - the transition cue a caller
## wants heard over the load rather than silence.
func begin(scene_path: String, caption: String = "LOADING", stinger: AudioStream = null) -> void:
	if _loading or scene_path.is_empty():
		return
	_loading = true
	_resource_ready = false
	_min_time_elapsed = false
	_switched = false
	_scene_path = scene_path

	if _caption != null:
		_caption.text = caption
	if _bar != null:
		_bar.value = 0.0
	if _backdrop != null:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true

	if stinger != null and _stinger != null:
		_stinger.stream = stinger
		_stinger.bus = stinger_bus
		_stinger.play()

	# One frame is not always enough for the compositor to actually present what
	# was just drawn - two guarantees the curtain has genuinely been seen before
	# the thread request below starts competing with the main thread for time.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not _loading:
		return

	var err := ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_warning("LoadingScreen: could not start loading %s (%d)." % [scene_path, err])
		# No thread to poll, so the ordinary blocking load is the only way left in -
		# still behind the curtain that is already up, which is what actually
		# mattered to the player.
		_resource_ready = true

	set_process(true)

	var timer := get_tree().create_timer(maxf(min_display_time, 0.0), true, false, true)
	timer.timeout.connect(_on_min_time_elapsed)


## The same curtain, for a transition that never leaves the current scene - a
## Travel Portal's own fast-travel jump across one already-loaded World Map,
## not a real [method SceneTree.change_scene_to_file]. Raised exactly like
## [method begin], held for [param duration] real seconds, and lowered
## through the identical [method _finish] - only the middle differs: instead
## of a threaded scene load, the whole tree is paused the instant the curtain
## is up, [param on_ready] is called once behind it - the caller's own chance
## to move the player and reset anything about the destination, without a
## single frame of it ever being visible or simulated - and only unpaused
## again as [method _finish] begins lowering the curtain. See the class doc's
## own "the gate on gameplay is the tree's own pause, not a bespoke lock": a
## Travel Portal wants the identical guarantee - the player cannot move, the
## World Map does not simulate, no enemy acts - and this is what lets it ask
## for that without a second pause system of its own.
func begin_transition(
		caption: String, duration: float, on_ready: Callable, stinger: AudioStream = null) -> void:
	if _loading:
		return
	_loading = true
	_manual_ready = on_ready
	_scene_path = ""

	if _caption != null:
		_caption.text = caption
	if _bar != null:
		_bar.value = 0.0
	if _backdrop != null:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true

	if stinger != null and _stinger != null:
		_stinger.stream = stinger
		_stinger.bus = stinger_bus
		_stinger.play()

	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not _loading:
		return

	# A steadily filling bar rather than a frozen one, even with no real
	# resource load behind it - "loading/initialization" reads as something
	# happening, the same way the threaded path's own real progress does.
	if _bar != null:
		var fill := create_tween()
		fill.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fill.tween_property(_bar, ^"value", 100.0, maxf(duration, 0.0001))

	get_tree().paused = true

	var hold := get_tree().create_timer(maxf(duration, 0.0), true, false, true)
	await hold.timeout
	if not is_instance_valid(self) or not _loading:
		return

	if _manual_ready.is_valid():
		_manual_ready.call()
	_manual_ready = Callable()

	get_tree().paused = false
	_finish()


func _on_min_time_elapsed() -> void:
	_min_time_elapsed = true
	_maybe_switch()


func _process(_delta: float) -> void:
	if not _loading or _resource_ready:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_scene_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _bar != null and not progress.is_empty():
				_bar.value = clampf(float(progress[0]), 0.0, 1.0) * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			if _bar != null:
				_bar.value = 100.0
			_resource_ready = true
			set_process(false)
			_maybe_switch()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("LoadingScreen: threaded load of %s failed." % _scene_path)
			_resource_ready = true
			set_process(false)
			_maybe_switch()


func _maybe_switch() -> void:
	if _switched or not _resource_ready or not _min_time_elapsed:
		return
	_switched = true
	_switch_now()


func _switch_now() -> void:
	var packed := ResourceLoader.load_threaded_get(_scene_path) as PackedScene
	if packed == null:
		# The threaded path failed outright - the ordinary loader is the fallback
		# so the game still gets where it is going, just without the background
		# read that made the curtain worth timing.
		packed = load(_scene_path) as PackedScene
	if packed == null:
		push_warning("LoadingScreen: %s did not resolve to a scene." % _scene_path)
		_finish()
		return

	get_tree().paused = false
	get_tree().change_scene_to_packed(packed)

	# The swap itself is deferred to the tree's own safe point rather than
	# happening on this line, so the new scene is not current yet - waited out
	# here instead of guessed at, and paused the instant it actually is, so
	# nothing the new scene's own `_ready` starts running gets a single
	# unpaused frame to act in before the curtain lets it.
	await get_tree().process_frame
	if is_instance_valid(self):
		get_tree().paused = true
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	_loading = false
	if _bar != null:
		_bar.value = 100.0

	if reveal_time <= 0.0:
		_lower_curtain()
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.05)
	tween.tween_callback(_lower_curtain)


func _lower_curtain() -> void:
	get_tree().paused = false
	visible = false
	if _backdrop != null:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
