class_name DevilsCoin
extends KillReward
## A kill with the weapon leaves one Blood Coin where the man fell - the part behind
## the DEVIL'S COIN Card (see [member RunCard.kill_reward]). Walk over it before it
## goes and it pays extra blood into the carried wallet; leave it and it fades,
## worth nothing.
##
## [b]It has no attack of its own.[/b] It fires nothing, hurts nobody, moves nobody
## and changes nothing about the shot. The whole of it is kill, coin, the walk in to
## take it, blood.
##
## [b]It is credited through the kill, never told by the weapon.[/b] It is a
## [KillReward] the Card puts on the weapons it names. Every hit a weapon lands
## carries the block it was armed from - see
## [member HitEffects.shot_stats] - and [Health] keeps the killing hit, so a dying
## man's [BloodEmitter] reads the block that killed him and hands the death here
## when it carries this part (see [method offer_kill]). A pellet, a blast it sets
## off, a HELL CHAMBER volley, a BLOOD REAPER echo - they are all rounds armed from
## the shotgun's block or a copy of it, so each can leave a coin without any of them
## being named here, and a later Legendary's kills do the same for nothing. A man
## killed by anything that was not a shot - his own dynamite, another man, the
## run's clock - carries no block and leaves none, and a removal leaves none because
## [BloodEmitter] pays nothing for one.

@export_group("Reward")
## Blood a taken coin pays straight into the carried wallet - the [code]Blood[/code]
## autoload - on top of what the kill itself spilled.
@export_range(0, 1000, 1) var blood_reward: int = 20
## Seconds the coin lies there to be taken before it starts to fade.
@export_range(0.1, 10.0, 0.05) var lifetime: float = 2.0
## How close the player's feet have to come to the coin to take it, in pixels.
@export var pickup_radius: float = 44.0

@export_group("Who")
## Only a man in this group leaves a coin. Empty - the default - allows any death the
## weapon's shots caused: a man who has thrown his hands up has already left
## [code]enemies[/code], and shooting him is still a shotgun kill that spills blood.
## A body of [member collector_group] never leaves one, whatever this says.
@export var victim_group: StringName = &""
## Only a body in this group can take one.
@export var collector_group: StringName = &"player"

@export_group("Look")
## The coin itself - see [BloodCoin].
@export var coin_scene: PackedScene
## What the coin scene is drawn at. 1 is as authored.
@export_range(0.1, 4.0, 0.05) var coin_scale: float = 1.0
## Colour the coin face is tinted.
@export var tint := Color(1.0, 0.3, 0.26)
## Colour of the glow under it.
@export var glow_color := Color(1.0, 0.08, 0.04, 0.75)
## Size of the glow, against the glow sprite as authored.
@export_range(0.0, 4.0, 0.05) var glow_scale: float = 1.0
## Pulses a second, at the start of its life.
@export_range(0.0, 10.0, 0.1) var pulse_rate: float = 2.2
## What the pulse rate has risen to by the end of its life - it beats faster as it
## runs out.
@export_range(0.5, 5.0, 0.05) var end_pulse_rate_multiplier: float = 2.2
## How far the pulse swings the glow's strength and size - 0 is a steady glow.
@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.45
## Seconds an untaken coin takes to fade out once its life is over.
@export_range(0.0, 2.0, 0.05) var fade_duration: float = 0.35

@export_group("Taken")
## One-shot burst played where a coin is taken - see [OneShotParticles]. Null plays
## none.
@export var pickup_burst: PackedScene


## Leaves a coin at [param at] for [param victim]'s death. Called by the dying man's
## [BloodEmitter] when the killing hit carried this part; returns the coin, or null
## when the victim is not one that leaves one or there is nowhere to put it.
func offer_kill(victim: Node, at: Vector2, _stats: WeaponStats) -> Node:
	if coin_scene == null:
		return null
	var container := KillReward.container_for(victim, collector_group)
	if container == null:
		return null
	if not victim_group.is_empty() and not victim.is_in_group(victim_group):
		return null
	var coin := coin_scene.instantiate() as BloodCoin
	if coin == null:
		return null
	coin.setup(self)
	container.add_child(coin)
	coin.global_position = at
	coin.reset_physics_interpolation()
	return coin


func describe_debug(tree: SceneTree) -> String:
	return "+%d BLOOD   LASTS %.1fs   ACTIVE COINS %d" % [blood_reward, lifetime,
		BloodCoin.count_active(tree)]
