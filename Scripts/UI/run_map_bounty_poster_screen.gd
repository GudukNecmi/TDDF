class_name RunMapBountyPosterScreen
extends Control
## The contract, held up over the run map, the instant the piece lands on the
## point the man is waiting at.
##
## [b]It is the poster the player already knows, not a second drawing of one.[/b]
## The sheet is a [WantedPoster] instanced from the very scene the base's wanted
## board and the World Map's own board hang up - the same paper, the same face
## printed out of the same wardrobe, the same three lines of what is known and
## the same price in blood. All this adds is the moment: the sheet comes in off
## the edge of the screen, turns straight, settles, is held long enough to read,
## and goes.
##
## [b]Nothing here decides anything.[/b] Which contract is shown is the arriving
## point's - see [RunMapBountyBossNode] - and what happens when the sheet is gone
## is that node's too, hung off [signal finished]. The screen never touches the
## ledger, never offers the contract and never asks a question.
##
## [b]It cannot be clicked.[/b] Every part of it is mouse-transparent and the
## sheet's own TAKE button is taken off, so a presentation playing over the map
## can never swallow a click meant for a road.

## Emitted as the sheet sets off, with the contract on it.
signal presented(bounty: Bounty)
## Emitted once the sheet has been held and taken away again. [b]The seam the
## fight hangs off[/b]: whatever asked for the presentation starts the encounter
## here.
signal finished(bounty: Bounty)

## Group this joins, so a listener can find it without being wired to it.
const GROUP := &"run_map_bounty_poster_screen"

## The sheet. The base's own [code]WantedPoster.tscn[/code], so there is one
## poster in the game rather than one per place that shows one.
@export var poster_scene: PackedScene
## The ledger the knowledge categories and the contract's rung are read from -
## the [code]Bounties[/code] autoload. Only its tuning is asked for; nothing is
## written.
@export var ledger_path: NodePath = ^"/root/Bounties"

@export_group("Nodes")
## The thing that is actually moved, scaled and turned. The sheet is built
## inside it, so the flight is authored once against a frame rather than against
## whatever size the poster came out.
@export var card_path: NodePath = ^"Card"
## The darkening behind it. Optional - a screen without one simply shows the
## sheet over the map.
@export var dim_path: NodePath = ^"Dim"

@export_group("The sheet")
## The smallest the sheet is ever drawn, in pixels, before [member card_scale].
## The sheet is sized to whatever it actually needs - a long name, a long line of
## what is known - and this is only a floor, so a contract nothing is known about
## is not held up as a postage stamp.
@export var card_min_size := Vector2(300.0, 560.0)

@export_group("The flight")
## How far off its resting place the sheet starts, in pixels. Down and to the
## right is a sheet coming up off the trail into the player's hands.
@export var from_offset := Vector2(220.0, 640.0)
## How far over the sheet starts, in degrees, straightening as it flies.
@export var from_degrees: float = 14.0
## How large the sheet starts, against the size it settles at. Below 1 is a
## sheet coming from far away.
@export var from_scale: float = 0.62
## How large the sheet is once it has settled, against the size it was authored
## at.
@export var card_scale: float = 1.35
## How long the flight takes, in seconds.
@export var fly_time: float = 0.85
## How long the sheet is left up afterwards, in seconds - long enough to read a
## name, a price and three lines.
@export var hold_time: float = 1.9
## How long it takes to go, in seconds.
@export var leave_time: float = 0.45
## How far the sheet drifts as it goes, in pixels.
@export var leave_offset := Vector2(0.0, -120.0)

@export_group("The darkening")
## How far the map behind is darkened while the sheet is up.
@export_range(0.0, 1.0, 0.01) var dim_alpha: float = 0.55
## How long that darkening takes to come in and go out, in seconds.
@export var dim_time: float = 0.35

@onready var _card: Control = get_node_or_null(card_path) as Control
@onready var _dim: CanvasItem = get_node_or_null(dim_path) as CanvasItem

var _ledger: BountyLedger
var _poster: WantedPoster
var _bounty: Bounty
var _flight: Tween
## Where the card rests - the middle of the screen, worked out from the size the
## sheet actually came out rather than authored, since a long name makes a wider
## sheet and a wider sheet is centred somewhere else.
var _home := Vector2.ZERO
var _running: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	# Every part of this is a picture. Nothing in it may ever take a click off
	# the map underneath - see the class doc.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _card != null:
		_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _dim != null and _dim is Control:
		(_dim as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


static func get_active(from_node: Node) -> RunMapBountyPosterScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RunMapBountyPosterScreen


## Whether a sheet is up or on its way.
func is_presenting() -> bool:
	return _running


## Holds [param bounty] up, and reports whether it actually set off - false for
## no contract, no sheet to print it on, or a presentation already running,
## which the caller reads as "get on with the fight".
func present(bounty: Bounty) -> bool:
	if _running or bounty == null or _card == null or poster_scene == null:
		return false

	if not _print(bounty):
		return false

	_running = true
	_bounty = bounty
	show()
	# The sheet's real size is not known on the frame it is built: a container
	# reports the room its contents need only once it has been laid out. So the
	# card is left invisible for that beat and measured on the other side of it -
	# see [method _fly]. A sheet laid out narrower than its own contents does not
	# shrink them, it spills them over both edges, which is exactly what asking
	# too early produced.
	_card.modulate.a = 0.0
	if _dim != null:
		_dim.modulate.a = 0.0
	_fly()
	presented.emit(bounty)
	return true


## The flight itself, a beat after [method present] so the sheet can be measured.
func _fly() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _running or _card == null:
		return

	_measure()
	_card.modulate.a = 1.0
	_card.position = _home + from_offset
	_card.rotation = deg_to_rad(from_degrees)
	_card.scale = Vector2.ONE * maxf(card_scale * from_scale, 0.01)

	if _flight != null and _flight.is_valid():
		_flight.kill()
	_flight = create_tween()
	_flight.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flight.tween_property(_card, ^"position", _home, maxf(fly_time, 0.01))
	_flight.parallel().tween_property(_card, ^"rotation", 0.0, maxf(fly_time, 0.01)) \
		.set_trans(Tween.TRANS_SINE)
	_flight.parallel().tween_property(_card, ^"scale",
		Vector2.ONE * maxf(card_scale, 0.01), maxf(fly_time, 0.01)) \
		.set_trans(Tween.TRANS_SINE)
	if _dim != null:
		_flight.parallel().tween_property(_dim, ^"modulate:a",
			clampf(dim_alpha, 0.0, 1.0), maxf(dim_time, 0.01)) \
			.set_trans(Tween.TRANS_SINE)

	_flight.tween_interval(maxf(hold_time, 0.0))
	_flight.tween_property(_card, ^"modulate:a", 0.0, maxf(leave_time, 0.01)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flight.parallel().tween_property(_card, ^"position", _home + leave_offset,
		maxf(leave_time, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _dim != null:
		_flight.parallel().tween_property(_dim, ^"modulate:a", 0.0,
			maxf(leave_time, 0.01)).set_trans(Tween.TRANS_SINE)
	_flight.tween_callback(_on_flight_done)


## Cuts a presentation short and reports it finished, so nothing is left waiting
## on a sheet that is no longer going to come down on its own.
func dismiss() -> void:
	if not _running:
		return
	if _flight != null and _flight.is_valid():
		_flight.kill()
	_flight = null
	_on_flight_done()


## Builds the sheet for [param bounty] and reports whether there was one to
## build. Torn down and rebuilt each time rather than kept, exactly the way the
## wanted board rebuilds its whole row, so a contract that changed between two
## presentations is never half redrawn.
func _print(bounty: Bounty) -> bool:
	for child: Node in _card.get_children():
		_card.remove_child(child)
		child.queue_free()
	_poster = null

	var poster := poster_scene.instantiate() as WantedPoster
	if poster == null:
		return false

	# Full strength and no button: this is the man the player has just ridden
	# into, not an offer on a board.
	poster.accepted_alpha = 1.0
	poster.shows_take_button = false
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(poster)

	var ledger := _get_ledger()
	var categories: Array[BountyKnowledgeCategory] = []
	var rarity: BountyRarity = null
	if ledger != null:
		var settings := ledger.get_settings()
		categories = settings.knowledge_categories
		rarity = bounty.get_rarity(settings)
	poster.set_bounty(bounty, categories, rarity)

	_poster = poster
	return true


## Sizes the card to the sheet and works out where the middle of the screen is
## for a sheet that size.
##
## [b]The sheet is given the room it actually asks for[/b] rather than a size
## authored here: a name and a line of what is known are as wide as they are, and
## a poster laid out narrower than its own contents spills them over both edges
## instead of shrinking them. [member card_min_size] is a floor under that, not a
## size.
func _measure() -> void:
	if _poster == null or not is_instance_valid(_poster):
		return
	var wanted := _poster.get_combined_minimum_size()
	wanted.x = maxf(wanted.x, card_min_size.x)
	wanted.y = maxf(wanted.y, card_min_size.y)
	_card.size = wanted
	_card.pivot_offset = wanted * 0.5
	# Anchors [i]and[/i] offsets: setting the anchors alone leaves the sheet
	# sitting at its own minimum size in the corner of the card.
	_poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Centred against the screen's own rectangle, which is the viewport's, so a
	# taller or wider sheet still rests in the middle of it. The scale is not in
	# this: the card turns about its own middle, so growing it moves nothing.
	_home = ((size - wanted) * 0.5).round()


func _on_flight_done() -> void:
	var bounty := _bounty
	_running = false
	_bounty = null
	_flight = null
	hide()
	finished.emit(bounty)


func _get_ledger() -> BountyLedger:
	if _ledger != null and is_instance_valid(_ledger):
		return _ledger
	_ledger = get_node_or_null(ledger_path) as BountyLedger
	return _ledger
