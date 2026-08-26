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
## The scorch left on the ground.
@export var mark_path: NodePath = ^"Mark"
## How long it lies there at full strength before it starts to go.
@export var mark_seconds: float = 7.0
## How long it then takes to disappear.
@export var mark_fade: float = 0.9
## What it is drawn at.
@export var mark_scale: float = 0.22
## How much its size varies from one blast to the next, as a fraction, so two
## explosions in the same spot do not stamp the same mark twice.
@export_range(0.0, 0.9) var mark_scale_variation: float = 0.18
## How dark it is. The artwork is black, so this is where a scorch is turned into
## a smear.
@export var mark_modulate := Color(0.12, 0.09, 0.08, 0.72)

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
	_flare()
	_flash()
	_mark()
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
	var life := maxf(mark_seconds + mark_fade,
		maxf(boom_seconds, flash_seconds)) + 1.0
	var timer := get_tree().create_timer(life, true, false, true)
	timer.timeout.connect(queue_free)


## The flare: up at once, swelling slightly, gone. The swell is what stops a
## single sprite reading as a decal.
func _flare() -> void:
	var boom := get_node_or_null(boom_path) as Sprite2D
	if boom == null:
		return

	boom.visible = true
	boom.modulate = boom_modulate
	boom.rotation = randf() * TAU
	boom.scale = Vector2.ONE * boom_scale
	if boom_seconds <= 0.0:
		boom.visible = false
		return

	var tween := create_tween().set_parallel(true)
	tween.tween_property(boom, "scale", Vector2.ONE * boom_scale * maxf(boom_growth, 0.01),
		boom_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(boom, "modulate:a", 0.0, boom_seconds) \
		.set_delay(boom_seconds * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


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


## The scorch. It lies at full strength for its whole stated life and only then
## starts to go, so "seven seconds" is seven seconds of mark rather than seven
## seconds of something fading.
func _mark() -> void:
	var mark := get_node_or_null(mark_path) as Sprite2D
	if mark == null:
		return

	var spread := clampf(mark_scale_variation, 0.0, 0.9)
	mark.visible = true
	mark.modulate = mark_modulate
	mark.rotation = randf() * TAU
	mark.scale = Vector2.ONE * mark_scale * (1.0 + randf_range(-spread, spread))

	if mark_fade <= 0.0:
		return
	var tween := create_tween()
	tween.tween_property(mark, "modulate:a", 0.0, mark_fade) \
		.set_delay(maxf(mark_seconds, 0.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


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
func _throw_gore(at: Vector2) -> void:
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
		carrier.launch(Vector2(sideways, lift), randf_range(gore_drop.x, gore_drop.y))


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
		_tear_apart(body)


## The gore that replaces a death. The same throw the blast itself makes, put on the
## man rather than on the blast, so there is one piece of code for both.
func _tear_apart(body: Node2D) -> void:
	_throw_gore(body.global_position + gore_body_offset)
	if gore_removes_body:
		body.queue_free()


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
