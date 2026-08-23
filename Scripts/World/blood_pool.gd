class_name BloodPool
extends Node2D
## The base's blood bank, drawn as a pool that visibly fills up.
##
## The pool owns no total of its own. What is in it *is* [BloodBank], the
## autoload, which is what makes the level survive a run: the world scene is
## rebuilt between runs and the pool is rebuilt with it, but the number it is
## drawing was never in the scene to be lost. Nothing here ever resets it.
##
## Depositing and withdrawing are the same operation in opposite directions -
## [method BloodWallet.transfer_to] moves blood between the player's carried
## wallet and the bank - so the pair of totals always sums to what it did before
## and neither direction can mint or lose blood.
##
## The accounting lands the moment the button goes down, and the blood flying
## between the hand and the pool is a *consequence* of it rather than the cause.
## That is deliberate: the readout has to move immediately, and a specks-in-flight
## ledger would put blood somewhere it could be stranded by a scene change.
## The flight is drawn by [BloodStream], the same node that flows blood into the
## player during a run, and the specks themselves are built by the arena's
## [BloodField] so blood in the base looks like blood in the arena.
##
## How full it *looks* is a list of textures, not code. The stored fraction picks
## one entry out of [member fill_textures] and writes it to one sprite, so adding
## a fill state is dropping a PNG into the array in the inspector - there is no
## threshold, no branch and no name anywhere in this file that a new stage would
## have to be added to.

## Emitted after blood has been banked, with what actually moved.
signal deposited(amount: int, stored: int)
## Emitted after blood has been drawn back out.
signal withdrawn(amount: int, stored: int)
## Emitted whenever the stored total changes, whatever moved it.
signal stored_changed(stored: int)
## Emitted when the pool changes which fill artwork it is showing.
signal fill_stage_changed(stage: int)

## The persistent bank this pool draws. Left unresolved the pool still runs and
## simply always reads empty.
@export var bank_path: NodePath = ^"/root/BloodBank"
## The player's carried blood, which a deposit comes out of.
@export var wallet_path: NodePath = ^"/root/Blood"
## Most blood the pool will take. 0 is unlimited - a deposit is never refused -
## which is what it is set to for now.
##
## The limit is kept as a system rather than deleted because a base upgrade will
## eventually buy a bigger pool: raising this number is the whole of that
## feature, and everything that reads [method get_free_space] or [method is_full]
## already behaves correctly at any value.
@export var capacity: int = 0
## What the pool is drawn as *full* at, which is a separate question from what it
## will accept. An unlimited pool still has to have something to be a fraction
## of, or the artwork would jump to its fullest state on the first drop and stay
## there - so this is the denominator the fill stage is chosen against and
## nothing else. A capacity above 0 overrules it, so a limited pool has exactly
## one number governing both.
@export var display_capacity: int = 600

@export_group("Fill states")
## Sprite whose texture is swapped. Only [member Sprite2D.texture] is ever
## written, so the sprite's position, scale and modulate stay yours.
@export var fill_sprite_path: NodePath = ^"Art/Fill"
## Artwork for each fill state, emptiest first. Entry 0 is the dry pool and is
## only ever shown at exactly zero; whatever is left of the range is split evenly
## between the rest, so a single drop already shows the lowest wet state and only
## a genuinely full pool shows the last one.
@export var fill_textures: Array[Texture2D] = []

@export_group("Interaction")
## Region the mouse has to be over. A separate node from the art on purpose, so
## the clickable area can be tightened to the basin without the sprite's
## transparent corners deciding it.
@export var click_area_path: NodePath = ^"ClickArea"
## Button that banks carried blood.
@export var deposit_button: MouseButton = MOUSE_BUTTON_LEFT
## Button that draws it back out.
@export var withdraw_button: MouseButton = MOUSE_BUTTON_RIGHT
## Blood moved by one click. 0 moves everything available, which is what makes a
## single click feel like emptying your hands into the pool.
@export var transfer_per_click: int = 0
## Marks the click handled, so the shot the same button would otherwise fire
## never goes off while the player is banking blood.
@export var consume_click: bool = true
## How close the player has to be standing to use the pool, in pixels. 0 lets them
## bank from anywhere they can see it.
@export var interaction_range: float = 0.0

@export_group("Flow")
## Stream that carries blood from the hand into the pool.
@export var deposit_stream_path: NodePath = ^"DepositStream"
## Stream that carries it back out to the hand.
@export var withdraw_stream_path: NodePath = ^"WithdrawStream"
## Where the specks converge, relative to this node - the middle of the basin.
@export var centre_offset := Vector2(0, 8)
## Group the player is found by, so nothing is wired to them.
@export var player_group: StringName = &"player"
## Where on the player blood leaves from and returns to. Their origin is at their
## feet, so this is roughly the outstretched hand.
@export var hand_offset := Vector2(0, -34)
## How far the specks of one transfer are scattered around their start point.
@export var spawn_scatter: float = 22.0
## Ceiling on how many specks one transfer draws, whatever it was worth. A
## thousand banked blood must not become a thousand instances.
@export var max_specks_per_transfer: int = 90
## Floor on the same, so banking a handful still reads as a stream rather than a
## single dot.
@export var min_specks_per_transfer: int = 12

@export_group("Feedback")
## Art given a squash whenever blood moves.
@export var art_path: NodePath = ^"Art"
## How much the pool swells on a deposit and pinches on a withdrawal.
@export var pulse_scale: float = 0.09
@export var pulse_out_time: float = 0.09
@export var pulse_back_time: float = 0.26
## Camera nudge on a transfer. 0 leaves the camera alone.
@export var camera_kick: float = 0.035

@onready var _bank: BloodWallet = get_node_or_null(bank_path) as BloodWallet
@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet
@onready var _fill: Sprite2D = get_node_or_null(fill_sprite_path) as Sprite2D
@onready var _art: Node2D = get_node_or_null(art_path) as Node2D
@onready var _deposit_stream: BloodStream = get_node_or_null(deposit_stream_path) as BloodStream
@onready var _withdraw_stream: BloodStream = get_node_or_null(withdraw_stream_path) as BloodStream
@onready var _click_area: Area2D = get_node_or_null(click_area_path) as Area2D

var _stage: int = -1
var _art_base_scale := Vector2.ONE
var _pulse_tween: Tween
var _field: BloodField


func _ready() -> void:
	if _art != null:
		_art_base_scale = _art.scale

	if _bank != null:
		_bank.changed.connect(_on_bank_changed)

	# The deposit target never moves, so it is set once rather than every frame.
	if _deposit_stream != null:
		_deposit_stream.set_target(get_centre())

	_refresh_fill()


func _process(_delta: float) -> void:
	# The withdrawal target is the player's hand, which walks away while the blood
	# is still in the air - so it is followed rather than captured at launch.
	if _withdraw_stream != null:
		_withdraw_stream.set_target(_hand_point())


## Where the specks converge, in world space.
func get_centre() -> Vector2:
	return global_position + centre_offset


func get_stored() -> int:
	return 0 if _bank == null else _bank.get_total()


func get_capacity() -> int:
	return capacity


## How much more the pool will take. Unlimited when [member capacity] is 0.
func get_free_space() -> int:
	if capacity <= 0:
		return 0x7FFFFFFF
	return maxi(capacity - get_stored(), 0)


func is_full() -> bool:
	return capacity > 0 and get_stored() >= capacity


## 0 empty, 1 at the level the pool is drawn full at. An unlimited pool measures
## against [member display_capacity] rather than reporting 1 for any drop at all,
## so removing the limit does not also remove the staging.
func get_fill_fraction() -> float:
	var stored := get_stored()
	if stored <= 0:
		return 0.0

	var against := capacity if capacity > 0 else display_capacity
	if against <= 0:
		return 1.0
	return clampf(float(stored) / float(against), 0.0, 1.0)


## Which entry of [member fill_textures] is currently being shown.
func get_fill_stage() -> int:
	return _stage


## Banks up to [param amount] of the player's carried blood, or everything they
## are carrying when it is 0 or less. Returns what actually moved, which is
## clamped by both what they have and what the pool will still take.
func deposit(amount: int = 0) -> int:
	if _wallet == null or _bank == null:
		return 0

	var wanted := amount if amount > 0 else _wallet.get_total()
	wanted = mini(wanted, get_free_space())
	var moved := _wallet.transfer_to(_bank, wanted)
	if moved <= 0:
		return 0

	_flow(_deposit_stream, _hand_point(), moved)
	_pulse(1.0)
	_kick_camera()
	deposited.emit(moved, get_stored())
	return moved


## Draws up to [param amount] back out of the pool and into the player's hands,
## or everything the pool holds when it is 0 or less. Returns what moved.
func withdraw(amount: int = 0) -> int:
	if _wallet == null or _bank == null:
		return 0

	var wanted := amount if amount > 0 else _bank.get_total()
	var moved := _bank.transfer_to(_wallet, wanted)
	if moved <= 0:
		return 0

	# Thrown out of the middle of the basin, so the pool visibly gives it up.
	_flow(_withdraw_stream, get_centre(), moved)
	_pulse(-1.0)
	_kick_camera()
	withdrawn.emit(moved, get_stored())
	return moved


## Clicks are read here rather than through [signal CollisionObject2D.input_event]
## on the area, even though the area is still what decides *where* the pool is.
##
## The reason is ordering. Physics picking runs on the physics frame, by which
## time the same press has already been offered to every `_unhandled_input` in the
## tree - so a pool that waited to be picked would bank the blood and fire the
## shotgun through itself, and marking the event handled by then would be too
## late to stop it. `_input` runs before all of that, so consuming the press here
## genuinely consumes it.
##
## The area is still the authority on the pool's shape: the test below is a point
## query against that very node, so the clickable region is whatever collision
## shape was authored in the scene and is never a radius guessed at in code.
func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index != deposit_button and button.button_index != withdraw_button:
		return
	if not _is_over_pool(button.position) or not _is_player_in_range():
		return

	var moved := 0
	if button.button_index == deposit_button:
		moved = deposit(transfer_per_click)
	else:
		moved = withdraw(transfer_per_click)

	# Handled even when nothing moved, so clicking an empty pool still does not
	# fire the shotgun through it.
	if consume_click:
		get_viewport().set_input_as_handled()
	if moved == 0:
		_pulse(0.0)


## Whether [param at_viewport] - the click's own position, not the live cursor -
## lands on the interaction area. Using the event's position is what keeps this
## working for injected input as well as a real mouse.
func _is_over_pool(at_viewport: Vector2) -> bool:
	if _click_area == null:
		return false

	var at_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * at_viewport
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at_world
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = _click_area.collision_layer

	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(query, 8):
		if hit.get("collider") == _click_area:
			return true
	return false


func _is_player_in_range() -> bool:
	if interaction_range <= 0.0:
		return true
	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null:
		return false
	return get_centre().distance_to(player.global_position) <= interaction_range


func _on_bank_changed(stored: int) -> void:
	_refresh_fill()
	stored_changed.emit(stored)


## Swaps in the artwork for the level the pool is at now. Guarded on the stage
## rather than the total, so a pool being filled a point at a time does not
## rewrite the same texture every frame.
func _refresh_fill() -> void:
	if _fill == null or fill_textures.is_empty():
		return

	var stage := _stage_for(get_fill_fraction())
	if stage == _stage:
		return

	_stage = stage
	if fill_textures[stage] != null:
		_fill.texture = fill_textures[stage]
	fill_stage_changed.emit(stage)


## Splits the fill into as many bands as there are textures. Stage 0 is reserved
## for a genuinely empty pool so that "dry" is never shown with blood in it, and
## the remaining stages divide the rest of the range evenly - which is the whole
## of the staging rule, and why a new stage needs nothing here.
func _stage_for(fraction: float) -> int:
	var count := fill_textures.size()
	if count <= 1 or fraction <= 0.0:
		return 0
	return clampi(1 + int(fraction * float(count - 1)), 1, count - 1)


## Releases the drawn half of a transfer. The count is not the amount - a
## thousand blood is still drawn as a stream you can see through - so this is
## deliberately independent of the accounting that has already happened.
func _flow(stream: BloodStream, from: Vector2, amount: int) -> void:
	if stream == null or amount <= 0:
		return

	var field := _get_field()
	if field != null:
		stream.adopt_texture_from(field)

	var wanted := clampi(amount, min_specks_per_transfer, maxi(max_specks_per_transfer, 1))
	wanted = mini(wanted, stream.get_free_slots())
	for i in wanted:
		var at := from + Vector2(randf_range(0.0, spawn_scatter), 0.0).rotated(randf() * TAU)
		var speck := field.make_speck(at) if field != null else _plain_speck(at)
		stream.add_speck(speck)


## Fallback for a world with no [BloodField] - the base on its own, or a test
## scene. Blood still flows, it just does not match a floor that is not there.
func _plain_speck(at: Vector2) -> BloodField.Speck:
	var speck := BloodField.Speck.new()
	speck.position = at
	speck.rotation = randf() * TAU
	speck.scale = Vector2(randf_range(5.0, 11.0), randf_range(4.0, 9.0))
	speck.colour = Color(0.44, 0.03, 0.04, randf_range(0.6, 0.92))
	return speck


## [param direction] is +1 for a deposit swelling the pool, -1 for a withdrawal
## pinching it, and 0 for a refused click, which still twitches so a full pool or
## an empty wallet is not silent.
func _pulse(direction: float) -> void:
	if _art == null:
		return

	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	var swell := 1.0 + pulse_scale * direction
	if is_zero_approx(direction):
		swell = 1.0 - pulse_scale * 0.4

	_art.scale = _art_base_scale
	_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_pulse_tween.tween_property(_art, "scale", _art_base_scale * swell, pulse_out_time) \
		.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_art, "scale", _art_base_scale, pulse_back_time) \
		.set_ease(Tween.EASE_IN_OUT)


func _kick_camera() -> void:
	if is_zero_approx(camera_kick):
		return
	var camera := CameraController.get_active(self)
	if camera != null:
		camera.zoom_kick(camera_kick, 0.07, 0.22)


func _hand_point() -> Vector2:
	var player := get_tree().get_first_node_in_group(player_group) as Node2D
	if player == null:
		return get_centre()
	return player.global_position + hand_offset


## Looked up lazily and re-looked-up if it goes away, the same way the spray finds
## it - the field lives in the arena and may be rebuilt without the base.
func _get_field() -> BloodField:
	if _field == null or not is_instance_valid(_field):
		_field = BloodField.get_active(self)
	return _field
