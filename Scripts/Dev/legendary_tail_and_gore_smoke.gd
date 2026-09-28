extends SceneTree
## Headless check of two shared pieces the shotgun's Legendaries lean on:
##
##   * [method SoundBank.fade_tail] - a Legendary layer starts at its own level and
##     is taken smoothly down to silence at the end of its recording, never cut;
##     a pooled voice handed a new sound drops the old sound's fade; and every
##     Legendary audio slot - BLOOD PUMP, FAN THE HAMMER, DEVIL'S BREATH - uses it.
##   * DEVIL'S BREATH kills - a man the blast kills comes apart into the existing
##     [Explosion] gore once, a man it does not kill is only hit, several kills in
##     one volley are torn apart once each, and an ordinary pellet kill still dies
##     the ordinary way.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/legendary_tail_and_gore_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const PELLET_SCENE := "res://Scenes/Projectile/Projectile.tscn"
const CUE := "res://Sound/Generated/BloodPumpPierceCue.wav"
const FAN_LAYER := "res://Sound/Generated/FanTheHammerPump.mp3"

var _failures: int = 0
var _arena: Node2D
var _shotgun: WeaponDefinition
var _breath: WeaponLegendary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var session := root.get_node(^"RunSession") as RunSessionState
	_shotgun = session.get_weapon_catalog().find(&"shotgun")
	_shotgun.reset_upgrades()
	for legendary: WeaponLegendary in _shotgun.legendaries:
		if legendary.id == &"devils_breath":
			_breath = legendary

	await _check_fade()
	await _check_slots()
	await _check_gore()

	_shotgun.reset_upgrades()
	_finish()


# --- The fade --------------------------------------------------------------------

func _check_fade() -> void:
	print("--- the shared tail fade ---")
	var bank := SoundBank.new()
	bank.voice_count = 1
	_arena.add_child(bank)
	var stream := load(FAN_LAYER) as AudioStream
	var length := stream.get_length()
	var voice := bank.play_stream(stream, -4.0)
	bank.fade_tail(voice)
	var start := voice.volume_linear
	_ok(is_equal_approx(voice.volume_db, -4.0), "it starts at its own level", "%.1f dB" % voice.volume_db)
	var fade_from := length - minf(bank.tail_fade_seconds, length * bank.tail_fade_max_share)
	var samples: Array[Vector2] = []
	print("  time scale %.2f" % Engine.time_scale)
	var t := 0.0
	var positions: Array[float] = []
	while voice.playing or samples.is_empty():
		samples.append(Vector2(t, voice.volume_linear))
		positions.append(voice.get_playback_position() if voice.playing else -1.0)
		if t > length + 1.0:
			break
		await process_frame
		t += root.get_process_delta_time()
	var first_drop := -1.0
	for sample: Vector2 in samples:
		if first_drop < 0.0 and sample.y < start - 0.001:
			first_drop = sample.x
			print("  playback position at first drop %.2f" % positions[samples.find(sample)])
	print("  fade expected from %.2f, first drop at %.2f, %d samples, first at %.3f" % [fade_from, first_drop, samples.size(), samples[0].x])
	var held := true
	var largest_step := 0.0
	var last := start
	for sample: Vector2 in samples:
		if sample.x < fade_from - 0.05 and not is_equal_approx(sample.y, start):
			held = false
		largest_step = maxf(largest_step, last - sample.y)
		last = sample.y
	_ok(held, "the body of the sound is untouched until the tail")
	_ok(is_zero_approx(voice.volume_linear) and not voice.playing, "it ends at true silence and stops",
		"%.4f" % voice.volume_linear)
	_ok(largest_step < start * 0.25, "it gets there smoothly, never a cut",
		"largest frame step %.3f of %.3f" % [largest_step, start])
	var ended_at := samples[samples.size() - 1].x
	_ok(absf(ended_at - length) < 0.12, "and the fade ends where the recording ends",
		"%.2f s of %.2f" % [ended_at, length])

	var short := load(CUE) as AudioStream
	voice = bank.play_stream(short, 0.0)
	bank.fade_tail(voice)
	var fade_len := minf(bank.tail_fade_seconds, short.get_length() * bank.tail_fade_max_share)
	_ok(fade_len <= short.get_length() * bank.tail_fade_max_share + 0.001,
		"a short sound keeps its attack - the fade is capped to its tail", "%.2f of %.2f s" % [fade_len, short.get_length()])

	voice = bank.play_stream(short, 0.0)
	bank.fade_tail(voice, 0.05)
	var reused := bank.play_stream(stream, 0.0)
	_ok(reused == voice, "one voice: the next sound takes it over")
	await create_timer(short.get_length() + 0.2).timeout
	_ok(is_equal_approx(reused.volume_linear, 1.0) and reused.playing, "and the old sound's fade does not touch it",
		"%.3f" % reused.volume_linear)
	bank.free()


func _check_slots() -> void:
	print("--- every Legendary slot uses it ---")
	var gun := (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	gun.definition = _shotgun
	_arena.add_child(gun)
	gun.global_position = Vector2(-9000, -9000)
	await process_frame
	var bank := gun.get_node(^"Sounds") as SoundBank

	var charge := gun.get_node(^"ChargeFeedback") as PumpChargeFeedback
	charge._charge = 1
	charge._max_charge = 5
	charge._play_layer(false)
	_ok(bank._fades.size() == 1, "BLOOD PUMP's layer fades", str(bank._fades.size()))
	charge._charge = 5
	charge._play_layer(true)
	_ok(bank._fades.size() == 1 + charge.max_pitches.size() + 1, "its max layers and pierce cue fade",
		str(bank._fades.size()))
	for voice: AudioStreamPlayer in bank._voices:
		voice.stop()
	bank._fades.clear()

	var fan := gun.get_node(^"FanFeedback") as FanHammerFeedback
	fan._on_fan_pumped()
	fan._on_fanned_shot(0.5)
	_ok(bank._fades.size() == 2, "FAN THE HAMMER's pump and fire layers fade", str(bank._fades.size()))
	gun.free()

	var blast := (_breath.shot_explosion.blast_scene.instantiate()) as ShotBlast
	_arena.add_child(blast)
	blast.global_position = Vector2(-9000, 9000)
	blast.detonate(0.0, 10.0, 0.0, 0, HitEffects.new())
	var detached: AudioStreamPlayer2D = null
	for child: Node in _arena.get_children():
		if child is AudioStreamPlayer2D:
			detached = child
	_ok(detached != null, "DEVIL'S BREATH's blast is heard")
	if detached != null:
		var start := detached.volume_linear
		var last := start
		var largest_step := 0.0
		while is_instance_valid(detached):
			largest_step = maxf(largest_step, last - detached.volume_linear)
			last = detached.volume_linear
			await process_frame
		_ok(last < start * 0.1 and largest_step < start * 0.25,
			"and it fades smoothly to silence before its voice goes",
			"last %.3f of %.3f, largest step %.3f" % [last, start, largest_step])


# --- The gore --------------------------------------------------------------------

func _check_gore() -> void:
	print("--- DEVIL'S BREATH kills ---")
	var explosion := _breath.shot_explosion
	var stats := _shotgun.get_stats()
	var origin := Vector2(3000, 3000)

	var victim := await _enemy(origin, explosion.get_damage() * 0.5)
	var deaths := _count_deaths(victim)
	explosion.detonate(_arena, origin, stats, 2)
	await _frames(6)
	_ok(deaths[0] == 1, "the blast kills him once, through his own Health", str(deaths[0]))
	_ok(not is_instance_valid(victim), "and the body is taken away")
	var torn := _gore_pieces()
	_ok(torn >= 8 and torn <= 12, "he comes apart into the existing gore", "%d pieces" % torn)
	_ok(_head_pops() == 0, "and not also into the ordinary head-pop")
	_ok(_nodes(Explosion).size() == 1, "one gore effect for one man")
	await _clear()

	var tough := await _enemy(origin, explosion.get_damage() * 4.0)
	var tough_health := tough.get_node(^"Health") as Health
	explosion.detonate(_arena, origin, stats, 2)
	await _frames(6)
	_ok(tough_health.is_alive() and is_equal_approx(tough_health.get_current(), explosion.get_damage() * 3.0),
		"a man the blast does not kill is only hit", "%.1f left" % tough_health.get_current())
	_ok(_gore_pieces() == 0 and _nodes(Explosion).is_empty(), "and nothing comes apart")
	tough.free()
	await _clear()

	var men: Array[Node2D] = []
	var counts: Array = []
	for i in 3:
		var man := await _enemy(origin + Vector2(i * 14 - 14, 0), explosion.get_damage() * 0.5)
		men.append(man)
		counts.append(_count_deaths(man))
	explosion.detonate(_arena, origin, stats, 2)
	explosion.detonate(_arena, origin + Vector2(6, 0), stats, 2)
	explosion.detonate(_arena, origin - Vector2(6, 0), stats, 2)
	await _frames(6)
	var each_once := true
	for count: Array in counts:
		each_once = each_once and count[0] == 1
	_ok(each_once, "three men in one volley of three blasts each die once")
	_ok(_nodes(Explosion).size() == 3, "and each comes apart once", "%d gore effects" % _nodes(Explosion).size())
	_ok(_gore_pieces() >= 24, "all their gore thrown", str(_gore_pieces()))
	await _clear()

	print("--- an ordinary kill ---")
	var shot := await _enemy(origin, 1.0)
	var shot_deaths := _count_deaths(shot)
	var pellet := (load(PELLET_SCENE) as PackedScene).instantiate() as Projectile
	pellet.apply_weapon_stats(stats, false)
	_arena.add_child(pellet)
	pellet.global_position = origin - Vector2(60, 26)
	await _frames(20)
	_ok(shot_deaths[0] == 1, "a pellet kill still kills")
	_ok(_gore_pieces() == 0 and _nodes(Explosion).is_empty(), "with no gore")
	_ok(_head_pops() > 0, "and the ordinary head-pop", str(_head_pops()))
	if is_instance_valid(shot):
		shot.free()
	await _clear()


func _enemy(at: Vector2, health: float) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(health)
	await _frames(2)
	return enemy


func _count_deaths(enemy: Node) -> Array:
	var count := [0]
	(enemy.get_node(^"Health") as Health).died.connect(func() -> void: count[0] += 1)
	return count


func _gore_pieces() -> int:
	var found := 0
	for child: Node in _arena.get_children():
		if child is DeathDebris and child.name.begins_with("GorePiece"):
			found += 1
	return found


func _head_pops() -> int:
	var found := 0
	for child: Node in _arena.get_children():
		if child is DeathDebris and not child.name.begins_with("GorePiece"):
			found += 1
	return found


func _nodes(type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _arena.get_children():
		if is_instance_of(child, type):
			found.append(child)
	return found


func _clear() -> void:
	for child: Node in _arena.get_children():
		child.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ok(condition: bool, what: String, detail: String = "") -> void:
	if not condition:
		_failures += 1
	print("%s %s%s" % ["PASS" if condition else "FAIL", what, "" if detail.is_empty() else "  (" + detail + ")"])


func _finish() -> void:
	print("LEGENDARY TAIL AND GORE SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
