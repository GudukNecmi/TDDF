extends SceneTree
## Headless check of the Mystery ? Upgrade Card system, off the run: the counts a
## won point pays, the generator's Luck, per-slot type roll, rarity roll and
## strength, unlimited stacking through the weapon's run stack, the Legendary
## pool and its fallback, the Turkish lettering - and the real Loot Screen with
## its real selection screen: one ? opened, its cards revealed strictly left to
## right with one flip and one stinger of the right number of hits each, rarity
## colours and particles, hover lean and glare under a real mouse, a real click
## taking a card, the ? resolved exactly once and RIDE ON held until every ? is.
##
## The whole-run flow (a real won fight, the game's own pointer) is
## loot_screen_smoke.gd's.
##
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/mystery_card_smoke.gd
## [/codeblock]

const SOURCE := "res://Resources/Loot/Sources/source_mystery_cards.tres"
const GENERATOR := "res://Resources/Rewards/mystery_card_generator.tres"
const UPGRADE_POOL := "res://Resources/Rewards/reward_pool_upgrade.tres"
const LEGENDARY_POOL := "res://Resources/Rewards/reward_pool_legendary.tres"
const CATALOG := "res://Resources/Weapons/weapon_catalog.tres"
const RARITY_DIR := "res://Resources/Rewards/Rarity/"
const LOOT_SCREEN := "res://Scenes/UI/Loot/LootScreen.tscn"
const RARITY_ORDER: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic",
	&"legendary", &"legendary_upgrade"]

var _failures: int = 0
var _generator: RewardChoiceGenerator
var _shotgun: WeaponDefinition
var _weapons: Array[WeaponDefinition] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_generator = load(GENERATOR) as RewardChoiceGenerator
	var catalog := load(CATALOG) as WeaponCatalog
	for weapon: WeaponDefinition in catalog.weapons:
		if weapon != null:
			_weapons.append(weapon)
			weapon.reset_upgrades()
	_shotgun = catalog.find(&"shotgun")

	print("--- counts ---")
	_count_checks()
	print("--- choices and luck ---")
	_luck_checks()
	print("--- type roll ---")
	_type_roll_checks()
	print("--- rarity ---")
	_rarity_checks()
	print("--- stacking ---")
	_stacking_checks()
	print("--- legendaries ---")
	_legendary_checks()
	print("--- turkish ---")
	_turkish_checks()
	print("--- the table ---")
	await _table_checks()
	for weapon: WeaponDefinition in _weapons:
		weapon.reset_upgrades()
	_finish()


# --- Counts -----------------------------------------------------------------------

func _count_checks() -> void:
	var source := load(SOURCE) as LootSourceMysteryCards
	var host := Node.new()
	root.add_child(host)
	for pair: Array in [[&"bandit_group", 1], [&"bandit_camp", 2], [&"bounty", 3],
			[&"bandit_group_cleared", 0], [&"", 0]]:
		var bundle := LootBundle.new()
		var context := LootContext.create(host, null, pair[0])
		source.contribute(bundle, context)
		var mysteries := 0
		for reward: LootReward in bundle.rewards:
			if reward is LootRewardMystery:
				mysteries += 1
		_ok(mysteries == pair[1] and bundle.size() == pair[1],
			"%s pays exactly %d ?" % [pair[0] if pair[0] != &"" else &"<no point>", pair[1]],
			str(mysteries))
	host.free()
	# The screen never decides it: nothing in the Loot Screen scripts names an
	# encounter or a content entry.
	for path: String in ["res://Scripts/UI/loot_screen.gd", "res://Scripts/UI/reward_choice_screen.gd",
			"res://Scripts/UI/reward_choice_card.gd", "res://Scripts/Rewards/reward_choice_generator.gd",
			"res://Scripts/Rewards/reward_pool_upgrade.gd", "res://Scripts/Rewards/reward_pool_legendary.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var named := false
		for word: String in ["bandit_group", "bandit_camp", "&\"bounty\"", "black_powder",
				"hell_chamber", "devils_barrel", "&\"damage\"", "&\"luck\""]:
			if text.contains(word):
				named = true
		_ok(not named, "%s names no encounter, upgrade or Legendary" % path.get_file())


# --- Luck -----------------------------------------------------------------------

func _luck_checks() -> void:
	_shotgun.reset_upgrades()
	var rng := _rng(1)
	_ok(_generator.generate(_shotgun, rng).size() == 3, "0 Luck deals 3 cards")
	var luck_card := _upgrade_by_id(_shotgun, &"luck")
	_ok(luck_card != null and luck_card.card_name == "ŞANSLI EL", "ŞANSLI EL is one of the weapon's upgrades")
	_ok(luck_card != null and luck_card.describe_card(1).begins_with("+1 Şans"),
		"it reads +1 Şans", luck_card.describe_card(1) if luck_card else "")
	var common := RewardChoiceUpgrade.create(_shotgun, luck_card, _rarity(&"common"))
	common.apply()
	_ok(_generator.generate(_shotgun, rng).size() == 4, "1 Luck (a Common ŞANSLI EL) deals 4")
	common.apply()
	_ok(_generator.generate(_shotgun, rng).size() == 5, "2 Luck deals 5")
	_shotgun.reset_upgrades()
	# Any source of Luck works, not only the card - a later charm, for one.
	var modifier := WeaponStatModifier.new()
	modifier.stat = WeaponStats.Stat.LUCK
	modifier.amount = 1.0
	var charm: Array[WeaponStatModifier] = [modifier]
	_shotgun.set_modifier_source(&"smoke_luck", charm)
	_ok(_generator.generate(_shotgun, rng).size() == 4, "Luck from another source widens it too")
	_shotgun.set_modifier_source(&"smoke_luck", [] as Array[WeaponStatModifier])
	_ok(_generator.choice_count(0.0) == 3 and _generator.choice_count(2.0) == 5
		and _generator.choice_count(99.0) == _generator.max_choice_count,
		"choice count is base + Luck, capped")


# --- Type roll ------------------------------------------------------------------

func _type_roll_checks() -> void:
	_shotgun.reset_upgrades()
	var rng := _rng(2)
	var slots := 0
	var legendaries := 0
	var per_roll := {0: 0, 1: 0, 2: 0, 3: 0}
	for _i: int in 6000:
		var roll := _generator.generate(_shotgun, rng, 3)
		var in_roll := 0
		for choice: RewardChoice in roll:
			slots += 1
			if choice is RewardChoiceLegendary:
				in_roll += 1
		legendaries += in_roll
		per_roll[in_roll] += 1
	var share := float(legendaries) / float(slots)
	_ok(absf(share - 0.1) < 0.01, "each slot rolls ~10% Legendary", "%.3f" % share)
	_ok(per_roll[0] > 0 and per_roll[1] > 0 and per_roll[2] > 0 and per_roll[3] > 0,
		"any mix happens, three Legendaries included", str(per_roll))
	var legendary_entry: RewardPoolEntry = null
	for entry: RewardPoolEntry in _generator.entries:
		if entry.pool is RewardPoolLegendary:
			legendary_entry = entry
	_ok(legendary_entry != null and is_equal_approx(legendary_entry.weight, 10.0),
		"the 10% is data (Legendary weight 10 of 100)")
	var tuned := _generator.duplicate(true) as RewardChoiceGenerator
	for entry: RewardPoolEntry in tuned.entries:
		entry.weight = 50.0
	var half := 0
	for _i: int in 2000:
		for choice: RewardChoice in tuned.generate(_shotgun, rng, 1):
			if choice is RewardChoiceLegendary:
				half += 1
	_ok(absf(half / 2000.0 - 0.5) < 0.04, "changing the weights changes the roll", "%.3f" % (half / 2000.0))


# --- Rarity ---------------------------------------------------------------------

func _rarity_checks() -> void:
	var pool := load(UPGRADE_POOL) as RewardPoolUpgrade
	var rng := _rng(3)
	var counts := {}
	var n := 20000
	for _i: int in n:
		var choice := pool.draw(_shotgun, rng)
		counts[choice.rarity.id] = int(counts.get(choice.rarity.id, 0)) + 1
	for pair: Array in [[&"common", 0.70], [&"uncommon", 0.20], [&"rare", 0.08], [&"epic", 0.02]]:
		var share := int(counts.get(pair[0], 0)) / float(n)
		_ok(absf(share - pair[1]) < 0.012, "%s ~%d%%" % [pair[0], roundi(pair[1] * 100)], "%.3f" % share)
	var epic_only := pool.duplicate(true) as RewardPoolUpgrade
	for chance: RewardRarityChance in epic_only.rarities:
		chance.weight = 1.0 if chance.rarity.id == &"epic" else 0.0
	var all_epic := true
	for _i: int in 200:
		if epic_only.draw(_shotgun, rng).rarity.id != &"epic":
			all_epic = false
	_ok(all_epic, "the rarity weights are configurable")

	var damage := _upgrade_by_id(_shotgun, &"damage")
	for pair: Array in [[&"common", 1, "%10"], [&"uncommon", 2, "%20"], [&"rare", 3, "%30"], [&"epic", 4, "%40"]]:
		_shotgun.reset_upgrades()
		var choice := RewardChoiceUpgrade.create(_shotgun, damage, _rarity(pair[0]))
		choice.apply()
		var bonus := _shotgun.get_stats().get_bonus(WeaponStats.Stat.DAMAGE)
		_ok(is_equal_approx(bonus, 0.1 * pair[1]) and choice.get_description().contains(pair[2]),
			"%s DAMAGE is %dx: +%d%% (%s)" % [pair[0], pair[1], pair[1] * 10, choice.get_description()],
			"%.2f" % bonus)
	var epic := RewardChoiceUpgrade.create(_shotgun, damage, _rarity(&"epic"))
	_ok(epic.get_title() == "İBLİSİN ÖFKESİ" and epic.get_rarity_name() == "EPİK"
		and epic.get_description() == "Hasarını %40 artırır.",
		"the brief's example card reads exactly", "%s / %s / %s" % [epic.get_title(),
			epic.get_rarity_name(), epic.get_description()])

	var tiers: Array[UpgradeRarity] = []
	for id: StringName in RARITY_ORDER:
		tiers.append(_rarity(id))
	var colors_ok := true
	var expected: Array[Color] = [Color(0.95, 0.93, 0.88), Color(0.35, 0.85, 0.35), Color(0.3, 0.6, 1),
		Color(0.72, 0.36, 1), Color(1, 0.8, 0.2), Color(1, 0.5, 0.12)]
	for i: int in tiers.size():
		if tiers[i] == null or not tiers[i].color.is_equal_approx(Color(expected[i], 1.0)):
			colors_ok = false
	_ok(colors_ok, "white / green / blue / purple / gold / orange")
	var hits: Array[int] = []
	for rarity: UpgradeRarity in tiers:
		hits.append(rarity.stinger_hits if rarity.stinger_hit != null else -1)
	_ok(hits.slice(0, 5) == [1, 2, 3, 4, 5], "Common..Legendary stingers are 1/2/3/4/5 hits", str(hits))
	_ok(tiers[5].stinger_layer != null and tiers[5].stinger_layer != tiers[4].stinger_hit,
		"Legendary Upgrade has its own orange sound identity reserved")
	var rising := true
	for i: int in range(1, 5):
		if tiers[i].particle_amount < tiers[i - 1].particle_amount \
				or tiers[i].particle_intensity < tiers[i - 1].particle_intensity:
			rising = false
	_ok(rising, "particle intensity rises with rarity")


# --- Stacking -------------------------------------------------------------------

func _stacking_checks() -> void:
	_shotgun.reset_upgrades()
	var damage := _upgrade_by_id(_shotgun, &"damage")
	var every_copy_landed := true
	for _i: int in 7:
		if not RewardChoiceUpgrade.create(_shotgun, damage, _rarity(&"common")).apply():
			every_copy_landed = false
	_ok(every_copy_landed, "no copy is rejected as a duplicate")
	_ok(_shotgun.get_run_level(damage) == 7 and damage.max_level < 7,
		"seven copies stack past the level-%d market cap" % damage.max_level, str(_shotgun.get_run_level(damage)))
	RewardChoiceUpgrade.create(_shotgun, damage, _rarity(&"epic")).apply()
	_ok(is_equal_approx(_shotgun.get_stats().get_bonus(WeaponStats.Stat.DAMAGE), 1.1),
		"and an Epic on top adds its 4 levels: +110%",
		"%.2f" % _shotgun.get_stats().get_bonus(WeaponStats.Stat.DAMAGE))
	_ok(_shotgun.get_upgrade_level(damage) == 0, "only the run stack moved - the Base level is untouched")
	_shotgun.clear_run_levels()
	_ok(_shotgun.get_run_level(damage) == 0, "and it is forgotten with the run")


# --- Legendaries ----------------------------------------------------------------

func _legendary_checks() -> void:
	var rng := _rng(4)
	var forced := _generator.duplicate(true) as RewardChoiceGenerator
	for entry: RewardPoolEntry in forced.entries:
		entry.weight = 100.0 if entry.pool is RewardPoolLegendary else 0.0
	for weapon: WeaponDefinition in _weapons:
		weapon.reset_upgrades()
		var own := true
		var all_upgrades_own := true
		var legendary_seen := 0
		for _i: int in 200:
			for choice: RewardChoice in _generator.generate(weapon, rng):
				if choice is RewardChoiceLegendary:
					legendary_seen += 1
					if not weapon.legendaries.has((choice as RewardChoiceLegendary).legendary):
						own = false
				elif choice is RewardChoiceUpgrade:
					if not weapon.upgrades.has((choice as RewardChoiceUpgrade).upgrade):
						all_upgrades_own = false
		_ok(own and all_upgrades_own, "%s: every card is from its own upgrades and Legendaries (%d Legendary)" % [
			weapon.weapon_id, legendary_seen])
		if weapon.legendaries.is_empty():
			var fallback := forced.generate(weapon, rng)
			var normal := fallback.size() == 3
			for choice: RewardChoice in fallback:
				if not choice is RewardChoiceUpgrade:
					normal = false
			_ok(normal, "%s has no Legendary: a Legendary roll falls back to an Upgrade Card" % weapon.weapon_id)
	var every := forced.generate(_shotgun, rng, 3)
	var distinct := {}
	for choice: RewardChoice in every:
		distinct[choice.get_key()] = true
	_ok(every.size() == 3 and distinct.size() == 3, "a selection of Legendaries never repeats one")
	var picked := every[0] as RewardChoiceLegendary
	_ok(picked.apply() and _shotgun.is_legendary_active(picked.legendary),
		"taking a Legendary switches it on through the weapon")
	for legendary: WeaponLegendary in _shotgun.legendaries:
		_shotgun.set_legendary_active(legendary, true)
	var exhausted := forced.generate(_shotgun, rng)
	var safe := exhausted.size() == 3
	for choice: RewardChoice in exhausted:
		if not choice is RewardChoiceUpgrade:
			safe = false
	_ok(safe, "with every Legendary already carried, the roll falls back safely")
	_shotgun.reset_upgrades()


# --- Turkish --------------------------------------------------------------------

func _turkish_checks() -> void:
	var title_font := load("res://Fonts/Sancreek-Regular.ttf") as Font
	var body_font := load("res://Fonts/AlfaSlabOne-Regular.ttf") as Font
	var lines: Array[String] = []
	var complete := true
	for weapon: WeaponDefinition in _weapons:
		for upgrade: WeaponUpgrade in weapon.upgrades:
			var text := upgrade.describe_card(1)
			if upgrade.card_name.is_empty() or text.is_empty() \
					or text.count("\n") + 1 != upgrade.modifiers_per_level.size():
				complete = false
				print("       missing: %s" % upgrade.id)
			lines.append(upgrade.card_name)
			lines.append(text)
		for legendary: WeaponLegendary in weapon.legendaries:
			if legendary.card_name.is_empty() or legendary.card_description.is_empty():
				complete = false
			lines.append(legendary.card_name)
			lines.append(legendary.card_description)
	for id: StringName in RARITY_ORDER:
		lines.append(_rarity(id).display_name)
	_ok(complete, "every upgrade and Legendary has a Turkish name and description")
	var missing := ""
	for line: String in lines:
		for i: int in line.length():
			var code := line.unicode_at(i)
			if code == 10:
				continue
			if not title_font.has_char(code) or not body_font.has_char(code):
				missing += line[i]
	_ok(missing.is_empty(), "both card fonts draw every Turkish letter (İ Ş Ğ ı ş ğ Ü Ö Ç)", missing)
	var english := false
	for line: String in lines:
		for word: String in ["DAMAGE", "UPGRADE", "LEGENDARY", "SHOTGUN", "_"]:
			if line.contains(word):
				english = true
	_ok(not english, "no English or internal names on any card")


# --- The real table ---------------------------------------------------------------

func _table_checks() -> void:
	_shotgun.reset_upgrades()
	var loot := (load(LOOT_SCREEN) as PackedScene).instantiate() as LootScreen
	loot.pauses_game = false
	root.add_child(loot)
	await process_frame
	var choices_screen := RewardChoiceScreen.get_active(loot)
	_ok(choices_screen != null, "the selection screen sits in the Loot Screen")
	# Shorter beats keep the check quick; the order is what is checked.
	choices_screen.start_delay = 0.02
	choices_screen.enter_time = 0.05
	choices_screen.flip_time = 0.06
	choices_screen.after_reveal_hold = 0.12
	choices_screen.selected_time = 0.1

	var source := load(SOURCE) as LootSourceMysteryCards
	var context := LootContext.create(loot, null, &"bandit_camp")
	context.rng.seed = 11
	var bundle := LootBundle.new()
	bundle.context = context
	source.contribute(bundle, context)
	# Make the table's weapon the shotgun whatever the session would answer.
	for reward: LootReward in bundle.rewards:
		(reward as LootRewardMystery).weapon = _shotgun
	_ok(loot.present(bundle), "the table is up with %d ?" % bundle.size())
	loot.reveal(true)
	for _i: int in 20:
		await process_frame
	var cards := loot.get_cards()
	_ok(cards.size() == 2, "two ? cards lie on the table")
	_ok(loot.can_leave() and loot.get_bundle().has_unclaimed(),
		"DEVAM ET is open with ? unresolved - they are optional")
	var first := cards[0]
	var second := cards[1]
	var face := first.get_node_or_null(^"Face") as TextureRect
	_ok(face != null and face.texture != null and face.texture.resource_path.ends_with("Cards.PNG")
		and first.get_reward().get_title() == "?", "the ? card is Cards.PNG with a big ?")

	var revealed_at: Array[float] = []
	var revealed_index: Array[int] = []
	choices_screen.card_revealed.connect(func(index: int, _c: RewardChoice) -> void:
		revealed_index.append(index)
		revealed_at.append(Time.get_ticks_msec() / 1000.0))
	loot.activate(first)
	_ok(choices_screen.is_open(), "clicking ? opened the selection")
	_ok(second.disabled, "the other ? is held still while it is open")
	loot.activate(second)
	_ok(not second.get_reward().is_busy(), "and clicking it does nothing")
	var dealt := choices_screen.get_cards()
	_ok(dealt.size() == 3, "3 cards dealt at 0 Luck", str(dealt.size()))
	var row_ok := dealt.size() == 3 and dealt[0].position.x < dealt[1].position.x \
		and dealt[1].position.x < dealt[2].position.x \
		and is_equal_approx(dealt[0].position.y, dealt[2].position.y)
	_ok(row_ok, "laid out in one horizontal row")
	_ok(not dealt[0].is_face_up() and not dealt[2].is_face_up(), "dealt face down")
	var clicked_early := [false]
	choices_screen.selected.connect(func(_c: RewardChoice) -> void: clicked_early[0] = true, CONNECT_ONE_SHOT)
	choices_screen.choose(1)
	_ok(not clicked_early[0], "nothing can be taken before every card is revealed")
	var waited := 0
	while not choices_screen.is_choosing() and waited < 1200:
		waited += 1
		await process_frame
	_ok(choices_screen.is_choosing(), "every card turned and the choice is open")
	_ok(revealed_index == [0, 1, 2], "revealed strictly left to right", str(revealed_index))
	_ok(revealed_at.size() == 3 and revealed_at[1] - revealed_at[0] >= 0.15
		and revealed_at[2] - revealed_at[1] >= 0.15, "one at a time, never together",
		str(revealed_at))
	_ok(choices_screen.get_flip_plays() == 3, "one flip sound per card", str(choices_screen.get_flip_plays()))
	# The last card's stinger is still running when the choice opens.
	await create_timer(1.2, true).timeout
	var expected_hits: Array[int] = []
	for card: RewardChoiceCard in dealt:
		expected_hits.append(card.get_choice().rarity.stinger_hits)
	_ok(choices_screen.get_stinger_hit_log() == expected_hits,
		"each card's stinger played its rarity's number of hits",
		"%s vs %s" % [choices_screen.get_stinger_hit_log(), expected_hits])

	var colours_ok := true
	for card: RewardChoiceCard in dealt:
		var choice := card.get_choice()
		var label := card.get_node(card.rarity_label_path) as Label
		var particles := card.get_node(card.particles_path) as CPUParticles2D
		var title := card.get_node(card.title_label_path) as Label
		var ramp := particles.color_ramp.get_color(0)
		if not label.get_theme_color(&"font_color").is_equal_approx(choice.get_color()) \
				or not Color(ramp, 1.0).is_equal_approx(Color(choice.get_color(), 1.0)) \
				or not particles.emitting or particles.amount != choice.rarity.particle_amount \
				or title.text != choice.get_title() or title.text.is_empty():
			colours_ok = false
		print("       %s | %s | %s" % [choice.get_rarity_name(), choice.get_title(),
			choice.get_description().replace("\n", " / ")])
	_ok(colours_ok, "rarity line and particles carry the rarity's colour and numbers")
	var particles_behind := true
	for card: RewardChoiceCard in dealt:
		var p := card.get_node(card.particles_path)
		var d := card.get_node(card.display_path)
		if p.get_index() > d.get_index():
			particles_behind = false
	_ok(particles_behind, "particles are drawn behind the face, never over its text")

	# Hover, lean and glare need a real pointer, which headless has none of - see
	# mystery_card_preview.gd for those. The button's own press is used here.
	print("--- selection ---")
	var target := dealt[2]
	var taken: Array[RewardChoice] = []
	choices_screen.selected.connect(func(c: RewardChoice) -> void: taken.append(c))
	var picked := target.get_choice()
	var levels_before := _total_run_levels(_shotgun)
	target.pressed.emit()
	target.pressed.emit()
	dealt[0].pressed.emit()
	await process_frame
	_ok(taken.size() == 1 and taken[0] == picked, "pressing the card took it - once, double presses ignored")
	if picked is RewardChoiceUpgrade:
		var up := picked as RewardChoiceUpgrade
		_ok(_shotgun.get_run_level(up.upgrade) == up.get_levels()
			and _total_run_levels(_shotgun) - levels_before == up.get_levels(),
			"applied at once through the weapon's run stack (%d levels of %s)" % [up.get_levels(), up.upgrade.id])
	elif picked is RewardChoiceLegendary:
		_ok(_shotgun.is_legendary_active((picked as RewardChoiceLegendary).legendary),
			"applied at once: the Legendary is on")
	waited = 0
	while choices_screen.is_open() and waited < 600:
		waited += 1
		await process_frame
	_ok(not choices_screen.is_open(), "back to the table")
	_ok(first.get_reward().is_resolved() and not second.get_reward().is_resolved(),
		"only that ? is resolved")
	_ok(not first.get_reward().can_activate(context), "it cannot be opened twice")
	loot.activate(first)
	_ok(not choices_screen.is_open(), "clicking it again opens nothing")
	_ok(not second.disabled, "the other ? is available again")
	_ok(loot.can_leave() and loot.get_bundle().get_unclaimed().size() == 1
		and loot.get_bundle().get_unclaimed()[0] == second.get_reward(),
		"DEVAM ET is open with one ? left, and only it is unclaimed")

	loot.activate(second)
	waited = 0
	while not choices_screen.is_choosing() and waited < 1200:
		waited += 1
		await process_frame
	choices_screen.choose(0)
	waited = 0
	while choices_screen.is_open() and waited < 600:
		waited += 1
		await process_frame
	_ok(second.get_reward().is_resolved(), "the second ? resolved")
	_ok(loot.can_leave() and not loot.get_bundle().has_unclaimed(),
		"nothing is unclaimed once every ? is resolved")
	loot.close()
	loot.queue_free()


# --- Helpers --------------------------------------------------------------------

func _rarity(id: StringName) -> UpgradeRarity:
	return load(RARITY_DIR + "rarity_%s.tres" % id) as UpgradeRarity


func _upgrade_by_id(weapon: WeaponDefinition, id: StringName) -> WeaponUpgrade:
	for upgrade: WeaponUpgrade in weapon.upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func _total_run_levels(weapon: WeaponDefinition) -> int:
	var total := 0
	for upgrade: WeaponUpgrade in weapon.upgrades:
		total += weapon.get_run_level(upgrade)
	return total


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _finish() -> void:
	if _failures == 0:
		print("MYSTERY CARD SMOKE: ALL PASSED")
	else:
		print("MYSTERY CARD SMOKE: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, what: String, detail: String = "") -> void:
	var line := ("  ok   " if condition else "  FAIL ") + what
	if not detail.is_empty():
		line += "  (%s)" % detail
	print(line)
	if not condition:
		_failures += 1
