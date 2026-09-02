class_name WorldBoot
extends Node
## Decides what the world that has just been built is for: standing around at
## home, or a run.
##
## The base and the arena are not two scenes, they are two places a few thousand
## pixels apart in the same one, and going on a run rebuilds that scene. So
## something has to look at the freshly built world and say which end of it the
## player belongs at. That is this node, and it is the only place that decision
## is made.
##
## It asks [RunSessionState] - the one piece of state a rebuild does not destroy
## - and then does one of two things:
##
##   * [b]No map chosen.[/b] The player is put at the base's own arrival point,
##     the camera is clamped to the base, and the run's clock is simply never
##     started. The world is fully built either way; the arena is just somewhere
##     nobody is standing.
##   * [b]A map chosen.[/b] The player is left in the arena where the scene
##     placed them, the round intro is played, and the run is started the moment
##     it finishes. The World Map is the current way a run is actually reached -
##     see [RunPortal] - and never rebuilds the world to fight, so this branch is
##     for whichever later phase migrates a map that does not open there.
##
## [b]A boss can take a round away from this node.[/b] It is not a round: it has
## no clock and nothing follows it, so where an ordinary round would have started
## its manager, the manager is simply not started.
##
##   * [b]A boss.[/b] If one of the player's contracts points at this map, this region
##     and this hour, the man is here - see [method _boss_takes_the_round].
##
## Starting the run is deliberately this node's job rather than the wave
## manager's own [member WaveManager.auto_start]: the round has to begin *after*
## the intro rather than underneath it, and "when does the fighting start" is a
## property of the world being built, not of the manager. The manager's own
## public [method WaveManager.start] is what is called, so nothing about how a
## run runs changes here.
##
## [b]The world runs in slow motion while the card is on screen.[/b] Not starting
## the wave manager stops enemies *arriving* and keeps the run's clock at zero,
## but it does nothing about the player walking off or the enemy the scene was
## authored with closing in while a title nobody has finished reading is still up.
## So everything that walks is put into slow motion for the length of the intro
## and released the instant it reports itself done - see
## [member slow_during_intro].
##
## The slowdown is deliberately not a freeze and not a time scale. The player
## keeps control the whole way through, and only *characters* are slowed, so the
## card's own animation, the soundtrack and every effect in the arena run at their
## ordinary speed and the intro takes exactly as long as it was authored to.
## [WorldSlowdown] owns the multiplier and both the player and the enemies read
## it, so there is one number and nothing is left slow behind us.

## Emitted once the world is ready to be played - after the intro on a run, and
## immediately when opening in the base.
signal world_started(running: bool)

## The session's memory of which map was chosen, if any.
@export var session_path: NodePath = ^"/root/RunSession"
## The run's clock. Started when a run's intro finishes and left alone otherwise.
@export var wave_manager_path: NodePath = ^"../WaveManager"
## Body moved home when the world opens with no run under way.
@export var player_path: NodePath = ^"../Player"

@export_group("Base")
## Id of the [TeleportDestination] the player is put at when there is no run -
## the pit at the foot of the base, the same place the teleport home lands.
@export var base_destination_id: StringName = &"base_pit"
## Whether the camera is clamped to that destination's own bounds on arrival, so
## the view cannot wander off across the empty world between the base and the
## arena. Exactly what [Teleporter] does when it carries the player home.
@export var move_camera_to_base: bool = true

@export_group("Resupply")
## Whether setting out on a round refills every reserve the player owns to its
## capacity, and hands them a weapon that is ready to fire.
##
## [b]This is where "you leave for the arena fully stocked" lives.[/b] It happens
## once, as the world is built, so it can never be a way to top up mid-round - the
## clock is what ammunition runs out against, and nothing during a round calls
## this. It is deliberately here rather than on the button that started the round:
## every way into an arena comes through a world being built, so putting it here
## covers the ones that have not been invented yet.
##
## Off leaves the player carrying exactly what they came home with, which is what
## the game did before there was a resupply.
@export var resupply_on_run: bool = true
## Whether [i]every[/i] round is kitted out, or only the one the player sets out
## from the base on.
##
## Off, and that matters: the next round is a world being built exactly as setting
## out is, so a resupply on every build hands the player a full pouch between
## rounds - which would make the ammunition the camp sells worthless, and the
## camp's whole point is that what you spend a round with is what you brought and
## what you paid for. Which build is which is remembered by
## [method RunSessionState.take_outfit], because it cannot be read off the world.
##
## On restores the older behaviour, where a round always began full.
@export var resupply_every_round: bool = false
## The ammunition locker the reserves are filled through.
@export var locker_path: NodePath = ^"/root/Ammo"

@export_group("Run")
## The intro played as a run opens. Anything with a `play()` and a `finished`
## signal works; left unresolved the run simply starts at once, which is what the
## world did before there was an intro.
@export var intro_path: NodePath = ^"../RunHUD/RoundIntro"
## Whether the run's clock is started at all. Off leaves the arena built but
## quiet, for looking at a map without being attacked while doing it.
@export var start_run: bool = true
## Whether the world drops into slow motion for as long as the intro is on
## screen. Released the moment the card reports itself finished, which is the
## frame the round actually begins and the frame everything is back to full speed.
##
## Off leaves the intro playing over a world running at its ordinary speed. How
## *much* it slows is not here - it is [member WorldSlowdown.slow_multiplier], on
## the map's own slowdown node, next to the rest of what that map is like.
@export var slow_during_intro: bool = true

@onready var _wave_manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager
@onready var _player: Node2D = get_node_or_null(player_path) as Node2D

var _session: Node
var _started: bool = false
var _slowed: bool = false


func _ready() -> void:
	_session = get_node_or_null(session_path)
	if is_running():
		_begin_run()
	else:
		_open_in_base()


## Whether this world was built for a run. False on the very first launch, and
## any time the player is at home with no map chosen.
func is_running() -> bool:
	if _session == null or not _session.has_method(&"is_running"):
		# No session to ask - a world opened on its own, from the editor. Behaves
		# as it always did and plays.
		return true
	return _session.call(&"is_running")


## Home, and no fighting. The arena still exists behind them; it is simply not
## where they are.
func _open_in_base() -> void:
	var destination := TeleportDestination.get_by_id(self, base_destination_id)
	if destination != null and _player != null:
		_player.global_position = destination.get_spawn_position()
		# Physics interpolation is on project-wide; without this the player is
		# visibly smeared in from wherever the scene placed them.
		_player.reset_physics_interpolation()
		if move_camera_to_base:
			_clamp_camera_to(destination.get_world_bounds())

	_started = true
	world_started.emit(false)


## A run. The intro plays over a slowed arena and hands over to the clock when it
## is done, so the round begins the moment the title has blown away rather than
## while it is still on screen.
func _begin_run() -> void:
	# Deferred by one frame because the weapon does not exist yet: [WeaponMount]
	# builds it in its own `_ready`, and whether that has happened by the time this
	# runs is a question about node order in the scene rather than anything this
	# should depend on.
	_resupply.call_deferred()

	var intro := get_node_or_null(intro_path)
	if intro == null or not intro.has_method(&"play"):
		_start_waves()
		return

	# Only waited for - and therefore only slowed for - when the card can actually
	# say when it is done. An intro that cannot is played over a world at full
	# speed rather than leaving it slowed with nothing coming to release it.
	if intro.has_signal(&"finished"):
		intro.connect(&"finished", _start_waves, CONNECT_ONE_SHOT)
		_set_slowed(true)
		intro.call(&"play")
		return

	intro.call(&"play")
	_start_waves()


## Fills the pouches and closes the action, in that order - a weapon made ready
## before the resupply would fill its magazine out of the count the player came
## home with rather than the one they are leaving with.
##
## Neither half knows which weapon it is dealing with. The locker fills every
## reserve it is keeping, and the weapon is asked for the state a round should
## begin in through [method CarriedWeapon.reload_to_ready], which each weapon
## answers for itself.
func _resupply() -> void:
	if not resupply_on_run or not is_inside_tree():
		return

	# Only the pouches are gated. Making the weapon ready is not a resupply - it
	# moves rounds the player already owns out of the reserve and into the gun - so
	# it happens on every build, and a round two that skipped it would begin with an
	# empty chamber.
	var locker := get_node_or_null(locker_path) as AmmoLocker
	if locker != null and _owed_an_outfit():
		locker.refill_all()

	var mount := WeaponMount.get_active(self)
	if mount == null:
		return
	var weapon := mount.get_weapon()
	if weapon != null:
		weapon.reload_to_ready()


## Whether this world is the one that should kit the player out. Asked of the
## session and [i]taken[/i] from it, so the answer is yes exactly once per run; a
## world with no session to ask - one opened on its own in the editor - kits out as
## it always did.
func _owed_an_outfit() -> bool:
	if resupply_every_round:
		return true
	if _session == null or not _session.has_method(&"take_outfit"):
		return true
	return _session.call(&"take_outfit")


func _start_waves() -> void:
	if _started:
		return
	_started = true

	# Released before the clock is started, so the first frame of the round is a
	# frame the world is already running at full speed in.
	_set_slowed(false)

	if start_run and not _boss_takes_the_round() and _wave_manager != null:
		_wave_manager.start()
	world_started.emit(true)


## Whether the man on one of the player's posters turns out to be in this region, and
## has actually been placed.
##
## [b]It is asked before the arrival, and that order is the rule.[/b] Riding into the
## right region at the right hour on a day a contract points there is a boss day, and
## a boss day is not also an ambush: the arrival's roll is simply never acted on -
## [method RegionArrival.begin_encounter] is not called - so nothing else is waiting in
## the region and no wave follows. Being *told* he is nearby is all that happens up
## front; the fight is somewhere the player has to walk to, so this taking the round
## over does not mean the round opens in a fight. See [MiniBossDirector].
##
## The refusal matters more than the acceptance, exactly as it does for an arrival: a
## world with no boss system, a region no contract points at, a knowledge count with no
## rung authored or a spawner that refused all answer false, and the round is started
## as it always was. A boss can never be the reason a world comes up with neither a
## clock nor a fight in it.
func _boss_takes_the_round() -> bool:
	var director := MiniBossDirector.get_active(self)
	return director != null and director.begin() > 0


## The slow motion itself. Guarded on its own flag, so this can only ever release
## a slowdown it asked for.
func _set_slowed(slowed: bool) -> void:
	if not slow_during_intro or slowed == _slowed:
		return

	var slowdown := WorldSlowdown.get_active(self)
	if slowdown == null:
		return

	_slowed = slowed
	slowdown.set_slowed(slowed)


## Nothing is ever left slowed behind us: a world torn down mid-intro - a reload,
## a quit - would otherwise hand the next round a crawling player.
func _exit_tree() -> void:
	if not _slowed:
		return
	_slowed = false
	var slowdown := WorldSlowdown.get_active(self)
	if slowdown != null:
		slowdown.set_slowed(false)


## The same growing the teleporter does: a limit rectangle smaller than the
## screen is a request the camera cannot satisfy, so a small area is widened
## around its own centre rather than leaving bars down the edges.
func _clamp_camera_to(area: Rect2) -> void:
	var camera := CameraController.get_active(self)
	if camera == null:
		return

	var view := camera.get_viewport_rect().size / camera.zoom
	var box := area
	if area.size.x < view.x or area.size.y < view.y:
		var size := Vector2(maxf(area.size.x, view.x), maxf(area.size.y, view.y))
		box = Rect2(area.get_center() - size * 0.5, size)

	camera.limit_left = int(box.position.x)
	camera.limit_top = int(box.position.y)
	camera.limit_right = int(box.end.x)
	camera.limit_bottom = int(box.end.y)
	camera.reset_smoothing()
