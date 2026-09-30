extends SceneTree
## Photographs the Loot Screen on its own with a bundle of one card per reward
## look: the shut pouch, the pouch mid-opening, and the cards dealt round it.
## Needs a window - not headless.
##
## [codeblock]
## godot --path . --script res://Scripts/Dev/loot_screen_shot.gd
## [/codeblock]

const SCREEN_SCENE := "res://Scenes/UI/Loot/LootScreen.tscn"
const LOOKS_DIR := "res://Resources/Loot/Looks/"
const OUT_DIR := "user://loot_screen_shots"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await process_frame
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var screen := (load(SCREEN_SCENE) as PackedScene).instantiate() as LootScreen
	layer.add_child(screen)
	await _frames(2)

	var bundle := LootBundle.new()
	bundle.context = LootContext.new()
	for file: String in DirAccess.get_files_at(LOOKS_DIR):
		if not file.ends_with(".tres"):
			continue
		var reward := LootReward.new()
		reward.look = load(LOOKS_DIR + file) as LootRewardLook
		reward.detail = "PLACEHOLDER"
		reward.amount = 3
		bundle.add(reward)
	bundle.rewards[0].mark_resolved()

	screen.present(bundle)
	await _frames(40)
	_shot("1_pouch_shut")
	screen.reveal()
	await create_timer(0.62, true).timeout
	_shot("2_pouch_shaking")
	await create_timer(0.25, true).timeout
	_shot("3_pouch_burst")
	await create_timer(1.6, true).timeout
	_shot("4_dealt")
	print("shots in %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit()


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _shot(shot_name: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	root.get_texture().get_image().save_png(path)
