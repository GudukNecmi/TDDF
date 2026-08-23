class_name Horse
extends Resource
## The animal at the front of the cart, and the only thing that decides how long
## a journey can take.
##
## It is a resource rather than a number on the travel screen for the same reason
## a [MapRegion] is one: a horse is a thing the player will own, replace and
## upgrade, and every one of those is a [code].tres[/code] file dropped into an
## inspector slot rather than a branch in a script. Nothing in the travel system
## names a horse or knows how many exist.
##
## [b]A horse states a range, not a number.[/b] [member fastest_days] is what the
## animal is capable of and [member slowest_days] is how long the player is
## allowed to deliberately dawdle - so the starting pack horse, which can only
## manage the long way round, is simply a horse whose two numbers are the same and
## which therefore offers exactly one option. A later three-day horse is
## [code]fastest_days = 3[/code] with the same slowest, and the selection screen
## grows a second and third tile without being told that anything changed.
##
## Nothing here knows what a day *is*. How many stages a day is divided into
## belongs to the map - see [member MapDefinition.day_stages] - and advancing the
## clock by that many belongs to [DayClock]. This only ever answers "how many".

## The handle the rest of the game uses, for a saved game or a shop to name a
## horse without holding the resource.
@export var horse_id: StringName = &"horse"
## What the player is shown it is called.
@export var display_name: String = "HORSE"
## A line about it, for the travel screen and, later, the stable that sells it.
@export var description: String = ""
## Picture of it. Optional - a horse with none is listed by name alone.
@export var icon: Texture2D

@export_group("Speed")
## The fewest day stages this animal can make the journey in. [b]This is the
## upgrade.[/b] Lowering it is what a better horse is; nothing else about travel
## changes.
@export var fastest_days: int = 4
## The most day stages the player may choose to take. Equal to
## [member fastest_days] - which is the starting horse - there is only one option
## and the screen offers a single tile.
##
## It is separate from the speed on purpose. Taking the long way round is a
## decision the player might want to make once arriving at a particular hour
## matters, and whether a given horse allows it is a fact about that horse rather
## than a rule in the travel system.
@export var slowest_days: int = 4


## Every duration the player may pick, fastest first. Always at least one entry,
## so a horse configured with nonsense still offers a journey rather than an
## empty screen.
func get_available_days() -> Array[int]:
	var fastest := maxi(fastest_days, 1)
	var slowest := maxi(slowest_days, fastest)
	var days: Array[int] = []
	for count: int in range(fastest, slowest + 1):
		days.append(count)
	return days


## Whether [param days] is a journey this horse will make.
func can_travel_in(days: int) -> bool:
	return get_available_days().has(days)


## The duration used when nothing has been picked - the fastest the animal can
## manage, which is what a caller with no screen to ask should assume.
func get_default_days() -> int:
	return maxi(fastest_days, 1)


## What this horse is called, falling back to its handle so one that has been
## given no display name still reads as something.
func get_label() -> String:
	return display_name if not display_name.is_empty() else String(horse_id)
