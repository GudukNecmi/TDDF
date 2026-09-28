class_name PlayerRecoil
extends Node
## The shove a weapon's own shot gives the player - what RECOIL DEVIL throws them
## with. See [ShotRecoil].
##
## [b]It does not take movement over, it is added to it[/b], exactly as
## [PlayerDash] is: [Player] hands it the walk it has already worked out and gets
## it back with the recoil on top - see [method apply_recoil_velocity]. The walk is
## only turned down while a kick is fresh and never switched off, so the player
## keeps steering and aiming the whole way; the recoil speed dies away on its own
## damping, and the one [code]move_and_slide[/code] still does every wall, so a
## shove can never carry the body through anything solid. Recoil that runs into a
## wall is spent against it rather than left pushing along it.
##
## [b]It is kept apart from the hit shove on purpose.[/b] [HitReaction] is being
## struck; this is the player's own weapon, chained shot after shot, with its own
## ceiling and its own control - so neither can bleed into the other's tuning.
##
## Every number for the push itself comes with the kick - the weapon's
## [ShotRecoil] - so the Legendary is tuned in one place. What is here is only how
## the player looks while being thrown: the afterimage.

## Emitted as a kick lands, with the velocity change it added.
signal recoiled(push: Vector2)

## The body being pushed.
@export var body_path: NodePath = ^".."

@export_group("Afterimage")
## The artwork a ghost is taken from - never the body, so what is left behind is
## the drawing alone. Every visible [Sprite2D] under it is copied.
@export var visual_path: NodePath = ^"../Visual"
## Seconds between two ghosts while the player is being thrown.
@export var afterimage_interval: float = 0.035
## How long one ghost takes to fade.
@export var afterimage_lifetime: float = 0.16
## Its colour and its starting opacity.
@export var afterimage_color := Color(0.75, 0.08, 0.06, 0.42)
## Recoil speed below which no ghosts are left, and the speed at which they are
## left at full [member afterimage_color] opacity.
@export var afterimage_min_speed: float = 320.0
@export var afterimage_full_speed: float = 900.0

@onready var _body: CharacterBody2D = get_node_or_null(body_path) as CharacterBody2D
@onready var _visual: Node2D = get_node_or_null(visual_path) as Node2D

var _tuning: ShotRecoil
var _velocity: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _ghost_timer: float = 0.0


## Adds one shot's [param push] to whatever recoil is already carrying the player,
## tuned by [param recoil]. The momentum already there is swung towards the new
## push by [member ShotRecoil.directional_influence] first, and the sum is capped
## at [member ShotRecoil.max_recoil_velocity], so chained shots build a shove but
## never an ever-faster one.
func kick(push: Vector2, recoil: ShotRecoil) -> void:
	if recoil == null or push.is_zero_approx():
		return
	_tuning = recoil
	if not _velocity.is_zero_approx():
		var turned := push.normalized() * _velocity.length()
		_velocity = _velocity.slerp(turned, clampf(recoil.directional_influence, 0.0, 1.0))
	_velocity = (_velocity + push).limit_length(maxf(recoil.max_recoil_velocity, 0.0))
	_elapsed = 0.0
	_ghost_timer = 0.0
	recoiled.emit(push)


## The player's walk with the recoil folded into it. Called once per physics frame
## from [Player] while they are free to move at all.
func apply_recoil_velocity(walk_velocity: Vector2, delta: float) -> Vector2:
	if _tuning == null or _velocity.is_zero_approx():
		return walk_velocity
	_spend_against_walls()
	var duration := maxf(_tuning.recoil_duration, 0.0001)
	var u := clampf(_elapsed / duration, 0.0, 1.0)
	var control := lerpf(clampf(_tuning.movement_control_multiplier, 0.0, 1.0), 1.0, u)
	var result := walk_velocity * control + _velocity

	_leave_afterimage(delta)
	var damping := _tuning.recoil_damping if _elapsed < duration else _tuning.settle_damping
	_velocity *= exp(-maxf(damping, 0.0) * delta)
	_elapsed += delta
	if _elapsed >= duration and _velocity.length() < 4.0:
		_velocity = Vector2.ZERO
	return result


## Drops any recoil at once - a death or a hold pinning the player.
func clear() -> void:
	_velocity = Vector2.ZERO
	_elapsed = 0.0


## Whether a shove is carrying the player right now.
func is_recoiling() -> bool:
	return not _velocity.is_zero_approx()


func get_recoil_velocity() -> Vector2:
	return _velocity


## Whatever part of the recoil drove into a wall on the last move is gone, so the
## shove stops at the wall instead of sliding the player along it for the rest of
## its life.
func _spend_against_walls() -> void:
	if _body == null:
		return
	for i in _body.get_slide_collision_count():
		var normal := _body.get_slide_collision(i).get_normal()
		var into := _velocity.dot(normal)
		if into < 0.0:
			_velocity -= normal * into


func _leave_afterimage(delta: float) -> void:
	var speed := _velocity.length()
	if _visual == null or _body == null or speed < afterimage_min_speed:
		return
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = maxf(afterimage_interval, 0.005)
	var strength := clampf(inverse_lerp(afterimage_min_speed, maxf(afterimage_full_speed,
		afterimage_min_speed + 1.0), speed), 0.0, 1.0)
	_spawn_ghost(lerpf(0.35, 1.0, strength))


## A still copy of every visible sprite of the artwork, left where the player is
## and faded out. Put just under the player in their own parent, so it sorts and
## lights exactly as they do and is never drawn over them.
func _spawn_ghost(opacity: float) -> void:
	var parent := _body.get_parent()
	if parent == null:
		return
	var ghost := Node2D.new()
	ghost.name = "RecoilAfterimage"
	parent.add_child(ghost)
	parent.move_child(ghost, _body.get_index())
	ghost.global_position = _body.global_position
	_copy_sprites(_visual, ghost)
	ghost.modulate = Color(1, 1, 1, clampf(opacity, 0.0, 1.0))
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, maxf(afterimage_lifetime, 0.01))
	fade.tween_callback(ghost.queue_free)


func _copy_sprites(from: Node, into: Node2D) -> void:
	for child: Node in from.get_children():
		# A shadow is drawn from the body's ground position, not left in the air.
		if child is ShadowCaster:
			continue
		var sprite := child as Sprite2D
		if sprite != null and sprite.is_visible_in_tree() and sprite.texture != null:
			var copy := Sprite2D.new()
			copy.texture = sprite.texture
			copy.centered = sprite.centered
			copy.offset = sprite.offset
			copy.flip_h = sprite.flip_h
			copy.flip_v = sprite.flip_v
			copy.hframes = sprite.hframes
			copy.vframes = sprite.vframes
			copy.frame = sprite.frame
			copy.region_enabled = sprite.region_enabled
			copy.region_rect = sprite.region_rect
			copy.self_modulate = afterimage_color
			into.add_child(copy)
			copy.global_transform = sprite.global_transform
		if child is CanvasItem and (child as CanvasItem).visible:
			_copy_sprites(child, into)
