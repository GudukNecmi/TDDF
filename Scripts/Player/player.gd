extends CharacterBody2D
## Constant-speed, 8-directional WASD movement.
##
## There is no acceleration or deceleration: the player is either moving at
## full speed or standing still. The visuals never rotate - the player always
## faces downward, even while walking up.
##
## The idle squash is owned by the [SquashIdle] AnimationPlayer, which keeps it
## running at all times and reads `velocity` to decide its playback speed.
##
## [b]The dash is the one exception to the constant speed[/b], and it is added
## rather than substituted: [PlayerDash] is handed the walk velocity worked out
## here and hands it back with a launch on top - see [member dash_path]. The
## visuals still never rotate; a dash lifts the artwork off the ground and puts
## it back down again.

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

## Component allowed to add motion of its own on top of the walk - see
## [PlayerDash]. It is handed the velocity the modifiers above have already
## settled and hands one back, so the walk is worked out in exactly one place
## and a launch is added to it rather than replacing it.
##
## Anything with an [code]apply_dash_velocity(velocity, delta)[/code] method
## works here. An empty path, or a node without it, leaves movement precisely
## as it was.
@export var dash_path: NodePath = ^"Dash"
## The shove a hit throws the player with - see [HitReaction], the same
## component every enemy is knocked about by. Added on top of the walk after
## everything else, and only while the player is free to move at all, so a death
## or a sleep that holds them still is never pushed. The player's own reaction is
## authored with no knockback of its own, so only a hit that carries a
## [member HitEffects.knockback_push] - a boss's sword - moves them. An empty path
## leaves movement exactly as it was.
@export var hit_reaction_path: NodePath = ^"HitReaction"

var _speed_modifiers: Array[Node] = []
var _dash: Node
var _hit_reaction: HitReaction


## Resolved once. A path that points at nothing, or at something that does not
## answer, is dropped here rather than being checked on every frame.
func _ready() -> void:
	for path: NodePath in speed_modifier_paths:
		var node := get_node_or_null(path)
		if node != null and node.has_method(&"get_speed_multiplier"):
			_speed_modifiers.append(node)

	var dash := get_node_or_null(dash_path)
	if dash != null and dash.has_method(&"apply_dash_velocity"):
		_dash = dash

	_hit_reaction = get_node_or_null(hit_reaction_path) as HitReaction


func _physics_process(delta: float) -> void:
	var direction := _read_input_direction()
	var multiplier := _get_speed_multiplier()
	velocity = direction * speed * multiplier
	# The dash rides on top of the walk rather than replacing it, so it decays
	# to nothing and control is already back the frame it lands.
	if _dash != null:
		var launched: Vector2 = _dash.call(&"apply_dash_velocity", velocity, delta)
		velocity = launched
	if _hit_reaction != null and multiplier > 0.0:
		velocity += _hit_reaction.get_knockback()
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
