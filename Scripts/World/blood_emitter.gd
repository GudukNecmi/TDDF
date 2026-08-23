class_name BloodEmitter
extends Node
## Leaves blood behind when the owner dies.
##
## It listens to a [Health] component rather than being told by whatever landed
## the killing blow, so anything that can kill this character drops blood for
## free without knowing this component exists - the same way [HitReaction] picks
## up its hits.
##
## The two halves are deliberately different things. The permanent stain is
## handed to the shared [BloodField], where it is one instance in one draw call
## with no node, no physics and no lifetime. The splash is a short one-shot
## particle burst that frees itself. Nothing permanent is ever a particle
## system, which is what keeps a whole run's worth of kills affordable.
##
## What a kill is *worth* lives here, on the enemy, as [member blood_value] -
## not in the field, not in the magnet and not in the wallet. Those all treat a
## speck as a speck. This node is the only place that decides an Enemy1 is worth
## 30, which is what lets a future enemy be worth more without any of them
## changing.
##
## The burst is added to the running scene rather than to the owner, because
## [Health] frees the owner in the very frame this fires.

## Health component whose death this reacts to.
@export var health_path: NodePath = ^"../Health"
## Node the blood is placed at. Defaults to this component's parent.
@export var origin_path: NodePath = ^".."
## Offset from the origin to where the blood lands. A character's origin sits at
## its feet, so this lifts the splash up to body height.
@export var offset := Vector2(0, -20)

@export_group("Drop")
## How much blood this character is worth. One speck is dropped per point and
## every speck is worth exactly 1 to [BloodWallet], so this single number is both
## the drop's cash value and how many pieces it leaves on the floor - they cannot
## drift apart. Give a tougher enemy a bigger number and it drops proportionally
## more to pick up.
##
## Below 0 falls back to [member BloodField.specks_per_splash].
@export var blood_value: int = 30
## Blood left behind by every damage event that lands, before any death. 0 drops
## nothing on a hit, which is the default and what the enemies are set to.
##
## Unlike a death's blood this is never drawn to the player: it stains the floor
## and stays there for the rest of the run. That is exactly why the enemies have
## it switched off - a kill is meant to leave [i]nothing[/i] behind once its
## [member blood_value] has flowed to the player, and any amount here would sit on
## the ground next to blood that had just been collected.
##
## It is kept as a system rather than deleted because it is still the right tool
## for a character that is meant to bleed where it stands: the player uses it for
## their own trail, and switching an enemy back on is one number in the inspector.
##
## It is deliberately separate from [member blood_value]: wounding and dying are
## worth different amounts, and the player - who has no death drop at all - only
## ever uses this one.
@export var damage_blood_value: int = 0
## Drags the stain along the direction the killing blow was travelling, so blood
## sprays away from the shot instead of pooling symmetrically.
@export var use_hit_direction: bool = true
## Whether a death's blood is *thrown* rather than stamped straight down.
##
## On, it is handed to [BloodSpray], which blasts it out the far side of the body
## along the hit, arcs it through the air, and stains the floor where each piece
## comes down - so the shot visibly sprays the blood rather than the blood having
## always been there. What lands is an ordinary permanent speck either way, and
## the amount is identical, so the collector cannot tell the difference.
##
## Off - or in a world with no spray node - the blood is stamped immediately, which
## is exactly what it did before.
@export var throw_death_blood: bool = true

@export_group("Burst")
## Short-lived spray played at the death point. Optional - the stain is the part
## that matters and reads fine on its own.
##
## The burst is the *impact*: the shot arrives, and the blood is thrown out the
## far side of the body along the way the damage was travelling. It is short and
## hard on purpose, because it is standing in for a force rather than for a
## quantity - the quantity is the stain, which lands underneath it and stays.
@export var burst_scene: PackedScene
## Speed the blood is thrown at. This is the whole of "how hard did that hit".
@export var burst_force: float = 620.0
## How much faster or slower individual pieces leave, as a fraction, so the spray
## has a leading edge instead of moving as one wall.
@export_range(0.0, 1.0) var burst_force_variation: float = 0.6
## Total angle the spray covers, in degrees. Narrow reads as a jet, wide as a
## cloud.
@export var burst_spread_degrees: float = 42.0
## Pieces in one burst. Kept modest now that the collectable blood is thrown as
## well: this is the mist of the impact, and the arcing specks are the substance.
@export var burst_count: int = 22
## How long they last. Short - the burst is a blow landing, not a fountain.
@export var burst_lifetime: float = 0.26
@export var burst_scale_min: float = 1.8
@export var burst_scale_max: float = 5.0
## How much the spray follows the hit. 1 throws it all straight out the far side;
## 0 sprays evenly in every direction, as an unattributed death does. Between the
## two the direction is a lean rather than a rule.
@export_range(0.0, 1.0) var burst_directional_influence: float = 1.0
## Whether these settings are written onto the burst at all. Off leaves the burst
## scene entirely as authored, which is what it did before.
@export var burst_overrides_scene: bool = true
## Whether a character taken off the board by [method Health.remove] still plays
## the burst.
##
## Off, because the burst is blood as much as the stain is, and a removal is worth
## no blood at all - and because the burst is an *impact*, which a body that was
## cleared off the field rather than shot never took. Turn it on if the run's clock
## should still throw a spray as each enemy goes.
@export var burst_on_removal: bool = false

@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _origin: Node2D = get_node_or_null(origin_path) as Node2D

var _last_hit_direction := Vector2.ZERO


func _ready() -> void:
	if _health == null:
		return
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


## The direction is remembered as well as used, because [signal Health.died]
## carries none of its own - the last hit to land is the one that killed.
##
## A hit absorbed by an invulnerability window never reaches here at all, since
## [Health] drops it before emitting, so a player mid-grace leaves no blood.
func _on_damaged(_amount: float, hit_direction: Vector2) -> void:
	if not hit_direction.is_zero_approx():
		_last_hit_direction = hit_direction.normalized()

	if damage_blood_value <= 0 or _origin == null or _is_removal():
		return

	var field := BloodField.get_active(self)
	if field != null:
		field.add_splash(
			_origin.global_position + offset,
			damage_blood_value,
			hit_direction if use_hit_direction else Vector2.ZERO)


## A character that was [i]removed[/i] rather than killed spills nothing at all -
## no stain, no thrown blood, and no burst.
##
## This is the whole of the difference between the two endings. The removal still
## plays out identically in every other respect, because [method Health.remove]
## runs the very same death; it is only worth nothing, because the player did not
## earn it. The run's clock clearing the arena is the case this exists for: those
## enemies are taken off the field rather than beaten, so a run cannot be farmed
## by standing still and letting the timer kill everything.
func _on_died() -> void:
	if _origin == null:
		return

	var at := _origin.global_position + offset
	var direction := _last_hit_direction if use_hit_direction else Vector2.ZERO

	if _is_removal():
		if burst_on_removal:
			_spawn_burst(at, direction)
		return

	_drop_blood(at, direction)
	_spawn_burst(at, direction)


## Whether the death currently being reported was a removal. A character with no
## [Health] to ask - nothing in the game, but this component does not require one -
## is treated as having died normally, so the drop is never lost to a missing
## reference.
func _is_removal() -> bool:
	return _health != null and _health.was_removed()


## The death's blood, thrown if there is anything to throw it and spilled where it
## fell if not.
##
## Every path spills exactly [member blood_value] worth, so how a kill is drawn
## can be changed - or switched off entirely - without changing what it is worth
## to the player.
##
## Thrown blood is offered to [BloodMagnet] by [BloodSpray] as each piece lands.
## Unthrown blood is offered here instead, piece by piece and scattered by the
## field's own splash shape, so turning [member throw_death_blood] off changes
## what a death looks like and never whether its blood comes back to the player.
func _drop_blood(at: Vector2, direction: Vector2) -> void:
	var field := BloodField.get_active(self)
	if field == null:
		return

	# Resolved here rather than in any branch, so "below 0 means the field
	# decides" holds whichever way the blood is delivered.
	var count := blood_value if blood_value >= 0 else field.specks_per_splash
	if count <= 0:
		return

	if throw_death_blood:
		var spray := BloodSpray.get_active(self)
		if spray != null:
			spray.launch(at, count, direction)
			return

	var magnet := BloodMagnet.get_active(self)
	if magnet == null:
		field.add_splash(at, count, direction)
		return

	# Anything the magnet will not take stains the floor instead, in one call, so
	# a full stream costs the player nothing and never quietly loses a kill's
	# worth of blood.
	var left := 0
	for i: int in count:
		if not magnet.absorb(field.make_splash_speck(at, direction)):
			left += 1
	if left > 0:
		field.add_splash(at, left, direction)


## Parented to the running scene, not to the owner: the owner is about to be
## freed, and these bursts emit in global particle space, so they have to be
## standing where they belong before emission starts.
func _spawn_burst(at: Vector2, direction: Vector2) -> void:
	var container := get_tree().current_scene
	if burst_scene == null or container == null:
		return

	var burst := burst_scene.instantiate() as Node2D
	if burst == null:
		return

	container.add_child(burst)
	burst.global_position = at
	# Aimed along the way the damage was travelling, so the blood leaves out the
	# far side of the body rather than back at whoever fired. A death with no
	# recorded direction sprays somewhere random instead, so unattributed kills do
	# not all look identical.
	burst.global_rotation = direction.angle() if not direction.is_zero_approx() else randf() * TAU
	burst.reset_physics_interpolation()

	# Written before emission starts: a one-shot burst reads its counts, speeds
	# and spread when it begins, so a change afterwards would only reach the next
	# one - and there is no next one.
	_shape_burst(burst as CPUParticles2D, not direction.is_zero_approx())

	if burst.has_method(&"play"):
		burst.play()
	elif burst is CPUParticles2D:
		(burst as CPUParticles2D).emitting = true


## Pushes the exported burst settings onto the instance.
##
## [member burst_directional_influence] is applied as a widening rather than as a
## branch: at 1 the spray keeps its authored cone and all of it goes the way the
## shot went; at 0 the cone is opened to a full circle, which *is* "no direction"
## - the aim above stops meaning anything once the spray covers every angle. That
## keeps one code path for a directed hit and an unattributed one, and makes every
## value between the two a real setting rather than a special case.
##
## A death that recorded no direction at all is always sprayed evenly, whatever
## the influence is set to, since there is nothing for it to lean towards.
func _shape_burst(burst: CPUParticles2D, directed: bool) -> void:
	if burst == null or not burst_overrides_scene:
		return

	var lean := burst_directional_influence if directed else 0.0
	burst.amount = maxi(burst_count, 1)
	burst.lifetime = maxf(burst_lifetime, 0.01)
	burst.spread = lerpf(180.0, maxf(burst_spread_degrees, 0.0) * 0.5, lean)
	burst.initial_velocity_min = burst_force * (1.0 - clampf(burst_force_variation, 0.0, 1.0))
	burst.initial_velocity_max = burst_force
	burst.scale_amount_min = burst_scale_min
	burst.scale_amount_max = burst_scale_max
