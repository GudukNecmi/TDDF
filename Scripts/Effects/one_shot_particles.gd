class_name OneShotParticles
extends CPUParticles2D
## A particle burst that plays once and then removes itself.
##
## Meant to be spawned into the world at the position of whatever triggered it,
## rather than parented to it - an emitter that is scaled or spinning would
## otherwise shrink the burst and drag it around after it had gone off.
##
## Emission is NOT started on ready. These bursts run in global particle
## coordinates, so the emission point is baked in the instant emission begins:
## starting on ready would fire the whole burst at the world origin, because
## `add_child()` happens before the caller has had a chance to place the node.
## Place it first, then call [method play].


func _ready() -> void:
	emitting = false
	# Freed the moment the last particle dies. The timer is a fallback so the
	# node can never leak on a build where the signal is missing, or if `play`
	# is never called at all.
	if has_signal(&"finished"):
		connect(&"finished", queue_free)
	else:
		get_tree().create_timer(lifetime * 1.5 + 0.2).timeout.connect(queue_free)


## Starts the burst. Call this only once the effect is already sitting where it
## belongs, otherwise the particles are released from wherever it was before.
func play() -> void:
	restart()
	emitting = true
