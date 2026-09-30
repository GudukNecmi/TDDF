class_name KillReward
extends Resource
## Something a kill with a weapon leaves behind - the shared shape every kill-triggered
## part takes, whoever granted it: a Legendary such as VOLATILE BLOOD, a Card such as
## DEVIL'S COIN.
##
## [b]It is credited through the kill, never told by the weapon.[/b] A weapon's
## [WeaponStats] block carries every reward granted to it in
## [member WeaponStats.kill_rewards]; every hit armed from that block or a copy of it
## - a pellet, a blast it sets off, a HELL CHAMBER volley, a BLOOD REAPER echo, ONE
## BIG SHELL's cannon - carries the block in [member HitEffects.shot_stats]; and a
## dying man's [BloodEmitter] reads the killing hit's block and offers the death to
## each reward on it, once. So a reward never names a Legendary, and a later
## Legendary's kills - or a later Card's reward - need nothing added here.
##
## A death no shot caused carries no block and offers nothing; a removal offers
## nothing because [BloodEmitter] pays nothing for one.


## Leaves whatever this reward leaves for [param victim]'s death at [param at].
## [param stats] is the block the killing hit was armed from - handed on so whatever
## is left can credit its own hits to the same shot. Returns what it left, or null.
func offer_kill(_victim: Node, _at: Vector2, _stats: WeaponStats) -> Node:
	return null


## One line for the developer panel on this reward's Inspector values and how many of
## what it leaves are down in [param tree]. Empty shows nothing.
func describe_debug(_tree: SceneTree) -> String:
	return ""


## The running scene [param victim] died in - what a reward's leavings are parented
## to - or null when there is none, or the victim is not one that may leave one:
## a body of [param never_group] never does.
static func container_for(victim: Node, never_group: StringName) -> Node:
	if victim == null or not victim.is_inside_tree():
		return null
	if not never_group.is_empty() and victim.is_in_group(never_group):
		return null
	return victim.get_tree().current_scene
