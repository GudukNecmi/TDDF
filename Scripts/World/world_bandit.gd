class_name WorldBandit
extends Node2D
## One symbolic bandit GROUP moving on the World Map - never a crowd of
## combat enemies.
##
## [b]This is the whole of a group, not one member of it.[/b] A World Map
## bandit is a single lightweight [Node2D]: ten men and sixty men are the
## same node with a different [member group_strength], never twenty to sixty
## separately spawned [code]enemy.gd[/code] bodies walking in formation.
## [member group_strength] is stored and read this phase and converted into
## nothing - no enemy count, no wave, no fight - that conversion is later
## phases' work, done at the point a run actually begins against this group.
##
## [b]Everything it needs is asked for, never owned.[/b] Its speed comes from
## [member speed_profile] sampling [member group_strength]; whether the
## player is a threat or prey comes from comparing [member group_strength]
## against [WorldMapPlayerPower] through [member threat_profile]'s ratios;
## its current region comes from the same [WorldMapRegionZone] rectangles
## that already tell [WorldMapState] where the player is standing. No second
## region system, no second progression system and no second obstruction
## system exist anywhere in this file.
##
## [b]Decisions are throttled by distance; movement never is.[/b]
## [method _physics_process] moves this node toward [member target_position]
## every single frame, so a group's walk always looks smooth - but
## [method _ai_tick], which is what can change [member behavior_state] and
## [member target_position], only runs as often as [method _update_interval]
## says a group this far from the player is worth reconsidering. A far-off
## group still glides along its route at full visual smoothness; it simply
## does not re-check its eyesight sixty times a second to do it.

## The five things a group can be doing. Nothing beyond movement and
## detection is implemented against any of them yet - no combat, no
## interaction prompt, no joining another group. See the class doc.
##
## [b]DISENGAGE is the visible "giving up" beat.[/b] A chase that has run past
## [member give_up_distance] does not snap straight back to
## [constant PATROL] - it spends a moment in [constant DISENGAGE] first,
## slowing down and heading back toward its own route, so giving up on the
## player reads as something happening rather than a state flipping. See
## [method _enter_disengage].
enum BehaviorState { PATROL, INVESTIGATE, CHASE, FLEE, DISENGAGE }

signal behavior_changed(state: BehaviorState)
## Emitted whenever [member region_id] changes - crossing from one
## [WorldMapRegionZone] into another, exactly the way the player's own
## crossing tells [WorldMapState] about it. Nothing currently listens; the
## seam exists for whatever later phase wants to react to a group crossing a
## border.
signal region_changed(new_region_id: StringName)

## Combat strength this group represents. Stored and compared this phase;
## turned into an actual fight - enemy count, wave count, individual
## strength, how long it lasts - only by later phases. See the class doc.
@export var group_strength: float = 20.0
## How close the player has to walk before this group counts as physically
## contacted. Read by [WorldMapCombatBridge], which watches every group in
## [constant "world_bandit"] for this distance and opens the fight - nothing
## about starting, running or ending combat lives in this file; see the
## bridge's own class doc for why.
@export var contact_radius: float = 70.0
## Maps [member group_strength] to a pixels-per-second speed. Shared between
## many bandits so retuning the curve moves every group at once; see
## [WorldBanditSpeedProfile].
@export var speed_profile: WorldBanditSpeedProfile
## The ratios this group flees or gives chase at, weighed against
## [WorldMapPlayerPower]. See [WorldBanditThreatProfile].
@export var threat_profile: WorldBanditThreatProfile
## The [WorldBanditRoute] this group patrols when it is not investigating,
## chasing or fleeing. A group with none simply holds its spawn position
## while in [constant BehaviorState.PATROL].
@export var current_route: NodePath
## How far this group can spot the player from, in pixels - the first of the
## two conditions detection needs. The second is line of sight; see
## [method _has_line_of_sight].
@export var detection_radius: float = 520.0
## How far the player has to get from a chasing group before
## [constant BehaviorState.CHASE] breaks off into [constant BehaviorState.DISENGAGE] -
## the group visibly slows and turns back toward its route, rather than
## snapping straight back to [constant BehaviorState.PATROL]. See
## [method _enter_disengage].
@export var give_up_distance: float = 900.0
## How far the player has to be, past [member give_up_distance], before a
## group already disengaging is considered fully gone and returns to
## [constant BehaviorState.PATROL]. Kept as its own, larger number rather than
## reusing [member give_up_distance] for both, so there is a real gap the
## player can see a group cross - still winding down, not yet back to an
## ordinary patrol.
@export var chase_break_distance: float = 1400.0
## The longest [constant BehaviorState.DISENGAGE] is ever allowed to run
## before resolving to [constant BehaviorState.PATROL] on its own, in
## seconds - so a group that peels off toward a route point already behind
## [member chase_break_distance] still eventually stands down instead of
## disengaging forever.
@export var disengage_duration: float = 6.0
## Physics layers a sightline can be blocked by - the World Map's own
## obstruction layers ("world" and "prop_solid"), never a second occlusion
## system of this class's own. See [method _has_line_of_sight].
@export_flags_2d_physics var vision_obstruction_mask: int = 33
## Group the player is found in, the same convention [WorldZone] and
## [WorldMapRegionZone] already read the player off.
@export var body_group: StringName = &"player"
## Whether this group does anything at all. Off freezes it exactly where it
## stands and stops every check below - the one flag a later phase can use to
## pull a group out of play (defeated, captured, not yet spawned) without
## removing the node.
@export var active: bool = true
## The [Sprite2D] scaled and tinted to hint at [member group_strength] - see
## [method _apply_visual]. Left unset, this group simply never adjusts its
## own artwork. Doubles as the formation's own leader box - box 0 - once
## [member people_per_box] gives this group more than one to show; see
## [method _rebuild_formation].
@export var icon_path: NodePath = ^"Icon"

@export_group("Formation")
## How many people one visual box stands for - "one visual red box represents
## 5 people". [method _rebuild_formation] always shows
## [code]ceil(group_strength / people_per_box)[/code] boxes: [member _icon]
## itself is the first of them, the leader, and every one past it is a plain
## trailing [Sprite2D] this class builds and frees on its own as
## [member group_strength] changes.
@export var people_per_box: int = 5
## How far back, rank to rank, one row of the formation sits behind the row in
## front of it, in pixels - see [method _update_formation_heading]. Depth
## only: two boxes in the same row never differ by this.
@export var box_spacing: float = 26.0
## How far apart, side to side, two boxes in the same row of the formation
## sit, in pixels - see [method _update_formation_heading]. What actually
## gives a group its width; [member box_spacing] alone would still be a
## single-file line.
@export var box_lateral_spacing: float = 28.0
## How many boxes wide the formation tries to be, before
## [member min_formation_width] and the group's own total box count clamp it -
## a curve in everything but name: [method _formation_width] samples
## [code]sqrt(total boxes)[/code] and scales it by this, so a formation grows
## wider only as fast as its own area does rather than in a straight line with
## its member count. Raise it for a formation that reads wide and shallow;
## lower it for one that reads narrow and deep.
@export var formation_width_factor: float = 1.3
## The narrowest a formation of two or more boxes is ever allowed to be - see
## [method _formation_width]. Below this a group would start reading as the
## single-file line this whole formation exists to avoid.
@export var min_formation_width: int = 2
## The colour a trailing box is tinted at once it is [member darkest_at_box]
## boxes back or further - blended from [member _icon]'s own colour at
## [member group_strength] the nearer a box is to the front. "Boxes farther
## behind become progressively darker/redder."
@export var rear_box_color := Color(0.3, 0.04, 0.03, 1.0)
## How many boxes back [member rear_box_color] is fully reached. Past this,
## every further box simply repeats the same darkest tint, so a
## seventy-strong group's fourteen boxes never fade out to nothing rather
## than merely getting darker.
@export var darkest_at_box: int = 6

@export_group("Update frequency")
## Groups within this many pixels of the player re-run their AI every frame.
@export var near_range: float = 900.0
## Groups within this many pixels (but past [member near_range]) re-run their
## AI a few times a second instead of every frame.
@export var medium_range: float = 2200.0
## Seconds between AI ticks for a group within [member medium_range].
@export var medium_update_interval: float = 0.25
## Seconds between AI ticks for a group past [member medium_range] entirely.
@export var far_update_interval: float = 0.75

@export_group("State Speed")
## What [member movement_speed] is multiplied by while
## [constant BehaviorState.PATROL] - a relaxed pace for ordinary roaming,
## never the group's full speed. See [method _effective_speed].
@export_range(0.0, 2.0, 0.01) var roam_speed_multiplier: float = 0.7
## What [member movement_speed] is multiplied by while
## [constant BehaviorState.INVESTIGATE] - a little brisker than an ordinary
## patrol, since the group has just lost sight of something worth a look.
@export_range(0.0, 2.0, 0.01) var investigate_speed_multiplier: float = 1.05
## What [member movement_speed] is multiplied by while
## [constant BehaviorState.DISENGAGE] - winding down out of a chase, slower
## than the chase itself but still moving with purpose back toward its route.
@export_range(0.0, 2.0, 0.01) var disengage_speed_multiplier: float = 0.65
## The slowest a group's turning is ever allowed to be, in turns per second,
## sampled at [member WorldBanditSpeedProfile.max_group_strength] - a
## sixty-strong group changing direction like something with real mass to it.
## See [method _effective_turn_rate].
@export_range(0.05, 4.0, 0.01) var min_turn_rate: float = 0.35
## The fastest a group's turning is ever allowed to be, in turns per second,
## sampled at [member WorldBanditSpeedProfile.min_group_strength] - a
## ten-strong group all but snapping onto a new heading.
@export_range(0.05, 4.0, 0.01) var max_turn_rate: float = 2.5

## The pixels-per-second this group is currently moving at - [member group_strength]
## already run through [member speed_profile]. Read rather than authored;
## recomputed in [method _ready] and whenever [member group_strength] changes
## at runtime through [method set_group_strength].
var movement_speed: float = 0.0
## The [WorldMapRegionZone.region]'s handle this group is currently standing
## in, or empty before the first AI tick has placed it. Read the same way
## [method WorldMapState.get_region_id] is.
var region_id: StringName = &""
## Index into [method WorldBanditRoute.get_points] of the waypoint this group
## is currently walking toward.
var current_route_index: int = 0
## What this group is doing right now. See [enum BehaviorState].
var behavior_state: BehaviorState = BehaviorState.PATROL
## Where [method _physics_process] is currently steering this group toward -
## the next patrol point, the player's last known position, or a point
## chosen away from them. Always in global space.
var target_position: Vector2 = Vector2.ZERO
## True exactly while [member behavior_state] is [constant BehaviorState.FLEE].
## Kept as its own flag rather than checked against [member behavior_state]
## everywhere, the same way [code]enemy.gd[/code] keeps its own
## [code]_fleeing[/code] beside its other movement flags.
var fleeing: bool = false
## True only while this group is one of a scripted World Map ambush's own
## attackers - see [WorldMapAmbushDirector] and [method begin_ambush]. Never
## set by anything in this file's own detection; a group notices the player
## and picks a side entirely on its own in [method _on_player_spotted], which
## never touches this flag. While it is true, [method _ai_tick]'s own CHASE
## branch tracks the player regardless of [member detection_radius] or line of
## sight, and never breaks off past [member chase_break_distance] - an ambush
## is a deliberate script, not something this group has to actually notice or
## keep noticing, and [WorldMapAmbushDirector] is the one authority that
## decides when the player has gotten away. See [method end_ambush].
var in_ambush: bool = false

@onready var _icon: Sprite2D = get_node_or_null(icon_path) as Sprite2D

var _route: WorldBanditRoute
var _route_direction: int = 1
var _player: Node2D
var _last_known_player_position: Vector2 = Vector2.ZERO
var _investigate_timer: float = 0.0
## Counts down while [member behavior_state] is [constant BehaviorState.DISENGAGE] -
## see [method _enter_disengage].
var _disengage_timer: float = 0.0
var _update_timer: float = 0.0
## The direction this group is actually moving in right now, kept and turned
## toward [member target_position] at [method _effective_turn_rate] rather
## than recomputed from scratch every frame - see [method _move_along_heading].
## Also what [method _update_formation_heading] trails the formation off of,
## so the boxes always line up behind wherever the group is really walking,
## never where it merely wants to.
var _movement_heading := Vector2.RIGHT
## Every trailing box past [member _icon] itself - see [method _rebuild_formation].
## Empty for a group whose whole [member group_strength] fits in the leader
## alone.
var _formation_boxes: Array[Sprite2D] = []


func _ready() -> void:
	add_to_group(&"world_bandit")
	_route = get_node_or_null(current_route) as WorldBanditRoute
	movement_speed = _compute_speed()
	_apply_visual()
	target_position = global_position
	_movement_heading = Vector2.RIGHT if _route == null or _route.get_points().is_empty() \
		else global_position.direction_to(_route_point(_nearest_route_index()))
	if _movement_heading.is_zero_approx():
		_movement_heading = Vector2.RIGHT
	_enter_patrol()
	# Ticks once immediately rather than waiting out its first interval, so a
	# group spawned near the player is not silently blind for its first
	# fraction of a second on the map.
	_ai_tick(0.0)


func _physics_process(delta: float) -> void:
	if not active:
		return

	_update_fog_visibility()

	_update_timer += delta
	var interval := _update_interval()
	if _update_timer >= interval:
		var elapsed := _update_timer
		_update_timer = 0.0
		_ai_tick(elapsed)

	_step_toward_target(delta)
	_update_formation_heading()


## Changes [member group_strength] and immediately recomputes
## [member movement_speed] to match - the one place strength is ever written
## to at runtime, so it can never drift out of step with the speed it should
## produce. Also rebuilds the visual formation - see [method _apply_visual] -
## so a group that grows or shrinks mid-run shows the right number of boxes
## from the very next frame.
func set_group_strength(strength: float) -> void:
	group_strength = maxf(strength, 0.0)
	movement_speed = _compute_speed()
	_apply_visual()


## Forces this group straight into CHASE, aimed at [param player_position],
## bypassing the ordinary sighting-and-ratio check [method _on_player_spotted]
## makes - what [WorldMapAmbushDirector] calls on each of the three groups it
## has chosen for a World Map ambush. A group already stood down - see
## [member active] - is left alone: nothing here reaches into a group that has
## been engaged, hidden or freed by [WorldMapCombatBridge].
func begin_ambush(player_position: Vector2) -> void:
	if not active:
		return
	in_ambush = true
	_last_known_player_position = player_position
	_enter_chase()


## Breaks this group off an ambush by hand, whatever it is currently doing -
## [WorldMapAmbushDirector]'s own escape distance decided the player got away,
## not this group's own [member chase_break_distance], which an ambushed
## chase ignores entirely (see [method _ai_tick]). Returns it to PATROL
## exactly the way giving up an ordinary chase already does - see
## [method _enter_patrol] - so it goes back to roaming its route rather than
## vanishing, and picks the player up again later only through its own
## ordinary detection. A group not currently ambushed is left alone.
func end_ambush() -> void:
	if not in_ambush:
		return
	_enter_patrol()


func _compute_speed() -> float:
	if speed_profile == null:
		return movement_speed
	return speed_profile.get_speed(group_strength)


## Grows and darkens [member _icon] a little with [member group_strength], so
## a sixty-strong group reads as heavier on the map than a ten-strong one at
## a glance - the "small visual indication of group strength" asked for,
## kept to exactly that: no second sprite, no per-member artwork beyond the
## formation [method _rebuild_formation] lines up behind it.
func _apply_visual() -> void:
	if _icon == null or speed_profile == null:
		return
	var span := maxf(speed_profile.max_group_strength - speed_profile.min_group_strength, 0.001)
	var t := clampf((group_strength - speed_profile.min_group_strength) / span, 0.0, 1.0)
	_icon.scale = Vector2.ONE * lerpf(0.7, 1.6, t)
	_icon.modulate = Color(0.55, 0.14, 0.08).lerp(Color(0.85, 0.05, 0.05), t)
	_rebuild_formation()


## Adds one more trailing box behind [member _icon] for every extra
## [member people_per_box] beyond the first, so the group always shows
## [code]ceil(group_strength / people_per_box)[/code] boxes in total -
## [member _icon] itself counted as the first, the leader. Only the count is
## decided here; where each box actually sits in the formation's own block is
## [method _update_formation_heading]'s. Only rebuilds when the count has
## actually changed; called on every [method _apply_visual], which is cheap to
## do since it does nothing at all the rest of the time.
##
## [b]Never a second AI.[/b] Every trailing box is a plain [Sprite2D] parented
## directly under this same [WorldBandit], sharing [member _icon]'s own
## texture. It moves, turns with the map and is hidden by fog because this one
## node already is - see [method _update_fog_visibility], which reads
## [member Node2D.visible] on this node and every child, including these -
## not because a box has any behaviour of its own.
func _rebuild_formation() -> void:
	if _icon == null:
		return
	var wanted := maxi(int(ceil(maxf(group_strength, 0.0) / maxf(float(people_per_box), 1.0))), 1) - 1
	while _formation_boxes.size() > wanted:
		var extra: Sprite2D = _formation_boxes.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	while _formation_boxes.size() < wanted:
		var box := Sprite2D.new()
		box.texture = _icon.texture
		box.rotation = _icon.rotation
		add_child(box)
		_formation_boxes.append(box)

	for i in _formation_boxes.size():
		var rank := i + 1
		var box := _formation_boxes[i]
		box.scale = _icon.scale
		var fade := 1.0 if darkest_at_box <= 0 else clampf(float(rank) / float(darkest_at_box), 0.0, 1.0)
		box.modulate = _icon.modulate.lerp(rear_box_color, fade)
	_update_formation_heading()


## Keeps every trailing box lined up in a compact block behind wherever this
## group is actually heading right now, rather than a fixed direction - read
## straight off [member target_position] and [member Node2D.global_position],
## the same pair [method _step_toward_target] is already moving this node
## along, so no second notion of "which way is this group walking" exists
## anywhere in this file. Cheap and run every physics frame; box creation and
## destruction themselves only ever happen in [method _rebuild_formation].
##
## [b]A block, never a single-file line.[/b] [member _icon] - the leader - is
## the whole of row 0 on its own, always exactly at [member Node2D.position],
## so it reads as the one member out in front. Every other box fills a grid
## behind it, [method _formation_width] boxes to a row, centred left-to-right
## on the leader's own line of travel: box 1 starts row 1, the row directly
## behind the leader, box [code]width[/code] starts row 2, and so on. A row
## widens or narrows only [member box_lateral_spacing] apart and rows sit
## [member box_spacing] apart, so a ten-strong group's own single trailing box
## rides shoulder to shoulder with the leader rather than trailing it, and a
## seventy-strong group reads as a wide, shallow block instead of a long tail.
func _update_formation_heading() -> void:
	if _formation_boxes.is_empty():
		return

	# [member _movement_heading] - the group's own actual, turn-rate-limited
	# walking direction (see [method _move_along_heading]) - rather than a
	# second, instantly-snapping direction of this method's own: the
	# formation always trails behind wherever the group is really heading,
	# not wherever it merely wants to.
	var width := _formation_width()
	var right := _movement_heading.orthogonal()
	for i in _formation_boxes.size():
		var slot := i + 1
		var row := slot / width
		var col := slot % width
		var lateral := (float(col) - float(width - 1) * 0.5) * box_lateral_spacing
		# +0.6 rather than a whole extra row keeps row 1 close enough behind
		# the leader to still read as one tight knot of riders, while still
		# leaving the leader clearly the front-most of the group.
		var depth := (float(row) - 1.0 + 0.6) * box_spacing
		_formation_boxes[i].position = _icon.position + right * lateral - _movement_heading * depth


## How many boxes wide the formation's own grid is, leader included - see the
## class doc on [method _update_formation_heading]. A curve rather than a
## ladder of size brackets: [code]sqrt(total)[/code] is how a compact block's
## own width naturally grows with its area, [member formation_width_factor]
## is the one dial that reshapes it, and the result is clamped so a two-box
## group is never asked to be wider than it has boxes to fill.
func _formation_width() -> int:
	var total := _formation_boxes.size() + 1
	if total <= 1:
		return 1
	var raw := int(round(sqrt(float(total)) * formation_width_factor))
	return clampi(raw, mini(maxi(min_formation_width, 1), total), total)


## Seconds between AI ticks for a group this far from the player right now -
## every frame up close, tapering off with distance. See the class doc.
func _update_interval() -> float:
	var player := _get_player()
	if player == null:
		return far_update_interval
	var distance := global_position.distance_to(player.global_position)
	if distance <= near_range:
		return 0.0
	if distance <= medium_range:
		return medium_update_interval
	return far_update_interval


## Reconsiders this group's behaviour. [param elapsed] is how many seconds
## actually passed since the last tick - not a fixed step, since ticks
## themselves run at whatever cadence [method _update_interval] currently
## chooses - and is only ever used to count down [member _investigate_timer]
## at the real rate time is passing, however often this happens to be called.
func _ai_tick(elapsed: float) -> void:
	_update_region()

	var player := _get_player()
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)
	var can_see := distance <= detection_radius and _has_line_of_sight(player)
	# An ambush is a deliberate script, not something this group has to spot -
	# see [member in_ambush] - so a group ordered into one keeps tracking the
	# player's live position however far off or blocked the sightline actually
	# is, for as long as it is still in CHASE.
	var chase_can_see := can_see or in_ambush

	match behavior_state:
		BehaviorState.PATROL:
			if can_see:
				_on_player_spotted(player)
		BehaviorState.INVESTIGATE:
			if can_see:
				_on_player_spotted(player)
			else:
				_investigate_timer -= elapsed
				if _investigate_timer <= 0.0:
					_enter_patrol()
		BehaviorState.CHASE:
			if chase_can_see:
				_last_known_player_position = player.global_position
				target_position = _last_known_player_position
			else:
				# Lost sight of them - go take a look at where they were last
				# seen rather than either giving up outright or steering
				# blindly at a position that is now stale. See section 16.
				_enter_investigate()
			# An ambushed group's own break-off distance is
			# [WorldMapAmbushDirector]'s to decide - see [method end_ambush] -
			# not this ordinary chase's own [member give_up_distance].
			if distance > give_up_distance and not in_ambush:
				_enter_disengage()
		BehaviorState.DISENGAGE:
			_disengage_timer -= elapsed
			if can_see and distance <= give_up_distance:
				# The player closed back in, or stepped back into sight, before
				# this group had actually finished winding down - resume
				# whatever a fresh sighting would normally decide, rather than
				# a chase it has already half broken off from.
				_on_player_spotted(player)
			elif distance > chase_break_distance or _disengage_timer <= 0.0:
				_enter_patrol()
		BehaviorState.FLEE:
			if distance > chase_break_distance:
				_enter_patrol()


## Weighs this group's strength against the player's and picks a side - flee
## or chase - the way section 12 of the design asks for: a ratio read from
## [member threat_profile], never a hardcoded branch on either strength. A
## roughly matched player commits this group to neither, which resolves back
## to [constant BehaviorState.PATROL] - a fresh sighting from patrol simply
## never becomes anything, and a sighting reacquired mid-[constant BehaviorState.INVESTIGATE]
## stands the group down rather than escalating it for free.
func _on_player_spotted(player: Node2D) -> void:
	_last_known_player_position = player.global_position

	var power := WorldMapPlayerPower.get_active(self)
	var player_power := power.player_power if power != null else 0.0
	var flee_ratio := threat_profile.flee_power_ratio if threat_profile != null else 1.6
	var chase_ratio := threat_profile.chase_power_ratio if threat_profile != null else 1.6

	if player_power >= group_strength * flee_ratio:
		_enter_flee(player.global_position)
	elif group_strength >= player_power * chase_ratio:
		_enter_chase()
	else:
		_enter_patrol()


func _enter_patrol() -> void:
	_set_state(BehaviorState.PATROL)
	fleeing = false
	in_ambush = false
	current_route_index = _nearest_route_index()
	target_position = _route_point(current_route_index)


func _enter_investigate() -> void:
	_set_state(BehaviorState.INVESTIGATE)
	fleeing = false
	target_position = _last_known_player_position
	_investigate_timer = threat_profile.investigate_duration if threat_profile != null else 4.0


func _enter_chase() -> void:
	_set_state(BehaviorState.CHASE)
	fleeing = false
	target_position = _last_known_player_position


## The visible "giving up" beat between [constant BehaviorState.CHASE] and
## [constant BehaviorState.PATROL] - see [member give_up_distance] and the
## class doc's own note on [constant BehaviorState.DISENGAGE]. Heads back
## toward the nearest point on this group's own route, at
## [member disengage_speed_multiplier], rather than the player's last known
## position: a group giving up is going home, not still hunting.
func _enter_disengage() -> void:
	_set_state(BehaviorState.DISENGAGE)
	fleeing = false
	in_ambush = false
	_disengage_timer = disengage_duration
	current_route_index = _nearest_route_index()
	target_position = _route_point(current_route_index)


## Picks a point on the opposite side of this group from the player and
## heads for it. Never teleports and never starts a fight - see the class
## doc - it is only ever a destination and the ordinary walk toward it.
func _enter_flee(player_position: Vector2) -> void:
	_set_state(BehaviorState.FLEE)
	fleeing = true
	in_ambush = false
	var away := global_position.direction_to(player_position) * -1.0
	if away.is_zero_approx():
		away = Vector2.from_angle(randf() * TAU)
	target_position = global_position + away * detection_radius * 2.0


func _set_state(state: BehaviorState) -> void:
	if state == behavior_state:
		return
	behavior_state = state
	behavior_changed.emit(state)


## One frame of walking toward [member target_position]. Runs every physics
## frame regardless of how often [method _ai_tick] itself runs, which is
## what keeps a group's movement smooth even while it is only reconsidering
## its decisions a few times a second.
func _step_toward_target(delta: float) -> void:
	if behavior_state == BehaviorState.PATROL:
		_step_patrol(delta)
		return
	_move_along_heading(target_position, delta)


func _step_patrol(delta: float) -> void:
	if _route == null or _route.get_points().is_empty():
		return
	_move_along_heading(target_position, delta)
	if global_position.distance_to(target_position) <= 4.0:
		_advance_route_index()
		target_position = _route_point(current_route_index)


## Turns [member _movement_heading] toward [param target] at
## [method _effective_turn_rate] and steps [member Node2D.global_position]
## along it at [method _effective_speed] - never straight at the target the
## way a plain [method Vector2.move_toward] would. This is section 15's own
## "large groups take longer to change direction, small groups stay mobile":
## the turn rate is sampled off [member group_strength] the same way
## [member speed_profile] already samples speed, so nothing here invents a
## second notion of how heavy a group is.
func _move_along_heading(target: Vector2, delta: float) -> void:
	var to_target := target - global_position
	var distance := to_target.length()
	var speed := _effective_speed()
	if speed <= 0.0:
		return
	if distance > 0.5:
		var desired := to_target / distance
		var max_radians := _effective_turn_rate() * TAU * delta
		var turn := clampf(_movement_heading.angle_to(desired), -max_radians, max_radians)
		_movement_heading = _movement_heading.rotated(turn).normalized()
	global_position += _movement_heading * minf(speed * delta, distance)


## [member movement_speed] - [member speed_profile] sampled at
## [member group_strength], the group's own top speed - scaled by whichever
## of the [code]"State Speed"[/code] multipliers matches [member behavior_state]
## right now. [constant BehaviorState.CHASE] and [constant BehaviorState.FLEE]
## are left at the full, unmultiplied speed - "use the existing chase speed,
## but still obey group-size speed differences" is exactly what leaving
## [member movement_speed] alone already does, since that figure is the
## group-size curve's own answer.
func _effective_speed() -> float:
	var multiplier := 1.0
	match behavior_state:
		BehaviorState.PATROL:
			multiplier = roam_speed_multiplier
		BehaviorState.INVESTIGATE:
			multiplier = investigate_speed_multiplier
		BehaviorState.DISENGAGE:
			multiplier = disengage_speed_multiplier
	return movement_speed * multiplier


## This group's turning speed right now, in turns per second - a heavier,
## larger group turns slower, the same span [member speed_profile] already
## defines for speed, so retuning one curve's endpoints does not leave the
## other out of step with it.
func _effective_turn_rate() -> float:
	if speed_profile == null:
		return max_turn_rate
	var span := maxf(speed_profile.max_group_strength - speed_profile.min_group_strength, 0.001)
	var t := clampf((group_strength - speed_profile.min_group_strength) / span, 0.0, 1.0)
	return lerpf(max_turn_rate, min_turn_rate, t)


## Moves [member current_route_index] on to the next waypoint - wrapping
## straight back to the first point for a looping route, or reversing
## direction at either end for the default there-and-back one. See
## [member WorldBanditRoute.loop].
func _advance_route_index() -> void:
	var points := _route.get_points()
	if points.size() <= 1:
		return

	if _route.loop:
		current_route_index = (current_route_index + 1) % points.size()
		return

	current_route_index += _route_direction
	if current_route_index >= points.size():
		current_route_index = points.size() - 2
		_route_direction = -1
	elif current_route_index < 0:
		current_route_index = mini(1, points.size() - 1)
		_route_direction = 1


func _route_point(index: int) -> Vector2:
	if _route == null:
		return global_position
	var points := _route.get_points()
	if points.is_empty():
		return global_position
	return points[clampi(index, 0, points.size() - 1)]


## The route point closest to where this group actually is right now, so a
## group returning to [constant BehaviorState.PATROL] resumes at whichever
## leg of its route it is nearest to instead of snapping back to wherever it
## started.
func _nearest_route_index() -> int:
	if _route == null:
		return 0
	var points := _route.get_points()
	if points.is_empty():
		return 0
	var best_index := 0
	var best_distance := INF
	for i in points.size():
		var distance := global_position.distance_to(points[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


## True only when [param target] is both within [member detection_radius] and
## not behind a blocking rock or canyon wall - the World Map's own
## "prop_solid" obstruction layer, queried through Godot's ordinary 2D
## physics rather than a second occlusion system. See [member vision_obstruction_mask].
##
## [b]Shared with the World Map's own visual occlusion.[/b] [WorldMapOcclusion]
## exists so this exact raycast is also what decides whether a location or a
## bounty boss can be [i]seen[/i], not only whether it can see the player -
## see that class's own doc. This delegates to it when one is in the scene,
## and falls back to the original inline query - unchanged - for a World Map
## that has not added one, so nothing about this class's own behaviour moved.
##
## The target's own body is excluded from the query either way. Without that,
## a ray aimed exactly at the player's [CharacterBody2D] always reports a hit -
## the player themselves, standing right where the ray ends - which every
## unobstructed sightline would otherwise be mistaken for a blocked one.
func _has_line_of_sight(target: Node2D) -> bool:
	var exclude: Array[RID] = []
	if target is CollisionObject2D:
		exclude.append((target as CollisionObject2D).get_rid())

	var occlusion := WorldMapOcclusion.get_active(self)
	if occlusion != null:
		return occlusion.has_line_of_sight(global_position, target.global_position, exclude)

	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var params := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, vision_obstruction_mask)
	if not exclude.is_empty():
		params.exclude = exclude
	var result := space.intersect_ray(params)
	return result.is_empty()


## Hides this group's art the instant it is not [WorldMapFog]'s VISIBLE
## state - EXPLORED remembers the ground but not what is moving on it,
## per Phase 3B-2 - while [method _ai_tick] and [method _step_toward_target]
## keep running underneath exactly as before. A hidden group is never
## paused, only unseen; see the class doc on [member active] for the flag
## that actually freezes one. A World Map with no [WorldMapFog] in it
## leaves every group visible, so this never gates anything for a scene
## that hasn't added fog yet.
##
## [b]A rock or a canyon wall hides it too.[/b] Being inside the fog's
## VISIBLE radius is not the same as being seeable - see [WorldMapOcclusion] -
## so a group standing behind a blocking obstruction reads exactly as it
## would if the fog itself had never revealed it, and it becomes visible
## again the instant the player walks around whatever was in the way. A
## World Map with no [WorldMapOcclusion] in it leaves this exactly as fog
## alone already decided, so this never gates anything for a scene that
## hasn't added one yet.
func _update_fog_visibility() -> void:
	var fog := WorldMapFog.get_active(self)
	var fog_visible := true if fog == null else fog.get_state(global_position) == WorldMapFog.VisibilityState.VISIBLE
	if not fog_visible:
		visible = false
		return

	var occlusion := WorldMapOcclusion.get_active(self)
	visible = true if occlusion == null else occlusion.is_visible_from_player(global_position)


## Reads this group's current region off the same [WorldMapRegionZone]
## rectangles the player's own crossing already updates [WorldMapState]
## with - never a second region system. Leaves [member region_id] at its
## last known value outside every authored zone, the same fallback
## [WorldMapState] itself uses.
func _update_region() -> void:
	for node in get_tree().get_nodes_in_group(WorldMapRegionZone.GROUP):
		var zone := node as WorldMapRegionZone
		if zone == null or zone.region == null:
			continue
		if zone.get_world_area().has_point(global_position):
			if zone.region.region_id != region_id:
				region_id = zone.region.region_id
				region_changed.emit(region_id)
			return


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(body_group) as Node2D
	return _player


## The name a debug readout shows for [member behavior_state].
func get_state_name() -> String:
	match behavior_state:
		BehaviorState.PATROL:
			return "PATROL"
		BehaviorState.INVESTIGATE:
			return "INVESTIGATE"
		BehaviorState.CHASE:
			return "CHASE"
		BehaviorState.FLEE:
			return "FLEE"
		BehaviorState.DISENGAGE:
			return "DISENGAGE"
	return "?"
