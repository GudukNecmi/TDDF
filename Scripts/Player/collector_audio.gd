class_name CollectorAudio
extends Node
## The sound of blood being drawn into the player.
##
## It is a [LoopingSound], so this node never starts or stops anything - it only
## sets a level each frame and lets the fading take care of itself. That is what
## lets the level be driven straight off a changing quantity, blood in flight,
## without any bookkeeping and without the loop clicking in and out as batches
## come and go.
##
## The level follows the *blood*, not the pull: [BloodMagnet] is always on, so a
## sound that followed the magnet would drone forever. It follows how much blood
## is actually moving, so a quiet arena is silent, a kill swells it, and it dies
## away as the last few specks land.
##
## Blood still lying on the ground waiting out its delay is deliberately not
## counted - the sound belongs to the flow, and starting it before anything moves
## would give the launch away.
##
## It reads [BloodMagnet] and writes to nothing else, so muting, retuning or
## removing this node cannot affect collection itself.

## Magnet whose flow is followed.
@export var magnet_path: NodePath = ^"../BloodMagnet"
## Loop that plays while blood is on its way in.
@export var suck_loop_path: NodePath = ^"SuckLoop"

@export_group("Suck loop")
## Specks in flight at which the loop reaches its full level. Below this it
## scales up smoothly; above it the sound is already at the ceiling, so a huge
## haul cannot run away with the mix.
@export var specks_for_full_volume: float = 90.0
## Level the loop is allowed to reach at that point. The hard decibel ceiling
## lives on the [LoopingSound] itself as `max_volume_db`; this is the fraction of
## it this system will ever ask for.
@export_range(0.0, 1.0) var suck_max_level: float = 1.0
## Shapes how the level grows with the amount of blood. Below 1 makes a small
## trickle already clearly audible; above 1 keeps quiet hauls quiet and saves the
## loudness for a real torrent.
@export_range(0.2, 3.0) var suck_response_curve: float = 0.65

@onready var _magnet: BloodMagnet = get_node_or_null(magnet_path) as BloodMagnet
@onready var _suck_loop: LoopingSound = get_node_or_null(suck_loop_path) as LoopingSound


func _process(_delta: float) -> void:
	if _magnet == null or _suck_loop == null:
		return
	_suck_loop.set_level(_suck_level())


## Scaled by how much blood is currently on its way to the player, so the sound
## swells with a big haul and dies away as the last few specks land.
func _suck_level() -> float:
	var flowing := float(_magnet.get_flowing_count())
	if flowing <= 0.0 or specks_for_full_volume <= 0.0:
		return 0.0

	var fraction := clampf(flowing / specks_for_full_volume, 0.0, 1.0)
	return pow(fraction, suck_response_curve) * suck_max_level
