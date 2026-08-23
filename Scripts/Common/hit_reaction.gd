class_name HitReaction
extends Node
## Flash, knockback and a brief slow whenever the owner takes damage.
##
## It listens to a [Health] component rather than being driven by whatever dealt
## the damage, so anything that can hurt this character - the shotgun today,
## anything else later - gets the reaction for free without knowing it exists.
##
## It never writes to the body. Movement code asks it for [method get_knockback]
## and [method get_speed_multiplier] and folds those into whatever steering it
## already does, so the character keeps control of its own movement rules and
## its base speed is never modified.

## Health component whose hits are reacted to.
@export var health_path: NodePath = ^"../Health"
## Sprites tinted on a hit. Each needs a ShaderMaterial running
## hit_flash.gdshader; anything else is skipped.
@export var flash_paths: Array[NodePath] = []

@export_group("Flash")
## How long the tint stays on. Very short - it should register, not linger.
@export var flash_time: float = 0.08
@export var flash_color := Color(1.0, 1.0, 1.0, 1.0)

@export_group("Knockback")
## Speed of the shove, in pixels per second. A nudge, not a launch.
@export var knockback_speed: float = 150.0
## How quickly the shove dies away. Higher settles sooner.
@export var knockback_decay: float = 14.0

@export_group("Slow")
## How long the character stays slowed after a hit.
@export var slow_duration: float = 0.2
## Fraction of normal speed at the instant of the hit.
@export var slow_multiplier: float = 0.35

@onready var _health: Health = get_node_or_null(health_path) as Health

var _knockback := Vector2.ZERO
var _slow_left: float = 0.0
var _flash_left: float = 0.0
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_collect_materials()
	_set_flash(0.0)
	if _health != null:
		_health.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	if _knockback != Vector2.ZERO:
		_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-knockback_decay * delta))
		if _knockback.length() < 1.0:
			_knockback = Vector2.ZERO

	if _slow_left > 0.0:
		_slow_left = maxf(_slow_left - delta, 0.0)

	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		if _flash_left <= 0.0:
			_set_flash(0.0)


## Current shove in pixels per second, for the mover to add to its velocity.
func get_knockback() -> Vector2:
	return _knockback


## What the character's normal speed should be multiplied by right now: it dips
## to [member slow_multiplier] on the hit and eases smoothly back to 1 across
## [member slow_duration]. The character's own speed value is never written to,
## so nothing about it is permanently changed.
func get_speed_multiplier() -> float:
	if _slow_left <= 0.0 or slow_duration <= 0.0:
		return 1.0

	var recovered := 1.0 - (_slow_left / slow_duration)
	return lerpf(slow_multiplier, 1.0, smoothstep(0.0, 1.0, recovered))


func is_reacting() -> bool:
	return _slow_left > 0.0 or _knockback != Vector2.ZERO


## The per-character materials this reaction owns, for anything else that has to
## write a shader parameter on the same sprites.
##
## [b]It exists so that there is only ever one set of duplicates.[/b] The flash
## works by duplicating the scene's shared material per character - see
## [method _collect_materials] - and anything that duplicated them a second time
## would leave this holding materials the sprites no longer use, silently killing
## the flash. So the outline on a [MiniBoss] is written onto exactly these
## materials rather than onto materials of its own.
func get_flash_materials() -> Array[ShaderMaterial]:
	return _materials


## Every part of the reaction is *reset* rather than accumulated, so however
## fast the hits arrive the shove cannot build up, the slow cannot deepen or
## stretch beyond one window, and the flash cannot latch on. That is what keeps
## a shotgun's worth of pellets landing at once from wrecking the movement.
func _on_damaged(_amount: float, hit_direction: Vector2) -> void:
	if not hit_direction.is_zero_approx():
		_knockback = hit_direction.normalized() * knockback_speed

	_slow_left = slow_duration
	_flash_left = flash_time
	_set_flash(1.0)


func _collect_materials() -> void:
	for path: NodePath in flash_paths:
		var node := get_node_or_null(path) as CanvasItem
		if node == null:
			continue

		var shared := node.material as ShaderMaterial
		if shared == null:
			continue

		# Duplicated per character. Sprites in a scene share one material
		# resource, so without this every enemy in the arena would flash
		# whenever any single one of them was shot.
		var own := shared.duplicate() as ShaderMaterial
		own.set_shader_parameter(&"flash_color", flash_color)
		node.material = own
		_materials.append(own)


func _set_flash(amount: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"flash", amount)
