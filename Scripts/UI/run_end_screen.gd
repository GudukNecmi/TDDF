class_name RunEndScreen
extends Control
## The pause menu, opened only by the player pressing Escape.
##
## It used to open itself when the run's clock hit zero. It no longer listens to
## the wave manager at all: the clock running out now just stops spawning and
## hands the arena over to the blood-collection phase, and the run keeps playing.
## Nothing but [member open_action] can raise this menu, so it can never
## interrupt a collection the player is part way through.
##
## It freezes the whole tree rather than switching individual systems off, so
## enemies, pellets, casings, the weapon, blood in mid-air and the spawner all
## hold exactly where they were. The blur underneath samples that frozen frame.
##
## Blood already banked is not this screen's business. [BloodWallet] is an
## autoload, so it survives the scene reload "Next Run" does - starting a new run
## keeps the total and carries on adding to it.

## Action that opens and closes the menu. Escape by default.
@export var open_action: StringName = &"pause_menu"
## Manager restarted when the scene is not reloaded. Only used by the
## [member restart_reloads_scene] = false path.
@export var wave_manager_path: NodePath = ^"../../WaveManager"
## Rebuilds the arena for the next run by reloading the world scene, which
## restarts the wave manager through its own auto-start rather than needing a
## second code path for "begin a run". Turn this off to resume the existing
## world in place instead.
@export var restart_reloads_scene: bool = true
## The persistent round counter - the [code]RunProgress[/code] autoload.
##
## [b]Advancing it is what makes NEXT RUN the next round rather than this one
## again.[/b] Everything a round is built from reads off this count: the wave
## manager scales its waves against it, and the day cycle works out the hour from
## it - see [DayClock], which has no clock of its own and simply follows the rounds
## played. So a rebuild that did not move the counter rebuilt the same round, at
## the same hour, with the same waves, which is exactly what it used to do.
@export var progress_path: NodePath = ^"/root/RunProgress"
## Whether the soundtrack crosses over as the next round starts, the same way the
## upgrade screen's own NEXT ROUND does. The arena track carries straight across the
## rebuild and the new round winds it back up from its run-start speed; this only
## takes the base track down where one is playing.
@export var drive_music: bool = true
## Whether opening the menu drags the soundtrack down and closing it lets it back
## up. The music is never stopped: freezing the world muffles it rather than
## silencing it, and it comes back at exactly the speed it was running at before,
## from exactly where it had got to. [MusicDirector] owns all of that - this only
## says when.
@export var ducks_music: bool = true

@export_group("Buttons")
## Paths rather than fixed lookups, so the menu can be relaid out - logo on one
## side, buttons on the other - without the script having to follow it.
##
## Continue is the same [method close] the Escape key already ran, only visible:
## the key stays exactly as it was and the button is a second way to reach it, so
## there is one place the game is resumed rather than two that could drift.
@export var continue_button_path: NodePath = ^"Menu/Buttons/ContinueButton"
@export var next_run_button_path: NodePath = ^"Menu/Buttons/NextRunButton"
@export var exit_button_path: NodePath = ^"Menu/Buttons/ExitButton"

@onready var _manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager
@onready var _progress: RoundCounter = get_node_or_null(progress_path) as RoundCounter
@onready var _continue_button: Button = get_node_or_null(continue_button_path) as Button
@onready var _next_run_button: Button = get_node_or_null(next_run_button_path) as Button
@onready var _exit_button: Button = get_node_or_null(exit_button_path) as Button


func _ready() -> void:
	hide()
	if _continue_button != null:
		_continue_button.pressed.connect(close)
	if _next_run_button != null:
		_next_run_button.pressed.connect(_on_next_run_pressed)
	if _exit_button != null:
		_exit_button.pressed.connect(_on_exit_pressed)


## Escape both opens and closes the menu. The event is marked handled either way,
## so the press that closes the menu cannot also reach the game underneath.
##
## This node's [CanvasLayer] runs with [constant Node.PROCESS_MODE_ALWAYS], which
## is what lets the key still be read once the tree is frozen - otherwise the
## menu could be opened but never dismissed.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(open_action):
		return

	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Deliberately leaves both buttons unfocused. Reload is bound to Space, which is
## also the GUI's accept key, so a focused button would swallow it - pausing
## mid-reload would otherwise restart the run instead.
func open() -> void:
	if visible:
		return
	show()
	_drop_focus()
	_duck_music(true)
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	hide()
	_drop_focus()
	_duck_music(false)
	get_tree().paused = false


## Found by group rather than wired up, the same way every other cross-branch
## lookup in the project is. A scene with no soundtrack simply pauses silently.
func _duck_music(ducked: bool) -> void:
	if not ducks_music:
		return
	var music := MusicDirector.get_active(self)
	if music == null:
		return
	if ducked:
		music.duck_for_pause()
	else:
		music.unduck_after_pause()


## The next round, not this one over again.
##
## The counter is moved before the world is rebuilt, so the arena that comes up is
## round two's: harder waves, and an hour later in the day. Everything that has to
## survive the rebuild is an autoload and is untouched - the blood, the ammunition
## and the count itself - and everything that is rebuilt reads the new round on the
## way up, which is why nothing else here has to be told what round it is.
##
## Restarting the manager in place, for the [member restart_reloads_scene] = false
## path, deliberately does not advance anything: that is a test harness replaying
## the same arena, not the player finishing a round.
func _on_next_run_pressed() -> void:
	hide()
	_drop_focus()
	get_tree().paused = false
	if not restart_reloads_scene:
		if _manager != null:
			_manager.start()
		return

	if _progress != null:
		_progress.advance()

	if drive_music:
		var music := MusicDirector.get_active(self)
		if music != null:
			music.switch_to_arena()

	# Deferred so the reload does not happen part way through delivering this
	# button's own signal.
	get_tree().reload_current_scene.call_deferred()


func _on_exit_pressed() -> void:
	# Unpaused first so the quit is not processed against a frozen tree.
	get_tree().paused = false
	get_tree().quit()


## Dropped for the same reason the menu opens unfocused: a button that kept focus
## would keep eating Space once play resumed. Released at the viewport rather
## than button by button, so a button added later is covered without being listed.
func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
