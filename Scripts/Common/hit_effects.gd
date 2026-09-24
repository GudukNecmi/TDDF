class_name HitEffects
extends RefCounted
## What one hit does to its victim beyond the damage - how hard it shoves, how
## long it slows, what the kill is worth.
##
## Handed from the attack through [method Hitbox.take_hit] into
## [method Health.take_damage], which keeps it as the last hit's effects while it
## announces the hit, so [HitReaction] and [BloodEmitter] - which only ever hear
## [signal Health.damaged] - can read it back with
## [method Health.get_last_hit_effects]. Each is a multiplier on the victim's own
## authored value, so a hit that carries none is exactly an ordinary hit.

var knockback_scale: float = 1.0
var stagger_scale: float = 1.0
var blood_gain_scale: float = 1.0
## A shove this hit throws on its own account, in pixels per second, added on top
## of the victim's scaled [member HitReaction.knockback_speed]. The one field here
## that is not a multiplier: it is what lets a hit move a victim authored to take
## no knockback at all - a boss's sword throwing the player. 0 on every ordinary
## hit.
var knockback_push: float = 0.0
