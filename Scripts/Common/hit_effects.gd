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
## The shot state this hit was armed from - the firing weapon's whole
## [WeaponStats] block, Legendary parts included - or null for a hit no weapon
## shot fired: an enemy's blow, a bomber's own blast, the run's clock. It is what a
## death is credited to: whatever landed the killing hit, a pellet, a blast it set
## off or a volley copied from it, carries the block it came from, so a kill reward
## such as [DevilsCoin] reads the killer's block here rather than being told who
## fired.
var shot_stats: WeaponStats
