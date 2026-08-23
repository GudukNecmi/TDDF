class_name AmmoCrate
extends Node2D
## A crate of ammunition dropped in the arena during a boss fight: walk up to it,
## press E, and top up whatever you are holding.
##
## [b]It is [WeaponRack] with a different thing behind the key[/b], and deliberately the
## same shape as every other interaction in the game: the player is found by group
## rather than by path, the reach test is a circle around this node, the prompt is
## [i]told[/i] on the crossing rather than asked every frame, and the key is taken in
## [method Node._unhandled_input] and marked handled so the press that opens a crate
## cannot also fire the gun. Its artwork is the scene's, it carries no collision, and it
## can be walked over.
##
## [b]There is no ammunition system here.[/b] What the player is carrying lives in the
## [code]Ammo[/code] locker ([AmmoLocker]) and always has; a crate asks it for the
## reserve belonging to the gun currently in the player's hands - see
## [method AmmoLocker.get_equipped_reserve], which is the same seam the camp's shop
## sells through - and puts rounds into it with [method AmmoReserve.add]. That is why a
## crate needs to know nothing about which weapons exist, which ammunition each one
## feeds on, or what the player is carrying: it refills the equipped weapon because the
## locker's answer to "what is equipped" is the only weapon it can see.
##
## [b]What it gives is a fraction of the capacity, not of the count.[/b] Half of a
## fifty-round ceiling is twenty-five rounds whether the player has ten left or forty -
## see [member refill_fraction] - so a crate is worth the same to somebody who has been
## careful as to somebody who is empty, and it is never worth nothing. Anything that
## would not fit is refused by the reserve rather than held, so the ceiling cannot be
## exceeded.
##
## [b]A crate the player has no room for is not consumed.[/b] Taking one at full
## ammunition would throw it away for nothing, so a full player is refused and the crate
## is left standing - see [member requires_room].
##
## [b]It can be dropped in rather than simply appearing.[/b] A crate asked to
## [method drop_in] falls into its own position from above, shakes the ground as it
## lands and bounces once - the same arrival [RewardChest] makes, through the same
## [method CameraController.shake] a shotgun and a death use, so there is one language
## for something heavy hitting the dirt. Nothing calls it automatically: a crate left
## alone is standing the moment it is added, which is what the arena's ten-second supply
## has always done.

## Emitted as the player comes within reach, and as they leave it.
signal player_entered
signal player_exited
## Emitted when the crate is actually taken, with how many rounds were handed over and
## which ammunition they were. The crate frees itself immediately afterwards.
signal collected(rounds: int, ammo_id: StringName)
## Emitted when the key was pressed in reach but there was nothing to give - an
## empty-handed player, or one already carrying all they can. [b]The crate is still
## standing[/b]; this is a refusal, not a collection.
signal refused
## Emitted as a dropped crate touches the ground - the same frame the camera is shaken.
## A crate that was never dropped in emits it on the frame it is added, so anything
## waiting on the landing is never left waiting.
signal landed

## Group every crate joins, so the spawner can count what is still uncollected without
## holding references to them.
const GROUP := &"ammo_crate"

## The locker the rounds come out of, reached by path the way every other node in the
## project reaches an autoload.
@export var locker_path: NodePath = ^"/root/Ammo"
## How much of the equipped weapon's [b]maximum[/b] capacity one crate is worth, as a
## fraction of it.
##
## [b]Of the ceiling, not of what is in the gun.[/b] At 0.5 a fifty-round weapon gets
## twenty-five rounds from a crate: a player with ten ends on thirty-five, a player with
## forty ends on fifty and the five that did not fit are refused rather than lost track
## of. Reading the current count instead would make a crate worth almost nothing to
## somebody nearly out, which is exactly when they need it.
@export_range(0.0, 1.0, 0.01) var refill_fraction: float = 0.5
## Whether a player with no room is refused rather than spending the crate on nothing.
## On, so a full player can leave it for later.
@export var requires_room: bool = true

@export_group("Reaching it")
## How close the player has to stand for the prompt to appear and the key to work, in
## pixels. Generous, exactly as the base's stations are - "at the crate" has to mean
## somewhere the player can walk to in a fight rather than a pixel they have to find.
@export var interaction_radius: float = 150.0
## Only bodies in this group can take it.
@export var body_group: StringName = &"player"
## Key that takes it. The project's own interact action, so a crate is opened with
## whatever every other interaction in the game is opened with.
@export var interact_action: StringName = &"interact"
## Where the reach is measured from, so the circle sits on the crate rather than at the
## middle of its artwork.
@export var reach_offset := Vector2(0.0, 0.0)

@export_group("Nodes")
## The E shown by the player's head while they are in reach. Optional.
@export var prompt_path: NodePath = ^"Prompt"
## The artwork, faded out as the crate is taken. Optional; a crate without one simply
## disappears.
@export var art_path: NodePath = ^"Art"

@export_group("Falling in")
## How far above its landing spot the crate starts, in pixels, when it is dropped in.
## Comfortably more than a screen, so it comes from off the top of the picture rather
## than fading into the middle of it.
@export var fall_height: float = 900.0
## How long the fall takes, in seconds. Quicker than the reward chest's - this is a
## crate, not the prize at the end of a hunt.
@export var fall_time: float = 0.55
## How long it waits after being dropped before it starts falling.
@export var fall_delay: float = 0.0

@export_group("The landing")
## How hard the camera is shaken as it hits, and for how long. The world's own shake,
## the same one a death and a shotgun use - kept well under the chest's, because a
## crate arriving mid-fight must not read as something having gone wrong.
@export var landing_shake: float = 14.0
@export var landing_shake_time: float = 0.28
## How high it bounces back up after it lands, in pixels, and how long the bounce takes
## each way. Small: it is a box of shells, not a ball.
@export var bounce_height: float = 20.0
@export var bounce_up_time: float = 0.12
@export var bounce_down_time: float = 0.17
## How far the artwork squashes as it lands, as a fraction. 0 leaves it rigid.
@export_range(0.0, 0.6, 0.01) var landing_squash: float = 0.16

@export_group("Taken")
## How long the crate fades out over as it is collected, in seconds, before it frees
## itself. Short - this is an acknowledgement, not an animation.
@export var collect_fade: float = 0.18
## How far the artwork lifts as it goes, in pixels, so being taken reads as being picked
## up rather than as switching off.
@export var collect_lift: float = 26.0

@onready var _prompt: InteractionPrompt = get_node_or_null(prompt_path) as InteractionPrompt
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D

var _in_reach: bool = false
var _taken: bool = false
## Whether the crate is on the ground. True from the start, because a crate nobody drops
## in has always simply been standing there - only [method drop_in] takes it off the
## ground, and only until it lands.
var _landed: bool = true
## Where the artwork sits at rest, so the fall and the bounce both have somewhere to
## come home to.
var _art_rest := Vector2.ZERO
var _fall: Tween
var _locker: AmmoLocker


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	if _art != null:
		_art_rest = _art.position


## Whether [param body] is standing close enough to take the crate.
func is_in_reach(body: Node2D) -> bool:
	if body == null or not body.is_in_group(body_group):
		return false
	return (global_position + reach_offset).distance_to(body.global_position) <= interaction_radius


func is_player_in_reach() -> bool:
	return _in_reach


## Whether the crate is on the ground and can be taken. Only ever false between
## [method drop_in] and the landing.
func is_landed() -> bool:
	return _landed


## Sends it down from above.
##
## [b]The node is already standing where it will land[/b] - so the reach circle, the
## prompt and everything placed against the crate's position are right from the first
## frame - and it is only the artwork that falls into it. Safe to call on a crate with
## no artwork, which simply lands at once.
func drop_in() -> void:
	if _taken:
		return
	_landed = false
	if _art == null or fall_height <= 0.0:
		# Nothing to fall. It arrives with the same shake and the same announcement, so a
		# crate whose artwork is missing is a crate that landed instantly rather than one
		# that never lands.
		_land()
		return

	_art.position = _art_rest - Vector2(0.0, maxf(fall_height, 0.0))

	if _fall != null and _fall.is_running():
		_fall.kill()
	_fall = create_tween()
	if fall_delay > 0.0:
		_fall.tween_interval(fall_delay)
	# Eased in rather than linear: a falling thing accelerates, and the whole reason the
	# landing reads as an impact is that it is quickest at the bottom.
	_fall.tween_property(_art, "position", _art_rest, maxf(fall_time, 0.0001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall.tween_callback(_land)


## It hits: the ground shakes, the crate squashes, bounces once and settles. From the
## same frame it can be picked up.
func _land() -> void:
	if _landed:
		return
	_landed = true

	var camera := CameraController.get_active(self)
	if camera != null and landing_shake > 0.0:
		camera.shake(landing_shake, maxf(landing_shake_time, 0.0))

	landed.emit()

	if _art == null:
		return

	if _fall != null and _fall.is_running():
		_fall.kill()
	_fall = create_tween()

	if landing_squash > 0.0:
		# Squashed on the frame of impact and let go again, so the weight is carried by the
		# artwork rather than by the camera alone.
		_art.scale = Vector2(1.0 + landing_squash, 1.0 - landing_squash)
		_fall.tween_property(_art, "scale", Vector2.ONE, maxf(bounce_up_time, 0.0001)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_fall = _fall.parallel()

	_fall.tween_property(_art, "position", _art_rest - Vector2(0.0, maxf(bounce_height, 0.0)),
		maxf(bounce_up_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fall.chain().tween_property(_art, "position", _art_rest,
		maxf(bounce_down_time, 0.0001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Whether the crate has already been taken. A taken crate is on its way out and offers
## nothing, so the spawner does not count it among the uncollected.
func is_taken() -> bool:
	return _taken


## How many rounds this crate would hand over right now: its share of the capacity, or
## only what is left to fill when the player is nearly full.
##
## 0 means there is nothing to give - no weapon in hand, or no room in it - which is
## what [method use] refuses on.
func available_rounds() -> int:
	var reserve := _get_reserve()
	if reserve == null:
		return 0
	return mini(crate_rounds(reserve), maxi(reserve.get_max() - reserve.get_current(), 0))


## What one crate is worth for [param reserve], before the player's remaining room is
## considered: [member refill_fraction] of the ceiling, rounded, and never less than one
## round for a weapon that has a capacity at all.
func crate_rounds(reserve: AmmoReserve) -> int:
	if reserve == null:
		return 0
	var ceiling := reserve.get_max()
	if ceiling <= 0:
		return 0
	return maxi(int(round(float(ceiling) * clampf(refill_fraction, 0.0, 1.0))), 1)


## Takes the crate, and returns how many rounds went in. 0 means it was refused and the
## crate is still standing.
##
## Ignored unless the player is actually at it, so nothing can be collected from across
## the arena.
func use() -> int:
	# A crate still in the air cannot be taken out of it - the same rule the reward chest
	# keeps, so nothing is collected from underneath something that has not arrived.
	if _taken or not _in_reach or not _landed:
		return 0

	var reserve := _get_reserve()
	if reserve == null or (requires_room and reserve.is_full()):
		refused.emit()
		return 0

	var taken := reserve.add(crate_rounds(reserve))
	if taken <= 0:
		refused.emit()
		return 0

	_taken = true
	if _prompt != null:
		_prompt.set_prompt_visible(false)
	# Left the group before the fade rather than after it, so the spawner counts the
	# crate as gone the instant it is taken instead of a fifth of a second later.
	remove_from_group(GROUP)
	set_process(false)

	collected.emit(taken, reserve.get_ammo_id())
	_play_taken()
	return taken


## The crate going: lifted and faded, then freed. Nothing waits on it - the rounds are
## already in the reserve by the time this runs - so a world torn down mid-fade loses
## nothing.
func _play_taken() -> void:
	# The bounce is let go of first, or it would keep moving the artwork underneath the
	# fade that is taking it away.
	if _fall != null and _fall.is_running():
		_fall.kill()

	var art := get_node_or_null(art_path) as CanvasItem
	if art == null or collect_fade <= 0.0:
		queue_free()
		return

	var tween := create_tween().set_parallel(true)
	tween.tween_property(art, "modulate:a", 0.0, collect_fade)
	if collect_lift > 0.0 and art is Node2D:
		var node := art as Node2D
		tween.tween_property(node, "position", node.position - Vector2(0.0, collect_lift),
			collect_fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	_watch_player()


## The prompt is told rather than asked, and only on the crossing, so it is not
## rewritten every frame and anything else that wants to react to the player arriving
## can hang off the signals instead of repeating the distance test.
func _watch_player() -> void:
	if _taken:
		return

	var body := get_tree().get_first_node_in_group(body_group) as Node2D
	var reach := is_in_reach(body)
	if reach == _in_reach:
		return

	_in_reach = reach
	if _prompt != null:
		_prompt.set_prompt_visible(_in_reach)
	if _in_reach:
		player_entered.emit()
	else:
		player_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _taken or not _in_reach:
		return
	if not event.is_action_pressed(interact_action):
		return

	use()
	# Marked handled whether it was taken or refused, so a press aimed at a crate is
	# never also a shot.
	get_viewport().set_input_as_handled()


## The reserve belonging to the gun in the player's hands, or null when they are
## empty-handed or the locker has never heard of what they are carrying.
func _get_reserve() -> AmmoReserve:
	var locker := _get_locker()
	return null if locker == null else locker.get_equipped_reserve()


func _get_locker() -> AmmoLocker:
	if _locker == null or not is_instance_valid(_locker):
		_locker = get_node_or_null(locker_path) as AmmoLocker
	return _locker
