extends SceneTree
## Headless check of the World Map horse system - the one rig, the player's
## mount and the bandits' riders.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_map_horse_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on the first failure, the same
## shape [code]dust_camp_bandit_layout_smoke.gd[/code] already follows.

const HORSE_PATHS := {
	"MainCharacterHorse": "res://Scenes/World/Horses/MainCharacterHorse.tscn",
	"BanditHorse": "res://Scenes/World/Horses/BanditHorse.tscn",
}
const PLAYER_PATH := "res://Scenes/Player/Player.tscn"
const PART_NAMES := ["Tail", "BackLeg", "FrontLeg", "Neck", "Body", "Head"]
const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"

var _failures: int = 0


## Carries a rig across the ground at a steady speed, moving on the physics
## clock - which is the only clock anything that really carries a horse moves
## on: the player is a [CharacterBody2D] stepped in
## [method Node._physics_process], and a [WorldBandit] walks its route there too.
##
## [b]This deliberately does not move on drawn frames.[/b] A carrier that did
## would hand the rig a smooth position every single frame, which no real one
## does - and a rig that reads the travel on the wrong clock passes every check
## against a carrier like that while its gallop dies in the game. That is
## precisely the bug these checks exist to keep out, so the harness moves the way
## the game moves and nothing here is allowed to be gentler than the real thing.
class Mover extends Node2D:
	var velocity := Vector2.ZERO
	## Seconds of movement since [method restart], counted off the same ticks the
	## rig underneath is measuring on.
	var elapsed: float = 0.0

	func _physics_process(delta: float) -> void:
		position += velocity * delta
		elapsed += delta

	func restart(new_velocity: Vector2) -> void:
		velocity = new_velocity
		elapsed = 0.0


func _initialize() -> void:
	_run()


func _run() -> void:
	for name: String in HORSE_PATHS:
		await _check_horse_scene(name, HORSE_PATHS[name])
	await _check_gallop()
	await _check_timing()
	await _check_sustained_gallop()
	await _check_player_mount()
	await _check_bandit_riders()

	if _failures > 0:
		print("FAILED: %d check(s)" % _failures)
		quit(1)
		return
	print("OK")
	quit(0)


## Every horse variation is the one rig with different artwork: the same parts
## array, the same node names and a texture on each of them.
func _check_horse_scene(name: String, path: String) -> void:
	var horse := load(path).instantiate() as HorseRig
	if not _check(horse != null, "%s instantiates as a HorseRig" % name):
		return
	root.add_child(horse)
	await process_frame

	_check(horse.parts.size() == PART_NAMES.size(),
		"%s drives %d parts (got %d)" % [name, PART_NAMES.size(), horse.parts.size()])
	for part_name: String in PART_NAMES:
		var sprite := horse.get_node_or_null("Rig/%s" % part_name) as Sprite2D
		_check(sprite != null and sprite.texture != null, "%s/%s has artwork" % [name, part_name])
	for motion: HorsePartMotion in horse.parts:
		_check(motion != null and horse.get_node_or_null(motion.part_path) != null,
			"%s part_path %s resolves" % [name, "" if motion == null else motion.part_path])

	horse.queue_free()
	await process_frame


## A rig that is carried across the ground gallops, and one standing still
## settles back to standing - both read off nothing but the movement itself.
func _check_gallop() -> void:
	var carrier := Mover.new()
	root.add_child(carrier)
	var horse := load(HORSE_PATHS["MainCharacterHorse"]).instantiate() as HorseRig
	carrier.add_child(horse)
	await process_frame

	var leg := horse.get_node_or_null("Rig/FrontLeg") as Sprite2D
	var rest_rotation := leg.rotation

	# Carried left at a full gallop until the ramp has climbed, then watched.
	carrier.velocity = Vector2(-horse.run_speed, 0.0)
	for i in 120:
		await process_frame
	var swung := 0.0
	for i in 60:
		await process_frame
		swung = maxf(swung, absf(leg.rotation - rest_rotation))

	_check(swung > deg_to_rad(4.0),
		"a galloping horse swings its front leg (%.1f deg)" % rad_to_deg(swung))
	_check(horse.facing < 0.0, "a horse travelling left faces left")
	_check(horse.scale.x > 0.0, "left-facing art is not mirrored")

	# Turned round.
	carrier.velocity = Vector2(horse.run_speed, 0.0)
	for i in 30:
		await process_frame
	_check(horse.facing > 0.0, "a horse travelling right faces right")
	_check(horse.scale.x < 0.0, "right-facing art is mirrored")

	# Stood still until the ramp has fallen back.
	carrier.velocity = Vector2.ZERO
	for i in 200:
		await process_frame
	var settled := 0.0
	for i in 30:
		await process_frame
		settled = maxf(settled, absf(leg.rotation - rest_rotation))
	_check(settled < deg_to_rad(3.0),
		"a standing horse barely moves its legs (%.1f deg)" % rad_to_deg(settled))

	carrier.queue_free()
	await process_frame


## The gallop winds up to its normal rate over a second, holds a sprint at one
## and a half times that, falls back to the normal rate when the sprint is let
## go of while the horse is still moving, settles into idle within
## [member HorseRig.stop_settle_duration] of the horse stopping - out of a
## sprint as quickly as out of an ordinary gallop - and keeps turning the whole
## time.
##
## Run on the bandit's horse rather than the player's, since the two are the same
## rig with different artwork and the timing has to be identical on both - the
## checks above already prove the parts and the pose are shared.
func _check_timing() -> void:
	var carrier := Mover.new()
	root.add_child(carrier)
	var horse := load(HORSE_PATHS["BanditHorse"]).instantiate() as HorseRig
	carrier.add_child(horse)
	await process_frame

	var normal := horse.cycles_per_second_at_walk
	var sprint_rate := horse.get_sprint_cycles_per_second()
	_check(is_equal_approx(sprint_rate, normal * 1.5),
		"the sprint rate is 1.5x the normal rate (%.2f vs %.2f)" % [sprint_rate, normal * 1.5])
	_check(horse.get_cycles_per_second() == 0.0, "a horse that has not moved is not galloping")

	# Setting off: half wound up at half a second, fully wound up at one.
	carrier.restart(Vector2(-horse.walk_speed, 0.0))
	var half := await _rate_at(carrier, horse, 0.5)
	_check(half > normal * 0.3 and half < normal * 0.75,
		"half a second in, the gallop is part wound up (%.2f of %.2f)" % [half, normal])
	var full := await _rate_at(carrier, horse, 1.08)
	_check(full > normal * 0.94 and full <= normal * 1.02,
		"a second in, the gallop is at the normal rate (%.2f of %.2f)" % [full, normal])

	# Held at the normal rate, the legs really do swing that many times a second.
	var leg := horse.get_node_or_null("Rig/FrontLeg") as Sprite2D
	var rest := leg.rotation
	carrier.restart(Vector2(-horse.walk_speed, 0.0))
	var reversals := 0
	var was_forward := leg.rotation > rest
	while carrier.elapsed < 2.0:
		await process_frame
		var forward := leg.rotation > rest
		if forward != was_forward:
			reversals += 1
			was_forward = forward
	var observed := float(reversals) * 0.5 / carrier.elapsed
	_check(absf(observed - normal) < normal * 0.2,
		"the legs swing at the rate the gallop says (%.2f vs %.2f strides/s)" % [observed, normal])

	# Sprinting: the target is higher, so the same wind-up rate takes half again
	# as long to get there.
	carrier.restart(Vector2(-horse.run_speed, 0.0))
	var sprint := await _rate_at(carrier, horse, 2.2)
	_check(sprint > sprint_rate * 0.94,
		"a sprint reaches the sprint rate (%.2f of %.2f)" % [sprint, sprint_rate])

	# Letting the sprint go while still moving: back to the normal rate, and no
	# further - the horse is still running, so the gallop must not settle.
	carrier.restart(Vector2(-horse.walk_speed, 0.0))
	var eased := await _rate_at(carrier, horse, 0.7)
	_check(eased > normal * 0.94 and eased < normal * 1.06,
		"letting a sprint go returns to the normal rate (%.2f of %.2f)" % [eased, normal])
	var held := await _rate_at(carrier, horse, 2.0)
	_check(held > normal * 0.94,
		"and holds it for as long as the horse keeps moving (%.2f of %.2f)" % [held, normal])

	# Stopping out of a sprint - the longest settle there is: still turning a
	# moment later, and all the way into idle within the half second.
	carrier.restart(Vector2(-horse.run_speed, 0.0))
	await _rate_at(carrier, horse, 2.2)
	carrier.restart(Vector2.ZERO)
	var easing := await _rate_at(carrier, horse, 0.2)
	_check(easing > 0.0 and easing < sprint,
		"stopping slows the gallop rather than cutting it (%.2f)" % easing)
	var settled_rate := await _rate_at(carrier, horse, horse.stop_settle_duration + 0.15)
	_check(settled_rate <= 0.01,
		"a sprinting horse that stops is idle within %.2fs (%.2f)"
			% [horse.stop_settle_duration, settled_rate])

	# And the same half second out of an ordinary gallop - never quicker than the
	# settle, so it is a wind-down rather than a cut.
	carrier.restart(Vector2(-horse.walk_speed, 0.0))
	await _rate_at(carrier, horse, 1.5)
	carrier.restart(Vector2.ZERO)
	var mid_settle := await _rate_at(carrier, horse, horse.stop_settle_duration * 0.5)
	_check(mid_settle > 0.0,
		"halfway through the settle the stride is still turning (%.2f)" % mid_settle)
	var walk_settled := await _rate_at(carrier, horse, horse.stop_settle_duration + 0.15)
	_check(walk_settled <= 0.01,
		"an ordinary gallop settles in the same %.2fs (%.2f)"
			% [horse.stop_settle_duration, walk_settled])

	carrier.queue_free()
	await process_frame


## A horse carried on the physics clock - the way the player and every bandit
## really move - gallops for as long as it keeps moving, and never winds itself
## down partway through.
##
## [b]This is the check the render-clock carrier above cannot make.[/b] A rig
## that samples its own position once per drawn frame sees a body stepped at
## sixty hertz standing still through most of them, so it reads a stream of
## zeroes broken by spikes - and the faster the game draws, the more of the
## reading is zeroes. That is a gallop that dies while the horse is still
## running, and it only shows up when the carrier moves where a real one does.
func _check_sustained_gallop() -> void:
	var carrier := Mover.new()
	root.add_child(carrier)
	var horse := load(HORSE_PATHS["MainCharacterHorse"]).instantiate() as HorseRig
	carrier.add_child(horse)
	await physics_frame

	var normal := horse.cycles_per_second_at_walk
	carrier.restart(Vector2(-horse.walk_speed, 0.0))

	# Wound up, then held for long enough that anything decaying would have.
	while carrier.elapsed < 1.5:
		await physics_frame
	var lowest := INF
	var highest := 0.0
	while carrier.elapsed < 12.0:
		await physics_frame
		var rate := horse.get_cycles_per_second()
		lowest = minf(lowest, rate)
		highest = maxf(highest, rate)

	_check(lowest > normal * 0.9,
		"ten more seconds of movement never drops the gallop (low %.2f, high %.2f, of %.2f)"
			% [lowest, highest, normal])

	# And the stride clock is still turning at the end of it, not stuck on a pose.
	var leg := horse.get_node_or_null("Rig/FrontLeg") as Sprite2D
	var seen_min := INF
	var seen_max := -INF
	for i in 30:
		await process_frame
		seen_min = minf(seen_min, leg.rotation)
		seen_max = maxf(seen_max, leg.rotation)
	_check(rad_to_deg(seen_max - seen_min) > 4.0,
		"the legs are still swinging after twelve seconds (%.1f deg)"
			% rad_to_deg(seen_max - seen_min))

	carrier.queue_free()
	await process_frame


## The rig's stride rate once [param seconds] of the carrier's own movement have
## passed.
func _rate_at(carrier: Mover, horse: HorseRig, seconds: float) -> float:
	while carrier.elapsed < seconds:
		await process_frame
	return horse.get_cycles_per_second()


## The player carries a horse that is shown exactly while they are mounted -
## which is the World Map and nowhere else.
func _check_player_mount() -> void:
	var player: Node = load(PLAYER_PATH).instantiate()
	root.add_child(player)
	await process_frame

	var mount := player.get_node_or_null("MountedHorse") as HorseRig
	if not _check(mount != null, "the player carries a MountedHorse rig"):
		player.queue_free()
		await process_frame
		return

	var horse := player.get_node_or_null("WorldMapHorse") as WorldMapHorse
	if not _check(horse != null, "the player carries a WorldMapHorse"):
		player.queue_free()
		await process_frame
		return

	_check(not mount.visible, "the horse is hidden off the World Map")
	horse.set_mounted(true)
	_check(mount.visible, "mounting shows the horse")
	horse.set_mounted(false)
	_check(not mount.visible, "dismounting hides the horse again")

	player.queue_free()
	await process_frame


## A bandit group the player has ridden up to shows one horse per rider its
## formation is drawing, and gives them all up again once the player is gone.
func _check_bandit_riders() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	for i in 90:
		await physics_frame

	var player := map.get_tree().get_first_node_in_group(&"player") as Node2D
	var groups := map.get_tree().get_nodes_in_group(&"world_bandit")
	if not _check(player != null and not groups.is_empty(), "the map has a player and bandit groups"):
		map.queue_free()
		await physics_frame
		return

	# Nobody on this map notices or can touch the player for the length of this
	# check.
	#
	# What is being measured is horses appearing and disappearing with
	# distance, and the player has to ride right up to a group for that. But a
	# group that spots them there rides them down now, and any group at all
	# that reaches them hands the pair to [WorldMapCombatBridge], which opens an
	# encounter, pauses the game and freezes the group with its horses still on
	# it. Neither of those is what this measures, and both are checked where
	# they belong - see [code]world_bandit_mounted_smoke.gd[/code] for the
	# chase. Done before the player is driven anywhere.
	for node: Node in groups:
		node.set("detection_radius", 0.0)
		node.set("contact_radius", 0.0)

	await _check_gallop_under_real_input(player)

	var group := groups[0] as Node2D
	player.global_position = group.global_position + Vector2(200.0, 0.0)
	for i in 90:
		await physics_frame

	var riders: int = group.call(&"get_visible_bandit_count")
	var horses := _count_rigs(group)
	if not _check(horses == riders,
			"a group of %d riders shows %d horses (got %d)" % [riders, riders, horses]):
		print("    level=%s active=%s visible=%s dist=%.0f scene=%s children=%s" % [
			group.get("activation_level"), group.get("active"), group.visible,
			group.global_position.distance_to(player.global_position),
			group.get("rider_horse_scene"), str(group.get_children())])

	# Ridden away: far past the activation director's own sleep radius, so the
	# group falls dormant and gives its horses up.
	#
	# Long enough for a group that had given chase to have finished giving up
	# on it. The player was stood right in front of this group a moment ago and
	# groups ride down a player they can beat now - see
	# [member WorldBanditThreatProfile.chase_power_ratio] - and a group still
	# winding out of a chase refuses to be put to sleep, which is exactly what
	# [method WorldBandit.set_activation_level] promises. So this waits past
	# [member WorldBandit.disengage_duration] rather than expecting a group to
	# drop everything the instant the player is gone.
	player.global_position = group.global_position + Vector2(9000.0, 0.0)
	for i in 600:
		await physics_frame
	if not _check(_count_rigs(group) == 0, "a group the player has left behind keeps no horses"):
		print("    state=%s level=%s active=%s paused=%s dist=%.0f" % [
			group.call(&"get_state_name"), group.call(&"get_activation_name"),
			group.get("active"), root.get_tree().paused,
			group.global_position.distance_to(player.global_position)])

	map.queue_free()
	await physics_frame


## The whole thing end to end: a real player on the real map, mounted, moved by
## holding the game's own movement action so [code]player.gd[/code] does the
## walking - and a gallop that is still running fifteen seconds later.
##
## [b]Nothing here writes a position.[/b] That is the point: the bug this guards
## against was a rig reading its travel on the drawn frame rather than the
## physics tick, and any harness that moves a player itself, every frame, hides
## it completely.
##
## A player pressed up against the edge of the map has genuinely stopped, and a
## horse that stops with them is right to - so the stride is only held to account
## on the ticks the player actually covered ground.
func _check_gallop_under_real_input(player: Node2D) -> void:
	var horse := player.get_node_or_null("WorldMapHorse") as WorldMapHorse
	var rig := player.get_node_or_null("MountedHorse") as HorseRig
	if not _check(horse != null and rig != null, "the map's player is carrying the horse"):
		return
	horse.set_mounted(true)

	Input.action_press(&"move_left")
	var elapsed := 0.0
	var settle := 1.5
	var last := player.global_position
	var moving_ticks := 0
	var worst := INF
	while elapsed < 15.0:
		await physics_frame
		var step := root.get_physics_process_delta_time()
		elapsed += step
		var travelled := player.global_position.distance_to(last) / maxf(step, 0.0001)
		last = player.global_position
		if elapsed <= settle or travelled <= 20.0:
			continue
		moving_ticks += 1
		worst = minf(worst, rig.get_cycles_per_second())
	Input.action_release(&"move_left")

	if not _check(moving_ticks > 200, "the player really rode across the map (%d ticks)" % moving_ticks):
		return
	_check(worst > rig.cycles_per_second_at_walk * 0.9,
		"fifteen seconds of real riding never drops the gallop (worst %.2f of %.2f)"
			% [worst, rig.cycles_per_second_at_walk])


func _count_rigs(group: Node) -> int:
	var found := 0
	for child in group.get_children():
		if child is HorseRig:
			found += 1
	return found


func _check(passed: bool, label: String) -> bool:
	if passed:
		print("  ok   %s" % label)
	else:
		print("  FAIL %s" % label)
		_failures += 1
	return passed
