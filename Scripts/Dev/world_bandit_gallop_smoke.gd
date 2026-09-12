extends SceneTree
## Headless check that World Map bandit groups gallop the way the player's own
## horse does - one voice per rider the group shows, climbing and falling
## smoothly rather than switching on and off, never louder than the player, and
## costing nothing at all while every group is out of earshot.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/world_bandit_gallop_smoke.gd
## [/codeblock]
##
## Prints a line per check and exits non-zero on the first failure, the same
## shape [code]world_bandit_navigation_smoke.gd[/code] already follows.

const MAP_PATH := "res://Scenes/World/Regions/DustCampMap.tscn"

## Far enough that no group on the map is anywhere near audible.
const AWAY := Vector2(400000.0, 400000.0)

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var map: Node = load(MAP_PATH).instantiate()
	root.add_child(map)
	await process_frame
	for i in 4:
		await physics_frame

	var director := root.get_tree().get_first_node_in_group(
		WorldBanditGallopDirector.GROUP) as WorldBanditGallopDirector
	_ok(director != null, "the World Map carries a bandit gallop director")
	if director == null:
		_finish(map)
		return
	_ok(director.stream != null, "and it has the horse gallop loop on it",
		"" if director.stream == null else "%.1fs" % director.stream.get_length())

	var player := root.get_tree().get_first_node_in_group(&"player") as Node2D
	var bandits := _bandits()
	_ok(player != null and not bandits.is_empty(), "the map has a player and bandit groups",
		"%d groups" % bandits.size())
	if player == null or bandits.is_empty() or director.stream == null:
		_finish(map)
		return

	await _check_silent_when_alone(director, player, bandits)
	await _check_voices_match_the_formation(director, player, bandits)
	await _check_it_climbs_and_falls(director, player, bandits)
	await _check_never_louder_than_the_player(director, player, bandits)
	await _check_riding_away(director, player, bandits)

	_finish(map)


## A map whose groups are all far off builds no voices at all - "do not create
## unnecessary audio players for invisible or distant groups", checked as the
## absence of the players rather than as their silence.
func _check_silent_when_alone(
		director: WorldBanditGallopDirector, player: Node2D, bandits: Array[WorldBandit]
) -> void:
	player.global_position = AWAY
	await _wait(1.5)
	_ok(director.get_voice_count() == 0, "a map with nobody in earshot builds no voices at all",
		"%d voices, %d groups on the map" % [director.get_voice_count(), bandits.size()])
	_ok(director.get_audible_group_count() == 0, "and hears no group")


## One voice per rider the group actually shows, capped - never one per person
## in its strength.
func _check_voices_match_the_formation(
		director: WorldBanditGallopDirector, player: Node2D, bandits: Array[WorldBandit]
) -> void:
	var subject := _loudest_candidate(bandits)
	_ok(subject != null, "a group was found to ride up to")
	if subject == null:
		return

	var shown := subject.get_visible_bandit_count()
	var expected := int(ceil(subject.group_strength / float(subject.people_per_box)))
	_ok(shown == expected,
		"a group shows ceil(strength / people_per_box) riders",
		"strength %.0f over %d per box is %d riders" % [
			subject.group_strength, subject.people_per_box, shown])

	await _ride_to(director, player, subject)
	var riders := _riders_for(director, subject)
	_ok(riders != null, "riding up to a group gives it voices")
	if riders == null:
		return

	var wanted := mini(shown, director.max_voices_per_group)
	_ok(riders.voices.size() == wanted,
		"and gives it one voice per visible rider, capped at max_voices_per_group",
		"%d riders shown, cap %d, %d voices" % [shown, director.max_voices_per_group,
			riders.voices.size()])

	# Every voice stands on one of the group's own riders rather than all of
	# them at the group's origin.
	var places := subject.get_visible_bandit_positions(riders.voices.size())
	var off := 0
	for v in riders.voices.size():
		if v < places.size() and riders.voices[v].global_position.distance_to(places[v]) > 1.0:
			off += 1
	_ok(off == 0, "and each voice sits on one of that group's own riders",
		"%d of %d misplaced" % [off, riders.voices.size()])

	# The whole point of the cap and the pool: a hundred-group map can never
	# build more than the ceiling, however long it runs.
	var ceiling := director.max_groups * director.max_voices_per_group
	_ok(director.get_voice_count() <= ceiling,
		"the whole map never builds more than max_groups x max_voices_per_group",
		"%d voices, ceiling %d, %d groups on the map" % [
			director.get_voice_count(), ceiling, bandits.size()])


## Starts softly and climbs rather than switching on at full, and falls away
## over the deceleration ramp rather than cutting when the group stops - the
## player's horse's own behaviour, which is the point of sharing [GallopRamp].
func _check_it_climbs_and_falls(
		director: WorldBanditGallopDirector, player: Node2D, bandits: Array[WorldBandit]
) -> void:
	var subject := _loudest_candidate(bandits)
	if subject == null:
		return

	# Out of earshot first, so the group is picked up fresh and its ramp really
	# does start from a standstill.
	player.global_position = AWAY
	await _wait(1.0)
	await _ride_to(director, player, subject)

	var early := 0.0
	var elapsed := 0.0
	var peak := 0.0
	while elapsed < director.acceleration_duration * 1.6:
		await physics_frame
		elapsed += 1.0 / 60.0
		player.global_position = subject.global_position + Vector2(600.0, 0.0)
		var riders := _riders_for(director, subject)
		var level: float = 0.0 if riders == null else riders.ramp.level()
		if early <= 0.0 and level > 0.0:
			early = level
		peak = maxf(peak, level)

	_ok(early > 0.0 and early < 0.5,
		"a group's gallop starts softly rather than at full volume",
		"first audible level %.2f" % early)
	_ok(peak > 0.9, "and climbs to a full gallop as the group gets going",
		"peak level %.2f" % peak)

	# Frozen the way the combat bridge freezes a group it has pulled into an
	# encounter, so the ground it covers really is zero and the fall is the
	# ramp's own rather than a state this test invented.
	subject.active = false
	var fell_at := -1.0
	elapsed = 0.0
	while elapsed < director.deceleration_duration * 2.0 and fell_at < 0.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		player.global_position = subject.global_position + Vector2(600.0, 0.0)
		var riders := _riders_for(director, subject)
		if riders == null or riders.ramp.level() <= director.silence_threshold:
			fell_at = elapsed
	subject.active = true

	_ok(fell_at > director.deceleration_duration * 0.4,
		"and fades out over the deceleration ramp rather than cutting off",
		"silent after %.2fs, ramp is %.2fs" % [fell_at, director.deceleration_duration])


## A whole group, however many riders it has, is mixed no louder than the
## player's own horse - the voices share the ceiling rather than each taking it.
func _check_never_louder_than_the_player(
		director: WorldBanditGallopDirector, player: Node2D, bandits: Array[WorldBandit]
) -> void:
	var horse := WorldMapHorseGallop.get_active(director)
	_ok(horse != null, "the player's own horse gallop is findable to be matched against")

	var subject := _loudest_candidate(bandits)
	if subject == null:
		return
	await _ride_to(director, player, subject)
	# Measured at a full gallop, which is where the ceiling actually applies -
	# a group still climbing its ramp is quieter for a reason that has nothing
	# to do with how loud it is allowed to get.
	var elapsed := 0.0
	while elapsed < director.acceleration_duration * 2.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		player.global_position = subject.global_position + Vector2(600.0, 0.0)
		var climbing := _riders_for(director, subject)
		if climbing != null and climbing.ramp.level() >= 0.999:
			break

	var riders := _riders_for(director, subject)
	if riders == null or riders.voices.is_empty():
		_ok(false, "the group being measured has voices")
		return

	# Uncorrelated voices add in power, so the group's own loudness is the root
	# of the summed squares of its voices - the same sum
	# _voice_ceiling_db divides the ceiling by.
	var summed := 0.0
	for voice in riders.voices:
		var amplitude := db_to_linear(voice.volume_db)
		summed += amplitude * amplitude
	var group_amplitude := sqrt(summed)
	var ceiling := db_to_linear(director.volume_db if horse == null \
		else minf(director.volume_db, horse.volume_db))

	_ok(group_amplitude <= ceiling * 1.01,
		"a whole group is never mixed louder than the player's own horse",
		"%d voices come to %.1f dB, the player's horse is %.1f dB" % [
			riders.voices.size(), linear_to_db(group_amplitude), linear_to_db(ceiling)])
	_ok(group_amplitude > ceiling * 0.5,
		"and is not quietly thrown away either",
		"%.0f%% of the ceiling" % (100.0 * group_amplitude / maxf(ceiling, 0.0001)))


## Riding away lets a group tail off and hands its voices back to be reused,
## rather than cutting it dead or leaving a player behind per group ever heard.
func _check_riding_away(
		director: WorldBanditGallopDirector, player: Node2D, bandits: Array[WorldBandit]
) -> void:
	var subject := _loudest_candidate(bandits)
	if subject == null:
		return
	await _ride_to(director, player, subject)
	var before := director.get_voice_count()
	_ok(before > 0, "a group in earshot holds voices", "%d built" % before)

	player.global_position = AWAY
	await _wait(director.deceleration_duration + 1.5)

	_ok(director.get_audible_group_count() == 0, "riding away leaves no group audible")
	var playing := 0
	for riders in director._riders:
		for voice in riders.voices:
			if voice.playing:
				playing += 1
	_ok(playing == 0, "and stops every voice it was using")
	_ok(director.get_voice_count() == before,
		"the voices are pooled and reused rather than built again per group",
		"%d before, %d after" % [before, director.get_voice_count()])


# --- Helpers ------------------------------------------------------------------


## Puts the player [param stand_off] pixels from [param subject] and waits for
## the director's own sweep to pick the group up.
##
## Waited for rather than timed: the group only becomes audible once
## [WorldMapFog] has lit the ground it is standing on - see
## [member WorldBanditGallopDirector.silent_while_fogged] - and the fog runs on
## a sweep of its own, so how long that takes after the player is put somewhere
## new is not this test's to guess at.
func _ride_to(
		director: WorldBanditGallopDirector, player: Node2D, subject: WorldBandit,
		stand_off: float = 600.0
) -> void:
	var elapsed := 0.0
	while elapsed < 5.0:
		await physics_frame
		elapsed += 1.0 / 60.0
		player.global_position = subject.global_position + Vector2(stand_off, 0.0)
		if root.get_tree().paused:
			root.get_tree().paused = false
		if _riders_for(director, subject) != null:
			return


## The [code]Riders[/code] entry the director currently holds for
## [param subject], or null while it holds none.
func _riders_for(director: WorldBanditGallopDirector, subject: WorldBandit) -> RefCounted:
	for riders in director._riders:
		if riders.bandit == subject:
			return riders
	return null


## A group big enough to show several riders, so the per-rider voice count and
## the shared ceiling both have something to say.
func _loudest_candidate(bandits: Array[WorldBandit]) -> WorldBandit:
	var best: WorldBandit = null
	for b in bandits:
		if not is_instance_valid(b) or b.get_node_or_null(b.current_route) == null:
			continue
		if best == null or b.get_visible_bandit_count() > best.get_visible_bandit_count():
			best = b
	return best


func _finish(map: Node) -> void:
	map.free()
	print("")
	if _failures == 0:
		print("WORLD BANDIT GALLOP SMOKE: all checks passed")
	else:
		print("WORLD BANDIT GALLOP SMOKE: %d check(s) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _ok(passed: bool, label: String, detail: String = "") -> void:
	if not passed:
		_failures += 1
	print("[%s] %s%s" % ["PASS" if passed else "FAIL", label,
		"" if detail.is_empty() else "  -  " + detail])


func _bandits() -> Array[WorldBandit]:
	var found: Array[WorldBandit] = []
	for node: Node in root.get_tree().get_nodes_in_group(&"world_bandit"):
		var bandit := node as WorldBandit
		if bandit != null:
			found.append(bandit)
	return found


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / 60.0
