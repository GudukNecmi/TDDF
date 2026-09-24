extends SceneTree
## Photographs the Base menu: as it opens, with the wanted board raised by
## RIDE OUT, with the weapon table, the trader, the upgrade screen and the
## gunsmith open.
## Needs a window - not headless.
##
## [codeblock]
## godot --path . --script res://Scripts/Dev/base_menu_shot.gd
## [/codeblock]

const MENU_SCENE := "res://Scenes/Base/BaseMenu.tscn"
const OUT_DIR := "user://base_menu_shots"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await process_frame
	change_scene_to_file(MENU_SCENE)
	await _frames(40)
	_shot("1_menu")

	var menu := current_scene as BaseMenu
	(menu.get_node(^"Layout/RideOutButton") as Button).pressed.emit()
	await _frames(20)
	_shot("2_ride_out_board")

	menu.close_screen()
	await _frames(5)
	(menu.find_child("SelectWeaponButton", true, false) as Button).pressed.emit()
	await _frames(20)
	_shot("3_weapons")

	menu.close_screen()
	await _frames(5)
	(menu.find_child("ShopButton", true, false) as Button).pressed.emit()
	await _frames(20)
	_shot("4_trader")

	menu.close_screen()
	await _frames(5)
	(root.get_node(^"BloodBank") as BloodWallet).add(2000)
	(menu.find_child("UpgradeButton", true, false) as Button).pressed.emit()
	await _frames(20)
	_shot("5_upgrades")

	menu.close_screen()
	await _frames(5)
	(menu.find_child("BuyWeaponButton", true, false) as Button).pressed.emit()
	await _frames(20)
	_shot("6_buy_weapon")

	var shop := menu.find_child("BuyWeaponScreen", true, false) as BuyWeaponScreen
	var cards := shop.get_node(^"Panel/Body/Cards")
	var first := cards.get_child(1) as UpgradeCard
	first.buy_requested.emit(first)
	await _frames(20)
	_shot("7_buy_weapon_bought")
	quit(0)


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _shot(name: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, name]
	root.get_texture().get_image().save_png(path)
	print("[shot] ", ProjectSettings.globalize_path(path))
