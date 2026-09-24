class_name RunMapMarketScreen
extends RunMapSaloonScreen
## The market: the screen a run map's market point opens onto - a roadside wagon
## selling run-only weapon upgrades and a Card, and nothing else.
##
## [b]It is the saloon's shop with the saloon taken away.[/b] Everything a shop
## row does - asking a [RunMapSaloonGood] its price, greying what cannot be
## bought, counting purchases against a good's stock, paying through
## [BloodWallet] and delivering through whatever system owns the good - is
## [RunMapSaloonScreen]'s, inherited rather than written twice. What this adds is
## only what makes a market a market: there is no bartender and no bed, so it
## opens straight onto the shelf, BACK leaves rather than going back to a menu,
## what is on the shelf is dealt per point from [RunMapMarketProducts], and the
## merchant can be tipped to bring out something else.
##
## [b]Separate from the Base's economy.[/b] Everything here is paid for in the
## carried blood - never the [BloodBank] - and everything bought is for this run
## only: an upgrade raises the weapon's run stack
## ([method WeaponDefinition.raise_run_level]) and a Card goes to the
## [code]RunCards[/code] autoload.
##
## [b]A point keeps its shelf for the run.[/b] What a point has on its shelf, how
## many times it has been rerolled and what has been bought off it are written
## into [WorldMapState]'s between-scenes memory under [constant KIND_MARKET],
## stamped with the run - the same way [RunMapDirector] keeps the map - so riding
## back into a market finds the shelf exactly as it was left, and a fight in
## between cannot restock it.

const MARKET_GROUP := &"run_map_market_screen"
## Kind handle this screen's records are kept under in [WorldMapState].
const KIND_MARKET := &"market"

## What this market sells and how its shelf is dealt.
@export var products: RunMapMarketProducts
## Where the run map's graph and region are read from, for the seed the shelf is
## dealt with and the region its record is kept under.
@export var director_path: NodePath = ^"../../RunMapDirector"
## The run's between-scenes memory, where each point's shelf is kept.
@export var world_state_path: NodePath = ^"/root/WorldState"
## The run's state, asked which run this is and which weapon is carried.
@export var session_path: NodePath = ^"/root/RunSession"

@export_group("Reroll")
## The "what else do you have?" button.
@export var reroll_button_path: NodePath = ^"Panel/Body/Reroll"
## How the reroll button reads: [code]%d[/code] is the tip.
@export var reroll_format: String = "WHAT ELSE DO YOU HAVE?  -  %d BLOOD"
## Said once the shelf has been rerolled.
@export var rerolled_text: String = "HOW ABOUT THESE, THEN?"

@onready var _reroll: Button = get_node_or_null(reroll_button_path) as Button

## How many times this point's shelf has been rerolled this run.
var _refresh: int = 0


func _ready() -> void:
	super._ready()
	# Out of the saloon's group, so [RunMapSaloonNode]'s own fallback lookup can
	# never walk a saloon point into a market.
	remove_from_group(RunMapSaloonScreen.GROUP)
	add_to_group(MARKET_GROUP)
	# A market has no menu to go back to: BACK is the way out, like the close key.
	if _back != null:
		if _back.pressed.is_connected(_show_menu):
			_back.pressed.disconnect(_show_menu)
		_back.pressed.connect(close)
	if _reroll != null:
		_reroll.visible = false
		_reroll.pressed.connect(reroll)
	purchased.connect(_on_purchased)


## The market this map has, or null when there is none - [RunMapMarketNode]'s
## fallback when its screen path is not set.
static func get_active_market(from_node: Node) -> RunMapMarketScreen:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(MARKET_GROUP) as RunMapMarketScreen


## Walks up to the wagon: puts out [param site]'s shelf - the one it was left
## with, or a fresh deal on the first visit this run - and opens straight onto it.
func open(site: RunMapSite = null) -> void:
	if visible:
		return
	var bought: Array[StringName] = []
	if products != null:
		bought = _load_shelf(site)
	super.open(site)
	# [method RunMapSaloonScreen.open] starts every visit with nothing bought; a
	# market's purchases belong to its shelf, so they are put back.
	for good: RunMapSaloonGood in goods:
		if bought.has(RunMapMarketProducts.key_of(good)):
			_bought[good] = 1
			if good is RunMapUpgradeGood:
				(good as RunMapUpgradeGood).mark_sold()
	_on_shop_pressed()
	if _reroll != null:
		_reroll.visible = products != null
	_refresh_blood()


## "What else do you have?": pays the tip out of the carried blood and deals all
## five slots again, none of them allowed to be anything the shelf just carried.
## Returns whether it went.
func reroll() -> bool:
	if products == null or not visible:
		return false
	var wallet := _wallet()
	var tip := maxi(products.reroll_tip, 0)
	if tip > 0 and (wallet == null or not wallet.spend(tip)):
		_write(refused_text)
		_refresh_blood()
		return false

	var previous: Array[StringName] = []
	for good: RunMapSaloonGood in goods:
		previous.append(RunMapMarketProducts.key_of(good))
	_refresh += 1
	goods = products.deal(_weapon(), previous, deal_seed_for(get_site(), _refresh))
	_bought.clear()
	_store_shelf(get_site())
	_on_shop_pressed()
	_write(rerolled_text)
	return true


## The seed [param site]'s shelf is dealt with on its [param refresh]th deal: the
## run's map seed, the point's id and the refresh, so the same point deals the
## same way and no two points deal alike.
func deal_seed_for(site: RunMapSite, refresh: int = 0) -> int:
	var site_id := -1 if site == null else site.id
	var map_seed := 0
	var director := _director()
	if director != null and director.get_graph() != null:
		map_seed = director.get_graph().seed
	return hash([map_seed, site_id, refresh])


## The weapon the player is carrying - the one the upgrade slots are dealt for.
func _weapon() -> WeaponDefinition:
	var mount := WeaponMount.get_active(self)
	if mount != null and mount.get_definition() != null:
		return mount.get_definition()
	var session := get_node_or_null(session_path) as RunSessionState
	if session == null or session.get_weapon_catalog() == null:
		return null
	var catalog := session.get_weapon_catalog()
	var chosen := catalog.find(session.get_weapon_id())
	return chosen if chosen != null else catalog.get_default()


# --- The point's record -----------------------------------------------------------

## Puts [param site]'s shelf into [member RunMapSaloonScreen.goods] and answers
## the keys already bought off it. A point with no record from this run is dealt
## fresh and written down.
func _load_shelf(site: RunMapSite) -> Array[StringName]:
	var bought: Array[StringName] = []
	var record := _recall(site)
	if record.is_empty() or int(record.get(&"run_index", -1)) != _run_index():
		_refresh = 0
		var none: Array[StringName] = []
		goods = products.deal(_weapon(), none, deal_seed_for(site, _refresh))
		_store_shelf(site)
		return bought

	_refresh = int(record.get(&"refresh", 0))
	var keys: Array[StringName] = []
	for key: String in record.get(&"keys", PackedStringArray()):
		keys.append(StringName(key))
	goods = products.rebuild(_weapon(), keys)
	for key: String in record.get(&"bought", PackedStringArray()):
		bought.append(StringName(key))
	return bought


func _store_shelf(site: RunMapSite) -> void:
	var state := get_node_or_null(world_state_path) as WorldMapState
	var director := _director()
	if state == null or director == null or site == null:
		return
	var keys := PackedStringArray()
	var bought := PackedStringArray()
	for good: RunMapSaloonGood in goods:
		var key := String(RunMapMarketProducts.key_of(good))
		keys.append(key)
		if good.is_sold_out(int(_bought.get(good, 0))):
			bought.append(key)
	state.remember(director.region_id, KIND_MARKET, _record_key(site), {
		&"run_index": _run_index(),
		&"refresh": _refresh,
		&"keys": keys,
		&"bought": bought,
	})


func _recall(site: RunMapSite) -> Dictionary:
	var state := get_node_or_null(world_state_path) as WorldMapState
	var director := _director()
	if state == null or director == null or site == null:
		return {}
	return state.recall(director.region_id, KIND_MARKET, _record_key(site))


func _record_key(site: RunMapSite) -> StringName:
	return StringName("site_%d" % site.id)


func _run_index() -> int:
	var session := get_node_or_null(session_path) as RunSessionState
	return 0 if session == null else session.get_run_index()


func _director() -> RunMapDirector:
	return get_node_or_null(director_path) as RunMapDirector


func _on_purchased(_good: RunMapSaloonGood) -> void:
	_store_shelf(get_site())


## The carried blood readout, and with it whether the tip can be paid.
func _refresh_blood() -> void:
	super._refresh_blood()
	if _reroll == null or products == null:
		return
	var tip := maxi(products.reroll_tip, 0)
	_reroll.text = reroll_format % tip
	var wallet := _wallet()
	_reroll.disabled = tip > 0 and (wallet == null or not wallet.can_afford(tip))
