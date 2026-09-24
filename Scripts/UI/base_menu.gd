class_name BaseMenu
extends Control
## The base, as a screen: STORY lands here, and so does every ride home.
##
## [b]It replaces walking around the base, not the base's systems.[/b] Every
## line on it raises a screen the physical base already had - the wanted board,
## the weapon table, the trader - found by group through [BaseMenuEntry], and the
## blood pool standing in the middle of it is the base's own [BloodPool] scene,
## banking into the same [BloodBank] with the same clicks. Nothing here holds a
## number of its own.
##
## [b]RIDE OUT is the pit.[/b] It asks the scene's [RunPortal] to
## [method RunPortal.start_run], which is the chain of questions setting out has
## always been - here authored to raise the wanted board with its confirm button
## first ([member RunPortal.asks_for_bounty]) and to set out on a fixed map rather
## than asking ([member RunPortal.departure_map_id]) - then the resupply and the
## ride onto the Run Map through [WorldRegionRouter], exactly as from the pit.
##
## [b]Every screen closes with a mouse.[/b] The base's screens were raised by
## walking up to a station and closed with the pause key; a menu is driven with
## the pointer, so a BACK button is laid over whichever screen is up and closes it
## through that screen's own [code]close()[/code]. The key still works.

@export_group("Music & Sound")
## What every button on this screen plays as it is pressed.
@export var button_click_stream: AudioStream = preload("res://Sound/Music/Main menu/MainMenuButton2.WAV")
## How long an unavailable line's message stays up, in seconds.
@export var coming_soon_seconds: float = 2.0

@export_group("Nodes")
## Container every [BaseMenuEntry] is found in.
@export var entries_path: NodePath = ^"Layout/Menu/Frame/Body/Entries"
@export var ride_out_button_path: NodePath = ^"Layout/RideOutButton"
## Laid over the open screen, and the mouse's way out of it.
@export var back_button_path: NodePath = ^"BackButton"
@export var coming_soon_path: NodePath = ^"Layout/ComingSoonLabel"
@export var button_sound_path: NodePath = ^"ButtonSound"

@onready var _ride_out: BaseButton = get_node_or_null(ride_out_button_path) as BaseButton
@onready var _back: BaseButton = get_node_or_null(back_button_path) as BaseButton
@onready var _coming_soon: CanvasItem = get_node_or_null(coming_soon_path) as CanvasItem
@onready var _button_sound: AudioStreamPlayer = get_node_or_null(button_sound_path) as AudioStreamPlayer

## The screen the last press raised, while it is still up.
var _screen: Control
var _coming_soon_timer: SceneTreeTimer


func _ready() -> void:
	var entries := get_node_or_null(entries_path)
	if entries != null:
		for child: Node in entries.get_children():
			var entry := child as BaseMenuEntry
			if entry == null:
				continue
			entry.pressed.connect(_on_entry_pressed.bind(entry))
			entry.pressed.connect(_play_button_sound)

	if _ride_out != null:
		_ride_out.pressed.connect(ride_out)
		_ride_out.pressed.connect(_play_button_sound)
	if _back != null:
		_back.pressed.connect(close_screen)
		_back.pressed.connect(_play_button_sound)
		_back.hide()
	if _coming_soon != null:
		_coming_soon.hide()

	# A run that ended on the road left the tree however it was; the base is
	# always entered running.
	get_tree().paused = false


func _process(_delta: float) -> void:
	if _screen != null and (not is_instance_valid(_screen) or not _screen.visible):
		_screen = null
	if _back != null:
		_back.visible = _screen != null


## Starts the run through the scene's own [RunPortal].
func ride_out() -> void:
	if _screen != null:
		return
	var portal := RunPortal.get_active(self)
	if portal == null or portal.is_starting():
		return
	portal.start_run()
	_track_open_screen()


## Closes whichever base screen is up, through its own close.
func close_screen() -> void:
	if _screen == null or not is_instance_valid(_screen):
		return
	if _screen.has_method(&"close"):
		_screen.call(&"close")
	_screen = null


func _on_entry_pressed(entry: BaseMenuEntry) -> void:
	if _screen != null:
		return
	var screen := entry.find_screen()
	if screen == null or not screen.has_method(&"open"):
		_show_coming_soon(entry.unavailable_text)
		return
	screen.call(&"open")
	_track_open_screen()


## Whichever of the entries' screens is showing now - found rather than assumed,
## because RIDE OUT raises one through the portal rather than through a line.
func _track_open_screen() -> void:
	var entries := get_node_or_null(entries_path)
	if entries == null:
		return
	for child: Node in entries.get_children():
		var entry := child as BaseMenuEntry
		if entry == null:
			continue
		var screen := entry.find_screen()
		if screen != null and screen.visible:
			_screen = screen
			return


func _show_coming_soon(text: String) -> void:
	var label := _coming_soon as Label
	if label != null:
		label.text = text
	if _coming_soon == null:
		return
	_coming_soon.show()
	if _coming_soon_timer != null and _coming_soon_timer.timeout.is_connected(_hide_coming_soon):
		_coming_soon_timer.timeout.disconnect(_hide_coming_soon)
	_coming_soon_timer = get_tree().create_timer(coming_soon_seconds)
	_coming_soon_timer.timeout.connect(_hide_coming_soon)


func _hide_coming_soon() -> void:
	if _coming_soon != null:
		_coming_soon.hide()


func _play_button_sound() -> void:
	if _button_sound == null or button_click_stream == null:
		return
	_button_sound.stream = button_click_stream
	_button_sound.play()
