class_name BossSwordStorm
extends Node
## The bounty boss's sword phase: every tenth of his health he loses, he spins his
## blade through a full circle for several seconds - untouchable, turning shots away
## off the circle - and then comes straight out of it in a dash, cutting three times
## a second at the player and at any of his own men in the way.
##
## [b]It is the boss's own blade and the boss's own walk.[/b] The spin is the knife
## pivot's ordinary [LookAtTarget] handed a mark that orbits him, the dash is
## [method Enemy.begin_charge] re-aimed at the player every frame, and each cut is
## [KnifeSlash] run faster - the same three things [BossCharge] borrows, and handed
## back the same way. Nothing here is a second combat system:
##
##   [codeblock]
##   what            whose
##   untouchable     Health.set_shielded, and the hitboxes off their layer (as BossDefeat does)
##   shots turned    RicochetShield - Projectile's own deflector hook
##   player hurt     Health.take_damage with a HitEffects push - HitReaction throws them
##   men torn apart  Explosion.tear_apart - the blast's own gore and gore sound
##   [/codeblock]
##
## [b]His health is what triggers it, never a clock.[/b] The pool is watched through
## [signal Health.health_changed] and a phase is owed each time it falls through the
## next step of [member health_step_fraction]. A burst that crosses two steps at once
## owes one phase, not two. A step crossed during the dash - the only part of this he
## can be hurt in - is held until the dash is over.
##
## [b]Only the circle is untouchable.[/b] The shield goes up with the spin and comes
## down with it; the dash, the charge and the ordinary fight are all hurtable.
##
## [b]It stands the charge down for its whole length[/b] - see [method BossCharge.set_held]
## - so the two attacks can never overlap, and the charge comes back a full interval
## after the dash, which is "return to the normal boss combat state".

## Emitted as the circle goes up.
signal sword_phase_started
## Emitted as the circle comes down, just before the dash.
signal sword_phase_ended
## Emitted as he comes out of the circle at the player.
signal dash_started
## Emitted once the dash is over and he is back to his ordinary fight.
signal dash_finished
## Emitted for every one of his own men his sword or his body goes through.
signal bandit_torn(enemy: Node2D)

## Group this node joins, so a test or the developer panel can find it without a path.
const GROUP := &"boss_sword_storm"

enum Step {
	## His ordinary fight.
	IDLE,
	## The circle.
	SPIN,
	## The dash out of it.
	DASH,
}

@export_group("Wiring")
## The boss system whose fight this follows; [signal MiniBossDirector.fight_started]
## is the only thing that starts it.
@export var director_path: NodePath = ^"../MiniBossDirector"
## The charge, stood down while this has the boss.
@export var charge_path: NodePath = ^"../BossCharge"
## The ending, whose [signal BossDefeat.boss_defeated] stops this at once.
@export var defeat_path: NodePath = ^"../BossDefeat"
## The player's own pool, found by group - the one every other system hurts them through.
@export var player_health_group: StringName = &"player_health"
## Group the player is found in.
@export var player_group: StringName = &"player"
## Group his men are found in. He is in it himself and is always left out.
@export var enemy_group: StringName = &"enemies"
## Whether he does any of this. Off leaves him fighting with his charge alone.
@export var enabled: bool = true

@export_group("When")
## How much of his health, as a fraction of the most he has, has to go between one
## sword phase and the next. 0.1 is "every ten percent".
@export_range(0.01, 1.0, 0.01) var health_step_fraction: float = 0.1

@export_group("The circle")
## How long the circle lasts, in seconds.
@export var spin_seconds: float = 6.0
## How many full turns the blade makes a second.
@export var spin_turns_per_second: float = 2.2
## How far the circle reaches from his sword hand, in pixels, for a man drawn at the
## enemy scene's own size. Multiplied by his scale, so a bigger rung throws a
## bigger circle.
@export var spin_radius: float = 95.0
## What his walk is multiplied by while he spins. He keeps coming at the player's
## side the whole time, so the circle is a thing to be run from, not stood beside.
@export var spin_move_multiplier: float = 0.85
## What standing in the circle costs, in hearts. The player's own grace window is
## what paces it.
@export var spin_damage: float = 1.0
## How hard the circle throws the player out of it, in pixels per second - see
## [member HitEffects.knockback_push].
@export var spin_knockback: float = 900.0
## Whether his own men caught in the circle are torn apart as well. Off by default:
## the circle is the player's danger; it is the dash that goes through his men.
@export var spin_kills_bandits: bool = false
## The picture of the circle - a ring drawn at the size it reaches. Left empty the
## circle is felt but not seen.
@export var circle_texture: Texture2D
## The colour it is drawn in. Alpha is how solid it looks at full strength.
@export var circle_color := Color(1.0, 0.18, 0.12, 0.85)
## How fast the ring picture itself turns, in turns a second, so it reads as moving
## steel rather than a painted decal.
@export var circle_turns_per_second: float = 1.4
## How long the ring takes to appear and to go, in seconds.
@export var circle_fade_time: float = 0.18
## Where the ring is drawn among the layers. Just above the arena's blood on the
## sand and below everybody standing on it, so it reads as ground that is dangerous
## rather than a shape over the fight.
@export var circle_z_index: int = -9
## How far either side of a clean reflection a ricochet is thrown, in degrees - see
## [member RicochetShield.scatter_degrees].
@export var ricochet_scatter_degrees: float = 18.0

@export_group("The dash")
## How long he dashes for, in seconds.
@export var dash_seconds: float = 2.0
## What his walk is multiplied by for the dash.
@export var dash_speed_multiplier: float = 3.2
## Cuts a second during the dash.
@export var swings_per_second: float = 3.0
## What the blade's own wind-up, strike and recovery are divided by for a dash cut,
## so each arc fits inside its third of a second. 1 leaves them as authored.
@export var swing_speed_multiplier: float = 1.3
## How far a cut reaches from his sword hand, in pixels, for a man at the enemy
## scene's own size. Multiplied by his scale.
@export var sword_reach: float = 70.0
## What a cut that reaches the player costs, in hearts.
@export var dash_damage: float = 2.0
## How hard a cut throws the player, in pixels per second.
@export var dash_knockback: float = 1100.0
## How close to his feet one of his own men has to be to be run through by the dash
## itself, in pixels, for a man at the enemy scene's own size. Multiplied by his scale.
@export var body_reach: float = 34.0
## The gore a man comes apart into. [b]The blast's own scene[/b] - its
## [method Explosion.tear_apart] is the gore and the gore sound without the
## explosion. Left empty they simply die.
@export var gore_effect: PackedScene

@export_group("The rig")
## The blade, relative to the boss.
@export var knife_slash_path: NodePath = ^"KnifeAim/KnifeSlash"
## The pivot that aims it, relative to the boss. The circle is centred on it.
@export var aim_pivot_path: NodePath = ^"KnifeAim"
## The hitbox layer shots look for - the circle is put on it and the boss taken off
## it while he spins. 2 is the project's hitbox layer.
@export_flags_2d_physics var hitbox_layer: int = 2

var _director: MiniBossDirector
var _charge: BossCharge
var _defeat: BossDefeat
var _boss: Node2D
var _boss_health: Health
var _running: bool = false
var _step: Step = Step.IDLE
var _timer: float = 0.0
## The health that owes the next phase once he falls to it.
var _next_threshold: float = 0.0
## A step crossed during the dash, waiting for it to end.
var _owed: bool = false
var _spin_angle: float = 0.0
var _swing_timer: float = 0.0
## The mark the pivot is aimed at while the blade spins. Built once and reused.
var _aim_mark: Node2D
var _aim_rest: Node2D
var _swing_rest: Dictionary = {}
## Hitbox layers as they were before the circle went up, keyed by the region.
var _layers: Dictionary = {}
var _shield: RicochetShield
var _shield_shape: CircleShape2D
var _ring: Sprite2D
var _ring_tween: Tween
var _slash: KnifeSlash


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	set_physics_process(false)
	var director := _resolve_director()
	if director != null and not director.fight_started.is_connected(_on_fight_started):
		director.fight_started.connect(_on_fight_started)


## The sword storm in this world, or null when it has none.
static func get_active(from_node: Node) -> BossSwordStorm:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BossSwordStorm


func is_running() -> bool:
	return _running


func get_step() -> Step:
	return _step


## Whether the circle is up - the one time he cannot be hurt.
func is_spinning() -> bool:
	return _step == Step.SPIN


func is_dashing() -> bool:
	return _step == Step.DASH


## The health he has to fall to for the next phase to be owed.
func get_next_threshold() -> float:
	return _next_threshold


## How far the circle reaches right now, in pixels.
func get_spin_radius() -> float:
	return maxf(spin_radius, 0.0) * _boss_scale()


## Puts the circle up now, whatever his health says - the real phase, started by
## hand, for a smoke check or the developer panel. False when there is no fight or
## he is already in one.
func start_now() -> bool:
	if not _running or _step != Step.IDLE or not _has_boss():
		return false
	_begin_spin()
	return true


## Calls off whatever is in the air and hands everything back. Safe at any step.
func stop() -> void:
	if _step == Step.SPIN:
		_end_spin()
		_hand_back()
	elif _step == Step.DASH:
		_end_dash()
	_step = Step.IDLE
	_owed = false
	_running = false
	set_physics_process(false)


# --- Arming ---------------------------------------------------------------------

func _on_fight_started() -> void:
	if _running or not enabled:
		return
	var director := _resolve_director()
	if director == null:
		return
	_boss = director.get_boss()
	if not _has_boss():
		return
	_boss_health = _find_health(_boss)
	if _boss_health == null:
		return

	if not _boss_health.health_changed.is_connected(_on_boss_health_changed):
		_boss_health.health_changed.connect(_on_boss_health_changed)
	if not _boss_health.died.is_connected(stop):
		_boss_health.died.connect(stop, CONNECT_ONE_SHOT)
	var defeat := _resolve_defeat()
	if defeat != null and not defeat.boss_defeated.is_connected(_on_boss_defeated):
		defeat.boss_defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)

	var ceiling := _boss_health.get_max()
	_next_threshold = ceiling - ceiling * health_step_fraction
	# Moved past wherever he already is, so a boss who starts the fight worn down
	# owes nothing for steps he never lost in front of the player.
	_pass_thresholds(_boss_health.get_current(), ceiling)
	_step = Step.IDLE
	_owed = false
	_running = true
	set_physics_process(true)


## He is beaten: everything this has borrowed goes back, and the charge is stopped
## with it - a man on the ground is not going to run at anybody.
func _on_boss_defeated(_bounty: Bounty, _reward: int) -> void:
	stop()
	var charge := _resolve_charge()
	if charge != null:
		charge.stop()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if not _running or current <= 0.0:
		return
	var defeat := _resolve_defeat()
	if defeat != null and defeat.is_defeated():
		return
	if current > _next_threshold:
		return

	_pass_thresholds(current, maximum)
	if _step == Step.IDLE:
		_begin_spin.call_deferred()
	else:
		_owed = true


## Moves the next step below [param current], however many steps one hit crossed.
func _pass_thresholds(current: float, maximum: float) -> void:
	var step := maxf(maximum * health_step_fraction, 0.001)
	while _next_threshold >= current and _next_threshold > 0.0:
		_next_threshold -= step


# --- The circle -----------------------------------------------------------------

func _begin_spin() -> void:
	if not _running or _step != Step.IDLE or not _has_boss():
		return
	_owed = false
	var charge := _resolve_charge()
	if charge != null:
		charge.set_held(true)
	_set_boss_attacks(false)

	_step = Step.SPIN
	_timer = maxf(spin_seconds, 0.0)
	_spin_angle = _pivot_angle()
	_take_aim()
	_raise_shield(true)
	sword_phase_started.emit()


func _advance_spin(delta: float) -> void:
	var centre := _centre()
	_spin_angle += TAU * spin_turns_per_second * delta
	if _aim_mark != null:
		_aim_mark.global_position = centre + Vector2.RIGHT.rotated(_spin_angle) * 40.0
	if _shield != null:
		_shield.global_position = centre
	if _ring != null:
		_ring.global_position = centre
		_ring.rotation += TAU * circle_turns_per_second * delta

	var player := _resolve_player()
	if player != null:
		_drive(player.global_position, spin_move_multiplier)

	var reach := get_spin_radius()
	_hurt_player_within(centre, reach, spin_damage, spin_knockback)
	if spin_kills_bandits:
		_tear_men_within(centre, reach)

	_timer -= delta
	if _timer <= 0.0:
		_end_spin()
		sword_phase_ended.emit()
		_begin_dash()


func _end_spin() -> void:
	_raise_shield(false)
	_release_aim()
	_step = Step.IDLE


## The circle, up or down: the boss's pool held, his hitboxes off the layer shots
## look for, and the ricochet ring put on it in their place.
func _raise_shield(on: bool) -> void:
	if _boss_health != null and is_instance_valid(_boss_health):
		_boss_health.set_shielded(on)

	if _has_boss():
		for node: Node in _boss.find_children("*", "Hitbox", true, false):
			var region := node as Area2D
			if region == null:
				continue
			if on:
				if not _layers.has(region):
					_layers[region] = region.collision_layer
				region.collision_layer = 0
			elif _layers.has(region):
				region.collision_layer = int(_layers[region])
		if not on:
			_layers.clear()

	_build_shield()
	var reach := get_spin_radius()
	if _shield_shape != null:
		_shield_shape.radius = maxf(reach, 1.0)
	if _shield != null:
		_shield.global_position = _centre()
		_shield.scatter_degrees = ricochet_scatter_degrees
		_shield.set_deferred(&"collision_layer", hitbox_layer if on else 0)
	_show_ring(on, reach)


func _build_shield() -> void:
	if _shield != null and is_instance_valid(_shield):
		return
	_shield = RicochetShield.new()
	_shield.name = "SwordCircle"
	_shield.monitoring = false
	_shield.collision_layer = 0
	_shield.collision_mask = 0
	_shield_shape = CircleShape2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = _shield_shape
	_shield.add_child(shape)
	add_child(_shield)

	if circle_texture != null:
		_ring = Sprite2D.new()
		_ring.name = "SwordCircleRing"
		_ring.texture = circle_texture
		_ring.visible = false
		_ring.z_index = circle_z_index
		add_child(_ring)


func _show_ring(on: bool, reach: float) -> void:
	if _ring == null:
		return
	if _ring_tween != null and _ring_tween.is_running():
		_ring_tween.kill()
	var size := _ring.texture.get_size()
	var widest := maxf(maxf(size.x, size.y), 1.0)
	_ring.scale = Vector2.ONE * (reach * 2.0 / widest)
	_ring.global_position = _centre()

	var shown := circle_color
	var hidden := Color(shown.r, shown.g, shown.b, 0.0)
	_ring_tween = create_tween()
	if on:
		_ring.modulate = hidden
		_ring.visible = true
		_ring_tween.tween_property(_ring, "modulate", shown, maxf(circle_fade_time, 0.0001))
	else:
		_ring_tween.tween_property(_ring, "modulate", hidden, maxf(circle_fade_time, 0.0001))
		_ring_tween.tween_callback(_ring.hide)


# --- The dash -------------------------------------------------------------------

func _begin_dash() -> void:
	if not _has_boss():
		return
	_step = Step.DASH
	_timer = maxf(dash_seconds, 0.0)
	_swing_timer = 0.0
	_slash = _resolve_slash()
	if _slash != null:
		_shorten_swing_times(_slash)
		if not _slash.strike_started.is_connected(_on_dash_strike):
			_slash.strike_started.connect(_on_dash_strike)
	dash_started.emit()


func _advance_dash(delta: float) -> void:
	var player := _resolve_player()
	if player != null:
		_drive(player.global_position, dash_speed_multiplier)

	# His body goes through whoever is in the way.
	_tear_men_within(_boss.global_position, maxf(body_reach, 0.0) * _boss_scale())

	_swing_timer -= delta
	if _swing_timer <= 0.0:
		_swing_timer = 1.0 / maxf(swings_per_second, 0.01)
		if _slash != null:
			_slash.slash()

	_timer -= delta
	if _timer <= 0.0:
		_end_dash()
		dash_finished.emit()
		if _owed:
			_begin_spin()


## A cut is at its strike: whatever is inside its reach is hit, on the same frame the
## blade is seen to go through them.
func _on_dash_strike() -> void:
	if _step != Step.DASH or not _has_boss():
		return
	var centre := _centre()
	var reach := maxf(sword_reach, 0.0) * _boss_scale()
	_hurt_player_within(centre, reach, dash_damage, dash_knockback)
	_tear_men_within(centre, reach)


func _end_dash() -> void:
	if _slash != null and is_instance_valid(_slash):
		if _slash.strike_started.is_connected(_on_dash_strike):
			_slash.strike_started.disconnect(_on_dash_strike)
	_restore_swing_times()
	_slash = null
	_step = Step.IDLE
	_hand_back()


## The boss back to his ordinary fight: walking at the player at his own pace,
## swinging his own swing, and his charge let go.
func _hand_back() -> void:
	if _has_boss() and _boss.has_method(&"end_charge"):
		_boss.call(&"end_charge")
	_set_boss_attacks(true)
	var charge := _resolve_charge()
	if charge != null:
		charge.set_held(false)


# --- The frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _running:
		return
	if not _has_boss():
		stop()
		return
	var step_delta := delta * WorldSlowdown.get_multiplier(self)
	match _step:
		Step.SPIN:
			_advance_spin(step_delta)
		Step.DASH:
			_advance_dash(step_delta)
		_:
			pass


# --- What it does to people -----------------------------------------------------

## The player, if they are within [param reach] of [param centre]: hurt, and thrown
## straight away from it. Their own grace window decides how often that can land.
func _hurt_player_within(centre: Vector2, reach: float, damage: float, push: float) -> void:
	if damage <= 0.0 or not is_inside_tree():
		return
	var health := get_tree().get_first_node_in_group(player_health_group) as Health
	if health == null or not health.is_alive() or health.is_invulnerable():
		return
	var body := health.get_parent() as Node2D
	if body == null:
		return
	var offset := body.global_position - centre
	if offset.length() > reach:
		return
	var effects := HitEffects.new()
	effects.knockback_push = maxf(push, 0.0)
	var away := offset.normalized() if not offset.is_zero_approx() else Vector2.DOWN
	health.take_damage(damage, away, effects)


## Every one of his own men within [param reach] of [param centre], torn apart.
func _tear_men_within(centre: Vector2, reach: float) -> void:
	if reach <= 0.0 or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(enemy_group):
		var man := node as Node2D
		if man == null or man == _boss or not is_instance_valid(man) or man.is_queued_for_deletion():
			continue
		if man.global_position.distance_to(centre) > reach:
			continue
		var health := _find_health(man)
		if health == null or not health.is_alive():
			continue
		_tear(man, centre)


func _tear(man: Node2D, from: Vector2) -> void:
	var away := (man.global_position - from).normalized()
	var gore: Explosion = null
	if gore_effect != null:
		gore = gore_effect.instantiate() as Explosion
	if gore == null:
		var health := _find_health(man)
		if health != null:
			health.kill(away)
		bandit_torn.emit(man)
		return
	var into := man.get_parent() if man.get_parent() != null else get_tree().current_scene
	into.add_child(gore)
	bandit_torn.emit(man)
	gore.tear_apart(man, away)


# --- What it borrows ------------------------------------------------------------

func _drive(point: Vector2, multiplier: float) -> void:
	if _has_boss() and _boss.has_method(&"begin_charge"):
		_boss.call(&"begin_charge", point, maxf(multiplier, 0.0))


func _set_boss_attacks(enabled_now: bool) -> void:
	if _has_boss() and _boss.has_method(&"set_attacks_enabled"):
		_boss.call(&"set_attacks_enabled", enabled_now)


## Hands the pivot a mark that orbits him, which is the whole of the spin: the pivot
## already turns to whatever it is given.
func _take_aim() -> void:
	var pivot := _resolve_pivot()
	if pivot == null:
		return
	if _aim_mark == null or not is_instance_valid(_aim_mark):
		_aim_mark = Node2D.new()
		_aim_mark.name = "SpinMark"
		add_child(_aim_mark)
	_aim_mark.global_position = _centre() + Vector2.RIGHT.rotated(_spin_angle) * 40.0
	_aim_rest = pivot.target
	pivot.target = _aim_mark


func _release_aim() -> void:
	var pivot := _resolve_pivot()
	if pivot != null and pivot.target == _aim_mark:
		pivot.target = _aim_rest
	_aim_rest = null


func _shorten_swing_times(slash: KnifeSlash) -> void:
	if _swing_rest.is_empty():
		_swing_rest = {
			"windup": slash.windup_time,
			"strike": slash.strike_time,
			"recover": slash.recover_time,
		}
	var faster := maxf(swing_speed_multiplier, 0.01)
	slash.windup_time = float(_swing_rest["windup"]) / faster
	slash.strike_time = float(_swing_rest["strike"]) / faster
	slash.recover_time = float(_swing_rest["recover"]) / faster


func _restore_swing_times() -> void:
	if _swing_rest.is_empty():
		return
	var slash := _resolve_slash()
	if slash != null:
		slash.windup_time = float(_swing_rest["windup"])
		slash.strike_time = float(_swing_rest["strike"])
		slash.recover_time = float(_swing_rest["recover"])
	_swing_rest.clear()


# --- Looking things up ----------------------------------------------------------

func _has_boss() -> bool:
	return _boss != null and is_instance_valid(_boss)


## His size against the enemy scene's own, which every reach here is multiplied by.
func _boss_scale() -> float:
	return absf(_boss.scale.x) if _has_boss() else 1.0


## Where the circle and the cuts are measured from: his sword hand.
func _centre() -> Vector2:
	var pivot := _resolve_pivot()
	if pivot != null:
		return pivot.global_position
	return _boss.global_position if _has_boss() else Vector2.ZERO


func _pivot_angle() -> float:
	var pivot := _resolve_pivot()
	return 0.0 if pivot == null else pivot.global_rotation


func _resolve_player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(player_group) as Node2D


func _resolve_director() -> MiniBossDirector:
	if _director == null or not is_instance_valid(_director):
		_director = get_node_or_null(director_path) as MiniBossDirector
		if _director == null:
			_director = MiniBossDirector.get_active(self)
	return _director


func _resolve_charge() -> BossCharge:
	if _charge == null or not is_instance_valid(_charge):
		_charge = get_node_or_null(charge_path) as BossCharge
		if _charge == null:
			_charge = BossCharge.get_active(self)
	return _charge


func _resolve_defeat() -> BossDefeat:
	if _defeat == null or not is_instance_valid(_defeat):
		_defeat = get_node_or_null(defeat_path) as BossDefeat
		if _defeat == null:
			_defeat = BossDefeat.get_active(self)
	return _defeat


func _resolve_slash() -> KnifeSlash:
	return null if not _has_boss() else _boss.get_node_or_null(knife_slash_path) as KnifeSlash


func _resolve_pivot() -> LookAtTarget:
	return null if not _has_boss() else _boss.get_node_or_null(aim_pivot_path) as LookAtTarget


func _find_health(body: Node) -> Health:
	if body == null:
		return null
	for node: Node in body.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null
