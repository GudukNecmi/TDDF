class_name SunStage
extends Resource
## Where the sun stands at one hour of the day, and what its light does to the
## world while it is there.
##
## It is a resource for exactly the reason [DayStage] is: the set of them is an
## inspector array on the map's [SunController], so a seventh hour, a reorder, or
## a second map with a completely different sky is editing that array. No stage
## name, index or threshold is written anywhere in code, and in particular none of
## it is written into [ShadowCaster] - a caster reads the live sun and does what
## the geometry says.
##
## [b]The sun is authored as a place, not as a shadow.[/b] A stage says which way
## the light travels, how far away the sun is and how high it stands; where a
## shadow goes is then worked out from that and from where the object is standing -
## see [SunState]. Nothing here is a shadow offset, and moving the sun in the
## inspector moves every shadow in the world at once.
##
## [b]Length is the ratio of the two distances.[/b] A sun at
## [member sun_distance] 12000 and [member sun_height] 5000 rakes a shadow 2.4
## times the height of whatever casts it, so an artist tunes the rake by moving
## the sun rather than by typing a length - and the same numbers give a cactus a
## cactus-sized shadow and a bullet a bullet-sized one.

## What this hour is called. Never shown to the player; it is what makes the
## controller's inspector array readable and what a debug readout prints.
@export var stage_name: StringName = &"stage"

@export_group("Sun")
## Which way the light travels across the ground, in world space, as a direction
## pointing [i]from[/i] the sun [i]towards[/i] the map's sun anchor. Shadows at the
## anchor lie along it. Normalised on read, so its length here means nothing.
##
## Remember world Y is arena depth, not height: (0, 1) is light coming from the
## top of the screen and shadows thrown towards the camera.
@export var sun_direction := Vector2(0.35, 1.0)
## How far the sun stands from the map's sun anchor, along the ground, in world
## pixels. Together with [member sun_height] this is the sun's elevation: the
## ratio of the two is how many times its own height a shadow rakes.
##
## Large values make the light read as parallel across the map; small ones make
## shadows visibly fan out from underneath the sun.
@export_range(0.0, 200000.0, 1.0) var sun_distance: float = 12000.0
## How high the sun stands above the ground plane, in world pixels. Raising it
## shortens every shadow in the world; lowering it rakes them out.
@export_range(1.0, 200000.0, 1.0) var sun_height: float = 5000.0

@export_group("Light")
## The colour of the light at this hour, for the lighting systems. Read by
## [SunController]; nothing here writes to the world's [CanvasModulate], which
## still belongs to [DayCycleDirector].
@export var light_color := Color(1.0, 0.95, 0.88)
## What lamps, torches and muzzle flashes should multiply their authored energy by
## at this hour. Bright hours want less; night wants full.
@export_range(0.0, 8.0, 0.01) var light_energy: float = 1.0
## How strongly [member light_color] should apply, for whatever chooses to read it.
## 0 is "leave everything the colour it was authored".
@export_range(0.0, 1.0, 0.01) var ambient_intensity: float = 0.0

@export_group("Shadow")
## What colour shadows are on this map at this hour.
##
## [b]This is where a map's shadows get their colour and the only place.[/b]
## Nothing is written into [ShadowCaster] or [ShadowGroup], so a desert's shadows
## can be a warm brown while a cellar's are a cold near-black, and changing either
## is changing a value in the inspector on that map's own sun. The source artwork's
## own colours are discarded either way - see
## [code]shadow_silhouette.gdshader[/code], which writes this colour rather than
## multiplying by it - and how dark the mark actually reads is
## [member shadow_opacity], which is tuned separately.
##
## The alpha channel is ignored; near-black is the default, and is what a map that
## has not thought about it should keep.
@export var shadow_color := Color(0.02, 0.02, 0.02)
## How dark every shadow in the world is at this hour, before a group's or a
## caster's own multiplier. 0 is invisible, which is what a night sky is written
## with.
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 0.2
## How soft the silhouette's edge is. 0 is a cut-out of the artwork, 1 a smudge.
## It is a real blur of the finished shape, so it costs the same whatever it is set
## to and a low sun can be given a softer edge than a high one.
@export_range(0.0, 1.0, 0.01) var shadow_softness: float = 0.3
## How much the far tip of a shadow fades out along its length. Measured against
## how high up the object each point was drawn, so it is the head of a figure that
## fades and not whichever corner of a texture happens to be furthest out.
@export_range(0.0, 1.0, 0.01) var shadow_fade: float = 0.2
## How wide a shadow is, as a multiple of the width of the artwork casting it. A
## little under 1 keeps a low sun from painting a slab.
@export_range(0.0, 3.0, 0.01) var shadow_width_scale: float = 0.95
## Where along its own length a shadow is anchored to the point its caster's feet
## project to. 0 puts the near end there, which is what a cast shadow does; 0.5
## centres it, which is what a midday pool wants.
@export_range(0.0, 1.0, 0.01) var shadow_length_anchor: float = 0.02
## How much of its opacity a shadow loses per hundred world pixels its caster is
## above the ground. The mark under something at the top of a jump is fainter.
##
## [b]Length is not on this list on purpose.[/b] How long an airborne shadow is,
## and how far it has walked out from underneath its owner, both fall out of the
## sun's own geometry - see [SunState] - so there is nothing to author for them.
@export_range(0.0, 2.0, 0.01) var shadow_height_opacity_falloff: float = 0.4
## Furthest a shadow's near end may travel from the point its caster is standing
## on, in world pixels. It is the safety rail on a very low sun and a very high
## jump; 0 removes the limit rather than removing the system.
@export_range(0.0, 20000.0, 1.0) var shadow_max_distance: float = 1400.0

@export_group("Transition")
## How long the sun should take to travel [i]into[/i] this hour, in seconds. Below
## 0 uses [member SunController.transition_duration], which is what every stage
## does unless one hour in particular wants a slower dawn.
@export var transition_duration: float = -1.0


## [member sun_direction], guaranteed usable.
func get_direction() -> Vector2:
	if sun_direction.is_zero_approx():
		return Vector2.DOWN
	return sun_direction.normalized()


## How many times its own height a resting shadow rakes at the sun anchor - the
## ratio of the two distances, and the one number that used to be authored by hand
## as a shadow length.
func get_length_ratio() -> float:
	return sun_distance / maxf(sun_height, 0.001)


## Where the sun stands, on the ground plane, given the map's anchor. The sun
## itself is [member sun_height] above that point.
func get_sun_ground_position(anchor: Vector2) -> Vector2:
	return anchor - get_direction() * sun_distance


## A stage [param amount] of the way from [param from] to [param to].
##
## [b]Every value is interpolated[/b], which is what makes the sun travel rather
## than jump: a caster reading the result cannot tell a settled hour from a sun
## still on its way. Fills and returns [param into] when given, so a transition
## allocates nothing per frame.
static func blend(
		from: SunStage,
		to: SunStage,
		amount: float,
		into: SunStage = null) -> SunStage:
	if from == null:
		return to
	if to == null:
		return from

	var result := into if into != null else SunStage.new()
	var t := clampf(amount, 0.0, 1.0)

	result.stage_name = to.stage_name if t >= 0.5 else from.stage_name
	# Swung round as a direction rather than interpolated as a raw vector, so a sun
	# crossing from one side of the map to the other travels across the sky instead
	# of collapsing through the middle half way.
	result.sun_direction = from.get_direction().slerp(to.get_direction(), t)
	result.sun_distance = lerpf(from.sun_distance, to.sun_distance, t)
	result.sun_height = lerpf(from.sun_height, to.sun_height, t)

	result.light_color = from.light_color.lerp(to.light_color, t)
	result.light_energy = lerpf(from.light_energy, to.light_energy, t)
	result.ambient_intensity = lerpf(from.ambient_intensity, to.ambient_intensity, t)

	result.shadow_color = from.shadow_color.lerp(to.shadow_color, t)
	result.shadow_opacity = lerpf(from.shadow_opacity, to.shadow_opacity, t)
	result.shadow_softness = lerpf(from.shadow_softness, to.shadow_softness, t)
	result.shadow_fade = lerpf(from.shadow_fade, to.shadow_fade, t)
	result.shadow_width_scale = lerpf(from.shadow_width_scale, to.shadow_width_scale, t)
	result.shadow_length_anchor = lerpf(
		from.shadow_length_anchor, to.shadow_length_anchor, t)
	result.shadow_height_opacity_falloff = lerpf(
		from.shadow_height_opacity_falloff, to.shadow_height_opacity_falloff, t)
	result.shadow_max_distance = lerpf(
		from.shadow_max_distance, to.shadow_max_distance, t)
	result.transition_duration = to.transition_duration
	return result


## Copies [param other] into this stage in place, for the same reason
## [method blend] takes an [code]into[/code]: the live stage is one object the
## controller holds, so it is written rather than replaced.
func copy_from(other: SunStage) -> void:
	if other == null:
		return
	SunStage.blend(other, other, 1.0, self)


func _to_string() -> String:
	return "<SunStage %s  dir %s  dist %.0f  height %.0f  rake %.2f>" % [
		stage_name, get_direction(), sun_distance, sun_height, get_length_ratio()]
