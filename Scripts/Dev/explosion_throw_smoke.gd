extends SceneTree
## Headless check of how a real explosion kills: a man it kills has his body and
## his head thrown outwards from the blast as two separate pieces - both for a
## bomb's [Explosion] and a DEVIL'S BREATH blast - with no two men flying alike;
## a man killed by an ordinary shot still dies the ordinary way; and the bomb's
## scorch lies flat, unturned, sized off its reach and lasts 4-10 seconds by it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/explosion_throw_smoke.gd
## [/codeblock]

const EXPLOSION_SCENE := "res://Scenes/Effects/Explosion.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"

var _failures: int = 0
var _arena: Node2D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var view := CameraController.new()
	_arena.add_child(view)
	view.make_current()
	var origin := Vector2(3000, 3000)

	print("--- a bomb ---")
	var men: Array[Node2D] = []
	for offset: Vector2 in [Vector2(70, 0), Vector2(-70, 0), Vector2(0, -70), Vector2(0, 70)]:
		men.append(await _enemy(origin + offset, 1.0))
	var blast := (load(EXPLOSION_SCENE) as PackedScene).instantiate() as Explosion
	blast.blood_count = 0
	_arena.add_child(blast)
	blast.global_position = origin
	blast.play()
	await _frames(3)
	var gone := true
	for man: Node2D in men:
		gone = gone and not is_instance_valid(man)
	_ok(gone, "every man it kills is taken away")
	var bodies := _pieces("ThrownBody")
	var heads := _pieces("SeveredHead")
	_ok(bodies.size() == 4 and heads.size() == 4, "each thrown as a body and a head",
		"%d bodies, %d heads" % [bodies.size(), heads.size()])
	_ok(not _pieces("GorePiece").is_empty(), "with the gore thrown alongside")

	var right := _nearest(bodies, origin + Vector2(70, 0))
	var left := _nearest(bodies, origin + Vector2(-70, 0))
	var up := _nearest(bodies, origin + Vector2(0, -70))
	var down := _nearest(bodies, origin + Vector2(0, 70))
	_ok(right != null and right._velocity.x > 0.0 and left != null and left._velocity.x < 0.0,
		"a man to either side flies away from the blast")
	_ok(up != null and up._drift < 0.0 and down != null and down._drift > 0.0,
		"and one above or below it up or down the screen")
	var alike := false
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			alike = alike or ((bodies[i] as DeathDebris)._velocity.length()
				== (bodies[j] as DeathDebris)._velocity.length())
	_ok(not alike, "and no two fly alike")
	var split := true
	for head: Node in heads:
		var own := _nearest(bodies, (head as Node2D).global_position)
		split = split and own != null and not own._velocity.is_equal_approx((head as DeathDebris)._velocity)
	_ok(split, "the head flies apart from the body")

	var mark := blast.get_node(blast.mark_path) as Sprite2D
	var wanted := blast.get_reach() * 2.0 * blast.mark_coverage / float(mark.texture.get_width())
	_ok(mark.visible and mark.texture.resource_path.ends_with("ExplationMark.PNG")
		and is_zero_approx(mark.global_rotation)
		and absf(mark.scale.x - wanted) <= wanted * blast.mark_scale_variation + 0.0001,
		"its scorch is the mark, flat, unturned and sized off its reach", "%.3f vs %.3f" % [mark.scale.x, wanted])
	await _clear()

	print("--- the scorch by size ---")
	var small := _sized(20.0)
	var middle := _sized(100.0)
	var large := _sized(400.0)
	_ok(is_equal_approx(small[0], 4.0) and is_equal_approx(large[0], 10.0)
		and middle[0] > 4.0 and middle[0] < 10.0, "lies 4 seconds small to 10 large",
		"%.1f / %.1f / %.1f" % [small[0], middle[0], large[0]])
	_ok(small[1] < middle[1] and middle[1] < large[1], "and grows with the blast")
	await _clear()

	print("--- DEVIL'S BREATH ---")
	var victim := await _enemy(origin + Vector2(20, 0), 1.0)
	var breath := _breath()
	var shot := breath.shot_explosion.detonate(_arena, origin, null, 0xFFFFFFFF)
	await _frames(4)
	_ok(shot != null and not is_instance_valid(victim) and _pieces("ThrownBody").size() == 1
		and _pieces("SeveredHead").size() == 1, "its kill is thrown apart too")
	var flung := _pieces("ThrownBody")
	_ok(not flung.is_empty() and (flung[0] as DeathDebris)._velocity.x > 0.0, "away from the blast")
	await _clear()

	print("--- an ordinary kill ---")
	var plain := await _enemy(origin, 1.0)
	(plain.get_node(^"Health") as Health).take_damage(10.0, Vector2.RIGHT)
	await _frames(4)
	_ok(_pieces("ThrownBody").is_empty() and _pieces("SeveredHead").size() == 1,
		"still pops the head and leaves the body")
	await _clear()

	_finish()


func _breath() -> WeaponLegendary:
	var session := root.get_node(^"RunSession") as RunSessionState
	var def := session.get_weapon_catalog().find(&"shotgun")
	for legendary: WeaponLegendary in def.legendaries:
		if legendary.id == &"devils_breath":
			return legendary
	return null


## [seconds the scorch lies, its scale] for a bomb of [param reach].
func _sized(reach: float) -> Array:
	var blast := (load(EXPLOSION_SCENE) as PackedScene).instantiate() as Explosion
	blast.damage_radius = reach
	_arena.add_child(blast)
	var seconds := blast._mark_for(blast.get_reach())
	var size := (blast.get_node(blast.mark_path) as Sprite2D).scale.x
	blast.queue_free()
	return [seconds, size]


func _pieces(prefix: String) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _arena.get_children():
		if child is DeathDebris and child.name.begins_with(prefix):
			found.append(child)
	return found


func _nearest(pieces: Array[Node], at: Vector2) -> DeathDebris:
	var best: DeathDebris = null
	for node: Node in pieces:
		var piece := node as DeathDebris
		if best == null or piece.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = piece
	return best


func _enemy(at: Vector2, health: float) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(health)
	await _frames(2)
	return enemy


func _clear() -> void:
	for child: Node in _arena.get_children():
		if not child is CameraController:
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
	print("EXPLOSION THROW SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
