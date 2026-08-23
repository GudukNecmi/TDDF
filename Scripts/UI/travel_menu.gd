class_name TravelMenu
extends Control
## The screen the horse is waiting at: where the player is, where they are going,
## what hour it is, and - once there is more than one - how long the ride should
## take.
##
## [b]It is raised by [TravelDirector][/b] once the horse has arrived, over the
## camp the player pressed TRAVEL in. Backing out of it puts the journey back and
## hands the camp its own screen again; confirming rides.
##
## [b]A ride costs days and it costs blood.[/b] The days are the horse's answer and
## the price is those days times [member blood_cost_per_day] - see
## [method get_travel_cost], the one place a journey is priced. Both are shown on
## every tile before anything is picked, so the player is choosing between rides
## rather than finding out what one cost afterwards.
##
## [b]A ride that cannot be paid for is refused, not part-charged.[/b] The payment
## goes through [method BloodWallet.spend], which never parts with a partial
## amount; the screen stays up with a warning under the tiles and the player keeps
## everything they were carrying. See [method _on_confirm_pressed].
##
## [b]The options are the horse's, not the screen's.[/b] It asks whichever [Horse]
## the player owns for [method Horse.get_available_days] and builds one tile per
## answer, so the starting pack horse offers a single four-day ride and a faster
## animal grows the shorter ones on its own. No number of days is named in this
## file and no count is assumed - a horse is a [code].tres[/code] file, and giving
## the player a better one is [method RunSessionState.set_horse] and nothing else.
##
## [b]Nor does it own a clock.[/b] Each tile shows the hour that journey would end
## at, read through [method RunSessionState.get_time_stage_at_offset] - which is
## the same map's own list of hours, walked the same way, that the arrival itself
## will walk when [method RunSessionState.complete_travel] spends the days. The
## preview and the arrival are one piece of arithmetic read twice rather than two
## that could disagree, and each tile draws the stage's own
## [member DayStage.icon] in its own [member DayStage.icon_colour], so the picture
## promised here is the picture the HUD will be showing on the far side.
##
## [b]Choosing is two steps on purpose[/b], exactly as [RegionSelectMenu]'s and
## [TimeSelectMenu]'s are. Pressing a tile selects it and nothing else; the ride
## does not begin until RIDE OUT is pressed, and that cannot be pressed until a
## tile has been. Nothing is picked on the player's behalf.
##
## It reports the choice and stops. The fade, the journey and the rebuild belong
## to [TravelDirector], exactly as rebuilding the world belongs to the portal that
## opened the map and region screens rather than to those screens.

## Emitted when the player commits to a ride, with how many day stages it takes.
## The blood has already been taken by the time this is emitted. Zero days while
## [member offer_durations] is off, which arrives free and without moving the
## clock.
signal travel_confirmed(days: int)
## Emitted as the screen is raised and dropped, so the cart's prompt knows to get
## out of the way and come back.
signal opened
signal closed

## Group the screen joins, so the cart's director and the corner prompt can find
## it without a path across the HUD.
const GROUP := &"travel_menu"

## Where the run, the map and the hour are read from - the [code]RunSession[/code]
## autoload.
@export var session_path: NodePath = ^"/root/RunSession"
## The animal used when the player has never been given one. [b]This is the
## starting horse[/b], and it is an inspector slot rather than a number in code so
## that the first horse and the tenth are the same kind of thing.
@export var default_horse: Horse
## Whether the player is asked how long the ride should take.
##
## On: the grid of durations is built from the horse, RIDE OUT waits for one to be
## picked, and the days picked are the days spent on the clock and paid for in
## blood. Off hides the grid, leaves RIDE OUT pressable straight away and reports a
## ride of zero days - which arrives free, without moving the clock. Off is what
## the flow did before there were durations, kept so the journey can still be
## exercised with the question switched off.
@export var offer_durations: bool = true
## Freezes the world while the screen is up, the same way every other menu does.
## This is also what takes control off the player while they decide.
@export var pauses_game: bool = true
## Key that backs out without riding. The journey is put back and the camp returns.
@export var close_action: StringName = &"pause_menu"

@export_group("Price")
## What one day on the trail costs, in carried blood. The whole of what a journey
## charges: a ride is [member blood_cost_per_day] times the days it takes, so a
## faster horse is a cheaper journey without anything here changing.
##
## [b]It is the carried wallet that pays[/b], not the base's bank and not a purse
## of its own - there is no travel currency. Deliberately one exported number so a
## stable, a toll or a difficulty setting can move the price of every journey at
## once.
@export var blood_cost_per_day: int = 10
## The wallet a ride is paid out of - the [code]Blood[/code] autoload, the same one
## the camp heals and buys ammunition from.
@export var wallet_path: NodePath = ^"/root/Blood"

@export_group("Nodes")
## Container the duration tiles are built into. Hidden entirely while
## [member offer_durations] is off.
@export var tiles_path: NodePath = ^"Panel/Body/Days"
## Optional line naming where the player is riding from and to.
@export var route_label_path: NodePath = ^"Panel/Body/Header/Route"
## Optional line naming the hour they are setting out at.
@export var now_label_path: NodePath = ^"Panel/Body/Header/Now"
## The button that sets off. Disabled until a duration has been picked.
@export var confirm_button_path: NodePath = ^"Panel/Body/Footer/ConfirmButton"
## Optional line naming what has been picked so far.
@export var status_label_path: NodePath = ^"Panel/Body/Footer/Status"
## Optional heading, given the region being ridden to.
@export var title_label_path: NodePath = ^"Panel/Body/Header/Title"
## Optional line naming the animal and what it is capable of.
@export var horse_label_path: NodePath = ^"Panel/Body/Header/Horse"

@export_group("Wording")
## The heading. The region being ridden to is substituted in.
@export var title_format: String = "RIDE OUT FOR REGION %s"
## The heading used when there is nowhere named to ride to.
@export var title_fallback: String = "RIDE OUT"
## How the animal is named: what it is called, then the fewest days it can manage.
@export var horse_format: String = "%s  -  %d DAYS AT BEST"
## What is written when there is no horse at all.
@export var horse_none_text: String = "NO HORSE"
## How a ride of more than one day is written.
@export var days_format: String = "%d DAYS"
## How a ride of exactly one is written, so it does not read "1 DAYS".
@export var one_day_text: String = "1 DAY"
## The line under a tile, naming the hour that ride would arrive at.
@export var arrival_format: String = "ARRIVE %s"
## What that line says when the map keeps no hours to arrive at.
@export var arrival_unknown_text: String = "ARRIVE - "
## How the route is written: where the player is, then where they are going.
@export var route_format: String = "REGION %s  ->  REGION %s"
## What the route line says when there is nowhere named at one end of it.
@export var route_fallback: String = ""
## How the hour being set out at is written.
@export var now_format: String = "SETTING OUT AT %s"
## What that line says when the map keeps no hours.
@export var now_unknown_text: String = ""
## What the status line says before anything is picked.
@export var status_prompt: String = "PICK HOW LONG THE RIDE SHOULD TAKE"
## What it says while no duration is being asked for - see
## [member offer_durations].
@export var status_ready_text: String = "THE HORSE IS READY"
## What it says once a ride is picked: how long, what it costs, and where it lands.
@export var status_format: String = "RIDING %s  -  %d BLOOD  -  ARRIVING %s"
## The warning shown when the picked ride cannot be paid for: what it costs, then
## what the player is carrying. [b]Nothing is taken and the screen stays up[/b].
@export var too_poor_format: String = "NOT ENOUGH BLOOD  -  %d NEEDED, %d CARRIED"
## Colour the warning is written in.
@export var warning_colour := Color(0.82, 0.1, 0.1)
## How a ride's price is written on its own tile.
@export var cost_format: String = "%d BLOOD"
## What a tile's price line says when the ride is free.
@export var cost_free_text: String = "NO COST"
## What is shown in place of the tiles when there is no horse to ride.
@export var empty_text: String = "THERE IS NOTHING HERE TO RIDE"

@export_group("Tile style")
## Styleboxes the generated tiles wear. The same resources the rest of the game's
## menus use, handed in rather than rebuilt.
@export var tile_normal: StyleBox
@export var tile_hover: StyleBox
@export var tile_pressed: StyleBox
@export var tile_disabled: StyleBox
## What the picked tile wears, so the selection can be read without hovering.
## Falls back to the pressed style when none is given.
@export var tile_selected: StyleBox
## How many tiles sit side by side before the grid wraps.
@export var columns: int = 4
## Smallest a tile is drawn, in pixels.
@export var tile_size := Vector2(210.0, 170.0)
## How large the arrival hour's own picture is drawn on its tile.
@export var icon_size := Vector2(60.0, 60.0)
@export var days_font_size: int = 34
@export var arrival_font_size: int = 18
@export var font_colour := Color(0.84, 0.76, 0.73)
@export var label_colour := Color(0.5, 0.36, 0.34)
## Whether the arrival line is written in that hour's own colour, so the word and
## the picture read as one thing the way they do on the HUD.
@export var tint_arrival_with_stage_colour: bool = true
## How much an unpicked tile is faded, so the chosen ride is the bright one.
@export_range(0.0, 1.0) var unselected_dim: float = 0.55

@onready var _tiles: Container = get_node_or_null(tiles_path) as Container
@onready var _confirm: Button = get_node_or_null(confirm_button_path) as Button
@onready var _status: Label = get_node_or_null(status_label_path) as Label
@onready var _title: Label = get_node_or_null(title_label_path) as Label
@onready var _horse_label: Label = get_node_or_null(horse_label_path) as Label
@onready var _route_label: Label = get_node_or_null(route_label_path) as Label
@onready var _now_label: Label = get_node_or_null(now_label_path) as Label
@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet

var _session: Node
## The ride under the cursor of the player's decision, before RIDE OUT is
## pressed. 0 means nothing has been picked, which is what keeps the button
## disabled.
var _selected: int = 0
var _buttons: Dictionary[int, Button] = {}
var _confirming: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_session = get_node_or_null(session_path)
	if _confirm != null:
		_confirm.pressed.connect(_on_confirm_pressed)


## The screen the cart should open. Null means this world has none, which the
## director reads as "there is nothing to ask" and leaves the player standing.
static func get_active(from_node: Node) -> TravelMenu:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TravelMenu


func is_open() -> bool:
	return visible


## Which ride is picked but not yet committed, for a test or a readout.
func get_selected_days() -> int:
	return _selected


# --- What a ride costs --------------------------------------------------------

## What a ride of [param days] costs in carried blood: the days times
## [member blood_cost_per_day].
##
## [b]The one place the price of a journey is worked out.[/b] The tiles, the status
## line, the warning and the payment itself all read it, so what the player is
## shown and what they are charged cannot come apart - and a later toll or discount
## is this function and nothing else.
func get_travel_cost(days: int) -> int:
	return maxi(days, 0) * maxi(blood_cost_per_day, 0)


## What the ride the player has picked would cost, or zero when none is picked -
## which is also what a ride costs while durations are switched off.
func get_selected_cost() -> int:
	return get_travel_cost(_selected)


## What the player has in hand to pay with.
func get_carried_blood() -> int:
	return 0 if _wallet == null else _wallet.get_total()


## Whether the picked ride can be paid for. A free ride is always affordable, and
## a screen with no wallet to ask charges nothing rather than refusing to travel.
func can_afford_selected() -> bool:
	return _can_afford(get_selected_cost())


func _can_afford(price: int) -> bool:
	if price <= 0:
		return true
	return _wallet != null and _wallet.can_afford(price)


## The animal doing the pulling: the player's own if they have been given one, and
## otherwise whatever this screen was authored with - so there is no starting
## horse named in code and nothing here has to change when one is bought.
func get_horse() -> Horse:
	if _session != null and _session.has_method(&"get_horse"):
		var owned := _session.call(&"get_horse") as Horse
		if owned != null:
			return owned
	return default_horse


## Raises the screen. Built on every open rather than once, because the hour it is
## counting from - and one day the horse - will have moved since the last look.
func open() -> void:
	if visible:
		return

	_confirming = false
	_selected = 0
	_build()
	show()
	# Deliberately unfocused, for the same reason every other menu is: the accept
	# key is bound to gameplay too, and a focused button would swallow it.
	_drop_focus()
	if pauses_game:
		get_tree().paused = true
	opened.emit()


## Drops the screen and hands the world back. The cart is still standing there, so
## this is backing out rather than deciding not to travel.
func close() -> void:
	if not visible:
		return

	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _confirming:
		return
	if not event.is_action_pressed(close_action):
		return

	close()
	get_viewport().set_input_as_handled()


# --- Building -----------------------------------------------------------------

func _build() -> void:
	_write_title()
	_write_horse()
	_write_route()
	_write_now()
	_build_tiles()
	_refresh_confirm()


func _write_title() -> void:
	if _title == null:
		return
	var region := _destination_label()
	_title.text = title_fallback if region.is_empty() else title_format % region


## Where the ride starts and where it ends, both named through the map's own
## [MapRegion] so this screen prints the letters the camp and the posters do.
func _write_route() -> void:
	if _route_label == null:
		return

	var here := _region_label(_current_region())
	var there := _destination_label()
	if here.is_empty() or there.is_empty():
		_route_label.text = route_fallback
		return
	_route_label.text = route_format % [here, there]


## The hour the player is setting out at, asked of the session so this screen and
## the HUD behind it are reading one clock. Written in that hour's own colour, the
## way the arrival lines on the tiles are.
func _write_now() -> void:
	if _now_label == null:
		return

	var stage := _current_stage()
	if stage == null:
		_now_label.text = now_unknown_text
		return

	_now_label.text = now_format % stage.display_name
	if tint_arrival_with_stage_colour:
		_now_label.add_theme_color_override(&"font_color", stage.icon_colour)


func _write_horse() -> void:
	if _horse_label == null:
		return
	var horse := get_horse()
	if horse == null:
		_horse_label.text = horse_none_text
		return
	_horse_label.text = horse_format % [horse.get_label(), horse.get_default_days()]


## One tile per ride the animal will make. A player with no horse is not an error
## - they simply have nothing to ride - so it says so rather than showing an empty
## grid with a dead button under it.
func _build_tiles() -> void:
	if _tiles == null:
		return

	for child: Node in _tiles.get_children():
		child.queue_free()
	_buttons.clear()

	# Taken off the screen rather than left empty, so a milestone that is not asking
	# the question does not leave a gap where the question was.
	_tiles.visible = offer_durations
	if not offer_durations:
		return

	var grid := _tiles as GridContainer
	if grid != null:
		grid.columns = maxi(columns, 1)

	var horse := get_horse()
	if horse == null:
		_tiles.add_child(_build_notice(empty_text))
		return

	for days: int in horse.get_available_days():
		var tile := _build_tile(days)
		_buttons[days] = tile
		_tiles.add_child(tile)


## One ride: how long it takes, over the hour it lands at.
func _build_tile(days: int) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = tile_size
	tile.focus_mode = Control.FOCUS_NONE
	tile.clip_text = true

	var box := VBoxContainer.new()
	box.name = "Text"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 6)

	var stage := _arrival_stage(days)
	if stage != null and stage.icon != null:
		var picture := TextureRect.new()
		picture.name = "Icon"
		picture.texture = stage.icon
		picture.custom_minimum_size = icon_size
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(picture)

	var days_label := Label.new()
	days_label.name = "Days"
	days_label.text = format_days(days)
	days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_label.add_theme_font_size_override(&"font_size", days_font_size)
	days_label.add_theme_color_override(&"font_color", font_colour)
	box.add_child(days_label)

	var arrival := Label.new()
	arrival.name = "Arrival"
	arrival.text = _arrival_line(stage)
	arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrival.add_theme_font_size_override(&"font_size", arrival_font_size)
	arrival.add_theme_color_override(&"font_color", _arrival_colour(stage))
	box.add_child(arrival)

	# What this particular ride costs, on the tile that offers it - so the player is
	# comparing prices rather than discovering one after choosing. Written in the
	# warning colour when it is a ride they cannot pay for.
	var price := get_travel_cost(days)
	var cost := Label.new()
	cost.name = "Cost"
	cost.text = cost_free_text if price <= 0 else cost_format % price
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override(&"font_size", arrival_font_size)
	cost.add_theme_color_override(
		&"font_color", label_colour if _can_afford(price) else warning_colour)
	box.add_child(cost)

	tile.add_child(box)
	tile.set_meta(&"days", days)
	_apply_tile_style(tile, false)

	tile.pressed.connect(_on_tile_pressed.bind(days))
	return tile


## The line shown in place of the grid when there is nothing to offer.
func _build_notice(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", days_font_size)
	label.add_theme_color_override(&"font_color", label_colour)
	return label


## How a ride is written. Singular and plural are two inspector strings rather
## than a rule, so a language that pluralises differently is a field.
func format_days(days: int) -> String:
	if days == 1:
		return one_day_text
	return days_format % days


## The hour a ride of [param days] would land at, asked of the session so the
## preview and the arrival cannot come apart.
func _arrival_stage(days: int) -> DayStage:
	if _session == null or not _session.has_method(&"get_time_stage_at_offset"):
		return null
	return _session.call(&"get_time_stage_at_offset", days) as DayStage


func _arrival_line(stage: DayStage) -> String:
	if stage == null:
		return arrival_unknown_text
	return arrival_format % stage.display_name


func _arrival_colour(stage: DayStage) -> Color:
	if tint_arrival_with_stage_colour and stage != null:
		return stage.icon_colour
	return label_colour


## The hour the ride sets out at - offset zero, which is the same arithmetic every
## tile's arrival is read through.
func _current_stage() -> DayStage:
	return _arrival_stage(0)


## Where the player is standing, or empty when the run has not been asked.
func _current_region() -> StringName:
	if _session == null or not _session.has_method(&"get_region_id"):
		return &""
	return _session.call(&"get_region_id")


## What the region being ridden to is called.
func _destination_label() -> String:
	if _session == null or not _session.has_method(&"get_destination_region"):
		return ""
	return _region_label(_session.call(&"get_destination_region"))


## What a region is called, taken from the map's own [MapRegion] so this screen
## prints the same letter the camp and the posters do. Falls back to the bare id
## for a map that has not been divided up.
func _region_label(region_id: StringName) -> String:
	if region_id == &"":
		return ""

	if _session != null and _session.has_method(&"get_map"):
		var map := _session.call(&"get_map") as MapDefinition
		if map != null:
			var region := map.find_region(region_id)
			if region != null:
				# The letter and the place's own name - the travel screen has the
				# room for both, and where the ride ends is worth naming properly.
				return region.get_full_label()
	return String(region_id)


# --- Choosing -----------------------------------------------------------------

## Selecting only. [b]Nothing about the journey moves here[/b] - the clock is not
## touched and the world is not rebuilt until RIDE OUT is pressed, which is what
## makes changing your mind free.
func _on_tile_pressed(days: int) -> void:
	if _confirming or not offer_durations:
		return

	_selected = days
	for value: int in _buttons:
		_apply_tile_style(_buttons[value], value == _selected)
	_refresh_confirm()


## Commits: pays for the ride, then announces it. Making the journey is
## [TravelDirector]'s.
##
## A ride of zero days is what comes out of this while no duration is being asked
## for, and it is deliberately reported as a number rather than as a special case:
## the arrival spends it exactly as it spends four, and moves the clock by nothing.
##
## [b]The blood is taken here, and it is all or nothing.[/b] The price is checked
## and paid through [method BloodWallet.spend], which is the single place in the
## game that decides whether a price can be met and never parts with a partial
## amount - so a player who cannot afford the ride is left holding everything they
## had, on this screen, with the warning up and the other durations still there to
## pick. Charging in the same breath as committing is what stops the check and the
## payment from ever disagreeing.
func _on_confirm_pressed() -> void:
	if _confirming or (offer_durations and _selected <= 0):
		return

	var price := get_selected_cost()
	if price > 0 and (_wallet == null or not _wallet.spend(price)):
		# Refused rather than reported: the screen stays exactly where it was, with
		# the reason written under the tiles.
		_refresh_confirm()
		return

	_confirming = true

	var days := _selected
	# Closed without reporting a cancellation, because the player did not back out
	# - the world is already on its way to being rebuilt around this answer.
	hide()
	_drop_focus()
	if pauses_game:
		get_tree().paused = false

	travel_confirmed.emit(days)


## The button and the line under the tiles, written together so what RIDE OUT is
## doing and what the footer says can never disagree.
##
## A ride that cannot be paid for leaves the button dead and says why. [b]The
## player is not moved off the screen and nothing is taken from them[/b] - the
## other durations are still there to pick, and so is the way back to the camp.
func _refresh_confirm() -> void:
	var picked := not offer_durations or _selected > 0
	var affordable := can_afford_selected()

	if _confirm != null:
		_confirm.disabled = not (picked and affordable)

	if _status == null:
		return

	if not picked:
		_status.text = status_prompt
		_status.add_theme_color_override(&"font_color", label_colour)
		return

	if not affordable:
		_status.text = too_poor_format % [get_selected_cost(), get_carried_blood()]
		_status.add_theme_color_override(&"font_color", warning_colour)
		return

	_status.add_theme_color_override(&"font_color", label_colour)
	if _selected <= 0:
		_status.text = status_ready_text
		return

	var stage := _arrival_stage(_selected)
	var when := arrival_unknown_text if stage == null else stage.display_name
	_status.text = status_format % [format_days(_selected), get_selected_cost(), when]


## The one place a tile's look is decided, so the selected look cannot be left
## behind on a tile the player has moved off.
func _apply_tile_style(tile: Button, selected: bool) -> void:
	if tile == null:
		return

	var resting := tile_selected if selected and tile_selected != null else tile_normal
	if selected and tile_selected == null:
		resting = tile_pressed
	if resting != null:
		tile.add_theme_stylebox_override(&"normal", resting)
	if tile_hover != null:
		tile.add_theme_stylebox_override(&"hover", tile_hover if not selected else resting)
	if tile_pressed != null:
		tile.add_theme_stylebox_override(&"pressed", tile_pressed)
	if tile_disabled != null:
		tile.add_theme_stylebox_override(&"disabled", tile_disabled)

	# Faded rather than recoloured, so an hour's own colour survives being the one
	# not picked - a dimmed dawn still reads as dawn.
	tile.modulate.a = 1.0 if selected or _selected <= 0 else unselected_dim


func _drop_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
