extends CharacterBody2D
## Constant-speed, 8-directional WASD movement.
##
## There is no acceleration or deceleration: the player is either moving at
## full speed or standing still. The visuals never rotate - the player always
## faces downward, even while walking up.
##
## The idle squash is owned by the [SquashIdle] AnimationPlayer, which keeps it
## running at all times and reads `velocity` to decide its playback speed.

## Movement speed in pixels per second.
@export var speed: float = 220.0
## Components allowed to scale the player's speed: [PlayerDeathSequence], which
## pins them where they are through a death and the healing that follows, and
## [TerrainSlow], which drags them through the ground they are standing on.
##
## Each one is asked for a multiplier and the answers are multiplied together, so
## a modifier can be added or dropped in the inspector without any of the others
## knowing, and one holding the player still overrules every other. Nothing ever
## writes to [member speed], so no component can leave the player permanently
## slower. Anything with a `get_speed_multiplier()` works here.
@export var speed_modifier_paths: Array[NodePath] = [^"DeathSequence", ^"TerrainSlow"]

var _speed_modifiers: Array[Node] = []


## Resolved once. A path that points at nothing, or at something that does not
## answer, is dropped here rather than being checked on every frame.
func _ready() -> void:
	for path: NodePath in speed_modifier_paths:
		var node := get_node_or_null(path)
		if node != null and node.has_method(&"get_speed_multiplier"):
			_speed_modifiers.append(node)


func _physics_process(_delta: float) -> void:
	var direction := _read_input_direction()
	velocity = direction * speed * _get_speed_multiplier()
	move_and_slide()


## How fast the player is actually able to move right now, in pixels per second -
## their authored speed with every modifier already folded in.
##
## [b]Asked for rather than read.[/b] Anything pacing itself against the player -
## the lizard that has to stay outrunnable, an effect that scales with how quickly
## they are travelling - needs the number the player is really moving at, and
## [member speed] alone is not it: the ground drags on it, a death pins it and a
## later upgrade will raise it. This is the one place the two are put together, so
## nothing else has to know which modifiers exist.
##
## It is what they *could* do, not what they are doing: standing still, this is
## still their full speed. `velocity.length()` is the other question.
func get_current_speed() -> float:
	return speed * _get_speed_multiplier()


## 1 whenever there are no modifiers, so the player moves exactly as it always
## did when every component is absent or removed.
##
## The world's own slow motion is folded in alongside them rather than being a
## component of the player's: it belongs to the map, not to the body, and the
## enemies read the very same number - see [WorldSlowdown]. A world without one
## contributes 1, so this is read unconditionally.
func _get_speed_multiplier() -> float:
	var multiplier := WorldSlowdown.get_multiplier(self)
	for modifier: Node in _speed_modifiers:
		var value: float = modifier.call(&"get_speed_multiplier")
		multiplier *= value
	return multiplier


## Returns the desired movement direction, normalized so diagonals are not faster.
func _read_input_direction() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
