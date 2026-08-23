class_name UpgradeMenu
extends Control
## What the blood portal opens: a row of cards to spend on, and the button that
## starts the next round.
##
## Nothing is actually sold yet. A card is a price and a slot - see [UpgradeCard]
## - and buying one takes the blood and marks it taken. There is no effect
## anywhere in this file, so whatever upgrades turn out to be can be hung off
## [signal card_bought] without this having guessed at their shape first.
##
## The row is generated rather than authored, from one [PackedScene] and a count,
## so five cards is a number in the inspector instead of five nodes to keep in
## step - and a round that offers six later costs nothing here.
##
## REFRESH throws the row away and deals another through that same generator, so
## it re-deals whatever the cards turn out to be without knowing what they are.
## Its price, how much repeated use drives that price up and how many are allowed
## per visit are all inspector fields sitting at "free and unlimited", which is
## where they belong until a card is worth something.
##
## The money is this node's business and only this node's. [BloodWallet] decides
## whether a purchase can go through - it refuses what cannot be afforded and
## nothing here second-guesses it - and the cards are simply told afterwards what
## the player can still reach.
##
## NEXT ROUND advances the persistent round counter and rebuilds the world, which
## is the same path the pause menu has always used to start a run. Everything
## that has to survive is an autoload and is not touched: the carried blood, the
## banked blood and the round number all come through the rebuild, so the next
## round starts richer, deeper in, and with more to kill.

## Emitted as the menu is raised and dropped.
signal opened
signal closed
## Emitted when a card is actually paid for.
signal card_bought(index: int, cost: int)
## Emitted as the next round begins, before the world is rebuilt.
signal next_round_started(round_number: int)
## Emitted after the market has dealt a new row of cards, with what the refresh
## actually cost. Whatever eventually decides what a card *is* can hang off this
## without the refresh having to know about it.
signal market_refreshed(cost: int)
## Emitted when a refresh was asked for and refused - the price could not be met.
signal refresh_refused(cost: int)

## Cards offered.
@export var card_count: int = 5
## What one card costs, in blood.
@export var card_cost: int = 500
## Scene one card is built from.
@export var card_scene: PackedScene
## Wallet a purchase is paid out of - the [code]Blood[/code] autoload, which is
## the blood the player carried home from the run.
@export var wallet_path: NodePath = ^"/root/Blood"
## Freezes the world while the menu is up, the same way the pause menu does, so
## nothing carries on happening behind it.
@export var pauses_game: bool = true
## Key that closes the menu again without starting a round, so the player can go
## back out to the portal.
@export var close_action: StringName = &"pause_menu"

@export_group("Next round")
## The persistent round counter - the [code]RunProgress[/code] autoload.
@export var progress_path: NodePath = ^"/root/RunProgress"
## Whether NEXT ROUND actually rebuilds the world. Off makes the button report
## the press and change nothing, which is what a test harness wants.
@export var reload_scene: bool = true
## Gap between the button and the fade starting, so the press is seen to land.
@export var start_delay: float = 0.15
## How long the screen takes to go black. The world is not rebuilt until it has,
## so the teleport into the arena is never seen happening.
@export var fade_out_time: float = 1.0
## How long the screen takes to clear on the far side, once the new round has
## been built. It is carried across the rebuild by [ScreenFade] itself.
@export var fade_in_time: float = 1.0
## Whether the soundtrack crosses over with the screen: the base track down, the
## arena track up. The music is [MusicDirector]'s business - this only says when.
@export var drive_music: bool = true

@export_group("Refresh")
## What a refresh costs, in blood. 0 makes it free, which is where it starts:
## what a card is worth has not been decided yet, so what re-dealing them should
## cost cannot be either.
##
## The mechanics are already in place around that number, though - the wallet is
## charged through the same [method BloodWallet.spend] a purchase goes through, a
## refusal is reported rather than silently ignored, and the price can climb per
## use - so putting a real cost on this later is changing these fields and nothing
## else.
@export var refresh_cost: int = 0
## Added to the cost each time the market is refreshed in one visit, so repeated
## re-dealing can be made to bite. 0 keeps every refresh the same price.
@export var refresh_cost_growth: int = 0
## Most refreshes allowed in one visit. Below 0 is unlimited, which is the
## default - the limit is kept rather than removed so a future shop upgrade can
## raise it instead of code having to grow one.
@export var refresh_limit: int = -1
## Whether cards already bought survive a refresh. Off re-deals the whole row.
@export var refresh_keeps_bought: bool = false
## How the button is labelled. The running cost is substituted in when there is
## one, so a free refresh reads as free.
@export var refresh_format: String = "REFRESH (%d)"
@export var refresh_free_text: String = "REFRESH"
@export var refresh_spent_text: String = "NO REFRESHES LEFT"

@export_group("Nodes")
## Container the cards are put in. A horizontal box, so they sit side by side.
@export var cards_path: NodePath = ^"Panel/Body/Cards"
@export var next_round_button_path: NodePath = ^"Panel/Body/Footer/NextRoundButton"
## Button that re-deals the row. Optional - a menu without one simply offers the
## cards it opened with.
@export var refresh_button_path: NodePath = ^"Panel/Body/Footer/RefreshButton"
## Readout of what the player has to spend. Optional.
@export var blood_label_path: NodePath = ^"Panel/Body/Header/Blood"
## How the readout is written.
@export var blood_format: String = "BLOOD %d"

@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet
@onready var _progress: RoundCounter = get_node_or_null(progress_path) as RoundCounter
@onready var _cards_box: Container = get_node_or_null(cards_path) as Container
@onready var _next_round: Button = get_node_or_null(next_round_button_path) as Button
@onready var _refresh_button: Button = get_node_or_null(refresh_button_path) as Button
@onready var _blood_label: Label = get_node_or_null(blood_label_path) as Label

var _cards: Array[UpgradeCard] = []
var _starting: bool = false
var _refreshes_used: int = 0


func _ready() -> void:
	hide()
	_build_cards()

	if _next_round != null:
		_next_round.pressed.connect(_on_next_round_pressed)
	if _refresh_button != null:
		_refresh_button.pressed.connect(refresh_market)
	if _wallet != null:
		_wallet.changed.connect(_on_wallet_changed)
	_refresh()


func is_open() -> bool:
	return visible


## Raises the menu. Called by whatever the player used to get here - the portal -
## rather than by a key, so the menu cannot be opened from anywhere else.
func open() -> void:
	if visible:
		return

	show()
	_refresh()
	# Deliberately unfocused, for the same reason the pause menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


func close() -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


## Escape backs out to the portal, which is still standing there to be used
## again. The event is marked handled so the same press cannot also raise the
## pause menu sitting behind this one.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _starting:
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


## Built once, from the count and the scene, so the row is however many cards the
## inspector asks for. A menu with no card scene set simply offers none rather
## than erroring - the portal, the pause and the next round still work.
func _build_cards(count: int = -1) -> void:
	if _cards_box == null or card_scene == null:
		return

	for i in maxi(count if count >= 0 else card_count, 0):
		var card := card_scene.instantiate() as UpgradeCard
		if card == null:
			continue
		card.cost = card_cost
		_cards_box.add_child(card)
		card.buy_requested.connect(_on_buy_requested)
		_cards.append(card)


## Throws the row away and deals another one.
##
## Everything about *what* a card is is left alone: the row is rebuilt through the
## same [method _build_cards] that filled it in the first place, so whatever
## upgrade selection eventually lives there is picked exactly as it is when the
## menu opens, and this needs no idea what that turns out to be. All that is added
## here is the price and the accounting around it.
##
## Safe to call from anywhere - a button, a key, a debug command. It refuses
## rather than half-runs when the price cannot be met or the limit has been
## reached, and reports which of the two happened.
func refresh_market() -> void:
	if not can_refresh():
		refresh_refused.emit(get_refresh_cost())
		return

	var cost := get_refresh_cost()
	# Charged through the wallet rather than checked against it, for the same
	# reason a purchase is: one place decides whether blood can be spent, so the
	# price can never be taken twice or waived by a second opinion.
	if cost > 0 and (_wallet == null or not _wallet.spend(cost)):
		refresh_refused.emit(cost)
		return

	_refreshes_used += 1
	_deal_cards()
	_refresh()
	market_refreshed.emit(cost)


## What the next refresh would cost, with however much the ones already used this
## visit have driven it up.
func get_refresh_cost() -> int:
	return maxi(refresh_cost + refresh_cost_growth * _refreshes_used, 0)


func get_refreshes_used() -> int:
	return _refreshes_used


## Whether a refresh is currently possible: within the limit, and affordable.
func can_refresh() -> bool:
	if refresh_limit >= 0 and _refreshes_used >= refresh_limit:
		return false

	var cost := get_refresh_cost()
	if cost <= 0:
		return true
	return _wallet != null and _wallet.get_total() >= cost


## Clears the row and fills it again. Kept apart from [method _build_cards] so
## that the build knows nothing about there having been a previous row.
func _deal_cards() -> void:
	if _cards_box == null:
		return

	var kept: Array[UpgradeCard] = []
	for card: UpgradeCard in _cards:
		if refresh_keeps_bought and card.is_bought():
			kept.append(card)
			continue
		_cards_box.remove_child(card)
		card.queue_free()

	_cards = kept
	_build_cards(maxi(card_count - kept.size(), 0))


## The wallet is the authority on whether a purchase happens: it refuses what
## cannot be afforded and reports it, so there is no second affordability rule
## here that could disagree with the one that actually takes the money.
func _on_buy_requested(card: UpgradeCard) -> void:
	if _wallet == null or card.is_bought():
		return
	if not _wallet.spend(card.cost):
		return

	card.mark_bought()
	card_bought.emit(_cards.find(card), card.cost)
	_refresh()


func _on_wallet_changed(_total: int) -> void:
	_refresh()


## Pushes the current total out to the readout and to every card, so a purchase
## that empties the wallet greys out the two cards the player can no longer
## reach without any of them having to watch the wallet themselves.
func _refresh() -> void:
	var total := 0 if _wallet == null else _wallet.get_total()

	if _blood_label != null:
		_blood_label.text = blood_format % total

	for card: UpgradeCard in _cards:
		card.set_affordable(total >= card.cost)

	_refresh_button_state()


## The refresh button reads its own price and its own limit, so it greys out for
## the right reason without anything else having to work out which one applies.
func _refresh_button_state() -> void:
	if _refresh_button == null:
		return

	var out_of_refreshes := refresh_limit >= 0 and _refreshes_used >= refresh_limit
	var cost := get_refresh_cost()

	if out_of_refreshes:
		_refresh_button.text = refresh_spent_text
	elif cost > 0:
		_refresh_button.text = refresh_format % cost
	else:
		_refresh_button.text = refresh_free_text

	_refresh_button.disabled = not can_refresh()


func _on_next_round_pressed() -> void:
	if _starting:
		return
	_starting = true

	hide()
	_drop_focus()
	# Unpaused before anything else: a round started from a frozen tree would
	# come back frozen.
	get_tree().paused = false

	var round_number := 1
	if _progress != null:
		round_number = _progress.advance()
	next_round_started.emit(round_number)

	# The soundtrack starts crossing over now rather than on the far side, so the
	# handover is already under way while the screen is still going dark.
	if drive_music:
		var music := MusicDirector.get_active(self)
		if music != null:
			music.switch_to_arena(fade_out_time)

	if not reload_scene:
		_starting = false
		return

	# Real time and process-always, so the transition still lands whatever else
	# has touched the tree's pause state or the time scale by the time it fires.
	var timer := get_tree().create_timer(maxf(start_delay, 0.0), true, false, true)
	timer.timeout.connect(_fade_into_next_round)


## Black first, rebuild second. The whole point is that the player never watches
## the world being taken apart and put back together, so the reload waits for the
## screen to be fully covered rather than racing it.
##
## The fade back in cannot be asked for here, because this node is one of the
## things about to be freed - so it is left as a request for whichever
## [ScreenFade] comes up in the new world to honour.
func _fade_into_next_round() -> void:
	if not is_inside_tree():
		return

	ScreenFade.request_fade_in_after_reload(fade_in_time)

	var fade := ScreenFade.get_active(self)
	if fade == null:
		_rebuild_world()
		return
	fade.fade_out(fade_out_time, _rebuild_world)


func _rebuild_world() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


## Dropped for the same reason the menu opens unfocused - a button that kept
## focus would keep eating the accept key once play resumed. Released at the
## viewport rather than button by button, so a card added later is covered
## without being listed here.
func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
