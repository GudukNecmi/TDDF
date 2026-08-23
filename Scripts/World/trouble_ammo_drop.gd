class_name TroubleAmmoDrop
extends Node
## The ammunition a search for trouble is worth, on two triggers: one crate promised a
## few seconds after the search opens, and another kind that only appears when the
## player has very nearly run dry.
##
## [b]There is no crate system here.[/b] What a crate is, where one may land, how far it
## is kept from the player and from the walls, how it falls in and what happens when it
## is taken are all [AmmoCrateSpawner]'s and [AmmoCrate]'s already - the boss arena has
## been dropping them on a ten-second clock since before there was trouble to find. All
## this does is decide [i]when[/i] a search is owed one, ask that supply for it inside
## the map's own playable rectangle, and say how large it is drawn and what it is worth.
## So a change to how crates are placed or how they land reaches this for free, and there
## is one way a crate reaches the ground in the game rather than three.
##
## [b]The two triggers are independent.[/b] The promised crate is a pacing beat: it
## arrives on its own clock whatever the player is carrying, and it neither consumes nor
## restarts the emergency cooldown. The emergency crate is a safety net: it watches what
## is actually in the gun and only fires when that falls under
## [member emergency_threshold], and once it has fired it will not fire again for
## [member emergency_cooldown] seconds however empty the player gets. Spending the
## promised crate on the emergency clock would mean a player who opened a search nearly
## empty had to choose between the two.
##
##   [codeblock]
##   search opens  ->  drop_delay  ->  the promised crate
##                 |
##                 `-  ammunition under the threshold  ->  emergency crate
##                                                          |
##                                                          `- 25s deaf, then watching again
##   [/codeblock]
##
## [b]One box is out at a time.[/b] Both triggers pass through the same gate - see
## [member one_at_a_time] - so a search cannot litter the arena with ammunition, and a
## crate that is owed while another is standing is not lost: it waits for the ground to
## be clear and then falls.

## Emitted as a crate is dropped, with the crate, where it landed, and whether it was the
## emergency one rather than the promised one.
signal crate_dropped(crate: Node2D, at: Vector2, emergency: bool)

## Group this joins, so anything - a test, a later readout - can find it without a path.
const GROUP := &"trouble_ammo_drop"

## Whether a search drops crates at all. Off is the search exactly as it was before there
## was ammunition in it.
@export var enabled: bool = true

@export_group("Nodes")
## The search this hangs off. Left unresolved it is found by group, so the two need not
## be wired together in the scene.
@export var danger_path: NodePath = ^"../DangerDirector"
## The world's own crate supply, asked to build and place every crate. Without one,
## nothing is dropped - which is what a world with no crates should do rather than
## inventing a second way of making them.
@export var spawner_path: NodePath = ^"../AmmoCrates"
## Where crates are parented. The world itself, so one outlives the Danger it was dropped
## into and can still be collected in the one after it.
@export var container_path: NodePath = ^".."
## Read for the playable rectangle when [member bounds] is left empty - the same
## [member EnemySpawner.arena_bounds] every enemy in the world is placed against, so a
## crate is bound by the map's own walls rather than by a second idea of them.
@export var bounds_path: NodePath = ^"../EnemySpawner"
## The rectangle a crate may land in, given directly. Left at nothing, the spawner's own
## is used.
@export var bounds := Rect2()
## The ammunition locker, read to know how empty the player is. The same autoload a crate
## itself refills through, so the trigger and the refill cannot disagree about what the
## player is carrying.
@export var locker_path: NodePath = ^"/root/Ammo"

@export_group("The promised crate")
## Seconds after a Danger opens before the promised crate lands.
@export var drop_delay: float = 3.0
## Whether one promised crate covers the whole search.
##
## On, which is the rule as written: a search is one promised crate however many Dangers
## deep it is taken. Off promises one for every Danger, which is what a longer search
## would want if the ladder is ever lengthened.
@export var once_per_search: bool = true

@export_group("The emergency crate")
## Whether the safety net exists at all.
@export var emergency_enabled: bool = true
## How empty the equipped weapon's reserve has to get before one is sent, as a fraction
## of its [b]maximum[/b] capacity.
##
## A tenth by default: this is the player being genuinely out, not the player being low.
## Measured against the ceiling rather than against some fixed number of rounds, so it
## reads the same for every weapon and keeps reading correctly when a capacity upgrade
## raises that ceiling.
@export_range(0.0, 1.0, 0.01) var emergency_threshold: float = 0.1
## Seconds the net is deaf for after it has fired, counted from the moment the crate is
## dropped rather than from the moment it is collected - so a player who ignores one is
## not also denied the next.
@export var emergency_cooldown: float = 25.0

@export_group("The crate")
## How much of the equipped weapon's [b]maximum[/b] capacity one of these crates is
## worth.
##
## [b]Of the ceiling, not of what is in the gun[/b] - see
## [member AmmoCrate.refill_fraction] - so a fifth is the same number of rounds to a
## player who has been careful as to one who is nearly empty, and anything that would not
## fit is refused by the reserve rather than overfilling it.
@export_range(0.0, 1.0, 0.01) var refill_fraction: float = 0.2
## How large it is drawn against the crate scene's own size. Below 1 is the small crate.
@export var crate_scale: float = 0.62
## Whether only one of this search's crates may be standing at a time. On, so ammunition
## is a place the player goes to rather than a supply lying about the arena.
@export var one_at_a_time: bool = true

var _danger: DangerDirector
## Whether the search is on. Nothing is watched or dropped outside one.
var _searching: bool = false
## Whether this search's promised crate has already been given.
var _dropped: bool = false
## When the promised crate is due, on the engine's own clock. 0 is "nothing owed".
##
## Wall clock rather than a scaled timer, because the beat has to keep its length through
## an ending that is running the world at half speed.
var _due_msec: int = 0
## When the emergency net may fire again. 0 is "now".
var _ready_msec: int = 0
## The crate this search has standing, so the gate can tell whether the ground is clear
## without counting crates that belong to something else.
var _crate: AmmoCrate


func _enter_tree() -> void:
	add_to_group(GROUP)


## Wired a frame late for the reason every other director here is: there is no ordering
## of the world's children that guarantees the search has readied first.
func _ready() -> void:
	set_process(false)
	_wire.call_deferred()


## The drop in this world, or null when it has none.
static func get_active(from_node: Node) -> TroubleAmmoDrop:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as TroubleAmmoDrop


## Whether this search has already been given its promised crate.
func has_dropped() -> bool:
	return _dropped


## Whether the emergency net would fire if the player were empty enough right now.
func is_emergency_ready() -> bool:
	return get_emergency_cooldown_left() <= 0.0


## Seconds left on the emergency cooldown, for a readout or a test.
func get_emergency_cooldown_left() -> float:
	if _ready_msec <= 0:
		return 0.0
	return maxf(float(_ready_msec - Time.get_ticks_msec()) / 1000.0, 0.0)


## How full the equipped weapon's reserve is, from 0 to 1. 1 when there is nothing to
## measure - an empty-handed player is not an emergency.
func get_ammo_fraction() -> float:
	var reserve := _reserve()
	if reserve == null:
		return 1.0
	var ceiling := reserve.get_max()
	if ceiling <= 0:
		return 1.0
	return clampf(float(reserve.get_current()) / float(ceiling), 0.0, 1.0)


## The crate this search has standing, or null when the ground is clear.
func get_standing_crate() -> AmmoCrate:
	if _crate == null or not is_instance_valid(_crate) or _crate.is_taken():
		return null
	return _crate


func _wire() -> void:
	if not is_inside_tree():
		return
	_danger = _resolve_danger()
	if _danger == null:
		return
	if not _danger.sequence_started.is_connected(_on_search_started):
		_danger.sequence_started.connect(_on_search_started)
	if not _danger.danger_started.is_connected(_on_danger_started):
		_danger.danger_started.connect(_on_danger_started)
	if not _danger.sequence_ended.is_connected(_on_search_ended):
		_danger.sequence_ended.connect(_on_search_ended)


## A new search. Whatever the last one was given, and whatever it owed, is forgotten - so
## every outing is worth its own promised crate and opens with the net armed.
func _on_search_started() -> void:
	_dropped = false
	_due_msec = 0
	_ready_msec = 0
	_crate = null
	_searching = true
	set_process(true)


func _on_danger_started(_number: int, _enemy_count: int) -> void:
	if not enabled or _due_msec > 0:
		return
	if once_per_search and _dropped:
		return
	_due_msec = Time.get_ticks_msec() + int(maxf(drop_delay, 0.0) * 1000.0)


## The search is over: the net is disarmed and everything it was counting is dropped, so
## the next one cannot inherit a cooldown or a debt from this one. A crate already on the
## ground is left where it is - it belongs to the world now, not to the search.
func _on_search_ended(_dangers_cleared: int) -> void:
	_searching = false
	_due_msec = 0
	_ready_msec = 0
	_crate = null
	set_process(false)


## The one place either crate is decided, so the two triggers cannot both fire into the
## same gap. The promised crate is asked first: it is owed, and the net is only ever a
## fallback.
func _process(_delta: float) -> void:
	if not _searching or not enabled:
		return
	if one_at_a_time and get_standing_crate() != null:
		return

	var now := Time.get_ticks_msec()
	if _due_msec > 0 and now >= _due_msec:
		if _drop(false):
			_dropped = true
			_due_msec = 0
		return

	if not emergency_enabled or now < _ready_msec:
		return
	if get_ammo_fraction() >= clampf(emergency_threshold, 0.0, 1.0):
		return
	if _drop(true):
		# Counted from the drop, so the cooldown is the same length whether the player runs
		# for the crate or leaves it standing.
		_ready_msec = Time.get_ticks_msec() + int(maxf(emergency_cooldown, 0.0) * 1000.0)


## One crate, asked of the world's own supply and sent down from above. Returns whether
## anything actually landed.
func _drop(emergency: bool) -> bool:
	if not is_inside_tree():
		return false

	# A search called off between the beat being owed and this running leaves nothing
	# behind: the crate was for a fight that is no longer happening.
	var danger := _resolve_danger()
	if danger == null or not danger.is_running():
		return false

	var spawner := _resolve_spawner()
	if spawner == null:
		return false

	var crate := spawner.spawn_crate_in(_play_area(), _container())
	if crate == null:
		return false

	_dress(crate)
	_crate = crate as AmmoCrate
	if _crate != null:
		_crate.drop_in()

	crate_dropped.emit(crate, crate.global_position, emergency)
	return true


## How large it is drawn and what it is worth. Written to the crate that was built rather
## than to a second crate scene, so the small crate and the arena's crate are the same
## artwork at two sizes.
func _dress(crate: Node2D) -> void:
	crate.scale = Vector2.ONE * maxf(crate_scale, 0.05)

	var box := crate as AmmoCrate
	if box == null:
		return
	box.refill_fraction = clampf(refill_fraction, 0.0, 1.0)


## The rectangle it may land in: the one given here, or the map's own.
func _play_area() -> Rect2:
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		return bounds
	var spawner := get_node_or_null(bounds_path) as EnemySpawner
	return Rect2() if spawner == null else spawner.arena_bounds


func _container() -> Node:
	var named := get_node_or_null(container_path)
	return named if named != null else get_parent()


## The reserve belonging to the gun in the player's hands, or null when they are
## empty-handed - the same seam a crate refills through.
func _reserve() -> AmmoReserve:
	var locker := get_node_or_null(locker_path) as AmmoLocker
	return null if locker == null else locker.get_equipped_reserve()


func _resolve_danger() -> DangerDirector:
	var named := get_node_or_null(danger_path) as DangerDirector
	return named if named != null else DangerDirector.get_active(self)


func _resolve_spawner() -> AmmoCrateSpawner:
	var named := get_node_or_null(spawner_path) as AmmoCrateSpawner
	return named if named != null else AmmoCrateSpawner.get_active(self)
