class_name EnemyDefeat
extends Node
## Plays an enemy out when the run's clock calls time on it, instead of deleting
## it where it stands.
##
## The beat is: two X marks snap over the eyes, the enemy stops dead but stays
## standing for a moment, and then black smoke comes off it as it goes. The pause
## is the whole effect - a body that is visibly finished before it disappears
## reads as defeated, where one that vanishes on the same frame reads as a bug.
##
## Nothing about dying is reimplemented here. Once the beat is over this hands
## over to [Health] - by default through [method Health.remove], which runs exactly
## the same death a killing shot does, so [DeathFade] still owns the fade and the
## freeing and every other listener fires unchanged. What is added is only what
## happens *before* that.
##
## The one thing [method Health.remove] changes is what the body is [i]worth[/i]:
## it is marked as cleared off the field rather than beaten, and [BloodEmitter]
## reads that and spills nothing. See [member counts_as_kill] for the switch.
##
## It is driven per enemy rather than centrally so that anything else that wants
## to finish one off - a future execution, a cleared wave - can call
## [method defeat] on a single enemy without a manager being involved.
##
## The X marks are not only for the clock, though. An enemy shot dead by the
## player never comes through [method defeat] at all - its health simply reaches
## zero - so this also listens for that and puts the marks on. Both deaths look
## like a death; the difference between them is only that one has a beat of
## standing there first and the other does not.

## Emitted as the X marks land, not when the body finally goes.
signal defeated

## Health this ends. The kill goes through it rather than round it, so everything
## already hanging off death still fires.
@export var health_path: NodePath = ^"../Health"
## The X marks. Authored hidden and shown for the beat; being a child of the head
## sprite is what makes them lean and flip with it for free.
@export var dead_eyes_path: NodePath = ^"../HeadAim/Head/DeadEyes"
## How long the body stands there dead-eyed before it starts to go.
@export var eyes_time: float = 0.5
## Stops the enemy chasing and swinging the instant it is defeated. Its head keeps
## tracking and its idle keeps breathing, so it is a body that has stopped rather
## than a frozen frame.
@export var stop_on_defeat: bool = true
## Whether an enemy played out through [method defeat] counts as a kill.
##
## Off - the default - it is a [i]removal[/i]: the body still plays this whole
## sequence, X marks, beat, smoke and fade included, but it goes through
## [method Health.remove] rather than [method Health.kill] and so is worth nothing.
## That is what stops the run's clock clearing the arena from paying the player for
## every enemy they never beat, and it is why standing still until the timer runs
## out earns nothing.
##
## On, a defeat is indistinguishable from a killing shot and spills the enemy's
## full [member BloodEmitter.blood_value].
##
## Only [method defeat] is governed by this. An enemy shot dead never comes through
## it, so a weapon kill is always a kill however this is set.
@export var counts_as_kill: bool = false

@export_group("Smoke")
## Black burst released as the body goes. Optional - the death still plays without
## one.
@export var smoke_scene: PackedScene
## Offset from the enemy's origin, which sits at its feet, to body height.
@export var smoke_offset := Vector2(0, -30)

@onready var _health: Health = get_node_or_null(health_path) as Health
@onready var _eyes: CanvasItem = get_node_or_null(dead_eyes_path) as CanvasItem

var _defeated: bool = false


func _ready() -> void:
	if _eyes != null:
		_eyes.visible = false
	if _health != null:
		_health.died.connect(_on_died)


## A death that did not come through [method defeat] - the player shooting the
## enemy - still gets the marks, put on at the instant health runs out.
##
## Nothing else about that death is touched: no beat is inserted, no second kill
## is handed out, and the fall, the pieces coming off and the fade all carry on
## exactly as they were. This is the marks and only the marks.
##
## It is also what stops the two paths colliding. [method defeat] ends by calling
## [method Health.kill], which lands here - and finding the enemy already defeated,
## this does nothing rather than a second time.
func _on_died() -> void:
	if _defeated:
		return
	_defeated = true
	if _eyes != null:
		_eyes.visible = true
	defeated.emit()


func is_defeated() -> bool:
	return _defeated


## Starts the sequence. [param delay] staggers it, so a whole arena called at
## once goes out as a ripple rather than in a single frame.
##
## Guarded, so a second call - or an enemy shot dead during its own beat - cannot
## start it twice or hand out two kills.
func defeat(delay: float = 0.0) -> void:
	if _defeated:
		return
	_defeated = true

	if delay > 0.0:
		var wait := get_tree().create_timer(delay, true, false, true)
		wait.timeout.connect(_show_eyes)
		return
	_show_eyes()


func _show_eyes() -> void:
	if not is_inside_tree():
		return

	if _eyes != null:
		_eyes.visible = true
	if stop_on_defeat:
		_stop_host()
	defeated.emit()

	var timer := get_tree().create_timer(maxf(eyes_time, 0.0), true, false, true)
	timer.timeout.connect(_finish)


## Movement and the knife only. Everything cosmetic is left running on purpose -
## the shutdown that silences the whole character belongs to [DeathFade], and
## doing it here would freeze the body a beat too early.
func _stop_host() -> void:
	var host := get_parent()
	if host == null:
		return
	host.set_physics_process(false)
	if host is CharacterBody2D:
		(host as CharacterBody2D).velocity = Vector2.ZERO


## Both endings run the same death, so everything hanging off it - the smoke, the
## fade, the freeing - fires either way and none of it needs to know which this
## was. The choice only decides whether the body was worth anything.
func _finish() -> void:
	if not is_inside_tree():
		return

	_spawn_smoke()
	if _health == null:
		return

	if counts_as_kill:
		_health.kill()
	else:
		_health.remove()


## Parented to the running scene rather than to the enemy, because the enemy is
## about to fade out from under it and these bursts emit in global particle space.
func _spawn_smoke() -> void:
	var container := get_tree().current_scene
	if smoke_scene == null or container == null:
		return

	var host := get_parent() as Node2D
	if host == null:
		return

	var burst := smoke_scene.instantiate() as Node2D
	if burst == null:
		return

	container.add_child(burst)
	burst.global_position = host.global_position + smoke_offset
	burst.reset_physics_interpolation()

	if burst.has_method(&"play"):
		burst.call(&"play")
	elif burst is CPUParticles2D:
		(burst as CPUParticles2D).emitting = true
