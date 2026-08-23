class_name DeathFade
extends Node
## Plays a death out instead of letting the body vanish: a hard dark-red tint,
## held for a beat, then a quick fade to nothing - and only then is the owner
## freed.
##
## It takes over the freeing from [Health], so the Health it listens to must have
## [member Health.free_owner_on_death] switched off. This node becomes the one
## thing that decides when the body actually goes.
##
## The tint is a [member CanvasItem.modulate] write, deliberately not the
## [HitFlash] shader [HitReaction] uses: the white damage flash and this must be
## able to overlap without either cancelling the other, which they do because one
## is a shader parameter and the other is a vertex colour.
##
## Everything that could still act is switched off the instant death lands -
## movement, collision and every hitbox - so a corpse in mid-fade cannot shove
## the player, block a pellet or be shot a second time.

## Health whose death this plays out.
@export var health_path: NodePath = ^"../Health"
## Sprites tinted and faded. Anything left out simply disappears with the node at
## the end, so this only needs the parts that should be *seen* dying.
@export var sprite_paths: Array[NodePath] = []

@export_group("Timing")
## Colour the body snaps to the moment it dies. Multiplied over the artwork, so a
## dark red reads as blood-soaked rather than repainted.
@export var death_tint := Color(0.5, 0.06, 0.07)
## How long it holds that colour before fading. Short - this is a punctuation
## mark, not a death animation.
@export var hold_time: float = 0.1
## How long the fade to invisible takes.
@export var fade_time: float = 0.18
## Extra delay after the fade before the node is freed. Gives anything else
## hanging off the death - blood, a burst - a frame or two to detach.
@export var linger_time: float = 0.0

@export_group("Hit flash")
## Clears [HitReaction]'s white damage flash off the sprites as the death lands.
##
## The killing hit lit them through [member HitFlash]'s shader, and the component
## that eases that back off is one of the things [method _freeze] switches off a
## line later - so without this the shader is left holding `flash = 1.0` and the
## corpse falls, lies there and fades out as a solid white silhouette with none of
## its own artwork and none of [member death_tint] visible either, since the
## shader replaces the colour it is given.
##
## Cleared rather than the freeze being narrowed, because the corpse genuinely
## must stop reacting - it is the leftover *value* that is wrong, not the freeze.
## [EnemyHeadPop] does exactly the same thing to the pieces it throws clear, for
## the same reason.
@export var clear_hit_flash: bool = true
## How long the killing blow's white is [b]held[/b] before it is cleared, in
## seconds.
##
## Clearing it on the same frame the death arrives - which is what this did
## before - wipes the flash before a single frame has been drawn with it, so the
## hit that actually kills is the one hit in the whole fight that never flashes.
## Holding it for a moment first is what makes a kill land visually: the character
## lights up, and only then does the corpse settle into its own colours.
##
## 0 restores the old behaviour exactly, clearing on the instant of death.
@export var hit_flash_hold: float = 0.09
## Name of the shader uniform holding that flash amount.
@export var hit_flash_parameter: StringName = &"flash"

@export_group("Shutdown")
## Stops the owner's movement and its components the instant it dies.
@export var freeze_owner: bool = true
## Zeroes every collision layer and mask under the owner, so the corpse stops
## colliding, stops being shootable and stops crowding other enemies.
@export var disable_collision: bool = true

@onready var _health: Health = get_node_or_null(health_path) as Health

var _sprites: Array[CanvasItem] = []
var _dying: bool = false


func _ready() -> void:
	for path: NodePath in sprite_paths:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			_sprites.append(node)

	if _health != null:
		_health.died.connect(_on_died)


func is_dying() -> bool:
	return _dying


func _on_died() -> void:
	# Guarded because a second death signal, however it arrived, must not restart
	# the fade and hand out a second queue_free.
	if _dying:
		return
	_dying = true

	var host := get_parent()
	if host == null:
		return

	# Held for a moment rather than wiped, so the blow that killed flashes like
	# every other blow before the corpse takes over. The clear still happens - it
	# is only late - which is what keeps a frozen body from lying there white.
	if clear_hit_flash:
		_hold_then_clear_hit_flash()

	if freeze_owner:
		_freeze(host)
	if disable_collision:
		_disable_collision(host)

	_play(host)


## Leaves the white up for [member hit_flash_hold] and then takes it off.
##
## The timer is a scene tree timer rather than anything on this node, because the
## corpse is frozen a line later and a node that has stopped processing cannot
## time its own recovery. It is set to run while the tree is paused for the same
## reason every other transition in the game is: a kill that lands on the frame a
## menu opens must still finish.
##
## Nothing has to guard against the corpse being freed first - a freed object's
## connections are severed with it, so the clear simply never arrives, and there
## is nothing left to be white.
func _hold_then_clear_hit_flash() -> void:
	if hit_flash_hold <= 0.0:
		_clear_hit_flash()
		return

	var timer := get_tree().create_timer(hit_flash_hold, true, false, true)
	timer.timeout.connect(_clear_hit_flash)


## The material was duplicated per character by [HitReaction], so writing to it
## reaches this body and no other. A sprite drawn without the flash shader has no
## such parameter and is simply skipped.
func _clear_hit_flash() -> void:
	for sprite: CanvasItem in _sprites:
		var material := sprite.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter(hit_flash_parameter, 0.0)


## Snapped straight to the tint, then faded. Snapping rather than easing into the
## colour is what makes the death register as a hit landing.
func _play(host: Node) -> void:
	for sprite: CanvasItem in _sprites:
		sprite.modulate = death_tint

	# Owned by this node rather than the host, so it dies with the corpse if
	# anything else frees it first.
	var tween := create_tween().set_parallel(true)
	if fade_time > 0.0:
		for sprite: CanvasItem in _sprites:
			tween.tween_property(sprite, "modulate:a", 0.0, fade_time) \
				.set_delay(hold_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.chain().tween_interval(maxf(linger_time, 0.0))
	tween.chain().tween_callback(host.queue_free)


## Silences the whole character rather than only its movement: the chase, the
## knife, the squash and the aim pivots all stop dead. `set_physics_process` on
## the body alone would leave the components running on a corpse.
func _freeze(host: Node) -> void:
	if host is Node2D:
		(host as Node2D).set_physics_process(false)
		(host as Node2D).set_process(false)
	if host is CharacterBody2D:
		(host as CharacterBody2D).velocity = Vector2.ZERO

	for child: Node in host.get_children():
		# This node has to keep processing - it is running the fade.
		if child == self:
			continue
		child.set_physics_process(false)
		child.set_process(false)


func _disable_collision(host: Node) -> void:
	if host is CollisionObject2D:
		_clear_layers(host as CollisionObject2D)
	for node: Node in host.find_children("*", "CollisionObject2D", true, false):
		_clear_layers(node as CollisionObject2D)


## Layer *and* mask, so the corpse neither collides with anything nor is found by
## anything looking for it.
##
## The monitoring flags are deferred because a death very often arrives from
## inside the physics server's own overlap callback - a pellet's `area_entered`
## reporting the hit that killed this body - and an area refuses to have its
## monitoring changed while queries are being flushed. Zeroing the layers is what
## actually stops the corpse being found, and that is allowed there; the flags
## follow a frame later and only stop it looking for anything itself.
func _clear_layers(body: CollisionObject2D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0
	if body is Area2D:
		body.set_deferred(&"monitoring", false)
		body.set_deferred(&"monitorable", false)
