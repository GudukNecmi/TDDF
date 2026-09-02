class_name WorldBountyBoss
extends Node2D
## One bounty target's physical presence on the World Map - never the combat
## fight itself, exactly as [WorldBandit] is never a crowd of combat enemies.
##
## [b]Its whole life is read off [WorldTimeManager], not simulated frame by
## frame.[/b] A bounty target's active window is the same period its poster's
## time line names, and that period lands on the same pair of degrees every
## world day - so where this node should be and what it should be doing right
## now is a pure function of the current world day and degree, recomputed on
## every tick rather than advanced through a persisted countdown. See
## [method get_state] and [method _phase]. That is what makes a missed cycle
## free: nothing here was ever marked failed, so tomorrow's occurrence of the
## same window produces the same answer with nothing to reset.
##
## [b]It travels by the same "simple route, no pathfinding" rule [WorldBandit]
## is built to[/b] - a straight line from an approach point outside the camp
## to the camp itself while arriving, and the reverse while departing. The
## approach point is derived once from this boss's own bounty id, so a given
## contract always approaches its camp from the same bearing rather than a
## fresh one being rolled every cycle.
##
## [b]Ownership.[/b] [WorldBountyBossDirector] is the only thing that builds,
## configures or frees one of these - see that class's own doc for the
## schedule this node's position and state are read out of, and for how a
## camp is chosen. This file only turns "where in the cycle are we" into a
## position and a state; it decides nothing about whether a contract exists,
## which camp it was assigned, or what happens when the player interacts
## with it - that is [WorldMapCombatBridge], reached through the director.

## The four things a bounty boss can be doing, plus the two ways an
## occurrence can end without a fight: present now, present later, fought, or
## gone.
enum State {
	## Not near the camp and not travelling to or from it - either well
	## before its next window, or shortly after a cycle it was not caught in.
	SCHEDULED,
	## Walking to the camp before the window, or walking away after it.
	TRAVELLING,
	## Standing at the camp, inside its active window, ready to be fought.
	AT_CAMP,
	## A fight against this contract is currently in progress.
	ENGAGED,
	## The contract has been closed out. Permanent for the run - see
	## [method mark_defeated].
	DEFEATED,
	## This cycle's window has come and gone with the boss never engaged.
	## Purely informational - see the class doc - and never written anywhere;
	## the same contract simply produces [constant SCHEDULED] and then
	## [constant TRAVELLING] again on its next occurrence.
	MISSED,
}

## Group every instance joins, so a debug readout can find them all without
## being wired to [WorldBountyBossDirector].
const GROUP := &"world_bounty_boss"

## The contract this presence answers. Set once by the director and never
## reassigned.
var bounty: Bounty
## [constant Bounty.CATEGORY_REGION]'s true value for [member bounty] - read
## once when the director builds this node.
var region_id: StringName = &""
## The camp this boss is assigned to for the run, or null for a contract the
## director could not find one for.
var camp: WorldMapLocation
## How many degrees before the active window this boss starts travelling in.
var arrival_lead_degrees: float = 40.0
## How many degrees the active window itself lasts.
var active_duration_degrees: float = 60.0
## How many degrees after the window ends this boss keeps travelling out
## before the cycle reads as over.
var departure_delay_degrees: float = 25.0
## How far outside the camp travelling starts and ends, in pixels.
var approach_distance: float = 1400.0
## How many degrees after departing that a never-fought cycle still reports
## [constant State.MISSED] rather than [constant State.SCHEDULED] - purely
## for a debug readout to have something to say for a moment.
var missed_grace_degrees: float = 10.0

@export var world_clock_path: NodePath = ^"/root/WorldClock"
@export var icon_path: NodePath = ^"Icon"

var _defeated: bool = false
var _engaged: bool = false
var _fog_visible: bool = true
var _cycle_length: float = 360.0
var _approach_point: Vector2 = Vector2.ZERO
## Set by the director once, before this node is placed - the absolute
## world-degree (day * cycle length + degree) [member bounty]'s active window
## next starts or last started at, wrapped into a single day's worth of
## phase by [method _phase]. See that method for how a whole-day cycle turns
## this into "how far into the cycle are we".
var period_start_degree: float = 0.0

@onready var _icon: Sprite2D = get_node_or_null(icon_path) as Sprite2D


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if _icon == null:
		_icon = Sprite2D.new()
		_icon.name = "Icon"
		_icon.texture = load("res://Assets/Maps/Desert/WorldMap/placeholder_dot.tres")
		_icon.modulate = Color(0.05, 0.02, 0.02, 1.0)
		_icon.scale = Vector2.ONE * 1.7
		_icon.z_index = -6
		add_child(_icon)

	var clock := _resolve_clock()
	if clock != null:
		_cycle_length = maxf(clock.degrees_per_day, 1.0)
	_approach_point = _compute_approach_point()
	visible = false


func _physics_process(_delta: float) -> void:
	_update_fog_visibility()

	var state := get_state()
	match state:
		State.AT_CAMP, State.ENGAGED:
			global_position = camp_position()
		State.TRAVELLING:
			_step_travel()
		_:
			pass

	visible = _fog_visible and (state == State.AT_CAMP or state == State.TRAVELLING)


# --- Identity -----------------------------------------------------------------

func get_bounty_id() -> StringName:
	return &"" if bounty == null else bounty.bounty_id


## What the poster calls him, falling back so a contract with no outlaw on
## it still produces a name to print rather than a gap.
func get_display_name(fallback: String = "THE OUTLAW") -> String:
	if bounty != null and bounty.target != null and not bounty.target.display_name.is_empty():
		return bounty.target.display_name
	return fallback


func camp_position() -> Vector2:
	if camp != null and is_instance_valid(camp):
		return camp.global_position
	return global_position


# --- State ----------------------------------------------------------------

## Where this contract's cycle stands right now. See [enum State].
func get_state() -> State:
	if _defeated:
		return State.DEFEATED
	if _engaged:
		return State.ENGAGED

	var phase := _phase()
	if phase < 0.0:
		return State.SCHEDULED
	if phase < active_duration_degrees:
		return State.AT_CAMP
	if phase < active_duration_degrees + departure_delay_degrees:
		return State.TRAVELLING

	var missed_end := active_duration_degrees + departure_delay_degrees + missed_grace_degrees
	if phase < missed_end:
		return State.MISSED
	if phase >= _cycle_length - arrival_lead_degrees:
		return State.TRAVELLING
	return State.SCHEDULED


## Whether this boss currently belongs anywhere in the world - travelling,
## standing at camp, or being fought. What [WorldBountyBossDirector] reads to
## decide whether the camp it is assigned to should read as occupied and
## whether a Blood Trail may point at it; [constant State.SCHEDULED],
## [constant State.MISSED] and [constant State.DEFEATED] all answer false.
func is_present() -> bool:
	var state := get_state()
	return state == State.AT_CAMP or state == State.TRAVELLING or state == State.ENGAGED


## The name a debug readout shows for [method get_state].
func get_state_name() -> String:
	match get_state():
		State.SCHEDULED:
			return "SCHEDULED"
		State.TRAVELLING:
			return "TRAVELLING"
		State.AT_CAMP:
			return "AT_CAMP"
		State.ENGAGED:
			return "ENGAGED"
		State.DEFEATED:
			return "DEFEATED"
		State.MISSED:
			return "MISSED"
	return "?"


## Marks a fight against this contract as in progress. Hides this node the
## same instant, the way [WorldBandit] is hidden on contact - see
## [method WorldMapCombatBridge.try_begin_boss_encounter] - and holds
## [method get_state] at [constant State.ENGAGED] regardless of the schedule
## until [method set_engaged] is told otherwise or [method mark_defeated] is
## called.
func set_engaged(value: bool) -> void:
	_engaged = value
	if value:
		visible = false


## Closes the contract out here. Permanent for the run - nothing turns this
## back off - and [method get_state] reports [constant State.DEFEATED] from
## this call onward no matter what the clock does next.
func mark_defeated() -> void:
	_defeated = true
	_engaged = false
	visible = false


# --- Moving -----------------------------------------------------------------

func _step_travel() -> void:
	var phase := _phase()
	if phase < 0.0:
		return

	if phase >= active_duration_degrees and phase < active_duration_degrees + departure_delay_degrees:
		# Departing: camp toward the approach point.
		var t := (phase - active_duration_degrees) / maxf(departure_delay_degrees, 0.001)
		global_position = camp_position().lerp(_approach_point, clampf(t, 0.0, 1.0))
	else:
		# Arriving: approach point toward camp, measured off how much of the
		# lead time is left rather than how much has passed, since this leg
		# of the phase wraps across the day boundary.
		var remaining := _cycle_length - phase
		var t := 1.0 - clampf(remaining / maxf(arrival_lead_degrees, 0.001), 0.0, 1.0)
		global_position = _approach_point.lerp(camp_position(), clampf(t, 0.0, 1.0))


## A point off in some direction from the camp, derived once from this boss's
## own contract id so the same contract always approaches from the same
## bearing rather than a fresh one every cycle - the whole of "simple route
## movement, no pathfinding" this class needs.
func _compute_approach_point() -> Vector2:
	var seed_value := absi(hash(String(get_bounty_id())))
	var angle := float(seed_value % 360) * (PI / 180.0)
	return camp_position() + Vector2.RIGHT.rotated(angle) * approach_distance


# --- Time -------------------------------------------------------------------

## How far into this contract's daily cycle the world's clock currently is,
## in degrees, measured from [member period_start_degree] and wrapped to one
## day - so 0 is the instant the active window begins and the same number
## comes back around every world day without anything here counting days
## itself. -1 when there is no clock to ask.
func _phase() -> float:
	var clock := _resolve_clock()
	if clock == null:
		return -1.0
	var absolute := float(clock.get_world_day()) * _cycle_length + clock.get_world_degree()
	return fposmod(absolute - period_start_degree, maxf(_cycle_length, 1.0))


func _resolve_clock() -> WorldTimeManager:
	return get_node_or_null(world_clock_path) as WorldTimeManager


# --- Fog ----------------------------------------------------------------

## Hides this node's art the instant it is not [WorldMapFog]'s VISIBLE state,
## or the instant a rock or canyon wall stands between it and the player even
## while it is - the same discipline [method WorldBandit._update_fog_visibility]
## follows, and the whole of rule 11's "the exact boss position must respect
## Fog of War" together with the World Map occlusion pass built beside it. A
## World Map with no fog and no [WorldMapOcclusion] in it leaves this always
## true, so nothing here gates a scene that has not added either yet.
func _update_fog_visibility() -> void:
	var fog := WorldMapFog.get_active(self)
	var fog_visible := true if fog == null else fog.get_state(global_position) == WorldMapFog.VisibilityState.VISIBLE
	if not fog_visible:
		_fog_visible = false
		return

	var occlusion := WorldMapOcclusion.get_active(self)
	_fog_visible = true if occlusion == null else occlusion.is_visible_from_player(global_position)
