class_name FollowingParticles
extends CPUParticles2D
## A particle stream that lives in the world and follows something moving - a
## trail left behind a projectile.
##
## [b]It is not parented to what it follows.[/b] It sits in the scene and copies
## its source's position every physics tick, emitting in global coordinates, so
## the particles stay where they were shed. When the source is gone it stops
## emitting, lets what it has already shed die out, and removes itself - so a
## round that hits something does not take its trail with it in the same frame.
##
## How it looks is the [CPUParticles2D]'s own inspector fields; this file owns only
## the following and the clean-up.

var _source: Node2D
var _stopping: bool = false


func _ready() -> void:
	# Global so what has been shed stays put while the emitter moves on.
	local_coords = false
	# After the projectile has moved this tick.
	process_physics_priority = 10
	emitting = false


## Starts trailing [param source], with every particle grown by [param size_scale].
## Call once it has been placed, so the first particles leave from where it really
## is.
func follow(source: Node2D, size_scale: float = 1.0) -> void:
	_source = source
	scale_amount_min *= size_scale
	scale_amount_max *= size_scale
	if source == null:
		_stop()
		return
	global_position = source.global_position
	restart()
	emitting = true


func _physics_process(_delta: float) -> void:
	if _stopping:
		return
	if _source == null or not is_instance_valid(_source) or not _source.is_inside_tree() \
			or not _source.visible:
		_stop()
		return
	global_position = _source.global_position


func _stop() -> void:
	if _stopping:
		return
	_stopping = true
	_source = null
	emitting = false
	get_tree().create_timer(lifetime + 0.1, false).timeout.connect(queue_free)
