class_name MapDefinition
extends Resource
## One place the player can go on a run: the desert, and the four that are not
## built yet.
##
## It is a resource rather than an entry in a script so that the roster is an
## inspector array - see [MapCatalog]. Unlocking the forest later is ticking
## [member unlocked] on a [code].tres[/code] file; adding a sixth map is adding
## one. No list of names exists in any script that would have to be kept in step.
##
## The same definition is read by both places a map is named to the player: the
## selection menu the base's portal opens, and the round intro's title card. That
## is on purpose - the desert's title art and the desert's menu entry being one
## resource is what stops the two from disagreeing about what the map is called.

## The handle the rest of the game uses. What [RunSessionState] stores, and what
## the round intro matches against to find its title card. Never shown.
@export var map_id: StringName = &"map"
## What the player is shown it is called, in the selection menu.
@export var display_name: String = "MAP"
## The title card shown as a run on this map opens. The desert's is a piece of
## artwork with the word already drawn into it, which is why this is a texture
## and not a font size.
@export var title_texture: Texture2D
## Whether the map can be picked. A locked map is still listed - the point of
## showing it is that the player can see there is more coming - but it cannot be
## selected and is drawn dimmed.
@export var unlocked: bool = false
## What a locked entry says instead of being selectable.
@export var locked_label: String = "LOCKED"

@export_group("Regions")
## The map divided into named parts - what the region selection screen offers
## before a run, and what a wanted poster names when it knows roughly where the
## target is.
##
## [b]It lives on the map rather than in the bounty system or in the screen[/b],
## because it is a fact about this place: a desert is cut up differently from a
## town, and neither holds a setting about the other. Both the screen and the
## generator read this one array, so the region the player picks and the region a
## poster names can never be called different things.
##
## Nothing reads a count or a name out of it. Adding a sixth part of the desert is
## dropping a [MapRegion] in here; a map divided into places with real names
## instead of letters needs nothing else changed. A map that lists none falls back
## to [member BountySettings.fallback_regions] for its posters, so a place that
## has not been divided up yet still produces sensible ones.
@export var regions: Array[MapRegion] = []
## Which part of this map a run arrives in when the player has not been asked -
## the desert's A, the way in.
##
## [b]The map names its own front door.[/b] Riding out no longer asks which region
## to start in: the player picks the place and lands at its entry point, and only
## the camp's TRAVEL moves them on from there. Which one that is is a fact about
## the map, so a second map's way in is a field on its own [code].tres[/code] and
## nothing in code names a region.
##
## Left empty it is the first unlocked entry in [member regions], so a map that has
## not been given one still has a sensible way in rather than none at all. See
## [method get_entry_region].
@export var entry_region_id: StringName = &""
## The picture the camp's regional map is drawn on: this place seen from above,
## with its parts laid out where [member MapRegion.map_position] says they are.
##
## It lives on the map for the same reason the regions do - it is a fact about this
## place - so a second map is another texture on another [code].tres[/code] and the
## camp's map screen needs nothing changed. A map with none is drawn as bare
## ground with its regions still marked on it.
@export var region_map_texture: Texture2D

@export_group("Arrival")
## How likely a journey that ends on this map is met with a fight where the player
## gets down off the horse, from 0 (the road always ends quietly) to 1 (there is
## always somebody waiting).
##
## [b]It is the map's own number, not the arrival system's.[/b] How dangerous it is
## to ride into a place is a fact about the place - the desert is 0.4 and the
## forest is 0.5 - so it is authored on the [code].tres[/code] file alongside
## everything else that is true of that map, and a sixth map states its own chance
## without a name, a threshold or a table existing in any script. See
## [RegionArrival], which rolls it and knows nothing about which map it is rolling
## for.
@export_range(0.0, 1.0, 0.01) var arrival_combat_chance: float = 0.4
## How many are waiting when a run arrives in a part of this map of danger 0 - the
## map's way in.
##
## The two ends are read against [method MapRegion.get_difficulty] rather than
## authored per region, exactly as an ambush's size is, so retuning how hard it is
## to ride into this map is two fields here rather than an edit to five region
## files.
@export var arrival_entry_enemy_count: int = 4
## How many are waiting in this map's deadliest corner - a region of danger 1.
@export var arrival_deepest_enemy_count: int = 12

@export_group("Bounties")
## The hours this map can be hunted at, for anything asking about the map from
## outside it - a wanted poster naming a time of day is read in the base, with
## the map itself not loaded.
##
## These are the same [DayStage] resources the map's own [DayCycleDirector]
## plays through, pointed at from here as well so the roster can be read without
## the map's scene being in the tree. The director stays the authority on what
## hour is being played right now; this is only the list of which hours exist.
@export var day_stages: Array[DayStage] = []


## The parts of this map that can actually be picked. What the selection screen
## offers; a locked region is still listed there so the player can see there is
## more of the map coming, exactly as a locked map is.
func unlocked_regions() -> Array[MapRegion]:
	var open: Array[MapRegion] = []
	for region: MapRegion in regions:
		if region != null and region.unlocked:
			open.append(region)
	return open


## Where a run on this map begins - see [member entry_region_id].
##
## Falls through twice on purpose: the named entry first, then the first region
## that is actually open. A map whose named entry has been locked or renamed still
## has a way in rather than dropping the player nowhere, and a map with no regions
## at all answers null, which callers read as "this map is not divided up".
func get_entry_region() -> MapRegion:
	if entry_region_id != &"":
		var named := find_region(entry_region_id)
		if named != null:
			return named

	for region: MapRegion in regions:
		if region != null and region.unlocked:
			return region
	return null


## How likely arriving on this map is a fight, held to 0..1 - so a map authored out
## of range, or one from a catalogue that predates arrival combat, still answers
## something the roll can be taken against.
func get_arrival_combat_chance() -> float:
	return clampf(arrival_combat_chance, 0.0, 1.0)


## How many enemies an arrival in [param region] is worth: read between
## [member arrival_entry_enemy_count] and [member arrival_deepest_enemy_count]
## against that region's own danger.
##
## A null region - a map that has not been divided up, or a journey with nowhere
## named at the end of it - is read as danger 0 rather than as an error, so the
## quietest arrival is what an unknown destination produces.
func get_arrival_enemy_count(region: MapRegion) -> int:
	var danger := 0.0 if region == null else region.get_difficulty()
	var size := lerpf(float(arrival_entry_enemy_count), float(arrival_deepest_enemy_count), danger)
	return maxi(int(round(size)), 0)


## The region with [param region_id], or null when this map has none by that name -
## which every caller reads as "the run has not been sent anywhere in particular".
func find_region(region_id: StringName) -> MapRegion:
	for region: MapRegion in regions:
		if region != null and region.region_id == region_id:
			return region
	return null


## The hour called [param stage_name], or null. The companion to
## [method find_region], for anything holding an hour as a handle rather than as
## a resource - a wanted poster's answer, or a run being asked what time it is at.
func find_day_stage(stage_name: StringName) -> DayStage:
	for stage: DayStage in day_stages:
		if stage != null and stage.stage_name == stage_name:
			return stage
	return null
