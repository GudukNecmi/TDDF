class_name VolatileBlood
extends KillReward
## A kill with the weapon leaves one Blood Bag where the man fell - the part behind
## the shotgun's Legendary VOLATILE BLOOD. Walk through the bag or shoot it and it
## bursts: a violent spray of blood that hurts every enemy around it. Leave it and
## it fades.
##
## [b]Its whole identity is kill, bag, trigger, blood.[/b] It fires nothing, changes
## nothing about the shot, never buffs the next one and leaves no coin, explosion or
## scorch. The burst is blood, not a bomb - see [BloodBurst].
##
## [b]It is credited through the kill, never told by the weapon.[/b] It is a
## [KillReward], so a pellet, a DEVIL'S BREATH blast, a HELL CHAMBER round, a BLOOD
## REAPER echo, ONE BIG SHELL's cannon - any round armed from the weapon's block or a
## copy of it - leaves a bag with no case for any of them.
##
## [b]The burst is a shot of the same block.[/b] Its hits carry the block that left
## the bag - or the block of the round that shot it - in
## [member HitEffects.shot_stats], so a man the burst kills is a kill with the weapon
## like any other and leaves a bag of his own while this is on. There is no chain
## system: that is the shared kill attribution doing what it does for every kill,
## and [signal Health.died] firing once per death is what keeps one death from being
## offered twice.
##
## Every number is here, so the whole Legendary is tuned in one resource.

@export_group("Bag")
## The bag itself - see [BloodBag].
@export var bag_scene: PackedScene
## Seconds the bag lies there to be triggered before it starts to fade.
@export_range(0.1, 20.0, 0.05) var lifetime: float = 3.0
## Seconds an untriggered bag takes to fade out once its life is over.
@export_range(0.0, 2.0, 0.05) var fade_duration: float = 0.4
## How close the player's feet have to come to the bag to burst it, in pixels.
@export var trigger_radius: float = 30.0
## Only a body in this group bursts it by walking through it - and never leaves one.
@export var toucher_group: StringName = &"player"
## Only a man in this group leaves a bag. Empty allows any death the weapon's shots
## caused.
@export var victim_group: StringName = &""
## Whether a round that bursts the bag is spent on it. Off lets it fly on through.
@export var consumes_projectile: bool = true
## Seconds after it drops before a shot can burst it. Keeps the rest of the volley
## that made the kill - and a BLOOD REAPER echo fired from the body - from popping it
## the instant it lands. Walking through it is never delayed.
@export_range(0.0, 1.0, 0.01) var shot_arm_delay: float = 0.15

## Radius of the target a round's sweep meets, in pixels, centred where the blob
## hovers at rest. Kept apart from the blob's drawn size so reshaping the look never
## changes how easy it is to shoot.
@export var shot_radius: float = 17.0

@export_group("Blob look")
## Overall size of everything drawn - blob, globules, shadow. 1 is as tuned below.
@export_range(0.1, 4.0, 0.05) var bag_scale: float = 1.0
## Radius of the corrupted blob, in pixels - half the RECOIL DEVIL ward's 56.
@export var blob_radius: float = 28.0
## The almost black body. Its alpha is how opaque it is.
@export var core_color := Color(0.03, 0.0, 0.01, 0.94)
## The dark blood-red rim. Its alpha is the rim's strength.
@export var rim_color := Color(0.45, 0.02, 0.03, 0.95)
## Width of that rim, in pixels.
@export var rim_width: float = 6.0
## The red veins crawling through the body. Its alpha is how strongly they show.
@export var vein_color := Color(0.4, 0.01, 0.03, 0.55)
## The wet sheen on top. Its alpha is how bright it is.
@export var sheen_color := Color(0.85, 0.2, 0.18, 0.35)
## How far the blob's edge wobbles in and out, in pixels - the slime's wobble.
@export var wobble_strength: float = 2.5
## How fast that wobble, the veins and the shimmer move.
@export var wobble_speed: float = 3.0
## How many lobes wander round the edge.
@export_range(3, 9, 1) var wobble_lobes: int = 5
## How far what is behind the rim is bent, in screen pixels - the ward's shimmer.
@export_range(0.0, 8.0, 0.05) var distortion: float = 1.6
## Unstable pulses a second at the start of its life.
@export_range(0.0, 10.0, 0.1) var pulse_rate: float = 2.4
## What the pulse rate has risen to by the end of its life - it beats faster as it
## runs out.
@export_range(0.5, 5.0, 0.05) var end_pulse_rate_multiplier: float = 2.0
## How far the pulse brightens the rim and veins - 0 is steady.
@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.45

@export_group("Blob float")
## How high the blob's middle hovers above the ground at rest, in pixels.
@export var float_base_height: float = 26.0
## How far it bobs up and down about that, in pixels. Kept small.
@export var float_height: float = 2.5
## Bobs a second.
@export var float_speed: float = 0.9
## How far it squashes at the bottom of each bob and stretches at the top - 0.08
## is 8% wider and flatter.
@export_range(0.0, 0.5, 0.01) var squash_amount: float = 0.08
## Colour of the soft shadow on the ground under it. It shrinks as the blob rises.
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.35)
## Width and height of that shadow, in pixels.
@export var shadow_size := Vector2(46.0, 13.0)
## Colour of the faint glow on the ground under it, drawn additive. Kept dim so it
## reads as corruption seeping, not light.
@export var glow_color := Color(0.55, 0.02, 0.02, 0.35)
## Size of that glow, as a multiple of the blob's width.
@export_range(0.0, 4.0, 0.05) var glow_scale: float = 1.4

@export_group("Globules")
## Thick droplets of blood suspended round the blob.
@export_range(0, 16, 1) var globule_count: int = 5
## How far from the blob's middle they hang, in pixels.
@export var globule_spread: float = 38.0
## How far each one's distance wanders in and out, in pixels.
@export var globule_spread_wander: float = 5.0
## Radius of a globule, in pixels.
@export var globule_size: float = 3.6
## Share each globule's size varies by.
@export_range(0.0, 0.9, 0.01) var globule_size_variation: float = 0.4
## How fast they drift round the blob and bob on their own, in radians a second.
@export var globule_speed: float = 0.7
## How far each bobs up and down on its own, in pixels.
@export var globule_bob: float = 2.5
## A globule's colour, and the darker colour of its underside.
@export var globule_color := Color(0.5, 0.02, 0.04, 1.0)
@export var globule_dark_color := Color(0.12, 0.0, 0.01, 1.0)

@export_group("Rupture")
## Seconds the blob and its globules take to tear apart as it bursts. The burst's
## damage lands at once; this is only the blob's last frames.
@export_range(0.0, 0.3, 0.01) var rupture_time: float = 0.07
## What the blob swells to as it tears.
@export var rupture_swell: float = 1.5
## How far out the globules are flung as it tears, as a multiple of their spread.
@export var rupture_fling: float = 2.5

@export_group("Idle sound")
## A quiet wet loop the blob makes while it waits. Null is silent.
@export var idle_sound: AudioStream
@export var idle_volume_db: float = 0.0
@export var idle_pitch: float = 1.0
## Beyond this distance, in pixels, it is not heard at all.
@export var idle_max_distance: float = 420.0

@export_group("Burst")
## The blood burst set off when the bag goes - see [BloodBurst]. Its look, sound and
## camera are tuned on that scene; its damage, reach and weight here.
@export var burst_scene: PackedScene
## Damage dealt to each enemy the burst catches, in hit points.
@export var burst_damage: float = 45.0
## How far the burst reaches, in pixels.
@export var burst_radius: float = 110.0
## Share of the damage lost at the very edge. 0 hits everyone inside equally.
@export_range(0.0, 1.0, 0.01) var falloff: float = 0.45
## Shape of that falloff: 1 is linear, above 1 keeps damage up further out.
@export_range(0.1, 4.0, 0.05) var falloff_exponent: float = 1.0
## What an enemy's own authored knockback is multiplied by when caught.
@export var knockback: float = 1.3
## A shove the burst throws on its own account, outwards, in pixels per second.
@export var knockback_push: float = 80.0
## What an enemy's own authored stagger is multiplied by when caught.
@export var stagger: float = 1.3
## Seconds the burst stays live - a man stepping into it then is caught too, never
## twice.
@export var burst_lifetime: float = 0.1
## Physics layers the burst looks for enemy [Hitbox]es on. The player has none
## there, so the burst never hurts them.
@export_flags_2d_physics var hitbox_mask: int = 2
## Droplets in the main spray - see [member BloodBurst.blood_amount]. Every other
## layer of the burst grows with it.
@export_range(1, 1000, 1) var blood_amount: int = 150
## Fastest a droplet leaves, in pixels per second - see
## [member BloodBurst.blood_force]. Every other layer's speed grows with it.
@export var burst_force: float = 620.0


## Leaves a bag at [param at] for [param victim]'s death, remembering [param stats]
## - the block that killed him - so a bag burst by walking through it is still that
## shot's. Returns the bag, or null when the victim is not one that leaves one or
## there is nowhere to put it. The bag joins the scene at the end of the frame.
func offer_kill(victim: Node, at: Vector2, stats: WeaponStats) -> Node:
	if bag_scene == null:
		return null
	var container := KillReward.container_for(victim, toucher_group)
	if container == null:
		return null
	if not victim_group.is_empty() and not victim.is_in_group(victim_group):
		return null
	var bag := bag_scene.instantiate() as BloodBag
	if bag == null:
		return null
	bag.setup(self, stats, at)
	# Deferred: a death is often reported from inside a round's physics callback,
	# where a new collision area cannot join the space.
	container.add_child.call_deferred(bag)
	return bag


## Sets the burst off at [param at] in [param container], credited to [param stats]
## - see [member HitEffects.shot_stats]. Every burst is full strength: a BLOOD REAPER
## echo's weakened block still leaves a whole bag. Returns the burst, or null when
## there is no scene.
func burst(container: Node, at: Vector2, stats: WeaponStats) -> ShotBlast:
	if burst_scene == null or container == null or not container.is_inside_tree():
		return null
	var blast := burst_scene.instantiate() as ShotBlast
	if blast == null:
		return null
	var blood := blast as BloodBurst
	if blood != null:
		blood.blood_amount = blood_amount
		blood.blood_force = burst_force
	container.add_child(blast)
	blast.global_position = at
	blast.reset_physics_interpolation()
	blast.detonate(maxf(burst_damage, 0.0), maxf(burst_radius, 0.0), burst_lifetime,
		hitbox_mask, make_hit_effects(stats), falloff, falloff_exponent)
	return blast


## What the burst does beyond damage. The kill is credited to [param stats] at full
## power, so a man it kills is the weapon's kill.
func make_hit_effects(stats: WeaponStats) -> HitEffects:
	var effects := HitEffects.new()
	effects.knockback_scale = maxf(knockback, 0.0)
	effects.stagger_scale = maxf(stagger, 0.0)
	effects.knockback_push = maxf(knockback_push, 0.0)
	if stats != null:
		var credit := stats.duplicate_stats()
		credit.power_scale = 1.0
		effects.shot_stats = credit
		effects.blood_gain_scale = stats.blood_gain_scale()
	return effects


func describe_debug(tree: SceneTree) -> String:
	return "DMG %.0f   RADIUS %.0f   FALLOFF %d%%   KNOCKBACK x%.2f +%.0f   STAGGER x%.2f   LASTS %.1fs   ACTIVE BAGS %d" % [
		burst_damage, burst_radius, roundi(falloff * 100.0), knockback, knockback_push,
		stagger, lifetime, BloodBag.count_active(tree)]
