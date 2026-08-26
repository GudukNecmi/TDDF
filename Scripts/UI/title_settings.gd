class_name TitleSettings
extends Control
## The settings the title screen offers: how loud the game is and whether it fills
## the screen.
##
## [b]Both of them are the engine's own, not the game's.[/b] The volume is a bus on
## the [AudioServer] - the same bus every sound in the game already plays through -
## and the window mode is [DisplayServer]'s, so there is no settings system here and
## nothing about how the game sounds or draws is duplicated. Which bus is a name in
## the inspector rather than a constant, so a later Music-and-Effects pair is two of
## these rather than a rewrite of this one.
##
## Nothing is saved. That is deliberate rather than missing: a settings file is a
## place for the whole of the game's options to live, this screen has two of them,
## and writing half a save format now would have to be undone when the rest arrive.

## The mixer bus the slider moves. Named rather than numbered so the layout can be
## rearranged without this following it.
@export var bus_name: StringName = &"Master"

## The quietest the slider can go before it is treated as silence, as a linear
## fraction. Below this the bus is muted outright, because a fader dragged to the
## bottom should be off rather than very nearly off.
@export var silence_below: float = 0.001

@export_group("Wording")
@export var fullscreen_on_text: String = "FULLSCREEN: ON"
@export var fullscreen_off_text: String = "FULLSCREEN: OFF"

@export_group("Nodes")
@export var volume_slider_path: NodePath = ^"Frame/Body/Volume/Slider"
@export var volume_value_path: NodePath = ^"Frame/Body/Volume/Value"
@export var fullscreen_button_path: NodePath = ^"Frame/Body/FullscreenButton"

@onready var _slider: Range = get_node_or_null(volume_slider_path) as Range
@onready var _value: Label = get_node_or_null(volume_value_path) as Label
@onready var _fullscreen: BaseButton = get_node_or_null(fullscreen_button_path) as BaseButton


func _ready() -> void:
	if _slider != null:
		_slider.value = get_volume()
		if not _slider.value_changed.is_connected(_on_volume_changed):
			_slider.value_changed.connect(_on_volume_changed)
	if _fullscreen != null and not _fullscreen.pressed.is_connected(toggle_fullscreen):
		_fullscreen.pressed.connect(toggle_fullscreen)

	_show_volume(get_volume())
	_show_fullscreen()


## How loud the bus is, as a linear fraction. 0 when there is no such bus, which
## every caller reads as "nothing to move".
func get_volume() -> float:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return 0.0
	if AudioServer.is_bus_mute(bus):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus))


## Sets the bus, muting outright at the bottom of the fader rather than leaving it
## at a level nobody can hear but the engine is still mixing.
func set_volume(linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return

	var wanted := clampf(linear, 0.0, 1.0)
	var silent := wanted <= silence_below
	AudioServer.set_bus_mute(bus, silent)
	if not silent:
		AudioServer.set_bus_volume_db(bus, linear_to_db(wanted))
	_show_volume(wanted)


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_fullscreen()


func _on_volume_changed(value: float) -> void:
	set_volume(value)


func _show_volume(linear: float) -> void:
	if _value != null:
		_value.text = "%d%%" % roundi(clampf(linear, 0.0, 1.0) * 100.0)


func _show_fullscreen() -> void:
	if _fullscreen == null:
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen.text = fullscreen_on_text if full else fullscreen_off_text
