extends SceneTree
## Headless check of the DEVIL'S COIN Card: it is a Card in the market's pool for
## the shotgun, and no longer a shotgun Legendary; not held, a shotgun kill leaves no
## coin; held - through the RunCards autoload - it
## leaves exactly one where the man fell, and so does a kill by any round or blast
## armed from a copy of the shotgun's block - a BLOOD REAPER execution and its
## volley, a HELL CHAMBER charged shot, a DEVIL'S BREATH blast - with no case for
## any of them; a death no shot caused, a removal, or a man a pellet wounded but
## something else finished leaves none; a coin walked over pays its Inspector reward
## into the carried wallet and goes, one left alone fades and pays nothing; the coin
## never hurts anybody; and the K panel lists it.
##
## Run with:
## [codeblock]
## godot --path . --headless --script res://Scripts/Dev/devils_coin_smoke.gd
## [/codeblock]

const SHOTGUN_SCENE := "res://Scenes/Weapons/Shotgun.tscn"
const ENEMY_SCENE := "res://Scenes/Enemy/Enemy.tscn"
const MARKET_PRODUCTS := "res://Resources/RunMap/Market/market_products_roadside.tres"

var _failures: int = 0
var _arena: Node2D
var _gun: Shotgun
var _def: WeaponDefinition
var _card: RunCard
var _cards: RunCardHolder
var _wallet: BloodWallet


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var session := root.get_node(^"RunSession") as RunSessionState
	_wallet = root.get_node(^"Blood") as BloodWallet
	_def = session.get_weapon_catalog().find(&"shotgun")
	_def.reset_upgrades()

	print("--- the Card ---")
	_cards = root.get_node(^"RunCards") as RunCardHolder
	_cards.clear()
	var pool := load(MARKET_PRODUCTS) as RunMapMarketProducts
	for card: RunCard in pool.cards:
		if card != null and card.id == &"devils_coin":
			_card = card
	_ok(_card != null and _card.kill_reward is DevilsCoin and _card.unlocked,
		"the market's Card pool deals DEVIL'S COIN with a coin part")
	if _card == null:
		_finish()
		return
	_ok(_card.applies_to(_def) and _card.weapon_ids == [&"shotgun"], "for the shotgun's kills")
	_ok(_legendary(&"devils_coin") == null, "and it is no longer a shotgun Legendary")
	var part := _card.kill_reward as DevilsCoin
	_ok(is_equal_approx(part.lifetime, 2.0) and part.blood_reward > 0,
		"a 2 second coin with a reward set in the Inspector", "+%d" % part.blood_reward)

	_arena = Node2D.new()
	root.add_child(_arena)
	current_scene = _arena
	var view := CameraController.new()
	_arena.add_child(view)
	view.make_current()
	var holder := Node2D.new()
	holder.name = "Holder"
	_arena.add_child(holder)
	_gun = (load(SHOTGUN_SCENE) as PackedScene).instantiate() as Shotgun
	_gun.definition = _def
	_gun.target_path = ^"../Holder"
	_arena.add_child(_gun)
	await process_frame
	var origin := Vector2(3000, 3000)

	print("--- off ---")
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(20)
	_ok(_coins().is_empty(), "a shotgun kill leaves no coin")
	await _clear()

	_cards.add_card(_card)
	_ok(_def.get_stats().kill_rewards.has(part), "held, it reaches the shotgun's kill rewards")

	print("--- on: a pellet kill ---")
	var man := await _enemy(origin, 1.0)
	var fell := [Vector2.INF]
	(man.get_node(^"Health") as Health).died.connect(func() -> void: fell[0] = man.global_position)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	var coins := _coins()
	_ok(coins.size() == 1, "one kill, exactly one coin", "%d coins" % coins.size())
	_ok(coins.size() == 1 and coins[0].global_position.distance_to(fell[0]) < 0.5,
		"lying where he fell")
	_ok(BloodCoin.count_active(self) == coins.size(), "and counted as live")
	await _clear()

	print("--- not the shotgun's kill ---")
	var killed := await _enemy(origin, 50.0)
	(killed.get_node(^"Health") as Health).kill()
	var removed := await _enemy(origin + Vector2(200, 0), 50.0)
	(removed.get_node(^"Health") as Health).remove()
	var blown := await _enemy(origin + Vector2(400, 0), 50.0)
	(blown.get_node(^"Health") as Health).take_damage(1000.0, Vector2.RIGHT)
	await _frames(4)
	_ok(_coins().is_empty(), "a plain death, a removal and unattributed damage leave none")
	# Wounded by the shotgun, finished by something else - the killing hit decides.
	var wounded := await _enemy(origin, 1000.0)
	var wounded_health := wounded.get_node(^"Health") as Health
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	var hurt := wounded_health.get_current() < 1000.0
	wounded_health.take_damage(100000.0)
	await _frames(4)
	_ok(hurt and _coins().is_empty(), "nor a man a pellet wounded but something else finished")
	await _clear()

	print("--- other shots armed from the shotgun's block ---")
	var chamber := _legendary(&"hell_chamber")
	await _enemy(origin, 1.0)
	_shoot_at(origin, chamber.hell_chamber.charged_stats(_gun.get_stats(), 1.0))
	await _frames(12)
	_ok(_coins().size() == 1, "a charged HELL CHAMBER round's kill", "%d" % _coins().size())
	await _clear()

	var breath := _legendary(&"devils_breath")
	for i in 3:
		await _enemy(origin + Vector2(i * 30.0, 0.0), 1.0)
	breath.shot_explosion.detonate(_arena, origin, _gun.get_stats(), 2)
	await _frames(12)
	_ok(_coins().size() == 3, "a DEVIL'S BREATH blast's kills, one each", "%d" % _coins().size())
	await _clear()

	var reaper := _legendary(&"blood_reaper")
	_def.set_legendary_active(reaper, true)
	await _enemy(origin, 1.0)
	for i in 3:
		await _enemy(origin + Vector2(90.0 + i * 70.0, 0.0), 0.01)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(90)
	_ok(_coins().size() == 4, "a BLOOD REAPER execution and every kill of its chain",
		"%d coins" % _coins().size())
	_def.set_legendary_active(reaper, false)
	await _clear()

	print("--- taken ---")
	var before := _wallet.get_total()
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	var dropped := _coins()
	var player := Node2D.new()
	player.add_to_group(&"player")
	_arena.add_child(player)
	player.global_position = origin + Vector2(3000, 0)
	await _frames(4)
	_ok(dropped.size() == 1 and _wallet.get_total() == before, "out of reach it waits")
	var paid := [0]
	if dropped.size() == 1:
		(dropped[0] as BloodCoin).collected.connect(func(amount: int) -> void: paid[0] += amount)
		player.global_position = dropped[0].global_position + Vector2(20, 0)
	await _frames(4)
	_ok(_wallet.get_total() == before + part.blood_reward and paid[0] == part.blood_reward,
		"walked over, it pays its reward into the carried wallet",
		"%d -> %d" % [before, _wallet.get_total()])
	_ok(_coins().is_empty() and BloodCoin.count_active(self) == 0, "and is gone")
	var bursts := 0
	for child: Node in _arena.get_children():
		if child is CPUParticles2D and child.name.begins_with("BloodCoinBurst"):
			bursts += 1
	_ok(bursts == 1, "with its pickup burst")
	player.queue_free()
	await _clear()

	print("--- left alone ---")
	before = _wallet.get_total()
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	var left := _coins()
	var bystander := await _enemy(origin + Vector2(10, 0), 1000.0)
	var bystander_health := bystander.get_node(^"Health") as Health
	await create_timer(part.lifetime * 0.5).timeout
	_ok(left.size() == 1 and is_instance_valid(left[0]) and not (left[0] as BloodCoin).is_done(),
		"half way through its life it is still there")
	await create_timer(part.lifetime * 0.5 + 0.05).timeout
	_ok(left.size() == 1 and is_instance_valid(left[0]) and (left[0] as BloodCoin).is_done()
		and BloodCoin.count_active(self) == 0 and (left[0] as BloodCoin).modulate.a < 1.0,
		"at 2 seconds it can no longer be taken and is fading")
	await create_timer(part.fade_duration + 0.2).timeout
	_ok(not is_instance_valid(left[0]), "then it is gone")
	_ok(_wallet.get_total() == before, "having paid nothing")
	_ok(is_equal_approx(bystander_health.get_current(), 1000.0), "and never hurting the man stood on it")
	await _clear()

	print("--- off again ---")
	_cards.remove_card(_card)
	_ok(not _def.get_stats().kill_rewards.has(part), "given back, it leaves them")
	await _enemy(origin, 1.0)
	_shoot_at(origin, _gun._shot_stats())
	await _frames(12)
	_ok(_coins().is_empty(), "no new coin")
	await _clear()

	print("--- the K panel ---")
	var listed := false
	for method: Dictionary in (load("res://Scripts/UI/weapon_debug_panel.gd") as Script).get_script_method_list():
		listed = listed or method.get("name") == "_add_card_row"
	_ok(listed and not part.describe_debug(self).is_empty(), "the panel's Card row reads its coin")

	_cards.clear()
	_def.reset_upgrades()
	_finish()


func _shoot_at(at: Vector2, stats: WeaponStats) -> void:
	_gun._release_pellet(_arena, stats, false, at - Vector2(60, 26), 0.0)


func _coins() -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in _arena.get_children():
		if child is BloodCoin and not (child as BloodCoin).is_done():
			found.append(child)
	return found


func _legendary(id: StringName) -> WeaponLegendary:
	for legendary: WeaponLegendary in _def.legendaries:
		if legendary.id == id:
			return legendary
	return null


func _enemy(at: Vector2, health: float) -> Node2D:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as Node2D
	_arena.add_child(enemy)
	enemy.global_position = at
	(enemy.get_node(^"Health") as Health).set_max_health(health)
	await _frames(2)
	return enemy


func _clear() -> void:
	for child: Node in _arena.get_children():
		if child != _gun and child.name != &"Holder" and not child is CameraController:
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
	print("DEVIL'S COIN SMOKE: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
