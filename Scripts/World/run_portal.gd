class_name RunPortal
extends Node2D
## The pit at the foot of the base: stand in the middle of it, press B, and the
## next run begins.
##
## B does two different things and this node is the difference between them.
## [Teleporter] asks the portal whether the player is already standing in it
## before it does anything: if they are not, B teleports them here as it always
## did; if they are, the teleport is skipped and this starts the run instead.
## There is no second key and no menu - where the player is standing *is* the
## choice.
##
## [member radius] is deliberately generous. "In the centre of the pit" has to
## mean somewhere the player can casually walk to, not a pixel they have to find,
## so the check is a circle around this node rather than an exact position.
##
## Starting a run rebuilds the world scene, which is the same thing the pause
## menu's "Next Run" has always done, so the arena, the spawner and the run clock
## all come back fresh from their own defaults. Both blood totals are autoloads
## and are not touched here: carried blood comes along into the run and banked
## blood stays banked.

## Emitted the moment the run transition begins, before the scene is rebuilt.
signal run_starting

## Group every portal joins, so [Teleporter] can find it without a NodePath into
## another branch of the scene.
const GROUP := &"run_portal"

## How close to this node's centre the player has to be, in pixels.
@export var radius: float = 76.0
## Only bodies in this group can start a run.
@export var body_group: StringName = &"player"
## Whether pressing B asks the player *what* they are taking before anything
## else. On, the [WeaponSelectMenu] is raised first and the map question follows
## it; off, the player sets out with whatever they are already carrying.
##
## [b]Off, and deliberately.[/b] What the player is carrying is chosen at the rack
## in the base - see [WeaponRack] - rather than being asked for at the mouth of the
## pit every time they set out, so the question belongs to a place in the world
## instead of to the act of leaving. The machinery is untouched and this is the one
## switch: turning it back on restores the old startup question exactly.
@export var asks_for_weapon: bool = false
## Whether pressing B asks the player *where* they are going before the world is
## rebuilt. On, the [MapSelectMenu] is raised and the transition below does not
## begin until a map has been picked; off, B sets out immediately, which is what
## the portal did before there were maps to choose between.
##
## A world with no menu in it behaves as though this were off, so the portal
## still works on its own.
@export var asks_for_map: bool = true
## Whether pressing B asks the player which *part* of that map they are riding
## into, once they have picked the map itself.
##
## It comes after the map on purpose and could not come before it: the regions a
## [RegionSelectMenu] offers are the chosen map's own, so there is nothing to show
## until there is a map to show the inside of.
##
## [b]Off, and deliberately.[/b] Picking the desert now puts the player down at the
## desert's way in - see [member enters_at_entry_region] - and moving between its
## parts is the camp's TRAVEL rather than a question asked before the run. The
## screen itself is untouched and still works; this is the one switch that decides
## whether it is asked.
@export var asks_for_region: bool = false
## Whether a run that was never asked which region to start in begins at the
## chosen map's own way in - see [member MapDefinition.entry_region_id].
##
## It is what stops [member asks_for_region] being off from meaning "no region at
## all". The region is not named here: the map answers it, so the desert starting
## at A and a later map starting somewhere else are two resources rather than two
## branches.
@export var enters_at_entry_region: bool = true
## Whether pressing B asks the player [i]when[/i] they are riding out, once they
## have picked where.
##
## It comes last on purpose. The hours a [TimeSelectMenu] offers are the chosen
## map's own - a place with a different day cycle keeps a different set - so like
## the region question there is nothing to show until a map has been picked, and
## the hour is the last thing decided before the world is built around it. Off
## sets out at whatever hour the day cycle had already reached, which is what
## every run did before the question existed.
##
## A world with no time screen in it behaves as though this were off, so the
## portal still works on its own.
@export var asks_for_time: bool = true
## The E-style hint shown by the player's head while they are standing in the
## portal, so it is visible that B means something here. Optional, and purely a
## hint - [member radius] is what decides, not this.
@export var prompt_path: NodePath = ^"Prompt"

@export_group("Transition")
## Gap between the key press and the departure screen going up. The camera closes
## in across it, so the run starts as something happening rather than a cut.
@export var start_delay: float = 0.55
## How long the departure screen is held before the world is rebuilt, in seconds.
##
## [b]It is what the base music is handed over in.[/b] The soundtrack begins its
## two-second change of state as the screen goes up - see [member music_state] - so
## the road's own music has wound all the way up to full speed by the time the
## world underneath has finished being built. Shortening this below the board's own
## handover would leave the run opening part way through the fade.
@export var screen_time: float = 3.0
## What is written in the corner of the departure screen.
@export var screen_caption: String = "Maceraya çıkılıyor"
## Whether the world that comes back clears itself from black rather than simply
## appearing. Carried across the rebuild by [ScreenFade] itself, exactly as a
## journey's arrival is.
@export var fades_in_after: bool = true
## How long that takes.
@export var fade_in_time: float = 1.0
## Which state the soundtrack is asked for as the screen goes up - the road, which
## is what the whole run is played to. Empty leaves the music alone.
@export var music_state: StringName = &"travel"
## Zoom the camera pushes to on the way out, as a fraction. 0 leaves the camera
## alone.
@export var zoom_amount: float = 0.55
## Whether the scene is actually reloaded. Off makes the portal report the press
## and change nothing, which is what a future "choose your run" screen would want.
@export var reload_scene: bool = true

@export_group("Ready glow")
## Optional art brought up while the player is standing in the portal, so it is
## visible that B means something different here. Purely a hint - the radius is
## what decides, not this.
@export var glow_path: NodePath
## How brightly the glow sits while the player is standing in the portal.
@export_range(0.0, 1.0) var glow_alpha: float = 0.85
## How quickly it comes up and goes down.
@export var glow_response: float = 6.0

@onready var _glow: CanvasItem = get_node_or_null(glow_path) as CanvasItem
@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _starting: bool = false
var _glow_amount: float = 0.0
var _in_reach: bool = false
var _map_chosen: bool = false
var _weapon_chosen: bool = false
var _region_chosen: bool = false
var _time_chosen: bool = false
var _menu: MapSelectMenu
var _weapon_menu: WeaponSelectMenu
var _region_menu: RegionSelectMenu
var _time_menu: TimeSelectMenu


func _ready() -> void:
	add_to_group(GROUP)
	if _glow != null:
		_glow.modulate.a = 0.0
	if _prompt != null:
		_prompt.set_prompt_visible(false)


## The portal the rest of the scene should talk to. Null means the world has none,
## which every caller treats as "B just teleports".
static func get_active(from_node: Node) -> RunPortal:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as RunPortal


## Whether [param body] is standing close enough to the centre to start a run.
## Anything not in [member body_group] is never inside, so an enemy that wandered
## into the pit cannot arm it.
func is_inside(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return global_position.distance_to(body.global_position) <= radius


func is_starting() -> bool:
	return _starting


## Runs the transition. Ignored while one is already under way, so a second press
## during the delay cannot stack reloads.
func start_run() -> void:
	if _starting:
		return

	# What, then where, then whereabouts, then when, then going. Each screen is
	# raised instead of the transition beginning, and answering it comes back
	# through here with that question marked answered - so however many screens are
	# added in front of a run, the camera, the delay and the rebuild below stay one
	# path rather than being duplicated on the far side of each of them. A screen
	# added later is a line in this list, in the position the question belongs in.
	if asks_for_weapon and not _weapon_chosen and _open_weapon_menu():
		return

	if asks_for_map and not _map_chosen and _open_map_menu():
		return

	if asks_for_region and not _region_chosen and _open_region_menu():
		return

	if asks_for_time and not _time_chosen and _open_time_menu():
		return

	_starting = true
	run_starting.emit()

	_zoom_out()

	if not reload_scene:
		_starting = false
		return

	# Real time and process-always, so the transition still lands if anything has
	# paused the tree by the time it fires.
	var timer := get_tree().create_timer(maxf(start_delay, 0.0), true, false, true)
	timer.timeout.connect(_leave_for_the_road)


## The departure: the picture goes up, the soundtrack starts changing under it, and
## the world is rebuilt on the far side of both.
##
## [b]Nothing here is a transition system of its own.[/b] The screen is
## [TravelLoading] - the same black the road is ridden behind - asked to hold a
## still instead of a crossing, and the music is the state board's ordinary
## handover. All this owns is how long the picture is up for.
func _leave_for_the_road() -> void:
	if not is_inside_tree():
		return

	var screen := TravelLoading.get_active(self)
	if screen != null:
		screen.play_still(screen_caption)

	_hand_music_over()

	var timer := get_tree().create_timer(maxf(screen_time, 0.0), true, false, true)
	timer.timeout.connect(_rebuild_world)


## The road's music begins here rather than in the world that comes back, which is
## the whole reason it is already playing by the time the player can see anything:
## the board is an autoload and the rebuild does not touch it.
func _hand_music_over() -> void:
	if music_state == &"":
		return
	var board := MusicStateBoard.get_active(self)
	if board != null:
		board.enter(music_state)


## Raises the weapon selection, if this world has one. Returns whether it was - a
## world with no screen answers false and the map question is asked straight away,
## exactly as it was before there was a weapon to choose.
func _open_weapon_menu() -> bool:
	if _weapon_menu == null or not is_instance_valid(_weapon_menu):
		_weapon_menu = WeaponSelectMenu.get_active(self)
	if _weapon_menu == null:
		return false

	if not _weapon_menu.weapon_chosen.is_connected(_on_weapon_chosen):
		_weapon_menu.weapon_chosen.connect(_on_weapon_chosen)
		_weapon_menu.cancelled.connect(_on_map_cancelled)

	_weapon_menu.open()
	return true


## The player picked a weapon. The question is marked answered and the flow is
## re-entered, which raises the next screen - so the order of the questions lives
## in one place, [method start_run], rather than each screen knowing what follows
## it.
func _on_weapon_chosen(_weapon_id: StringName) -> void:
	_weapon_chosen = true
	start_run()


## Raises the map selection, if this world has one. Returns whether it was - a
## world with no menu answers false and the run sets out immediately, exactly as
## it used to.
func _open_map_menu() -> bool:
	if _menu == null or not is_instance_valid(_menu):
		_menu = MapSelectMenu.get_active(self)
	if _menu == null:
		return false

	if not _menu.map_chosen.is_connected(_on_map_chosen):
		_menu.map_chosen.connect(_on_map_chosen)
		_menu.cancelled.connect(_on_map_cancelled)

	_menu.open()
	return true


## The player picked somewhere. The question is marked answered and the flow is
## re-entered, which raises whatever question comes next.
##
## The way in is chosen here rather than left unanswered: with the region question
## off, a run would otherwise set out onto a map with no part of it chosen. See
## [method _enter_at_entry_region].
func _on_map_chosen(_map_id: StringName) -> void:
	_map_chosen = true
	if not asks_for_region:
		_enter_at_entry_region()
	start_run()


## Puts the run down at the chosen map's own way in.
##
## [b]Nothing here names a region.[/b] The map is asked for its entry through
## [method MapDefinition.get_entry_region] and the answer goes through
## [method RunSessionState.choose_region], which is the one place the run's region
## is ever written - so arriving at the desert's A and arriving there by riding
## are the same call, and the hour, the darkness and the HUD follow it exactly as
## they always have.
func _enter_at_entry_region() -> void:
	if not enters_at_entry_region:
		return

	var session := get_node_or_null(^"/root/RunSession")
	if session == null or not session.has_method(&"get_map"):
		return

	var map := session.call(&"get_map") as MapDefinition
	if map == null:
		return

	var entry := map.get_entry_region()
	if entry != null and session.has_method(&"choose_region"):
		session.call(&"choose_region", entry.region_id)


## Raises the region selection, if this world has one. Returns whether it was - a
## world with no screen answers false and the run sets out with no region chosen,
## exactly as it did before there were regions.
func _open_region_menu() -> bool:
	if _region_menu == null or not is_instance_valid(_region_menu):
		_region_menu = RegionSelectMenu.get_active(self)
	if _region_menu == null:
		return false

	if not _region_menu.region_chosen.is_connected(_on_region_chosen):
		_region_menu.region_chosen.connect(_on_region_chosen)
		_region_menu.cancelled.connect(_on_region_cancelled)

	_region_menu.open()
	return true


## The player picked a part of the map. The question is marked answered and the
## flow is re-entered, which raises the hour screen for that map.
func _on_region_chosen(_region_id: StringName) -> void:
	_region_chosen = true
	start_run()


## Raises the time-of-day selection, if this world has one. Returns whether it
## was - a world with no screen answers false and the run sets out at whatever
## hour the day cycle had reached, exactly as it did before the hour was a choice.
func _open_time_menu() -> bool:
	if _time_menu == null or not is_instance_valid(_time_menu):
		_time_menu = TimeSelectMenu.get_active(self)
	if _time_menu == null:
		return false

	if not _time_menu.time_chosen.is_connected(_on_time_chosen):
		_time_menu.time_chosen.connect(_on_time_chosen)
		_time_menu.cancelled.connect(_on_time_cancelled)

	_time_menu.open()
	return true


## The player picked an hour. The last question is answered and the ordinary
## transition runs, so from here on a run started through the screens and one
## started without them are the same thing - the world is simply rebuilt with the
## clock already standing at the hour that was asked for.
func _on_time_chosen(_time_id: StringName) -> void:
	_time_chosen = true
	start_run()


## Backed out of the hour screen. The whole destination goes back with it, for the
## same reason backing out of the region does: the session was told where the
## player was going the moment they answered, and a half-answered destination left
## standing would send the next rebuild somewhere they had just declined. Pressing
## B again asks from the map afresh.
##
## The clock is deliberately not put back, because nothing has moved it yet - see
## [method TimeSelectMenu._on_confirm_pressed], where committing is the only thing
## that touches it.
func _on_time_cancelled() -> void:
	_time_chosen = false
	_on_region_cancelled()


## Backed out of the region screen. [b]The map goes back with it[/b], because a
## map with no region chosen is a half-answered destination: the session was told
## where the player was going the moment they pressed the map, and leaving that
## standing would send the next rebuild into an arena the player had just declined.
## Pressing B again therefore asks for the map afresh, which is what backing out of
## the last question should mean.
func _on_region_cancelled() -> void:
	_map_chosen = false
	_region_chosen = false
	_time_chosen = false

	var session := get_node_or_null(^"/root/RunSession")
	if session != null and session.has_method(&"end"):
		session.call(&"end")

	_on_map_cancelled()


## Backed out. The teleport that opened this never happened, so the key is handed
## back - otherwise B would be dead for the rest of the visit.
func _on_map_cancelled() -> void:
	_release_teleporters()


## Found on the body rather than wired up, so the portal needs no path into the
## player and a player built differently still works.
func _release_teleporters() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node
	if body == null:
		return
	for node: Node in body.find_children("*", "Teleporter", true, false):
		if node.has_method(&"cancel"):
			node.call(&"cancel")


func _process(delta: float) -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	_watch_reach(body)

	if _glow == null:
		return

	var goal := 1.0 if is_inside(body) else 0.0
	_glow_amount = lerpf(_glow_amount, goal, 1.0 - exp(-glow_response * delta))
	_glow.modulate.a = _glow_amount * glow_alpha


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame - the same arrangement [ArenaPortal] uses for its own E.
func _watch_reach(body: Node2D) -> void:
	if _prompt == null:
		return

	var reach := is_inside(body) and not _starting
	if reach == _in_reach:
		return

	_in_reach = reach
	_prompt.set_prompt_visible(_in_reach)


func _rebuild_world() -> void:
	if not is_inside_tree():
		return
	if fades_in_after:
		ScreenFade.request_fade_in_after_reload(fade_in_time)
	# Unpaused first: a run started from a frozen tree would come back frozen.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _zoom_out() -> void:
	if is_zero_approx(zoom_amount):
		return
	var camera := CameraController.get_active(self)
	if camera == null:
		return
	camera.zoom_impulse([Vector2(zoom_amount, maxf(start_delay, 0.05))])
