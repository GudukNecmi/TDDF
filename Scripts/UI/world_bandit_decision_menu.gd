class_name WorldBanditDecisionMenu
extends Control
## The short bandit-contact screen: one line from the bandits, and one to
## three replies back - built the plain way [TravelEventMenu] already is,
## a name and a set of buttons wearing the same styleboxes every menu in
## the game wears, rather than a stretched copy of that screen. It is its
## own screen because [DangerDirector]'s own CONTINUE/STOP question needs
## [TravelEventMenu] fixed at exactly two buttons, and STRONGER, EQUAL and
## WEAKER do not all want the same number.
##
## [b]It decides nothing.[/b] Handed a [WorldBanditDecisionTier] by
## [WorldMapCombatBridge], it picks one bandit line at random off
## [method WorldBanditDecisionTier.pick_line], shows exactly as many
## buttons as [member WorldBanditDecisionTier.choices] carries, and reports
## which [member WorldBanditDecisionChoice.outcome] was pressed - see
## [signal answered]. What paying, taking, walking away or fighting actually
## does is entirely [WorldMapCombatBridge]'s.
##
## [b]The briefing is part of this screen, not a second one.[/b] "Should I take
## this fight?" is the question these buttons already ask, so what the player
## needs in order to answer it - how many men, what they have left to meet them
## with, how dangerous that is and what kinds of men are out there - is shown
## on this same panel, above the same buttons, answered by the same press. It is
## a read-out and nothing else: every number on it is asked of the system that
## already owns it, and nothing here spawns, arms, heals or refuses anything.
##
## [b]It describes this encounter, not another one.[/b] The count is the count
## [method WorldMapCombatBridge._enemy_count_for] will hand the arena if FIGHT
## is pressed - the same reinforced group strength through the same conversion -
## rather than a second reading of the same group. Hearts are the player's own
## [Health], one heart per point exactly as [HeartBar] draws them, and
## ammunition is the equipped reserve on the shared [AmmoLocker], the same
## number [AmmoCounter] shows in the corner - so the panel and the HUD can never
## disagree.

signal answered(outcome: StringName)

const GROUP := &"world_bandit_decision_menu"

## How dangerous the fight is, from least to most. The order is the ranking:
## where two rules both apply, the higher one is what the player is shown.
enum Risk {
	SAFE,
	NORMAL,
	RISKY,
	VERY_RISKY,
}

## Whether the world is frozen while the question is up - the same as every
## other menu built this way.
@export var pauses_game: bool = true

@export_group("Briefing sources")
## The player's [Health], found by group so this works on any HUD without being
## wired to a particular scene's player.
@export var health_group: StringName = &"player_health"
## The shared ammunition locker. The equipped reserve on it is what the player
## is actually going to fight with.
@export var locker_path: NodePath = ^"/root/Ammo"

@export_group("Risk rules")
## Ammunition below this fraction of the enemy count is [constant Risk.RISKY] -
## not enough rounds to go round.
@export_range(0.0, 2.0, 0.01) var risky_ammo_fraction: float = 0.75
## At or below this many hearts the fight is [constant Risk.VERY_RISKY],
## whatever the ammunition says. One hit from over.
@export var very_risky_hearts: int = 1
## What each level of [enum Risk] is called, in the enum's own order. An array
## rather than four fields, so the wording is changed in one place and a fifth
## level is a fifth entry.
@export var risk_names: PackedStringArray = PackedStringArray(
	["SAFE", "NORMAL RISK", "RISKY", "VERY RISKY"]
)
## The colour each level is drawn in, in the same order.
@export var risk_colors: PackedColorArray = PackedColorArray([
	Color(0.62, 0.82, 0.46),
	Color(0.93, 0.87, 0.8),
	Color(0.95, 0.62, 0.2),
	Color(0.88, 0.13, 0.12),
])

@export_group("Enemy types")
## Every type this screen knows how to draw, in the order they are shown. The
## entry with no scene of its own is the fallback - the ordinary Bandit - and is
## what every place in the fight no other entry claims is drawn as. See
## [BattlePreviewEnemyType]; adding a third type is dropping a resource in here.
@export var enemy_types: Array[BattlePreviewEnemyType] = []

@export_group("Nodes")
@export var line_label_path: NodePath = ^"Panel/Body/Line"
## One path per button this screen can ever show, in the order
## [member WorldBanditDecisionTier.choices] is read. A tier with fewer
## choices than there are paths simply hides the rest.
@export var button_paths: Array[NodePath] = [
	^"Panel/Body/Buttons/Choice1",
	^"Panel/Body/Buttons/Choice2",
	^"Panel/Body/Buttons/Choice3",
]
## Everything the briefing is written into, put away whole when a contact is
## opened without a count to show - so a caller that says nothing about the
## fight gets exactly the screen that existed before the briefing did.
@export var briefing_paths: Array[NodePath] = [
	^"Panel/Body/Art",
	^"Panel/Body/Enemies",
	^"Panel/Body/Resources",
	^"Panel/Body/Risk",
	^"Panel/Body/Types",
]
@export var enemy_count_label_path: NodePath = ^"Panel/Body/Enemies/Count"
@export var hearts_label_path: NodePath = ^"Panel/Body/Resources/Hearts/Value"
@export var ammo_label_path: NodePath = ^"Panel/Body/Resources/Ammo/Value"
@export var risk_label_path: NodePath = ^"Panel/Body/Risk/Value"
## Where one row per present enemy type is put.
@export var types_box_path: NodePath = ^"Panel/Body/Types"
## The row copied for each type. It is authored in the scene and kept hidden, so
## every portrait's size, spacing and lettering is an Inspector value rather than
## anything built in code.
@export var type_entry_path: NodePath = ^"Panel/Body/Types/Entry"
## The icon and the name inside that row, as paths relative to it.
@export var entry_icon_path: NodePath = ^"Icon"
@export var entry_name_path: NodePath = ^"Name"

@onready var _line: Label = get_node_or_null(line_label_path) as Label
@onready var _enemy_count_label: Label = get_node_or_null(enemy_count_label_path) as Label
@onready var _hearts_label: Label = get_node_or_null(hearts_label_path) as Label
@onready var _ammo_label: Label = get_node_or_null(ammo_label_path) as Label
@onready var _risk_label: Label = get_node_or_null(risk_label_path) as Label
@onready var _types_box: Control = get_node_or_null(types_box_path) as Control
@onready var _type_entry: Control = get_node_or_null(type_entry_path) as Control

var _buttons: Array[Button] = []
## True from the moment a button is pressed, so a second press - or a second
## signal from a button double-clicked before the screen hides - cannot
## answer twice.
var _answered: bool = false
var _type_rows: Array[Node] = []


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	# The template is never shown itself; it is only ever copied.
	if _type_entry != null:
		_type_entry.visible = false
	for path: NodePath in button_paths:
		var button := get_node_or_null(path) as Button
		var index := _buttons.size()
		_buttons.append(button)
		if button != null:
			button.pressed.connect(_on_button_pressed.bind(index))


## The screen the bridge should raise, or null when this world has none -
## which [WorldMapCombatBridge] reads as "there is nowhere to ask, so a
## contact goes straight to the fight it always used to".
static func get_active(from_node: Node) -> WorldBanditDecisionMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as WorldBanditDecisionMenu


func is_open() -> bool:
	return visible


## Puts the question up. Does nothing on a null tier or a screen already
## showing, exactly as [method TravelEventMenu.ask_choice] refuses a second
## call while one is already up.
##
## [param enemy_count] is how many men the FIGHT button leads to, worked out by
## [WorldMapCombatBridge] from the reinforced group - below zero means "not
## known", and the briefing is put away rather than guessed at.
##
## [param bodies] is the fight's composition when it has already been rolled,
## one entry per enemy with a null meaning the spawner's own ordinary Bandit.
## [b]On the World Map it never has been[/b] - the roster lives with the arena
## and is not asked until the fight opens - so an empty array is the ordinary
## case and reads as what a contact on the road is worth: the spawner's own men,
## every one of them, which is exactly what the roster's first wave hands back.
func ask(tier: WorldBanditDecisionTier, enemy_count: int = -1,
		bodies: Array[PackedScene] = []) -> void:
	if tier == null or visible:
		return

	_answered = false
	if _line != null:
		_line.text = tier.pick_line()

	_write_briefing(enemy_count, bodies)

	for i in _buttons.size():
		var button := _buttons[i]
		if button == null:
			continue
		if i < tier.choices.size():
			var choice := tier.choices[i]
			button.text = choice.label if choice != null else ""
			button.set_meta(&"outcome", &"fight" if choice == null else choice.outcome)
			button.visible = true
		else:
			button.visible = false

	show()
	_drop_focus()
	if pauses_game:
		get_tree().paused = true


## Takes the question back down without answering it - what
## [WorldMapCombatBridge] calls if a contact it opened this for turns out
## not to be able to start after all, the same way it already cancels a
## loading transition it cannot follow through on.
func close() -> void:
	if not visible:
		return
	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false


## The player's hearts - one per point of health, exactly as [HeartBar] draws
## them. 0 when there is no player to ask, which is what stops this inventing a
## number on a HUD with no run behind it.
func get_player_hearts() -> int:
	if not is_inside_tree():
		return 0
	var health := get_tree().get_first_node_in_group(health_group) as Health
	if health == null:
		return 0
	return int(round(health.get_current()))


## Rounds in the equipped weapon's reserve. 0 when nothing is equipped or there
## is no locker, so an unarmed player reads as unarmed rather than as unknown.
func get_equipped_ammo() -> int:
	var locker := get_node_or_null(locker_path) as AmmoLocker
	if locker == null:
		return 0
	var reserve := locker.get_equipped_reserve()
	if reserve == null:
		return 0
	return reserve.get_current()


## The fight's risk, by the four rules, with the enemy count as the reference.
##
##   * Ammunition below [member risky_ammo_fraction] of the count is risky -
##     there are not enough rounds to go round.
##   * Ammunition at or above the count itself is an ordinary fight.
##   * Anything between the two is safe: fewer rounds than men, but comfortably
##     more than the fraction that would leave the player short.
##   * At or below [member very_risky_hearts] hearts it is very risky whatever
##     the ammunition says.
##
## [b]The rules are ranked, not chained.[/b] Where more than one applies the
## worst answer is the one shown - which is the whole reason [enum Risk] is
## ordered least to most dangerous rather than being four unrelated names.
func evaluate_risk(enemy_count: int, ammo: int, hearts: int) -> Risk:
	var level := Risk.SAFE
	var enemies := maxi(enemy_count, 0)

	if float(ammo) < float(enemies) * risky_ammo_fraction:
		level = Risk.RISKY
	elif ammo >= enemies:
		level = Risk.NORMAL

	# Last, and unconditional, because it is the worst answer there is - which is
	# exactly what "the more dangerous result wins" means for it.
	if hearts <= very_risky_hearts:
		level = Risk.VERY_RISKY

	return level


# --- The briefing -------------------------------------------------------------

## Fills the read-out in, or puts it away when there is no fight to describe.
##
## Hearts and ammunition are read here, at the instant the question goes up,
## rather than being passed in - so what the player is shown is what they are
## holding now and not what they were holding when contact was made.
func _write_briefing(enemy_count: int, bodies: Array[PackedScene]) -> void:
	_clear_type_rows()
	_show_briefing(enemy_count >= 0)
	if enemy_count < 0:
		return

	var hearts := get_player_hearts()
	var ammo := get_equipped_ammo()
	var risk := evaluate_risk(enemy_count, ammo, hearts)

	if _enemy_count_label != null:
		_enemy_count_label.text = str(enemy_count)
	if _hearts_label != null:
		_hearts_label.text = str(hearts)
	if _ammo_label != null:
		_ammo_label.text = str(ammo)
	if _risk_label != null:
		_risk_label.text = _risk_name(risk)
		_risk_label.add_theme_color_override(&"font_color", _risk_color(risk))

	_build_type_rows(bodies, enemy_count)


func _show_briefing(shown: bool) -> void:
	for path: NodePath in briefing_paths:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = shown


## Which types are in [param bodies], in [member enemy_types] order, one row
## each. A body no entry claims falls to the entry with no scene of its own -
## the ordinary Bandit - which is why the roster never has to name it.
func _build_type_rows(bodies: Array[PackedScene], enemy_count: int) -> void:
	if _types_box == null or _type_entry == null:
		return

	var present := _present_types(bodies, enemy_count)
	for type: BattlePreviewEnemyType in enemy_types:
		if type == null or not present.has(type):
			continue
		_add_type_row(type)


## The set of entries [param bodies] actually calls for. Kept as a lookup rather
## than a list so the rows come out in the authored order however the roll fell.
func _present_types(bodies: Array[PackedScene], enemy_count: int) -> Dictionary:
	var present := {}
	var fallback := _fallback_type()

	for body: PackedScene in bodies:
		var matched := fallback if body == null else _type_for(body)
		if matched != null:
			present[matched] = true

	# Every place the roll does not account for is an ordinary man - and on the
	# World Map, where nothing has been rolled yet, that is all of them. Without
	# this a contact would show its numbers and no faces.
	if bodies.size() < enemy_count and fallback != null:
		present[fallback] = true

	return present


## The entry describing [param body], or the fallback when no entry claims it.
func _type_for(body: PackedScene) -> BattlePreviewEnemyType:
	for type: BattlePreviewEnemyType in enemy_types:
		if type != null and type.scene == body:
			return type
	return _fallback_type()


## The entry with no scene of its own - what an unclaimed body is drawn as.
func _fallback_type() -> BattlePreviewEnemyType:
	for type: BattlePreviewEnemyType in enemy_types:
		if type != null and type.scene == null:
			return type
	return null


## One row: the type's heads, and its name when it has one to give.
func _add_type_row(type: BattlePreviewEnemyType) -> void:
	var row := _type_entry.duplicate() as Control
	if row == null:
		return

	var name_label := row.get_node_or_null(entry_name_path) as Label
	if name_label != null:
		name_label.visible = type.show_name and not type.display_name.is_empty()
		name_label.text = type.display_name

	var icon := row.get_node_or_null(entry_icon_path) as TextureRect
	if icon != null:
		var picked := type.pick_icons(maxi(type.portrait_count, 1))
		icon.visible = not picked.is_empty()
		if not picked.is_empty():
			icon.texture = picked[0]
		# A type shown as more than one head gets the extra portraits as copies
		# of the very same authored icon, so their size and spacing stay the
		# template's rather than being decided here.
		for i in range(1, picked.size()):
			var extra := icon.duplicate() as TextureRect
			if extra == null:
				continue
			extra.texture = picked[i]
			icon.get_parent().add_child(extra)
			icon.get_parent().move_child(extra, icon.get_index() + i)

	row.visible = true
	_types_box.add_child(row)
	_type_rows.append(row)


func _clear_type_rows() -> void:
	for row: Node in _type_rows:
		if is_instance_valid(row):
			row.queue_free()
	_type_rows.clear()


func _risk_name(level: Risk) -> String:
	var index := int(level)
	if index < 0 or index >= risk_names.size():
		return ""
	return risk_names[index]


func _risk_color(level: Risk) -> Color:
	var index := int(level)
	if index < 0 or index >= risk_colors.size():
		return Color.WHITE
	return risk_colors[index]


func _on_button_pressed(index: int) -> void:
	if _answered or index < 0 or index >= _buttons.size():
		return
	var button := _buttons[index]
	if button == null:
		return

	_answered = true
	var outcome := button.get_meta(&"outcome", &"fight") as StringName
	close()
	answered.emit(outcome)


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
