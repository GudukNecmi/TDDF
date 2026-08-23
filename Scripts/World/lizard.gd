class_name Lizard
extends CharacterBody2D
## The thing that bolts out from under a bush when you walk into it.
##
## [b]It is scenery that reacts, not an enemy.[/b] It has no health, deals no
## damage and is on nobody's side: the whole of it is that the desert is
## occasionally startled by the player, runs, and takes cover. Everything about it
## that a player can see is one of four beats -
##
##   [codeblock]
##   emerge   from behind the prop that was touched, at its base
##   flee     straight away from the player, at a fraction of their speed
##   hide     behind the third prop it passes, and stop there
##   squish   under the player's boot, and stay where it was stepped on
##   [/codeblock]
##
## [b]Depth is the point of the first and third beats.[/b] The props container is
## y-sorted and a prop's origin sits on the middle of the bottom edge of its
## artwork - see [PropArt] - so anything standing a little *above* a prop's origin
## is drawn behind it. That single fact is what makes the lizard appear from
## behind cover rather than on top of it, and what makes it disappear behind the
## prop it hides at. There is no z-index anywhere in this script and no second
## sorting rule: it is the same one the cacti, the tents and the player already
## use.
##
## [b]How fast it runs is asked of the player, not written down.[/b] The player's
## speed is upgradeable and modified by the ground they are on, so a hardcoded
## number would be right for exactly one build of the game. See
## [member speed_fraction].
##
## [b]The cover it counts is whatever it runs past.[/b] There are no authored
## paths and no list of hiding places: a sensor on the lizard notices props on the
## scenery collision layer as it passes them, and the [member cover_required]th one
## it meets is where it stops. Which props exist and where they are is the
## scatter's business - see [PropScatter] - and a desert laid out differently gives
## a different chase for nothing.

## Emitted as the player steps on it, carrying where the stomp landed.
signal squished(at: Vector2)
## Emitted once it has settled behind its cover.
##
## Named for the act rather than the state because [code]hidden[/code] is already a
## signal on [CanvasItem], and a script may not redefine one.
signal took_cover(behind: Node2D)

enum State {
	## Running away from whatever startled it.
	FLEEING,
	## Settled behind cover, and staying there.
	HIDING,
	## Stepped on.
	SQUISHED,
}

@export_group("Running")
## How fast it runs, as a fraction of the player's own current speed.
##
## [b]A fraction rather than a number.[/b] The player's speed is theirs to change -
## the ground drags on it, a later upgrade will raise it - and a lizard authored at
## a fixed 154 pixels a second would be a lizard the player outruns the moment
## anything touches their speed. Asked of the player every frame, so it keeps its
## relationship to them whatever happens to either.
@export var speed_fraction: float = 0.7
## Speed used when there is no player to ask - a scene run on its own in the
## editor. Never read while the game is being played.
@export var fallback_speed: float = 154.0
## How quickly it turns onto the direction it wants, in radians per second. High:
## it is a bolt, not a vehicle. 0 turns instantly.
@export var turn_speed: float = 14.0
## Group the player is found in, both to run from and to measure speed against.
@export var player_group: StringName = &"player"

@export_group("Cover")
## How many props it must pass before it takes cover behind one. Three by design:
## the first two are near misses and the third is where the chase ends.
@export var cover_required: int = 3
## How far above a prop's own base it settles, in pixels.
##
## Positive is up the screen, which in a y-sorted world is *behind* - the whole of
## why it disappears when it gets there. Large enough to be clearly behind the art,
## small enough that it is still at the foot of the prop rather than up its side.
@export var hide_depth: float = 7.0
## How close to that spot counts as arrived, in pixels.
@export var hide_arrive_distance: float = 6.0
## How long it will chase its chosen cover before giving up and simply stopping, in
## seconds. A cover spot it cannot reach - the far side of a wall - must not leave
## it running forever.
@export var hide_timeout: float = 4.0
## Sensor whose overlaps are counted as passing near a prop. Its shape is the
## "near" distance, so how wide a berth counts is dragged in the editor rather than
## typed here.
@export var cover_sensor_path: NodePath = ^"Cover"

@export_group("Leaving")
## How long it may be off screen before it is taken off the board, in seconds.
##
## It is deliberately not freed the instant it leaves: a lizard that vanishes at
## the edge of the screen is a lizard the player sees vanish. Two seconds is long
## enough that it is genuinely gone.
@export var offscreen_lifetime: float = 2.0
## The notifier that decides what "off screen" is. It answers to the real camera,
## so this needs no screen coordinates of its own and follows every zoom the game
## does.
@export var notifier_path: NodePath = ^"Screen"

@export_group("Squish")
## Sensor that notices the player standing on it.
@export var stomp_sensor_path: NodePath = ^"Stomp"
## The artwork, swapped as it is stepped on.
@export var art_path: NodePath = ^"Art"
## How it is drawn alive.
@export var alive_texture: Texture2D:
	set(value):
		alive_texture = value
		_apply_art()
## How it is drawn once it has been stepped on.
@export var squished_texture: Texture2D
## Bank the squish is played through, and the sound in it.
@export var sound_bank_path: NodePath = ^"Sounds"
@export var squish_sound: StringName = &"squish"
## How long the flattened one stays on the ground, in seconds. 0 leaves it there
## for the rest of the round, which is what a stain wants.
@export var squished_lifetime: float = 0.0

@export_group("Look")
## How far the artwork must be turned, in degrees, to put its head along +X.
##
## The drawing faces up the screen, so a quarter turn is what lines it up with the
## direction it is running. It turns the artwork only - the body, the sensors and
## the sorting are untouched by it.
@export var art_rotation_offset_degrees: float = 90.0
## Whether the artwork turns to face the way it is running at all. Off leaves it
## drawn exactly as painted.
@export var art_turns_with_run: bool = true

@onready var _art: Sprite2D = get_node_or_null(art_path) as Sprite2D
@onready var _cover: Area2D = get_node_or_null(cover_sensor_path) as Area2D
@onready var _stomp: Area2D = get_node_or_null(stomp_sensor_path) as Area2D
@onready var _notifier: VisibleOnScreenNotifier2D = \
	get_node_or_null(notifier_path) as VisibleOnScreenNotifier2D
@onready var _sounds: SoundBank = get_node_or_null(sound_bank_path) as SoundBank

var _state: State = State.FLEEING
var _direction := Vector2.RIGHT
var _offscreen: float = -1.0
var _hiding_time: float = 0.0
## The prop it came out from under. Never counted as cover: it is the one place it
## is certainly not going to hide.
var _origin: Node2D
## Props already counted, so passing the same one twice is one prop.
var _counted: Array[Node] = []
var _cover_target: Node2D
var _hide_spot := Vector2.ZERO
## Whether it has already come to rest. Without it, arriving at cover would be
## re-decided - and re-announced - on every frame it spent sitting there.
var _settled: bool = false


func _ready() -> void:
	_apply_art()
	_apply_art_rotation()
	if _cover != null:
		_cover.body_entered.connect(_on_cover_entered)
	if _stomp != null:
		_stomp.body_entered.connect(_on_stomp_entered)
	if _notifier != null:
		_notifier.screen_entered.connect(_on_screen_entered)
		_notifier.screen_exited.connect(_on_screen_exited)


## Sets it running, away from [param from] and out from behind [param origin].
##
## Called by whatever spawned it, the moment it is placed, so it is already pointing
## the right way on its very first frame rather than being seen to turn.
func startle(from: Vector2, origin: Node2D = null) -> void:
	_origin = origin
	var away := global_position - from
	_direction = away.normalized() if not away.is_zero_approx() else Vector2.RIGHT
	_state = State.FLEEING
	_apply_art_rotation()


func get_state() -> State:
	return _state


## How many props it has passed. For a readout, and for a test.
func get_cover_count() -> int:
	return _counted.size()


func _physics_process(delta: float) -> void:
	_advance_offscreen(delta)
	if _state == State.SQUISHED:
		return

	if _state == State.HIDING:
		_advance_hiding(delta)
	else:
		_advance_fleeing(delta)

	_apply_art_rotation()
	move_and_slide()


## Straight away from the player, re-read every frame so a player who runs round it
## turns it rather than being chased in the direction it first set off.
func _advance_fleeing(delta: float) -> void:
	var player := _get_player()
	if player != null:
		var away := global_position - player.global_position
		if not away.is_zero_approx():
			_turn_towards(away.normalized(), delta)

	velocity = _direction * _speed()


## Onto the spot behind its cover, and then nothing at all. It keeps running at its
## own speed the whole way, so taking cover reads as the end of the same bolt
## rather than as a second, slower movement.
func _advance_hiding(delta: float) -> void:
	if _settled:
		velocity = Vector2.ZERO
		return

	_hiding_time += delta
	if _cover_target == null or not is_instance_valid(_cover_target):
		_settle()
		return

	var to_spot := _hide_spot - global_position
	if to_spot.length() <= maxf(hide_arrive_distance, 0.5) or _hiding_time >= maxf(hide_timeout, 0.1):
		_settle()
		return

	_turn_towards(to_spot.normalized(), delta)
	velocity = _direction * _speed()


## Stops for good, wherever it is. Reached both by arriving at cover and by giving
## up on it, so there is one place the lizard comes to rest.
func _settle() -> void:
	if _settled:
		return
	_settled = true
	velocity = Vector2.ZERO
	_state = State.HIDING
	took_cover.emit(_cover_target)


## Eased rather than snapped, so a lizard turned by the player moving round it
## curves away instead of pivoting on the spot. 0 turns instantly.
func _turn_towards(wanted: Vector2, delta: float) -> void:
	if turn_speed <= 0.0:
		_direction = wanted
		return
	_direction = Vector2.RIGHT.rotated(
		rotate_toward(_direction.angle(), wanted.angle(), turn_speed * delta))


## The player's own speed, taken at whatever fraction this lizard runs at. A player
## who is not there, or who does not answer, leaves it at its fallback - so a
## lizard dropped into a scene with no player still runs.
func _speed() -> float:
	var player := _get_player()
	if player != null and player.has_method(&"get_current_speed"):
		return maxf(player.call(&"get_current_speed") as float, 0.0) * maxf(speed_fraction, 0.0)
	return maxf(fallback_speed, 0.0) * maxf(speed_fraction, 0.0)


## One more prop passed. The third one - see [member cover_required] - is where the
## chase ends, and the lizard turns for the spot behind it.
##
## Bodies rather than a group lookup: the sensor is masked to the scenery layer, so
## what it notices is exactly what the world considers a solid prop, and a prop kind
## added later is counted without this being told about it.
func _on_cover_entered(body: Node2D) -> void:
	if _state != State.FLEEING or body == null:
		return
	# The prop it came out from under never counts - it is the one place it is
	# certainly not going to hide, and it begins the run standing inside it. The
	# ancestor test is what makes that true for a prop whose cover is a child body
	# rather than the prop's own root, which is how the ones that are not solid
	# announce themselves.
	if _origin != null and (body == _origin or _origin.is_ancestor_of(body)):
		return
	if _counted.has(body):
		return

	_counted.append(body)
	if _counted.size() < maxi(cover_required, 1):
		return

	_cover_target = body
	# Above the prop's own base, which in a y-sorted world is behind it.
	_hide_spot = body.global_position - Vector2(0.0, maxf(hide_depth, 0.0))
	_state = State.HIDING
	_hiding_time = 0.0


## Stepped on. It stops exactly where the boot landed - the position is not
## adjusted towards the player or the prop - and stays there.
func _on_stomp_entered(body: Node2D) -> void:
	if _state == State.SQUISHED or body == null or not body.is_in_group(player_group):
		return

	_state = State.SQUISHED
	velocity = Vector2.ZERO
	set_physics_process(false)
	if _stomp != null:
		_stomp.set_deferred(&"monitoring", false)
	if _cover != null:
		_cover.set_deferred(&"monitoring", false)

	if _art != null and squished_texture != null:
		_art.texture = squished_texture
	if _sounds != null:
		_sounds.play(squish_sound)

	squished.emit(global_position)

	if squished_lifetime > 0.0:
		var timer := get_tree().create_timer(squished_lifetime)
		timer.timeout.connect(queue_free)


## The two-second stay of execution. It runs on the notifier's answer rather than
## on coordinates of its own, so it follows every zoom and every camera the game
## has without knowing about any of them.
func _advance_offscreen(delta: float) -> void:
	if _offscreen < 0.0:
		return
	_offscreen += delta
	if _offscreen >= maxf(offscreen_lifetime, 0.0):
		queue_free()


func _on_screen_exited() -> void:
	_offscreen = 0.0


func _on_screen_entered() -> void:
	_offscreen = -1.0


func _apply_art() -> void:
	if _art != null and alive_texture != null:
		_art.texture = alive_texture


## Turns the picture the way it is running. The body itself is never rotated,
## because rotating it would turn the sensors and the shadow with it.
func _apply_art_rotation() -> void:
	if _art == null or not art_turns_with_run:
		return
	_art.rotation = _direction.angle() + deg_to_rad(art_rotation_offset_degrees)


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group(player_group) as Node2D
