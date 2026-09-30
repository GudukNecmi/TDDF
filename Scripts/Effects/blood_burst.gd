class_name BloodBurst
extends ShotBlast
## A VOLATILE BLOOD bag going off: blood, not a bomb.
##
## [b]It is a [ShotBlast] with a different body.[/b] The damage, falloff, shove,
## stagger, camera kick, screen flash and sound are the blast's own shared code,
## so the burst is one more hit on the one damage system and every man it catches
## is struck once through his own [Hitbox]. What it looks like is its own: a dense
## core of blood, a wide spray of droplets flying every way and a thin red mist -
## no fire, no smoke, no flare of light worth the name and no scorch mark. It has
## no [member ShotBlast.gore_effect], so a man it kills dies the ordinary bloody way.
##
## How much blood and how hard it flies are the Legendary's - see
## [member VolatileBlood.blood_amount] and [member VolatileBlood.burst_force] - and
## are laid over the layers as authored, keeping their proportions.

## The layer [member blood_amount] and [member blood_force] are measured against -
## the main droplet spray. Every other layer in [member ShotBlast.burst_paths] is
## scaled by the same ratio.
@export var reference_layer_path: NodePath = ^"Spray"

## Droplets in the reference layer, set before the burst enters the tree. Below 1
## leaves every layer as authored.
var blood_amount: int = -1
## Fastest a reference-layer droplet leaves, in pixels per second. Below 0 leaves
## every layer as authored.
var blood_force: float = -1.0


func _bursts(size: float) -> void:
	var reference := get_node_or_null(reference_layer_path) as CPUParticles2D
	var amount_ratio := 1.0
	var force_ratio := 1.0
	if reference != null:
		if blood_amount > 0:
			amount_ratio = float(blood_amount) / float(maxi(reference.amount, 1))
		if blood_force >= 0.0:
			force_ratio = blood_force / maxf(reference.initial_velocity_max, 0.01)
	for path: NodePath in burst_paths:
		var layer := get_node_or_null(path) as CPUParticles2D
		if layer == null:
			continue
		layer.amount = maxi(roundi(layer.amount * amount_ratio), 1)
		layer.initial_velocity_min *= force_ratio
		layer.initial_velocity_max *= force_ratio
	super(size)
