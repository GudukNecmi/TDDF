class_name SunState
extends RefCounted
## The sun as it actually stands right now, in world space, and the projection
## maths that follows from it.
##
## [b]This is the single source of truth for light direction and shadow
## projection.[/b] There is exactly one of these in the world - built and written
## in place by [SunController] - and every shadow in the game is worked out from
## it. No [Sprite2D] decides which way its own shadow points, and nothing about a
## source's rotation, mirroring, scale or parent can reach in here.
##
## [b]The model.[/b] The game is drawn flat but lit as though it were not. A point
## in the world is a ground position on the arena floor plus a height above it, and
## the sun is a ground position of its own plus [member height]. The shadow of a
## point is where the ray from the sun through that point meets the floor again:
##
##   [codeblock]
##   t = h / (sun.height - h)
##   ground_hit = p + (p - sun.position) * t
##   [/codeblock]
##
## Everything else falls out of that one line. A thing standing on the floor has
## h = 0 and its feet cast at its feet; a thing in the air has its shadow walk out
## from underneath it along the light and grow as it rises; and a silhouette is
## simply the same projection applied to its footing and to its top, which gives
## both where the shadow lies and how long it is. There is no shadow offset, no
## airborne special case and no per-object equation anywhere.
##
## [b]Directional is the same maths with the sun infinitely far away.[/b] Under
## [constant SunController.SUN_DIRECTIONAL] the rays are parallel, so the direction
## is one vector for the whole map and the length is a fixed ratio of the height.
## A map picks whichever reads better; nothing downstream can tell the difference.

## Where the sun stands on the ground plane, in world space. The sun itself is
## [member height] above this point. Only meaningful when
## [member directional] is false.
var position := Vector2.ZERO
## How high the sun stands above the ground plane, in world pixels.
var height: float = 5000.0
## Which way the light travels across the ground at the map's sun anchor. Used for
## the whole map under [member directional], and as a fallback anywhere the
## positional maths degenerates.
var direction := Vector2(0.35, 1.0).normalized()
## How many times its own height a resting shadow rakes - the sun's elevation as a
## single number. Used directly under [member directional].
var length_ratio: float = 2.4
## Whether the rays are parallel. See [SunController.ProjectionMode].
var directional: bool = false

## What colour shadows are on this map right now - see [member SunStage.shadow_color].
var shadow_color := Color(0.03, 0.02, 0.03)
## How dark every shadow in the world is, before any group's or caster's own
## multiplier.
var shadow_opacity: float = 0.2
## Edge softness handed to the shared shadow material.
var shadow_softness: float = 0.4
## How much a shadow's far tip fades out along its length.
var shadow_fade: float = 0.5
## How wide a shadow is, as a multiple of the artwork's own width.
var shadow_width_scale: float = 0.95
## Where along its length a shadow is anchored to its caster's projected footing.
var shadow_length_anchor: float = 0.02
## How much opacity a shadow loses per hundred world pixels of height.
var shadow_height_opacity_falloff: float = 0.4
## Furthest a shadow's near end may travel from its caster, in world pixels. 0 is
## no limit.
var shadow_max_distance: float = 1400.0

## The colour of the light right now, for the lighting systems rather than for the
## shadows.
var light_color := Color(1.0, 0.95, 0.88)
## What a lamp should multiply its authored energy by right now.
var light_energy: float = 1.0
## How strongly [member light_color] should apply, 0 to 1.
var ambient_intensity: float = 0.0

## What hour the sun is standing at, for a debug readout.
var stage_name: StringName = &"stage"


## Writes this state from an authored [SunStage] and the map's sun anchor. Called
## by [SunController] whenever the blend moves, so the whole world sees one sun.
func read_from(stage: SunStage, anchor: Vector2, is_directional: bool) -> void:
	if stage == null:
		return
	direction = stage.get_direction()
	height = maxf(stage.sun_height, 1.0)
	length_ratio = stage.get_length_ratio()
	position = stage.get_sun_ground_position(anchor)
	directional = is_directional

	shadow_color = stage.shadow_color
	shadow_opacity = stage.shadow_opacity
	shadow_softness = stage.shadow_softness
	shadow_fade = stage.shadow_fade
	shadow_width_scale = stage.shadow_width_scale
	shadow_length_anchor = stage.shadow_length_anchor
	shadow_height_opacity_falloff = stage.shadow_height_opacity_falloff
	shadow_max_distance = stage.shadow_max_distance

	light_color = stage.light_color
	light_energy = stage.light_energy
	ambient_intensity = stage.ambient_intensity
	stage_name = stage.stage_name


## Where a point at [param ground_position] and [param visual_height] above the
## floor throws its shadow onto the floor.
##
## [b]The whole of the projection.[/b] Nothing else in the game works out where a
## shadow goes, so nothing else can disagree about it.
func project(ground_position: Vector2, visual_height: float) -> Vector2:
	var h := maxf(visual_height, 0.0)
	if is_zero_approx(h):
		return ground_position
	if directional:
		return ground_position + direction * (h * length_ratio)

	var to_object := ground_position - position
	if to_object.is_zero_approx():
		# Standing exactly under the sun: no direction to lean, so the shadow is
		# straight down and the authored direction breaks the tie.
		return ground_position + direction * (h * length_ratio)

	# The sun cannot be reached, let alone passed: something thrown higher than the
	# sun would flip its shadow to the far side, so the ray is held just below it.
	var lift := minf(h, height * 0.98)
	return ground_position + to_object * (lift / (height - lift))


## Which way the shadow of something standing at [param ground_position] lies, in
## world space, as a unit vector pointing away from the sun.
##
## [b]It is a function of the sun and the ground, and of nothing else.[/b] A
## character facing the other way, a weapon spinning, a sprite mirrored or scaled -
## none of them are arguments to it, so none of them can turn a shadow round.
func shadow_direction_at(ground_position: Vector2) -> Vector2:
	if directional:
		return direction
	var to_object := ground_position - position
	if to_object.is_zero_approx():
		return direction
	return to_object.normalized()


## Where the sun is, as an (x, y, height) point in world space. For a debug
## readout, a lens flare, or anything that wants to draw the sun itself.
func get_sun_point() -> Vector3:
	return Vector3(position.x, position.y, height)


## Copies [param other] in place, so the one live state object is written rather
## than replaced.
func copy_from(other: SunState) -> void:
	if other == null:
		return
	position = other.position
	height = other.height
	direction = other.direction
	length_ratio = other.length_ratio
	directional = other.directional
	shadow_color = other.shadow_color
	shadow_opacity = other.shadow_opacity
	shadow_softness = other.shadow_softness
	shadow_fade = other.shadow_fade
	shadow_width_scale = other.shadow_width_scale
	shadow_length_anchor = other.shadow_length_anchor
	shadow_height_opacity_falloff = other.shadow_height_opacity_falloff
	shadow_max_distance = other.shadow_max_distance
	light_color = other.light_color
	light_energy = other.light_energy
	ambient_intensity = other.ambient_intensity
	stage_name = other.stage_name


func _to_string() -> String:
	return "<SunState %s  at %s h %.0f  rake %.2f%s>" % [
		stage_name, position, height, length_ratio,
		"  directional" if directional else ""]
