class_name BaseMenuEntry
extends Button
## One line of the Base menu: a button that raises one of the base's existing
## screens.
##
## [b]It names the screen, it does not own it.[/b] The screen is found by the
## group it already joins - [code]wanted_board_menu[/code],
## [code]weapon_select_menu[/code], [code]trader_menu[/code] - and asked to
## [code]open()[/code], the same call the station in the physical base made. So a
## new line in the menu is a duplicated button with a different group written on
## it in the Inspector, and nothing in [BaseMenu] has to learn about it.
##
## [b]An empty group is a function the base does not have yet.[/b] The button
## stays on the menu and pressing it shows [member unavailable_text] instead of
## opening anything - the same arrangement FREE RUN has on the title screen - so
## filling one in later is writing the group here, not adding a button.

## Group the screen this line opens joins. Empty means it is not built yet.
@export var screen_group: StringName = &""
## What the menu says when a line with no screen behind it is pressed.
@export var unavailable_text: String = "COMING SOON"


## The screen this line raises, or null when there is none in the scene.
func find_screen() -> Control:
	if screen_group.is_empty() or not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(screen_group) as Control


func is_available() -> bool:
	return find_screen() != null
