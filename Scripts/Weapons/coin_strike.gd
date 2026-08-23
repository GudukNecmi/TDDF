class_name CoinStrike
extends Node
## The moment after a coin is shot out of the air: the freeze, the slow motion,
## and the camera riding the coin to whatever it was sent at.
##
## [b]Why this is not in the coin's own scene.[/b] Everything here has to outlive
## the coin. The coin is spent the instant it reaches its enemy, and the round that
## hit it is spent on a different enemy at a different moment - but the slow motion
## has to last until both are done and the camera has to be handed back afterwards.
## A node hanging off the coin is freed with the coin, so it can only ever run half
## of that. This sits in the world instead, next to [HitStop] and [WorldSlowdown]
## and found the same way, and is handed the pair to watch.
##
## What is left on the coin is everything that genuinely belongs to one coin: the
## flash, the burst, the sound and the shake, all in [CoinFeedback]. This owns only
## the parts that carry on after it.
##
## [b]The sequence.[/b] A freeze first, on the real clock, so the frame that stops
## is the frame of the impact. Then the world drops to [member slow_scale] while
## the coin and the round it split from carry on at their ordinary speed - which is
## the whole trick, and it is done by excusing exactly those two rounds from the
## time scale rather than by slowing everything else one system at a time. The
## camera takes the coin as its subject for the same stretch, so the shot the
## player earned is the thing on screen rather than the player themselves. Both
## end when both attacks have landed.
##
## [b]It always ends.[/b] The world's time scale is put back by [method _finish],
## which is reached from four directions - both attacks landing, the player firing
## again, the player dying, and a real-time deadline that nothing should ever
## reach - and the node puts the scale back on its way out of the tree as well.

## Group used by [method get_active].
const GROUP := &"coin_strike"

## Whether the sequence plays at all. Off makes every strike an ordinary hit, with
## the coin's own flash and burst still landing - which is how the whole effect is
## switched off without a caller being touched.
@export var enabled: bool = true

@export_group("Freeze")
## How long the world stops for on the impact, in real seconds.
##
## Long enough to be felt as the game catching its breath on the hit, and still
## short enough that the player is never waiting on it. It is served by [HitStop],
## whose own [member HitStop.max_duration] is the ceiling this is clamped to.
@export var freeze_time: float = 0.28

@export_group("Slow motion")
## What fraction of normal speed the rest of the run drops to once the freeze has
## lifted. 0.5 is half speed; 1 leaves the world running and reduces the sequence
## to the camera move.
@export_range(0.05, 1.0) var slow_scale: float = 0.5
## Whether the coin and the round that struck it are excused from that slowdown.
##
## On, which is the entire point of the effect: the world goes to half speed and
## the two attacks the player just earned do not, so they visibly outrun everything
## around them on the way to their enemies.
@export var exempt_attacks: bool = true
## Longest the whole sequence may last, in real seconds. A guard rather than a
## tuning value - both attacks resolve long before it - and what makes certain the
## world cannot be left slowed by a round that somehow never lands.
@export var max_duration: float = 2.5

@export_group("Camera")
## Whether the camera takes the coin as its subject for the flight.
##
## On, and it is the difference between the effect reading as "look what that shot
## did" and as "look at the player". The zoom below pushes in on whatever the
## camera is centred on, so with this off it pushes in on the player instead.
@export var follow_coin: bool = true
## How hard the camera locks onto the coin, in the camera's own smoothing units.
## Well above its resting follow, because a coin crossing the arena has to stay in
## the middle of the frame rather than be chased across it.
@export var follow_speed: float = 20.0
## How quickly the camera comes back to the player once the coin is spent. This is
## the return timing: higher snaps the view back the instant the coin lands, lower
## drifts home.
@export var return_speed: float = 9.0
## How far the camera pushes in on the strike, as a fraction. 0.3 is thirty per
## cent closer.
@export var zoom_amount: float = 0.3
## How quickly it gets there. Fast - the push is part of the impact, not a move.
@export var zoom_in_time: float = 0.06
## How long it takes to come back out once the sequence ends.
@export var zoom_recover_time: float = 0.22
## How quickly it lets go when the player cuts the sequence short by firing.
@export var zoom_cancel_time: float = 0.1
## The camera layer this is written to.
##
## [b]Its own channel, and a loud one.[/b] The controller sums channels and lets
## each caller restart only its own, so a shot's recoil, a reload's shove or any
## other ordinary feedback physically cannot cut this short - they are added on top
## of it. The priority sits above the weapon's so that while this is holding, those
## lesser effects are the ones scaled down rather than this one.
@export var zoom_channel: StringName = &"coin_impact"
@export var zoom_priority: int = 20

@export_group("Interruptions")
## Whether firing again ends the sequence early. On: taking another shot is the
## player getting back to work, and the camera should be out of their way when they
## do.
@export var cancel_on_fire: bool = true
## Whether the player dying ends it early. On, so a death is never watched from
## somewhere else in the arena.
@export var cancel_on_death: bool = true

## The two attacks being watched. Both are ordinary [Projectile]s - the coin is one
## too, from the moment it is struck.
var _coin: Projectile
var _shot: Projectile
var _coin_done: bool = true
var _shot_done: bool = true

## The world's time scale as it was before any of this started, and what it is put
## back to. Captured rather than assumed, so a sequence beginning during somebody
## else's slowdown restores theirs rather than plain 1.
var _restore_scale: float = 1.0
var _slowing: bool = false
## When the whole thing gives up, on the real clock - milliseconds since start-up,
## so it is untouched by the very scale this is changing.
var _deadline_msec: int = 0

var _camera: CameraController
var _weapon: Node
var _health: Health


func _enter_tree() -> void:
	# Joined here rather than in `_ready`, so a coin struck on this world's first
	# frame can still find it.
	add_to_group(GROUP)


func _ready() -> void:
	# Runs while the tree is paused, so a menu opening mid-sequence can never leave
	# the world in slow motion.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## The sequence in this world, or null when it has none - which [CoinFeedback]
## reads as "a struck coin is an ordinary hit here".
static func get_active(from_node: Node) -> CoinStrike:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as CoinStrike


## Whether a strike is playing out right now.
func is_running() -> bool:
	return is_processing()


## Starts the sequence on the pair a struck coin has just produced.
##
## [param coin] is the coin itself, now flying as a shot, and [param shot] is the
## round that hit it. Either may be null - a coin struck with nobody to send it at
## frees itself immediately - and the sequence simply watches whichever it was
## given.
func begin(coin: Projectile, shot: Projectile) -> void:
	if not enabled:
		return

	# A second strike during the first cannot happen - there is only ever one coin
	# in the air - but if it ever did, the running one is closed out properly rather
	# than having its state overwritten and its time scale orphaned.
	if is_running():
		_finish(zoom_cancel_time)

	_coin = coin if is_instance_valid(coin) else null
	_shot = shot if is_instance_valid(shot) else null
	_coin_done = _coin == null
	_shot_done = _shot == null
	if _coin_done and _shot_done:
		return

	_restore_scale = Engine.time_scale
	_slowing = false
	_deadline_msec = Time.get_ticks_msec() + int(maxf(max_duration, 0.0) * 1000.0)

	HitStop.request(self, freeze_time)
	_watch(_coin, _on_coin_landed, _on_coin_resolved)
	_watch(_shot, _on_shot_landed, _on_shot_resolved)
	_watch_for_interruptions()
	_take_camera()

	set_process(true)


## Timed off the real clock rather than off [param _delta], which is already
## multiplied by the scale this is changing - counting with that would make the
## sequence last as long as the world is slow, which is to say far too long.
func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _deadline_msec:
		_finish(zoom_recover_time)
		return

	_sweep_lost_attacks()
	if _coin_done and _shot_done:
		_finish(zoom_recover_time)
		return

	_advance_slowdown()


## Counts an attack as resolved the moment its instance is gone, whether or not the
## signal that would have said so was heard.
##
## The signals remain how this normally learns an attack is over. This is the floor
## underneath them: an attack can leave without landing and without a tidy exit - a
## coin whose enemy died before it arrived retires itself mid-flight, and the whole
## scene going away takes both with it - and an attack the sequence never hears
## about would hold the camera and the world's time scale until the deadline. It
## also guarantees the references are dropped rather than left pointing at freed
## instances.
func _sweep_lost_attacks() -> void:
	if not _coin_done and not is_instance_valid(_coin):
		_on_coin_resolved()
	if not _shot_done and not is_instance_valid(_shot):
		_on_shot_resolved()


## Holds the world at [member slow_scale] once the freeze has lifted.
##
## The scale is written every frame rather than once, deliberately. [HitStop] owns
## it for the length of the freeze and puts back the value it found on the way out,
## and the two nodes are processed in whatever order the scene puts them in - so
## asserting it each frame is what makes the hand-over from the freeze to the slow
## motion correct without either node having to know about the other's ordering.
func _advance_slowdown() -> void:
	var stop := HitStop.get_active(self)
	if stop != null and stop.is_stopping():
		return

	if not _slowing:
		_slowing = true
		_set_attack_exemption(slow_scale)

	Engine.time_scale = slow_scale


## Puts the world, the rounds and the camera back exactly as they were found.
## Every way out of the sequence comes through here.
func _finish(zoom_out_time: float) -> void:
	if not is_running():
		return
	set_process(false)

	if _slowing:
		Engine.time_scale = _restore_scale
		_slowing = false
	_set_attack_exemption(1.0)

	_release_camera(zoom_out_time)
	_stop_watching()
	_drop_interruptions()

	_coin_done = true
	_shot_done = true


## Excuses - or stops excusing - the pair from the world's time scale.
## [param world_scale] of 1 is the pair back in step with everything else.
func _set_attack_exemption(world_scale: float) -> void:
	if not exempt_attacks:
		return
	var scale_to := world_scale if world_scale > 0.0 else 1.0
	if is_instance_valid(_coin):
		_coin.exempt_from_time_scale(scale_to)
	if is_instance_valid(_shot):
		_shot.exempt_from_time_scale(scale_to)


## Centres the camera on the coin and pushes in on it.
##
## The hold is handed over as one long step rather than a measured one, because
## what ends the push is the coin landing rather than a duration - [method _finish]
## replaces the step with the way out. The camera's following, its resting spot and
## its limits are untouched throughout: this is a subject and a zoom offset on top
## of whatever the camera was already doing.
func _take_camera() -> void:
	_camera = CameraController.get_active(self)
	if _camera == null:
		return

	if follow_coin and is_instance_valid(_coin):
		_camera.follow(_coin, follow_speed)

	if is_zero_approx(zoom_amount):
		return
	_camera.zoom_impulse([
		Vector2(zoom_amount, maxf(zoom_in_time, 0.0001)),
		Vector2(zoom_amount, maxf(max_duration, 0.0)),
	], zoom_channel, zoom_priority)


func _release_camera(zoom_out_time: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.release_follow(return_speed)
	if not is_zero_approx(zoom_amount):
		_camera.zoom_impulse(
			[Vector2(0.0, maxf(zoom_out_time, 0.0001))], zoom_channel, zoom_priority)
	_camera = null


## An attack counts as resolved the moment it lands on a body, and also if it
## leaves the tree without landing on one - a round that expired, or a coin with
## nobody to be sent at. Both routes are watched because the sequence has to end on
## whichever happens, and only one of them ever comes first.
func _watch(attack: Projectile, on_landed: Callable, on_gone: Callable) -> void:
	if not is_instance_valid(attack):
		return
	attack.landed.connect(on_landed)
	attack.tree_exited.connect(on_gone)


## Lets go of both attacks and forgets them.
##
## [b]The validity check has to happen here, before the call.[/b] By the time the
## sequence ends the usual case is that both attacks are already gone - a round is
## freed the moment it lands, which is precisely the event that ends the sequence -
## and a freed instance cannot be handed to a parameter typed as anything
## Object-derived: the engine has no class left to check it against and refuses the
## call outright. So the reference is tested and cleared here, and [method _unwatch]
## is only ever reached with an attack that is genuinely still alive.
##
## The references are dropped either way, so nothing is left holding a stale one.
func _stop_watching() -> void:
	if is_instance_valid(_coin):
		_unwatch(_coin, _on_coin_landed, _on_coin_resolved)
	_coin = null

	if is_instance_valid(_shot):
		_unwatch(_shot, _on_shot_landed, _on_shot_resolved)
	_shot = null


func _unwatch(attack: Projectile, on_landed: Callable, on_gone: Callable) -> void:
	if attack.landed.is_connected(on_landed):
		attack.landed.disconnect(on_landed)
	if attack.tree_exited.is_connected(on_gone):
		attack.tree_exited.disconnect(on_gone)


func _on_coin_landed(_hitbox: Hitbox) -> void:
	_on_coin_resolved()


func _on_shot_landed(_hitbox: Hitbox) -> void:
	_on_shot_resolved()


## The coin has arrived. The camera lets go of it here rather than waiting for the
## sequence to end, so the view is on its way back to the player on the very frame
## the coin hits rather than a moment after it.
func _on_coin_resolved() -> void:
	if _coin_done:
		return
	_coin_done = true
	if _camera != null and is_instance_valid(_camera):
		_camera.release_follow(return_speed)


func _on_shot_resolved() -> void:
	_shot_done = true


func _watch_for_interruptions() -> void:
	if cancel_on_fire:
		var mount := WeaponMount.get_active(self)
		_weapon = mount.get_weapon() if mount != null else null
		if _weapon != null and _weapon.has_signal(&"fired") \
				and not _weapon.is_connected(&"fired", _on_fired):
			_weapon.connect(&"fired", _on_fired)

	if not cancel_on_death:
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	_health = player.get_node_or_null(^"Health") as Health
	if _health != null and not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)


func _drop_interruptions() -> void:
	if is_instance_valid(_weapon) and _weapon.has_signal(&"fired") \
			and _weapon.is_connected(&"fired", _on_fired):
		_weapon.disconnect(&"fired", _on_fired)
	_weapon = null

	if is_instance_valid(_health) and _health.died.is_connected(_on_died):
		_health.died.disconnect(_on_died)
	_health = null


func _on_fired() -> void:
	_finish(zoom_cancel_time)


func _on_died() -> void:
	_finish(zoom_cancel_time)


## The world is going away mid-sequence - a scene rebuild, or the game closing.
## The time scale is global state that outlives every scene, so it is put back
## rather than left.
func _exit_tree() -> void:
	if _slowing:
		Engine.time_scale = _restore_scale
		_slowing = false
