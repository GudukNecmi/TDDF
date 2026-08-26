class_name TitleScreen
extends Control
## The screen the game opens on: the picture, the four choices, and nothing else.
##
## [b]It starts games, it does not contain one.[/b] Both ways in lead to the same
## world scene the game has always been - see [member world_scene] - so there is no
## second start-up path here and nothing about how a run is built lives on this
## screen. The whole of the difference between the two is a flag on [RunSession] and
## which questions have already been answered by the time the world is built:
##
##   * [b]STORY[/b] hands the world nothing at all. No map is chosen, so [WorldBoot]
##     opens at the base exactly as launching the game used to, and the player walks
##     to the rack, the board and the pit as they always did.
##   * [b]FREE RUN[/b] answers the pit's questions in advance - the map, and its own
##     way in - and marks the session a Free Run, which is what makes [WorldBoot]
##     hand the round to the search instead of to the wave manager and what takes the
##     bottom out of the Danger ladder. See [method DangerDirector.get_final_danger].
##
## Neither of them is a mode this file knows the inside of: it sets the state and
## loads the scene, and everything after that belongs to the world.
##
## [b]The pointer is the game's own.[/b] [GameCursor] is on this screen with
## [member GameCursor.always_shown] on, because the two things that normally put it
## up - a paused tree and an empty pair of hands - are both questions about a world
## that does not exist yet. The hand still only appears over a real button, which is
## the cursor's own rule and not this screen's.

## The world this screen loads, whichever choice is made. One scene for both,
## deliberately: a Free Run is the ordinary world with the search running in it.
@export_file("*.tscn") var world_scene: String = "res://Scenes/World/World.tscn"

## Which map a Free Run is fought on. Left empty the first unlocked map in the
## catalogue is used - the desert - so a later map becoming the opening one is a
## change to the catalogue rather than to this screen.
@export var free_run_map_id: StringName = &""

## Whether a Free Run starts at the chosen map's own way in - see
## [member MapDefinition.entry_region_id]. Off leaves the region unchosen, which the
## world reads as the map's default.
@export var free_run_enters_at_entry_region: bool = true

@export_group("Nodes")
## The four choices, so this screen does not have to be wired to each of them one at
## a time.
@export var story_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/StoryButton"
@export var free_run_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/FreeRunButton"
@export var settings_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/SettingsButton"
@export var exit_button_path: NodePath = ^"Layout/Menu/Frame/Body/Buttons/ExitButton"
## The panel the choices sit on, hidden while the settings are up.
@export var menu_path: NodePath = ^"Layout/Menu"
## The settings panel, raised by SETTINGS and closed by its own BACK.
@export var settings_path: NodePath = ^"Layout/Settings"
## The settings own BACK, which is the only way out of that panel.
@export var back_button_path: NodePath = ^"Layout/Settings/Frame/Body/BackButton"
## The session the choice is written to. Left as the default it is the
## [code]RunSession[/code] autoload.
@export var session_path: NodePath = ^"/root/RunSession"

## Guards the double click: the scene takes a moment to change and the buttons are
## still live while it does.
var _leaving: bool = false


func _ready() -> void:
	_connect(story_button_path, start_story)
	_connect(free_run_button_path, start_free_run)
	_connect(settings_button_path, open_settings)
	_connect(exit_button_path, quit)
	_connect(back_button_path, close_settings)
	close_settings()


## The ordinary game: nothing is chosen, so the world comes up at the base and the
## player sets out from the pit exactly as they always have.
func start_story() -> void:
	if _leaving:
		return
	var session := _resolve_session()
	if session != null and session.has_method(&"set_free_run"):
		session.call(&"set_free_run", false)
	_leave()


## The endless search. The questions the pit would have asked are answered here so
## the world can be built straight into a region, and the session is marked so that
## [WorldBoot] knows what it is building.
func start_free_run() -> void:
	if _leaving:
		return

	var session := _resolve_session()
	if session == null:
		return

	if session.has_method(&"set_free_run"):
		session.call(&"set_free_run", true)

	var map := _free_run_map(session)
	if map == null:
		# Nowhere to fight. The choice is refused rather than loading a world that
		# would come up in the base with a Free Run flag on it and nothing to run.
		if session.has_method(&"set_free_run"):
			session.call(&"set_free_run", false)
		return

	session.call(&"begin", map.map_id)
	if free_run_enters_at_entry_region:
		var entry := map.get_entry_region()
		if entry != null and session.has_method(&"choose_region"):
			session.call(&"choose_region", entry.region_id)

	_leave()


## Which map a Free Run is fought on: the one named, or the first the catalogue has
## open. Null when there is no catalogue to ask, which the caller refuses on.
func _free_run_map(session: Node) -> MapDefinition:
	if not session.has_method(&"get_map_catalog"):
		return null
	var catalog := session.call(&"get_map_catalog") as MapCatalog
	if catalog == null:
		return null

	if free_run_map_id != &"":
		return catalog.find(free_run_map_id)

	var open := catalog.unlocked_maps()
	return null if open.is_empty() else open[0]


## Raises the settings and puts the choices away, so only one of the two is ever on
## screen and the buttons underneath cannot be clicked through.
func open_settings() -> void:
	_show(menu_path, false)
	_show(settings_path, true)


func close_settings() -> void:
	_show(settings_path, false)
	_show(menu_path, true)


func quit() -> void:
	get_tree().quit()


func _leave() -> void:
	_leaving = true
	get_tree().change_scene_to_file(world_scene)


func _connect(path: NodePath, to: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button != null and not button.pressed.is_connected(to):
		button.pressed.connect(to)


func _show(path: NodePath, shown: bool) -> void:
	var node := get_node_or_null(path) as CanvasItem
	if node != null:
		node.visible = shown


func _resolve_session() -> Node:
	return get_node_or_null(session_path)
