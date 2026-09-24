class_name RunMapSaloonNode
extends Node
## The run map's saloon points: what happens when the piece arrives on one.
##
## [b]It is the third listener on [signal RunMapDirector.site_reached], and it
## is built exactly like the first two.[/b] [RunMapBanditNode] and
## [RunMapBountyBossNode] answer their own kinds of point the same way: they hear
## an arrival, deal with it, and know nothing about riding, generating or
## drawing the map - which is the whole reason the arrival is a signal rather
## than a branch in [RunMapDirector]. None of the three knows the others exist.
##
## [b]Unlike those two, a saloon changes no scene.[/b] A bandit point hands the
## arrival to [WorldMapCombatBridge] and the map is torn down behind it; a
## saloon is a screen raised over the board - see [RunMapSaloonScreen] - so the
## piece never moves, the graph is never stored and reloaded, and leaving is
## simply the screen going away. That is the whole of "return to the run map at
## the same node".
##
## [b]The map's own choices are closed while the screen is up.[/b]
## [RunMapDirector] opens them again immediately after announcing the arrival,
## which would leave the roads live underneath the saloon; so the close is
## deferred, landing after the director's own call, and the arrival's choices
## come back only when the player leaves. The screen swallows input and freezes
## the tree as well, but neither of those unhighlights the roads, and a haloed
## road behind an open screen is a road the player is being invited to take.
##
## [b]Which points are saloons is not decided here.[/b] That is the generator's
## node distribution - an array of [RunMapSitePlan] on the map's own
## [RunMapGenerator] - and this node simply answers whichever handles
## [member kinds] names. A map with no saloon on it wires this up and it never
## fires.

## Emitted the instant a saloon's screen has been raised, with the point.
signal saloon_entered(site: RunMapSite)
## Emitted once the player has left it again and the map is live once more.
signal saloon_left(site: RunMapSite)

@export_group("Wiring")
@export var director_path: NodePath = ^"../RunMapDirector"
@export var view_path: NodePath = ^"../RunMapView"
## The screen an arrival raises. Optional, and looked up by group when it is not
## set: a map with no saloon screen simply arrives on a saloon point and does
## nothing, which is what a run map opened on its own for tuning does.
@export var screen_path: NodePath = ^"../UI/RunMapSaloonScreen"

@export_group("Which points are saloons")
## Every handle this node answers. An array rather than one name, so a second
## sort of saloon - a cantina, a roadhouse - is an entry here and no edit to
## this file.
@export var kinds: Array[StringName] = [&"saloon"]

var _director: RunMapDirector
var _view: RunMapView
var _screen: RunMapSaloonScreen
## The point whose saloon is currently open, so leaving is reported against the
## right one. Null whenever no saloon is open.
var _inside: RunMapSite


func _ready() -> void:
	_director = get_node_or_null(director_path) as RunMapDirector
	_view = get_node_or_null(view_path) as RunMapView
	if _director != null and not _director.site_reached.is_connected(_on_site_reached):
		_director.site_reached.connect(_on_site_reached)


## Whether [param kind] is one this node answers - which every caller reads as
## "this point is a saloon".
func answers(kind: StringName) -> bool:
	return kinds.has(kind)


# --- Arriving on one ------------------------------------------------------------

func _on_site_reached(site: RunMapSite) -> void:
	if site == null or _inside != null or not answers(site.kind):
		return
	var screen := _resolve_screen()
	if screen == null or screen.is_open():
		return

	_inside = site
	if not screen.closed.is_connected(_on_screen_closed):
		screen.closed.connect(_on_screen_closed, CONNECT_ONE_SHOT)
	# Deferred so it lands after [RunMapDirector] reopens them - see the class
	# doc. Deferred calls are made whether or not the tree is paused, so the
	# screen pausing the world does not hold this one back.
	if _view != null:
		_view.set_picking.call_deferred(false)
	screen.open(site)
	saloon_entered.emit(site)


func _on_screen_closed() -> void:
	var site := _inside
	_inside = null
	if _view != null:
		_view.set_picking(true)
	saloon_left.emit(site)


func _resolve_screen() -> RunMapSaloonScreen:
	if _screen != null and is_instance_valid(_screen):
		return _screen
	_screen = get_node_or_null(screen_path) as RunMapSaloonScreen
	if _screen == null:
		_screen = RunMapSaloonScreen.get_active(self)
	return _screen
