extends SceneTree
## Headless check of how a mounted World Map bandit group moves and how it
## reacts to the player: the formation through a turn, the chase and the flee,
## and the pace every group rides at.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_bandit_mounted_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on any failure, the same shape
## [code]world_bandit_navigation_smoke.gd[/code] already follows.
##
## [b]Every group but the one under test is stood down.[/b] Groups ride down a
## player they can beat now, so a player parked anywhere in the open for a
## measurement is contacted by whoever happens to be patrolling past, and the
## World Map's own encounter then freezes the map underneath the reading. The
## groups are put back afterwards.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"
const PROFILE_PATH := "res://Resources/World/Bandits/bandit_speed_profile.tres"

## The pace groups rode at before they were slowed, in pixels per second, and
## what they were slowed by. Kept here so the reduction stays a stated fact
## rather than two numbers in a resource nobody can tell the history of.
const PREVIOUS_FASTEST := 252.0
const PREVIOUS_SLOWEST := 174.0
const SPEED_REDUCTION := 0.15

## How far the player stands from a group while it decides what to do about
## them, in pixels - inside [member WorldBandit.detection_radius] and a long way
## outside [member WorldBandit.contact_radius], so the group has to see them but
## never reaches them.
const STAND_OFF := 420.0
## How far off the player is put to be got away from, in pixels - past both
## [member WorldBandit.give_up_distance] and
## [member WorldBandit.chase_break_distance].
const AWAY := 6000.0
## The longest a group is given to notice the player, and to give up on them
## again, in seconds.
const REACT_SECONDS := 3.0
const GIVE_UP_SECONDS := 20.0

var _failures: int = 0
var _map: Node
var _player: Node2D
var _groups: Array[WorldBandit] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_map = load(MAP_PATH).instantiate()
	root.add_child(_map)
	for i in 30:
		await process_frame

	_player = root.get_tree().get_first_node_in_group(&"player") as Node2D
	for node: Node in root.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit != null:
			_groups.append(bandit)

	if not _ok(_player != null and not _groups.is_empty(),
			"the map has a player and bandit groups on it"):
		_finish()
		return

	_check_speed()
	await _check_formation_turn()
	await _check_reactions()

	_finish()


func _finish() -> void:
	if _failures > 0:
		print("WORLD BANDIT MOUNTED SMOKE: %d check(s) FAILED" % _failures)
		quit(1)
		return
	print("WORLD BANDIT MOUNTED SMOKE: all checks passed")
	quit(0)


# --- Pace ---------------------------------------------------------------------

## Every mounted group rides fifteen percent slower than it used to, and the
## whole map is slowed by the one shared profile rather than group by group.
func _check_speed() -> void:
	var profile := load(PROFILE_PATH) as WorldBanditSpeedProfile
	if not _ok(profile != null, "the bandits share one speed profile"):
		return

	_near(profile.fastest_speed, PREVIOUS_FASTEST * (1.0 - SPEED_REDUCTION),
		"the quickest group rides a fifteenth off its old pace")
	_near(profile.slowest_speed, PREVIOUS_SLOWEST * (1.0 - SPEED_REDUCTION),
		"and so does the heaviest")

	var off_profile := 0
	var fastest := 0.0
	for group in _groups:
		if group.speed_profile != profile:
			off_profile += 1
		fastest = maxf(fastest, group.movement_speed)
	_ok(off_profile == 0, "every group reads its speed off it",
		"%d group(s) do not" % off_profile)
	# The player's own mounted walk - see WorldMapHorse.
	_ok(fastest <= 220.0, "which leaves no group outriding the player's own walk",
		"fastest %.0fpx/s" % fastest)


# --- The formation through a turn ---------------------------------------------

## A group swung right round keeps its riders behind it instead of slinging them
## about the leader.
##
## What is measured is the sideways half of a rider's travel - the part across
## the group's own heading, which is the whole of an orbit and none of a ride. A
## rigidly placed formation threw it at nine times the speed the group itself
## was moving.
func _check_formation_turn() -> void:
	var subject: WorldBandit = null
	for group in _groups:
		if group.get_visible_bandit_count() >= 3:
			subject = group
			break
	if not _ok(subject != null, "a group rides in a formation of three or more"):
		return

	for group in _groups:
		if group != subject:
			group.active = false
	# The corridor is not what is being measured; the walk and the formation are.
	subject.uses_navigation = false

	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	var start := subject.global_position
	_player.global_position = start + Vector2.RIGHT * AWAY
	subject.begin_ambush(_player.global_position)
	for i in 60:
		await physics_frame

	var boxes: Array[Sprite2D] = subject._formation_boxes
	var last: Array[Vector2] = []
	for box in boxes:
		last.append(box.global_position)

	# Straight back the way it came, which is the sharpest turn there is.
	_player.global_position = subject.global_position + Vector2.LEFT * AWAY
	var sideways := 0.0
	var backwards := 0.0
	for i in 240:
		await physics_frame
		var heading: Vector2 = subject._movement_heading
		for j in boxes.size():
			var here: Vector2 = boxes[j].global_position
			var travel: Vector2 = here - last[j]
			last[j] = here
			sideways = maxf(sideways, absf(travel.dot(heading.orthogonal())) / step)
			backwards = minf(backwards, travel.dot(heading) / step)

	var pace := subject.movement_speed
	_ok(sideways < pace, "no rider is swept sideways faster than the group rides",
		"%.0fpx/s across a %.0fpx/s ride" % [sideways, pace])
	_ok(backwards >= 0.0, "and none is carried backwards, so no horse turns round",
		"%.0fpx/s backwards" % backwards)

	# And the block is a block again once the turn is over.
	for i in 120:
		await physics_frame
	var spread := 0.0
	var depth := 0.0
	for box in boxes:
		spread = maxf(spread, box.position.length())
		depth = maxf(depth, -box.position.dot(subject._movement_heading))
	_ok(spread > 1.0, "the riders keep their places rather than piling onto the leader",
		"furthest rider %.0fpx out" % spread)
	_ok(depth > 1.0, "and are back behind it once the turn is done",
		"deepest rank %.0fpx" % depth)

	subject.end_ambush()
	subject.uses_navigation = true
	for group in _groups:
		group.active = true


# --- Chase and flee -----------------------------------------------------------

## What a group does about a player who rides up to it, and about one who rides
## away again - read off the groups the map actually authors rather than off a
## group built for the check.
func _check_reactions() -> void:
	var power := WorldMapPlayerPower.get_active(_map)
	if not _ok(power != null, "the map says how strong the player reads"):
		return

	var chaser: WorldBandit = null
	var runner: WorldBandit = null
	for group in _groups:
		var threat := group.threat_profile
		if threat == null:
			continue
		if chaser == null and group.group_strength >= power.player_power * threat.chase_power_ratio:
			chaser = group
		if runner == null and power.player_power >= group.group_strength * threat.flee_power_ratio:
			runner = group
	if not _ok(chaser != null and runner != null,
			"the map has a group that outmatches the player and one that does not"):
		return

	var chased := await _react(chaser)
	_ok(chased == WorldBandit.BehaviorState.CHASE,
		"a group that outmatches the player gives chase",
		"strength %.0f did %s" % [chaser.group_strength, chaser.get_state_name()])
	if chased == WorldBandit.BehaviorState.CHASE:
		var gave_up := await _escape(chaser)
		_ok(gave_up, "and gives up once the player is well away from it",
			"still %s after %.0fs" % [chaser.get_state_name(), GIVE_UP_SECONDS])

	var fled := await _react(runner)
	_ok(fled == WorldBandit.BehaviorState.FLEE,
		"a group the player outmatches runs from them",
		"strength %.0f did %s" % [runner.group_strength, runner.get_state_name()])


## Stands the player in front of [param group] until it does something about
## them, with every other group stood down so none of them can reach the player
## and open an encounter. Returns whatever the group decided, or PATROL if it
## never decided anything.
func _react(group: WorldBandit) -> WorldBandit.BehaviorState:
	for other in _groups:
		other.active = other == group
	group.behavior_state = WorldBandit.BehaviorState.PATROL

	for i in int(REACT_SECONDS * 60.0):
		# Held in front of the group rather than dropped once, so a group that
		# walks on down its route is still being looked at when it decides.
		_player.global_position = group.global_position \
			+ group._movement_heading * STAND_OFF
		await physics_frame
		if group.behavior_state != WorldBandit.BehaviorState.PATROL:
			return group.behavior_state
	return WorldBandit.BehaviorState.PATROL


## Whether [param group] stops pursuing and goes back to its route once the
## player is a long way off.
func _escape(group: WorldBandit) -> bool:
	_player.global_position = group.global_position + Vector2(AWAY, 0.0)
	for i in int(GIVE_UP_SECONDS * 60.0):
		await physics_frame
		if group.behavior_state == WorldBandit.BehaviorState.PATROL:
			return true
	return false


# --- Reporting ----------------------------------------------------------------

func _near(value: float, wanted: float, label: String) -> void:
	_ok(absf(value - wanted) <= 0.05, label, "%.2f, wanted %.2f" % [value, wanted])


func _ok(passed: bool, label: String, detail: String = "") -> bool:
	if passed:
		print("[ ok ] %s" % label)
	else:
		print("[FAIL] %s%s" % [label, "" if detail.is_empty() else "  -  " + detail])
		_failures += 1
	return passed
