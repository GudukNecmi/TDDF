class_name CannonShell
extends Projectile
## The one enormous round ONE BIG SHELL fires - see [OneBigShell].
##
## [b]It is an ordinary [Projectile] in everything but its width.[/b] It is armed,
## flown, ranged, empowered, exploded, pierced and credited exactly as a pellet is,
## off the same [WeaponStats] block, so every stat and Legendary part reaches it
## with nothing here naming them. What it changes is only what a round's shape
## changes:
##
##   * [b]What it hits.[/b] Each step is swept as a capsule of the shell's full hit
##     radius rather than as a line, and the nearest hitbox anywhere across that
##     width is the one landed on - see [method _trace].
##   * [b]What a hit is worth.[/b] Each landing is measured as its victim's
##     distance off the centre line, 0 dead centre to 1 grazing the rim, and the
##     [OneBigShell] turns that one number into the damage, the shove and its
##     direction - see [method _begin_landing].
##   * [b]Whether it stops.[/b] A graze strikes and shoves the victim and the shell
##     flies on; a hit nearer the centre stops it as it stops any round.
##
## Every landing is announced through [signal struck], with where and how centred
## it was, for the feedback - see [OneBigShellFeedback].

## Emitted once per landing, after the hit is dealt, at the point on the victim the
## shell met: [param direction] is the way the shell was flying,
## [param centrality] how near the centre line the hit was (1 dead centre, 0 the
## rim), and [param killed] whether it was fatal.
signal struck(at: Vector2, direction: Vector2, centrality: float, killed: bool)

@export_group("Shell look")
## Everything drawn that is grown by [member OneBigShell.visual_scale] - the dark
## rim, the glow, the core, the shimmer. The light's reach grows with it too.
@export var scaled_paths: Array[NodePath] = [^"Shimmer", ^"Glow", ^"Sprite2D", ^"Core"]
## The hot core, drawn additively over the dark rim. Its brightness follows the
## glow - see [member OneBigShell.glow_intensity].
@export var core_path: NodePath = ^"Core"
## HDR colour of the core at the muzzle and at the end of the range.
@export var core_color_near := Color(2.4, 1.3, 0.55, 1.0)
@export var core_color_far := Color(0.9, 0.12, 0.04, 0.6)
## The heat shimmer around the shell - a sprite whose material bends what is
## behind it. Its [code]strength[/code] parameter is driven from here.
@export var shimmer_path: NodePath = ^"Shimmer"
## Shimmer strength at the muzzle and at the end of the range, before
## [member OneBigShell.shimmer_strength].
@export var shimmer_near: float = 1.0
@export var shimmer_far: float = 0.2

@onready var _core: CanvasItem = get_node_or_null(core_path) as CanvasItem
@onready var _shimmer: CanvasItem = get_node_or_null(shimmer_path) as CanvasItem

var _shell: OneBigShell
## What a pellet's damage is multiplied by for a dead-centre hit.
var _core_factor: float = 1.0
## The landing in progress: its distance off the centre line, 0..1, and which side
## of the line the victim was on, as a unit vector. See [method _begin_landing].
var _hit_distance: float = 0.0
var _hit_side := Vector2.ZERO
var _hit_point := Vector2.ZERO
## The last hitbox [method _measure] looked at: the centre of its shapes, and their
## half width across the shell's line.
var _measured_centre := Vector2.ZERO
var _measured_half: float = 0.0


## Makes this the shell [param shell] describes, a dead-centre hit dealing
## [param core_factor] times a pellet's damage. Call before it enters the tree -
## [method OneBigShell.prepare] does.
func set_big_shell(shell: OneBigShell, core_factor: float) -> void:
	_shell = shell
	_core_factor = maxf(core_factor, 0.0)


func get_big_shell() -> OneBigShell:
	return _shell


## Half the width of what the shell hits right now, in pixels: the shell's
## radius, grown by the weapon's projectile size stat.
func get_hit_radius() -> float:
	var radius := hit_half_width if _shell == null else _shell.hit_radius
	return maxf(radius, 0.5) * (1.0 if _stats == null else _stats.size_scale())


## Damage a hit [param distance] off the centre line would deal right now, before
## the hitbox's own multiplier - what a readout or a test can ask without flying
## the shell into anybody.
func damage_at_distance(distance: float) -> float:
	var share := 1.0 if _shell == null else _shell.damage_factor(distance)
	return get_current_damage() * _core_factor * share


func _ready() -> void:
	super._ready()
	var grow := 1.0 if _shell == null else maxf(_shell.visual_scale, 0.05)
	if not is_equal_approx(grow, 1.0):
		for path: NodePath in scaled_paths:
			var drawn := get_node_or_null(path) as Node2D
			if drawn != null:
				drawn.scale *= grow
		_light_base_scale *= grow
	_apply_progress()


# --- What it hits ----------------------------------------------------------------

## The nearest victim - or deflector - anywhere across the shell's width along
## [param query]'s segment. Swept as a capsule of [method get_hit_radius] around
## the segment, on the same mask and with the same exclusions the ray would have,
## and reported the way the ray reports: the collider, and a point on the shell's
## own centre line abreast of it, so the shell stops on its own path.
##
## [b]A man is one victim however many hitboxes he has.[/b] Of the hitboxes of the
## nearest man the shell touches, the one it is best centred on is the one landed
## on - so a shell straight through his body is a body hit dead centre, not a graze
## of the head that happens to stick out into its width first.
func _trace(query: PhysicsRayQueryParameters2D) -> Dictionary:
	var from := query.from
	var to := query.to
	var travel := to - from
	var length := travel.length()
	var forward := transform.x.normalized() if length < 0.001 else travel / length
	var radius := get_hit_radius()

	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = length + radius * 2.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = capsule
	# A capsule stands along its own Y; turned so that axis runs down the flight.
	params.transform = Transform2D(forward.angle() - PI * 0.5, (from + to) * 0.5)
	params.collision_mask = query.collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = query.exclude

	var found := get_world_2d().direct_space_state.intersect_shape(params, 32)
	# Per victim: how far along the flight he is first met, and his best-centred
	# hitbox. A deflector is a victim of its own.
	var victims := {}
	for entry: Dictionary in found:
		var collider := entry.get("collider") as Node2D
		if collider == null:
			continue
		var hitbox := collider as Hitbox
		if hitbox == null and not collider.has_method(&"take_projectile_hit"):
			continue
		var victim: Node = collider if hitbox == null else _victim_of(hitbox)
		if hitbox != null and _struck.has(victim):
			continue
		var centre := collider.global_position
		var distance := 0.0
		if hitbox != null:
			distance = _distance_to(hitbox, from)
			centre = _measured_centre
		var along := (centre - from).dot(forward)
		var seen: Dictionary = victims.get(victim, {})
		if seen.is_empty():
			seen = {"along": along, "distance": distance, "collider": collider, "rid": entry.get("rid")}
		else:
			seen["along"] = minf(seen["along"], along)
			if distance < seen["distance"]:
				seen["distance"] = distance
				seen["collider"] = collider
				seen["rid"] = entry.get("rid")
		victims[victim] = seen

	var best := {}
	var best_along := INF
	for seen: Dictionary in victims.values():
		var along: float = seen["along"]
		if along < best_along:
			best_along = along
			best = {
				"collider": seen["collider"],
				"rid": seen["rid"],
				"position": from + forward * clampf(along, 0.0, length),
			}
	return best


## How far [param hitbox] sits off the shell's centre line through
## [param line_point], 0 dead centre to 1 the rim barely touching it: its shapes'
## centre off the line, over the shell's radius plus their own half width across
## it. Leaves the measurement in [member _measured_centre] and
## [member _measured_half].
func _distance_to(hitbox: Hitbox, line_point: Vector2) -> float:
	_measure(hitbox)
	var side := transform.x.normalized().orthogonal()
	var lateral := (_measured_centre - line_point).dot(side)
	return clampf(absf(lateral) / maxf(get_hit_radius() + _measured_half, 0.001), 0.0, 1.0)


## Where [param hitbox]'s shapes sit, measured off the shell's current heading:
## the centre of its shapes into [member _measured_centre], and how far they reach
## either side of that across the line into [member _measured_half]. Worked out
## from the shapes' own rectangles, so a head and a body are each measured as they
## are.
func _measure(hitbox: Hitbox) -> void:
	var side := transform.x.normalized().orthogonal()
	var low := INF
	var high := -INF
	var mid := Vector2.ZERO
	var count := 0
	for child: Node in hitbox.get_children():
		var owner_shape := child as CollisionShape2D
		if owner_shape == null or owner_shape.shape == null or owner_shape.disabled:
			continue
		var rect := owner_shape.shape.get_rect()
		var xform := owner_shape.global_transform
		for corner: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0.0),
				rect.end, rect.position + Vector2(0.0, rect.size.y)]:
			var point := xform * corner
			var across := point.dot(side)
			low = minf(low, across)
			high = maxf(high, across)
		mid += xform * rect.get_center()
		count += 1
	if count == 0:
		_measured_centre = hitbox.global_position
		_measured_half = 0.0
		return
	_measured_centre = mid / float(count)
	_measured_half = (high - low) * 0.5


# --- What a hit is worth ---------------------------------------------------------

## Measures the landing on [param hitbox]: how far its shapes' centre sits off the
## centre line, over how far off it could sit and still be touched - the shell's
## radius plus the hitbox's own half width across the line. 0 is dead centre, 1 is
## the rim barely touching.
func _begin_landing(hitbox: Hitbox) -> void:
	var side := transform.x.normalized().orthogonal()
	_hit_distance = _distance_to(hitbox, global_position)
	var lateral := (_measured_centre - global_position).dot(side)
	_hit_side = Vector2.ZERO if is_zero_approx(lateral) else side * signf(lateral)
	# The point on the victim the shell met: from the line, towards his centre, as
	# far as the shell reaches.
	_hit_point = global_position + _hit_side * minf(absf(lateral), get_hit_radius())


func _landing_damage() -> float:
	return damage_at_distance(_hit_distance)


## Along the flight at the centre, turned out towards the side the victim was
## clipped on as the hit nears the rim.
func _landing_direction() -> Vector2:
	var forward := transform.x.normalized()
	if _shell == null or _hit_side == Vector2.ZERO:
		return forward
	var turn := clampf(_shell.edge_side_push, 0.0, 1.0) * _hit_distance
	return forward.lerp(_hit_side, turn).normalized()


## The shot's own effects - the same block, so the death is credited to it - with
## the shell's shove and stagger for where it struck.
func _landing_effects() -> HitEffects:
	if _shell == null:
		return _hit_effects
	var effects := HitEffects.new()
	if _hit_effects != null:
		effects.knockback_scale = _hit_effects.knockback_scale
		effects.stagger_scale = _hit_effects.stagger_scale
		effects.blood_gain_scale = _hit_effects.blood_gain_scale
		effects.knockback_push = _hit_effects.knockback_push
		effects.shot_stats = _hit_effects.shot_stats
	var power := 1.0 if _stats == null else maxf(_stats.power_scale, 0.0)
	effects.knockback_scale *= maxf(_shell.knockback_factor(_hit_distance), 0.0)
	effects.stagger_scale *= maxf(_shell.stagger_multiplier, 0.0)
	effects.knockback_push += maxf(_shell.knockback_push, 0.0) * power
	return effects


## A fatal hit comes apart the way any round's does first - a charged shockwave's
## gore, BLOOD REAPER's execution - and, failing those, a near-centre one tears
## through the shell's own [member OneBigShell.kill_gore_effect].
func _tear_if_fatal(victim: Node, hitbox: Hitbox, damage: float, direction: Vector2,
		effects: HitEffects) -> bool:
	if super._tear_if_fatal(victim, hitbox, damage, direction, effects):
		return true
	if _shell == null or _shell.kill_gore_effect == null \
			or 1.0 - _hit_distance < _shell.gore_min_centrality:
		return false
	return Explosion.tear_if_fatal(_shell.kill_gore_effect, victim, hitbox, damage, direction,
		global_position, effects, _shell.kill_gore_requires, _shell.kill_gore_excludes,
		_critical, _on_execution)


func _end_landing(hitbox: Hitbox, victim: Node, _damage: float, _direction: Vector2) -> void:
	var killed := false
	var health: Health = null
	if is_instance_valid(hitbox):
		health = hitbox.get_node_or_null(hitbox.health_path) as Health
	if health != null:
		killed = not health.is_alive()
	elif victim == null or not is_instance_valid(victim):
		killed = true
	struck.emit(_hit_point, transform.x.normalized(), 1.0 - _hit_distance, killed)


func _graze_onward() -> bool:
	if _shell == null or not _shell.grazes(_hit_distance):
		return false
	_spent = false
	return true


# --- Range and look --------------------------------------------------------------

func _stat_range_scale() -> float:
	return super._stat_range_scale() * (1.0 if _shell == null else maxf(_shell.range_multiplier, 0.05))


func _apply_progress() -> void:
	super._apply_progress()
	var intensity := 1.0 if _shell == null else maxf(_shell.glow_intensity, 0.0)
	var progress := get_progress()
	if _glow != null:
		_glow.modulate.a = clampf(_glow.modulate.a * intensity, 0.0, 1.0)
	if _light != null:
		_light.energy *= intensity
	if _core != null:
		var core := core_color_near.lerp(core_color_far, progress)
		core.r *= intensity
		core.g *= intensity
		core.b *= intensity
		_core.modulate = core
	if _shimmer != null:
		var strength := lerpf(shimmer_near, shimmer_far, progress) \
			* (1.0 if _shell == null else maxf(_shell.shimmer_strength, 0.0))
		_shimmer.visible = strength > 0.0
		var haze := _shimmer.material as ShaderMaterial
		if haze != null:
			haze.set_shader_parameter(&"strength", strength)
