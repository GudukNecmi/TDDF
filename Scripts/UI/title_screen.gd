class_name TitleScreen
extends Control
## The screen the game opens on: the picture, the choices, and nothing else.
##
## [b]It starts games, it does not contain one.[/b] STORY loads the same world scene
## the game has always been - see [member world_scene] - with nothing chosen, so
## [WorldBoot] opens at the base exactly as launching the game used to, and the
## player walks to the rack, the board and the pit as they always did.
##
## [b]FREE RUN is a stub.[/b] It once answered the pit's questions in advance and
## marked the session a Free Run, booting straight into the old endless
## Travel/Trouble/Camp ladder - see [method _on_free_run_pressed]. That ladder is
## gone, and nothing has replaced it yet, so the button stays on screen rather than
## being pulled, but pressing it only shows [member coming_soon_path] and goes
## nowhere. Restoring it is a later phase's job, not a matter of wiring the old call
## back in.
##
## [b]The pointer is the game's own.[/b] [GameCursor] is on this screen with
## [member GameCursor.always_shown] on, because the two things that normally put it
## up - a paused tree and an empty pair of hands - are both questions about a world
## that does not exist yet. The hand still only appears over a real button, which is
## the cursor's own rule and not this screen's.
##
## [b]The music is a state like any other.[/b] This screen simply enters
## [code]&"main_menu"[/code] on [member MusicStateBoard] the moment it is up - the
## same autoload every gameplay system already hands the soundtrack over through -
## and leaving is nothing this screen has to arrange either: the world that comes
## up behind STORY claims its own state the instant it is built (see
## [MusicStateWatcher]), which is an ordinary handover away from
## [code]&"main_menu"[/code] like any other change of state.
##
## [b]STORY hands off to [LoadingCurtain] instead of changing the scene itself.[/b]
## A world scene this size used to freeze the menu for however long Godot took to
## load it, with nothing on screen saying why - seeing the curtain go up first is
## the whole of the fix, and it lives entirely in that one autoload; this screen
## only asks for it. A build with no curtain registered falls back to the plain
## [method SceneTree.change_scene_to_file] this always did, so the game still
## starts either way.

## The world STORY loads.
@export_file("*.tscn") var world_scene: String = "res://Scenes/World/World.tscn"

## How long the "coming soon" message stays up after FREE RUN is pressed, in
## seconds.
@export var coming_soon_seconds: float = 2.0

@export_group("Music & Sound")
## The state [MusicStateBoard] is asked for the moment this screen is up.
@export var music_state: StringName = &"main_menu"
## What plays once, immediately, as STORY is pressed - accompanies the loading
## curtain rather than the ordinary click.
@export var story_transition_stream: AudioStream = preload("res://Sound/Music/Main menu/MainMenu StoryPres.WAV")
## What every other button on this screen plays as it is pressed.
@export var button_click_stream: AudioStream = preload("res://Sound/Music/Main menu/MainMenuButton2.WAV")
## Caption written on the loading curtain while STORY's world is being built.
@export var loading_caption: String = "SADDLING UP"

@export_group("Nodes")
## The choices, so this screen does not have to be wired to each of them one at a
## time.
@export var story_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/StoryButton"
@export var free_run_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/FreeRunButton"
@export var settings_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/SettingsButton"
@export var credits_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/CreditsButton"
@export var exit_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/ExitButton"
## The panel the choices sit on, hidden while the settings or credits are up.
@export var menu_path: NodePath = ^"Layout/Menu"
## The settings panel, raised by SETTINGS and closed by its own BACK.
@export var settings_path: NodePath = ^"Layout/Settings"
## The settings own BACK, which is the only way out of that panel.
@export var back_button_path: NodePath = ^"Layout/Settings/Frame/Body/BackButton"
## The credits panel, raised by CREDITS and closed by its own BACK.
@export var credits_path: NodePath = ^"Layout/Credits"
## The credits own BACK.
@export var credits_back_button_path: NodePath = ^"Layout/Credits/Frame/Body/BackButton"
## The session the choice is written to. Left as the default it is the
## [code]RunSession[/code] autoload.
@export var session_path: NodePath = ^"/root/RunSession"
## The "coming soon" message FREE RUN shows instead of starting anything. Hidden
## until pressed.
@export var coming_soon_path: NodePath = ^"Layout/ComingSoonLabel"
## Where the ordinary click plays from.
@export var button_sound_path: NodePath = ^"ButtonSound"

@onready var _button_sound: AudioStreamPlayer = get_node_or_null(button_sound_path) as AudioStreamPlayer

## Guards the double click: the scene takes a moment to change and the buttons are
## still live while it does.
var _leaving: bool = false
var _coming_soon_timer: SceneTreeTimer


func _ready() -> void:
	_connect(story_button_path, start_story)
	_connect(free_run_button_path, _on_free_run_pressed)
	_connect(settings_button_path, open_settings)
	_connect(credits_button_path, open_credits)
	_connect(exit_button_path, quit)
	_connect(back_button_path, close_settings)
	_connect(credits_back_button_path, close_credits)
	close_settings()
	close_credits()
	_show(coming_soon_path, false)

	# Every button but STORY gets the ordinary click - see [member button_click_stream].
	# STORY's own sound is [member story_transition_stream], played once from
	# [method start_story] instead, so it is never wired here.
	for path: NodePath in [
		free_run_button_path, settings_button_path, credits_button_path,
		exit_button_path, back_button_path, credits_back_button_path,
	]:
		_wire_click_sound(path)

	var board := MusicStateBoard.get_active(self)
	if board != null:
		board.enter(music_state)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _is_visible(credits_path):
		close_credits()
		get_viewport().set_input_as_handled()
	elif _is_visible(settings_path):
		close_settings()
		get_viewport().set_input_as_handled()


## The ordinary game: nothing is chosen, so the world comes up at the base and the
## player sets out from the pit exactly as they always have.
func start_story() -> void:
	if _leaving:
		return
	_leaving = true

	var session := _resolve_session()
	if session != null and session.has_method(&"set_free_run"):
		session.call(&"set_free_run", false)

	var curtain := LoadingCurtain.get_active(self)
	if curtain == null:
		# No curtain in this build - the plain scene change this always did, so the
		# game still starts.
		_leave()
		return

	curtain.begin(world_scene, loading_caption, story_transition_stream)


## FREE RUN, for now. The mode this button used to start no longer exists - see
## the class doc - so this neither touches [RunSession] nor loads a scene; it only
## shows [member coming_soon_path] for [member coming_soon_seconds] and leaves the
## player on this screen.
func _on_free_run_pressed() -> void:
	if _leaving:
		return

	_show(coming_soon_path, true)
	if _coming_soon_timer != null and _coming_soon_timer.timeout.is_connected(_hide_coming_soon):
		_coming_soon_timer.timeout.disconnect(_hide_coming_soon)
	_coming_soon_timer = get_tree().create_timer(coming_soon_seconds)
	_coming_soon_timer.timeout.connect(_hide_coming_soon)


func _hide_coming_soon() -> void:
	_show(coming_soon_path, false)


## Raises the settings and puts the choices away, so only one of the two is ever on
## screen and the buttons underneath cannot be clicked through.
func open_settings() -> void:
	if _leaving:
		return
	_show(menu_path, false)
	_show(settings_path, true)


func close_settings() -> void:
	_show(settings_path, false)
	_show(menu_path, true)


## The credits, raised and closed exactly the way settings are - see
## [method open_settings] - so a second panel behaves like the first rather than
## growing a rule of its own.
func open_credits() -> void:
	if _leaving:
		return
	_show(menu_path, false)
	_show(credits_path, true)


func close_credits() -> void:
	_show(credits_path, false)
	_show(menu_path, true)


func quit() -> void:
	if _leaving:
		return
	get_tree().quit()


func _leave() -> void:
	_leaving = true
	get_tree().change_scene_to_file(world_scene)


func _connect(path: NodePath, to: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null and not button.pressed.is_connected(to):
		button.pressed.connect(to)


## Wires the ordinary click onto one button. Kept to a single connection per
## button - the same guard [method _connect] already uses - so a screen rebuilt or
## asked twice can never stack a second copy of the sound onto a press.
func _wire_click_sound(path: NodePath) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null and not button.pressed.is_connected(_play_button_sound):
		button.pressed.connect(_play_button_sound)


func _play_button_sound() -> void:
	if _button_sound == null or button_click_stream == null:
		return
	_button_sound.stream = button_click_stream
	_button_sound.play()


func _show(path: NodePath, shown: bool) -> void:
	var node := get_node_or_null(path) as CanvasItem
	if node != null:
		node.visible = shown


func _is_visible(path: NodePath) -> bool:
	var node := get_node_or_null(path) as CanvasItem
	return node != null and node.visible


func _resolve_session() -> Node:
	return get_node_or_null(session_path)
