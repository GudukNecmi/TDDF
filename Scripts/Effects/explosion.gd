class_name Explosion
extends Node2D
## A blast: the flare, the flash of light, the gore, the blood, the smoke and the
## scorch mark left behind.
##
## [b]It belongs to nothing in particular.[/b] A bomber's fuse spawns one - see
## [BomberFuse] - but nothing in here knows what a bomber is, so the same scene can
## later be hung on a barrel, a keg or a thrown stick of dynamite by pointing
## something else at it.
##
## [b]Every part of it is a system the game already had.[/b] The gore is thrown by
## [DeathDebris], the same arithmetic a severed head rolls on; the blood is handed
## to [BloodSpray], so it arcs, lands, and is drawn to the player by [BloodMagnet]
## exactly as a kill's blood is; the flash is a [PointLight2D] and therefore lights
## the sand and the men standing on it through the world's own lighting rather than
## being a white rectangle over the top of them; and the smoke is an ordinary
## [OneShotParticles] burst. There is no new effect infrastructure here at all -
## only the timings, which are all in the inspector.
##
## Place it, then call [method play], for the same reason a particle burst is
## started after being placed: everything is measured from where it is standing at
## the moment it goes off.

## Emitted as it goes off.
signal exploded(at: Vector2)

## Goes off by itself the frame it enters the tree. Off by default, because the
## thing that spawns one normally wants to place it first.
@export var play_on_ready: bool = false

@export_group("Boom")
## The flare sprite - the [code]Boom[/code] artwork.
@export var boom_path: NodePath = ^"Boom"
## How long it is up for, in seconds.
@export var boom_seconds: float = 0.3
## What it is drawn at, before the punch below.
@export var boom_scale: float = 0.24
## How much larger it swells over its life. 1 leaves it a fixed size.
@export var boom_growth: float = 1.35
## Colour the flare is drawn in. Above 1 on a channel burns brighter than the
## artwork itself, which is the "stronger visual emphasis" the flare is asked for -
## it is the same picture, lit harder, not a different picture.
@export var boom_modulate := Color(1.7, 1.45, 1.15, 1.0)

@export_group("Flash")
## The light thrown on everything standing nearby.
@export var flash_path: NodePath = ^"Flash"
## How long it lasts. Very short on purpose: a flare and then nothing.
@export var flash_seconds: float = 0.2
## Its colour. Deliberately a dark yellow-orange rather than white - a white flash
## reads as a camera effect, an orange one reads as fire.
@export var flash_colour := Color(0.95, 0.55, 0.14)
## How hard it burns at its peak.
@export var flash_energy: float = 3.6
## How far it reaches, as a multiple of the light texture's own size.
@export var flash_texture_scale: float = 3.2

@export_group("Mark")
## The scorch left on the ground. It lies flat and never turns.
@export var mark_path: NodePath = ^"Mark"
## How long it lies at full strength before it starts to go, in seconds: the first
## figure for a blast of [member mark_radius_range].x reach or less, the second for
## one of .y or more, interpolated between - a bigger blast scorches for longer.
## The reach is the blast's own - see [method get_reach].
@export var mark_seconds_range := Vector2(4.0, 10.0)
@export var mark_radius_range := Vector2(40.0, 160.0)
## How long it then takes to disappear.
@export var mark_fade: float = 0.9
## How wide it is drawn, as a multiple of the blast's diameter - 1 covers exactly
## the ground the blast reached. Measured off the artwork's own width, so a new
## scorch picture is sized the same way.
@export var mark_coverage: float = 0.6
## How much its size varies from one blast to the next, as a fraction, so two
## explosions in the same spot do not stamp the same mark twice.
@export_range(0.0, 0.9) var mark_scale_variation: float = 0.18
## How dark it is. The artwork is black, so this is where a scorch is turned into
## a smear.
@export var mark_modulate := Color(0.12, 0.09, 0.08, 0.72)

@export_group("Boom ripple")
## Further, smaller copies of the [code]Boom[/code] flare burst around the main one
## so the blast reads as a blast rather than one sprite. 0 is the main flare only.
@export var extra_booms: int = 3
## How far from the centre they burst, as a fraction of the blast's reach.
@export_range(0.0, 1.5, 0.01) var extra_boom_spread: float = 0.55
## Their size against the main flare's, rolled between the two.
@export var extra_boom_scale := Vector2(0.4, 0.7)
## How long after the main flare each further one goes, in seconds, one after
## another - a ripple rather than one frame.
@export var extra_boom_delay: float = 0.04
## Most blasts inside [member crowd_window] seconds that get the ripple. Past it -
## a chain of bombers going up together - a blast keeps its one flare, so the pile
## stays readable. 0 or below never thins.
@export var crowd_budget: int = 3
@export var crowd_window: float = 0.3

@export_group("Blast throw")
## Whether a man this blast kills is thrown apart - his body and his head flung
## outwards from the centre as two pieces - rather than torn into gore where he
## stood. Needs his [EnemyHeadPop]; a man without one is torn apart as before.
## Only a real blast throws: [method tear_apart] and a hit's kill never do.
@export var throws_bodies: bool = true
## How fast the body leaves, outwards along the ground, in pixels per second -
## rolled between the two.
@export var body_throw_force := Vector2(260.0, 420.0)
## How hard it is thrown upwards on top of that.
@export var body_throw_lift := Vector2(160.0, 300.0)
## How fast the head leaves, and its lift - lighter, so it flies further.
@export var head_throw_force := Vector2(340.0, 560.0)
@export var head_throw_lift := Vector2(300.0, 520.0)
## How far the head's path is turned away from the body's, in degrees either side,
## so the two separate in the air rather than flying as one.
@export var head_separation_degrees: float = 28.0
## Random turn on the whole throw, in degrees either side, so men standing
## together do not fly identically.
@export var throw_angle_jitter_degrees: float = 18.0
## How much of the throw is kept by a man at the very edge of the blast rather
## than at its centre. 1 throws everybody alike.
@export_range(0.0, 1.0, 0.01) var throw_edge_scale: float = 0.55
## How much of the outward speed that points up or down the screen is kept -
## the floor is foreshortened, so a throw along it reads further than one across.
@export_range(0.0, 1.0, 0.01) var throw_depth_scale: float = 0.6
## Outward push added to the gore pieces thrown with him, in pixels per second.
@export var gore_outward_push: float = 180.0

@export_group("Smoke")
## The rising puff. Purely visual, no collision, and it frees itself.
@export var smoke_path: NodePath = ^"Smoke"
## Puff artwork one is picked from per blast, so no two explosions smoke alike.
@export var smoke_textures: Array[Texture2D] = []

@export_group("Gore")
## Pieces one is picked from at random, per piece.
@export var gore_textures: Array[Texture2D] = []
## How many are thrown, rolled between the two.
@export var gore_count := Vector2i(7, 10)
## How hard they are thrown sideways, in pixels per second.
@export var gore_speed := Vector2(90.0, 320.0)
## How hard they are thrown upwards on top of that.
@export var gore_lift := Vector2(180.0, 420.0)
## How far below the blast a piece's ground is, so they land around it rather than
## on top of it.
@export var gore_drop := Vector2(18.0, 64.0)
## What a piece is drawn at.
@export var gore_scale := Vector2(0.16, 0.28)
## How long a piece lies still before it goes. The brief's four seconds.
@export var gore_settle_time: float = 4.0
## How long it then takes to fade out.
@export var gore_fade_time: float = 0.5
## Downward pull on a piece while it is in the air.
@export var gore_gravity: float = 1500.0
## How much speed a bounce keeps.
@export_range(0.0, 1.0) var gore_bounce: float = 0.36
## How quickly a piece stops sliding once it is down.
@export var gore_ground_friction: float = 2.4
## How far the pieces are also thrown up or down the screen, as a share of their
## sideways speed, rolled either way per piece. 0 throws them only sideways, as a
## flat spray; 1 scatters them evenly in every direction across the floor.
@export_range(0.0, 1.5, 0.01) var gore_depth_spread: float = 0.0
## Whether a man killed by this blast is torn into the same gore where he stood,
## instead of dying the way a shot kills him.
##
## [b]It is the same throw, at a second place.[/b] Nothing new is built for it -
## [method _throw_gore] already takes the point it happens at, so a victim simply
## gets a burst of his own - and his own [EnemyHeadPop] is called off for that one
## death so the body does not also come apart in the ordinary way on top of it.
## Everything else about dying is untouched: he still bleeds, still counts, and
## still pays out exactly what he was worth.
@export var gore_kills: bool = true
## Where on a victim the pieces come from, measured from his origin at his feet.
@export var gore_body_offset := Vector2(0.0, -26.0)
## Whether the body is taken away as it comes apart. On - the gore is the death, so
## a corpse lying underneath it would read as a man who survived being torn up.
@export var gore_removes_body: bool = true
## The recordings a piece of gore makes as it hits the ground, one picked at
## random per landing.
##
## [b]A list rather than a named sound, and it is played through this explosion's
## own [SoundBank].[/b] The bank's bus, level and every one of its positional
## fields are the ones the blast itself is heard through - see
## [method SoundBank.play_detached_stream_at] - so a lump landing off the side of
## the screen sits in the world exactly as the boom does, and adding a recording is
## dropping a file into this array.
##
## The voice is detached, which is what lets a piece still be heard landing long
## after the explosion that threw it has cleaned itself up.
##
## Left empty the gore lands silently, which is the sound switched off rather than
## a broken blast.
@export var gore_impact_sounds: Array[AudioStream] = []
## How wide the pitch is thrown about per landing, as a multiplier picked between
## the two.
##
## [b]Deliberately far wider than the bank's own spread.[/b] Eight or ten pieces
## come down inside about a second of each other, and at the bank's usual few
## percent that reads as one sound stuttering. Spread across most of an octave each
## impact instead reads as a different lump of a different size, which is the whole
## effect.
@export var gore_impact_pitch := Vector2(0.6, 1.6)
## Level the impacts sit at against the rest of the bank, in decibels. Under the
## boom, because there are a lot of them.
@export var gore_impact_volume_db: float = -5.0
## Below this landing speed a piece is considered to have been dropped rather than
## thrown, and makes no noise. In pixels per second.
@export var gore_impact_min_speed: float = 40.0
## Whether the bounces after the first landing are heard as well as the landing
## itself. Off: one piece is one impact, so a spray of gore is as many sounds as
## there are pieces rather than three times that.
@export var gore_impact_on_bounce: bool = false

@export_group("Blood")
## How much blood the blast scatters. [b]This is the explosion's blood, and it is
## deliberately not a death's blood[/b] - a bomber killed before it lit itself
## bleeds through its own [BloodEmitter] like any other enemy, and never comes
## through here.
##
## Every speck is worth exactly 1 to [BloodWallet] and lands as an ordinary
## collectable piece, because it is thrown by the same [BloodSpray] a kill's is.
@export var blood_count: int = 30

@export_group("Damage")
## What standing in the blast costs, in hearts. 0 makes the explosion cosmetic.
@export var damage: float = 2.0
## How far the damage reaches, in pixels.
@export var damage_radius: float = 110.0
## Group the player's own pool is found in - the world's own group, the same one
## every other system follows them by.
@export var damage_group: StringName = &"player_health"
## What standing in the blast costs a man, in hit points.
##
## [b]It is deliberately a different number from the player's.[/b] The two pools
## are not in the same units - the player is measured in hearts and an enemy in
## hundreds - so one figure could not serve both without one of the two being
## nonsense. 0 leaves the blast harmless to the men in it, which is what it was
## before.
@export var enemy_damage: float = 600.0
## How far that reaches, in pixels. Below 0 uses [member damage_radius], so the
## blast is one size by default and there is no second figure to keep in step.
@export var enemy_damage_radius: float = -1.0
## Group the men are found in.
@export var enemy_group: StringName = &"enemies"
## Whether a bomber caught in this blast goes off with it rather than being damaged
## by it.
##
## [b]This is the chain, and it is the whole of it.[/b] Anything in the blast
## carrying a [BomberFuse] is asked to detonate immediately - see
## [method BomberFuse.chain_detonate] - lit or unlit, walking or lying down, so a
## group of bombers standing together goes up as one thing rather than as a queue
## of three-second timers. Each of those detonations is an ordinary [Explosion] and
## chains again out of itself, and each bomber can only go off once, so the whole
## thing settles on the frame it started.
##
## Off, a bomber in the blast is damaged like anybody else.
@export var chains_bombers: bool = true

@export_group("Sound")
## The voices the blast is heard through - its own child, so an explosion carries
## its sound with it and nothing outside has to be wired up when one is spawned.
@export var sound_bank_path: NodePath = ^"SoundBank"
## Which sound in the bank is the blast. Left unfilled in the bank the explosion
## is silent, which is an explosion with its sound switched off rather than a
## broken one.
@export var sound_name: StringName = &"explosion"
## Level this sits at against the rest of its bank, in decibels.
@export var sound_volume_db: float = 0.0

@export_group("Camera")
## How hard the camera is knocked, in pixels. Deliberately heavier than a shot or
## a hit - see [member CameraController.shake] - because this is the loudest thing
## that happens in a wave and it has to land as such.
@export var shake_strength: float = 34.0
## How long the knock lasts, in seconds. Short: the shake is a punch, not a
## rumble, and the falloff takes most of it away in the first third of that.
@export var shake_duration: float = 0.3

var _played: bool = false
## Bodies this blast will not touch. Only ever the one that produced it.
var _spared: Array[Node] = []

## Shared by every blast, so a chain is counted across all of them - see
## [member crowd_budget].
static var _crowd_start_ms: int = -100000
static var _crowd_count: int = 0


func _ready() -> void:
	# Nothing is shown until it goes off, so an explosion that is placed one frame
	# and played the next does not sit there as a still picture in between.
	_hide_parts()
	if play_on_ready:
		play()


## Sets it off. Everything happens on this one frame except the fades, which are
## the only things that take any time.
func play() -> void:
	if _played:
		return
	_played = true

	var at := global_position
	var reach := get_reach()
	_flare()
	if not _join_crowd():
		_extra_flares(reach)
	_flash()
	var mark_life := _mark_for(reach)
	_smoke()
	_throw_gore(at)
	_scatter_blood(at)
	_hurt(at)
	_hurt_the_men(at)
	_sound(at)
	_shake_camera()
	exploded.emit(at)

	# The node itself lives exactly as long as the longest thing hanging off it.
	# The gore and the blood have already left - they own themselves - so this is
	# the mark's life and nothing else's.
	var life := maxf(mark_life + mark_fade, maxf(flash_seconds, boom_seconds
		+ extra_boom_delay * float(maxi(extra_booms, 0)))) + 1.0
	var timer := get_tree().create_timer(life, true, false, true)
	timer.timeout.connect(queue_free)


## How far this blast reaches the men in it, in pixels - its size, and what its
## scorch and ripple are measured from.
func get_reach() -> float:
	return maxf(damage_radius if enemy_damage_radius < 0.0 else enemy_damage_radius, 1.0)


## Counts one blast into the crowd and reports whether it is past the budget.
func _join_crowd() -> bool:
	var now := Time.get_ticks_msec()
	if now - _crowd_start_ms > int(crowd_window * 1000.0):
		_crowd_start_ms = now
		_crowd_count = 0
	_crowd_count += 1
	return crowd_budget > 0 and _crowd_count > crowd_budget


## The ripple of smaller flares around the main one - copies of the same
## [code]Boom[/code] sprite, played through the same [method _flare_sprite].
func _extra_flares(reach: float) -> void:
	var boom := get_node_or_null(boom_path) as Sprite2D
	if boom == null:
		return
	for i: int in maxi(extra_booms, 0):
		var extra := boom.duplicate() as Sprite2D
		add_child(extra)
		extra.position = boom.position + Vector2.from_angle(randf() * TAU) \
			* reach * extra_boom_spread * randf_range(0.5, 1.0)
		var size_roll := randf_range(minf(extra_boom_scale.x, extra_boom_scale.y),
			maxf(extra_boom_scale.x, extra_boom_scale.y))
		_flare_sprite(extra, boom_scale * size_roll, extra_boom_delay * float(i + 1))


## The scorch for a blast of [param reach]: [member mark_coverage] of its diameter,
## lying for its share of [member mark_seconds_range]. Returns how long it lies.
func _mark_for(reach: float) -> float:
	var small := minf(mark_radius_range.x, mark_radius_range.y)
	var large := maxf(mark_radius_range.x, mark_radius_range.y)
	var t := 1.0 if large <= small else clampf((reach - small) / (large - small), 0.0, 1.0)
	var seconds := maxf(lerpf(mark_seconds_range.x, mark_seconds_range.y, t), 0.0)
	var mark := get_node_or_null(mark_path) as Sprite2D
	if mark == null or mark.texture == null:
		return 0.0
	_mark(reach * 2.0 * maxf(mark_coverage, 0.0) / float(mark.texture.get_width()), seconds)
	return seconds


## Kills [param body] and tears him into this explosion's gore where he stands,
## with none of the blast: no flare, no light, no scorch, no smoke, no blood
## spray of its own and nobody else hurt. Reports whether it happened.
##
## [b]It is the gore a blast kill already gets, asked for on its own[/b] - see
## [method _hurt_the_man]. The ordinary death is called off, the man dies through
## his own [Health] (so he still bleeds, counts and pays what he was worth), the
## pieces are the same [member gore_textures] thrown by [method _throw_gore], and
## the same [member gore_impact_sounds] are heard as he comes apart and again as
## each piece lands. A boss's sword going through a man is the caller today.
##
## Place the scene anywhere in the world first; it moves itself onto him. It is
## spent by this exactly as [method play] spends it, and frees itself once the
## last piece has had time to land.
func tear_apart(body: Node2D, hit_direction: Vector2 = Vector2.ZERO) -> bool:
	if _played or body == null or not is_instance_valid(body) or not is_inside_tree():
		return false
	_played = true

	var at := body.global_position + gore_body_offset
	global_position = body.global_position

	var health := _find_health(body)
	if health != null and health.is_alive():
		_call_off_the_ordinary_death(body)
		health.kill(hit_direction)

	_finish_tearing(body, at)
	return true


## [method tear_apart] for a man a hit is about to kill, rather than one killed
## here: the hit lands through [param hitbox] like any other - its damage number,
## its [HitEffects], and the blood and payout his own death gives - and he comes
## apart into this scene's gore because it was that hit which killed him. Reports
## whether it did.
##
## Call it only for a hit already known to be fatal. The ordinary death is called
## off before the hit lands, because [signal Health.died] arrives from inside it.
## A DEVIL'S BREATH blast is the caller - see [member ShotBlast.gore_effect] - and
## a charged HELL CHAMBER pellet - see [member ShotExplosion.kill_gore_effect]; both
## go through [method tear_if_fatal]. [param critical] is carried onto the hit.
##
## [param blast_from] is where a real blast that killed him went off, and
## [param blast_reach] how far it reached - he is then thrown apart from there
## rather than torn where he stood; see [member throws_bodies]. Left at
## [code]Vector2.INF[/code] - a pellet's kill, a BLOOD REAPER execution - he is torn.
func tear_apart_by_hit(body: Node2D, hitbox: Hitbox, damage: float, hit_direction: Vector2,
		hit_position: Vector2, effects: HitEffects, critical: bool = false,
		blast_from: Vector2 = Vector2.INF, blast_reach: float = 0.0) -> bool:
	if _played or body == null or hitbox == null or not is_inside_tree():
		return false
	_played = true

	var at := body.global_position + gore_body_offset
	global_position = body.global_position
	_call_off_the_ordinary_death(body)
	hitbox.take_hit(damage, hit_direction, hit_position, critical, effects)

	var health := _find_health(body)
	if health != null and health.is_alive():
		queue_free()
		return false
	_finish_tearing(body, at, blast_from, blast_reach)
	return true


## Lands [param damage] on [param victim] through a fresh [param gore_scene] when it
## is going to kill him, so he comes apart - and reports whether the hit went this
## way. Worked out exactly as the hit will be: the hitbox's multiplier on the damage
## against what he has left, and nothing while he is in a grace window that would
## drop the hit. A man already dead or already going is never torn twice. False
## means nothing was dealt and the caller lands its hit the ordinary way.
##
## Only a man carrying a node of class [param requires] comes apart (empty allows
## anybody), and never one carrying any of [param excludes] - a boss has his own
## defeat, a bomber his own blast.
##
## [param on_executed], when valid, is called once he has come apart, with the point
## the gore burst from and the man - BLOOD REAPER's volley hangs off it. Only a man
## really torn apart reports, so one death is reported once.
##
## [param blast_from] and [param blast_reach] are a real blast's - see
## [method tear_apart_by_hit]. Only a blast passes them.
static func tear_if_fatal(gore_scene: PackedScene, victim: Node, hitbox: Hitbox, damage: float,
		direction: Vector2, at: Vector2, effects: HitEffects, requires: StringName,
		excludes: Array[StringName], critical: bool = false,
		on_executed: Callable = Callable(), blast_from: Vector2 = Vector2.INF,
		blast_reach: float = 0.0) -> bool:
	var body := victim as Node2D
	if gore_scene == null or body == null or hitbox == null or body.is_queued_for_deletion() \
			or not body.is_inside_tree() or not gore_allowed(body, requires, excludes):
		return false
	var health := hitbox.get_node_or_null(hitbox.health_path) as Health
	if health == null or not health.is_alive() or health.is_invulnerable():
		return false
	if damage * hitbox.damage_multiplier < health.get_current():
		return false
	var gore := gore_scene.instantiate() as Explosion
	var container := body.get_tree().current_scene
	if gore == null or container == null:
		if gore != null:
			gore.free()
		return false
	container.add_child(gore)
	var burst_at := body.global_position + gore.gore_body_offset
	if gore.tear_apart_by_hit(body, hitbox, damage, direction, at, effects, critical,
			blast_from, blast_reach) and on_executed.is_valid():
		on_executed.call(burst_at, body)
	return true


## Whether [param body] may come apart - see [method tear_if_fatal].
static func gore_allowed(body: Node, requires: StringName, excludes: Array[StringName]) -> bool:
	if not requires.is_empty() and body.find_children("*", requires, true, false).is_empty():
		return false
	for type: StringName in excludes:
		if not body.find_children("*", type, true, false).is_empty():
			return false
	return true


func _finish_tearing(body: Node2D, at: Vector2, blast_from: Vector2 = Vector2.INF,
		blast_reach: float = 0.0) -> void:
	_tear_apart(body, blast_from, blast_reach)
	_gore_impact_sound(at)
	exploded.emit(at)

	var life := maxf(gore_settle_time, 0.0) + maxf(gore_fade_time, 0.0) + 1.0
	get_tree().create_timer(life, true, false, true).timeout.connect(queue_free)


## The flare: up at once, swelling slightly, gone. The swell is what stops a
## single sprite reading as a decal.
func _flare() -> void:
	var boom := get_node_or_null(boom_path) as Sprite2D
	if boom == null:
		return
	_flare_sprite(boom, boom_scale, 0.0)


## One flare sprite at [param size], [param delay] seconds from now.
func _flare_sprite(boom: Sprite2D, size: float, delay: float) -> void:
	boom.modulate = boom_modulate
	boom.rotation = randf() * TAU
	boom.scale = Vector2.ONE * size
	if boom_seconds <= 0.0:
		boom.visible = false
		return
	boom.visible = delay <= 0.0

	var tween := create_tween().set_parallel(true)
	if delay > 0.0:
		tween.tween_callback(boom.show).set_delay(delay)
	tween.tween_property(boom, "scale", Vector2.ONE * size * maxf(boom_growth, 0.01),
		boom_seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(boom, "modulate:a", 0.0, boom_seconds) \
		.set_delay(delay + boom_seconds * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The light. It is not a circle drawn over the scene - it is a light in the
## scene, so what it brightens is the sand, the props and whoever is standing in
## it, and it is gone again before the eye settles on it.
func _flash() -> void:
	var flash := get_node_or_null(flash_path) as PointLight2D
	if flash == null:
		return

	flash.color = flash_colour
	flash.texture_scale = maxf(flash_texture_scale, 0.01)
	flash.energy = maxf(flash_energy, 0.0)
	flash.visible = true
	if flash_seconds <= 0.0:
		flash.visible = false
		return

	var tween := create_tween()
	tween.tween_property(flash, "energy", 0.0, flash_seconds) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: flash.visible = false)


## The scorch, [param size] times its artwork. It lies at full strength for its
## whole stated [param seconds] and only then starts to go, so "seven seconds" is
## seven seconds of mark rather than seven seconds of something fading.
##
## It lies flat and never turns: whatever direction the blast came from, the scorch
## is stamped square to the ground.
func _mark(size: float, seconds: float) -> void:
	var mark := get_node_or_null(mark_path) as Sprite2D
	if mark == null:
		return

	var spread := clampf(mark_scale_variation, 0.0, 0.9)
	mark.visible = true
	mark.modulate = mark_modulate
	mark.global_rotation = 0.0
	mark.scale = Vector2.ONE * size * (1.0 + randf_range(-spread, spread))

	if mark_fade <= 0.0:
		return
	var tween := create_tween()
	tween.tween_property(mark, "modulate:a", 0.0, mark_fade) \
		.set_delay(maxf(seconds, 0.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _smoke() -> void:
	var smoke := get_node_or_null(smoke_path) as CPUParticles2D
	if smoke == null:
		return

	if not smoke_textures.is_empty():
		var pick := smoke_textures[randi() % smoke_textures.size()]
		if pick != null:
			smoke.texture = pick

	smoke.visible = true
	smoke.restart()
	smoke.emitting = true


## The pieces, thrown outwards and left where they land.
##
## Each one is an ordinary [DeathDebris] with a sprite in it, which is the same
## arrangement a severed head is - so a gore piece bounces, rolls, settles and
## fades through code that was already written and tuned, and none of it is here.
##
## [param outward], when given, is the way a blast threw the man they came out of:
## every piece is pushed along it by [member gore_outward_push] as well.
func _throw_gore(at: Vector2, outward: Vector2 = Vector2.ZERO) -> void:
	if gore_textures.is_empty() or not is_inside_tree():
		return
	var container := get_tree().current_scene
	if container == null:
		return

	var wanted := randi_range(mini(gore_count.x, gore_count.y), maxi(gore_count.x, gore_count.y))
	for i: int in maxi(wanted, 0):
		var texture := gore_textures[randi() % gore_textures.size()]
		if texture == null:
			continue

		var carrier := DeathDebris.new()
		carrier.gravity = gore_gravity
		carrier.bounce = gore_bounce
		carrier.ground_friction = gore_ground_friction
		carrier.settle_time = gore_settle_time
		carrier.fade_time = gore_fade_time

		container.add_child(carrier)
		carrier.name = "GorePiece"
		carrier.global_position = at
		carrier.rotation = randf() * TAU

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * randf_range(
			minf(gore_scale.x, gore_scale.y), maxf(gore_scale.x, gore_scale.y))
		carrier.add_child(sprite)
		carrier.reset_physics_interpolation()

		# Connected before it is thrown, so the arrival cannot be missed, and connected
		# to this rather than to the piece so the recording, the pitch and the level are
		# the blast's to tune in one place.
		carrier.landed.connect(_on_gore_landed)

		# Sideways in either direction and always upwards, so the pieces leave the
		# blast in a spray rather than a ring and all of them come back down.
		var sideways := randf_range(gore_speed.x, gore_speed.y) * (1.0 if randf() < 0.5 else -1.0)
		var lift := -randf_range(gore_lift.x, gore_lift.y)
		# Up or down the screen as well as sideways, so the spray leaves in every
		# direction rather than as a flat fan.
		var drift := randf_range(-1.0, 1.0) * gore_depth_spread * absf(sideways)
		sideways += outward.x * gore_outward_push
		drift += outward.y * gore_outward_push * throw_depth_scale
		carrier.launch(Vector2(sideways, lift), randf_range(gore_drop.x, gore_drop.y), drift)


## One piece of gore arriving on the ground.
##
## [b]It is the landing that is heard, not the lying there.[/b] [DeathDebris] only
## reports a ground contact - the arrival, and the bounces after it - and stops
## reporting entirely once the piece has settled, so a screenful of gore resting on
## the sand is silent without anything here having to remember which pieces have
## already spoken.
func _on_gore_landed(at: Vector2, impact_speed: float, first_touch: bool) -> void:
	if not first_touch and not gore_impact_on_bounce:
		return
	if impact_speed < maxf(gore_impact_min_speed, 0.0):
		return
	_gore_impact_sound(at)


## The impact itself: one recording of however many, at the point it landed, thrown
## a long way off its own pitch so no two pieces of the same spray sound alike.
##
## The voice is detached - see [method SoundBank.play_detached_stream_at] - which is
## what lets a piece thrown by a blast that has since cleaned itself up still be
## heard coming down.
func _gore_impact_sound(at: Vector2) -> void:
	if gore_impact_sounds.is_empty():
		return
	var bank := get_node_or_null(sound_bank_path) as SoundBank
	if bank == null:
		return

	var stream := gore_impact_sounds[randi() % gore_impact_sounds.size()]
	var voice := bank.play_detached_stream_at(stream, at, gore_impact_volume_db)
	if voice == null:
		return

	# Written over the bank's own narrow spread rather than added to it, so the range
	# heard is exactly the one written in the inspector.
	voice.pitch_scale = randf_range(
		minf(gore_impact_pitch.x, gore_impact_pitch.y),
		maxf(gore_impact_pitch.x, gore_impact_pitch.y))


## The blast's blood. Thrown rather than stamped, so it arcs out of the explosion
## and lands as collectable specks - the same journey a kill's blood makes.
func _scatter_blood(at: Vector2) -> void:
	if blood_count <= 0:
		return

	var spray := BloodSpray.get_active(self)
	if spray != null:
		spray.launch(at, blood_count)
		return

	var field := BloodField.get_active(self)
	if field != null:
		field.add_splash(at, blood_count)


## What standing too close costs. The player is found by their own group rather
## than wired to, so an explosion set off anywhere reaches whoever is near it.
func _hurt(at: Vector2) -> void:
	if damage <= 0.0 or not is_inside_tree():
		return

	for node: Node in get_tree().get_nodes_in_group(damage_group):
		var health := node as Health
		if health == null or not health.is_alive():
			continue
		var body := health.get_parent() as Node2D
		if body == null:
			continue
		var offset := body.global_position - at
		if offset.length() > damage_radius:
			continue
		# Aimed away from the blast, so the knockback and the blood spray both point
		# the way the force was travelling.
		health.take_damage(damage, offset.normalized())


## Keeps [param body] out of this blast entirely - no damage, no gore, no chain.
##
## [b]One caller and one reason.[/b] A bomber's own fuse spares the bomber, because
## the blast is already taking that body away and killing it with its own explosion
## would play a second death underneath the first. Anything else standing in the
## radius is in the radius. Call it before [method play]; afterwards it does
## nothing, which is what stops a blast being disarmed after the fact.
func spare(body: Node) -> void:
	if body != null and not _spared.has(body):
		_spared.append(body)


## What the blast does to the men in it.
##
## Two things, and which one a man gets is decided by whether he is carrying
## dynamite. A bomber goes off - see [member chains_bombers] - and everybody else
## takes [member enemy_damage] and, if that finishes him, comes apart into
## [member gore_textures] where he stood.
##
## The chain is deferred rather than called straight out of this loop, so a group
## of bombers unwinds one after another across the frame instead of nesting three
## explosions inside each other's own iteration. It is still the same frame, which
## is what "immediately" has to mean here.
func _hurt_the_men(at: Vector2) -> void:
	if not is_inside_tree():
		return
	var reach := damage_radius if enemy_damage_radius < 0.0 else enemy_damage_radius
	if reach <= 0.0:
		return

	var chained: Array[BomberFuse] = []

	# The fuses already burning, first. A lit bomber shot on its way in has left its
	# body behind - the fuse is out in the world on its own by then - so it cannot be
	# found by walking the men, and a corpse with a countdown on it is exactly the
	# case the chain exists for.
	if chains_bombers:
		for fuse: BomberFuse in BomberFuse.get_threats(self):
			if _is_spared(fuse.get_body()) or _is_spared(fuse):
				continue
			if fuse.global_position.distance_to(at) > reach:
				continue
			chained.append(fuse)

	for node: Node in get_tree().get_nodes_in_group(enemy_group):
		var body := node as Node2D
		if body == null or not is_instance_valid(body) or _is_spared(body):
			continue
		var offset := body.global_position - at
		if offset.length() > reach:
			continue

		# A bomber that has not lit itself yet is found here rather than above, and
		# goes up exactly the same way: being idle is not cover.
		var fuse := _find_fuse(body)
		if chains_bombers and fuse != null:
			if not chained.has(fuse):
				chained.append(fuse)
			continue

		_hurt_the_man(body, offset)

	for fuse: BomberFuse in chained:
		fuse.chain_detonate.call_deferred()


## One man. Aimed away from the blast, so his knockback and his blood both point
## the way the force was travelling, exactly as the player's do.
func _hurt_the_man(body: Node2D, offset: Vector2) -> void:
	if enemy_damage <= 0.0:
		return
	var health := _find_health(body)
	if health == null or not health.is_alive():
		return

	# Read before the damage lands, because afterwards there is no pool left to ask.
	# The head is called off first for the same reason: [signal Health.died] arrives
	# from inside [method Health.take_damage], so anything that has to happen instead
	# of the ordinary death has to be in place before the hit.
	var fatal := gore_kills and enemy_damage >= health.get_current()
	if fatal:
		_call_off_the_ordinary_death(body)

	health.take_damage(enemy_damage, offset.normalized())

	if fatal or (gore_kills and not health.is_alive()):
		_tear_apart(body, global_position)


## The gore that replaces a death. The same throw the blast itself makes, put on the
## man rather than on the blast, so there is one piece of code for both.
##
## With [param blast_from] - a real blast went off there - and [member throws_bodies]
## on, the man is thrown apart instead: his body and his head flung outwards as two
## pieces by his own [EnemyHeadPop], the gore pushed outwards with them. See
## [method _throw_body]. [param blast_reach] is that blast's reach; 0 is this one's.
func _tear_apart(body: Node2D, blast_from: Vector2 = Vector2.INF, blast_reach: float = 0.0) -> void:
	var gore_at := body.global_position + gore_body_offset
	if throws_bodies and blast_from.is_finite():
		var away := body.global_position - blast_from
		if _throw_body(body, away, blast_reach if blast_reach > 0.0 else get_reach()):
			_throw_gore(gore_at, away.normalized())
			return
	_throw_gore(gore_at)
	if gore_removes_body:
		body.queue_free()


## Flings [param body] apart along [param away] - from the blast to him - through his
## [EnemyHeadPop]: the body and the head each get their own speed, turned apart by
## [member head_separation_degrees] and both jittered, so no two men fly alike. A
## man at the edge of [param reach] is thrown by [member throw_edge_scale] of it.
## False when he has nothing to throw him with.
func _throw_body(body: Node2D, away: Vector2, reach: float) -> bool:
	var pop: EnemyHeadPop = null
	for node: Node in body.find_children("*", "EnemyHeadPop", true, false):
		pop = node as EnemyHeadPop
		if pop != null:
			break
	if pop == null:
		return false

	var heading := away.angle() if not away.is_zero_approx() else randf() * TAU
	heading += deg_to_rad(randf_range(-throw_angle_jitter_degrees, throw_angle_jitter_degrees))
	var edge := lerpf(1.0, throw_edge_scale, clampf(away.length() / maxf(reach, 1.0), 0.0, 1.0))

	var body_dir := Vector2.from_angle(heading)
	var body_speed := _roll(body_throw_force) * edge
	var head_side := 1.0 if randf() < 0.5 else -1.0
	var head_dir := Vector2.from_angle(heading
		+ deg_to_rad(head_separation_degrees) * head_side * randf_range(0.5, 1.0))
	var head_speed := _roll(head_throw_force) * edge

	return pop.blast_apart(
		Vector2(body_dir.x * body_speed, -_roll(body_throw_lift) * edge),
		body_dir.y * body_speed * throw_depth_scale,
		Vector2(head_dir.x * head_speed, -_roll(head_throw_lift) * edge),
		head_dir.y * head_speed * throw_depth_scale,
		gore_removes_body)


func _roll(span: Vector2) -> float:
	return randf_range(minf(span.x, span.y), maxf(span.x, span.y))


func _call_off_the_ordinary_death(body: Node2D) -> void:
	for node: Node in body.find_children("*", "EnemyHeadPop", true, false):
		var pop := node as EnemyHeadPop
		if pop != null:
			pop.suppress()


## The fuse on [param body], or null for anybody who is not carrying dynamite.
func _find_fuse(body: Node2D) -> BomberFuse:
	for node: Node in body.find_children("*", "BomberFuse", true, false):
		var fuse := node as BomberFuse
		if fuse != null and not fuse.has_detonated():
			return fuse
	return null


## Found by type rather than by name, so an enemy that keeps its pool somewhere
## unusual is still hurt by a blast.
func _find_health(body: Node2D) -> Health:
	for node: Node in body.find_children("*", "Health", true, false):
		var health := node as Health
		if health != null:
			return health
	return null


func _is_spared(node: Node) -> bool:
	return node != null and _spared.has(node)


## The blast itself, heard at the place it happened.
##
## Detached through [method SoundBank.play_detached_at] rather than played on a
## pooled voice, for the reason every other one-off in the game is: the thing that
## made the noise is going away - the bomber is freed on this very frame, and this
## node frees itself once the mark has gone - and a voice inside it would be cut
## off part way through the one moment it exists for.
func _sound(at: Vector2) -> void:
	var bank := get_node_or_null(sound_bank_path) as SoundBank
	if bank == null:
		return
	bank.play_detached_at(sound_name, at, sound_volume_db)


## The knock on the camera. It goes through the one camera the game has - see
## [CameraController] - so it layers with the shakes the weapons and the boss's
## footsteps are already asking for rather than fighting them: the controller
## takes the larger of the two, which is what makes a blast during a shotgun
## reload read as the blast.
func _shake_camera() -> void:
	if shake_strength <= 0.0 or shake_duration <= 0.0:
		return
	var camera := CameraController.get_active(self)
	if camera != null:
		camera.shake(shake_strength, shake_duration)


func _hide_parts() -> void:
	for path: NodePath in [boom_path, flash_path, mark_path, smoke_path]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false
