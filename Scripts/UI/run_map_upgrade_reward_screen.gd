class_name RunMapUpgradeRewardScreen
extends Control
## What a won fight at a run map point opens onto before the ride back to the
## map: one free, run-only weapon upgrade for the weapon in the player's hands,
## shown and taken.
##
## [b]It opens itself, and only when the point pays.[/b] It listens for
## [signal WorldMapCombatBridge.encounter_ended] and asks the bridge which kind of
## point the fight was opened from - [method WorldMapCombatBridge.get_site_kind].
## A win at a kind one of [member rewards] pays for draws the upgrade and holds
## the ride home ([method WorldMapCombatBridge.hold_the_return]) until TAKE; every
## other ending - a death, a free-roam fight, a point that pays nothing, a weapon
## with nothing left to give - leaves the bridge to go home exactly as it always
## has.
##
## [b]It owns no upgrade system.[/b] What is drawn and how it is delivered is
## [RunMapUpgradeReward]'s, which is the Market's pool and the Market's
## [RunMapUpgradeGood] with the price taken off: the level goes onto the weapon's
## run stack and nothing is charged to the carried blood or the [BloodBank].
##
## [b]A reward with a choice to make is shown as a selection.[/b] When the
## reward's [member RunMapUpgradeReward.choices] is above one, the single upgrade
## and TAKE are put away and each pick is dealt as that many rows - copies of a
## row authored in the scene - of which exactly one is taken. Once
## [member RunMapUpgradeReward.picks] have been taken the ride home goes; what was
## just taken is kept out of the next selection while enough else is left.

## Emitted once for every upgrade taken - for a selection, as each row is chosen.
signal taken(weapon: WeaponDefinition, upgrade: WeaponUpgrade)

## What each kind of point pays. The first entry that pays for the point's kind
## is the one used.
@export var rewards: Array[RunMapUpgradeReward] = []
## The run's state, asked which weapon is carried when no [WeaponMount] answers.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Wording")
## Headed on a common upgrade.
@export var common_heading: String = "WEAPON UPGRADE"
## Headed on a Unique upgrade.
@export var unique_heading: String = "UNIQUE UPGRADE"
## The resulting run level: [code]%d[/code] is the level the stack reaches.
@export var level_format: String = "RUN LEVEL %d"
## Under the upgrade, so it is plain the level is this run's only.
@export var note_text: String = "FREE  -  FOR THIS RUN ONLY"
## Headed over a selection: the pick being made, then how many there are.
@export var choose_heading_format: String = "CHOOSE ONE  -  %d OF %d"
## How a selection row reads: the name, the effect, then the resulting run level.
@export var choice_format: String = "%s\n%s\n%s"
## How a Unique row's name is written.
@export var unique_name_format: String = "UNIQUE: %s"

@export_group("Colours")
## The heading's colour on a common upgrade.
@export var common_color: Color = Color(0.72, 0.66, 0.6, 1)
## The heading's colour on a Unique upgrade.
@export var unique_color: Color = Color(1, 0.82, 0.25, 1)
## The lettering of a Unique row in a selection - dark enough to read on the
## row's button.
@export var unique_row_color: Color = Color(0.55, 0.33, 0.0, 1)

@export_group("Wiring")
@export var heading_label_path: NodePath = ^"Panel/Body/Heading"
@export var weapon_label_path: NodePath = ^"Panel/Body/Weapon"
@export var name_label_path: NodePath = ^"Panel/Body/UpgradeName"
@export var effect_label_path: NodePath = ^"Panel/Body/Effect"
@export var level_label_path: NodePath = ^"Panel/Body/Level"
@export var note_label_path: NodePath = ^"Panel/Body/Note"
@export var take_button_path: NodePath = ^"Panel/Body/Take"
## Where a selection's rows are put.
@export var choices_path: NodePath = ^"Panel/Body/Choices"
## The row copied for each upgrade in a selection. Authored in the scene and kept
## hidden, so every row's lettering, size and stylebox is an Inspector value.
@export var choice_template_path: NodePath = ^"Panel/Body/Choices/Choice"

@onready var _heading: Label = get_node_or_null(heading_label_path) as Label
@onready var _weapon_label: Label = get_node_or_null(weapon_label_path) as Label
@onready var _name: Label = get_node_or_null(name_label_path) as Label
@onready var _effect: Label = get_node_or_null(effect_label_path) as Label
@onready var _level: Label = get_node_or_null(level_label_path) as Label
@onready var _note: Label = get_node_or_null(note_label_path) as Label
@onready var _take: Button = get_node_or_null(take_button_path) as Button
@onready var _choices: Container = get_node_or_null(choices_path) as Container
@onready var _choice_template: Button = get_node_or_null(choice_template_path) as Button

var _bridge: WorldMapCombatBridge
var _weapon: WeaponDefinition
var _upgrade: WeaponUpgrade
var _good: RunMapUpgradeGood

## The selection being made, while one is up: the reward, the upgrades on offer,
## the rows showing them, which pick this is, what the last pick took and the
## generator every selection of this reward is dealt with.
var _reward: RunMapUpgradeReward
var _offer: Array[WeaponUpgrade] = []
var _rows: Array[Button] = []
var _pick: int = 0
var _last_taken: Array[StringName] = []
var _rng: RandomNumberGenerator


func _ready() -> void:
	hide()
	if _take != null:
		_take.pressed.connect(take)
	if _choice_template != null:
		# The template is never shown itself; it is only ever copied.
		_choice_template.visible = false
	if _choices != null:
		_choices.visible = false


func _process(_delta: float) -> void:
	if _bridge == null or not is_instance_valid(_bridge):
		_bind_bridge()


## The upgrade on offer, or null while the screen is shut.
func get_upgrade() -> WeaponUpgrade:
	return _upgrade


## The weapon it is for, or null while the screen is shut.
func get_weapon() -> WeaponDefinition:
	return _weapon


## Takes the upgrade - one run level on the weapon's run stack, free - and rides
## home. Returns whether a level was given.
func take() -> bool:
	if not visible or _reward != null:
		return false
	var weapon := _weapon
	var upgrade := _upgrade
	var given := _good != null and _good.buy(self)
	_weapon = null
	_upgrade = null
	_good = null
	hide()
	if given:
		taken.emit(weapon, upgrade)
	if _bridge != null and is_instance_valid(_bridge):
		_bridge.let_the_return_go()
	return given


## Opens on [param upgrade] for [param weapon] and holds the ride home until it
## is taken. Answers false - and holds nothing - when there is no bridge to hold.
func open_with(weapon: WeaponDefinition, upgrade: WeaponUpgrade, reward: RunMapUpgradeReward) -> bool:
	if weapon == null or upgrade == null or reward == null:
		return false
	if _bridge == null or not _bridge.hold_the_return(self):
		return false
	_weapon = weapon
	_upgrade = upgrade
	_good = reward.make_good(weapon, upgrade)
	_fill()
	show()
	if _take != null:
		_take.grab_focus()
	return true


## The upgrades in the selection on offer, or empty while none is up.
func get_offer() -> Array[WeaponUpgrade]:
	return _offer.duplicate()


## Which pick of the selection is being made, counting from one, or 0 while none
## is up.
func get_pick() -> int:
	return _pick + 1 if _reward != null else 0


## Opens a selection of [param reward] for [param weapon] - its
## [member RunMapUpgradeReward.picks], each chosen from
## [member RunMapUpgradeReward.choices] - and holds the ride home until the last
## is taken. Answers false, holding nothing, when there is nothing to offer or no
## bridge to hold.
func open_selection(weapon: WeaponDefinition, reward: RunMapUpgradeReward,
		rng: RandomNumberGenerator) -> bool:
	if weapon == null or reward == null or rng == null:
		return false
	var offer := reward.draw_choices(weapon, rng)
	if offer.is_empty():
		return false
	if _bridge == null or not _bridge.hold_the_return(self):
		return false
	_weapon = weapon
	_reward = reward
	_rng = rng
	_pick = 0
	_last_taken = []
	_show_offer(offer)
	show()
	return true


## Takes the upgrade at [param index] of the selection on offer - one run level,
## free - then deals the next pick, or rides home after the last. Returns whether
## a level was given.
func choose(index: int) -> bool:
	if not visible or _reward == null or index < 0 or index >= _offer.size():
		return false
	var weapon := _weapon
	var upgrade := _offer[index]
	var given := _reward.make_good(weapon, upgrade).buy(self)
	if given:
		taken.emit(weapon, upgrade)
	_pick += 1
	_last_taken = [RunMapUpgradeGood.product_key(weapon, upgrade)]
	if _pick < _reward.picks:
		var offer := _reward.draw_choices(weapon, _rng, _last_taken)
		if not offer.is_empty():
			_show_offer(offer)
			return given
	_close_selection()
	return given


func _show_offer(offer: Array[WeaponUpgrade]) -> void:
	_offer = offer
	_set_single_visible(false)
	if _heading != null:
		_heading.text = choose_heading_format % [_pick + 1, _reward.picks]
		_heading.add_theme_color_override(&"font_color", common_color)
	if _weapon_label != null:
		_weapon_label.text = _weapon.display_name
	if _note != null:
		_note.text = note_text
	_clear_rows()
	if _choices == null or _choice_template == null:
		return
	_choices.visible = true
	for index: int in _offer.size():
		var upgrade := _offer[index]
		var row := _choice_template.duplicate() as Button
		row.visible = true
		var shown_name := unique_name_format % upgrade.display_name if upgrade.unique \
			else upgrade.display_name
		row.text = choice_format % [shown_name, upgrade.describe_level(1),
			level_format % (_weapon.get_run_level(upgrade) + 1)]
		if upgrade.unique:
			row.add_theme_color_override(&"font_color", unique_row_color)
		row.pressed.connect(choose.bind(index))
		_choices.add_child(row)
		_rows.append(row)
	if not _rows.is_empty():
		_rows[0].grab_focus()


func _close_selection() -> void:
	_clear_rows()
	if _choices != null:
		_choices.visible = false
	_set_single_visible(true)
	_weapon = null
	_reward = null
	_rng = null
	_offer = []
	_pick = 0
	_last_taken = []
	hide()
	if _bridge != null and is_instance_valid(_bridge):
		_bridge.let_the_return_go()


func _clear_rows() -> void:
	for row: Button in _rows:
		# Hidden rather than pulled out: the row may be the one whose press is
		# still being handled.
		if is_instance_valid(row):
			row.visible = false
			row.queue_free()
	_rows.clear()


## Shows or puts away what only a single handed-over upgrade uses.
func _set_single_visible(on: bool) -> void:
	for control: Control in [_name, _effect, _level, _take]:
		if control != null:
			control.visible = on


## Nothing but TAKE - or a row of a selection - leaves this screen: the back key
## and anything else a key would open underneath it are swallowed while it is up.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _reward == null and event.is_action_pressed(&"ui_accept"):
		take()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


func _fill() -> void:
	var next_level := _weapon.get_run_level(_upgrade) + 1
	if _heading != null:
		_heading.text = unique_heading if _upgrade.unique else common_heading
		_heading.add_theme_color_override(&"font_color",
			unique_color if _upgrade.unique else common_color)
	if _weapon_label != null:
		_weapon_label.text = _weapon.display_name
	if _name != null:
		_name.text = _upgrade.display_name
	if _effect != null:
		_effect.text = _upgrade.describe_level(1)
	if _level != null:
		_level.text = level_format % next_level
	if _note != null:
		_note.text = note_text


func _bind_bridge() -> void:
	_bridge = WorldMapCombatBridge.get_active(self)
	if _bridge != null and not _bridge.encounter_ended.is_connected(_on_encounter_ended):
		_bridge.encounter_ended.connect(_on_encounter_ended)


func _on_encounter_ended(victory: bool) -> void:
	if not victory or visible or _bridge == null:
		return
	var reward := _reward_for(_bridge.get_site_kind())
	if reward == null:
		return
	var weapon := _equipped_weapon()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if reward.choices > 1:
		open_selection(weapon, reward, rng)
		return
	var upgrade := reward.draw(weapon, rng)
	if upgrade == null:
		return
	open_with(weapon, upgrade, reward)


func _reward_for(site_kind: StringName) -> RunMapUpgradeReward:
	for reward: RunMapUpgradeReward in rewards:
		if reward != null and reward.pays_for(site_kind):
			return reward
	return null


## The weapon in the player's hands - the one the Market deals for too.
func _equipped_weapon() -> WeaponDefinition:
	var mount := WeaponMount.get_active(self)
	if mount != null and mount.get_definition() != null:
		return mount.get_definition()
	var session := get_node_or_null(session_path) as RunSessionState
	if session == null or session.get_weapon_catalog() == null:
		return null
	var catalog := session.get_weapon_catalog()
	var chosen := catalog.find(session.get_weapon_id())
	return chosen if chosen != null else catalog.get_default()
