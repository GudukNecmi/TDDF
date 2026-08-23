class_name DayStage
extends Resource
## One time of day on a map: dawn, noon, night. What is true about the world
## while the run is happening at that hour.
##
## A stage is a resource rather than a branch in a script so that the set of them
## is an inspector array on the map - see [DayCycleDirector]. Adding a seventh
## hour, reordering them, or giving a second map a completely different set of
## four is editing that array, and there is no name, index or threshold anywhere
## in code that has to be told about it.
##
## Right now a stage only carries a colour. The two prop hooks below are the
## reason it is a resource at all: "birds at dawn, fireflies at night" is a
## stage's own scenery, and it belongs on the stage rather than in a check
## somewhere that asks which hour it is. They are deliberately left empty for
## every stage until there is art for them, and a stage with both empty simply
## adds nothing to the shared desert.
##
## Nothing here is map-specific in the *code* sense: a stage does not know it is
## a desert. The desert's six stages are six [code].tres[/code] files under
## [code]Resources/Maps/Desert/Day/[/code].

## What this hour is called. Never shown to the player - it is the handle a
## debug key or a later system uses to ask for one particular stage, and what
## makes the inspector array readable.
@export var stage_name: StringName = &"stage"
## What the player is shown it is called, on the HUD and in the round intro.
## Separate from [member stage_name] so the wording can be changed, translated or
## capitalised differently without anything that looks a stage up breaking.
@export var display_name: String = "STAGE"

@export_group("Look")
## Colour the world's ambient [CanvasModulate] is set to while this stage is the
## one being played. This is the whole of what a stage changes about the *world*.
@export var ambient_colour := Color.WHITE
## The little sun, moon or horizon shown for this hour - on the HUD beside the
## round number, inside the next-round button, and in the round intro. One
## picture, used everywhere, so the three cannot drift apart.
@export var icon: Texture2D
## Colour any text naming this hour is written in. It is meant to be the colour
## of [member icon] itself, so the word and the picture read as one thing.
@export var icon_colour := Color.WHITE

@export_group("Clock")
## Earliest clock time this hour can be shown as, in minutes past midnight.
## 300 is 05:00.
@export_range(0, 1439, 1) var clock_start_minutes: int = 0
## Latest clock time, in minutes past midnight. Setting it *below*
## [member clock_start_minutes] wraps the range through midnight, which is what
## night wants - 21:00 to 05:00 is 1260 to 300.
@export_range(0, 1439, 1) var clock_end_minutes: int = 59
## How the clock is written. The hour and the minute are substituted in, in that
## order, so a twelve-hour or a different separator is a change here rather than
## in whatever happens to be displaying it.
@export var clock_format: String = "%02d:%02d"

@export_group("Stage scenery")
## Scattered props that exist only during this hour, strewn across the map
## alongside the shared ones. This is where a dawn's birds or a night's
## fireflies go: another [ScatterLayer], with its own count, spacing and prop
## scene, appended to the map's own layers rather than replacing them.
##
## Empty - which every stage is for now - leaves the map with exactly its shared
## scenery.
@export var extra_scatter_layers: Array[ScatterLayer] = []
## One-off scenes instanced once for this hour rather than strewn about: a
## weather effect, a sky layer, a light. Placed at the container the director is
## pointed at, at its origin, so where they sit is the scene's own business.
@export var extra_scenes: Array[PackedScene] = []


## A clock time somewhere inside this hour's range, already written out.
##
## The range belongs to the stage rather than to whatever shows it, so the hours
## a desert dawn can be are tuned next to the dawn's colour and its icon instead
## of inside a piece of UI - and a second map's dawn can run to different hours
## without the intro screen knowing.
##
## Ranges that run backwards are read as wrapping through midnight, so night can
## be 21:00 to 05:00 without being split into two stages.
func random_clock_text() -> String:
	var minutes := random_clock_minutes()
	return clock_format % [minutes / 60, minutes % 60]


## The same time as a raw number of minutes past midnight, for anything that
## wants to do arithmetic with it rather than print it.
func random_clock_minutes() -> int:
	var start := clampi(clock_start_minutes, 0, 1439)
	var span := clock_end_minutes - start
	if span < 0:
		# Wrapped: measure the span the long way round through midnight, roll
		# inside it, and bring the answer back onto the clock face.
		span += 1440
	return (start + randi_range(0, maxi(span, 0))) % 1440
