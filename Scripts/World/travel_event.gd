class_name TravelEvent
extends Resource
## One thing that can happen on one day of a journey: nothing at all, an ambush,
## or a gang on the road.
##
## [b]It is a resource so that what can happen on the road is data.[/b] The
## director holds an array of these - see [member TravelDirector.travel_events] -
## rolls one per travel day, and does what the file says. Nothing in any script
## names an ambush or a gang, counts how many kinds there are, or carries a
## probability: a fourth event is a [code].tres[/code] dropped into that array, and
## retuning how dangerous the road is is editing these files.
##
## The three the game ships with differ only in their fields:
##
##   * [b]Nothing[/b] - [member enemy_count] of zero and no choice. The day passes.
##   * [b]Ambush[/b] - enemies and no choice. The fight simply happens.
##   * [b]Gang[/b] - enemies and [member offers_choice], so the player is asked
##     whether to ride past or take them on, and fewer of them than an ambush.
##
## [b]It owns no behaviour.[/b] Spawning, the choice screen and getting back on the
## road are the director's; this only ever answers what this event is like.

## The handle, for a saved game or a later system to name an event without holding
## the resource.
@export var event_id: StringName = &"event"
## What the player is told this is, on the choice screen and over the black.
@export var display_name: String = "THE ROAD"
## A line under that name, for anything worth saying about it.
@export var description: String = ""

@export_group("The word over the black")
## What the player is told happened, once the day has been rolled and before
## anything comes of it - "NOTHING HAPPENED.", "AMBUSH!".
##
## [b]It is a separate line from [member display_name] on purpose.[/b] The name is
## what a thing is called on the choice screen; this is what is shouted over the
## black at the moment it is found out, and the two want different wording - "QUIET
## ROAD" is a name, "NOTHING HAPPENED." is news. Left empty it falls back to the
## name, so an event that does not care is one field lighter.
@export var result_text: String = ""
## The colour that line is written in, so a quiet day and an ambush read apart
## before they have been read at all.
@export var result_colour := Color(0.84, 0.76, 0.73)

@export_group("Chance")

## How likely this event is, against the other entries in the same array.
##
## [b]A weight, not a percentage.[/b] The director adds up every event's weight and
## picks in proportion, so the numbers never have to total anything in particular
## and adding a fourth event does not mean editing the other three. A weight of
## zero is an event that is authored but cannot currently happen, which is how one
## is switched off without being deleted.
@export var weight: float = 1.0

@export_group("The fight")
## How many enemies this event puts on the road. [b]Zero is "nothing happens"[/b] -
## the day passes and the journey carries on - so a quiet day is an event like any
## other rather than a branch in the director.
##
## They are built by the world's own [EnemySpawner], so they are the game's
## ordinary enemies and there is no travel enemy anywhere.
@export var enemy_count: int = 0
## Whether the player is asked before the fight starts.
##
## On is the gang: the road stops and a choice comes up. Off is the ambush, which
## is not a decision - it is already happening. What the two buttons say is below,
## so the wording of a later event is its own file's business.
@export var offers_choice: bool = false
## What the button that rides past says.
@export var ignore_text: String = "IGNORE"
## What the button that takes them on says.
@export var fight_text: String = "FIGHT"
## Whether this event's fight is run by the dedicated ambush system - see
## [AmbushWaveDirector].
##
## [b]On is an ambush: short, dense, and as large as the country it happens in.[/b]
## The size is the region's answer rather than [member enemy_count], because being
## jumped in the deep desert should not be the same fight as being jumped at its
## edge - so an ambush event carries no count of its own worth reading.
##
## Off is the plain encounter the road has always had: exactly
## [member enemy_count] enemies, placed off the edges of the view, ending when the
## last is down. That is what the gang is, and it is untouched by any of this.
##
## A world with no ambush system in it runs an ambush as a plain encounter, so this
## can never be the reason a journey stalls.
@export var uses_ambush_wave: bool = false


## What this event is called, falling back to its handle so one given no display
## name still reads as something.
func get_label() -> String:
	return display_name if not display_name.is_empty() else String(event_id)


## The line shouted over the black when this day is rolled, falling back to the
## event's name so an event given no wording of its own still says something.
func get_result_text() -> String:
	return result_text if not result_text.is_empty() else get_label()


## Whether anything at all happens on a day that rolls this.
##
## An ambush is never quiet however [member enemy_count] is authored, because its
## size is not read from there - see [member uses_ambush_wave].
func is_quiet() -> bool:
	if uses_ambush_wave:
		return false
	return enemy_count <= 0


## How much this event should count for in a roll. Negative weights are read as
## zero rather than as a chance running backwards.
func get_weight() -> float:
	return maxf(weight, 0.0)


## One event picked out of [param events] in proportion to their weights.
##
## [b]The weights do not have to add up to anything[/b]: the total is taken and the
## roll is made against it, so a table authored 60/25/15 and one authored 6/2.5/1.5
## behave identically, and switching an event off is setting its weight to zero
## rather than rebalancing the others.
##
## Null - an empty table, or every weight zero - is a quiet day, which every caller
## reads as "nothing happened".
##
## It lives on the resource rather than on whatever is rolling, so the road and the
## night pick out of a table by exactly the same rule.
static func roll(events: Array[TravelEvent]) -> TravelEvent:
	var total := 0.0
	for event: TravelEvent in events:
		if event != null:
			total += event.get_weight()
	if total <= 0.0:
		return null

	var chance := randf() * total
	for event: TravelEvent in events:
		if event == null:
			continue
		chance -= event.get_weight()
		if chance <= 0.0:
			return event

	# Only reachable on floating-point crumbs at the very top of the range.
	for index: int in range(events.size() - 1, -1, -1):
		var event := events[index]
		if event != null and event.get_weight() > 0.0:
			return event
	return null
