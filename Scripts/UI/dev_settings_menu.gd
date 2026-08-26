class_name DevSettingsMenu
extends Control
## The developer panel: every number worth retuning and every state worth forcing,
## in one list, behind one key.
##
## [b]P is the only key.[/b] The whole panel - the weapon balance it started as and
## every section added since - opens and closes on [member open_action], so there is
## one developer surface in the game rather than a menu per system. Escape closes it
## too, shared with the pause menu so Escape means "back" wherever the player is.
##
## It is two halves that behave differently on purpose:
##
##   * [b]The balance rows edit a copy and nothing is applied until SAVE.[/b] The
##     panel edits a deep copy of the live balance - see
##     [method DevBalance.working_copy] - so typing in a box moves a number on that
##     copy and nothing else in the game can see it. SAVE hands the copy to
##     [DevBalanceStore], which is the single place that pushes values into the
##     game's own resources and writes them out to disk. Closing the panel without
##     saving throws the copy away, and the next open takes a fresh one.
##   * [b]The tool buttons act the instant they are pressed[/b], and every one of
##     them acts [i]through the system that owns the thing[/i]. A contract's
##     knowledge goes through [method BountyLedger.reveal]; the world's map, region
##     and hour go through [RunSessionState] and [DayClock]; the boss is placed by
##     [method MiniBossDirector.begin] and beaten by damaging its own [Health] so
##     [BossDefeat] answers it; the streak is [StreakCounter] and the blood is
##     [BloodWallet]; killing the player is [method Health.kill], which is the same
##     death a knife gives them. [b]Nothing here is a second implementation of
##     anything[/b] - if a button works, the real system worked.
##
## [b]The rows are generated, not authored.[/b] Each weapon is asked which of its
## numbers are editable - see [method DevWeaponBalance.get_editable_rows], which
## reads that off its own exported properties - so adding a tunable value is writing
## one [code]@export[/code] on that resource and nothing in this file changes. The
## tool sections are the same shape: the knowledge lines come from whichever
## categories [BountySettings] lists, the maps, regions and hours come from the map
## catalogue, and every set of buttons that comes in steps - health fractions,
## knowledge counts, streak counts - is an exported array, so another step is an
## entry in the inspector rather than a branch here.
##
## What [i]is[/i] authored is the shell it fills: the panel, the title, the scrolling
## body and the footer are nodes in the HUD scene with their own styling, so the
## look is inspector work rather than colours written into this script. The buttons
## it builds are dressed from the footer's own SAVE button - see
## [method _button_style] - so they are the game's buttons rather than default Godot
## ones without a second set of styles existing anywhere.

## Emitted as the panel is raised and dropped.
signal opened
signal closed
## Emitted once a save has gone through and the new numbers are live.
signal saved(balance: DevBalance)

## Key that opens the panel. Development only - it is deliberately its own action
## rather than a modifier on an existing one, so it can be unbound in one place.
@export var open_action: StringName = &"dev_menu"
## Key that closes it again, shared with the pause menu so Escape means "back"
## wherever the player is.
@export var close_action: StringName = &"pause_menu"
## The store the values are read from and handed back to - the
## [code]DevConfig[/code] autoload.
@export var store_path: NodePath = ^"/root/DevConfig"
## Freezes the world while the panel is up, the same way the pause and upgrade
## menus do, so nothing carries on happening behind it.
@export var pauses_game: bool = true

@export_group("Nodes")
## Container the generated rows are put in. A vertical box inside the scroller.
@export var rows_path: NodePath = ^"Panel/Body/Scroll/Rows"
@export var save_button_path: NodePath = ^"Panel/Body/Footer/SaveButton"
## Optional line under the footer reporting what the last press did.
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"

@export_group("Rows")
## Colour and size of a weapon's heading.
@export var section_color := Color(0.85, 0.11, 0.11)
@export var section_font_size: int = 26
## Colour and size of a value's name.
@export var label_color := Color(0.72, 0.09, 0.1)
@export var label_font_size: int = 18
## How wide the names column is, in pixels, so the boxes line up down the panel.
@export var label_width: float = 240.0
## How wide a value box is, in pixels.
@export var value_width: float = 150.0
## Gap above a heading, so the weapons read as separate blocks.
@export var section_spacing: float = 18.0
## Largest value any box will accept. A ceiling rather than a balance decision -
## it only stops a slip of the keyboard producing a number nothing can recover from.
@export var value_maximum: float = 100000.0
## Smallest step a box moves in. Whole numbers, which is the grain everything in
## the game is actually tuned at.
@export var value_step: float = 1.0

@export_group("Status")
@export var saved_text: String = "SAVED  -  VALUES ARE LIVE AND WILL PERSIST"
@export var save_failed_text: String = "APPLIED, BUT COULD NOT BE WRITTEN TO DISK"
@export var unsaved_text: String = "UNSAVED CHANGES"
@export var idle_text: String = ""

# --- The tool sections ------------------------------------------------------------

@export_group("Tools")
## Whether the tool sections are built at all. Off leaves the panel exactly the
## weapon balance it was, for a build that should carry no developer controls.
@export var shows_tools: bool = true
## The ledger every contract lives in - the [code]Bounties[/code] autoload.
@export var ledger_path: NodePath = ^"/root/Bounties"
## The run's own state - the [code]RunSession[/code] autoload. Where the map, the
## region and the hour are set, and where they are read back from.
@export var session_path: NodePath = ^"/root/RunSession"
## The run's streak - the [code]Streak[/code] autoload.
@export var streak_path: NodePath = ^"/root/Streak"
## The blood the player is carrying - the [code]Blood[/code] autoload.
@export var wallet_path: NodePath = ^"/root/Blood"
## Group the player is found in, so the panel is not wired to them.
@export var player_group: StringName = &"player"
## Group the player's own [Health] is found in, which is what the heal and the kill
## go through.
@export var player_health_group: StringName = &"player_health"

@export_group("Tool rows")
## How wide a tool row's name column is, in pixels. Narrower than the balance rows'
## because the value beside it is a sentence rather than a number.
@export var info_label_width: float = 150.0
## How wide a tool row's value column is, in pixels.
@export var info_value_width: float = 300.0
@export var info_font_size: int = 17
## Colour a known or set value is written in.
@export var known_color := Color(0.86, 0.78, 0.72)
## Colour of a value that is missing, unknown or not applicable, so a gap reads as a
## gap at a glance down the panel.
@export var unknown_color := Color(0.5, 0.33, 0.32)

@export_group("Buttons")
## Colour the tool buttons are lettered in.
@export var button_font_color := Color(0.16, 0.06, 0.05)
## Padding inside a tool button, sideways and down.
##
## The styles are taken from the footer's SAVE button, which is half a menu wide and
## padded to match - a panel of thirty small buttons wants them tighter, and this is
## that without a second set of styles to keep in step. See [method _tighten].
@export var button_padding := Vector2(14.0, 2.0)
@export var button_font_size: int = 17

@export_group("Steps")
## Knowledge counts the SET KNOWLEDGE buttons offer. Each one reveals exactly that
## many of the contract's lines and hides the rest.
@export var knowledge_steps: Array[int] = [0, 1, 2, 3]
## Fractions of its pool the boss can be dropped to, as buttons. These are what
## drive [BossPhases] - its bands are read off the pool - so 0.49 is the enrage and
## 0.75 is the group of three.
@export var boss_health_steps: Array[float] = [1.0, 0.75, 0.5, 0.49, 0.1]
## Absolute hit points the last boss-health button sets, for the shot before the
## last one.
@export var boss_health_low: float = 1.0
## Support group sizes the wave buttons send in, matching the sizes the authored
## [MiniBossPhase] bands use.
@export var support_wave_sizes: Array[int] = [2, 3]
## How many men the SPAWN STARTING ENEMIES button stands round the boss - the group
## an encounter opens with.
@export var starting_support_count: int = 10
## Streak counts the SET STREAK buttons offer.
@export var streak_steps: Array[int] = [0, 1, 2, 3, 5]

@export_group("Presets")
@export var preset_easy_knowledge: int = 3
@export var preset_blind_knowledge: int = 0
## What ENRAGED BOSS drops the pool to - just under half, which is the band that
## stops the support and washes him red.
@export var preset_enraged_fraction: float = 0.49
## What BOSS DEFEAT leaves him on, in hit points, so the next shot finishes him.
@export var preset_defeat_health: float = 1.0
@export var preset_cash_out_blood: int = 250
@export var preset_cash_out_streak: int = 2

@export_group("Wording")
@export var weapon_heading: String = "WEAPON"
@export var bounty_heading: String = "BOUNTY / BOSS"
@export var world_heading: String = "WORLD"
@export var phase_heading: String = "BOSS PHASE TESTING"
@export var crate_heading: String = "AMMO CRATES"
@export var streak_heading: String = "STREAK / BLOOD"
@export var player_heading: String = "PLAYER"
@export var preset_heading: String = "PRESETS"
## What an unknown or missing value reads as.
@export var empty_text: String = "-"

@onready var _rows: Container = get_node_or_null(rows_path) as Container
@onready var _save_button: Button = get_node_or_null(save_button_path) as Button
@onready var _status: Label = get_node_or_null(status_label_path) as Label

var _store: DevBalanceStore
## The copy being edited. Everything the boxes write goes here and nowhere else,
## which is what makes an unsaved change harmless.
var _edited: DevBalance
var _dirty: bool = false

## Which taken contract the bounty section is pointed at, as a place in
## [method BountyLedger.get_active]. Held across a rebuild so the panel opens on the
## contract it was last looking at.
var _bounty_index: int = 0
## Which map, region and hour the world section is pointed at, as places in the
## catalogue's own arrays. Set from the run's current answers on every open.
var _map_index: int = 0
var _region_index: int = 0
var _time_index: int = 0

## The labels the tool sections write into, kept so a button press can refresh what
## the panel is showing without the rows being thrown away and built again - which
## would take the unsaved balance edits with them.
var _readouts: Dictionary = {}
## The box the carried blood is typed into.
var _blood_box: SpinBox
## Padded-down copies of the SAVE button's styles, made once and handed to every
## button rather than duplicated per row.
var _tightened: Dictionary = {}


func _ready() -> void:
	hide()
	_store = get_node_or_null(store_path) as DevBalanceStore
	if _save_button != null:
		_save_button.pressed.connect(save)
	_set_status(idle_text)


## P from anywhere, Escape while it is up. The press is marked handled either way,
## so the key that closes this cannot also reach the pause menu behind it or the
## game underneath.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(open_action):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return

	if visible and event.is_action_pressed(close_action):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Raises the panel on a fresh copy of the live values, so it always opens showing
## what the game is currently running rather than an edit that was abandoned last
## time.
func open() -> void:
	if visible:
		return

	_rebuild()
	show()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Drops the panel and throws the edit away. Deliberately: leaving it would mean a
## number the player can see is not the number the game is using, and the panel is
## the only place that could ever be true.
func close() -> void:
	if not visible:
		return

	hide()
	_edited = null
	_dirty = false
	_readouts.clear()
	_blood_box = null
	# Released at the viewport rather than box by box, so a row added later is
	# covered without being listed - a focused SpinBox would otherwise keep eating
	# the arrow keys once play resumed.
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


## Hands the edited copy to the store, which applies it to the game and writes it
## out. [b]This is the only thing in the balance rows that changes anything.[/b]
func save() -> void:
	if _store == null or _edited == null:
		return

	var written := _store.save(_edited)
	_dirty = false
	# A fresh copy afterwards, so the panel carries on editing something separate
	# from the balance it just handed over.
	_edited = _store.get_balance().working_copy()
	_set_status(saved_text if written else save_failed_text)
	saved.emit(_store.get_balance())


## Throws the rows away and builds them again. Called on every open rather than
## once, because the values - and the contracts, the boss and everything else the
## tools report on - can have moved since the last time it was up.
func _rebuild() -> void:
	if _rows == null:
		return

	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	_readouts.clear()
	_blood_box = null
	_dirty = false
	_set_status(idle_text)

	_add_weapon_section()
	if not shows_tools:
		return

	_take_world_from_session()
	_add_bounty_section()
	_add_world_section()
	_add_phase_section()
	_add_crate_section()
	_add_streak_section()
	_add_player_section()
	_add_preset_section()
	_refresh()


# --- The weapon balance -----------------------------------------------------------

## The balance rows, exactly as they were: one block per weapon, generated from the
## weapons the store is holding.
func _add_weapon_section() -> void:
	if _store == null:
		_add_heading("NO DEVELOPER BALANCE IS LOADED")
		return

	var live := _store.get_balance()
	if live == null:
		_add_heading("NO DEVELOPER BALANCE IS LOADED")
		return

	_add_heading(weapon_heading)
	_edited = live.working_copy()
	for weapon: DevWeaponBalance in _edited.weapons:
		if weapon != null:
			_add_weapon(weapon)


## One weapon: its name, then a row for each of its numbers, grouped under the
## headings the resource itself declares.
func _add_weapon(weapon: DevWeaponBalance) -> void:
	var title := weapon.display_name
	if title.is_empty():
		title = "UNNAMED WEAPON"
	_add_heading(title.to_upper())

	var group := ""
	for row: Dictionary in weapon.get_editable_rows():
		var row_group := String(row.get("group", ""))
		if row_group != group:
			group = row_group
			if not group.is_empty():
				_add_group_label(group)
		_add_row(weapon, row)


## One value: its name on the left, a box on the right. The box writes to the
## edited copy as it changes and to nothing else.
func _add_row(weapon: DevWeaponBalance, row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)

	var label := Label.new()
	label.text = String(row.get("label", ""))
	label.custom_minimum_size = Vector2(label_width, 0.0)
	label.add_theme_color_override(&"font_color", label_color)
	label.add_theme_font_size_override(&"font_size", label_font_size)
	line.add_child(label)

	var property := StringName(row.get("name", ""))
	var is_int: bool = row.get("is_int", false)

	var box := SpinBox.new()
	box.custom_minimum_size = Vector2(value_width, 0.0)
	box.min_value = 0.0
	box.max_value = value_maximum
	box.step = 1.0 if is_int else value_step
	box.rounded = is_int
	box.allow_greater = false
	box.select_all_on_focus = true
	box.value = float(weapon.get(property))
	box.value_changed.connect(
		func(value: float) -> void: _on_value_changed(weapon, property, value, is_int))
	line.add_child(box)

	_rows.add_child(line)


## Written into the edited copy only. The live balance, the ammunition and the
## bullet profiles are all untouched until SAVE.
func _on_value_changed(
	weapon: DevWeaponBalance, property: StringName, value: float, is_int: bool
) -> void:
	# Rounded rather than truncated, and set as the property's own type: a whole
	# number typed into a box for an int has to arrive as an int, or the resource
	# quietly holds a float where the game expects a count.
	if is_int:
		weapon.set(property, int(round(value)))
	else:
		weapon.set(property, value)
	_dirty = true
	_set_status(unsaved_text)


## Whether there are edits the player has not saved, for anything wanting to warn
## about them.
func has_unsaved_changes() -> bool:
	return _dirty


# --- Bounty and boss --------------------------------------------------------------

## The contract the boss is hunted on: which one is selected, everything it knows,
## and the four things that can be done to the man himself.
##
## Every line is driven by the categories [BountySettings] lists rather than by the
## three this game happens to have, so a fourth kind of knowledge appears here with
## its own reveal button and nothing in this file changed.
func _add_bounty_section() -> void:
	_add_heading(bounty_heading)

	_add_chooser("CONTRACT", &"bounty", _step_bounty)
	_add_info("NAME", &"bounty_name")
	_add_info("RARITY", &"bounty_rarity")
	_add_info("REWARD", &"bounty_reward")
	_add_info("KNOWLEDGE", &"bounty_knowledge")

	for category: BountyKnowledgeCategory in _knowledge_categories():
		if category == null:
			continue
		var key := StringName("fact_%s" % category.category_id)
		_add_info(category.display_name.to_upper(), key, [{
			"text": "REVEAL",
			"call": _reveal_fact.bind(category.category_id),
		}])

	var knowledge: Array[Dictionary] = []
	for count: int in knowledge_steps:
		knowledge.append({"text": str(count), "call": _set_knowledge.bind(count)})
	_add_actions("SET KNOWLEDGE", knowledge)

	_add_info("BOSS", &"boss_state")
	_add_actions("", [
		{"text": "FIND BOSS", "call": _find_boss},
		{"text": "TELEPORT TO BOSS", "call": _teleport_to_boss, "closes": true},
		{"text": "SPAWN / RESET BOSS", "call": _spawn_boss},
	])


## Moves the selection along the taken contracts, wrapping at both ends.
func _step_bounty(step: int) -> void:
	var taken := _taken_bounties()
	if taken.is_empty():
		return
	_bounty_index = posmod(_bounty_index + step, taken.size())
	_refresh()


## The contract the section is pointed at, or null when the player is holding none.
func _selected_bounty() -> Bounty:
	var taken := _taken_bounties()
	if taken.is_empty():
		return null
	_bounty_index = clampi(_bounty_index, 0, taken.size() - 1)
	return taken[_bounty_index]


## Learns one line, [b]through the ledger[/b] rather than by writing to the contract
## here. It is the same call a beaten boss makes, so pressing this exercises the real
## path - signals, poster redraw and all.
func _reveal_fact(category_id: StringName) -> void:
	var bounty := _selected_bounty()
	var ledger := _get_ledger()
	if bounty == null or ledger == null:
		_set_status("NO CONTRACT SELECTED")
		return

	if ledger.reveal(bounty.bounty_id, category_id):
		_set_status("REVEALED %s" % String(category_id).to_upper())
	else:
		_set_status("%s WAS ALREADY KNOWN" % String(category_id).to_upper())
	_refresh()


## Puts the selected contract on exactly [param count] pieces of knowledge.
##
## [b]It writes the remembered count as well as the lines.[/b] Which rung of boss a
## contract summons is read off [member Bounty.generated_knowledge] - see
## [method MiniBossDirector.get_accepted_knowledge] - and never off the live count,
## because a contract's difficulty must not move when the player learns something
## mid-run. So a debug control that only turned lines on would change what the poster
## prints and nothing at all about the fight, which is the opposite of what it is for.
##
## Turning a line back off is the one thing here that has no counterpart in play -
## knowledge is only ever gained - so it is done on the line itself and announced on
## the contract's own signal, which is what the posters redraw on.
func _set_knowledge(count: int) -> void:
	var bounty := _selected_bounty()
	if bounty == null:
		_set_status("NO CONTRACT SELECTED")
		return

	var wanted := clampi(count, 0, bounty.get_max_knowledge())
	for fact: BountyFact in bounty.facts:
		if fact != null:
			fact.known = false

	var ledger := _get_ledger()
	var learned := 0
	for fact: BountyFact in bounty.facts:
		if fact == null or learned >= wanted:
			continue
		if ledger != null:
			ledger.reveal(bounty.bounty_id, fact.category_id)
		else:
			fact.reveal()
		learned += 1

	bounty.generated_knowledge = wanted
	bounty.bounty_changed.emit()
	_set_status("KNOWLEDGE SET TO %d - THE RUNG THE BOSS IS BUILT FROM MOVED WITH IT" % wanted)
	_refresh()


## Says where the boss is, or - when there is none standing - why this region has not
## produced one.
##
## [b]It commits to nothing.[/b] Every answer comes from
## [method MiniBossDirector.matches_situation] and
## [method MiniBossDirector.get_situation_value], which are the same two questions the
## world asks itself when it is built, so what this prints is the real rule being
## evaluated rather than a second copy of it.
func _find_boss() -> void:
	var director := MiniBossDirector.get_active(self)
	if director == null:
		_set_status("THERE IS NO BOSS SYSTEM IN THIS WORLD")
		return

	var boss := director.get_boss()
	if boss != null and is_instance_valid(boss):
		var player := _get_player()
		var away := 0.0 if player == null else player.global_position.distance_to(boss.global_position)
		_set_status("BOSS AT %d, %d  -  %d PX AWAY" % [
			int(boss.global_position.x), int(boss.global_position.y), int(away)])
		return

	var bounty := _selected_bounty()
	if bounty == null:
		_set_status("NO CONTRACT TAKEN - NOTHING CAN SUMMON A BOSS")
		return
	if director.matches_situation(bounty):
		_set_status("THIS CONTRACT MATCHES - PRESS SPAWN / RESET BOSS")
		return

	var wrong := PackedStringArray()
	for category_id: StringName in director.required_categories:
		var here := director.get_situation_value(category_id)
		var there := bounty.get_fact_value(category_id)
		if not bounty.is_known(category_id):
			wrong.append("%s UNKNOWN" % String(category_id).to_upper())
		elif here != there:
			wrong.append("%s %s / HERE %s" % [
				String(category_id).to_upper(), _or_dash(there), _or_dash(here)])
	if wrong.is_empty():
		_set_status("THIS CONTRACT IS NOT OUTSTANDING")
		return
	_set_status("NO MATCH  -  %s" % "  ".join(wrong))


## Stands the player next to the boss, which is what starts the encounter: the
## director's own approach check sees them arrive and plays the introduction, exactly
## as walking there would.
func _teleport_to_boss() -> void:
	var director := MiniBossDirector.get_active(self)
	var player := _get_player()
	if director == null or player == null:
		_set_status("NO BOSS AND NO PLAYER TO CARRY")
		return

	var boss := director.get_boss()
	if boss == null or not is_instance_valid(boss):
		_set_status("NO BOSS IS STANDING - PRESS SPAWN / RESET BOSS")
		return

	# Just inside the trigger, rather than on top of him: the introduction should be
	# reached by arriving, and a player standing in the middle of the man is a player
	# the fight starts inside.
	player.global_position = boss.global_position \
		- Vector2.RIGHT * maxf(director.trigger_radius * 0.5, 1.0)
	# Physics interpolation is on project-wide; without this the player is visibly
	# smeared across the map from wherever they were standing.
	player.reset_physics_interpolation()
	_set_status("CARRIED TO THE BOSS")


## Takes down whatever encounter is standing and asks for a fresh one.
##
## The order is the teardown's own: the support stops, the ending disarms, the fixed
## screen is handed back, the bodies go, and only then is [method MiniBossDirector.begin]
## asked - which is the same call [WorldBoot] makes when a world comes up on a boss day,
## so a boss spawned from here is placed, dressed, marked and announced exactly as one
## found by riding into the right region at the right hour.
func _spawn_boss() -> void:
	var director := MiniBossDirector.get_active(self)
	if director == null:
		_set_status("THERE IS NO BOSS SYSTEM IN THIS WORLD")
		return

	var phases := BossPhases.get_active(self)
	if phases != null:
		phases.reset()
	var defeat := BossDefeat.get_active(self)
	if defeat != null:
		defeat.reset()
	var arena := BossArena.get_active(self)
	if arena != null:
		arena.unlock()
	director.reset_encounter()

	var placed := director.begin()
	if placed <= 0:
		_set_status("NO BOSS PLACED - PRESS FIND BOSS TO SEE WHY")
	else:
		_set_status("BOSS PLACED WITH %d BODIES - WALK OR TELEPORT TO HIM" % placed)
	_refresh()


# --- The world --------------------------------------------------------------------

## Where and when the run thinks it is: the map, the part of it, and the hour.
##
## [b]It sets the run's own answers and nothing else.[/b] All three go into
## [RunSessionState] - the hour through it and on into [DayClock], which is the one
## place the time of day lives - so the boss's match, the world's darkness and the
## HUD's icon are all reading the same numbers they always did. The scenery around the
## player does not change until the world is next built, exactly as
## [method DayClock.set_stage_index] says.
func _add_world_section() -> void:
	_add_heading(world_heading)

	_add_chooser("MAP", &"map", _step_map)
	_add_chooser("REGION", &"region", _step_region)
	_add_chooser("TIME OF DAY", &"time", _step_time)
	_add_info("RUN IS AT", &"world_now")
	_add_actions("", [{"text": "APPLY WORLD STATE", "call": _apply_world}])


func _step_map(step: int) -> void:
	var maps := _all_maps()
	if maps.is_empty():
		return
	_map_index = posmod(_map_index + step, maps.size())
	# A region and an hour only mean anything against the map that owns them - the
	# desert's C is not a town's C - so both are taken back to that map's first.
	_region_index = 0
	_time_index = 0
	_refresh()


func _step_region(step: int) -> void:
	var regions := _map_regions()
	if regions.is_empty():
		return
	_region_index = posmod(_region_index + step, regions.size())
	_refresh()


func _step_time(step: int) -> void:
	var stages := _map_stages()
	if stages.is_empty():
		return
	_time_index = posmod(_time_index + step, stages.size())
	_refresh()


## Hands the three choices to the run, in the order the player's own screens hand
## them over: map, then the part of it, then the hour. Choosing the map is what
## clears the region, so it has to go first.
func _apply_world() -> void:
	var session := _get_session()
	if session == null:
		_set_status("THERE IS NO RUN SESSION TO SET")
		return

	var map := _selected_map()
	if map == null:
		_set_status("THE MAP CATALOGUE IS EMPTY")
		return

	session.begin(map.map_id)

	var region := _selected_region()
	if region != null:
		session.choose_region(region.region_id)

	var stage := _selected_stage()
	var hour := "-"
	if stage != null and session.choose_time(stage.stage_name):
		hour = stage.display_name

	_set_status("RUN SET TO %s / %s / %s  -  THE SCENERY FOLLOWS ON THE NEXT WORLD" % [
		map.display_name,
		"-" if region == null else region.display_name,
		hour,
	])
	_refresh()


# --- Boss phase testing -----------------------------------------------------------

## The fight itself: where the boss's pool is, and the support that arrives because of
## it.
##
## [b]Every button here moves the pool and lets the systems answer.[/b] [BossPhases]
## reads the fight off [signal Health.health_changed] and [BossDefeat] catches the
## lethal one, so dropping the boss to 49% enrages him through the real band change and
## killing him plays the real ending - the reward, the streak, the fall, the name and
## the way home.
func _add_phase_section() -> void:
	_add_heading(phase_heading)

	var health: Array[Dictionary] = []
	for fraction: float in boss_health_steps:
		health.append({
			"text": "HP %d%%" % int(round(clampf(fraction, 0.0, 1.0) * 100.0)),
			"call": _set_boss_fraction.bind(fraction),
		})
	health.append({
		"text": "HP %d" % int(round(boss_health_low)),
		"call": _set_boss_health.bind(boss_health_low),
	})
	health.append({"text": "KILL BOSS", "call": _kill_boss, "closes": true})
	_add_actions("BOSS HEALTH", health)

	var waves: Array[Dictionary] = []
	for wave: int in support_wave_sizes:
		waves.append({
			"text": "%d-ENEMY WAVE" % wave,
			"call": _send_support_wave.bind(wave),
		})
	waves.append({"text": "STOP SUPPORT SPAWNING", "call": _stop_support})
	waves.append({
		"text": "SPAWN %d STARTING ENEMIES" % starting_support_count,
		"call": _spawn_starting_enemies,
	})
	_add_actions("SUPPORT", waves)


## Drops the boss to [param fraction] of its ceiling.
func _set_boss_fraction(fraction: float) -> void:
	var health := _boss_health()
	if health == null:
		_set_status("NO BOSS IS STANDING")
		return
	_set_boss_health(health.get_max() * clampf(fraction, 0.0, 1.0))


## Puts the boss's pool at [param value] hit points.
##
## Through [method Health.set_current], which announces the change without being a hit:
## no flash, no blood and no knockback, but [BossPhases] still hears it and still
## changes band, because the fight is read off the pool rather than off the damage.
func _set_boss_health(value: float) -> void:
	var health := _boss_health()
	if health == null:
		_set_status("NO BOSS IS STANDING")
		return

	health.set_current(value)
	_set_status("BOSS ON %d / %d" % [int(health.get_current()), int(health.get_max())])
	_refresh()


## The last shot, dealt as damage rather than written into the pool - so it goes
## through exactly the path a shell does and [BossDefeat] answers it with the whole
## ending rather than the boss quietly disappearing.
func _kill_boss() -> void:
	var health := _boss_health()
	if health == null:
		_set_status("NO BOSS IS STANDING")
		return
	health.take_damage(health.get_current())
	_set_status("THE LAST SHOT LANDED")


## One group of reinforcements now, through the phase system's own arrivals - so they
## are put down outside the picture and walked in through the fence exactly as a band's
## own group is.
func _send_support_wave(count: int) -> void:
	var phases := BossPhases.get_active(self)
	if phases == null:
		_set_status("THERE IS NO PHASE SYSTEM IN THIS WORLD")
		return

	var sent := phases.spawn_support_group(count)
	if sent > 0:
		_set_status("SENT %d IN FROM OUTSIDE THE PICTURE" % sent)
	else:
		_set_status("NOTHING COULD BE SENT IN")
	_refresh()


func _stop_support() -> void:
	var phases := BossPhases.get_active(self)
	if phases == null:
		_set_status("THERE IS NO PHASE SYSTEM IN THIS WORLD")
		return
	phases.stop()
	_set_status("SUPPORT SPAWNING STOPPED - WHAT IS ALREADY STANDING IS LEFT ALONE")
	_refresh()


## The group an encounter opens with, stood round the boss - the director's own, so
## they are built, toughened and counted as the men who were already there.
func _spawn_starting_enemies() -> void:
	var director := MiniBossDirector.get_active(self)
	if director == null:
		_set_status("THERE IS NO BOSS SYSTEM IN THIS WORLD")
		return

	var built := director.spawn_support_group(starting_support_count)
	if built > 0:
		_set_status("STOOD %d MEN UP ROUND HIM" % built)
	else:
		_set_status("NOBODY COULD BE STOOD UP")
	_refresh()


# --- Ammunition crates ------------------------------------------------------------

## The crate supply: how many are lying uncollected, and the two things worth doing to
## them. The ceiling is the spawner's own - see [member AmmoCrateSpawner.max_uncollected] -
## so a press that finds three already standing drops nothing, exactly as the ten-second
## clock does.
func _add_crate_section() -> void:
	_add_heading(crate_heading)
	_add_info("UNCOLLECTED", &"crates")
	_add_actions("", [
		{"text": "SPAWN CRATE", "call": _spawn_crate},
		{"text": "CLEAR CRATES", "call": _clear_crates},
	])


func _spawn_crate() -> void:
	var crates := AmmoCrateSpawner.get_active(self)
	if crates == null:
		_set_status("THERE IS NO CRATE SUPPLY IN THIS WORLD")
		return

	if crates.spawn_crate() == null:
		_set_status("NO CRATE - %d ARE ALREADY WAITING" % crates.get_uncollected())
	else:
		_set_status("CRATE DROPPED")
	_refresh()


func _clear_crates() -> void:
	var crates := AmmoCrateSpawner.get_active(self)
	if crates == null:
		_set_status("THERE IS NO CRATE SUPPLY IN THIS WORLD")
		return
	crates.clear_crates()
	_set_status("CRATES CLEARED")
	_refresh()


# --- Streak and blood -------------------------------------------------------------

## What the ride home will be worth: the outlaws on the tally, the blood in the
## player's hands, and the screen that turns the two into money.
func _add_streak_section() -> void:
	_add_heading(streak_heading)

	_add_info("STREAK", &"streak")
	var steps: Array[Dictionary] = []
	for count: int in streak_steps:
		steps.append({"text": str(count), "call": _set_streak.bind(count)})
	_add_actions("SET STREAK", steps)

	_add_blood_row()
	_add_actions("", [{"text": "OPEN CASH-OUT", "call": _open_cash_out, "closes": true}])


## The carried blood, as a box and a button rather than as steps: the amount worth
## testing with is whatever the thing being tested needs.
func _add_blood_row() -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)

	var label := Label.new()
	label.text = "CARRIED BLOOD"
	label.custom_minimum_size = Vector2(info_label_width, 0.0)
	label.add_theme_color_override(&"font_color", label_color)
	label.add_theme_font_size_override(&"font_size", info_font_size)
	line.add_child(label)

	_blood_box = SpinBox.new()
	_blood_box.custom_minimum_size = Vector2(value_width, 0.0)
	_blood_box.min_value = 0.0
	_blood_box.max_value = value_maximum
	_blood_box.step = 1.0
	_blood_box.rounded = true
	_blood_box.allow_greater = false
	_blood_box.select_all_on_focus = true
	_blood_box.value = float(_carried_blood())
	line.add_child(_blood_box)

	var button := _build_button("SET")
	button.pressed.connect(_on_blood_set)
	line.add_child(button)

	_rows.add_child(line)


func _on_blood_set() -> void:
	if _blood_box != null:
		_set_blood(int(round(_blood_box.value)))


## Moves the carried total to [param amount] through the wallet's own deposit and
## spend, so nothing here can mint or strand blood in a way the rest of the game
## cannot.
func _set_blood(amount: int) -> void:
	var wallet := _get_wallet()
	if wallet == null:
		_set_status("THERE IS NO WALLET TO SET")
		return

	var wanted := maxi(amount, 0)
	var now := wallet.get_total()
	if wanted > now:
		wallet.add(wanted - now)
	elif wanted < now:
		wallet.spend(now - wanted)

	_set_status("CARRYING %d BLOOD" % wallet.get_total())
	_refresh()


## Sets the tally to exactly [param count], by giving the current one up and counting
## the new one on - both of which are the counter's own calls, so everything following
## the streak hears it change.
func _set_streak(count: int) -> void:
	var streak := _get_streak()
	if streak == null:
		_set_status("THERE IS NO STREAK TO SET")
		return

	streak.reset()
	streak.add(maxi(count, 0))
	_set_status("STREAK %d  -  PAYS x%d" % [streak.get_streak(), streak.get_multiplier()])
	_refresh()


## The real screen the camp raises on the way home, opened where the player stands.
## Nothing about it is copied: it reads the same wallet and the same streak, and
## CONTINUE banks the run for real.
func _open_cash_out() -> void:
	var screen := CashOutScreen.get_active(self)
	if screen == null:
		_set_status("THERE IS NO CASH-OUT SCREEN IN THIS WORLD")
		return
	screen.open()


# --- The player -------------------------------------------------------------------

func _add_player_section() -> void:
	_add_heading(player_heading)
	_add_info("HEALTH", &"player_health")
	_add_actions("", [
		{"text": "FULL HEAL", "call": _full_heal},
		{"text": "KILL PLAYER", "call": _kill_player, "closes": true},
	])


func _full_heal() -> void:
	var health := _get_player_health()
	if health == null:
		_set_status("THERE IS NO PLAYER TO HEAL")
		return
	health.restore_full()
	_set_status("HEALED TO %d" % int(health.get_max()))
	_refresh()


## The real death: [method Health.kill] empties the pool through the ordinary damage
## path, so [PlayerDeathSequence] answers it with the whole failure - the slow motion,
## the fall, the blood and the streak lost, the ride home and the revival.
func _kill_player() -> void:
	var health := _get_player_health()
	if health == null:
		_set_status("THERE IS NO PLAYER TO KILL")
		return
	health.kill()
	_set_status("PLAYER KILLED")


# --- Presets ----------------------------------------------------------------------

## The setups worth reaching in one press. Each is the buttons above it, called in
## order - there is nothing here that cannot be done by hand.
func _add_preset_section() -> void:
	_add_heading(preset_heading)
	_add_actions("", [
		{
			"text": "EASY BOSS  (%d KNOWLEDGE)" % preset_easy_knowledge,
			"call": _set_knowledge.bind(preset_easy_knowledge),
		},
		{
			"text": "BLIND BOSS  (%d KNOWLEDGE)" % preset_blind_knowledge,
			"call": _set_knowledge.bind(preset_blind_knowledge),
		},
		{
			"text": "ENRAGED BOSS  (%d%% HP)" % int(round(preset_enraged_fraction * 100.0)),
			"call": _set_boss_fraction.bind(preset_enraged_fraction),
		},
		{
			"text": "BOSS DEFEAT  (%d HP)" % int(round(preset_defeat_health)),
			"call": _set_boss_health.bind(preset_defeat_health),
		},
		{"text": "CASH-OUT TEST", "call": _preset_cash_out},
	])


func _preset_cash_out() -> void:
	_set_blood(preset_cash_out_blood)
	_set_streak(preset_cash_out_streak)
	_set_status("CARRYING %d BLOOD ON A STREAK OF %d" % [
		preset_cash_out_blood, preset_cash_out_streak])


# --- What the panel is showing ----------------------------------------------------

## Rewrites every readout in the tool sections from the systems themselves.
##
## [b]The rows are not rebuilt.[/b] Throwing them away would take the unsaved balance
## edits with them, so a press only ever changes what the labels say - which is also
## why every value here is asked for again rather than remembered.
func _refresh() -> void:
	# An empty set of readouts is a panel that has been closed - its rows were freed
	# with it - so there is nothing to write and nothing to look up.
	if _readouts.is_empty():
		return

	_refresh_bounty()
	_refresh_world()
	_write(&"boss_state", _boss_summary(), true)
	_refresh_crates()
	_refresh_player()

	var streak := _get_streak()
	if streak == null:
		_write(&"streak", empty_text, false)
	else:
		_write(&"streak", "%d  -  PAYS x%d" % [streak.get_streak(), streak.get_multiplier()], true)


func _refresh_bounty() -> void:
	var taken := _taken_bounties()
	var bounty := _selected_bounty()
	if bounty == null:
		_write(&"bounty", "NO CONTRACT TAKEN", false)
		_write(&"bounty_name", empty_text, false)
		_write(&"bounty_rarity", empty_text, false)
		_write(&"bounty_reward", empty_text, false)
		_write(&"bounty_knowledge", empty_text, false)
		for category: BountyKnowledgeCategory in _knowledge_categories():
			if category != null:
				_write(StringName("fact_%s" % category.category_id), empty_text, false)
		return

	_write(&"bounty", "%d / %d  %s" % [
		_bounty_index + 1, taken.size(), _poster_name(bounty)], true)
	_write(&"bounty_name", _poster_name(bounty), true)

	var ledger := _get_ledger()
	var settings: BountySettings = null if ledger == null else ledger.get_settings()
	var rarity := bounty.get_rarity(settings)
	_write(&"bounty_rarity", empty_text if rarity == null else rarity.display_name,
		rarity != null)
	_write(&"bounty_reward", "%d BLOOD%s" % [
		bounty.reward, "  [LOCKED]" if bounty.is_reward_locked() else ""], true)
	_write(&"bounty_knowledge", "%d / %d  (DEALT WITH %d)" % [
		bounty.get_knowledge_count(),
		bounty.get_max_knowledge(),
		bounty.get_generated_knowledge()], true)

	for category: BountyKnowledgeCategory in _knowledge_categories():
		if category == null:
			continue
		var fact := bounty.get_fact(category.category_id)
		var key := StringName("fact_%s" % category.category_id)
		if fact == null:
			_write(key, "%s  (NO LINE)" % category.unknown_text, false)
			continue
		# The answer behind the question mark is shown deliberately: seeing that the
		# region was always C before anything revealed it is what proves revealing
		# turns a flag on rather than deciding an answer late.
		_write(key, fact.describe(category.unknown_text), fact.known)


func _refresh_world() -> void:
	var map := _selected_map()
	_write(&"map", empty_text if map == null else map.display_name, map != null)

	var region := _selected_region()
	_write(&"region", empty_text if region == null else region.get_label(), region != null)

	var stage := _selected_stage()
	_write(&"time", empty_text if stage == null else stage.display_name, stage != null)

	var session := _get_session()
	if session == null:
		_write(&"world_now", empty_text, false)
		return
	_write(&"world_now", "%s / %s / %s" % [
		_or_dash(session.get_map_id()),
		_or_dash(session.get_region_id()),
		_or_dash(session.get_time_id()),
	], session.is_running())


func _refresh_crates() -> void:
	var crates := AmmoCrateSpawner.get_active(self)
	if crates == null:
		_write(&"crates", empty_text, false)
		return
	_write(&"crates", "%d / %d STANDING%s" % [
		crates.get_uncollected(),
		crates.max_uncollected,
		"  -  SUPPLY RUNNING" if crates.is_running() else "",
	], true)


func _refresh_player() -> void:
	var health := _get_player_health()
	if health == null:
		_write(&"player_health", empty_text, false)
		return
	_write(&"player_health", "%d / %d" % [
		int(ceil(health.get_current())), int(ceil(health.get_max()))], health.is_alive())


## The encounter in one line: how far it has got, what the boss has left, how many are
## standing with him, and how far the ending has run.
func _boss_summary() -> String:
	var director := MiniBossDirector.get_active(self)
	if director == null:
		return "NO BOSS SYSTEM"

	var parts := PackedStringArray([_phase_name(director.get_phase())])

	var health := _boss_health()
	if health != null:
		var ceiling := maxf(health.get_max(), 0.0001)
		parts.append("HP %d / %d  (%d%%)" % [
			int(health.get_current()), int(health.get_max()),
			int(round(health.get_current() / ceiling * 100.0))])
		parts.append("SUPPORT %d" % director.get_support_alive())

	var phases := BossPhases.get_active(self)
	if phases != null and phases.is_running():
		var band := phases.get_phase()
		parts.append("BAND %d%s" % [
			phases.get_phase_index() + 1,
			"" if band == null or band.phase_name.is_empty() else "  %s" % band.phase_name])

	var defeat := BossDefeat.get_active(self)
	if defeat != null and defeat.is_defeated():
		parts.append("BEATEN")

	return "  -  ".join(parts)


func _phase_name(phase: int) -> String:
	var names := MiniBossDirector.Phase.keys()
	if phase < 0 or phase >= names.size():
		return "UNKNOWN"
	return String(names[phase])


# --- Building rows ----------------------------------------------------------------

func _add_heading(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, section_spacing)
	_rows.add_child(spacer)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", section_color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_font_size_override(&"font_size", section_font_size)
	_rows.add_child(label)


func _add_group_label(text: String) -> void:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_color_override(&"font_color", label_color * Color(1.0, 1.0, 1.0, 0.7))
	label.add_theme_font_size_override(&"font_size", maxi(label_font_size - 4, 8))
	_rows.add_child(label)


## One readout: its name on the left, whatever it currently says on the right, and
## any buttons that belong to that line after it.
##
## The value label is filed under [param key] rather than returned, so
## [method _refresh] can write to every line in the panel without any of them being
## held in a named field.
func _add_info(title: String, key: StringName, actions: Array = []) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(info_label_width, 0.0)
	label.add_theme_color_override(&"font_color", label_color)
	label.add_theme_font_size_override(&"font_size", info_font_size)
	line.add_child(label)

	var value := Label.new()
	value.text = empty_text
	value.custom_minimum_size = Vector2(info_value_width, 0.0)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override(&"font_color", known_color)
	value.add_theme_font_size_override(&"font_size", info_font_size)
	line.add_child(value)
	_readouts[key] = value

	for action: Dictionary in actions:
		line.add_child(_action_button(action))

	_rows.add_child(line)


## One choice: its name, a step back, what is currently picked, and a step on.
## [param step] is called with -1 and 1.
func _add_chooser(title: String, key: StringName, step: Callable) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(info_label_width, 0.0)
	label.add_theme_color_override(&"font_color", label_color)
	label.add_theme_font_size_override(&"font_size", info_font_size)
	line.add_child(label)

	var back := _build_button("<")
	back.pressed.connect(step.bind(-1))
	line.add_child(back)

	# Deliberately not expanding, so the two steps sit either side of what is picked
	# rather than at opposite ends of the panel.
	var value := Label.new()
	value.text = empty_text
	value.custom_minimum_size = Vector2(info_value_width, 0.0)
	value.add_theme_color_override(&"font_color", known_color)
	value.add_theme_font_size_override(&"font_size", info_font_size)
	line.add_child(value)
	_readouts[key] = value

	var on := _build_button(">")
	on.pressed.connect(step.bind(1))
	line.add_child(on)

	_rows.add_child(line)


## A block of buttons under [param title], wrapped onto as many lines as the panel's
## width needs - so a section can grow another button without anything being measured
## or a width being retuned.
func _add_actions(title: String, actions: Array) -> void:
	if not title.is_empty():
		_add_group_label(title)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 8)
	flow.add_theme_constant_override(&"v_separation", 6)
	for action: Dictionary in actions:
		flow.add_child(_action_button(action))
	_rows.add_child(flow)


## One button off a [code]{text, call, closes}[/code] description.
func _action_button(action: Dictionary) -> Button:
	var button := _build_button(String(action.get("text", "")))
	var pressed: Callable = action.get("call", Callable())
	var closes: bool = action.get("closes", false)
	button.pressed.connect(_run_action.bind(pressed, closes))
	return button


## Runs one action.
##
## [param closes] drops the panel first, and it is what the handful of buttons whose
## result has to be [i]watched[/i] are marked with: the world is frozen while the panel
## is up - see [member pauses_game] - so a death, an introduction or a cash-out
## triggered from behind it would sit there half played until the panel came down.
func _run_action(action: Callable, closes: bool) -> void:
	if closes:
		close()
	if action.is_valid():
		action.call()


## A button in the game's own dress.
##
## The styles are the footer's SAVE button's own - see [method _button_style] - so the
## panel's buttons are the game's buttons without a second set of styles existing
## anywhere or a single colour being written into this script.
func _build_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", button_font_size)
	button.add_theme_color_override(&"font_color", button_font_color)
	button.add_theme_color_override(&"font_hover_color", button_font_color.lightened(0.2))
	button.add_theme_color_override(&"font_pressed_color", Color.WHITE)

	var normal := _tighten(_button_style(&"normal"))
	if normal != null:
		button.add_theme_stylebox_override(&"normal", normal)
		button.add_theme_stylebox_override(&"focus", normal)
		button.add_theme_stylebox_override(&"disabled", normal)
	var hover := _tighten(_button_style(&"hover"))
	if hover != null:
		button.add_theme_stylebox_override(&"hover", hover)
	var pressed := _tighten(_button_style(&"pressed"))
	if pressed != null:
		button.add_theme_stylebox_override(&"pressed", pressed)
	return button


## Where the buttons get their look from: the SAVE button in the panel's own footer,
## which is styled in the scene alongside every other menu in the game. A panel whose
## footer has been taken away falls back to the theme rather than to colours written
## here.
func _button_style(style_name: StringName) -> StyleBox:
	if _save_button == null or not is_instance_valid(_save_button):
		return null
	return _save_button.get_theme_stylebox(style_name)


## A copy of [param style] padded for a dense panel rather than for a menu footer,
## made once per style. [b]Copied rather than edited[/b] - the style belongs to the
## HUD scene and is shared with the menus the player uses, and repadding it here would
## repad those too.
func _tighten(style: StyleBox) -> StyleBox:
	if style == null:
		return null
	if _tightened.has(style):
		return _tightened[style]

	var copy := style.duplicate() as StyleBox
	copy.content_margin_left = button_padding.x
	copy.content_margin_right = button_padding.x
	copy.content_margin_top = button_padding.y
	copy.content_margin_bottom = button_padding.y
	_tightened[style] = copy
	return copy


## Writes one readout, in the colour that says whether it is an answer or a gap.
func _write(key: StringName, text: String, known: bool) -> void:
	var label := _readouts.get(key) as Label
	if label == null or not is_instance_valid(label):
		return
	label.text = text
	label.add_theme_color_override(&"font_color", known_color if known else unknown_color)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


# --- Looking things up ------------------------------------------------------------

func _get_ledger() -> BountyLedger:
	return get_node_or_null(ledger_path) as BountyLedger


func _get_session() -> RunSessionState:
	return get_node_or_null(session_path) as RunSessionState


func _get_streak() -> StreakCounter:
	return get_node_or_null(streak_path) as StreakCounter


func _get_wallet() -> BloodWallet:
	return get_node_or_null(wallet_path) as BloodWallet


func _carried_blood() -> int:
	var wallet := _get_wallet()
	return 0 if wallet == null else wallet.get_total()


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D


## The player's pool, found by its own group rather than by a path through the world,
## so the panel is not wired to where the player happens to sit in the scene.
func _get_player_health() -> Health:
	var health := get_tree().get_first_node_in_group(player_health_group) as Health
	if health != null:
		return health

	var player := _get_player()
	if player == null:
		return null
	for node: Node in player.find_children("*", "Health", true, false):
		var found := node as Health
		if found != null:
			return found
	return null


## The boss's own pool, or null when there is no boss standing.
func _boss_health() -> Health:
	var director := MiniBossDirector.get_active(self)
	if director == null:
		return null
	var boss := director.get_boss()
	if boss == null or not is_instance_valid(boss):
		return null
	for node: Node in boss.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


func _taken_bounties() -> Array[Bounty]:
	var none: Array[Bounty] = []
	var ledger := _get_ledger()
	return none if ledger == null else ledger.get_active()


func _knowledge_categories() -> Array[BountyKnowledgeCategory]:
	var none: Array[BountyKnowledgeCategory] = []
	var ledger := _get_ledger()
	if ledger == null:
		return none
	var settings := ledger.get_settings()
	return none if settings == null else settings.knowledge_categories


func _poster_name(bounty: Bounty) -> String:
	if bounty == null or bounty.target == null or bounty.target.display_name.is_empty():
		return "THE OUTLAW"
	return bounty.target.display_name


func _all_maps() -> Array[MapDefinition]:
	var none: Array[MapDefinition] = []
	var session := _get_session()
	if session == null:
		return none
	var catalog := session.get_map_catalog()
	return none if catalog == null else catalog.maps


func _selected_map() -> MapDefinition:
	var maps := _all_maps()
	if maps.is_empty():
		return null
	_map_index = clampi(_map_index, 0, maps.size() - 1)
	return maps[_map_index]


func _map_regions() -> Array[MapRegion]:
	var none: Array[MapRegion] = []
	var map := _selected_map()
	return none if map == null else map.regions


func _selected_region() -> MapRegion:
	var regions := _map_regions()
	if regions.is_empty():
		return null
	_region_index = clampi(_region_index, 0, regions.size() - 1)
	return regions[_region_index]


func _map_stages() -> Array[DayStage]:
	var none: Array[DayStage] = []
	var map := _selected_map()
	return none if map == null else map.day_stages


func _selected_stage() -> DayStage:
	var stages := _map_stages()
	if stages.is_empty():
		return null
	_time_index = clampi(_time_index, 0, stages.size() - 1)
	return stages[_time_index]


## Points the world section at wherever the run currently is, so it opens showing the
## truth rather than the first entry in each list.
func _take_world_from_session() -> void:
	var session := _get_session()
	if session == null:
		return

	var maps := _all_maps()
	for index: int in range(maps.size()):
		if maps[index] != null and maps[index].map_id == session.get_map_id():
			_map_index = index
			break

	var regions := _map_regions()
	for index: int in range(regions.size()):
		if regions[index] != null and regions[index].region_id == session.get_region_id():
			_region_index = index
			break

	var stages := _map_stages()
	for index: int in range(stages.size()):
		if stages[index] != null and stages[index].stage_name == session.get_time_id():
			_time_index = index
			break


func _or_dash(id: StringName) -> String:
	return empty_text if id == &"" else String(id).to_upper()
