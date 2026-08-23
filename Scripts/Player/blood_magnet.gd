class_name BloodMagnet
extends Node
## The player's pull on spilled blood. Blood comes to them on its own; there is
## no key, no mode and no reach.
##
## A death spills its blood exactly as it always did - thrown out of the body by
## [BloodSpray] and landing where it comes down - and every piece that lands is
## offered here as it lands. What this node does with it is a delay: the blood
## lies on the ground looking like ordinary floor blood for
## [member ground_delay], glows for [member glow_time], and sets off. All three
## stages are drawn by one [BloodStream], so a piece is a single [MultiMesh]
## instance from the moment it settles to the moment it is banked - no timers, no
## nodes and no particle systems are created per piece.
##
## The delay and the glow are rolled per piece within their variation, so a
## splash does not lift off as one block. That is the only randomness involved;
## the path itself is [BloodStream]'s business and is deliberately tight.
##
## Nothing is wired to this node. [BloodSpray] and [BloodEmitter] find it through
## [method get_active], and a world without one simply stains the floor the way
## it did before, so the whole system can be switched off by deleting this node
## without leaving anything broken.
##
## It is the single point where a drawn speck becomes currency: the blood visuals
## know nothing about [BloodWallet] and the wallet knows nothing about them, so
## either side can be retuned or replaced without touching the other.

## Emitted whenever blood reaches the player. [param amount] is what this batch
## was worth, [param total] is the wallet's running total.
signal blood_collected(amount: int, total: int)

## Group [method get_active] finds this node by, so nothing needs a NodePath
## across the scene.
const GROUP := &"blood_magnet"

## Body the blood is drawn to. Defaults to this component's parent.
@export var owner_path: NodePath = ^".."
## Where the blood in flight lives.
@export var stream_path: NodePath = ^"../BloodStream"
## The carried wallet collected blood is banked into - the [code]Blood[/code]
## autoload. Left unresolved, blood still flows and still reports through
## [signal blood_collected]; only the running total stops being kept.
@export var wallet_path: NodePath = ^"/root/Blood"
## Whether spilled blood is drawn in at all. Off, every piece stains the floor
## and stays there, which is exactly what the game did before this existed.
@export var enabled: bool = true
## Where on the body the blood converges. The player's origin is at their feet,
## so this is roughly chest height.
@export var target_offset := Vector2(0, -30)

@export_group("Attraction")
## How long blood lies on the ground, looking like any other stain, before
## anything happens to it.
@export var ground_delay: float = 0.2
## Spread on that delay, in seconds, rolled per piece, so a splash does not lift
## off as one block.
@export var ground_delay_variation: float = 0.07
## How long a piece glows before it sets off. The glow peaks at exactly the
## moment it starts moving - see [BloodStream] - so this is the wind-up rather
## than a separate flash.
@export var glow_time: float = 0.13
## Spread on that, rolled per piece.
@export var glow_time_variation: float = 0.04

@export_group("Collection")
## What one speck is worth to whatever ends up spending it.
@export var blood_per_speck: int = 1

@onready var _body: Node2D = get_node_or_null(owner_path) as Node2D
@onready var _stream: BloodStream = get_node_or_null(stream_path) as BloodStream
@onready var _wallet: BloodWallet = get_node_or_null(wallet_path) as BloodWallet

var _field: BloodField


func _ready() -> void:
	add_to_group(GROUP)
	if _stream != null:
		_stream.specks_arrived.connect(_on_specks_arrived)


## The magnet the rest of the scene should talk to. Null means this world has
## none, which every caller treats as "blood stays where it lands".
static func get_active(from_node: Node) -> BloodMagnet:
	if from_node == null or not from_node.is_inside_tree():
		return null
	return from_node.get_tree().get_first_node_in_group(GROUP) as BloodMagnet


## Kept up to date every frame, so blood already on its way keeps following the
## player as they walk rather than converging on where they were standing when it
## set off.
func _process(_delta: float) -> void:
	if _stream == null:
		return
	_stream.set_target(get_target_point())
	_dress_stream()


## Makes sure the stream has artwork to stamp its pieces with.
##
## A [MultiMesh] with no texture draws its quads bare, which reads on screen as
## plain squares - so this is not a nicety. The stream is given the arena's own
## blood art, the same way [BloodSpray] takes it, so a piece looks identical
## lying on the floor, flying out of a body and flowing to the player, and none
## of the three owns a second copy of it.
##
## The field lives in the arena and this lives on the player, so neither is
## guaranteed to have entered the tree first - hence the lazy look-up. Once the
## stream is dressed, or if it was given its own [member BloodStream.piece_texture]
## in the inspector, this is a single null check a frame and nothing more.
func _dress_stream() -> void:
	if _stream.texture != null:
		return
	if _field == null or not is_instance_valid(_field):
		_field = BloodField.get_active(self)
	_stream.adopt_texture_from(_field)


## Where blood is being drawn to, in world space.
func get_target_point() -> Vector2:
	if _body == null:
		return target_offset
	return _body.global_position + target_offset


## Blood on its way to the player right now, counting only the pieces actually
## moving. Anything reacting to the pull - the sound, a future UI - follows this
## rather than reaching into [BloodStream], so the stream stays private.
func get_flowing_count() -> int:
	return 0 if _stream == null else _stream.get_flowing_count()


## Every piece this node currently owns, including those still lying on the
## ground waiting out their delay.
func get_held_count() -> int:
	return 0 if _stream == null else _stream.get_in_flight_count()


## Takes ownership of one piece of spilled blood, wherever it came from.
##
## Returns false when it will not take it - switched off, or the stream is full -
## and the caller is then responsible for the blood, which every caller handles
## by staining the floor with it as it always did. Blood is therefore never lost
## to a busy frame; the worst case is that it stays on the ground.
##
## The piece is handed over with its own colour, size and rotation intact, so
## what lies on the ground is the very speck that flew out of the body rather
## than a fresh one rolled to look like it.
func absorb(speck: BloodField.Speck) -> bool:
	if not enabled or _stream == null or speck == null:
		return false
	return _stream.add_speck(speck, _roll_ground_delay(), _roll_glow_time())


## Drops everything currently held without banking it. Nothing in a run calls
## this - it exists for a caller that needs the pull cleared without the blood
## being counted.
func release_all() -> void:
	if _stream != null:
		_stream.clear_all()


func _roll_ground_delay() -> float:
	return maxf(ground_delay + randf_range(
		-ground_delay_variation, ground_delay_variation), 0.0)


func _roll_glow_time() -> float:
	return maxf(glow_time + randf_range(
		-glow_time_variation, glow_time_variation), 0.0)


## Banked the moment it lands. The wallet outlives the run, so blood is safe as
## soon as it reaches the player - dying is the only thing that can cost them it,
## and that is [PlayerDeathSequence]'s decision rather than this node's.
func _on_specks_arrived(count: int) -> void:
	if count <= 0:
		return

	var earned := count * blood_per_speck
	if _wallet != null:
		_wallet.add(earned)

	blood_collected.emit(earned, 0 if _wallet == null else _wallet.get_total())
