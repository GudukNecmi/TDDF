class_name RunMapSaloonScreen
extends Control
## The saloon: the screen a run map's saloon point opens onto, and the three
## things that can be done in one.
##
## [b]It is a screen over the board, not a place to ride to.[/b] A run map
## saloon is a point the piece is already standing on - the ride there was the
## ordinary one, paid for in day cycles by [RunMapTravel] like every other road
## - so arriving raises this over the map and leaving puts it away, and the
## piece never moves. That is the whole of "return to the run map at the same
## node": there is nothing to return to it from. [RunMapSaloonNode] is what
## hears the arrival and raises this; see it for why the map's own choices are
## closed while the screen is up.
##
## [b]Three doors, one panel.[/b] The root menu offers information, rest and
## the shop, and each of the two lists is built into the same rows on the same
## panel rather than being a second screen - the same way the bandit briefing
## lives on [WorldBanditDecisionMenu]'s own panel rather than opening in front
## of it. Every row is a copy of a button authored in this screen's scene, so
## how a row looks is an Inspector value and this file sets no colour, size or
## font.
##
## [b]The information half is a seam with nothing behind it yet.[/b] A topic -
## see [RunMapSaloonTopic] - names a subject and carries a line to say until
## something really answers it. Asking emits [signal information_asked]; a
## listener that knows the answer calls [method tell] while that signal is being
## handled, and whatever it says is what the bartender says. With no listener at
## all the topic's own placeholder line is used. Bounties, the places the
## sandstorm has covered and anything else a run wants to know all arrive as
## listeners and as [code].tres[/code] topics, and none of them will add a
## branch here.
##
## [b]Rest is the existing clock, spent outright.[/b] Sleeping calls
## [method WorldTimeManager.advance_day_cycle] once per cycle - the same call
## one beat of a ride makes, landing exactly on an authored period boundary -
## so the sun, the day stage and the map's lighting move for a night upstairs
## exactly as they move for a night on the road. Nothing about travel timing is
## touched: this spends day cycles, it does not change what a road costs.
##
## [b]The shop owns no prices.[/b] Each row is a [RunMapSaloonGood] that
## charges and delivers through whatever system already owns it - see
## [RunMapSaloonAmmoGood], which buys through [AmmoLocker] exactly as the camp's
## trader does.

## Emitted as the saloon opens, with the point it belongs to. Null for a screen
## raised on its own for tuning.
signal opened(site: RunMapSite)
## Emitted once the player has left and the screen is down.
signal closed
## Emitted the moment a subject is asked about, for whatever knows the answer.
## [b]A listener answers by calling [method tell] from inside its handler[/b];
## anything said after this signal has finished being handled is too late and is
## ignored, which is what keeps the bartender's line a reply rather than a
## message arriving later.
signal information_asked(topic: RunMapSaloonTopic)
## Emitted once a rest has been slept, with how many day cycles it spent.
signal rested(day_cycles: int)
## Emitted once a purchase has actually landed.
signal purchased(good: RunMapSaloonGood)

const GROUP := &"run_map_saloon_screen"

## Which of the three lists is up. The root menu is [constant Page.MENU]; the
## other two are the same rows built from different data.
enum Page { MENU, INFORMATION, SHOP }

## Whether the world is frozen while the saloon is up - the same as every other
## menu built this way.
@export var pauses_game: bool = true
## The action that leaves the saloon, so it closes on the same key every other
## screen closes on.
@export var close_action: StringName = &"pause_menu"
## Where the clock a rest is spent on is found.
@export var clock_path: NodePath = ^"/root/WorldClock"
## Where the blood the shop is paid in is counted.
@export var wallet_path: NodePath = ^"/root/Blood"

@export_group("Rest")
## How many day cycles one rest spends. [b]Four[/b] - a rest is a long stop, not
## a nap - and an Inspector value so a saloon that sells a shorter night is a
## number here rather than an edit to this file.
@export var rest_day_cycles: int = 4

@export_group("Information")
## Every subject this saloon can be asked about, one [RunMapSaloonTopic] each.
@export var topics: Array[RunMapSaloonTopic] = []

@export_group("Shop")
## Everything this saloon carries, one [RunMapSaloonGood] each.
@export var goods: Array[RunMapSaloonGood] = []

@export_group("Wording")
@export var greeting_text: String = "WHAT WILL IT BE?"
@export var information_prompt: String = "ASK ABOUT WHAT?"
@export var shop_prompt: String = "EVERYTHING ON THE SHELF IS FOR SALE."
## Said after a rest. [code]%d[/code] is how many day cycles were slept and
## [code]%s[/code] the word for that many - see [member cycle_words].
@export var rest_text: String = "YOU SLEEP OFF %d %s."
## The word for one day cycle, two, three, and so on - the first entry is one.
## An array rather than a plural rule, exactly as [RunMapPanel] words a road.
@export var cycle_words: PackedStringArray = PackedStringArray(
	["DAY", "DAYS", "DAYS"])
## How a shop row reads: the name, then the price.
@export var price_format: String = "%s  -  %d BLOOD"
## How a shop row reads when there is nothing left to sell the player - the
## reserve already full, or the shelf emptied for this visit.
@export var unavailable_format: String = "%s  -  NOTHING TO SELL"
## How a shop row reads when the player cannot pay for it.
@export var unaffordable_format: String = "%s  -  %d BLOOD  (SHORT)"
## How an information row reads when asking is free.
@export var free_topic_format: String = "%s"
## How an information row reads when asking costs.
@export var paid_topic_format: String = "%s  -  %d BLOOD"
## Said when a purchase lands.
@export var bought_text: String = "OBLIGED."
## Said when a press could not be paid for or had nothing behind it.
@export var refused_text: String = "NOT WITH WHAT YOU ARE CARRYING."
## How the blood readout is written.
@export var blood_format: String = "%d BLOOD"

@export_group("Nodes")
@export var line_path: NodePath = ^"Panel/Body/Line"
@export var blood_path: NodePath = ^"Panel/Body/Blood/Value"
## The root menu and its four buttons.
@export var menu_path: NodePath = ^"Panel/Body/Pages/Stack/Menu"
@export var information_button_path: NodePath = ^"Panel/Body/Pages/Stack/Menu/Information"
@export var rest_button_path: NodePath = ^"Panel/Body/Pages/Stack/Menu/Rest"
@export var shop_button_path: NodePath = ^"Panel/Body/Pages/Stack/Menu/Shop"
@export var leave_button_path: NodePath = ^"Panel/Body/Pages/Stack/Menu/Leave"
## Where a list's rows are put.
@export var list_path: NodePath = ^"Panel/Body/Pages/Stack/List"
## The row copied for each topic and each good. Authored in the scene and kept
## hidden, so every row's lettering, size and stylebox is an Inspector value.
@export var row_template_path: NodePath = ^"Panel/Body/Pages/Stack/List/Row"
## The button that goes back from a list to the root menu.
@export var back_button_path: NodePath = ^"Panel/Body/Back"

@onready var _line: Label = get_node_or_null(line_path) as Label
@onready var _blood: Label = get_node_or_null(blood_path) as Label
@onready var _menu: Control = get_node_or_null(menu_path) as Control
@onready var _list: Control = get_node_or_null(list_path) as Control
@onready var _row_template: Button = get_node_or_null(row_template_path) as Button
@onready var _back: Button = get_node_or_null(back_button_path) as Button

## The point this saloon belongs to, for a listener that wants to know which one
## was walked into. Null for a screen opened on its own.
var _site: RunMapSite
var _page: Page = Page.MENU
## The rows currently built, so a list can be torn down without touching the
## template that made them.
var _rows: Array[Button] = []
## What a listener said in answer to the question being asked, cleared before
## every ask - see [method tell].
var _told: String = ""
## Whether one is being asked at all, so a stray [method tell] from something
## that was not asked cannot put words in the bartender's mouth.
var _asking: bool = false
## How many of each good have been bought this visit, keyed by the good.
var _bought: Dictionary[RunMapSaloonGood, int] = {}


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	if _row_template != null:
		# The template is never shown itself; it is only ever copied.
		_row_template.visible = false
	_bind(information_button_path, _on_information_pressed)
	_bind(rest_button_path, _on_rest_pressed)
	_bind(shop_button_path, _on_shop_pressed)
	_bind(leave_button_path, close)
	if _back != null:
		_back.pressed.connect(_show_menu)


## The saloon this map has, or null when there is none - which
## [RunMapSaloonNode] reads as "there is nowhere to walk into, so arriving on a
## saloon point does nothing", exactly as a run map opened on its own for tuning
## should.
static func get_active(from_node: Node) -> RunMapSaloonScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RunMapSaloonScreen


func is_open() -> bool:
	return visible


## Walks in. [param site] is the point this saloon is, for a listener that cares
## which one; nothing here reads it. Does nothing on a screen already up.
func open(site: RunMapSite = null) -> void:
	if visible:
		return
	_site = site
	_bought.clear()
	_show_menu()
	_write(greeting_text)
	show()
	if pauses_game:
		get_tree().paused = true
	opened.emit(_site)


## Leaves, and puts the screen away. Safe to call on a screen already down, so
## the same call serves the LEAVE button, the close key and a caller cancelling
## a saloon it opened.
func close() -> void:
	if not visible:
		return
	_clear_rows()
	hide()
	_site = null
	if pauses_game:
		get_tree().paused = false
	closed.emit()


## What the bartender says in answer to the subject currently being asked about.
## [b]Called from inside a handler of [signal information_asked][/b] by whatever
## knows the answer; ignored at any other moment, so nothing can write a line
## onto a question that was not asked.
func tell(line: String) -> void:
	if _asking:
		_told = line


## Which point this saloon belongs to. Null for a screen opened on its own.
func get_site() -> RunMapSite:
	return _site


# --- The three doors ------------------------------------------------------------

func _on_information_pressed() -> void:
	_page = Page.INFORMATION
	_build_rows(topics.size(), _topic_label, _on_topic_pressed)
	_write(information_prompt)


func _on_shop_pressed() -> void:
	_page = Page.SHOP
	_build_rows(goods.size(), _good_label, _on_good_pressed)
	_write(shop_prompt)


## A night upstairs, spent on the clock the whole game already runs on - see the
## class doc. The cycles are spent one at a time rather than as one jump because
## a day cycle is a period, and [method WorldTimeManager.advance_day_cycle]
## lands exactly on the next boundary: four of them is four authored hours, and
## the sun, the day stage and the lighting each hear all four go by.
func _on_rest_pressed() -> void:
	var cycles := maxi(rest_day_cycles, 0)
	var clock := _clock()
	if clock != null:
		for _cycle: int in range(cycles):
			clock.advance_day_cycle()
	_write(rest_text % [cycles, _cycle_word(cycles)])
	_refresh_blood()
	rested.emit(cycles)


func _on_topic_pressed(index: int) -> void:
	if index < 0 or index >= topics.size():
		return
	var topic := topics[index]
	if topic == null:
		return

	var wallet := _wallet()
	if topic.cost > 0 and (wallet == null or not wallet.spend(topic.cost)):
		_write(refused_text)
		_refresh_blood()
		return

	# Cleared before the ask and read straight after it, so the line the screen
	# writes is the answer to this question and nothing else - see [method tell].
	_told = ""
	_asking = true
	information_asked.emit(topic)
	_asking = false

	_write(_told if not _told.is_empty() else topic.placeholder_line)
	_refresh_blood()
	_refresh_rows()


func _on_good_pressed(index: int) -> void:
	if index < 0 or index >= goods.size():
		return
	var good := goods[index]
	if good == null or good.is_sold_out(int(_bought.get(good, 0))) or not good.can_buy(self):
		_write(refused_text)
		return

	if not good.buy(self):
		_write(refused_text)
		_refresh_blood()
		_refresh_rows()
		return

	_bought[good] = int(_bought.get(good, 0)) + 1
	_write(bought_text)
	_refresh_blood()
	_refresh_rows()
	purchased.emit(good)


# --- The rows -------------------------------------------------------------------

## Puts the root menu back up and takes whichever list was showing down.
func _show_menu() -> void:
	_page = Page.MENU
	_clear_rows()
	if _menu != null:
		_menu.visible = true
	if _list != null:
		_list.visible = false
	if _back != null:
		_back.visible = false
	_refresh_blood()


## Builds [param count] rows from the template, each labelled by
## [param label_for] and each reporting its own index to [param pressed].
func _build_rows(count: int, label_for: Callable, pressed: Callable) -> void:
	_clear_rows()
	if _menu != null:
		_menu.visible = false
	if _list != null:
		_list.visible = true
	if _back != null:
		_back.visible = true
	if _list == null or _row_template == null:
		return

	for index: int in range(count):
		var row := _row_template.duplicate() as Button
		if row == null:
			continue
		row.visible = true
		row.text = label_for.call(index)
		row.pressed.connect(pressed.bind(index))
		_list.add_child(row)
		_rows.append(row)
	_refresh_rows()
	_refresh_blood()


## Rewrites every row in place - what a purchase, a price change or a question
## paid for leaves behind. The rows themselves are not rebuilt, so nothing the
## player is hovering moves out from under them.
func _refresh_rows() -> void:
	var label_for := _topic_label if _page == Page.INFORMATION else _good_label
	for index: int in range(_rows.size()):
		var row := _rows[index]
		if row == null:
			continue
		row.text = label_for.call(index)
		row.disabled = not _row_enabled(index)


## Whether the row at [param index] can be pressed. An information row is always
## live unless it cannot be paid for; a shop row is live only while its good has
## something left to hand over.
func _row_enabled(index: int) -> bool:
	if _page == Page.INFORMATION:
		var topic := topics[index] if index < topics.size() else null
		if topic == null:
			return false
		var wallet := _wallet()
		return topic.cost <= 0 or (wallet != null and wallet.can_afford(topic.cost))
	var good := goods[index] if index < goods.size() else null
	if good == null:
		return false
	return not good.is_sold_out(int(_bought.get(good, 0))) and good.can_buy(self)


func _topic_label(index: int) -> String:
	var topic := topics[index] if index < topics.size() else null
	if topic == null:
		return ""
	if topic.cost <= 0:
		return free_topic_format % topic.label
	return paid_topic_format % [topic.label, topic.cost]


func _good_label(index: int) -> String:
	var good := goods[index] if index < goods.size() else null
	if good == null:
		return ""
	var named := good.get_label(self)
	if good.is_sold_out(int(_bought.get(good, 0))) or not good.can_buy(self):
		# A good refused for want of blood still shows its price, because that is
		# the number the player is short of; one refused because there is nothing
		# left to hand over has no price to show.
		var price := good.get_price(self)
		var wallet := _wallet()
		if price > 0 and wallet != null and not wallet.can_afford(price):
			return unaffordable_format % [named, price]
		return unavailable_format % named
	return price_format % [named, good.get_price(self)]


func _clear_rows() -> void:
	for row: Button in _rows:
		if row != null and is_instance_valid(row):
			row.queue_free()
	_rows.clear()


# --- Odds and ends --------------------------------------------------------------

## The close key leaves the saloon, and every other press is swallowed while it
## is up - so the map behind it can never take a click meant for this screen.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(close_action):
		close()
	get_viewport().set_input_as_handled()


func _bind(path: NodePath, handler: Callable) -> void:
	var button := get_node_or_null(path) as Button
	if button != null:
		button.pressed.connect(handler)


func _refresh_blood() -> void:
	if _blood == null:
		return
	var wallet := _wallet()
	_blood.text = blood_format % (0 if wallet == null else wallet.get_total())


func _write(text: String) -> void:
	if _line != null:
		_line.text = text


func _cycle_word(cycles: int) -> String:
	if cycle_words.is_empty():
		return ""
	return cycle_words[clampi(cycles - 1, 0, cycle_words.size() - 1)]


func _clock() -> WorldTimeManager:
	return get_node_or_null(clock_path) as WorldTimeManager


func _wallet() -> BloodWallet:
	return get_node_or_null(wallet_path) as BloodWallet
