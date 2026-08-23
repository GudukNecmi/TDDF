class_name CashOutScreen
extends Control
## What the run was worth, counted out at the door of the base before the player
## walks through it.
##
## [b]It is where the streak is finally paid.[/b] Every drop of blood picked up during a
## run is worth exactly what it says while the player is out there - see [StreakCounter] -
## and the multiplication happens here, once, against the pile they actually carried home.
## That is what makes the streak a bet: three outlaws put down treble the whole ride home,
## and being killed on the way back to the base loses the same three times over. A camp
## pays the same multiple on what is stashed there - see [method CampMenu.deposit_blood] -
## but only this screen spends the streak, so what is left in the player's hands is still
## riding on it.
##
## [b]It owns no totals of its own.[/b] The carried blood is the [code]Blood[/code]
## autoload, the base's pool is [code]BloodBank[/code], and moving one into the other
## is [method BloodWallet.transfer_to] - the same primitive the pool in the base and
## the stash at a camp both use, so nothing here can mint or strand blood. The only
## thing that is not a transfer is the streak's own bonus, which is added on top and is
## the single place in the game blood is created from a rule rather than from a body.
##
## [b]Nothing happens until CONTINUE.[/b] The screen can be backed out of with Escape,
## which puts the player back in the camp exactly as they were - no blood has moved and
## the streak still stands, so a press of RETURN HOME that was not meant is a press
## that cost nothing.
##
## Like the rest of the menus it is styled from the scene rather than in code, and
## every line it prints is an inspector field.

## Emitted as the screen is raised, with what it is about to pay.
signal opened(carried: int, streak: int, payout: int)
## Emitted once the player continues and the blood has actually been banked, with what
## went into the pool. The camp listens for this to finish going home.
signal continued(banked: int)
## Emitted when the player backs out instead. Nothing has been paid.
signal cancelled

## Group the screen joins, so the camp can find it without a path.
const GROUP := &"cash_out_screen"

## The blood the player is carrying - the [code]Blood[/code] autoload. Emptied into
## the pool as the player continues.
@export var wallet_path: NodePath = ^"/root/Blood"
## The base's permanent pool - the [code]BloodBank[/code] autoload. What the run is
## finally paid into.
@export var bank_path: NodePath = ^"/root/BloodBank"
## The streak the payout is multiplied by, and cleared once it has been - the
## [code]Streak[/code] autoload.
@export var streak_path: NodePath = ^"/root/Streak"
## Whether the blood is actually moved. Off shows the whole reckoning and pays nothing,
## for looking at the screen without the money moving.
@export var pays_out: bool = true
## Whether the streak is cleared once it has been paid. On - it has been spent.
@export var clears_streak: bool = true
## Freezes the world while the screen is up, the same way every other menu does.
@export var pauses_game: bool = true
## Key that backs out without being paid. The camp is still standing behind it.
@export var close_action: StringName = &"pause_menu"

@export_group("Nodes")
@export var carried_label_path: NodePath = ^"Panel/Body/Rows/Carried"
@export var streak_label_path: NodePath = ^"Panel/Body/Rows/Streak"
@export var payout_label_path: NodePath = ^"Panel/Body/Earned"
@export var continue_button_path: NodePath = ^"Panel/Body/Footer/ContinueButton"
@export var hint_label_path: NodePath = ^"Panel/Body/Footer/Hint"

@export_group("Wording")
## What the player rode in with.
@export var carried_format: String = "CARRIED  %d BLOOD"
## The streak, and what it is paying at. The count comes first because it is the thing
## the player earned; the multiple is what it is worth.
@export var streak_format: String = "STREAK  %d  -  PAYS  x%d"
## The line the whole screen is for.
@export var payout_format: String = "YOU EARNED %d BLOOD"
## What that line says for a run that came home with nothing. A player who banked
## everything at a camp and rode in empty is not shown "YOU EARNED 0 BLOOD" as though
## the run had failed.
@export var payout_empty_text: String = "YOU RODE IN EMPTY HANDED"
@export var continue_text: String = "RIDE IN"
@export var hint_text: String = "ESC STEPS BACK OUT"

@onready var _carried_label: Label = get_node_or_null(carried_label_path) as Label
@onready var _streak_label: Label = get_node_or_null(streak_label_path) as Label
@onready var _payout_label: Label = get_node_or_null(payout_label_path) as Label
@onready var _hint_label: Label = get_node_or_null(hint_label_path) as Label
@onready var _continue_button: Button = get_node_or_null(continue_button_path) as Button

@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet
@onready var _bank: BloodWallet = get_node_or_null(bank_path) as BloodWallet
@onready var _streak: StreakCounter = get_node_or_null(streak_path) as StreakCounter

## True from the moment CONTINUE goes down, so a second press during the transition
## cannot pay the run out twice.
var _paid: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()

	if _continue_button != null:
		_continue_button.pressed.connect(continue_home)
	if _hint_label != null:
		_hint_label.text = hint_text


## The cash-out screen in this world, or null when it has none - which the camp reads
## as "go straight home". See [method CampMenu.return_home].
static func get_active(from_node: Node) -> CashOutScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as CashOutScreen


func is_open() -> bool:
	return visible


## What the player is carrying, which is the whole of what is about to be multiplied.
## Blood stashed at a camp is deliberately not counted: it is already out of their
## hands, and it was never at risk.
func get_carried() -> int:
	return 0 if _wallet == null else _wallet.get_total()


func get_streak() -> int:
	return 0 if _streak == null else _streak.get_streak()


func get_multiplier() -> int:
	return 1 if _streak == null else _streak.get_multiplier()


## What the base will pay. Asked of the streak rather than worked out here, so the
## figure on the screen and the figure that lands in the pool are the same arithmetic.
func get_payout() -> int:
	if _streak == null:
		return get_carried()
	return _streak.apply_to(get_carried())


## Raises the screen. Called by the camp on its way home rather than by a key, so it
## cannot be opened anywhere the run is not ending.
func open() -> void:
	if visible:
		return

	_paid = false
	_refresh()
	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept key
	# is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit(get_carried(), get_streak(), get_payout())


## Backs out without being paid, and hands the world back the way the camp left it.
func close() -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _paid:
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


## The player has agreed to be paid. The blood moves here and nowhere else, and the
## camp is told once it has, so the screen is never left standing over a world that has
## already begun rebuilding itself.
##
## Reports what actually went into the pool.
func continue_home() -> int:
	if not visible or _paid:
		return 0
	_paid = true

	var banked := _bank_the_run()
	hide()
	_drop_focus()
	# The pause is deliberately handed back here rather than left to the caller: the
	# transition home is started from a tree that must be running, exactly as
	# [method CampMenu._begin_leaving] requires.
	if pauses_game:
		get_tree().paused = false

	continued.emit(banked)
	return banked


## Empties the player's hands into the base's pool, with the streak's share added on
## top, and returns what the pool received.
##
## [b]The two halves are deliberately different operations.[/b] What the player carried
## is [i]transferred[/i] - taken out of one wallet before it is put into the other, so
## it can never exist in both places - and only the bonus the streak is worth is added
## from nothing. That keeps the one place blood is created in this game down to a
## single line, and means a payout at a streak of one is a plain transfer with nothing
## invented at all.
func _bank_the_run() -> int:
	if not pays_out or _wallet == null or _bank == null:
		_spend_the_streak()
		return 0

	# Read from what actually moved rather than from what was showing, so a wallet
	# changed between the screen going up and the button going down pays what is really
	# there.
	var moved := _wallet.transfer_to(_bank, get_carried())
	var bonus := 0 if _streak == null else _streak.get_bonus(moved)
	if bonus > 0:
		_bank.add(bonus)

	_spend_the_streak()
	return moved + bonus


## The streak has been paid and is gone. Cleared after the money has moved, never
## before, so a payout that failed part way cannot also cost the player the streak that
## would have paid it.
func _spend_the_streak() -> void:
	if clears_streak and _streak != null:
		_streak.reset()


## The single place every line on the screen is written, so the carried total, the
## streak and the figure they come to can never disagree.
func _refresh() -> void:
	var carried := get_carried()
	var payout := get_payout()

	if _carried_label != null:
		_carried_label.text = carried_format % carried
	if _streak_label != null:
		_streak_label.text = streak_format % [get_streak(), get_multiplier()]
	if _payout_label != null:
		_payout_label.text = payout_empty_text if payout <= 0 else payout_format % payout
	if _continue_button != null:
		_continue_button.text = continue_text


## Dropped for the same reason the screen opens unfocused - a button that kept focus
## would keep eating the accept key. Released at the viewport rather than button by
## button, so a button added later is covered without being listed here.
func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
