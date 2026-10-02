extends SceneTree
## Photographs the Loot Screen's pouch opening and the direct loot it spills -
## a ? card, a Charm, a Gem heap, the three whisky Health items and a flask of
## Blood - at each beat of the opening, then with a tooltip up. Needs a window -
## not headless.
##
## [codeblock]
## godot --path . --script res://Scripts/Dev/loot_pouch_shot.gd
## [/codeblock]

const SCREEN_SCENE := "res://Scenes/UI/Loot/LootScreen.tscn"
const OUT_DIR := "user://loot_pouch_shots"


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
	var mystery := LootReward.new()
	mystery.look = load("res://Resources/Loot/Looks/look_mystery_card.tres") as LootRewardLook
	bundle.add(mystery)
	var charm := LootRewardCharm.new()
	charm.look = load("res://Resources/Loot/Looks/look_charm.tres") as LootRewardLook
	charm.charm = load("res://Resources/Charms/charm_devils_step.tres") as CharmDefinition
	bundle.add(charm)
	var table := load("res://Resources/World/combat_loot_table.tres") as CombatLootTable
	var loot := CombatLoot.new()
	loot.add_gem(table.gem_colors[1].id, table.gem_colors[1].display_name, 4, 99,
		table.gem_colors[1].icon)
	var gems := LootRewardStack.new()
	gems.look = load("res://Resources/Loot/Looks/look_gem.tres") as LootRewardLook
	gems.loot = loot
	gems.stack = loot.get_stacks()[0]
	bundle.add(gems)
	for path: String in ["res://Resources/Loot/Health/whisky_glass.tres",
			"res://Resources/Loot/Health/whisky_bottle_35.tres",
			"res://Resources/Loot/Health/whisky_bottle_50.tres"]:
		var drink := LootRewardHealth.new()
		drink.look = load("res://Resources/Loot/Looks/look_health_item.tres") as LootRewardLook
		drink.item = load(path) as HealthLootDefinition
		bundle.add(drink)
	var blood := LootRewardBlood.new()
	blood.look = load("res://Resources/Loot/Looks/look_blood.tres") as LootRewardLook
	blood.title = "KAN"
	blood.amount = 25
	bundle.add(blood)

	screen.present(bundle)
	await _frames(40)
	_shot("1_shut")
	screen.reveal()
	var pouch := screen.get_node(^"Table/Pouch") as LootPouch
	for moment: float in [0.3, 0.75, 1.15, 1.45, 1.7]:
		await create_timer(moment - _elapsed(pouch), true).timeout
		_shot("2_opening_%.2fs" % moment)
	await create_timer(2.2, true).timeout
	_shot("3_dealt")
	var cards := screen.get_cards()
	for card: LootRewardCard in cards:
		if card.get_reward() is LootRewardCharm:
			card._on_hover(true)
	await create_timer(0.3, true).timeout
	_shot("4_hover_charm")
	for card: LootRewardCard in cards:
		card._on_hover(false)
		if card.get_reward() is LootRewardHealth \
				and (card.get_reward() as LootRewardHealth).item.id == &"whisky_bottle_50":
			card._on_hover(true)
	await create_timer(0.3, true).timeout
	_shot("5_hover_bottle")
	print("shots in %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit()


var _started: int = -1


func _elapsed(_pouch: LootPouch) -> float:
	if _started < 0:
		_started = Time.get_ticks_msec()
	return (Time.get_ticks_msec() - _started) / 1000.0


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _shot(shot_name: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
