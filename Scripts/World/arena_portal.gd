class_name ArenaPortal
extends Node2D
## The way on to the next round: a pool of blood that opens in the middle of the
## arena once the run is over and everything in it is dead.
##
## It waits for two things, not one. The clock stopping is not enough - the run
## carries on into the collection phase with the arena still full of bodies going
## down - so the portal also waits for the enemies container to empty, which is
## the same "the arena is genuinely clear" test [MusicDirector] hands the
## soundtrack over on. That is why it opens as the last body disappears rather
## than the moment the countdown hits zero.
##
## It is a sibling of the arena rather than a child of anything, sitting at the
## middle of the field, so where it appears is the node's own position in the
## editor and not a number in this file.
##
## The portal decides nothing about what using it does. It reports that the
## player is close, shows them the prompt, and calls [method use] when the key
## goes down; what opens then is whatever [member menu_path] points at. That
## keeps a menu, a shop or a run-select screen interchangeable without this
## knowing which one it is talking to.
##
## [b]It is an arena portal and it only ever opens in the arena.[/b] The base and
## the arena are two places in the same scene, so a player who snapped home part
## way through a run leaves the arena empty and the clock still running - and a
## portal set to open where the player is standing would grow in the middle of the
## base. [member open_region] is the rectangle it is allowed to exist in: the
## portal waits until the player is back inside it before opening, and a portal
## opening at the player is clamped into it. See [member require_player_in_region].

## Emitted as the portal begins to open, before it has finished growing.
signal opened
## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when the player actually uses it.
signal used
## Emitted as a hold starts, runs and is let go, with how far along it is from 0
## to 1. 0 arrives whenever the hold is lost, so a readout following this can
## simply draw the number. Silent on a portal that is tapped rather than held.
signal hold_changed(progress: float)
## Emitted the moment a hold completes, just before [method use] is called.
signal hold_completed

## Group the portal joins, so anything can find it without being wired to it.
const GROUP := &"arena_portal"

## Run whose clock has to have stopped before the portal can open.
@export var wave_manager_path: NodePath = ^"../WaveManager"
## Node whose children are the live enemies. The portal waits for it to empty.
@export var enemies_path: NodePath = ^"../Enemies"
## What the portal opens. Anything with an `open()` works; unresolved, the portal
## still lights up and still reports [signal used] and simply opens nothing.
@export var menu_path: NodePath = ^"../RunHUD/UpgradeMenu"
## Only bodies in this group can use it.
@export var body_group: StringName = &"player"

@export_group("Opening")
## Opens the instant the scene starts, ignoring the run. For testing the rest of
## the loop without playing a minute of it first.
@export var open_on_ready: bool = false
## Whether the arena has to be empty as well as out of time. Off opens the portal
## on the clock alone, with the last bodies still going down.
@export var require_arena_clear: bool = true
## Beat between the arena falling quiet and the portal appearing, so the last
## death is seen to finish before the way out arrives.
@export var open_delay: float = 1.4
## Whether the portal opens where the player is standing rather than where this
## node was placed.
##
## Off - the default, and what a small arena wants - keeps the portal at the
## authored position, so where the round ends is a fixed place on the map. It is
## turned on by a map large enough that the middle of it is a long walk from
## wherever the fight actually finished: an open desert has no "middle" the player
## is ever near, and making them cross it after the last enemy is down is dead
## time rather than a journey.
##
## Only *where* it appears changes. Everything else about the portal - when it
## opens, how it grows, what using it does - is untouched, and the position is
## taken once, as it opens, so it stays put afterwards and is walked back to
## normally if the player wanders off.
@export var open_at_player: bool = false
## How far from the player it lands when [member open_at_player] is on. A little
## clear of them, so it grows beside the player rather than swallowing them the
## moment the round ends.
@export var open_at_player_offset := Vector2(0.0, -150.0)
## The only ground the portal may appear on, in world space. Normally the arena's
## own playable rectangle.
##
## Two things are measured against it, and between them they are what stops a
## round portal ever growing inside the base: the portal will not open at all
## while the player is standing outside it - see
## [member require_player_in_region] - and a portal opening at the player is
## clamped back inside it whatever happens.
##
## A rectangle with no size switches both off, which is what a world with only one
## place in it wants.
@export var open_region := Rect2(-4000.0, -2500.0, 8000.0, 5000.0)
## Whether the portal waits for the player to be inside [member open_region]
## before it opens.
##
## On. The way out of a round belongs at the end of the round, standing in the
## arena. A player who has already snapped home is not at the end of a round -
## they have left it - and the pit under their feet is how they set out again, so
## there is nothing for a portal to do there. It is left open as a field because a
## map whose collection phase happens somewhere else would want it off.
@export var require_player_in_region: bool = true
## How long the portal takes to grow to full size.
@export var open_time: float = 1.2
## Size it finally sits at. The art is authored large on purpose - this is the
## end of a round, and it has to read across a dark arena.
@export var portal_scale: float = 1.0
## How hard the artwork is driven. Above 1 on a channel brightens rather than
## tints, which is what makes the portal look lit from inside instead of painted.
@export var brightness: float = 1.4
## Energy of the light it throws across the floor. 0 leaves the portal a bright
## sprite that lights nothing.
@export var light_energy: float = 2.4

@export_group("Idle")
## How much the portal swells and settles as it sits there, as a fraction.
@export var pulse_scale: float = 0.05
## Breaths per second.
@export var pulse_speed: float = 1.3
## Turns per second of the swirl. Slow - it is a pool turning over, not a fan.
@export var swirl_speed: float = 0.22
## How much the light breathes along with the artwork, as a fraction.
@export var light_pulse: float = 0.22

@export_group("Music")
## Whether using the portal winds the soundtrack back up to full speed.
##
## Off. The wind-down at the end of a run is not a mood the portal clears - it is
## where the *next* round starts from. The music holds at
## [member MusicPlayer.run_start_pitch] through the collection phase, the
## menu and the black screen, and the new round's own tempo ramp is what picks it
## back up, climbing from there to full speed across the minute. Winding it up
## here would spend that climb before the round it belongs to had begun.
##
## Only the *speed* is ever in question either way: the track is never stopped,
## switched or restarted by the portal.
@export var restores_music_speed: bool = false

@export_group("Interaction")
## How close the player has to stand for the prompt to appear and the key to
## work, in pixels.
@export var interaction_radius: float = 170.0
## Key that uses the portal.
@export var interact_action: StringName = &"interact"

@export_group("Hold")
## How long [member interact_action] has to be held down before the portal is
## used, in seconds. [b]0 - the default - is a tap[/b], which is the blood
## portal's behaviour and is unchanged by any of this.
##
## A positive value turns the interaction into a decision rather than a keypress
## that could be an accident on the way past, which is what making camp and
## setting out on a journey both want. The hold is driven from the key's own state
## rather than from press and release events, so a key already down when the
## portal opens does nothing until it has been let go and pressed again - see
## [member _armed], which is what stops a menu re-opening under a finger still
## resting on E as it closes.
##
## What the hold *looks* like is not here. The portal reports how far along it is
## through [signal hold_changed] and [CampPrompt] draws it, for the same reason
## the tap prompt is a separate node: where a hint is drawn is the HUD's business.
@export var hold_seconds: float = 0.0
## Whether letting go part way through loses the progress. On - a hold is a hold.
## Off leaves what has been built up so far, so the player can hold it in stages.
@export var hold_resets_on_release: bool = true
## How quickly a released hold drains back to nothing, in progress per second,
## when [member hold_resets_on_release] is off.
@export var hold_decay_speed: float = 1.5

@export_group("Nodes")
## Artwork grown, pulsed and brightened. Everything visual hangs off it, so the
## portal is one thing to scale rather than three.
@export var art_path: NodePath = ^"Art"
## The turning ring. Optional.
@export var swirl_path: NodePath = ^"Art/Swirl"
## Light thrown on the floor. Optional.
@export var light_path: NodePath = ^"Light"
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"

@onready var _manager: WaveManager = get_node_or_null(wave_manager_path) as WaveManager
@onready var _enemies: Node = get_node_or_null(enemies_path)
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _swirl: Node2D = get_node_or_null(swirl_path) as Node2D
@onready var _light: PointLight2D = get_node_or_null(light_path) as PointLight2D
@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt

var _open: bool = false
var _opening: bool = false
var _seen_enemy: bool = false
var _in_reach: bool = false
var _time: float = 0.0
var _grow: float = 0.0
var _grow_tween: Tween
## How far the current hold has got, in seconds. Always 0 on a tapped portal.
var _hold: float = 0.0
## Whether the key is allowed to start a hold. Cleared the moment the portal is
## used and only set again once the key has actually been released, so a finger
## still down as a menu closes cannot immediately re-open it.
var _armed: bool = true


func _ready() -> void:
	add_to_group(GROUP)
	_apply_size()
	visible = false
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	if open_on_ready:
		open()


## The portal the rest of the scene should talk to. Null means this world has
## none, which every caller reads as "there is nowhere to go yet".
static func get_active(from_node: Node) -> ArenaPortal:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as ArenaPortal


func is_open() -> bool:
	return _open


## Whether [param body] is close enough to use the portal.
func is_in_reach(body: Node2D) -> bool:
	if not _open or body == null or not body.is_in_group(body_group):
		return false
	return global_position.distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Whether this portal is held rather than tapped.
func uses_hold() -> bool:
	return hold_seconds > 0.0


## How far the current hold has got, from 0 to 1. Always 0 on a tapped portal.
func get_hold_progress() -> float:
	if not uses_hold():
		return 0.0
	return clampf(_hold / hold_seconds, 0.0, 1.0)


func is_holding() -> bool:
	return _hold > 0.0


## Opens the portal. Safe to call directly - a debug key, a scripted round - and
## guarded, so the arena emptying and filling again cannot open it twice.
func open() -> void:
	if _open or _opening:
		return
	_opening = true

	var timer := get_tree().create_timer(maxf(open_delay, 0.0), true, false, true)
	timer.timeout.connect(_grow_open)


## Uses the portal. Ignored unless it is actually open and the player is actually
## standing at it, so nothing can be triggered across the arena.
func use() -> void:
	if not _open or not _in_reach:
		return

	# Disarmed here rather than in the hold, so however the portal was used the
	# key has to be let go before it can be used again.
	_armed = false
	_set_hold(0.0)

	used.emit()
	if _prompt != null:
		_prompt.set_prompt_visible(false)

	if restores_music_speed:
		var music := MusicDirector.get_active(self)
		if music != null:
			music.restore_pitch()

	var menu := get_node_or_null(menu_path)
	if menu != null and menu.has_method(&"open"):
		menu.call(&"open")


func _process(delta: float) -> void:
	if not _open:
		_watch_for_arena_clear()
		# A portal that has not opened cannot be part way through being held, so a
		# hold left standing by a portal closing is dropped rather than kept.
		_set_hold(0.0)
		return

	_time += delta
	_animate(delta)
	_watch_player()
	_drive_hold(delta)


## The hold, read off the key's live state rather than off its events.
##
## Polling is deliberate here where the rest of the game listens: a hold is a
## question about how long a key has been down, and answering it from press and
## release events means keeping a copy of that state and keeping it right through
## pauses, scene rebuilds and a menu opening on top. The key already knows.
func _drive_hold(delta: float) -> void:
	if not uses_hold():
		return

	if not _in_reach:
		_set_hold(0.0)
		return

	if not Input.is_action_pressed(interact_action):
		# Letting go is what re-arms the portal, which is the only way back in
		# after it has been used once.
		_armed = true
		if hold_resets_on_release:
			_set_hold(0.0)
		else:
			_set_hold(_hold - hold_decay_speed * delta)
		return

	if not _armed:
		return

	_set_hold(_hold + delta)
	if _hold >= hold_seconds:
		hold_completed.emit()
		use()


## The one place the hold is written, so it is announced exactly once however it
## moved and can never be left showing a stale fraction.
func _set_hold(value: float) -> void:
	var clamped := clampf(value, 0.0, maxf(hold_seconds, 0.0))
	if is_equal_approx(clamped, _hold):
		return
	_hold = clamped
	hold_changed.emit(get_hold_progress())


## The two conditions the portal opens on. The enemies container is watched for
## emptying rather than a kill being counted, so it is right however enemies come
## and go - and because a corpse stays in the tree while it fades, this lands when
## the last body genuinely disappears rather than when its health hit zero.
func _watch_for_arena_clear() -> void:
	if _opening:
		return

	# Counted from the first frame of the run rather than from the moment the
	# clock stops. A player who cleared the last enemy a second before the bell
	# would otherwise have the collection phase begin on an already-empty arena,
	# and the portal would sit there waiting for an enemy that is never coming.
	if _enemies != null and _enemies.get_child_count() > 0:
		_seen_enemy = true

	if _manager == null or not _manager.is_collection_phase():
		return

	# Checked every frame rather than once, so a player who wandered home and came
	# back still gets their portal - it simply does not arrive while they are
	# standing somewhere it has no business being.
	if not _is_player_on_open_ground():
		return

	if require_arena_clear:
		if _enemies == null or _enemies.get_child_count() > 0:
			return
		# An arena that has been empty since the first frame has not been cleared,
		# it was never filled - so the portal waits for something to have lived.
		if not _seen_enemy:
			return

	open()


func _grow_open() -> void:
	if not is_inside_tree() or _open:
		return

	_open = true
	_opening = false
	_move_to_player()
	visible = true
	_grow = 0.0
	_apply_size()

	if _grow_tween != null and _grow_tween.is_running():
		_grow_tween.kill()
	_grow_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_grow_tween.tween_method(_set_grow, 0.0, 1.0, maxf(open_time, 0.0001))

	opened.emit()


## Taken once, on the frame the portal opens, and never again - so it is a place
## the portal appeared at rather than something that follows the player around.
## A world with no player leaves it where it was authored.
##
## The spot is clamped into [member open_region] as a last line of defence. The
## waiting above should mean the player is already standing on open ground by the
## time this runs, but a portal opened directly - a debug key, a scripted round -
## goes through here too, and this is what guarantees that however it was asked
## for it lands in the arena.
func _move_to_player() -> void:
	if not open_at_player:
		return
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	if body == null:
		return

	global_position = _clamped_to_region(body.global_position + open_at_player_offset)
	# Physics interpolation is on project-wide; without this the portal is smeared
	# in from wherever it was standing.
	reset_physics_interpolation()


## Whether the player is standing somewhere the portal is allowed to open. True
## when there is no region to be outside of, and true when the check is switched
## off, so both are simply "the portal opens as it always did".
func _is_player_on_open_ground() -> bool:
	if not require_player_in_region or not _has_region():
		return true

	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	if body == null:
		return true
	return open_region.has_point(body.global_position)


func _clamped_to_region(point: Vector2) -> Vector2:
	if not _has_region():
		return point
	return point.clamp(open_region.position, open_region.end)


func _has_region() -> bool:
	return open_region.size.x > 0.0 and open_region.size.y > 0.0


func _set_grow(value: float) -> void:
	_grow = value
	_apply_size()


## Size, brightness and light are all read off the same growth value, so they can
## never drift apart part way through the opening.
func _apply_size() -> void:
	var breath := 1.0
	if _open:
		breath += sin(_time * pulse_speed * TAU) * pulse_scale

	if _art != null:
		_art.scale = Vector2.ONE * portal_scale * _grow * breath
		var lit := Color(brightness, brightness, brightness, 1.0)
		_art.modulate = Color.WHITE.lerp(lit, _grow)

	if _light != null:
		var pulse := 1.0 + sin(_time * pulse_speed * TAU) * light_pulse
		_light.energy = light_energy * _grow * (pulse if _open else 1.0)
		_light.enabled = _light.energy > 0.001


func _animate(delta: float) -> void:
	if _swirl != null:
		_swirl.rotation += swirl_speed * TAU * delta
	_apply_size()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame and anything else that wants to react to the player
## arriving can hang off the signals instead of repeating the distance test.
func _watch_player() -> void:
	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	if _in_reach:
		player_entered.emit()
	else:
		player_exited.emit()


## Marked handled, so the press that opens the menu cannot also reach the
## shotgun or anything else standing behind it.
##
## A held portal swallows the press without using anything: how long the key has
## been down is [method _drive_hold]'s question, and all this does is stop the tap
## reaching whatever is standing behind it.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	if not uses_hold():
		use()
	get_viewport().set_input_as_handled()
