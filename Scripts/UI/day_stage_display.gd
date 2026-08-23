class_name DayStageDisplay
extends Node
## Puts the current hour's picture and name onto whatever pieces of UI are
## pointed at it.
##
## Three places show the time of day - the corner of the HUD, the label under it,
## and the next-round button - and all three want the same picture and the same
## colour. Rather than three scripts each finding the day cycle and each deciding
## what to draw, this is one node that finds it once and hands the answer out.
##
## It reads the map's own [DayCycleDirector] - the one authority on what time of
## day it is, and the same one the world's darkness is taken from - so the picture,
## the word and the light can never be showing three different hours. A world with
## no day cycle simply leaves every target as it was authored, which is what makes
## it safe to leave on a HUD that might be used by a map with no clock.
##
## It writes on ready, and again whenever the map's clock says the hour has moved -
## see [signal DayCycleDirector.stage_applied]. Most of the time that is once, as the
## world is built; what makes the second route necessary is that the day now also
## moves [i]during[/i] a round, when a Trouble Danger is cleared, and the corner of
## the HUD has to follow it without the world being rebuilt around it.
##
## [b]Not every target shows the same hour.[/b] The corner of the HUD says where
## the player is now; the NEXT ROUND button is a picture of where they are going,
## and so shows the hour one step further round the cycle. That is one exported
## number per group of targets rather than a second component - see
## [member icon_button_stage_offset].

## [TextureRect]s given the hour's icon.
@export var icon_rect_paths: Array[NodePath] = []
## How many hours ahead [member icon_rect_paths] are shown. 0 - the default - is
## the hour being played now.
@export var icon_rect_stage_offset: int = 0
## [Button]s given the hour's icon, drawn to the left of their own text - which
## is where a [Button] puts an icon by default.
@export var icon_button_paths: Array[NodePath] = []
## How many hours ahead [member icon_button_paths] are shown.
##
## 1 by default, because the only button wearing one of these is NEXT ROUND, and
## what that button promises is the hour the *next* round will be fought at -
## press it at twilight and you are going to night. The order it steps through is
## the map's own [member DayCycleDirector.stages] array, wrapping at the end, so
## nothing here knows what any of the hours are called.
@export var icon_button_stage_offset: int = 1
## [Label]s given the hour's name, written in the hour's own colour.
@export var name_label_paths: Array[NodePath] = []
## How many hours ahead [member name_label_paths] are written. 0 names the hour
## being played now.
@export var name_label_stage_offset: int = 0

@export_group("Look")
## Whether the icons are tinted to the hour's colour as well as being swapped.
## Off leaves the artwork its own colours, which is normally right - the pictures
## are already coloured.
@export var tint_icons: bool = false
## Whether the labels are recoloured to match the icon. This is what "the time
## name uses the same colour as the icon" is.
@export var colour_labels: bool = true


func _ready() -> void:
	_follow_day_cycle()
	apply()


## Followed rather than polled, and connected before the first write so an hour that
## moves on the very frame the HUD is built is still picked up. A world with no day
## cycle simply has nothing to follow.
func _follow_day_cycle() -> void:
	var day := DayCycleDirector.get_active(self)
	if day == null or day.stage_applied.is_connected(_on_stage_applied):
		return
	day.stage_applied.connect(_on_stage_applied)


func _on_stage_applied(_stage: DayStage, _stage_index: int) -> void:
	apply()


## Pushes the current hour to every target. Public so a debug key that forces a
## stage can refresh the HUD without rebuilding the world.
func apply() -> void:
	var day := DayCycleDirector.get_active(self)
	if day == null:
		return

	var icon_stage := day.get_stage_at_offset(icon_rect_stage_offset)
	for path: NodePath in icon_rect_paths:
		var rect := get_node_or_null(path) as TextureRect
		if rect == null or icon_stage == null:
			continue
		rect.texture = icon_stage.icon
		if tint_icons:
			rect.self_modulate = icon_stage.icon_colour

	var button_stage := day.get_stage_at_offset(icon_button_stage_offset)
	for path: NodePath in icon_button_paths:
		var button := get_node_or_null(path) as Button
		if button == null or button_stage == null:
			continue
		button.icon = button_stage.icon
		if tint_icons:
			button.add_theme_color_override(&"icon_normal_color", button_stage.icon_colour)

	if not colour_labels:
		return
	var label_stage := day.get_stage_at_offset(name_label_stage_offset)
	for path: NodePath in name_label_paths:
		var label := get_node_or_null(path) as Label
		if label == null or label_stage == null:
			continue
		label.text = label_stage.display_name
		label.add_theme_color_override(&"font_color", label_stage.icon_colour)
