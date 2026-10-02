extends SceneTree
## Windowed check and photographs of the Mystery ? cards on the real Loot Screen
## inside the real RunHUD (MysteryCardPreview.tscn): the ? table, each card of the
## reveal, a real pointer hovering a card (lift, lean, glare), and the click that
## takes it - with the game's own pointer up and the system pointer hidden the
## whole way. Needs a window - not headless.
##
## [codeblock]
## godot --path . --script res://Scripts/Dev/mystery_card_shot.gd
## [/codeblock]

const PREVIEW := "res://Scenes/Dev/MysteryCardPreview.tscn"
const OUT_DIR := "user://mystery_card_shots"

var _failures: int = 0
var _cursor: GameCursor
var _pointer_ok: bool = true
var _held_pointer: Vector2 = Vector2(-1.0, -1.0)


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	change_scene_to_file(PREVIEW)
	for _i: int in 10:
		await process_frame
	var loot := current_scene.find_child("LootScreen", true, false) as LootScreen
	_cursor = current_scene.find_child("GameCursor", true, false) as GameCursor
	var choices := RewardChoiceScreen.get_active(loot)
	_ok(loot != null and loot.is_open() and _cursor != null and choices != null, "the preview table is up")
	if loot == null or choices == null:
		_finish()
		return
	loot.reveal()
	while not loot.is_revealed() or loot.get_cards().is_empty():
		await process_frame
	await _hold(2.0)
	_shot("1_table")
	var mysteries := loot.get_cards()
	_ok(mysteries.size() == 3, "three ? on the table", str(mysteries.size()))
	_ok(loot.can_leave(), "DEVAM ET open")

	# Hover the ? with the real pointer first.
	await _point(mysteries[0].get_global_rect().get_center())
	await _hold(0.3)
	_shot("2_hover_mystery")
	loot.activate(mysteries[0])
	var revealed := [0]
	choices.card_revealed.connect(func(_i: int, _c: RewardChoice) -> void: revealed[0] += 1)
	var taken_shots := 0
	while not choices.is_choosing():
		await process_frame
		_check_pointer()
		if revealed[0] > taken_shots:
			taken_shots = revealed[0]
			await _hold(0.08)
			_shot("3_reveal_%d" % taken_shots)
	await _hold(1.0)
	_shot("4_all_revealed")

	var cards := choices.get_cards()
	var target := cards[1]
	var rect := target.get_global_rect()
	var at := rect.get_center() + Vector2(rect.size.x * 0.3, -rect.size.y * 0.3)
	await _point(at)
	await _hold(0.6)
	_shot("5_hover_card")
	var pivot := target.get_node(target.pivot_path) as Control
	var material := (target.get_node(target.display_path) as TextureRect).material as ShaderMaterial
	var tilt: Vector2 = material.get_shader_parameter(&"tilt")
	var glare: Vector2 = material.get_shader_parameter(&"glare_pos")
	_ok(pivot.position.y < -5.0 and pivot.scale.x > 1.03, "the real pointer lifts and swells the card",
		"lift %.1f scale %.3f" % [pivot.position.y, pivot.scale.x])
	_ok(tilt.length() > 0.05 and absf(tilt.x) <= deg_to_rad(target.max_tilt_degrees) + 0.001
		and absf(tilt.y) <= deg_to_rad(target.max_tilt_degrees) + 0.001, "it leans, within the limit", str(tilt))
	_ok(glare.x > 0.6 and glare.y < 0.4, "the glare sits under the pointer", str(glare))
	var resting := cards[0].get_node(cards[0].pivot_path) as Control
	_ok(absf(resting.position.y) < 0.5, "the others rest", str(resting.position.y))
	await _point(rect.get_center() + Vector2(-rect.size.x * 0.3, rect.size.y * 0.3))
	await _hold(0.4)
	var tilt_after: Vector2 = material.get_shader_parameter(&"tilt")
	_ok(signf(tilt_after.x) != signf(tilt.x) and signf(tilt_after.y) != signf(tilt.y),
		"moving to the opposite corner leans it the other way", "%s -> %s" % [tilt, tilt_after])
	_shot("6_hover_other_corner")

	var picked: Array[RewardChoice] = []
	choices.selected.connect(func(c: RewardChoice) -> void: picked.append(c))
	_click(rect.get_center() + Vector2(-rect.size.x * 0.3, rect.size.y * 0.3))
	_click(rect.get_center())
	await _hold(0.15)
	_shot("7_selected")
	_ok(picked.size() == 1 and picked[0] == target.get_choice(), "a real click on the leaning card took it, once")
	while choices.is_open():
		await process_frame
		_check_pointer()
	await _hold(0.3)
	_shot("8_back_to_table")
	_ok(mysteries[0].get_reward().is_resolved() and not mysteries[1].get_reward().is_resolved(),
		"only that ? resolved")
	_ok(_pointer_ok, "the game's pointer was up and the system pointer hidden throughout")

	# The longest lettering there is: a selection of Legendaries.
	var forced := (mysteries[1].get_reward() as LootRewardMystery).generator.duplicate(true) \
		as RewardChoiceGenerator
	for entry: RewardPoolEntry in forced.entries:
		entry.weight = 100.0 if entry.pool is RewardPoolLegendary else 0.0
	(mysteries[1].get_reward() as LootRewardMystery).generator = forced
	loot.activate(mysteries[1])
	while not choices.is_choosing():
		await process_frame
	await _hold(0.8)
	_shot("9_legendaries")
	var fits := true
	for card: RewardChoiceCard in choices.get_cards() + cards:
		if not is_instance_valid(card):
			continue
		var box := card.get_node(card.text_box_path) as Control
		var description := card.get_node(card.description_label_path) as Label
		var font_size := description.get_theme_font_size(&"font_size")
		print("       %s: text %.0f/%.0f px, description %dpt" % [card.get_choice().get_title(),
			card.lettering_height(), card.get_text_room(), font_size])
		if not card.text_fits():
			fits = false
	_ok(fits, "every dealt card's lettering fits on the stock")

	# Every card the data can deal, not only the ones this roll happened to.
	var every: Array[RewardChoice] = []
	var epic := load("res://Resources/Rewards/Rarity/rarity_epic.tres") as UpgradeRarity
	var gold := load("res://Resources/Rewards/Rarity/rarity_legendary.tres") as UpgradeRarity
	var session := root.get_node(^"RunSession") as RunSessionState
	for weapon: WeaponDefinition in session.get_weapon_catalog().weapons:
		for upgrade: WeaponUpgrade in weapon.upgrades:
			every.append(RewardChoiceUpgrade.create(weapon, upgrade, epic))
		for legendary: WeaponLegendary in weapon.legendaries:
			every.append(RewardChoiceLegendary.create(weapon, legendary, gold))
	var scene := load("res://Scenes/UI/Loot/RewardChoiceCard.tscn") as PackedScene
	var overflowing: PackedStringArray = []
	var smallest := 99
	for choice: RewardChoice in every:
		var card := scene.instantiate() as RewardChoiceCard
		current_scene.add_child(card)
		card.bind(choice)
		await process_frame
		await process_frame
		var description := card.get_node(card.description_label_path) as Label
		smallest = mini(smallest, description.get_theme_font_size(&"font_size"))
		if not card.text_fits():
			overflowing.append(choice.get_title())
		card.queue_free()
	_ok(overflowing.is_empty(), "all %d cards the data can deal fit their stock (smallest text %dpt)"
		% [every.size(), smallest], ", ".join(overflowing))
	choices.choose(0)
	while choices.is_open():
		await process_frame
	print("shots in %s" % ProjectSettings.globalize_path(OUT_DIR))
	_finish()


func _check_pointer() -> void:
	if _cursor == null or not _cursor.visible or not _cursor.is_pointer_wanted() \
			or Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
		_pointer_ok = false


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)


func _hold(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		_check_pointer()
		if _held_pointer.x >= 0.0:
			_push_pointer(_held_pointer)


func _shot(shot_name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, shot_name])


func _finish() -> void:
	print("MYSTERY CARD SHOT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	var line := ("  ok   " if condition else "  FAIL ") + what
	if not detail.is_empty():
		line += "  (%s)" % detail
	print(line)
	if not condition:
		_failures += 1


## Moves the game's pointer to [param at] with a real motion event through the
## window's input - the path the OS mouse takes - without moving the desktop's.
func _point(at: Vector2) -> void:
	_held_pointer = at
	_push_pointer(at)
	await process_frame


## Real desktop motion over the window would otherwise win - it is re-asserted
## every frame the check holds.
func _push_pointer(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
