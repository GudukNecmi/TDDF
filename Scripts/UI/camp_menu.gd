class_name CampMenu
extends Control
## What the camp opens: patch yourself up, buy shells, and decide whether to ride
## out again or go home.
##
## [b]It owns no systems of its own.[/b] Every one of the four things it offers is
## an existing part of the game asked to do what it already does:
##
##   * HEAL goes through [method Health.heal], so the pool, its ceiling and the
##     hearts drawn from it are the ones the player has been playing with. Blood
##     is taken through [method BloodWallet.spend], the single place that decides
##     whether a price can be met.
##   * AMMO goes through [method AmmoLocker.purchase_available_for_equipped].
##     [b]Nothing here knows what a shotgun is[/b] - which ammunition is for sale,
##     what a box holds and what it costs are all answered by whatever weapon is
##     in the player's hands, so a second weapon sells its own rounds at its own
##     price with nothing in this file to change.
##   * SLEEP hands the night to [SleepDirector] and comes down. The player lies
##     down where they are standing, the world is [i]not[/i] rebuilt, and the hour
##     moves one stage per slept segment through the run's own clock. Nothing about
##     how long a night is, what wakes the player or what it costs is decided here.
##     A world with no sleep system in it falls back to what SLEEP used to do -
##     advance the [code]RunProgress[/code] counter and rebuild the world - so the
##     button is never the reason a camp cannot be left.
##   * TRAVEL hands the journey to [TravelDirector] and steps out of the way - the
##     horse is sent for and the travel screen comes up over the camp, and nothing
##     is rebuilt unless the player confirms the ride. Nothing here knows how long a
##     journey takes, what it does to the clock, or what happens between pressing
##     the button and arriving. With nowhere marked yet it opens the regional map,
##     because there is no ride to be had until somewhere has been chosen.
##   * SEARCH FOR TROUBLE puts the waggon into its search state - see
##     [method Camp.begin_trouble_search] - and comes down. The state is the camp's
##     and the encounter that will follow is the danger system's.
##   * STASH puts blood into the camp's own pile, at the streak it is worth. The
##     multiplication is [StreakCounter]'s, asked for the same way the ride home asks
##     for it, and the ceiling on it is the camp's own room - see
##     [member camp_blood_capacity].
##   * RETURN HOME hands the run to [CashOutScreen] to be counted out and paid - and
##     only then ends the run on
##     [RunSessionState] and rebuilds the world, which [WorldBoot] then opens in the
##     base. Everything that has to survive is an autoload and is not touched: banked
##     blood, carried blood, ammunition, accepted contracts, what is known about them
##     and what they locked in all come through the rebuild.
##
## The world is frozen while it is up, the same way every other menu in the game
## freezes it, which is what stops the clock, the spawning and the enemies for as
## long as the player is deciding.
##
## Like the rest of the menus it is styled from the scene rather than in code, and
## every number it charges is an inspector field.

## Emitted as the menu is raised and dropped.
signal opened
signal closed
## Emitted when healing actually happens, with what went back in and what it cost.
signal healed(amount: float, cost: int)
## Emitted when ammunition is actually handed over.
signal ammo_bought(rounds: int, cost: int)
## Emitted as the next round begins, before the world is rebuilt.
signal next_round_started(round_number: int)
## Emitted as the player sets off home, before the world is rebuilt.
signal returned_home
## Emitted when blood is actually moved into the camp's store.
signal blood_deposited(amount: int, stored: int)
## Emitted as the player rides out for the region they marked, before the world
## is rebuilt as the road.
signal travel_requested(region_id: StringName)
## Emitted as the player sets out looking for trouble. The state itself belongs to
## the [Camp] - see [method Camp.begin_trouble_search] - and the encounter that will
## follow belongs to the danger system; this only reports the press.
signal trouble_search_started
## Emitted as the player lies down. The night itself belongs to [SleepDirector];
## this only reports the press.
signal sleep_started

## Group the menu joins, so the camp can find it without a path across the scene -
## the camp is in the world and this is on the HUD.
const GROUP := &"camp_menu"

## The carried wallet everything here is paid for out of - the [code]Blood[/code]
## autoload. Deliberately not the base's bank: what is banked is safe from the
## run, and the camp is inside the run.
@export var wallet_path: NodePath = ^"/root/Blood"
## The ammunition locker - the [code]Ammo[/code] autoload.
@export var locker_path: NodePath = ^"/root/Ammo"
## The persistent round counter - the [code]RunProgress[/code] autoload.
@export var progress_path: NodePath = ^"/root/RunProgress"
## The run's own state - the [code]RunSession[/code] autoload. Told the run is
## over when the player goes home.
@export var session_path: NodePath = ^"/root/RunSession"
## Group the player's health is found in, so the menu is not wired to the player.
@export var health_group: StringName = &"player_health"
## Freezes the world while the menu is up: no clock, no spawning, nothing moving.
@export var pauses_game: bool = true
## Key that backs out without choosing. The camp is still standing there to be
## used again.
@export var close_action: StringName = &"pause_menu"

@export_group("Heal")
## What one helping of healing costs, in blood.
@export var heal_cost: int = 300
## How much health one helping puts back. 1 is one whole heart, which is what the
## player is buying; the pool underneath is fractional, so a half-empty heart is
## filled by half of this.
@export var heal_amount: float = 1.0
## Whether a helping that cannot be used in full is charged for in part.
##
## On, and deliberately: a player missing a quarter of a heart pays a quarter of
## the price rather than a full one for healing they cannot receive. Off charges
## the whole price however little is missing, which is the blunter shop rule.
## Either way blood is only ever taken when health is actually restored, and the
## pool is never taken above its ceiling.
@export var prorate_partial_heal: bool = true

@export_group("Camp store")
## The camp's own blood pile - the [code]CampBlood[/code] autoload. A third total,
## kept apart from the carried wallet and the base's bank on purpose; see
## [BloodWallet].
@export var camp_blood_path: NodePath = ^"/root/CampBlood"
## How much blood [b]this[/b] camp will take, in total.
##
## It is a capacity and not a price: a player carrying 500 with 300 of room puts in
## 300 and walks on with 200. The ceiling belongs to the camp rather than to the
## pile, which is what makes it "per camp" - a new camp is a new [CampMenu] built
## with the world, so its room starts full again - and it is one exported number so
## a later upgrade can raise it to 400 or 500 without anything here being rewritten.
@export var camp_blood_capacity: int = 300
## The streak a stash is paid at - the [code]Streak[/code] autoload. The same counter
## the ride home is paid by, asked the same question, so the camp and the base can
## never disagree about what an outlaw is worth.
@export var streak_path: NodePath = ^"/root/Streak"
## Whether stashing pays at the streak the way the ride home does.
##
## On, blood put into a camp is worth what the player's streak says it is: four
## outlaws down turns 50 carried into 200 stashed. Off is a plain transfer, which is
## what the camp did before there was a streak to pay.
@export var pays_streak: bool = true
## Whether stashing spends the streak.
##
## Off, and deliberately. The streak is still the player's after they have stashed,
## so putting blood somewhere safe on the way through cannot quietly cost them the
## multiple the rest of the run is riding on - a camp is a place to leave blood, not
## the reckoning. What stops it being free money is the camp's own ceiling: a camp
## takes [member camp_blood_capacity] and no more however good the streak is. Turned
## on, a stash is a payout in its own right and ends the streak exactly as the base
## does.
@export var stash_clears_streak: bool = false

@export_group("Ammo")
## How many boxes one press buys. The size of a box and what it costs belong to
## the ammunition itself - see [AmmoType] - so this is the only number about
## buying that is the camp's.
@export var ammo_bundles: int = 1

@export_group("Leaving")
## Whether going home stops at the cash-out screen on the way. Off rides straight in
## and nothing is paid, which is what the camp did before there was anything to pay.
@export var shows_cash_out: bool = true
## Whether the world is actually rebuilt. Off makes the buttons report the press
## and change nothing, which is what a test harness wants.
@export var reload_scene: bool = true
## Gap between the button and the fade starting, so the press is seen to land.
@export var start_delay: float = 0.15
## How long the screen takes to go black. The world is not rebuilt until it has,
## so the rebuild is never seen happening.
@export var fade_out_time: float = 1.0
## How long the screen takes to clear on the far side. It is carried across the
## rebuild by [ScreenFade] itself.
@export var fade_in_time: float = 1.0
## Whether the soundtrack crosses over with the screen - the arena track for the
## next round, the base track for the ride home. Which tracks those are is
## [MusicDirector]'s business; this only says when.
@export var drive_music: bool = true

@export_group("Nodes")
## The right-hand column: the three things the player can decide to do. Each one only
## ever hands the press to something that already exists - the round counter, the
## travel flow, and the camp's own search state - so there is no fourth system behind
## any of them, and none of them opens a further menu.
@export var sleep_button_path: NodePath = ^"Panel/Body/Columns/Actions/SleepButton"
@export var travel_button_path: NodePath = ^"Panel/Body/Columns/Actions/TravelButton"
@export var trouble_button_path: NodePath = ^"Panel/Body/Columns/Actions/TroubleButton"
## The left-hand column: everything the camp is for looking after. All of it is on
## show the whole time the panel is up.
@export var heal_button_path: NodePath = ^"Panel/Body/Columns/Camp/HealButton"
@export var ammo_button_path: NodePath = ^"Panel/Body/Columns/Camp/AmmoButton"
@export var deposit_button_path: NodePath = ^"Panel/Body/Columns/Camp/DepositButton"
@export var weapon_button_path: NodePath = ^"Panel/Body/Columns/Camp/WeaponButton"
@export var map_button_path: NodePath = ^"Panel/Body/Columns/Camp/MapButton"
@export var return_home_button_path: NodePath = ^"Panel/Body/Columns/Camp/ReturnHomeButton"
## Readout of what the player has to spend.
@export var blood_label_path: NodePath = ^"Panel/Body/Header/Blood"
## Readout of how much health they have.
@export var health_label_path: NodePath = ^"Panel/Body/Status/Health"
## Readout of what they are carrying to fire.
@export var ammo_label_path: NodePath = ^"Panel/Body/Status/Ammo"
## Readout of how much this camp is holding.
@export var camp_blood_label_path: NodePath = ^"Panel/Body/Status/CampBlood"
## Readout of where the player is and where they have said they are going.
@export var destination_label_path: NodePath = ^"Panel/Body/Status/Destination"
## The line along the bottom, used for the hint and for anything the camp has to
## report back.
@export var status_label_path: NodePath = ^"Panel/Body/Hint"

@export_group("Wording")
@export var blood_format: String = "BLOOD %s"
## How the health readout is written: what is left, then the ceiling.
@export var health_format: String = "HEALTH %s / %s"
## How the ammunition readout is written: what the round is called, then the count
## and the capacity.
@export var ammo_readout_format: String = "%s %d / %d"
## What the readout says when nothing is in hand.
@export var ammo_readout_empty: String = "NOTHING IN HAND"
## How the heal button is written. The price is substituted in.
@export var heal_format: String = "HEAL  -  %d BLOOD"
## What it says once there is nothing to heal.
@export var heal_full_text: String = "HEALTH FULL"
## How the ammunition button is written: what is being bought, then the price.
@export var ammo_format: String = "BUY %s  -  %d BLOOD"
## What it says once the player is carrying all they can.
@export var ammo_full_text: String = "AMMUNITION FULL"
## What it says when there is no weapon to buy for.
@export var ammo_empty_text: String = "NO WEAPON IN HAND"
## How the deposit button is written: what would go in, and the camp's remaining
## room.
@export var deposit_format: String = "STASH %d BLOOD  -  ROOM %d"
## How it is written while a streak is paying: what leaves the player's hands, what it
## is paying at, what the camp will hold for it, and the camp's remaining room. Used in
## place of [member deposit_format] only while the multiple is above 1, so a run with
## no streak on it reads the plain line.
@export var deposit_streak_format: String = "STASH %d BLOOD  -  x%d  =  %d  -  ROOM %d"
## What it says once the camp will take no more.
@export var deposit_full_text: String = "THE CAMP WILL TAKE NO MORE"
## What it says when there is nothing to stash.
@export var deposit_empty_text: String = "NO BLOOD TO STASH"
## How the camp's own pile is written: what is in this camp, its capacity, and the
## total stashed across every camp.
@export var camp_blood_format: String = "CAMP %d / %d   STASHED %d"
## How the weapon button is written. What is in hand is substituted in.
@export var weapon_format: String = "WEAPONS  -  %s"
@export var weapon_none_text: String = "EMPTY HANDED"
## What the map button says.
@export var map_text: String = "REGIONAL MAP"
## What the TRAVEL action says once a region has been marked. The region is
## substituted in.
@export var travel_option_format: String = "TRAVEL TO %s"
## What it says while nothing has been marked, when pressing it opens the regional map
## to mark one.
@export var travel_option_text: String = "TRAVEL  -  CHOOSE A REGION"
@export var sleep_text: String = "SLEEP"
## What the footer reports when there is nowhere to sleep - a world with no sleep
## system in it, or a night already under way.
@export var sleep_unavailable_text: String = "THERE IS NO REST TO BE HAD HERE"
@export var trouble_text: String = "SEARCH FOR TROUBLE"
## What the footer reports when there is no waggon to search from - a world with no
## camp in it, or a search already under way.
@export var trouble_unavailable_text: String = "THERE IS NO TROUBLE TO BE FOUND FROM HERE"
## How the standing-still line is written. The region is substituted in.
@export var here_format: String = "REGION %s"
## How it is written once somewhere else has been marked: here, then there.
@export var heading_format: String = "REGION %s  ->  %s"
## What the footer reports as the player rides out. The region is substituted in.
@export var travel_status_format: String = "RIDING OUT FOR REGION %s"
## What it reports when the ride cannot be started at all - there is no way out of
## this world, or a journey is already under way.
@export var travel_unavailable_text: String = "THERE IS NO RIDE TO BE HAD FROM HERE"

@onready var _sleep_button: Button = get_node_or_null(sleep_button_path) as Button
@onready var _travel_button: Button = get_node_or_null(travel_button_path) as Button
@onready var _trouble_button: Button = get_node_or_null(trouble_button_path) as Button
@onready var _heal_button: Button = get_node_or_null(heal_button_path) as Button
@onready var _ammo_button: Button = get_node_or_null(ammo_button_path) as Button
@onready var _deposit_button: Button = get_node_or_null(deposit_button_path) as Button
@onready var _weapon_button: Button = get_node_or_null(weapon_button_path) as Button
@onready var _map_button: Button = get_node_or_null(map_button_path) as Button
@onready var _return_home_button: Button = get_node_or_null(return_home_button_path) as Button
@onready var _blood_label: Label = get_node_or_null(blood_label_path) as Label
@onready var _health_label: Label = get_node_or_null(health_label_path) as Label
@onready var _ammo_label: Label = get_node_or_null(ammo_label_path) as Label
@onready var _camp_blood_label: Label = get_node_or_null(camp_blood_label_path) as Label
@onready var _destination_label: Label = get_node_or_null(destination_label_path) as Label
@onready var _status_label: Label = get_node_or_null(status_label_path) as Label

@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet
@onready var _camp_store: BloodWallet = get_node_or_null(camp_blood_path) as BloodWallet
@onready var _streak: StreakCounter = get_node_or_null(streak_path) as StreakCounter
@onready var _locker: AmmoLocker = get_node_or_null(locker_path) as AmmoLocker
@onready var _progress: RoundCounter = get_node_or_null(progress_path) as RoundCounter

var _health: Health
## How much has gone into [b]this[/b] camp. It lives on the menu rather than in the
## pile because the ceiling is the camp's: this node is built with the world, so a
## new camp starts with its room full again.
var _stashed_here: int = 0
## True from the moment a leaving button is pressed, so a second press during the
## fade cannot start two transitions.
var _leaving: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()

	# The three actions, each wired straight to the thing it does. None of them raises
	# a further list of camp buttons - that list is the other column, and it is always
	# on show.
	if _sleep_button != null:
		_sleep_button.pressed.connect(sleep)
	if _travel_button != null:
		_travel_button.pressed.connect(_on_travel_option_pressed)
	if _trouble_button != null:
		_trouble_button.pressed.connect(search_for_trouble)
	if _heal_button != null:
		_heal_button.pressed.connect(_on_heal_pressed)
	if _ammo_button != null:
		_ammo_button.pressed.connect(_on_ammo_pressed)
	if _deposit_button != null:
		_deposit_button.pressed.connect(_on_deposit_pressed)
	if _weapon_button != null:
		_weapon_button.pressed.connect(open_weapons)
	if _map_button != null:
		_map_button.pressed.connect(open_map)
	if _return_home_button != null:
		_return_home_button.pressed.connect(return_home)

	# Followed rather than polled, so a price paid anywhere - here, or by something
	# else while the menu is up - redraws every readout at once.
	if _wallet != null:
		_wallet.changed.connect(_on_wallet_changed)
	if _locker != null:
		_locker.ammo_changed.connect(_on_ammo_changed)
		_locker.equipped_changed.connect(_on_equipped_changed)
	# The streak decides what a stash is worth, so it is followed for the same reason
	# the wallet is: an outlaw put down anywhere redraws what the camp is offering.
	if _streak != null:
		_streak.changed.connect(_on_streak_changed)


## The menu the camp should open. Null means this world has none, which the camp
## reads as "there is nothing to make camp for".
static func get_active(from_node: Node) -> CampMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as CampMenu


func is_open() -> bool:
	return visible


## Raises the menu. Called by the camp rather than by a key, so it cannot be
## opened from anywhere the player is not standing.
func open() -> void:
	if visible or _leaving:
		return

	_refresh()
	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Drops the menu and hands the world back. The camp is still standing, so this is
## backing out rather than leaving.
func close() -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _leaving:
		return
	if not event.is_action_pressed(close_action):
		return

	# Everything the camp offers is on one screen now, so there is no level to step
	# back through: the key leaves the waggon, which is what it did before the options
	# were ever split in two.
	close()
	get_viewport().set_input_as_handled()


# --- Healing ------------------------------------------------------------------

## How much health one purchase would actually put back: what the player is buying,
## or what is missing, whichever is less.
func get_heal_amount() -> float:
	var health := _get_health()
	if health == null:
		return 0.0
	return minf(maxf(heal_amount, 0.0), health.get_max() - health.get_current())


## What that would cost. A part helping is charged for in part when
## [member prorate_partial_heal] is on, and rounded up so it is never cheaper per
## point than a whole one.
func get_heal_price() -> int:
	var amount := get_heal_amount()
	if amount <= 0.0:
		return 0
	if not prorate_partial_heal or heal_amount <= 0.0:
		return maxi(heal_cost, 0)
	return ceili(float(maxi(heal_cost, 0)) * amount / heal_amount)


func can_heal() -> bool:
	if get_heal_amount() <= 0.0:
		return false
	var price := get_heal_price()
	return price <= 0 or (_wallet != null and _wallet.can_afford(price))


## Buys health, and reports whether anything happened.
##
## The order is the whole of the rule "blood is only deducted when healing
## actually occurs": what can be restored is worked out first, a player with
## nothing missing is turned away before the wallet is touched, and the pool is
## asked for exactly the amount that fits under its ceiling.
func heal() -> bool:
	if not can_heal():
		return false

	var health := _get_health()
	var amount := get_heal_amount()
	var price := get_heal_price()
	if price > 0 and (_wallet == null or not _wallet.spend(price)):
		return false

	var restored := health.heal(amount)
	healed.emit(restored, price)
	_refresh()
	return true


# --- Ammunition ---------------------------------------------------------------

## The count belonging to the weapon in the player's hands, or null when they are
## empty-handed. Everything the ammunition half of this menu shows is read off
## this, which is why the menu never learns what a shotgun is.
func get_equipped_reserve() -> AmmoReserve:
	return null if _locker == null else _locker.get_equipped_reserve()


## How many rounds one press would hand over - a whole box, or only what is left
## to fill.
func get_ammo_rounds() -> int:
	if _locker == null:
		return 0
	return _locker.purchasable_rounds(get_equipped_reserve(), ammo_bundles)


func get_ammo_price() -> int:
	if _locker == null:
		return 0
	return _locker.purchase_price(get_equipped_reserve(), ammo_bundles)


func can_buy_ammo() -> bool:
	if _locker == null:
		return false
	return _locker.can_purchase_available(get_equipped_reserve(), ammo_bundles)


## Buys ammunition for whatever is in hand, and reports how many rounds arrived.
func buy_ammo() -> int:
	if _locker == null:
		return 0

	var price := get_ammo_price()
	var rounds := _locker.purchase_available_for_equipped(ammo_bundles)
	if rounds > 0:
		ammo_bought.emit(rounds, price)
	_refresh()
	return rounds


# --- The camp's own store -----------------------------------------------------

## How much more this camp will take.
func get_camp_room() -> int:
	return maxi(camp_blood_capacity - _stashed_here, 0)


## What the streak is paying at. 1 where the camp does not pay a streak at all, so
## every figure below is the same arithmetic whether or not there is one.
func get_streak_multiplier() -> int:
	if not pays_streak or _streak == null:
		return 1
	return _streak.get_multiplier()


## How much would leave the player's hands: what they are carrying, or as much as the
## camp still has room for [i]once the streak has been paid on it[/i], whichever is
## less. [b]A capacity, not a price[/b] - carrying 500 into a camp with 300 of room
## stashes 300 and leaves 200 in hand, and on a streak of three the same camp takes
## 100 out of those hands and holds the 300 they are worth.
##
## The division is the whole reason the room is measured against
## [method get_deposit_payout] rather than against this: the ceiling is the camp's, so
## it counts what the camp ends up holding, never what was handed over to fill it.
func get_deposit_amount() -> int:
	var carried := 0 if _wallet == null else _wallet.get_total()
	@warning_ignore("integer_division")
	var room_in_hand := get_camp_room() / get_streak_multiplier()
	return mini(carried, room_in_hand)


## What the camp would actually receive: what leaves the player's hands, at the streak
## they are on. Asked of [StreakCounter] rather than worked out here, so the figure on
## the button and the figure that lands in the pile are the same arithmetic - exactly
## as [method CashOutScreen.get_payout] is.
func get_deposit_payout() -> int:
	if not pays_streak or _streak == null:
		return get_deposit_amount()
	return _streak.apply_to(get_deposit_amount())


func can_deposit() -> bool:
	return _camp_store != null and get_deposit_amount() > 0


## Moves blood out of the player's hands and into the camp, at the streak it is worth,
## and reports what the camp received.
##
## [b]The two halves are deliberately different operations, the same way the ride home
## does it[/b] - see [method CashOutScreen._bank_the_run]. What the player carried is
## [i]transferred[/i] through [method BloodWallet.transfer_to], which takes it out
## before it puts it in, so a failure part way can only ever leave the blood where it
## started and it can never exist in two piles at once; only the streak's own share is
## added from nothing. That keeps blood minted from a rule down to a single line here
## as well, and means a stash at a streak of one is a plain transfer with nothing
## invented at all.
func deposit_blood() -> int:
	if not can_deposit():
		return 0

	# Read from what actually moved rather than from what was showing, so a wallet
	# changed between the panel being drawn and the button going down stashes what is
	# really there.
	var moved := _wallet.transfer_to(_camp_store, get_deposit_amount())
	if moved <= 0:
		_refresh()
		return 0

	var bonus := 0
	if pays_streak and _streak != null:
		bonus = _streak.get_bonus(moved)
	if bonus > 0:
		_camp_store.add(bonus)

	# The room is the camp's, so what fills it is what the camp is holding - the
	# streak's share included.
	var stashed := moved + bonus
	_stashed_here += stashed
	blood_deposited.emit(stashed, _camp_store.get_total())

	# Cleared after the blood has moved, never before, so a stash that failed part way
	# cannot also cost the player the streak that would have paid it.
	if stash_clears_streak and _streak != null:
		_streak.reset()

	_refresh()
	return stashed


# --- The other screens --------------------------------------------------------

# --- The three actions ------------------------------------------------------------

## The TRAVEL action.
##
## [b]It is the existing flow and nothing else.[/b] With a region already marked it
## calls [method travel], which is the same [TravelDirector] hand-off the camp has
## always used; with nothing marked there is no ride to be had yet, so it opens the
## regional map to mark one rather than reporting a refusal the player cannot act on.
func _on_travel_option_pressed() -> void:
	if is_travelling():
		travel()
	else:
		open_map()


## Sets the player looking for trouble.
##
## [b]There is no encounter behind this yet.[/b] The waggon is put into its search
## state - see [method Camp.begin_trouble_search] - which sends the horse away so that
## the way back is the player calling it, and the panel comes down so they are standing
## in the world again. No waves, no chest, and the waggon is not moved.
func search_for_trouble() -> void:
	if _leaving:
		return

	var camp := Camp.get_active_camp(self)
	if camp == null or not camp.begin_trouble_search():
		_set_status(trouble_unavailable_text)
		return

	trouble_search_started.emit()
	close()


## Raises the weapon screen over the camp. The camp hides itself rather than
## closing, and comes back when that screen does, so nothing about what is being
## decided here is lost while the player is looking at their guns.
func open_weapons() -> void:
	var screen := CampWeaponMenu.get_active(self)
	if screen == null:
		return
	_step_aside_for(screen.closed)
	screen.open()


## Raises the regional map the same way.
func open_map() -> void:
	var screen := CampMapMenu.get_active(self)
	if screen == null:
		return
	_step_aside_for(screen.closed)
	screen.open()


## Hides the camp without handing the world back, and arranges for it to return
## when [param reopened_on] fires.
##
## The pause is deliberately left alone here. The screen going up in front takes it
## over and hands it back as it closes, and this returns in the same frame that
## happens - inside the signal, before another frame is drawn - so the world never
## gets a chance to run between the two.
func _step_aside_for(reopened_on: Signal) -> void:
	hide()
	_drop_focus()
	if not reopened_on.is_connected(_return_from_screen):
		reopened_on.connect(_return_from_screen, CONNECT_ONE_SHOT)


func _return_from_screen() -> void:
	if _leaving:
		return
	# Straight back to a rebuilt camp: a weapon swapped or a destination marked has
	# to show on the buttons the moment the player is looking at them again.
	visible = false
	open()


# --- Leaving ------------------------------------------------------------------

## Whether the player has marked somewhere other than where they are standing.
func is_travelling() -> bool:
	var session := get_node_or_null(session_path)
	if session == null or not session.has_method(&"has_travel_pending"):
		return false
	return session.call(&"has_travel_pending")


## Rides out for the marked region.
##
## [b]It leaves the world standing.[/b] Riding out is not a transition the camp
## makes - it is [TravelDirector]'s whole job, and it happens where the player is
## sitting: the horse is sent for, the travel screen goes up, and only confirming
## the ride rebuilds anything. So this hands the journey over and steps aside
## exactly as it does for the weapon and map screens, and comes back if the player
## backs out of the travel screen without riding.
##
## Where the player is going is already stored on [RunSessionState] - marking it on
## the regional map is what stored it - so nothing about the destination is decided
## or copied here.
##
## [b]The round counter is deliberately not advanced.[/b] Setting out is not
## finishing a round, and advancing it would move the time of day for a round
## nobody played - the journey spends its own days on the clock when it ends, and
## that is the only thing about a ride that touches the hour.
func travel() -> void:
	if _leaving or not is_travelling():
		return

	var director := TravelDirector.get_active(self)
	if director == null:
		return

	var session := get_node_or_null(session_path)
	var region: StringName = &""
	if session != null and session.has_method(&"get_destination_region"):
		region = session.call(&"get_destination_region")

	# Asked before the camp gets out of the way. A journey that will not begin - no
	# destination, or one already under way - leaves the camp exactly as it was
	# rather than hiding it behind a ride that never started.
	#
	# [b]It says so rather than doing nothing.[/b] A press that silently changes
	# nothing reads as the travel screen having been skipped, so the refusal is
	# written where the player is already looking.
	if not director.request():
		_set_status(travel_unavailable_text)
		return

	_set_status(travel_status_format % _region_label(region))
	# The pause is left alone, as it is for every other screen the camp steps aside
	# for: the travel screen takes it over as it opens, and the horse's arrival
	# happens in the frozen world between the two.
	_step_aside_for(director.travel_cancelled)
	travel_requested.emit(region)


## The SLEEP action: the player lies down where they are standing and the night is
## handed to [SleepDirector].
##
## [b]It leaves the world standing.[/b] Sleeping is no longer a round being finished -
## nothing is rebuilt, nobody goes anywhere, and the hour moves a stage at a time while
## the player lies there. The night is begun [i]before[/i] the panel comes down, so the
## world handed back is one that is already asleep: the camp refuses to open while it
## is, and the soundtrack reads the same answer rather than dropping back to the road
## for a frame first.
##
## A world with no sleep system falls through to [method start_next_round], which is
## exactly what this button did before there was a night to sleep.
func sleep() -> void:
	if _leaving:
		return

	var director := SleepDirector.get_active(self)
	if director == null:
		start_next_round()
		return

	if not director.begin():
		_set_status(sleep_unavailable_text)
		return

	sleep_started.emit()
	close()


## Sleeping at the camp the way it used to be done: the round counter goes up,
## the world is rebuilt, and the hour moves on because the day cycle follows that
## counter. Everything the player is carrying comes with them.
##
## [b]It is the round-advancing behaviour the camp has always had[/b], reached by the
## action that names it rather than by a button that also had to mean TRAVEL.
func start_next_round() -> void:
	if _leaving:
		return
	_leaving = true
	_begin_leaving()

	var round_number := 1
	if _progress != null:
		round_number = _progress.advance()
	next_round_started.emit(round_number)

	# The night has a state of its own on the music board, and [MusicStateWatcher] is
	# what puts the soundtrack into it - it hangs off the signal just emitted. Asking
	# for the arena here as well would take that night's music straight back off
	# again, so the older two-track handover is only used where there is no board.
	if MusicStateBoard.get_active(self) == null:
		_hand_music_over(true)
	_leave()


## Goes home - by way of being paid for the ride.
##
## [b]The reckoning comes first and the transition second.[/b] What the run was worth
## is counted out on [CashOutScreen], which is where the streak is multiplied in and
## where the carried blood is emptied into the base's pool; only once the player has
## agreed to it does anything here start rebuilding the world. Backing out of that
## screen puts them back in the camp with nothing moved, so pressing this by mistake
## costs nothing.
##
## A world with no cash-out screen in it - a test harness, a scene opened on its own -
## goes straight home exactly as it used to. Nothing is lost by that: carried blood is
## an autoload and rides home in the player's hands either way, to be put into the pool
## by hand.
func return_home() -> void:
	if _leaving:
		return
	if shows_cash_out and _raise_cash_out():
		return
	_ride_in()


## Raises the cash-out screen over the camp and reports whether there was one.
##
## The camp steps aside for it exactly as it does for the weapon and the map - hidden
## rather than closed, and with the pause left alone, because the screen in front takes
## it over. What is different is where the two ways out lead: being paid goes home,
## backing out comes back here.
func _raise_cash_out() -> bool:
	var screen := CashOutScreen.get_active(self)
	if screen == null or screen.is_open():
		return false

	hide()
	_drop_focus()
	if not screen.continued.is_connected(_on_paid_out):
		screen.continued.connect(_on_paid_out, CONNECT_ONE_SHOT)
	if not screen.cancelled.is_connected(_return_from_screen):
		screen.cancelled.connect(_return_from_screen, CONNECT_ONE_SHOT)
	screen.open()
	return true


## Paid, and the blood is already in the pool. All that is left is the ride itself.
func _on_paid_out(_banked: int) -> void:
	_ride_in()


## The ride home. The run is ended on the session, so the world that comes back is
## built as the base - see [WorldBoot], which is the one place that decision is
## made. [b]The round counter is deliberately not advanced[/b]: going home is not
## finishing a round, and advancing it would move the time of day for a round
## nobody played.
func _ride_in() -> void:
	if _leaving:
		return
	_leaving = true
	_begin_leaving()

	var session := get_node_or_null(session_path)
	if session != null and session.has_method(&"end"):
		session.call(&"end")
	returned_home.emit()

	_hand_music_over(false)
	_leave()


## Shared by both ways out: the menu comes down and the world is handed back
## before anything else, because a transition started from a frozen tree would
## come back frozen.
func _begin_leaving() -> void:
	hide()
	_drop_focus()
	get_tree().paused = false


## The soundtrack starts crossing over now rather than on the far side, so the
## handover is already under way while the screen is still going dark.
func _hand_music_over(to_arena: bool) -> void:
	if not drive_music:
		return
	var music := MusicDirector.get_active(self)
	if music == null:
		return
	if to_arena:
		music.switch_to_arena(fade_out_time)
	else:
		music.switch_to_base(fade_out_time)


func _leave() -> void:
	if not reload_scene:
		_leaving = false
		return

	# Real time and process-always, so the transition still lands whatever else has
	# touched the tree's pause state or the time scale by the time it fires.
	var timer := get_tree().create_timer(maxf(start_delay, 0.0), true, false, true)
	timer.timeout.connect(_fade_out)


## Black first, rebuild second - the player is never shown the world being taken
## apart. The fade back in cannot be asked for here, because this node is one of
## the things about to be freed, so it is left as a request for whichever
## [ScreenFade] comes up in the new world to honour.
func _fade_out() -> void:
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


# --- Readouts -----------------------------------------------------------------

## The single place every line and every button on the menu is written, so the
## price on a button and the total in the header can never disagree.
func _refresh() -> void:
	var total := 0 if _wallet == null else _wallet.get_total()
	if _blood_label != null:
		_blood_label.text = blood_format % _format_number(float(total))

	_refresh_health()
	_refresh_ammo()
	_refresh_store()
	_refresh_destination()


func _refresh_store() -> void:
	if _camp_blood_label != null:
		var stored := 0 if _camp_store == null else _camp_store.get_total()
		_camp_blood_label.text = camp_blood_format % [
			_stashed_here, maxi(camp_blood_capacity, 0), stored]

	if _deposit_button == null:
		return
	if get_camp_room() <= 0:
		_deposit_button.text = deposit_full_text
	elif get_deposit_amount() <= 0:
		_deposit_button.text = deposit_empty_text
	elif get_streak_multiplier() > 1:
		# The streak is only named on the button while it is actually worth something,
		# so a run with none reads exactly as it always did.
		_deposit_button.text = deposit_streak_format % [
			get_deposit_amount(), get_streak_multiplier(), get_deposit_payout(),
			get_camp_room()]
	else:
		_deposit_button.text = deposit_format % [get_deposit_amount(), get_camp_room()]
	_deposit_button.disabled = not can_deposit()


## Where the player is, where they have said they are going, and which of the two
## the leaving button is therefore offering. All three are read from the one
## answer, so the line and the button can never disagree.
func _refresh_destination() -> void:
	var session := get_node_or_null(session_path)
	var here: StringName = &""
	var there: StringName = &""
	if session != null and session.has_method(&"get_region_id"):
		here = session.call(&"get_region_id")
		there = session.call(&"get_destination_region")
	var travelling := is_travelling()

	if _destination_label != null:
		if here == &"" and there == &"":
			_destination_label.text = ""
		elif travelling:
			_destination_label.text = heading_format % [
				_region_label(here), _region_label(there)]
		else:
			_destination_label.text = here_format % _region_label(here)

	if _weapon_button != null:
		_weapon_button.text = weapon_format % _equipped_weapon_name()
	if _map_button != null:
		_map_button.text = map_text

	# The three actions, written off the same answer, so the one that says where the
	# player is going cannot disagree with the line above it.
	if _sleep_button != null:
		_sleep_button.text = sleep_text
	if _travel_button != null:
		_travel_button.text = travel_option_format % _region_label(there) \
			if travelling else travel_option_text
	if _trouble_button != null:
		_trouble_button.text = trouble_text


## What a region is called, taken from the map's own [MapRegion] so the camp prints
## the same label the selection screen and the posters do. Falls back to the bare
## id for a map that has not been divided up.
func _region_label(region_id: StringName) -> String:
	if region_id == &"":
		return "-"
	var session := get_node_or_null(session_path)
	if session != null and session.has_method(&"get_map"):
		var map := session.call(&"get_map") as MapDefinition
		if map != null:
			var region := map.find_region(region_id)
			if region != null:
				# The letter and the place's own name, so the camp says where the
				# player actually is rather than only which patch of map it is.
				return region.get_full_label()
	return String(region_id)


## What is in the player's hands, named from the roster rather than from the gun,
## so the button reads right even before a weapon has been built.
func _equipped_weapon_name() -> String:
	var screen := CampWeaponMenu.get_active(self)
	if screen == null or screen.catalog == null:
		return weapon_none_text
	var definition := screen.catalog.find(screen.get_equipped_id())
	return weapon_none_text if definition == null else definition.display_name


func _refresh_health() -> void:
	var health := _get_health()

	if _health_label != null:
		if health == null:
			_health_label.text = ""
		else:
			_health_label.text = health_format % [
				_format_number(health.get_current()), _format_number(health.get_max())]

	if _heal_button == null:
		return
	if health != null and get_heal_amount() <= 0.0:
		_heal_button.text = heal_full_text
	else:
		_heal_button.text = heal_format % get_heal_price()
	_heal_button.disabled = not can_heal()


func _refresh_ammo() -> void:
	var reserve := get_equipped_reserve()
	var type := null if reserve == null else reserve.get_type()

	if _ammo_label != null:
		if reserve == null or type == null:
			_ammo_label.text = ammo_readout_empty
		else:
			_ammo_label.text = ammo_readout_format % [
				type.get_plural_name().to_upper(), reserve.get_current(), reserve.get_max()]

	if _ammo_button == null:
		return

	if reserve == null or type == null:
		_ammo_button.text = ammo_empty_text
		_ammo_button.disabled = true
		return

	var rounds := get_ammo_rounds()
	if rounds <= 0:
		_ammo_button.text = ammo_full_text
		_ammo_button.disabled = true
		return

	_ammo_button.text = ammo_format % [type.format_count(rounds).to_upper(), get_ammo_price()]
	_ammo_button.disabled = not can_buy_ammo()


## Whole numbers written without a decimal point, fractions with one - so three
## hearts reads "3" and a bitten one reads "2.4", against a pool that is
## fractional underneath.
func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value


## The player's health, found by group and re-looked-up if it goes away, the same
## way the heart bar finds it. Null while there is no player, which every caller
## here reads as "there is nothing to heal".
func _get_health() -> Health:
	if _health == null or not is_instance_valid(_health):
		_health = get_tree().get_first_node_in_group(health_group) as Health
	return _health


func _on_heal_pressed() -> void:
	heal()


func _on_ammo_pressed() -> void:
	buy_ammo()


func _on_deposit_pressed() -> void:
	deposit_blood()


## The footer, used for the hint and for anything the camp reports back. Kept as
## one place so a message cannot be left standing where the hint should be.
func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _on_wallet_changed(_total: int) -> void:
	if visible:
		_refresh()


func _on_ammo_changed(_ammo_id: StringName, _current: int, _maximum: int) -> void:
	if visible:
		_refresh()


func _on_streak_changed(_streak_count: int) -> void:
	if visible:
		_refresh()


func _on_equipped_changed(_ammo_id: StringName) -> void:
	if visible:
		_refresh()


## Dropped for the same reason the menu opens unfocused - a button that kept focus
## would keep eating the accept key once play resumed. Released at the viewport
## rather than button by button, so a button added later is covered without being
## listed here.
func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
