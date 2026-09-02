class_name WorldMapLocation
extends Node2D
## One physical, discoverable point on the World Map - a bounty camp, a
## normal camp, the tavern, the market, an arena, an extraction, a blood
## depot - all drawn through this one generic node rather than one script
## per kind. Phase 3B-3A's foundation; no location's actual gameplay lives
## here. See the class doc sections below for what this does and does not
## own.
##
## [b]It answers four questions and nothing else.[/b] What location is this,
## where is it, can the player interact with it right now, and what generic
## event should fire when they do. [member location] - the same
## [MapLocation] resource Phase 3A already placed - remains the one source
## of the location's id, type, region and display name; this node only adds
## what a [i]physical[/i] presence in the world needs on top of that data: a
## reach to detect the player in, a placeholder visual, and the fog-of-war
## rules a static landmark follows. Nothing here decides what a bounty camp
## or a tavern actually does - see [signal location_interacted].
##
## [b]Migrated from [code]world_map_location_marker.gd[/code], not built
## beside it.[/b] Phase 3A's 58 markers already carried the right node
## shape - an [code]Icon[/code] [Sprite2D] and a [member location] resource -
## so becoming a generic, interactive location was this class absorbing the
## marker's own placeholder-visual job, and every existing marker node
## simply having this script attached in its place. The four Blood Depots
## Phase 3B-3A adds are built the identical way, never a second kind of node.
##
## [b]Proximity is not this node's job.[/b] Nothing here runs a per-frame
## reach test of its own; [WorldMapLocationDirector] walks every location in
## [const GROUP] on one shared timer and calls [method set_player_in_range] -
## which is what keeps sixty-some locations from becoming sixty-some
## independent per-frame checks. See the director's own class doc.
##
## [b]Fog visibility is asked, never cached.[/b] [method get_visibility_state]
## reads [WorldMapFog] directly, and this node's own visual state is
## refreshed off [signal WorldMapFog.fog_changed] - the fog's own recompute
## tick - rather than a timer of this node's own, the same discipline
## [method WorldBandit._update_fog_visibility] and [WorldMapFogOverlay]
## already follow.
##
## [b]Presentation may look at [member MapLocation.location_type]; behaviour
## never does.[/b] [const COLORS], [const SCALES] and [const ACTION_LABELS]
## are lookup tables a placeholder icon and a generic hint word are read
## from - the "icon category" and "default action label" the location
## foundation asks for - and are the only places this file ever branches on
## what kind of location it is. No system here opens a menu, starts a fight
## or spends currency; that is what [signal location_interacted] is for.

## Emitted as the player comes within [member interaction_radius] of an
## enabled, currently VISIBLE location.
signal location_entered
## Emitted as [method try_interact] succeeds. Carries nothing beyond the
## location itself - whatever this actually opens (a menu, a fight, a trade)
## is a later system's job, listening on this node rather than being told
## about from here. See the class doc.
signal location_interacted
## Emitted as the player leaves reach of a location that had been entered.
signal location_exited
## Emitted as [method set_occupied] changes this location's occupied flag -
## a bounty boss actually standing at it, or any future "something is here
## right now" case. Generic on purpose - see the class doc's
## presentation/behaviour split. Nothing in this file decides what occupies a
## location or why; a system like [WorldBountyBossDirector] is the only thing
## that ever calls [method set_occupied].
signal occupancy_changed(occupied: bool)

## Group every location joins, so [WorldMapLocationDirector] and a debug
## readout can find them all without being wired to any one of them - the
## same convention [WorldBandit] and [WorldMapRegionZone] already use.
const GROUP := &"world_map_location"

## The data this location stands for: id, type, region, world position,
## display name and whether it is enabled. The single source of all of
## those - see the class doc - never duplicated onto this node.
@export var location: MapLocation:
	set(value):
		location = value
		_apply_location()
## How close the player has to stand for this to become interactable, in
## pixels. Generic and set per instance; never hardcoded per type.
@export var interaction_radius: float = 160.0
## Only bodies in this group can interact with this location.
@export var body_group: StringName = &"player"
## Overrides [method get_action_label] when set to anything but empty. Left
## empty, the label is looked up from [member MapLocation.location_type]
## instead - see [const ACTION_LABELS]. The seam a later Tavern, Market or
## Arena system can use to say something more specific than "ENTER" without
## this class ever needing to know that system exists.
@export var action_label_override: String = ""

@export_group("Nodes")
## The placeholder art this stands in the world with. Optional.
@export var icon_path: NodePath = ^"Icon"

@export_group("The edge")
## Whether the icon is outlined while the player is in reach of it and it can
## actually be interacted with. See [SpriteOutline] - the same edge a knife
## on the ground gets.
@export var outlines_in_reach: bool = true
## The shader the edge is drawn with. Left unset, [method _ready] loads the
## project's own shared outline shader the first time one is needed, so
## sixty-some locations do not each need it authored onto them by hand.
@export var outline_shader: Shader
@export var outline_width: float = 2.0
@export var outline_color := Color(1.0, 0.85, 0.25, 1.0)

## Extra multiplier over [const SCALES], on top of whatever a location's own
## type already reads there. Added once the World Map's own exploration zoom
## pulled the camera back - see the camera framing pass - and every marker
## read smaller on screen along with everything else in world space; this is
## the single Inspector knob that gets them back to readable without a
## change to [const SCALES] itself or to any per-instance node. Left at 1,
## markers read exactly as large as [const SCALES] alone says.
@export var icon_scale: float = 1.5

@export_group("Fog dimming")
## How dim the icon reads while EXPLORED but not currently VISIBLE - the
## "remembered but not in sight" state rule 6 of the location foundation
## asks for. 1 would make no visual difference from being seen right now.
@export_range(0.0, 1.0) var explored_alpha: float = 0.55

@export_group("Occupancy")
## How much larger an occupied location's icon draws, on top of its own
## [const SCALES] entry. See [method set_occupied].
@export var occupied_scale_boost: float = 1.2

## True while the player is standing within [member interaction_radius], as
## last told by [WorldMapLocationDirector]. Read rather than polled - see
## [method set_player_in_range].
var player_in_range: bool = false
## Whether something is currently standing at this location worth calling
## out on the map - see [signal occupancy_changed]. False for every location
## nothing has ever called [method set_occupied] on.
var _occupied: bool = false

@onready var _icon: Sprite2D = get_node_or_null(icon_path) as Sprite2D

## Placeholder colour per [enum MapLocation.LocationType], purely so the map
## is readable before any of these have real art. Swapping this for final
## camp, tavern, market, arena, extraction or depot art later is a
## [member Sprite2D.texture] change on [member _icon] - never a change to
## this script or to gameplay code that reads a location, per rule 12.
const COLORS := {
	MapLocation.LocationType.BOUNTY_CAMP: Color(0.85, 0.2, 0.15),
	MapLocation.LocationType.NORMAL_CAMP: Color(0.82, 0.62, 0.22),
	MapLocation.LocationType.TAVERN: Color(0.6, 0.38, 0.85),
	MapLocation.LocationType.MARKET: Color(0.25, 0.66, 0.85),
	MapLocation.LocationType.ARENA: Color(0.85, 0.25, 0.6),
	MapLocation.LocationType.EXTRACTION: Color(0.3, 0.85, 0.45),
	MapLocation.LocationType.BLOOD_DEPOT: Color(0.55, 0.05, 0.1),
	MapLocation.LocationType.TRAVEL_PORTAL: Color(0.35, 0.75, 0.85),
}
## Placeholder scale per type, so the handful of one-off locations - the
## market, the tavern, an arena - read as more important than an ordinary
## camp.
const SCALES := {
	MapLocation.LocationType.BOUNTY_CAMP: 1.15,
	MapLocation.LocationType.NORMAL_CAMP: 0.9,
	MapLocation.LocationType.TAVERN: 1.6,
	MapLocation.LocationType.MARKET: 1.6,
	MapLocation.LocationType.ARENA: 1.8,
	MapLocation.LocationType.EXTRACTION: 1.05,
	MapLocation.LocationType.BLOOD_DEPOT: 1.3,
	MapLocation.LocationType.TRAVEL_PORTAL: 1.4,
}
## The generic action word offered for each type - presentation only, read by
## [method get_action_label]. Nothing here or downstream branches on type for
## behaviour; a later Tavern, Market or Arena system is free to say something
## more specific through [member action_label_override] on its own
## instances instead of this table ever needing a conditional.
## Colour blended into a location's own colour while [method is_occupied] is
## true, so an active bounty camp reads as different from an empty one at a
## glance without a second icon or a second node - rule 8 of the bounty
## camps phase.
const OCCUPIED_TINT := Color(1.0, 0.78, 0.15, 1.0)
const ACTION_LABELS := {
	MapLocation.LocationType.BOUNTY_CAMP: "ENTER",
	MapLocation.LocationType.NORMAL_CAMP: "ENTER",
	MapLocation.LocationType.TAVERN: "ENTER",
	MapLocation.LocationType.MARKET: "ENTER",
	MapLocation.LocationType.ARENA: "ENTER",
	MapLocation.LocationType.EXTRACTION: "EXTRACT",
	MapLocation.LocationType.BLOOD_DEPOT: "DEPOSIT BLOOD",
	MapLocation.LocationType.TRAVEL_PORTAL: "TRAVEL",
}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if outline_shader == null:
		outline_shader = load("res://Shaders/hit_flash.gdshader") as Shader
	var fog := WorldMapFog.get_active(self)
	if fog != null:
		fog.fog_changed.connect(_refresh_state)
	_apply_location()


# --- What is this, and where ------------------------------------------------

func get_location_id() -> StringName:
	return location.location_id if location != null else &""


func get_location_type() -> MapLocation.LocationType:
	return location.location_type if location != null else MapLocation.LocationType.NORMAL_CAMP


func get_region_id() -> StringName:
	return location.region_id if location != null else &""


func get_display_name() -> String:
	return location.display_name if location != null else ""


func is_enabled() -> bool:
	return location != null and location.enabled


## The generic hint word this location currently offers - "ENTER",
## "EXTRACT", whatever [const ACTION_LABELS] names for its type - or
## [member action_label_override] when one has been set on this instance.
func get_action_label() -> String:
	if action_label_override != "":
		return action_label_override
	if location == null:
		return "INTERACT"
	return ACTION_LABELS.get(location.location_type, "INTERACT")


# --- Discovery and current visibility ---------------------------------------

## This location's [enum WorldMapFog.VisibilityState] right now. A World Map
## with no [WorldMapFog] in it reports every location VISIBLE - the same
## fallback [WorldBandit] uses - so nothing here gates a scene that has not
## added fog yet.
func get_visibility_state() -> WorldMapFog.VisibilityState:
	var fog := WorldMapFog.get_active(self)
	if fog == null:
		return WorldMapFog.VisibilityState.VISIBLE
	return fog.get_state(global_position)


## Whether the player has ever seen this location - EXPLORED or VISIBLE,
## either one.
func is_discovered() -> bool:
	return get_visibility_state() != WorldMapFog.VisibilityState.UNEXPLORED


## Whether the player is currently looking at this location, as opposed to
## merely remembering it.
func is_currently_visible() -> bool:
	return get_visibility_state() == WorldMapFog.VisibilityState.VISIBLE


# --- Reach -------------------------------------------------------------------

## Whether [param body] is standing close enough to interact, ignoring fog
## and [member enabled] - the raw circle test [WorldMapLocationDirector]
## uses to pick a nearest candidate. See [method can_interact] for the full
## answer, fog and [member enabled] included.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return global_position.distance_to(body.global_position) <= interaction_radius


## Whether this can actually be interacted with right now: enabled, the
## player told they are in reach of it, and it currently VISIBLE rather than
## merely remembered. See rules 6 and 10 of the location foundation.
func can_interact() -> bool:
	return is_enabled() and player_in_range \
		and get_visibility_state() == WorldMapFog.VisibilityState.VISIBLE


## Told by [WorldMapLocationDirector], never polled - see the class doc.
## Guarded, so being told the same thing twice in a row costs nothing beyond
## the guard itself.
func set_player_in_range(value: bool) -> void:
	if value == player_in_range:
		return
	player_in_range = value
	_refresh_highlight()
	if player_in_range:
		location_entered.emit()
	else:
		location_exited.emit()


## Interacts with this location if [method can_interact] allows it right
## now. Returns whether it did. This node never knows what interacting
## means beyond emitting [signal location_interacted] - see the class doc.
func try_interact() -> bool:
	if not can_interact():
		return false
	location_interacted.emit()
	return true


# --- Occupancy -----------------------------------------------------------

func is_occupied() -> bool:
	return _occupied


## Told by whatever system currently has something standing here - never
## polled and never decided in this file, per rule 16 of the bounty camps
## phase: "do not hardcode boss behaviour into WorldMapLocation". Guarded, so
## being told the same thing twice in a row costs nothing beyond the guard,
## and redraws the icon through the same [method _refresh_state] every other
## visual change already goes through.
func set_occupied(value: bool) -> void:
	if value == _occupied:
		return
	_occupied = value
	occupancy_changed.emit(_occupied)
	_refresh_state()


# --- Visual --------------------------------------------------------------

func _apply_location() -> void:
	if location == null:
		return
	position = location.world_position
	_refresh_state()


## Redrawn on [signal WorldMapFog.fog_changed] and whenever [member location]
## is (re)assigned - never on a timer of this node's own. Hides the marker
## outright while UNEXPLORED, disabled, or occluded, shows it dimmed while
## EXPLORED but not currently seen, and at full strength while VISIBLE and
## unobstructed - see rule 6 of the location foundation. [method _refresh_highlight]
## is folded in here too, since a location that has just gone dark under the
## player's feet should drop its outline in the same beat it disappears.
##
## [b]A rock or a canyon wall hides it outright, the same as [WorldBandit]
## and [WorldBountyBoss].[/b] Fog's own VISIBLE only ever means "close enough
## and inside uncovered ground" - see [WorldMapOcclusion] - so being inside
## that radius with something solid actually standing in the way must not
## read as visible at all, not merely dimmed; a dimmed-but-still-drawn icon
## is still plainly seeable through the obstruction. [member explored_alpha]
## remains only for the unrelated case of a place the player has discovered
## before and simply is not currently looking at - Fog's own EXPLORED state,
## untouched by occlusion. [signal WorldMapFog.fog_changed] already fires
## every fog recompute whether or not the visible set actually changed,
## which is what lets this recheck occlusion on the same beat without a
## timer of this node's own.
func _refresh_state() -> void:
	if location == null or _icon == null:
		return

	var state := get_visibility_state()
	var occluded := state == WorldMapFog.VisibilityState.VISIBLE and not _occlusion_clear()
	var shown := is_enabled() and state != WorldMapFog.VisibilityState.UNEXPLORED and not occluded
	visible = shown

	if shown:
		var color: Color = COLORS.get(location.location_type, Color.WHITE)
		var s: float = SCALES.get(location.location_type, 1.0)
		if _occupied:
			color = color.lerp(OCCUPIED_TINT, 0.6)
			s *= occupied_scale_boost
		color.a = 1.0 if state == WorldMapFog.VisibilityState.VISIBLE else explored_alpha
		_icon.modulate = color
		_icon.scale = Vector2(s, s) * icon_scale

	_refresh_highlight()


## Whether nothing on [WorldMapOcclusion]'s obstruction layer stands between
## the player and this location right now. True when there is no occlusion
## system in the scene, so a World Map that has not added one draws exactly
## as it did before this existed.
func _occlusion_clear() -> bool:
	var occlusion := WorldMapOcclusion.get_active(self)
	return true if occlusion == null else occlusion.is_visible_from_player(global_position)


func _refresh_highlight() -> void:
	if not outlines_in_reach or _icon == null:
		return
	SpriteOutline.set_outlined(_icon, can_interact(), outline_shader, outline_width, outline_color)
