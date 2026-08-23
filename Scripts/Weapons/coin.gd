class_name Coin
extends Projectile
## The coin the revolver throws: flung out, slowing, hanging for an instant, and
## falling back to the hand - unless the player shoots it out of the air.
##
## [b]It extends [Projectile] on purpose.[/b] A struck coin is not a special kind
## of effect, it is a shot: it flies at an enemy, it damages whatever it lands on
## through that enemy's own [Hitbox] - so a coin can land a headshot exactly as a
## bullet can - and it carries the same [member Projectile.bounce_count] to the
## next target afterwards. Everything from the moment it is hit is code that
## already existed; all this file adds is the part before that, which is the throw.
##
## [b]The two lives of a coin.[/b] Until it is struck it is not a projectile at
## all: it ignores its profile's range and speed, runs its own out-and-back arc,
## and touches nothing - enemies cannot be hurt by it and cannot stop it. Once
## struck it stops being thrown and becomes the shot, and from that instant every
## frame of it is [Projectile]'s.
##
## The spin is two pictures rather than a rotation. A coin turning edge-on is a
## thing a sprite cannot do, so the artwork alternates between the flat face and
## the edge at a rate the inspector sets, which reads as tumbling for a fraction
## of the cost of animating it.

## Emitted when a shot knocks the coin out of the air, carrying the round that did
## it and where it landed. Everything cosmetic about the strike hangs off this.
signal struck(shot: Projectile, at: Vector2)
## Emitted when the coin makes it home without being shot.
signal returned

## Group the coin joins so a weapon can find the one it already has in the air
## rather than throwing a second.
const GROUP := &"thrown_coin"

@export_group("Throw")
## How fast the coin leaves the hand, in pixels per second.
@export var throw_speed: float = 420.0
## How hard it is slowed on the way out, in pixels per second squared. Together
## with the speed this is what decides how far out it gets before it stops.
@export var deceleration: float = 620.0
## How long it hangs at the top of its arc before starting back, in seconds.
@export var hang_time: float = 0.12
## How hard it accelerates on the way home. Higher snaps it back into the hand.
@export var return_acceleration: float = 760.0
## Ceiling on the speed it comes home at, so a long throw does not arrive as a
## bullet.
@export var max_return_speed: float = 700.0
## How close to the thrower it has to get to count as caught, in pixels.
@export var catch_distance: float = 26.0
## Longest a throw may last before the coin gives up and vanishes, in seconds. A
## guard, not a tuning value - nothing should ever reach it.
@export var max_flight_time: float = 6.0

@export_group("Spin")
## The two pictures the coin alternates between: flat on, then edge on.
@export var face_texture: Texture2D
@export var edge_texture: Texture2D
## How many times a second the picture changes. Higher spins faster.
@export var flip_rate: float = 14.0

@export_group("Shine")
## The glint the coin carries for the whole of the throw.
##
## It is lit as the coin leaves the hand and burns until the coin is back in it -
## through the flight out, the slowing, the stop and the way home alike. It is not
## a cue that a particular moment has arrived, it is what makes the coin readable
## as a thing in the air at all, and a coin that is on screen is always worth
## seeing.
@export var shine_path: NodePath = ^"Shine"
## How quickly it comes up as the coin is thrown. Deliberately tiny: a glint
## arrives, it does not fade in.
@export var shine_rise_time: float = 0.04
## How bright it burns. Above 1 blows it out against an additive material, which
## is what makes it read as a glint rather than a decal.
@export var shine_brightness: float = 1.8
## Size it is drawn at, as a fraction of the authored scale.
@export var shine_scale: float = 1.0

@export_group("Hit")
## How much bigger the coin is to shoot at than it looks, in pixels of radius.
##
## A coin is a tiny target moving across the screen, and missing one by a pixel is
## not interesting. This is deliberately a small, quiet number: enough that a shot
## which looks like it should have connected does, and not so much that the player
## can see they are shooting at air.
@export var hit_radius_bonus: float = 5.0
## Only shots in this group can knock the coin out of the air. It is what keeps
## the coin the revolver's own mechanic - another weapon's rounds pass straight
## through it and are entirely unaffected. Empty accepts any shot at all.
@export var struck_by_group: StringName = &"revolver_shot"
## The coin's own tumbling sound, silenced the instant it is shot.
@export var flip_sound_path: NodePath = ^"FlipSound"

@export_group("Strike reward")
## What both attacks hit for, as a multiple of what they would otherwise do.
##
## [b]It is the payment for the shot.[/b] Hitting a coin in mid-air is the hardest
## thing the revolver asks for, and the two attacks it buys are worth this much
## each - so the multiplier is the dial that decides whether the trick is worth
## taking. It is applied to the coin and to the round that hit it identically:
## neither is the "real" attack.
##
## Nothing about the damage itself is written here. Both remain ordinary
## [Projectile]s reading their own profiles, so a profile retuned later - or a
## damage upgrade added later - carries through this untouched.
@export var strike_damage_multiplier: float = 2.0
## Whether both attacks land as critical hits.
##
## This does not add a critical system; it marks the hit with the one the game
## already has, so the figures come off in the critical colour and at the critical
## size, and a headshot on top of it still applies its own multiplier as usual.
@export var strike_is_critical: bool = true

@export_group("Strike flight")
## How much faster the struck coin travels at its enemy than its profile says.
##
## A coin knocked out of the air is not a coin any more, it is a shot, and it
## should read as one - so it leaves the strike faster than it flew as a throw.
## It is a multiple rather than a speed on purpose: the whole shape of the flight
## still comes from the coin's own [ProjectileProfile] and still eases off across
## the range, so retuning that profile - or a speed upgrade added later - carries
## through here without this number being touched. It changes nothing but the
## pace: the coin reaches exactly as far as it always did, it just gets there
## sooner. 1 flies it at the speed its profile alone would give it.
@export var strike_speed_multiplier: float = 1.6

@onready var _art: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D
@onready var _shine: CanvasItem = get_node_or_null(shine_path) as CanvasItem
@onready var _shape: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D

## Who threw it, and who it comes back to.
var _thrower: Node2D
var _direction := Vector2.RIGHT
var _speed: float = 0.0
var _returning: bool = false
var _flight_age: float = 0.0
var _flip_age: float = 0.0
var _showing_edge: bool = false
## Time left hanging at the top of the arc, once the outward speed has gone.
var _hang_left: float = 0.0
var _shine_tween: Tween
var _shine_rest_scale := Vector2.ONE
## True from the instant a shot lands on it. Everything before this is the throw;
## everything after is [Projectile].
var _in_flight: bool = true


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()
	_grow_hitbox()
	if _shine != null:
		var shine_node := _shine as Node2D
		if shine_node != null:
			_shine_rest_scale = shine_node.scale
		_shine.visible = false
		_shine.modulate.a = 0.0
	# Nothing about the throw is a projectile, so the inherited flight is switched
	# off until a shot turns it back on.
	_apply_flip(true)


## Throws the coin from [param from] in [param direction]. Called by the weapon
## the instant it is spawned, because everything here is measured from where it
## started and which way it was sent.
func throw(from: Node2D, direction: Vector2) -> void:
	_thrower = from
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_speed = throw_speed
	_returning = false
	_flight_age = 0.0
	global_rotation = 0.0
	# Lit here rather than at any point of the arc: the glint belongs to the whole
	# throw, so the one moment it can be timed off is the throw itself.
	_show_shine()


## Whether the coin is still out - thrown and neither caught nor shot.
func is_in_flight() -> bool:
	return _in_flight


## How long until the coin runs out of outward speed, in seconds, for anything
## wanting to land on the moment it comes to rest. Worked out rather than tracked,
## so it stays right if the deceleration is retuned mid-flight.
func get_time_to_stop() -> float:
	if _returning or deceleration <= 0.0:
		return 0.0
	return _speed / deceleration


## The thrown coin already in the air, or null when there is none. A weapon asks
## this before throwing, so there is only ever one.
static func get_active(from_node: Node) -> Coin:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as Coin


## The throw, and only the throw. Once the coin has been struck this hands every
## frame to [Projectile], which is what makes a struck coin behave exactly like a
## shot rather than like a coin that also does damage.
func _physics_process(delta: float) -> void:
	if not _in_flight:
		super._physics_process(delta)
		return

	_flight_age += delta
	if _flight_age >= max_flight_time:
		queue_free()
		return

	_spin(delta)

	if _returning:
		_fly_home(delta)
		return
	_fly_out(delta)


## Out, slowing, until the speed is gone. The hang at the top is a wait rather
## than a separate state: the coin is simply travelling at nothing for a moment,
## which is exactly what a coin at the top of its arc is doing.
func _fly_out(delta: float) -> void:
	if _speed > 0.0:
		_speed = maxf(_speed - deceleration * delta, 0.0)
		global_position += _direction * _speed * delta
		if _speed <= 0.0:
			# It has just run out. The hang is started here rather than counted from
			# the throw, so it is always the same length whatever the throw was.
			_hang_left = hang_time
		return

	_hang_left -= delta
	if _hang_left <= 0.0:
		_returning = true


## Home, accelerating, aimed at wherever the thrower is *now* - so a player who
## has run since throwing is still caught up with rather than the coin returning
## to a spot they have left.
func _fly_home(delta: float) -> void:
	if _thrower == null or not is_instance_valid(_thrower):
		queue_free()
		return

	var to_hand := _thrower.global_position - global_position
	if to_hand.length() <= catch_distance:
		# Home. This is the one place the glint goes out on a throw that was never
		# shot at - it is lit for exactly as long as there is a coin in the air.
		_hide_shine()
		returned.emit()
		queue_free()
		return

	_speed = minf(_speed + return_acceleration * delta, max_return_speed)
	global_position += to_hand.normalized() * _speed * delta


## Alternates the two pictures. Time-based rather than tied to the speed, so the
## coin keeps turning while it hangs - a coin that stopped spinning at the top
## would read as having landed on something.
func _spin(delta: float) -> void:
	_flip_age += delta
	var interval := 1.0 / maxf(flip_rate, 0.01)
	if _flip_age < interval:
		return
	_flip_age = 0.0
	_apply_flip(not _showing_edge)


func _apply_flip(edge: bool) -> void:
	_showing_edge = edge
	if _art == null:
		return
	var wanted := edge_texture if edge else face_texture
	if wanted != null:
		_art.texture = wanted


## Lights the glint and leaves it burning. There is deliberately nothing here that
## takes it down again: a thrown coin carries it for the whole of its flight, and
## the only two things that end it - being caught and being shot - both end the
## coin as well, so both go through [method _hide_shine].
func _show_shine() -> void:
	if _shine == null:
		return

	if _shine_tween != null and _shine_tween.is_running():
		_shine_tween.kill()

	var shine_node := _shine as Node2D
	if shine_node != null:
		shine_node.scale = _shine_rest_scale * shine_scale

	var tint := Color(1.0, 1.0, 1.0, 1.0) * shine_brightness
	tint.a = 0.0
	_shine.modulate = tint
	_shine.visible = true

	# Up fast, and then simply left alone. The tween ends at full brightness rather
	# than running on into a fade, which is what keeps the glint lit through the
	# slowing, the stop and the way home without anything having to hold it there.
	_shine_tween = create_tween()
	_shine_tween.tween_property(_shine, "modulate:a", 1.0, maxf(shine_rise_time, 0.0001))


## Widens the coin's own collision shape by [member hit_radius_bonus].
##
## Done to the shape rather than by drawing the coin larger, so what the player
## shoots at is a little more generous than what they see without the coin itself
## looking wrong - which is the entire point of the assist.
func _grow_hitbox() -> void:
	if _shape == null or hit_radius_bonus <= 0.0:
		return
	var circle := _shape.shape as CircleShape2D
	if circle == null:
		return
	# Duplicated first: the shape resource is shared by every coin the scene
	# spawns, and growing it in place would grow it again on every throw.
	var own := circle.duplicate() as CircleShape2D
	own.radius += hit_radius_bonus
	_shape.shape = own


## A shot has reached the coin. Returns whether it was taken, which is what tells
## the shot to stop here rather than pass through.
##
## [b]This is the hinge of the whole mechanic.[/b] The coin stops being thrown and
## becomes a shot, and the round that hit it is handed back to whatever is
## listening so the two can be sent at different enemies. Everything after this is
## [Projectile]'s.
func take_projectile_hit(shot: Projectile, at: Vector2) -> bool:
	if not _in_flight or shot == null:
		return false
	if struck_by_group != &"" and not shot.is_in_group(struck_by_group):
		return false

	_in_flight = false
	global_position = at
	# Applied to the coin alone, never to the round that hit it: the coin is the
	# attack that was aimed by hand, and it is the one that gets to travel like it.
	set_speed_scale(strike_speed_multiplier)
	_hide_shine()
	_stop_flip_sound()
	_split_targets(shot)
	struck.emit(shot, at)
	return true


## Sends the coin and the round that hit it at different enemies.
##
## [b]Two attacks out of one shot is the point of the weapon[/b], so the pair is
## chosen together, here, rather than each of them looking for its own target and
## both arriving at the same body. With one enemy on the field they do both go to
## the same one - the mechanic is not allowed to need a crowd to work.
##
## Beyond being turned up by [member strike_damage_multiplier] neither is given
## anything of its own: both fly, damage and bounce as [Projectile]s, so a bounce
## upgrade later applies to the pair without this knowing.
func _split_targets(shot: Projectile) -> void:
	# Both are turned up before either is sent, so the pair is empowered whether or
	# not there is anybody to send them at - and identically, since neither of them
	# is the attack the player actually aimed.
	empower(strike_damage_multiplier, strike_is_critical)
	if shot != null and is_instance_valid(shot):
		shot.empower(strike_damage_multiplier, strike_is_critical)

	var found := EnemyTargeting.nearest_many(self, global_position, 2, target_search_radius)
	if found.is_empty():
		# Nothing to send them at. The coin drops out and the round carries on the
		# way it was going, which is the honest answer to shooting a coin in an
		# empty arena.
		queue_free()
		return

	launch_at(found[0])
	if shot != null and is_instance_valid(shot):
		shot.redirect_to(found[1] if found.size() > 1 else found[0])


func _stop_flip_sound() -> void:
	var sound := get_node_or_null(flip_sound_path) as AudioStreamPlayer2D
	if sound != null and sound.playing:
		sound.stop()


## Puts the glint out. Only ever called as the coin itself ends - caught in the
## hand, or shot out of the air - since those are the only two moments there
## stops being a coin in flight for it to belong to.
func _hide_shine() -> void:
	if _shine_tween != null and _shine_tween.is_running():
		_shine_tween.kill()
	if _shine != null:
		_shine.visible = false
		_shine.modulate.a = 0.0


## The struck coin flies at [param target] as a shot. Called by whatever handled
## the strike, after it has decided who the coin and the round are each going at.
func launch_at(target: Node2D) -> void:
	redirect_to(target)


## Enemies cannot touch a coin that is still being thrown - it is a coin in the
## air, not an attack - so the inherited overlap damage is refused until a shot
## has turned it into one.
func _on_area_entered(area: Area2D) -> void:
	if _in_flight:
		return
	super._on_area_entered(area)
